//! Zero-dependency C-ABI bridge for Apple (iPadOS / macOS Touch / iPhone Duo),
//! Android (JNI), Windows (P/Invoke), and Linux integrations.
//!
//! Matching C declarations live in `core/manga-core/include/manga_core.h`.

use std::ffi::{c_char, CStr};
use std::slice;

use crate::action_bus::{ActionBus, ActionCommand, ActionPlan, ProjectDocument};
use crate::canvas::CanvasSession;
use crate::fill::FillOptions;
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
    BlendMode::from_u32(code)
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

/// Opaque handle owning a full dual-track `ProjectDocument`, `PanelLayout`, `ActionBus`,
/// active `SelectionMask`, and CoW `LayerStack` undo/redo history.
pub struct MangaProjectHandle {
    doc: ProjectDocument,
    panels: PanelLayout,
    bus: ActionBus,
    active_selection: Option<crate::selection::SelectionMask>,
    undo_snapshots: Vec<crate::layer::LayerStack>,
    redo_snapshots: Vec<crate::layer::LayerStack>,
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
        active_selection: None,
        undo_snapshots: Vec::new(),
        redo_snapshots: Vec::new(),
    }))
}

/// Allocates a custom-resolution `MangaProjectHandle` (e.g. `800×1132` interactive working buffer).
#[no_mangle]
pub extern "C" fn manga_project_create_custom(width: u32, height: u32) -> *mut MangaProjectHandle {
    let w = width.clamp(64, 8192);
    let h = height.clamp(64, 16384);
    let mut doc = ProjectDocument::from_preset(CanvasPreset::Illustration4K);
    doc.spec.width = w;
    doc.spec.height = h;
    doc.layers = crate::layer::LayerStack::new(w, h);
    let margin_x = (w as f32 * 0.05).max(16.0);
    let margin_y = (h as f32 * 0.05).max(16.0);
    let panels = PanelLayout::new_page_frame(w as f32, h as f32, margin_x, margin_y);
    Box::into_raw(Box::new(MangaProjectHandle {
        doc,
        panels,
        bus: ActionBus::new(),
        active_selection: None,
        undo_snapshots: Vec::new(),
        redo_snapshots: Vec::new(),
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
    let res = crate::raster_ops::close_gap_fill_with_selection(
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
        h.active_selection.as_ref(),
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

// ============================================================================
// v0.2.1 Tri-App Core C-ABI (S1 Project Init, S2 Brush Dynamics, S3 Novel Core)
// ============================================================================

/// Bootstraps a new dual-engine CPFF v1.0 project at `<parent_dir>/<folder_name>/`.
/// Returns `1` on success, `0` on invalid input or I/O error.
///
/// # Safety
/// Pointer parameters must be null or valid NUL-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn manga_hub_init_project(
    parent_dir_utf8: *const c_char,
    folder_name_utf8: *const c_char,
    author_utf8: *const c_char,
) -> u8 {
    let parent = unsafe { cstr_to_string(parent_dir_utf8, "") };
    let folder = unsafe { cstr_to_string(folder_name_utf8, "") };
    let author = unsafe { cstr_to_string(author_utf8, "Creator") };
    if parent.is_empty() || folder.is_empty() {
        return 0;
    }
    let opts = crate::project_init::ProjectInitOptions::dual_engine_default(&folder, &author);
    u8::from(crate::project_init::init_cpff_project(std::path::Path::new(&parent), &opts).is_ok())
}

/// Returns the number of built-in dual-track starter brush presets (`8`).
#[no_mangle]
pub extern "C" fn manga_brush_preset_count() -> u32 {
    crate::brush::starter_brush_presets().len() as u32
}

/// Samples effective brush radius in pixels for `preset_code`, `pressure`, and stylus `altitude`.
#[no_mangle]
pub extern "C" fn manga_brush_sample_radius(
    preset_code: u32,
    pressure: f32,
    altitude: f32,
) -> f32 {
    let presets = crate::brush::starter_brush_presets();
    let Some(id) = crate::brush::BrushPresetId::from_u32(preset_code) else {
        return 0.0;
    };
    crate::brush::sample_effective_radius(&presets[id as usize], pressure, altitude)
}

/// Computes zoom-adaptive rope stabilizer radius in canvas pixels.
#[no_mangle]
pub extern "C" fn manga_brush_zoom_adaptive_rope(base_screen_px: f32, viewport_zoom: f32) -> f32 {
    crate::brush::zoom_adaptive_rope_radius(base_screen_px, viewport_zoom)
}

/// Counts combined CJK characters + Latin words for light novel prose (`S3 v0.2.1`).
///
/// # Safety
/// `text_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_novel_count_units(text_utf8: *const c_char) -> usize {
    let text = unsafe { cstr_to_string(text_utf8, "") };
    crate::novel::count_novel_words(&text).total_units
}

/// Resolves a CPFF v1.0 `.prj` folder (`S1 v0.2.3`):
/// returns `1` for exact match, `2` for `RenamedFolderFallback`, or `0` on invalid/missing.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_hub_resolve_prj_status(project_dir_utf8: *const c_char) -> u32 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    match crate::project::resolve_prj_file(std::path::Path::new(&dir)) {
        Ok(crate::project::PrjResolution::ExactMatch(_)) => 1,
        Ok(crate::project::PrjResolution::RenamedFolderFallback { .. }) => 2,
        Err(_) => 0,
    }
}

/// Evaluates deterministic brush stamping count over a stylus point sequence (`S2 v0.2.3`).
///
/// # Safety
/// `points` must point to `count` valid `CMangaStrokePoint` elements (or be null when `count == 0`).
#[no_mangle]
pub unsafe extern "C" fn manga_brush_generate_stamp_count(
    preset_code: u32,
    points: *const CMangaStrokePoint,
    count: usize,
) -> usize {
    if points.is_null() || count == 0 {
        return 0;
    }
    let presets = crate::brush::starter_brush_presets();
    let Some(id) = crate::brush::BrushPresetId::from_u32(preset_code) else {
        return 0;
    };
    let raw = unsafe { slice::from_raw_parts(points, count) };
    let pts: Vec<StrokePoint> = raw
        .iter()
        .map(|p| StrokePoint {
            x: p.x,
            y: p.y,
            pressure: p.pressure,
            altitude: p.altitude,
            azimuth: p.azimuth,
            roll_angle: p.roll_angle,
            timestamp_ms: p.timestamp_ms,
            is_predicted: p.is_predicted != 0,
        })
        .collect();
    crate::brush::BrushStampingEngine::generate_stamps(&presets[id as usize], &pts).len()
}

/// Atomically writes light novel prose under `chapters/*/novel/prose/<lang>.md` (`S3 v0.2.3`).
/// Enforces `SuiteApp::Novel` write ownership and `locked="true"` protection. Returns `1` on success, `0` on rejection.
///
/// # Safety
/// All non-null string pointers must be valid NUL-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn manga_novel_save_prose_atomic(
    project_dir_utf8: *const c_char,
    rel_path_utf8: *const c_char,
    markdown_utf8: *const c_char,
    is_locked: u8,
    explicit_human_edit: u8,
) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let rel = unsafe { cstr_to_string(rel_path_utf8, "") };
    let body = unsafe { cstr_to_string(markdown_utf8, "") };
    if dir.is_empty() || rel.is_empty() {
        return 0;
    }
    match crate::novel::write_novel_prose_atomic(
        std::path::Path::new(&dir),
        &rel,
        &body,
        is_locked != 0,
        explicit_human_edit != 0,
    ) {
        Ok(_) => 1,
        Err(_) => 0,
    }
}

/// Runs the `S4` Tri-App Compatibility Gate plus optional `T0.2-S4` concurrency soak rounds (`soak_rounds`).
/// Returns `1` if all checks pass, `0` otherwise.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_s4_gate(
    project_dir_utf8: *const c_char,
    soak_rounds: u32,
) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    let path = std::path::Path::new(&dir);
    let ok = if soak_rounds > 0 {
        crate::suite::run_t02_s4_concurrency_soak(path, soak_rounds as usize).is_ok()
    } else {
        crate::suite::run_tri_app_compatibility_check(path).is_ok()
    };
    u8::from(ok)
}

