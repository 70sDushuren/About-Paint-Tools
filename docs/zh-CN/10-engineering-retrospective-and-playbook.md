# 10. 项目开发思路、工程策略、可复用技能与阶段复盘手册（持续更新版）

**语言 / Language**: [English](../en/10-engineering-retrospective-and-playbook.md) | **简体中文** | [中英对照综合学习版](../bilingual/10-engineering-retrospective-and-playbook-bilingual.md)

> **文档定位**：本文档是 **About-Paint-Tools** 项目的活文档（Living Engineering Playbook & Retrospective），系统记录从架构蓝图到发版落地全过程的**顶层思路、研发策略、踩坑排障经验与可复用 AI Agent 技能（Skills）**。
> **维护节奏**：在每个版本的 **`S4` 集成兼容修订阶段**（`v0.2-S4`、`v0.3-S4` … `v1.0-S4`）强制补充最新实战复盘，待项目完结时汇总形成最终项目开发工作总结存档。
> **当前覆盖范围**：`v0.1.0-architecture-baseline` → `v0.2.1` + 云-端 `GoNext` 自动化与熔断护栏体系（Commit `97434c8`）。

---

## 1. 产品与架构顶层思路

### 1.1 “双线并重 × 双引擎并进”但不膨胀
- **痛点洞察**：主流创作软件往往在“黑白页漫专业度”与“全彩条漫/轻小说联动”之间顾此失彼，或把所有功能塞进单一巨型进程导致平板 8GB 内存频频闪退。
- **核心解法**：在统一的 **CPFF v1.0（`.prj`）** 开源创作工程格式之上，实现黑白页漫（600DPI B4/网点/分格）与全彩条漫/插画（竖向切片/赛璐璐）双线并重，同时将轻小说与漫画纳入同一作品工程并进演化。

### 1.2 三独立/并发工具架构（`S1`/`S2`/`S3`）+ 强制 `S4` 集成门禁
- **轻重分离与内存硬预算**：
  - `S1` **创想空间 / `NoemaDock`**（`< 200 MB` RAM，无 GPU 画布）：工程总览、导入、跨引擎排期与多语言发版；
  - `S2` **雕龙 / `DracoNib`**（`1536 MB` 瓦片预算，满血 GPU 画布）：240Hz 专业绘图、矢量线稿、网点与图层；
  - `S3` **文心 / `LitteraCore`**（`< 120 MB` RAM，无 GPU 画布）：护眼轻小说写作、大纲、插图管理与 EPUB3。
- **写权隔离（Write-Ownership Isolation）**：在 Rust 核心 [suite.rs](../../core/manga-core/src/suite.rs) 中硬编码三款工具对 `.prj` 子路径的独占写权（例如仅 `S3` 可写 `chapters/*/novel/novel_meta.xml` 与 `novel/prose/`），从底层杜绝 iPad/Mac 分屏同开时的并发写冲突。
- **Cargo Feature 分片裁剪**：`hub` / `canvas` / `novel` 三套 Feature 独立编译验证，确保非画布应用不背负 GPU 引擎依赖。
- **暂定代号治理**：三款工具品牌名在代码与词条中均标记 `is_final_brand = false` / `locked = false`，避免研发前期因改名反复返工，留待 `v1.0-S4` 专项 PR 一次定稿。

### 1.3 MIT 纯净度与 AI 隔离红线
- **零 GPL/AGPL 依赖**：核心 Rust 引擎 `manga-core` 保持零重型外部依赖，编译极快且 100% 兼容商业与开源二次开发。
- **AI 永不覆盖人工终稿**：内嵌本地 **Gemma 4（E2B/E4B, Apache 2.0）** 的一切文本/分镜/参考输出强制隔离在 `ai_assist/`（`role="ai_reference_only"`），由 Rust 核心与 Python CI 脚本（[prj_validate.py](../../scripts/prj_validate.py)）双层拦截越界写入。

---

## 2. 研发策略与工程治理方法论

### 2.1 文档先行、视觉决策先行（Doc-First & Visual-First）
在大规模写 UI 代码之前，先走完四层低成本收敛漏斗：
1. **1:1 中英镜像架构文档**：先定清数据格式（CPFF）、技术栈与任务拆解（文档 `01`–`09`）；
2. **多代理并行市场调研与原创视觉稿**：用 3 个专项代理并行调研 20+ 主流/开源竞品，产出 7 张清洁室原创 MIT UI 视觉稿；
3. **可交互 HTML 原型**：把静态设计稿做成 3 个零依赖交互 Demo（图标表意为主 + 四要素 Hint 气泡），在写原生 Swift/Metal 前验证信息密度与交互手感；
4. **双语 Keynote 决策评审**：把核心分歧提炼为 4 项可执行决策，一次性拍板后才全面进入代码迭代。

