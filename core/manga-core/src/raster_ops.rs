//! `S2 v1.0.0-rc3` — Real RGBA8 Raster Brush, Transparent Eraser, Smudge, Blur,
//! Selection-Masked Close-Gap Bucket Fill, and Fast Tile-Aware Viewport Compositor.

use crate::fill::{close_gap_expand_fill, FillOptions, FillResult};
use crate::layer::{blend_rgba, BlendMode, LayerId, LayerNode, LayerStack};
use crate::selection::SelectionMask;
use crate::tile::TileCoord;

/// Paints an anti-aliased radial brush stroke segment onto `layer` using Porter-Duff Source-Over,
/// respecting `layer.locked`, `layer.alpha_lock`, `hardness`, `opacity`, and optional `selection`.
#[allow(clippy::too_many_arguments)]
pub fn paint_stroke_segment_rgba(
    layer: &mut LayerNode,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    radius_px: f32,
    hardness: f32,
    opacity: f32,
    rgba: [u8; 4],
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked || rgba[3] == 0 || opacity <= 0.0 {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let w = tile.width;
    let h = tile.height;
    let r = radius_px.clamp(0.5, 256.0);
    let hard = hardness.clamp(0.05, 1.0);
    let op = opacity.clamp(0.0, 1.0) * (rgba[3] as f32 / 255.0);
    let dx = x1 - x0;
    let dy = y1 - y0;
    let dist = (dx * dx + dy * dy).sqrt();
    let step = (r * 0.28).clamp(0.5, 8.0);
    let steps = ((dist / step).ceil() as usize).max(1);

    let mut touched = 0usize;
    let alpha_lock = layer.alpha_lock;

    for s in 0..=steps {
        let t = if steps == 0 { 0.0 } else { s as f32 / steps as f32 };
        let cx = x0 + dx * t;
        let cy = y0 + dy * t;
        let min_x = ((cx - r - 1.0).floor().max(0.0) as u32).min(w);
        let max_x = ((cx + r + 1.0).ceil().max(0.0) as u32).min(w);
        let min_y = ((cy - r - 1.0).floor().max(0.0) as u32).min(h);
        let max_y = ((cy + r + 1.0).ceil().max(0.0) as u32).min(h);

        for py in min_y..max_y {
            let dy_p = (py as f32 + 0.5) - cy;
            for px in min_x..max_x {
                if let Some(sel) = selection {
                    if !sel.contains(px, py) {
                        continue;
                    }
                }
                let dx_p = (px as f32 + 0.5) - cx;
                let d = (dx_p * dx_p + dy_p * dy_p).sqrt();
                if d > r {
                    continue;
                }
                let norm = d / r;
                let falloff = if norm <= hard {
                    1.0
                } else {
                    let span = (1.0 - hard).max(1e-4);
                    let u = ((norm - hard) / span).clamp(0.0, 1.0);
                    // Smoothstep falloff for soft airbrush / watercolor feel
                    1.0 - (u * u * (3.0 - 2.0 * u))
                };
                let dab_a = (op * falloff * 255.0).round().clamp(0.0, 255.0) as u8;
                if dab_a == 0 {
                    continue;
                }
                let dst = tile.get_pixel(px, py);
                if alpha_lock && dst[3] == 0 {
                    continue;
                }
                let src = [rgba[0], rgba[1], rgba[2], dab_a];
                let mut blended = blend_rgba(dst, src, BlendMode::Normal);
                if alpha_lock {
                    blended[3] = dst[3];
                }
                tile.set_pixel(px, py, blended);
                touched += 1;
            }
        }
    }
    touched
}

/// Real transparent-channel Eraser (`Destination-Out`): reduces pixel alpha cleanly toward `0`.
#[allow(clippy::too_many_arguments)]
pub fn erase_stroke_segment_rgba(
    layer: &mut LayerNode,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    radius_px: f32,
    hardness: f32,
    opacity: f32,
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked || layer.alpha_lock || opacity <= 0.0 {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let w = tile.width;
    let h = tile.height;
    let r = radius_px.clamp(0.5, 256.0);
    let hard = hardness.clamp(0.05, 1.0);
    let op = opacity.clamp(0.0, 1.0);
    let dx = x1 - x0;
    let dy = y1 - y0;
    let dist = (dx * dx + dy * dy).sqrt();
    let step = (r * 0.28).clamp(0.5, 8.0);
    let steps = ((dist / step).ceil() as usize).max(1);
    let mut touched = 0usize;

    for s in 0..=steps {
        let t = if steps == 0 { 0.0 } else { s as f32 / steps as f32 };
        let cx = x0 + dx * t;
        let cy = y0 + dy * t;
        let min_x = ((cx - r - 1.0).floor().max(0.0) as u32).min(w);
        let max_x = ((cx + r + 1.0).ceil().max(0.0) as u32).min(w);
        let min_y = ((cy - r - 1.0).floor().max(0.0) as u32).min(h);
        let max_y = ((cy + r + 1.0).ceil().max(0.0) as u32).min(h);

        for py in min_y..max_y {
            let dy_p = (py as f32 + 0.5) - cy;
            for px in min_x..max_x {
                if let Some(sel) = selection {
                    if !sel.contains(px, py) {
                        continue;
                    }
                }
                let dst = tile.get_pixel(px, py);
                if dst[3] == 0 {
                    continue;
                }
                let dx_p = (px as f32 + 0.5) - cx;
                let d = (dx_p * dx_p + dy_p * dy_p).sqrt();
                if d > r {
                    continue;
                }
                let norm = d / r;
                let falloff = if norm <= hard {
                    1.0
                } else {
                    let span = (1.0 - hard).max(1e-4);
                    let u = ((norm - hard) / span).clamp(0.0, 1.0);
                    1.0 - (u * u * (3.0 - 2.0 * u))
                };
                let keep = (1.0 - op * falloff).clamp(0.0, 1.0);
                let new_a = (dst[3] as f32 * keep).round().clamp(0.0, 255.0) as u8;
                let out = if new_a == 0 {
                    [0, 0, 0, 0]
                } else {
                    [dst[0], dst[1], dst[2], new_a]
                };
                tile.set_pixel(px, py, out);
                touched += 1;
            }
        }
    }
    touched
}

/// Real Smudge brush: picks up local pixels near `(x0, y0)` and drags/blends them along `(x0, y0) -> (x1, y1)`.
#[allow(clippy::too_many_arguments)]
pub fn smudge_stroke_segment_rgba(
    layer: &mut LayerNode,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    radius_px: f32,
    strength: f32,
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked || strength <= 0.0 {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let w = tile.width;
    let h = tile.height;
    let r = radius_px.clamp(1.0, 128.0);
    let str_clamped = strength.clamp(0.05, 0.95);
    let alpha_lock = layer.alpha_lock;

    // Sample average pickup color around (x0, y0)
    let sx0 = (x0.round().clamp(0.0, (w.saturating_sub(1)) as f32)) as u32;
    let sy0 = (y0.round().clamp(0.0, (h.saturating_sub(1)) as f32)) as u32;
    let mut pickup = [0.0f32; 4];
    let mut weight_sum = 0.0f32;
    let sample_r = (r * 0.5).clamp(1.0, 8.0) as i32;
    for oy in -sample_r..=sample_r {
        for ox in -sample_r..=sample_r {
            let px = (sx0 as i32 + ox).clamp(0, w.saturating_sub(1) as i32) as u32;
            let py = (sy0 as i32 + oy).clamp(0, h.saturating_sub(1) as i32) as u32;
            let p = tile.get_pixel(px, py);
            pickup[0] += p[0] as f32;
            pickup[1] += p[1] as f32;
            pickup[2] += p[2] as f32;
            pickup[3] += p[3] as f32;
            weight_sum += 1.0;
        }
    }
    if weight_sum > 0.0 {
        for c in &mut pickup {
            *c /= weight_sum;
        }
    }

    let dx = x1 - x0;
    let dy = y1 - y0;
    let dist = (dx * dx + dy * dy).sqrt();
    let step = (r * 0.35).clamp(1.0, 8.0);
    let steps = ((dist / step).ceil() as usize).max(1);
    let mut touched = 0usize;

    for s in 1..=steps {
        let t = s as f32 / steps as f32;
        let cx = x0 + dx * t;
        let cy = y0 + dy * t;
        let min_x = ((cx - r).floor().max(0.0) as u32).min(w);
        let max_x = ((cx + r).ceil().max(0.0) as u32).min(w);
        let min_y = ((cy - r).floor().max(0.0) as u32).min(h);
        let max_y = ((cy + r).ceil().max(0.0) as u32).min(h);

        let mut next_pickup = pickup;
        for py in min_y..max_y {
            let dy_p = (py as f32 + 0.5) - cy;
            for px in min_x..max_x {
                if let Some(sel) = selection {
                    if !sel.contains(px, py) {
                        continue;
                    }
                }
                let dx_p = (px as f32 + 0.5) - cx;
                let d = (dx_p * dx_p + dy_p * dy_p).sqrt();
                if d > r {
                    continue;
                }
                let falloff = (1.0 - d / r).clamp(0.0, 1.0);
                let mix = str_clamped * falloff;
                let dst = tile.get_pixel(px, py);
                if alpha_lock && dst[3] == 0 {
                    continue;
                }
                let out_r = (dst[0] as f32 * (1.0 - mix) + pickup[0] * mix).round().clamp(0.0, 255.0) as u8;
                let out_g = (dst[1] as f32 * (1.0 - mix) + pickup[1] * mix).round().clamp(0.0, 255.0) as u8;
                let out_b = (dst[2] as f32 * (1.0 - mix) + pickup[2] * mix).round().clamp(0.0, 255.0) as u8;
                let out_a = if alpha_lock {
                    dst[3]
                } else {
                    (dst[3] as f32 * (1.0 - mix) + pickup[3] * mix).round().clamp(0.0, 255.0) as u8
                };
                tile.set_pixel(px, py, [out_r, out_g, out_b, out_a]);
                if d <= 1.5 {
                    next_pickup = [
                        pickup[0] * 0.8 + dst[0] as f32 * 0.2,
                        pickup[1] * 0.8 + dst[1] as f32 * 0.2,
                        pickup[2] * 0.8 + dst[2] as f32 * 0.2,
                        pickup[3] * 0.8 + dst[3] as f32 * 0.2,
                    ];
                }
                touched += 1;
            }
        }
        pickup = next_pickup;
    }
    touched
}

/// Real local Blur brush: applies a smooth 3×3 neighborhood softening kernel inside brush footprint.
#[allow(clippy::too_many_arguments)]
pub fn blur_stroke_segment_rgba(
    layer: &mut LayerNode,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    radius_px: f32,
    strength: f32,
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked || strength <= 0.0 {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let w = tile.width;
    let h = tile.height;
    let r = radius_px.clamp(1.0, 96.0);
    let mix_base = strength.clamp(0.1, 1.0);
    let alpha_lock = layer.alpha_lock;

    let min_x = ((x0.min(x1) - r - 1.0).floor().max(0.0) as u32).min(w);
    let max_x = ((x0.max(x1) + r + 1.0).ceil().max(0.0) as u32).min(w);
    let min_y = ((y0.min(y1) - r - 1.0).floor().max(0.0) as u32).min(h);
    let max_y = ((y0.max(y1) + r + 1.0).ceil().max(0.0) as u32).min(h);
    if min_x >= max_x || min_y >= max_y {
        return 0;
    }

    let rw = (max_x - min_x) as usize;
    let rh = (max_y - min_y) as usize;
    let mut snapshot = vec![[0u8; 4]; rw * rh];
    for y in min_y..max_y {
        let row = (y - min_y) as usize * rw;
        for x in min_x..max_x {
            snapshot[row + (x - min_x) as usize] = tile.get_pixel(x, y);
        }
    }

    let seg_dx = x1 - x0;
    let seg_dy = y1 - y0;
    let seg_len_sq = seg_dx * seg_dx + seg_dy * seg_dy;
    let mut touched = 0usize;

    for y in min_y..max_y {
        for x in min_x..max_x {
            if let Some(sel) = selection {
                if !sel.contains(x, y) {
                    continue;
                }
            }
            let px = x as f32 + 0.5;
            let py = y as f32 + 0.5;
            let proj = if seg_len_sq <= 1e-4 {
                0.0
            } else {
                (((px - x0) * seg_dx + (py - y0) * seg_dy) / seg_len_sq).clamp(0.0, 1.0)
            };
            let cx = x0 + seg_dx * proj;
            let cy = y0 + seg_dy * proj;
            let d = ((px - cx).powi(2) + (py - cy).powi(2)).sqrt();
            if d > r {
                continue;
            }
            let falloff = (1.0 - d / r).clamp(0.0, 1.0);
            let mix = mix_base * falloff;

            let mut acc = [0.0f32; 4];
            let mut wsum = 0.0f32;
            for oy in -1i32..=1 {
                for ox in -1i32..=1 {
                    let nx = (x as i32 + ox).clamp(min_x as i32, (max_x - 1) as i32) as u32;
                    let ny = (y as i32 + oy).clamp(min_y as i32, (max_y - 1) as i32) as u32;
                    let k = if ox == 0 && oy == 0 {
                        4.0
                    } else if ox == 0 || oy == 0 {
                        2.0
                    } else {
                        1.0
                    };
                    let p = snapshot[(ny - min_y) as usize * rw + (nx - min_x) as usize];
                    acc[0] += p[0] as f32 * k;
                    acc[1] += p[1] as f32 * k;
                    acc[2] += p[2] as f32 * k;
                    acc[3] += p[3] as f32 * k;
                    wsum += k;
                }
            }
            let dst = snapshot[(y - min_y) as usize * rw + (x - min_x) as usize];
            if alpha_lock && dst[3] == 0 {
                continue;
            }
            let blur_px = [
                (dst[0] as f32 * (1.0 - mix) + (acc[0] / wsum) * mix).round().clamp(0.0, 255.0) as u8,
                (dst[1] as f32 * (1.0 - mix) + (acc[1] / wsum) * mix).round().clamp(0.0, 255.0) as u8,
                (dst[2] as f32 * (1.0 - mix) + (acc[2] / wsum) * mix).round().clamp(0.0, 255.0) as u8,
                if alpha_lock {
                    dst[3]
                } else {
                    (dst[3] as f32 * (1.0 - mix) + (acc[3] / wsum) * mix).round().clamp(0.0, 255.0) as u8
                },
            ];
            tile.set_pixel(x, y, blur_px);
            touched += 1;
        }
    }
    touched
}

/// Runs `close_gap_expand_fill` and, if a `SelectionMask` is active, clips the written fill strictly
/// inside the selected region.
pub fn close_gap_fill_with_selection(
    stack: &mut LayerStack,
    target_layer_id: LayerId,
    seed_x: u32,
    seed_y: u32,
    fill_rgba: [u8; 4],
    options: FillOptions,
    selection: Option<&SelectionMask>,
) -> FillResult {
    let Some(sel) = selection else {
        return close_gap_expand_fill(stack, target_layer_id, seed_x, seed_y, fill_rgba, options);
    };
    if !sel.contains(seed_x, seed_y) {
        return FillResult {
            filled_pixels: 0,
            dirty_tiles: Vec::new(),
        };
    }
    // Snapshot target layer before fill, run close-gap fill, then restore pixels outside selection.
    let before = stack.get(target_layer_id).and_then(|l| l.raster.clone());
    let res = close_gap_expand_fill(stack, target_layer_id, seed_x, seed_y, fill_rgba, options);
    if let (Some(prev), Some(layer)) = (before, stack.get_mut(target_layer_id)) {
        if let Some(curr) = layer.raster.as_mut() {
            let tile_sz = crate::tile::TILE_SIZE as u32;
            let coords: Vec<TileCoord> = curr.sorted_tiles().into_iter().map(|(c, _)| c).collect();
            for coord in coords {
                let bx = (coord.tx as i64 * tile_sz as i64).max(0) as u32;
                let by = (coord.ty as i64 * tile_sz as i64).max(0) as u32;
                let ex = (bx + tile_sz).min(curr.width);
                let ey = (by + tile_sz).min(curr.height);
                for y in by..ey {
                    for x in bx..ex {
                        if !sel.contains(x, y) {
                            curr.set_pixel(x, y, prev.get_pixel(x, y));
                        }
                    }
                }
            }
        }
    }
    res
}

/// Fast tile-aware full-stack RGBA8 compositor for live GPU/CGImage viewport & PNG export.
/// `backdrop_code`: `0 = white paper`, `1 = transparent light checker`, `2 = transparent dark checker`,
/// `3 = pure transparent RGBA (for lossless PNG export)`.
pub fn composite_stack_rgba(
    stack: &LayerStack,
    backdrop_code: u32,
    out_rgba: &mut [u8],
) -> usize {
    let w = stack.width as usize;
    let h = stack.height as usize;
    let needed = w.saturating_mul(h).saturating_mul(4);
    if out_rgba.len() < needed || w == 0 || h == 0 {
        return 0;
    }

    // 1. Fill backdrop quickly in one pass
    match backdrop_code {
        0 => {
            // Solid white paper
            out_rgba[..needed].fill(255);
        }
        1 | 2 => {
            let (c0, c1) = if backdrop_code == 1 {
                ([242u8, 242, 242, 255], [216u8, 216, 216, 255])
            } else {
                ([52u8, 54, 62, 255], [38u8, 40, 46, 255])
            };
            for y in 0..h {
                let cy = (y >> 4) & 1;
                let row = y * w * 4;
                for x in 0..w {
                    let c = if ((x >> 4) & 1) ^ cy == 0 { c0 } else { c1 };
                    let off = row + x * 4;
                    out_rgba[off..off + 4].copy_from_slice(&c);
                }
            }
        }
        _ => {
            // Pure transparent RGBA8
            out_rgba[..needed].fill(0);
        }
    }

    // 2. Collect union of allocated TileCoords across all visible layers (O(allocated_tiles)!)
    let mut dirty_tiles = std::collections::BTreeSet::new();
    for layer in stack.layers() {
        if !layer.visible || layer.opacity <= 0.0 {
            continue;
        }
        if let Some(r) = layer.raster.as_ref() {
            for (coord, _) in r.sorted_tiles() {
                dirty_tiles.insert((coord.ty, coord.tx));
            }
        }
    }

    // 3. Composite ONLY pixels inside allocated tiles over the backdrop!
    let tile_sz = crate::tile::TILE_SIZE;
    for (ty, tx) in dirty_tiles {
        let bx = (tx as isize * tile_sz as isize).max(0) as usize;
        let by = (ty as isize * tile_sz as isize).max(0) as usize;
        let ex = (bx + tile_sz).min(w);
        let ey = (by + tile_sz).min(h);
        for y in by..ey {
            let row = y * w * 4;
            for x in bx..ex {
                let top = stack.composite_pixel(x as u32, y as u32);
                if top[3] == 0 {
                    continue;
                }
                let off = row + x * 4;
                if backdrop_code == 3 || top[3] == 255 {
                    out_rgba[off..off + 4].copy_from_slice(&top);
                } else {
                    let bg = [
                        out_rgba[off],
                        out_rgba[off + 1],
                        out_rgba[off + 2],
                        out_rgba[off + 3],
                    ];
                    let merged = blend_rgba(bg, top, BlendMode::Normal);
                    out_rgba[off..off + 4].copy_from_slice(&merged);
                }
            }
        }
    }
    needed
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn raster_paint_erase_smudge_blur_and_composite_work() {
        let mut stack = LayerStack::new(128, 128);
        let l1 = stack.add_raster_layer("Ink");

        // Paint coral red stroke across (20, 64) -> (100, 64)
        let painted = paint_stroke_segment_rgba(
            stack.get_mut(l1).unwrap(),
            20.0,
            64.0,
            100.0,
            64.0,
            8.0,
            0.9,
            1.0,
            [255, 80, 60, 255],
            None,
        );
        assert!(painted > 400);
        let mid = stack.composite_pixel(60, 64);
        assert_eq!(mid, [255, 80, 60, 255]);

        // Transparent Eraser clears alpha to 0 cleanly at (60, 64)
        let erased = erase_stroke_segment_rgba(
            stack.get_mut(l1).unwrap(),
            60.0,
            64.0,
            60.0,
            64.0,
            6.0,
            0.95,
            1.0,
            None,
        );
        assert!(erased > 50);
        assert_eq!(stack.composite_pixel(60, 64), [0, 0, 0, 0]);

        // Smudge drags coral ink from (30, 64) downward into empty space (30, 80)
        let smudged = smudge_stroke_segment_rgba(
            stack.get_mut(l1).unwrap(),
            30.0,
            64.0,
            30.0,
            78.0,
            6.0,
            0.8,
            None,
        );
        assert!(smudged > 50);
        assert!(stack.composite_pixel(30, 74)[3] > 0);

        // Blur softens boundary cleanly
        let blurred = blur_stroke_segment_rgba(
            stack.get_mut(l1).unwrap(),
            90.0,
            64.0,
            95.0,
            64.0,
            8.0,
            0.8,
            None,
        );
        assert!(blurred > 50);

        // Composite full buffer over white backdrop
        let mut rgba = vec![0u8; 128 * 128 * 4];
        let written = composite_stack_rgba(&stack, 0, &mut rgba);
        assert_eq!(written, 128 * 128 * 4);
        // Corner (0,0) is white paper, erased (60,64) reveals white paper, stroke (85,64) is coral
        assert_eq!(&rgba[0..4], &[255, 255, 255, 255]);
        let off_erased = (64 * 128 + 60) * 4;
        assert_eq!(&rgba[off_erased..off_erased + 4], &[255, 255, 255, 255]);
        let off_ink = (64 * 128 + 85) * 4;
        assert!(rgba[off_ink] > 200 && rgba[off_ink + 2] < 100);
    }

    #[test]
    fn selection_mask_and_magic_wand_restrict_painting() {
        let mut stack = LayerStack::new(64, 64);
        let l1 = stack.add_raster_layer("Line");
        let sel = SelectionMask::from_rect(64, 64, 10, 10, 30, 30);

        paint_stroke_segment_rgba(
            stack.get_mut(l1).unwrap(),
            0.0,
            20.0,
            60.0,
            20.0,
            5.0,
            1.0,
            1.0,
            [30, 140, 255, 255],
            Some(&sel),
        );
        // Inside selection painted, outside strictly untouched!
        assert_eq!(stack.composite_pixel(20, 20), [30, 140, 255, 255]);
        assert_eq!(stack.composite_pixel(5, 20), [0, 0, 0, 0]);
        assert_eq!(stack.composite_pixel(45, 20), [0, 0, 0, 0]);

        // Magic wand clicks blue stripe and selects ONLY connected blue pixels
        let wand = SelectionMask::from_magic_wand(&stack, 20, 20, 10, false);
        assert!(wand.contains(20, 20));
        assert!(!wand.contains(5, 5));
        assert!(wand.selected_pixel_count() > 50 && wand.selected_pixel_count() < 400);
    }
}
