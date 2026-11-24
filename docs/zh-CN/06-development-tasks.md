# 06. 开发任务细化清单（Engineering Work Breakdown Structure）

**语言 / Language**: [English](../en/06-development-tasks.md) | **简体中文**

---

## 1. 任务标签说明

本文档将 [04. 分阶段开发规划](./04-roadmap.md) 拆解为可直接排期、建 Issue 与验收的原子工程任务：
- `[双线]`：黑白页漫与全彩条漫/插画共同依赖的底座能力
- `[黑白页漫]`：侧重 B4 600DPI、矢量线稿、分格框、程序化网点纸与竖排气泡
- `[全彩条漫]`：侧重赛璐璐图层混合、防白边闭口填色、超长条漫画布与切片导出
- `[本地AI]`：内嵌本地 Gemma 4（E2B/E4B）场记/策划/Function Calling 驱动与端侧视觉辅助
- `[多端]`：六大触控/折叠硬件适配（波次一 `v0.9`/`v1.0`：iPad / 触摸屏 MacBook / iPhone Duo；波次二 `v1.1`–`v1.3`：Android / Windows / Linux）
- `[i18n]`：5 语言（`en` / `zh-Hans` / `zh-Hant` / `yue-Hant` / `es`）国际化与布局适配

### 推荐 MIT 兼容图形学库按版本引入映射（详见 [02. 架构 RFC](./02-architecture-and-tech-stack.md#4-高性能开源图形学库选型rust--c与-mit-协议合规评估)）

| 引入版本 | 核心引入库（均兼容 MIT 协议） | 直接加速的任务 ID |
| :--- | :--- | :--- |
| `v0.1` | `wgpu`、`glam`、`swift-bridge` / `uniffi` | `T0.1-02`、`T0.1-03` |
| `v0.2–v0.4` | `rayon`、`tiny-skia`、`fast_image_resize`（笔刷物理参考 ISC `libmypaint`） | `T0.2-01`、`T0.4-02`、`T0.4-03` |
| `v0.5` | `vello`（GPU 矢量）、`kurbo`（贝塞尔求交/偏置）、`rstar`（R\*-tree 空间索引） | `T0.5-01`、`T0.5-02` |
| `v0.6` | `i_overlay`（分格多边形斜切与布尔）、`parley` + `harfrust`（跨端塑形） | `T0.6-01`、`T0.6-03` |
| `v0.7–v0.9` | `rusqlite`、`zstd` / `lz4_flex`、`psd`、`moxcms`（或 C `lcms2` CMYK 校色） | `T0.7-01`、`T0.7-02`、`T0.9-01` |
| `v1.0–v1.3` | `LiteRT-LM` + **Gemma 4 E2B/E4B**（Apache 2.0）、`gltf`（3D 人偶）、`gtk4-rs`（Linux） | `T1.0-04`–`T1.3-03` |

---

## 2. Pre-1.0 细化工程任务（`v0.1` – `v0.9`）

