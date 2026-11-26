# 10. Engineering Philosophy, Strategy, Reusable Skills & Living Retrospective Playbook

**Language / 语言**: **English** | [简体中文](../zh-CN/10-engineering-retrospective-and-playbook.md) | [Bilingual Study Edition (中英对照学习版)](../bilingual/10-engineering-retrospective-and-playbook-bilingual.md)

> **Purpose**: This is the living engineering handbook and retrospective archive for **About-Paint-Tools**, capturing the project's **architectural philosophy, delivery strategy, real-world troubleshooting lessons, and reusable AI Agent Skills**.
> **Update Cadence**: Appended at every mandatory **`S4` Integration & Compatibility Gate** (`v0.2-S4`, `v0.3-S4`, …, `v1.0-S4`), culminating in the final project summary archive upon release.
> **Current Coverage**: `v0.1.0-architecture-baseline` → `v0.2.1` + Cloud ↔ Local Mac `GoNext` Relay & Circuit Breakers (Commit `97434c8`).

---

## 1. Product & Architectural Philosophy

### 1.1 Dual-Track × Dual-Engine Without Monolithic Bloat
- **Core Problem**: Mainstream creative apps either neglect B&W page-manga craft (600DPI B4, screentones, panel cutting) or bolt novel/webtoon workflows onto one heavyweight process that crashes on 8GB tablets.
- **Architectural Answer**: Unify B&W Page Manga, Full-Color Webtoon/Illustration, and Light Novel creation over a single open-source **CPFF v1.0 (`.prj`)** workspace while separating runtime responsibilities cleanly.

### 1.2 Tri-App Modular Suite (`S1`/`S2`/`S3`) + Mandatory `S4` Gate
- **Memory-Bounded Specialization**:
  - `S1` **`NoemaDock` / `创想空间`** (`< 200 MB` RAM, no GPU canvas): Project hub, import/ingest, dual-engine scheduling & multi-locale publishing.
  - `S2` **`DracoNib` / `雕龙`** (`1536 MB` tile budget, full GPU canvas): 240Hz drawing, vector lineart, screentones, cel shading & panels.
  - `S3` **`LitteraCore` / `文心`** (`< 120 MB` RAM, no GPU canvas): Eye-friendly light-novel editor, outline tree, illustration curation & EPUB3.
- **Write-Ownership Isolation**: Hard-coded path ownership rules in Rust [suite.rs](../../core/manga-core/src/suite.rs) (e.g., only `S3` may write `chapters/*/novel/novel_meta.xml` and `novel/prose/`) structurally eliminate concurrent write corruption when apps run side by side in iPad/Mac Split View.
- **Cargo Feature Slicing**: Independent compilation of `--features hub`, `canvas`, and `novel` ensures lightweight tools never carry GPU canvas overhead.
- **Working Codename Discipline**: All three names remain marked `is_final_brand = false` / `locked = false` until a single pre-release branding PR at `v1.0-S4`.

### 1.3 MIT License Purity & Hard AI Isolation Red Line
- **Zero GPL/AGPL Dependencies**: `core/manga-core` stays dependency-free, ensuring clean MIT licensing and sub-second incremental compiles across Linux VM, MacBook Pro, and Xcode Cloud.
- **AI Never Overwrites Human Canon**: All local **Gemma 4 (E2B/E4B, Apache 2.0)** outputs are sandboxed strictly inside `ai_assist/` (`role="ai_reference_only"`), enforced in both Rust and Python CI ([prj_validate.py](../../scripts/prj_validate.py)).

---

## 2. Engineering Strategy & Governance

### 2.1 Doc-First & Visual-First Convergence Funnel
Before writing heavyweight native UI, every major design passes four low-cost alignment gates:
1. **1:1 Bilingual Architecture Specs**: Lock file formats (CPFF), architecture, and task maps first (Docs `01`–`09`).
2. **Parallel Multi-Agent Market Research & Original Mockups**: 3 specialist agents surveyed 20+ mainstream & OSS tools and produced 7 clean-room MIT UI mockups.
3. **Interactive HTML Prototypes**: 3 self-contained HTML demos validated Icon-First (`24×24dp`) navigation + 4-element Hint Popovers before writing SwiftUI/Metal code.
4. **Bilingual Keynote Sign-Off**: Distilled open choices into 4 crisp executive decisions so engineering proceeds with zero ambiguity.

### 2.2 SemVer 3rd-Segment (`vX.Y.Z`) Incremental Parallel Delivery
- Each minor version (`v0.2`, `v0.3`, …) progresses via focused patch waves (`v0.2.1` core engines → `v0.2.2` native shells & GPU pipeline → …) across independent `S1`/`S2`/`S3` tracks before converging into a mandatory **`T0.X-S4` integration PR**.
- **Core Before Shell**: `v0.2.1` delivered deterministic Rust + C-ABI + Swift bridges (`project_init.rs`, `brush.rs`, `novel.rs`) verified by 48 unit tests and real E2E validation before binding UI views.

