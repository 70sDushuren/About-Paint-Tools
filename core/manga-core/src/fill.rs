//! Anime anti-halo flood fill engine (v0.4):
//! Close-Gap morphological barrier sealing + Edge-Expand pixel dilation
//! + Reference-Layer awareness (matching ibisPaint X / Clip Studio Paint workflows).

use std::collections::{HashSet, VecDeque};

use crate::layer::{LayerId, LayerStack};
use crate::tile::TileCoord;

/// Configuration for anime/manga bucket fill.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FillOptions {
    /// Per-channel color tolerance (`0..=255`) when matching the seed pixel.
    pub tolerance: u8,
    /// Maximum unclosed lineart gap width in pixels to seal automatically (`0..=8`).
    pub close_gap_px: u8,
    /// Outward pixel expansion (`0..=4`) to tuck flat color under anti-aliased lineart (zero white halos).
    pub expand_px: u8,
    /// Minimum alpha (`1..=255`) treated as a lineart barrier on reference layers.
    pub reference_alpha_threshold: u8,
}

impl Default for FillOptions {
    fn default() -> Self {
        Self {
            tolerance: 24,
            close_gap_px: 3,
            expand_px: 1,
            reference_alpha_threshold: 64,
        }
    }
}

/// Summary returned after executing a flood fill operation.
#[derive(Debug, Clone)]
pub struct FillResult {
    pub filled_pixels: usize,
    pub dirty_tiles: Vec<TileCoord>,
}

#[inline]
fn color_within_tolerance(a: [u8; 4], b: [u8; 4], tol: u8) -> bool {
    let t = tol as i16;
    (a[0] as i16 - b[0] as i16).abs() <= t
        && (a[1] as i16 - b[1] as i16).abs() <= t
        && (a[2] as i16 - b[2] as i16).abs() <= t
        && (a[3] as i16 - b[3] as i16).abs() <= t
}

/// Separable box/Chebyshev morphological dilation on a 2D boolean mask.
fn dilate_mask(mask: &[bool], w: usize, h: usize, radius: usize) -> Vec<bool> {
    if radius == 0 {
        return mask.to_vec();
    }
    let mut horiz = vec![false; w * h];
    for y in 0..h {
        let row = y * w;
        let mut count = 0usize;
        let init_end = radius.min(w - 1);
        for x in 0..=init_end {
            if mask[row + x] {
                count += 1;
            }
        }
        for x in 0..w {
            horiz[row + x] = count > 0;
            if x >= radius && mask[row + x - radius] {
                count -= 1;
            }
            if x + radius + 1 < w && mask[row + x + radius + 1] {
                count += 1;
            }
        }
    }

    let mut out = vec![false; w * h];
    for x in 0..w {
        let mut count = 0usize;
        let init_end = radius.min(h - 1);
        for y in 0..=init_end {
            if horiz[y * w + x] {
                count += 1;
            }
        }
        for y in 0..h {
            out[y * w + x] = count > 0;
            if y >= radius && horiz[(y - radius) * w + x] {
                count -= 1;
            }
            if y + radius + 1 < h && horiz[(y + radius + 1) * w + x] {
                count += 1;
            }
        }
    }
    out
}