/// Atomically upserts a character into `bible/characters.xml` under `SuiteApp::Hub` (`S1 v0.3.1`).
///
/// # Safety
/// All non-null string pointers must be valid NUL-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn manga_bible_upsert_character(
    project_dir_utf8: *const c_char,
    id_utf8: *const c_char,
    name_zh_utf8: *const c_char,
    name_en_utf8: *const c_char,
    role_utf8: *const c_char,
    palette_hex_utf8: *const c_char,
) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let id = unsafe { cstr_to_string(id_utf8, "") };
    if dir.is_empty() || id.is_empty() {
        return 0;
    }
    let name_zh = unsafe { cstr_to_string(name_zh_utf8, "") };
    let name_en = unsafe { cstr_to_string(name_en_utf8, "") };
    let role = unsafe { cstr_to_string(role_utf8, "supporting") };
    let palette_hex = unsafe { cstr_to_string(palette_hex_utf8, "#4F7CFF") };
    let root = std::path::Path::new(&dir);
    let mut bible = match crate::bible::StoryBible::load_from_project(root) {
        Ok(b) => b,
        Err(_) => return 0,
    };
    bible.upsert_character(crate::bible::BibleCharacter {
        id,
        name_zh,
        name_en,
        role,
        palette_hex,
        visual_anchors: Vec::new(),
    });
    u8::from(bible.save_atomic(root).is_ok())
}

/// Returns the character count currently stored in `bible/characters.xml` (`S1`/`S2`/`S3` RO).
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_bible_character_count(project_dir_utf8: *const c_char) -> usize {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    crate::bible::StoryBible::load_from_project(std::path::Path::new(&dir))
        .map(|b| b.characters.len())
        .unwrap_or(0)
}

/// Computes fast `< 1ms` revision hash of Story Bible + TOC for `S2`/`S3` hot-reload (`v0.3.1`).
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_bible_revision_hash(project_dir_utf8: *const c_char) -> u64 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    crate::bible::story_bible_revision_hash(std::path::Path::new(&dir))
}

/// Updates layer flags (`R` reference, `✂` clipping, `🔒` alpha lock, `B` blue sketch tint,
/// 13 cel blend modes, visibility, opacity) on a live `MangaProjectHandle` (`S2 v0.3.1`).
///
/// # Safety
/// `handle` must be null or a valid mutable `MangaProjectHandle` pointer.
#[no_mangle]
pub unsafe extern "C" fn manga_project_set_layer_flags(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    visible: u8,
    alpha_lock: u8,
    clipping_mask: u8,
    is_reference: u8,
    blend_mode_code: u32,
    opacity: f32,
    blue_sketch_tint: u8,
) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    layer.visible = visible != 0;
    layer.alpha_lock = alpha_lock != 0;
    layer.clipping_mask = clipping_mask != 0;
    layer.is_reference = is_reference != 0;
    layer.blend_mode = blend_mode_from_u32(blend_mode_code);
    layer.opacity = opacity.clamp(0.0, 1.0);
    layer.tint_rgba = if blue_sketch_tint != 0 {
        Some([77, 166, 255, 255])
    } else {
        None
    };
    1
}

unsafe fn write_utf8_to_c_buf(text: &str, out_buf: *mut c_char, out_cap: usize) -> usize {
    if out_buf.is_null() || out_cap == 0 {
        return 0;
    }
    let bytes = text.as_bytes();
    let max_copy = out_cap.saturating_sub(1);
    let mut n = bytes.len().min(max_copy);
    // Avoid splitting multi-byte UTF-8 characters when truncated.
    while n > 0 && !text.is_char_boundary(n) {
        n -= 1;
    }
    unsafe {
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), out_buf.cast::<u8>(), n);
        *out_buf.add(n) = 0;
    }
    n
}

/// Reads tab-delimited Story Bible summary lines into caller-owned UTF-8 buffer (`S1`/`S3` RO, `v0.3.2`).
/// Returns bytes written (excluding NUL terminator).
///
/// # Safety
/// `project_dir_utf8` must be a valid NUL-terminated string; `out_buf` must have capacity `out_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_bible_read_summary(
    project_dir_utf8: *const c_char,
    out_buf: *mut c_char,
    out_cap: usize,
) -> usize {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    let Ok(bible) = crate::bible::StoryBible::load_from_project(std::path::Path::new(&dir)) else {
        return 0;
    };
    let summary = bible.export_summary_lines();
    unsafe { write_utf8_to_c_buf(&summary, out_buf, out_cap) }
}

/// Atomically upserts a chapter entry into `outline/toc.xml` under `SuiteApp::Hub` (`S1 v0.3.2`).
///
/// # Safety
/// All non-null string pointers must be valid NUL-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn manga_toc_upsert_entry(
    project_dir_utf8: *const c_char,
    chapter_id_utf8: *const c_char,
    number: u32,
    title_zh_utf8: *const c_char,
    title_en_utf8: *const c_char,
    status_utf8: *const c_char,
) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let chapter_id = unsafe { cstr_to_string(chapter_id_utf8, "") };
    if dir.is_empty() || chapter_id.is_empty() {
        return 0;
    }
    let title_zh = unsafe { cstr_to_string(title_zh_utf8, "") };
    let title_en = unsafe { cstr_to_string(title_en_utf8, "") };
    let status = unsafe { cstr_to_string(status_utf8, "draft") };
    let root = std::path::Path::new(&dir);
    let mut toc = match crate::bible::ProjectToc::load_from_project(root) {
        Ok(t) => t,
        Err(_) => return 0,
    };
    toc.upsert_entry(crate::bible::TocChapterEntry {
        chapter_id,
        number,
        title_zh,
        title_en,
        status,
    });
    u8::from(toc.save_atomic(root).is_ok())
}

/// Reads tab-delimited Master TOC summary lines into caller-owned UTF-8 buffer (`S1`/`S3` RO, `v0.3.2`).
/// Returns bytes written (excluding NUL terminator).
///
/// # Safety
/// `project_dir_utf8` must be a valid NUL-terminated string; `out_buf` must have capacity `out_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_toc_read_summary(
    project_dir_utf8: *const c_char,
    out_buf: *mut c_char,
    out_cap: usize,
) -> usize {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    let Ok(toc) = crate::bible::ProjectToc::load_from_project(std::path::Path::new(&dir)) else {
        return 0;
    };
    let summary = toc.export_summary_lines();
    unsafe { write_utf8_to_c_buf(&summary, out_buf, out_cap) }
}

/// Executes the **`T0.3-S4` Story Bible Hot-Reload (`< 300ms`) & 13-Mode Cel Layer Gate**.
/// Returns `1` on PASS, `0` on failure.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_t03_s4_gate(project_dir_utf8: *const c_char) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    u8::from(crate::suite::run_t03_s4_bible_layers_gate(std::path::Path::new(&dir)).is_ok())
}

/// Atomically ingests a UTF-8 asset/draft into canonical CPFF v1.0 layout (`S1 v0.4`).
/// Writes normalized destination relative path into `out_rel_path_buf` and returns bytes written.
///
/// # Safety
/// Pointer parameters must be valid NUL-terminated UTF-8 strings and `out_rel_path_buf` must have `out_rel_path_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_hub_ingest_text_asset(
    project_dir_utf8: *const c_char,
    chapter_id_utf8: *const c_char,
    kind_code: u32,
    filename_utf8: *const c_char,
    payload_utf8: *const c_char,
    out_rel_path_buf: *mut c_char,
    out_rel_path_cap: usize,
) -> usize {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let ch = unsafe { cstr_to_string(chapter_id_utf8, "ch001") };
    let fname = unsafe { cstr_to_string(filename_utf8, "") };
    let payload = unsafe { cstr_to_string(payload_utf8, "") };
    let Some(kind) = crate::ingest::IngestAssetKind::from_u32(kind_code) else {
        return 0;
    };
    if dir.is_empty() || fname.is_empty() {
        return 0;
    }
    let Ok(res) = crate::ingest::ingest_bytes_atomic(
        std::path::Path::new(&dir),
        &ch,
        kind,
        &fname,
        payload.as_bytes(),
    ) else {
        return 0;
    };
    unsafe { write_utf8_to_c_buf(&res.destination_rel_path, out_rel_path_buf, out_rel_path_cap) }
}