### `v0.1` — 低延迟画布内核、双线模板与 i18n 基座

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 状态 / 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.1-01` | `[双线]` | `core/manga-core` | 稀疏 `256×256` CoW 瓦片存储（`TileLayer`）、拉绳防抖（`RopeStabilizer`）与增量撤销栈（`TileUndoStack`） | ✅ 已落地并通过单元测试 |
| `T0.1-02` | `[双线]` | `core/manga-core` + `apps/apple` | 导出 C-ABI 静态/动态库接口（`ffi.rs`、`include/manga_core.h`、`platform.rs`）与 Swift RAII 桥接（`MangaCoreBridge.swift`） | ✅ Rust C-ABI（`staticlib` + `cdylib`）、C 头文件、Swift 封装与端到端 FFI 单测已落地 |
| `T0.1-03` | `[双线]` | `core/manga-gpu` | 基于 `wgpu`（Metal 后端）实现脏瓦片上传与全屏视图矩阵合成着色器 | ⏳ 待在 macOS/Xcode 环境联调真机 Metal |
| `T0.1-04` | `[双线]` | `apps/apple` | 封装 UIKit `MetalCanvasView` 宿主：接入 `coalescedTouches`（240Hz）、`predictedTouches` 临时叠加与 Palm Rejection | ⏳ 已完成 `ApplePencilInputAdapter.swift`，待真机渲染联调 |
| `T0.1-05` | `[双线]` | `core` + `apps/apple` | 新建工程**双线画布预设**（B4/A4 600DPI 出血裁切 + 800/1600 条漫 + 4K 插画）与 `CanvasSession` 视口/落笔闭环 | ✅ Rust `preset.rs` + `canvas.rs` 已落地并通过单测 |
| `T0.1-06` | `[i18n]` | `i18n/` + `scripts/` | 5 语言术语词典、词条种子、CI 校验（`i18n_check.py`）与 `scripts/i18n_sync.py` 导出 Apple `.xcstrings` + Android `strings.xml` | ✅ 已落地并接入 GitHub Actions CI |

### `v0.2` — 二次元笔刷引擎与防抖系统

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.2-01` | `[双线]` | `core/manga-gpu` | 实现 GPU 笔刷盖章管线（笔尖灰度纹理、间距插值、硬度、旋转、透明度流控） | 200px 大笔刷连续快速涂抹无掉帧 |
| `T0.2-02` | `[双线]` | `core/manga-core` | 压感 / 倾角 / 速度 / Apple Pencil Pro `roll_angle` 映射贝塞尔响应曲线编辑器数据模型 | 同一笔迹回放输出像素完全确定性一致 |
| `T0.2-03` | `[黑白页漫]` | `core/manga-core` | 优化 G 笔 / 圆笔起收笔出锋算法与动态拉绳防抖（支持按缩放比自适应半径） | 慢速勾长发曲线无锯齿，画师盲测达标 |
| `T0.2-04` | `[全彩条漫]` | `core/manga-gpu` | 实现赛璐璐平涂实心笔、软喷枪与基础涂抹混色笔刷预设（内置 8 支标准笔刷包） | 实心笔无多余半透明毛边，喷枪过渡无明显色带 |

### `v0.3` — 赛璐璐图层栈、蒙版与混合模式

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.3-01` | `[全彩条漫]` | `core/manga-core` | 实现树状图层文档模型（普通层、文件夹、剪切蒙版、Alpha 锁定、参考层标记、草稿着染） | ✅ `layer.rs`（`LayerStack` / 剪切蒙版 / Alpha 锁 / 蓝稿着染）已落地并单测通过 |
| `T0.3-02` | `[全彩条漫]` | `core/manga-gpu` | 在 WGSL 合成管线中实现 12+ 常用混合模式（Multiply / Screen / Overlay / Glow Dodge / Linear Burn 等） | ⏳ Rust CPU 参考实现（13 种混合模式 `blend_rgba`）已落地，待移植至 WGSL |
| `T0.3-03` | `[双线]` | `core/manga-core` | 将 `TileUndoStack` 升级为多图层事务型撤销/重做（支持新建/删除/重排/合并图层回滚） | ✅ 已随 `ActionBus` 事务级 `ActionUndoGroup` 落地 |

### `v0.4` — 选区、自由变形与防白边闭口填色

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.4-01` | `[双线]` | `core/manga-core` | 实现套索、矩形/椭圆选区与魔棒（参考图层感知、蚁行线 GPU 叠加、反选/扩张/收缩） | 选区遮罩精确约束笔刷与填色区域 |
| `T0.4-02` | `[全彩条漫]` | `core/manga-core` | **核心亮点**：实现闭口识别扫描线油漆桶（Close Gap `1–8px`）+ 像素边缘扩张（Expand `1–3px`）+ 涂抹封闭区填色 | ✅ `fill.rs`（`close_gap_expand_fill` 参考层感知 + 3px 断口防漏 + 1px 防白边扩张）已落地并单测通过 |
| `T0.4-03` | `[双线]` | `core/manga-gpu` | GPU 双线性/双三次自由变换（缩放/旋转/透视四角拖拽）与基础液化推挤网格 | 实时 60–120fps 交互预览，确认后仅回写脏瓦片 |

