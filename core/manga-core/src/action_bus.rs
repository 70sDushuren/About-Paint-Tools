//! Deterministic `ActionBus` command engine (v0.7 foundation for v1.2 Gemma 4 Function Calling).
//!
//! All batch workflows (manual macros or local Gemma 4 function-calling plans)
//! must be expressed as whitelisted `ActionCommand`s, previewed non-destructively,
//! and executed inside an atomic single-step `UndoGroup`.

use crate::continuity::{ContinuityLog, NoteSource};
use crate::fill::{close_gap_expand_fill, FillOptions};
use crate::layer::{BlendMode, LayerStack};
use crate::preset::{CanvasPreset, CanvasSpec};
use crate::vector::VectorLayer;

/// Unified document container operated on by `ActionBus`.
#[derive(Debug, Clone)]
pub struct ProjectDocument {
    pub spec: CanvasSpec,
    pub layers: LayerStack,
    pub vectors: VectorLayer,
    pub continuity: ContinuityLog,
}

impl ProjectDocument {
    pub fn from_preset(preset: CanvasPreset) -> Self {
        let spec = preset.spec();
        Self {
            spec,
            layers: LayerStack::new(spec.width, spec.height),
            vectors: VectorLayer::new(),
            continuity: ContinuityLog::new(),
        }
    }
}

/// Whitelisted deterministic commands callable by UI macros or local Gemma 4 Function Calling.
#[derive(Debug, Clone, PartialEq)]
pub enum ActionCommand {
    CreateRasterLayer {
        name: String,
        blend_mode: BlendMode,
        clipping_mask: bool,
        is_reference: bool,
    },
    /// Batch-tints, adjusts opacity, and locks all layers whose name starts with `name_prefix`.
    BatchTintLayers {
        name_prefix: String,
        tint_rgba: [u8; 4],
        opacity: f32,
        lock: bool,
    },
    /// Runs Close-Gap + Edge-Expand anti-halo fill onto a named layer.
    RunCloseGapFill {
        target_layer_name: String,
        seed_x: u32,
        seed_y: u32,
        color_rgba: [u8; 4],
        options: FillOptions,
    },
    /// Appends a structured Script Supervisor continuity record (e.g., from Gemma 4 voice dictation).
    AddContinuityNote {
        chapter: u32,
        page: u32,
        panel: u32,
        characters: Vec<String>,
        outfit_state: String,
        lighting_dir: String,
        props_note: String,
        source: NoteSource,
    },
    /// Drops a non-destructive editorial review pin without touching canvas pixels.
    AddReviewPin {
        page: u32,
        panel: u32,
        x: f32,
        y: f32,
        message: String,
    },
}

/// Reviewable multi-step plan emitted by UI macros or Gemma 4 before execution.
#[derive(Debug, Clone, PartialEq)]
pub struct ActionPlan {
    pub title: String,
    pub commands: Vec<ActionCommand>,
}

/// Human-readable dry-run preview shown to the artist before tapping "Execute".
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ActionPreview {
    pub title: String,
    pub step_summaries: Vec<String>,
    pub matched_layers: usize,
}

#[derive(Debug, Clone)]
struct ActionUndoGroup {
    #[allow(dead_code)]
    title: String,
    prev_layers: LayerStack,
    prev_continuity: ContinuityLog,
}

/// Deterministic command bus with non-destructive preview and atomic batch rollback.
#[derive(Debug, Default)]
pub struct ActionBus {
    undo_groups: Vec<ActionUndoGroup>,
    redo_groups: Vec<ActionUndoGroup>,
}

impl ActionBus {
    pub fn new() -> Self {
        Self::default()
    }