/// Evaluates a freehand lasso polygon selection mask (with optional invert & expand/contract) (`S2 v0.4`).
///
/// # Safety
/// `xs` and `ys` must point to `point_count` valid `f32` values (or be null when `point_count == 0`).
#[no_mangle]
pub unsafe extern "C" fn manga_selection_lasso_pixel_count(
    xs: *const f32,
    ys: *const f32,
    point_count: usize,
    width: u32,
    height: u32,
    invert: u8,
    border_delta_px: i32,
) -> usize {
    if xs.is_null() || ys.is_null() || point_count < 3 {
        return 0;
    }
    let x_slice = unsafe { slice::from_raw_parts(xs, point_count) };
    let y_slice = unsafe { slice::from_raw_parts(ys, point_count) };
    let poly: Vec<(f32, f32)> = x_slice.iter().copied().zip(y_slice.iter().copied()).collect();
    let mut sel = crate::selection::SelectionMask::from_lasso_polygon(width, height, &poly);
    if border_delta_px != 0 {
        sel.adjust_border(border_delta_px);
    }
    if invert != 0 {
        sel.invert();
    }
    sel.selected_pixel_count()
}

/// Appends and atomically persists a `<DivergenceNote>` in `chapters/<ch>/novel/novel_meta.xml` (`S3 v0.4`).
///
/// # Safety
/// All non-null string pointers must be valid NUL-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn manga_novel_add_divergence_note(
    project_dir_utf8: *const c_char,
    chapter_id_utf8: *const c_char,
    scene_id_utf8: *const c_char,
    summary_utf8: *const c_char,
) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let ch = unsafe { cstr_to_string(chapter_id_utf8, "") };
    let scene = unsafe { cstr_to_string(scene_id_utf8, "") };
    let summary = unsafe { cstr_to_string(summary_utf8, "") };
    if dir.is_empty() || ch.is_empty() || summary.is_empty() {
        return 0;
    }
    let root = std::path::Path::new(&dir);
    let mut meta = match crate::novel::NovelChapterMeta::load_from_project(root, &ch) {
        Ok(m) => m,
        Err(_) => return 0,
    };
    meta.divergence_notes.push(crate::novel::DivergenceNote {
        scene_id: if scene.is_empty() { None } else { Some(scene) },
        summary,
    });
    u8::from(meta.save_atomic(root).is_ok())
}

/// Reads tab-delimited `<DivergenceNote>` lines (`scene_id\tsummary`) into caller-owned UTF-8 buffer (`S3 v0.4`).
///
/// # Safety
/// `project_dir_utf8` and `chapter_id_utf8` must be valid strings; `out_buf` must have `out_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_novel_read_divergence_notes(
    project_dir_utf8: *const c_char,
    chapter_id_utf8: *const c_char,
    out_buf: *mut c_char,
    out_cap: usize,
) -> usize {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let ch = unsafe { cstr_to_string(chapter_id_utf8, "") };
    if dir.is_empty() || ch.is_empty() {
        return 0;
    }
    let Ok(meta) = crate::novel::NovelChapterMeta::load_from_project(std::path::Path::new(&dir), &ch)
    else {
        return 0;
    };
    let lines = meta.export_divergence_lines();
    unsafe { write_utf8_to_c_buf(&lines, out_buf, out_cap) }
}

/// Executes the **`T0.4-S4` Asset Ingest + Close-Gap Anti-Halo Fill + `<DivergenceNote>` Gate**.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_t04_s4_gate(project_dir_utf8: *const c_char) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    u8::from(crate::suite::run_t04_s4_ingest_fill_divergence_gate(std::path::Path::new(&dir)).is_ok())
}

/// Evaluates manga drawing ruler snapping or symmetry mirroring (`S2 v0.5`).
/// `ruler_kind`: `0 = Symmetry (axis_x, axis_y, angle_rad)`, `1 = Parallel (angle_rad in param_aux)`,
/// `2 = 2-Point Perspective (vp1=(param_x, param_y), vp2=(param_aux, param_y))`,
/// `3 = FocusLines (center_x=param_x, center_y=param_y)`.
///
/// # Safety
/// `out_x` and `out_y` must be non-null writable pointers.
#[no_mangle]
pub unsafe extern "C" fn manga_ruler_transform_point(
    ruler_kind: u32,
    param_x: f32,
    param_y: f32,
    param_aux: f32,
    anchor_x: f32,
    anchor_y: f32,
    in_x: f32,
    in_y: f32,
    out_x: *mut f32,
    out_y: *mut f32,
) -> u8 {
    if out_x.is_null() || out_y.is_null() {
        return 0;
    }
    let pt = StrokePoint::simple(in_x, in_y, 1.0);
    let result = match ruler_kind {
        0 => {
            let r = crate::ruler::RulerKind::Symmetry {
                axis_x: param_x,
                axis_y: param_y,
                angle_rad: param_aux,
            };
            r.mirror_point(pt).unwrap_or(pt)
        }
        1 => crate::ruler::RulerKind::Parallel {
            angle_rad: param_aux,
        }
        .snap_point(anchor_x, anchor_y, pt),
        2 => crate::ruler::RulerKind::Perspective {
            vanishing_points: vec![(param_x, param_y), (param_aux, param_y)],
        }
        .snap_point(anchor_x, anchor_y, pt),
        3 => crate::ruler::RulerKind::FocusLines {
            center_x: param_x,
            center_y: param_y,
        }
        .snap_point(anchor_x, anchor_y, pt),
        _ => return 0,
    };
    unsafe {
        *out_x = result.x;
        *out_y = result.y;
    }
    1
}

/// Atomically upserts a 5-language glossary term into `bible/glossary.xml` under `SuiteApp::Hub` (`S1 v0.5`).
///
/// # Safety
/// All non-null string pointers must be valid NUL-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn manga_glossary_upsert_term(
    project_dir_utf8: *const c_char,
    key_utf8: *const c_char,
    en_utf8: *const c_char,
    zh_hans_utf8: *const c_char,
    zh_hant_utf8: *const c_char,
    yue_hant_utf8: *const c_char,
    es_utf8: *const c_char,
    locked: u8,
) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let key = unsafe { cstr_to_string(key_utf8, "") };
    if dir.is_empty() || key.is_empty() {
        return 0;
    }
    let root = std::path::Path::new(&dir);
    let mut g = match crate::glossary::ProjectGlossary::load_from_project(root) {
        Ok(g) => g,
        Err(_) => return 0,
    };
    g.upsert_term(crate::glossary::GlossaryTerm {
        key,
        en: unsafe { cstr_to_string(en_utf8, "") },
        zh_hans: unsafe { cstr_to_string(zh_hans_utf8, "") },
        zh_hant: unsafe { cstr_to_string(zh_hant_utf8, "") },
        yue_hant: unsafe { cstr_to_string(yue_hant_utf8, "") },
        es: unsafe { cstr_to_string(es_utf8, "") },
        locked: locked != 0,
    });
    u8::from(g.save_atomic(root).is_ok())
}

/// Returns tab-delimited localized glossary suggestions for `S1`/`S3` RO autocomplete (`v0.5`).
///
/// # Safety
/// String pointers must be valid UTF-8 C strings; `out_buf` must have capacity `out_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_glossary_suggest_terms(
    project_dir_utf8: *const c_char,
    query_utf8: *const c_char,
    locale_utf8: *const c_char,
    out_buf: *mut c_char,
    out_cap: usize,
) -> usize {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let query = unsafe { cstr_to_string(query_utf8, "") };
    let locale = unsafe { cstr_to_string(locale_utf8, "en") };
    if dir.is_empty() {
        return 0;
    }
    let Ok(g) = crate::glossary::ProjectGlossary::load_from_project(std::path::Path::new(&dir))
    else {
        return 0;
    };
    let lines = g.export_suggestions_lines(&query, &locale);
    unsafe { write_utf8_to_c_buf(&lines, out_buf, out_cap) }
}

