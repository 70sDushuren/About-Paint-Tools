# iPad Pro & Mac Local Device Dev Log

## 2026-11-27 16:45 CST — v1.0.0-rc5+ 图层自定义重命名（上下移动保持不变）与 ibisPaint 标准套索/选区工作流修订 (Physical iPad Pro 13" M5)

- **测试设备**：iPad Pro 13" (M5) (`iPad (103)` via USB-C 真机部署)
- **修复问题清单**：
  1. **各图层支持自定义名称且在上下移动及重启恢复时绝不改变 (`Custom Layer Renaming & Invariant Preservation Across Up/Down Reordering`)**：
     - 在 `StudioWorkspaceController.swift` 中新增 `renameLayer(id:newName:)` 与 `addLayer(customName:)`，支持对任意图层自定义命名并纳入单步 Undo/Redo 快照与 `.about-paint-session.json` 持久化。
     - 在 `CelLayerDrawerView.swift` 中提供多入口一键重命名（顶部工具栏 `pencil` 按钮、当前图层控制卡 `重命名` 按钮、每行图层右侧铅笔图标、以及长按 `.contextMenu`），点击即可在图层行内联弹出 `TextField` 直接输入新名称并回车确认。
     - 移除原先在图层名称前缀拼接的动态序号 `#\(index + 1)` 徽标，并将所有图层属性修改闭包改为按稳定的 `item.id` 索引，同时修复 `ensureRustCanvasAndLayersInitialized()` 在加载重排过顺序的图层时按递增 ID (`1, 2, 3...`) 覆盖图层 ID 的问题，确保无论如何上下移动图层或重启恢复，各图层的自定义名称与绑定像素 100% 保持不变。
  2. **对齐 ibisPaint X (爱笔思画) 的套索与选区特性及操作习惯 (`ibisPaint-Aligned Lasso & Selection Workflow`)**：
     - **3 种 ibisPaint 套索工作模式 (`S2LassoWorkMode`)**：
       - **自由选区 (`Lasso`, `.selection`)**：手绘闭合虚线选区（实时渲染自动闭合预览线与半透明选区底色）。
       - **套索填色 (`Lasso Fill`, `.lassoFill`)**：还原 ibisPaint 标志性的“套索填色”速涂功能，圈出闭合区域松手即自动填充当前前景色与不透明度，无需二次点击油漆桶（且不破坏原有选区）。
       - **套索橡皮 (`Lasso Eraser`, `.lassoEraser`)**：圈出闭合区域松手即精准擦除区域内像素。
     - **3 种布尔选区组合模式 (`S2SelectionCombineMode`)**：支持 **`新选区` (`.replace`)**、**`+ 加选` (`.add`)**、**`- 减选` (`.subtract`)**（套索与矩形选框均适用，通过零宽桥接边在 Rust 奇偶扫描线掩码中实现并集与挖洞减选，并在圈选过程中保持已有选区高亮显示）。
     - **选区内直接拖动平移像素 & 轻点取消选区 (`Direct On-Canvas Drag-to-Move Inside Selection & Tap-to-Deselect`)**：
       - 新增 `isNormalizedPointInsideActiveSelection(_:)` 精确奇偶射线命中判定；在套索/选框工具下开启 `选区内拖动直接移动像素`（或在 `变形 T` 工具下）时，直接在画布选区内单指或 Apple Pencil 拖动即可实时预览选区位移并在松手时执行局部像素平移（或开启 `复制移动 Clone` 进行局部复制盖章）；轻点画布空白处（移动距离 `< 2px`）即可像 ibisPaint 一样一键取消选区。
     - **大选区 100% 均匀填色与擦除 (`Scanline Sweep Fill/Erase Bypassing 256px Radius Clamp`)**：修复原先单圆点涂抹受限于 Rust `radius_px.clamp(0.5, 256.0)` 导致大尺寸选区四角填色/擦除不全的问题，改为 `160px` 硬边扫描线遍历整个选区包围盒，确保任意尺寸选区 100% 均匀填色与擦除。
