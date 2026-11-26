//! `S1 v0.2.1` — CPFF v1.0 `.prj` Project Bootstrap Engine (`创想空间 / NoemaDock`, working codename).
//!
//! Creates a complete, deterministic, GitHub/GitLab + Git LFS ready CPFF v1.0 creative project
//! supporting Dual-Track (`BwPageManga` / `ColorWebtoon`) and Dual-Engine (`MangaOnly` / `NovelOnly`
//! / `DualNovelManga`) workflows that passes `scripts/prj_validate.py` and the `S4` integration gate.

use crate::project::{
    CreativeEngineMode, NovelIllustrationMode, ReadingDirection, CPFF_SCHEMA_VERSION,
    CPFF_XML_NAMESPACE,
};
use std::fs;
use std::path::{Path, PathBuf};

/// Configuration options for bootstrapping a new CPFF v1.0 project directory.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectInitOptions {
    /// Safe folder & `<ProjectName>.prj` stem (ASCII alphanumerics, `_`, `-`).
    pub folder_name: String,
    /// Stable project identifier (e.g. `prj-starlight-001`).
    pub project_id: String,
    pub title_en: String,
    pub title_zh_hans: String,
    pub author: String,
    pub creative_engines: CreativeEngineMode,
    pub reading_direction: ReadingDirection,
    pub novel_illustration_mode: NovelIllustrationMode,
    pub lfs_enabled: bool,
}

impl ProjectInitOptions {
    pub fn dual_engine_default(folder_name: &str, author: &str) -> Self {
        let slug = sanitize_id_slug(folder_name);
        Self {
            folder_name: folder_name.to_string(),
            project_id: format!("prj-{slug}-001"),
            title_en: folder_name.to_string(),
            title_zh_hans: folder_name.to_string(),
            author: author.to_string(),
            creative_engines: CreativeEngineMode::DualNovelManga,
            reading_direction: ReadingDirection::Rtl,
            novel_illustration_mode: NovelIllustrationMode::Hybrid,
            lfs_enabled: true,
        }
    }
}

fn sanitize_id_slug(raw: &str) -> String {
    let mut out = String::new();
    for ch in raw.chars() {
        if ch.is_ascii_alphanumeric() {
            out.push(ch.to_ascii_lowercase());
        } else if (ch == '-' || ch == '_' || ch == ' ') && !out.ends_with('-') {
            out.push('-');
        }
    }
    let trimmed = out.trim_matches('-').to_string();
    if trimmed.is_empty() {
        "project".to_string()
    } else {
        trimmed
    }
}

fn validate_folder_name(name: &str) -> Result<(), String> {
    if name.is_empty()
        || name.contains('/')
        || name.contains('\\')
        || name.contains("..")
        || name == "."
    {
        return Err(format!("Invalid CPFF project folder name: '{name}'"));
    }
    Ok(())
}

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn write_utf8_lf(path: &Path, content: &str) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed creating dir '{}': {e}", parent.display()))?;
    }
    let normalized = content.replace("\r\n", "\n");
    fs::write(path, normalized.as_bytes())
        .map_err(|e| format!("Failed writing '{}': {e}", path.display()))
}

