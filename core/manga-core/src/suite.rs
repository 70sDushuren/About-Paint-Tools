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

/// Summary produced by the **`T0.3-S4` Story Bible Hot-Reload (`< 300ms`) & 13-Mode Cel Layer Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T03S4GateReport {
    pub bible_characters_verified: usize,
    pub toc_entries_verified: usize,
    pub hot_reload_latency_ms: u64,
    pub cel_blend_modes_verified: usize,
    pub clipping_mask_verified: bool,
    pub alpha_lock_verified: bool,
    pub blue_sketch_tint_verified: bool,
    pub write_isolation_verified: bool,
    pub temp_files_remaining: usize,
}

/// Executes the **`T0.3-S4` Integration & Compatibility Gate** over a CPFF v1.0 `.prj` workspace:
/// - `S1`: Atomically writes 3 Story Bible characters (`bible/characters.xml`) and 3 TOC entries
///   (`outline/toc.xml`), confirming monotonic revision hash changes and zero leaked `.tmp.*`.
/// - `S2`: Exercises all **13 anime cel-shading blend modes**, `R` reference layer query,
///   `✂` clipping mask alpha restriction, `🔒` alpha lock preservation, and `B` non-destructive
///   blue sketch tinting inside `LayerStack::composite_pixel`.
/// - `S3`: Measures live cross-app hot-reload (`story_bible_revision_hash` + RO reload of Story Bible
///   & TOC) strictly under the `< 300ms` SLA, and asserts `S2`/`S3` write attempts to `bible/` and
///   `outline/` are blocked.
pub fn run_t03_s4_bible_layers_gate(project_dir: &Path) -> Result<T03S4GateReport, String> {
    let _ = run_tri_app_compatibility_check(project_dir)?;

    // 1. S1 atomic Story Bible + TOC persistence
    let rev_start = crate::bible::story_bible_revision_hash(project_dir);
    let mut bible = crate::bible::StoryBible::load_from_project(project_dir)?;
    for (id, zh, en, role, hex) in [
        ("char-lin", "林晓", "Lin Xiao", "protagonist", "#4F7CFF"),
        ("char-ren", "墨凛", "Mo Lin", "rival", "#FF6B4A"),
        ("char-sora", "苍月", "Sora Tsuki", "mentor", "#2FA88B"),
    ] {
        bible.upsert_character(crate::bible::BibleCharacter {
            id: id.into(),
            name_zh: zh.into(),
            name_en: en.into(),
            role: role.into(),
            palette_hex: hex.into(),
            visual_anchors: vec![format!("{en} signature silhouette")],
        });
    }
    bible.save_atomic(project_dir)?;
    let rev_after_bible = crate::bible::story_bible_revision_hash(project_dir);
    if rev_after_bible == rev_start {
        return Err("T0.3-S4 S1 revision hash did not change after StoryBible atomic save".into());
    }

    let mut toc = crate::bible::ProjectToc::load_from_project(project_dir)?;
    for (cid, num, zh, en, status) in [
        ("ch001", 1, "星辉觉醒", "Starlight Awakening", "in_progress"),
        ("ch002", 2, "墨影回廊", "Ink Shadow Corridor", "draft"),
        ("ch003", 3, "双生分镜", "Twin Storyboards", "planned"),
    ] {
        toc.upsert_entry(crate::bible::TocChapterEntry {
            chapter_id: cid.into(),
            number: num,
            title_zh: zh.into(),
            title_en: en.into(),
            status: status.into(),
        });
    }
    toc.save_atomic(project_dir)?;
    let rev_after_toc = crate::bible::story_bible_revision_hash(project_dir);
    if rev_after_toc == rev_after_bible {
        return Err("T0.3-S4 S1 revision hash did not change after ProjectToc atomic save".into());
    }

    // 2. S3 read-only hot-reload SLA (< 300ms) + write-ownership isolation check
    let t0 = std::time::Instant::now();
    let observed_rev = crate::bible::story_bible_revision_hash(project_dir);
    let reloaded_bible = crate::bible::StoryBible::load_from_project(project_dir)?;
    let reloaded_toc = crate::bible::ProjectToc::load_from_project(project_dir)?;
    let hot_reload_latency_ms = t0.elapsed().as_millis() as u64;

    if observed_rev != rev_after_toc {
        return Err("T0.3-S4 S3 observed inconsistent revision hash".into());
    }
    if reloaded_bible.characters.len() < 3 || reloaded_toc.entries.len() < 3 {
        return Err("T0.3-S4 S3 reloaded incomplete StoryBible or ProjectToc".into());
    }
    if hot_reload_latency_ms >= 300 {
        return Err(format!(
            "T0.3-S4 S3 hot-reload exceeded 300ms SLA ({hot_reload_latency_ms}ms)"
        ));
    }

    if can_write_relative_path(SuiteApp::Manga, crate::bible::STORY_BIBLE_REL_PATH).is_ok()
        || can_write_relative_path(SuiteApp::Novel, crate::bible::STORY_BIBLE_REL_PATH).is_ok()
        || can_write_relative_path(SuiteApp::Novel, crate::bible::PROJECT_TOC_REL_PATH).is_ok()
    {
        return Err("T0.3-S4 write isolation failed: S2/S3 must never write bible/ or outline/".into());
    }

    // 3. S2 13 cel blend modes + R / Clip / AlphaLock / BlueSketch live compositing gate
    let all_modes = [
        crate::layer::BlendMode::Normal,
        crate::layer::BlendMode::Multiply,
        crate::layer::BlendMode::Screen,
        crate::layer::BlendMode::Overlay,
        crate::layer::BlendMode::GlowDodge,
        crate::layer::BlendMode::LinearBurn,
        crate::layer::BlendMode::HardLight,
        crate::layer::BlendMode::SoftLight,
        crate::layer::BlendMode::Darken,
        crate::layer::BlendMode::Lighten,
        crate::layer::BlendMode::ColorBurn,
        crate::layer::BlendMode::ColorDodge,
        crate::layer::BlendMode::Add,
    ];
    for mode in all_modes {
        let blended = crate::layer::blend_rgba([180, 140, 120, 255], [90, 110, 200, 200], mode);
        if blended[3] == 0 {
            return Err(format!("T0.3-S4 S2 blend mode {:?} produced zero alpha", mode));
        }
    }

    let mut stack = crate::layer::LayerStack::new(64, 64);
    let sketch_id = stack.add_raster_layer("Sketch_Rough");
    let base_id = stack.add_raster_layer("Base_Flat");
    let shadow_id = stack.add_raster_layer("Cel_Shadow");
    let ink_id = stack.add_raster_layer("Ink_Lineart");

    // Blue sketch tint (B)
    {
        let sketch = stack.get_mut(sketch_id).unwrap();
        sketch.tint_rgba = Some([77, 166, 255, 255]);
        sketch.write_pixel(4, 4, [20, 20, 20, 255]);
    }
    let tinted = stack.get(sketch_id).unwrap().sample_display_pixel(4, 4);
    let blue_sketch_tint_verified = tinted[2] > tinted[0] && tinted[2] >= 200;
    if !blue_sketch_tint_verified {
        return Err("T0.3-S4 S2 blue sketch tint failed to recolor dark sketch stroke".into());
    }

    // Base flat + Alpha Lock (🔒)
    {
        let base = stack.get_mut(base_id).unwrap();
        base.write_pixel(10, 10, [220, 180, 160, 255]);
        base.alpha_lock = true;
        // Must reject writing transparent pixel (11,11) and allow recoloring opaque (10,10)
        if base.write_pixel(11, 11, [255, 0, 0, 255]) {
            return Err("T0.3-S4 S2 alpha lock failed to block transparent pixel write".into());
        }
        if !base.write_pixel(10, 10, [200, 160, 140, 128]) {
            return Err("T0.3-S4 S2 alpha lock failed to update existing opaque pixel".into());
        }
    }
    let alpha_lock_verified = stack.get(base_id).unwrap().sample_display_pixel(10, 10)[3] == 255;
    if !alpha_lock_verified {
        return Err("T0.3-S4 S2 alpha lock did not preserve existing alpha channel".into());
    }

    // Clipped Multiply Shadow (✂)
    {
        let shadow = stack.get_mut(shadow_id).unwrap();
        shadow.blend_mode = crate::layer::BlendMode::Multiply;
        shadow.clipping_mask = true;
        shadow.opacity = 0.75;
        shadow.write_pixel(10, 10, [100, 100, 160, 255]);
        shadow.write_pixel(20, 20, [100, 100, 160, 255]); // outside base alpha -> must clip out!
    }
    let clipped_inside = stack.composite_pixel(10, 10);
    let clipped_outside = stack.composite_pixel(20, 20);
    let clipping_mask_verified = clipped_inside[0] < 200 && clipped_outside[3] == 0;
    if !clipping_mask_verified {
        return Err("T0.3-S4 S2 clipping mask failed to clip outside base alpha".into());
    }

    // Reference Layer (R)
    {
        let ink = stack.get_mut(ink_id).unwrap();
        ink.is_reference = true;
    }
    if stack.reference_layer_ids() != vec![ink_id] {
        return Err("T0.3-S4 S2 reference layer query mismatch".into());
    }

    // Confirm zero leaked `.tmp.*` in bible/ and outline/
    let mut temp_files_remaining = 0usize;
    for sub in ["bible", "outline"] {
        if let Ok(entries) = std::fs::read_dir(project_dir.join(sub)) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.contains(".tmp.") {
                        temp_files_remaining += 1;
                    }
                }
            }
        }
    }
    if temp_files_remaining > 0 {
        return Err(format!(
            "T0.3-S4 leaked {temp_files_remaining} temp files in bible/ or outline/"
        ));
    }

    Ok(T03S4GateReport {
        bible_characters_verified: reloaded_bible.characters.len(),
        toc_entries_verified: reloaded_toc.entries.len(),
        hot_reload_latency_ms,
        cel_blend_modes_verified: all_modes.len(),
        clipping_mask_verified,
        alpha_lock_verified,
        blue_sketch_tint_verified,
        write_isolation_verified: true,
        temp_files_remaining,
    })
}