- **验证结果**：
  - `MangaStudio-macOS-Tests`：`MangaStudioV100Rc5IpadTests` 全部 **9 项测试 100% 通过 (`0 failures`)**，含新增的 `testCustomLayerRenamePreservedAcrossMoveUpDownUndoRedoAndSessionReload` 与 `testIbisPaintLassoModesAddSubtractFillEraseAndInsideHitTest`。
  - 已通过 `devicectl` 将最新 `MangaStudio-iPadOS.app` 安装至物理 `iPad (103)` (`org.aboutpainttools.mangastudio.ipad`)。
- **涉及修改的文件清单**：
  - `apps/apple/Shared/Sources/CelLayerDrawerView.swift`
  - `apps/apple/Shared/Sources/StudioWorkspaceController.swift`
  - `apps/apple/Shared/Sources/MangaCanvasStageView.swift`
  - `apps/apple/iPadOS/ApplePencilInputAdapter.swift`
  - `apps/apple/Shared/Tests/MangaStudioV100Rc5IpadTests.swift`
  - `ops/local-dev-log/IPAD_MAC_DEV_LOG.md`

---

## 2026-11-27 15:05 CST — v1.0.0-rc5+ 顶栏固定 LED 保存指示灯 + 悬浮 Hint、多图层上下顺序调整与 60FPS 零阻塞绘制性能优化 (Physical iPad Pro 13" M5)

- **测试设备**：iPad Pro 13" (M5) (`iPad (103)` via USB-C 真机部署启动)
- **修复问题清单**：
  1. **第一行顶栏固定尺寸 LED 保存状态灯 + 悬浮 Hint 提示 (`Fixed-Position Top Bar Save LED Indicator & Floating Hint Toast`)**：
     - 将 `AppleWorkspaceShell.swift` 顶栏原本随 `"Saved HH:mm:ss"` / `"Unsaved…"` 文本长度变化导致整行控件左右跳动的文字胶囊，替换为严格固定尺寸 (`30×26pt`) 的 **LED 状态呼吸灯胶囊** (`saveStatusLedIndicatorButton`)，同时将语言胶囊与 `?` 提示胶囊固定为 `42×26pt`，确保第一行所有显示项目位置完全固定、互不影响。
     - 当存在未保存修改 (`hasUnsavedChanges == true`) 时，橙色 LED 呈亮暗交替呼吸闪烁；已保存时呈常亮翠绿色。点击 LED（或开启 `?` Hint 模式）时，在顶栏右下方以独立悬浮层 (`floatingSaveStatusHintToast`, `.zIndex(99)`) 展示详细保存状态并立即执行保存，2.4 秒后自动渐隐，完全不挤压第一行布局。
  2. **多图层上下调整位置与堆叠次序 (`Multi-Layer Stack Reordering Up / Down`)**：
     - 在 `CelLayerDrawerView.swift` 顶部工具栏新增专用的 **上移一层 (`arrow.up`)** 与 **下移一层 (`arrow.down`)** 快捷按钮，并增加直观的 `"堆叠次序 (上层遮挡下层) · 上移 ▲ / 下移 ▼"` 说明栏。
     - 为每个图层行标注 `#1..#N` 层级序号徽标，将图层行右侧的上下移动按钮放大为适合 iPad 触控的 `24×26pt` 并排独立胶囊按钮（高亮当前可移动方向），同时支持长按上下文菜单 (`.contextMenu`) 一键上移、下移、复制、清空或删除图层，并与 Rust `LayerStack` 及单步 Undo/Redo 完整同步。
  3. **彻底消除连续绘制与手势操作中的卡顿、响应延迟叠加与死机 (`60FPS Throttled Compositing, Sub-Pixel Filtering, Zero-Copy Metal CGImage & Idle-Aware Auto-Save`)**：
     - **60FPS 节流合成与精简 `@Published` 广播**：修复 `ApplePencilInputAdapter.swift` 在 240Hz `touchesMoved` 下每帧无节制执行全画布 `makeCGImage` 及重复写入 6 个 `@Published` 属性导致 SwiftUI 主线程重绘风暴的问题。新增 `refreshCompositeImage(interactive: true)`（限制合成频率不高于 60FPS `16ms` 并带尾帧补齐）及 `0.45px` 亚像素冗余采样过滤。
     - **零拷贝 Metal `CGImage` 上传**：在 `MangaCoreBridge.swift` 中缓存静态 `sRGB` 色彩空间，并对不透明背景合成图采用 `CGImageAlphaInfo.noneSkipLast | CGBitmapInfo.byteOrder32Big` + `.interpolation(.low)`，消除 iPadOS CoreAnimation 每帧在主线程通过 CPU 执行 `vImagePremultiplyData_RGBA8888` 软件预乘的开销。
     - **交互感知空闲自动保存**：移除高频滑杆/手势属性（`s2BrushSize`、`s2BrushOpacity`、`s2StabilizerPx`、`s2ViewportZoom`、`s2PanOffset`、`s2RotationDeg`）上的 `didSet { scheduleAutoSave() }`，引入 `isCanvasInteractionActive` 标志位并将自动保存防抖设为 `3.2s` 且仅在非交互空闲时触发（跳过后台自动保存时的 PNG 缩略图重编码），彻底避免落笔中途主线程同步写盘 (`fsync`) 造成的等待时间叠加与假死。
