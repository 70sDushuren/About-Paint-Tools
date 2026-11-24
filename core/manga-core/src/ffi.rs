//! Zero-dependency C-ABI bridge for Apple (iPadOS / macOS Touch / iPhone Duo),
//! Android (JNI), Windows (P/Invoke), and Linux integrations.
//!
//! Matching C declarations live in `core/manga-core/include/manga_core.h`.

use std::ffi::{c_char, CStr};
use std::slice;

use crate::action_bus::{ActionBus, ActionCommand, ActionPlan, ProjectDocument};
use crate::canvas::CanvasSession;
use crate::fill::{close_gap_expand_fill, FillOptions};
use crate::layer::{BlendMode, LayerId};
use crate::panel::{PanelId, PanelLayout};
use crate::platform::{recommend_workspace_layout, FoldPosture, TargetPlatform};
use crate::preset::CanvasPreset;
use crate::stroke::StrokePoint;
use crate::suite::{can_write_relative_path, SuiteApp};
use crate::vector::VectorNode;

/// C-compatible stylus input struct matching `CMangaStrokePoint` in `manga_core.h`.
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

fn blend_mode_from_u32(code: u32) -> BlendMode {
    match code {
        1 => BlendMode::Multiply,
        2 => BlendMode::Screen,
        3 => BlendMode::Overlay,
        4 => BlendMode::GlowDodge,
        5 => BlendMode::LinearBurn,
        6 => BlendMode::HardLight,
        7 => BlendMode::SoftLight,
        8 => BlendMode::Darken,
        9 => BlendMode::Lighten,
        10 => BlendMode::ColorBurn,
        11 => BlendMode::ColorDodge,
        12 => BlendMode::Add,
        _ => BlendMode::Normal,
    }
}

unsafe fn cstr_to_string(ptr: *const c_char, fallback: &str) -> String {
    if ptr.is_null() {
        return fallback.to_string();
    }
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map(|s| s.to_string())
        .unwrap_or_else(|_| fallback.to_string())
}

// ============================================================================
// Single-Canvas Low-Latency Drawing Handle (`MangaCanvasHandle`)
// ============================================================================

/// Opaque handle passed across FFI boundaries for v0.1 single-canvas drawing.
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

// ============================================================================
// Full Project Handle (`MangaProjectHandle`: Layers, Fill, Vector, Panels, ActionBus)
// ============================================================================

/// Opaque handle owning a full dual-track `ProjectDocument`, `PanelLayout`, and `ActionBus`.
pub struct MangaProjectHandle {
    doc: ProjectDocument,
    panels: PanelLayout,
    bus: ActionBus,
}

#[no_mangle]
pub extern "C" fn manga_project_create_preset(preset_code: u32) -> *mut MangaProjectHandle {
    let Some(preset) = CanvasPreset::from_u32(preset_code) else {
        return std::ptr::null_mut();
    };
    let doc = ProjectDocument::from_preset(preset);
    let margin_x = (doc.spec.width as f32 * 0.05).max(16.0);
    let margin_y = (doc.spec.height as f32 * 0.05).max(16.0);
    let panels = PanelLayout::new_page_frame(
        doc.spec.width as f32,
        doc.spec.height as f32,
        margin_x,
        margin_y,
    );
    Box::into_raw(Box::new(MangaProjectHandle {
        doc,
        panels,
        bus: ActionBus::new(),
    }))
}

/// # Safety
/// `handle` must be null or a pointer previously returned by `manga_project_create_preset`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_destroy(handle: *mut MangaProjectHandle) {
    if !handle.is_null() {
        drop(unsafe { Box::from_raw(handle) });
    }
}