/// Summary produced by the **`T0.4-S4` Asset Ingest + Close-Gap Anti-Halo Fill + `<DivergenceNote>` Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T04S4GateReport {
    pub ingest_collision_renamed: bool,
    pub ingest_prose_isolated: bool,
    pub close_gap_filled_pixels: usize,
    pub close_gap_zero_leak: bool,
    pub anti_halo_expanded: bool,
    pub lasso_selected_pixels: usize,
    pub divergence_notes_verified: usize,
}

/// Executes the **`T0.4-S4` Integration & Compatibility Gate** over a CPFF v1.0 `.prj` workspace:
/// - `S1`: Normalizes reference art + auto-versions duplicate names without clobbering, and stages
///   imported prose strictly inside `ai_assist/ingest_staging/` (never overwriting human finals).
/// - `S2`: Executes Close-Gap (`3px`) + Edge-Expand (`1px`) anti-halo flood fill on a reference lineart
///   box with a 3px break (verifying zero leak & anti-halo tucking), plus Lasso polygon selection.
/// - `S3`: Atomically persists and reloads `<DivergenceNote>` metadata in `chapters/ch001/novel/novel_meta.xml`
///   strictly under `SuiteApp::Novel`.
pub fn run_t04_s4_ingest_fill_divergence_gate(project_dir: &Path) -> Result<T04S4GateReport, String> {
    let _ = run_tri_app_compatibility_check(project_dir)?;

    // 1. S1 Ingest normalization + collision auto-versioning + AI/human prose isolation
    let r1 = crate::ingest::ingest_bytes_atomic(
        project_dir,
        "ch001",
        crate::ingest::IngestAssetKind::ReferenceArt,
        "Lead Sheet (Color).png",
        b"PNG_REF_V1",
    )?;
    let r2 = crate::ingest::ingest_bytes_atomic(
        project_dir,
        "ch001",
        crate::ingest::IngestAssetKind::ReferenceArt,
        "Lead Sheet (Color).png",
        b"PNG_REF_V2",
    )?;
    if !r2.conflict_renamed || r1.destination_rel_path == r2.destination_rel_path {
        return Err("T0.4-S4 S1 ingest failed to auto-version duplicate asset".into());
    }
    let r_prose = crate::ingest::ingest_bytes_atomic(
        project_dir,
        "ch001",
        crate::ingest::IngestAssetKind::ProseStagingDraft,
        "external_chapter1.md",
        b"# Imported external draft",
    )?;
    let ingest_prose_isolated = r_prose
        .destination_rel_path
        .starts_with("chapters/ch001/ai_assist/ingest_staging/");
    if !ingest_prose_isolated {
        return Err("T0.4-S4 S1 prose ingest escaped ai_assist/ingest_staging/".into());
    }

    // 2. S2 Close-Gap 3px anti-halo flood fill + Lasso selection
    let mut stack = crate::layer::LayerStack::new(80, 80);
    let flat_id = stack.add_raster_layer("Flat_Color");
    let ink_id = stack.add_raster_layer("Ink_Ref");
    {
        let ink = stack.get_mut(ink_id).unwrap();
        ink.is_reference = true;
        for x in 10..=50 {
            if !(28..=30).contains(&x) {
                ink.write_pixel(x, 10, [0, 0, 0, 255]);
            }
            ink.write_pixel(x, 50, [0, 0, 0, 255]);
        }
        for y in 10..=50 {
            ink.write_pixel(10, y, [0, 0, 0, 255]);
            ink.write_pixel(50, y, [0, 0, 0, 255]);
        }
    }
    let fill_res = crate::fill::close_gap_expand_fill(
        &mut stack,
        flat_id,
        30,
        30,
        [255, 107, 74, 255],
        crate::fill::FillOptions {
            tolerance: 24,
            close_gap_px: 3,
            expand_px: 1,
            reference_alpha_threshold: 64,
        },
    );
    let flat_layer = stack.get(flat_id).unwrap().raster.as_ref().unwrap();
    let close_gap_zero_leak = flat_layer.get_pixel(2, 2) == [0, 0, 0, 0];
    let anti_halo_expanded = flat_layer.get_pixel(10, 30) == [255, 107, 74, 255];
    if !close_gap_zero_leak || !anti_halo_expanded || fill_res.filled_pixels < 1000 {
        return Err("T0.4-S4 S2 close-gap anti-halo fill gate failed".into());
    }

    let poly = [(10.0, 10.0), (40.0, 10.0), (40.0, 40.0), (10.0, 40.0)];
    let mut sel = crate::selection::SelectionMask::from_lasso_polygon(80, 80, &poly);
    sel.adjust_border(1);
    let lasso_selected_pixels = sel.selected_pixel_count();
    if lasso_selected_pixels != 32 * 32 {
        return Err(format!(
            "T0.4-S4 S2 lasso expanded pixel count mismatch: {lasso_selected_pixels}"
        ));
    }

    // 3. S3 <DivergenceNote> round-trip under SuiteApp::Novel
    let mut meta = crate::novel::NovelChapterMeta::load_from_project(project_dir, "ch001")?;
    meta.locked = true;
    meta.divergence_notes.push(crate::novel::DivergenceNote {
        scene_id: Some("sc002".into()),
        summary: "Novel expands rooftop dialogue while manga uses silent 3-panel beat.".into(),
    });
    meta.save_atomic(project_dir)?;
    let reloaded = crate::novel::NovelChapterMeta::load_from_project(project_dir, "ch001")?;
    if reloaded.divergence_notes.is_empty() {
        return Err("T0.4-S4 S3 DivergenceNote failed round-trip persistence".into());
    }

    Ok(T04S4GateReport {
        ingest_collision_renamed: r2.conflict_renamed,
        ingest_prose_isolated,
        close_gap_filled_pixels: fill_res.filled_pixels,
        close_gap_zero_leak,
        anti_halo_expanded,
        lasso_selected_pixels,
        divergence_notes_verified: reloaded.divergence_notes.len(),
    })
}