- **验证结果**：
  - `MangaStudio-macOS-Tests` 全量 **52 项单元测试 100% 通过 (`0 failures`)**，含新增的 `testMultiLayerStackOrderMoveUpDownAndThrottledInteractiveComposite`。
  - 已通过 `devicectl` 安装并启动至物理 `iPad (103)` (`org.aboutpainttools.mangastudio.ipad`)。
- **涉及修改的文件清单**：
  - `apps/apple/Shared/Sources/AppleWorkspaceShell.swift`
  - `apps/apple/Shared/Sources/CelLayerDrawerView.swift`
  - `apps/apple/Shared/Sources/MangaCoreBridge.swift`
  - `apps/apple/Shared/Sources/StudioWorkspaceController.swift`
  - `apps/apple/Shared/Sources/MangaCanvasStageView.swift`
  - `apps/apple/iPadOS/ApplePencilInputAdapter.swift`
  - `apps/apple/Shared/Tests/MangaStudioV100Rc5IpadTests.swift`
  - `ops/local-dev-log/IPAD_MAC_DEV_LOG.md`

---

## 2026-11-27 14:30 CST — v1.0.0-rc5+ iPadOS 笔刷/橡皮尺寸可视化、图层删除像素清理与 Undo/Redo 同步修订 (Physical iPad Pro 13" M5)

- **测试设备**：iPad Pro 13" (M5) (`iPad (103)` via USB-C 真机部署启动 `pid: 1207`)
- **修复问题清单**：
  1. **笔刷与橡皮尺寸实时可视化 (`Brush & Eraser Size Visualizer Icon & On-Canvas HUD`)**：
     - 在左侧快捷滑条 (`leftQuickCaliperStrip`) 及顶部聚焦调参栏 (`focusedSizeSliderCluster`) 中新增实时尺寸预览圆标 (`brushSizeVisualizerBadge`)，随滑杆动态呈现笔刷当前颜色圆点直径或橡皮虚线圆环尺寸。
     - 当调节笔刷/橡皮/涂抹半径滑杆时，画布中央自动浮现 1:1 缩放比例的半透明准星圆环预览 HUD (`brushSizeCanvasPreviewHUD`, `s2ShowBrushSizePreviewHUD`)，直观可视化真实落笔直径并在停止调节 0.9 秒后自动渐隐（`allowsHitTesting(false)` 不遮挡绘画）。
  2. **删除图层时彻底清除该图层画布像素 (`Delete Layer Pixel Cleanup & ID Reconciliation`)**：
     - 修复 `deleteSelectedLayer()` 与 `CelLayerDrawerView`：删除图层时同步执行 Rust `clearLayer(layerId:)` + `deleteLayer(layerId:)` 并立即刷新合成图；当仅剩 1 个图层点击删除按钮时自动清空并重置该图层像素；在会话恢复 (`ensureRustCanvasAndLayersInitialized`) 时严格对齐 Swift `s2CelLayers[i].id` 与 Rust `LayerStack` 的真实 `LayerId`，并将默认 `Cel_Shadow` 的初始 `clippingMask` 设为 `false`，避免图层 ID 漂移导致删层后笔迹残留。
  3. **Undo / Redo 精准回退每一步操作 (`Synchronized Step-by-Step Undo / Redo`)**：
     - 在 `ApplePencilTouchCanvasUIView` 中区分 Apple Pencil 与手指触控：手指 `.direct` 触控延迟至确认单指滑动 (`touchesMoved`) 或单指轻点落笔时才开启 `beginRasterUndoCheckpoint()`，并在双指点按撤销 (`twoFingerUndo`)、双指平移/缩放/旋转触发时自动回滚未完成的试探单指状态 (`abortTentativeFingerStrokeIfNeeded()`)，彻底杜绝双指手势落指时间差向 Undo 栈压入空快照导致“Undo 无法回到上一步”的问题。
     - 在 `StudioWorkspaceController` 中引入与 Rust `pushUndoSnapshot` / `undoSnapshot` / `redoSnapshot` 1:1 同步的 `swiftUndoLayerStack` / `swiftRedoLayerStack`，使新增/复制/删除/合并/清空图层与笔刷绘画、填色、变形、滤镜全部支持精准单步 Undo / Redo。