/// Executes the **`T0.5-S4` Vector Lineart + Rulers + 5-Locale Glossary Gate**.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_t05_s4_gate(project_dir_utf8: *const c_char) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    u8::from(crate::suite::run_t05_s4_vector_ruler_glossary_gate(std::path::Path::new(&dir)).is_ok())
}

/// Evaluates procedural halftone screentone mask at `(x, y)` (`S2 v0.6`).
#[no_mangle]
pub extern "C" fn manga_screentone_sample_mask(
    lpi: f32,
    dpi: f32,
    angle_deg: f32,
    density: f32,
    pattern_code: u32,
    x: u32,
    y: u32,
) -> u8 {
    let pattern = match pattern_code {
        1 => crate::screentone::TonePattern::LineScreen,
        2 => crate::screentone::TonePattern::CrossHatch,
        3 => crate::screentone::TonePattern::NoiseGrain,
        _ => crate::screentone::TonePattern::CircleDot,
    };
    let spec = crate::screentone::ScreentoneSpec {
        lpi,
        dpi,
        angle_deg,
        density,
        pattern,
        ink_rgba: [0, 0, 0, 255],
    };
    u8::from(spec.sample_mask(x, y))
}

/// Returns contiguous vertical slice count for a Webtoon strip (`S2 v0.6`).
#[no_mangle]
pub extern "C" fn manga_webtoon_slice_count(canvas_height: u32, slice_height: u32) -> usize {
    crate::webtoon::compute_webtoon_slices(canvas_height, slice_height).len()
}

/// Renders a light-novel Markdown chapter into valid EPUB3 XHTML into caller-owned buffer (`S3 v0.6`).
///
/// # Safety
/// String pointers must be valid UTF-8 C strings; `out_buf` must have capacity `out_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_novel_render_epub_xhtml(
    chapter_title_utf8: *const c_char,
    locale_utf8: *const c_char,
    markdown_utf8: *const c_char,
    out_buf: *mut c_char,
    out_cap: usize,
) -> usize {
    let title = unsafe { cstr_to_string(chapter_title_utf8, "Chapter") };
    let locale = unsafe { cstr_to_string(locale_utf8, "zh-Hans") };
    let md = unsafe { cstr_to_string(markdown_utf8, "") };
    let xhtml = crate::bubble::render_novel_chapter_epub_xhtml(&title, &locale, &md, &[]);
    unsafe { write_utf8_to_c_buf(&xhtml, out_buf, out_cap) }
}

/// Executes the **`T0.6-S4` Dual-Track Panels/Screentones/Webtoon + 5-Locale Bubbles + EPUB3 Gate**.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_t06_s4_gate(project_dir_utf8: *const c_char) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    u8::from(crate::suite::run_t06_s4_panels_tones_webtoon_epub_gate(std::path::Path::new(&dir)).is_ok())
}

/// Atomically persists a `.mnga` v1 manuscript snapshot with FNV-1a integrity checksum (`S2 v0.7`).
/// Returns encoded byte size written on success, or `0` on failure / write-ownership violation.
///
/// # Safety
/// `handle` must be a valid `MangaProjectHandle`; strings must be valid NUL-terminated UTF-8.
#[no_mangle]
pub unsafe extern "C" fn manga_mnga_save_snapshot(
    handle: *const MangaProjectHandle,
    project_dir_utf8: *const c_char,
    rel_path_utf8: *const c_char,
    dpi: u16,
    timelapse_events: u32,
) -> usize {
    let Some(proj) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let rel = unsafe { cstr_to_string(rel_path_utf8, "") };
    if dir.is_empty() || rel.is_empty() {
        return 0;
    }
    let snap = crate::mnga::MngaDocumentSnapshot::from_layer_stack(
        &proj.doc.layers,
        dpi,
        timelapse_events,
    );
    let bytes = snap.encode_bytes();
    if snap.save_atomic(std::path::Path::new(&dir), &rel).is_ok() {
        bytes.len()
    } else {
        0
    }
}

/// Generates a minimal standards-compliant Adobe PSD (`8BPS` v1 RGB8) interchange payload and returns byte count (`S2 v0.7`).
///
/// # Safety
/// `handle` must be a valid `MangaProjectHandle` pointer or null.
#[no_mangle]
pub unsafe extern "C" fn manga_psd_export_byte_len(handle: *const MangaProjectHandle) -> usize {
    let Some(proj) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    crate::mnga::encode_minimal_psd_rgb8(&proj.doc.layers).len()
}

/// Validates an `S3 v0.7` light-novel illustration slot (`0 = MangaPick`, `1 = NovelCustom`, `2 = Hybrid`, `3 = None`).
///
/// # Safety
/// `rel_src_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_novel_validate_illustration_slot(
    mode_code: u32,
    rel_src_utf8: *const c_char,
) -> u8 {
    let rel = unsafe { cstr_to_string(rel_src_utf8, "") };
    let mode = match mode_code {
        0 => crate::project::NovelIllustrationMode::MangaPick,
        1 => crate::project::NovelIllustrationMode::NovelCustom,
        2 => crate::project::NovelIllustrationMode::Hybrid,
        _ => crate::project::NovelIllustrationMode::None,
    };
    u8::from(crate::mnga::validate_novel_illustration_slot(mode, &rel).is_ok())
}

/// Executes the **`T0.7-S4` `.mnga` Persistence + PSD `8BPS` + `ActionBus` + S3 Illustration Slot Gate**.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_t07_s4_gate(project_dir_utf8: *const c_char) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    u8::from(crate::suite::run_t07_s4_mnga_psd_actionbus_gate(std::path::Path::new(&dir)).is_ok())
}

/// Resolves touch/stylus telemetry into a deterministic `GestureAction` code (`v0.8`).
#[no_mangle]
pub extern "C" fn manga_gesture_resolve(
    touch_count: u8,
    duration_ms: f32,
    max_travel_px: f32,
    contact_radius_px: f32,
    stylus_active: u8,
    pencil_squeeze: u8,
) -> u32 {
    crate::gesture::resolve_touch_gesture(
        touch_count,
        duration_ms,
        max_travel_px,
        contact_radius_px,
        stylus_active != 0,
        pencil_squeeze != 0,
    ) as u32
}

/// Computes hinge-safe left/right pane widths for iPhone Duo & Android foldable postures (`v0.8`).
///
/// # Safety
/// `out_left_w`, `out_right_w`, and `out_hinge_w` must be non-null writable pointers.
#[no_mangle]
pub unsafe extern "C" fn manga_foldable_compute_pane_widths(
    viewport_width_dp: f32,
    posture_code: u32,
    reported_crease_dp: f32,
    out_left_w: *mut f32,
    out_right_w: *mut f32,
    out_hinge_w: *mut f32,
) -> u8 {
    if out_left_w.is_null() || out_right_w.is_null() || out_hinge_w.is_null() {
        return 0;
    }
    let posture = crate::platform::FoldPosture::from_u32(posture_code)
        .unwrap_or(crate::platform::FoldPosture::Flat);
    let geom = crate::gesture::compute_foldable_pane_geometry(
        viewport_width_dp,
        posture,
        reported_crease_dp,
    );
    unsafe {
        *out_left_w = geom.left_pane_width_dp;
        *out_right_w = geom.right_pane_width_dp;
        *out_hinge_w = geom.hinge_exclusion_dp;
    }
    u8::from(geom.is_split)
}

/// Resolves a core UI key in one of the 5 live languages (`0=en, 1=zh-Hans, 2=zh-Hant, 3=yue-Hant, 4=es`).
///
/// # Safety
/// `key_utf8` must be a valid NUL-terminated string; `out_buf` must have capacity `out_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_i18n_translate_key(
    locale_code: u32,
    key_utf8: *const c_char,
    out_buf: *mut c_char,
    out_cap: usize,
) -> usize {
    let key = unsafe { cstr_to_string(key_utf8, "") };
    let Some(locale) = crate::gesture::UiLocale::from_u32(locale_code) else {
        return 0;
    };
    let Some(val) = locale.translate_core_key(&key) else {
        return 0;
    };
    unsafe { write_utf8_to_c_buf(val, out_buf, out_cap) }
}