/// Summary produced by the **`T0.5-S4` Vector Lineart + Rulers + 5-Locale Glossary Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T05S4GateReport {
    pub glossary_5_locale_complete: usize,
    pub glossary_missing_cells: usize,
    pub vector_intersection_erased: bool,
    pub vector_4x_lossless_scaled: bool,
    pub rulers_verified: usize,
    pub novel_autocomplete_hits: usize,
}

/// Executes the **`T0.5-S4` Integration & Compatibility Gate** over a CPFF v1.0 `.prj` workspace:
/// - `S1`: Atomically writes 5-locale `bible/glossary.xml` strictly under `SuiteApp::Hub`,
///   audits 100% 5-locale completeness, and verifies `S2`/`S3` write attempts are blocked.
/// - `S2`: Verifies variable-width `VectorLayer` 4x lossless scaling, single-swipe Vector
///   Intersection Eraser trimming overshoot tails, and Symmetry + 2-Point Perspective + FocusLines rulers.
/// - `S3`: Verifies localized proper-noun autocomplete across `zh-Hans`, `en`, and `es`.
pub fn run_t05_s4_vector_ruler_glossary_gate(project_dir: &Path) -> Result<T05S4GateReport, String> {
    let _ = run_tri_app_compatibility_check(project_dir)?;

    // 1. S1 5-Locale Glossary atomic write + completeness audit + write-ownership isolation
    let mut glossary = crate::glossary::ProjectGlossary::load_from_project(project_dir)?;
    for (key, en, zh_s, zh_t, yue, es) in [
        ("weapon.starlight_blade", "Starlight Blade", "星辉之刃", "星輝之刃", "星輝之刃", "Hoja Estelar"),
        ("place.ink_corridor", "Ink Corridor", "墨影回廊", "墨影迴廊", "墨影迴廊", "Corredor de Tinta"),
        ("skill.cel_flash", "Cel Flash", "赛璐璐瞬斩", "賽璐璐瞬斬", "賽璐璐瞬斬", "Destello Cel"),
    ] {
        glossary.upsert_term(crate::glossary::GlossaryTerm {
            key: key.into(),
            en: en.into(),
            zh_hans: zh_s.into(),
            zh_hant: zh_t.into(),
            yue_hant: yue.into(),
            es: es.into(),
            locked: true,
        });
    }
    glossary.save_atomic(project_dir)?;
    if can_write_relative_path(SuiteApp::Novel, crate::glossary::PROJECT_GLOSSARY_REL_PATH).is_ok()
        || can_write_relative_path(SuiteApp::Manga, crate::glossary::PROJECT_GLOSSARY_REL_PATH).is_ok()
    {
        return Err("T0.5-S4 write isolation failed: only S1 Hub may write bible/glossary.xml".into());
    }
    let reloaded = crate::glossary::ProjectGlossary::load_from_project(project_dir)?;
    let audit = reloaded.audit_completeness();
    if audit.complete_5_locale_terms < 3 || audit.missing_cells != 0 {
        return Err("T0.5-S4 S1 5-locale glossary audit found incomplete entries".into());
    }

    // 2. S2 Vector Layer 4x lossless scaling + Vector Intersection Eraser + 3 Manga Rulers
    let mut vlayer = crate::vector::VectorLayer::new();
    let _horiz = vlayer.add_stroke(
        [0, 0, 0, 255],
        vec![
            crate::vector::VectorNode { x: 0.0, y: 50.0, width: 2.0 },
            crate::vector::VectorNode { x: 100.0, y: 50.0, width: 2.0 },
        ],
    );
    let _vert = vlayer.add_stroke(
        [0, 0, 0, 255],
        vec![
            crate::vector::VectorNode { x: 50.0, y: 0.0, width: 2.0 },
            crate::vector::VectorNode { x: 50.0, y: 100.0, width: 2.0 },
        ],
    );
    let vector_intersection_erased = vlayer.erase_to_intersection(80.0, 50.0, 6.0);
    if !vector_intersection_erased {
        return Err("T0.5-S4 S2 Vector Intersection Eraser failed to trim overshoot".into());
    }
    let mut scaled_ok = false;
    if let Some(stroke) = vlayer
        .strokes_mut()
        .iter_mut()
        .find(|s| s.nodes.first().map(|n| (n.y - 50.0).abs() < 1.0).unwrap_or(false))
    {
        let before_max_x = stroke.nodes.last().map(|n| n.x).unwrap_or(0.0);
        stroke.scale(4.0);
        let after_max_x = stroke.nodes.last().map(|n| n.x).unwrap_or(0.0);
        scaled_ok = (after_max_x - before_max_x * 4.0).abs() < 1e-2 && after_max_x <= 205.0;
    }
    if !scaled_ok {
        return Err("T0.5-S4 S2 Vector 4x lossless scale check failed".into());
    }

    let sym = crate::ruler::RulerKind::Symmetry {
        axis_x: 200.0,
        axis_y: 0.0,
        angle_rad: std::f32::consts::FRAC_PI_2,
    };
    let mirrored = sym
        .mirror_point(crate::stroke::StrokePoint::simple(140.0, 80.0, 0.9))
        .ok_or_else(|| "T0.5-S4 Symmetry mirror returned None".to_string())?;
    if (mirrored.x - 260.0).abs() > 1e-2 {
        return Err("T0.5-S4 Symmetry ruler mirror math mismatch".into());
    }
    let persp = crate::ruler::RulerKind::Perspective {
        vanishing_points: vec![(0.0, 500.0), (1000.0, 500.0)],
    };
    let p_snap = persp.snap_point(500.0, 0.0, crate::stroke::StrokePoint::simple(600.0, 90.0, 1.0));
    if ((p_snap.x - 500.0) - p_snap.y).abs() > 1e-2 {
        return Err("T0.5-S4 2-Point Perspective ruler snap mismatch".into());
    }
    let focus = crate::ruler::RulerKind::FocusLines {
        center_x: 500.0,
        center_y: 500.0,
    };
    let f_snap = focus.snap_point(800.0, 500.0, crate::stroke::StrokePoint::simple(700.0, 520.0, 1.0));
    if (f_snap.y - 500.0).abs() > 1e-2 {
        return Err("T0.5-S4 FocusLines ruler snap mismatch".into());
    }

    // 3. S3 5-locale proper-noun autocomplete
    let hits_zh = reloaded.suggest_terms("星辉", "zh-Hans").len();
    let hits_es = reloaded.suggest_terms("estelar", "es").len();
    let hits_en = reloaded.suggest_terms("corridor", "en").len();
    let novel_autocomplete_hits = hits_zh + hits_es + hits_en;
    if novel_autocomplete_hits < 3 {
        return Err("T0.5-S4 S3 localized glossary autocomplete returned fewer than 3 hits".into());
    }

    Ok(T05S4GateReport {
        glossary_5_locale_complete: audit.complete_5_locale_terms,
        glossary_missing_cells: audit.missing_cells,
        vector_intersection_erased,
        vector_4x_lossless_scaled: scaled_ok,
        rulers_verified: 3,
        novel_autocomplete_hits,
    })
}

