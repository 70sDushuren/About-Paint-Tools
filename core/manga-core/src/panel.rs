//! Manga Panel Frame Folder geometry & diagonal/grid slicing (v0.6).
//!
//! Uses exact Sutherland-Hodgman half-plane clipping with configurable gutter
//! spacing so artists can slice panels horizontally, vertically, or diagonally
//! while automatically masking strokes strictly inside each panel's interior.

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct PanelId(pub u64);

/// 2D polygon defining a comic panel's interior mask and border path.
#[derive(Debug, Clone, PartialEq)]
pub struct PanelPolygon {
    pub vertices: Vec<(f32, f32)>,
}

impl PanelPolygon {
    pub fn rect(min_x: f32, min_y: f32, max_x: f32, max_y: f32) -> Self {
        Self {
            vertices: vec![
                (min_x, min_y),
                (max_x, min_y),
                (max_x, max_y),
                (min_x, max_y),
            ],
        }
    }

    /// Unsigned area via shoelace formula.
    pub fn area(&self) -> f32 {
        let n = self.vertices.len();
        if n < 3 {
            return 0.0;
        }
        let mut sum = 0.0f32;
        for i in 0..n {
            let (x1, y1) = self.vertices[i];
            let (x2, y2) = self.vertices[(i + 1) % n];
            sum += x1 * y2 - x2 * y1;
        }
        (sum * 0.5).abs()
    }

    /// Even-odd ray-casting point-in-polygon mask check.
    pub fn contains_point(&self, px: f32, py: f32) -> bool {
        let n = self.vertices.len();
        if n < 3 {
            return false;
        }
        let mut inside = false;
        let mut j = n - 1;
        for i in 0..n {
            let (xi, yi) = self.vertices[i];
            let (xj, yj) = self.vertices[j];
            let intersects = ((yi > py) != (yj > py))
                && (px < (xj - xi) * (py - yi) / ((yj - yi) + 1e-12) + xi);
            if intersects {
                inside = !inside;
            }
            j = i;
        }
        inside
    }

    /// Clips this polygon against the half-plane `nx * x + ny * y >= offset`.
    fn clip_half_plane(&self, nx: f32, ny: f32, offset: f32) -> Option<Self> {
        let n = self.vertices.len();
        if n < 3 {
            return None;
        }
        let mut out = Vec::with_capacity(n + 2);
        let eval = |p: (f32, f32)| nx * p.0 + ny * p.1 - offset;

        for i in 0..n {
            let a = self.vertices[i];
            let b = self.vertices[(i + 1) % n];
            let da = eval(a);
            let db = eval(b);
            let in_a = da >= -1e-4;
            let in_b = db >= -1e-4;

            if in_a && in_b {
                out.push(b);
            } else if in_a && !in_b {
                let t = (da / (da - db)).clamp(0.0, 1.0);
                out.push((a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t));
            } else if !in_a && in_b {
                let t = (da / (da - db)).clamp(0.0, 1.0);
                out.push((a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t));
                out.push(b);
            }
        }

        if out.len() < 3 {
            return None;
        }
        let poly = Self { vertices: out };
        if poly.area() > 1.0 {
            Some(poly)
        } else {
            None
        }
    }
}

/// A single manga panel frame folder carrying its mask polygon and border style.
#[derive(Debug, Clone, PartialEq)]
pub struct PanelFrame {
    pub id: PanelId,
    pub name: String,
    pub polygon: PanelPolygon,
    pub border_width_px: f32,
    pub border_rgba: [u8; 4],
}

/// Page-level panel layout manager supporting knife slicing with configurable gutters.
#[derive(Debug, Clone)]
pub struct PanelLayout {
    next_id: u64,
    panels: Vec<PanelFrame>,
}

impl PanelLayout {
    /// Creates an initial single live-frame panel inset from the page border.
    pub fn new_page_frame(width: f32, height: f32, margin_x: f32, margin_y: f32) -> Self {
        let poly = PanelPolygon::rect(margin_x, margin_y, width - margin_x, height - margin_y);
        Self {
            next_id: 2,
            panels: vec![PanelFrame {
                id: PanelId(1),
                name: "Panel_1".into(),
                polygon: poly,
                border_width_px: 4.0,
                border_rgba: [0, 0, 0, 255],
            }],
        }
    }

