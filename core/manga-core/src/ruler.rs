//! Manga drawing rulers & snapping pipeline (v0.5):
//! Symmetry mirror, Parallel lines, 1/2/3-Point Perspective vanishing rays,
//! and Radial Focus/Speed lines.

use crate::stroke::StrokePoint;

/// Active drawing ruler guide for stroke snapping or mirroring.
#[derive(Debug, Clone, PartialEq)]
pub enum RulerKind {
    /// Mirrors strokes across the infinite axis passing through `(axis_x, axis_y)` at `angle_rad`.
    Symmetry {
        axis_x: f32,
        axis_y: f32,
        angle_rad: f32,
    },
    /// Locks stroke direction strictly parallel to `angle_rad`.
    Parallel { angle_rad: f32 },
    /// 1-, 2-, or 3-point perspective ruler snapping strokes onto the nearest vanishing ray.
    Perspective { vanishing_points: Vec<(f32, f32)> },
    /// Radial action/focus lines converging toward `(center_x, center_y)`.
    FocusLines { center_x: f32, center_y: f32 },
}

/// Projects point `(px, py)` orthogonally onto the line through `(ax, ay)` with unit direction `(ux, uy)`.
#[inline]
fn project_onto_line(px: f32, py: f32, ax: f32, ay: f32, ux: f32, uy: f32) -> (f32, f32) {
    let t = (px - ax) * ux + (py - ay) * uy;
    (ax + ux * t, ay + uy * t)
}

impl RulerKind {
    /// Mirrors a single `StrokePoint` across a Symmetry ruler axis.
    /// Returns `None` for non-symmetry rulers.
    pub fn mirror_point(&self, pt: StrokePoint) -> Option<StrokePoint> {
        let Self::Symmetry {
            axis_x,
            axis_y,
            angle_rad,
        } = *self
        else {
            return None;
        };
        let (sin, cos) = angle_rad.sin_cos();
        let (proj_x, proj_y) = project_onto_line(pt.x, pt.y, axis_x, axis_y, cos, sin);
        Some(StrokePoint {
            x: 2.0 * proj_x - pt.x,
            y: 2.0 * proj_y - pt.y,
            ..pt
        })
    }

    /// Snaps `pt` relative to the stroke start anchor `(anchor_x, anchor_y)`.
    /// For Symmetry rulers, returns the original point unchanged (use `mirror_point` for the twin stroke).
    pub fn snap_point(&self, anchor_x: f32, anchor_y: f32, pt: StrokePoint) -> StrokePoint {
        match self {
            Self::Symmetry { .. } => pt,
            Self::Parallel { angle_rad } => {
                let (sin, cos) = angle_rad.sin_cos();
                let (nx, ny) = project_onto_line(pt.x, pt.y, anchor_x, anchor_y, cos, sin);
                StrokePoint { x: nx, y: ny, ..pt }
            }
            Self::FocusLines { center_x, center_y } => {
                let dx = anchor_x - *center_x;
                let dy = anchor_y - *center_y;
                let len = dx.hypot(dy);
                if len < 1e-4 {
                    return pt;
                }
                let (nx, ny) = project_onto_line(pt.x, pt.y, *center_x, *center_y, dx / len, dy / len);
                StrokePoint { x: nx, y: ny, ..pt }
            }
            Self::Perspective { vanishing_points } => {
                if vanishing_points.is_empty() {
                    return pt;
                }
                let move_x = pt.x - anchor_x;
                let move_y = pt.y - anchor_y;
                let move_len = move_x.hypot(move_y);
                if move_len < 1e-4 {
                    return pt;
                }
                let mx = move_x / move_len;
                let my = move_y / move_len;

                // Choose the vanishing point ray with greatest alignment (`|dot|`) to artist drag vector.
                let mut best_ray: Option<(f32, f32, f32)> = None; // (ux, uy, abs_dot)
                for &(vx, vy) in vanishing_points {
                    let rx = vx - anchor_x;
                    let ry = vy - anchor_y;
                    let rlen = rx.hypot(ry);
                    if rlen < 1e-4 {
                        continue;
                    }
                    let ux = rx / rlen;
                    let uy = ry / rlen;
                    let score = (ux * mx + uy * my).abs();
                    if best_ray.map_or(true, |b| score > b.2) {
                        best_ray = Some((ux, uy, score));
                    }
                }

                if let Some((ux, uy, _)) = best_ray {
                    let (nx, ny) = project_onto_line(pt.x, pt.y, anchor_x, anchor_y, ux, uy);
                    StrokePoint { x: nx, y: ny, ..pt }
                } else {
                    pt
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::f32::consts::FRAC_PI_2;

    #[test]
    fn vertical_symmetry_ruler_mirrors_horizontally_and_round_trips() {
        let sym = RulerKind::Symmetry {
            axis_x: 100.0,
            axis_y: 0.0,
            angle_rad: FRAC_PI_2,
        };
        let p = StrokePoint::simple(70.0, 40.0, 0.8);
        let m = sym.mirror_point(p).unwrap();
        assert!((m.x - 130.0).abs() < 1e-3);
        assert!((m.y - 40.0).abs() < 1e-3);
        let back = sym.mirror_point(m).unwrap();
        assert!((back.x - 70.0).abs() < 1e-3);
    }

    #[test]
    fn two_point_perspective_snaps_onto_nearest_vanishing_ray() {
        let persp = RulerKind::Perspective {
            vanishing_points: vec![(0.0, 500.0), (1000.0, 500.0)],
        };
        // Anchor at (500, 0); dragging roughly toward right vanishing point (1000, 500) (45 deg ray)
        let raw = StrokePoint::simple(600.0, 90.0, 1.0);
        let snapped = persp.snap_point(500.0, 0.0, raw);
        // On ray from (500,0) -> (1000,500), (x - 500) must equal y.
        assert!(((snapped.x - 500.0) - snapped.y).abs() < 1e-3);
    }

    #[test]
    fn focus_lines_snap_radially_toward_center() {
        let focus = RulerKind::FocusLines {
            center_x: 500.0,
            center_y: 500.0,
        };
        // Anchor due right of center at (800, 500) -> radial ray is horizontal y = 500.
        let snapped = focus.snap_point(800.0, 500.0, StrokePoint::simple(700.0, 512.0, 0.9));
        assert!((snapped.x - 700.0).abs() < 1e-3);
        assert!((snapped.y - 500.0).abs() < 1e-3);
    }
}
