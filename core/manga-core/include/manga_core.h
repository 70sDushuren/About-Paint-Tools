#ifndef MANGA_CORE_H
#define MANGA_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MangaCanvasHandle MangaCanvasHandle;
typedef struct MangaProjectHandle MangaProjectHandle;

typedef enum MangaCanvasPreset {
    MANGA_PRESET_B4_PRINT_600DPI = 0,
    MANGA_PRESET_A4_PRINT_600DPI = 1,
    MANGA_PRESET_WEBTOON_800     = 2,
    MANGA_PRESET_WEBTOON_1600    = 3,
    MANGA_PRESET_ILLUSTRATION_4K = 4,
} MangaCanvasPreset;

typedef enum MangaBlendMode {
    MANGA_BLEND_NORMAL      = 0,
    MANGA_BLEND_MULTIPLY    = 1,
    MANGA_BLEND_SCREEN      = 2,
    MANGA_BLEND_OVERLAY     = 3,
    MANGA_BLEND_GLOW_DODGE  = 4,
    MANGA_BLEND_LINEAR_BURN = 5,
    MANGA_BLEND_HARD_LIGHT  = 6,
    MANGA_BLEND_SOFT_LIGHT  = 7,
    MANGA_BLEND_DARKEN      = 8,
    MANGA_BLEND_LIGHTEN     = 9,
    MANGA_BLEND_COLOR_BURN  = 10,
    MANGA_BLEND_COLOR_DODGE = 11,
    MANGA_BLEND_ADD         = 12,
} MangaBlendMode;

typedef struct CMangaStrokePoint {
    float x;
    float y;
    float pressure;
    float altitude;
    float azimuth;
    float roll_angle;
    double timestamp_ms;
    uint8_t is_predicted;
} CMangaStrokePoint;

/* --- Single-Canvas Low-Latency Drawing API --- */

MangaCanvasHandle *manga_canvas_create_preset(uint32_t preset_code);
void manga_canvas_destroy(MangaCanvasHandle *handle);

uint32_t manga_canvas_width(const MangaCanvasHandle *handle);
uint32_t manga_canvas_height(const MangaCanvasHandle *handle);
size_t manga_canvas_allocated_tiles(const MangaCanvasHandle *handle);

void manga_canvas_set_viewport(
    MangaCanvasHandle *handle,
    float pan_x,
    float pan_y,
    float zoom,
    float rotation_rad
);

void manga_canvas_begin_stroke(
    MangaCanvasHandle *handle,
    float base_radius,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a,
    uint8_t is_eraser,
    float stabilizer_radius
);

size_t manga_canvas_push_points(
    MangaCanvasHandle *handle,
    const CMangaStrokePoint *points,
    size_t count
);

size_t manga_canvas_end_stroke(MangaCanvasHandle *handle);

uint8_t manga_canvas_undo(MangaCanvasHandle *handle);
uint8_t manga_canvas_redo(MangaCanvasHandle *handle);
uint32_t manga_canvas_get_pixel_rgba(const MangaCanvasHandle *handle, uint32_t x, uint32_t y);

/* --- Full Project API (Layers, Close-Gap Fill, Vector Eraser, Panels, ActionBus) --- */

MangaProjectHandle *manga_project_create_preset(uint32_t preset_code);
void manga_project_destroy(MangaProjectHandle *handle);

uint64_t manga_project_add_raster_layer(
    MangaProjectHandle *handle,
    const char *name_utf8,
    uint32_t blend_mode_code,
    uint8_t clipping_mask,
    uint8_t is_reference
);

size_t manga_project_layer_count(const MangaProjectHandle *handle);

size_t manga_project_batch_tint_layers(
    MangaProjectHandle *handle,
    const char *prefix_utf8,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a,
    float opacity,
    uint8_t lock
);

size_t manga_project_close_gap_fill(
    MangaProjectHandle *handle,
    uint64_t layer_id,
    uint32_t seed_x,
    uint32_t seed_y,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a,
    uint8_t close_gap_px,
    uint8_t expand_px
);

uint64_t manga_project_add_vector_stroke(
    MangaProjectHandle *handle,
    const float *xs,
    const float *ys,
    const float *widths,
    size_t count,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a
);

uint8_t manga_project_vector_erase_intersection(
    MangaProjectHandle *handle,
    float hit_x,
    float hit_y,
    float hit_radius
);

size_t manga_project_vector_stroke_count(const MangaProjectHandle *handle);

size_t manga_project_slice_panel(
    MangaProjectHandle *handle,
    uint64_t panel_id,
    float ax,
    float ay,
    float bx,
    float by,
    float gutter_px
);

typedef enum MangaTargetPlatform {
    MANGA_PLATFORM_IPADOS               = 0,
    MANGA_PLATFORM_MACOS_TOUCH          = 1,
    MANGA_PLATFORM_IPHONE_DUO           = 2,
    MANGA_PLATFORM_ANDROID_PAD_FOLDABLE = 3,
    MANGA_PLATFORM_WINDOWS_TOUCH        = 4,
    MANGA_PLATFORM_LINUX_TOUCH          = 5,
} MangaTargetPlatform;

