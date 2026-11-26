# 06. Detailed Engineering Task Breakdown (Work Breakdown Structure)

**Language / 语言**: **English** | [简体中文](../zh-CN/06-development-tasks.md)

> **Working Codename Notice**: The Chinese, English, and Spanish names of the three standalone tools (**`创想空间` / `NoemaDock`**, **`雕龙` / `DracoNib`**, **`文心` / `LitteraCore`**) are currently reserved as **working codenames (`is_final_brand = false`)** and will be finalized via a dedicated branding PR prior to official release.

---

## 1. Track Tags & "3+1" Subproject Delivery Discipline

This document decomposes [04. Phased Development Roadmap](./04-roadmap.md) into atomic, issue-ready engineering tasks. Under our **Tri-App Modular Suite Architecture**, **every version `vX.Y` MUST be split into 3 independent tool subprojects plus 1 dedicated Integration & Compatibility Revision stage**, merging a unified version PR only after all four pass:

### 1.1 Subproject & Release Gate Tags (Mandatory `S1` + `S2` + `S3` + `S4` per Version)
- `[S1 Hub]` (working codename `NoemaDock` / `创想空间`): Project overview, script/manuscript import, dual-engine (Manga × Light Novel) episode management & multi-language release hub (no GPU canvas, `< 200 MB` RAM budget, `manga-core --features hub`)
- `[S2 Manga]` (working codename `DracoNib` / `雕龙`): Series manga & anime illustration drawing tool covering manuscript management and high-FPS GPU painting (`manga-core --features canvas`)
- `[S3 Novel]` (working codename `LitteraCore` / `文心`): Light novel authoring, illustration curation & EPUB/Markdown publishing manager (no GPU canvas, `< 120 MB` RAM budget, `manga-core --features novel`)
- `[S4 Integration→PR]`: Dedicated **per-version integration & compatibility revision phase** validating concurrent `.prj` write-ownership isolation, cross-app Deep-Link handoffs, `ai_assist/` red-line isolation, 8GB multi-app RAM coexistence, and multi-platform packaging prior to unified Release PR publication

