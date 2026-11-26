# 10. 项目开发思路、策略与技能综合学习手册（中英对照版）
# 10. Engineering Philosophy, Strategy & Skills Study Handbook (Bilingual Side-by-Side Edition)

**版本导航 / Editions**: [简体中文版](../zh-CN/10-engineering-retrospective-and-playbook.md) | [English Edition](../en/10-engineering-retrospective-and-playbook.md) | **中英对照综合学习版 / Bilingual Study Edition**

> **学习版说明 / About This Study Edition**：
> 本文档将中文深度解析与地道英文工程表达按章节**一一并排对照**，并在文末附带**核心工程术语中英对照词表**，既适合作为项目最终复盘存档，也适合日常精读架构设计、AI Agent 协作与 GitOps 工程英语。
> This edition pairs Chinese engineering analysis side-by-side with idiomatic English technical prose and includes a curated bilingual engineering glossary for both final project archiving and bilingual technical study.
>
> **维护节奏 / Update Cadence**：每个版本的 **`S4` 集成兼容阶段**（`v0.2-S4` … `v1.0-S4`）同步增量补充，直至项目完结定稿。当前覆盖：`v0.1.0` → `v0.2.1` + `GoNext` 熔断护栏体系（Commit `97434c8`）。

---

## 1. 产品与架构顶层思路 / Product & Architectural Philosophy

| 中文精讲 (Simplified Chinese) | English Technical Expression |
| :--- | :--- |
| **1.1 双线并重 × 双引擎并进，但拒绝单体膨胀**<br>传统创作软件要么忽略黑白页漫专业工艺（600DPI B4、网点、斜切分格），要么把小说与条漫硬塞进单一巨型进程，导致 8GB 平板频繁闪退。我们在统一开源 **CPFF v1.0（`.prj`）** 工程格式之上，将能力解耦而非堆砌。 | **1.1 Dual-Track × Dual-Engine Without Monolithic Bloat**<br>Mainstream creative apps either neglect B&W page-manga craft (600DPI B4, screentones, diagonal panel cutting) or bolt novel/webtoon workflows onto one heavyweight process that crashes on 8GB tablets. We unify workflows over one open **CPFF v1.0 (`.prj`)** workspace while cleanly decoupling runtime responsibilities. |
| **1.2 三独立/并发工具套件（`S1`/`S2`/`S3`）+ 强制 `S4` 门禁**<br>- `S1 创想空间/NoemaDock`（`< 200 MB` RAM，无 GPU 画布）：工程总览、导入、跨引擎排期与多语发版；<br>- `S2 雕龙/DracoNib`（`1536 MB` 瓦片预算，满血 GPU 画布）：240Hz 绘图、矢量线稿与网点；<br>- `S3 文心/LitteraCore`（`< 120 MB` RAM，无 GPU 画布）：护眼轻小说、大纲与 EPUB3。<br>Rust 核心 [suite.rs](../../core/manga-core/src/suite.rs) 写死路径**写权隔离**（Write-Ownership Isolation）与 Cargo Feature 分片裁剪；品牌名暂标 `is_final_brand = false`，留待 `v1.0-S4` 一次定稿。 | **1.2 Tri-App Modular Suite (`S1`/`S2`/`S3`) + Mandatory `S4` Gate**<br>- `S1 NoemaDock` (`< 200 MB` RAM, no GPU canvas): Project hub, ingest, dual-engine scheduling & publishing;<br>- `S2 DracoNib` (`1536 MB` tile budget, full GPU canvas): 240Hz drawing, vector lineart & screentones;<br>- `S3 LitteraCore` (`< 120 MB` RAM, no GPU canvas): Eye-friendly light novel editor, outline & EPUB3.<br>Rust [suite.rs](../../core/manga-core/src/suite.rs) enforces hard **Write-Ownership Isolation** and Cargo feature slicing; working codenames stay `is_final_brand = false` until a single branding PR at `v1.0-S4`. |
| **1.3 MIT 纯净度与 AI 隔离红线**<br>核心引擎 `manga-core` 零 GPL/AGPL 依赖、零重型外部库，保证云端与 Xcode Cloud 秒级编译。内嵌本地 **Gemma 4（Apache 2.0）** 的所有参考输出强制隔离在 `ai_assist/`（`role="ai_reference_only"`），Rust 与 Python CI 双层拦截，**AI 永不覆盖人工终稿**。 | **1.3 MIT License Purity & Hard AI Isolation Red Line**<br>`manga-core` keeps zero GPL/AGPL dependencies and zero heavy external crates, enabling sub-second incremental compiles on Cloud VM and Xcode Cloud. All local **Gemma 4 (Apache 2.0)** outputs stay strictly sandboxed in `ai_assist/` (`role="ai_reference_only"`), dual-enforced in Rust and Python CI so **AI never overwrites human canon**. |

