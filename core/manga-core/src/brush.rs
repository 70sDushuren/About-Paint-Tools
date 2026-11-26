//! `S2 v0.2.1` — Deterministic Anime Brush Dynamics & Stamping Engine (`雕龙 / DracoNib`, working codename).
//!
//! Clean-room MIT implementation providing cubic Bézier response curves for pressure,
//! tilt, velocity, and Apple Pencil Pro `roll_angle`, zoom-adaptive Rope Stabilizer
//! radius scaling, G-Pen entry/exit taper physics, and 8 built-in dual-track starter presets.

use crate::stroke::StrokePoint;

/// Cubic Bézier response curve mapping normalized input `t in [0, 1]` to `[0, 1]`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ResponseCurve {
    pub p1: (f32, f32),
    pub p2: (f32, f32),
}

impl ResponseCurve {
    pub const LINEAR: Self = Self {
        p1: (0.33, 0.33),
        p2: (0.67, 0.67),
    };

    /// Crisp G-Pen curve: light touch yields hair-thin ink; firm pressure swells smoothly.
    pub const G_PEN_TAPER: Self = Self {
        p1: (0.55, 0.12),
        p2: (0.78, 0.88),
    };

    /// Soft airbrush curve: gentle opacity buildup for cel gradients without banding.
    pub const SOFT_AIRBRUSH: Self = Self {
        p1: (0.25, 0.45),
        p2: (0.65, 0.90),
    };

    /// Evaluates the cubic Bézier Y value at normalized parameter `t in [0, 1]`.
    pub fn evaluate(&self, t: f32) -> f32 {
        let u = t.clamp(0.0, 1.0);
        let inv = 1.0 - u;
        let y = 3.0 * inv * inv * u * self.p1.1
            + 3.0 * inv * u * u * self.p2.1
            + u * u * u;
        y.clamp(0.0, 1.0)
    }
}

/// Built-in dual-track anime starter brush families.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum BrushPresetId {
    GPen = 0,
    MaruPen = 1,
    SketchPencil = 2,
    CelFlattingSolid = 3,
    SoftAirbrush = 4,
    WetBlend = 5,
    HardEraser = 6,
    ScreentoneScraper = 7,
}

impl BrushPresetId {
    pub fn from_u32(code: u32) -> Option<Self> {
        match code {
            0 => Some(Self::GPen),
            1 => Some(Self::MaruPen),
            2 => Some(Self::SketchPencil),
            3 => Some(Self::CelFlattingSolid),
            4 => Some(Self::SoftAirbrush),
            5 => Some(Self::WetBlend),
            6 => Some(Self::HardEraser),
            7 => Some(Self::ScreentoneScraper),
            _ => None,
        }
    }
}

/// Complete deterministic brush preset descriptor (ready for both CPU reference and WGSL GPU stamping).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BrushTipPreset {
    pub id: BrushPresetId,
    pub name: &'static str,
    pub base_radius_px: f32,
    pub min_radius_ratio: f32,
    pub spacing_ratio: f32,
    pub hardness: f32,
    pub flow: f32,
    pub pressure_size_curve: ResponseCurve,
    pub pressure_opacity_curve: ResponseCurve,
    pub supports_barrel_roll: bool,
    pub is_eraser: bool,
    pub default_rope_px: f32,
}