### `v0.5` — 矢量线稿图层与漫画尺规

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.5-01` | `[黑白页漫]` | `core/manga-vector` | 可变线宽中心线数据结构与高质量 GPU 栅格化缓存（支持无损缩放与局部线宽调整） | ✅ 核心数据结构与无损缩放/局部线宽调节（`vector.rs`）已落地，待接入 `vello` GPU 渲染 |
| `T0.5-02` | `[黑白页漫]` | `core/manga-vector` | **矢量交点橡皮擦**：求取最近线段交点并精准裁剪出头段（后续大规模线稿接入 `rstar` 加速） | ✅ `VectorLayer::erase_to_intersection`（X 型出头裁剪 + H 型中段切分）已落地并单测通过 |
| `T0.5-03` | `[双线]` | `core/manga-core` | 尺规吸附管线：对称尺、平行尺、1/2/3 点透视尺、同心圆与漫画集中线/速度线生成器 | ✅ `ruler.rs`（对称镜像 + 平行 + 1/2/3 点透视射线吸附 + 集中线）已落地并单测通过 |

### `v0.6` — 分格框、非破坏性网点、多语气泡与条漫切片

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.6-01` | `[黑白页漫]` | `core/manga-core` | 分格框文件夹（Panel Frame Folder）：支持直线/斜切分格、自定义格间距（Gutter）与自动蒙版裁切 | ✅ `panel.rs`（Sutherland-Hodgman 水平/斜切分格 + Gutter 间距 + 格内蒙版判断）已落地并接入 C-ABI |
| `T0.6-02` | `[黑白页漫]` | `core/manga-gpu` | 程序化网点纸图层（圆点/线条/交叉线/噪点、LPI 线数、角度、浓度与 600DPI 二值导出） | ⏳ `screentone.rs` 面积守恒半调数学内核已落地并单测通过，待移植 WGSL |
| `T0.6-03` | `[双线]` | `apps/apple` + `core` | 气泡模板 + CoreText **中/日文竖排（含标点挤压）与英/西横排**排版引擎，支持按语言切换气泡文本层 | 同页可一键切换中/英/西多语种气泡并无损排版 |
| `T0.6-04` | `[全彩条漫]` | `core/manga-io` | 条漫（Webtoon）手机阅读安全框预览 + 自动按高度切片（如 `800×1280`）无损批量导出 | ✅ `webtoon.rs`（切片计算 + 无缝像素合成验证）已落地，待接入 PNG 编码写盘 |

