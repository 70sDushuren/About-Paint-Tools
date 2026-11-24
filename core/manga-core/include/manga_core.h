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

size_t manga_project_panel_count(const MangaProjectHandle *handle);

uint8_t manga_project_undo_action(MangaProjectHandle *handle);
uint8_t manga_project_redo_action(MangaProjectHandle *handle);

#ifdef __cplusplus
}
#endif

#endif /* MANGA_CORE_H */