---

## 2. 研发策略与工程治理 / Engineering Strategy & Governance

| 中文精讲 (Simplified Chinese) | English Technical Expression |
| :--- | :--- |
| **2.1 文档先行、视觉决策先行（四层低成本收敛漏斗）**<br>在大规模写原生 UI 前依次完成：① 1:1 中英架构文档（`01`–`09`）→ ② 3 代理并行竞品调研与 7 张清洁室原创 UI 稿 → ③ 3 个零依赖交互 HTML 原型（验证图标表意 + 四要素 Hint 气泡）→ ④ 双语 Keynote 4 项关键决策一次性拍板，避免昂贵的原生代码返工。 | **2.1 Doc-First & Visual-First Convergence Funnel**<br>Before writing heavy native UI, major decisions pass four low-cost alignment gates: (1) 1:1 bilingual architecture specs (`01`–`09`) → (2) parallel 3-agent competitive research & 7 clean-room MIT UI mockups → (3) 3 zero-dependency interactive HTML demos (validating Icon-First + 4-element Hint Popovers) → (4) bilingual Keynote sign-off on 4 executive decisions to eliminate rework. |
| **2.2 SemVer 第三位（`vX.Y.Z`）先核后壳小步并行**<br>每个次版本拆为多轮补丁波次（如 `v0.2.1` 先把 S1 `project_init.rs`、S2 `brush.rs`、S3 `novel.rs` 与 C-ABI/Swift 桥接跑通 48 项单测与 E2E 校验，`v0.2.2` 再接 UI 壳与 Metal 管线），最后统一进入 `T0.X-S4` 集成门禁合入发布。 | **2.2 SemVer 3rd-Segment (`vX.Y.Z`) Core-Before-Shell Delivery**<br>Each minor milestone advances through focused patch waves (`v0.2.1` ships deterministic Rust + C-ABI + Swift cores verified by 48 unit tests & E2E checks before `v0.2.2` binds native UI shells & Metal pipelines), converging into a mandatory `T0.X-S4` integration release PR. |
| **2.3 单一真相源（Single Source of Truth）零漂移契约**<br>- 5 语言词条唯一源：`i18n/locales/*.json`（禁止在 Xcode 直接改 `.xcstrings`）；<br>- Apple 工程唯一源：`apps/apple/project.yml`（`.xcodeproj` 入 `.gitignore`）；<br>- 双语文档唯一契约：`docs/en/` ↔ `docs/zh-CN/` 1:1 镜像，CI 自动检查。 | **2.3 Single-Source-of-Truth (Zero-Drift) Contracts**<br>- 5-locale UI strings: `i18n/locales/*.json` only (never hand-edit `.xcstrings` in Xcode);<br>- Apple project config: `apps/apple/project.yml` only (`.xcodeproj` gitignored);<br>- Bilingual docs: 1:1 filename parity between `docs/en/` and `docs/zh-CN/`, enforced in CI. |

---

