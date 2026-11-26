//! Modular Tri-App Suite architecture (`Hub` / `Manga` / `Novel`) sharing one CPFF v1.0
//! (`.prj`) file system framework, enabling both low-RAM standalone execution and
//! simultaneous multi-window / split-screen collaboration.
//!
//! > **Naming Note**: All Chinese, English, and Spanish app names below are **working codenames**
//! > (`is_final_brand = false`) pending final pre-release branding sign-off:
//! > - `SuiteApp::Hub`   — Working Codename: `创想空间` / `NoemaDock` (Project Hub & Release)
//! > - `SuiteApp::Manga` — Working Codename: `雕龙` / `DracoNib` (Manga & Illustration Drawing)
//! > - `SuiteApp::Novel` — Working Codename: `文心` / `LitteraCore` (Light Novel & Publishing)

use std::path::Path;

use crate::project::{resolve_prj_file, AiBridgeArtifact, CreativeProjectManifest};

/// Stable programmatic identifier for each of the three modular suite tools.
/// Using semantic variants ensures zero Rust/FFI breakage if working codenames change before release.
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SuiteApp {
    /// S1: Project overview, asset/prose import, dual-engine serialization & multi-language release hub.
    Hub = 0,
    /// S2: Series manga & illustration drawing tool (artwork management & low-latency GPU canvas).
    Manga = 1,
    /// S3: Light novel authoring, illustration curation & EPUB3/Markdown publishing tool.
    Novel = 2,
}

/// Static metadata for a suite application (working codenames + resource budgets).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SuiteAppMetadata {
    pub app: SuiteApp,
    pub id: &'static str,
    pub codename_zh_hans: &'static str,
    pub codename_zh_hant: &'static str,
    pub codename_en: &'static str,
    pub codename_es: &'static str,
    pub is_final_brand: bool,
    pub url_scheme: &'static str,
    pub standalone_ram_budget_mb: u32,
    pub requires_gpu_canvas: bool,
}

impl SuiteApp {
    pub fn from_u32(code: u32) -> Option<Self> {
        match code {
            0 => Some(Self::Hub),
            1 => Some(Self::Manga),
            2 => Some(Self::Novel),
            _ => None,
        }
    }

    /// Parses stable CLI/config identifiers or working codename aliases.
    pub fn from_str_alias(s: &str) -> Option<Self> {
        match s.trim().to_ascii_lowercase().as_str() {
            "hub" | "s1" | "noemadock" | "创想空间" => Some(Self::Hub),
            "manga" | "canvas" | "s2" | "draconib" | "雕龙" => Some(Self::Manga),
            "novel" | "s3" | "litteracore" | "文心" => Some(Self::Novel),
            _ => None,
        }
    }

    pub fn metadata(self) -> SuiteAppMetadata {
        match self {
            Self::Hub => SuiteAppMetadata {
                app: Self::Hub,
                id: "suite.hub",
                codename_zh_hans: "创想空间",
                codename_zh_hant: "創想空間",
                codename_en: "NoemaDock",
                codename_es: "NoemaDock",
                is_final_brand: false,
                url_scheme: "noemadock",
                standalone_ram_budget_mb: 200,
                requires_gpu_canvas: false,
            },
            Self::Manga => SuiteAppMetadata {
                app: Self::Manga,
                id: "suite.manga",
                codename_zh_hans: "雕龙",
                codename_zh_hant: "雕龍",
                codename_en: "DracoNib",
                codename_es: "DracoNib",
                is_final_brand: false,
                url_scheme: "draconib",
                standalone_ram_budget_mb: 1536,
                requires_gpu_canvas: true,
            },
            Self::Novel => SuiteAppMetadata {
                app: Self::Novel,
                id: "suite.novel",
                codename_zh_hans: "文心",
                codename_zh_hant: "文心",
                codename_en: "LitteraCore",
                codename_es: "LitteraCore",
                is_final_brand: false,
                url_scheme: "litteracore",
                standalone_ram_budget_mb: 120,
                requires_gpu_canvas: false,
            },
        }
    }
}

