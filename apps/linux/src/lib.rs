//! Touchscreen Linux Notebook / 2-in-1 Pad shell (`apps/linux`).
//!
//! Links directly to `manga-core` with zero FFI overhead and normalizes
//! Wayland `zwp_tablet_v2` stylus events + `libinput` multi-touch / 2-in-1
//! tablet-mode switches into shared engine primitives.

use std::f32::consts::FRAC_PI_2;
use std::path::Path;

use manga_core::{
    recommend_workspace_layout, CanvasPreset, CanvasSession, CreativeProjectManifest, FoldPosture,
    StrokePoint, TargetPlatform, WorkspaceLayoutHint,
};

/// Raw Wayland `zwp_tablet_v2` tool sample (pressure 0..65535, tilt in degrees).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WaylandTabletToolEvent {
    pub x: f32,
    pub y: f32,
    /// Wayland `zwp_tablet_tool_v2::pressure` normalized range `0..=65535`.
    pub pressure_raw: u32,
    /// Tilt along X/Y axes in degrees (`-90.0..=90.0`).
    pub tilt_x_deg: f32,
    pub tilt_y_deg: f32,
    /// Barrel rotation in degrees (`0.0..360.0`).
    pub rotation_deg: f32,
    pub timestamp_ms: f64,
    pub is_eraser_end: bool,
}

/// Converts Wayland `zwp_tablet_v2` events into deterministic `manga_core::StrokePoint`s.
pub struct WaylandTabletTouchAdapter;

impl WaylandTabletTouchAdapter {
    pub fn to_stroke_point(ev: WaylandTabletToolEvent) -> StrokePoint {
        let pressure = (ev.pressure_raw.min(65_535) as f32) / 65_535.0;
        let tilt_rad_x = ev.tilt_x_deg.to_radians();
        let tilt_rad_y = ev.tilt_y_deg.to_radians();
        let tilt_mag = (tilt_rad_x * tilt_rad_x + tilt_rad_y * tilt_rad_y)
            .sqrt()
            .min(FRAC_PI_2);
        let altitude = (FRAC_PI_2 - tilt_mag).max(0.0);
        let azimuth = tilt_rad_y.atan2(tilt_rad_x);

        StrokePoint {
            x: ev.x,
            y: ev.y,
            pressure,
            altitude,
            azimuth,
            roll_angle: ev.rotation_deg.to_radians(),
            timestamp_ms: ev.timestamp_ms,
            is_predicted: false,
        }
    }
}

/// Native Linux shell controller bridging GTK4/Wayland input, 2-in-1 tablet switch,
/// CPFF v1.0 `.prj` loader, and `manga_core::CanvasSession`.
pub struct LinuxStudioShell {
    pub session: CanvasSession,
    pub is_tablet_mode: bool,
    pub viewport_width_dp: f32,
    pub viewport_height_dp: f32,
}

impl LinuxStudioShell {
    pub fn new(preset: CanvasPreset, width_dp: f32, height_dp: f32) -> Self {
        Self {
            session: CanvasSession::from_preset(preset),
            is_tablet_mode: false,
            viewport_width_dp: width_dp,
            viewport_height_dp: height_dp,
        }
    }

    /// Updates layout posture when `libinput` `SW_TABLET_MODE` toggles on a 2-in-1 notebook.
    pub fn set_convertible_tablet_mode(&mut self, enabled: bool) {
        self.is_tablet_mode = enabled;
    }

    pub fn current_layout(&self) -> WorkspaceLayoutHint {
        let posture = if self.is_tablet_mode {
            FoldPosture::ConvertibleTabletMode
        } else {
            FoldPosture::Flat
        };
        recommend_workspace_layout(
            TargetPlatform::LinuxTouch,
            posture,
            self.viewport_width_dp,
            self.viewport_height_dp,
        )
    }

    pub fn open_project_manifest(project_dir: &Path) -> Result<CreativeProjectManifest, String> {
        let resolved = manga_core::resolve_prj_file(project_dir)?;
        let xml = std::fs::read_to_string(resolved.path())
            .map_err(|e| format!("Failed to read .prj manifest: {e}"))?;
        CreativeProjectManifest::parse_prj_xml(&xml)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wayland_tablet_event_normalizes_pressure_and_tilt() {
        let ev = WaylandTabletToolEvent {
            x: 120.5,
            y: 240.25,
            pressure_raw: 32_768,
            tilt_x_deg: 0.0,
            tilt_y_deg: 0.0,
            rotation_deg: 90.0,
            timestamp_ms: 42.0,
            is_eraser_end: false,
        };
        let pt = WaylandTabletTouchAdapter::to_stroke_point(ev);
        assert!((pt.pressure - 0.5).abs() < 0.01);
        assert!((pt.altitude - FRAC_PI_2).abs() < 0.001);
        assert!((pt.roll_angle - FRAC_PI_2).abs() < 0.001);
        assert!(!pt.is_predicted);
    }

    #[test]
    fn linux_shell_switches_between_desktop_touch_and_2in1_tablet_mode() {
        let mut shell = LinuxStudioShell::new(CanvasPreset::B4PrintManga600Dpi, 1440.0, 900.0);
        assert_eq!(shell.current_layout(), WorkspaceLayoutHint::DesktopTouchHybrid);

        shell.set_convertible_tablet_mode(true);
        assert_eq!(shell.current_layout(), WorkspaceLayoutHint::TabletTouchStudio);

        // Draw a Wayland stylus stroke directly into manga-core without FFI overhead.
        shell.session.begin_stroke(3.0, [0, 0, 0, 255], false, 0.0);
        let p = WaylandTabletTouchAdapter::to_stroke_point(WaylandTabletToolEvent {
            x: 64.0,
            y: 64.0,
            pressure_raw: 65_535,
            tilt_x_deg: 10.0,
            tilt_y_deg: 5.0,
            rotation_deg: 0.0,
            timestamp_ms: 1.0,
            is_eraser_end: false,
        });
        assert!(!shell.session.push_points(&[p]).is_empty());
        assert!(!shell.session.end_stroke().is_empty());
        assert_eq!(shell.session.layer().allocated_tile_count(), 1);
    }
}
