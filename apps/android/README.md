# Android Pad & Foldable Phone Native Shell (`apps/android`)

**Target Milestone**: `v1.1` (Wave 2 — First Post-`v1.0` Cross-Ecosystem Target)  
**Architecture**: Kotlin + Jetpack Compose + Jetpack WindowManager (`FoldingFeature`) + `androidx.graphics` Low-Latency Front-Buffer + `wgpu` (Vulkan) + Rust `libmanga_core.so` (`cdylib`).

## Target Hardware
- Android Tablets (Samsung Galaxy Tab S-Pen, Huawei MatePad NearLink M-Pencil, Xiaomi/Lenovo USI 2.0)
- Foldable Phones (Galaxy Z Fold, Pixel Fold, Mate X / Magic V / Find N) — supporting:
  - **Folded Cover Screen**: Quick sketch, Light Novel writing, hands-free Gemma 4 voice continuity
  - **Unfolded Dual-Pane**: Left Outline/Novel/AI Reference + Right Manga Canvas avoiding hinge crease
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