/// Returns all 8 built-in dual-track starter brushes (`v0.2`).
pub fn starter_brush_presets() -> [BrushTipPreset; 8] {
    [
        BrushTipPreset {
            id: BrushPresetId::GPen,
            name: "G-Pen",
            base_radius_px: 6.0,
            min_radius_ratio: 0.08,
            spacing_ratio: 0.12,
            hardness: 0.96,
            flow: 1.0,
            pressure_size_curve: ResponseCurve::G_PEN_TAPER,
            pressure_opacity_curve: ResponseCurve::LINEAR,
            supports_barrel_roll: true,
            is_eraser: false,
            default_rope_px: 6.0,
        },
        BrushTipPreset {
            id: BrushPresetId::MaruPen,
            name: "Maru-Pen",
            base_radius_px: 3.5,
            min_radius_ratio: 0.05,
            spacing_ratio: 0.10,
            hardness: 0.98,
            flow: 1.0,
            pressure_size_curve: ResponseCurve::G_PEN_TAPER,
            pressure_opacity_curve: ResponseCurve::LINEAR,
            supports_barrel_roll: false,
            is_eraser: false,
            default_rope_px: 5.0,
        },
        BrushTipPreset {
            id: BrushPresetId::SketchPencil,
            name: "Sketch Pencil",
            base_radius_px: 4.5,
            min_radius_ratio: 0.30,
            spacing_ratio: 0.18,
            hardness: 0.65,
            flow: 0.72,
            pressure_size_curve: ResponseCurve::LINEAR,
            pressure_opacity_curve: ResponseCurve::SOFT_AIRBRUSH,
            supports_barrel_roll: true,
            is_eraser: false,
            default_rope_px: 2.0,
        },
        BrushTipPreset {
            id: BrushPresetId::CelFlattingSolid,
            name: "Cel Flatting Solid",
            base_radius_px: 14.0,
            min_radius_ratio: 0.75,
            spacing_ratio: 0.15,
            hardness: 1.0,
            flow: 1.0,
            pressure_size_curve: ResponseCurve::LINEAR,
            pressure_opacity_curve: ResponseCurve::LINEAR,
            supports_barrel_roll: false,
            is_eraser: false,
            default_rope_px: 4.0,
        },
        BrushTipPreset {
            id: BrushPresetId::SoftAirbrush,
            name: "Soft Airbrush",
            base_radius_px: 48.0,
            min_radius_ratio: 0.60,
            spacing_ratio: 0.20,
            hardness: 0.08,
            flow: 0.28,
            pressure_size_curve: ResponseCurve::LINEAR,
            pressure_opacity_curve: ResponseCurve::SOFT_AIRBRUSH,
            supports_barrel_roll: false,
            is_eraser: false,
            default_rope_px: 0.0,
        },
        BrushTipPreset {
            id: BrushPresetId::WetBlend,
            name: "Wet Blend",
            base_radius_px: 22.0,
            min_radius_ratio: 0.45,
            spacing_ratio: 0.14,
            hardness: 0.35,
            flow: 0.55,
            pressure_size_curve: ResponseCurve::LINEAR,
            pressure_opacity_curve: ResponseCurve::SOFT_AIRBRUSH,
            supports_barrel_roll: true,
            is_eraser: false,
            default_rope_px: 2.0,
        },
        BrushTipPreset {
            id: BrushPresetId::HardEraser,
            name: "Hard Eraser",
            base_radius_px: 16.0,
            min_radius_ratio: 0.50,
            spacing_ratio: 0.15,
            hardness: 0.95,
            flow: 1.0,
            pressure_size_curve: ResponseCurve::LINEAR,
            pressure_opacity_curve: ResponseCurve::LINEAR,
            supports_barrel_roll: false,
            is_eraser: true,
            default_rope_px: 0.0,
        },
        BrushTipPreset {
            id: BrushPresetId::ScreentoneScraper,
            name: "Screentone White Scraper",
            base_radius_px: 10.0,
            min_radius_ratio: 0.10,
            spacing_ratio: 0.12,
            hardness: 0.90,
            flow: 0.95,
            pressure_size_curve: ResponseCurve::G_PEN_TAPER,
            pressure_opacity_curve: ResponseCurve::LINEAR,
            supports_barrel_roll: true,
            is_eraser: true,
            default_rope_px: 4.0,
        },
    ]
}

/// Computes zoom-adaptive rope stabilizer radius in canvas pixels so artist muscle memory
/// feels consistent whether zoomed at 50% or 400%.
pub fn zoom_adaptive_rope_radius(base_screen_px: f32, viewport_zoom: f32) -> f32 {
    if base_screen_px <= 0.0 {
        return 0.0;
    }
    let safe_zoom = viewport_zoom.clamp(0.1, 32.0);
    (base_screen_px / safe_zoom).clamp(0.5, 128.0)
}

/// Single deterministic brush stamp emitted for GPU (WGSL) or CPU rasterization.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BrushStamp {
    pub x: f32,
    pub y: f32,
    pub radius_px: f32,
    pub opacity: f32,
    pub angle_rad: f32,
    pub hardness: f32,
}

/// Evaluates effective brush radius for a given preset and stylus sample.
pub fn sample_effective_radius(preset: &BrushTipPreset, pressure: f32, altitude: f32) -> f32 {
    let shaped = preset.pressure_size_curve.evaluate(pressure);
    let ratio = preset.min_radius_ratio + (1.0 - preset.min_radius_ratio) * shaped;
    // Slight chisel widening when stylus tilts flat (low altitude angle)
    let tilt_boost = 1.0 + ((1.5707 - altitude.clamp(0.2, 1.5707)) / 1.5707) * 0.25;
    (preset.base_radius_px * ratio * tilt_boost).max(0.25)
}

