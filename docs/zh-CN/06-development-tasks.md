# 06. 开发任务细化清单（Engineering Work Breakdown Structure）

**语言 / Language**: [English](../en/06-development-tasks.md) | **简体中文**

> **命名留置说明**：本文档中三款独立工具的中文名、英文名与西语名（**`创想空间` / `NoemaDock`**、**`雕龙` / `DracoNib`**、**`文心` / `LitteraCore`**）目前均为**暂定开发代号（Working Codenames）**，待发版前最终品牌确认后再通过专项 PR 统一定稿。

---

## 1. 任务标签与「3+1 四段式」子项目说明

本文档将 [04. 分阶段开发规划](./04-roadmap.md) 拆解为可直接排期、建 Issue 与验收的原子工程任务。遵循本项目的**三独立工具架构**，**每个版本 `vX.Y` 均强制拆分为 3 个独立工具子项目 + 1 个独立的集成兼容性修订阶段**，全部通过后方统一发起版本 PR 发布：

### 1.1 工具子项目与发布门禁标签（每版本必含 `S1` + `S2` + `S3` + `S4`）
- `[S1 创想空间]`（暂定代号 `NoemaDock`）：项目概览、文案与画稿导入、双引擎（漫画 × 轻小说）分集/分话协同与多语种版本发布中心（无 GPU 画布，`< 200 MB` 内存预算，`manga-core --features hub`）
- `[S2 雕龙]`（暂定代号 `DracoNib`）：系列漫画与二次元插画绘制工具，覆盖画稿管理与高帧率 GPU 绘制管线（`manga-core --features canvas`）
- `[S3 文心]`（暂定代号 `LitteraCore`）：轻小说撰写、插图选配与 EPUB/Markdown 出版管理工具（无 GPU 画布，`< 120 MB` 内存预算，`manga-core --features novel`）
- `[S4 集成兼容→PR]`：每版本**独立收口阶段**，专项修订三工具共享 `.prj` 并发写权隔离、Deep-Link 互跳、`ai_assist/` 隔离红线、8GB 设备三开内存共存与多端打包兼容性，验收通过后统一合并并发布该版本 PR

### 1.2 技术域标签
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

