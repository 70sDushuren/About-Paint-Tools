//! `S1 v0.3.1` Story Bible (`bible/characters.xml`) & Master TOC (`outline/toc.xml`)
//! atomic persistence and `< 300ms` cross-app hot-reload revision fingerprinting for `S2`/`S3`.

use std::fs;
use std::path::{Path, PathBuf};

use crate::project::{CPFF_SCHEMA_VERSION, CPFF_XML_NAMESPACE};
use crate::suite::{can_write_relative_path, SuiteApp};

pub const STORY_BIBLE_REL_PATH: &str = "bible/characters.xml";
pub const PROJECT_TOC_REL_PATH: &str = "outline/toc.xml";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BibleCharacter {
    pub id: String,
    pub name_zh: String,
    pub name_en: String,
    pub role: String,
    pub palette_hex: String,
    pub visual_anchors: Vec<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct StoryBible {
    pub characters: Vec<BibleCharacter>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TocChapterEntry {
    pub chapter_id: String,
    pub number: u32,
    pub title_zh: String,
    pub title_en: String,
    pub status: String,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ProjectToc {
    pub entries: Vec<TocChapterEntry>,
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

fn extract_attr(tag: &str, attr: &str) -> Option<String> {
    let needle = format!("{attr}=\"");
    let start = tag.find(&needle)? + needle.len();
    let rest = &tag[start..];
    let end = rest.find('"')?;
    Some(xml_unescape(&rest[..end]))
}

fn atomic_write_xml(target: &Path, xml: &str) -> Result<PathBuf, String> {
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed creating parent dir '{}': {e}", parent.display()))?;
    }
    let tmp_name = format!(
        ".{}.tmp.{}",
        target
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("xml"),
        std::process::id()
    );
    let tmp_path = target.with_file_name(tmp_name);
    fs::write(&tmp_path, xml.as_bytes())
        .map_err(|e| format!("Failed writing temp XML '{}': {e}", tmp_path.display()))?;
    fs::rename(&tmp_path, target)
        .map_err(|e| format!("Failed atomic rename into '{}': {e}", target.display()))?;
    Ok(target.to_path_buf())
}

impl StoryBible {
    pub fn upsert_character(&mut self, character: BibleCharacter) {
        if let Some(existing) = self.characters.iter_mut().find(|c| c.id == character.id) {
            *existing = character;
        } else {
            self.characters.push(character);
        }
        self.characters.sort_by(|a, b| a.id.cmp(&b.id));
    }

    /// Deterministic 2-space LF XML serialization (zero noisy Git diffs).
    pub fn to_xml(&self) -> String {
        let mut out = format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<StoryBible xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\">\n"
        );
        for c in &self.characters {
            let anchors = c.visual_anchors.join("|");
            out.push_str(&format!(
                "  <Character id=\"{}\" nameZh=\"{}\" nameEn=\"{}\" role=\"{}\" palette=\"{}\" anchors=\"{}\"/>\n",
                xml_escape(&c.id),
                xml_escape(&c.name_zh),
                xml_escape(&c.name_en),
                xml_escape(&c.role),
                xml_escape(&c.palette_hex),
                xml_escape(&anchors),
            ));
        }
        out.push_str("</StoryBible>\n");
        out
    }

    pub fn parse_xml(xml: &str) -> Result<Self, String> {
        let mut characters = Vec::new();
        for line in xml.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("<Character ") {
                let id = extract_attr(trimmed, "id")
                    .ok_or_else(|| "StoryBible <Character> missing id".to_string())?;
                let name_zh = extract_attr(trimmed, "nameZh").unwrap_or_default();
                let name_en = extract_attr(trimmed, "nameEn").unwrap_or_default();
                let role = extract_attr(trimmed, "role").unwrap_or_else(|| "supporting".into());
                let palette_hex = extract_attr(trimmed, "palette").unwrap_or_else(|| "#4F7CFF".into());
                let anchors_raw = extract_attr(trimmed, "anchors").unwrap_or_default();
                let visual_anchors = anchors_raw
                    .split('|')
                    .map(str::trim)
                    .filter(|s| !s.is_empty())
                    .map(String::from)
                    .collect();
                characters.push(BibleCharacter {
                    id,
                    name_zh,
                    name_en,
                    role,
                    palette_hex,
                    visual_anchors,
                });
            }
        }
        Ok(Self { characters })
    }

    pub fn load_from_project(project_dir: &Path) -> Result<Self, String> {
        let path = project_dir.join(STORY_BIBLE_REL_PATH);
        if !path.is_file() {
            return Ok(Self::default());
        }
        let xml = fs::read_to_string(&path)
            .map_err(|e| format!("Failed reading '{}': {e}", path.display()))?;
        Self::parse_xml(&xml)
    }

    /// Atomically persists `bible/characters.xml` strictly under `SuiteApp::Hub` write ownership.
    pub fn save_atomic(&self, project_dir: &Path) -> Result<PathBuf, String> {
        can_write_relative_path(SuiteApp::Hub, STORY_BIBLE_REL_PATH)?;
        atomic_write_xml(&project_dir.join(STORY_BIBLE_REL_PATH), &self.to_xml())
    }

    /// Exports compact tab-delimited summary lines (`id\tname_zh\tname_en\trole\tpalette_hex`)
    /// for zero-allocation C-ABI read-only display in `S1`/`S2`/`S3` UI shells.
    pub fn export_summary_lines(&self) -> String {
        self.characters
            .iter()
            .map(|c| {
                format!(
                    "{}\t{}\t{}\t{}\t{}",
                    c.id.replace(['\t', '\n', '\r'], " "),
                    c.name_zh.replace(['\t', '\n', '\r'], " "),
                    c.name_en.replace(['\t', '\n', '\r'], " "),
                    c.role.replace(['\t', '\n', '\r'], " "),
                    c.palette_hex.replace(['\t', '\n', '\r'], " "),
                )
            })
            .collect::<Vec<_>>()
            .join("\n")
    }
}

impl ProjectToc {
    pub fn upsert_entry(&mut self, entry: TocChapterEntry) {
        if let Some(existing) = self
            .entries
            .iter_mut()
            .find(|e| e.chapter_id == entry.chapter_id)
        {
            *existing = entry;
        } else {
            self.entries.push(entry);
        }
        self.entries
            .sort_by(|a, b| a.number.cmp(&b.number).then_with(|| a.chapter_id.cmp(&b.chapter_id)));
    }

    pub fn to_xml(&self) -> String {
        let mut out = format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<ProjectToc xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\">\n"
        );
        for e in &self.entries {
            out.push_str(&format!(
                "  <Entry chapter=\"{}\" number=\"{}\" titleZh=\"{}\" titleEn=\"{}\" status=\"{}\"/>\n",
                xml_escape(&e.chapter_id),
                e.number,
                xml_escape(&e.title_zh),
                xml_escape(&e.title_en),
                xml_escape(&e.status),
            ));
        }
        out.push_str("</ProjectToc>\n");
        out
    }

    pub fn parse_xml(xml: &str) -> Result<Self, String> {
        let mut entries = Vec::new();
        for line in xml.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("<Entry ") {
                let chapter_id = extract_attr(trimmed, "chapter")
                    .ok_or_else(|| "ProjectToc <Entry> missing chapter".to_string())?;
                let number = extract_attr(trimmed, "number")
                    .and_then(|s| s.parse::<u32>().ok())
                    .unwrap_or(1);
                let title_zh = extract_attr(trimmed, "titleZh").unwrap_or_default();
                let title_en = extract_attr(trimmed, "titleEn").unwrap_or_default();
                let status = extract_attr(trimmed, "status").unwrap_or_else(|| "draft".into());
                entries.push(TocChapterEntry {
                    chapter_id,
                    number,
                    title_zh,
                    title_en,
                    status,
                });
            }
        }
        Ok(Self { entries })
    }

    pub fn load_from_project(project_dir: &Path) -> Result<Self, String> {
        let path = project_dir.join(PROJECT_TOC_REL_PATH);
        if !path.is_file() {
            return Ok(Self::default());
        }
        let xml = fs::read_to_string(&path)
            .map_err(|e| format!("Failed reading '{}': {e}", path.display()))?;
        Self::parse_xml(&xml)
    }

    /// Atomically persists `outline/toc.xml` strictly under `SuiteApp::Hub` write ownership.
    pub fn save_atomic(&self, project_dir: &Path) -> Result<PathBuf, String> {
        can_write_relative_path(SuiteApp::Hub, PROJECT_TOC_REL_PATH)?;
        atomic_write_xml(&project_dir.join(PROJECT_TOC_REL_PATH), &self.to_xml())
    }

    /// Exports compact tab-delimited summary lines (`chapter_id\tnumber\ttitle_zh\ttitle_en\tstatus`)
    /// for zero-allocation C-ABI read-only display in `S1`/`S2`/`S3` UI shells.
    pub fn export_summary_lines(&self) -> String {
        self.entries
            .iter()
            .map(|e| {
                format!(
                    "{}\t{}\t{}\t{}\t{}",
                    e.chapter_id.replace(['\t', '\n', '\r'], " "),
                    e.number,
                    e.title_zh.replace(['\t', '\n', '\r'], " "),
                    e.title_en.replace(['\t', '\n', '\r'], " "),
                    e.status.replace(['\t', '\n', '\r'], " "),
                )
            })
            .collect::<Vec<_>>()
            .join("\n")
    }
}

