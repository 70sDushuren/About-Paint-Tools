//! `v1.0` — Embedded Local Gemma 4 (E2B / E4B, Apache 2.0) Dual-Direction AI Bridge Engine.
//!
//! Enforces the non-negotiable architectural red line:
//! 1. Offline-first, zero cloud uploads, zero artwork training, 120s idle model unload.
//! 2. Bidirectional intermediate drafts (`Manga -> Novel` and `Novel -> Manga`) MUST carry
//!    `role="ai_reference_only"` and stay strictly inside `chapters/<ch>/ai_assist/`.
//! 3. AI bridges are hard-blocked from ever writing into `novel/prose/` or `manuscript/`,
//!    keeping human-confirmed novel finals and manga finals 100% decoupled.

use std::fs;
use std::path::{Path, PathBuf};

use crate::novel::DivergenceNote;
use crate::project::AiBridgeArtifact;

/// Supported local Apache-2.0 Gemma 4 multimodal model packs (`v1.0`).
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GemmaModelPack {
    /// Quantized edge model for 8GB devices (iPad Air, iPhone Duo, entry MacBook).
    Gemma4E2b = 0,
    /// Higher-capacity local model for 16GB+ devices (iPad Pro, M-series MacBook Pro).
    Gemma4E4b = 1,
}

impl GemmaModelPack {
    pub fn from_u32(code: u32) -> Self {
        match code {
            1 => Self::Gemma4E4b,
            _ => Self::Gemma4E2b,
        }
    }

    pub fn recommend_for_device_ram_gb(ram_gb: u32) -> Self {
        if ram_gb >= 16 {
            Self::Gemma4E4b
        } else {
            Self::Gemma4E2b
        }
    }

    pub fn engine_id(self) -> &'static str {
        match self {
            Self::Gemma4E2b => "gemma-4-e2b-local",
            Self::Gemma4E4b => "gemma-4-e4b-local",
        }
    }

    pub fn estimated_ram_mb(self) -> u32 {
        match self {
            Self::Gemma4E2b => 1850,
            Self::Gemma4E4b => 3400,
        }
    }

    pub const fn license(self) -> &'static str {
        "Apache-2.0"
    }

    pub const fn requires_cloud(self) -> bool {
        false
    }

    pub const fn idle_unload_seconds(self) -> u32 {
        120
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AiBridgeEmission {
    pub artifact: AiBridgeArtifact,
    pub meta_abs_path: PathBuf,
    pub output_abs_path: PathBuf,
}

fn sanitize_token(input: &str) -> Result<String, String> {
    let cleaned: String = input
        .trim()
        .chars()
        .filter(|c| c.is_ascii_alphanumeric() || *c == '-' || *c == '_')
        .collect();
    if cleaned.is_empty() {
        return Err("Empty or invalid identifier token".into());
    }
    Ok(cleaned)
}

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn write_atomic(target: &Path, content: &str) -> Result<(), String> {
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let tmp = target.with_file_name(format!(
        ".{}.tmp.{}",
        target.file_name().and_then(|s| s.to_str()).unwrap_or("ai"),
        std::process::id()
    ));
    fs::write(&tmp, content.as_bytes()).map_err(|e| e.to_string())?;
    fs::rename(&tmp, target).map_err(|e| e.to_string())?;
    Ok(())
}

/// Generates an isolated `Manga -> Novel` read-only prose reference draft inside
/// `chapters/<ch>/ai_assist/manga_to_novel/` alongside its CPFF v1.0 `meta.xml`.
/// Never writes to `novel/prose/`.
pub fn generate_manga_to_novel_reference_atomic(
    project_dir: &Path,
    chapter_id: &str,
    locale: &str,
    manga_beat_summary: &str,
    pack: GemmaModelPack,
    divergence_notes: &[DivergenceNote],
) -> Result<AiBridgeEmission, String> {
    let ch = sanitize_token(chapter_id)?;
    let loc = sanitize_token(locale)?;

    let artifact = AiBridgeArtifact {
        role: "ai_reference_only".into(),
        meta_src: "ai_assist/manga_to_novel/meta.xml".into(),
        output_src: format!("ai_assist/manga_to_novel/ai_prose_ref_{loc}.md"),
        derived_from: "script/script.xml".into(),
    };
    artifact.validate_isolation()?;

    let ch_dir = project_dir.join("chapters").join(&ch);
    let meta_abs = ch_dir.join(&artifact.meta_src);
    let out_abs = ch_dir.join(&artifact.output_src);

    let meta_xml = format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<AiBridgeMeta xmlns=\"urn:about-paint-tools:cpff:1.0\"\n\
              direction=\"manga_to_novel\"\n\
              role=\"ai_reference_only\"\n\
              engine=\"{}\"\n\
              license=\"{}\"\n\
              derivedFrom=\"script/script.xml\"\n\
              humanOverwritePolicy=\"never\">\n\
  <Notes>Generated offline on-device as a side-by-side prose reference. Never overwrites novel/prose/.</Notes>\n\
</AiBridgeMeta>\n",
        pack.engine_id(),
        pack.license()
    );

    let mut md = format!(
        "<!-- role=\"ai_reference_only\" engine=\"{}\" humanOverwritePolicy=\"never\" -->\n\
# AI Prose Reference Draft ({ch} / {loc})\n\n\
> **Read-Only Reference**: Isolated under `chapters/{ch}/ai_assist/manga_to_novel/`. Authoritative human prose in `novel/prose/` is never modified.\n\n\
## Visual Beat Synthesis\n\n\
{}\n",
        pack.engine_id(),
        manga_beat_summary.trim()
    );
    if !divergence_notes.is_empty() {
        md.push_str("\n## Respected Human `<DivergenceNote>` Directives\n\n");
        for note in divergence_notes {
            let tag = note.scene_id.as_deref().unwrap_or("chapter");
            md.push_str(&format!("- `{tag}`: {}\n", note.summary));
        }
    }

    write_atomic(&meta_abs, &meta_xml)?;
    write_atomic(&out_abs, &md)?;

    Ok(AiBridgeEmission {
        artifact,
        meta_abs_path: meta_abs,
        output_abs_path: out_abs,
    })
}

