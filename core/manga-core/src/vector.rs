//! Variable-width vector lineart layer & Vector Intersection Eraser (v0.5).
//!
//! Stores centerlines with per-node pressure widths for lossless scaling,
//! localized line-width tweaking, and single-swipe intersection erasing.

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct VectorStrokeId(pub u64);

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct VectorNode {
    pub x: f32,
    pub y: f32,
    pub width: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Aabb {
    pub min_x: f32,
    pub min_y: f32,
    pub max_x: f32,
    pub max_y: f32,
}

impl Aabb {
    pub fn overlaps(&self, other: &Self, pad: f32) -> bool {
        self.min_x - pad <= other.max_x
            && self.max_x + pad >= other.min_x
            && self.min_y - pad <= other.max_y
            && self.max_y + pad >= other.min_y
    }

    pub fn contains_point(&self, x: f32, y: f32, pad: f32) -> bool {
        x >= self.min_x - pad
            && x <= self.max_x + pad
            && y >= self.min_y - pad
            && y <= self.max_y + pad
    }
}

/// A single variable-width polyline/curve stroke in a vector lineart layer.
#[derive(Debug, Clone, PartialEq)]
pub struct VectorStroke {
    pub id: VectorStrokeId,
    pub color_rgba: [u8; 4],
    pub nodes: Vec<VectorNode>,
}

impl VectorStroke {
    pub fn aabb(&self) -> Option<Aabb> {
        let first = self.nodes.first()?;
        let mut b = Aabb {
            min_x: first.x,
            min_y: first.y,
            max_x: first.x,
            max_y: first.y,
        };
        for n in &self.nodes[1..] {
            b.min_x = b.min_x.min(n.x);
            b.min_y = b.min_y.min(n.y);
            b.max_x = b.max_x.max(n.x);
            b.max_y = b.max_y.max(n.y);
        }
        Some(b)
    }

    pub fn max_param(&self) -> f32 {
        self.nodes.len().saturating_sub(1) as f32
    }

    /// Evaluates interpolated `(x, y, width)` at continuous parameter `u in [0, nodes.len()-1]`.
    pub fn sample_at(&self, u: f32) -> VectorNode {
        let last_idx = self.nodes.len() - 1;
        let clamped = u.clamp(0.0, last_idx as f32);
        let seg = (clamped.floor() as usize).min(last_idx.saturating_sub(1));
        let t = clamped - seg as f32;
        let a = self.nodes[seg];
        let b = self.nodes[seg + 1];
        VectorNode {
            x: a.x + (b.x - a.x) * t,
            y: a.y + (b.y - a.y) * t,
            width: a.width + (b.width - a.width) * t,
        }
    }

    /// Losslessly scales all node coordinates and stroke widths.
    pub fn scale(&mut self, factor: f32) {
        for n in &mut self.nodes {
            n.x *= factor;
            n.y *= factor;
            n.width = (n.width * factor).max(0.25);
        }
    }

    /// Adjusts width for all nodes within `radius` of `(cx, cy)` (CSP-style local line-width tool).
    pub fn adjust_width_in_radius(&mut self, cx: f32, cy: f32, radius: f32, delta: f32) -> usize {
        let r2 = radius * radius;
        let mut modified = 0;
        for n in &mut self.nodes {
            let dx = n.x - cx;
            let dy = n.y - cy;
            if dx * dx + dy * dy <= r2 {
                n.width = (n.width + delta).clamp(0.25, 500.0);
                modified += 1;
            }
        }
        modified
    }

    /// Extracts a continuous sub-stroke for parameter range `[u_start, u_end]`.
    fn slice_substroke(&self, new_id: VectorStrokeId, u_start: f32, u_end: f32) -> Option<Self> {
        const EPS: f32 = 1e-4;
        if u_end - u_start <= EPS || self.nodes.len() < 2 {
            return None;
        }
        let mut out = Vec::new();
        out.push(self.sample_at(u_start));

        let first_interior = (u_start.floor() as usize) + 1;
        let last_interior = (u_end.ceil() as usize).saturating_sub(1);
        for idx in first_interior..=last_interior {
            if idx < self.nodes.len() {
                out.push(self.nodes[idx]);
            }
        }

        let end_node = self.sample_at(u_end);
        let prev = *out.last().unwrap();
        if (end_node.x - prev.x).hypot(end_node.y - prev.y) > EPS {
            out.push(end_node);
        }

        if out.len() < 2 {
            return None;
        }
        Some(Self {
            id: new_id,
            color_rgba: self.color_rgba,
            nodes: out,
        })
    }
}

/// Closest point on segment `(a, b)` to `(px, py)` returning `(dist_sq, t in [0, 1])`.
fn closest_point_on_segment(a: VectorNode, b: VectorNode, px: f32, py: f32) -> (f32, f32) {
    let abx = b.x - a.x;
    let aby = b.y - a.y;
    let len2 = abx * abx + aby * aby;
    let t = if len2 > 1e-8 {
        (((px - a.x) * abx + (py - a.y) * aby) / len2).clamp(0.0, 1.0)
    } else {
        0.0
    };
    let cx = a.x + abx * t;
    let cy = a.y + aby * t;
    let dx = px - cx;
    let dy = py - cy;
    (dx * dx + dy * dy, t)
}

/// Exact parametric intersection between segments `(p1, p2)` and `(q1, q2)`.
/// Returns `Some(t)` on `(p1, p2)` when the segments intersect within `[0, 1]`.
fn segment_intersection_t(p1: VectorNode, p2: VectorNode, q1: VectorNode, q2: VectorNode) -> Option<f32> {
    let rx = p2.x - p1.x;
    let ry = p2.y - p1.y;
    let sx = q2.x - q1.x;
    let sy = q2.y - q1.y;
    let denom = rx * sy - ry * sx;
    if denom.abs() < 1e-6 {
        return None;
    }
    let qpx = q1.x - p1.x;
    let qpy = q1.y - p1.y;
    let t = (qpx * sy - qpy * sx) / denom;
    let u = (qpx * ry - qpy * rx) / denom;
    const TOL: f32 = 1e-5;
    if (-TOL..=1.0 + TOL).contains(&t) && (-TOL..=1.0 + TOL).contains(&u) {
        Some(t.clamp(0.0, 1.0))
    } else {
        None
    }
}

/// Vector lineart layer supporting lossless scaling, width editing, and intersection erasing.
#[derive(Debug, Clone, Default)]
pub struct VectorLayer {
    next_id: u64,
    strokes: Vec<VectorStroke>,
}

impl VectorLayer {
    pub fn new() -> Self {
        Self {
            next_id: 1,
            strokes: Vec::new(),
        }
    }

    pub fn add_stroke(&mut self, color_rgba: [u8; 4], nodes: Vec<VectorNode>) -> Option<VectorStrokeId> {
        if nodes.len() < 2 {
            return None;
        }
        let id = VectorStrokeId(self.next_id);
        self.next_id += 1;
        self.strokes.push(VectorStroke {
            id,
            color_rgba,
            nodes,
        });
        Some(id)
    }

    pub fn strokes(&self) -> &[VectorStroke] {
        &self.strokes
    }

    pub fn strokes_mut(&mut self) -> &mut [VectorStroke] {
        &mut self.strokes
    }

    /// Vector Intersection Eraser:
    /// Finds the stroke closest to `(hit_x, hit_y)` within `hit_radius`, locates its
    /// nearest intersections on either side of the hit point, and trims strictly that span.
    ///
    /// Returns `true` if a stroke segment was erased/trimmed.
    pub fn erase_to_intersection(&mut self, hit_x: f32, hit_y: f32, hit_radius: f32) -> bool {
        let mut best_hit: Option<(usize, f32, f32)> = None; // (stroke_idx, u_hit, dist_sq)
        let r2 = hit_radius * hit_radius;

        for (s_idx, stroke) in self.strokes.iter().enumerate() {
            let Some(aabb) = stroke.aabb() else { continue };
            if !aabb.contains_point(hit_x, hit_y, hit_radius) {
                continue;
            }
            for seg in 0..stroke.nodes.len() - 1 {
                let (d2, t) = closest_point_on_segment(stroke.nodes[seg], stroke.nodes[seg + 1], hit_x, hit_y);
                if d2 <= r2 {
                    let replace = match best_hit {
                        None => true,
                        Some((_, _, best_d2)) => d2 < best_d2,
                    };
                    if replace {
                        best_hit = Some((s_idx, seg as f32 + t, d2));
                    }
                }
            }
        }

        let Some((hit_idx, u_hit, _)) = best_hit else {
            return false;
        };

        let target = self.strokes[hit_idx].clone();
        let target_aabb = target.aabb().unwrap();
        let mut intersections: Vec<f32> = Vec::new();

        for (other_idx, other) in self.strokes.iter().enumerate() {
            let Some(other_aabb) = other.aabb() else { continue };
            if !target_aabb.overlaps(&other_aabb, 1.0) {
                continue;
            }
            for i in 0..target.nodes.len() - 1 {
                for j in 0..other.nodes.len() - 1 {
                    // Skip same or adjacent segments when checking self-intersections.
                    if other_idx == hit_idx && i.abs_diff(j) <= 1 {
                        continue;
                    }
                    if let Some(t) = segment_intersection_t(
                        target.nodes[i],
                        target.nodes[i + 1],
                        other.nodes[j],
                        other.nodes[j + 1],
                    ) {
                        intersections.push(i as f32 + t);
                    }
                }
            }
        }

        const EPS: f32 = 1e-3;
        let max_u = target.max_param();
        let mut u_prev = 0.0f32;
        let mut u_next = max_u;

        for u_int in intersections {
            if u_int < u_hit - EPS && u_int > u_prev {
                u_prev = u_int;
            } else if u_int > u_hit + EPS && u_int < u_next {
                u_next = u_int;
            }
        }

        // Replace hit stroke with surviving left/right remnants.
        self.strokes.remove(hit_idx);
        let left_id = VectorStrokeId(self.next_id);
        self.next_id += 1;
        let right_id = VectorStrokeId(self.next_id);
        self.next_id += 1;

        if let Some(left) = target.slice_substroke(left_id, 0.0, u_prev) {
            self.strokes.push(left);
        }
        if let Some(right) = target.slice_substroke(right_id, u_next, max_u) {
            self.strokes.push(right);
        }

        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn intersection_eraser_trims_only_overshoot_tail_on_crossed_strokes() {
        let mut vlayer = VectorLayer::new();
        // Horizontal line y = 50 from x = 0 to x = 100
        vlayer.add_stroke(
            [0, 0, 0, 255],
            vec![
                VectorNode { x: 0.0, y: 50.0, width: 2.0 },
                VectorNode { x: 100.0, y: 50.0, width: 2.0 },
            ],
        );
        // Vertical crossing line x = 50 from y = 0 to y = 100
        vlayer.add_stroke(
            [0, 0, 0, 255],
            vec![
                VectorNode { x: 50.0, y: 0.0, width: 2.0 },
                VectorNode { x: 50.0, y: 100.0, width: 2.0 },
            ],
        );

        // Tap right overshoot tail at (80, 50)
        assert!(vlayer.erase_to_intersection(80.0, 50.0, 5.0));
        assert_eq!(vlayer.strokes().len(), 2);

        // Find the trimmed horizontal stroke: it must now end exactly at x = 50.0!
        let horiz = vlayer
            .strokes()
            .iter()
            .find(|s| (s.nodes[0].y - 50.0).abs() < 1e-3 && (s.nodes[1].y - 50.0).abs() < 1e-3)
            .expect("Trimmed horizontal stroke should remain");
        assert!((horiz.nodes[0].x - 0.0).abs() < 1e-3);
        assert!((horiz.nodes[1].x - 50.0).abs() < 1e-3);
    }

    #[test]
    fn intersection_eraser_splits_middle_bridge_between_two_crossings() {
        let mut vlayer = VectorLayer::new();
        // Horizontal bar from x = 0 to x = 100 at y = 50
        vlayer.add_stroke(
            [0, 0, 0, 255],
            vec![
                VectorNode { x: 0.0, y: 50.0, width: 2.0 },
                VectorNode { x: 100.0, y: 50.0, width: 2.0 },
            ],
        );
        // Two vertical rails at x = 25 and x = 75
        vlayer.add_stroke(
            [0, 0, 0, 255],
            vec![
                VectorNode { x: 25.0, y: 0.0, width: 2.0 },
                VectorNode { x: 25.0, y: 100.0, width: 2.0 },
            ],
        );
        vlayer.add_stroke(
            [0, 0, 0, 255],
            vec![
                VectorNode { x: 75.0, y: 0.0, width: 2.0 },
                VectorNode { x: 75.0, y: 100.0, width: 2.0 },
            ],
        );

        // Tap middle bridge at (50, 50) -> splits horizontal bar into [0..25] and [75..100]
        assert!(vlayer.erase_to_intersection(50.0, 50.0, 5.0));
        assert_eq!(vlayer.strokes().len(), 4);
    }

    #[test]
    fn local_width_adjustment_modifies_only_nodes_within_radius() {
        let mut stroke = VectorStroke {
            id: VectorStrokeId(1),
            color_rgba: [0, 0, 0, 255],
            nodes: vec![
                VectorNode { x: 0.0, y: 0.0, width: 2.0 },
                VectorNode { x: 50.0, y: 0.0, width: 2.0 },
                VectorNode { x: 100.0, y: 0.0, width: 2.0 },
            ],
        };
        let count = stroke.adjust_width_in_radius(50.0, 0.0, 10.0, 3.0);
        assert_eq!(count, 1);
        assert_eq!(stroke.nodes[0].width, 2.0);
        assert_eq!(stroke.nodes[1].width, 5.0);
        assert_eq!(stroke.nodes[2].width, 2.0);
    }
}