/// Deterministic spacing-interpolated brush stamping engine.
pub struct BrushStampingEngine;

impl BrushStampingEngine {
    /// Converts a sequence of stylus points into deterministic evenly-spaced stamps.
    pub fn generate_stamps(preset: &BrushTipPreset, points: &[StrokePoint]) -> Vec<BrushStamp> {
        if points.is_empty() {
            return Vec::new();
        }
        let mut stamps = Vec::new();
        let make_stamp = |p: &StrokePoint| -> BrushStamp {
            let radius = sample_effective_radius(preset, p.pressure, p.altitude);
            let opacity = (preset.flow * preset.pressure_opacity_curve.evaluate(p.pressure))
                .clamp(0.02, 1.0);
            let angle = if preset.supports_barrel_roll {
                p.roll_angle
            } else {
                0.0
            };
            BrushStamp {
                x: p.x,
                y: p.y,
                radius_px: radius,
                opacity,
                angle_rad: angle,
                hardness: preset.hardness,
            }
        };

        stamps.push(make_stamp(&points[0]));
        let mut carry = 0.0f32;

        for seg in points.windows(2) {
            let a = &seg[0];
            let b = &seg[1];
            let dx = b.x - a.x;
            let dy = b.y - a.y;
            let seg_len = dx.hypot(dy);
            if seg_len <= 1e-4 {
                continue;
            }
            let r_avg = 0.5
                * (sample_effective_radius(preset, a.pressure, a.altitude)
                    + sample_effective_radius(preset, b.pressure, b.altitude));
            let step = (r_avg * 2.0 * preset.spacing_ratio).max(0.5);

            let mut dist = step - carry;
            while dist <= seg_len {
                let t = (dist / seg_len).clamp(0.0, 1.0);
                let interp = StrokePoint {
                    x: a.x + dx * t,
                    y: a.y + dy * t,
                    pressure: a.pressure + (b.pressure - a.pressure) * t,
                    altitude: a.altitude + (b.altitude - a.altitude) * t,
                    azimuth: a.azimuth + (b.azimuth - a.azimuth) * t,
                    roll_angle: a.roll_angle + (b.roll_angle - a.roll_angle) * t,
                    timestamp_ms: a.timestamp_ms + (b.timestamp_ms - a.timestamp_ms) * f64::from(t),
                    is_predicted: b.is_predicted,
                };
                stamps.push(make_stamp(&interp));
                dist += step;
            }
            carry = (seg_len - (dist - step)).max(0.0);
        }

        stamps
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn g_pen_taper_and_deterministic_replay_match_exactly() {
        let presets = starter_brush_presets();
        assert_eq!(presets.len(), 8);
        let gpen = presets[BrushPresetId::GPen as usize];

        let r_light = sample_effective_radius(&gpen, 0.1, 1.57);
        let r_heavy = sample_effective_radius(&gpen, 0.95, 1.57);
        assert!(r_heavy > r_light * 4.0, "G-Pen must exhibit strong entry/exit taper");

        let pts = vec![
            StrokePoint { x: 0.0, y: 0.0, pressure: 0.1, altitude: 1.5, azimuth: 0.0, roll_angle: 0.3, timestamp_ms: 0.0, is_predicted: false },
            StrokePoint { x: 30.0, y: 12.0, pressure: 0.85, altitude: 1.2, azimuth: 0.0, roll_angle: 0.6, timestamp_ms: 8.0, is_predicted: false },
            StrokePoint { x: 60.0, y: 0.0, pressure: 0.15, altitude: 1.5, azimuth: 0.0, roll_angle: 0.9, timestamp_ms: 16.0, is_predicted: false },
        ];
        let run1 = BrushStampingEngine::generate_stamps(&gpen, &pts);
        let run2 = BrushStampingEngine::generate_stamps(&gpen, &pts);
        assert_eq!(run1, run2, "Brush stamping must be 100% deterministic");
        assert!(run1.len() > 20);
        assert!((run1[0].angle_rad - 0.3).abs() < 1e-5);
    }

    #[test]
    fn zoom_adaptive_rope_scales_inversely_with_zoom() {
        let r_1x = zoom_adaptive_rope_radius(8.0, 1.0);
        let r_4x = zoom_adaptive_rope_radius(8.0, 4.0);
        assert!((r_1x - 8.0).abs() < 1e-5);
        assert!((r_4x - 2.0).abs() < 1e-5);
    }
}
