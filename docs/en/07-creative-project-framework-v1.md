# 07. Creative Project File Framework V1.0 (CPFF v1.0)

**Language / 语言**: **English** | [简体中文](../zh-CN/07-creative-project-framework-v1.md)

> **Specification ID**: `CPFF-1.0` (Creative Project File Framework v1.0)  
> **XML Namespace**: `urn:about-paint-tools:cpff:1.0`  
> **Scope**: The official project file architecture and workspace management foundation of About-Paint-Tools, natively supporting **B&W Page Manga, Full-Color Webtoons, Anime Artbooks, Doujinshi, and Multilingual Serialization**, with first-class **GitHub / GitLab (Git + Git LFS)** compatibility.

---

## 1. Motivation & Core Design Principles

Traditional drawing apps scatter standalone canvas files (`page1.clip`, `page2.psd`) inside an unstructured folder. For serialized comics, doujinshi print runs, multilingual releases, and studio collaboration, this creates five chronic bottlenecks:
1. **No Unified Project Entry Point**: Outlines, scene scripts, character sheets, and continuity logs live disconnected in separate apps.
2. **Edition Chaos**: Publishing the same story as a B4 600DPI B&W Japanese print book, a color `800×1280` Webtoon, and an international EN/ES digital edition forces error-prone manual folder duplication.
3. **Missing Legal & Production Declarations**: Copyright terms, fanwork/derivative guidelines, reading direction (RTL/LTR), print specs, and AI assistance disclosures lack a machine-readable home.
4. **Locked-In Dialogue**: Speech bubble text embedded inside opaque binary canvases blocks translators from reviewing or submitting text PRs.
5. **Poor Git Ergonomics**: Pushing raw raster binaries bloats `.git` history while text metadata remains unmergeable.

**CPFF v1.0** synthesizes best practices from **Software Engineering (`.csproj` XML + Git/LFS)**, **Novel Authoring (Scrivener `.scrivx` binder)**, **Screenwriting (Final Draft `.fdx` scenes & continuity)**, and **Manga Production (multi-page/multi-edition publishing)** into five core principles:
- **Principle 1 — Folder-as-Project with Same-Named `.prj` XML Manifest**: Every project folder contains `<ProjectName>.prj` as its single source of truth.
- **Principle 2 — Clean Text/Binary Separation**: Plain UTF-8 text (XML/Markdown/JSON) lives in native Git for clean diffs and PRs; heavy binaries (`.mnga`, `.psd`, `.tiff`, `.glb`) route automatically to **Git LFS** via `.gitattributes`; compiled builds in `dist/` are `.gitignore`d.
- **Principle 3 — Single-Source Multi-Edition**: One story & manuscript tree compiles to multiple print, Webtoon, and localized editions.
- **Principle 4 — Dual-Source Multilingual Content Dictionary + Human Lock**: Work dialogue uses `en` + `zh-Hans` as dual baselines; automated completions never overwrite human-tuned entries marked `locked="true"`.
- **Principle 5 — Isolated AI Proposal Queue (Artist-in-the-Loop)**: Auto-completions from local Gemma 4 land inside `ai_assist/` as reviewable drafts (`status="ai_draft"`) before explicit human sign-off.

---

## 2. Standard Directory Layout

Every valid CPFF v1.0 project folder is directly a **GitHub / GitLab-ready Git repository**:

