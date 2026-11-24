//! `manga-core`: MIT-licensed cross-platform engine core for About-Paint-Tools.
//!
//! Designed to power hardware-native UI shells (iPadOS UIKit/SwiftUI first,
//! with future macOS, Android, and Windows shells) while sharing deterministic
//! dual-track presets, sparse tile storage, stroke stabilization, CoW undo,
//! and a zero-dependency C-ABI bridge.

pub mod canvas;
pub mod ffi;
pub mod preset;
pub mod stroke;
pub mod tile;
pub mod undo;

pub use canvas::{CanvasSession, ViewportTransform};
pub use preset::{CanvasPreset, CanvasSpec, MangaPageGuides, ProductionTrack, WebtoonSliceSpec};
pub use stroke::{RopeStabilizer, StrokePoint};
pub use tile::{TileCoord, TileData, TileLayer, TILE_SIZE};
pub use undo::{TileDiff, TileUndoStack};
