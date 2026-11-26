//! `S3 v0.2.1` — Light Novel Markdown Core, CJK+Latin Word Counter, Atomic Save,
//! and `<DivergenceNote>` Metadata Codec (`文心 / LitteraCore`, working codename).
//!
//! Strictly enforces `SuiteApp::Novel` CPFF v1.0 write-ownership isolation and
//! `locked="true"` human-authoritative prose protection.

use crate::project::{CPFF_SCHEMA_VERSION, CPFF_XML_NAMESPACE};
use crate::suite::{can_write_relative_path, SuiteApp};
use std::fs;
use std::path::{Path, PathBuf};

/// Accurate mixed CJK + Latin word/character statistics for light novel chapters.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NovelWordStats {
    /// CJK ideographs & kana/hangul characters (each counts as 1 publishing unit).
    pub cjk_chars: usize,
    /// Whitespace/punctuation-delimited Latin/numeric words.
    pub latin_words: usize,
    /// Combined light-novel publishing units (`cjk_chars + latin_words`).
    pub total_units: usize,
    /// Non-empty paragraph count.
    pub paragraphs: usize,
    /// Estimated reading time in minutes (rounded up, ~450 units/min).
    pub estimated_read_minutes: usize,
}

fn is_cjk_char(ch: char) -> bool {
    matches!(
        ch as u32,
        0x3040..=0x309F // Hiragana
        | 0x30A0..=0x30FF // Katakana
        | 0x3400..=0x4DBF // CJK Extension A
        | 0x4E00..=0x9FFF // CJK Unified Ideographs
        | 0xAC00..=0xD7AF // Hangul Syllables
        | 0xF900..=0xFAFF // CJK Compatibility Ideographs
    )
}

/// Counts mixed CJK characters and Latin words in a single linear pass (`< 10ms` for 100k chars).
pub fn count_novel_words(text: &str) -> NovelWordStats {
    let mut cjk_chars = 0usize;
    let mut latin_words = 0usize;
    let mut in_latin_word = false;

    for ch in text.chars() {
        if is_cjk_char(ch) {
            if in_latin_word {
                latin_words += 1;
                in_latin_word = false;
            }
            cjk_chars += 1;
        } else if ch.is_ascii_alphanumeric() || (ch.is_alphabetic() && !is_cjk_char(ch)) {
            in_latin_word = true;
        } else if in_latin_word {
            latin_words += 1;
            in_latin_word = false;
        }
    }
    if in_latin_word {
        latin_words += 1;
    }

    let paragraphs = text
        .split("\n\n")
        .filter(|block| !block.trim().is_empty())
        .count();
    let total_units = cjk_chars + latin_words;
    let estimated_read_minutes = if total_units == 0 {
        0
    } else {
        total_units.div_ceil(450)
    };

    NovelWordStats {
        cjk_chars,
        latin_words,
        total_units,
        paragraphs,
        estimated_read_minutes,
    }
}

/// Atomically writes a light novel prose file under `chapters/<chapter_id>/novel/prose/<locale>.md`
/// using temp-file + `fs::rename`, enforcing `SuiteApp::Novel` write ownership and `locked` guard.
pub fn write_novel_prose_atomic(
    project_dir: &Path,
    rel_path: &str,
    markdown_utf8: &str,
    is_locked: bool,
    explicit_human_edit: bool,
) -> Result<PathBuf, String> {
    can_write_relative_path(SuiteApp::Novel, rel_path)?;
    if !rel_path.contains("/novel/prose/") {
        return Err(format!(
            "Novel prose writer only targets 'chapters/*/novel/prose/<lang>.md', got '{rel_path}'"
        ));
    }
    if is_locked && !explicit_human_edit {
        return Err(format!(
            "Refused automated overwrite of locked human prose '{rel_path}' (locked=\"true\")"
        ));
    }

    let target = project_dir.join(rel_path);
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed creating prose dir '{}': {e}", parent.display()))?;
    }

    let tmp_name = format!(
        ".{}.tmp.{}",
        target
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("prose"),
        std::process::id()
    );
    let tmp_path = target.with_file_name(tmp_name);
    let normalized = markdown_utf8.replace("\r\n", "\n");
    fs::write(&tmp_path, normalized.as_bytes())
        .map_err(|e| format!("Failed writing temp prose file '{}': {e}", tmp_path.display()))?;
    fs::rename(&tmp_path, &target)
        .map_err(|e| format!("Failed atomic rename to '{}': {e}", target.display()))?;
    Ok(target)
}