### `v0.7` — 开放文档 `.mnga`、多层 PSD 互通与 `ActionBus`

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.7-01` | `[双线]` | `core/manga-io` | 定义并实现 `.mnga`（SQLite + Zstd 瓦片 + JSON 清单 + **场记/剧本扩展表**）增量自动保存与崩溃恢复 | ⏳ 场记 SQLite DDL 与内存模型（`continuity.rs`）已落地，待接入 `rusqlite`/`zstd` 落盘 |
| `T0.7-02` | `[双线]` | `core/manga-io` | Clean-room MIT 多层 PSD 编解码（图层树、混合模式、不透明度、剪切蒙版与文字元数据） | 导出 PSD 在 CSP / Photoshop 打开视觉一致 |
| `T0.7-03` | `[双线]` | `core/manga-core` | **确定性 `ActionBus` 命令总线**：定义白名单命令集、非破坏性 Dry-Run 预览与单步 `UndoGroup` 原子撤回 | ✅ `action_bus.rs`（`ActionBus` + `ProjectDocument` + Gemma 4 批处理单测）已落地 |
| `T0.7-04` | `[双线]` | `core/manga-io` | 轻量过程回放（Timelapse）关键帧采集与后台 MP4 导出 | 录制对绘制帧率影响 `< 2%` |
| `T0.7-05` | `[双线]` | `core/manga-core` | **CPFF v1.0 创作工程框架**：同名 `.prj` XML 读写、Git Clone 改名回退解析、多发行版与章节索引（见 [07. 创作工程文件框架 V1.0](./07-creative-project-framework-v1.md)） | ✅ `project.rs` + `templates/SampleManga/` 已落地并通过单测 |
| `T0.7-06` | `[双线]` | `scripts/` + `templates/` | GitHub / GitLab 兼容模板（`.gitattributes` Git LFS / `.gitignore` / 版权与同人声明）与自动化校验器 `prj_validate.py` | ✅ 已落地并接入 GitHub Actions CI |

### `v0.8` – `v0.9` — Apple 三端触控/折叠适配（iPad · 触摸屏 MacBook · iPhone Duo）、5 语言与 Beta

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.8-01` | `[双线]` | `apps/apple` | iPad 完整手势体系（双指撤回/三指重做/长按吸色）+ Apple Pencil Pro 轻捏径向快捷盘与悬停轮廓预览 | 80% 高频工具切换无需点击顶部栏 |
| `T0.8-02` | `[双线]` | `apps/apple` | 悬浮参考图小窗（可吸色/缩放）+ 蓝牙键盘与左手控制器快捷键映射 | 支持导出/导入快捷键配置文件 |
| `T0.8-03` | `[i18n]` | `apps/apple` + `i18n/` | 上线 5 语言应用内即时切换（含 `zh-HK → yue-Hant` 回退）与术语锁定自动同步脚本 | 5 语言实时切换无需重启 App，零缺词 |
| `T0.8-04` | `[多端]` | `apps/apple/macOS-Touch` | **触摸屏 MacBook 适配**：AppKit 直接屏幕多点触控防误触 + `tabletPoint` 压感 + 触控板手势 + 桌面键盘快捷键融合 | ✅ 输入适配骨架（`MacTouchInputAdapter.swift` + `project.yml`）已落地，待真机联调 |
| `T0.8-05` | `[多端]` | `apps/apple/iPhoneDuo` | **iPhone Duo 折叠双形态适配**：折叠态单手轻小说/语音场记/速写 ↔ 展开态双联对照工作区与铰链折痕避让安全区 | ✅ 姿态骨架（`IphoneDuoPostureAdapter.swift` + `platform.rs`）已落地，待真机联调 |
| `T0.9-01` | `[双线]` | `core/manga-core` | 瓦片虚拟内存磁盘换页（LRU 冷瓦片 Zstd 落盘）与 Jetsam 内存告警监听 | 8GB iPad 上 B4 600DPI 50 层与 `1600×25600` 彩漫双线连续 2h 零闪退 |
| `T0.9-02` | `[i18n]` | `apps/apple` | 5 语言在 iPad 11 寸分屏、触摸屏 MacBook 窗口与 iPhone Duo 折叠/展开态的全量截图防截断回归 QA | 三端 5 语言零按钮裁切、零文本重叠 |
| `T0.9-03` | `[多端]` | `apps/apple` | **Wave 1 Apple 三端联合 Beta 打包**：iPad（`.ipa`）、触摸屏 MacBook（`.dmg`）、iPhone Duo（`.ipa`）同步产出 TestFlight/公测包与跨设备 `.prj` Git 接力验收 | 三端同步稳定运行，同一 `.prj` 工程三端打开渲染 100% 一致 |

---

## 3. 1.x 细化工程任务（双引擎 + 本地 Gemma 4 + Wave 2 跨平台）