```text
<ProjectName>/                          # Project root (= Git repository root)
├── <ProjectName>.prj                   # [REQUIRED] Same-named XML project manifest
├── README.md                           # [RECOMMENDED] English synopsis & repo landing page
├── README.zh-CN.md                     # [RECOMMENDED] Simplified Chinese synopsis
├── LICENSE                             # [REQUIRED] Work license (All Rights Reserved / CC BY-NC-SA 4.0)
├── .gitignore                          # [RECOMMENDED] Ignores .cache/, dist/, ai_assist/tmp/
├── .gitattributes                      # [RECOMMENDED] Git LFS rules (*.mnga, *.psd, *.tiff, *.glb)
│
├── declarations/                       # Legal, format, and editorial declarations
│   ├── FORMAT_AND_EDITION.md           # Page formats, reading direction (RTL/LTR), edition matrix
│   ├── FANWORK_LICENSE.md              # Fanwork/secondary creation policy (or doujinshi disclaimer)
│   └── AI_DISCLOSURE.md                # Transparent AI assistance scope disclosure
│
├── bible/                              # Story Bible & Continuity
│   ├── world.md                        # Worldbuilding, timeline, factions, and rules
│   ├── characters/                     # Character sheets (XML metadata + LFS turnarounds)
│   │   └── char_*.xml
│   └── continuity/                     # Cross-chapter continuity & script supervisor log
│       └── continuity_log.xml
│
├── outline/                            # Plot Outline & Table of Contents
│   ├── synopsis.md                     # Logline & full story pitch
│   ├── toc.xml                         # Volume / chapter TOC tree & production status
│   └── arcs/                           # Arc-level outlines (arc_01.md, ...)
│
├── i18n/                               # [WORK CONTENT] Multilingual Dictionary & Dialogue
│   ├── dictionary.xml                  # Proper nouns, attacks, locations & SFX glossary
│   └── locales/                        # Per-language dialogue / narration / title catalogs
│       ├── en.xml                      # Canonical English baseline
│       ├── zh-Hans.xml                 # Canonical Simplified Chinese baseline
│       ├── zh-Hant.xml                 # Traditional Chinese (auto + locked tuning)
│       ├── yue-Hant.xml                # Traditional Cantonese (zh-HK fallback + locked tuning)
│       └── es.xml                      # Spanish (auto + bubble-length locked tuning)
│
├── editions/                           # Multi-Edition Publishing Profiles
│   ├── edition_jp_b4_print.xml         # B&W B4 600DPI Print Edition (RTL, 5mm bleed)
│   ├── edition_webtoon_color.xml       # Full-Color Webtoon Edition (800x1280 slices)
│   └── edition_intl_digital.xml        # International Digital Edition (EN / ES)
│
├── chapters/                           # Per-Chapter Isolation (Minimizes Git Merge Conflicts)
│   └── ch001/
│       ├── chapter.xml                 # Chapter structure, scenes, rough/final pages & status
│       ├── scenes/                     # Scene & beat sheets (time, location, cast, lighting)
│       │   └── sc001_*.md
│       ├── script/                     # Panel-by-panel script referencing i18n dialogue keys
│       │   └── script.xml
│       ├── storyboard/                 # Rough manga layouts / Name (Git LFS)
│       │   └── p001_rough.mnga
│       ├── manuscript/                 # Final manga manuscripts (Git LFS)
│       │   └── p001_final.mnga
│       └── ai_assist/                  # Reviewable auto-completion & critic staging area
│           ├── completion_queue.xml    # Gemma 4 plot/dialogue/panel proposals
│           └── review_pins.xml         # Non-destructive visual continuity review pins
│
├── assets/                             # Shared Project Art Assets (Git LFS)
│   ├── brushes/                        # Project-specific brush sets
│   ├── screentones/                    # Custom halftone patterns & textures
│   └── models3d/                       # Lightweight 3D pose mannequins & interiors (.glb)
│
└── dist/                               # [.gitignore] Local compiled builds (ship via Releases)
```

---

## 3. `.prj` File Resolution & Git Clone Rename Tolerance

1. **Canonical Rule**: Directory `<ProjectName>/` MUST contain `<ProjectName>/<ProjectName>.prj`.
2. **Git Clone / Local Rename Fallback**: When a user clones a repo into a custom directory name (`git clone <url> local-work`), the loader resolves in deterministic order:
   - **Exact Match First**: Check `<dir>/<dir_name>.prj` (`ExactMatch`).
   - **Unique Root Fallback**: If absent, scan root `*.prj` files; if **exactly one** `.prj` exists, load it cleanly and surface a non-blocking `RenamedFolderFallback` notice offering optional rename sync.
   - **Fail Fast on Ambiguity**: If zero or multiple root `.prj` files exist, abort with an explicit diagnostic error.

---

## 4. Core XML Schema Conventions (Git-Diff Friendly)

All XML documents enforce **UTF-8 encoding, 2-space indentation, LF line endings, POSIX `/` relative paths, and deterministic element ordering**.

### 4.1 Master Manifest `<ProjectName>.prj`

