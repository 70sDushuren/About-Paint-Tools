//! Full-Color Webtoon vertical strip slicing & seamless RGBA8 export (v0.6).

use crate::layer::LayerStack;

/// Descriptor for a single vertical slice exported from a long Webtoon canvas.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WebtoonSlice {
    pub index: usize,
    pub y_start: u32,
    pub height: u32,
}

/// Computes contiguous, zero-gap, zero-overlap vertical slices covering `0..canvas_height`.
pub fn compute_webtoon_slices(canvas_height: u32, slice_height: u32) -> Vec<WebtoonSlice> {
    if canvas_height == 0 || slice_height == 0 {
        return Vec::new();
    }
    let mut slices = Vec::new();
    let mut y = 0u32;
    let mut idx = 0usize;
    while y < canvas_height {
        let h = slice_height.min(canvas_height - y);
        slices.push(WebtoonSlice {
            index: idx,
            y_start: y,
            height: h,
        });
        y += h;
        idx += 1;
    }
    slices
}

/// Composites an exact RGBA8 pixel buffer for `slice` from `stack`.
pub fn render_webtoon_slice_rgba(stack: &LayerStack, slice: WebtoonSlice) -> Vec<u8> {
    let w = stack.width as usize;
    let h = slice.height as usize;
    let mut buf = vec![0u8; w * h * 4];
    for ly in 0..h {
        let cy = slice.y_start + ly as u32;
        for lx in 0..w {
            let rgba = stack.composite_pixel(lx as u32, cy);
            let offset = (ly * w + lx) * 4;
            buf[offset..offset + 4].copy_from_slice(&rgba);
        }
    }
    buf
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn webtoon_slicer_handles_exact_and_remainder_heights_seamlessly() {
        let slices = compute_webtoon_slices(3000, 1280);
        assert_eq!(slices.len(), 3);
        assert_eq!(slices[0], WebtoonSlice { index: 0, y_start: 0, height: 1280 });
        assert_eq!(slices[1], WebtoonSlice { index: 1, y_start: 1280, height: 1280 });
        assert_eq!(slices[2], WebtoonSlice { index: 2, y_start: 2560, height: 440 });
    }

    #[test]
    fn rendered_webtoon_slices_stitch_with_zero_seam_mismatch() {
        let mut stack = LayerStack::new(16, 40);
        let base = stack.add_raster_layer("Color");
        // Paint a vertical gradient crossing the slice boundary at y = 19 -> y = 20.
        for y in 0..40 {
            stack
                .get_mut(base)
                .unwrap()
                .write_pixel(8, y, [(y * 5) as u8, 120, 200, 255]);
        }

        let slices = compute_webtoon_slices(40, 20);
        let buf0 = render_webtoon_slice_rgba(&stack, slices[0]);
        let buf1 = render_webtoon_slice_rgba(&stack, slices[1]);

        let last_row_px = &buf0[(19 * 16 + 8) * 4..(19 * 16 + 8) * 4 + 4];
        let first_row_px = &buf1[8 * 4..8 * 4 + 4];
        assert_eq!(last_row_px, &[95, 120, 200, 255]);
        assert_eq!(first_row_px, &[100, 120, 200, 255]);
    }
}