/// Executes the **`T0.8-S4` Apple Trio Touch/Foldable Ergonomics & Live 5-Language Gate**.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_t08_s4_gate(project_dir_utf8: *const c_char) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    u8::from(crate::suite::run_t08_s4_apple_trio_gesture_i18n_gate(std::path::Path::new(&dir)).is_ok())
}

/// Runs a live 50-step CoW Undo/Redo benchmark on a B4 600DPI (`6071×8598`) sparse tile layer
/// and returns elapsed microseconds (`v0.9` Beta stress telemetry).
#[no_mangle]
pub extern "C" fn manga_beta_b4_50layer_undo_benchmark_us() -> u64 {
    let b4 = crate::preset::CanvasPreset::B4PrintManga600Dpi.spec();
    let mut tile_layer = crate::tile::TileLayer::new(b4.width, b4.height);
    let mut history = crate::undo::TileUndoStack::new(100);
    let t0 = std::time::Instant::now();
    for step in 0..50u32 {
        let px = step * 100;
        let py = step * 120;
        let (coord, _, _) = crate::tile::TileCoord::from_pixel(px as i32, py as i32);
        let before = tile_layer.get_tile(coord);
        tile_layer.set_pixel(px, py, [(step * 5) as u8, 80, 180, 255]);
        let after = tile_layer.get_tile(coord);
        history.push(crate::undo::TileDiff {
            entries: vec![(coord, before, after)],
        });
    }
    for _ in 0..50 {
        let _ = history.undo(&mut tile_layer);
    }
    for _ in 0..50 {
        let _ = history.redo(&mut tile_layer);
    }
    t0.elapsed().as_micros().max(1) as u64
}

/// Executes the **`T0.9-S4` Pre-1.0 Wave 1 Apple Trio Joint Beta Stress Gate**.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_t09_s4_gate(project_dir_utf8: *const c_char) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    u8::from(crate::suite::run_t09_s4_wave1_beta_stress_gate(std::path::Path::new(&dir)).is_ok())
}

/// Recommends local Apache-2.0 Gemma 4 model pack (`0 = E2B` for 8GB, `1 = E4B` for 16GB+) (`v1.0`).
#[no_mangle]
pub extern "C" fn manga_ai_recommend_gemma_pack(device_ram_gb: u32) -> u32 {
    crate::ai_bridge::GemmaModelPack::recommend_for_device_ram_gb(device_ram_gb) as u32
}

/// Emits an isolated `Manga -> Novel` read-only AI prose reference strictly under `chapters/<ch>/ai_assist/manga_to_novel/` (`v1.0`).
///
/// # Safety
/// String pointers must be valid UTF-8 C strings; `out_rel_path_buf` must have capacity `out_rel_path_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_ai_bridge_generate_manga_to_novel(
    project_dir_utf8: *const c_char,
    chapter_id_utf8: *const c_char,
    locale_utf8: *const c_char,
    beat_summary_utf8: *const c_char,
    model_pack_code: u32,
    out_rel_path_buf: *mut c_char,
    out_rel_path_cap: usize,
) -> usize {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let ch = unsafe { cstr_to_string(chapter_id_utf8, "ch001") };
    let loc = unsafe { cstr_to_string(locale_utf8, "zh-Hans") };
    let beat = unsafe { cstr_to_string(beat_summary_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    let pack = crate::ai_bridge::GemmaModelPack::from_u32(model_pack_code);
    let Ok(emitted) = crate::ai_bridge::generate_manga_to_novel_reference_atomic(
        std::path::Path::new(&dir),
        &ch,
        &loc,
        &beat,
        pack,
        &[],
    ) else {
        return 0;
    };
    unsafe { write_utf8_to_c_buf(&emitted.artifact.output_src, out_rel_path_buf, out_rel_path_cap) }
}

/// Emits an isolated `Novel -> Manga` read-only AI storyboard proposal strictly under `chapters/<ch>/ai_assist/novel_to_manga/` (`v1.0`).
///
/// # Safety
/// String pointers must be valid UTF-8 C strings; `out_rel_path_buf` must have capacity `out_rel_path_cap`.
#[no_mangle]
pub unsafe extern "C" fn manga_ai_bridge_generate_novel_to_manga(
    project_dir_utf8: *const c_char,
    chapter_id_utf8: *const c_char,
    prose_excerpt_utf8: *const c_char,
    model_pack_code: u32,
    out_rel_path_buf: *mut c_char,
    out_rel_path_cap: usize,
) -> usize {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let ch = unsafe { cstr_to_string(chapter_id_utf8, "ch001") };
    let excerpt = unsafe { cstr_to_string(prose_excerpt_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    let pack = crate::ai_bridge::GemmaModelPack::from_u32(model_pack_code);
    let Ok(emitted) = crate::ai_bridge::generate_novel_to_manga_storyboard_atomic(
        std::path::Path::new(&dir),
        &ch,
        "novel/prose/zh-Hans.md",
        &excerpt,
        pack,
    ) else {
        return 0;
    };
    unsafe { write_utf8_to_c_buf(&emitted.artifact.output_src, out_rel_path_buf, out_rel_path_cap) }
}

/// Executes the **`T1.0-S4` Wave 1 Release Candidate (`v1.0.0-rc1`) Dual-Engine & AI Red-Line Gate**.
///
/// # Safety
/// `project_dir_utf8` must be null or a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn manga_suite_run_t10_s4_gate(project_dir_utf8: *const c_char) -> u8 {
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    if dir.is_empty() {
        return 0;
    }
    u8::from(crate::suite::run_t10_s4_release_candidate_gate(std::path::Path::new(&dir)).is_ok())
}

/// Atomically persists the full `LayerStack` (metadata + RLE-compressed sparse `256×256` RGBA8 tiles)
/// into `MNGA0002` format with `.mnga.bak` crash-recovery backup (`v1.0.0-rc2`).
///
/// # Safety
/// `handle` must be a valid `MangaProjectHandle`; strings must be valid NUL-terminated UTF-8.
#[no_mangle]
pub unsafe extern "C" fn manga_project_save_mnga_v2(
    handle: *const MangaProjectHandle,
    project_dir_utf8: *const c_char,
    rel_path_utf8: *const c_char,
    dpi: u16,
    timelapse_events: u32,
) -> usize {
    let Some(proj) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let rel = unsafe { cstr_to_string(rel_path_utf8, "") };
    if dir.is_empty() || rel.is_empty() {
        return 0;
    }
    crate::mnga::save_layer_stack_v2_atomic(
        &proj.doc.layers,
        std::path::Path::new(&dir),
        &rel,
        dpi,
        timelapse_events,
    )
    .map(|(_, len)| len)
    .unwrap_or(0)
}

/// Restores a full `MNGA0002` archive (including all sparse RGBA8 pixel tiles, falling back to `.mnga.bak`
/// if needed) directly into `handle` (`v1.0.0-rc2`). Returns `1` on success, `0` on failure.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`; strings must be valid NUL-terminated UTF-8.
#[no_mangle]
pub unsafe extern "C" fn manga_project_load_mnga_v2(
    handle: *mut MangaProjectHandle,
    project_dir_utf8: *const c_char,
    rel_path_utf8: *const c_char,
) -> u8 {
    let Some(proj) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let dir = unsafe { cstr_to_string(project_dir_utf8, "") };
    let rel = unsafe { cstr_to_string(rel_path_utf8, "") };
    if dir.is_empty() || rel.is_empty() {
        return 0;
    }
    let Ok((stack, _, _)) = crate::mnga::load_layer_stack_v2(std::path::Path::new(&dir), &rel) else {
        return 0;
    };
    proj.doc.spec.width = stack.width;
    proj.doc.spec.height = stack.height;
    proj.doc.layers = stack;
    proj.undo_snapshots.clear();
    proj.redo_snapshots.clear();
    1
}

// ============================================================================
// v1.0.0-rc3 Phase 2: Real Rust RGBA8 Raster Canvas, Layer CRUD, Selection & PSD Export API
// ============================================================================

/// Returns pixel width of the project's `LayerStack`.
///
/// # Safety
/// `handle` must be null or a valid `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_width(handle: *const MangaProjectHandle) -> u32 {
    unsafe { handle.as_ref() }.map(|h| h.doc.layers.width).unwrap_or(0)
}

/// Returns pixel height of the project's `LayerStack`.
///
/// # Safety
/// `handle` must be null or a valid `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_height(handle: *const MangaProjectHandle) -> u32 {
    unsafe { handle.as_ref() }.map(|h| h.doc.layers.height).unwrap_or(0)
}

/// Returns total allocated sparse `256×256` tiles across all layers in `handle`.
///
/// # Safety
/// `handle` must be null or a valid `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_allocated_tiles(handle: *const MangaProjectHandle) -> usize {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    h.doc
        .layers
        .layers()
        .iter()
        .filter_map(|l| l.raster.as_ref())
        .map(|r| r.allocated_tile_count())
        .sum()
}

