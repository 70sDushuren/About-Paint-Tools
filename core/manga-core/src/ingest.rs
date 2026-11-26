//! `S1 v0.4` — Asset & Prose Ingest Normalizer (`创想空间 / NoemaDock`):
//! Safely imports external reference images, storyboard drafts, or prose staging files
//! into canonical CPFF v1.0 locations without violating `S2`/`S3` write-ownership or
//! overwriting human-authoritative finals.

use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum IngestAssetKind {
    /// Reference art / sheet routed to `assets/refs/<sanitized_name>`.
    ReferenceArt = 0,
    /// External prose draft staged safely into `chapters/<ch>/ai_assist/ingest_staging/<sanitized_name>`
    /// (never directly overwrites human `novel/prose/*.md` finals!).
    ProseStagingDraft = 1,
    /// Storyboard / page scan staged into `assets/ingest/<ch>/<sanitized_name>`.
    StoryboardScan = 2,
}

impl IngestAssetKind {
    pub fn from_u32(v: u32) -> Option<Self> {
        match v {
            0 => Some(Self::ReferenceArt),
            1 => Some(Self::ProseStagingDraft),
            2 => Some(Self::StoryboardScan),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IngestResult {
    pub destination_rel_path: String,
    pub destination_abs_path: PathBuf,
    pub bytes_written: usize,
    pub conflict_renamed: bool,
}

/// Sanitizes an arbitrary filename into safe CPFF v1.0 ASCII/UTF-8 lowercase-safe form (zero traversal).
pub fn sanitize_ingest_filename(raw: &str) -> String {
    let base = Path::new(raw)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("asset.dat");
    let cleaned: String = base
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || matches!(c, '.' | '-' | '_') {
                c
            } else {
                '_'
            }
        })
        .collect();
    let trimmed = cleaned.trim_matches('.');
    if trimmed.is_empty() {
        "asset.dat".into()
    } else {
        trimmed.to_string()
    }
}

/// Atomically ingests raw bytes into a normalized CPFF v1.0 folder under `project_dir`.
/// Automatically resolves filename collisions with `-v2`, `-v3`, ... so existing files are never clobbered.
pub fn ingest_bytes_atomic(
    project_dir: &Path,
    chapter_id: &str,
    kind: IngestAssetKind,
    raw_filename: &str,
    payload: &[u8],
) -> Result<IngestResult, String> {
    if chapter_id.contains("..") || chapter_id.contains('/') || chapter_id.contains('\\') {
        return Err(format!("Unsafe chapter_id '{chapter_id}' rejected by ingest normalizer"));
    }
    let clean_name = sanitize_ingest_filename(raw_filename);
    let sub_dir = match kind {
        IngestAssetKind::ReferenceArt => "assets/refs".to_string(),
        IngestAssetKind::ProseStagingDraft => format!("chapters/{chapter_id}/ai_assist/ingest_staging"),
        IngestAssetKind::StoryboardScan => format!("assets/ingest/{chapter_id}"),
    };

    let target_dir = project_dir.join(&sub_dir);
    fs::create_dir_all(&target_dir)
        .map_err(|e| format!("Failed creating ingest dir '{}': {e}", target_dir.display()))?;

    let mut final_name = clean_name.clone();
    let mut conflict_renamed = false;
    if target_dir.join(&final_name).exists() {
        conflict_renamed = true;
        let (stem, ext) = match clean_name.rsplit_once('.') {
            Some((s, e)) => (s.to_string(), format!(".{e}")),
            None => (clean_name.clone(), String::new()),
        };
        let mut idx = 2usize;
        loop {
            let candidate = format!("{stem}-v{idx}{ext}");
            if !target_dir.join(&candidate).exists() {
                final_name = candidate;
                break;
            }
            idx += 1;
        }
    }

    let dest_abs = target_dir.join(&final_name);
    let tmp_abs = target_dir.join(format!(".{final_name}.tmp.{}", std::process::id()));
    fs::write(&tmp_abs, payload)
        .map_err(|e| format!("Failed writing ingest temp '{}': {e}", tmp_abs.display()))?;
    fs::rename(&tmp_abs, &dest_abs)
        .map_err(|e| format!("Failed atomic rename into '{}': {e}", dest_abs.display()))?;

    Ok(IngestResult {
        destination_rel_path: format!("{sub_dir}/{final_name}"),
        destination_abs_path: dest_abs,
        bytes_written: payload.len(),
        conflict_renamed,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ingest_normalizes_paths_preserves_collisions_and_isolates_prose() {
        let root = std::env::temp_dir().join(format!("manga_ingest_test_{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();

        let r1 = ingest_bytes_atomic(
            &root,
            "ch001",
            IngestAssetKind::ReferenceArt,
            "../../Hero Sheet (Final).png",
            b"PNGDATA",
        )
        .unwrap();
        assert_eq!(r1.destination_rel_path, "assets/refs/Hero_Sheet__Final_.png");
        assert!(!r1.conflict_renamed);

        // Second ingest with same filename auto-versions instead of clobbering
        let r2 = ingest_bytes_atomic(
            &root,
            "ch001",
            IngestAssetKind::ReferenceArt,
            "Hero Sheet (Final).png",
            b"PNGDATA_V2",
        )
        .unwrap();
        assert_eq!(r2.destination_rel_path, "assets/refs/Hero_Sheet__Final_-v2.png");
        assert!(r2.conflict_renamed);

        // Prose ingest stages strictly inside ai_assist/ingest_staging/, never overwriting novel/prose/
        let r3 = ingest_bytes_atomic(
            &root,
            "ch001",
            IngestAssetKind::ProseStagingDraft,
            "draft_notes.md",
            b"# External Draft",
        )
        .unwrap();
        assert!(r3.destination_rel_path.starts_with("chapters/ch001/ai_assist/ingest_staging/"));

        // Reject path traversal in chapter_id
        assert!(ingest_bytes_atomic(&root, "../evil", IngestAssetKind::ReferenceArt, "a.png", b"x").is_err());

        let _ = fs::remove_dir_all(&root);
    }
}
