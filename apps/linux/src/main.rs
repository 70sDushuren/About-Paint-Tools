use std::env;
use std::path::PathBuf;

use manga_core::{CanvasPreset, TargetPlatform};
use manga_linux_shell::{LinuxStudioShell, WaylandTabletToolEvent, WaylandTabletTouchAdapter};

fn main() {
    let args: Vec<String> = env::args().collect();
    let self_check = args.iter().any(|a| a == "--self-check");

    let mut shell = LinuxStudioShell::new(CanvasPreset::WebtoonStrip800, 1440.0, 900.0);
    let desktop_layout = shell.current_layout();
    shell.set_convertible_tablet_mode(true);
    let tablet_layout = shell.current_layout();

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
    let dirty = shell.session.push_points(&[sample]).len();
    shell.session.end_stroke();

    let caps = TargetPlatform::LinuxTouch.capabilities();
    println!(
        "manga-linux-shell ({} / {}): desktop={:?}, 2in1_tablet={:?}, dirty_tiles={}",
        caps.gpu_backend, caps.stylus_protocol, desktop_layout, tablet_layout, dirty
    );

    if self_check {
        let sample_prj = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../templates/SampleManga");
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