/// Captures a CoW `LayerStack` undo checkpoint (bounded to 40 steps) before a user stroke/fill/filter.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_push_undo_snapshot(handle: *mut MangaProjectHandle) {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return;
    };
    if h.undo_snapshots.len() >= 40 {
        h.undo_snapshots.remove(0);
    }
    h.undo_snapshots.push(h.doc.layers.clone());
    h.redo_snapshots.clear();
}

/// Restores the previous `LayerStack` undo snapshot. Returns `1` if undone, `0` otherwise.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_undo_snapshot(handle: *mut MangaProjectHandle) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let Some(prev) = h.undo_snapshots.pop() else {
        return 0;
    };
    h.redo_snapshots.push(h.doc.layers.clone());
    h.doc.layers = prev;
    1
}

/// Reapplies an undone `LayerStack` snapshot. Returns `1` if redone, `0` otherwise.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_redo_snapshot(handle: *mut MangaProjectHandle) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let Some(next) = h.redo_snapshots.pop() else {
        return 0;
    };
    h.undo_snapshots.push(h.doc.layers.clone());
    h.doc.layers = next;
    1
}

/// Returns `1` if at least one raster undo snapshot is available.
///
/// # Safety
/// `handle` must be null or a valid `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_can_undo_snapshot(handle: *const MangaProjectHandle) -> u8 {
    u8::from(unsafe { handle.as_ref() }.is_some_and(|h| !h.undo_snapshots.is_empty()))
}

/// Returns `1` if at least one raster redo snapshot is available.
///
/// # Safety
/// `handle` must be null or a valid `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_can_redo_snapshot(handle: *const MangaProjectHandle) -> u8 {
    u8::from(unsafe { handle.as_ref() }.is_some_and(|h| !h.redo_snapshots.is_empty()))
}

/// Paints an anti-aliased RGBA8 brush segment onto `layer_id`, honoring alpha lock and active selection.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn manga_project_paint_segment(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    radius_px: f32,
    hardness: f32,
    opacity: f32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::raster_ops::paint_stroke_segment_rgba(
        layer,
        x0,
        y0,
        x1,
        y1,
        radius_px,
        hardness,
        opacity,
        [r, g, b, a],
        sel,
    )
}

/// Erases a transparent-channel (`Destination-Out`) segment on `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn manga_project_erase_segment(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    radius_px: f32,
    hardness: f32,
    opacity: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::raster_ops::erase_stroke_segment_rgba(
        layer,
        x0,
        y0,
        x1,
        y1,
        radius_px,
        hardness,
        opacity,
        sel,
    )
}

/// Applies real pixel Smudge along `(x0, y0) -> (x1, y1)` on `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn manga_project_smudge_segment(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    radius_px: f32,
    strength: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::raster_ops::smudge_stroke_segment_rgba(layer, x0, y0, x1, y1, radius_px, strength, sel)
}

/// Applies real local Gaussian/box Blur brush along `(x0, y0) -> (x1, y1)` on `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn manga_project_blur_segment(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    radius_px: f32,
    strength: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::raster_ops::blur_stroke_segment_rgba(layer, x0, y0, x1, y1, radius_px, strength, sel)
}

/// Samples the true composite RGBA8 pixel at `(x, y)` for the Eyedropper tool (`I`).
///
/// # Safety
/// `handle` must be valid; `out_r`, `out_g`, `out_b`, `out_a` must be non-null writable pointers.
#[no_mangle]
pub unsafe extern "C" fn manga_project_eyedropper_rgba(
    handle: *const MangaProjectHandle,
    x: u32,
    y: u32,
    out_r: *mut u8,
    out_g: *mut u8,
    out_b: *mut u8,
    out_a: *mut u8,
) -> u8 {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    if out_r.is_null() || out_g.is_null() || out_b.is_null() || out_a.is_null() {
        return 0;
    }
    if x >= h.doc.layers.width || y >= h.doc.layers.height {
        return 0;
    }
    let px = h.doc.layers.composite_pixel(x, y);
    unsafe {
        *out_r = px[0];
        *out_g = px[1];
        *out_b = px[2];
        *out_a = px[3];
    }
    1
}

/// Renders the entire `LayerStack` into caller-owned flat RGBA8 pixel buffer (`width * height * 4` bytes).
/// `backdrop_code`: `0 = white paper`, `1 = light checker`, `2 = dark checker`, `3 = transparent RGBA`.
///
/// # Safety
/// `handle` must be valid; `out_rgba` must point to at least `out_cap` writable bytes.
#[no_mangle]
pub unsafe extern "C" fn manga_project_composite_rgba(
    handle: *const MangaProjectHandle,
    backdrop_code: u32,
    out_rgba: *mut u8,
    out_cap: usize,
) -> usize {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    if out_rgba.is_null() || out_cap == 0 {
        return 0;
    }
    let buf = unsafe { slice::from_raw_parts_mut(out_rgba, out_cap) };
    crate::raster_ops::composite_stack_rgba(&h.doc.layers, backdrop_code, buf)
}

/// Duplicates `layer_id` (tiles + flags) directly above it. Returns new layer ID or `0`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_duplicate_layer(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
) -> u64 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    h.doc
        .layers
        .duplicate_layer(LayerId(layer_id))
        .map(|id| id.0)
        .unwrap_or(0)
}

/// Deletes `layer_id` from the stack (refuses to delete last remaining layer). Returns `1` on success.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_delete_layer(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    if h.doc.layers.layers().len() <= 1 {
        return 0;
    }
    u8::from(h.doc.layers.remove_layer(LayerId(layer_id)).is_some())
}

/// Merges `layer_id` down into the layer beneath it. Returns surviving lower layer ID or `0`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_merge_layer_down(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
) -> u64 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    h.doc
        .layers
        .merge_layer_down(LayerId(layer_id))
        .map(|id| id.0)
        .unwrap_or(0)
}

/// Moves `layer_id` up (`up != 0`) or down (`up == 0`) by one stack slot.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_move_layer(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    up: u8,
) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    u8::from(h.doc.layers.move_layer(LayerId(layer_id), up != 0))
}

/// Clears all raster pixels in `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_clear_layer(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    u8::from(h.doc.layers.clear_layer(LayerId(layer_id)))
}

/// Flips all raster pixels in `layer_id` horizontally (`horizontal != 0`) or vertically (`horizontal == 0`).
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_flip_layer(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    horizontal: u8,
) -> u8 {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    u8::from(h.doc.layers.flip_layer(LayerId(layer_id), horizontal != 0))
}

/// Sets a rectangular marquee `SelectionMask` on `handle`. Returns selected pixel count.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_selection_set_rect(
    handle: *mut MangaProjectHandle,
    x0: u32,
    y0: u32,
    x1: u32,
    y1: u32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = crate::selection::SelectionMask::from_rect(
        h.doc.layers.width,
        h.doc.layers.height,
        x0,
        y0,
        x1,
        y1,
    );
    let count = sel.selected_pixel_count();
    h.active_selection = if count > 0 { Some(sel) } else { None };
    count
}

