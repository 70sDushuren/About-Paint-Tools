//! `S2 v1.0.0-rc4` (Phase 3) — 6 Pulled-Forward ibisPaint Daily FX Filters,
//! Bilinear Affine Layer Transform, Procedural Screentone Fill & Panel Border Rasterizer.

use crate::layer::{blend_rgba, BlendMode, LayerNode};
use crate::panel::PanelLayout;
use crate::raster_ops::paint_stroke_segment_rgba;
use crate::screentone::ScreentoneSpec;
use crate::selection::SelectionMask;
use crate::tile::{TileLayer, TILE_SIZE};

/// Computes bounding box `(min_x, min_y, max_x, max_y)` of allocated tiles expanded by `pad` pixels.
fn allocated_bounds(tile: &TileLayer, pad: u32) -> Option<(u32, u32, u32, u32)> {
    let tiles = tile.sorted_tiles();
    if tiles.is_empty() {
        return None;
    }
    let tsz = TILE_SIZE as u32;
    let mut min_x = u32::MAX;
    let mut min_y = u32::MAX;
    let mut max_x = 0u32;
    let mut max_y = 0u32;
    for (coord, _) in tiles {
        let bx = (coord.tx as i64 * tsz as i64).max(0) as u32;
        let by = (coord.ty as i64 * tsz as i64).max(0) as u32;
        let ex = (bx + tsz).min(tile.width);
        let ey = (by + tsz).min(tile.height);
        min_x = min_x.min(bx);
        min_y = min_y.min(by);
        max_x = max_x.max(ex);
        max_y = max_y.max(ey);
    }
    Some((
        min_x.saturating_sub(pad),
        min_y.saturating_sub(pad),
        (max_x + pad).min(tile.width),
        (max_y + pad).min(tile.height),
    ))
}

fn gaussian_kernel_1d(radius_px: f32) -> (i32, Vec<f32>) {
    let r = (radius_px.clamp(0.5, 24.0).ceil() as i32).max(1);
    let sigma = (radius_px.max(0.5) * 0.5).max(0.4);
    let two_sq = 2.0 * sigma * sigma;
    let mut k = Vec::with_capacity((2 * r + 1) as usize);
    let mut sum = 0.0f32;
    for i in -r..=r {
        let w = (-((i * i) as f32) / two_sq).exp();
        k.push(w);
        sum += w;
    }
    for v in &mut k {
        *v /= sum;
    }
    (r, k)
}

