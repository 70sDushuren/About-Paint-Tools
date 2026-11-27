# iPad Pro & Mac Local Device Dev Log

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