### 2.3 Single-Source-of-Truth (Zero-Drift) Matrix
| Domain | Single Source of Truth | Automated Sync / Gate | Strict Prohibition |
| :--- | :--- | :--- | :--- |
| **5-Language i18n** | `i18n/locales/*.json` + `glossary.json` | `i18n_check.py` + `i18n_sync.py` | Never hand-edit `.xcstrings` keys in Xcode |
| **Apple Project Config** | `apps/apple/project.yml` | `xcodegen generate` (`.xcodeproj` gitignored) | Never commit hand-edited `.pbxproj` noise |
| **Bilingual Docs** | `docs/en/` ↔ `docs/zh-CN/` 1:1 mirror | `i18n_check.py` filename parity gate | Never add a single-language doc without its mirror |
| **CPFF v1.0 Contract** | `templates/SampleManga/` + Doc `07` | Rust `project.rs` + `prj_validate.py` | Never bypass AI sandbox or write-ownership tests |

---

## 3. Cloud ↔ Local Hardware Hybrid Workflow & `GoNext` Automation

### 3.1 Clear Cloud Linux VM × Local Apple Silicon MacBook Split
- **Cloud Linux VM**: Owns platform-agnostic Rust core, C11 ABI, Swift/Android/Windows source authoring, 5-locale i18n, bilingual docs, and full CI checks.
- **Local M5 Pro MacBook Pro**: Owns Xcode 27+, 3-slice `MangaCore.xcframework`, Metal GPU rendering, and Simulator/device testing.
- **Single-Project Multi-Target + Incremental Rust Sync**: All Wave 1 Apple targets live in one [project.yml](../../apps/apple/project.yml); SHA-256 fingerprinting of `core/` ([scripts/dev.sh](../../scripts/dev.sh)) skips Rust builds in `< 50ms` for pure Swift `⌘R` runs while auto-rebuilding whenever Rust changes.

### 3.2 Zero-Conflict `GoNext` GitOps Relay ([ops/relay/](../../ops/relay/README.md))
- **Append-Only Paired Audit Log**: Cloud appends only `ops/relay/orders/<TS>_<slug>.json`; Mac appends only `ops/relay/results/<TS>_<slug>.result.md` with the identical `order_id`. Merge conflicts are structurally impossible, and both folders serve as a permanent chronological log.
- **Declarative Allowlist Security (Safer than Self-Hosted Runners on Public Repos)**: Public repositories must avoid GitHub Self-Hosted Runners due to untrusted PR injection risk. `GoNext` tracks only `origin/main` and validates every step against a dual-enforced (CI + local) action allowlist — zero arbitrary shell execution.
- **Two-Sided Loop-Detection Circuit Breakers & Budgets**:
  1. **Wall-Clock Budget (`MAX_MIN`)**: Never kills an active build mid-flight; finishes & pushes the active order's receipt, then stops/unloads cleanly and notifies the user.
  2. **Order Cap (`MAX_ORDERS`)**: Runs `--single-order` per tick so budgets are checked after every completed order.
  3. **Loop & Failure Breaker (`MAX_FAILS` + `DUPLICATE_ERROR_LOOP`)**: Trips immediately (`exit 42`) on consecutive failures or 2 consecutive identical normalized error signatures, writing a local pause lock until human review (`make relay-resume`).
  4. **Two-Way Kill Switches**: Local `make relay-stop` / `make relay-resume` and repository-level `ops/relay/PAUSE`.

---

## 4. Real-World Pitfalls & Troubleshooting Log (Living Table)

> Every entry below was genuinely encountered, diagnosed via real tests or Mac `GoNext` receipts, and permanently eliminated.

