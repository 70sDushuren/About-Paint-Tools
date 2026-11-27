# Cloud Dev Log (`ops/cloud-dev-log/CLOUD_DEV_LOG.md`)

> **Ownership Rule (Zero-Conflict Protocol)**:
> - **Cloud Agent ONLY** appends entries (reverse chronological) to this file (`ops/cloud-dev-log/CLOUD_DEV_LOG.md`).
> - **Local Xcode / Mac Agent ONLY** reads this file for handoff context and writes its own local device log to `ops/local-dev-log/IPAD_MAC_DEV_LOG.md`.

---

## 2026-11-27 11:35 PST — Formalized Dual-Agent Collaboration Skill (`cloud-local-dual-agent-collab`) & Bilingual Doc 11

- **Base Commit**: Built on top of Local Mac verification commit `74ca465` (48/48 Apple Silicon XCTests PASS + physical iPad Pro 13" M5 deployed!)
- **FFI Rebuild Required**: **NO** (docs & skill only; no changes to `core/manga-core/` or `apps/apple/` — `git pull --rebase` is sufficient).
- **Added / Updated Files**:
  - `skills/cloud-local-dual-agent-collab/SKILL.md` (canonical dual-agent collaboration skill, also registered globally as `cloud-local-dual-agent-collab`)
  - `docs/zh-CN/11-cloud-local-dual-agent-collaboration.md` (Simplified Chinese spec)
  - `docs/en/11-cloud-local-dual-agent-collaboration.md` (1:1 English mirror)
  - `docs/bilingual/11-cloud-local-dual-agent-collaboration-bilingual.md` (Bilingual side-by-side edition + prompt templates + glossary)
  - `README.md` & `README.zh-CN.md` (indexed Doc 11 and reusable skill)
- **Note for Local Xcode Agent**: Going forward, follow `skills/cloud-local-dual-agent-collab/SKILL.md` as our shared collaboration baseline (read `CLOUD_DEV_LOG.md` on pull, rebuild XCFramework whenever `build-rust --force` is flagged, keep `LocalSigning.xcconfig` gitignored, append to `IPAD_MAC_DEV_LOG.md`, and push via `make push`).

---

## 2026-11-27 10:45 PST — `v1.0.0-rc5` Cloud Handoff: Floating Selection Transform, 2-Finger Canvas Rotation, Multi-Canvas Gallery & Photo Import

- **Base Commit**: Built cleanly on top of Local Mac commit `e3eeb98` (`ops/local-dev-log/IPAD_MAC_DEV_LOG.md` Entry #1)
- **Target Priority**: Physical **iPad Pro 13-inch (M5)** + Apple Pencil Pro (backward compatible with `MangaStudio-macOS-Touch` & `MangaStudio-iPhoneDuo`)
- **IMPORTANT BUILD NOTE FOR LOCAL XCODE / MAC AGENT**:
  - **Rust `core/manga-core` and C11 header `core/manga-core/include/manga_core.h` were updated with 2 new FFI symbols!**
  - You **MUST** rebuild the 3-slice `MangaCore.xcframework` before building/running in Xcode:
    ```bash
    git pull --rebase
    ./scripts/dev.sh build-rust --force
    ./scripts/dev.sh xcode-gen
    ```
    *(Or run `make sync` + `./scripts/dev.sh build-rust --force` if timestamp stamp is unchanged.)*

### 1. Three Completed Cloud Upgrades

#### ① 选区局部像素独立浮动自由变形 (`Floating Selection Pixel Transform`)
Directly resolves the Cloud follow-up item noted in `ops/local-dev-log/IPAD_MAC_DEV_LOG.md`:
- **Rust Core** (`core/manga-core/src/filters.rs`, `core/manga-core/src/selection.rs`, `core/manga-core/src/lib.rs`):
  - Added `SelectionMask::set(x, y, selected)` and `transform_selected_pixels_affine(layer, selection, dx, dy, scale_x, scale_y, rot_deg, clear_source)`.
  - Extracts ONLY pixels inside `selection` into a floating buffer, optionally clears their source footprint (`clear_source = true` for Cut-Move; `false` for Copy-Stamp), bilinearly composites back onto `layer` while leaving unselected pixels **100% untouched**, and updates `selection` in place so marching ants and subsequent fills/transforms stay aligned.
- **C11 ABI & Swift Bridge** (`core/manga-core/include/manga_core.h`, `core/manga-core/src/ffi.rs`, `apps/apple/Shared/Sources/MangaCoreBridge.swift`):
  - `manga_project_transform_selected_pixels_affine(handle, layer_id, dx, dy, scale_x, scale_y, rot_deg, clear_source)`
  - `MangaProjectEngine.transformSelectedPixelsAffine(layerId:dx:dy:scaleX:scaleY:rotDeg:clearSource:)`
- **Controller & UI** (`StudioWorkspaceController.swift`, `MangaCanvasStageView.swift`):
  - Upgraded `applyAffineTransform(dx:dy:scaleX:scaleY:rotDeg:selectionOnly:clearSource:)` (defaults `selectionOnly` to `s2TransformSelectionOnly` when `s2HasActiveSelection == true`) and syncs `s2SelectionRectNorm` / `s2SelectionLassoNorm` overlays with the transform.
  - Upgraded `transformInteractiveBar` with **`选区局部变形` / `整层变形`** toggle pill and **`剪切移动` / `✓ 保留原图(复制)`** Copy-Stamp toggle pill.

#### ② 画布双指自由旋转 (`2-Finger Canvas Rotation` + Magnetic Detent + Unified UIKit Multi-Touch)
- **iPadOS UIKit Touch Surface** (`apps/apple/iPadOS/ApplePencilInputAdapter.swift`):
  - Added `UIRotationGestureRecognizer` (`handleTwoFingerRotate`) and `UIPinchGestureRecognizer` (`handleTwoFingerPinch`) working simultaneously with `twoFingerPan` via `UIGestureRecognizerDelegate` (`allowedTouchTypes = [.direct]`, so Apple Pencil strokes never conflict).
  - Includes subtle `±4°` magnetic snap at cardinal angles (`0°`, `±90°`, `±180°`) and updates `controller.s2RotationDeg` in real time.
- **Viewport & Navigator** (`StudioWorkspaceController.swift`, `MangaCanvasStageView.swift`):
  - Guarded SwiftUI `.simultaneousGesture(MagnificationGesture())` with `#if !os(iOS)` to prevent double-pinching on iPadOS while keeping macOS trackpad pinch intact.
  - Added `rotateCanvas(by:)` & `resetRotation()` helpers and a compact **`↺ -15°` | `0°` live angle pill | `↻ +15°`** rotation strip directly on `floatingCanvasPanControlPad`.

#### ③ 多画布画廊 + 新建画布预设 + 相册照片导入到图层/参考浮窗 (`Multi-Canvas Gallery & Photo Import`)
- **Rust C11 FFI** (`core/manga-core/src/filters.rs`, `ffi.rs`, `manga_core.h`, `MangaCoreBridge.swift`):
  - Added `import_rgba_to_layer` / `manga_project_import_rgba_to_layer(...)` bilinearly scaling and blitting any RGBA8 image buffer into a Rust raster layer.
- **Controller** (`StudioWorkspaceController.swift`):
  - Added `CanvasSizePresetOption` (B5 `800×1132`, A4 `1000×1414`, B4 `1200×1698`, 16:9 `1920×1080`, 1:1 `1200×1200`, Webtoon `800×2400` + custom `256...4096`) and `CanvasGalleryItem`.
  - Added `refreshCanvasGallery()`, `createNewCanvasProject(...)`, `switchToCanvasProject(dir:)`, `duplicateCanvasProject(dir:)`, `deleteCanvasProject(dir:)`, plus automatic `.about-paint-thumb.png` thumbnail generation on `flushAllSync()` and persisted `s2CanvasPixelWidth` / `s2CanvasPixelHeight` in `.about-paint-session.json`.
  - Added `importImageDataAsNewLayer(_:layerName:)` (decodes via `ImageIO`, un-premultiplies, aspect-fits, blits into a new Rust layer) and `importReferenceImageData(_:)` / `clearReferenceImage()` (persisted as `reference_image.png` inside `activeProjectDir`).
- **UI** (`MangaCanvasStageView.swift`):
  - Added 1-tap **Gallery (`square.grid.2x2.fill`)** button at top of `ibisToolRail` and in `More` menu opening `canvasGallerySheetView` (preset chips, custom W×H, live thumbnail cards, Duplicate/Delete/Switch, and direct `PhotosPicker` buttons for **导入相册图片为新图层** & **导入相册到参考浮窗**).
  - Upgraded `floatingReferenceWindow` to render `controller.s2ReferenceImage ?? controller.s2CompositeImage` with inline `PhotosPicker` ("从相册载入参考图") and "清除恢复总览" buttons.

### 2. Files Modified / Added in Cloud
- `core/manga-core/src/selection.rs`
- `core/manga-core/src/filters.rs` (+2 new Rust unit tests)
- `core/manga-core/src/lib.rs`
- `core/manga-core/src/ffi.rs`
- `core/manga-core/include/manga_core.h`
- `apps/apple/Shared/Sources/MangaCoreBridge.swift`
- `apps/apple/Shared/Sources/StudioWorkspaceController.swift`
- `apps/apple/Shared/Sources/MangaCanvasStageView.swift`
- `apps/apple/iPadOS/ApplePencilInputAdapter.swift`
- `apps/apple/Shared/Tests/MangaStudioV100Rc5IpadTests.swift` (3 new live XCTests)
- `ops/cloud-dev-log/CLOUD_DEV_LOG.md`

### 3. Verification Checklist for Local Xcode / Physical iPad Pro 13" (M5)
1. Rebuild XCFramework (`./scripts/dev.sh build-rust --force`) and regenerate project (`./scripts/dev.sh xcode-gen`).
2. Run macOS XCTests (`MangaStudio-macOS-Tests`, now 48 tests including `MangaStudioV100Rc5IpadTests`) and verify zero Swift 6 strict concurrency errors on `MangaStudio-iPadOS`, `MangaStudio-macOS-Touch`, and `MangaStudio-iPhoneDuo`.
3. Deploy to physical iPad Pro 13" (M5) (`make run-ipad-device` with local `NSB5UZC327` signing in `LocalSigning.xcconfig`) and test:
   - **Floating Selection Transform**: Lasso part of a drawing → tap Transform → verify **选区局部变形** moves/rotates ONLY the selected pixels while unselected art stays untouched, and test **保留原图(复制)** Copy-Stamp mode.
   - **2-Finger Canvas Rotation + Pinch + Pan**: Rotate canvas freely with 2 fingers simultaneously while panning/zooming, verify `±4°` snap at `0°/±90°/180°`, verify Apple Pencil draws accurately at rotated angles (e.g. 35°), and verify `-15° / 0° / +15°` strip on bottom-right pad.
   - **Gallery + Photo Import**: Tap top-left Gallery icon → create a new B4 (`1200×1698`) or 16:9 (`1920×1080`) canvas → switch back & forth between canvases (verify thumbnails & state survival) → import a real photo from iPad Photos into a new layer AND into the Floating Reference Window!
4. Record verification results & any tactile/gesture tweaks back into `ops/local-dev-log/IPAD_MAC_DEV_LOG.md` and push with `make push`.