/// Filter 1: Separable premultiplied-alpha Gaussian Blur (`radius_px` in `0.5..=24.0`).
pub fn filter_gaussian_blur(
    layer: &mut LayerNode,
    radius_px: f32,
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked || radius_px <= 0.1 {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let (r, kernel) = gaussian_kernel_1d(radius_px);
    let Some((bx0, by0, bx1, by1)) = allocated_bounds(tile, r as u32) else {
        return 0;
    };
    let rw = (bx1 - bx0) as usize;
    let rh = (by1 - by0) as usize;
    if rw == 0 || rh == 0 {
        return 0;
    }

    // Premultiplied RGBA float buffer
    let mut src = vec![[0.0f32; 4]; rw * rh];
    for y in by0..by1 {
        let row = (y - by0) as usize * rw;
        for x in bx0..bx1 {
            let p = tile.get_pixel(x, y);
            let a = p[3] as f32 / 255.0;
            src[row + (x - bx0) as usize] = [p[0] as f32 * a, p[1] as f32 * a, p[2] as f32 * a, a];
        }
    }

    // Horizontal pass
    let mut horiz = vec![[0.0f32; 4]; rw * rh];
    for y in 0..rh {
        let row = y * rw;
        for x in 0..rw {
            let mut acc = [0.0f32; 4];
            for (ki, &w) in kernel.iter().enumerate() {
                let ox = ki as i32 - r;
                let sx = (x as i32 + ox).clamp(0, rw as i32 - 1) as usize;
                let p = src[row + sx];
                acc[0] += p[0] * w;
                acc[1] += p[1] * w;
                acc[2] += p[2] * w;
                acc[3] += p[3] * w;
            }
            horiz[row + x] = acc;
        }
    }

    // Vertical pass + write back
    let mut modified = 0usize;
    for y in 0..rh {
        let py = by0 + y as u32;
        for x in 0..rw {
            let px = bx0 + x as u32;
            if let Some(sel) = selection {
                if !sel.contains(px, py) {
                    continue;
                }
            }
            let mut acc = [0.0f32; 4];
            for (ki, &w) in kernel.iter().enumerate() {
                let oy = ki as i32 - r;
                let sy = (y as i32 + oy).clamp(0, rh as i32 - 1) as usize;
                let p = horiz[sy * rw + x];
                acc[0] += p[0] * w;
                acc[1] += p[1] * w;
                acc[2] += p[2] * w;
                acc[3] += p[3] * w;
            }
            let out_a = (acc[3].clamp(0.0, 1.0) * 255.0).round() as u8;
            if out_a == 0 {
                if tile.get_pixel(px, py)[3] != 0 {
                    tile.set_pixel(px, py, [0, 0, 0, 0]);
                    modified += 1;
                }
                continue;
            }
            let inv_a = 1.0 / acc[3].max(1e-5);
            let out = [
                (acc[0] * inv_a).round().clamp(0.0, 255.0) as u8,
                (acc[1] * inv_a).round().clamp(0.0, 255.0) as u8,
                (acc[2] * inv_a).round().clamp(0.0, 255.0) as u8,
                out_a,
            ];
            tile.set_pixel(px, py, out);
            modified += 1;
        }
    }
    modified
}

fn rgb_to_hsb(r: f32, g: f32, b: f32) -> (f32, f32, f32) {
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let delta = max - min;
    let h = if delta <= 1e-6 {
        0.0
    } else if (max - r).abs() <= 1e-6 {
        60.0 * (((g - b) / delta).rem_euclid(6.0))
    } else if (max - g).abs() <= 1e-6 {
        60.0 * (((b - r) / delta) + 2.0)
    } else {
        60.0 * (((r - g) / delta) + 4.0)
    };
    let s = if max <= 1e-6 { 0.0 } else { delta / max };
    (h, s, max)
}

fn hsb_to_rgb(h: f32, s: f32, v: f32) -> (f32, f32, f32) {
    let h_norm = h.rem_euclid(360.0);
    let c = v * s;
    let x = c * (1.0 - ((h_norm / 60.0).rem_euclid(2.0) - 1.0).abs());
    let m = v - c;
    let (r1, g1, b1) = if h_norm < 60.0 {
        (c, x, 0.0)
    } else if h_norm < 120.0 {
        (x, c, 0.0)
    } else if h_norm < 180.0 {
        (0.0, c, x)
    } else if h_norm < 240.0 {
        (0.0, x, c)
    } else if h_norm < 300.0 {
        (x, 0.0, c)
    } else {
        (c, 0.0, x)
    };
    (
        (r1 + m).clamp(0.0, 1.0),
        (g1 + m).clamp(0.0, 1.0),
        (b1 + m).clamp(0.0, 1.0),
    )
}

/// Filter 2: Hue / Saturation / Brightness adjustment (`hue_deg: -180..180`, `sat_delta: -1..1`, `bright_delta: -1..1`).
pub fn filter_hsb_adjust(
    layer: &mut LayerNode,
    hue_deg: f32,
    sat_delta: f32,
    bright_delta: f32,
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let Some((bx0, by0, bx1, by1)) = allocated_bounds(tile, 0) else {
        return 0;
    };
    let mut modified = 0usize;
    for y in by0..by1 {
        for x in bx0..bx1 {
            if let Some(sel) = selection {
                if !sel.contains(x, y) {
                    continue;
                }
            }
            let p = tile.get_pixel(x, y);
            if p[3] == 0 {
                continue;
            }
            let (h, s, v) = rgb_to_hsb(p[0] as f32 / 255.0, p[1] as f32 / 255.0, p[2] as f32 / 255.0);
            let (nr, ng, nb) = hsb_to_rgb(
                h + hue_deg,
                (s + sat_delta).clamp(0.0, 1.0),
                (v + bright_delta).clamp(0.0, 1.0),
            );
            tile.set_pixel(
                x,
                y,
                [
                    (nr * 255.0).round() as u8,
                    (ng * 255.0).round() as u8,
                    (nb * 255.0).round() as u8,
                    p[3],
                ],
            );
            modified += 1;
        }
    }
    modified
}

/// Filter 3: Brightness & Contrast (`brightness: -1..1`, `contrast: -1..1`).
pub fn filter_brightness_contrast(
    layer: &mut LayerNode,
    brightness: f32,
    contrast: f32,
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let Some((bx0, by0, bx1, by1)) = allocated_bounds(tile, 0) else {
        return 0;
    };
    let b = brightness.clamp(-1.0, 1.0);
    let c = contrast.clamp(-1.0, 1.0);
    let factor = (1.0 + c) / (1.0001 - c * 0.95);
    let mut modified = 0usize;
    for y in by0..by1 {
        for x in bx0..bx1 {
            if let Some(sel) = selection {
                if !sel.contains(x, y) {
                    continue;
                }
            }
            let p = tile.get_pixel(x, y);
            if p[3] == 0 {
                continue;
            }
            let adj = |v: u8| -> u8 {
                let norm = v as f32 / 255.0 + b;
                let out = ((norm - 0.5) * factor + 0.5).clamp(0.0, 1.0);
                (out * 255.0).round() as u8
            };
            tile.set_pixel(x, y, [adj(p[0]), adj(p[1]), adj(p[2]), p[3]]);
            modified += 1;
        }
    }
    modified
}

/// Filter 4: ibisPaint signature **Extract Line Drawing** — turns light/white paper background
/// completely transparent while extracting crisp black anti-aliased manga ink!
/// `black_threshold` (default `0.25`) and `white_threshold` (default `0.80`) in `[0.0, 1.0]`.
pub fn filter_extract_line_drawing(
    layer: &mut LayerNode,
    black_threshold: f32,
    white_threshold: f32,
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let Some((bx0, by0, bx1, by1)) = allocated_bounds(tile, 0) else {
        return 0;
    };
    let blk = black_threshold.clamp(0.0, 0.95);
    let wht = white_threshold.clamp(blk + 0.02, 1.0);
    let span = (wht - blk).max(0.02);
    let mut modified = 0usize;

    for y in by0..by1 {
        for x in bx0..bx1 {
            if let Some(sel) = selection {
                if !sel.contains(x, y) {
                    continue;
                }
            }
            let p = tile.get_pixel(x, y);
            if p[3] == 0 {
                continue;
            }
            let lum = (0.299 * p[0] as f32 + 0.587 * p[1] as f32 + 0.114 * p[2] as f32) / 255.0;
            let ink_strength = ((wht - lum) / span).clamp(0.0, 1.0);
            let out_a = ((ink_strength * (p[3] as f32 / 255.0)) * 255.0).round().clamp(0.0, 255.0) as u8;
            if out_a == 0 {
                tile.set_pixel(x, y, [0, 0, 0, 0]);
            } else {
                tile.set_pixel(x, y, [0, 0, 0, out_a]);
            }
            modified += 1;
        }
    }
    modified
}

/// Filter 5: **Stroke (Outer)** — draws a crisp colored outline around opaque layer content (`width_px` in `1..=24`).
pub fn filter_outer_stroke(
    layer: &mut LayerNode,
    width_px: u32,
    rgba: [u8; 4],
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked || width_px == 0 || rgba[3] == 0 {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let r = width_px.clamp(1, 24);
    let Some((bx0, by0, bx1, by1)) = allocated_bounds(tile, r) else {
        return 0;
    };
    let rw = (bx1 - bx0) as usize;
    let rh = (by1 - by0) as usize;
    let mut orig = vec![[0u8; 4]; rw * rh];
    for y in by0..by1 {
        let row = (y - by0) as usize * rw;
        for x in bx0..bx1 {
            orig[row + (x - bx0) as usize] = tile.get_pixel(x, y);
        }
    }

    let r_i = r as i32;
    let r_sq = r_i * r_i;
    let mut modified = 0usize;

    for y in 0..rh {
        let py = by0 + y as u32;
        for x in 0..rw {
            let px = bx0 + x as u32;
            if let Some(sel) = selection {
                if !sel.contains(px, py) {
                    continue;
                }
            }
            let center = orig[y * rw + x];
            if center[3] == 255 {
                continue;
            }
            let mut max_neighbor_a = 0u8;
            'search: for oy in -r_i..=r_i {
                let ny = y as i32 + oy;
                if ny < 0 || ny >= rh as i32 {
                    continue;
                }
                for ox in -r_i..=r_i {
                    if ox * ox + oy * oy > r_sq {
                        continue;
                    }
                    let nx = x as i32 + ox;
                    if nx < 0 || nx >= rw as i32 {
                        continue;
                    }
                    let na = orig[ny as usize * rw + nx as usize][3];
                    if na > max_neighbor_a {
                        max_neighbor_a = na;
                        if max_neighbor_a == 255 {
                            break 'search;
                        }
                    }
                }
            }
            if max_neighbor_a > 0 {
                let stroke_a = ((max_neighbor_a as f32 / 255.0) * (rgba[3] as f32)).round() as u8;
                let bg = [rgba[0], rgba[1], rgba[2], stroke_a];
                let out = blend_rgba(bg, center, BlendMode::Normal);
                tile.set_pixel(px, py, out);
                modified += 1;
            }
        }
    }
    modified
}

/// Filter 6: **Drop Shadow** — creates an offset Gaussian-blurred shadow silhouette composited behind layer pixels.
pub fn filter_drop_shadow(
    layer: &mut LayerNode,
    dx: i32,
    dy: i32,
    blur_px: f32,
    rgba: [u8; 4],
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked || rgba[3] == 0 {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let blur_r = (blur_px.clamp(0.0, 20.0).ceil() as u32).max(1);
    let pad = blur_r + dx.unsigned_abs().max(dy.unsigned_abs());
    let Some((bx0, by0, bx1, by1)) = allocated_bounds(tile, pad) else {
        return 0;
    };
    let rw = (bx1 - bx0) as usize;
    let rh = (by1 - by0) as usize;
    if rw == 0 || rh == 0 {
        return 0;
    }

    let mut orig = vec![[0u8; 4]; rw * rh];
    let mut shadow_a = vec![0.0f32; rw * rh];
    for y in by0..by1 {
        let row = (y - by0) as usize * rw;
        for x in bx0..bx1 {
            orig[row + (x - bx0) as usize] = tile.get_pixel(x, y);
        }
    }
    for y in 0..rh {
        let sy = y as i32 - dy;
        if sy < 0 || sy >= rh as i32 {
            continue;
        }
        for x in 0..rw {
            let sx = x as i32 - dx;
            if sx < 0 || sx >= rw as i32 {
                continue;
            }
            shadow_a[y * rw + x] = orig[sy as usize * rw + sx as usize][3] as f32 / 255.0;
        }
    }

    if blur_px > 0.2 {
        let (r, kernel) = gaussian_kernel_1d(blur_px);
        let mut h_buf = vec![0.0f32; rw * rh];
        for y in 0..rh {
            let row = y * rw;
            for x in 0..rw {
                let mut acc = 0.0f32;
                for (ki, &w) in kernel.iter().enumerate() {
                    let sx = (x as i32 + ki as i32 - r).clamp(0, rw as i32 - 1) as usize;
                    acc += shadow_a[row + sx] * w;
                }
                h_buf[row + x] = acc;
            }
        }
        for y in 0..rh {
            for x in 0..rw {
                let mut acc = 0.0f32;
                for (ki, &w) in kernel.iter().enumerate() {
                    let sy = (y as i32 + ki as i32 - r).clamp(0, rh as i32 - 1) as usize;
                    acc += h_buf[sy * rw + x] * w;
                }
                shadow_a[y * rw + x] = acc;
            }
        }
    }

    let mut modified = 0usize;
    let tint_a = rgba[3] as f32;
    for y in 0..rh {
        let py = by0 + y as u32;
        for x in 0..rw {
            let px = bx0 + x as u32;
            if let Some(sel) = selection {
                if !sel.contains(px, py) {
                    continue;
                }
            }
            let sa = (shadow_a[y * rw + x].clamp(0.0, 1.0) * tint_a).round() as u8;
            if sa == 0 {
                continue;
            }
            let sh = [rgba[0], rgba[1], rgba[2], sa];
            let fg = orig[y * rw + x];
            let out = blend_rgba(sh, fg, BlendMode::Normal);
            tile.set_pixel(px, py, out);
            modified += 1;
        }
    }
    modified
}

/// Interactive Bilinear Affine Transform (`dx`, `dy`, `scale_x`, `scale_y`, `rot_deg`)
/// rotating & scaling around the layer's visual center cleanly.
pub fn transform_layer_affine(
    layer: &mut LayerNode,
    dx: f32,
    dy: f32,
    scale_x: f32,
    scale_y: f32,
    rot_deg: f32,
) -> usize {
    if layer.locked {
        return 0;
    }
    let Some(old) = layer.raster.as_ref() else {
        return 0;
    };
    let w = old.width;
    let h = old.height;
    let Some((bx0, by0, bx1, by1)) = allocated_bounds(old, 0) else {
        return 0;
    };
    let sx = scale_x.clamp(0.1, 8.0);
    let sy = scale_y.clamp(0.1, 8.0);
    let cx = (bx0 + bx1) as f32 * 0.5;
    let cy = (by0 + by1) as f32 * 0.5;
    let rad = (-rot_deg).to_radians();
    let (sin_r, cos_r) = rad.sin_cos();

    let mut next = TileLayer::new(w, h);
    let mut written = 0usize;

    // Sample across full canvas bounds around transformed region
    let half_w = ((bx1 - bx0) as f32 * 0.5 * sx.max(sy) * 1.5).ceil() as i32 + 4;
    let half_h = ((by1 - by0) as f32 * 0.5 * sx.max(sy) * 1.5).ceil() as i32 + 4;
    let ncx = (cx + dx).round() as i32;
    let ncy = (cy + dy).round() as i32;
    let min_x = (ncx - half_w).clamp(0, w as i32) as u32;
    let max_x = (ncx + half_w).clamp(0, w as i32) as u32;
    let min_y = (ncy - half_h).clamp(0, h as i32) as u32;
    let max_y = (ncy + half_h).clamp(0, h as i32) as u32;

    for y in min_y..max_y {
        let ty = y as f32 - (cy + dy);
        for x in min_x..max_x {
            let tx = x as f32 - (cx + dx);
            let rx = (tx * cos_r - ty * sin_r) / sx + cx;
            let ry = (tx * sin_r + ty * cos_r) / sy + cy;
            if rx < 0.0 || ry < 0.0 || rx >= (w as f32 - 1.0) || ry >= (h as f32 - 1.0) {
                continue;
            }
            let x0 = rx.floor() as u32;
            let y0 = ry.floor() as u32;
            let fx = rx - x0 as f32;
            let fy = ry - y0 as f32;
            let p00 = old.get_pixel(x0, y0);
            let p10 = old.get_pixel(x0 + 1, y0);
            let p01 = old.get_pixel(x0, y0 + 1);
            let p11 = old.get_pixel(x0 + 1, y0 + 1);
            if p00[3] == 0 && p10[3] == 0 && p01[3] == 0 && p11[3] == 0 {
                continue;
            }
            let bilerp = |c: usize| -> u8 {
                let top = p00[c] as f32 * (1.0 - fx) + p10[c] as f32 * fx;
                let bot = p01[c] as f32 * (1.0 - fx) + p11[c] as f32 * fx;
                (top * (1.0 - fy) + bot * fy).round().clamp(0.0, 255.0) as u8
            };
            let out = [bilerp(0), bilerp(1), bilerp(2), bilerp(3)];
            if out[3] > 0 {
                next.set_pixel(x, y, out);
                written += 1;
            }
        }
    }
    layer.raster = Some(next);
    written
}

/// Independent Floating Selection Pixel Transform (`dx`, `dy`, `scale_x`, `scale_y`, `rot_deg`).
///
/// Extracts ONLY pixels inside `selection` from `layer`, optionally clears their original
/// footprint (`clear_source == true`, or keeps it when `false` for Copy-Stamp), resamples
/// them bilinearly onto `layer` while leaving unselected pixels untouched, and updates
/// `selection` in place so follow-up transforms/fills stay aligned with the moved pixels.
#[allow(clippy::too_many_arguments)]
pub fn transform_selected_pixels_affine(
    layer: &mut LayerNode,
    selection: &mut SelectionMask,
    dx: f32,
    dy: f32,
    scale_x: f32,
    scale_y: f32,
    rot_deg: f32,
    clear_source: bool,
) -> usize {
    if layer.locked {
        return 0;
    }
    let Some((bx0, by0, bx1, by1)) = selection.bounds() else {
        return 0;
    };
    let Some(raster) = layer.raster.as_mut() else {
        return 0;
    };
    let w = raster.width;
    let h = raster.height;
    if w == 0 || h == 0 || bx1 <= bx0 || by1 <= by0 {
        return 0;
    }

    // 1. Extract ONLY selected pixels into a floating buffer and optionally clear their source footprint.
    let mut floating = TileLayer::new(w, h);
    let mut extracted = 0usize;
    for y in by0..by1.min(h) {
        for x in bx0..bx1.min(w) {
            if !selection.contains(x, y) {
                continue;
            }
            let px = raster.get_pixel(x, y);
            if px[3] > 0 {
                floating.set_pixel(x, y, px);
                extracted += 1;
            }
            if clear_source {
                raster.set_pixel(x, y, [0, 0, 0, 0]);
            }
        }
    }

    let sx = scale_x.clamp(0.1, 8.0);
    let sy = scale_y.clamp(0.1, 8.0);
    let cx = (bx0 + bx1) as f32 * 0.5;
    let cy = (by0 + by1) as f32 * 0.5;
    let rad = (-rot_deg).to_radians();
    let (sin_r, cos_r) = rad.sin_cos();

    let half_w = ((bx1 - bx0) as f32 * 0.5 * sx.max(sy) * 1.55).ceil() as i32 + 4;
    let half_h = ((by1 - by0) as f32 * 0.5 * sx.max(sy) * 1.55).ceil() as i32 + 4;
    let ncx = (cx + dx).round() as i32;
    let ncy = (cy + dy).round() as i32;
    let min_x = (ncx - half_w).clamp(0, w as i32) as u32;
    let max_x = (ncx + half_w).clamp(0, w as i32) as u32;
    let min_y = (ncy - half_h).clamp(0, h as i32) as u32;
    let max_y = (ncy + half_h).clamp(0, h as i32) as u32;

    // 2. Bilinearly composite floating pixels back onto `raster` and transform the selection mask itself.
    let mut next_sel = SelectionMask::empty(w, h);
    let mut written = 0usize;

    for y in min_y..max_y {
        let ty = y as f32 - (cy + dy);
        for x in min_x..max_x {
            let tx = x as f32 - (cx + dx);
            let rx = (tx * cos_r - ty * sin_r) / sx + cx;
            let ry = (tx * sin_r + ty * cos_r) / sy + cy;
            if rx < 0.0 || ry < 0.0 || rx >= w as f32 || ry >= h as f32 {
                continue;
            }
            let sx_nn = rx.round().clamp(0.0, (w - 1) as f32) as u32;
            let sy_nn = ry.round().clamp(0.0, (h - 1) as f32) as u32;
            if selection.contains(sx_nn, sy_nn) {
                next_sel.set(x, y, true);
            }
            if extracted == 0 {
                continue;
            }
            let x0 = (rx.floor() as u32).min(w - 1);
            let y0 = (ry.floor() as u32).min(h - 1);
            let x1 = (x0 + 1).min(w - 1);
            let y1 = (y0 + 1).min(h - 1);
            let fx = rx - x0 as f32;
            let fy = ry - y0 as f32;
            let p00 = floating.get_pixel(x0, y0);
            let p10 = floating.get_pixel(x1, y0);
            let p01 = floating.get_pixel(x0, y1);
            let p11 = floating.get_pixel(x1, y1);
            if p00[3] == 0 && p10[3] == 0 && p01[3] == 0 && p11[3] == 0 {
                continue;
            }
            let bilerp = |c: usize| -> u8 {
                let top = p00[c] as f32 * (1.0 - fx) + p10[c] as f32 * fx;
                let bot = p01[c] as f32 * (1.0 - fx) + p11[c] as f32 * fx;
                (top * (1.0 - fy) + bot * fy).round().clamp(0.0, 255.0) as u8
            };
            let src = [bilerp(0), bilerp(1), bilerp(2), bilerp(3)];
            if src[3] > 0 {
                let dst = raster.get_pixel(x, y);
                let out = crate::layer::blend_rgba(dst, src, crate::layer::BlendMode::Normal);
                raster.set_pixel(x, y, out);
                written += 1;
            }
        }
    }

    *selection = next_sel;
    written
}

/// Bilinearly blits an imported RGBA8 image buffer (`img_w × img_h`) into `layer`
/// at destination rectangle `(dst_x, dst_y, dst_w, dst_h)` for photo/sketch import.
#[allow(clippy::too_many_arguments)]
pub fn import_rgba_to_layer(
    layer: &mut LayerNode,
    rgba: &[u8],
    img_w: u32,
    img_h: u32,
    dst_x: i32,
    dst_y: i32,
    dst_w: u32,
    dst_h: u32,
) -> usize {
    if layer.locked || img_w == 0 || img_h == 0 || dst_w == 0 || dst_h == 0 {
        return 0;
    }
    let expected = (img_w as usize).saturating_mul(img_h as usize).saturating_mul(4);
    if rgba.len() < expected {
        return 0;
    }
    let Some(raster) = layer.raster.as_mut() else {
        return 0;
    };
    let cw = raster.width as i32;
    let ch = raster.height as i32;
    let x_start = dst_x.max(0);
    let y_start = dst_y.max(0);
    let x_end = (dst_x + dst_w as i32).min(cw);
    let y_end = (dst_y + dst_h as i32).min(ch);
    if x_start >= x_end || y_start >= y_end {
        return 0;
    }

    let sample_img = |ix: u32, iy: u32| -> [u8; 4] {
        let idx = ((iy as usize) * (img_w as usize) + (ix as usize)) * 4;
        [rgba[idx], rgba[idx + 1], rgba[idx + 2], rgba[idx + 3]]
    };

    let mut written = 0usize;
    let scale_x = img_w as f32 / dst_w as f32;
    let scale_y = img_h as f32 / dst_h as f32;

    for cy in y_start..y_end {
        let sy = ((cy - dst_y) as f32 + 0.5) * scale_y - 0.5;
        let sy_clamped = sy.clamp(0.0, (img_h - 1) as f32);
        let y0 = sy_clamped.floor() as u32;
        let y1 = (y0 + 1).min(img_h - 1);
        let fy = sy_clamped - y0 as f32;
        for cx in x_start..x_end {
            let sx = ((cx - dst_x) as f32 + 0.5) * scale_x - 0.5;
            let sx_clamped = sx.clamp(0.0, (img_w - 1) as f32);
            let x0 = sx_clamped.floor() as u32;
            let x1 = (x0 + 1).min(img_w - 1);
            let fx = sx_clamped - x0 as f32;

            let p00 = sample_img(x0, y0);
            let p10 = sample_img(x1, y0);
            let p01 = sample_img(x0, y1);
            let p11 = sample_img(x1, y1);
            let bilerp = |c: usize| -> u8 {
                let top = p00[c] as f32 * (1.0 - fx) + p10[c] as f32 * fx;
                let bot = p01[c] as f32 * (1.0 - fx) + p11[c] as f32 * fx;
                (top * (1.0 - fy) + bot * fy).round().clamp(0.0, 255.0) as u8
            };
            let px = [bilerp(0), bilerp(1), bilerp(2), bilerp(3)];
            if px[3] > 0 {
                let existing = raster.get_pixel(cx as u32, cy as u32);
                let out = crate::layer::blend_rgba(existing, px, crate::layer::BlendMode::Normal);
                raster.set_pixel(cx as u32, cy as u32, out);
                written += 1;
            }
        }
    }
    written
}

/// Fills `layer` (clipped to `selection` if active) with a procedural manga halftone screentone.
pub fn apply_screentone_fill(
    layer: &mut LayerNode,
    spec: ScreentoneSpec,
    selection: Option<&SelectionMask>,
) -> usize {
    if layer.locked {
        return 0;
    }
    let Some(tile) = layer.raster.as_mut() else {
        return 0;
    };
    let (x0, y0, x1, y1) = if let Some(sel) = selection {
        match sel.bounds() {
            Some(b) => b,
            None => return 0,
        }
    } else {
        (0, 0, tile.width, tile.height)
    };
    let mut inked = 0usize;
    for y in y0..y1 {
        for x in x0..x1 {
            if let Some(sel) = selection {
                if !sel.contains(x, y) {
                    continue;
                }
            }
            if spec.sample_mask(x, y) {
                tile.set_pixel(x, y, spec.ink_rgba);
                inked += 1;
            }
        }
    }
    inked
}

/// Rasterizes all panel frame borders from `PanelLayout` onto `layer`.
pub fn rasterize_panel_borders(layer: &mut LayerNode, layout: &PanelLayout) -> usize {
    if layer.locked {
        return 0;
    }
    let mut touched = 0usize;
    for frame in layout.panels() {
        let verts = &frame.polygon.vertices;
        if verts.len() < 3 {
            continue;
        }
        let radius = (frame.border_width_px * 0.5).clamp(1.0, 12.0);
        for i in 0..verts.len() {
            let a = verts[i];
            let b = verts[(i + 1) % verts.len()];
            touched += paint_stroke_segment_rgba(
                layer,
                a.0,
                a.1,
                b.0,
                b.1,
                radius,
                1.0,
                1.0,
                frame.border_rgba,
                None,
            );
        }
    }
    touched
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::layer::LayerStack;
    use crate::screentone::TonePattern;

    #[test]
    fn all_six_ibispaint_fx_filters_and_affine_transform_work() {
        let mut stack = LayerStack::new(128, 128);
        let l1 = stack.add_raster_layer("Artwork");

        // Paint opaque red square [40..60, 40..60]
        {
            let layer = stack.get_mut(l1).unwrap();
            for y in 40..60 {
                for x in 40..60 {
                    layer.write_pixel(x, y, [240, 40, 40, 255]);
                }
            }
        }

        // 1. HSB shift hue by +120° (Red -> Green)
        assert!(filter_hsb_adjust(stack.get_mut(l1).unwrap(), 120.0, 0.0, 0.0, None) >= 400);
        let green = stack.composite_pixel(50, 50);
        assert!(green[1] > 200 && green[0] < 80);

        // 2. Brightness & Contrast
        assert!(filter_brightness_contrast(stack.get_mut(l1).unwrap(), 0.1, 0.2, None) >= 400);

        // 3. Outer Stroke adds colored border outside [40..60]
        let stroked = filter_outer_stroke(stack.get_mut(l1).unwrap(), 3, [255, 255, 0, 255], None);
        assert!(stroked > 100);
        assert_eq!(stack.composite_pixel(38, 50), [255, 255, 0, 255]);

        // 4. Drop Shadow casts shadow at (+6, +6)
        let shadowed = filter_drop_shadow(stack.get_mut(l1).unwrap(), 6, 6, 2.0, [0, 0, 0, 180], None);
        assert!(shadowed > 100);
        assert!(stack.composite_pixel(64, 64)[3] > 0);

        // 5. Gaussian Blur softens edges cleanly
        assert!(filter_gaussian_blur(stack.get_mut(l1).unwrap(), 2.0, None) > 100);

        // 6. Affine Transform shifts content (+20, 0)
        assert!(transform_layer_affine(stack.get_mut(l1).unwrap(), 20.0, 0.0, 1.0, 1.0, 0.0) > 100);
        assert!(stack.composite_pixel(70, 50)[3] > 0);

        // 7. Extract Line Drawing turns white paper transparent and preserves dark ink
        let l2 = stack.add_raster_layer("Scan");
        {
            let scan = stack.get_mut(l2).unwrap();
            scan.write_pixel(10, 10, [250, 250, 250, 255]); // white paper
            scan.write_pixel(11, 10, [15, 15, 15, 255]); // black ink
            assert_eq!(filter_extract_line_drawing(scan, 0.2, 0.85, None), 2);
            assert_eq!(scan.raster.as_ref().unwrap().get_pixel(10, 10)[3], 0);
            assert_eq!(scan.raster.as_ref().unwrap().get_pixel(11, 10), [0, 0, 0, 255]);
        }

        // 8. Procedural Screentone fill inside selection
        let l3 = stack.add_raster_layer("Tone");
        let sel = SelectionMask::from_rect(128, 128, 10, 10, 50, 50);
        let inked = apply_screentone_fill(
            stack.get_mut(l3).unwrap(),
            ScreentoneSpec {
                lpi: 60.0,
                dpi: 300.0,
                angle_deg: 45.0,
                density: 0.35,
                pattern: TonePattern::CircleDot,
                ink_rgba: [0, 0, 0, 255],
            },
            Some(&sel),
        );
        assert!(inked > 300 && inked < 1000);
    }

    #[test]
    fn floating_selection_transform_preserves_unselected_and_moves_mask() {
        let mut stack = LayerStack::new(128, 128);
        let l1 = stack.add_raster_layer("Character");
        {
            let layer = stack.get_mut(l1).unwrap();
            // Paint red square at [10..30, 10..30] (will be selected & moved)
            for y in 10..30 {
                for x in 10..30 {
                    layer.write_pixel(x, y, [220, 30, 30, 255]);
                }
            }
            // Paint blue anchor square at [90..110, 90..110] (unselected — must stay untouched!)
            for y in 90..110 {
                for x in 90..110 {
                    layer.write_pixel(x, y, [20, 80, 240, 255]);
                }
            }
        }

        let mut sel = SelectionMask::from_rect(128, 128, 10, 10, 30, 30);
        // Cut-move selection by (+30, +20)
        let moved = transform_selected_pixels_affine(
            stack.get_mut(l1).unwrap(),
            &mut sel,
            30.0,
            20.0,
            1.0,
            1.0,
            0.0,
            true,
        );
        assert!(moved >= 350);
        // Source region cleared
        assert_eq!(stack.composite_pixel(15, 15)[3], 0);
        // Destination region received red pixels
        assert_eq!(stack.composite_pixel(45, 35), [220, 30, 30, 255]);
        // Unselected blue square is 100% untouched
        assert_eq!(stack.composite_pixel(100, 100), [20, 80, 240, 255]);
        // Selection mask moved along with pixels
        assert!(sel.contains(45, 35));
        assert!(!sel.contains(15, 15));

        // Copy-stamp (clear_source = false) by (+20, 0) keeps previous pixels AND stamps new copy
        let copied = transform_selected_pixels_affine(
            stack.get_mut(l1).unwrap(),
            &mut sel,
            20.0,
            0.0,
            1.0,
            1.0,
            0.0,
            false,
        );
        assert!(copied >= 350);
        assert_eq!(stack.composite_pixel(45, 35), [220, 30, 30, 255]);
        assert_eq!(stack.composite_pixel(65, 35), [220, 30, 30, 255]);
    }

    #[test]
    fn import_rgba_to_layer_scales_and_blits_cleanly() {
        let mut stack = LayerStack::new(128, 128);
        let l1 = stack.add_raster_layer("ImportedPhoto");
        // 2x2 synthetic RGBA image: solid cyan-gold
        let img: Vec<u8> = vec![
            10, 200, 240, 255, 10, 200, 240, 255,
            10, 200, 240, 255, 10, 200, 240, 255,
        ];
        let written = import_rgba_to_layer(
            stack.get_mut(l1).unwrap(),
            &img,
            2,
            2,
            16,
            24,
            40,
            30,
        );
        assert_eq!(written, 40 * 30);
        assert_eq!(stack.composite_pixel(30, 35), [10, 200, 240, 255]);
        assert_eq!(stack.composite_pixel(5, 5)[3], 0);
    }
}