| # | Phase | Symptom | Root Cause | Permanent Fix |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Mac Setup | `sudo xcodebuild -license accept` failed (`active developer directory is CommandLineTools`) | Active developer path pointed to CLT instead of full `Xcode.app` | Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| 2 | First Xcode Run | Clean build silently dirtied `Localizable.xcstrings` in `git status` | Xcode 15–27 auto-extracts SwiftUI strings into `.xcstrings` on build | Set `SWIFT_EMIT_LOC_STRINGS: NO` and `LOCALIZED_STRING_SWIFTUI_SUPPORT: NO` in `project.yml` |
| 3 | Xcode Pre-Build Hook | Run Script reading `../../core/` blocked by Xcode sandbox | Xcode 15+ defaults `ENABLE_USER_SCRIPT_SANDBOXING=YES` | Set `ENABLE_USER_SCRIPT_SANDBOXING: NO` in `project.yml` |
| 4 | GoNext Order #1 | `build-mac` passed, `build-ipad` failed (`does not contain a scheme named "MangaStudio-iPadOS"`, exit 65) | `project.yml` omitted explicit top-level `schemes:`, so XcodeGen emitted no shared `.xcscheme` | Declare explicit shared `schemes:` for all 3 targets in `project.yml` |
| 5 | GoNext Order #2 | `arm64` linked cleanly, but `build-ipad` failed with `Undefined symbols for architecture x86_64` | `generic/platform=iOS Simulator` attempted legacy Intel `x86_64`, while `XCFramework` is pure `arm64` | Set `ARCHS: arm64` and `"EXCLUDED_ARCHS[sdk=iphonesimulator*]": x86_64` (Order #3 passed 7/7 in 7s!) |
| 6 | Mac Auto-Relay | First 2 `make gonext` runs prompted for admin password, then stopped | One-time `DevToolsSecurity` & Keychain authorization on fresh Xcode install | Verify `DevToolsSecurity -status` & `gh auth status`; prefer `make relay-watch` in unlocked session |
| 7 | CPFF Bootstrap | Initial `project_init.rs` `<Edition>` XML missed attributes required by `parse_prj_xml` | Schema drift from canonical `SampleManga.prj` | Align XML with `SampleManga.prj` and gate with real `prj_validate.py` E2E test |
| 8 | Bilingual Keynote | English deck had stray Chinese titles on one slide and tight banner spacing | Programmatic `.pptx` build without visual inspection | Render every slide via `libreoffice` → `pdftoppm` and visually QA every PNG |
| 9 | Google Drive CLI | `gdrive mutate mkdir --json \| jq` threw JSON parse error | `mutate mkdir` prints plain text rather than JSON | Query newly created folder IDs via `gdrive readonly ls <parent> --json` |
| 10 | LaunchAgent Self-Unload | After 120m expiry `Local State` paused properly, yet `make relay-status` still showed `INSTALLED` | Calling `launchctl bootout` from inside the LaunchAgent kills the script with `SIGTERM` before `rm -f *.plist` runs | Delete `*.plist` & `*.budget` BEFORE calling `launchctl bootout`, and query live `launchctl print` in `status` (`6fd21fb`) |
| 11 | macOS Headless XCTests | Hosted `TEST_HOST` tests on hardened-runtime apps with `CODE_SIGNING_ALLOWED=NO` risk `dyld` validation failures | Host injection requires matching code signatures | Use a standalone `bundle.unit-test` linking `MangaCore.xcframework` directly (excluding `@main`): 9/9 live Apple Silicon FFI tests in `< 0.02s` |

---

## 5. Reusable Agent Skills Catalog

Key cross-project engineering patterns from this project have been distilled into **3 reusable Agent Skills**:

| Skill Name | Layer | Problem Solved | Reuse Scenarios |
| :--- | :--- | :--- | :--- |
| **`gitops-gonext-relay-setup`** | Infrastructure Scaffold | Scaffolds zero-conflict `orders/`↔`results/`, allowlist validator, local runner, `launchd` service, `Makefile`, and CI schema gate | Bootstrapping any hybrid Cloud-Agent + Local-Hardware (Mac/Win GPU/Android/Embedded) repo |
| **`gitops-gonext-dispatch`** | Daily Dispatch Loop | Standardizes cloud checks → `guard-check` audit → minimal allowlisted `GoNext` order → bounded `wait` → advance on PASS / diagnose on FAIL | Every `vX.Y.Z` cross-platform iteration and real-device regression |
| **`gitops-gonext-circuit-breaker`** | Autonomous Loop Safety | Enforces `MAX_MIN` time budgets, `MAX_ORDERS` caps, `MAX_FAILS` + `DUPLICATE_ERROR_LOOP` error fingerprinting, graceful completion, and two-way kill switches | Guarding any autonomous multi-round loop or `/goal` execution against runaway retries |

> **Planned Future Skills** (to be distilled in upcoming milestones):
> - `metal-240hz-brush-profiler` (`v0.3`: Metal frame capture & Pencil Pro latency/memory verification)
> - `cpff-tri-app-s4-gate` (`v0.4`–`v0.9`: automated Tri-App concurrency, 5-locale overflow & dual-engine parity audit)

---

## 6. Living Milestone Retrospective Log (Append-Only)

> **Maintenance Rule**: Append one row at every `S4` Integration & Compatibility Gate and update Sections 4 & 5 accordingly.