### `v0.1` — 三工具模块化基座、低延迟画布内核、双线模板与 i18n 基座

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 状态 / 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.1-01` | `[S2 雕龙]` `[双线]` | `core/manga-core` | 稀疏 `256×256` CoW 瓦片存储（`TileLayer`）、拉绳防抖（`RopeStabilizer`）与增量撤销栈（`TileUndoStack`） | ✅ 已落地并通过单元测试 |
| `T0.1-02` | `[S1/S2/S3]` `[双线]` | `core/manga-core` + `apps/apple` | 导出 C-ABI 静态/动态库接口（`ffi.rs`、`include/manga_core.h`、`platform.rs`、`suite.rs`）与 Swift RAII 桥接（`MangaCoreBridge.swift`），启用 Cargo Feature 分片（`hub`/`canvas`/`novel`） | ✅ Rust C-ABI（`staticlib` + `cdylib`）、三工具 Feature 分片与 FFI 单测已落地 |
| `T0.1-03` | `[S2 雕龙]` `[双线]` | `core/manga-gpu` | 基于 `wgpu`（Metal 后端）实现脏瓦片上传与全屏视图矩阵合成着色器 | ⏳ 待在 macOS/Xcode 环境联调真机 Metal |
| `T0.1-04` | `[S2 雕龙]` `[双线]` | `apps/apple` | 封装 UIKit `MetalCanvasView` 宿主：接入 `coalescedTouches`（240Hz）、`predictedTouches` 临时叠加与 Palm Rejection | ⏳ 已完成 `ApplePencilInputAdapter.swift`，待真机渲染联调 |
| `T0.1-05` | `[S2 雕龙]` `[双线]` | `core` + `apps/apple` | 新建工程**双线画布预设**（B4/A4 600DPI 出血裁切 + 800/1600 条漫 + 4K 插画）与 `CanvasSession` 视口/落笔闭环 | ✅ Rust `preset.rs` + `canvas.rs` 已落地并通过单测 |
| `T0.1-06` | `[S1 创想空间]` `[i18n]` | `i18n/` + `scripts/` + `core` | 5 语言术语词典、三工具暂定代号词条、CI 校验（`i18n_check.py`）、`i18n_sync.py`（Apple `.xcstrings` + Android `strings.xml`）及 `.prj` 工程概览基础解析 | ✅ 已落地并接入 GitHub Actions CI |
| `T0.1-07` | `[S3 文心]` `[双线]` | `core/manga-core` + `apps/*` | 轻小说独立启动模式（`--features novel` / `SuiteApp::Novel`，零 GPU 画布初始化）与 `.prj` 章节大纲/正文路径挂载契约 | ✅ `SuiteApp::Novel` + Linux 独立启动验证已落地，待接入前端编辑器 UI |
| `T0.1-S4` | `[S4 集成兼容→PR]` | `core` + `apps/linux` + `.github/` | **v0.1 三工具集成兼容门禁**：校验 3 组 Cargo Feature 独立编译、`suite.rs` 路径写权隔离矩阵、`templates/SampleManga` 兼容性自检与 CI 门禁，通过后统一发 PR | ✅ `suite.rs` + Cargo Feature 分片编译 + `manga-linux-shell --integration-check` 已落地并接入 CI |

### `v0.2` — 二次元笔刷引擎、工程概览壳与轻小说基础编辑器

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.2-01` | `[S2 雕龙]` `[双线]` | `core/manga-gpu` | 实现 GPU 笔刷盖章管线（笔尖灰度纹理、间距插值、硬度、旋转、透明度流控） | 200px 大笔刷连续快速涂抹无掉帧 |
| `T0.2-02` | `[S2 雕龙]` `[双线]` | `core/manga-core` | 压感 / 倾角 / 速度 / Apple Pencil Pro `roll_angle` 映射贝塞尔响应曲线编辑器数据模型 | 同一笔迹回放输出像素完全确定性一致 |
| `T0.2-03` | `[S2 雕龙]` `[黑白页漫]` | `core/manga-core` | 优化 G 笔 / 圆笔起收笔出锋算法与动态拉绳防抖（支持按缩放比自适应半径） | 慢速勾长发曲线无锯齿，画师盲测达标 |
| `T0.2-04` | `[S2 雕龙]` `[全彩条漫]` | `core/manga-gpu` | 实现赛璐璐平涂实心笔、软喷枪与基础涂抹混色笔刷预设（内置 8 支标准笔刷包） | 实心笔无多余半透明毛边，喷枪过渡无明显色带 |
| `T0.2-05` | `[S1 创想空间]` `[双线]` | `apps/apple` + `core` | 项目概览卡片列表、新建 `.prj` 工程向导（自选双线/双引擎模板）与只读画稿/章节缩略图浏览 | 冷启动 `< 500ms`，峰值内存 `< 180 MB` |
| `T0.2-06` | `[S3 文心]` `[双线]` | `apps/apple` + `core` | 轻小说纯文本/Markdown 基础编辑器、自动字数统计、大纲（`outline/master_outline.md`）只读分屏参考 | 打开 10 万字章节滚动 `120fps`，内存 `< 100 MB` |
| `T0.2-S4` | `[S4 集成兼容→PR]` | `core` + `apps/*` | **v0.2 三工具集成兼容修订**：验证「创想空间」新建工程可被「雕龙」与「文心」零报错打开，跨工具切换无文件锁冲突，全量回归后发 PR | 三工具连续打开/保存同一 `.prj` 100 轮零损坏 |

### `v0.3` — 赛璐璐图层栈、角色圣经面板与轻小说场景大纲联动

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.3-01` | `[S2 雕龙]` `[全彩条漫]` | `core/manga-core` | 实现树状图层文档模型（普通层、文件夹、剪切蒙版、Alpha 锁定、参考层标记、草稿着染） | ✅ `layer.rs`（`LayerStack` / 剪切蒙版 / Alpha 锁 / 蓝稿着染）已落地并单测通过 |
| `T0.3-02` | `[S2 雕龙]` `[全彩条漫]` | `core/manga-gpu` | 在 WGSL 合成管线中实现 12+ 常用混合模式（Multiply / Screen / Overlay / Glow Dodge / Linear Burn 等） | ⏳ Rust CPU 参考实现（13 种混合模式 `blend_rgba`）已落地，待移植至 WGSL |
| `T0.3-03` | `[S2 雕龙]` `[双线]` | `core/manga-core` | 将 `TileUndoStack` 升级为多图层事务型撤销/重做（支持新建/删除/重排/合并图层回滚） | ✅ 已随 `ActionBus` 事务级 `ActionUndoGroup` 落地 |
| `T0.3-04` | `[S1 创想空间]` `[双线]` | `apps/apple` + `core` | 角色设定集（`bible/characters.xml`）、世界观条目与目录（`toc.xml`）可视化编辑器 | 增删改角色与章节目录即时同步写入 `.prj` 与 `toc.xml` |
| `T0.3-05` | `[S3 文心]` `[双线]` | `apps/apple` + `core` | 轻小说分场景导航树（关联 `chapters/chXXX/scenes/`）、角色设定卡只读侧边栏与增量自动保存 | 场景跳转 `< 50ms`，自动保存不阻塞输入法 |
| `T0.3-S4` | `[S4 集成兼容→PR]` | `core` + `apps/*` | **v0.3 三工具集成兼容修订**：验证「创想空间」修改角色/目录后，「雕龙」与「文心」并发热刷新且严守文件写权分区，回归通过后发 PR | 并发写测试零覆盖、热刷新延迟 `< 300ms` |

### `v0.4` — 选区/防白边填色、文案画稿批量导入与字典联想

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.4-01` | `[S2 雕龙]` `[双线]` | `core/manga-core` | 实现套索、矩形/椭圆选区与魔棒（参考图层感知、蚁行线 GPU 叠加、反选/扩张/收缩） | 选区遮罩精确约束笔刷与填色区域 |
| `T0.4-02` | `[S2 雕龙]` `[全彩条漫]` | `core/manga-core` | **核心亮点**：实现闭口识别扫描线油漆桶（Close Gap `1–8px`）+ 像素边缘扩张（Expand `1–3px`）+ 涂抹封闭区填色 | ✅ `fill.rs`（`close_gap_expand_fill` 参考层感知 + 3px 断口防漏 + 1px 防白边扩张）已落地并单测通过 |
| `T0.4-03` | `[S2 雕龙]` `[双线]` | `core/manga-gpu` | GPU 双线性/双三次自由变换（缩放/旋转/透视四角拖拽）与基础液化推挤网格 | 实时 60–120fps 交互预览，确认后仅回写脏瓦片 |
| `T0.4-04` | `[S1 创想空间]` `[双线]` | `core` + `apps/apple` | **文案与画稿统一导入器**：支持导入 Markdown/DOCX/TXT 剧本与小说、以及 PNG/PSD/CLIP 散页画稿自动归档入对应章节 | 导入 50 页画稿 + 10 章文案自动生成完整 CPFF 结构并零报错通过 `prj_validate.py` |
| `T0.4-05` | `[S3 文心]` `[i18n]` | `apps/apple` + `core` | 共享专有名词词典（`i18n/dictionary.xml`）输入自动联想、多语小说分文件并行视图基础能力 | 键入专有名词触发 5 语对照提示，绝不越界修改 `dictionary.xml` |
| `T0.4-S4` | `[S4 集成兼容→PR]` | `core` + `apps/*` | **v0.4 三工具集成兼容修订**：端到端验收「创想空间导入散稿/文案 → 雕龙二次上色填色 → 文心续写修订」全链路数据一致性，通过后发 PR | 导入产出在三工具中像素/编码/目录 100% 一致 |

### `v0.5` — 矢量线稿/尺规、双引擎章节分集树与有意分歧标记

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.5-01` | `[S2 雕龙]` `[黑白页漫]` | `core/manga-vector` | 可变线宽中心线数据结构与高质量 GPU 栅格化缓存（支持无损缩放与局部线宽调整） | ✅ 核心数据结构与无损缩放/局部线宽调节（`vector.rs`）已落地，待接入 `vello` GPU 渲染 |
| `T0.5-02` | `[S2 雕龙]` `[黑白页漫]` | `core/manga-vector` | **矢量交点橡皮擦**：求取最近线段交点并精准裁剪出头段（后续大规模线稿接入 `rstar` 加速） | ✅ `VectorLayer::erase_to_intersection`（X 型出头裁剪 + H 型中段切分）已落地并单测通过 |
| `T0.5-03` | `[S2 雕龙]` `[双线]` | `core/manga-core` | 尺规吸附管线：对称尺、平行尺、1/2/3 点透视尺、同心圆与漫画集中线/速度线生成器 | ✅ `ruler.rs`（对称镜像 + 平行 + 1/2/3 点透视射线吸附 + 集中线）已落地并单测通过 |
| `T0.5-04` | `[S1 创想空间]` `[双线]` | `apps/apple` + `core` | 分集/分连载章节看板：同屏展示每话「漫画原稿进度」与「轻小说正文进度」双轨状态与版本标签 | 支持拖拽重排章节序号并自动重写 `.prj` 与 `toc.xml` 索引 |
| `T0.5-05` | `[S3 文心]` `[双线]` | `apps/apple` + `core` | 支持在章节中创建 `<DivergenceNote>` 有意改编分歧标注（记录小说与漫画剧情差异，供场记与 AI 尊重） | 标注写入 `novel/novel_meta.xml`，漫画稿与小说稿保持独立演化 |
| `T0.5-S4` | `[S4 集成兼容→PR]` | `core` + `apps/*` | **v0.5 三工具集成兼容修订**：验证章节重排后「雕龙」画稿引用与「文心」`<DivergenceNote>`/正文引用无断链，通过后发 PR | 章节重排与改名回归用例 100% 通过 |

### `v0.6` — 分格框/网点/气泡/切片、多语字典巡检与多语轻小说管理

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.6-01` | `[S2 雕龙]` `[黑白页漫]` | `core/manga-core` | 分格框文件夹（Panel Frame Folder）：支持直线/斜切分格、自定义格间距（Gutter）与自动蒙版裁切 | ✅ `panel.rs`（Sutherland-Hodgman 水平/斜切分格 + Gutter 间距 + 格内蒙版判断）已落地并接入 C-ABI |
| `T0.6-02` | `[S2 雕龙]` `[黑白页漫]` | `core/manga-gpu` | 程序化网点纸图层（圆点/线条/交叉线/噪点、LPI 线数、角度、浓度与 600DPI 二值导出） | ⏳ `screentone.rs` 面积守恒半调数学内核已落地并单测通过，待移植 WGSL |
| `T0.6-03` | `[S2 雕龙]` `[双线]` | `apps/apple` + `core` | 气泡模板 + CoreText **中/日文竖排（含标点挤压）与英/西横排**排版引擎，支持按语言切换气泡文本层 | 同页可一键切换中/英/西多语种气泡并无损排版 |
| `T0.6-04` | `[S2 雕龙]` `[全彩条漫]` | `core/manga-io` | 条漫（Webtoon）手机阅读安全框预览 + 自动按高度切片（如 `800×1280`）无损批量导出 | ✅ `webtoon.rs`（切片计算 + 无缝像素合成验证）已落地，待接入 PNG 编码写盘 |
| `T0.6-05` | `[S1 创想空间]` `[i18n]` | `apps/apple` + `core` | **多语言版本矩阵管理**：统一巡检 5 语 `i18n/dictionary.xml`、各话气泡译文缺漏与小说多语章节完备度 | 一键高亮缺译章节与未锁定（`locked="false"`）词条 |
| `T0.6-06` | `[S3 文心]` `[i18n]` | `apps/apple` + `core` | 轻小说 5 语言分卷/分章正文编辑器（`prose.<lang>.md`）、竖排/横排阅读预览与人工锁定防覆写标记 | 5 语对照分屏写作流畅，人工定稿锁零误覆盖 |
| `T0.6-S4` | `[S4 集成兼容→PR]` | `core` + `apps/*` | **v0.6 三工具集成兼容修订**：验证「雕龙」多语气泡 `script.xml`、「文心」多语小说与「创想空间」5 语字典巡检三方同步一致性，通过后发 PR | 5 语全量切换与多语导出校验 0 漂移 |

### `v0.7` — 开放文档 `.mnga`、PSD 互通、`ActionBus` 与多发行版发布中心

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.7-01` | `[S2 雕龙]` `[双线]` | `core/manga-io` | 定义并实现 `.mnga`（SQLite + Zstd 瓦片 + JSON 清单 + **场记/剧本扩展表**）增量自动保存与崩溃恢复 | ⏳ 场记 SQLite DDL 与内存模型（`continuity.rs`）已落地，待接入 `rusqlite`/`zstd` 落盘 |
| `T0.7-02` | `[S2 雕龙]` `[双线]` | `core/manga-io` | Clean-room MIT 多层 PSD 编解码（图层树、混合模式、不透明度、剪切蒙版与文字元数据） | 导出 PSD 在 CSP / Photoshop 打开视觉一致 |
| `T0.7-03` | `[S2 雕龙]` `[双线]` | `core/manga-core` | **确定性 `ActionBus` 命令总线**：定义白名单命令集、非破坏性 Dry-Run 预览与单步 `UndoGroup` 原子撤回 | ✅ `action_bus.rs`（`ActionBus` + `ProjectDocument` + Gemma 4 批处理单测）已落地 |
| `T0.7-04` | `[S2 雕龙]` `[双线]` | `core/manga-io` | 轻量过程回放（Timelapse）关键帧采集与后台 MP4 导出 | 录制对绘制帧率影响 `< 2%` |
| `T0.7-05` | `[S1 创想空间]` `[双线]` | `core/manga-core` + `scripts/` | **CPFF v1.0 发行与 Git 协作中心**：同名 `.prj` XML 读写、GitHub/GitLab+LFS 同步、版权/同人声明与**多发行版（单行本/条漫连载/电子书）多语种一键打包发布** | ✅ `project.rs` + `templates/SampleManga/` + `prj_validate.py` 已落地；发行打包器接入 `v0.7` |
| `T0.7-06` | `[S3 文心]` `[双线]` | `core/manga-io` + `apps/apple` | **轻小说插图管理与 EPUB3 / Markdown 出版导出**：支持勾选漫画成品页（`CuratedMangaPages`）或 `novel/illustrations/` 单独高分插画，输出合规 EPUB3 | 生成 EPUB3 通过 `epubcheck` 校验，插图路径引用无损 |
| `T0.7-S4` | `[S4 集成兼容→PR]` | `core` + `apps/*` | **v0.7 三工具集成兼容修订**：验证「创想空间」联合调用「雕龙」漫画切片/印刷导出与「文心」EPUB3 导出生成多语发行包，及 Git+LFS 协同无冲突，通过后发 PR | 同一 `.prj` 仓库多语发行包全自动构建并校验通过 |

### `v0.8` – `v0.9` — Apple 三端触控/折叠适配（iPad · 触摸屏 MacBook · iPhone Duo）、5 语言与 Beta

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T0.8-01` | `[S2 雕龙]` `[双线]` | `apps/apple` | iPad 完整手势体系（双指撤回/三指重做/长按吸色）+ Apple Pencil Pro 轻捏径向快捷盘与悬停轮廓预览 | 80% 高频工具切换无需点击顶部栏 |
| `T0.8-02` | `[S2 雕龙]` `[双线]` | `apps/apple` | 悬浮参考图小窗（可吸色/缩放）+ 蓝牙键盘与左手控制器快捷键映射 | 支持导出/导入快捷键配置文件 |
| `T0.8-03` | `[S1/S2/S3]` `[i18n]` | `apps/apple` + `i18n/` | 三工具同步上线 5 语言应用内即时切换（含 `zh-HK → yue-Hant` 回退）与术语锁定自动同步脚本 | 三工具 5 语言实时切换无需重启 App，零缺词 |
| `T0.8-04` | `[S1/S2/S3]` `[多端]` | `apps/apple/macOS-Touch` | **触摸屏 MacBook 适配**：三工具独立/多窗运行；「雕龙」直触防误触 + `tabletPoint` 压感，「创想空间」/「文心」键盘+直触双模交互 | ✅ 输入适配骨架（`MacTouchInputAdapter.swift` + `project.yml`）已落地，待真机联调 |
| `T0.8-05` | `[S1/S2/S3]` `[多端]` | `apps/apple/iPhoneDuo` | **iPhone Duo 折叠双形态适配**：折叠态优先运行超轻量「文心」单手写作与「创想空间」概览 ↔ 展开态铰链安全区避让双联创作 | ✅ 姿态骨架（`IphoneDuoPostureAdapter.swift` + `platform.rs`）已落地，待真机联调 |
| `T0.9-01` | `[S2 雕龙]` `[双线]` | `core/manga-core` | 瓦片虚拟内存磁盘换页（LRU 冷瓦片 Zstd 落盘）与 Jetsam 内存告警监听 | 8GB iPad 上 B4 600DPI 50 层与 `1600×25600` 彩漫双线连续 2h 零闪退 |
| `T0.9-02` | `[S1/S2/S3]` `[i18n]` | `apps/apple` | 三工具 5 语言在 iPad 11 寸分屏、触摸屏 MacBook 窗口与 iPhone Duo 折叠/展开态的全量截图防截断回归 QA | 三端三工具 5 语言零按钮裁切、零文本重叠 |
| `T0.9-S4` | `[S4 集成兼容→PR]` `[多端]` | `apps/apple` + `core` | **v0.9 Wave 1 三端三工具联合集成修订与 Beta PR**：验收 8GB 设备「创想空间 + 雕龙 + 文心」并行内存共存、Deep-Link 互跳（`noemadock://` ↔ `draconib://` ↔ `litteracore://`）、跨设备 `.prj` Git 接力与三端 `.ipa`/`.dmg` Beta 打包 | 三端三工具联合压测零 OOM、Deep-Link 100% 精准定位后发起 Wave 1 Beta PR |

---

## 3. 1.x 细化工程任务（双引擎 + 本地 Gemma 4 + Wave 2 跨平台）

### `v1.0` — 整体 UI 升级 + 小说 × 漫画双引擎并进（Apple 三端正式版）

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T1.0-01` | `[S1/S2/S3]` `[双线]` | `apps/apple` | 三工具统一 Pro 设计系统（OLED 暗黑/护眼深灰/浅色主题、左右手工作区、重构高辨识度图标库） | 三工具视觉统一性与 5 语言排版全部通过定稿评审 |
| `T1.0-02` | `[S1 创想空间]` `[本地AI]` | `apps/apple` + `ai/local-llm` | **双引擎总控台与本地 Gemma 4 运行时中心**：按需下载/校验 **Gemma 4 E2B（8GB）/ E4B（16GB+）**、统一触发批量双向 AI 参考稿生成、120s 闲置自动卸载与内存告警释放 | 断网离线可启动推理；卸载后内存完全归零；多工具共享单一模型权重 |
| `T1.0-03` | `[S3 文心]` `[本地AI]` | `apps/apple` + `ai/dual-bridge` | **正式版轻小说工坊 + 「漫画 → 小说」AI 参考稿并排写作**：Gemma 4 只读漫画分格与 `script.xml` 输出参考散文至 `ai_assist/manga_to_novel/`（`role="ai_reference_only"`），右侧人工写作区完全独立可自由重写并导出 EPUB3 | 严禁越界写入 `novel/prose/`；AI 中间稿可留存追溯历史，人工定稿可与漫画完全不同 |
| `T1.0-04` | `[S2 雕龙]` `[本地AI]` | `apps/apple` + `ai/dual-bridge` | **正式版漫画画布 + 「小说 → 漫画」AI 分镜/大样半透明参考窗**：Gemma 4 只读小说正文输出分镜脚本与分格占位至 `ai_assist/novel_to_manga/`，画布可作底图参考，人工原稿可完全不同 | 严禁越界写入 `manuscript/`；校验器与 Rust 内核双重拦截越界路径 |
| `T1.0-05` | `[S1/S2/S3]` `[双线]` | `apps/apple` | **三工具同屏分屏协同与焦点切换**：iPad Stage Manager / MacBook 多窗 / iPhone Duo 展开态支持「创想空间」「雕龙」「文心」无缝并排与 Deep-Link 即时定位 | 切换与互跳耗时 `< 100ms`，保留各自视口、笔刷与编辑光标 |
| `T1.0-S4` | `[S4 集成兼容→PR]` `[多端]` | `core` + `apps/apple` + `ai/` | **v1.0 正式版三工具总集成兼容闸门**：全量审计 `ai_assist/` 隔离红线、双引擎终稿解耦回归、三工具并发共享单份 Gemma 4 权重防 OOM、**并确认三工具最终中/英/西文正式品牌名**后发起 `v1.0` Apple 三端正式 PR | AI 零越界、三端三工具全量回归绿灯、品牌定稿 PR 合入后正式发布 `v1.0` |

### `v1.1` — Android Pad / 折叠屏兼容版 + Gemma 4 语音场记 & 铺色/LT

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T1.1-01` | `[S1 创想空间]` `[本地AI]` | `ai/script-supervisor` + `apps/android` | **Android 版「创想空间」+ 智能场记总控**：绑定 `.mnga`/`.prj` 场记表、尊重 `<DivergenceNote>` 分歧、支持 Android 折叠屏分集看板与多语发布 | 场记状态跨设备秒级同步，Android 平板/折叠屏冷启动 `< 600ms` |
| `T1.1-02` | `[S2 雕龙]` `[黑白/彩漫]` `[本地AI]` | `ai/vision` + `apps/android` | **Android 版「雕龙」+ 端侧铺底色与离线 LT 转换**：Jetpack Compose + S-Pen/M-Pencil/USI `FrontBufferedRenderer` + Vulkan `wgpu`；集成 `MobileSAM`/`SAM2-Tiny` 一键分图层铺底色 + 照片/3D 转可编辑黑白漫画 3 层 | 单人线稿 3–6 秒铺底色，2K 照片 `< 5 秒` LT 转换，压感延迟达标 |
| `T1.1-03` | `[S3 文心]` `[本地AI]` | `ai/story-planner` + `apps/android` | **Android 版「文心」+ 语音口述场记 & 5 语言小说润色**：折叠屏外屏单手写作/语音场记结构化抽取、结合 `i18n/dictionary.xml` 校对繁中/粤语/西语并严守 `locked="true"` | 语音场记 3 秒内入库，术语一致率 `100%`，零覆盖人工锁定行 |
| `T1.1-S4` | `[S4 集成兼容→PR]` `[多端]` | `apps/android` + `core` | **v1.1 Android 三工具集成兼容修订**：验证 Android 多窗口/折叠分屏（`FoldingFeature` / Tabletop）下三工具并发读写 `.prj`、Android App Links 互跳与 `libmanga_core.so` 内存占用，通过后发 PR | 折叠/展开切换零重载丢失，Android 三工具联合回归通过后发 `v1.1` PR |

### `v1.2` — 触摸屏 Windows 兼容版 + Gemma 4 工作流驱动 & 清稿/二分

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T1.2-01` | `[S1 创想空间]` `[多端]` | `apps/windows` + `core` | **Windows 版「创想空间」**：WinUI 3 + `manga_core.dll` P/Invoke，提供桌面级多工程管理、批量文案画稿导入、Git+LFS 图形化同步与多发行版导出 | 支持 Windows 触控 + 键鼠双模，MSIX 独立或套件安装可选 |
| `T1.2-02` | `[S2 雕龙]` `[本地AI]` `[多端]` | `apps/windows` + `ai/` | **Windows 版「雕龙」+ Gemma 4 宏驱动 & 清稿/赛璐璐二分**：`WM_POINTER`/Windows Ink 防误触 + DX12 `wgpu`；`ActionBus` 语音/文本批处理、草稿清稿矢量化 + `< 4px` 断口雷达、3D 光源球自动二分 | 10 类批处理指令成功率 `≥ 95%` 可撤回，光源球预览 `≥ 30fps` |
| `T1.2-03` | `[S3 文心]` `[本地AI]` `[多端]` | `apps/windows` + `ai/` | **Windows 版「文心」+ Gemma 4 剧情/设定联动宏**：2-in-1 笔记本翻转平板自动切换触控阅读校对态，支持一键按设定集校对全卷人名/时间线冲突 | 10 万字长文全卷校验 `< 5 秒`，零修改未确认正文 |
| `T1.2-S4` | `[S4 集成兼容→PR]` `[多端]` | `apps/windows` + `core` | **v1.2 Windows 三工具集成兼容修订**：验证 WinUI 3 多窗/2-in-1 平板模式切换、自定义 URI 协议互跳、Windows 文件锁（`ReadFile`/`CreateFile` 共享读写）下三工具并发无拒访，通过后发 PR | Windows 文件并发读写与 MSIX 三工具打包 100% 通过后发 `v1.2` PR |

### `v1.3` – `v1.4` — 触摸屏 Linux 兼容版、3D 人偶、视觉穿帮巡检与 ComfyUI 桥接

| 任务 ID | 子项目 / 标签 | 所属模块 | 具体开发内容 | 验收标准 |
| :--- | :--- | :--- | :--- | :--- |
| `T1.3-01` | `[S1 创想空间]` `[多端]` | `apps/linux` + `core` | **Linux 版「创想空间」+ 多卷/多话大型连载总管**：Rust 原生 GTK4/Wayland 壳，支持 32 页+ 对页/跨页装订、条漫分集与多卷轻小说联合排期发布 | 32 页工程切换 `< 150ms`，Flatpak/AppImage 离线可运行 |
| `T1.3-02` | `[S2 雕龙]` `[多端]` `[本地AI]` | `apps/linux` + `ai/` | **Linux 版「雕龙」+ 3D 人偶、视觉穿帮巡检 & ComfyUI 桥接**：`zwp_tablet_v2` + `libinput` + Vulkan `wgpu`；5–8 头身 3D 人偶与透视尺同步；Gemma 4 多模态穿帮巡检（非破坏批注）；局域网 ComfyUI BYOK 桥接 | 穿帮巡检零修改画布像素；ComfyUI 选区回贴或入 `ai_assist/` 稳定运行 |
| `T1.3-03` | `[S3 文心]` `[多端]` `[本地AI]` | `apps/linux` + `ai/` | **Linux 版「文心」+ 跨卷伏笔/设定一致性巡检**：原生低耗 GTK4 写作与多卷 EPUB3/Print PDF 排版预览，支持将局域网 BYOK 生图结果按红线隔离导入 `ai_assist/` 供插画构图参考 | 严守 `ai_assist/` 隔离；多卷排版输出稳定一致 |
| `T1.3-S4` | `[S4 集成兼容→PR]` `[多端]` | `apps/*` + `core` | **v1.3–v1.4 六平台 × 三工具全矩阵集成兼容修订**：验证 Linux Wayland `xdg-open` 互跳、六大平台（iPad / MacBook 触摸 / iPhone Duo / Android / Windows / Linux）同一 `.prj` 仓库跨平台三工具互操作回归，通过后发 PR | 六端 × 三工具互操作矩阵 100% 绿灯后发布 `v1.3`/`v1.4` PR |
