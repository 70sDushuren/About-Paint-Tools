# Android Pad & Foldable Phone Native Shell (`apps/android`)

**Target Milestone**: `v1.1` (Wave 2 — First Post-`v1.0` Cross-Ecosystem Target)  
**Architecture**: Kotlin + Jetpack Compose + Jetpack WindowManager (`FoldingFeature`) + `androidx.graphics` Low-Latency Front-Buffer + `wgpu` (Vulkan) + Rust `libmanga_core.so` (`cdylib`).

## Modular Tri-App Targets (Working Codenames — Final Brand TBD before Release)
To minimize RAM/VRAM usage on Android tablets and foldables, the Android workspace splits into three standalone-or-concurrent apps sharing one CPFF v1.0 `.prj` folder and `:core-bridge`:
- **S1 — `创想空间` / `NoemaDock`** (`noemadock://`): Project overview, asset/prose import, dual-engine serialization & publishing (`< 200 MB` RAM)
- **S2 — `雕龙` / `DracoNib`** (`draconib://`): S-Pen / NearLink M-Pencil / USI 2.0 low-latency Vulkan manga drawing
- **S3 — `文心` / `LitteraCore`** (`litteracore://`): Lightweight novel writing, illustration curation & EPUB3 publishing (`< 120 MB` RAM)

## Target Hardware
- Android Tablets (Samsung Galaxy Tab S-Pen, Huawei MatePad NearLink M-Pencil, Xiaomi/Lenovo USI 2.0)
- Foldable Phones (Galaxy Z Fold, Pixel Fold, Mate X / Magic V / Find N) — supporting:
  - **Folded Cover Screen**: Quick sketch, `LitteraCore` novel writing, hands-free Gemma 4 voice continuity
  - **Unfolded Dual-Pane**: Left `LitteraCore` / Outline / AI Reference + Right `DracoNib` Manga Canvas avoiding hinge crease
  - **Half-Open Tabletop Mode**: Top screen canvas/preview + bottom screen tool deck / novel keyboard

## 5-Language Android Resources
Android `values*/strings.xml` files (`values`, `values-zh-rCN`, `values-zh-rTW`, `values-zh-rHK`, `values-es`) are automatically generated and CI-checked from `i18n/locales/*.json` via:
```bash
python3 scripts/i18n_sync.py --export-android --check-android
```

## Building Rust `cdylib` for Android (NDK)
```bash
# Requires cargo-ndk & Android NDK r27+
rustup target add aarch64-linux-android x86_64-linux-android
cargo ndk -t arm64-v8a -t x86_64 -o app/src/main/jniLibs \
    build --manifest-path ../../core/Cargo.toml -p manga-core --release
```
