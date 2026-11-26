//! `manga-core`: MIT-licensed cross-platform engine core for About-Paint-Tools.
//!
//! Designed to power hardware-native UI shells (iPadOS UIKit/SwiftUI first,
//! with future macOS, Android, and Windows shells) while sharing deterministic
//! dual-track presets, sparse tile storage, cel-shading blend layers, anti-halo
//! close-gap fill, vector lineart with intersection erasing, manga rulers,
//! panel slicing, procedural screentones, Webtoon slicing, continuity logs,
//! and a transactional `ActionBus` for local Gemma 4 Function Calling.

pub mod action_bus;
pub mod bible;
pub mod brush;
pub mod bubble;
pub mod canvas;
pub mod continuity;
pub mod ffi;
pub mod fill;
pub mod glossary;
pub mod ingest;
pub mod layer;
pub mod novel;
pub mod panel;
pub mod platform;
pub mod preset;
pub mod project;
pub mod project_init;
pub mod ruler;
pub mod screentone;
pub mod selection;
pub mod stroke;
pub mod suite;
pub mod tile;
pub mod undo;
pub mod vector;
pub mod webtoon;

pub use action_bus::{ActionBus, ActionCommand, ActionPlan, ActionPreview, ProjectDocument};
pub use bible::{
    story_bible_revision_hash, BibleCharacter, ProjectToc, StoryBible, TocChapterEntry,
    PROJECT_TOC_REL_PATH, STORY_BIBLE_REL_PATH,
};
pub use brush::{
    sample_effective_radius, starter_brush_presets, zoom_adaptive_rope_radius, BrushPresetId,
    BrushStamp, BrushStampingEngine, BrushTipPreset, ResponseCurve,
};
pub use bubble::{
    render_novel_chapter_epub_xhtml, write_publish_manifest_atomic, SpeechBubble, TextFlowDirection,
};
pub use canvas::{CanvasSession, ViewportTransform};
pub use continuity::{
    CharacterSheet, ContinuityEntry, ContinuityLog, ContinuityReviewPin, NoteSource,
    CONTINUITY_SQLITE_DDL,
};
pub use fill::{close_gap_expand_fill, FillOptions, FillResult};
pub use glossary::{
    GlossaryAuditReport, GlossaryTerm, ProjectGlossary, PROJECT_GLOSSARY_REL_PATH,
};
pub use ingest::{ingest_bytes_atomic, sanitize_ingest_filename, IngestAssetKind, IngestResult};
pub use layer::{blend_rgba, BlendMode, LayerId, LayerKind, LayerNode, LayerStack};
pub use novel::{
    count_novel_words, write_novel_prose_atomic, DivergenceNote, NovelChapterMeta, NovelWordStats,
};
pub use panel::{PanelFrame, PanelId, PanelLayout, PanelPolygon};
pub use platform::{
    recommend_workspace_layout, FoldPosture, HingeBounds, InputCapabilities, TargetPlatform,
    WorkspaceLayoutHint,
};
pub use preset::{CanvasPreset, CanvasSpec, MangaPageGuides, ProductionTrack, WebtoonSliceSpec};
pub use project::{
    resolve_prj_file, AiBridgeArtifact, ChapterRef, CreativeEngineMode, CreativeProjectManifest,
    EditionRef, NovelIllustrationMode, PrjResolution, ReadingDirection, WorkType,
    CPFF_SCHEMA_VERSION, CPFF_XML_NAMESPACE,
};
pub use project_init::{init_cpff_project, ProjectInitOptions};
pub use ruler::RulerKind;
pub use screentone::{ScreentoneSpec, TonePattern};
pub use selection::SelectionMask;
pub use stroke::{RopeStabilizer, StrokePoint};
pub use suite::{
    can_write_relative_path, run_t02_s4_concurrency_soak, run_t03_s4_bible_layers_gate,
    run_t04_s4_ingest_fill_divergence_gate, run_t05_s4_vector_ruler_glossary_gate,
    run_t06_s4_panels_tones_webtoon_epub_gate, run_tri_app_compatibility_check, DeepLinkAction,
    SuiteApp, SuiteAppMetadata, T02S4ConcurrencyReport, T03S4GateReport, T04S4GateReport,
    T05S4GateReport, T06S4GateReport, TriAppIntegrationReport,
};
pub use tile::{TileCoord, TileData, TileLayer, TILE_SIZE};
pub use undo::{TileDiff, TileUndoStack};
pub use vector::{Aabb, VectorLayer, VectorNode, VectorStroke, VectorStrokeId};
pub use webtoon::{compute_webtoon_slices, render_webtoon_slice_rgba, WebtoonSlice};