/// Executes Close-Gap + Edge-Expand flood fill onto `target_id` inside `stack`.
///
/// If any visible layers are marked `is_reference`, their non-transparent strokes
/// act as barriers (standard anime workflow: Reference Lineart on top, Flat Color below).
/// Otherwise, barriers are computed by color tolerance against the seed pixel on `target_id`.
pub fn close_gap_expand_fill(
    stack: &mut LayerStack,
    target_id: LayerId,
    seed_x: u32,
    seed_y: u32,
    fill_rgba: [u8; 4],
    options: FillOptions,
) -> FillResult {
    let w = stack.width as usize;
    let h = stack.height as usize;
    if seed_x >= stack.width || seed_y >= stack.height || w == 0 || h == 0 {
        return FillResult {
            filled_pixels: 0,
            dirty_tiles: Vec::new(),
        };
    }

    let Some(target_snapshot) = stack.get(target_id) else {
        return FillResult {
            filled_pixels: 0,
            dirty_tiles: Vec::new(),
        };
    };
    if target_snapshot.locked {
        return FillResult {
            filled_pixels: 0,
            dirty_tiles: Vec::new(),
        };
    }

    let ref_ids = stack.reference_layer_ids();
    let use_refs = !ref_ids.is_empty();

    // Step 1: Build raw obstacle barrier mask.
    let mut raw_barrier = vec![false; w * h];
    if use_refs {
        for &ref_id in &ref_ids {
            if let Some(layer) = stack.get(ref_id) {
                if let Some(tile_layer) = layer.raster.as_ref() {
                    for y in 0..h {
                        for x in 0..w {
                            let p = tile_layer.get_pixel(x as u32, y as u32);
                            if p[3] >= options.reference_alpha_threshold {
                                raw_barrier[y * w + x] = true;
                            }
                        }
                    }
                }
            }
        }
    } else if let Some(tile_layer) = stack.get(target_id).and_then(|l| l.raster.as_ref()) {
        let seed_color = tile_layer.get_pixel(seed_x, seed_y);
        for y in 0..h {
            for x in 0..w {
                let p = tile_layer.get_pixel(x as u32, y as u32);
                if !color_within_tolerance(p, seed_color, options.tolerance) {
                    raw_barrier[y * w + x] = true;
                }
            }
        }
    }

    let seed_idx = seed_y as usize * w + seed_x as usize;
    if raw_barrier[seed_idx] {
        return FillResult {
            filled_pixels: 0,
            dirty_tiles: Vec::new(),
        };
    }

    // Step 2: Close-Gap barrier dilation (`r = ceil(close_gap_px / 2)` seals gaps up to `close_gap_px`).
    let gap_radius = (options.close_gap_px as usize).div_ceil(2);
    let closed_barrier = if gap_radius > 0 {
        dilate_mask(&raw_barrier, w, h, gap_radius)
    } else {
        raw_barrier.clone()
    };

    // If the seed itself sits within `gap_radius` of a wall, fall back to raw_barrier for seeding.
    let active_barrier = if closed_barrier[seed_idx] {
        &raw_barrier
    } else {
        &closed_barrier
    };

    // Step 3: 4-connected BFS flood fill on the closed barrier map.
    let mut filled = vec![false; w * h];
    let mut queue = VecDeque::new();
    filled[seed_idx] = true;
    queue.push_back((seed_x as usize, seed_y as usize));

    while let Some((cx, cy)) = queue.pop_front() {
        let neighbors = [
            (cx.wrapping_sub(1), cy, cx > 0),
            (cx + 1, cy, cx + 1 < w),
            (cx, cy.wrapping_sub(1), cy > 0),
            (cx, cy + 1, cy + 1 < h),
        ];
        for (nx, ny, valid) in neighbors {
            if !valid {
                continue;
            }
            let nidx = ny * w + nx;
            if !filled[nidx] && !active_barrier[nidx] {
                filled[nidx] = true;
                queue.push_back((nx, ny));
            }
        }
    }

    // Step 4: Recover the thin inner rim eaten by `gap_radius`, clipped against `raw_barrier`.
    let mut final_mask = if gap_radius > 0 && !closed_barrier[seed_idx] {
        let recovered = dilate_mask(&filled, w, h, gap_radius);
        recovered
            .into_iter()
            .enumerate()
            .map(|(i, v)| v && !raw_barrier[i])
            .collect::<Vec<bool>>()
    } else {
        filled
    };

    // Step 5: Anti-white-halo outward pixel expansion (`expand_px`) underneath the lineart.
    if options.expand_px > 0 {
        final_mask = dilate_mask(&final_mask, w, h, options.expand_px as usize);
    }

    // Step 6: Commit pixels into target layer and collect dirtied tiles.
    let mut dirty = HashSet::new();
    let mut filled_pixels = 0usize;
    if let Some(target) = stack.get_mut(target_id) {
        for y in 0..h {
            let row = y * w;
            for x in 0..w {
                if final_mask[row + x] && target.write_pixel(x as u32, y as u32, fill_rgba) {
                    filled_pixels += 1;
                    let (coord, _, _) = TileCoord::from_pixel(x as i32, y as i32);
                    dirty.insert(coord);
                }
            }
        }
    }

    FillResult {
        filled_pixels,
        dirty_tiles: dirty.into_iter().collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn build_box_with_3px_gap(stack: &mut LayerStack, ref_id: LayerId) {
        let line = stack.get_mut(ref_id).unwrap();
        line.is_reference = true;
        // Draw a 40x40 black box from (10, 10) to (50, 50) with a 3px gap on the top edge (28..=30).
        for x in 10..=50 {
            if !(28..=30).contains(&x) {
                line.write_pixel(x, 10, [0, 0, 0, 255]);
            }
            line.write_pixel(x, 50, [0, 0, 0, 255]);
        }
        for y in 10..=50 {
            line.write_pixel(10, y, [0, 0, 0, 255]);
            line.write_pixel(50, y, [0, 0, 0, 255]);
        }
    }

    #[test]
    fn close_gap_seals_3px_lineart_break_and_prevents_leak() {
        let mut stack_leak = LayerStack::new(80, 80);
        let flat_a = stack_leak.add_raster_layer("Flat");
        let ink_a = stack_leak.add_raster_layer("Ink");
        build_box_with_3px_gap(&mut stack_leak, ink_a);

        // Without Close Gap, fill leaks outside the box to (2, 2).
        close_gap_expand_fill(
            &mut stack_leak,
            flat_a,
            30,
            30,
            [255, 180, 200, 255],
            FillOptions {
                close_gap_px: 0,
                expand_px: 0,
                ..Default::default()
            },
        );
        assert_eq!(
            stack_leak.get(flat_a).unwrap().raster.as_ref().unwrap().get_pixel(2, 2),
            [255, 180, 200, 255],
            "Without Close Gap, fill should leak out of the 3px gap"
        );

        // With Close Gap = 3 and Expand = 1, fill stays 100% contained AND expands 1px under lineart!
        let mut stack_sealed = LayerStack::new(80, 80);
        let flat_b = stack_sealed.add_raster_layer("Flat");
        let ink_b = stack_sealed.add_raster_layer("Ink");
        build_box_with_3px_gap(&mut stack_sealed, ink_b);

        let res = close_gap_expand_fill(
            &mut stack_sealed,
            flat_b,
            30,
            30,
            [255, 180, 200, 255],
            FillOptions {
                close_gap_px: 3,
                expand_px: 1,
                ..Default::default()
            },
        );
        let flat_tile = stack_sealed.get(flat_b).unwrap().raster.as_ref().unwrap();
        assert!(res.filled_pixels > 1000);
        assert_eq!(flat_tile.get_pixel(30, 30), [255, 180, 200, 255]);
        // Outside remains completely clean (no leak!).
        assert_eq!(flat_tile.get_pixel(2, 2), [0, 0, 0, 0]);
        // Anti-white-halo: 1px expansion reaches directly underneath the left lineart edge at x = 10.
        assert_eq!(flat_tile.get_pixel(10, 30), [255, 180, 200, 255]);
    }
}