/// # Safety
/// `handle` must be valid; `name_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_project_add_raster_layer(
    handle: *mut MangaProjectHandle,
    name_utf8: *const c_char,
    blend_mode_code: u32,
    clipping_mask: u8,
    is_reference: u8,
) -> u64 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let name = unsafe { cstr_to_string(name_utf8, "Layer") };
    let plan = ActionPlan {
        title: format!("Create layer {name}"),
        commands: vec![ActionCommand::CreateRasterLayer {
            name: name.clone(),
            blend_mode: blend_mode_from_u32(blend_mode_code),
            clipping_mask: clipping_mask != 0,
            is_reference: is_reference != 0,
        }],
    };
    h.bus.execute(&mut h.doc, &plan);
    h.doc
        .layers
        .layers()
        .last()
        .map(|l| l.id.0)
        .unwrap_or(0)
}

/// # Safety
/// `handle` must be null or a valid `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_layer_count(handle: *const MangaProjectHandle) -> usize {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    h.doc.layers.layers().len()
}

/// Batch-tints, adjusts opacity, and locks all layers matching `prefix_utf8` inside one `ActionBus` UndoGroup.
///
/// # Safety
/// `handle` must be valid; `prefix_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_project_batch_tint_layers(
    handle: *mut MangaProjectHandle,
    prefix_utf8: *const c_char,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    opacity: f32,
    lock: u8,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let prefix = unsafe { cstr_to_string(prefix_utf8, "") };
    let plan = ActionPlan {
        title: format!("Batch tint '{prefix}*'"),
        commands: vec![ActionCommand::BatchTintLayers {
            name_prefix: prefix,
            tint_rgba: [r, g, b, a],
            opacity,
            lock: lock != 0,
        }],
    };
    let preview = h.bus.preview(&h.doc, &plan);
    h.bus.execute(&mut h.doc, &plan);
    preview.matched_layers
}

/// Runs Close-Gap + Edge-Expand anti-halo fill onto `layer_id`. Returns count of filled pixels.
///
/// # Safety
/// `handle` must be null or a valid mutable `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_close_gap_fill(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    seed_x: u32,
    seed_y: u32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    close_gap_px: u8,
    expand_px: u8,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let res = close_gap_expand_fill(
        &mut h.doc.layers,
        LayerId(layer_id),
        seed_x,
        seed_y,
        [r, g, b, a],
        FillOptions {
            close_gap_px,
            expand_px,
            ..Default::default()
        },
    );
    res.filled_pixels
}

/// Adds a variable-width vector stroke from parallel `(xs, ys, widths)` arrays.
///
/// # Safety
/// `handle` must be valid, and `xs`, `ys`, `widths` must each point to `count` valid `f32` elements.
#[no_mangle]
pub unsafe extern "C" fn manga_project_add_vector_stroke(
    handle: *mut MangaProjectHandle,
    xs: *const f32,
    ys: *const f32,
    widths: *const f32,
    count: usize,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> u64 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    if xs.is_null() || ys.is_null() || widths.is_null() || count < 2 {
        return 0;
    }
    let x_slice = unsafe { slice::from_raw_parts(xs, count) };
    let y_slice = unsafe { slice::from_raw_parts(ys, count) };
    let w_slice = unsafe { slice::from_raw_parts(widths, count) };
    let nodes: Vec<VectorNode> = (0..count)
        .map(|i| VectorNode {
            x: x_slice[i],
            y: y_slice[i],
            width: w_slice[i],
        })
        .collect();
    h.doc
        .vectors
        .add_stroke([r, g, b, a], nodes)
        .map(|id| id.0)
        .unwrap_or(0)
}

/// # Safety
/// `handle` must be null or a valid mutable `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_vector_erase_intersection(
    handle: *mut MangaProjectHandle,
    hit_x: f32,
    hit_y: f32,
    hit_radius: f32,
) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    u8::from(h.doc.vectors.erase_to_intersection(hit_x, hit_y, hit_radius))
}

/// # Safety
/// `handle` must be null or a valid `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_vector_stroke_count(handle: *const MangaProjectHandle) -> usize {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    h.doc.vectors.strokes().len()
}

