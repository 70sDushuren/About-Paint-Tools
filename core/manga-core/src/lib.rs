//! `manga-core`: MIT-licensed cross-platform engine core for About-Paint-Tools.
//!
//! Designed to power hardware-native UI shells (iPadOS UIKit/SwiftUI first,
//! with future macOS, Android, and Windows shells) while sharing deterministic
//! sparse tile storage, stroke stabilization, and Copy-on-Write undo history.

pub mod stroke;
pub mod tile;
pub mod undo;

pub use stroke::{RopeStabilizer, StrokePoint};
pub use tile::{TileCoord, TileData, TileLayer, TILE_SIZE};
pub use undo::{TileDiff, TileUndoStack};