See the live validated example in [`templates/SampleManga/SampleManga.prj`](../../templates/SampleManga/SampleManga.prj). Six top-level sections define the complete project graph:
1. `<Metadata>`: Multilingual titles, authors/circles, genre, work type (`original` | `doujinshi` | `anthology`), default reading direction (`rtl` | `ltr` | `vertical-scroll`), and primary track (`bw-manga` | `color-webtoon` | `dual`).
2. `<Declarations>`: Links bilingual READMEs, `LICENSE`, `FORMAT_AND_EDITION.md`, `FANWORK_LICENSE.md` (with machine-readable `allowDerivative`, `commercialAllowed`, `aiTrainingOptOut`), and `AI_DISCLOSURE.md`.
3. `<Localization>`: Declares dual canonical sources (`en`, `zh-Hans`), derived locales (`zh-Hant`, `yue-Hant` with `fallback="zh-HK"`, `es`), and `i18n/dictionary.xml`.
4. `<Editions>`: Declares buildable publishing targets pointing to `editions/*.xml`.
5. `<StoryStructure>`: Indexes `outline/synopsis.md`, `outline/toc.xml`, `bible/world.md`, `bible/continuity/continuity_log.xml`, and ordered `<Chapters>`.
6. `<Repository>`: Declares `vcs="git"`, `lfsEnabled="true"`, and text vs. LFS binary path globs.

### 4.2 Chapters (`chapter.xml`) & Multilingual Panel Scripts (`script.xml`)

- **`chapter.xml`** binds scene breakdowns, panel scripts, rough storyboard canvases, final manuscripts, AI proposal queues, and per-page production states (`outline` → `scripted` → `storyboard` → `inked` → `flatted` → `toned` → `lettered` → `final`).
- **`script/script.xml`** structures `<Scene>` → `<Panel>` shot notes and speech bubbles referencing **`dialogueKey` IDs** (e.g., `ch001.p01.b01`) resolved dynamically from `i18n/locales/<lang>.xml` — enabling instant 5-language bubble switching over one shared artwork tree.

### 4.3 Multilingual Content Dictionary & Human-Edit Lock

```xml
<!-- i18n/locales/es.xml example -->
<DialogueLocale xmlns="urn:about-paint-tools:cpff:1.0" locale="es" preferredSource="en">
  <Line key="ch001.p01.b01" speaker="char_hero" status="tuned" locked="true" maxChars="42">
    ¡La tormenta se acerca a la azotea!
  </Line>
  <Line key="ch001.p01.b02" speaker="char_hero" status="auto" locked="false">
    No podemos retroceder ahora.
  </Line>
</DialogueLocale>
```

- `status="ai_draft"`: Unapproved Gemma 4 proposals staged exclusively in `ai_assist/`.
- `status="auto" locked="false"`: Accepted automated translations eligible for sync updates.
- `status="tuned" locked="true"`: Human-edited or bubble-width-tuned lines **permanently protected from automated overwrites**.

### 4.4 Dual-Engine Novel × Manga Parallel Studio & AI Intermediate Isolation (`v1.0` Core Capability)

Within a single CPFF project, the **Novel Engine** and **Manga Engine** share one backbone (`<ProjectName>.prj`, `outline/`, `bible/`, `i18n/dictionary.xml`, and `chapters/chXXX/scenes/`) while maintaining complete creative sovereignty over their human finals:

- **Independent Human Novel Tree (`chapters/chXXX/novel/`)**:
  - `novel/prose/{en,zh-Hans,zh-Hant,yue-Hant,es}.md`: Authoritative human-approved novel prose (`status="human_authoritative"`), which **need not match either the manga final or the AI reference prose**.
  - `novel/illustrations/`: Dedicated light-novel illustration folder — when configuring a light-novel edition (`editions/edition_novel_epub.xml`), illustrations may either be **self-selected from curated manga pages (`source="manga-pick"`)** or **custom-designed separately (`source="novel-custom"`)**.
- **Intentional Divergence Declaration (`<DivergenceNote>`)**: `chapter.xml` marks `<Novel decoupledFromManga="true">` with optional `<DivergenceNote>` explaining deliberate cross-media adaptations so Continuity Critics flag only accidental lore/prop errors.
- **Bidirectional AI Intermediate Red Line (Hard Constraint)**:
  - **Manga → Novel AI Drafts** live strictly inside `chapters/chXXX/ai_assist/manga_to_novel/` (`meta.xml` + reference prose marked `role="ai_reference_only"`);
  - **Novel → Manga AI Drafts** live strictly inside `chapters/chXXX/ai_assist/novel_to_manga/` (`meta.xml` + AI storyboard/rough intermediates marked `role="ai_reference_only"`);
  - **Hard Red Line**: AI bridges read human finals strictly read-only and **MUST NEVER write into `novel/prose/` or `manuscript/`**; text intermediates stay in Git as creative process history while heavy visual roughs route through Git LFS and may be pruned anytime.

### 4.5 Modular Tri-App Write-Ownership Partition, Concurrency & Deep-Link Protocol

