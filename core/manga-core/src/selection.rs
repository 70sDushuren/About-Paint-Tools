//! `S2 v0.4` — Selection Mask Engine: Rectangular, Freehand Lasso Polygon (even-odd ray-casting),
//! Invert, and Morphological Expand / Contract for anime flatting & cel-shading workflows.

/// 2D boolean selection mask matching canvas dimensions.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SelectionMask {
    pub width: u32,
    pub height: u32,
    mask: Vec<bool>,
}

impl SelectionMask {
    pub fn empty(width: u32, height: u32) -> Self {
        Self {
            width,
            height,
            mask: vec![false; (width as usize).saturating_mul(height as usize)],
        }
    }

    pub fn all(width: u32, height: u32) -> Self {
        Self {
            width,
            height,
            mask: vec![true; (width as usize).saturating_mul(height as usize)],
        }
    }

    pub fn from_rect(width: u32, height: u32, x0: u32, y0: u32, x1: u32, y1: u32) -> Self {
        let mut sel = Self::empty(width, height);
        let min_x = x0.min(x1).min(width);
        let max_x = x0.max(x1).min(width);
        let min_y = y0.min(y1).min(height);
        let max_y = y0.max(y1).min(height);
        let w = width as usize;
        for y in min_y..max_y {
            let row = y as usize * w;
            for x in min_x..max_x {
                sel.mask[row + x as usize] = true;
            }
        }
        sel
    }

    /// Contiguous 4-connected Magic Wand selection from `(seed_x, seed_y)` over composite pixels
    /// (or reference lineart layers when `use_reference == true`) within `tolerance` per channel.
    pub fn from_magic_wand(
        stack: &crate::layer::LayerStack,
        seed_x: u32,
        seed_y: u32,
        tolerance: u8,
        use_reference: bool,
    ) -> Self {
        let w = stack.width;
        let h = stack.height;
        let mut sel = Self::empty(w, h);
        if seed_x >= w || seed_y >= h || w == 0 || h == 0 {
            return sel;
        }
        let ref_ids = if use_reference {
            stack.reference_layer_ids()
        } else {
            Vec::new()
        };
        let sample_px = |x: u32, y: u32| -> [u8; 4] {
            if use_reference && !ref_ids.is_empty() {
                let mut acc = [0u8, 0, 0, 0];
                for &rid in &ref_ids {
                    if let Some(l) = stack.get(rid) {
                        let p = l.sample_display_pixel(x, y);
                        if p[3] > 0 {
                            acc = crate::layer::blend_rgba(acc, p, crate::layer::BlendMode::Normal);
                        }
                    }
                }
                acc
            } else {
                stack.composite_pixel(x, y)
            }
        };

        let target = sample_px(seed_x, seed_y);
        let tol = i32::from(tolerance);
        let matches = |p: [u8; 4]| -> bool {
            (i32::from(p[0]) - i32::from(target[0])).abs() <= tol
                && (i32::from(p[1]) - i32::from(target[1])).abs() <= tol
                && (i32::from(p[2]) - i32::from(target[2])).abs() <= tol
                && (i32::from(p[3]) - i32::from(target[3])).abs() <= tol
        };

        let uw = w as usize;
        let mut visited = vec![false; uw * (h as usize)];
        let mut queue = std::collections::VecDeque::with_capacity(1024);
        let start_idx = seed_y as usize * uw + seed_x as usize;
        visited[start_idx] = true;
        sel.mask[start_idx] = true;
        queue.push_back((seed_x, seed_y));

        while let Some((cx, cy)) = queue.pop_front() {
            let neighbors = [
                (cx.wrapping_sub(1), cy, cx > 0),
                (cx + 1, cy, cx + 1 < w),
                (cx, cy.wrapping_sub(1), cy > 0),
                (cx, cy + 1, cy + 1 < h),
            ];
            for (nx, ny, ok) in neighbors {
                if !ok {
                    continue;
                }
                let idx = ny as usize * uw + nx as usize;
                if visited[idx] {
                    continue;
                }
                visited[idx] = true;
                if matches(sample_px(nx, ny)) {
                    sel.mask[idx] = true;
                    queue.push_back((nx, ny));
                }
            }
        }
        sel
    }

    /// Returns axis-aligned bounding box `(min_x, min_y, max_x, max_y)` of selected pixels, if non-empty.
    pub fn bounds(&self) -> Option<(u32, u32, u32, u32)> {
        let mut min_x = u32::MAX;
        let mut min_y = u32::MAX;
        let mut max_x = 0u32;
        let mut max_y = 0u32;
        let mut found = false;
        let w = self.width as usize;
        for y in 0..self.height {
            let row = y as usize * w;
            for x in 0..self.width {
                if self.mask[row + x as usize] {
                    found = true;
                    min_x = min_x.min(x);
                    min_y = min_y.min(y);
                    max_x = max_x.max(x + 1);
                    max_y = max_y.max(y + 1);
                }
            }
        }
        if found {
            Some((min_x, min_y, max_x, max_y))
        } else {
            None
        }
    }

