//! Non-destructive procedural manga Screentone (Halftone) engine (v0.6).
//!
//! Computes exact mathematical dot/line/crosshatch/noise halftone masks directly
//! from `(LPI, DPI, angle_deg, density)`, serving as both the 600DPI binary print
//! rasterizer and the bit-accurate reference for future WGSL halftone shaders.

use std::f32::consts::PI;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum TonePattern {
    CircleDot = 0,
    LineScreen = 1,
    CrossHatch = 2,
    NoiseGrain = 3,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ScreentoneSpec {
    /// Lines per inch (classic Japanese manga tones: 45–85 LPI, default 60 LPI).
    pub lpi: f32,
    /// Canvas print DPI (e.g., 600.0 for B4 commercial manga).
    pub dpi: f32,
    /// Screen rotation angle in degrees (classic manga default: 45.0°).
    pub angle_deg: f32,
    /// Tone density in `[0.0, 1.0]` (e.g., 0.10 = 10% light gray tone, 0.50 = 50% mid-tone).
    pub density: f32,
    pub pattern: TonePattern,
    pub ink_rgba: [u8; 4],
}

impl Default for ScreentoneSpec {
    fn default() -> Self {
        Self {
            lpi: 60.0,
            dpi: 600.0,
            angle_deg: 45.0,
            density: 0.25,
            pattern: TonePattern::CircleDot,
            ink_rgba: [0, 0, 0, 255],
        }
    }
}

impl ScreentoneSpec {
    /// Evaluates whether canvas pixel `(x, y)` is inked by this procedural screentone.
    pub fn sample_mask(&self, x: u32, y: u32) -> bool {
        let d = self.density.clamp(0.0, 1.0);
        if d <= 0.0 {
            return false;
        }
        if d >= 1.0 {
            return true;
        }

        let period = (self.dpi / self.lpi.max(1.0)).max(1.0);
        let rad = self.angle_deg.to_radians();
        let (sin, cos) = rad.sin_cos();

        let fx = x as f32 + 0.5;
        let fy = y as f32 + 0.5;

        // Rotate canvas coordinates into halftone screen space normalized by `period`.
        let u = (fx * cos + fy * sin) / period;
        let v = (-fx * sin + fy * cos) / period;

        // Cell-local coordinates in [-0.5, 0.5).
        let cu = u.rem_euclid(1.0) - 0.5;
        let cv = v.rem_euclid(1.0) - 0.5;

        match self.pattern {
            TonePattern::CircleDot => {
                // Exact area-preserving dot radius for density <= 0.5, inverted white dot above 0.5.
                if d <= 0.5 {
                    let r = (d / PI).sqrt();
                    cu * cu + cv * cv <= r * r
                } else {
                    let r_white = ((1.0 - d) / PI).sqrt();
                    // Inverted corner-centered white dots preserve visual continuity above 50%.
                    let du = 0.5 - cu.abs();
                    let dv = 0.5 - cv.abs();
                    du * du + dv * dv > r_white * r_white
                }
            }
            TonePattern::LineScreen => cu.abs() <= d * 0.5,
            TonePattern::CrossHatch => {
                // Solve 2*w - w^2 = d -> w = 1 - sqrt(1 - d)
                let w = 1.0 - (1.0 - d).sqrt();
                cu.abs() <= w * 0.5 || cv.abs() <= w * 0.5
            }
            TonePattern::NoiseGrain => {
                // Deterministic hash noise for sandy/gritty manga atmospheric tones.
                let mut h = x.wrapping_mul(374_761_393) ^ y.wrapping_mul(668_265_263);
                h = (h ^ (h >> 13)).wrapping_mul(1_274_126_177);
                let norm = ((h ^ (h >> 16)) & 0xFFFF) as f32 / 65536.0;
                norm < d
            }
        }
    }

    pub fn sample_rgba(&self, x: u32, y: u32) -> [u8; 4] {
        if self.sample_mask(x, y) {
            self.ink_rgba
        } else {
            [0, 0, 0, 0]
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn circle_dot_and_line_screen_match_target_density_within_tolerance() {
        for &(pattern, target_density) in &[
            (TonePattern::CircleDot, 0.25f32),
            (TonePattern::CircleDot, 0.65f32),
            (TonePattern::LineScreen, 0.30f32),
            (TonePattern::CrossHatch, 0.40f32),
            (TonePattern::NoiseGrain, 0.50f32),
        ] {
            let spec = ScreentoneSpec {
                lpi: 60.0,
                dpi: 600.0,
                angle_deg: 45.0,
                density: target_density,
                pattern,
                ink_rgba: [0, 0, 0, 255],
            };
            let mut inked = 0usize;
            let side = 200u32;
            for y in 0..side {
                for x in 0..side {
                    if spec.sample_mask(x, y) {
                        inked += 1;
                    }
                }
            }
            let measured = inked as f32 / (side * side) as f32;
            assert!(
                (measured - target_density).abs() < 0.03,
                "Pattern {pattern:?} target {target_density}, got {measured}"
            );
        }
    }
}