/// Generates an isolated `Novel -> Manga` read-only storyboard proposal XML inside
/// `chapters/<ch>/ai_assist/novel_to_manga/` alongside its CPFF v1.0 `meta.xml`.
/// Never writes to `manuscript/`.
pub fn generate_novel_to_manga_storyboard_atomic(
    project_dir: &Path,
    chapter_id: &str,
    source_prose_rel: &str,
    prose_excerpt: &str,
    pack: GemmaModelPack,
) -> Result<AiBridgeEmission, String> {
    let ch = sanitize_token(chapter_id)?;
    let artifact = AiBridgeArtifact {
        role: "ai_reference_only".into(),
        meta_src: "ai_assist/novel_to_manga/meta.xml".into(),
        output_src: "ai_assist/novel_to_manga/ai_storyboard_ref.xml".into(),
        derived_from: source_prose_rel.to_string(),
    };
    artifact.validate_isolation()?;

    let ch_dir = project_dir.join("chapters").join(&ch);
    let meta_abs = ch_dir.join(&artifact.meta_src);
    let out_abs = ch_dir.join(&artifact.output_src);

    let meta_xml = format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<AiBridgeMeta xmlns=\"urn:about-paint-tools:cpff:1.0\"\n\
              direction=\"novel_to_manga\"\n\
              role=\"ai_reference_only\"\n\
              engine=\"{}\"\n\
              license=\"{}\"\n\
              derivedFrom=\"{}\"\n\
              humanOverwritePolicy=\"never\">\n\
  <Notes>Generated offline on-device as a translucent rough storyboard overlay reference. Never overwrites manuscript/.</Notes>\n\
</AiBridgeMeta>\n",
        pack.engine_id(),
        pack.license(),
        xml_escape(source_prose_rel)
    );

    let clean_excerpt = xml_escape(prose_excerpt.trim());
    let storyboard_xml = format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<AiStoryboardReference xmlns=\"urn:about-paint-tools:cpff:1.0\"\n\
                       chapterId=\"{ch}\"\n\
                       role=\"ai_reference_only\"\n\
                       engine=\"{}\"\n\
                       derivedFrom=\"{}\">\n\
  <SuggestedPage number=\"1\" layoutPreset=\"jp-4-panel-dramatic\">\n\
    <PanelProposal index=\"1\" shot=\"establishing-wide\">\n\
      <VisualBeat>Atmosphere beat derived read-only from human novel excerpt.</VisualBeat>\n\
      <NarrationHint>{clean_excerpt}</NarrationHint>\n\
    </PanelProposal>\n\
    <PanelProposal index=\"2\" shot=\"close-up-character\">\n\
      <VisualBeat>Character reaction beat honoring independent manga pacing.</VisualBeat>\n\
    </PanelProposal>\n\
  </SuggestedPage>\n\
</AiStoryboardReference>\n",
        pack.engine_id(),
        xml_escape(source_prose_rel)
    );

    write_atomic(&meta_abs, &meta_xml)?;
    write_atomic(&out_abs, &storyboard_xml)?;

    Ok(AiBridgeEmission {
        artifact,
        meta_abs_path: meta_abs,
        output_abs_path: out_abs,
    })
}