    /// Dry-runs `plan` against `doc` without mutating any state.
    pub fn preview(&self, doc: &ProjectDocument, plan: &ActionPlan) -> ActionPreview {
        let mut summaries = Vec::with_capacity(plan.commands.len());
        let mut matched_layers = 0usize;

        for cmd in &plan.commands {
            match cmd {
                ActionCommand::CreateRasterLayer { name, .. } => {
                    summaries.push(format!("Create raster layer '{name}'"));
                }
                ActionCommand::BatchTintLayers {
                    name_prefix,
                    opacity,
                    lock,
                    ..
                } => {
                    let hits = doc
                        .layers
                        .layers()
                        .iter()
                        .filter(|l| l.name.starts_with(name_prefix))
                        .count();
                    matched_layers += hits;
                    summaries.push(format!(
                        "Tint {hits} layer(s) matching '{name_prefix}*' (opacity={:.0}%, lock={lock})",
                        opacity * 100.0
                    ));
                }
                ActionCommand::RunCloseGapFill {
                    target_layer_name,
                    options,
                    ..
                } => {
                    summaries.push(format!(
                        "Close-gap fill on '{target_layer_name}' (gap={}px, expand={}px)",
                        options.close_gap_px, options.expand_px
                    ));
                }
                ActionCommand::AddContinuityNote {
                    chapter,
                    page,
                    panel,
                    ..
                } => {
                    summaries.push(format!("Log continuity note Ch.{chapter} P.{page} Panel {panel}"));
                }
                ActionCommand::AddReviewPin {
                    page,
                    panel,
                    message,
                    ..
                } => {
                    summaries.push(format!("Drop review pin P.{page} Panel {panel}: {message}"));
                }
            }
        }

        ActionPreview {
            title: plan.title.clone(),
            step_summaries: summaries,
            matched_layers,
        }
    }

    /// Executes `plan` atomically and records a single `UndoGroup` snapshot.
    pub fn execute(&mut self, doc: &mut ProjectDocument, plan: &ActionPlan) -> usize {
        if plan.commands.is_empty() {
            return 0;
        }

        let snapshot = ActionUndoGroup {
            title: plan.title.clone(),
            prev_layers: doc.layers.clone(),
            prev_continuity: doc.continuity.clone(),
        };

        let mut executed = 0usize;
        for cmd in &plan.commands {
            match cmd {
                ActionCommand::CreateRasterLayer {
                    name,
                    blend_mode,
                    clipping_mask,
                    is_reference,
                } => {
                    let id = doc.layers.add_raster_layer(name.clone());
                    if let Some(layer) = doc.layers.get_mut(id) {
                        layer.blend_mode = *blend_mode;
                        layer.clipping_mask = *clipping_mask;
                        layer.is_reference = *is_reference;
                    }
                    executed += 1;
                }
                ActionCommand::BatchTintLayers {
                    name_prefix,
                    tint_rgba,
                    opacity,
                    lock,
                } => {
                    for layer in doc.layers.layers_mut() {
                        if layer.name.starts_with(name_prefix) {
                            layer.tint_rgba = Some(*tint_rgba);
                            layer.opacity = opacity.clamp(0.0, 1.0);
                            layer.locked = *lock;
                        }
                    }
                    executed += 1;
                }
                ActionCommand::RunCloseGapFill {
                    target_layer_name,
                    seed_x,
                    seed_y,
                    color_rgba,
                    options,
                } => {
                    if let Some(id) = doc.layers.find_by_name(target_layer_name) {
                        close_gap_expand_fill(
                            &mut doc.layers,
                            id,
                            *seed_x,
                            *seed_y,
                            *color_rgba,
                            *options,
                        );
                        executed += 1;
                    }
                }
                ActionCommand::AddContinuityNote {
                    chapter,
                    page,
                    panel,
                    characters,
                    outfit_state,
                    lighting_dir,
                    props_note,
                    source,
                } => {
                    doc.continuity.add_entry(
                        *chapter,
                        *page,
                        *panel,
                        characters.clone(),
                        outfit_state.clone(),
                        lighting_dir.clone(),
                        props_note.clone(),
                        *source,
                    );
                    executed += 1;
                }
                ActionCommand::AddReviewPin {
                    page,
                    panel,
                    x,
                    y,
                    message,
                } => {
                    doc.continuity
                        .add_review_pin(*page, *panel, *x, *y, message.clone());
                    executed += 1;
                }
            }
        }

        self.undo_groups.push(snapshot);
        self.redo_groups.clear();
        executed
    }