/// Summary produced by the **`T0.6-S4` Dual-Track Panels/Screentones/Webtoon + 5-Locale Bubbles + EPUB3 Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T06S4GateReport {
    pub b4_manga_panels: usize,
    pub screentone_patterns_verified: usize,
    pub webtoon_slices_count: usize,
    pub webtoon_zero_seam_verified: bool,
    pub five_locale_bubbles_ok: bool,
    pub epub_xhtml_bytes: usize,
    pub publish_manifest_written: bool,
}

/// Executes the **`T0.6-S4` Dual-Track End-to-End Gate** over a CPFF v1.0 `.prj` workspace:
/// - `S2` Track A (B&W Manga): Slices a B4 600DPI page into 4 panels (including diagonal cut) & evaluates
///   all 4 procedural screentone patterns (CircleDot, LineScreen, CrossHatch, NoiseGrain).
/// - `S2` Track B (Full-Color Webtoon): Slices a `1600×12800` strip into seamless slices and verifies 0-seam pixel boundary.
/// - `S3` (Light Novel): Generates valid EPUB3 XHTML with custom illustration figure embedding.
/// - `S1` (Hub): Audits 5-language speech bubble completeness (Vertical RTL CJK + Horizontal LTR EN/ES) and
///   atomically writes `editions/publish_report.xml`.
pub fn run_t06_s4_panels_tones_webtoon_epub_gate(project_dir: &Path) -> Result<T06S4GateReport, String> {
    let _ = run_tri_app_compatibility_check(project_dir)?;

    // 1. S2 Track A: B4 600DPI 4-panel page layout (diagonal + vertical splits)
    let mut layout = crate::panel::PanelLayout::new_page_frame(6071.0, 8598.0, 320.0, 320.0);
    let root_id = layout.panels()[0].id;
    let (half_a, half_b) = layout
        .slice_panel(root_id, (0.0, 4200.0), (6071.0, 4400.0), 40.0)
        .ok_or_else(|| "T0.6-S4 failed diagonal panel cut 1".to_string())?;
    let _ = layout
        .slice_panel(half_a, (3000.0, 0.0), (2800.0, 8598.0), 36.0)
        .ok_or_else(|| "T0.6-S4 failed panel cut 2".to_string())?;
    let _ = layout
        .slice_panel(half_b, (2900.0, 0.0), (3100.0, 8598.0), 36.0)
        .ok_or_else(|| "T0.6-S4 failed panel cut 3".to_string())?;
    let b4_manga_panels = layout.panels().len();
    if b4_manga_panels != 4 {
        return Err(format!("T0.6-S4 expected 4 manga panels, got {b4_manga_panels}"));
    }

    // 2. S2 Procedural Screentone 4 patterns accuracy check
    let patterns = [
        crate::screentone::TonePattern::CircleDot,
        crate::screentone::TonePattern::LineScreen,
        crate::screentone::TonePattern::CrossHatch,
        crate::screentone::TonePattern::NoiseGrain,
    ];
    for pat in patterns {
        let spec = crate::screentone::ScreentoneSpec {
            lpi: 60.0,
            dpi: 600.0,
            angle_deg: 45.0,
            density: 0.30,
            pattern: pat,
            ink_rgba: [0, 0, 0, 255],
        };
        let mut inked = 0usize;
        for y in 0..40 {
            for x in 0..40 {
                if spec.sample_mask(x, y) {
                    inked += 1;
                }
            }
        }
        if inked == 0 || inked == 1600 {
            return Err(format!("T0.6-S4 screentone pattern {:?} degenerated", pat));
        }
    }

    // 3. S2 Track B: Webtoon strip slicing + zero-seam boundary stitch check
    let webtoon_slices = crate::webtoon::compute_webtoon_slices(12800, 1280);
    if webtoon_slices.len() != 10 {
        return Err(format!("T0.6-S4 expected 10 webtoon slices, got {}", webtoon_slices.len()));
    }
    let mut wstack = crate::layer::LayerStack::new(16, 40);
    let base = wstack.add_raster_layer("WebtoonFlat");
    for y in 0..40 {
        wstack.get_mut(base).unwrap().write_pixel(4, y, [(y * 5) as u8, 100, 220, 255]);
    }
    let mini_slices = crate::webtoon::compute_webtoon_slices(40, 20);
    let b0 = crate::webtoon::render_webtoon_slice_rgba(&wstack, mini_slices[0]);
    let b1 = crate::webtoon::render_webtoon_slice_rgba(&wstack, mini_slices[1]);
    let webtoon_zero_seam_verified =
        &b0[(19 * 16 + 4) * 4..(19 * 16 + 4) * 4 + 4] == &[95, 100, 220, 255]
            && &b1[4 * 4..4 * 4 + 4] == &[100, 100, 220, 255];
    if !webtoon_zero_seam_verified {
        return Err("T0.6-S4 Webtoon slice seam mismatch".into());
    }

    // 4. S1/S2 5-Language speech bubble completeness & vertical/horizontal lettering audit
    let mut locs = std::collections::BTreeMap::new();
    locs.insert("en".into(), "Draw the future!".into());
    locs.insert("zh-Hans".into(), "绘出未来！".into());
    locs.insert("zh-Hant".into(), "繪出未來！".into());
    locs.insert("yue-Hant".into(), "畫出未來！".into());
    locs.insert("es".into(), "¡Dibuja el futuro!".into());
    let bubble = crate::bubble::SpeechBubble {
        id: "b-001".into(),
        panel_id: 1,
        x: 100.0,
        y: 120.0,
        width: 160.0,
        height: 240.0,
        direction: crate::bubble::SpeechBubble::recommended_direction("zh-Hans", false),
        locales: locs,
    };
    let (present, overflows) = bubble.audit_five_locales(40);
    let five_locale_bubbles_ok = present == 5
        && overflows == 0
        && bubble.direction == crate::bubble::TextFlowDirection::VerticalRtl;
    if !five_locale_bubbles_ok {
        return Err("T0.6-S4 5-locale speech bubble audit failed".into());
    }

    // 5. S3 EPUB3 XHTML export + S1 atomic PublishReport manifest
    let xhtml = crate::bubble::render_novel_chapter_epub_xhtml(
        "Ch.001 Starlight Awakening",
        "zh-Hans",
        "# 第一话 星辉觉醒\n\n星光落满屋顶。",
        &["../illustrations/ch001_cover.png"],
    );
    if !xhtml.contains("<html xmlns=\"http://www.w3.org/1999/xhtml\"") {
        return Err("T0.6-S4 EPUB3 XHTML header missing".into());
    }
    let report_path = crate::bubble::write_publish_manifest_atomic(
        project_dir,
        b4_manga_panels,
        webtoon_slices.len(),
        1,
        five_locale_bubbles_ok,
    )?;

    Ok(T06S4GateReport {
        b4_manga_panels,
        screentone_patterns_verified: patterns.len(),
        webtoon_slices_count: webtoon_slices.len(),
        webtoon_zero_seam_verified,
        five_locale_bubbles_ok,
        epub_xhtml_bytes: xhtml.len(),
        publish_manifest_written: report_path.is_file(),
    })
}

/// Summary produced by the **`T0.7-S4` `.mnga` Persistence + PSD `8BPS` + `ActionBus` + S3 Illustration Slot Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T07S4GateReport {
    pub mnga_bytes_written: usize,
    pub mnga_tamper_rejected: bool,
    pub psd_8bps_bytes: usize,
    pub action_bus_preview_steps: usize,
    pub action_bus_single_undo_ok: bool,
    pub novel_illustration_slots_verified: bool,
}