/// Sets a freehand lasso polygon `SelectionMask` on `handle`. Returns selected pixel count.
///
/// # Safety
/// `handle` must be valid; `xs` and `ys` must point to `point_count` floats.
#[no_mangle]
pub unsafe extern "C" fn manga_project_selection_set_lasso(
    handle: *mut MangaProjectHandle,
    xs: *const f32,
    ys: *const f32,
    point_count: usize,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    if xs.is_null() || ys.is_null() || point_count < 3 {
        return 0;
    }
    let x_slice = unsafe { slice::from_raw_parts(xs, point_count) };
    let y_slice = unsafe { slice::from_raw_parts(ys, point_count) };
    let poly: Vec<(f32, f32)> = x_slice.iter().copied().zip(y_slice.iter().copied()).collect();
    let sel = crate::selection::SelectionMask::from_lasso_polygon(
        h.doc.layers.width,
        h.doc.layers.height,
        &poly,
    );
    let count = sel.selected_pixel_count();
    h.active_selection = if count > 0 { Some(sel) } else { None };
    count
}

/// Runs contiguous Magic Wand selection from `(seed_x, seed_y)`. Returns selected pixel count.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_selection_magic_wand(
    handle: *mut MangaProjectHandle,
    seed_x: u32,
    seed_y: u32,
    tolerance: u8,
    use_reference: u8,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = crate::selection::SelectionMask::from_magic_wand(
        &h.doc.layers,
        seed_x,
        seed_y,
        tolerance,
        use_reference != 0,
    );
    let count = sel.selected_pixel_count();
    h.active_selection = if count > 0 { Some(sel) } else { None };
    count
}

/// Selects the entire canvas (`⌘A`).
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_selection_select_all(
    handle: *mut MangaProjectHandle,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = crate::selection::SelectionMask::all(h.doc.layers.width, h.doc.layers.height);
    let count = sel.selected_pixel_count();
    h.active_selection = Some(sel);
    count
}

/// Clears active selection (`⌘D`).
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_selection_clear(handle: *mut MangaProjectHandle) {
    if let Some(h) = unsafe { handle.as_mut() } {
        h.active_selection = None;
    }
}

/// Inverts active selection (`⇧⌘I`). Returns new selected pixel count.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_selection_invert(
    handle: *mut MangaProjectHandle,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    if let Some(sel) = h.active_selection.as_mut() {
        sel.invert();
        sel.selected_pixel_count()
    } else {
        0
    }
}

/// Writes full Adobe PSD (`8BPS` v1 RGB8) bytes into caller-owned buffer.
/// Pass `out_buf = null` to query exact required byte length.
///
/// # Safety
/// `handle` must be valid; if `out_buf` is non-null, it must hold at least `out_cap` bytes.
#[no_mangle]
pub unsafe extern "C" fn manga_project_export_psd_bytes(
    handle: *const MangaProjectHandle,
    out_buf: *mut u8,
    out_cap: usize,
) -> usize {
    let Some(h) = (unsafe { handle.as_ref() }) else {
        return 0;
    };
    let bytes = crate::mnga::encode_minimal_psd_rgb8(&h.doc.layers);
    if out_buf.is_null() || out_cap < bytes.len() {
        return bytes.len();
    }
    let dst = unsafe { slice::from_raw_parts_mut(out_buf, bytes.len()) };
    dst.copy_from_slice(&bytes);
    bytes.len()
}

// ============================================================================
// v1.0.0-rc4 Phase 3: 6 Pulled-Forward FX Filters, Affine Transform, Screentone & Panel Slicing
// ============================================================================

/// Filter 1: Separable Gaussian Blur on `layer_id` (`radius_px` in `0.5..=24.0`).
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_filter_gaussian_blur(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    radius_px: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::filter_gaussian_blur(layer, radius_px, sel)
}

/// Filter 2: Hue / Saturation / Brightness adjustment on `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_filter_hsb(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    hue_deg: f32,
    sat_delta: f32,
    bright_delta: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::filter_hsb_adjust(layer, hue_deg, sat_delta, bright_delta, sel)
}

/// Filter 3: Brightness & Contrast adjustment on `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_filter_brightness_contrast(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    brightness: f32,
    contrast: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::filter_brightness_contrast(layer, brightness, contrast, sel)
}

/// Filter 4: Extract Line Drawing (converts white/light paper to transparent & extracts crisp ink).
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_filter_extract_line_drawing(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    black_threshold: f32,
    white_threshold: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::filter_extract_line_drawing(layer, black_threshold, white_threshold, sel)
}

/// Filter 5: Outer Stroke border around opaque alpha on `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_filter_outer_stroke(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    width_px: u32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::filter_outer_stroke(layer, width_px, [r, g, b, a], sel)
}

/// Filter 6: Offset Gaussian Drop Shadow behind artwork on `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn manga_project_filter_drop_shadow(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    dx: i32,
    dy: i32,
    blur_px: f32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::filter_drop_shadow(layer, dx, dy, blur_px, [r, g, b, a], sel)
}

/// Bilinear affine transform (`dx`, `dy`, `scale_x`, `scale_y`, `rot_deg`) on `layer_id`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_transform_layer_affine(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    dx: f32,
    dy: f32,
    scale_x: f32,
    scale_y: f32,
    rot_deg: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::transform_layer_affine(layer, dx, dy, scale_x, scale_y, rot_deg)
}

/// Independent Floating Selection Pixel Transform (`dx`, `dy`, `scale_x`, `scale_y`, `rot_deg`).
/// Moves/scales/rotates ONLY pixels inside the active selection mask on `layer_id` while leaving
/// unselected pixels untouched, and transforms the selection mask along with the pixels.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn manga_project_transform_selected_pixels_affine(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    dx: f32,
    dy: f32,
    scale_x: f32,
    scale_y: f32,
    rot_deg: f32,
    clear_source: u8,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let Some(sel) = h.active_selection.as_mut() else {
        return 0;
    };
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::transform_selected_pixels_affine(
        layer,
        sel,
        dx,
        dy,
        scale_x,
        scale_y,
        rot_deg,
        clear_source != 0,
    )
}

/// Bilinearly imports an RGBA8 image buffer into `layer_id` at `(dst_x, dst_y, dst_w, dst_h)`.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`, and `rgba_ptr` must point to at least
/// `img_w * img_h * 4` valid readable bytes.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn manga_project_import_rgba_to_layer(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    rgba_ptr: *const u8,
    img_w: u32,
    img_h: u32,
    dst_x: i32,
    dst_y: i32,
    dst_w: u32,
    dst_h: u32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    if rgba_ptr.is_null() || img_w == 0 || img_h == 0 || dst_w == 0 || dst_h == 0 {
        return 0;
    }
    let byte_len = (img_w as usize)
        .saturating_mul(img_h as usize)
        .saturating_mul(4);
    let rgba = unsafe { std::slice::from_raw_parts(rgba_ptr, byte_len) };
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::import_rgba_to_layer(layer, rgba, img_w, img_h, dst_x, dst_y, dst_w, dst_h)
}

/// Applies procedural manga halftone screentone fill onto `layer_id` (clipped to active selection if set).
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn manga_project_apply_screentone(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    lpi: f32,
    dpi: f32,
    angle_deg: f32,
    density: f32,
    pattern_code: u32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    let pattern = match pattern_code {
        1 => crate::screentone::TonePattern::LineScreen,
        2 => crate::screentone::TonePattern::CrossHatch,
        3 => crate::screentone::TonePattern::NoiseGrain,
        _ => crate::screentone::TonePattern::CircleDot,
    };
    let spec = crate::screentone::ScreentoneSpec {
        lpi,
        dpi,
        angle_deg,
        density,
        pattern,
        ink_rgba: [r, g, b, a],
    };
    let sel = h.active_selection.as_ref();
    let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) else {
        return 0;
    };
    crate::filters::apply_screentone_fill(layer, spec, sel)
}

