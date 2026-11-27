---
name: cloud-local-dual-agent-collab
description: "Orchestrates zero-conflict peer-to-peer collaboration between a Cloud AI Agent (Linux VM: architecture, cross-platform core/Rust/C-ABI, docs, i18n, CI) and a Local IDE AI Agent (macOS Xcode / Android Studio / Visual Studio: native UI, GPU/Metal/Vulkan, physical device deployment, XCTests, hardware ergonomics) using GitHub as Single Source of Truth, dual one-way append-only dev logs, persistent gitignored signing overrides, FFI rebuild signaling, and hybrid GoNext GitOps relay fallback."
---

# Cloud ↔ Local Dual-Agent Collaboration Skill

Use this skill whenever a project is co-developed by **two peer AI coding agents** operating in different hardware/OS environments connected through Git:
- **Cloud Agent** (e.g., Antigravity on Linux VM): owns cross-platform core logic (Rust / C++ / Go / Python), C-ABI/FFI headers, unit tests, schema validators, i18n, bilingual documentation, and CI gates.
- **Local IDE Agent** (e.g., Antigravity inside Xcode on macOS with a connected iPad Pro / iPhone / MacBook, or Android Studio / Visual Studio): owns native platform UI (SwiftUI / UIKit / AppKit / Metal), native SDK compiler & strict-concurrency fixes, real-device signing & deployment, hardware input/gesture tuning, and on-device XCTests/profiling.

---

## 1. Choose the Right Collaboration Mode

| Mode | When to Use | Transport & Trigger |
| :--- | :--- | :--- |
| **Mode A: Interactive Dual-Agent Handoff (Primary for Active UI & Device Polish)** | Both Cloud Agent and Local IDE Agent actively write code in alternating turns (e.g., Cloud builds Rust FFI + Swift scaffolding; Local Agent verifies in Xcode, fixes SDK/gesture nuances, deploys to physical iPad Pro, and logs results). | Git `main` + **Dual One-Way Append-Only Dev Logs** (`ops/cloud-dev-log/CLOUD_DEV_LOG.md` & `ops/local-dev-log/LOCAL_DEV_LOG.md` or `IPAD_MAC_DEV_LOG.md`). User copies a structured handoff prompt between agents. |
| **Mode B: Autonomous `GoNext` GitOps Relay (Batch CI / Unattended Verification)** | Cloud needs to dispatch 1–20 unattended build/test verification passes to a local Mac without interactive Xcode editing. | Allowlisted JSON orders in `ops/relay/orders/` + paired receipts in `ops/relay/results/` (`make gonext` / `make relay-watch` / `make relay-install-agent`). See `gitops-gonext-relay-setup`, `gitops-gonext-dispatch`, and `gitops-gonext-circuit-breaker`. |

> **Golden Rule — Never Mix Triggers**:
> - When Local IDE Agent has made active code edits, push with **`make push MSG="..."`** (or `git add -A && git commit && git pull --rebase && git push`). **NEVER run `make gonext`** on a dirty working tree or to push local edits — `make gonext` is strictly for pulling and executing Cloud-dispatched `ops/relay/orders/`.

---

## 2. Zero-Conflict File Ownership & Directory Layout

Structure every dual-agent repository with strict **single-writer ownership** for handoff logs and build configs:

```text
<repo>/
├── ops/
│   ├── cloud-dev-log/
│   │   └── CLOUD_DEV_LOG.md        # Cloud Agent WRITES (reverse chronological); Local Agent READ-ONLY
│   ├── local-dev-log/
│   │   └── IPAD_MAC_DEV_LOG.md     # Local Agent WRITES (reverse chronological); Cloud Agent READ-ONLY
│   └── relay/                      # Mode B autonomous GoNext orders/ (Cloud) & results/ (Local)
├── apps/apple/                     # (Or native platform dir)
│   ├── project.yml                 # Tracked single source of truth (XcodeGen) — NEVER hardcode TEAM_ID here
│   ├── BaseSigning.xcconfig        # Tracked base signing with `#include? "LocalSigning.xcconfig"`
│   ├── LocalSigning.xcconfig.example
│   └── LocalSigning.xcconfig       # GITIGNORED local override (DEVELOPMENT_TEAM, custom BUNDLE_PREFIX)
└── skills/
    └── cloud-local-dual-agent-collab/SKILL.md