### 1.2 Technical Domain Tags
- `[Dual]`: Core foundation shared by both B&W Page Manga and Full-Color Webtoon/Illustration
- `[B&W Manga]`: Focused on B4 600DPI print sheets, vector ink, panel frames, procedural screentones, and vertical CJK bubbles
- `[Color Webtoon]`: Focused on cel-shading blend modes, anti-halo close-gap flatting, vertical long strips, and seamless slicing
- `[Local AI]`: Embedded local Gemma 4 (E2B/E4B) Script Supervisor, Story Planner, Function-Calling driver, and on-device vision tools
- `[Multi-Platform]`: Six-platform touch/foldable delivery (Wave 1 `v0.9`/`v1.0`: iPad / Touch MacBook / iPhone Duo; Wave 2 `v1.1`–`v1.3`: Android / Windows / Linux)
- `[i18n]`: 5-language (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`) localization & adaptive layout QA

### MIT-Compatible Graphics Library Integration Map (see [02. Architecture RFC](./02-architecture-and-tech-stack.md#4-high-performance-open-source-graphics-libraries-rust--c--mit-compliance))

| Milestone | Key Permissive Crates / Libs | Accelerated Tasks |
| :--- | :--- | :--- |
| `v0.1` | `wgpu`, `glam`, `swift-bridge` / `uniffi` | `T0.1-02`, `T0.1-03` |
| `v0.2–v0.4` | `rayon`, `tiny-skia`, `fast_image_resize` (brush dynamics reference: ISC `libmypaint`) | `T0.2-01`, `T0.4-02`, `T0.4-03` |
| `v0.5` | `vello` (GPU vectors), `kurbo` (Bézier intersections/offsets), `rstar` (R\*-tree index) | `T0.5-01`, `T0.5-02` |
| `v0.6` | `i_overlay` (panel polygon slicing & booleans), `parley` + `harfrust` (text shaping) | `T0.6-01`, `T0.6-03` |
| `v0.7–v0.9` | `rusqlite`, `zstd` / `lz4_flex`, `psd`, `moxcms` (or C `lcms2` for print CMYK) | `T0.7-01`, `T0.7-02`, `T0.9-01` |
| `v1.0–v1.3` | `LiteRT-LM` + **Gemma 4 E2B/E4B** (Apache 2.0), `gltf` (3D figure), `gtk4-rs` (Linux) | `T1.0-04`–`T1.3-03` |

---

## 2. Pre-1.0 Engineering Tasks (`v0.1` – `v0.9`)

### `v0.1` — Tri-App Modular Core, Low-Latency Canvas, Dual Presets & i18n Base

| Task ID | Subproject / Tag | Module | Engineering Scope | Status / Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.1-01` | `[S2 Manga]` `[Dual]` | `core/manga-core` | Sparse `256×256` CoW tile store (`TileLayer`), Rope Stabilizer (`RopeStabilizer`), and incremental undo (`TileUndoStack`) | ✅ Landed & unit-tested |
| `T0.1-02` | `[S1/S2/S3]` `[Dual]` | `core/manga-core` + `apps/apple` | Expose C-ABI static/dynamic endpoints (`ffi.rs`, `include/manga_core.h`, `platform.rs`, `suite.rs`), Swift RAII bridge (`MangaCoreBridge.swift`), and Cargo feature slices (`hub`/`canvas`/`novel`) | ✅ Rust C-ABI (`staticlib` + `cdylib`), 3 feature slices & FFI lifecycle tests landed |
| `T0.1-03` | `[S2 Manga]` `[Dual]` | `core/manga-gpu` | Implement `wgpu` (Metal backend) dirty-tile texture upload & fullscreen viewport compositor shader | ⏳ Pending macOS/Xcode Metal device integration |
| `T0.1-04` | `[S2 Manga]` `[Dual]` | `apps/apple` | Implement UIKit `MetalCanvasView` host capturing 240Hz `coalescedTouches`, `predictedTouches` overlay, and Palm Rejection | ⏳ `ApplePencilInputAdapter.swift` ready; pending Metal view wiring |
| `T0.1-05` | `[S2 Manga]` `[Dual]` | `core` + `apps/apple` | **Dual New-Canvas Presets** (B4/A4 600DPI guides, 800/1600 Webtoon, 4K) & `CanvasSession` viewport/stroke loop | ✅ Rust `preset.rs` + `canvas.rs` landed & unit-tested |
| `T0.1-06` | `[S1 Hub]` `[i18n]` | `i18n/` + `scripts/` + `core` | 5-language glossary, working-codename UI keys, `i18n_check.py`, `i18n_sync.py` (Apple `.xcstrings` + Android `strings.xml`), and `.prj` overview parser | ✅ Landed & enforced in GitHub Actions CI |
| `T0.1-07` | `[S3 Novel]` `[Dual]` | `core/manga-core` + `apps/*` | Standalone light-novel boot mode (`--features novel` / `SuiteApp::Novel`, zero GPU canvas init) & `.prj` outline/prose path binding contract | ✅ `SuiteApp::Novel` + Linux standalone shell verified; frontend editor UI pending |
| `T0.1-S4` | `[S4 Integration→PR]` | `core` + `apps/linux` + `.github/` | **v0.1 Tri-App Integration & Compatibility Gate**: verify all 3 standalone Cargo feature builds, `suite.rs` write-ownership matrix, `templates/SampleManga` compatibility self-check & CI enforcement before PR | ✅ `suite.rs` + Cargo feature slices + `manga-linux-shell --integration-check` landed & enforced in CI |

### `v0.2` — Anime Brush Engine, Hub Overview Shell & Light Novel Base Editor

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.2-01` | `[S2 Manga]` `[Dual]` | `core/manga-gpu` | GPU brush stamping pipeline (tip texture, spacing interpolation, hardness, rotation, flow/opacity) | Smooth 120fps stamping with 200px brush |
| `T0.2-02` | `[S2 Manga]` `[Dual]` | `core/manga-core` | Bézier response curve engine for pressure, tilt, velocity, and Apple Pencil Pro `roll_angle` | Deterministic bit-identical stroke replay |
| `T0.2-03` | `[S2 Manga]` `[B&W Manga]` | `core/manga-core` | Tuned G-Pen / Maru entry-exit taper physics & zoom-adaptive Rope Stabilizer | Jitter-free slow hair curves verified in blind artist tests |
| `T0.2-04` | `[S2 Manga]` `[Color Webtoon]` | `core/manga-gpu` | Solid cel flatting pen, soft airbrush, and wet-blend brush presets (8 starter brushes) | Crisp solid edges without muddy halos; band-free airbrush gradients |
| `T0.2-05` | `[S1 Hub]` `[Dual]` | `apps/apple` + `core` | Project overview grid, new `.prj` wizard (Dual-Track / Dual-Engine templates) & read-only chapter/page thumbnail browser | Cold start `< 500ms`, peak RAM `< 180 MB` |
| `T0.2-06` | `[S3 Novel]` `[Dual]` | `apps/apple` + `core` | Plaintext/Markdown novel editor, live word counter, and read-only split view for `outline/synopsis.md` + `outline/toc.xml` | `120fps` scrolling on 100k-word chapter, RAM `< 100 MB` |
| `T0.2-S4` | `[S4 Integration→PR]` | `core` + `apps/*` | **v0.2 Tri-App Integration Revision**: verify Hub-created `.prj` opens cleanly in both Manga and Novel apps with zero lock contention before unified PR | 100 consecutive cross-app open/save cycles with 0 corruption |

### `v0.3` — Cel Layer Stack, Series Bible Editor & Novel Scene Sync

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.3-01` | `[S2 Manga]` `[Color Webtoon]` | `core/manga-core` | Hierarchical layer tree (raster, folders, Clipping Mask, Alpha Lock, Reference flag, non-destructive blue sketch tint) | ✅ `layer.rs` (`LayerStack`, clipping masks, alpha lock, blue tint) landed & unit-tested |
| `T0.3-02` | `[S2 Manga]` `[Color Webtoon]` | `core/manga-gpu` | 12+ WGSL blend modes (Multiply, Screen, Overlay, Glow Dodge, Linear Burn, Hard Light, Hue/Sat) | ⏳ 13 reference CPU blend modes (`blend_rgba`) landed; WGSL port pending |
| `T0.3-03` | `[S2 Manga]` `[Dual]` | `core/manga-core` | Upgrade `TileUndoStack` to transactional multi-layer undo/redo (add/delete/reorder/merge) | ✅ Transactional `ActionUndoGroup` landed in `action_bus.rs` |
| `T0.3-04` | `[S1 Hub]` `[Dual]` | `apps/apple` + `core` | Visual editor for character bible (`bible/characters.xml`), worldbuilding entries & table of contents (`toc.xml`) | Character/TOC updates persist atomically into `.prj` and `toc.xml` |
| `T0.3-05` | `[S3 Novel]` `[Dual]` | `apps/apple` + `core` | Scene outline sidebar (`chapters/chXXX/scenes/`), read-only character bible drawer & non-blocking autosave | Scene navigation `< 50ms`; autosave never stalls IME |
| `T0.3-S4` | `[S4 Integration→PR]` | `core` + `apps/*` | **v0.3 Tri-App Integration Revision**: verify Hub bible/TOC edits live-refresh in concurrent Manga & Novel instances while respecting strict write-ownership partitions before PR | Zero concurrent overwrites; live-refresh latency `< 300ms` |

### `v0.4` — Selection/Anti-Halo Fill, Batch Asset Importer & Glossary Autocomplete

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.4-01` | `[S2 Manga]` `[Dual]` | `core/manga-core` | Lasso, rect/ellipse marquee, magic wand (reference-layer aware, GPU marching ants, expand/contract/invert) | Selection mask constrains both brushes and fills cleanly |
| `T0.4-02` | `[S2 Manga]` `[Color Webtoon]` | `core/manga-core` | **Headline Feature**: Scanline Close-Gap bucket fill (`1–8px`) + Edge Expand (`1–3px`) + enclose-and-fill lasso | ✅ `fill.rs` (`close_gap_expand_fill`, reference layers, 3px gap sealing & 1px expansion) landed & unit-tested |
| `T0.4-03` | `[S2 Manga]` `[Dual]` | `core/manga-gpu` | GPU bilinear/bicubic Free Transform (scale, rotate, 4-corner perspective) & basic Liquify mesh | Real-time 60–120fps preview writing back only dirty tiles on commit |
| `T0.4-04` | `[S1 Hub]` `[Dual]` | `core` + `apps/apple` | **Unified Script & Artwork Importer**: batch import Markdown/DOCX/TXT prose & scripts plus PNG/PSD/CLIP pages into structured CPFF chapters | Importing 50 pages + 10 chapters passes `prj_validate.py` cleanly |
| `T0.4-05` | `[S3 Novel]` `[i18n]` | `apps/apple` + `core` | Shared glossary (`i18n/dictionary.xml`) inline autocomplete & multi-locale novel split-file foundation | Proper-noun lookup across 5 locales; strictly read-only on `dictionary.xml` |
| `T0.4-S4` | `[S4 Integration→PR]` | `core` + `apps/*` | **v0.4 Tri-App Integration Revision**: E2E validation of Hub batch import → Manga flatting/painting → Novel revision round-trip before unified PR | 100% pixel, encoding, and directory parity across all 3 tools |

### `v0.5` — Vector Lineart/Rulers, Dual-Engine Episode Board & Divergence Notes

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.5-01` | `[S2 Manga]` `[B&W Manga]` | `core/manga-vector` | Variable-width centerline representation + GPU raster cache (lossless zoom & local width adjustment) | ✅ Core `VectorStroke` / lossless scale / local width edit (`vector.rs`) landed; `vello` GPU integration pending |
| `T0.5-02` | `[S2 Manga]` `[B&W Manga]` | `core/manga-vector` | **Vector Intersection Eraser**: exact intersection trimming (scale to 50k strokes with `rstar`) | ✅ `VectorLayer::erase_to_intersection` (X-overshoot & H-bridge splitting) landed & unit-tested |
| `T0.5-03` | `[S2 Manga]` `[Dual]` | `core/manga-core` | Ruler snapping pipeline: symmetry, parallel, 1/2/3-point perspective, concentric, and focus/speed lines | ✅ `ruler.rs` (symmetry mirror, parallel, 1/2/3-point perspective rays, focus lines) landed & unit-tested |
| `T0.5-04` | `[S1 Hub]` `[Dual]` | `apps/apple` + `core` | Serialized episode/chapter Kanban displaying side-by-side Manga manuscript progress and Light Novel prose status | Drag-reordering chapters atomically updates `.prj` and `toc.xml` |
| `T0.5-05` | `[S3 Novel]` `[Dual]` | `apps/apple` + `core` | Chapter `<DivergenceNote>` editor marking intentional plot/pacing adaptations between novel and manga editions | Persisted in `novel/novel_meta.xml`; both tracks evolve independently |
| `T0.5-S4` | `[S4 Integration→PR]` | `core` + `apps/*` | **v0.5 Tri-App Integration Revision**: verify chapter reordering/renaming preserves Manga asset links and Novel `<DivergenceNote>` references with zero broken paths before PR | 100% pass on chapter-reorder & rename regression suite |

### `v0.6` — Panels/Screentones/Bubbles/Slicer, Multi-Locale QA & Multilingual Novel

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.6-01` | `[S2 Manga]` `[B&W Manga]` | `core/manga-core` | Panel Frame Folders: straight/diagonal cuts, configurable gutters, automatic per-panel mask clipping | ✅ `panel.rs` (Sutherland-Hodgman straight/diagonal slicing, gutters & point masking) landed & exposed via C-ABI |
| `T0.6-02` | `[S2 Manga]` `[B&W Manga]` | `core/manga-gpu` | Procedural screentones (dots/lines/crosshatch/noise, live LPI, angle, density, 600DPI binary print) | ⏳ `screentone.rs` area-preserving halftone math landed & unit-tested; WGSL port pending |
| `T0.6-03` | `[S2 Manga]` `[Dual]` | `apps/apple` + `core` | Speech bubble presets + CoreText **vertical CJK (punctuation compression) & horizontal EN/ES** with locale-switchable text layers | Single page toggles cleanly across EN/CN/ES bubble sets |
| `T0.6-04` | `[S2 Manga]` `[Color Webtoon]` | `core/manga-io` | Webtoon mobile viewport frame preview + automated height slicing (e.g., `800×1280`) lossless batch export | ✅ `webtoon.rs` (slice calculator & zero-seam RGBA8 renderer) landed; PNG encoder wiring pending |
| `T0.6-05` | `[S1 Hub]` `[i18n]` | `apps/apple` + `core` | **Multi-Language Release Matrix**: unified inspector auditing 5-locale `i18n/dictionary.xml`, bubble translation gaps, and novel locale coverage | One-click highlight of missing translations and unlocked (`locked="false"`) terms |
| `T0.6-06` | `[S3 Novel]` `[i18n]` | `apps/apple` + `core` | 5-language novel prose editor (`novel/prose/<lang>.md`), vertical/horizontal reading preview, and manual lock protection | Smooth 5-locale split drafting; zero overwrites of locked prose |
| `T0.6-S4` | `[S4 Integration→PR]` | `core` + `apps/*` | **v0.6 Tri-App Integration Revision**: verify three-way consistency between Manga `script.xml` bubbles, Novel multilingual prose, and Hub 5-locale dictionary audit before PR | Zero locale drift across all 5 languages and multi-locale exports |

### `v0.7` — Open `.mnga`, PSD Interop, `ActionBus` & Multi-Edition Publishing

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.7-01` | `[S2 Manga]` `[Dual]` | `core/manga-io` | `.mnga` open archive (SQLite + Zstd tiles + JSON manifest + **continuity/script tables**) with incremental autosave & crash recovery | ⏳ Continuity SQLite DDL & model (`continuity.rs`) landed; `rusqlite`/`zstd` persistence pending |
| `T0.7-02` | `[S2 Manga]` `[Dual]` | `core/manga-io` | Clean-room MIT layered PSD codec (layer tree, blend modes, opacity, clipping masks, text metadata) | Visual parity when opened in CSP / Photoshop |
| `T0.7-03` | `[S2 Manga]` `[Dual]` | `core/manga-core` | **Deterministic `ActionBus`**: whitelisted commands, dry-run preview, and atomic single-step `UndoGroup` rollback | ✅ `action_bus.rs` (`ActionBus`, `ProjectDocument`, Gemma 4 batch test) landed & unit-tested |
| `T0.7-04` | `[S2 Manga]` `[Dual]` | `core/manga-io` | Lightweight Timelapse keyframe capture & background MP4 export | `< 2%` frame-rate overhead while drawing |
| `T0.7-05` | `[S1 Hub]` `[Dual]` | `core/manga-core` + `scripts/` | **CPFF v1.0 Publishing & Git Collaboration Hub**: same-name `.prj` codec, GitHub/GitLab+LFS sync, rights/doujin declarations & **multi-edition / multi-language batch release packager** | ✅ `project.rs` + `templates/SampleManga/` + `prj_validate.py` landed; release packager lands in `v0.7` |
| `T0.7-06` | `[S3 Novel]` `[Dual]` | `core/manga-io` + `apps/apple` | **Light Novel Illustration Manager & EPUB3/Markdown Publisher**: supports `CuratedMangaPages` or custom `novel/illustrations/` artwork | Generated EPUB3 passes `epubcheck` with lossless artwork links |
| `T0.7-S4` | `[S4 Integration→PR]` | `core` + `apps/*` | **v0.7 Tri-App Integration Revision**: verify Hub orchestrating Manga print/Webtoon slices + Novel EPUB3 into unified multi-locale release bundles alongside Git+LFS sync before PR | Automated multi-edition release build & validation passes 100% |

### `v0.8` – `v0.9` — Wave 1 Apple Trio Touch/Foldable Ergonomics (iPad · Touch MacBook · iPhone Duo) & Beta

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.8-01` | `[S2 Manga]` `[Dual]` | `apps/apple` | iPad gestures (2/3-finger undo/redo, long-press picker) + Apple Pencil Pro Squeeze radial menu & Hover cursor outline | 80% of frequent actions performed without touching top toolbar |
| `T0.8-02` | `[S2 Manga]` `[Dual]` | `apps/apple` | Floating Reference Window (eyedropper-enabled) + Bluetooth keyboard & one-handed gamepad remapping | Import/export custom keymap profiles |
| `T0.8-03` | `[S1/S2/S3]` `[i18n]` | `apps/apple` + `i18n/` | In-app 5-language live switcher across all 3 tools (with `zh-HK → yue-Hant` fallback) + glossary-locked auto-sync | Instant live switching without restart; zero missing keys across all 3 apps |
| `T0.8-04` | `[S1/S2/S3]` `[Multi-Platform]` | `apps/apple/macOS-Touch` | **Touchscreen MacBook Adaptation**: standalone/multi-window launch; direct-touch palm rejection + `tabletPoint` in Manga, keyboard+touch hybrid in Hub & Novel | ✅ Input adapter scaffold (`MacTouchInputAdapter.swift` + `project.yml`) landed; pending device bring-up |
| `T0.8-05` | `[S1/S2/S3]` `[Multi-Platform]` | `apps/apple/iPhoneDuo` | **iPhone Duo Foldable Adaptation**: folded posture favors lightweight one-handed Novel writing & Hub overview ↔ unfolded hinge-aware dual-pane creation | ✅ Posture scaffold (`IphoneDuoPostureAdapter.swift` + `platform.rs`) landed; pending device bring-up |
| `T0.9-01` | `[S2 Manga]` `[Dual]` | `core/manga-core` | LRU Zstd disk tile paging & Jetsam memory-pressure eviction handler | 2h zero-crash soak on 8GB iPad for both B4 600DPI (50 layers) & `1600×25600` Webtoon |
| `T0.9-02` | `[S1/S2/S3]` `[i18n]` | `apps/apple` | 5-language zero-truncation screenshot QA for all 3 apps across iPad 11" Split View, Touch MacBook, and iPhone Duo folded/unfolded postures | Zero truncated buttons or overlapping text across all 3 apps × 3 Apple form factors |
| `T0.9-S4` | `[S4 Integration→PR]` `[Multi-Platform]` | `apps/apple` + `core` | **v0.9 Wave 1 Apple Trio × Tri-App Integration Gate & Beta PR**: verify 8GB concurrent 3-app RAM coexistence, Deep-Link handoffs (`noemadock://` ↔ `draconib://` ↔ `litteracore://`), cross-device `.prj` Git handoff & `.ipa`/`.dmg` Beta packaging | Zero OOM under 3-app soak & 100% Deep-Link accuracy prior to Wave 1 Beta PR |

---

## 3. 1.x Engineering Tasks (Dual-Engine + Embedded Gemma 4 + Wave 2 Cross-Platform)

### `v1.0` — Pro UI Overhaul + Dual-Engine Novel × Manga Studio (Apple Trio Official Launch)

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T1.0-01` | `[S1/S2/S3]` `[Dual]` | `apps/apple` | Unified Pro Design System across all 3 tools (OLED Dark / Studio Gray / Light themes, left/right-handed layout, crisp custom icon set) | Visual design & 5-language layout audit sign-off across all 3 apps |
| `T1.0-02` | `[S1 Hub]` `[Local AI]` | `apps/apple` + `ai/local-llm` | **Dual-Engine Control Center & Local Gemma 4 Runtime Hub**: opt-in download/verification for **Gemma 4 E2B (8GB) / E4B (16GB+)**, batch bidirectional AI draft triggers, 120s idle auto-unload & memory eviction | Fully offline inference; `0 MB` RAM when unloaded; single shared model weight cache across all 3 apps |
| `T1.0-03` | `[S3 Novel]` `[Local AI]` | `apps/apple` + `ai/dual-bridge` | **Official Light Novel Studio + "Manga → Novel" AI Reference Split Writer**: Gemma 4 reads manga panels + `script.xml` read-only and outputs reference prose to `ai_assist/manga_to_novel/` (`role="ai_reference_only"`), displayed beside an independent human editor & EPUB3 publisher | Never writes into `novel/prose/`; AI intermediates preserved for history; human final may diverge freely |
| `T1.0-04` | `[S2 Manga]` `[Local AI]` | `apps/apple` + `ai/dual-bridge` | **Official Manga Canvas + "Novel → Manga" AI Storyboard/Rough Overlay**: Gemma 4 reads novel prose read-only and outputs storyboard/panel drafts to `ai_assist/novel_to_manga/` as an optional translucent reference overlay; human manuscript may diverge completely | Never writes into `manuscript/`; dual guard in validator & Rust core |
| `T1.0-05` | `[S1/S2/S3]` `[Dual]` | `apps/apple` | **Concurrent Tri-App Split-Screen & Deep-Link Focus Switching**: seamless side-by-side operation across iPad Stage Manager, Touch MacBook multi-window & iPhone Duo unfolded dual-pane | `< 100ms` handoff preserving viewport, brush & editor cursor |
| `T1.0-S4` | `[S4 Integration→PR]` `[Multi-Platform]` | `core` + `apps/apple` + `ai/` | **v1.0 Official Release Tri-App Master Integration Gate**: full `ai_assist/` red-line audit, dual-engine decoupling regression, shared Gemma 4 OOM stress test, **plus final CN/EN/ES brand-name confirmation PR** before issuing the official `v1.0` Apple Trio Release PR | Zero AI boundary violations, all 3 apps × 3 Apple targets green, final brand names signed off |

### `v1.1` — Android Pad / Foldable Edition + Gemma 4 Voice Continuity & Flatting / LT

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T1.1-01` | `[S1 Hub]` `[Local AI]` | `ai/script-supervisor` + `apps/android` | **Android Hub + Intelligent Continuity Master**: wired to `.mnga`/`.prj` continuity logs, respecting `<DivergenceNote>`, with foldable episode board & multi-language release hub | Sub-second cross-device continuity sync; Android cold start `< 600ms` |
| `T1.1-02` | `[S2 Manga]` `[B&W/Color]` `[Local AI]` | `ai/vision` + `apps/android` | **Android Manga + Semantic Flatting & Offline LT**: Jetpack Compose + S-Pen/M-Pencil/USI `FrontBufferedRenderer` + Vulkan `wgpu`; quantized `MobileSAM`/`SAM2-Tiny` multi-layer flatting + offline Photo/3D-to-Manga 3-layer LT | Single-character anime lineart flatted in 3–6s; 2K photo LT in `< 5s` offline |
| `T1.1-03` | `[S3 Novel]` `[Local AI]` | `ai/story-planner` + `apps/android` | **Android Novel + Voice Continuity Dictation & 5-Locale Polish**: foldable cover-screen one-handed drafting/voice memo structuring, `i18n/dictionary.xml` localization check strictly protecting `locked="true"` | Voice memos structured within 3s; `100%` glossary adherence, zero locked overwrites |
| `T1.1-S4` | `[S4 Integration→PR]` `[Multi-Platform]` | `apps/android` + `core` | **v1.1 Android Tri-App Integration Revision**: verify Android multi-window/foldable (`FoldingFeature` / Tabletop) concurrent `.prj` access, App Links handoffs & `libmanga_core.so` RAM footprint before PR | Zero state loss across fold/unfold transitions; all 3 Android apps green prior to `v1.1` PR |

### `v1.2` — Touchscreen Windows Edition + Gemma 4 Workflow Driver & Cleanup / Cel Shade

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T1.2-01` | `[S1 Hub]` `[Multi-Platform]` | `apps/windows` + `core` | **Windows Hub**: WinUI 3 + `manga_core.dll` P/Invoke delivering multi-project overview, batch script/art import, visual Git+LFS sync & multi-edition packager | Full touch + mouse/keyboard hybrid; standalone or suite MSIX install |
| `T1.2-02` | `[S2 Manga]` `[Local AI]` `[Multi-Platform]` | `apps/windows` + `ai/` | **Windows Manga + Gemma 4 Action Driver & Cleanup/Cel Shade**: `WM_POINTER`/Windows Ink palm rejection + DX12 `wgpu`; `ActionBus` voice/text batch macros, sketch-to-vector cleanup + `< 4px` Gap Radar, 3D Light-Sphere cel shading | `≥ 95%` accuracy on 10 batch tasks with single-undo; light-sphere preview `≥ 30fps` |
| `T1.2-03` | `[S3 Novel]` `[Local AI]` `[Multi-Platform]` | `apps/windows` + `ai/` | **Windows Novel + Gemma 4 Lore/Timeline Checker**: automatic 2-in-1 tablet-mode proofreading layout + whole-volume character/timeline consistency scan against shared bible | 100k-word volume check in `< 5s` without mutating unapproved prose |
| `T1.2-S4` | `[S4 Integration→PR]` `[Multi-Platform]` | `apps/windows` + `core` | **v1.2 Windows Tri-App Integration Revision**: verify WinUI 3 multi-window & 2-in-1 tablet transitions, custom URI protocol handoffs & Windows file-sharing locks under concurrent 3-app load before PR | Zero sharing-violation errors & clean MSIX Tri-App bundle prior to `v1.2` PR |

### `v1.3` – `v1.4` — Touchscreen Linux Edition, 3D Mannequin, Vision Critic & ComfyUI Bridge

| Task ID | Subproject / Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T1.3-01` | `[S1 Hub]` `[Multi-Platform]` | `apps/linux` + `core` | **Linux Hub + Multi-Volume Serialization Master**: native Rust GTK4/Wayland shell managing 32+ page spreads/binding, multi-episode Webtoons & multi-volume novel schedules | 32-page project switching `< 150ms`; offline Flatpak/AppImage ready |
| `T1.3-02` | `[S2 Manga]` `[Multi-Platform]` `[Local AI]` | `apps/linux` + `ai/` | **Linux Manga + 3D Mannequin, Vision Critic & ComfyUI Bridge**: `zwp_tablet_v2` + `libinput` + Vulkan `wgpu`; 5–8 head 3D pose mannequin synced to perspective rulers; Gemma 4 non-destructive continuity critic; LAN ComfyUI BYOK bridge | Continuity critic emits pins without mutating canvas; ComfyUI maps cleanly to new layer or `ai_assist/` |
| `T1.3-03` | `[S3 Novel]` `[Multi-Platform]` `[Local AI]` | `apps/linux` + `ai/` | **Linux Novel + Cross-Volume Foreshadowing Auditor**: lightweight native GTK4 authoring & multi-volume EPUB3/Print PDF preview, allowing LAN BYOK concept art strictly into `ai_assist/` for illustration reference | Strict `ai_assist/` isolation; consistent multi-volume layout output |
| `T1.3-S4` | `[S4 Integration→PR]` `[Multi-Platform]` | `apps/*` + `core` | **v1.3–v1.4 Six-Platform × Tri-App Matrix Integration Gate**: verify Linux Wayland `xdg-open` handoffs and full cross-platform `.prj` interop across all 6 hardware targets (iPad / Touch MacBook / iPhone Duo / Android / Windows / Linux) × 3 tools before PR | 100% green 6-platform × 3-app interop matrix prior to `v1.3`/`v1.4` PR |