### 2.2 SemVer 第三位（`vX.Y.Z`）精细化小步并行推进
- 每个次版本（如 `v0.2`）拆分为多轮小补丁（`v0.2.1` 核心内核 → `v0.2.2` 原生 UI 壳与硬件管线 → …），每轮按 `S1`/`S2`/`S3` 三线独立交付，最后统一收敛到 **`T0.X-S4` 集成兼容修订阶段**通过联调门禁再合入发布。
- **先核后壳**：`v0.2.1` 先把 `project_init.rs`（S1）、`brush.rs`（S2）、`novel.rs`（S3）在 Rust 核心与 C-ABI/Swift 桥接层跑通 48 项单测与端到端校验，确保 UI 层拿到的全是确定性、可复现的底层能力。

### 2.3 单一真相源（Single Source of Truth）防漂移策略
| 领域 | 唯一真相源 | 自动同步 / 校验工具 | 禁止事项 |
| :--- | :--- | :--- | :--- |
| **5 语言国际化** | `i18n/locales/*.json` + `glossary.json` | `i18n_check.py` + `i18n_sync.py` | 严禁仅在 Xcode 中直接改 `.xcstrings` |
| **Apple 工程配置** | `apps/apple/project.yml` | `xcodegen generate`（`.xcodeproj` 入 `.gitignore`） | 严禁手改 `.pbxproj` 后直接提交 |
| **双语工程文档** | `docs/zh-CN/` ↔ `docs/en/` 1:1 镜像 | `i18n_check.py` CI 强制比对文件名集合 | 严禁单语新增或遗漏镜像 |
| **CPFF 工程规范** | `templates/SampleManga/` + `07` 规范 | Rust `project.rs` + Python `prj_validate.py` | 严禁跳过 AI 沙盒与写权负向校验 |

---

## 3. 云-端混合开发与 `GoNext` GitOps 自动化体系

### 3.1 云端 Linux VM × 本地 Apple Silicon MacBook 黄金分工
- **云端 Linux VM**：专攻 Rust 跨平台内核、C11 ABI、Swift/Android/Win 源码、5 语 i18n、双语文档与全量 CI 测试。
- **本地 M5 Pro MacBook Pro**：专攻 Xcode 27+、三切片 `MangaCore.xcframework`、Metal GPU 渲染与真机/模拟器调试。
- **单工程多 Target + 增量构建**：全套 Apple 端统一收口在 1 个 [project.yml](../../apps/apple/project.yml)；通过 `core/` SHA-256 指纹缓存（[scripts/dev.sh](../../scripts/dev.sh)），仅改 Swift 时在 Xcode 中按 `⌘R` 自动跳过 Rust 重编（`< 50ms`），改过 Rust 时自动增量更新。

### 3.2 零冲突 `GoNext` GitOps 异步接力（[ops/relay/](../../ops/relay/README.md)）
- **只增不改配对日志**：云端只向 `ops/relay/orders/<TS>_<slug>.json` 追加任务单，Mac 只向 `ops/relay/results/<TS>_<slug>.result.md` 追加同名回执。天然零合并冲突，且永久留存为时间序研发审计日志。
- **声明式白名单安全锁（优于 Public 仓库挂 Self-Hosted Runner）**：公开开源仓库不宜直接挂 GitHub Self-Hosted Runner（防外部 PR 注入）；`GoNext` 仅跟踪 `origin/main`，且每条指令都由 CI 与本地双层白名单校验，杜绝任意 Shell 执行。
- **终端与云端双向防死循环熔断护栏**：
  1. **总时长预算（`MAX_MIN`）**：优雅完成在途最后一单并推回回执后再自动停止并弹出系统通知；
  2. **总单数预算（`MAX_ORDERS`）**：自动模式逐单（`--single-order`）核算，达上限即停；
  3. **死循环自动识别（`MAX_FAILS` + `DUPLICATE_ERROR_LOOP`）**：连续失败达阈值或连续 2 次报错归一化指纹完全一致，立刻熔断锁定（`exit 42`）等待人工核查；
  4. **双向急停开关**：本地 `make relay-stop` / `make relay-resume`，远端 `ops/relay/PAUSE`。

---

## 4. 真实踩坑与排障案例库（持续增补）

