//! End-to-end v0.1 canvas session: viewport transforms, hard-round brush stamping,
//! predicted-touch isolation, dirty-tile tracking, and atomic CoW undo commits.

use std::collections::{HashMap, HashSet};
use std::sync::Arc;

use crate::preset::{CanvasPreset, CanvasSpec};
use crate::stroke::{RopeStabilizer, StrokePoint};
use crate::tile::{TileCoord, TileData, TileLayer};
use crate::undo::{TileDiff, TileUndoStack};

/// 2D affine viewport transform between screen space and canvas pixel space.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ViewportTransform {
    pub pan_x: f32,
    pub pan_y: f32,
    pub zoom: f32,
    pub rotation_rad: f32,
}

impl Default for ViewportTransform {
    fn default() -> Self {
        Self {
            pan_x: 0.0,
            pan_y: 0.0,
            zoom: 1.0,
            rotation_rad: 0.0,
        }
    }
}

impl ViewportTransform {
    pub fn canvas_to_screen(&self, cx: f32, cy: f32) -> (f32, f32) {
        let (sin, cos) = self.rotation_rad.sin_cos();
        let sx = (cx * cos - cy * sin) * self.zoom + self.pan_x;
        let sy = (cx * sin + cy * cos) * self.zoom + self.pan_y;
        (sx, sy)
    }

    pub fn screen_to_canvas(&self, sx: f32, sy: f32) -> (f32, f32) {
        let inv_zoom = if self.zoom.abs() > 1e-6 {
            1.0 / self.zoom
        } else {
            1.0
        };
        let dx = (sx - self.pan_x) * inv_zoom;
        let dy = (sy - self.pan_y) * inv_zoom;
        let (sin, cos) = self.rotation_rad.sin_cos();
        let cx = dx * cos + dy * sin;
        let cy = -dx * sin + dy * cos;
        (cx, cy)
    }
}

#[derive(Debug, Clone)]
struct ActiveStroke {
    base_radius: f32,
    color_rgba: [u8; 4],
    is_eraser: bool,
    last_point: Option<StrokePoint>,
    before_snapshots: HashMap<TileCoord, Option<Arc<TileData>>>,
    dirty_tiles: HashSet<TileCoord>,
}

/// Stateful v0.1 drawing session owned by the Rust core and driven from iPadOS UIKit.
#[derive(Debug)]
pub struct CanvasSession {
    pub spec: CanvasSpec,
    pub viewport: ViewportTransform,
    layer: TileLayer,
    history: TileUndoStack,
    stabilizer: RopeStabilizer,
    active_stroke: Option<ActiveStroke>,
    /// Temporary predicted-touch overlay points (cleared on every committed batch / stroke end).
    predicted_preview: Vec<StrokePoint>,
}

impl CanvasSession {
    pub fn from_preset(preset: CanvasPreset) -> Self {
        Self::from_spec(preset.spec())
    }

    pub fn from_spec(spec: CanvasSpec) -> Self {
        Self {
            spec,
            viewport: ViewportTransform::default(),
            layer: TileLayer::new(spec.width, spec.height),
            history: TileUndoStack::new(128),
            stabilizer: RopeStabilizer::new(0.0),
            active_stroke: None,
            predicted_preview: Vec::new(),
        }
    }

    pub fn layer(&self) -> &TileLayer {
        &self.layer
    }

    pub fn predicted_preview(&self) -> &[StrokePoint] {
        &self.predicted_preview
    }

    pub fn can_undo(&self) -> bool {
        self.history.can_undo()
    }

    pub fn can_redo(&self) -> bool {
        self.history.can_redo()
    }

    pub fn begin_stroke(
        &mut self,
        base_radius: f32,
        color_rgba: [u8; 4],
        is_eraser: bool,
        stabilizer_radius: f32,
    ) {
        self.stabilizer = RopeStabilizer::new(stabilizer_radius);
        self.predicted_preview.clear();
        self.active_stroke = Some(ActiveStroke {
            base_radius: base_radius.max(0.5),
            color_rgba,
            is_eraser,
            last_point: None,
            before_snapshots: HashMap::new(),
            dirty_tiles: HashSet::new(),
        });
    }