/// Executes the **`T0.7-S4` Integration & Compatibility Gate** over a CPFF v1.0 `.prj` workspace:
/// - `S2`: Atomically persists `.mnga` manuscript under `chapters/ch001/manuscript/p001.mnga`,
///   verifies FNV-1a checksum round-trip + tamper detection, and exports a standards-compliant
///   Adobe PSD (`8BPS` v1 RGB8) buffer.
/// - `S2` `ActionBus`: Dry-run previews, executes, and single-step rolls back / redoes a multi-step
///   cel-layer macro plan atomically.
/// - `S3`: Validates both `PickMangaPage` and `CustomCommissioned` novel illustration slot policies.
pub fn run_t07_s4_mnga_psd_actionbus_gate(project_dir: &Path) -> Result<T07S4GateReport, String> {
    let _ = run_tri_app_compatibility_check(project_dir)?;

    // 1. S2 ActionBus preview -> atomic execute -> single-step undo -> redo
    let mut doc = crate::action_bus::ProjectDocument::from_preset(crate::preset::CanvasPreset::Illustration4K);
    doc.layers = crate::layer::LayerStack::new(64, 64);
    let mut bus = crate::action_bus::ActionBus::new();
    let plan = crate::action_bus::ActionPlan {
        title: "Cel Setup Macro".into(),
        commands: vec![
            crate::action_bus::ActionCommand::CreateRasterLayer {
                name: "Sketch_Rough".into(),
                blend_mode: crate::layer::BlendMode::Normal,
                clipping_mask: false,
                is_reference: false,
            },
            crate::action_bus::ActionCommand::CreateRasterLayer {
                name: "Ink_Lineart".into(),
                blend_mode: crate::layer::BlendMode::Normal,
                clipping_mask: false,
                is_reference: true,
            },
            crate::action_bus::ActionCommand::CreateRasterLayer {
                name: "Cel_Shadow".into(),
                blend_mode: crate::layer::BlendMode::Multiply,
                clipping_mask: true,
                is_reference: false,
            },
            crate::action_bus::ActionCommand::BatchTintLayers {
                name_prefix: "Sketch_".into(),
                tint_rgba: [77, 166, 255, 255],
                opacity: 0.30,
                lock: true,
            },
        ],
    };
    let preview = bus.preview(&doc, &plan);
    if preview.step_summaries.len() != 4 {
        return Err("T0.7-S4 ActionBus preview step count mismatch".into());
    }
    let executed = bus.execute(&mut doc, &plan);
    if executed != 4 || doc.layers.layers().len() != 3 {
        return Err("T0.7-S4 ActionBus execute did not materialize 3 cel layers".into());
    }
    let undo_ok = bus.undo_last(&mut doc) && doc.layers.layers().is_empty();
    let redo_ok = bus.redo_last(&mut doc) && doc.layers.layers().len() == 3;
    if !undo_ok || !redo_ok {
        return Err("T0.7-S4 ActionBus atomic single-step undo/redo failed".into());
    }

    // Paint a pixel so allocated_tiles > 0 in `.mnga` and PSD composite
    let ink_id = doc.layers.find_by_name("Ink_Lineart").unwrap();
    doc.layers.get_mut(ink_id).unwrap().write_pixel(12, 12, [20, 24, 32, 255]);

    // 2. S2 `.mnga` atomic persistence + FNV-1a tamper detection + PSD 8BPS export
    let snap = crate::mnga::MngaDocumentSnapshot::from_layer_stack(&doc.layers, 600, 128);
    let mnga_path = snap.save_atomic(project_dir, "chapters/ch001/manuscript/p001.mnga")?;
    let mut disk_bytes = std::fs::read(&mnga_path).map_err(|e| e.to_string())?;
    let decoded = crate::mnga::MngaDocumentSnapshot::decode_bytes(&disk_bytes)?;
    if decoded != snap {
        return Err("T0.7-S4 .mnga round-trip snapshot mismatch".into());
    }
    disk_bytes[12] ^= 0x55;
    let mnga_tamper_rejected = crate::mnga::MngaDocumentSnapshot::decode_bytes(&disk_bytes).is_err();
    if !mnga_tamper_rejected {
        return Err("T0.7-S4 .mnga FNV-1a checksum failed to reject tampered file".into());
    }

    let psd = crate::mnga::encode_minimal_psd_rgb8(&doc.layers);
    if &psd[..4] != b"8BPS" || psd.len() != 26 + 12 + 2 + 64 * 64 * 3 {
        return Err("T0.7-S4 PSD 8BPS export header or byte length invalid".into());
    }

    // 3. S3 Novel Illustration Slot policy check (MangaPick vs NovelCustom)
    let slot_pick_ok = crate::mnga::validate_novel_illustration_slot(
        crate::project::NovelIllustrationMode::MangaPick,
        "chapters/ch001/manuscript/p001.mnga",
    )
    .is_ok();
    let slot_custom_ok = crate::mnga::validate_novel_illustration_slot(
        crate::project::NovelIllustrationMode::NovelCustom,
        "chapters/ch001/novel/illustrations/ch001_plate01.png",
    )
    .is_ok();
    let slot_escape_blocked = crate::mnga::validate_novel_illustration_slot(
        crate::project::NovelIllustrationMode::NovelCustom,
        "../outside.png",
    )
    .is_err();
    let novel_illustration_slots_verified = slot_pick_ok && slot_custom_ok && slot_escape_blocked;
    if !novel_illustration_slots_verified {
        return Err("T0.7-S4 S3 Novel illustration slot policy check failed".into());
    }

    Ok(T07S4GateReport {
        mnga_bytes_written: disk_bytes.len(),
        mnga_tamper_rejected,
        psd_8bps_bytes: psd.len(),
        action_bus_preview_steps: preview.step_summaries.len(),
        action_bus_single_undo_ok: undo_ok && redo_ok,
        novel_illustration_slots_verified,
    })
}

/// Summary produced by the **`T0.8-S4` Apple Trio Touch/Foldable Ergonomics & Live 5-Language Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T08S4GateReport {
    pub apple_trio_layouts_verified: usize,
    pub gestures_verified: usize,
    pub iphone_duo_hinge_safe: bool,
    pub locales_checked_cells: usize,
    pub locale_truncation_violations: usize,
}

