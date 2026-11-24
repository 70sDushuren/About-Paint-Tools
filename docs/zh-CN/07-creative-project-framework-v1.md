# 07. 创作工程文件框架 V1.0（CPFF v1.0）

**语言 / Language**: [English](../en/07-creative-project-framework-v1.md) | **简体中文**

> **规范编号**：`CPFF-1.0`（Creative Project File Framework v1.0）  
> **XML 命名空间**：`urn:about-paint-tools:cpff:1.0`  
> **适用范围**：作为 About-Paint-Tools 的官方项目文件体系与项目管理基础，原生支持**黑白页漫、全彩条漫、二次元插画集、同人本与多语种连载**，并与 **GitHub / GitLab（Git + Git LFS）** 生态完全兼容。

---

## 1. 设计背景与核心理念

传统绘画软件通常在单个文件夹内零散堆放单页画布文件（如 `page1.clip`、`page2.psd`），在长篇连载、同人本出版、多语种出海与多人协作时存在五大痛点：
1. **缺乏统一「项目」入口**：画稿与大纲、分场剧本、角色色卡、场记表割裂在不同软件中。
2. **多发行版本混乱**：同一部作品同时制作「日漫 B4 600DPI 黑白印刷版」「全彩 800×1280 条漫版」「西语/粤语海外电子版」时，只能手动复制文件夹导致版本失控。
3. **声明与授权缺失**：作品版权、同人/二次创作授权范围、翻页版式、字体与 AI 辅助声明缺少机器可读的统一规范。
4. **多语种台词难以协作**：气泡文字深埋在二进制画稿里，译者无法通过标准文本工具审校与协作。
5. **无法享受 Git 工程化红利**：大型二进制画稿直接入库会瞬间撑爆 `.git` 历史，而纯文本剧本与元数据又没有解耦出来。

**CPFF v1.0** 融合了**软件工程（`.csproj` XML + Git/LFS）**、**小说工程（Scrivener `.scrivx` 活页夹）**、**影视编剧（Final Draft `.fdx` 分场与场记）**与**漫画连载（多页/多版发行）**的精华，确立以下五项核心原则：
- **原则 1：文件夹即项目，根目录同名 `.prj` XML 为唯一总控入口**。
- **原则 2：文本与二进制物理分离**（Git 管文本 Diff/PR，Git LFS 管重型画稿，`.gitignore` 隔绝构建产物）。
- **原则 3：单源多发行（Single-Source Multi-Edition）**（一套剧情与原稿目录映射多个印刷/条漫/多语发行版）。
- **原则 4：双基准多语种字典 + 人工锁定**（作品台词以 `en` + `zh-Hans` 为双基准，自动补全永不覆盖 `locked="true"` 的人工精修）。
- **原则 5：AI 提案隔离区（Artist-in-the-Loop）**（自动补全成果先入 `ai_assist/` 提案队列，人工审阅修改后方可签收入正式正文）。

---

## 2. 标准目录体系规范

一个合法的 CPFF v1.0 创作工程目录同时也是一个**标准 Git 仓库根目录**：