To minimize RAM/VRAM footprint on touch & mobile hardware, the suite ships as **three standalone-or-concurrent tools sharing the same CPFF v1.0 folder** (all Chinese, English, and Spanish app names below are **working codenames** pending final pre-release branding sign-off):

| Subproject | Working Codename (`zh-Hans` / `zh-Hant` / `EN & ES`) | URL Scheme | Standalone RAM Budget | Exclusive Write-Owned Paths |
| :--- | :--- | :--- | :--- | :--- |
| **`S1` Project Hub** | **创想空间** / 創想空間 / `NoemaDock` | `noemadock://` | `< 200 MB` (no GPU canvas) | `<ProjectName>.prj`, `README*.md`, `LICENSE`, `declarations/`, `outline/`, `bible/`, `i18n/`, `editions/`, `dist/`, `chapters/*/chapter.xml`, `chapters/*/scenes/` |
| **`S2` Manga Studio** | **雕龙** / 雕龍 / `DracoNib` | `draconib://` | Dedicated GPU VRAM & tile pool | `chapters/*/storyboard/`, `chapters/*/manuscript/`, `chapters/*/script/`, `chapters/*/ai_assist/novel_to_manga/` |
| **`S3` Novel Atelier** | **文心** / 文心 / `LitteraCore` | `litteracore://` | `< 120 MB` (no GPU canvas) | `chapters/*/novel/prose/`, `chapters/*/novel/illustrations/`, `chapters/*/ai_assist/manga_to_novel/` |

- **Concurrent Safety**: Every tool uses atomic write-and-rename plus kernel-enforced directory write checks (see [`core/manga-core/src/suite.rs`](../../core/manga-core/src/suite.rs)); cross-boundary writes are rejected deterministically while all three tools watch shared folders read-only for live UI refresh.
- **Cross-App Deep Links**: Enables seamless handoffs such as launching the Manga tool from the Hub directly to Chapter 1 Page 1 (`draconib://open?project=prj-sample-manga-001&chapter=ch001&detail=page=1`) or opening Novel prose (`litteracore://open?project=prj-sample-manga-001&chapter=ch001&detail=locale=zh-Hans`).

---

## 5. GitHub / GitLab Compatibility (Git + Git LFS)

### 5.1 Standard `.gitattributes` Template

```gitattributes
# Normalize plain-text project manifests & scripts to LF for clean cross-OS diffs
*.prj text eol=lf
*.xml text eol=lf
*.md text eol=lf
*.json text eol=lf

# Track heavy artwork binaries via Git LFS (GitHub & GitLab native support)
*.mnga filter=lfs diff=lfs merge=lfs -text
*.psd filter=lfs diff=lfs merge=lfs -text
*.psb filter=lfs diff=lfs merge=lfs -text
*.tiff filter=lfs diff=lfs merge=lfs -text
*.tif filter=lfs diff=lfs merge=lfs -text
*.png filter=lfs diff=lfs merge=lfs -text
*.glb filter=lfs diff=lfs merge=lfs -text
```

### 5.2 Collaborative Branching & Release Workflow
- `main`: Locked outlines and finalized chapters.
- `feat/ch002-script` / `feat/ch002-art`: Parallel chapter production with minimal merge conflicts.
- `l10n/es-ch001` / `l10n/yue-ch001`: Translators can clone text-only in seconds (`GIT_LFS_SKIP_SMUDGE=1 git clone ...`) and open GitHub PRs / GitLab MRs reviewing dialogue line-by-line!
- `Tag + GitHub/GitLab Releases`: Tag releases per edition (`ch001-jp-print-v1.0`, `ch001-webtoon-es-v1.0`) and attach compiled `dist/` exports without bloating Git history.

---

## 6. Automated Tooling & Core Engine Support

1. **Zero-Dependency Validator**: `python3 scripts/prj_validate.py <path/to/ProjectFolder>` (enforced in `.github/workflows/ci.yml` against [`templates/SampleManga`](../../templates/SampleManga/)).
2. **Rust Core Module**: [`core/manga-core/src/project.rs`](../../core/manga-core/src/project.rs) implements `CreativeProjectManifest`, deterministic XML generation/parsing, and the exact-name + unique-fallback resolver.
3. **S4 Tri-App Integration Gate**: [`core/manga-core/src/suite.rs`](../../core/manga-core/src/suite.rs) and `cargo run --manifest-path core/Cargo.toml -p manga-linux-shell -- --integration-check` automatically enforce write-ownership isolation, AI red-line isolation, and cross-app deep-link round-trips on every PR.