typedef enum MangaFoldPosture {
    MANGA_POSTURE_FLAT                    = 0,
    MANGA_POSTURE_FOLDED_COMPACT          = 1,
    MANGA_POSTURE_UNFOLDED_DUAL_PANE      = 2,
    MANGA_POSTURE_TABLETOP_HALF_OPEN      = 3,
    MANGA_POSTURE_CONVERTIBLE_TABLET_MODE = 4,
} MangaFoldPosture;

typedef enum MangaWorkspaceLayout {
    MANGA_LAYOUT_SINGLE_PANE_COMPACT               = 0,
    MANGA_LAYOUT_TABLET_TOUCH_STUDIO               = 1,
    MANGA_LAYOUT_DUAL_PANE_ACROSS_HINGE            = 2,
    MANGA_LAYOUT_TABLETOP_CANVAS_TOP_CONTROLS_BOT  = 3,
    MANGA_LAYOUT_DESKTOP_TOUCH_HYBRID              = 4,
} MangaWorkspaceLayout;

size_t manga_project_panel_count(const MangaProjectHandle *handle);

uint8_t manga_project_undo_action(MangaProjectHandle *handle);
uint8_t manga_project_redo_action(MangaProjectHandle *handle);

/* --- Cross-Platform Posture & Adaptive Workspace Layout API --- */

uint32_t manga_platform_recommend_layout(
    uint32_t platform_code,
    uint32_t posture_code,
    float width_dp,
    float height_dp
);

uint8_t manga_platform_release_wave(uint32_t platform_code);

/* --- Tri-App Suite (Working Codenames: Hub / Manga / Novel) Boundary API --- */

typedef enum MangaSuiteApp {
    MANGA_SUITE_APP_HUB   = 0, /* Working Codename: 创想空间 / NoemaDock */
    MANGA_SUITE_APP_MANGA = 1, /* Working Codename: 雕龙 / DracoNib */
    MANGA_SUITE_APP_NOVEL = 2, /* Working Codename: 文心 / LitteraCore */
} MangaSuiteApp;

uint8_t manga_suite_can_write_path(uint32_t app_code, const char *rel_path_utf8);
uint32_t manga_suite_ram_budget_mb(uint32_t app_code);

/* --- v0.2.1 Tri-App Core API (S1 Project Init, S2 Brush Dynamics, S3 Novel Core) --- */

uint8_t manga_hub_init_project(
    const char *parent_dir_utf8,
    const char *folder_name_utf8,
    const char *author_utf8
);
uint32_t manga_brush_preset_count(void);
float manga_brush_sample_radius(uint32_t preset_code, float pressure, float altitude);
float manga_brush_zoom_adaptive_rope(float base_screen_px, float viewport_zoom);
size_t manga_novel_count_units(const char *text_utf8);

/* --- v0.2.3 & T0.2-S4 Tri-App Extended & Concurrency Soak API --- */

typedef enum MangaPrjResolutionStatus {
    MANGA_PRJ_STATUS_INVALID                 = 0,
    MANGA_PRJ_STATUS_EXACT_MATCH             = 1,
    MANGA_PRJ_STATUS_RENAMED_FOLDER_FALLBACK = 2,
} MangaPrjResolutionStatus;

uint32_t manga_hub_resolve_prj_status(const char *project_dir_utf8);

size_t manga_brush_generate_stamp_count(
    uint32_t preset_code,
    const CMangaStrokePoint *points,
    size_t count
);

uint8_t manga_novel_save_prose_atomic(
    const char *project_dir_utf8,
    const char *rel_path_utf8,
    const char *markdown_utf8,
    uint8_t is_locked,
    uint8_t explicit_human_edit
);

uint8_t manga_suite_run_s4_gate(const char *project_dir_utf8, uint32_t soak_rounds);

/* --- v0.3.1 Story Bible Atomic Hot-Reload & Layer Drawer Flags API --- */

uint8_t manga_bible_upsert_character(
    const char *project_dir_utf8,
    const char *id_utf8,
    const char *name_zh_utf8,
    const char *name_en_utf8,
    const char *role_utf8,
    const char *palette_hex_utf8
);

size_t manga_bible_character_count(const char *project_dir_utf8);
uint64_t manga_bible_revision_hash(const char *project_dir_utf8);

uint8_t manga_project_set_layer_flags(
    MangaProjectHandle *handle,
    uint64_t layer_id,
    uint8_t visible,
    uint8_t alpha_lock,
    uint8_t clipping_mask,
    uint8_t is_reference,
    uint32_t blend_mode_code,
    float opacity,
    uint8_t blue_sketch_tint
);

/* --- v0.3.2 & T0.3-S4 Live Story Bible / TOC Summary & Integration Gate API --- */

size_t manga_bible_read_summary(
    const char *project_dir_utf8,
    char *out_buf,
    size_t out_cap
);

uint8_t manga_toc_upsert_entry(
    const char *project_dir_utf8,
    const char *chapter_id_utf8,
    uint32_t number,
    const char *title_zh_utf8,
    const char *title_en_utf8,
    const char *status_utf8
);

size_t manga_toc_read_summary(
    const char *project_dir_utf8,
    char *out_buf,
    size_t out_cap
);

uint8_t manga_suite_run_t03_s4_gate(const char *project_dir_utf8);

#ifdef __cplusplus
}
#endif

#endif /* MANGA_CORE_H */