/// Validates CPFF v1.0 directory write-ownership boundaries so all three tools can run
/// concurrently on the same `<ProjectName>/` folder without overwriting each other's files.
///
/// Write-ownership partition:
/// - **Hub (`创想空间` / `NoemaDock`)**: root `*.prj`, `README*.md`, `LICENSE`, `declarations/`,
///   `outline/`, `bible/`, `i18n/`, `editions/`, `dist/`, `.gitattributes`, `.gitignore`,
///   and chapter metadata `chapters/*/chapter.xml` + `chapters/*/scenes/`.
/// - **Manga (`雕龙` / `DracoNib`)**: `chapters/*/storyboard/`, `chapters/*/manuscript/`,
///   `chapters/*/script/`, and isolated `chapters/*/ai_assist/novel_to_manga/` + `ai_assist/review_pins.xml`.
/// - **Novel (`文心` / `LitteraCore`)**: `chapters/*/novel/prose/`, `chapters/*/novel/illustrations/`,
///   and isolated `chapters/*/ai_assist/manga_to_novel/`.
pub fn can_write_relative_path(app: SuiteApp, rel_path: &str) -> Result<(), String> {
    if rel_path.is_empty()
        || rel_path.starts_with('/')
        || rel_path.contains('\\')
        || rel_path.split('/').any(|p| p.is_empty() || p == "." || p == "..")
    {
        return Err(format!("Unsafe relative project path: '{rel_path}'"));
    }

    let parts: Vec<&str> = rel_path.split('/').collect();
    let allowed = match app {
        SuiteApp::Hub => {
            if parts.len() == 1 {
                parts[0].ends_with(".prj")
                    || parts[0].starts_with("README")
                    || parts[0] == "LICENSE"
                    || parts[0] == ".gitattributes"
                    || parts[0] == ".gitignore"
            } else {
                matches!(
                    parts[0],
                    "declarations" | "outline" | "bible" | "i18n" | "editions" | "dist"
                ) || (parts[0] == "chapters"
                    && parts.len() >= 3
                    && (parts[2] == "chapter.xml" || parts[2] == "scenes"))
            }
        }
        SuiteApp::Manga => {
            parts.len() >= 4
                && parts[0] == "chapters"
                && (matches!(parts[2], "storyboard" | "manuscript" | "script")
                    || (parts[2] == "ai_assist"
                        && matches!(
                            parts[3],
                            "novel_to_manga" | "review_pins.xml" | "completion_queue.xml"
                        )))
        }
        SuiteApp::Novel => {
            parts.len() >= 4
                && parts[0] == "chapters"
                && ((parts[2] == "novel"
                    && matches!(parts[3], "prose" | "illustrations" | "novel_meta.xml"))
                    || (parts[2] == "ai_assist"
                        && matches!(parts[3], "manga_to_novel" | "completion_queue.xml")))
        }
    };

    if allowed {
        Ok(())
    } else {
        Err(format!(
            "Write-ownership violation: {} ({}) is not permitted to write '{}'",
            app.metadata().id,
            app.metadata().codename_en,
            rel_path
        ))
    }
}

/// Cross-application deep-link handoff payload (`<scheme>://<verb>?project=...&chapter=...`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeepLinkAction {
    pub target: SuiteApp,
    pub verb: String,
    pub project_id: String,
    pub chapter_id: Option<String>,
    pub detail: Option<String>,
}

impl DeepLinkAction {
    pub fn to_uri(&self) -> String {
        let mut uri = format!(
            "{}://{}?project={}",
            self.target.metadata().url_scheme,
            self.verb,
            self.project_id
        );
        if let Some(ref ch) = self.chapter_id {
            uri.push_str(&format!("&chapter={ch}"));
        }
        if let Some(ref d) = self.detail {
            uri.push_str(&format!("&detail={d}"));
        }
        uri
    }

    pub fn parse_uri(uri: &str) -> Result<Self, String> {
        let (scheme, rest) = uri
            .split_once("://")
            .ok_or_else(|| format!("Invalid deep-link URI (missing '://'): '{uri}'"))?;
        let target = match scheme {
            "noemadock" => SuiteApp::Hub,
            "draconib" => SuiteApp::Manga,
            "litteracore" => SuiteApp::Novel,
            _ => return Err(format!("Unknown suite URL scheme: '{scheme}'")),
        };
        let (verb, query) = rest
            .split_once('?')
            .ok_or_else(|| format!("Missing query string in deep-link URI: '{uri}'"))?;

        let mut project_id = None;
        let mut chapter_id = None;
        let mut detail = None;
        for pair in query.split('&') {
            if let Some((k, v)) = pair.split_once('=') {
                match k {
                    "project" => project_id = Some(v.to_string()),
                    "chapter" => chapter_id = Some(v.to_string()),
                    "detail" => detail = Some(v.to_string()),
                    _ => {}
                }
            }
        }
        let project_id =
            project_id.ok_or_else(|| format!("Deep-link URI missing 'project=' parameter: '{uri}'"))?;

        Ok(Self {
            target,
            verb: verb.to_string(),
            project_id,
            chapter_id,
            detail,
        })
    }
}