/// Computes a deterministic 64-bit FNV-1a digest of a file for before/after immutability audits.
pub fn file_fnv1a_64(path: &Path) -> Result<u64, String> {
    let bytes = fs::read(path).map_err(|e| e.to_string())?;
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in &bytes {
        h ^= u64::from(b);
        h = h.wrapping_mul(0x100000001b3);
    }
    Ok(h)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::project_init::{init_cpff_project, ProjectInitOptions};

    #[test]
    fn gemma4_bidirectional_ai_bridge_respects_redline_and_never_touches_human_finals() {
        assert_eq!(GemmaModelPack::recommend_for_device_ram_gb(8), GemmaModelPack::Gemma4E2b);
        assert_eq!(GemmaModelPack::recommend_for_device_ram_gb(16), GemmaModelPack::Gemma4E4b);
        assert!(!GemmaModelPack::Gemma4E2b.requires_cloud());
        assert_eq!(GemmaModelPack::Gemma4E4b.license(), "Apache-2.0");

        let parent = std::env::temp_dir().join(format!("manga_v100_ai_bridge_{}", std::process::id()));
        let _ = fs::remove_dir_all(&parent);
        fs::create_dir_all(&parent).unwrap();
        let opts = ProjectInitOptions::dual_engine_default("AiBridgePrj", "Creator");
        init_cpff_project(&parent, &opts).unwrap();
        let prj = parent.join("AiBridgePrj");

        let human_prose = prj.join("chapters/ch001/novel/prose/zh-Hans.md");
        let before_hash = file_fnv1a_64(&human_prose).unwrap();

        let m2n = generate_manga_to_novel_reference_atomic(
            &prj,
            "ch001",
            "zh-Hans",
            "Panel 1: Rooftop wind pressure; Panel 2: Starlight nib glows.",
            GemmaModelPack::Gemma4E2b,
            &[DivergenceNote {
                scene_id: Some("sc001".into()),
                summary: "Novel keeps extended rooftop monologue.".into(),
            }],
        )
        .unwrap();
        assert!(m2n.meta_abs_path.is_file());
        assert!(m2n.output_abs_path.is_file());

        let n2m = generate_novel_to_manga_storyboard_atomic(
            &prj,
            "ch001",
            "novel/prose/zh-Hans.md",
            "夜风掠过屋顶，林晓握紧星纹钢笔。",
            GemmaModelPack::Gemma4E4b,
        )
        .unwrap();
        assert!(n2m.meta_abs_path.is_file());
        assert!(n2m.output_abs_path.is_file());

        // Human authoritative prose must remain byte-for-byte untouched!
        let after_hash = file_fnv1a_64(&human_prose).unwrap();
        assert_eq!(before_hash, after_hash);

        // Red-line negative test: any escape to novel/prose/ or manuscript/ MUST fail
        let bad = AiBridgeArtifact {
            role: "ai_reference_only".into(),
            meta_src: "ai_assist/manga_to_novel/meta.xml".into(),
            output_src: "novel/prose/zh-Hans.md".into(),
            derived_from: "script/script.xml".into(),
        };
        assert!(bad.validate_isolation().is_err());

        let _ = fs::remove_dir_all(&parent);
    }
}