    /// Consumes a batch of raw UIKit samples (coalesced committed + predicted tail).
    /// Returns the tile coordinates dirtied by committed samples during this call.
    pub fn push_points(&mut self, points: &[StrokePoint]) -> Vec<TileCoord> {
        let mut frame_dirty = HashSet::new();
        self.predicted_preview.clear();

        if self.active_stroke.is_none() {
            return Vec::new();
        }

        for &sample in points {
            if sample.is_predicted {
                // Keep predicted points isolated so they never pollute committed tiles or undo history.
                self.predicted_preview.push(sample);
                continue;
            }

            let Some(stabilized) = self.stabilizer.push(sample) else {
                continue;
            };

            let (prev, base_radius, color, is_eraser) = {
                let s = self.active_stroke.as_ref().unwrap();
                (s.last_point, s.base_radius, s.color_rgba, s.is_eraser)
            };

            match prev {
                None => {
                    let r = (base_radius * stabilized.pressure.clamp(0.15, 1.0)).max(0.5);
                    self.stamp_disc(stabilized.x, stabilized.y, r, color, is_eraser, &mut frame_dirty);
                }
                Some(p0) => {
                    let dx = stabilized.x - p0.x;
                    let dy = stabilized.y - p0.y;
                    let dist = (dx * dx + dy * dy).sqrt();
                    let spacing = (base_radius * 0.25).max(0.75);
                    let steps = (dist / spacing).ceil().max(1.0) as usize;
                    for i in 1..=steps {
                        let t = i as f32 / steps as f32;
                        let x = p0.x + dx * t;
                        let y = p0.y + dy * t;
                        let pressure = p0.pressure + (stabilized.pressure - p0.pressure) * t;
                        let r = (base_radius * pressure.clamp(0.15, 1.0)).max(0.5);
                        self.stamp_disc(x, y, r, color, is_eraser, &mut frame_dirty);
                    }
                }
            }

            if let Some(s) = self.active_stroke.as_mut() {
                s.last_point = Some(stabilized);
            }
        }

        frame_dirty.into_iter().collect()
    }

    /// Finalizes the active stroke, committing CoW tile diffs into `TileUndoStack`.
    /// Returns all tile coordinates touched across the full stroke.
    pub fn end_stroke(&mut self) -> Vec<TileCoord> {
        self.predicted_preview.clear();
        self.stabilizer.reset();

        let Some(stroke) = self.active_stroke.take() else {
            return Vec::new();
        };

        let mut entries = Vec::with_capacity(stroke.before_snapshots.len());
        for (coord, before) in stroke.before_snapshots {
            let after = self.layer.get_tile(coord);
            entries.push((coord, before, after));
        }

        self.history.push(TileDiff { entries });
        stroke.dirty_tiles.into_iter().collect()
    }

    pub fn undo(&mut self) -> bool {
        self.predicted_preview.clear();
        self.history.undo(&mut self.layer)
    }

    pub fn redo(&mut self) -> bool {
        self.predicted_preview.clear();
        self.history.redo(&mut self.layer)
    }

    fn stamp_disc(
        &mut self,
        cx: f32,
        cy: f32,
        radius: f32,
        color: [u8; 4],
        is_eraser: bool,
        frame_dirty: &mut HashSet<TileCoord>,
    ) {
        let min_x = (cx - radius).floor().max(0.0) as u32;
        let max_x = (cx + radius).ceil().min((self.spec.width.saturating_sub(1)) as f32) as u32;
        let min_y = (cy - radius).floor().max(0.0) as u32;
        let max_y = (cy + radius).ceil().min((self.spec.height.saturating_sub(1)) as f32) as u32;
        let r2 = radius * radius;
        let pixel_val = if is_eraser { [0, 0, 0, 0] } else { color };

        for y in min_y..=max_y {
            let dy = y as f32 + 0.5 - cy;
            for x in min_x..=max_x {
                let dx = x as f32 + 0.5 - cx;
                if dx * dx + dy * dy <= r2 {
                    let (coord, _, _) = TileCoord::from_pixel(x as i32, y as i32);
                    if let Some(stroke) = self.active_stroke.as_mut() {
                        stroke
                            .before_snapshots
                            .entry(coord)
                            .or_insert_with(|| self.layer.get_tile(coord));
                    }
                    if let Some(touched) = self.layer.set_pixel(x, y, pixel_val) {
                        frame_dirty.insert(touched);
                        if let Some(stroke) = self.active_stroke.as_mut() {
                            stroke.dirty_tiles.insert(touched);
                        }
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn viewport_transform_round_trips_accurately() {
        let vp = ViewportTransform {
            pan_x: 120.5,
            pan_y: -45.25,
            zoom: 2.5,
            rotation_rad: 0.7,
        };
        let (sx, sy) = vp.canvas_to_screen(320.0, 640.0);
        let (cx, cy) = vp.screen_to_canvas(sx, sy);
        assert!((cx - 320.0).abs() < 1e-3);
        assert!((cy - 640.0).abs() < 1e-3);
    }

    #[test]
    fn predicted_touches_never_pollute_committed_tiles() {
        let mut session = CanvasSession::from_preset(CanvasPreset::B4PrintManga600Dpi);
        session.begin_stroke(4.0, [0, 0, 0, 255], false, 0.0);

        let committed = StrokePoint::simple(50.0, 50.0, 1.0);
        let mut predicted = StrokePoint::simple(500.0, 500.0, 1.0);
        predicted.is_predicted = true;

        let dirty = session.push_points(&[committed, predicted]);
        assert!(!dirty.is_empty());
        assert_eq!(session.predicted_preview().len(), 1);
        assert_eq!(session.layer().get_pixel(50, 50), [0, 0, 0, 255]);
        // Predicted touch location must remain transparent in committed tile store.
        assert_eq!(session.layer().get_pixel(500, 500), [0, 0, 0, 0]);

        session.end_stroke();
        assert!(session.predicted_preview().is_empty());
        assert!(session.can_undo());

        assert!(session.undo());
        assert_eq!(session.layer().get_pixel(50, 50), [0, 0, 0, 0]);
        assert_eq!(session.layer().allocated_tile_count(), 0);
    }
}