    /// Reverts the entire most recent batch plan in one atomic step.
    pub fn undo_last(&mut self, doc: &mut ProjectDocument) -> bool {
        let Some(prev) = self.undo_groups.pop() else {
            return false;
        };
        let redo_snapshot = ActionUndoGroup {
            title: prev.title.clone(),
            prev_layers: doc.layers.clone(),
            prev_continuity: doc.continuity.clone(),
        };
        doc.layers = prev.prev_layers;
        doc.continuity = prev.prev_continuity;
        self.redo_groups.push(redo_snapshot);
        true
    }

    pub fn redo_last(&mut self, doc: &mut ProjectDocument) -> bool {
        let Some(next) = self.redo_groups.pop() else {
            return false;
        };
        let undo_snapshot = ActionUndoGroup {
            title: next.title.clone(),
            prev_layers: doc.layers.clone(),
            prev_continuity: doc.continuity.clone(),
        };
        doc.layers = next.prev_layers;
        doc.continuity = next.prev_continuity;
        self.undo_groups.push(undo_snapshot);
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::continuity::CONTINUITY_SQLITE_DDL;

    #[test]
    fn gemma4_batch_plan_previews_executes_and_reverts_atomically() {
        assert!(CONTINUITY_SQLITE_DDL.contains("CREATE TABLE IF NOT EXISTS continuity_entries"));

        let mut doc = ProjectDocument::from_preset(CanvasPreset::B4PrintManga600Dpi);
        let s1 = doc.layers.add_raster_layer("Sketch_01");
        let s2 = doc.layers.add_raster_layer("Sketch_02");
        let ink = doc.layers.add_raster_layer("VectorInk");

        let plan = ActionPlan {
            title: "Prepare sketches for inking & log voice continuity note".into(),
            commands: vec![
                ActionCommand::BatchTintLayers {
                    name_prefix: "Sketch_".into(),
                    tint_rgba: [77, 166, 255, 255],
                    opacity: 0.30,
                    lock: true,
                },
                ActionCommand::CreateRasterLayer {
                    name: "CelShadow".into(),
                    blend_mode: BlendMode::Multiply,
                    clipping_mask: true,
                    is_reference: false,
                },
                ActionCommand::AddContinuityNote {
                    chapter: 1,
                    page: 3,
                    panel: 5,
                    characters: vec!["Hero".into()],
                    outfit_state: "Right sleeve torn".into(),
                    lighting_dir: "Top-left sunset".into(),
                    props_note: "Glasses cracked".into(),
                    source: NoteSource::VoiceGemma4,
                },
            ],
        };

        let mut bus = ActionBus::new();
        let preview = bus.preview(&doc, &plan);
        assert_eq!(preview.matched_layers, 2);
        assert_eq!(preview.step_summaries.len(), 3);
        // Dry-run preview must not mutate document state.
        assert!(!doc.layers.get(s1).unwrap().locked);
        assert_eq!(doc.continuity.entries.len(), 0);

        // Execute full plan atomically.
        assert_eq!(bus.execute(&mut doc, &plan), 3);
        assert!(doc.layers.get(s1).unwrap().locked);
        assert!(doc.layers.get(s2).unwrap().locked);
        assert!((doc.layers.get(s1).unwrap().opacity - 0.30).abs() < 1e-6);
        assert!(!doc.layers.get(ink).unwrap().locked);
        assert!(doc.layers.find_by_name("CelShadow").is_some());
        assert_eq!(doc.continuity.entries_for_page(1, 3).len(), 1);

        // Single undo reverts all 3 steps together!
        assert!(bus.undo_last(&mut doc));
        assert!(!doc.layers.get(s1).unwrap().locked);
        assert_eq!(doc.layers.get(s1).unwrap().tint_rgba, None);
        assert!(doc.layers.find_by_name("CelShadow").is_none());
        assert_eq!(doc.continuity.entries.len(), 0);

        // Redo restores all 3 steps together!
        assert!(bus.redo_last(&mut doc));
        assert!(doc.layers.get(s2).unwrap().locked);
        assert_eq!(doc.continuity.entries.len(), 1);
    }
}
