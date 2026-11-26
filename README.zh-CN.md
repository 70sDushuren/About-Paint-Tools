# About-Paint-Tools

> **基于 MIT 开源协议、面向 iPad 触控与 Apple Pencil 的二次元漫画创作工具——融合专业漫画工作流与「创作者主导（Artist-in-the-Loop）」端侧 AI 辅助工具集。**

**文档语言 / Languages**: [English](./README.md) | **简体中文**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Platforms: 6端触控与折叠](https://img.shields.io/badge/全平台-iPad%20%7C%20MacBook触摸%20%7C%20iPhone%20Duo%20%7C%20Android%20%7C%20Win%20%7C%20Linux-black.svg)](#技术架构概览)
[![Locales: 5](https://img.shields.io/badge/应用支持-EN%20%7C%20简体%20%7C%20繁體%20%7C%20粵語%20%7C%20ES-green.svg)](./docs/zh-CN/05-i18n-and-l10n-guide.md)

---

## 项目愿景与定位

当前触控设备上的二次元漫画/插画创作者长期面临工具断层：

- **Procreate** 触控手感与低延迟 Metal 性能堪称标杆，但严重缺乏专业漫画能力（无真正矢量线稿层、无矢量交点橡皮、无分格文件夹、无非破坏性网点纸与多页连载管理）。
- **Clip Studio Paint (CSP)** 是漫画行业标准，但移动端强制订阅制且桌面移植 UI 繁杂拥挤。
- **ibisPaint X / MediBang Paint** 轻快易用、填色顺手，但免费版广告与会员墙割裂体验且全闭源。
- **Krita** 是最强的开源绘画软件，但因采用 **GPLv3 协议** 与 Apple App Store 条款冲突，至今无法登陆 iPadOS / iOS。

**About-Paint-Tools** 从第一行代码起即采用宽松的 **MIT 开源协议**，确立首阶段 **黑白页漫（日漫/同人本）× 全彩条漫/二次元插画 双线并重**，并分阶段覆盖 **六大触控与折叠屏硬件平台**（第一波次 `v0.9`→`v1.0`：**iPad · 触摸屏 MacBook · iPhone Duo**；第二波次 `v1.1`–`v1.3`：**Android Pad/折叠屏手机 · 触摸屏 Windows · 触摸屏 Linux**）。

为优化移动与触控设备的系统资源占用，本项目基于同一套 CPFF v1.0（`.prj`）文件体系，拆分为**三个既可单独低耗运行、又可同屏并发协同的独立工具** *(以下中/英/西语名称均暂留置为**开发代号**，待正式发版前确认最终品牌名后 PR 定稿)*：
- **`S1` 创想空间（代号：`NoemaDock`）**：项目概览与管理中心——文案与画稿导入、漫画 × 轻小说双引擎分集连载、Git/LFS 协作与多语种/多版式成品发布（单独运行内存 `< 200 MB`）。
- **`S2` 雕龙（代号：`DracoNib`）**：系列漫画与插画绘制工具——独占 GPU 显存与瓦片池，覆盖 240Hz Apple Pencil Pro / S-Pen / Windows Ink / Wayland `zwp_tablet_v2`、矢量线稿 + 交点橡皮、分格、网点、防白边闭口填色与条漫切片。
- **`S3` 文心（代号：`LitteraCore`）**：轻小说撰写与出版管理工具——5 语正文写作、共享故事圣经/专有名词词典联想、自选漫画页或单独定制插图、EPUB3/Markdown 出版导出（零 GPU 画布负载，单独运行内存 `< 120 MB`）。
- **每版本强制 `S4` 集成兼容门禁**：每个版本（`v0.1`–`v1.5+`）均拆分为 `S1`、`S2`、`S3` 三个独立子项目 + 独立的 **`S4` 三工具集成与兼容性修订阶段**，全部验收通过后再统一 PR 发布。
- **「创作者主导」内嵌本地 AI（Gemma 4 E2B/E4B + 端侧视觉）**：离线 **Gemma 4（Apache 2.0）** 驱动 **`v1.0` 小说 ↔ 漫画双向 AI 参考稿**（严格隔离在 `ai_assist/` 内并标记 `role="ai_reference_only"`，绝不覆盖人工终稿）、语音场记、分镜策划与 `ActionBus` 批处理宏——**坚持本地优先、画作零上传、绝不用于训练**。

---

## 技术架构概览

为确保**「不同硬件上的用户体验为先」**（守住各平台原生触控与手写笔延迟，同时保持 80%+ 核心代码在 Rust 端单一维护），本项目采用**「六端薄原生壳 × 三独立模块化应用 × 共享 Rust 核心引擎」**架构：

```mermaid
flowchart TD
    subgraph UI["六大硬件原生触控与折叠壳层（三独立应用：S1 创想空间 · S2 雕龙 · S3 文心）"]
        Apple["波次一（v0.9 -> v1.0）：apps/apple/<br/>iPadOS（240Hz Pencil Pro）· 触摸屏 MacBook · iPhone Duo 折叠双形态"]
        Wave2["波次二（v1.1 - v1.3）：跨生态触控/折叠壳<br/>Android Pad/折叠屏（Compose/Vulkan）· Windows触摸本（WinUI 3/DX12）· Linux触摸本（Rust GTK4/Wayland）"]
    end

    subgraph Bridge["零拷贝 FFI 与 Rust 原生直连（按 Feature 裁剪：hub / canvas / novel）"]
        FFI["C-ABI staticlib/cdylib（Apple/Android/Win）· Rust Crate 直连（Linux）"]
    end

    subgraph Core["共享跨平台核心引擎（Rust, MIT 协议）"]
        Suite["suite.rs（三工具写权分治 / Deep-Link 协议 / S4 集成门禁）"]
        Platform["platform.rs（6平台姿态 / 折叠铰链 / 自适应布局引擎）"]
        Bus["ActionBus（确定性命令总线）<br/>事务批处理宏 / 单步 UndoGroup"]
        Input["笔迹管线<br/>压感曲线 / 拉绳防抖 / 预测点合并"]
        Canvas["分块画布管理器<br/>256x256 稀疏瓦片 / 磁盘换页 / 写时复制 Undo"]
        Vector["双线漫画与彩漫内核<br/>矢量线稿 / 分格 / 网点 / 防白边填色 / 条漫切片"]
        Render["GPU 合成引擎（wgpu + WGSL）<br/>Metal / Vulkan / DX12 原生后端"]
        IO["开放文档与 CPFF v1.0<br/>.prj 双引擎 / .mnga（含场记表） / PSD / EPUB3"]
    end

    subgraph AI["创作者主导本地 AI 层"]
        Gemma["内嵌本地大模型（Gemma 4 E2B/E4B, Apache 2.0）<br/>小说↔漫画参考稿 · 场记 · 策划 · Function Calling"]
        Vision["端侧专项视觉（CoreML / ONNX）<br/>智能铺色 · 离线 LT · 光影二分 · 姿态提取"]
        BridgeAI["开放工作流桥接（BYOK）<br/>本地 ComfyUI / 自定义 API 端点"]
    end

    Apple --> FFI
    Wave2 --> FFI
    FFI --> Suite
    FFI --> Platform
    FFI --> Input
    FFI --> Bus
    Gemma --> Bus
    Vision --> Bus
    BridgeAI --> Bus
    Bus --> Canvas
    Bus --> Vector
    Input --> Canvas
    Input --> Vector
    Canvas --> Render
    Vector --> Render
    Canvas --> IO
```

---

## 分阶段版本路线图

> 以下每个版本均严格按 **`S1`（创想空间）+ `S2`（雕龙）+ `S3`（文心）+ `S4`（三工具集成兼容修订）→ 统一版本 PR 发布** 推进，详见 [06. 开发任务细化清单](./docs/zh-CN/06-development-tasks.md)。

- **波次一 — Pre-1.0 系列（`v0.1` – `v0.9`）——双线内核 + Apple 三端（iPad · 触摸屏 MacBook · iPhone Duo）**
  - `v0.1`：`256×256` 稀疏分块画布内核、240Hz Apple Pencil 输入、B4 600DPI & 条漫画布预设、双基准（`en`/`zh-Hans`）i18n 基座
  - `v0.2`：笔刷盖章引擎、压感/倾斜/笔杆旋转曲线、实时拉绳防抖、8 支双线核心笔刷预设（G 笔/圆笔/平涂笔等）
  - `v0.3`：图层树、剪切蒙版、Alpha 锁定、参考图层、12+ 赛璐璐混合模式、Tile 级写时复制撤销/重做
  - `v0.4`：套索/魔棒选区、**闭口识别 + 边缘扩张防白边油漆桶**、自由变换与基础液化
  - `v0.5`：**矢量线稿图层**、**矢量交点橡皮擦**、对称尺与 1/2/3 点透视尺
  - `v0.6`：分格框文件夹、非破坏性 GPU 网点纸、中/日文竖排与英/西横排气泡、**条漫手机预览与一键切片导出**
  - `v0.7`：CPFF v1.0 `.prj` 创作工程（Git + Git LFS）、开源 `.mnga`（含场记扩展表）、多层 PSD 互通、延时回放、**确定性 `ActionBus`**
  - `v0.8`：Apple Pencil Pro 轻捏/悬停、**触摸屏 MacBook** 屏幕直触与快捷键融合、**iPhone Duo** 折叠双形态、**5 语言应用内即时切换**
  - `v0.9`：**Wave 1 Apple 三端联合 Beta（iPad · 触摸屏 MacBook · iPhone Duo）**、B4 600DPI & `1600×25600` 磁盘换页压测、5 语言防截断 QA
- **1.x 正式版系列（`v1.0` – `v1.5+`）——三工具正式版 + 本地 Gemma 4 + Wave 2 全平台兼容**
  - `v1.0`：**Apple 三端同步正式版**——三独立工具正式发布（代号：`创想空间` · `雕龙` · `文心`）+ **轻小说创作出版引擎**（共用 `.prj`、终稿解耦、自选/定制插图、EPUB3）+ **内嵌本地 Gemma 4 双向 AI 参考稿**（严格隔离于 `ai_assist/`）
  - `v1.1`：**Android Pad / 折叠屏兼容版（`apps/android/`）**（Compose + WindowManager 折叠/Tabletop + S-Pen/星闪笔 Vulkan）+ Gemma 4 语音场记 + 端侧铺底色 & 离线 LT 转线
  - `v1.2`：**触摸屏 Windows 兼容版（`apps/windows/`）**（WinUI 3 + Windows Ink + 2-in-1 平板模式 + DX12）+ Gemma 4 Function-Calling 批处理驱动 + 清稿矢量化 & 赛璐璐二分
  - `v1.3`：**触摸屏 Linux 兼容版（`apps/linux/`）**（Rust 原生直连 + GTK4/Wayland `zwp_tablet_v2` + Vulkan）+ 3D 二次元人偶 + 多页/条漫分集/轻小说多卷管理
  - `v1.4`：**Gemma 4 视觉场记穿帮巡检** + 局域网 ComfyUI / BYOK 桥接插件
  - `v1.5+`：六端 `.prj` 全能力对齐 + Lua/WASM 社区插件生态

---

## 项目文档索引（中英双语 1:1 镜像）

项目文档以**英文版**与**中文简体版**作为双基准源同步维护：

| 文档主题 | 简体中文 | English |
| :--- | :--- | :--- |
| 01. 市场竞品调研与二次元痛点分析 | [01-market-research.md](./docs/zh-CN/01-market-research.md) | [01-market-research.md](./docs/en/01-market-research.md) |
| 02. 技术架构选型与平台对比（RFC） | [02-architecture-and-tech-stack.md](./docs/zh-CN/02-architecture-and-tech-stack.md) | [02-architecture-and-tech-stack.md](./docs/en/02-architecture-and-tech-stack.md) |
| 03. AI 辅助创作者工具集规格（含 Gemma 4） | [03-ai-assistant-spec.md](./docs/zh-CN/03-ai-assistant-spec.md) | [03-ai-assistant-spec.md](./docs/en/03-ai-assistant-spec.md) |
| 04. 分阶段开发规划（`v0.1`–`v1.x`） | [04-roadmap.md](./docs/zh-CN/04-roadmap.md) | [04-roadmap.md](./docs/en/04-roadmap.md) |
| 05. 5 语言国际化与界面适配规范 | [05-i18n-and-l10n-guide.md](./docs/zh-CN/05-i18n-and-l10n-guide.md) | [05-i18n-and-l10n-guide.md](./docs/en/05-i18n-and-l10n-guide.md) |
| 06. 开发任务细化清单（WBS） | [06-development-tasks.md](./docs/zh-CN/06-development-tasks.md) | [06-development-tasks.md](./docs/en/06-development-tasks.md) |
| 07. 创作工程文件框架 V1.0（`.prj` / Git） | [07-creative-project-framework-v1.md](./docs/zh-CN/07-creative-project-framework-v1.md) | [07-creative-project-framework-v1.md](./docs/en/07-creative-project-framework-v1.md) |
| 08. 三独立工具原创 UI 设计与 `vX.Y.Z` 小步规划 | [08-tri-app-ui-design-and-patch-roadmap.md](./docs/zh-CN/08-tri-app-ui-design-and-patch-roadmap.md) | [08-tri-app-ui-design-and-patch-roadmap.md](./docs/en/08-tri-app-ui-design-and-patch-roadmap.md) |
| 09. Apple MacBook Pro Xcode 与 Xcode Cloud 开发指南 | [09-apple-xcode-and-cloud-dev-guide.md](./docs/zh-CN/09-apple-xcode-and-cloud-dev-guide.md) | [09-apple-xcode-and-cloud-dev-guide.md](./docs/en/09-apple-xcode-and-cloud-dev-guide.md) |
| 10. 项目开发思路、工程策略、可复用技能与阶段复盘手册 | [10-engineering-retrospective-and-playbook.md](./docs/zh-CN/10-engineering-retrospective-and-playbook.md) | [10-engineering-retrospective-and-playbook.md](./docs/en/10-engineering-retrospective-and-playbook.md) |

- **中英对照综合学习版（含核心双语工程术语词表，每轮 `S4` 定期增补）**：[10-engineering-retrospective-and-playbook-bilingual.md](./docs/bilingual/10-engineering-retrospective-and-playbook-bilingual.md)
- **可交互 HTML UI 设计稿 Demo**：[`S1 创想空间`](./docs/demos/s1_hub_ui_demo.html) · [`S2 雕龙`](./docs/demos/s2_manga_ui_demo.html) · [`S3 文心`](./docs/demos/s3_novel_ui_demo.html)
- **Apple Keynote 兼容双语汇报文稿（14 页）**：[简体中文 `.pptx`](./docs/presentations/About-Paint-Tools_Overview_and_Plan_zh-CN.pptx)（[PDF](./docs/presentations/About-Paint-Tools_Overview_and_Plan_zh-CN.pdf)） · [English `.pptx`](./docs/presentations/About-Paint-Tools_Overview_and_Plan_en.pptx)（[PDF](./docs/presentations/About-Paint-Tools_Overview_and_Plan_en.pdf)）

---

## 仓库目录结构

```text
About-Paint-Tools/
├── LICENSE                      # MIT 开源许可证
├── README.md                    # 英文主页（GitHub 默认入口）
├── README.zh-CN.md              # 简体中文主页
├── docs/
│   ├── zh-CN/                   # 简体中文基准文档（01–09）
│   ├── en/                      # 英文基准文档（1:1 镜像，01–09）
│   ├── assets/ui-mockups/       # S1/S2/S3 原创高清 UI 设计稿（7 张）
│   ├── demos/                   # S1/S2/S3 自包含可交互 HTML UI Demo（3 份）
│   └── presentations/           # 中英双语 Apple Keynote 兼容汇报文稿（.pptx + .pdf）
├── templates/
│   └── SampleManga/             # CPFF v1.0 双引擎标准示例创作工程（SampleManga.prj + Git LFS）
├── i18n/
│   ├── glossary.json            # 二次元绘画、轻小说与三工具代号 5 语词典
│   └── locales/                 # en, zh-Hans（双基准）+ zh-Hant, yue-Hant, es
├── scripts/
│   ├── i18n_check.py            # CI 词条完整性、占位符与西语长度预警校验
│   ├── i18n_sync.py             # 术语锁定同步 + Apple .xcstrings 与 Android strings.xml 导出
│   └── prj_validate.py          # CPFF v1.0 .prj XML、AI 红线隔离与 Git LFS 校验器
├── core/                        # Rust 跨平台画布、套件、姿态与创作工程核心引擎（MIT）
│   └── manga-core/              # 按 Feature 裁剪（hub / canvas / novel）+ suite.rs + platform.rs
└── apps/
    ├── apple/                   # 波次一（v0.9→v1.0）：iPadOS / 触摸屏 MacBook / iPhone Duo 统一壳
    ├── android/                 # 波次二（v1.1）：Android Pad / 折叠屏手机（Compose + WindowManager + Vulkan）
    ├── windows/                 # 波次二（v1.2）：触摸屏 Windows Notebook / Pad（WinUI 3 + DX12）
    └── linux/                   # 波次二（v1.3）：触摸屏 Linux Notebook / Pad（Rust 原生 GTK4/Wayland）
```

---

## 快速本地校验

```bash
# 1. 校验 5 语言词条、Apple .xcstrings & Android strings.xml 同步与中英双语文档镜像
python3 scripts/i18n_check.py && python3 scripts/i18n_sync.py --check-xcstrings --check-android

# 2. 校验 CPFF v1.0 双引擎示例创作工程（SampleManga.prj + AI 隔离红线 + Git LFS）
python3 scripts/prj_validate.py templates/SampleManga

# 3. 校验 C-ABI 头文件、Rust 全工作区单测、三工具 Feature 裁剪及 S4 集成兼容门禁
gcc -std=c11 -Wall -Wextra -Werror -fsyntax-only core/manga-core/include/manga_core.h
cargo test --manifest-path core/Cargo.toml --workspace --all-targets
cargo check --manifest-path core/Cargo.toml -p manga-core --no-default-features --features hub
cargo check --manifest-path core/Cargo.toml -p manga-core --no-default-features --features canvas
cargo check --manifest-path core/Cargo.toml -p manga-core --no-default-features --features novel
cargo run --manifest-path core/Cargo.toml -p manga-linux-shell -- --integration-check
```

---

## 开源协议

本项目基于 [MIT License](./LICENSE) 开源。为保证 iPadOS App Store 合规分发及社区自由商用/二次开发，所有第三方依赖均严格限定于 MIT / Apache-2.0 / BSD / Zlib 兼容协议，严禁引入 GPL/AGPL 依赖。
