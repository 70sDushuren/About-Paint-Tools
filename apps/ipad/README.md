# iPadOS Native Shell (`apps/ipad`)

This directory houses the thin, hardware-native **iPadOS (SwiftUI + UIKit + CAMetalLayer)** shell designed for **Option C** (`Thin Native Shell + Shared Rust Core Engine`).

## Responsibilities
1. **240Hz Apple Pencil Capture**: Directly consumes `UIEvent.coalescedTouches(for:)` and `UIEvent.predictedTouches(for:)`, plus Apple Pencil Pro `rollAngle`, `altitudeAngle`, `azimuthAngle`, `UIPencilInteraction` (Squeeze / Double-Tap), and `UIHoverGestureRecognizer`.
2. **Zero-Copy Presentation**: Owns a `CAMetalLayer` passed to `manga-core` (`wgpu` Metal backend) for `< 9ms` latency on 120Hz ProMotion displays.
3. **5-Language Adaptive UI**: Loads localized keys from `i18n/locales/{en,zh-Hans,zh-Hant,yue-Hant,es}.json` (compiled to `Localizable.xcstrings` in Xcode builds) with an in-app locale override supporting `zh-HK → yue-Hant` fallback.

## Building on macOS (Xcode)
```bash
# Build static Rust core for iPadOS (arm64)
rustup target add aarch64-apple-ios
cargo build --manifest-path ../../core/Cargo.toml --release --target aarch64-apple-ios
```
