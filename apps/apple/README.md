# Apple Multi-Device Touch & Foldable Shell (`apps/apple`)

**Release Wave 1 (`v0.1` – `v0.9` Beta → `v1.0` Release)**

This unified SwiftUI + UIKit/AppKit workspace ships **three native Apple touch & foldable targets** (`iPad`, `Touchscreen MacBook`, `iPhone Duo`) and supports **three standalone-or-concurrent modular tools** over one shared CPFF v1.0 `.prj` workspace (all names below are **working codenames**, final brand names TBD before release):
- **S1 — `创想空间` / `NoemaDock`** (`noemadock://`, `< 200 MB` RAM): Project overview, manuscript/prose import, dual-engine serialization & multi-language release hub.
- **S2 — `雕龙` / `DracoNib`** (`draconib://`, full GPU canvas): Series manga & illustration drawing + artwork management.
- **S3 — `文心` / `LitteraCore`** (`litteracore://`, `< 120 MB` RAM, zero GPU canvas overhead): Light novel writing, illustration curation & EPUB3/Markdown publishing.

| Target | Platform / Form Factor | Primary Input & Ergonomics | Target Milestone |
| :--- | :--- | :--- | :--- |
| **`MangaStudio-iPadOS`** | **iPad** (11" / 13" ProMotion) | UIKit 240Hz `coalescedTouches` + `predictedTouches`, Apple Pencil Pro (Squeeze / Hover / Barrel Roll), Palm Rejection | `v0.1` – `v0.9` → `v1.0` |
| **`MangaStudio-macOS-Touch`** | **Touchscreen MacBook** (macOS Touch) | AppKit direct multi-touch screen gestures + `NSEvent` `tabletPoint` / Sidecar stylus + full menu bar & single-key shortcuts | `v0.8` – `v0.9` → `v1.0` |
| **`MangaStudio-iPhoneDuo`** | **iPhone Duo** (Apple Foldable) | Folded cover screen: one-handed `LitteraCore` / Voice Continuity / Quick Sketch ↔ Unfolded: Hinge-aware Dual-Pane (`LitteraCore` + `DracoNib`) | `v0.8` – `v0.9` → `v1.0` |

## Directory Layout
```text
apps/apple/
├── project.yml                         # XcodeGen 3-target project specification (links MangaCore.xcframework)
├── ci_scripts/
│   └── ci_post_clone.sh                # Xcode Cloud Rust toolchain & XCFramework build hook
├── Shared/
│   ├── Resources/Localizable.xcstrings # Synced 5-language catalog (en, zh-Hans, zh-Hant, yue-Hant/zh-HK, es)
│   └── Sources/
│       ├── MangaStudioApp.swift        # @main SwiftUI entry point (macOS Touch, iPadOS, iPhone Duo)
│       ├── MangaCoreBridge.swift       # Type-safe Swift RAII wrapper over core/manga-core C-ABI
│       └── AppleWorkspaceShell.swift   # Interactive Tri-App shell + live Rust FFI canvas & diagnostics
├── iPadOS/
│   └── ApplePencilInputAdapter.swift   # 240Hz coalesced/predictedTouches + Apple Pencil Pro
├── macOS-Touch/
│   └── MacTouchInputAdapter.swift      # Direct touchscreen NSTouch + tabletPoint + keyboard fusion
└── iPhoneDuo/
    └── IphoneDuoPostureAdapter.swift   # Folded/Unfolded posture & HingeSafeArea crease avoidance
```

## Building & Running on macOS (Unified Workflow)
```bash
# One-command sync: git pull --rebase + incremental 3-slice Rust XCFramework + XcodeGen + open Xcode
make sync

# Or build/run directly from terminal (great for local Antigravity / CI verification)
make run-mac       # Builds & launches MangaStudio-macOS-Touch on My Mac
make run-ipad      # Builds MangaStudio-iPadOS for Apple Silicon iOS Simulator
make check         # Runs full CI + S4 Tri-App integration gates locally
make push MSG="feat(apple): your change"
```
> Every Xcode target in `project.yml` also runs an incremental Rust pre-build script (`scripts/dev.sh ensure-rust-xcode`): pure Swift edits skip Rust compilation in `< 50ms`, while edits under `core/` automatically rebuild `MangaCore.xcframework` on `⌘R`.