```text
<ProjectName>/                          # 项目根目录（即 Git 仓库根目录）
├── <ProjectName>.prj                   # 【必填】与目录同名的 XML 项目主控文件
├── README.md                           # 【推荐】英文作品简介（GitHub/GitLab 默认主页）
├── README.zh-CN.md                     # 【推荐】简体中文作品简介
├── LICENSE                             # 【必填】作品版权许可（如 All Rights Reserved / CC BY-NC-SA 4.0）
├── .gitignore                          # 【推荐】忽略 .cache/、dist/、ai_assist/tmp/ 等
├── .gitattributes                      # 【推荐】Git LFS 二进制托管规则（*.mnga / *.psd / *.tiff / *.glb）
│
├── declarations/                       # 声明与规范文件目录
│   ├── FORMAT_AND_EDITION.md           # 版式、翻页方向（RTL/LTR）、印刷规格与各发行版说明
│   ├── FANWORK_LICENSE.md              # 同人授权/二次创作指引（或同人作品原作声明与免责）
│   └── AI_DISCLOSURE.md                # AI 辅助边界声明（场记/策划/铺色等非代画说明）
│
├── bible/                              # 世界观与设定圣经（Story Bible）
│   ├── world.md                        # 世界观、年表、势力与规则
│   ├── characters/                     # 角色设定卡（XML 文本 + LFS 三视图/色卡图）
│   │   └── char_*.xml
│   └── continuity/                     # 全工程场记与连载一致性总表
│       └── continuity_log.xml
│
├── outline/                            # 内容大纲与全书目录
│   ├── synopsis.md                     # 故事梗概与核心卖点（Logline）
│   ├── toc.xml                         # 卷 / 话 / 章目录树与状态
│   └── arcs/                           # 分卷大纲（arc_01.md 等）
│
├── i18n/                               # 【作品内容】多语种字典对照体系
│   ├── dictionary.xml                  # 专有名词统一对照表（角色名/地名/招式/拟声词 SFX）
│   └── locales/                        # 各语种台词/旁白/章节标题包
│       ├── en.xml                      # 英文基准
│       ├── zh-Hans.xml                 # 简体中文基准
│       ├── zh-Hant.xml                 # 繁体中文（自动补全 + locked 精修）
│       ├── yue-Hant.xml                # 繁体粤语（含 zh-HK 回退 + locked 精修）
│       └── es.xml                      # 西班牙语（自动补全 + 气泡字数微调锁定）
│
├── editions/                           # 不同发行版本配置文件
│   ├── edition_jp_b4_print.xml         # 黑白页漫 B4 600DPI 印刷版（RTL 右翻）
│   ├── edition_webtoon_color.xml       # 全彩条漫竖屏版（800x1280 切片）
│   └── edition_intl_digital.xml        # 海外电子版（EN / ES）
│
├── chapters/                           # 详细章节目录（按话隔离，最小化 Git 冲突）
│   └── ch001/
│       ├── chapter.xml                 # 章节结构、分场清单、大样/原稿页索引、完成度
│       ├── scenes/                     # 分场景 / 情节说明（时间、地点、角色、光源、节拍）
│       │   └── sc001_*.md
│       ├── script/                     # 详细分格剧本与多语言气泡 Key 绑定
│       │   └── script.xml
│       ├── storyboard/                 # 漫画稿大样（Name / 粗分镜草图，Git LFS）
│       │   └── p001_rough.mnga
│       ├── manuscript/                 # 正式漫画原稿（线稿/矢量/铺色/网点，Git LFS）
│       │   └── p001_final.mnga
│       └── ai_assist/                  # 自动补全提案区（可人工修改后签收）
│           ├── completion_queue.xml    # Gemma 4 剧情/台词/分镜补全提案
│           └── review_pins.xml         # 视觉场记穿帮巡检批注（非破坏性）
│
├── assets/                             # 工程共享美术资源（Git LFS）
│   ├── brushes/                        # 作品专属笔刷包
│   ├── screentones/                    # 专属网点与纹理
│   └── models3d/                       # 轻量 3D 人偶与背景模型（.glb）
│
└── dist/                               # 【不入 Git】本地构建的发行成品，经 Releases 发布
```

---

## 3. `.prj` 文件定位与 Git Clone 改名容错规则

1. **标准规范**：目录 `<ProjectName>/` 的根级必须存在同名文件 `<ProjectName>/<ProjectName>.prj`。
2. **Git Clone / 改名容错**：当用户通过 `git clone <url> my-local-dir` 导致目录名与 `.prj` 主文件名不一致时，软件加载顺序为：
   - **优先匹配**：检查 `<dir>/<dir_name>.prj` 是否存在（返回 `ExactMatch`）。
   - **唯一回退**：若不存在，扫描根目录全部 `*.prj`；若**恰好存在 1 个** `.prj` 文件，正常加载并返回 `RenamedFolderFallback` 状态提示用户「当前目录名与 `.prj` 文件名不一致，可保持兼容或一键同步重命名」。
   - **冲突报错**：若根目录不存在任何 `.prj` 或存在多个 `.prj`，则拒绝隐式猜测并明确报错。

---

## 4. 核心 XML Schema 规范（Git Diff 友好）

所有 XML 文件均须遵守：**UTF-8 编码、2 空格缩进、统一 LF 换行、POSIX `/` 相对路径、固定节点顺序**。

### 4.1 主控文件 `<ProjectName>.prj`

完整可验证示例见 [`templates/SampleManga/SampleManga.prj`](../../templates/SampleManga/SampleManga.prj)。核心一级节点固定为 6 段：
1. `<Metadata>`：作品多语种标题、作者/社团、题材、作品性质（`original` 原创 / `doujinshi` 同人 / `anthology` 合志）、默认阅读方向（`rtl` / `ltr` / `vertical-scroll`）、主线类型（`bw-manga` / `color-webtoon` / `dual`）。
2. `<Declarations>`：绑定中英 README、`LICENSE`（SPDX 标识或自定义声明）、`FORMAT_AND_EDITION.md`、`FANWORK_LICENSE.md`（含机器可读属性 `allowDerivative`、`commercialAllowed`、`aiTrainingOptOut`）与 `AI_DISCLOSURE.md`。
3. `<Localization>`：声明双基准源语言（`en`、`zh-Hans`）、衍生目标语言及偏好源（`zh-Hant`、`yue-Hant` 含 `fallback="zh-HK"`、`es`）和专有名词对照字典 `i18n/dictionary.xml`。
4. `<Editions>`：列出所有发行版本配置（如黑白 B4 印刷版、全彩条漫版、海外西语电子版），指向 `editions/*.xml`。
5. `<StoryStructure>`：绑定大纲 `outline/synopsis.md`、总目录 `outline/toc.xml`、世界观 `bible/world.md`、总场记 `bible/continuity/continuity_log.xml` 以及按序排列的 `<Chapters>`。
6. `<Repository>`：声明 `vcs="git"`、`lfsEnabled="true"` 与文本/二进制分层路径规则。