## 3. 云-端混合协同与 `GoNext` 自动化 / Cloud ↔ Local Hybrid Workflow & `GoNext` Automation

| 中文精讲 (Simplified Chinese) | English Technical Expression |
| :--- | :--- |
| **3.1 云端 Linux VM × 本地 M5 Pro MacBook 黄金分工**<br>云端专攻 Rust 核心、跨端代码、文档、i18n 与全套 CI；本地 MacBook Pro 专攻 Xcode 27+、三切片 `MangaCore.xcframework`、Metal 渲染与真机调试。通过根目录 [Makefile](../../Makefile) + [scripts/dev.sh](../../scripts/dev.sh) 与 `core/` SHA-256 增量指纹，仅改 Swift 时按 `⌘R` **< 50ms 跳过 Rust 重编**。 | **3.1 Clear Cloud Linux VM × Local M5 Pro MacBook Split**<br>Cloud VM owns platform-agnostic Rust core, cross-platform code, docs, i18n, and CI; local MacBook Pro owns Xcode 27+, 3-slice `MangaCore.xcframework`, Metal rendering, and device profiling. Root [Makefile](../../Makefile) + [scripts/dev.sh](../../scripts/dev.sh) compute a SHA-256 fingerprint of `core/` so pure Swift `⌘R` builds **skip Rust in `< 50ms`**. |
| **3.2 只增不改、零冲突 `GoNext` GitOps 异步接力**<br>云端仅追加 `ops/relay/orders/<TS>_<slug>.json`，Mac 仅追加同名回执 `ops/relay/results/<TS>_<slug>.result.md`：天然零合并冲突，且完整留存为时间序研发审计日志。采用**声明式白名单安全锁**（禁止任意 Shell 注入），对公开 MIT 仓库比挂载 GitHub Self-Hosted Runner 更安全轻量。 | **3.2 Append-Only, Zero-Conflict `GoNext` GitOps Relay**<br>Cloud appends only `ops/relay/orders/<TS>_<slug>.json`; Mac appends only `ops/relay/results/<TS>_<slug>.result.md` with the identical `order_id` — eliminating merge conflicts while preserving a chronological audit trail. A **declarative action allowlist** (no arbitrary shell execution) is far safer for public MIT repos than attaching a GitHub Self-Hosted Runner. |
| **3.3 双端五层防死循环熔断护栏**<br>① 总时长预算（`MAX_MIN`）：绝不腰斩在途构建，完成当前最后 1 单并推回回执后再自动停止并弹系统通知；<br>② 总单数上限（`MAX_ORDERS`）：逐单（`--single-order`）核算；<br>③ 死循环发现（`MAX_FAILS` + `DUPLICATE_ERROR_LOOP`）：连续失败或连续 2 次归一化错误指纹完全一致立即 `exit 42` 熔断锁定；<br>④ 双向急停：本地 `make relay-stop` 与远端 `ops/relay/PAUSE`。 | **3.3 Two-Sided Five-Layer Loop-Detection Circuit Breakers**<br>(1) Wall-clock budget (`MAX_MIN`): never aborts an active build mid-flight — finishes & pushes the in-flight `.result.md`, then auto-stops & notifies;<br>(2) Order cap (`MAX_ORDERS`): `--single-order` per tick enforces exact counts;<br>(3) Loop detection (`MAX_FAILS` + `DUPLICATE_ERROR_LOOP`): trips immediately (`exit 42`) on fail streaks or 2 consecutive identical normalized error fingerprints;<br>(4) Two-way kill switch: local `make relay-stop` and repository `ops/relay/PAUSE`. |

---

## 4. 真实踩坑与排障案例对照库 / Real-World Troubleshooting Casebook