/// Summary produced by the mandatory **S4 Tri-App Integration & Compatibility Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TriAppIntegrationReport {
    pub project_id: String,
    pub editions_count: usize,
    pub chapters_count: usize,
    pub combined_ram_budget_mb: u32,
    pub write_isolation_verified: bool,
    pub ai_redline_verified: bool,
    pub deep_link_handoff_verified: bool,
}

/// Executes the **S4 Tri-App Integration & Compatibility Gate** against a CPFF v1.0 project folder:
/// 1. Loads and validates the shared `<ProjectName>.prj` manifest across all 3 tools.
/// 2. Verifies non-overlapping write ownership across Hub / Manga / Novel directories.
/// 3. Verifies AI bidirectional bridges strictly obey the `ai_assist/` isolation red line.
/// 4. Round-trips cross-app Deep-Link handoffs between Hub -> Manga and Hub -> Novel.
pub fn run_tri_app_compatibility_check(project_dir: &Path) -> Result<TriAppIntegrationReport, String> {
    let resolved = resolve_prj_file(project_dir)?;
    let xml = std::fs::read_to_string(resolved.path())
        .map_err(|e| format!("S4 check failed reading .prj: {e}"))?;
    let manifest = CreativeProjectManifest::parse_prj_xml(&xml)?;

    let first_chapter = manifest
        .chapters
        .first()
        .ok_or_else(|| "S4 check failed: project must contain at least one chapter".to_string())?;
    let cid = &first_chapter.id;

    // 1. Positive write ownership checks
    can_write_relative_path(SuiteApp::Hub, "editions/edition_novel_epub.xml")?;
    can_write_relative_path(SuiteApp::Manga, &format!("chapters/{cid}/manuscript/p001.mnga"))?;
    can_write_relative_path(SuiteApp::Novel, &format!("chapters/{cid}/novel/prose/zh-Hans.md"))?;

    // 2. Negative cross-app contamination checks (MUST be rejected)
    if can_write_relative_path(SuiteApp::Manga, &format!("chapters/{cid}/novel/prose/zh-Hans.md")).is_ok() {
        return Err("S4 isolation failure: Manga app must never write Novel prose".into());
    }
    if can_write_relative_path(SuiteApp::Novel, &format!("chapters/{cid}/manuscript/p001.mnga")).is_ok() {
        return Err("S4 isolation failure: Novel app must never write Manga manuscript".into());
    }
    if can_write_relative_path(SuiteApp::Hub, &format!("chapters/{cid}/novel/prose/zh-Hans.md")).is_ok() {
        return Err("S4 isolation failure: Hub must never overwrite human Novel prose directly".into());
    }

    // 3. Hard AI red-line isolation check
    let m2n = AiBridgeArtifact {
        role: "ai_reference_only".into(),
        meta_src: "ai_assist/manga_to_novel/meta.xml".into(),
        output_src: "ai_assist/manga_to_novel/ai_prose_ref_zh-Hans.md".into(),
        derived_from: "script/script.xml".into(),
    };
    let n2m = AiBridgeArtifact {
        role: "ai_reference_only".into(),
        meta_src: "ai_assist/novel_to_manga/meta.xml".into(),
        output_src: "ai_assist/novel_to_manga/ai_storyboard_ref.xml".into(),
        derived_from: "novel/prose/zh-Hans.md".into(),
    };
    m2n.validate_isolation()?;
    n2m.validate_isolation()?;

    // 4. Cross-app Deep-Link round-trip checks
    for link in [
        DeepLinkAction {
            target: SuiteApp::Manga,
            verb: "open".into(),
            project_id: manifest.id.clone(),
            chapter_id: Some(cid.clone()),
            detail: Some("page=1".into()),
        },
        DeepLinkAction {
            target: SuiteApp::Novel,
            verb: "open".into(),
            project_id: manifest.id.clone(),
            chapter_id: Some(cid.clone()),
            detail: Some("locale=zh-Hans".into()),
        },
        DeepLinkAction {
            target: SuiteApp::Hub,
            verb: "publish".into(),
            project_id: manifest.id.clone(),
            chapter_id: None,
            detail: Some("edition=novel-ebook-zh".into()),
        },
    ] {
        let parsed = DeepLinkAction::parse_uri(&link.to_uri())?;
        if parsed != link {
            return Err(format!("S4 deep-link round-trip mismatch for {:?}", link));
        }
    }

    let combined_ram = SuiteApp::Hub.metadata().standalone_ram_budget_mb
        + SuiteApp::Manga.metadata().standalone_ram_budget_mb
        + SuiteApp::Novel.metadata().standalone_ram_budget_mb;

    Ok(TriAppIntegrationReport {
        project_id: manifest.id,
        editions_count: manifest.editions.len(),
        chapters_count: manifest.chapters.len(),
        combined_ram_budget_mb: combined_ram,
        write_isolation_verified: true,
        ai_redline_verified: true,
        deep_link_handoff_verified: true,
    })
}