```

### Why Dual Logs Live Under `ops/` (Not `docs/`)
1. **Zero Merge Conflicts**: Cloud only appends to `ops/cloud-dev-log/CLOUD_DEV_LOG.md`; Local only appends to `ops/local-dev-log/<LOCAL_LOG>.md`. Neither agent ever edits the other agent's log file.
2. **Zero i18n CI Friction**: Repositories with strict 1:1 bilingual doc checks (e.g., `scripts/i18n_check.py` over `docs/zh-CN/` ↔ `docs/en/`) will NOT block fast local dev log pushes when logs live in `ops/`.

---

## 3. Mandatory Pre-Work, Build & Push Protocols

### 3.1 Cloud Agent Turn Protocol
1. **Always Pull First**: Before editing, run `git fetch origin && git status -sb`. If behind `origin/main`, run `git pull --rebase` and **read the newest entry in `ops/local-dev-log/*.md`** to capture every local fix, hardware test result, and requested core follow-up.
2. **Respect Native Platform Boundaries**:
   - Keep `Shared/Sources/` free of unguarded platform-only symbols (`UIKit`/`AppKit` must be wrapped in `#if canImport(...)` or `#if os(...)`).
   - Run full cloud CI (`make check` / C11 `-Wall -Wextra -Werror` / Rust tests / feature slices / i18n check) before committing.
3. **Explicit FFI Rebuild Signaling**:
   - Whenever Cloud changes native core sources (`core/`), C ABI headers (`.h`), or Cargo features, **explicitly flag `REBUILD_NATIVE_CORE_REQUIRED`** at the top of the new entry in `ops/cloud-dev-log/CLOUD_DEV_LOG.md` so the Local Agent knows to force-rebuild the static library / `XCFramework` (`./scripts/dev.sh build-rust --force && ./scripts/dev.sh xcode-gen`).
4. **Append Cloud Dev Log & Push**:
   - Prepend a reverse-chronological entry to `ops/cloud-dev-log/CLOUD_DEV_LOG.md` containing: Base Commit, FFI Rebuild Flag, Feature Summary, Modified File List, and Physical Device Verification Checklist.
   - Commit & push to `origin/main`, then give the user a **copy-paste Handoff Prompt** for the Local IDE Agent.
   - **Turn Discipline**: After handing off to Local, do NOT push extra commits to `main` until Local finishes its turn (guarantees fast-forward pushes with zero rebasing friction).

### 3.2 Local IDE Agent (Xcode / Mac) Turn Protocol
1. **Sync & Read Cloud Log**: Run `git pull --rebase` and read the top entry of `ops/cloud-dev-log/CLOUD_DEV_LOG.md`.
2. **Rebuild Native Core When Flagged**: If `CLOUD_DEV_LOG.md` flags FFI/core changes (or `core/` changed in `git pull`), run:
   ```bash
   ./scripts/dev.sh build-rust --force
   ./scripts/dev.sh xcode-gen
   ```
   Otherwise incremental build (`make sync`) skips Rust in `< 50ms`.
3. **Verify Native Builds, Tests & Real Device**:
   - Build all native targets under strict concurrency (e.g., Swift 6) and run full unit tests (`MangaStudio-macOS-Tests`).
   - Fix any platform SDK / compiler / real-device ergonomics issues directly.
   - Deploy to physical device (`make run-ipad-device`) using gitignored `LocalSigning.xcconfig`.
4. **Security Audit Before Pushing**:
   - Verify `git status -s` and `git diff -- apps/apple/project.yml apps/apple/BaseSigning.xcconfig` contain **ZERO personal `DEVELOPMENT_TEAM` IDs or secrets**.
   - **NEVER** force-add (`git add -f`) `.xcodeproj/`, `Frameworks/`, `DerivedData/`, or `LocalSigning.xcconfig`.
5. **Append Local Dev Log & Push**:
   - Prepend a reverse-chronological entry to `ops/local-dev-log/<LOCAL_LOG>.md` (Device, Stage, Fixes/UX Polish, Modified Files, Test/Device Pass Results, and Cloud Core Follow-Up Requests).
   - Push cleanly using `make push MSG="fix(ipados): ..."` (never `make gonext`).

---

## 4. Conflict-Free Recovery Protocol (When Both Sides Edited Simultaneously)

If Local made unpushed edits while Cloud also pushed to `origin/main` (e.g., both touched `project.yml` or `Assets.xcassets`):
1. **Do NOT rebase locally on `main`**. Instead, Local pushes its exact state to a temporary branch:
   ```bash
   git checkout -b local/<topic-slug>
   git add -A
   git commit -m "wip(local): <summary>"
   git push -u origin local/<topic-slug>
   ```
   *(If Xcode GUI-only changes were made inside gitignored `project.pbxproj`, dump non-secret settings via `grep -E "PRODUCT_BUNDLE_IDENTIFIER|INFOPLIST_KEY|ASSETCATALOG|TARGETED_DEVICE_FAMILY|DEPLOYMENT_TARGET" *.xcodeproj/project.pbxproj | sort -u`.)*
2. **Cloud Agent Reconciles**: Cloud fetches `local/<topic-slug>`, merges the best of both (e.g., keeping verified device assets/fixes while stripping any hardcoded Team ID into `LocalSigning.xcconfig`), runs `make check`, pushes `origin/main`, and deletes the temporary remote branch (`git push origin --delete local/<topic-slug>`).
3. **Local Resets Cleanly**:
   ```bash
   git checkout main && git branch -D local/<topic-slug> && git pull --rebase
   ```

---

## 5. Persistent Signing Pattern (Survives Project Regeneration)

Never store personal signing IDs in tracked build manifests (`project.yml`) or manually inside regenerated `.xcodeproj` files:
1. Track `BaseSigning.xcconfig`:
   ```xcconfig
   CODE_SIGN_STYLE = Automatic
   ABOUT_PAINT_BUNDLE_PREFIX = org.example.app
   #include? "LocalSigning.xcconfig"
   ```
2. Add `LocalSigning.xcconfig` to `.gitignore` and provide a one-command generator (`make ipad-setup-signing TEAM_ID=<10-char-id> [BUNDLE_PREFIX=...]`).
3. Every subsequent `xcodegen generate` / `make sync` preserves local signing automatically without leaking credentials to Git.

---

## 6. Copy-Paste Handoff Prompt Templates

### Cloud → Local IDE Agent Template
```text
Cloud has pushed <milestone> (commit <SHA>) and logged full details in ops/cloud-dev-log/CLOUD_DEV_LOG.md. Please take over in local Xcode:
1. Run `git pull --rebase` and read the top entry of ops/cloud-dev-log/CLOUD_DEV_LOG.md.
2. [If FFI/core changed] Run `./scripts/dev.sh build-rust --force && ./scripts/dev.sh xcode-gen`.
3. Build all native targets cleanly, run full native XCTests, fix any SDK/strict-concurrency or device UX nuances, and deploy to the physical device (`make run-ipad-device` using gitignored LocalSigning.xcconfig).
4. Append your verification results and any Cloud-side core follow-ups to ops/local-dev-log/IPAD_MAC_DEV_LOG.md (do NOT edit CLOUD_DEV_LOG.md).
5. Verify no personal TEAM_ID is in tracked files, then push via `make push MSG="..."` (do NOT run `make gonext`).
```

### Local IDE Agent → Cloud Agent Template
```text
Local Xcode agent finished device polish & verification and pushed commit <SHA> via `make push`, with details logged in ops/local-dev-log/IPAD_MAC_DEV_LOG.md. Please run `git pull --rebase`, read the latest local dev log entry, audit cross-platform guards, and implement the requested Cloud core / FFI follow-ups.
```

---

## 7. 5-Minute Adoption Checklist for New Projects

1. Create `ops/cloud-dev-log/CLOUD_DEV_LOG.md` and `ops/local-dev-log/LOCAL_DEV_LOG.md` with ownership headers.
2. Copy this `SKILL.md` into `<repo>/skills/cloud-local-dual-agent-collab/SKILL.md` so both Cloud and Local IDE agents discover it automatically.
3. Add `BaseSigning.xcconfig` (`#include? "LocalSigning.xcconfig"`), `LocalSigning.xcconfig.example`, and ignore `LocalSigning.xcconfig` + generated `.xcodeproj/` / build outputs in `.gitignore`.
4. Provide unified `Makefile` shortcuts (`make check`, `make sync`, `make push MSG="..."`, `make run-<device>`), plus optional `ops/relay/` (`gitops-gonext-relay-setup`) if overnight unattended loops are also desired.
