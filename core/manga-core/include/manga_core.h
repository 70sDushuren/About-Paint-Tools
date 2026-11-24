#ifndef MANGA_CORE_H
#define MANGA_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MangaCanvasHandle MangaCanvasHandle;

typedef enum MangaCanvasPreset {
    MANGA_PRESET_B4_PRINT_600DPI = 0,
    MANGA_PRESET_A4_PRINT_600DPI = 1,
    MANGA_PRESET_WEBTOON_800     = 2,
    MANGA_PRESET_WEBTOON_1600    = 3,
    MANGA_PRESET_ILLUSTRATION_4K = 4,
} MangaCanvasPreset;

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

#ifdef __cplusplus
}
#endif

#endif /* MANGA_CORE_H */
