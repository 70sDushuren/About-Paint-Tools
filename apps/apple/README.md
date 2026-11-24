# Apple Multi-Device Touch & Foldable Shell (`apps/apple`)

**Release Wave 1 (`v0.1` – `v0.9` Beta → `v1.0` Release)**

This unified SwiftUI + UIKit/AppKit workspace ships **three native Apple touch & foldable targets** from >85% shared Swift code and a single Rust `manga-core` static library (`libmanga_core.a`):

| Target | Platform / Form Factor | Primary Input & Ergonomics | Target Milestone |
| :--- | :--- | :--- | :--- |
| **`MangaStudio-iPadOS`** | **iPad** (11" / 13" ProMotion) | UIKit 240Hz `coalescedTouches` + `predictedTouches`, Apple Pencil Pro (Squeeze / Hover / Barrel Roll), Palm Rejection | `v0.1` – `v0.9` → `v1.0` |
| **`MangaStudio-macOS-Touch`** | **Touchscreen MacBook** (macOS Touch) | AppKit direct multi-touch screen gestures + `NSEvent` `tabletPoint` / Sidecar stylus + full menu bar & single-key shortcuts | `v0.8` – `v0.9` → `v1.0` |
| **`MangaStudio-iPhoneDuo`** | **iPhone Duo** (Apple Foldable) | Folded cover screen: one-handed Light Novel / Voice Continuity / Quick Sketch ↔ Unfolded: Hinge-aware Dual-Pane Studio | `v0.8` – `v0.9` → `v1.0` |

## Directory Layout
```text
apps/apple/
├── project.yml                         # XcodeGen 3-target project specification
├── Shared/
│   ├── Resources/Localizable.xcstrings # Synced 5-language catalog (en, zh-Hans, zh-Hant, yue-Hant/zh-HK, es)
│   └── Sources/
│       ├── MangaCoreBridge.swift       # Type-safe Swift RAII wrapper over core/manga-core C-ABI
│       └── AppleWorkspaceShell.swift   # 3-mode adaptive SwiftUI studio shell (Focus / Manga / Novel×Manga)
├── iPadOS/
│   └── ApplePencilInputAdapter.swift   # 240Hz coalesced/predictedTouches + Apple Pencil Pro
├── macOS-Touch/
│   └── MacTouchInputAdapter.swift      # Direct touchscreen NSTouch + tabletPoint + keyboard fusion
└── iPhoneDuo/
    └── IphoneDuoPostureAdapter.swift   # Folded/Unfolded posture & HingeSafeArea crease avoidance
```

## Building on macOS (Xcode + XcodeGen)
```bash
# 1. Build Rust static libraries for iOS/iPadOS and macOS Apple Silicon
rustup target add aarch64-apple-ios aarch64-apple-darwin
cargo build --manifest-path ../../core/Cargo.toml --release --target aarch64-apple-ios
cargo build --manifest-path ../../core/Cargo.toml --release --target aarch64-apple-darwin

# 2. Generate Xcode project for all 3 targets
xcodegen generate
```