/// Executes the **`T0.8-S4` Apple Trio Ergonomics & 5-Language Gate** over a CPFF v1.0 `.prj` workspace:
/// - Verifies iPadOS (full + Split View), Touchscreen MacBook (desktop hybrid), and iPhone Duo
///   (folded cover / unfolded dual-pane / tabletop) deterministic layouts and hinge exclusion math.
/// - Verifies 2-finger Undo, 3-finger Redo, Pencil Pro Squeeze Radial Menu, and Palm Rejection.
/// - Audits all 5 runtime locales (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`) for 0 missing keys
///   and 0 compact touch truncation violations.
pub fn run_t08_s4_apple_trio_gesture_i18n_gate(project_dir: &Path) -> Result<T08S4GateReport, String> {
    let _ = run_tri_app_compatibility_check(project_dir)?;

    use crate::gesture::{
        audit_five_locale_truncation, compute_foldable_pane_geometry, resolve_touch_gesture,
        GestureAction,
    };
    use crate::platform::{recommend_workspace_layout, FoldPosture, TargetPlatform, WorkspaceLayoutHint};

    let l_ipad_full = recommend_workspace_layout(TargetPlatform::IpadOs, FoldPosture::Flat, 1194.0, 834.0);
    let l_ipad_split = recommend_workspace_layout(TargetPlatform::IpadOs, FoldPosture::Flat, 390.0, 834.0);
    let l_mac_touch = recommend_workspace_layout(TargetPlatform::MacOsTouch, FoldPosture::Flat, 1512.0, 982.0);
    let l_duo_fold = recommend_workspace_layout(TargetPlatform::IphoneDuo, FoldPosture::FoldedCompact, 402.0, 874.0);
    let l_duo_open = recommend_workspace_layout(TargetPlatform::IphoneDuo, FoldPosture::UnfoldedDualPane, 780.0, 874.0);
    let l_duo_table = recommend_workspace_layout(TargetPlatform::IphoneDuo, FoldPosture::TabletopHalfOpen, 780.0, 874.0);

    if l_ipad_full != WorkspaceLayoutHint::TabletTouchStudio
        || l_ipad_split != WorkspaceLayoutHint::SinglePaneCompact
        || l_mac_touch != WorkspaceLayoutHint::DesktopTouchHybrid
        || l_duo_fold != WorkspaceLayoutHint::SinglePaneCompact
        || l_duo_open != WorkspaceLayoutHint::DualPaneAcrossHinge
        || l_duo_table != WorkspaceLayoutHint::TabletopCanvasTopControlsBottom
    {
        return Err("T0.8-S4 Apple Trio layout recommendation mismatch".into());
    }

    let g_undo = resolve_touch_gesture(2, 110.0, 3.0, 7.0, false, false) == GestureAction::Undo;
    let g_redo = resolve_touch_gesture(3, 125.0, 5.0, 7.0, false, false) == GestureAction::Redo;
    let g_squeeze = resolve_touch_gesture(0, 0.0, 0.0, 0.0, true, true) == GestureAction::ToggleRadialMenu;
    let g_palm = resolve_touch_gesture(1, 40.0, 1.0, 22.0, true, false) == GestureAction::RejectPalm;
    if !(g_undo && g_redo && g_squeeze && g_palm) {
        return Err("T0.8-S4 touch/stylus gesture resolver failed".into());
    }

    let duo_geom = compute_foldable_pane_geometry(780.0, FoldPosture::UnfoldedDualPane, 18.0);
    let iphone_duo_hinge_safe = duo_geom.is_split
        && duo_geom.hinge_exclusion_dp >= 16.0
        && (duo_geom.left_pane_width_dp + duo_geom.right_pane_width_dp + duo_geom.hinge_exclusion_dp - 780.0).abs()
            < 1e-3;
    if !iphone_duo_hinge_safe {
        return Err("T0.8-S4 iPhone Duo hinge-safe split math failed".into());
    }

    let (locales_checked_cells, locale_truncation_violations) = audit_five_locale_truncation();
    if locale_truncation_violations > 0 {
        return Err(format!(
            "T0.8-S4 5-locale audit reported {locale_truncation_violations} violations"
        ));
    }

    Ok(T08S4GateReport {
        apple_trio_layouts_verified: 6,
        gestures_verified: 4,
        iphone_duo_hinge_safe,
        locales_checked_cells,
        locale_truncation_violations,
    })
}

/// Summary produced by the **`T0.9-S4` Pre-1.0 Apple Wave 1 Joint Beta Dual-Track Stress Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T09S4GateReport {
    pub b4_layers_verified: usize,
    pub cow_undo_redo_steps: usize,
    pub cow_undo_total_us: u64,
    pub b4_sparse_memory_bytes: usize,
    pub webtoon_1600_slices_1280: usize,
    pub combined_ram_budget_mb: u32,
    pub wave1_apple_targets_ready: usize,
    pub five_locale_violations: usize,
}

/// Executes the **`T0.9-S4` Pre-1.0 Wave 1 Apple Trio Joint Beta Stress Gate**:
/// - Track A: Allocates a 50-layer B4 600DPI (`6071×8598`) cel stack, verifies sparse tile memory
///   efficiency, and benchmarks 50 consecutive CoW `TileUndoStack` undo + redo cycles (`< 16ms/step` SLA).
/// - Track B: Verifies `1600×25600` high-res Webtoon strip splits into 20 seamless `1280px` slices.
/// - Tri-App 8GB RAM Guard: Confirms combined standalone budget (`<= 2048 MB`) and Wave 1 Metal readiness
///   across iPadOS, Touchscreen MacBook, and iPhone Duo, plus 0 5-locale truncation violations.
pub fn run_t09_s4_wave1_beta_stress_gate(project_dir: &Path) -> Result<T09S4GateReport, String> {
    let base_report = run_tri_app_compatibility_check(project_dir)?;

    // 1. Track A: 50-layer B4 600DPI sparse cel stack + 50-step CoW Undo/Redo latency benchmark
    let b4 = crate::preset::CanvasPreset::B4PrintManga600Dpi.spec();
    let mut stack = crate::layer::LayerStack::new(b4.width, b4.height);
    let modes = [
        crate::layer::BlendMode::Normal,
        crate::layer::BlendMode::Multiply,
        crate::layer::BlendMode::Screen,
        crate::layer::BlendMode::GlowDodge,
        crate::layer::BlendMode::LinearBurn,
    ];
    for i in 0..50usize {
        let lid = stack.add_raster_layer(format!("B4_Layer_{i:02}"));
        if let Some(layer) = stack.get_mut(lid) {
            layer.blend_mode = modes[i % modes.len()];
            layer.clipping_mask = i % 3 == 2;
            layer.is_reference = i == 0;
            // Paint 1 sparse pixel in distinct coordinates on every 5th layer
            if i % 5 == 0 {
                layer.write_pixel((i as u32) * 32, (i as u32) * 48, [16, 20, 28, 255]);
            }
        }
    }
    let b4_layers_verified = stack.layers().len();
    let b4_sparse_memory_bytes: usize = stack
        .layers()
        .iter()
        .filter_map(|l| l.raster.as_ref().map(|r| r.memory_bytes()))
        .sum();
    // 10 painted tiles * 256 KiB = 2.5 MiB (vs ~10.4 GiB naive dense 50-layer B4!)
    if b4_layers_verified != 50 || b4_sparse_memory_bytes > 8 * 1024 * 1024 {
        return Err(format!(
            "T0.9-S4 50-layer B4 sparse memory exceeded bound: layers={b4_layers_verified}, bytes={b4_sparse_memory_bytes}"
        ));
    }

    let mut tile_layer = crate::tile::TileLayer::new(b4.width, b4.height);
    let mut history = crate::undo::TileUndoStack::new(100);
    let t0 = std::time::Instant::now();
    for step in 0..50u32 {
        let px = step * 100;
        let py = step * 120;
        let (coord, _, _) = crate::tile::TileCoord::from_pixel(px as i32, py as i32);
        let before = tile_layer.get_tile(coord);
        tile_layer.set_pixel(px, py, [(step * 5) as u8, 80, 180, 255]);
        let after = tile_layer.get_tile(coord);
        history.push(crate::undo::TileDiff {
            entries: vec![(coord, before, after)],
        });
    }
    for _ in 0..50 {
        if !history.undo(&mut tile_layer) {
            return Err("T0.9-S4 CoW undo stack underrun".into());
        }
    }
    if tile_layer.allocated_tile_count() != 0 {
        return Err("T0.9-S4 CoW 50-step undo leaked allocated tiles".into());
    }
    for _ in 0..50 {
        if !history.redo(&mut tile_layer) {
            return Err("T0.9-S4 CoW redo stack underrun".into());
        }
    }
    let cow_undo_total_us = t0.elapsed().as_micros() as u64;
    // DoD: 50 consecutive undo/redo steps < 16ms each (< 800_000 us total)
    if cow_undo_total_us > 800_000 {
        return Err(format!(
            "T0.9-S4 50-step CoW undo/redo exceeded 16ms/step SLA ({cow_undo_total_us}us)"
        ));
    }

    // 2. Track B: High-res Webtoon 1600x25600 strip slicing (20 slices @ 1280px)
    let wt_spec = crate::preset::CanvasPreset::WebtoonStrip1600.spec();
    let wt_slices = crate::webtoon::compute_webtoon_slices(wt_spec.height, 1280);
    if wt_slices.len() != 20 {
        return Err(format!(
            "T0.9-S4 Webtoon 1600x25600 expected 20 slices @ 1280px, got {}",
            wt_slices.len()
        ));
    }

    // 3. Wave 1 Apple Trio Metal readiness & 8GB Tri-App RAM guard
    let wave1 = [
        crate::platform::TargetPlatform::IpadOs,
        crate::platform::TargetPlatform::MacOsTouch,
        crate::platform::TargetPlatform::IphoneDuo,
    ];
    let wave1_apple_targets_ready = wave1
        .iter()
        .filter(|p| p.release_wave() == 1 && p.capabilities().gpu_backend == "Metal (wgpu)")
        .count();
    if wave1_apple_targets_ready != 3 || base_report.combined_ram_budget_mb > 2048 {
        return Err("T0.9-S4 Wave 1 Apple Trio Metal or 8GB RAM budget guard failed".into());
    }

    // 4. 5-Locale zero-truncation QA
    let (_, five_locale_violations) = crate::gesture::audit_five_locale_truncation();
    if five_locale_violations > 0 {
        return Err("T0.9-S4 5-locale zero-truncation QA failed".into());
    }

    Ok(T09S4GateReport {
        b4_layers_verified,
        cow_undo_redo_steps: 50,
        cow_undo_total_us,
        b4_sparse_memory_bytes,
        webtoon_1600_slices_1280: wt_slices.len(),
        combined_ram_budget_mb: base_report.combined_ram_budget_mb,
        wave1_apple_targets_ready,
        five_locale_violations,
    })
}