> 以下每一条均为本项目实战中真实触发、通过自动化回执或测试定位并根治的问题。

| # | 阶段 | 触发症状 | 根因定位 | 永久根治方案 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Mac 环境部署 | `sudo xcodebuild -license accept` 报 `requires Xcode, but active developer directory is CommandLineTools` | 系统默认激活目录指向轻量 CLT 而非完整 `Xcode.app` | 执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| 2 | Xcode 首跑 | 编译运行未改源码，但 `git status` 显示 `Localizable.xcstrings` 被修改 | Xcode 15–27 默认开启编译期自动字符串提取，会原地改写 `.xcstrings` | 在 `project.yml` 设 `SWIFT_EMIT_LOC_STRINGS: NO` 与 `LOCALIZED_STRING_SWIFTUI_SUPPORT: NO` |
| 3 | Xcode 增量钩子 | 新版 Xcode 中 Run Script 读取仓库上级 `core/` 可能触发沙盒拒绝 | Xcode 15+ 默认启用 `ENABLE_USER_SCRIPT_SANDBOXING=YES` | 在 `project.yml` 显式关闭 `ENABLE_USER_SCRIPT_SANDBOXING: NO` |
| 4 | GoNext Order #1 | `build-mac` 通过，但 `build-ipad` 报 `does not contain a scheme named "MangaStudio-iPadOS"`（exit 65） | `project.yml` 未声明顶层 `schemes:`，XcodeGen 未导出共享 `.xcscheme` | 在 `project.yml` 为全部 Target 显式声明共享 `schemes:` |
| 5 | GoNext Order #2 | `arm64` 链接成功，但 `build-ipad` 报 `Undefined symbols for architecture x86_64` | `generic/platform=iOS Simulator` 默认顺带编旧款 Intel `x86_64`，而 `XCFramework` 为纯 `arm64` | 在 `project.yml` 设置 `ARCHS: arm64` 与 `"EXCLUDED_ARCHS[sdk=iphonesimulator*]": x86_64`（Order #3 7秒 7/7 全绿） |
| 6 | Mac 自动执行 | 前两次 `make gonext` 弹窗索要管理员密码，后面不再弹出 | 新装 Xcode 首次运行触发一次性 `DevToolsSecurity` 与 Keychain 授权 | 验证 `DevToolsSecurity -status`、`gh auth status`；日常优先在解锁会话运行 `make relay-watch` |
| 7 | CPFF 初始化 | `project_init.rs` 初始生成 XML 的 `<Edition>` 节点缺失属性导致解析计数为 0 | 与规范模板 `SampleManga.prj` 必填属性未完全对齐 | 对齐 `SampleManga.prj` 全属性并用真实 `prj_validate.py` 做 E2E 验证 |
| 8 | 双语 Keynote | 英文版幻灯片个别卡片残留中文标题、Banner 文字略拥挤 | 仅靠代码生成未做视觉验收 | 用 `libreoffice` → `pdftoppm` 导出整套 PNG 逐页肉眼复检并修正 |
| 9 | Google Drive CLI | `gdrive mutate mkdir --json \| jq` 报解析错误 | `mutate mkdir` 输出为纯文本而非 JSON | 建完目录后改用 `gdrive readonly ls <parent> --json` 精确读取目录 ID |
| 10 | LaunchAgent 到期自卸载 | 120 分钟到点后状态变为 `PAUSED`，但 `make relay-status` 仍显示 `LaunchAgent: INSTALLED` | 在 `launchd` 自身进程内调用 `launchctl bootout` 会立刻触发 `SIGTERM`，后续 `rm -f *.plist` 来不及执行 | 先 `rm -f *.plist *.budget` 再 `launchctl bootout`，并在 `status` 中用 `launchctl print` 查询真实加载态（`6fd21fb`） |
| 11 | macOS 自动化 XCTest | 带 `ENABLE_HARDENED_RUNTIME` + `CODE_SIGNING_ALLOWED=NO` 的宿主 App 跑 `TEST_HOST` 单测易遇 `dyld` 签名校验拦截 | 宿主注入式测试依赖签名一致 | 采用独立逻辑 `bundle.unit-test`（直链 `MangaCore.xcframework`、排除 `@main`），免签名 0.008 秒实跑 9/9 真机 FFI 单测 |

---

## 5. 已沉淀的可复用 Agent Skills 技能体系

本项目不仅交付代码，还将跨项目通用的高价值工程范式抽象沉淀为 **3 项可复用 Skills**：