### 4.2 章节结构 `chapters/chXXX/chapter.xml` 与多语言剧本 `script/script.xml`

- **`chapter.xml`**：索引本话的全部场景文件（`scenes/*.md`）、剧本文件（`script/script.xml`）、大样画稿（`storyboard/*.mnga`）、原稿画稿（`manuscript/*.mnga`）与 AI 提案文件（`ai_assist/*.xml`），并可标记每页的工序状态（`outline` → `scripted` → `storyboard` → `inked` → `flatted` → `toned` → `lettered` → `final`）。
- **`script/script.xml`**：按「场景（`<Scene>`）→ 分格（`<Panel>`）」组织镜头景别、画面动作说明与气泡条目；每个气泡**不硬编码单一语言文本，而是绑定 `dialogueKey`（如 `ch001.p01.b01`）**，实际显示文案由 `i18n/locales/<lang>.xml` 动态解析，实现「一套原稿 + 一键切换 5 语言气泡」。

### 4.3 多语种作品字典与自动补全锁定机制

```xml
<!-- i18n/locales/es.xml 示例 -->
<DialogueLocale xmlns="urn:about-paint-tools:cpff:1.0" locale="es" preferredSource="en">
  <Line key="ch001.p01.b01" speaker="char_hero" status="tuned" locked="true" maxChars="42">
    ¡La tormenta se acerca a la azotea!
  </Line>
  <Line key="ch001.p01.b02" speaker="char_hero" status="auto" locked="false">
    No podemos retroceder ahora.
  </Line>
</DialogueLocale>
```

- `status="ai_draft"`：仅存在于 `ai_assist/` 中的未签收自动补全草案。
- `status="auto" locked="false"`：已入库但允许自动翻译脚本随源文更新的条目。
- `status="tuned" locked="true"`：经人工精修或针对气泡字数微调的条目，**任何自动补全或翻译同步工具严禁覆盖**。

### 4.4 小说创作 × 漫画创作「双引擎并进」与双向 AI 中间产物隔离规范（`v1.0` 基础能力）

同一工程下，**小说引擎（Novel Engine）**与**漫画引擎（Manga Engine）**共享唯一主干（`<ProjectName>.prj`、`outline/`、`bible/`、`i18n/dictionary.xml` 与 `chapters/chXXX/scenes/`），但各自拥有完全独立的人工终稿主权：

- **独立人工小说目录（`chapters/chXXX/novel/`）**：
  - `novel/prose/{zh-Hans,en,zh-Hant,yue-Hant,es}.md`：作者确认的小说终稿正文（`status="human_authoritative"`），**无需与漫画稿或 AI 小说参考稿一致**。
  - `novel/illustrations/`：轻小说专属插画目录——在配置轻小说发行版（`editions/edition_novel_epub.xml`）时，插图既可**自选精选漫画原稿页（`source="manga-pick"`）**，也可**单独设计绘制专属轻小说插图（`source="novel-custom"`）**。
- **双线有意分歧声明（`<DivergenceNote>`）**：在 `chapter.xml` 的 `<Novel decoupledFromManga="true">` 节点中记录小说版与漫画版的刻意改编差异，场记 AI 巡检会尊重作者声明的媒介分歧，仅提示无意的设定穿帮。
- **双向 AI 中间产物隔离红线（硬性约束）**：
  - **漫画 → 小说 AI 中间稿** 严格存放于 `chapters/chXXX/ai_assist/manga_to_novel/`（含 `meta.xml` 与参考散文草稿，强制标记 `role="ai_reference_only"`）；
  - **小说 → 漫画 AI 中间稿** 严格存放于 `chapters/chXXX/ai_assist/novel_to_manga/`（含 `meta.xml` 与 AI 分镜/大样中间稿，强制标记 `role="ai_reference_only"`）；
  - **红线**：AI 桥接管线对漫画原稿与小说正文均为单向只读，**严禁任何自动化流程越界写入 `novel/prose/` 或 `manuscript/` 人工终稿目录**；纯文本 AI 中间稿可随 Git 留存创作脉络，重型参考图走 Git LFS 且可随时归档清理。

### 4.5 三独立工具套件的文件写权分治、并发保护与 Deep-Link 协同规范

