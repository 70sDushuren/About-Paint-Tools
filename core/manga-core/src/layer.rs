//! Multi-layer cel-shading stack (v0.3): blend modes, clipping masks,
//! alpha lock, reference layers, and non-destructive sketch tinting.

use crate::tile::TileLayer;

/// Unique identifier for a layer within a document.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct LayerId(pub u64);

/// 22 standard anime / cel-shading & ibisPaint-compatible blend modes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum BlendMode {
    Normal = 0,
    Multiply = 1,
    Screen = 2,
    Overlay = 3,
    GlowDodge = 4,
    LinearBurn = 5,
    HardLight = 6,
    SoftLight = 7,
    Darken = 8,
    Lighten = 9,
    ColorBurn = 10,
    ColorDodge = 11,
    Add = 12,
    Difference = 13,
    Exclusion = 14,
    VividLight = 15,
    DarkerColor = 16,
    LighterColor = 17,
    Hue = 18,
    Saturation = 19,
    Color = 20,
    Luminosity = 21,
}

impl BlendMode {
    pub fn from_u32(code: u32) -> Self {
        match code {
            1 => Self::Multiply,
            2 => Self::Screen,
            3 => Self::Overlay,
            4 => Self::GlowDodge,
            5 => Self::LinearBurn,
            6 => Self::HardLight,
            7 => Self::SoftLight,
            8 => Self::Darken,
            9 => Self::Lighten,
            10 => Self::ColorBurn,
            11 => Self::ColorDodge,
            12 => Self::Add,
            13 => Self::Difference,
            14 => Self::Exclusion,
            15 => Self::VividLight,
            16 => Self::DarkerColor,
            17 => Self::LighterColor,
            18 => Self::Hue,
            19 => Self::Saturation,
            20 => Self::Color,
            21 => Self::Luminosity,
            _ => Self::Normal,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LayerKind {
    Raster,
    Folder,
    Vector,
    Screentone,
}

/// A single layer node in the document stack.
#[derive(Debug, Clone)]
pub struct LayerNode {
    pub id: LayerId,
    pub name: String,
    pub kind: LayerKind,
    pub visible: bool,
    pub locked: bool,
    pub opacity: f32,
    pub blend_mode: BlendMode,
    /// When true, this layer clips its alpha to the nearest non-clipped base layer below it.
    pub clipping_mask: bool,
    /// When true, painting/filling preserves existing pixel alpha and only updates RGB.
    pub alpha_lock: bool,
    /// Marks this layer as a reference lineart layer for flood fill / smart flatting.
    pub is_reference: bool,
    /// Non-destructive display tint (e.g., light blue `#4DA6FF` for rough sketch layers).
    pub tint_rgba: Option<[u8; 4]>,
    pub raster: Option<TileLayer>,
}

impl LayerNode {
    pub fn new_raster(id: LayerId, name: impl Into<String>, width: u32, height: u32) -> Self {
        Self {
            id,
            name: name.into(),
            kind: LayerKind::Raster,
            visible: true,
            locked: false,
            opacity: 1.0,
            blend_mode: BlendMode::Normal,
            clipping_mask: false,
            alpha_lock: false,
            is_reference: false,
            tint_rgba: None,
            raster: Some(TileLayer::new(width, height)),
        }
    }

    /// Writes a pixel respecting `locked` and `alpha_lock`.
    pub fn write_pixel(&mut self, x: u32, y: u32, mut rgba: [u8; 4]) -> bool {
        if self.locked {
            return false;
        }
        let Some(tile) = self.raster.as_mut() else {
            return false;
        };
        if self.alpha_lock {
            let existing = tile.get_pixel(x, y);
            if existing[3] == 0 {
                return false;
            }
            rgba[3] = existing[3];
        }
        tile.set_pixel(x, y, rgba).is_some()
    }

    /// Samples a pixel with non-destructive `tint_rgba` applied when active.
    pub fn sample_display_pixel(&self, x: u32, y: u32) -> [u8; 4] {
        let Some(tile) = self.raster.as_ref() else {
            return [0, 0, 0, 0];
        };
        let p = tile.get_pixel(x, y);
        if p[3] == 0 {
            return p;
        }
        if let Some(tint) = self.tint_rgba {
            // Colorize luminance toward tint color (standard anime blue-pencil sketch tint).
            let lum = (0.299 * p[0] as f32 + 0.587 * p[1] as f32 + 0.114 * p[2] as f32) / 255.0;
            let inv = 1.0 - lum;
            let r = (tint[0] as f32 * inv + 255.0 * lum).round().clamp(0.0, 255.0) as u8;
            let g = (tint[1] as f32 * inv + 255.0 * lum).round().clamp(0.0, 255.0) as u8;
            let b = (tint[2] as f32 * inv + 255.0 * lum).round().clamp(0.0, 255.0) as u8;
            [r, g, b, p[3]]
        } else {
            p
        }
    }
}

/// Ordered bottom-to-top layer stack for a canvas document.
#[derive(Debug, Clone)]
pub struct LayerStack {
    pub width: u32,
    pub height: u32,
    next_id: u64,
    layers: Vec<LayerNode>,
}

impl LayerStack {
    pub fn new(width: u32, height: u32) -> Self {
        Self {
            width,
            height,
            next_id: 1,
            layers: Vec::new(),
        }
    }

    pub fn add_raster_layer(&mut self, name: impl Into<String>) -> LayerId {
        let id = LayerId(self.next_id);
        self.next_id += 1;
        self.layers
            .push(LayerNode::new_raster(id, name, self.width, self.height));
        id
    }

    pub fn layers(&self) -> &[LayerNode] {
        &self.layers
    }

    pub fn layers_mut(&mut self) -> &mut [LayerNode] {
        &mut self.layers
    }

    pub fn get(&self, id: LayerId) -> Option<&LayerNode> {
        self.layers.iter().find(|l| l.id == id)
    }

    pub fn get_mut(&mut self, id: LayerId) -> Option<&mut LayerNode> {
        self.layers.iter_mut().find(|l| l.id == id)
    }

    pub fn find_by_name(&self, name: &str) -> Option<LayerId> {
        self.layers.iter().find(|l| l.name == name).map(|l| l.id)
    }

    pub fn reference_layer_ids(&self) -> Vec<LayerId> {
        self.layers
            .iter()
            .filter(|l| l.visible && l.is_reference)
            .map(|l| l.id)
            .collect()
    }

    pub fn remove_layer(&mut self, id: LayerId) -> Option<LayerNode> {
        let idx = self.layers.iter().position(|l| l.id == id)?;
        Some(self.layers.remove(idx))
    }

    /// Duplicates `id` (including sparse raster tiles and flags) and inserts directly above it.
    pub fn duplicate_layer(&mut self, id: LayerId) -> Option<LayerId> {
        let idx = self.layers.iter().position(|l| l.id == id)?;
        let mut cloned = self.layers[idx].clone();
        let new_id = LayerId(self.next_id);
        self.next_id += 1;
        cloned.id = new_id;
        cloned.name = format!("{} Copy", cloned.name);
        cloned.is_reference = false;
        self.layers.insert(idx + 1, cloned);
        Some(new_id)
    }

    /// Merges `id` down into the layer immediately beneath it, preserving blend mode & opacity.
    /// Returns the surviving lower `LayerId`.
    pub fn merge_layer_down(&mut self, id: LayerId) -> Option<LayerId> {
        let idx = self.layers.iter().position(|l| l.id == id)?;
        if idx == 0 {
            return None;
        }
        let upper = self.layers.remove(idx);
        let lower_idx = idx - 1;
        let lower_id = self.layers[lower_idx].id;

        if upper.visible && upper.opacity > 0.0 {
            if let Some(upper_tiles) = upper.raster.as_ref() {
                let coords: Vec<_> = upper_tiles.sorted_tiles().into_iter().map(|(c, _)| c).collect();
                let lower = &mut self.layers[lower_idx];
                if let Some(lower_tiles) = lower.raster.as_mut() {
                    let tile_sz = crate::tile::TILE_SIZE as u32;
                    for coord in coords {
                        let base_x = (coord.tx as i64 * tile_sz as i64).max(0) as u32;
                        let base_y = (coord.ty as i64 * tile_sz as i64).max(0) as u32;
                        let end_x = (base_x + tile_sz).min(self.width);
                        let end_y = (base_y + tile_sz).min(self.height);
                        for y in base_y..end_y {
                            for x in base_x..end_x {
                                let mut src = upper.sample_display_pixel(x, y);
                                if src[3] == 0 {
                                    continue;
                                }
                                let dst = lower_tiles.get_pixel(x, y);
                                if upper.clipping_mask && dst[3] == 0 {
                                    continue;
                                }
                                let eff_a = if upper.clipping_mask {
                                    (src[3] as f32 * upper.opacity.clamp(0.0, 1.0) * (dst[3] as f32 / 255.0))
                                        .round()
                                        .clamp(0.0, 255.0) as u8
                                } else {
                                    (src[3] as f32 * upper.opacity.clamp(0.0, 1.0))
                                        .round()
                                        .clamp(0.0, 255.0) as u8
                                };
                                src[3] = eff_a;
                                if src[3] == 0 {
                                    continue;
                                }
                                let merged = blend_rgba(dst, src, upper.blend_mode);
                                lower_tiles.set_pixel(x, y, merged);
                            }
                        }
                    }
                }
            }
        }
        Some(lower_id)
    }

    /// Reorders layer `id` one slot upward (`up == true`) or downward (`up == false`).
    pub fn move_layer(&mut self, id: LayerId, up: bool) -> bool {
        let Some(idx) = self.layers.iter().position(|l| l.id == id) else {
            return false;
        };
        if up && idx + 1 < self.layers.len() {
            self.layers.swap(idx, idx + 1);
            true
        } else if !up && idx > 0 {
            self.layers.swap(idx, idx - 1);
            true
        } else {
            false
        }
    }

    /// Clears all raster pixels in `id`.
    pub fn clear_layer(&mut self, id: LayerId) -> bool {
        let Some(layer) = self.get_mut(id) else {
            return false;
        };
        if layer.locked {
            return false;
        }
        if let Some(raster) = layer.raster.as_mut() {
            raster.clear();
            true
        } else {
            false
        }
    }

    /// Flips all raster pixels of layer `id` horizontally or vertically.
    pub fn flip_layer(&mut self, id: LayerId, horizontal: bool) -> bool {
        let w = self.width;
        let h = self.height;
        let Some(layer) = self.get_mut(id) else {
            return false;
        };
        if layer.locked {
            return false;
        }
        let Some(old_raster) = layer.raster.as_ref() else {
            return false;
        };
        let mut flipped = TileLayer::new(w, h);
        let tile_sz = crate::tile::TILE_SIZE as u32;
        for (coord, _) in old_raster.sorted_tiles() {
            let base_x = (coord.tx as i64 * tile_sz as i64).max(0) as u32;
            let base_y = (coord.ty as i64 * tile_sz as i64).max(0) as u32;
            let end_x = (base_x + tile_sz).min(w);
            let end_y = (base_y + tile_sz).min(h);
            for y in base_y..end_y {
                for x in base_x..end_x {
                    let px = old_raster.get_pixel(x, y);
                    if px[3] == 0 {
                        continue;
                    }
                    let nx = if horizontal { w - 1 - x } else { x };
                    let ny = if horizontal { y } else { h - 1 - y };
                    flipped.set_pixel(nx, ny, px);
                }
            }
        }
        layer.raster = Some(flipped);
        true
    }

    /// Composites all visible layers at `(x, y)` bottom-to-top with full support
    /// for 22 blend modes, opacity, sketch tinting, and Clipping Masks.
    pub fn composite_pixel(&self, x: u32, y: u32) -> [u8; 4] {
        let mut acc = [0u8, 0, 0, 0];
        let mut base_clip_alpha: u8 = 0;

        for layer in &self.layers {
            if !layer.visible || layer.opacity <= 0.0 {
                if !layer.clipping_mask {
                    base_clip_alpha = 0;
                }
                continue;
            }

            let mut src = layer.sample_display_pixel(x, y);
            let effective_opacity = layer.opacity.clamp(0.0, 1.0);

            if !layer.clipping_mask {
                let scaled_a = (src[3] as f32 * effective_opacity).round().clamp(0.0, 255.0) as u8;
                base_clip_alpha = scaled_a;
                src[3] = scaled_a;
            } else {
                // Clipping mask restricts visibility strictly to the alpha of the base layer below.
                if base_clip_alpha == 0 {
                    continue;
                }
                let clipped_a = (src[3] as f32 * effective_opacity * (base_clip_alpha as f32 / 255.0))
                    .round()
                    .clamp(0.0, 255.0) as u8;
                src[3] = clipped_a;
            }

            if src[3] == 0 {
                continue;
            }

            acc = blend_rgba(acc, src, layer.blend_mode);
        }

        acc
    }
}

/// Blends a single normalized channel `b` (backdrop) and `s` (source) in `[0.0, 1.0]` for separable modes.
#[inline]
fn blend_channel(b: f32, s: f32, mode: BlendMode) -> f32 {
    match mode {
        BlendMode::Normal => s,
        BlendMode::Multiply => b * s,
        BlendMode::Screen => 1.0 - (1.0 - b) * (1.0 - s),
        BlendMode::Overlay => {
            if b <= 0.5 {
                2.0 * b * s
            } else {
                1.0 - 2.0 * (1.0 - b) * (1.0 - s)
            }
        }
        BlendMode::GlowDodge => {
            if s >= 1.0 {
                1.0
            } else {
                (b / (1.0 - s).max(1e-4)).min(1.0)
            }
        }
        BlendMode::LinearBurn => (b + s - 1.0).max(0.0),
        BlendMode::HardLight => {
            if s <= 0.5 {
                2.0 * b * s
            } else {
                1.0 - 2.0 * (1.0 - b) * (1.0 - s)
            }
        }
        BlendMode::SoftLight => (1.0 - 2.0 * s) * b * b + 2.0 * s * b,
        BlendMode::Darken => b.min(s),
        BlendMode::Lighten => b.max(s),
        BlendMode::ColorBurn => {
            if s <= 1e-4 {
                0.0
            } else {
                (1.0 - ((1.0 - b) / s).min(1.0)).max(0.0)
            }
        }
        BlendMode::ColorDodge => {
            if s >= 1.0 - 1e-4 {
                1.0
            } else {
                (b / (1.0 - s)).min(1.0)
            }
        }
        BlendMode::Add => (b + s).min(1.0),
        BlendMode::Difference => (b - s).abs(),
        BlendMode::Exclusion => b + s - 2.0 * b * s,
        BlendMode::VividLight => {
            if s <= 0.5 {
                let s2 = 2.0 * s;
                if s2 <= 1e-4 {
                    0.0
                } else {
                    (1.0 - ((1.0 - b) / s2).min(1.0)).max(0.0)
                }
            } else {
                let s2 = 2.0 * (s - 0.5);
                if s2 >= 1.0 - 1e-4 {
                    1.0
                } else {
                    (b / (1.0 - s2)).min(1.0)
                }
            }
        }
        _ => s,
    }
}

#[inline]
fn lum(rgb: [f32; 3]) -> f32 {
    0.3 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2]
}

#[inline]
fn sat(rgb: [f32; 3]) -> f32 {
    rgb[0].max(rgb[1]).max(rgb[2]) - rgb[0].min(rgb[1]).min(rgb[2])
}

#[inline]
fn clip_color(mut c: [f32; 3]) -> [f32; 3] {
    let l = lum(c);
    let n = c[0].min(c[1]).min(c[2]);
    let x = c[0].max(c[1]).max(c[2]);
    if n < 0.0 {
        let denom = (l - n).max(1e-6);
        for v in &mut c {
            *v = l + ((*v - l) * l) / denom;
        }
    }
    if x > 1.0 {
        let denom = (x - l).max(1e-6);
        for v in &mut c {
            *v = l + ((*v - l) * (1.0 - l)) / denom;
        }
    }
    [c[0].clamp(0.0, 1.0), c[1].clamp(0.0, 1.0), c[2].clamp(0.0, 1.0)]
}

#[inline]
fn set_lum(c: [f32; 3], l: f32) -> [f32; 3] {
    let d = l - lum(c);
    clip_color([c[0] + d, c[1] + d, c[2] + d])
}

#[inline]
fn set_sat(c: [f32; 3], s: f32) -> [f32; 3] {
    let mut idx = [0usize, 1, 2];
    if c[idx[0]] > c[idx[1]] {
        idx.swap(0, 1);
    }
    if c[idx[1]] > c[idx[2]] {
        idx.swap(1, 2);
    }
    if c[idx[0]] > c[idx[1]] {
        idx.swap(0, 1);
    }
    let mut out = [0.0f32; 3];
    let min_i = idx[0];
    let mid_i = idx[1];
    let max_i = idx[2];
    if c[max_i] > c[min_i] {
        out[mid_i] = ((c[mid_i] - c[min_i]) * s) / (c[max_i] - c[min_i]);
        out[max_i] = s;
    }
    out
}

#[inline]
fn blend_rgb(b: [f32; 3], s: [f32; 3], mode: BlendMode) -> [f32; 3] {
    match mode {
        BlendMode::DarkerColor => {
            if lum(b) <= lum(s) {
                b
            } else {
                s
            }
        }
        BlendMode::LighterColor => {
            if lum(b) >= lum(s) {
                b
            } else {
                s
            }
        }
        BlendMode::Hue => set_lum(set_sat(s, sat(b)), lum(b)),
        BlendMode::Saturation => set_lum(set_sat(b, sat(s)), lum(b)),
        BlendMode::Color => set_lum(s, lum(b)),
        BlendMode::Luminosity => set_lum(b, lum(s)),
        _ => [
            blend_channel(b[0], s[0], mode),
            blend_channel(b[1], s[1], mode),
            blend_channel(b[2], s[2], mode),
        ],
    }
}

/// Porter-Duff Source-Over RGBA8 compositing with all 22 separable & non-separable W3C blend modes.
pub fn blend_rgba(dst: [u8; 4], src: [u8; 4], mode: BlendMode) -> [u8; 4] {
    let sa = src[3] as f32 / 255.0;
    if sa <= 0.0 {
        return dst;
    }
    let da = dst[3] as f32 / 255.0;
    if da <= 0.0 {
        return src;
    }

    let out_a = sa + da * (1.0 - sa);
    if out_a <= 1e-6 {
        return [0, 0, 0, 0];
    }

    let b = [dst[0] as f32 / 255.0, dst[1] as f32 / 255.0, dst[2] as f32 / 255.0];
    let s = [src[0] as f32 / 255.0, src[1] as f32 / 255.0, src[2] as f32 / 255.0];
    let blended = blend_rgb(b, s, mode);

    let mut out = [0u8; 4];
    for c in 0..3 {
        // Standard W3C Compositing & Blending formula for non-premultiplied output:
        // Cr = ((1 - sa) * da * bc + (1 - da) * sa * sc + sa * da * B(bc, sc)) / out_a
        let numer = (1.0 - sa) * da * b[c] + (1.0 - da) * sa * s[c] + sa * da * blended[c];
        out[c] = ((numer / out_a).clamp(0.0, 1.0) * 255.0).round() as u8;
    }
    out[3] = (out_a.clamp(0.0, 1.0) * 255.0).round() as u8;
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn multiply_and_screen_match_expected_cel_shading_math() {
        let base = [200, 100, 50, 255];
        let shadow = [128, 128, 255, 255];
        let mult = blend_rgba(base, shadow, BlendMode::Multiply);
        // 200 * 128 / 255 ≈ 100, 100 * 128 / 255 ≈ 50, 50 * 255 / 255 = 50
        assert!((mult[0] as i32 - 100).abs() <= 1);
        assert!((mult[1] as i32 - 50).abs() <= 1);
        assert_eq!(mult[2], 50);

        let glow = blend_rgba([100, 100, 100, 255], [100, 100, 100, 255], BlendMode::Screen);
        assert!(glow[0] > 150 && glow[0] < 170);
    }

    #[test]
    fn all_22_ibispaint_blend_modes_and_layer_crud_work() {
        let base = [210, 120, 60, 255];
        let top = [60, 180, 220, 255];
        for code in 0..22u32 {
            let mode = BlendMode::from_u32(code);
            let res = blend_rgba(base, top, mode);
            assert_eq!(res[3], 255);
        }
        let diff = blend_rgba([200, 100, 50, 255], [200, 100, 50, 255], BlendMode::Difference);
        assert_eq!(diff, [0, 0, 0, 255]);

        let mut stack = LayerStack::new(64, 64);
        let l1 = stack.add_raster_layer("Base");
        stack.get_mut(l1).unwrap().write_pixel(5, 10, [255, 0, 0, 255]);
        let l2 = stack.duplicate_layer(l1).unwrap();
        assert_eq!(stack.layers().len(), 2);
        assert_eq!(stack.get(l2).unwrap().raster.as_ref().unwrap().get_pixel(5, 10), [255, 0, 0, 255]);

        assert!(stack.flip_layer(l2, true));
        assert_eq!(stack.get(l2).unwrap().raster.as_ref().unwrap().get_pixel(58, 10), [255, 0, 0, 255]);

        let merged_id = stack.merge_layer_down(l2).unwrap();
        assert_eq!(merged_id, l1);
        assert_eq!(stack.layers().len(), 1);
        assert_eq!(stack.composite_pixel(5, 10), [255, 0, 0, 255]);
        assert_eq!(stack.composite_pixel(58, 10), [255, 0, 0, 255]);
    }

    #[test]
    fn clipping_mask_restricts_shadow_layer_to_base_alpha() {
        let mut stack = LayerStack::new(128, 128);
        let base_id = stack.add_raster_layer("BaseSkin");
        let shadow_id = stack.add_raster_layer("CelShadow");

        // Paint skin only at (10, 10)
        stack.get_mut(base_id).unwrap().write_pixel(10, 10, [255, 200, 180, 255]);

        // Paint shadow at both (10, 10) and outside (20, 20), with clipping_mask = true
        {
            let sh = stack.get_mut(shadow_id).unwrap();
            sh.clipping_mask = true;
            sh.blend_mode = BlendMode::Multiply;
            sh.write_pixel(10, 10, [128, 128, 128, 255]);
            sh.write_pixel(20, 20, [128, 128, 128, 255]);
        }

        // Inside base skin: darkened by multiply shadow
        let inside = stack.composite_pixel(10, 10);
        assert!((inside[0] as i32 - 128).abs() <= 1);
        assert_eq!(inside[3], 255);

        // Outside base skin: completely clipped away!
        assert_eq!(stack.composite_pixel(20, 20), [0, 0, 0, 0]);
    }

    #[test]
    fn alpha_lock_and_blue_sketch_tint_behave_non_destructively() {
        let mut stack = LayerStack::new(64, 64);
        let sketch_id = stack.add_raster_layer("Sketch");
        let sketch = stack.get_mut(sketch_id).unwrap();
        sketch.write_pixel(5, 5, [0, 0, 0, 255]);

        // Alpha lock prevents painting empty pixel (6, 6) but allows recoloring (5, 5).
        sketch.alpha_lock = true;
        assert!(!sketch.write_pixel(6, 6, [255, 0, 0, 255]));
        assert!(sketch.write_pixel(5, 5, [20, 20, 20, 255]));

        // Blue sketch tint changes display output without mutating underlying raster pixels.
        sketch.tint_rgba = Some([77, 166, 255, 255]);
        let displayed = stack.composite_pixel(5, 5);
        assert!(displayed[2] > displayed[0], "Blue channel should dominate tinted sketch");
        assert_eq!(
            stack.get(sketch_id).unwrap().raster.as_ref().unwrap().get_pixel(5, 5),
            [20, 20, 20, 255]
        );
    }
}