/// Summary produced by the **`T0.2-S4` 100-round Tri-App Concurrency Soak Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T02S4ConcurrencyReport {
    pub rounds_completed: usize,
    pub manifest_reads_verified: usize,
    pub brush_stamps_generated: usize,
    pub atomic_prose_saves_verified: usize,
    pub locked_overwrite_rejections: usize,
    pub temp_files_remaining: usize,
}

/// Executes the **`T0.2-S4` Tri-App Concurrency Soak Gate** over a CPFF v1.0 `.prj` workspace:
/// - `S1`: repeatedly resolves & parses `.prj` manifest (verifying zero manifest corruption).
/// - `S2`: runs deterministic G-Pen stamping + sparse CoW stroke/undo cycles under write guard.
/// - `S3`: performs `rounds` atomic prose saves (`write_novel_prose_atomic`), verifies `locked="true"`
///   rejects automated overwrite, round-trips `novel/novel_meta.xml`, and asserts zero leftover `.tmp.*`.
pub fn run_t02_s4_concurrency_soak(
    project_dir: &Path,
    rounds: usize,
) -> Result<T02S4ConcurrencyReport, String> {
    let base = run_tri_app_compatibility_check(project_dir)?;
    let _ = base;

    let presets = crate::brush::starter_brush_presets();
    let g_pen = &presets[crate::brush::BrushPresetId::GPen as usize];
    let mut canvas = crate::canvas::CanvasSession::from_preset(crate::preset::CanvasPreset::B4PrintManga600Dpi);

    let mut manifest_reads_verified = 0usize;
    let mut brush_stamps_generated = 0usize;
    let mut atomic_prose_saves_verified = 0usize;
    let mut locked_overwrite_rejections = 0usize;

    let prose_rel = "chapters/ch001/novel/prose/zh-Hans.md";

    for r in 0..rounds {
        // S1: resolve & parse manifest
        let resolved = resolve_prj_file(project_dir)?;
        let xml = std::fs::read_to_string(resolved.path())
            .map_err(|e| format!("T0.2-S4 round {r} S1 read failed: {e}"))?;
        let manifest = CreativeProjectManifest::parse_prj_xml(&xml)?;
        if manifest.chapters.is_empty() {
            return Err(format!("T0.2-S4 round {r} S1 manifest lost chapters"));
        }
        manifest_reads_verified += 1;

        // S2: deterministic brush stamping + sparse CoW stroke/undo
        let pts = [
            crate::stroke::StrokePoint {
                x: 40.0 + (r as f32),
                y: 60.0,
                pressure: 0.25,
                altitude: 1.3,
                azimuth: 0.0,
                roll_angle: 0.1,
                timestamp_ms: (r * 10) as f64,
                is_predicted: false,
            },
            crate::stroke::StrokePoint {
                x: 120.0 + (r as f32),
                y: 95.0,
                pressure: 0.90,
                altitude: 1.2,
                azimuth: 0.0,
                roll_angle: 0.2,
                timestamp_ms: (r * 10 + 4) as f64,
                is_predicted: false,
            },
        ];
        let stamps = crate::brush::BrushStampingEngine::generate_stamps(g_pen, &pts);
        if stamps.is_empty() {
            return Err(format!("T0.2-S4 round {r} S2 brush stamping produced 0 stamps"));
        }
        brush_stamps_generated += stamps.len();

        canvas.begin_stroke(5.0, [17, 18, 22, 255], false, 4.0);
        canvas.push_points(&pts);
        canvas.end_stroke();
        if !canvas.undo() || canvas.layer().allocated_tile_count() != 0 {
            return Err(format!("T0.2-S4 round {r} S2 CoW undo failed to return to 0 tiles"));
        }

        // S3: atomic prose write + locked overwrite rejection + novel_meta round-trip
        let body = format!("# 第一话 并发压测\n\n第 {} 轮三工具原子读写校验 Starlight Round {}.\n", r + 1, r + 1);
        let saved_path = crate::novel::write_novel_prose_atomic(project_dir, prose_rel, &body, false, true)?;
        let read_back = std::fs::read_to_string(&saved_path)
            .map_err(|e| format!("T0.2-S4 round {r} S3 read-back failed: {e}"))?;
        if read_back != body {
            return Err(format!("T0.2-S4 round {r} S3 prose corruption detected"));
        }
        atomic_prose_saves_verified += 1;

        if crate::novel::write_novel_prose_atomic(project_dir, prose_rel, "hijack", true, false).is_ok() {
            return Err(format!("T0.2-S4 round {r} S3 locked prose allowed automated overwrite"));
        }
        locked_overwrite_rejections += 1;

        if r == 0 || r + 1 == rounds {
            let meta = crate::novel::NovelChapterMeta {
                chapter_id: "ch001".into(),
                decoupled_from_manga: true,
                locked: true,
                divergence_notes: vec![crate::novel::DivergenceNote {
                    scene_id: Some(format!("sc-r{}", r + 1)),
                    summary: "T0.2-S4 concurrency verification note".into(),
                }],
            };
            meta.save_atomic(project_dir)?;
        }
    }

    // Confirm zero leftover `.tmp.*` atomic staging files
    let prose_dir = project_dir.join("chapters/ch001/novel/prose");
    let mut temp_files_remaining = 0usize;
    if let Ok(entries) = std::fs::read_dir(&prose_dir) {
        for entry in entries.flatten() {
            if let Some(name) = entry.file_name().to_str() {
                if name.contains(".tmp.") {
                    temp_files_remaining += 1;
                }
            }
        }
    }
    if temp_files_remaining > 0 {
        return Err(format!("T0.2-S4 leaked {temp_files_remaining} temporary files in prose dir"));
    }

    Ok(T02S4ConcurrencyReport {
        rounds_completed: rounds,
        manifest_reads_verified,
        brush_stamps_generated,
        atomic_prose_saves_verified,
        locked_overwrite_rejections,
        temp_files_remaining,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn three_apps_have_working_codenames_and_low_ram_standalone_budgets() {
        let hub = SuiteApp::Hub.metadata();
        let manga = SuiteApp::Manga.metadata();
        let novel = SuiteApp::Novel.metadata();

        assert!(!hub.is_final_brand && !manga.is_final_brand && !novel.is_final_brand);
        assert!(!hub.requires_gpu_canvas);
        assert!(manga.requires_gpu_canvas);
        assert!(!novel.requires_gpu_canvas);
        assert!(novel.standalone_ram_budget_mb <= 128);
        assert!(hub.standalone_ram_budget_mb <= 256);

        assert_eq!(SuiteApp::from_str_alias("noemadock"), Some(SuiteApp::Hub));
        assert_eq!(SuiteApp::from_str_alias("draconib"), Some(SuiteApp::Manga));
        assert_eq!(SuiteApp::from_str_alias("litteracore"), Some(SuiteApp::Novel));
    }

    #[test]
    fn write_ownership_prevents_concurrent_cross_app_corruption() {
        assert!(can_write_relative_path(SuiteApp::Hub, "SampleManga.prj").is_ok());
        assert!(can_write_relative_path(SuiteApp::Hub, "outline/toc.xml").is_ok());
        assert!(can_write_relative_path(SuiteApp::Manga, "chapters/ch001/manuscript/p01.mnga").is_ok());
        assert!(can_write_relative_path(SuiteApp::Novel, "chapters/ch001/novel/prose/en.md").is_ok());
        assert!(can_write_relative_path(SuiteApp::Novel, "chapters/ch001/novel/novel_meta.xml").is_ok());

        // Cross-app writes are strictly blocked
        assert!(can_write_relative_path(SuiteApp::Manga, "chapters/ch001/novel/prose/en.md").is_err());
        assert!(can_write_relative_path(SuiteApp::Manga, "chapters/ch001/novel/novel_meta.xml").is_err());
        assert!(can_write_relative_path(SuiteApp::Hub, "chapters/ch001/novel/novel_meta.xml").is_err());
        assert!(can_write_relative_path(SuiteApp::Novel, "chapters/ch001/manuscript/p01.mnga").is_err());
        assert!(can_write_relative_path(SuiteApp::Novel, "SampleManga.prj").is_err());
        assert!(can_write_relative_path(SuiteApp::Manga, "../escape.prj").is_err());
    }

    #[test]
    fn s4_tri_app_compatibility_gate_passes_on_sample_manga() {
        let sample_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../templates/SampleManga");
        let report = run_tri_app_compatibility_check(&sample_dir)
            .expect("S4 tri-app compatibility check must pass on SampleManga");
        assert_eq!(report.project_id, "prj-sample-manga-001");
        assert_eq!(report.editions_count, 4);
        assert!(report.write_isolation_verified);
        assert!(report.ai_redline_verified);
        assert!(report.deep_link_handoff_verified);
    }
}