| # | 症状与根因（中 / EN） | 永久根治方案（中 / EN） |
| :--- | :--- | :--- |
| **1** | **CLT 路径冲突**：`xcodebuild -license accept` 报当前激活目录是 `CommandLineTools`。<br>*CLT Path Mismatch*: active developer directory pointed to CommandLineTools instead of `Xcode.app`. | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| **2** | **Xcode 编译改写 `.xcstrings`**：未改源码但 `Localizable.xcstrings` 被自动提取弄脏。<br>*Xcode Auto-Mutating `.xcstrings`*: compiler string extraction dirtied `Localizable.xcstrings` on build. | 在 `project.yml` 设 `SWIFT_EMIT_LOC_STRINGS: NO` 与 `LOCALIZED_STRING_SWIFTUI_SUPPORT: NO`。<br>*Disable both flags in `project.yml` so JSON catalogs stay the single source of truth.* |
| **3** | **Xcode 15+ 脚本沙盒**：`preBuildScripts` 读取上级 `core/` 可能触发沙盒拒绝。<br>*User Script Sandboxing*: Xcode 15+ blocks Run Scripts from reading parent `core/` dirs by default. | 在 `project.yml` 显式设 `ENABLE_USER_SCRIPT_SANDBOXING: NO`。<br>*Explicitly set `ENABLE_USER_SCRIPT_SANDBOXING: NO` in `project.yml`.* |
| **4** | **GoNext Order #1 缺 Scheme（exit 65）**：无头 `xcodebuild` 找不到 `MangaStudio-iPadOS`。<br>*Missing Shared Schemes*: XcodeGen omitted shared `.xcscheme` files without a `schemes:` block. | 在 `project.yml` 顶层为 3 个 Target 显式声明共享 `schemes:`。<br>*Declare explicit top-level shared `schemes:` for all 3 targets in `project.yml`.* |
| **5** | **GoNext Order #2 多余 `x86_64` 链接失败**：`arm64` 已通过，但通用模拟器尝试链接 Intel `x86_64`。<br>*Stray Intel `x86_64` Slice*: `generic/platform=iOS Simulator` linked `x86_64` against an `arm64`-only `XCFramework`. | 在 `project.yml` 加 `ARCHS: arm64` 与 `"EXCLUDED_ARCHS[sdk=iphonesimulator*]": x86_64`（Order #3 7秒 7/7 全绿）。<br>*Set `ARCHS: arm64` + exclude `x86_64` simulator slice (Order #3 passed 7/7 in 7s).* |
| **6** | **首跑管理员密码提示**：新装 Xcode 前 2 次 `gonext` 触发 `DevToolsSecurity` / Keychain 一次授权。<br>*Initial Admin Prompts*: fresh Xcode triggers one-time `DevToolsSecurity` & Keychain authorization. | 验证 `DevToolsSecurity -status` 与 `gh auth status`；日常优先在解锁终端跑 `make relay-watch`。<br>*Verify `DevToolsSecurity` & `gh auth status`; prefer `make relay-watch` inside unlocked session.* |
| **7** | **CPFF XML 字段漂移**：初版 `project_init.rs` 的 `<Edition>` 缺必填属性导致解析数为 0。<br>*CPFF XML Schema Drift*: early `project_init.rs` omitted required `<Edition>` attributes. | 严格对齐 `SampleManga.prj` 并以真实 `prj_validate.py` 做端到端测试。<br>*Align with canonical `SampleManga.prj` and gate with real `prj_validate.py` E2E test.* |
| **8** | **双语 Keynote 视觉缺陷**：代码生成 `.pptx` 出现残留语言标题与版面拥挤。<br>*Programmatic Slide Visual Defects*: stray language headings & tight banners in generated `.pptx`. | 用 `libreoffice` → `pdftoppm` 渲染整套 PNG 逐页肉眼复检。<br>*Render all slides to PNG via `libreoffice` + `pdftoppm` and visually QA every slide.* |
| **9** | **LaunchAgent 自我卸载残余 `.plist`**：到点触发 `bootout` 立刻 `SIGTERM` 终止进程，后续 `rm -f` 未运行。<br>*LaunchAgent Self-Bootout Timing*: `launchctl bootout` terminates the agent immediately before subsequent `rm -f *.plist`. | 先 `rm -f *.plist *.budget` 再 `bootout`，并在 `status` 中用 `launchctl print` 查询真实加载态。<br>*Delete plist/budget BEFORE `bootout` and query live `launchctl print` in `status`.* |
| **10** | **无签名 macOS 宿主单测风险**：`TEST_HOST` 注入开启硬化运行时的 App 易遇 `dyld` 拦截。<br>*Hardened Runtime `TEST_HOST` Friction*: unsigned host-injected macOS tests risk `dyld` signature rejections. | 采用独立逻辑 `bundle.unit-test` 直链 `MangaCore.xcframework`（排除 `@main`），免签名跑 9/9 真机 FFI 测试。<br>*Use standalone `bundle.unit-test` linking `MangaCore.xcframework` directly for zero-signing live FFI XCTests.* |