| Milestone | Date / Commit | Core Deliverables & Evolution | Key Lessons Captured |
| :--- | :--- | :--- | :--- |
| **`v0.1.0` Architecture Baseline** | `3c52338` (`v0.1.0-architecture-baseline`) | MIT license, CPFF v1.0, Dual-Track × Dual-Engine, 6 hardware targets, Tri-App modularization & `S4` gate, 46×5 i18n | Enforcing write-ownership & RAM budgets in Rust `suite.rs` upfront prevents architectural drift across all future UI work |
| **`v0.2.0`–`v0.2.1` Design Sign-Off, Apple 3-Slice & `GoNext` Relay** | `9227d14` → `66e7ceb` → `8f53934` → `97434c8` | 7 UI mockups, 3 HTML demos, 4 bilingual Keynote decisions; `v0.2.1` S1/S2/S3 core engines (48 tests); M5 Pro 7/7 PASS in 7s; guarded `GoNext` Relay + 3 Skills | Visual prototypes + Keynote alignment eliminate rework; guarded GitOps relay collapses cloud↔Mac debugging from manual log pasting to a 7-second closed loop |
| **`v0.2.2`–`v0.2.3` & `T0.2-S4` Sign-Off** | `0ffb9fb` → `7fa92ad` → `7410dea` (`v0.2.0`) | 18 clean-room MIT icons + 4-element Hint Popovers + native SwiftUI Tri-App shells; `RenamedFolderFallback`, tapered brush stamping, atomic save + lock guard, **100-round Tri-App concurrency soak (`run_t02_s4_concurrency_soak`)**; 9 live M5 Pro Swift ↔ Rust XCTests | Standalone `bundle.unit-test` eliminates signing friction for headless Rust FFI XCTests; self-unloading `launchd` agents must delete `.plist` before `bootout` |
| **`v0.3.1`–`v0.3.2` & `T0.3-S4` Sign-Off** | `719ef10` → `bbfcf96` (`v0.3.0`) | `S1` atomic Story Bible (`bible/characters.xml`) & Master TOC (`outline/toc.xml`) + Left Project Tree & live character editor; `S2` 13 cel-shading blend modes, right layer drawer (`R`/`✂`/`🔒`/`B` + visibility) & live multi-layer canvas compositing preview; `S3` 250ms `< 300ms`-SLA disk revision watcher (measured `0–1ms`); **`T0.3-S4` gate (`run_t03_s4_bible_layers_gate`)** wired into Linux CI & **15/15 live M5 Pro FFI XCTests** | Caller-owned UTF-8 C-ABI summary buffers paired with 64-bit FNV-1a content hashing avoid cross-language heap leaks and platform file-watcher quirks while keeping hot-reload at `~1ms` with zero cursor disruption |
| **`v0.4.0` & `T0.4-S4` Sign-Off** | `de14944` (`v0.4.0`) | `S1` CPFF asset & prose ingest normalizer (`ingest.rs`, auto-versioning `-v2` on collision and staging external prose strictly under `ai_assist/ingest_staging/`); `S2` freehand lasso polygon selection mask (`selection.rs`, ray-casting/invert/expand-contract) + live `3px` Close-Gap anti-halo fill UI; `S3` 5-locale prose switcher & `<DivergenceNote>` XML round-trip editor; **`T0.4-S4` gate** + 55 Rust tests + **18/18 live M5 Pro FFI XCTests** | Routing external prose imports into `ai_assist/ingest_staging/` with automatic `-v2` collision versioning extends the "zero overwrite of human canon" red line across every ingestion path |
| **`v0.5.0` & `T0.5-S4` Sign-Off** | `v0.5.0` | `S1` 5-locale terminology glossary (`bible/glossary.xml`) & completeness audit matrix (`glossary.rs`); `S2` 4x lossless vector lineart scaling, single-swipe Vector Intersection Eraser & Symmetry/Parallel/2-Pt Perspective/Focus-Line rulers via C-ABI; `S3` read-only 5-locale proper-noun autocomplete pill bar; **`T0.5-S4` gate** + 57 Rust tests + **21/21 live M5 Pro FFI XCTests** | Centralizing ruler snapping/mirroring in `manga_ruler_transform_point` guarantees identical floating-point stroke snapping across Apple, Android, Windows, and Linux shells |
| **`v0.6-S4` – `v0.9-S4`** *(Pending)* | _TBD_ | Diagonal panels/screentones/vertical bubbles/webtoon slicing, `.mnga`/PSD/`ActionBus`, Apple 3-device inputs & 5-locale UI, Wave 1 Beta & TestFlight | _Appended per milestone_ |
| **`v1.0-S4` Final Archive** | _TBD_ | Wave 1 store release, final branding & full project retrospective | _Final archived edition upon completion_ |