### `v1.0` — 整体 UI 升级 + 小说 × 漫画双引擎并进（Apple 三端正式版）

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T1.0-01` | `[双线]` | `apps/apple` | 全新设计系统（OLED 暗黑/护眼深灰/浅色主题、自定义左右手工作区、重构高辨识度图标库） | 视觉一致性与 5 语言排版全部通过定稿评审 |
| `T1.0-02` | `[双线]` | `apps/apple` | **三工作区模式一键切换**：*专注插画/条漫模式* ↔ *专业漫画工作台模式* ↔ **小说 × 漫画双引擎并行模式**（自适应三端屏幕与 iPhone Duo 铰链） | 切换耗时 `< 100ms`，保留当前视口、笔刷与编辑光标 |
| `T1.0-03` | `[双线]` | `apps/apple` + `core/manga-core` | **轻小说创作引擎内置**：Markdown/富文本写作、字数统计、共享大纲/专有名词词典自动联想、5 语言小说正文管理及 EPUB/Markdown 发行导出（支持自选漫画页或 `novel/illustrations/` 单独定制插画） | 同一 `.prj` 工程可独立产出 EPUB 轻小说与漫画稿，支持 `<DivergenceNote>` 有意分歧 |
| `T1.0-04` | `[本地AI]` | `ai/local-llm` | **前置集成 LiteRT-LM / CoreML 本地运行时**：按需下载、校验与加载 **Gemma 4 E2B（8GB）/ E4B（16GB+）**，实现 120s 闲置自动卸载与内存告警释放 | 断网离线可启动推理；卸载后内存完全归零 |
| `T1.0-05` | `[本地AI]` | `ai/dual-bridge` | **漫画 → 小说 AI 参考稿生成与并排对照写作**：Gemma 4 只读漫画分格与 `script.xml` 生成参考散文存入 `ai_assist/manga_to_novel/`（`role="ai_reference_only"`），右侧人工写作区完全独立可自由重写 | 严禁越界写入 `novel/prose/`；AI 中间稿可留存追溯历史 |
| `T1.0-06` | `[本地AI]` | `ai/dual-bridge` | **小说 → 漫画 AI 分镜/大样中间稿生成与参考浮窗**：Gemma 4 只读小说正文生成分镜脚本与分格占位存入 `ai_assist/novel_to_manga/`，漫画画布可作半透明底图参考，人工原稿可完全不同 | 严禁越界写入 `manuscript/`；校验器与 Rust 内核双重拦截越界路径 |

### `v1.1` — Android Pad / 折叠屏兼容版 + Gemma 4 语音场记 & 铺色/LT

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T1.1-01` | `[本地AI]` | `ai/script-supervisor` | **智能场记本**：绑定 `.mnga` / `.prj` 场记表，支持角色/服饰/光源/道具状态录入、尊重 `<DivergenceNote>` 分歧及 **Gemma 4 语音口述结构化抽取** | 语音口述场记在 3 秒内准确写入对应页/格记录 |
| `T1.1-02` | `[本地AI]` | `ai/story-planner` | **5 语言对白与小说本土化润色助手**：结合 `i18n/dictionary.xml` 校对繁中/粤语/西语，严格保护 `locked="true"` 人工定稿 | 术语一致率 `100%`，永不覆盖人工锁定行 |
| `T1.1-03` | `[全彩条漫]` | `ai/vision` | **端侧语义一键分图层铺底色**：集成量化 `MobileSAM`/`SAM2-Tiny`，自动拆分皮肤/头发/服饰层并防白边扩张 | 典型二次元单人线稿端侧 3–6 秒完成分图层铺色 |
| `T1.1-04` | `[黑白页漫]` | `ai/vision` | **开源离线照片/3D 转黑白漫画背景（LT 转换）**：拆出线稿层 + 可调 LPI 网点层 + 纯黑阴影层 | 离线处理 2K 实拍背景图 `< 5 秒`，三层完全可编辑 |
| `T1.1-05` | `[多端]` | `apps/android` | **Android Pad / 折叠屏手机兼容版**：Kotlin + Jetpack Compose + `WindowManager` 折叠态/半折 Tabletop 模式 + S-Pen/星闪 M-Pencil/USI `FrontBufferedRenderer` + Vulkan `wgpu` + `libmanga_core.so` | ⏳ 工程骨架、JNI 契约、折叠适配与 5 语言 `strings.xml` 已落地，待 `v1.1` 接入真机渲染与发布 |