/// Slices `panel_id` along `(ax, ay) -> (bx, by)` with `gutter_px` spacing.
/// Returns the updated total panel count (`0` if the slice missed or failed).
///
/// # Safety
/// `handle` must be null or a valid mutable `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_slice_panel(
    handle: *mut MangaProjectHandle,
    panel_id: u64,
    ax: f32,
    ay: f32,
    bx: f32,
    by: f32,
    gutter_px: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    if h.panels
        .slice_panel(PanelId(panel_id), (ax, ay), (bx, by), gutter_px)
        .is_some()
    {
        h.panels.panels().len()
    } else {
        0
    }
}

/// # Safety
/// `handle` must be null or a valid `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_panel_count(handle: *const MangaProjectHandle) -> usize {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    h.panels.panels().len()
}

/// # Safety
/// `handle` must be null or a valid mutable `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_undo_action(handle: *mut MangaProjectHandle) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    u8::from(h.bus.undo_last(&mut h.doc))
}

/// # Safety
/// `handle` must be null or a valid mutable `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_redo_action(handle: *mut MangaProjectHandle) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    u8::from(h.bus.redo_last(&mut h.doc))
}

// ============================================================================
// Cross-Platform Posture & Adaptive Workspace Layout C-ABI
// ============================================================================

/// Returns a deterministic `MangaWorkspaceLayout` code for any `(platform, posture, width_dp, height_dp)`.
#[no_mangle]
pub extern "C" fn manga_platform_recommend_layout(
    platform_code: u32,
    posture_code: u32,
    width_dp: f32,
    height_dp: f32,
) -> u32 {
    let platform = TargetPlatform::from_u32(platform_code).unwrap_or(TargetPlatform::IpadOs);
    let posture = FoldPosture::from_u32(posture_code).unwrap_or(FoldPosture::Flat);
    recommend_workspace_layout(platform, posture, width_dp, height_dp) as u32
}

/// Returns the release wave (`1` for v0.9/v1.0 Apple trio, `2` for post-v1.0 Android/Windows/Linux, `0` if unknown).
#[no_mangle]
pub extern "C" fn manga_platform_release_wave(platform_code: u32) -> u8 {
    TargetPlatform::from_u32(platform_code)
        .map(TargetPlatform::release_wave)
        .unwrap_or(0)
}

// ============================================================================
// Tri-App Suite (Working Codenames: Hub / Manga / Novel) Boundary C-ABI
// ============================================================================

/// Returns `1` if `app_code` is allowed to write `rel_path_utf8` under CPFF v1.0 write ownership, else `0`.
///
/// # Safety
/// `rel_path_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_can_write_path(
    app_code: u32,
    rel_path_utf8: *const c_char,
) -> u8 {
    let Some(app) = SuiteApp::from_u32(app_code) else {
        return 0;
    };
    let rel = unsafe { cstr_to_string(rel_path_utf8, "") };
    u8::from(can_write_relative_path(app, &rel).is_ok())
}

