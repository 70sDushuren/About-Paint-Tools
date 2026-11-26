use std::env;
use std::path::PathBuf;

use manga_core::{
    init_cpff_project, run_t02_s4_concurrency_soak, run_t03_s4_bible_layers_gate,
    run_t04_s4_ingest_fill_divergence_gate, run_t05_s4_vector_ruler_glossary_gate,
    run_tri_app_compatibility_check, CanvasPreset, ProjectInitOptions, SuiteApp, TargetPlatform,
};
use manga_linux_shell::{LinuxStudioShell, WaylandTabletToolEvent, WaylandTabletTouchAdapter};

fn parse_app_arg(args: &[String]) -> SuiteApp {
    for i in 0..args.len() {
        if args[i] == "--app" {
            if let Some(val) = args.get(i + 1).and_then(|s| SuiteApp::from_str_alias(s)) {
                return val;
            }
        }
    }
    SuiteApp::Manga
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if let Some(pos) = args.iter().position(|a| a == "--init-project") {
        let Some(parent_dir) = args.get(pos + 1) else {
            eprintln!("Usage: manga-linux-shell --init-project <parent_dir> <folder_name> [author]");
            std::process::exit(2);
        };
        let Some(folder_name) = args.get(pos + 2) else {
            eprintln!("Usage: manga-linux-shell --init-project <parent_dir> <folder_name> [author]");
            std::process::exit(2);
        };
        let author = args.get(pos + 3).map(String::as_str).unwrap_or("Creator");
        let opts = ProjectInitOptions::dual_engine_default(folder_name, author);
        match init_cpff_project(std::path::Path::new(parent_dir), &opts) {
            Ok(prj_path) => {
                println!("OK [S1 v0.2.1]: Bootstrapped CPFF v1.0 project at '{}'", prj_path.display());
                return;
            }
            Err(err) => {
                eprintln!("FAILED [S1 v0.2.1]: {err}");
                std::process::exit(1);
            }
        }
    }

    let self_check = args.iter().any(|a| a == "--self-check");
    let integration_check = args.iter().any(|a| a == "--integration-check");
    let selected_app = parse_app_arg(&args);
    let meta = selected_app.metadata();

    let sample_prj = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../templates/SampleManga");

    if integration_check {
        match run_tri_app_compatibility_check(&sample_prj) {
            Ok(report) => {
                println!(
                    "OK [S4 Integration Gate]: Tri-app compatibility verified on '{}' (editions={}, chapters={}, write_isolation={}, ai_redline={}, deep_links={}, combined_ram_budget={}MB)",
                    report.project_id,
                    report.editions_count,
                    report.chapters_count,
                    report.write_isolation_verified,
                    report.ai_redline_verified,
                    report.deep_link_handoff_verified,
                    report.combined_ram_budget_mb
                );
            }
            Err(err) => {
                eprintln!("FAILED [S4 Integration Gate]: {err}");
                std::process::exit(1);
            }
        }

        let soak_parent = std::env::temp_dir().join(format!("manga_t02_s4_soak_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&soak_parent);
        if let Err(err) = std::fs::create_dir_all(&soak_parent) {
            eprintln!("FAILED [T0.2-S4 Soak]: {err}");
            std::process::exit(1);
        }
        let opts = ProjectInitOptions::dual_engine_default("SoakVerify", "S4Gate");
        let soak_prj = soak_parent.join("SoakVerify");
        let gate_result = init_cpff_project(&soak_parent, &opts).and_then(|_| {
            let soak = run_t02_s4_concurrency_soak(&soak_prj, 100)?;
            let t03 = run_t03_s4_bible_layers_gate(&soak_prj)?;
            let t04 = run_t04_s4_ingest_fill_divergence_gate(&soak_prj)?;
            let t05 = run_t05_s4_vector_ruler_glossary_gate(&soak_prj)?;
            Ok((soak, t03, t04, t05))
        });
        let _ = std::fs::remove_dir_all(&soak_parent);

        match gate_result {
            Ok((soak, t03, t04, t05)) => {
                println!(
                    "OK [T0.2-S4 Concurrency Soak]: {} rounds passed (S1_reads={}, S2_stamps={}, S3_atomic_saves={}, locked_rejections={}, leaked_tmp={})",
                    soak.rounds_completed,
                    soak.manifest_reads_verified,
                    soak.brush_stamps_generated,
                    soak.atomic_prose_saves_verified,
                    soak.locked_overwrite_rejections,
                    soak.temp_files_remaining
                );
                println!(
                    "OK [T0.3-S4 Bible & Cel Gate]: bible_chars={}, toc_entries={}, hot_reload_ms={}ms (<300ms), cel_blend_modes={}, clip={}, alpha_lock={}, blue_sketch={}, leaked_tmp={}",
                    t03.bible_characters_verified,
                    t03.toc_entries_verified,
                    t03.hot_reload_latency_ms,
                    t03.cel_blend_modes_verified,
                    t03.clipping_mask_verified,
                    t03.alpha_lock_verified,
                    t03.blue_sketch_tint_verified,
                    t03.temp_files_remaining
                );
                println!(
                    "OK [T0.4-S4 Ingest/Fill/Divergence Gate]: collision_renamed={}, prose_isolated={}, close_gap_filled={}, zero_leak={}, anti_halo={}, lasso_px={}, divergence_notes={}",
                    t04.ingest_collision_renamed,
                    t04.ingest_prose_isolated,
                    t04.close_gap_filled_pixels,
                    t04.close_gap_zero_leak,
                    t04.anti_halo_expanded,
                    t04.lasso_selected_pixels,
                    t04.divergence_notes_verified
                );
                println!(
                    "OK [T0.5-S4 Vector/Ruler/Glossary Gate]: glossary_5_locale={}, missing_cells={}, vec_intersection_erased={}, vec_4x_scaled={}, rulers={}, novel_hits={}",
                    t05.glossary_5_locale_complete,
                    t05.glossary_missing_cells,
                    t05.vector_intersection_erased,
                    t05.vector_4x_lossless_scaled,
                    t05.rulers_verified,
                    t05.novel_autocomplete_hits
                );
                return;
            }
            Err(err) => {
                eprintln!("FAILED [S4 Release Gate]: {err}");
                std::process::exit(1);
            }
        }
    }

    let mut shell = LinuxStudioShell::new(CanvasPreset::WebtoonStrip800, 1440.0, 900.0);
    let desktop_layout = shell.current_layout();
    shell.set_convertible_tablet_mode(true);
    let tablet_layout = shell.current_layout();

    let dirty = if meta.requires_gpu_canvas {
        shell.session.begin_stroke(4.0, [20, 20, 20, 255], false, 2.0);
        let sample = WaylandTabletTouchAdapter::to_stroke_point(WaylandTabletToolEvent {
            x: 128.0,
            y: 128.0,
            pressure_raw: 52_000,
            tilt_x_deg: 12.0,
            tilt_y_deg: -6.0,
            rotation_deg: 45.0,
            timestamp_ms: 10.0,
            is_eraser_end: false,
        });
        let count = shell.session.push_points(&[sample]).len();
        shell.session.end_stroke();
        count
    } else {
        0
    };

    let caps = TargetPlatform::LinuxTouch.capabilities();
    println!(
        "manga-linux-shell [{} / codename: {} / {} | GPU canvas={} | RAM budget={}MB] ({}): desktop={:?}, 2in1_tablet={:?}, dirty_tiles={}",
        meta.id,
        meta.codename_zh_hans,
        meta.codename_en,
        meta.requires_gpu_canvas,
        meta.standalone_ram_budget_mb,
        caps.gpu_backend,
        desktop_layout,
        tablet_layout,
        dirty
    );

    if self_check {
        match LinuxStudioShell::open_project_manifest(&sample_prj) {
            Ok(manifest) => println!(
                "OK: Loaded CPFF v1.0 project '{}' (engines={}, editions={})",
                manifest.title_en,
                manifest.creative_engines.as_str(),
                manifest.editions.len()
            ),
            Err(err) => {
                eprintln!("ERROR: Failed self-check loading SampleManga: {err}");
                std::process::exit(1);
            }
        }
    }
}