---

## 5. 可复用 Agent Skills 技能对照 / Reusable Agent Skills Map

| Skill | 中文职责定位 | English Operational Scope |
| :--- | :--- | :--- |
| **`gitops-gonext-relay-setup`** | **云-端接力脚手架**：在任意新仓库一键搭建零冲突 `orders/`↔`results/` 协议、白名单校验、本地执行器、`launchd` 服务、`Makefile` 与 CI 门禁。 | **Relay Infrastructure Scaffold**: Scaffolds zero-conflict `orders/`↔`results/`, strict allowlist validator, local runner, macOS `launchd` agent, `Makefile` shortcuts, and CI schema gate into any hybrid Cloud+Hardware repo. |
| **`gitops-gonext-dispatch`** | **日常调度闭环**：规范“云端校验 → `guard-check` → 签发最小白名单 `GoNext` 单 → 有界 `wait` → 绿灯推进 / 红灯修复”标准迭代节奏。 | **Guarded Dispatch Loop**: Runs cloud CI → audits `guard-check` → emits minimal allowlisted `GoNext` order → waits boundedly for receipt → advances on PASS or diagnoses on FAIL. |
| **`gitops-gonext-circuit-breaker`** | **自主循环安全护栏**：通用的时长上限（`MAX_MIN`）、次数上限（`MAX_ORDERS`）、重复错误指纹死循环检测（`DUPLICATE_ERROR_LOOP`）、优雅收尾与双向急停范式。 | **Autonomous Loop Guardrails**: Reusable pattern for wall-clock limits (`MAX_MIN`), iteration caps (`MAX_ORDERS`), duplicate-error fingerprinting (`DUPLICATE_ERROR_LOOP`), graceful in-flight completion, and two-way kill switches. |

---

## 6. 核心中英工程术语对照词表 / Core Bilingual Engineering Glossary

| 中文术语 | English Term | 本项目语境精解 / Contextual Note |
| :--- | :--- | :--- |
| 单一真相源 | **Single Source of Truth (SSOT)** | 如 `i18n/locales/*.json` 与 `apps/apple/project.yml`，所有派生文件一律自动生成、禁止手改。 |
| 写权隔离 | **Write-Ownership Isolation** | 通过路径白名单确保多工具并发访问同一 `.prj` 工程时互不覆写数据。 |
| 清洁室设计 | **Clean-Room Design** | 遵循行业交互惯例但 100% 原创视觉与代码，确保 MIT 开源无侵权风险。 |
| 只增不改协议 | **Append-Only Protocol** | 历史订单与回执只新增不修改，从结构上消除 Git 合并冲突并保留审计日志。 |
| 声明式动作白名单 | **Declarative Action Allowlist** | 仅允许触发预审动作名（如 `build-ipad`），彻底杜绝远程任意 Shell 注入风险。 |
| 熔断器 | **Circuit Breaker** | 检测到连续失败或重复错误死循环时自动切断循环并锁定，防止无限空耗。 |
| 重复错误指纹识别 | **Duplicate-Error Fingerprinting** | 剔除时间戳/路径噪声后对报错做哈希，连续两次同错立刻识别为死循环。 |
| 优雅收尾 | **Graceful Completion** | 到达时长/次数上限时不腰斩当前编译，完成最后一单并推回回执后再停止。 |
| 双向急停开关 | **Two-Way Kill Switch** | 本地 `make relay-stop` 与仓库远端 `ops/relay/PAUSE` 任一侧均可一秒刹停。 |
| 增量指纹缓存 | **Incremental Fingerprint Stamp** | 用 SHA-256 校验 `core/` 源码变化，无变更时 `< 50ms` 跳过昂贵的跨平台 Rust 编译。 |