/// Summary produced by the **`T1.0-S4` Wave 1 Release Candidate (`v1.0.0-rc1`) Dual-Engine & AI Red-Line Gate**.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct T10S4GateReport {
    pub gemma_offline_apache2_verified: bool,
    pub manga_to_novel_isolated: bool,
    pub novel_to_manga_isolated: bool,
    pub human_finals_byte_immutable: bool,
    pub escape_attempts_blocked: bool,
    pub pending_human_brand_signoff: bool,
}

/// Executes the **`T1.0-S4` Wave 1 Release Candidate Gate (`v1.0.0-rc1`)**:
/// - Confirms Gemma 4 E2B (8GB) & E4B (16GB+) local model pack metadata (`Apache-2.0`, offline-only, 120s idle unload).
/// - Emits BOTH `Manga -> Novel` and `Novel -> Manga` reference drafts strictly under `chapters/ch001/ai_assist/`.
/// - Proves via 64-bit FNV-1a digest that human authoritative prose (`novel/prose/zh-Hans.md`) is 100% byte-immutable.
/// - Proves that any AI write targeting `novel/prose/` or `manuscript/` is hard-blocked.
/// - Confirms working codenames remain `is_final_brand == false` until explicit human brand sign-off before `v1.0.0` GA.
pub fn run_t10_s4_release_candidate_gate(project_dir: &Path) -> Result<T10S4GateReport, String> {
    let _ = run_tri_app_compatibility_check(project_dir)?;

    use crate::ai_bridge::{
        file_fnv1a_64, generate_manga_to_novel_reference_atomic,
        generate_novel_to_manga_storyboard_atomic, GemmaModelPack,
    };
    use crate::novel::DivergenceNote;
    use crate::project::AiBridgeArtifact;

    let e2b = GemmaModelPack::recommend_for_device_ram_gb(8);
    let e4b = GemmaModelPack::recommend_for_device_ram_gb(16);
    let gemma_offline_apache2_verified = e2b == GemmaModelPack::Gemma4E2b
        && e4b == GemmaModelPack::Gemma4E4b
        && !e2b.requires_cloud()
        && !e4b.requires_cloud()
        && e2b.license() == "Apache-2.0"
        && e4b.idle_unload_seconds() == 120;
    if !gemma_offline_apache2_verified {
        return Err("T1.0-S4 Gemma 4 local offline/Apache-2.0 policy check failed".into());
    }

    let human_prose = project_dir.join("chapters/ch001/novel/prose/zh-Hans.md");
    let before_hash = file_fnv1a_64(&human_prose)?;

    let m2n = generate_manga_to_novel_reference_atomic(
        project_dir,
        "ch001",
        "zh-Hans",
        "Panel 1: Orbital Academy rooftop storm; Panel 2: Starlight Blade awakens.",
        e2b,
        &[DivergenceNote {
            scene_id: Some("sc001".into()),
            summary: "Human novel retains extended rooftop monologue.".into(),
        }],
    )?;
    let n2m = generate_novel_to_manga_storyboard_atomic(
        project_dir,
        "ch001",
        "novel/prose/zh-Hans.md",
        "暮色尚未褪尽，轨道学院北侧天台的风压警报已经拉响。",
        e4b,
    )?;

    let after_hash = file_fnv1a_64(&human_prose)?;
    let human_finals_byte_immutable = before_hash == after_hash;
    if !human_finals_byte_immutable {
        return Err("T1.0-S4 AI bridge mutated human authoritative prose!".into());
    }

    let manga_to_novel_isolated =
        m2n.meta_abs_path.is_file() && m2n.artifact.output_src.starts_with("ai_assist/");
    let novel_to_manga_isolated =
        n2m.meta_abs_path.is_file() && n2m.artifact.output_src.starts_with("ai_assist/");

    let escape_prose = AiBridgeArtifact {
        role: "ai_reference_only".into(),
        meta_src: "ai_assist/manga_to_novel/meta.xml".into(),
        output_src: "novel/prose/zh-Hans.md".into(),
        derived_from: "script/script.xml".into(),
    }
    .validate_isolation()
    .is_err();
    let escape_manuscript = AiBridgeArtifact {
        role: "ai_reference_only".into(),
        meta_src: "ai_assist/novel_to_manga/meta.xml".into(),
        output_src: "manuscript/p001.mnga".into(),
        derived_from: "novel/prose/zh-Hans.md".into(),
    }
    .validate_isolation()
    .is_err();
    let escape_attempts_blocked = escape_prose && escape_manuscript;
    if !escape_attempts_blocked {
        return Err("T1.0-S4 AI red-line isolation failed to block human-final write escape".into());
    }

    let pending_human_brand_signoff = !SuiteApp::Hub.metadata().is_final_brand
        && !SuiteApp::Manga.metadata().is_final_brand
        && !SuiteApp::Novel.metadata().is_final_brand;

    Ok(T10S4GateReport {
        gemma_offline_apache2_verified,
        manga_to_novel_isolated,
        novel_to_manga_isolated,
        human_finals_byte_immutable,
        escape_attempts_blocked,
        pending_human_brand_signoff,
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

    #[test]
    fn t03_s4_bible_hot_reload_and_13_blend_mode_gate_passes() {
        let parent = std::env::temp_dir().join(format!("manga_t03_s4_unit_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&parent);
        std::fs::create_dir_all(&parent).unwrap();
        let opts = crate::project_init::ProjectInitOptions::dual_engine_default("T03GatePrj", "S4Tester");
        crate::project_init::init_cpff_project(&parent, &opts).unwrap();

        let report = run_t03_s4_bible_layers_gate(&parent.join("T03GatePrj"))
            .expect("T0.3-S4 gate must pass");
        assert_eq!(report.bible_characters_verified, 3);
        assert_eq!(report.toc_entries_verified, 3);
        assert!(report.hot_reload_latency_ms < 300);
        assert_eq!(report.cel_blend_modes_verified, 13);
        assert!(report.clipping_mask_verified);
        assert!(report.alpha_lock_verified);
        assert!(report.blue_sketch_tint_verified);
        assert!(report.write_isolation_verified);
        assert_eq!(report.temp_files_remaining, 0);

        let _ = std::fs::remove_dir_all(&parent);
    }

    #[test]
    fn t04_s4_ingest_fill_selection_and_divergence_gate_passes() {
        let parent = std::env::temp_dir().join(format!("manga_t04_s4_unit_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&parent);
        std::fs::create_dir_all(&parent).unwrap();
        let opts = crate::project_init::ProjectInitOptions::dual_engine_default("T04GatePrj", "S4Tester");
        crate::project_init::init_cpff_project(&parent, &opts).unwrap();

        let report = run_t04_s4_ingest_fill_divergence_gate(&parent.join("T04GatePrj"))
            .expect("T0.4-S4 gate must pass");
        assert!(report.ingest_collision_renamed);
        assert!(report.ingest_prose_isolated);
        assert!(report.close_gap_zero_leak);
        assert!(report.anti_halo_expanded);
        assert_eq!(report.lasso_selected_pixels, 1024);
        assert!(report.divergence_notes_verified >= 1);

        let _ = std::fs::remove_dir_all(&parent);
    }

    #[test]
    fn t05_s4_vector_ruler_and_5_locale_glossary_gate_passes() {
        let parent = std::env::temp_dir().join(format!("manga_t05_s4_unit_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&parent);
        std::fs::create_dir_all(&parent).unwrap();
        let opts = crate::project_init::ProjectInitOptions::dual_engine_default("T05GatePrj", "S4Tester");
        crate::project_init::init_cpff_project(&parent, &opts).unwrap();

        let report = run_t05_s4_vector_ruler_glossary_gate(&parent.join("T05GatePrj"))
            .expect("T0.5-S4 gate must pass");
        assert_eq!(report.glossary_5_locale_complete, 3);
        assert_eq!(report.glossary_missing_cells, 0);
        assert!(report.vector_intersection_erased);
        assert!(report.vector_4x_lossless_scaled);
        assert_eq!(report.rulers_verified, 3);
        assert_eq!(report.novel_autocomplete_hits, 3);

        let _ = std::fs::remove_dir_all(&parent);
    }

    #[test]
    fn t06_s4_panels_screentones_webtoon_and_epub_gate_passes() {
        let parent = std::env::temp_dir().join(format!("manga_t06_s4_unit_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&parent);
        std::fs::create_dir_all(&parent).unwrap();
        let opts = crate::project_init::ProjectInitOptions::dual_engine_default("T06GatePrj", "S4Tester");
        crate::project_init::init_cpff_project(&parent, &opts).unwrap();

        let report = run_t06_s4_panels_tones_webtoon_epub_gate(&parent.join("T06GatePrj"))
            .expect("T0.6-S4 gate must pass");
        assert_eq!(report.b4_manga_panels, 4);
        assert_eq!(report.screentone_patterns_verified, 4);
        assert_eq!(report.webtoon_slices_count, 10);
        assert!(report.webtoon_zero_seam_verified);
        assert!(report.five_locale_bubbles_ok);
        assert!(report.epub_xhtml_bytes > 100);
        assert!(report.publish_manifest_written);

        let _ = std::fs::remove_dir_all(&parent);
    }

    #[test]
    fn t07_s4_mnga_psd_actionbus_gate_passes() {
        let parent = std::env::temp_dir().join(format!("manga_t07_s4_unit_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&parent);
        std::fs::create_dir_all(&parent).unwrap();
        let opts = crate::project_init::ProjectInitOptions::dual_engine_default("T07GatePrj", "S4Tester");
        crate::project_init::init_cpff_project(&parent, &opts).unwrap();

        let report = run_t07_s4_mnga_psd_actionbus_gate(&parent.join("T07GatePrj"))
            .expect("T0.7-S4 gate must pass");
        assert!(report.mnga_bytes_written > 40);
        assert!(report.mnga_tamper_rejected);
        assert!(report.psd_8bps_bytes > 40);
        assert_eq!(report.action_bus_preview_steps, 4);
        assert!(report.action_bus_single_undo_ok);
        assert!(report.novel_illustration_slots_verified);

        let _ = std::fs::remove_dir_all(&parent);
    }

    #[test]
    fn t08_s4_apple_trio_gesture_and_5_locale_gate_passes() {
        let parent = std::env::temp_dir().join(format!("manga_t08_s4_unit_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&parent);
        std::fs::create_dir_all(&parent).unwrap();
        let opts = crate::project_init::ProjectInitOptions::dual_engine_default("T08GatePrj", "S4Tester");
        crate::project_init::init_cpff_project(&parent, &opts).unwrap();

        let report = run_t08_s4_apple_trio_gesture_i18n_gate(&parent.join("T08GatePrj"))
            .expect("T0.8-S4 gate must pass");
        assert_eq!(report.apple_trio_layouts_verified, 6);
        assert_eq!(report.gestures_verified, 4);
        assert!(report.iphone_duo_hinge_safe);
        assert_eq!(report.locales_checked_cells, 40);
        assert_eq!(report.locale_truncation_violations, 0);

        let _ = std::fs::remove_dir_all(&parent);
    }

    #[test]
    fn t09_s4_wave1_beta_stress_gate_passes() {
        let parent = std::env::temp_dir().join(format!("manga_t09_s4_unit_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&parent);
        std::fs::create_dir_all(&parent).unwrap();
        let opts = crate::project_init::ProjectInitOptions::dual_engine_default("T09GatePrj", "S4Tester");
        crate::project_init::init_cpff_project(&parent, &opts).unwrap();

        let report = run_t09_s4_wave1_beta_stress_gate(&parent.join("T09GatePrj"))
            .expect("T0.9-S4 Wave 1 Beta stress gate must pass");
        assert_eq!(report.b4_layers_verified, 50);
        assert_eq!(report.cow_undo_redo_steps, 50);
        assert!(report.cow_undo_total_us < 800_000);
        assert_eq!(report.webtoon_1600_slices_1280, 20);
        assert_eq!(report.wave1_apple_targets_ready, 3);
        assert_eq!(report.five_locale_violations, 0);

        let _ = std::fs::remove_dir_all(&parent);
    }

    #[test]
    fn t10_s4_wave1_rc1_gemma4_redline_gate_passes() {
        let parent = std::env::temp_dir().join(format!("manga_t10_s4_unit_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&parent);
        std::fs::create_dir_all(&parent).unwrap();
        let opts = crate::project_init::ProjectInitOptions::dual_engine_default("T10GatePrj", "S4Tester");
        crate::project_init::init_cpff_project(&parent, &opts).unwrap();

        let report = run_t10_s4_release_candidate_gate(&parent.join("T10GatePrj"))
            .expect("T1.0-S4 Wave 1 RC1 gate must pass");
        assert!(report.gemma_offline_apache2_verified);
        assert!(report.manga_to_novel_isolated);
        assert!(report.novel_to_manga_isolated);
        assert!(report.human_finals_byte_immutable);
        assert!(report.escape_attempts_blocked);
        assert!(report.pending_human_brand_signoff);

        let _ = std::fs::remove_dir_all(&parent);
    }
}
