//! Creative Project File Framework V1.0 (CPFF v1.0) manifest model, deterministic
//! XML serializer/parser, and same-name / Git-clone-fallback `.prj` resolver.

use std::path::{Path, PathBuf};

pub const CPFF_XML_NAMESPACE: &str = "urn:about-paint-tools:cpff:1.0";
pub const CPFF_SCHEMA_VERSION: &str = "1.0";

/// Outcome of locating the master `.prj` file inside a project folder.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PrjResolution {
    /// Exact match: `<FolderName>/<FolderName>.prj`.
    ExactMatch(PathBuf),
    /// Git clone / local folder rename tolerance: exactly one `*.prj` found at root.
    RenamedFolderFallback {
        prj_path: PathBuf,
        expected_filename: String,
    },
}

impl PrjResolution {
    pub fn path(&self) -> &Path {
        match self {
            Self::ExactMatch(p) => p,
            Self::RenamedFolderFallback { prj_path, .. } => prj_path,
        }
    }
}

/// Locates the root `.prj` file for `project_dir` following CPFF v1.0 Section 3:
/// 1. Prefer exact `<FolderName>.prj`.
/// 2. Fall back to a unique root `*.prj` if the folder was renamed (e.g., via `git clone`).
/// 3. Return an explicit error if zero or multiple `.prj` files exist.
pub fn resolve_prj_file(project_dir: &Path) -> Result<PrjResolution, String> {
    if !project_dir.is_dir() {
        return Err(format!("Project path is not a directory: {}", project_dir.display()));
    }
    let folder_name = project_dir
        .file_name()
        .and_then(|s| s.to_str())
        .ok_or_else(|| "Unable to determine project folder name".to_string())?;

    let expected_filename = format!("{folder_name}.prj");
    let exact = project_dir.join(&expected_filename);
    if exact.is_file() {
        return Ok(PrjResolution::ExactMatch(exact));
    }

    let mut found: Vec<PathBuf> = Vec::new();
    let entries = std::fs::read_dir(project_dir)
        .map_err(|e| format!("Failed to read project directory: {e}"))?;
    for entry in entries.flatten() {
        let p = entry.path();
        if p.is_file() && p.extension().and_then(|s| s.to_str()) == Some("prj") {
            found.push(p);
        }
    }
    found.sort();

    match found.len() {
        1 => Ok(PrjResolution::RenamedFolderFallback {
            prj_path: found.remove(0),
            expected_filename,
        }),
        0 => Err(format!(
            "No .prj manifest found in '{}' (expected '{}')",
            project_dir.display(),
            expected_filename
        )),
        n => Err(format!(
            "Ambiguous project root '{}': found {n} .prj files ({:?})",
            project_dir.display(),
            found
        )),
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WorkType {
    Original,
    Doujinshi,
    Anthology,
}

impl WorkType {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Original => "original",
            Self::Doujinshi => "doujinshi",
            Self::Anthology => "anthology",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s.trim() {
            "original" => Some(Self::Original),
            "doujinshi" => Some(Self::Doujinshi),
            "anthology" => Some(Self::Anthology),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReadingDirection {
    Rtl,
    Ltr,
    VerticalScroll,
}

impl ReadingDirection {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Rtl => "rtl",
            Self::Ltr => "ltr",
            Self::VerticalScroll => "vertical-scroll",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s.trim() {
            "rtl" => Some(Self::Rtl),
            "ltr" => Some(Self::Ltr),
            "vertical-scroll" => Some(Self::VerticalScroll),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EditionRef {
    pub id: String,
    pub track: String,
    pub preset: String,
    pub reading: ReadingDirection,
    pub locale: String,
    pub config_src: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChapterRef {
    pub id: String,
    pub number: u32,
    pub status: String,
    pub src: String,
}

/// Core in-memory representation of a CPFF v1.0 `<ProjectName>.prj` XML manifest.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreativeProjectManifest {
    pub id: String,
    pub title_en: String,
    pub title_zh_hans: String,
    pub genre: String,
    pub work_type: WorkType,
    pub reading_direction: ReadingDirection,
    pub primary_track: String,
    pub license_spdx: String,
    pub allow_derivative: bool,
    pub commercial_allowed: bool,
    pub ai_training_opt_out: bool,
    pub dictionary_src: String,
    pub editions: Vec<EditionRef>,
    pub chapters: Vec<ChapterRef>,
    pub git_lfs_enabled: bool,
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

fn extract_attr(tag_slice: &str, attr_name: &str) -> Option<String> {
    let needle = format!("{attr_name}=\"");
    let start = tag_slice.find(&needle)? + needle.len();
    let rest = &tag_slice[start..];
    let end = rest.find('"')?;
    Some(xml_unescape(&rest[..end]))
}

fn extract_simple_tag_text(xml: &str, tag: &str) -> Option<String> {
    let open = format!("<{tag}>");
    let close = format!("</{tag}>");
    let start = xml.find(&open)? + open.len();
    let end = xml[start..].find(&close)? + start;
    Some(xml_unescape(xml[start..end].trim()))
}

fn extract_title_for_lang(xml: &str, lang: &str) -> Option<String> {
    let needle = format!("<Title lang=\"{lang}\">");
    let start = xml.find(&needle)? + needle.len();
    let end = xml[start..].find("</Title>")? + start;
    Some(xml_unescape(xml[start..end].trim()))
}

impl CreativeProjectManifest {
    /// Emits deterministic, Git-diff-friendly UTF-8 XML conforming to CPFF v1.0.
    pub fn to_prj_xml(&self) -> String {
        let mut out = String::new();
        out.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        out.push_str(&format!(
            "<CreativeProject xmlns=\"{}\" schemaVersion=\"{}\" id=\"{}\">\n",
            CPFF_XML_NAMESPACE,
            CPFF_SCHEMA_VERSION,
            xml_escape(&self.id)
        ));
        out.push_str("  <Metadata>\n");
        out.push_str(&format!("    <Title lang=\"en\">{}</Title>\n", xml_escape(&self.title_en)));
        out.push_str(&format!(
            "    <Title lang=\"zh-Hans\">{}</Title>\n",
            xml_escape(&self.title_zh_hans)
        ));
        out.push_str(&format!("    <Genre>{}</Genre>\n", xml_escape(&self.genre)));
        out.push_str(&format!("    <WorkType>{}</WorkType>\n", self.work_type.as_str()));
        out.push_str(&format!(
            "    <ReadingDirection default=\"{}\"/>\n",
            self.reading_direction.as_str()
        ));
        out.push_str(&format!(
            "    <PrimaryTrack>{}</PrimaryTrack>\n",
            xml_escape(&self.primary_track)
        ));
        out.push_str("  </Metadata>\n");

        out.push_str("  <Declarations>\n");
        out.push_str(&format!(
            "    <License spdx=\"{}\" src=\"LICENSE\"/>\n",
            xml_escape(&self.license_spdx)
        ));
        out.push_str(&format!(
            "    <FanworkPolicy allowDerivative=\"{}\" commercialAllowed=\"{}\" aiTrainingOptOut=\"{}\" src=\"declarations/FANWORK_LICENSE.md\"/>\n",
            self.allow_derivative, self.commercial_allowed, self.ai_training_opt_out
        ));
        out.push_str("  </Declarations>\n");

        out.push_str("  <Localization>\n");
        out.push_str(&format!(
            "    <Dictionary src=\"{}\"/>\n",
            xml_escape(&self.dictionary_src)
        ));
        out.push_str("  </Localization>\n");

        out.push_str("  <Editions>\n");
        for ed in &self.editions {
            out.push_str(&format!(
                "    <Edition id=\"{}\" track=\"{}\" preset=\"{}\" reading=\"{}\" locale=\"{}\" config=\"{}\"/>\n",
                xml_escape(&ed.id),
                xml_escape(&ed.track),
                xml_escape(&ed.preset),
                ed.reading.as_str(),
                xml_escape(&ed.locale),
                xml_escape(&ed.config_src),
            ));
        }
        out.push_str("  </Editions>\n");

        out.push_str("  <StoryStructure>\n");
        out.push_str("    <Chapters>\n");
        for ch in &self.chapters {
            out.push_str(&format!(
                "      <Chapter id=\"{}\" number=\"{}\" status=\"{}\" src=\"{}\"/>\n",
                xml_escape(&ch.id),
                ch.number,
                xml_escape(&ch.status),
                xml_escape(&ch.src),
            ));
        }
        out.push_str("    </Chapters>\n");
        out.push_str("  </StoryStructure>\n");

        out.push_str(&format!(
            "  <Repository vcs=\"git\" lfsEnabled=\"{}\"/>\n",
            self.git_lfs_enabled
        ));
        out.push_str("</CreativeProject>\n");
        out
    }

    /// Parses a CPFF v1.0 `.prj` XML string without external dependencies.
    pub fn parse_prj_xml(xml: &str) -> Result<Self, String> {
        let root_start = xml
            .find("<CreativeProject")
            .ok_or_else(|| "Missing <CreativeProject> root element".to_string())?;
        let root_end = xml[root_start..]
            .find('>')
            .map(|i| root_start + i)
            .ok_or_else(|| "Malformed <CreativeProject> opening tag".to_string())?;
        let root_tag = &xml[root_start..=root_end];

        let ns = extract_attr(root_tag, "xmlns").unwrap_or_default();
        if ns != CPFF_XML_NAMESPACE {
            return Err(format!("Unexpected xmlns '{ns}', expected '{CPFF_XML_NAMESPACE}'"));
        }
        let id = extract_attr(root_tag, "id").ok_or_else(|| "Missing project id".to_string())?;

        let title_en = extract_title_for_lang(xml, "en").unwrap_or_default();
        let title_zh_hans = extract_title_for_lang(xml, "zh-Hans").unwrap_or_default();
        let genre = extract_simple_tag_text(xml, "Genre").unwrap_or_default();
        let work_type = extract_simple_tag_text(xml, "WorkType")
            .and_then(|s| WorkType::from_str(&s))
            .unwrap_or(WorkType::Original);
        let primary_track =
            extract_simple_tag_text(xml, "PrimaryTrack").unwrap_or_else(|| "dual".into());

        let reading_direction = xml
            .find("<ReadingDirection")
            .and_then(|i| {
                let end = xml[i..].find('>')? + i;
                extract_attr(&xml[i..=end], "default")
            })
            .and_then(|s| ReadingDirection::from_str(&s))
            .unwrap_or(ReadingDirection::Rtl);

        let license_spdx = xml
            .find("<License")
            .and_then(|i| {
                let end = xml[i..].find('>')? + i;
                extract_attr(&xml[i..=end], "spdx")
            })
            .unwrap_or_else(|| "All-Rights-Reserved".into());

        let (allow_derivative, commercial_allowed, ai_training_opt_out) = xml
            .find("<FanworkPolicy")
            .and_then(|i| {
                let end = xml[i..].find('>')? + i;
                let tag = &xml[i..=end];
                Some((
                    extract_attr(tag, "allowDerivative").as_deref() == Some("true"),
                    extract_attr(tag, "commercialAllowed").as_deref() == Some("true"),
                    extract_attr(tag, "aiTrainingOptOut").as_deref() == Some("true"),
                ))
            })
            .unwrap_or((false, false, true));

        let dictionary_src = xml
            .find("<Dictionary")
            .and_then(|i| {
                let end = xml[i..].find('>')? + i;
                extract_attr(&xml[i..=end], "src")
            })
            .unwrap_or_else(|| "i18n/dictionary.xml".into());

        let mut editions = Vec::new();
        let mut search = xml;
        while let Some(pos) = search.find("<Edition ") {
            let after = &search[pos..];
            let Some(end) = after.find("/>") else { break };
            let tag = &after[..end + 2];
            if let (Some(eid), Some(track), Some(preset), Some(locale), Some(cfg)) = (
                extract_attr(tag, "id"),
                extract_attr(tag, "track"),
                extract_attr(tag, "preset"),
                extract_attr(tag, "locale"),
                extract_attr(tag, "config"),
            ) {
                let reading = extract_attr(tag, "reading")
                    .and_then(|s| ReadingDirection::from_str(&s))
                    .unwrap_or(ReadingDirection::Rtl);
                editions.push(EditionRef {
                    id: eid,
                    track,
                    preset,
                    reading,
                    locale,
                    config_src: cfg,
                });
            }
            search = &after[end + 2..];
        }

        let mut chapters = Vec::new();
        let mut search = xml;
        while let Some(pos) = search.find("<Chapter ") {
            let after = &search[pos..];
            let Some(end) = after.find("/>") else { break };
            let tag = &after[..end + 2];
            if let (Some(cid), Some(num_s), Some(status), Some(src)) = (
                extract_attr(tag, "id"),
                extract_attr(tag, "number"),
                extract_attr(tag, "status"),
                extract_attr(tag, "src"),
            ) {
                if let Ok(number) = num_s.parse::<u32>() {
                    chapters.push(ChapterRef {
                        id: cid,
                        number,
                        status,
                        src,
                    });
                }
            }
            search = &after[end + 2..];
        }

        let git_lfs_enabled = xml
            .find("<Repository")
            .and_then(|i| {
                let end = xml[i..].find('>')? + i;
                extract_attr(&xml[i..=end], "lfsEnabled")
            })
            .as_deref()
            == Some("true");

        Ok(Self {
            id,
            title_en,
            title_zh_hans,
            genre,
            work_type,
            reading_direction,
            primary_track,
            license_spdx,
            allow_derivative,
            commercial_allowed,
            ai_training_opt_out,
            dictionary_src,
            editions,
            chapters,
            git_lfs_enabled,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_real_sample_manga_prj_manifest_cleanly() {
        let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let sample_dir = manifest_dir.join("../../templates/SampleManga");
        let resolved = resolve_prj_file(&sample_dir).expect("SampleManga.prj must resolve");
        assert!(matches!(resolved, PrjResolution::ExactMatch(_)));

        let xml = std::fs::read_to_string(resolved.path()).expect("read SampleManga.prj");
        let parsed = CreativeProjectManifest::parse_prj_xml(&xml).expect("parse SampleManga.prj");
        assert_eq!(parsed.id, "prj-sample-manga-001");
        assert_eq!(parsed.work_type, WorkType::Original);
        assert_eq!(parsed.reading_direction, ReadingDirection::Rtl);
        assert_eq!(parsed.editions.len(), 3);
        assert_eq!(parsed.chapters.len(), 1);
        assert!(parsed.allow_derivative);
        assert!(!parsed.commercial_allowed);
        assert!(parsed.ai_training_opt_out);
        assert!(parsed.git_lfs_enabled);
    }

    #[test]
    fn manifest_round_trips_through_deterministic_xml() {
        let orig = CreativeProjectManifest {
            id: "prj-roundtrip-01".into(),
            title_en: "Moon & Blade".into(),
            title_zh_hans: "月与刃".into(),
            genre: "Fantasy".into(),
            work_type: WorkType::Doujinshi,
            reading_direction: ReadingDirection::VerticalScroll,
            primary_track: "color-webtoon".into(),
            license_spdx: "CC-BY-NC-SA-4.0".into(),
            allow_derivative: true,
            commercial_allowed: false,
            ai_training_opt_out: true,
            dictionary_src: "i18n/dictionary.xml".into(),
            editions: vec![EditionRef {
                id: "webtoon-es".into(),
                track: "color-webtoon".into(),
                preset: "WEBTOON_800".into(),
                reading: ReadingDirection::VerticalScroll,
                locale: "es".into(),
                config_src: "editions/edition_intl_digital.xml".into(),
            }],
            chapters: vec![ChapterRef {
                id: "ch001".into(),
                number: 1,
                status: "drafting".into(),
                src: "chapters/ch001/chapter.xml".into(),
            }],
            git_lfs_enabled: true,
        };

        let xml = orig.to_prj_xml();
        let parsed = CreativeProjectManifest::parse_prj_xml(&xml).unwrap();
        assert_eq!(parsed, orig);
    }

    #[test]
    fn resolve_prj_supports_git_clone_renamed_folder_fallback() {
        let base = std::env::temp_dir().join("cpff_test_renamed_clone");
        let _ = std::fs::remove_dir_all(&base);
        std::fs::create_dir_all(&base).unwrap();
        let prj = base.join("OriginalTitle.prj");
        std::fs::write(&prj, "<CreativeProject/>").unwrap();

        let res = resolve_prj_file(&base).expect("unique fallback must succeed");
        assert!(matches!(res, PrjResolution::RenamedFolderFallback { .. }));
        assert_eq!(res.path(), prj.as_path());

        // Adding a second .prj must trigger an ambiguity error.
        std::fs::write(base.join("Second.prj"), "<CreativeProject/>").unwrap();
        assert!(resolve_prj_file(&base).is_err());

        let _ = std::fs::remove_dir_all(&base);
    }
}