### `v1.2` — 触摸屏 Windows 兼容版 + Gemma 4 工作流驱动 & 清稿/二分

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T1.2-01` | `[本地AI]` | `ai/workflow-driver` | **Gemma 4 Function-Calling 工作流驱动引擎**：暴露 `ActionBus` 工具白名单 Schema，实现自然语言/语音 → `ActionPlan` 预览卡片 → 原子执行与单步整组撤回 | 10 类典型批处理指令成功率 `≥ 95%` 且 100% 可撤回 |
| `T1.2-02` | `[双线]` | `ai/vision` | **风格保留型草稿清稿 → 矢量线稿层** + `< 4px` 断口雷达实时提示 | 输出标准可编辑矢量图层，支持交点橡皮二次修整 |
| `T1.2-03` | `[全彩条漫]` | `ai/vision` | **3D 光源球引导自动赛璐璐二分**：端侧法线估计 + 实时拖球预览 + 烘焙独立 `Multiply` 阴影与边缘光层 | 拖动光源球预览帧率 `≥ 30fps`，烘焙输出不破坏底色层 |
| `T1.2-04` | `[多端]` | `apps/windows` | **触摸屏 Windows Notebook / 2-in-1 Pad 兼容版**：WinUI 3 + `WM_POINTER`/Windows Ink 压感防误触 + 2-in-1 平板模式自动切换 + DX12 `wgpu` + `manga_core.dll` P/Invoke | ⏳ `.csproj`、P/Invoke 契约与 Windows Ink 适配器骨架已落地，待 `v1.2` 接入 DX12 宿主与 MSIX 打包 |

### `v1.3` – `v1.4` — 触摸屏 Linux 兼容版、3D 人偶、视觉穿帮巡检与 ComfyUI 桥接

| 任务 ID | 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T1.3-01` | `[双线]` | `apps/*` + `ai/vision` | 轻量二次元比例 3D 人偶渲染 + 拍照/火柴人提姿 + 透视尺焦距同步 | 支持 5–8 头身切换与常用手部姿势库 |
| `T1.3-02` | `[双线]` | `core` + `apps/*` | 完整多页章节管理（对页/跨页/装订顺序）、条漫分集与多卷轻小说工程管理 | 32 页同人本/连载工程切换响应 `< 150ms` |
| `T1.3-03` | `[多端]` | `apps/linux` | **触摸屏 Linux Notebook / Pad 兼容版**：Rust 原生直连 `manga-core` + GTK4/Wayland `zwp_tablet_v2` + `libinput` 多点触控 + Vulkan `wgpu` + Flatpak/AppImage | ⏳ `manga-linux-shell` Crate 已接入 Cargo Workspace 并通过 CI 真实编译单测，待 `v1.3` 接入 GTK4/Vulkan 窗口 |
| `T1.4-01` | `[本地AI]` | `ai/script-supervisor` | **Gemma 4 多模态视觉穿帮巡检**：对比分格缩略图、角色设定卡与场记表，输出非破坏性批注气泡 | 可检出明显漏画配饰/瞳色冲突，零修改画布像素 |
| `T1.4-02` | `[本地AI]` | `ai/bridge` | 局域网 **ComfyUI / OpenAI-Compatible BYOK 桥接插件**（选区导出 → 远端推理 → 新图层或 `ai_assist/` 参考稿回贴） | 完整支持局域网自定义工作流 JSON 映射 |