---

## 7. 阶段复盘定期增补表 / Living Milestone Retrospective Log

| 阶段 / Milestone | 中文总结 / Chinese Summary | English Summary |
| :--- | :--- | :--- |
| **`v0.1.0`** (`3c52338`) | 确立 MIT 开源底座、CPFF v1.0、双线双引擎、三独立工具与 `S4` 门禁，用 Rust 提前锁死写权隔离与内存预算。 | Established MIT baseline, CPFF v1.0, Dual-Track × Dual-Engine, Tri-App modularization & `S4` gate, locking write-ownership and RAM budgets in Rust upfront. |
| **`v0.2.0`–`v0.2.1`** (`9227d14`→`97434c8`) | 完成 UI 稿/HTML 原型/双语 Keynote 4 项决策；交付 S1/S2/S3 `v0.2.1` 核心（48 测）；跑通 M5 Pro 7 秒 7/7 全绿与带五层熔断的 `GoNext` 闭环并沉淀 3 项 Skills。 | Finalized UI mockups, HTML demos & 4 Keynote decisions; shipped `v0.2.1` S1/S2/S3 cores (48 tests); achieved 7/7 PASS in 7s on M5 Pro via guarded `GoNext` Relay and distilled 3 reusable Skills. |
| **`v0.2.2`–`v0.2.3` & `T0.2-S4`** (`v0.2.0`) | 交付 18 枚原创 MIT 图标、四要素 Hint 气泡、三工具原生 SwiftUI 壳、`RenamedFolderFallback`、变宽笔刷盖章、原子保存锁与 100 轮三工具并发压测门禁，M5 Pro 实跑 9/9 真机 FFI XCTest 全绿。 | Shipped 18 clean-room MIT icons, 4-element Hint Popovers, native SwiftUI Tri-App shells, `RenamedFolderFallback`, tapered brush stamping, atomic save guard & 100-round concurrency soak gate verified by 9/9 live M5 Pro FFI XCTests. |
| **`v0.3.1`–`v0.3.2` & `T0.3-S4`** | 交付 `S1` 设定圣经/总目录原子读写 + 左侧工程树与实时角色卡编辑、`S2` 13 种赛璐璐混合与右侧图层抽屉（`R`/`✂`/`🔒`/`B`+显隐）及画布实时多层混合、`S3` 250ms `< 300ms` 磁盘指纹无感热刷新，落地 **`T0.3-S4` 集成门禁**并通过 52 Rust 单测 + 15 M5 Pro 真机 FFI 单测。 | Shipped `S1` atomic Story Bible/TOC + Left Project Tree & live character editor, `S2` 13 cel blend modes + right layer drawer (`R`/`✂`/`🔒`/`B` + visibility) & live multi-layer canvas compositing, `S3` 250ms `< 300ms`-SLA disk revision hot-reload, and **`T0.3-S4` gate** verified by 52 Rust tests + 15 live M5 Pro FFI XCTests. |
| **`v0.4-S4` – `v1.0-S4`** | _随每个 `S4` 阶段定期同步增补，项目完成后形成最终中英对照归档版。_ | _Appended at each `S4` integration gate, culminating in the final archived study edition upon release._ |
