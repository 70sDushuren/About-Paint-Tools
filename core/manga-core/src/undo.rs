//! Copy-on-Write tile-level Undo/Redo history stack.
//!
//! Each stroke records only the `Arc<TileData>` references of dirty tiles
//! before and after mutation, keeping 100+ undo steps fast and memory-bounded.

use std::sync::Arc;

use crate::tile::{TileCoord, TileData, TileLayer};

/// Diff for a single stroke or atomic operation affecting a subset of tiles.
#[derive(Debug, Clone)]
pub struct TileDiff {
    pub entries: Vec<(TileCoord, Option<Arc<TileData>>, Option<Arc<TileData>>)>,
}

/// Bounded undo/redo manager operating over a `TileLayer`.
#[derive(Debug, Default)]
pub struct TileUndoStack {
    undo_stack: Vec<TileDiff>,
    redo_stack: Vec<TileDiff>,
    max_steps: usize,
}

impl TileUndoStack {
    pub fn new(max_steps: usize) -> Self {
        Self {
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            max_steps: max_steps.max(1),
        }
    }

    pub fn push(&mut self, diff: TileDiff) {
        if diff.entries.is_empty() {
            return;
        }
        if self.undo_stack.len() == self.max_steps {
            self.undo_stack.remove(0);
        }
        self.undo_stack.push(diff);
        self.redo_stack.clear();
    }

    pub fn undo(&mut self, layer: &mut TileLayer) -> bool {
        let Some(diff) = self.undo_stack.pop() else {
            return false;
        };
        for (coord, before, _) in &diff.entries {
            layer.set_tile(*coord, before.clone());
        }
        self.redo_stack.push(diff);
        true
    }

    pub fn redo(&mut self, layer: &mut TileLayer) -> bool {
        let Some(diff) = self.redo_stack.pop() else {
            return false;
        };
        for (coord, _, after) in &diff.entries {
            layer.set_tile(*coord, after.clone());
        }
        self.undo_stack.push(diff);
        true
    }

    pub fn can_undo(&self) -> bool {
        !self.undo_stack.is_empty()
    }

    pub fn can_redo(&self) -> bool {
        !self.redo_stack.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cow_undo_and_redo_restore_exact_tile_state() {
        let mut layer = TileLayer::new(1024, 1024);
        let mut history = TileUndoStack::new(100);

        let coord = TileCoord { tx: 0, ty: 0 };
        let before = layer.get_tile(coord);
        layer.set_pixel(10, 12, [10, 20, 30, 255]);
        let after = layer.get_tile(coord);
        history.push(TileDiff {
            entries: vec![(coord, before, after)],
        });

        assert_eq!(layer.get_pixel(10, 12), [10, 20, 30, 255]);
        assert!(history.undo(&mut layer));
        assert_eq!(layer.get_pixel(10, 12), [0, 0, 0, 0]);
        assert_eq!(layer.allocated_tile_count(), 0);

        assert!(history.redo(&mut layer));
        assert_eq!(layer.get_pixel(10, 12), [10, 20, 30, 255]);
        assert_eq!(layer.allocated_tile_count(), 1);
    }
}