| Skill 名称 | 抽象层级 | 核心解决什么问题 | 典型复用场景 |
| :--- | :--- | :--- | :--- |
| **`gitops-gonext-relay-setup`** | 基础设施脚手架 | 在任意新仓库一键搭建零冲突 `orders/`↔`results/` 协议、白名单校验、本地执行器、`launchd` 后台服务、`Makefile` 与 CI 门禁 | 新建“云端 Agent + 本地硬件（Mac/Windows GPU/Android/嵌入式）”混合研发仓库 |
| **`gitops-gonext-dispatch`** | 日常调度闭环 | 规范“云端校验 → `guard-check` 审计 → 签发最小白名单 `GoNext` 单 → 有界 `wait` 收回执 → 绿灯推进/红灯修复”标准节奏 | 迭代期每一轮 `vX.Y.Z` 联调与跨端真机回归 |
| **`gitops-gonext-circuit-breaker`** | 自主循环安全护栏 | 为任何长时间自主循环提供时长硬上限（`MAX_MIN`）、次数上限（`MAX_ORDERS`）、连续失败与重复错误指纹检测（`DUPLICATE_ERROR_LOOP`）、优雅收尾与双向急停 | 防止长跑自动化任务或 `/goal` 多轮修复陷入死循环或资源空耗 |

> **后续待抽象 Skill 规划**（随项目推进逐步补全）：
> - `metal-240hz-brush-profiler`（`v0.3` 阶段沉淀：Metal 帧剖析与 Pencil Pro 延迟/内存回归验收）
> - `cpff-tri-app-s4-gate`（`v0.4`–`v0.9` 阶段沉淀：三工具联调、5 语溢出与双引擎一致性自动审计）

---

## 6. 后续阶段定期增补日志（Milestone Retrospective Log）

> **维护约定**：每完成一个次版本的 `S4` 集成兼容阶段，在此表追加一条复盘条目，并同步补充第 4 节踩坑库与第 5 节技能体系。