- **验证结果**：
  - `MangaStudio-macOS-Tests` 全量 **51 项单元测试 100% 通过 (`0 failures`)**，含新增的 `testBrushAndEraserSizeChangeTriggersPreviewVisualizerHUD`、`testDeleteSelectedLayerRemovesLayerPixelsAndSurvivesSessionRestore` 与 `testSynchronizedUndoRedoRevertsStrokesAndLayerDeletionsStepByStep`。
  - 已通过 Xcode `RunProject` 真机安装并启动至物理 `iPad (103)`。
- **涉及修改的文件清单**：
  - `apps/apple/Shared/Sources/MangaCanvasStageView.swift`
  - `apps/apple/Shared/Sources/StudioWorkspaceController.swift`
  - `apps/apple/Shared/Sources/CelLayerDrawerView.swift`
  - `apps/apple/iPadOS/ApplePencilInputAdapter.swift`
  - `apps/apple/Shared/Tests/MangaStudioV100Rc5IpadTests.swift`
  - `ops/local-dev-log/IPAD_MAC_DEV_LOG.md`

---

## 2026-11-27 13:30 CST — v1.0.0-rc5 云端三项升级接力验证与真机部署 (Physical iPad Pro 13" M5)

- **基线提交**：接力云端 `01d93c2` (`ops/cloud-dev-log/CLOUD_DEV_LOG.md` `v1.0.0-rc5`)
- **测试设备**：iPad Pro 13" (M5) (`iPad (103)` via USB-C 真机部署 & `devicectl` 签名安装启动)
- **所属阶段**：`v1.0.0-rc5` 选区局部浮动自由变形、画布双指旋转与多画布画廊/相册导入验证

### 1. 本地接力编译小修与三切片 XCFramework 重建
1. **强制重编 3-Slice `MangaCore.xcframework`**：
   - 执行 `./scripts/dev.sh build-rust --force` 与 `./scripts/dev.sh xcode-gen`，将新增的 2 个 Rust C11 FFI 符号 (`manga_project_transform_selected_pixels_affine` 与 `manga_project_import_rgba_to_layer`) 完整打包进 `aarch64-apple-ios`、`aarch64-apple-ios-sim`、`aarch64-apple-darwin` 三切片框架。
2. **修复 Swift 6 枚举成员引用小瑕疵**：
   - 在 `apps/apple/Shared/Sources/StudioWorkspaceController.swift` 的 `CanvasSizePresetOption.allPresets` 中，将条漫长卷预设使用的 `.webtoonStrip` 修正为 `CanvasPresetKind.webtoonStrip800`，使 `MangaStudio-iPadOS`、`MangaStudio-macOS-Touch`、`MangaStudio-iPhoneDuo` 三个 Target 及 `MangaStudio-macOS-Tests` 在 Swift 6 严格并发下 100% 零报错零警告编译通过。

### 2. 测试套件与真机实测结果
- **macOS 单元测试套件 (`MangaStudio-macOS-Tests`)**：
  - 共 **48 项 XCTest 全部通过 (`0 failures`)**，其中新增的 `MangaStudioV100Rc5IpadTests` 三项核心测试全部绿灯：
    - `testCanvasRotationNormalizationAndResetViewport` (`0.001s`)
    - `testFloatingSelectionPixelTransformPreservesUnselectedAndSupportsCopyStamp` (`0.016s`)
    - `testPhotoImportToNewRustLayerAndReferenceImage` (`0.191s`)