/// Returns standalone RAM budget in MB for `app_code` (`0` if unknown).
#[no_mangle]
pub extern "C" fn manga_suite_ram_budget_mb(app_code: u32) -> u32 {
    SuiteApp::from_u32(app_code)
        .map(|a| a.metadata().standalone_ram_budget_mb)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::platform::WorkspaceLayoutHint;
    use std::ffi::CString;

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

    #[test]
    fn c_abi_project_handle_layers_vectors_panels_and_action_undo() {
        unsafe {
            let p = manga_project_create_preset(CanvasPreset::B4PrintManga600Dpi as u32);
            assert!(!p.is_null());
            assert_eq!(manga_project_panel_count(p), 1);

            let sketch_name = CString::new("Sketch_1").unwrap();
            let prefix = CString::new("Sketch_").unwrap();
            let lid = manga_project_add_raster_layer(p, sketch_name.as_ptr(), 0, 0, 0);
            assert!(lid > 0);
            assert_eq!(manga_project_layer_count(p), 1);

            let tinted = manga_project_batch_tint_layers(p, prefix.as_ptr(), 77, 166, 255, 255, 0.3, 1);
            assert_eq!(tinted, 1);

            // Undo tint, then undo layer creation via ActionBus!
            assert_eq!(manga_project_undo_action(p), 1);
            assert_eq!(manga_project_undo_action(p), 1);
            assert_eq!(manga_project_layer_count(p), 0);
            assert_eq!(manga_project_redo_action(p), 1);
            assert_eq!(manga_project_layer_count(p), 1);

            // Add crossed vector strokes and trim overshoot via C-ABI.
            let hx = [0.0f32, 100.0];
            let hy = [50.0f32, 50.0];
            let hw = [2.0f32, 2.0];
            assert!(manga_project_add_vector_stroke(p, hx.as_ptr(), hy.as_ptr(), hw.as_ptr(), 2, 0, 0, 0, 255) > 0);

            let vx = [50.0f32, 50.0];
            let vy = [0.0f32, 100.0];
            assert!(manga_project_add_vector_stroke(p, vx.as_ptr(), vy.as_ptr(), hw.as_ptr(), 2, 0, 0, 0, 255) > 0);
            assert_eq!(manga_project_vector_stroke_count(p), 2);
            assert_eq!(manga_project_vector_erase_intersection(p, 80.0, 50.0, 5.0), 1);

            // Slice page panel diagonally.
            let new_count = manga_project_slice_panel(p, 1, 0.0, 3000.0, 6071.0, 5000.0, 40.0);
            assert_eq!(new_count, 2);

            manga_project_destroy(p);
        }
    }

    #[test]
    fn c_abi_platform_layout_and_wave_match_contract() {
        assert_eq!(manga_platform_release_wave(TargetPlatform::IpadOs as u32), 1);
        assert_eq!(manga_platform_release_wave(TargetPlatform::MacOsTouch as u32), 1);
        assert_eq!(manga_platform_release_wave(TargetPlatform::IphoneDuo as u32), 1);
        assert_eq!(manga_platform_release_wave(TargetPlatform::AndroidPadFoldable as u32), 2);
        assert_eq!(manga_platform_release_wave(TargetPlatform::WindowsTouch as u32), 2);
        assert_eq!(manga_platform_release_wave(TargetPlatform::LinuxTouch as u32), 2);
        assert_eq!(manga_platform_release_wave(99), 0);

        let duo_unfolded = manga_platform_recommend_layout(
            TargetPlatform::IphoneDuo as u32,
            FoldPosture::UnfoldedDualPane as u32,
            780.0,
            844.0,
        );
        assert_eq!(duo_unfolded, WorkspaceLayoutHint::DualPaneAcrossHinge as u32);
    }

    #[test]
    fn c_abi_suite_write_ownership_and_ram_budget_match_contract() {
        unsafe {
            let novel_path = CString::new("chapters/ch001/novel/prose/zh-Hans.md").unwrap();
            let manga_path = CString::new("chapters/ch001/manuscript/p001.mnga").unwrap();
            assert_eq!(manga_suite_can_write_path(SuiteApp::Novel as u32, novel_path.as_ptr()), 1);
            assert_eq!(manga_suite_can_write_path(SuiteApp::Manga as u32, novel_path.as_ptr()), 0);
            assert_eq!(manga_suite_can_write_path(SuiteApp::Manga as u32, manga_path.as_ptr()), 1);
            assert_eq!(manga_suite_can_write_path(SuiteApp::Novel as u32, manga_path.as_ptr()), 0);
            assert_eq!(manga_suite_ram_budget_mb(SuiteApp::Novel as u32), 120);
            assert_eq!(manga_suite_ram_budget_mb(SuiteApp::Hub as u32), 200);
        }
    }
}
