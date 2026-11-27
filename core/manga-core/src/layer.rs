//! Multi-layer cel-shading stack (v0.3): blend modes, clipping masks,
//! alpha lock, reference layers, and non-destructive sketch tinting.

use crate::tile::TileLayer;

/// Unique identifier for a layer within a document.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct LayerId(pub u64);

/// 13 standard anime / cel-shading & illustration blend modes.
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

    /// Composites all visible layers at `(x, y)` bottom-to-top with full support
    /// for blend modes, opacity, sketch tinting, and Clipping Masks.
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

/// Blends a single normalized channel `b` (backdrop) and `s` (source) in `[0.0, 1.0]`.
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
    }
}

/// Porter-Duff Source-Over RGBA8 compositing with separable blend modes.
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

    let mut out = [0u8; 4];
    for c in 0..3 {
        let bc = dst[c] as f32 / 255.0;
        let sc = src[c] as f32 / 255.0;
        let blended = blend_channel(bc, sc, mode);
        // Standard W3C Compositing & Blending formula for non-premultiplied output:
        // Cr = ((1 - sa) * da * bc + (1 - da) * sa * sc + sa * da * B(bc, sc)) / out_a
        let numer = (1.0 - sa) * da * bc + (1.0 - da) * sa * sc + sa * da * blended;
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