- **物理 iPad Pro 13" (M5) (`iPad (103)`) 真机部署与验证**：
  - 使用本地已忽略的 `LocalSigning.xcconfig` (`DEVELOPMENT_TEAM = NSB5UZC327`) 执行 `make run-ipad-device`，成功编译、签名 (`Apple Development`)、安装并启动 `org.aboutpainttools.mangastudio.ipad` (`databaseSequenceNumber: 2020`)。
  - **通过项**：
    1. **选区局部像素浮动自由变形 (`Floating Selection Pixel Transform`)**：圈选局部选区后开启自由变换栏，可切换 **`选区局部变形` / `整层变形`** 与 **`剪切移动` / `保留原图(复制)`**，仅对选区内像素做位移/缩放/旋转，未选中区域像素保持完好。
    2. **画布双指自由旋转 + 捏合缩放 + 双指平移**：UIKit 触控层同时识别 `UIRotationGestureRecognizer`、`UIPinchGestureRecognizer` 与 `UIPanGestureRecognizer`（限定 `.direct` 手指触控，与 Apple Pencil 笔迹零冲突），`0° / ±90° / ±180°` 具备 `±4°` 磁吸停靠，右下角悬浮盘亦提供 `↺ -15° | 0° | ↻ +15°` 快捷旋转条。
    3. **多画布画廊 (`Canvas Gallery`) 与相册照片导入 (`PhotosPicker`)**：左上角画廊入口可一键新建 B5 / A4 / B4 / 16:9 / 1:1 / Webtoon 画布、切换历史作品缩略图，并支持从 iPad 系统相册导入图片为新图层或载入参考浮窗 (`Reference Window`)。

### 3. 涉及修改的文件清单
- `apps/apple/Shared/Sources/StudioWorkspaceController.swift` (修正 `.webtoonStrip800` 枚举名)
- `ops/local-dev-log/IPAD_MAC_DEV_LOG.md` (追加本次 `v1.0.0-rc5` 真机验证记录)

---


## 2026-11-27 12:22 CST — v1.0.0-rc4+ iPadOS 体验打磨 (Physical iPad Pro 13" M5)

- **测试设备**：iPad Pro 13" (M5) (`iPad (103)` via USB-C 真机部署 & 240Hz Apple Pencil Pro / Touch 交互测试)
- **所属阶段**：`v1.0.0-rc4+` iPadOS 端侧体验打磨与交互优化

### 1. 本次解决的问题与体验优化点
1. **套索 (`Lasso`) / 选区交互闭环与实时可视化**：
   - 修复了 iPadOS UIKit 触控层 (`ApplePencilTouchCanvasUIView`) 此前未将实时套索顶点 (`s2LiveLassoNorm`) 与矩形框选坐标 (`s2LiveMarqueeStartNorm` / `s2LiveMarqueeCurrentNorm`) 同步至 SwiftUI 画布覆盖层的问题；现在圈选时实时渲染半透明高亮填充与双色虚线轨迹。
   - 新增 **选区激活工作流栏 (`activeSelectionWorkflowBar`)** 及两步操作引导提示：圈选完成后画布上方自动弹出选区操作栏，支持一键 **填色 (`Fill`)**、**清除像素 (`Erase`)**、**向外扩大 `+6px`**、**向内收缩 `-6px`**、**反选 (`Invert`)**、**贴网点 (`Tone`)**、**在选区内绘画**、**自由变换图层** 与 **取消选区**。
2. **绘图工具专属聚焦属性栏 (`focusedToolTuningBar`)**：
   - 重构顶部工具属性栏，选中每个绘图工具后仅单独 Focus 该工具对应的核心性能与参数调节组件（如 `Brush` 聚焦笔刷预设/粗细/不透明度/抖动修正/起笔渐细/形状辅助；`Eraser` 聚焦大小/擦除力度/稳定器/清空图层；`Smudge`/`Blur` 聚焦作用半径/混色强度/平滑；`Bucket` 聚焦封口间隙 Gap/扩张 Expand；`Magic Wand` 聚焦魔棒容差 Tolerance；`Panel Knife` 聚焦分格间距 Gutter；`Ruler` 聚焦尺规模式胶囊切换），低频项收纳至右侧 `More` 菜单，消除选项堆叠混乱。
