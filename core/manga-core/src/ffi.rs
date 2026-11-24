//! Zero-dependency C-ABI bridge for iPadOS Swift/UIKit integration (T0.1-02).
//!
//! Matching C declarations live in `core/manga-core/include/manga_core.h`.

use std::slice;

use crate::canvas::CanvasSession;
use crate::preset::CanvasPreset;
use crate::stroke::StrokePoint;

/// C-compatible stylus input struct matching `MangaStrokePoint` in `manga_core.h`.
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct CMangaStrokePoint {
    pub x: f32,
    pub y: f32,
    pub pressure: f32,
    pub altitude: f32,
    pub azimuth: f32,
    pub roll_angle: f32,
    pub timestamp_ms: f64,
    pub is_predicted: u8,
}

impl From<CMangaStrokePoint> for StrokePoint {
    fn from(p: CMangaStrokePoint) -> Self {
        Self {
            x: p.x,
            y: p.y,
            pressure: p.pressure.clamp(0.0, 1.0),
            altitude: p.altitude,
            azimuth: p.azimuth,
            roll_angle: p.roll_angle,
            timestamp_ms: p.timestamp_ms,
            is_predicted: p.is_predicted != 0,
        }
    }
}

/// Opaque handle passed across FFI boundaries.
pub struct MangaCanvasHandle {
    session: CanvasSession,
}

#[no_mangle]
pub extern "C" fn manga_canvas_create_preset(preset_code: u32) -> *mut MangaCanvasHandle {
    let Some(preset) = CanvasPreset::from_u32(preset_code) else {
        return std::ptr::null_mut();
    };
    let handle = Box::new(MangaCanvasHandle {
        session: CanvasSession::from_preset(preset),
    });
    Box::into_raw(handle)
}

/// # Safety
/// `handle` must be null or a pointer previously returned by `manga_canvas_create_preset`.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_destroy(handle: *mut MangaCanvasHandle) {
    if !handle.is_null() {
        drop(unsafe { Box::from_raw(handle) });
    }
}

/// # Safety
/// `handle` must be null or a valid `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_width(handle: *const MangaCanvasHandle) -> u32 {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    h.session.spec.width
}

/// # Safety
/// `handle` must be null or a valid `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_height(handle: *const MangaCanvasHandle) -> u32 {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    h.session.spec.height
}

/// # Safety
/// `handle` must be null or a valid `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_allocated_tiles(handle: *const MangaCanvasHandle) -> usize {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    h.session.layer().allocated_tile_count()
}

/// # Safety
/// `handle` must be null or a valid mutable `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_set_viewport(
    handle: *mut MangaCanvasHandle,
    pan_x: f32,
    pan_y: f32,
    zoom: f32,
    rotation_rad: f32,
) {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return;
    };
    h.session.viewport.pan_x = pan_x;
    h.session.viewport.pan_y = pan_y;
    h.session.viewport.zoom = zoom.max(0.05);
    h.session.viewport.rotation_rad = rotation_rad;
}

/// # Safety
/// `handle` must be null or a valid mutable `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_begin_stroke(
    handle: *mut MangaCanvasHandle,
    base_radius: f32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    is_eraser: u8,
    stabilizer_radius: f32,
) {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return;
    };
    h.session
        .begin_stroke(base_radius, [r, g, b, a], is_eraser != 0, stabilizer_radius);
}

/// Pushes a batch of 240Hz coalesced + predicted points.
/// Returns the number of tiles dirtied by committed samples during this call.
///
/// # Safety
/// `handle` must be valid, and if `count > 0`, `points` must point to `count` valid elements.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_push_points(
    handle: *mut MangaCanvasHandle,
    points: *const CMangaStrokePoint,
    count: usize,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    if points.is_null() || count == 0 {
        return 0;
    }
    let raw = unsafe { slice::from_raw_parts(points, count) };
    let converted: Vec<StrokePoint> = raw.iter().copied().map(StrokePoint::from).collect();
    h.session.push_points(&converted).len()
}

/// Finalizes the active stroke and commits it to the undo stack.
/// Returns total tiles dirtied by the stroke.
///
/// # Safety
/// `handle` must be null or a valid mutable `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_end_stroke(handle: *mut MangaCanvasHandle) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    h.session.end_stroke().len()
}

/// # Safety
/// `handle` must be null or a valid mutable `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_undo(handle: *mut MangaCanvasHandle) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    u8::from(h.session.undo())
}

/// # Safety
/// `handle` must be null or a valid mutable `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_redo(handle: *mut MangaCanvasHandle) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    u8::from(h.session.redo())
}

/// Packs an RGBA8 pixel into `0xRRGGBBAA` for diagnostics and cross-language verification tests.
///
/// # Safety
/// `handle` must be null or a valid `MangaCanvasHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_canvas_get_pixel_rgba(
    handle: *const MangaCanvasHandle,
    x: u32,
    y: u32,
) -> u32 {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    let [r, g, b, a] = h.session.layer().get_pixel(x, y);
    u32::from_be_bytes([r, g, b, a])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn c_abi_end_to_end_stroke_undo_redo_lifecycle() {
        unsafe {
            assert!(manga_canvas_create_preset(999).is_null());

            let h = manga_canvas_create_preset(CanvasPreset::WebtoonStrip800 as u32);
            assert!(!h.is_null());
            assert_eq!(manga_canvas_width(h), 800);
            assert_eq!(manga_canvas_height(h), 12800);
            assert_eq!(manga_canvas_allocated_tiles(h), 0);

            manga_canvas_begin_stroke(h, 3.0, 0x11, 0x22, 0x33, 0xFF, 0, 0.0);
            let pts = [
                CMangaStrokePoint {
                    x: 100.0,
                    y: 200.0,
                    pressure: 1.0,
                    altitude: 1.5,
                    azimuth: 0.0,
                    roll_angle: 0.0,
                    timestamp_ms: 1.0,
                    is_predicted: 0,
                },
                CMangaStrokePoint {
                    x: 400.0,
                    y: 400.0,
                    pressure: 1.0,
                    altitude: 1.5,
                    azimuth: 0.0,
                    roll_angle: 0.0,
                    timestamp_ms: 5.0,
                    is_predicted: 1,
                },
            ];
            let dirty = manga_canvas_push_points(h, pts.as_ptr(), pts.len());
            assert_eq!(dirty, 1);
            assert_eq!(manga_canvas_get_pixel_rgba(h, 100, 200), 0x112233FF);
            assert_eq!(manga_canvas_get_pixel_rgba(h, 400, 400), 0x00000000);

            let total_dirty = manga_canvas_end_stroke(h);
            assert_eq!(total_dirty, 1);
            assert_eq!(manga_canvas_allocated_tiles(h), 1);

            assert_eq!(manga_canvas_undo(h), 1);
            assert_eq!(manga_canvas_get_pixel_rgba(h, 100, 200), 0x00000000);
            assert_eq!(manga_canvas_allocated_tiles(h), 0);

            assert_eq!(manga_canvas_redo(h), 1);
            assert_eq!(manga_canvas_get_pixel_rgba(h, 100, 200), 0x112233FF);

            manga_canvas_destroy(h);
        }
    }
}