| 里程碑 | 完成日期 / Commit | 核心交付与架构演进 | 本阶段关键经验提炼 |
| :--- | :--- | :--- | :--- |
| **`v0.1.0` 架构基座** | `3c52338` (`v0.1.0-architecture-baseline`) | MIT 协议、CPFF v1.0、双线双引擎、6 大硬件规划、三独立工具模块与 `S4` 门禁、46×5 语言 i18n | 用 Rust `suite.rs` 提前锁死写权隔离与内存预算，后续 UI 怎么迭代都不会破坏多工具并发安全性 |
| **`v0.2.0`–`v0.2.1` 设计定稿 + Apple 全端打通 + `GoNext` 闭环** | `9227d14` → `66e7ceb` → `8f53934` → `97434c8` | 7 张 UI 稿、3 个 HTML Demo、双语 Keynote 4 项决策定稿；S1/S2/S3 `v0.2.1` 核心内核（48 测全过）；M5 Pro 7 秒 7/7 全绿；`GoNext` Relay 与三层熔断体系及 3 项 Skills | 先通过可视化 Demo 与 Keynote 统一认知，再把云-端真机验证做成带熔断的自动化接力，排障周期从人工贴日志压缩到秒级闭环 |
| **`v0.2.2`–`v0.2.3` & `T0.2-S4` 收官** | `0ffb9fb` → `7fa92ad` → `7410dea` (`v0.2.0`) | 18 枚原创 MIT 图标 + 四要素 Hint 气泡 + 三工具原生 SwiftUI 壳；`RenamedFolderFallback`、变宽笔刷盖章、原子写锁与 **100 轮三工具并发压测门禁（`run_t02_s4_concurrency_soak`）**；9 项 M5 Pro 实机 Swift ↔ Rust FFI XCTest 全绿 | 独立逻辑 `bundle.unit-test` 让真机 FFI 回归测试摆脱签名束缚；`launchd` 自我卸载须先删 `.plist` 再 `bootout`，120 分钟真实到期熔断零误触 |
| **`v0.3.1`–`v0.3.2` & `T0.3-S4` 收官** | `719ef10` → `bbfcf96` (`v0.3.0`) | `S1` 设定圣经（`bible/characters.xml`）与总目录（`outline/toc.xml`）原子读写 + 左侧工程树与实时角色卡编辑；`S2` 13 种赛璐璐混合模式与右侧图层抽屉（`R`/`✂`/`🔒`/`B`+显隐）及画布实时多层混合预览；`S3` 250ms 磁盘指纹监听 `< 300ms` 无感热刷新（实测 `0–1ms`）；**`T0.3-S4` 集成门禁（`run_t03_s4_bible_layers_gate`）** 接入 Linux CI 与 M5 Pro **15/15 真机 FFI 单测** | 跨应用同步用“调用方自持 UTF-8 缓冲 + 64 位 FNV-1a 内容指纹”跨越 C-ABI，避免跨语言堆释放泄漏与 `FSEvents` 平台碎片化，热刷新稳定在 `1ms` 量级且不打断编辑器光标 |
| **`v0.4.0` & `T0.4-S4` 收官** | `de14944` (`v0.4.0`) | `S1` 外部素材与文稿入库规范化器（`ingest.rs`，自动防重命名 `-v2` 且文稿严格隔离在 `ai_assist/ingest_staging/`）；`S2` 自由套索选区掩膜（`selection.rs`，射线法/反选/扩缩边）+ `3px` 闭口防白边油漆桶实机接入；`S3` 5 语言正文切换与 `<DivergenceNote>` XML 双向读写编辑器；**`T0.4-S4` 集成门禁** + 55 Rust 单测 + **18/18 M5 Pro 真机 FFI 单测** | 外部导入文稿绝不直写 `novel/prose/`，一律先入 `ai_assist/ingest_staging/` 并自动防撞名 `-v2`，把“零覆盖人工终稿”原则从 AI 扩展到全量导入链路 |
| **`v0.5.0` & `T0.5-S4` 收官** | `0497596` (`v0.5.0`) | `S1` 5 语言专有名词词典（`bible/glossary.xml`）与完整度巡检矩阵（`glossary.rs`）；`S2` 矢量线稿层 4× 无损缩放、一笔矢量交点橡皮擦与对称/平行/两点透视/集中线尺规全 C-ABI 实机接入；`S3` 5 语专有名词只读联想快捷插入栏；**`T0.5-S4` 集成门禁** + 57 Rust 单测 + **21/21 M5 Pro 真机 FFI 单测** | 尺规数学统一封装在纯 Rust `manga_ruler_transform_point` C-ABI，避免 Swift/Android/Windows 三端重复实现浮点几何逻辑导致吸附偏差 |
| **`v0.6.0` & `T0.6-S4` 收官** | `d1af860` (`v0.6.0`) | `S1` 多发行版发布中心与 5 语言气泡完整度巡检（`editions/publish_report.xml`）；`S2` B4 600DPI 斜切四格分格 + 4 种程序化网点纸（圆点/线条/交叉/噪点）+ `1280px` 零接缝条漫切片；`S3` 轻小说 EPUB3 XHTML 章节导出器（`bubble.rs`）；**`T0.6-S4` 双线端到端门禁** + 59 Rust 单测 + **24/24 M5 Pro 真机 FFI 单测** | 用同一个 `T0.6-S4` 门禁同时回归“黑白页漫 4 格+网点+竖排气泡”、“全彩条漫 10 切片零接缝”与“轻小说 EPUB3 导出”，确保双线双引擎同步演进不偏科 |
| **`v0.7.0` & `T0.7-S4` 收官** | `v0.7.0` | `S2` 开放 `.mnga` 二进制手稿编解码器（`mnga.rs`，FNV-1a 64 位完整性校验 + 防篡改拦截 + 原子写盘）与标准 Adobe PSD（`8BPS` v1 RGB8）互操作导出；`S2` `ActionBus` 非破坏性预览 + 原子批量执行 + 单步整组撤销/重做；`S3` 轻小说插图槽双策略校验（`MangaPick` 复用漫画页 / `NovelCustom` 专属插图 / `Hybrid` 混排防越权）；**`T0.7-S4` 集成门禁** + 61 Rust 单测 + **27/27 M5 Pro 真机 FFI 单测** | 把 `.mnga` 尾部 64 位 FNV-1a 校验与 `SuiteApp::Manga` 路径写权校验绑定在同一原子保存路径，兼顾开源可读性与防损坏/防跨端覆盖 |
| **`v0.8-S4` – `v0.9-S4`** *(待补充)* | _TBD_ | Apple 三端触控/折叠手势与 5 语言即时切换、Wave 1 联合 Beta 压测与 TestFlight 准备 | _随各里程碑定期补充_ |
| **`v1.0-S4` 终稿存档** | _TBD_ | Gemma 4 本地双引擎桥接、Wave 1 正式发布、最终品牌定稿与全项目总复盘 | _项目完成后形成最终归档版_ |