为降低系统内存与显存占用，本项目拆分为 **三个基于同一 CPFF v1.0 目录、既可单独运行也可并发同屏运行的独立工具**（以下中文/英文/西语名称当前均作为**暂定开发代号**，正式发版前定稿）：

| 子项目 | 暂定代号（简中 / 繁粤 / EN & ES） | URL Scheme | 单独运行内存目标 | 写权归属目录（严禁跨界写入） |
| :--- | :--- | :--- | :--- | :--- |
| **`S1` 项目总控** | **创想空间** / 創想空間 / `NoemaDock` | `noemadock://` | `< 200 MB`（无 GPU 画布） | `<ProjectName>.prj`、`README*.md`、`LICENSE`、`declarations/`、`outline/`、`bible/`、`i18n/`、`editions/`、`dist/`、`chapters/*/chapter.xml`、`chapters/*/scenes/` |
| **`S2` 漫画绘制** | **雕龙** / 雕龍 / `DracoNib` | `draconib://` | 独占 GPU 显存与瓦片池 | `chapters/*/storyboard/`、`chapters/*/manuscript/`、`chapters/*/script/`、`chapters/*/ai_assist/novel_to_manga/` |
| **`S3` 小说出版** | **文心** / 文心 / `LitteraCore` | `litteracore://` | `< 120 MB`（无 GPU 画布） | `chapters/*/novel/prose/`、`chapters/*/novel/illustrations/`、`chapters/*/ai_assist/manga_to_novel/` |

- **并发读写安全**：三工具均采用「临时文件写盘 + 原子重命名」与代码级目录写权校验（见 [`core/manga-core/src/suite.rs`](../../core/manga-core/src/suite.rs)），任何工具尝试向非归属目录写入时均在内核层拦截报错；三工具均可只读订阅彼此保存的目录变更并即时刷新视图。
- **跨工具 Deep-Link 跳转**：例如从「创想空间」一键拉起「雕龙」直达第 1 话第 1 页（`draconib://open?project=prj-sample-manga-001&chapter=ch001&detail=page=1`），或拉起「文心」打开简体正文（`litteracore://open?project=prj-sample-manga-001&chapter=ch001&detail=locale=zh-Hans`）。

---

## 5. GitHub / GitLab 兼容规范（Git + Git LFS）

### 5.1 必须内置的 `.gitattributes` 模板

```gitattributes
# 文本文件统一 LF，保障跨 macOS/iPadOS/Windows/Linux 干净 Diff
*.prj text eol=lf
*.xml text eol=lf
*.md text eol=lf
*.json text eol=lf

# 重型美术二进制交由 Git LFS 托管（兼容 GitHub & GitLab）
*.mnga filter=lfs diff=lfs merge=lfs -text
*.psd filter=lfs diff=lfs merge=lfs -text
*.psb filter=lfs diff=lfs merge=lfs -text
*.tiff filter=lfs diff=lfs merge=lfs -text
*.tif filter=lfs diff=lfs merge=lfs -text
*.png filter=lfs diff=lfs merge=lfs -text
*.glb filter=lfs diff=lfs merge=lfs -text
```

### 5.2 协作分支与发布建议
- `main`：稳定主干（已完稿或已定稿的大纲/章节）。
- `feat/ch002-script` / `feat/ch002-art`：按话并行开发，避免合并冲突。
- `l10n/es-ch001` / `l10n/yue-ch001`：译者无需下载数 GB 原稿即可浅克隆纯文本（`GIT_LFS_SKIP_SMUDGE=1 git clone ...`）并提交 Pull Request / Merge Request 校对西语或粤语台词！
- `Tag + GitHub/GitLab Releases`：如 `ch001-jp-print-v1.0`、`ch001-webtoon-es-v1.0`，将 `dist/` 编译产物作为 Release 附件发布，不污染 Git 仓库历史。

---

## 6. 自动化校验与工程工具支持

仓库已配套提供三套零外部依赖验证能力：
1. **CLI / CI 校验器**：`python3 scripts/prj_validate.py <path/to/ProjectFolder>`（已接入 `.github/workflows/ci.yml` 自动校验 [`templates/SampleManga`](../../templates/SampleManga/)）。
2. **Rust 核心读写模块**：[`core/manga-core/src/project.rs`](../../core/manga-core/src/project.rs) 提供原生 `CreativeProjectManifest` 解析、规范 XML 输出与目录同名/改名容错定位能力。
3. **S4 三工具集成兼容门禁**：[`core/manga-core/src/suite.rs`](../../core/manga-core/src/suite.rs) 与 `cargo run --manifest-path core/Cargo.toml -p manga-linux-shell -- --integration-check` 在每次 PR 自动验证三工具写权隔离、AI 红线与跨工具 Deep-Link 互通。
