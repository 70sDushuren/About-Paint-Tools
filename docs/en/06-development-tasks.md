# 06. Detailed Engineering Task Breakdown (Work Breakdown Structure)

**Language / 语言**: **English** | [简体中文](../zh-CN/06-development-tasks.md)

---

## 1. Track Tags

This document decomposes [04. Phased Development Roadmap](./04-roadmap.md) into atomic, issue-ready engineering tasks:
- `[Dual]`: Core foundation shared by both B&W Page Manga and Full-Color Webtoon/Illustration
- `[B&W Manga]`: Focused on B4 600DPI print sheets, vector ink, panel frames, procedural screentones, and vertical CJK bubbles
- `[Color Webtoon]`: Focused on cel-shading blend modes, anti-halo close-gap flatting, vertical long strips, and seamless slicing
- `[Local AI]`: Embedded local Gemma 4 (E2B/E4B) Script Supervisor, Story Planner, Function-Calling driver, and on-device vision tools
- `[i18n]`: 5-language (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`) localization & adaptive layout QA

### MIT-Compatible Graphics Library Integration Map (see [02. Architecture RFC](./02-architecture-and-tech-stack.md#4-high-performance-open-source-graphics-libraries-rust--c--mit-compliance))

| Milestone | Key Permissive Crates / Libs | Accelerated Tasks |
| :--- | :--- | :--- |
| `v0.1` | `wgpu`, `glam`, `swift-bridge` / `uniffi` | `T0.1-02`, `T0.1-03` |
| `v0.2–v0.4` | `rayon`, `tiny-skia`, `fast_image_resize` (brush dynamics reference: ISC `libmypaint`) | `T0.2-01`, `T0.4-02`, `T0.4-03` |
| `v0.5` | `vello` (GPU vectors), `kurbo` (Bézier intersections/offsets), `rstar` (R\*-tree index) | `T0.5-01`, `T0.5-02` |
| `v0.6` | `i_overlay` (panel polygon slicing & booleans), `parley` + `harfrust` (text shaping) | `T0.6-01`, `T0.6-03` |
| `v0.7–v0.9` | `rusqlite`, `zstd` / `lz4_flex`, `psd`, `moxcms` (or C `lcms2` for print CMYK) | `T0.7-01`, `T0.7-02`, `T0.9-01` |
| `v1.1–v1.3` | `LiteRT-LM` + **Gemma 4 E2B/E4B** (Apache 2.0), `gltf` (3D anime mannequin) | `T1.1-01`–`T1.2-01`, `T1.3-01` |

---

## 2. Pre-1.0 Engineering Tasks (`v0.1` – `v0.9`)

### `v0.1` — Low-Latency Canvas Core, Dual Presets & i18n Base

| Task ID | Tag | Module | Engineering Scope | Status / Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.1-01` | `[Dual]` | `core/manga-core` | Sparse `256×256` CoW tile store (`TileLayer`), Rope Stabilizer (`RopeStabilizer`), and incremental undo (`TileUndoStack`) | ✅ Landed & unit-tested |
| `T0.1-02` | `[Dual]` | `core/manga-core` + `apps/ipad` | Expose C-ABI staticlib endpoints (`ffi.rs`, `include/manga_core.h`) & Swift RAII bridge (`MangaCoreBridge.swift`) | ✅ Rust C-ABI, C header, Swift bridge & FFI lifecycle test landed |
| `T0.1-03` | `[Dual]` | `core/manga-gpu` | Implement `wgpu` (Metal backend) dirty-tile texture upload & fullscreen viewport compositor shader | ⏳ Pending macOS/Xcode Metal device integration |
| `T0.1-04` | `[Dual]` | `apps/ipad` | Implement UIKit `MetalCanvasView` host capturing 240Hz `coalescedTouches`, `predictedTouches` overlay, and Palm Rejection | ⏳ `ApplePencilInputAdapter.swift` ready; pending Metal view wiring |
| `T0.1-05` | `[Dual]` | `core` + `apps/ipad` | **Dual New-Canvas Presets** (B4/A4 600DPI guides, 800/1600 Webtoon, 4K) & `CanvasSession` viewport/stroke loop | ✅ Rust `preset.rs` + `canvas.rs` landed & unit-tested |
| `T0.1-06` | `[i18n]` | `i18n/` + `scripts/` | 5-language glossary, seed catalogs, `i18n_check.py`, plus `scripts/i18n_sync.py` exporting `Localizable.xcstrings` | ✅ Landed & enforced in GitHub Actions CI |

### `v0.2` — Anime Brush Engine & Stabilization

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.2-01` | `[Dual]` | `core/manga-gpu` | GPU brush stamping pipeline (tip texture, spacing interpolation, hardness, rotation, flow/opacity) | Smooth 120fps stamping with 200px brush |
| `T0.2-02` | `[Dual]` | `core/manga-core` | Bézier response curve engine for pressure, tilt, velocity, and Apple Pencil Pro `roll_angle` | Deterministic bit-identical stroke replay |
| `T0.2-03` | `[B&W Manga]` | `core/manga-core` | Tuned G-Pen / Maru entry-exit taper physics & zoom-adaptive Rope Stabilizer | Jitter-free slow hair curves verified in blind artist tests |
| `T0.2-04` | `[Color Webtoon]` | `core/manga-gpu` | Solid cel flatting pen, soft airbrush, and wet-blend brush presets (8 starter brushes) | Crisp solid edges without muddy halos; band-free airbrush gradients |

### `v0.3` — Cel Layer Stack, Masks & Blend Modes

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.3-01` | `[Color Webtoon]` | `core/manga-core` | Hierarchical layer tree (raster, folders, Clipping Mask, Alpha Lock, Reference flag, non-destructive blue sketch tint) | ✅ `layer.rs` (`LayerStack`, clipping masks, alpha lock, blue tint) landed & unit-tested |
| `T0.3-02` | `[Color Webtoon]` | `core/manga-gpu` | 12+ WGSL blend modes (Multiply, Screen, Overlay, Glow Dodge, Linear Burn, Hard Light, Hue/Sat) | ⏳ 13 reference CPU blend modes (`blend_rgba`) landed; WGSL port pending |
| `T0.3-03` | `[Dual]` | `core/manga-core` | Upgrade `TileUndoStack` to transactional multi-layer undo/redo (add/delete/reorder/merge) | ✅ Transactional `ActionUndoGroup` landed in `action_bus.rs` |

### `v0.4` — Selection, Free Transform & Anti-Halo Bucket Fill

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.4-01` | `[Dual]` | `core/manga-core` | Lasso, rect/ellipse marquee, magic wand (reference-layer aware, GPU marching ants, expand/contract/invert) | Selection mask constrains both brushes and fills cleanly |
| `T0.4-02` | `[Color Webtoon]` | `core/manga-core` | **Headline Feature**: Scanline Close-Gap bucket fill (`1–8px`) + Edge Expand (`1–3px`) + enclose-and-fill lasso | ✅ `fill.rs` (`close_gap_expand_fill`, reference layers, 3px gap sealing & 1px expansion) landed & unit-tested |
| `T0.4-03` | `[Dual]` | `core/manga-gpu` | GPU bilinear/bicubic Free Transform (scale, rotate, 4-corner perspective) & basic Liquify mesh | Real-time 60–120fps preview writing back only dirty tiles on commit |

### `v0.5` — Vector Lineart Layer & Manga Rulers

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.5-01` | `[B&W Manga]` | `core/manga-vector` | Variable-width centerline representation + GPU raster cache (lossless zoom & local width adjustment) | ✅ Core `VectorStroke` / lossless scale / local width edit (`vector.rs`) landed; `vello` GPU integration pending |
| `T0.5-02` | `[B&W Manga]` | `core/manga-vector` | **Vector Intersection Eraser**: exact intersection trimming (scale to 50k strokes with `rstar`) | ✅ `VectorLayer::erase_to_intersection` (X-overshoot & H-bridge splitting) landed & unit-tested |
| `T0.5-03` | `[Dual]` | `core/manga-core` | Ruler snapping pipeline: symmetry, parallel, 1/2/3-point perspective, concentric, and focus/speed lines | ✅ `ruler.rs` (symmetry mirror, parallel, 1/2/3-point perspective rays, focus lines) landed & unit-tested |

### `v0.6` — Panel Frames, GPU Screentones, Multilingual Bubbles & Webtoon Slicer

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.6-01` | `[B&W Manga]` | `core/manga-core` | Panel Frame Folders: straight/diagonal cuts, configurable gutters, automatic per-panel mask clipping | ✅ `panel.rs` (Sutherland-Hodgman straight/diagonal slicing, gutters & point masking) landed & exposed via C-ABI |
| `T0.6-02` | `[B&W Manga]` | `core/manga-gpu` | Procedural screentones (dots/lines/crosshatch/noise, live LPI, angle, density, 600DPI binary print) | ⏳ `screentone.rs` area-preserving halftone math landed & unit-tested; WGSL port pending |
| `T0.6-03` | `[Dual]` | `apps/ipad` + `core` | Speech bubble presets + CoreText **vertical CJK (punctuation compression) & horizontal EN/ES** with locale-switchable text layers | Single page toggles cleanly across EN/CN/ES bubble sets |
| `T0.6-04` | `[Color Webtoon]` | `core/manga-io` | Webtoon mobile viewport frame preview + automated height slicing (e.g., `800×1280`) lossless batch export | ✅ `webtoon.rs` (slice calculator & zero-seam RGBA8 renderer) landed; PNG encoder wiring pending |

### `v0.7` — Open `.mnga` Format, Layered PSD Interop & `ActionBus`

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.7-01` | `[Dual]` | `core/manga-io` | `.mnga` open archive (SQLite + Zstd tiles + JSON manifest + **continuity/script tables**) with incremental autosave & crash recovery | ⏳ Continuity SQLite DDL & model (`continuity.rs`) landed; `rusqlite`/`zstd` persistence pending |
| `T0.7-02` | `[Dual]` | `core/manga-io` | Clean-room MIT layered PSD codec (layer tree, blend modes, opacity, clipping masks, text metadata) | Visual parity when opened in CSP / Photoshop |
| `T0.7-03` | `[Dual]` | `core/manga-core` | **Deterministic `ActionBus`**: whitelisted commands, dry-run preview, and atomic single-step `UndoGroup` rollback | ✅ `action_bus.rs` (`ActionBus`, `ProjectDocument`, Gemma 4 batch test) landed & unit-tested |
| `T0.7-04` | `[Dual]` | `core/manga-io` | Lightweight Timelapse keyframe capture & background MP4 export | `< 2%` frame-rate overhead while drawing |
| `T0.7-05` | `[Dual]` | `core/manga-core` | **CPFF v1.0 Creative Project Framework**: same-name `.prj` XML codec, Git-clone rename fallback, editions & chapters (see [07. CPFF v1.0](./07-creative-project-framework-v1.md)) | ✅ `project.rs` + `templates/SampleManga/` landed & unit-tested |
| `T0.7-06` | `[Dual]` | `scripts/` + `templates/` | GitHub / GitLab repo scaffold (`.gitattributes` Git LFS / `.gitignore` / declarations) & `scripts/prj_validate.py` | ✅ Landed & enforced in GitHub Actions CI |

### `v0.8` – `v0.9` — Apple Pencil Pro, 5-Locale Polish & Dual-Track Beta

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T0.8-01` | `[Dual]` | `apps/ipad` | Procreate-grade gestures (2/3-finger undo/redo, long-press picker) + Apple Pencil Pro Squeeze radial menu & Hover cursor outline | 80% of frequent actions performed without touching top toolbar |
| `T0.8-02` | `[Dual]` | `apps/ipad` | Floating Reference Window (eyedropper-enabled) + Bluetooth keyboard & one-handed gamepad remapping | Import/export custom keymap profiles |
| `T0.8-03` | `[i18n]` | `apps/ipad` + `i18n/` | In-app 5-language live switcher (with `zh-HK → yue-Hant` fallback) + glossary-locked auto-sync script | Instant live switching without restart; zero missing keys |
| `T0.9-01` | `[Dual]` | `core/manga-core` | LRU Zstd disk tile paging & iPadOS Jetsam memory-pressure eviction handler | 2h zero-crash soak on 8GB iPad for both B4 600DPI (50 layers) & `1600×25600` Webtoon |
| `T0.9-02` | `[i18n]` | `apps/ipad` | 11-inch portrait & 1/3 Split View screenshot QA across ES / Cantonese / Traditional + `locked: true` layout tuning | Zero truncated buttons or overlapping text across all 5 locales |

---

## 3. 1.x Engineering Tasks (UI Overhaul + Embedded Gemma 4 + AI Suite)

### `v1.0` — Pro UI Overhaul & Dual Workspaces

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T1.0-01` | `[Dual]` | `apps/ipad` | Complete Design System (OLED Dark / Studio Gray / Light themes, left/right-handed layout, crisp custom icon set) | Visual design & 5-language layout audit sign-off |
| `T1.0-02` | `[Dual]` | `apps/ipad` | **One-Tap Dual Workspace**: *Focus Illustration/Webtoon Mode* ↔ *Manga Studio Mode* | `< 100ms` mode transition preserving viewport & active brush |

### `v1.1` — Embedded Gemma 4 (Phase 1: Continuity & Planning) + Flatting / LT

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T1.1-01` | `[Local AI]` | `ai/local-llm` | Integrate **LiteRT-LM / CoreML runtime** with opt-in download/verification for **Gemma 4 E2B (8GB) / E4B (16GB)**, 120s idle auto-unload, and memory-warning eviction | Fully offline inference; `0 MB` RAM when unloaded |
| `T1.1-02` | `[Local AI]` | `ai/script-supervisor` | **Intelligent Continuity Log**: wired to `.mnga` SQLite tables with cast/outfit/lighting/prop tracking & **Gemma 4 voice dictation structuring** | Voice memos parsed into structured page/panel logs within 3s |
| `T1.1-03` | `[Local AI]` | `ai/story-planner` | **Story & Storyboard Planner**: plot-to-panel script generation (B&W page or Webtoon pacing), one-tap scaffolding, and **5-language dialogue localization** | Generated breakdown scaffolds directly into canvas panel folders |
| `T1.1-04` | `[Color Webtoon]` | `ai/vision` | **On-Device Semantic Smart Flatting**: quantized CoreML `MobileSAM`/`SAM2-Tiny` multi-layer skin/hair/outfit fill with anti-halo expansion | Typical single-character anime lineart flatted in 3–6s offline |
| `T1.1-05` | `[B&W Manga]` | `ai/vision` | **Offline Photo/3D-to-Manga LT Conversion**: splits into editable lineart + procedural LPI screentone + solid shadow layers | 2K photo converted offline in `< 5s` with 3 fully editable layers |

### `v1.2` — Gemma 4 Workflow Driver + Sketch Cleanup & Cel Shading

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T1.2-01` | `[Local AI]` | `ai/workflow-driver` | **Gemma 4 Function-Calling Action Driver**: binds whitelisted `ActionBus` schemas for text/voice → `ActionPlan` preview → atomic single-undo execution | `≥ 95%` accuracy across 10 core manga batch tasks with 100% single-step rollback |
| `T1.2-02` | `[Dual]` | `ai/vision` | **Style-Preserving Sketch Cleanup → Vector Layer** + real-time `< 4px` Gap Radar overlay | Outputs standard editable vector layer compatible with intersection eraser |
| `T1.2-03` | `[Color Webtoon]` | `ai/vision` | **3D Light-Sphere Cel Shading Assist**: on-device normal estimation + live sphere drag preview + non-destructive `Multiply` & rim-light bake | Preview runs `≥ 30fps`; baked layers leave base flats untouched |

### `v1.3` – `v1.4` — 3D Mannequin, Multi-Page Studio, Vision Critic & ComfyUI Bridge

| Task ID | Tag | Module | Engineering Scope | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| `T1.3-01` | `[Dual]` | `apps/ipad` + `ai/vision` | Lightweight anime-proportioned 3D pose mannequin + photo/stick-figure pose capture + perspective ruler focal sync | 5–8 head ratio presets + hand pose library |
| `T1.3-02` | `[Dual]` | `core` + `apps/ipad` | Full Multi-Page chapter spread/binding manager & multi-episode Webtoon workspace | 32-page chapter switching responds in `< 150ms` |
| `T1.4-01` | `[Local AI]` | `ai/script-supervisor` | **Gemma 4 Vision Continuity Critic**: compares panel thumbnails with Character Reference Sheets & continuity DB, emitting dismissible pins | Flags missing accessories/eye-color mismatches without mutating canvas |
| `T1.4-02` | `[Local AI]` | `ai/bridge` | LAN **ComfyUI / OpenAI-Compatible BYOK Bridge** (selection export → remote run → new layer import) | Full custom workflow JSON mapping over LAN |