/// Slices any intersected panel in `PanelLayout` along `(x0, y0) -> (x1, y1)` with `gutter_px`,
/// rasterizes crisp comic borders onto `layer_id`, and returns updated total panel count.
///
/// # Safety
/// `handle` must be a valid mutable `MangaProjectHandle`.
#[no_mangle]
pub unsafe extern "C" fn manga_project_slice_and_rasterize_panel(
    handle: *mut MangaProjectHandle,
    layer_id: u64,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    gutter_px: f32,
) -> usize {
    let Some(h) = (unsafe { handle.as_mut() }) else {
        return 0;
    };
    // Find first panel whose polygon contains the midpoint of the knife drag (or fallback to panel 0)
    let mid_x = (x0 + x1) * 0.5;
    let mid_y = (y0 + y1) * 0.5;
    let target_id = h
        .panels
        .panels()
        .iter()
        .find(|p| p.polygon.contains_point(mid_x, mid_y))
        .or_else(|| h.panels.panels().first())
        .map(|p| p.id);
    if let Some(pid) = target_id {
        let _ = h.panels.slice_panel(pid, (x0, y0), (x1, y1), gutter_px.max(4.0));
    }
    if let Some(layer) = h.doc.layers.get_mut(LayerId(layer_id)) {
        let _ = crate::filters::rasterize_panel_borders(layer, &h.panels);
    }
    h.panels.panels().len()
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
            let novel_meta = CString::new("chapters/ch001/novel/novel_meta.xml").unwrap();
            let manga_path = CString::new("chapters/ch001/manuscript/p001.mnga").unwrap();
            assert_eq!(manga_suite_can_write_path(SuiteApp::Novel as u32, novel_path.as_ptr()), 1);
            assert_eq!(manga_suite_can_write_path(SuiteApp::Novel as u32, novel_meta.as_ptr()), 1);
            assert_eq!(manga_suite_can_write_path(SuiteApp::Manga as u32, novel_meta.as_ptr()), 0);
            assert_eq!(manga_suite_can_write_path(SuiteApp::Manga as u32, novel_path.as_ptr()), 0);
            assert_eq!(manga_suite_can_write_path(SuiteApp::Manga as u32, manga_path.as_ptr()), 1);
            assert_eq!(manga_suite_can_write_path(SuiteApp::Novel as u32, manga_path.as_ptr()), 0);
            assert_eq!(manga_suite_ram_budget_mb(SuiteApp::Novel as u32), 120);
            assert_eq!(manga_suite_ram_budget_mb(SuiteApp::Hub as u32), 200);
        }
    }

    #[test]
    fn c_abi_v021_brush_and_novel_endpoints_match_contract() {
        unsafe {
            assert_eq!(manga_brush_preset_count(), 8);
            let r_light = manga_brush_sample_radius(0, 0.1, 1.5);
            let r_heavy = manga_brush_sample_radius(0, 0.95, 1.5);
            assert!(r_heavy > r_light * 4.0);
            assert!((manga_brush_zoom_adaptive_rope(6.0, 2.0) - 3.0).abs() < 1e-5);

            let text = CString::new("星光之刃 Starlight Blade").unwrap();
            assert_eq!(manga_novel_count_units(text.as_ptr()), 6);
        }
    }

    #[test]
    fn c_abi_v023_and_t02_s4_soak_endpoints_pass() {
        unsafe {
            let parent = std::env::temp_dir().join(format!("manga_v023_ffi_{}", std::process::id()));
            let _ = std::fs::remove_dir_all(&parent);
            std::fs::create_dir_all(&parent).unwrap();

            let c_parent = CString::new(parent.to_str().unwrap()).unwrap();
            let c_folder = CString::new("NebulaTest").unwrap();
            let c_author = CString::new("S4Runner").unwrap();
            assert_eq!(manga_hub_init_project(c_parent.as_ptr(), c_folder.as_ptr(), c_author.as_ptr()), 1);

            let orig_dir = parent.join("NebulaTest");
            let c_orig = CString::new(orig_dir.to_str().unwrap()).unwrap();
            assert_eq!(manga_hub_resolve_prj_status(c_orig.as_ptr()), 1);

            // Rename folder -> must detect RenamedFolderFallback (2)
            let renamed_dir = parent.join("NebulaTest-RenamedClone");
            std::fs::rename(&orig_dir, &renamed_dir).unwrap();
            let c_renamed = CString::new(renamed_dir.to_str().unwrap()).unwrap();
            assert_eq!(manga_hub_resolve_prj_status(c_renamed.as_ptr()), 2);

            // S2 brush stamping count
            let pts = [
                CMangaStrokePoint { x: 0.0, y: 0.0, pressure: 0.5, altitude: 1.3, azimuth: 0.0, roll_angle: 0.0, timestamp_ms: 1.0, is_predicted: 0 },
                CMangaStrokePoint { x: 100.0, y: 0.0, pressure: 0.9, altitude: 1.3, azimuth: 0.0, roll_angle: 0.0, timestamp_ms: 8.0, is_predicted: 0 },
            ];
            assert!(manga_brush_generate_stamp_count(0, pts.as_ptr(), pts.len()) > 10);

            // S3 atomic save + locked guard
            let rel = CString::new("chapters/ch001/novel/prose/zh-Hans.md").unwrap();
            let body = CString::new("# 原子保存测试").unwrap();
            assert_eq!(manga_novel_save_prose_atomic(c_renamed.as_ptr(), rel.as_ptr(), body.as_ptr(), 0, 1), 1);
            assert_eq!(manga_novel_save_prose_atomic(c_renamed.as_ptr(), rel.as_ptr(), body.as_ptr(), 1, 0), 0);

            // T0.2-S4 100-round Tri-App concurrency soak gate!
            assert_eq!(manga_suite_run_s4_gate(c_renamed.as_ptr(), 100), 1);

            let _ = std::fs::remove_dir_all(&parent);
        }
    }

    #[test]
    fn c_abi_v032_summary_and_t03_s4_gate_pass() {
        unsafe {
            let parent = std::env::temp_dir().join(format!("manga_v032_ffi_{}", std::process::id()));
            let _ = std::fs::remove_dir_all(&parent);
            std::fs::create_dir_all(&parent).unwrap();

            let c_parent = CString::new(parent.to_str().unwrap()).unwrap();
            let c_folder = CString::new("V032Prj").unwrap();
            let c_author = CString::new("S4Runner").unwrap();
            assert_eq!(manga_hub_init_project(c_parent.as_ptr(), c_folder.as_ptr(), c_author.as_ptr()), 1);

            let prj = parent.join("V032Prj");
            let c_prj = CString::new(prj.to_str().unwrap()).unwrap();

            // Run full T0.3-S4 gate via C-ABI
            assert_eq!(manga_suite_run_t03_s4_gate(c_prj.as_ptr()), 1);

            // Read back Story Bible & TOC summaries via caller-owned UTF-8 buffer
            let mut buf = vec![0 as c_char; 4096];
            let bible_len = manga_bible_read_summary(c_prj.as_ptr(), buf.as_mut_ptr(), buf.len());
            assert!(bible_len > 0);
            let bible_str = std::ffi::CStr::from_ptr(buf.as_ptr()).to_str().unwrap().to_string();
            assert!(bible_str.contains("char-lin\t林晓\tLin Xiao"));

            let toc_len = manga_toc_read_summary(c_prj.as_ptr(), buf.as_mut_ptr(), buf.len());
            assert!(toc_len > 0);
            let toc_str = std::ffi::CStr::from_ptr(buf.as_ptr()).to_str().unwrap().to_string();
            assert!(toc_str.contains("ch001\t1\t星辉觉醒"));

            // Upsert a 4th chapter via C-ABI
            let cid = CString::new("ch004").unwrap();
            let zh = CString::new("星门彼岸").unwrap();
            let en = CString::new("Beyond Star Gate").unwrap();
            let st = CString::new("draft").unwrap();
            assert_eq!(manga_toc_upsert_entry(c_prj.as_ptr(), cid.as_ptr(), 4, zh.as_ptr(), en.as_ptr(), st.as_ptr()), 1);
            let toc_len2 = manga_toc_read_summary(c_prj.as_ptr(), buf.as_mut_ptr(), buf.len());
            assert!(toc_len2 > toc_len);

            let _ = std::fs::remove_dir_all(&parent);
        }
    }
}
