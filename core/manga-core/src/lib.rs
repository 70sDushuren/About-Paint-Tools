//! `manga-core`: MIT-licensed cross-platform engine core for About-Paint-Tools.
//!
//! Designed to power hardware-native UI shells (iPadOS UIKit/SwiftUI first,
//! with future macOS, Android, and Windows shells) while sharing deterministic
//! dual-track presets, sparse tile storage, cel-shading blend layers, anti-halo
//! close-gap fill, vector lineart with intersection erasing, manga rulers,
//! panel slicing, procedural screentones, Webtoon slicing, continuity logs,
//! and a transactional `ActionBus` for local Gemma 4 Function Calling.

pub mod action_bus;
pub mod canvas;
pub mod continuity;
pub mod ffi;
pub mod fill;
pub mod layer;
pub mod panel;
pub mod preset;
pub mod ruler;
pub mod screentone;
pub mod stroke;
pub mod tile;
pub mod undo;
pub mod vector;
pub mod webtoon;

pub use action_bus::{ActionBus, ActionCommand, ActionPlan, ActionPreview, ProjectDocument};
pub use canvas::{CanvasSession, ViewportTransform};
pub use continuity::{
    CharacterSheet, ContinuityEntry, ContinuityLog, ContinuityReviewPin, NoteSource,
    CONTINUITY_SQLITE_DDL,
};
pub use fill::{close_gap_expand_fill, FillOptions, FillResult};
pub use layer::{blend_rgba, BlendMode, LayerId, LayerKind, LayerNode, LayerStack};
pub use panel::{PanelFrame, PanelId, PanelLayout, PanelPolygon};
pub use preset::{CanvasPreset, CanvasSpec, MangaPageGuides, ProductionTrack, WebtoonSliceSpec};
pub use ruler::RulerKind;
pub use screentone::{ScreentoneSpec, TonePattern};
pub use stroke::{RopeStabilizer, StrokePoint};
pub use tile::{TileCoord, TileData, TileLayer, TILE_SIZE};
pub use undo::{TileDiff, TileUndoStack};
pub use vector::{Aabb, VectorLayer, VectorNode, VectorStroke, VectorStrokeId};
pub use webtoon::{compute_webtoon_slices, render_webtoon_slice_rgba, WebtoonSlice};