    pub fn panels(&self) -> &[PanelFrame] {
        &self.panels
    }

    pub fn get(&self, id: PanelId) -> Option<&PanelFrame> {
        self.panels.iter().find(|p| p.id == id)
    }

    pub fn is_inside_panel(&self, id: PanelId, x: f32, y: f32) -> bool {
        self.get(id)
            .map(|p| p.polygon.contains_point(x, y))
            .unwrap_or(false)
    }

    /// Slices `panel_id` along the line through `line_a -> line_b` with perpendicular
    /// spacing `gutter_px`. Returns `Some((id_positive, id_negative))` if the cut splits
    /// the panel into two valid non-empty panels.
    pub fn slice_panel(
        &mut self,
        panel_id: PanelId,
        line_a: (f32, f32),
        line_b: (f32, f32),
        gutter_px: f32,
    ) -> Option<(PanelId, PanelId)> {
        let idx = self.panels.iter().position(|p| p.id == panel_id)?;
        let dx = line_b.0 - line_a.0;
        let dy = line_b.1 - line_a.1;
        let len = dx.hypot(dy);
        if len < 1e-4 {
            return None;
        }
        // Unit normal perpendicular to the knife line.
        let nx = -dy / len;
        let ny = dx / len;
        let c = nx * line_a.0 + ny * line_a.1;
        let half_gutter = gutter_px.max(0.0) * 0.5;

        let target = &self.panels[idx];
        let poly_pos = target.polygon.clip_half_plane(nx, ny, c + half_gutter)?;
        let poly_neg = target.polygon.clip_half_plane(-nx, -ny, -(c - half_gutter))?;

        let border_w = target.border_width_px;
        let border_rgba = target.border_rgba;
        self.panels.remove(idx);

        let id1 = PanelId(self.next_id);
        self.next_id += 1;
        let id2 = PanelId(self.next_id);
        self.next_id += 1;

        self.panels.push(PanelFrame {
            id: id1,
            name: format!("Panel_{}", id1.0),
            polygon: poly_pos,
            border_width_px: border_w,
            border_rgba,
        });
        self.panels.push(PanelFrame {
            id: id2,
            name: format!("Panel_{}", id2.0),
            polygon: poly_neg,
            border_width_px: border_w,
            border_rgba,
        });

        Some((id1, id2))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn horizontal_and_diagonal_panel_slices_preserve_gutter_and_masking() {
        let mut layout = PanelLayout::new_page_frame(1000.0, 1400.0, 100.0, 100.0);
        assert_eq!(layout.panels().len(), 1);
        assert!(layout.is_inside_panel(PanelId(1), 500.0, 700.0));
        assert!(!layout.is_inside_panel(PanelId(1), 50.0, 50.0));

        // Horizontal cut at y = 700 with 40px gutter -> [100..680] and [720..1300]
        let (p_bot, p_top) = layout
            .slice_panel(PanelId(1), (0.0, 700.0), (1000.0, 700.0), 40.0)
            .expect("Horizontal slice should produce 2 panels");
        assert_eq!(layout.panels().len(), 2);

        // Point inside the 40px gutter (y = 700) belongs to NEITHER panel!
        assert!(!layout.is_inside_panel(p_bot, 500.0, 700.0));
        assert!(!layout.is_inside_panel(p_top, 500.0, 700.0));

        // Diagonal action-manga knife cut on one panel!
        let (d1, d2) = layout
            .slice_panel(p_bot, (100.0, 800.0), (900.0, 1200.0), 20.0)
            .expect("Diagonal slice should split bottom panel cleanly");
        assert_eq!(layout.panels().len(), 3);
        assert!(layout.get(d1).unwrap().polygon.area() > 10_000.0);
        assert!(layout.get(d2).unwrap().polygon.area() > 10_000.0);
    }
}