/// Intentional narrative adaptation note recorded in `chapters/<ch>/novel/novel_meta.xml`
/// so continuity checkers & local AI respect deliberate differences from the manga track.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DivergenceNote {
    pub scene_id: Option<String>,
    pub summary: String,
}

/// Deterministic metadata model persisted at `chapters/<ch>/novel/novel_meta.xml`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NovelChapterMeta {
    pub chapter_id: String,
    pub decoupled_from_manga: bool,
    pub locked: bool,
    pub divergence_notes: Vec<DivergenceNote>,
}

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn xml_unescape(s: &str) -> String {
    s.replace("&quot;", "\"")
        .replace("&gt;", ">")
        .replace("&lt;", "<")
        .replace("&amp;", "&")
}

fn extract_xml_attr(tag: &str, attr: &str) -> Option<String> {
    let needle = format!("{attr}=\"");
    let start = tag.find(&needle)? + needle.len();
    let rest = &tag[start..];
    let end = rest.find('"')?;
    Some(xml_unescape(&rest[..end]))
}

impl NovelChapterMeta {
    /// Serializes to deterministic 2-space LF CPFF v1.0 XML (zero noisy Git diffs).
    pub fn to_xml(&self) -> String {
        let mut out = format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<NovelChapterMeta xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\" chapter=\"{}\" decoupledFromManga=\"{}\" locked=\"{}\">\n",
            xml_escape(&self.chapter_id),
            if self.decoupled_from_manga { "true" } else { "false" },
            if self.locked { "true" } else { "false" },
        );
        for note in &self.divergence_notes {
            if let Some(ref sc) = note.scene_id {
                out.push_str(&format!(
                    "  <DivergenceNote scene=\"{}\">{}</DivergenceNote>\n",
                    xml_escape(sc),
                    xml_escape(&note.summary)
                ));
            } else {
                out.push_str(&format!(
                    "  <DivergenceNote>{}</DivergenceNote>\n",
                    xml_escape(&note.summary)
                ));
            }
        }
        out.push_str("</NovelChapterMeta>\n");
        out
    }

    pub fn parse_xml(xml: &str, fallback_chapter_id: &str) -> Self {
        let mut chapter_id = fallback_chapter_id.to_string();
        let mut decoupled = true;
        let mut locked = false;
        let mut notes = Vec::new();
        for line in xml.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("<NovelChapterMeta ") {
                if let Some(ch) = extract_xml_attr(trimmed, "chapter") {
                    chapter_id = ch;
                }
                if let Some(d) = extract_xml_attr(trimmed, "decoupledFromManga") {
                    decoupled = d == "true";
                }
                if let Some(l) = extract_xml_attr(trimmed, "locked") {
                    locked = l == "true";
                }
            } else if trimmed.starts_with("<DivergenceNote") && trimmed.ends_with("</DivergenceNote>") {
                let scene_id = extract_xml_attr(trimmed, "scene");
                if let (Some(open_end), Some(close_start)) = (trimmed.find('>'), trimmed.rfind("</DivergenceNote>")) {
                    if open_end + 1 <= close_start {
                        let body = xml_unescape(&trimmed[open_end + 1..close_start]);
                        notes.push(DivergenceNote {
                            scene_id,
                            summary: body,
                        });
                    }
                }
            }
        }
        Self {
            chapter_id,
            decoupled_from_manga: decoupled,
            locked,
            divergence_notes: notes,
        }
    }

    pub fn load_from_project(project_dir: &Path, chapter_id: &str) -> Result<Self, String> {
        let rel = format!("chapters/{chapter_id}/novel/novel_meta.xml");
        let path = project_dir.join(&rel);
        if !path.is_file() {
            return Ok(Self {
                chapter_id: chapter_id.to_string(),
                decoupled_from_manga: true,
                locked: false,
                divergence_notes: Vec::new(),
            });
        }
        let xml = fs::read_to_string(&path)
            .map_err(|e| format!("Failed reading '{}': {e}", path.display()))?;
        Ok(Self::parse_xml(&xml, chapter_id))
    }

    /// Exports compact tab-delimited `<DivergenceNote>` lines (`scene_id\tsummary`) for C-ABI display.
    pub fn export_divergence_lines(&self) -> String {
        self.divergence_notes
            .iter()
            .map(|n| {
                format!(
                    "{}\t{}",
                    n.scene_id.as_deref().unwrap_or("general").replace(['\t', '\n', '\r'], " "),
                    n.summary.replace(['\t', '\n', '\r'], " ")
                )
            })
            .collect::<Vec<_>>()
            .join("\n")
    }

    /// Atomically persists `chapters/<chapter_id>/novel/novel_meta.xml` under `SuiteApp::Novel`.
    pub fn save_atomic(&self, project_dir: &Path) -> Result<PathBuf, String> {
        let rel = format!("chapters/{}/novel/novel_meta.xml", self.chapter_id);
        can_write_relative_path(SuiteApp::Novel, &rel)?;
        let target = project_dir.join(&rel);
        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        let tmp = target.with_file_name(format!(".novel_meta.tmp.{}", std::process::id()));
        fs::write(&tmp, self.to_xml().as_bytes()).map_err(|e| e.to_string())?;
        fs::rename(&tmp, &target).map_err(|e| e.to_string())?;
        Ok(target)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn counts_mixed_cjk_and_latin_novel_prose_accurately() {
        let sample = "星川莲握紧 Starlight Blade。\n\n「风暴正逼近！」Ren whispered softly.";
        let stats = count_novel_words(sample);
        // CJK chars: 星川莲握紧 (5) + 风暴正逼近 (5) = 10
        // Latin words: Starlight, Blade, Ren, whispered, softly = 5
        assert_eq!(stats.cjk_chars, 10);
        assert_eq!(stats.latin_words, 5);
        assert_eq!(stats.total_units, 15);
        assert_eq!(stats.paragraphs, 2);
        assert_eq!(stats.estimated_read_minutes, 1);
    }

    #[test]
    fn atomic_prose_save_enforces_write_ownership_and_human_lock() {
        let tmp = std::env::temp_dir().join(format!(
            "about_paint_novel_test_{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&tmp);
        fs::create_dir_all(&tmp).unwrap();

        // Blocked: cross-app write into manga manuscript
        assert!(write_novel_prose_atomic(
            &tmp,
            "chapters/ch001/manuscript/p01.mnga",
            "bad",
            false,
            true
        )
        .is_err());

        // Blocked: automated overwrite of locked human prose
        assert!(write_novel_prose_atomic(
            &tmp,
            "chapters/ch001/novel/prose/zh-Hans.md",
            "ai overwrite",
            true,
            false
        )
        .is_err());

        // Allowed: explicit human save
        let saved = write_novel_prose_atomic(
            &tmp,
            "chapters/ch001/novel/prose/zh-Hans.md",
            "# 第一话\n\n人工终稿内容。\n",
            true,
            true,
        )
        .expect("explicit human save must succeed");
        assert_eq!(
            fs::read_to_string(&saved).unwrap(),
            "# 第一话\n\n人工终稿内容。\n"
        );

        // Allowed: save DivergenceNote metadata to novel/novel_meta.xml
        let meta = NovelChapterMeta {
            chapter_id: "ch001".into(),
            decoupled_from_manga: true,
            locked: true,
            divergence_notes: vec![DivergenceNote {
                scene_id: Some("sc001".into()),
                summary: "Retains extended inner monologue omitted in manga p03.".into(),
            }],
        };
        let meta_path = meta.save_atomic(&tmp).expect("novel_meta.xml save");
        let xml = fs::read_to_string(&meta_path).unwrap();
        assert!(xml.contains("<DivergenceNote scene=\"sc001\">"));
        assert!(xml.contains("decoupledFromManga=\"true\""));

        let _ = fs::remove_dir_all(&tmp);
    }
}