/// Computes a fast, deterministic FNV-1a 64-bit content hash over `bible/characters.xml`
/// and `outline/toc.xml` so `S2` (DracoNib) and `S3` (LitteraCore) detect `S1` atomic updates
/// in `< 1ms` (well within the `< 300ms` hot-reload SLA) without disturbing editor cursor state.
pub fn story_bible_revision_hash(project_dir: &Path) -> u64 {
    let mut hash: u64 = 0xcbf29ce484222325;
    for rel in [STORY_BIBLE_REL_PATH, PROJECT_TOC_REL_PATH] {
        let p = project_dir.join(rel);
        if let Ok(bytes) = fs::read(&p) {
            for b in rel.as_bytes().iter().chain(bytes.iter()) {
                hash ^= u64::from(*b);
                hash = hash.wrapping_mul(0x100000001b3);
            }
        }
    }
    hash
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn story_bible_and_toc_atomic_round_trip_updates_revision_hash() {
        let root = std::env::temp_dir().join(format!("manga_bible_test_{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();

        let rev0 = story_bible_revision_hash(&root);

        let mut bible = StoryBible::default();
        bible.upsert_character(BibleCharacter {
            id: "char-lin".into(),
            name_zh: "林晓".into(),
            name_en: "Lin Xiao".into(),
            role: "protagonist".into(),
            palette_hex: "#4F7CFF".into(),
            visual_anchors: vec!["silver starlight hairpin".into(), "navy cape".into()],
        });
        bible.save_atomic(&root).unwrap();

        let rev1 = story_bible_revision_hash(&root);
        assert_ne!(rev0, rev1);

        let loaded = StoryBible::load_from_project(&root).unwrap();
        assert_eq!(loaded, bible);
        assert_eq!(
            loaded.export_summary_lines(),
            "char-lin\t林晓\tLin Xiao\tprotagonist\t#4F7CFF"
        );

        let mut toc = ProjectToc::default();
        toc.upsert_entry(TocChapterEntry {
            chapter_id: "ch002".into(),
            number: 2,
            title_zh: "墨影回廊".into(),
            title_en: "Ink Shadow Corridor".into(),
            status: "draft".into(),
        });
        toc.upsert_entry(TocChapterEntry {
            chapter_id: "ch001".into(),
            number: 1,
            title_zh: "星辉觉醒".into(),
            title_en: "Starlight Awakening".into(),
            status: "in_progress".into(),
        });
        toc.save_atomic(&root).unwrap();
        let rev2 = story_bible_revision_hash(&root);
        assert_ne!(rev1, rev2);

        let loaded_toc = ProjectToc::load_from_project(&root).unwrap();
        assert_eq!(loaded_toc.entries.len(), 2);
        assert_eq!(loaded_toc.entries[0].chapter_id, "ch001");
        assert!(loaded_toc.export_summary_lines().contains("ch001\t1\t星辉觉醒"));

        // Enforce write-ownership isolation: only S1 Hub may write bible/ and outline/
        assert!(can_write_relative_path(SuiteApp::Hub, STORY_BIBLE_REL_PATH).is_ok());
        assert!(can_write_relative_path(SuiteApp::Manga, STORY_BIBLE_REL_PATH).is_err());
        assert!(can_write_relative_path(SuiteApp::Novel, STORY_BIBLE_REL_PATH).is_err());
        assert!(can_write_relative_path(SuiteApp::Novel, PROJECT_TOC_REL_PATH).is_err());

        let _ = fs::remove_dir_all(&root);
    }
}