3. **画布全方位自由平移 (`2-Finger Pan` + `Hand Pan Tool` + 悬浮方向盘)**：
   - 在 `ApplePencilTouchCanvasUIView` 中新增双指平移手势 (`UIPanGestureRecognizer`, `minimumNumberOfTouches = 2`)，任意工具下均可随时使用双指拖动平滑上下左右移动画布（并与双指捏合缩放协同）。
   - 新增 `.handPan` (**抓手平移工具**)，选中后支持单指或 Apple Pencil 直接拖动平移画布。
   - 在画布右下角新增悬浮方向控制盘 (`←` / `↑` / `↓` / `→` + `居中` 一键归位)。
4. **小说与漫画画布同屏双创 (`S2+S3 同屏双创 / Dual Novel + Manga Split`)**：
   - 在顶部主导航栏 (`S1 Hub | S2 Manga | S3 Novel` 旁) 及画布左侧工具栏新增一键 **`S2+S3 同屏双创`** 入口，无需进入二级菜单即可在 iPad 屏幕上左右并排同时打开小说文稿 (`S3 Novel`) 与漫画画布 (`S2 Manga`)。
   - 新增分屏控制条，支持 `35:65` / `42:58` / `50:50` 比例快捷切换、左右面板互换、拖拽分割条调整宽度及一键返回单画布视图。
5. **吸色器 (`Eyedropper`) 真实像素提取与高对比放大镜准星 HUD**：
   - 升级 `sampleEyedropper(canvasX:canvasY:)`，优先采样 Rust 图层像素并回退读取 `compositeRGBA(backdropCode:)` 合成缓冲区，确保草稿蓝线着色层、22 种图层混合模式及纸张背景色均可真实准确提取，提取后自动更新当前色块并置顶到最近色板 (`s2RecentColors`)。
   - 同步 iPadOS 触控坐标 `s2EyedropperLoupeNorm`，点按或拖动吸色时在触点上方实时显示高对比十字准星放大镜圆环与 `#RRGGBB` 色值标签，松手后默认自动切回画笔 (`s2EyedropperAutoSwitchToBrush`)。
6. **App Icon 资源集成**：
   - 新增全出血动漫奇幻风格 `AppIcon.appiconset` (`Shared/Resources/Assets.xcassets`) 并接入 `iPadOS`、`iPhoneDuo` 与 `macOS-Touch` 工程配置。

### 2. 涉及修改的文件清单
- `apps/apple/Shared/Sources/StudioWorkspaceController.swift`
- `apps/apple/Shared/Sources/MangaCanvasStageView.swift`
- `apps/apple/Shared/Sources/AppleWorkspaceShell.swift`
- `apps/apple/iPadOS/ApplePencilInputAdapter.swift`
- `apps/apple/Shared/Resources/Assets.xcassets/AppIcon.appiconset/*`
- `apps/apple/project.yml`
- `ops/local-dev-log/IPAD_MAC_DEV_LOG.md`

### 3. 真机实测结果
- **通过项**：
  - `MangaStudio-iPadOS` 在物理设备 `iPad (103)` (iPad Pro 13" M5) 上编译、签名、安装与启动全部通过。
  - 套索实时轨迹显示、选区一键填色/擦除/扩缩 (`+6px`/`-6px`)/反选/网点填充实测通过。
  - 各绘图工具选中后顶部属性栏单独聚焦对应性能参数滑块，无文字截断或重叠。
  - 双指拖动平移画布、抓手工具平移、右下角悬浮方向盘及一键居中归位实测顺畅。
  - `S2+S3 同屏双创` 一键开启小说与画布左右分屏、比例切换与左右互换实测通过。
  - 吸色器实时放大镜准星 HUD 预览、真实合成颜色提取与自动切回画笔实测通过。
- **仍待云端 / 后续配合项**：
  - 目前套索选区像素的“独立浮动自由变形 (`Floating Selection Pixel Transform`)”在 Rust `manga-core` FFI 层仍为整层仿射变换 (`manga_project_transform_layer_affine`)；若后续需要仅针对选区内局部像素做独立旋转/缩放浮动图层，可在云端 Rust `manga-core` 补充 `transform_selected_pixels_affine` FFI 接口后与端侧选区栏无缝对接。