    /// Rasterizes a closed freehand lasso polygon using deterministic even-odd ray-casting.
    pub fn from_lasso_polygon(width: u32, height: u32, polygon: &[(f32, f32)]) -> Self {
        let mut sel = Self::empty(width, height);
        if polygon.len() < 3 || width == 0 || height == 0 {
            return sel;
        }
        let mut min_x = f32::INFINITY;
        let mut max_x = f32::NEG_INFINITY;
        let mut min_y = f32::INFINITY;
        let mut max_y = f32::NEG_INFINITY;
        for &(px, py) in polygon {
            min_x = min_x.min(px);
            max_x = max_x.max(px);
            min_y = min_y.min(py);
            max_y = max_y.max(py);
        }
        let bx0 = (min_x.floor().max(0.0) as u32).min(width);
        let bx1 = (max_x.ceil().max(0.0) as u32).min(width);
        let by0 = (min_y.floor().max(0.0) as u32).min(height);
        let by1 = (max_y.ceil().max(0.0) as u32).min(height);
        let w = width as usize;

        for y in by0..by1 {
            let py = y as f32 + 0.5;
            let row = y as usize * w;
            for x in bx0..bx1 {
                let px = x as f32 + 0.5;
                if point_in_polygon(px, py, polygon) {
                    sel.mask[row + x as usize] = true;
                }
            }
        }
        sel
    }

    #[inline]
    pub fn contains(&self, x: u32, y: u32) -> bool {
        if x >= self.width || y >= self.height {
            return false;
        }
        self.mask[y as usize * self.width as usize + x as usize]
    }

    #[inline]
    pub fn set(&mut self, x: u32, y: u32, selected: bool) {
        if x < self.width && y < self.height {
            self.mask[y as usize * self.width as usize + x as usize] = selected;
        }
    }

    pub fn selected_pixel_count(&self) -> usize {
        self.mask.iter().filter(|&&v| v).count()
    }

    pub fn invert(&mut self) {
        for v in &mut self.mask {
            *v = !*v;
        }
    }

    /// Expands selection outward by `radius_px` (positive) or contracts inward (negative).
    pub fn adjust_border(&mut self, delta_px: i32) {
        if delta_px == 0 || self.width == 0 || self.height == 0 {
            return;
        }
        let radius = delta_px.unsigned_abs() as usize;
        let w = self.width as usize;
        let h = self.height as usize;
        if delta_px > 0 {
            self.mask = morph_dilate(&self.mask, w, h, radius);
        } else {
            // Erosion = invert(dilate(invert(mask)))
            let inv: Vec<bool> = self.mask.iter().map(|&v| !v).collect();
            let dilated = morph_dilate(&inv, w, h, radius);
            self.mask = dilated.into_iter().map(|v| !v).collect();
        }
    }
}

fn point_in_polygon(px: f32, py: f32, poly: &[(f32, f32)]) -> bool {
    let mut inside = false;
    let n = poly.len();
    let mut j = n - 1;
    for i in 0..n {
        let (xi, yi) = poly[i];
        let (xj, yj) = poly[j];
        let intersects = ((yi > py) != (yj > py))
            && (px < (xj - xi) * (py - yi) / ((yj - yi) + f32::EPSILON) + xi);
        if intersects {
            inside = !inside;
        }
        j = i;
    }
    inside
}

fn morph_dilate(mask: &[bool], w: usize, h: usize, radius: usize) -> Vec<bool> {
    let mut horiz = vec![false; w * h];
    for y in 0..h {
        let row = y * w;
        let mut count = 0usize;
        let init_end = radius.min(w - 1);
        for x in 0..=init_end {
            if mask[row + x] {
                count += 1;
            }
        }
        for x in 0..w {
            horiz[row + x] = count > 0;
            if x >= radius && mask[row + x - radius] {
                count -= 1;
            }
            if x + radius + 1 < w && mask[row + x + radius + 1] {
                count += 1;
            }
        }
    }
    let mut out = vec![false; w * h];
    for x in 0..w {
        let mut count = 0usize;
        let init_end = radius.min(h - 1);
        for y in 0..=init_end {
            if horiz[y * w + x] {
                count += 1;
            }
        }
        for y in 0..h {
            out[y * w + x] = count > 0;
            if y >= radius && horiz[(y - radius) * w + x] {
                count -= 1;
            }
            if y + radius + 1 < h && horiz[(y + radius + 1) * w + x] {
                count += 1;
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lasso_polygon_selection_invert_and_border_expand_contract_work() {
        let square = [(10.0, 10.0), (30.0, 10.0), (30.0, 30.0), (10.0, 30.0)];
        let mut sel = SelectionMask::from_lasso_polygon(64, 64, &square);
        assert_eq!(sel.selected_pixel_count(), 400);
        assert!(sel.contains(20, 20));
        assert!(!sel.contains(5, 5));

        sel.adjust_border(2);
        assert_eq!(sel.selected_pixel_count(), 24 * 24);
        assert!(sel.contains(9, 20));

        sel.adjust_border(-2);
        assert_eq!(sel.selected_pixel_count(), 400);

        sel.invert();
        assert_eq!(sel.selected_pixel_count(), 64 * 64 - 400);
        assert!(!sel.contains(20, 20));
        assert!(sel.contains(5, 5));
    }
}