/// Bootstraps a complete CPFF v1.0 project inside `parent_dir/<folder_name>/`.
///
/// Returns the path to the created `<folder_name>.prj` XML manifest.
pub fn init_cpff_project(
    parent_dir: &Path,
    opts: &ProjectInitOptions,
) -> Result<PathBuf, String> {
    validate_folder_name(&opts.folder_name)?;
    let root = parent_dir.join(&opts.folder_name);
    if root.exists() {
        return Err(format!(
            "Target project directory already exists: '{}'",
            root.display()
        ));
    }
    fs::create_dir_all(&root)
        .map_err(|e| format!("Failed creating project root '{}': {e}", root.display()))?;

    let prj_path = root.join(format!("{}.prj", opts.folder_name));
    let engines_str = opts.creative_engines.as_str();
    let dir_str = opts.reading_direction.as_str();
    let ill_mode = opts.novel_illustration_mode.as_str();
    let lfs_str = if opts.lfs_enabled { "true" } else { "false" };

    // 1. Root <ProjectName>.prj XML manifest (matches canonical SampleManga.prj schema)
    let prj_xml = format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<CreativeProject xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\" id=\"{id}\">\n\
  <Metadata>\n\
    <Title lang=\"en\">{title_en}</Title>\n\
    <Title lang=\"zh-Hans\">{title_zh}</Title>\n\
    <Authors>\n\
      <Author role=\"creator\">{author}</Author>\n\
    </Authors>\n\
    <WorkType>original</WorkType>\n\
    <ReadingDirection default=\"{reading}\"/>\n\
    <PrimaryTrack>dual</PrimaryTrack>\n\
    <CreativeEngines>{engines}</CreativeEngines>\n\
  </Metadata>\n\
  <Declarations>\n\
    <Readme lang=\"en\" src=\"README.md\"/>\n\
    <License spdx=\"CC-BY-NC-SA-4.0\" src=\"LICENSE\"/>\n\
    <FormatSpec src=\"declarations/FORMAT_SPEC.md\"/>\n\
    <FanworkPolicy allowDerivative=\"true\" commercialAllowed=\"false\" aiTrainingOptOut=\"true\" src=\"declarations/DOUJIN_POLICY.md\"/>\n\
    <AiDisclosure src=\"declarations/AI_DISCLOSURE.md\"/>\n\
  </Declarations>\n\
  <Localization>\n\
    <SourceLocales>\n\
      <Locale code=\"en\" src=\"i18n/locales/en.xml\"/>\n\
      <Locale code=\"zh-Hans\" src=\"i18n/locales/zh-Hans.xml\"/>\n\
    </SourceLocales>\n\
    <TargetLocales>\n\
      <Locale code=\"zh-Hant\" preferredSource=\"zh-Hans\" src=\"i18n/locales/zh-Hant.xml\"/>\n\
      <Locale code=\"yue-Hant\" fallback=\"zh-HK\" preferredSource=\"zh-Hans\" src=\"i18n/locales/yue-Hant.xml\"/>\n\
      <Locale code=\"es\" preferredSource=\"en\" src=\"i18n/locales/es.xml\"/>\n\
    </TargetLocales>\n\
    <Dictionary src=\"i18n/dictionary.xml\"/>\n\
  </Localization>\n\
  <Editions>\n\
    <Edition id=\"bw-print-b4\" track=\"bw-manga\" preset=\"B4_600DPI\" reading=\"{reading}\" locale=\"zh-Hans\" config=\"editions/edition_bw_print.xml\"/>\n\
    <Edition id=\"color-webtoon\" track=\"color-webtoon\" preset=\"WEBTOON_800\" reading=\"vertical-scroll\" locale=\"zh-Hans\" config=\"editions/edition_color_webtoon.xml\"/>\n\
    <Edition id=\"novel-ebook-zh\" track=\"novel-ebook\" preset=\"EPUB3\" reading=\"ltr\" locale=\"zh-Hans\" config=\"editions/edition_novel_epub.xml\"/>\n\
  </Editions>\n\
  <StoryStructure>\n\
    <Outline synopsis=\"outline/synopsis.md\" toc=\"outline/toc.xml\"/>\n\
    <Bible world=\"bible/world.md\" continuity=\"bible/continuity/continuity_log.xml\"/>\n\
    <Chapters>\n\
      <Chapter id=\"ch001\" number=\"1\" status=\"drafting\" src=\"chapters/ch001/chapter.xml\"/>\n\
    </Chapters>\n\
  </StoryStructure>\n\
  <Repository vcs=\"git\" lfsEnabled=\"{lfs}\" remoteHint=\"github-or-gitlab\"/>\n\
</CreativeProject>\n",
        id = xml_escape(&opts.project_id),
        title_en = xml_escape(&opts.title_en),
        title_zh = xml_escape(&opts.title_zh_hans),
        engines = engines_str,
        reading = dir_str,
        author = xml_escape(&opts.author),
        lfs = lfs_str,
    );
    write_utf8_lf(&prj_path, &prj_xml)?;

    // 2. Declarations, README, LICENSE, Git/LFS config
    write_utf8_lf(
        &root.join("README.md"),
        &format!(
            "# {}\n\nCreative Project File Framework V1.0 (`CPFF v1.0`) workspace.\n",
            opts.title_en
        ),
    )?;
    write_utf8_lf(
        &root.join("LICENSE"),
        "Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC-BY-NC-SA-4.0)\n",
    )?;
    write_utf8_lf(
        &root.join(".gitignore"),
        "# Build & release outputs\ndist/\n.DS_Store\n*.tmp\n",
    )?;
    write_utf8_lf(
        &root.join(".gitattributes"),
        "* text=auto eol=lf\n*.mnga filter=lfs diff=lfs merge=lfs -text\n*.psd filter=lfs diff=lfs merge=lfs -text\n*.png filter=lfs diff=lfs merge=lfs -text\n",
    )?;
    write_utf8_lf(
        &root.join("declarations/FORMAT_SPEC.md"),
        "# Format Specification\n\n- B&W Page Manga: B4 600DPI\n- Full-Color Webtoon: 800x1280 slices\n- Light Novel: EPUB3 / Markdown\n",
    )?;
    write_utf8_lf(
        &root.join("declarations/DOUJIN_POLICY.md"),
        "# Doujin & Derivative Works Policy\n\nNon-commercial fanworks permitted with attribution.\n",
    )?;
    write_utf8_lf(
        &root.join("declarations/AI_DISCLOSURE.md"),
        "# AI Assistance Disclosure\n\nAll AI-generated reference drafts are isolated under `ai_assist/` (`role=\"ai_reference_only\"`) and never overwrite human finals.\n",
    )?;

    // 3. Shared Outline & Story Bible
    write_utf8_lf(
        &root.join("outline/synopsis.md"),
        &format!("# {} — Synopsis\n\nOpening chapter outline.\n", opts.title_en),
    )?;
    write_utf8_lf(
        &root.join("outline/toc.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<TableOfContents xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\">\n\
  <Chapter id=\"ch001\" number=\"1\" titleKey=\"ch001.title\"/>\n\
</TableOfContents>\n"
        ),
    )?;
    write_utf8_lf(
        &root.join("bible/world.md"),
        "# Worldbuilding Bible\n\nShared lore for both Manga and Light Novel tracks.\n",
    )?;
    write_utf8_lf(
        &root.join("bible/continuity/continuity_log.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<ContinuityLog xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\"/>\n"
        ),
    )?;

    // 4. 5-Language Dictionary & Dialogue Locales
    write_utf8_lf(
        &root.join("i18n/dictionary.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<Dictionary xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\">\n\
  <Term id=\"term.title\" category=\"title\">\n\
    <Form lang=\"en\" locked=\"true\">{title_en}</Form>\n\
    <Form lang=\"zh-Hans\" locked=\"true\">{title_zh}</Form>\n\
    <Form lang=\"zh-Hant\" locked=\"false\">{title_zh}</Form>\n\
    <Form lang=\"yue-Hant\" locked=\"false\">{title_zh}</Form>\n\
    <Form lang=\"es\" locked=\"false\">{title_en}</Form>\n\
  </Term>\n\
</Dictionary>\n",
            title_en = xml_escape(&opts.title_en),
            title_zh = xml_escape(&opts.title_zh_hans),
        ),
    )?;

    let locale_seeds = [
        ("en", "source", "true", "Chapter 1: Opening", "The journey begins."),
        ("zh-Hans", "source", "true", "第1话：序幕", "旅程由此开始。"),
        ("zh-Hant", "auto", "false", "第1話：序幕", "旅程由此開始。"),
        ("yue-Hant", "auto", "false", "第1話：序幕", "旅程由呢度開始。"),
        ("es", "auto", "false", "Capítulo 1: Prólogo", "El viaje comienza aquí."),
    ];
    for (code, status, locked, ch_title, line1) in locale_seeds {
        write_utf8_lf(
            &root.join(format!("i18n/locales/{code}.xml")),
            &format!(
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<LocaleCatalog xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\" lang=\"{code}\">\n\
  <Line key=\"ch001.title\" status=\"{status}\" locked=\"{locked}\">{ch_title}</Line>\n\
  <Line key=\"ch001.p01.b01\" status=\"{status}\" locked=\"{locked}\" maxChars=\"42\">{line1}</Line>\n\
</LocaleCatalog>\n"
            ),
        )?;
    }

    // 5. Editions
    write_utf8_lf(
        &root.join("editions/edition_bw_print.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<EditionConfig xmlns=\"{CPFF_XML_NAMESPACE}\" id=\"bw-print-b4\">\n\
  <Track>bw-manga</Track>\n\
  <Format>PDF-X4-600DPI</Format>\n\
</EditionConfig>\n"
        ),
    )?;
    write_utf8_lf(
        &root.join("editions/edition_color_webtoon.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<EditionConfig xmlns=\"{CPFF_XML_NAMESPACE}\" id=\"color-webtoon\">\n\
  <Track>color-webtoon</Track>\n\
  <Format>PNG-SLICE-800x1280</Format>\n\
</EditionConfig>\n"
        ),
    )?;
    write_utf8_lf(
        &root.join("editions/edition_novel_epub.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<EditionConfig xmlns=\"{CPFF_XML_NAMESPACE}\" id=\"novel-ebook-zh\">\n\
  <Track>novel-ebook</Track>\n\
  <Format>EPUB3</Format>\n\
  <IllustrationPolicy mode=\"{ill_mode}\" allowMangaPick=\"true\" allowCustomNovelArt=\"true\" customDir=\"novel/illustrations\"/>\n\
</EditionConfig>\n"
        ),
    )?;

    // 6. Chapter 001 skeleton (Manga + Novel + strictly isolated AI sandbox)
    let ch1 = root.join("chapters/ch001");
    fs::create_dir_all(ch1.join("storyboard")).map_err(|e| e.to_string())?;
    fs::create_dir_all(ch1.join("manuscript")).map_err(|e| e.to_string())?;
    fs::create_dir_all(ch1.join("novel/illustrations")).map_err(|e| e.to_string())?;

    write_utf8_lf(
        &ch1.join("chapter.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<ChapterManifest xmlns=\"{CPFF_XML_NAMESPACE}\" schemaVersion=\"{CPFF_SCHEMA_VERSION}\" id=\"ch001\" number=\"1\">\n\
  <Scenes>\n\
    <Scene id=\"sc001\" src=\"scenes/sc001.md\"/>\n\
  </Scenes>\n\
  <Script src=\"script/script.xml\"/>\n\
  <Novel status=\"drafting\" decoupledFromManga=\"true\">\n\
    <Prose lang=\"zh-Hans\" status=\"human_authoritative\" locked=\"true\" src=\"novel/prose/zh-Hans.md\"/>\n\
    <Prose lang=\"en\" status=\"human_authoritative\" locked=\"true\" src=\"novel/prose/en.md\"/>\n\
    <Illustrations dir=\"novel/illustrations\" mode=\"{ill_mode}\"/>\n\
  </Novel>\n\
  <Pages>\n\
    <Page number=\"1\" storyboardDir=\"storyboard\" manuscriptDir=\"manuscript\"/>\n\
  </Pages>\n\
  <AiAssist>\n\
    <CompletionQueue src=\"ai_assist/completion_queue.xml\"/>\n\
    <ReviewPins src=\"ai_assist/review_pins.xml\"/>\n\
    <MangaToNovelBridge role=\"ai_reference_only\" meta=\"ai_assist/manga_to_novel/meta.xml\" draft=\"ai_assist/manga_to_novel/ai_prose_ref_zh-Hans.md\"/>\n\
    <NovelToMangaBridge role=\"ai_reference_only\" meta=\"ai_assist/novel_to_manga/meta.xml\" storyboard=\"ai_assist/novel_to_manga/ai_storyboard_ref.xml\"/>\n\
  </AiAssist>\n\
</ChapterManifest>\n"
        ),
    )?;

    write_utf8_lf(
        &ch1.join("scenes/sc001.md"),
        "# Scene 001\n\nOpening scene beats shared by Manga and Light Novel.\n",
    )?;
    write_utf8_lf(
        &ch1.join("script/script.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<ChapterScript xmlns=\"{CPFF_XML_NAMESPACE}\" chapter=\"ch001\">\n\
  <Page number=\"1\">\n\
    <Panel number=\"1\">\n\
      <Bubble id=\"b01\" dialogueKey=\"ch001.p01.b01\"/>\n\
    </Panel>\n\
  </Page>\n\
</ChapterScript>\n"
        ),
    )?;
    write_utf8_lf(
        &ch1.join("novel/prose/zh-Hans.md"),
        "# 第1话：序幕\n\n这是由作者独立撰写并锁定的轻小说人工终稿。\n",
    )?;
    write_utf8_lf(
        &ch1.join("novel/prose/en.md"),
        "# Chapter 1: Opening\n\nIndependent human-authoritative light novel prose.\n",
    )?;
    write_utf8_lf(
        &ch1.join("novel/novel_meta.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<NovelChapterMeta xmlns=\"{CPFF_XML_NAMESPACE}\" chapter=\"ch001\" decoupledFromManga=\"true\" locked=\"true\"/>\n"
        ),
    )?;

    // Strictly isolated AI sandbox placeholders
    write_utf8_lf(
        &ch1.join("ai_assist/completion_queue.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<CompletionQueue xmlns=\"{CPFF_XML_NAMESPACE}\" role=\"ai_reference_only\"/>\n"
        ),
    )?;
    write_utf8_lf(
        &ch1.join("ai_assist/review_pins.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<ReviewPins xmlns=\"{CPFF_XML_NAMESPACE}\" role=\"ai_reference_only\"/>\n"
        ),
    )?;
    write_utf8_lf(
        &ch1.join("ai_assist/manga_to_novel/meta.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<AiBridgeMeta xmlns=\"{CPFF_XML_NAMESPACE}\" role=\"ai_reference_only\" direction=\"manga_to_novel\" humanOverwritePolicy=\"never\"/>\n"
        ),
    )?;
    write_utf8_lf(
        &ch1.join("ai_assist/manga_to_novel/ai_prose_ref_zh-Hans.md"),
        "<!-- AI Reference Draft Only: never overwrites novel/prose/ -->\n",
    )?;
    write_utf8_lf(
        &ch1.join("ai_assist/novel_to_manga/meta.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<AiBridgeMeta xmlns=\"{CPFF_XML_NAMESPACE}\" role=\"ai_reference_only\" direction=\"novel_to_manga\" humanOverwritePolicy=\"never\"/>\n"
        ),
    )?;
    write_utf8_lf(
        &ch1.join("ai_assist/novel_to_manga/ai_storyboard_ref.xml"),
        &format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<AiStoryboardRef xmlns=\"{CPFF_XML_NAMESPACE}\" role=\"ai_reference_only\"/>\n"
        ),
    )?;

    Ok(prj_path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::project::{resolve_prj_file, CreativeProjectManifest};
    use crate::suite::run_tri_app_compatibility_check;

    #[test]
    fn init_cpff_project_creates_valid_dual_engine_project_passing_s4_gate() {
        let tmp = std::env::temp_dir().join(format!(
            "about_paint_init_test_{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&tmp);
        fs::create_dir_all(&tmp).unwrap();

        let opts = ProjectInitOptions::dual_engine_default("StarlightTest", "Creator");
        let prj = init_cpff_project(&tmp, &opts).expect("bootstrap must succeed");
        assert!(prj.is_file());

        let project_dir = tmp.join("StarlightTest");
        let resolved = resolve_prj_file(&project_dir).expect("resolve exact .prj");
        assert_eq!(resolved.path(), prj.as_path());

        let xml = fs::read_to_string(&prj).unwrap();
        let manifest = CreativeProjectManifest::parse_prj_xml(&xml).expect("parse generated .prj");
        assert_eq!(manifest.creative_engines, CreativeEngineMode::DualNovelManga);
        assert_eq!(manifest.editions.len(), 3);
        assert_eq!(manifest.chapters.len(), 1);

        let s4 = run_tri_app_compatibility_check(&project_dir)
            .expect("S4 compatibility gate must pass on newly initialized project");
        assert!(s4.write_isolation_verified);
        assert!(s4.ai_redline_verified);
        assert!(s4.deep_link_handoff_verified);

        let _ = fs::remove_dir_all(&tmp);
    }
}
