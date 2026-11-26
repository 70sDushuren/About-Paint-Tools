# `ops/relay` — Cloud ↔ Local Mac `GoNext` Async Relay

This directory implements a **zero-conflict, append-only GitOps relay** connecting the Cloud Linux VM (Rust core, cross-platform code, docs, i18n, CI) with a local Apple Silicon MacBook Pro (Xcode, 3-slice `MangaCore.xcframework`, Metal/iOS Simulator/Device builds).

## Protocol & Audit Trail

- **`orders/<YYYYMMDD-HHMMSS>_<slug>.json`** *(written only by Cloud / Orchestrator, never mutated)*:
  Declares the next milestone verification or build steps using a **strict local action allowlist** (no arbitrary shell execution).
- **`results/<YYYYMMDD-HHMMSS>_<slug>.result.md`** *(written only by Local Mac, never mutated)*:
  Paired 1:1 with the same timestamped `order_id`. Records host environment, overall `PASS`/`FAIL` status, per-step exit codes & durations, and trimmed logs as a permanent chronological engineering log.

Because Cloud only appends to `orders/` and Mac only appends to `results/`, **merge conflicts are structurally eliminated**, and both folders double as a chronological development audit log.

## Allowed Actions (Security Allowlist)

Only these pre-audited actions may appear in `orders/*.json` (enforced by both `scripts/relay_tool.py validate` in CI and `scripts/mac_relay.sh` locally):

| Action | Description |
| :--- | :--- |
| `env-info` | Records macOS version, Apple Silicon chip, Xcode, Rust, XcodeGen versions, and Git SHA |
| `build-rust` | Incremental 3-slice `MangaCore.xcframework` build (`scripts/dev.sh build-rust`) |
| `build-rust-force` | Forced clean 3-slice `MangaCore.xcframework` rebuild |
| `xcode-gen` | Regenerates `apps/apple/MangaStudioApple.xcodeproj` from `apps/apple/project.yml` |
| `build-mac` | Headless `xcodebuild` for `MangaStudio-macOS-Touch` (`arm64`, `CODE_SIGNING_ALLOWED=NO`) |
| `build-ipad` | Headless `xcodebuild` for `MangaStudio-iPadOS` (`iOS Simulator`, `CODE_SIGNING_ALLOWED=NO`) |
| `build-duo` | Headless `xcodebuild` for `MangaStudio-iPhoneDuo` (`iOS Simulator`, `CODE_SIGNING_ALLOWED=NO`) |
| `test-mac` | Runs macOS XCTest suite if test targets exist (cleanly skips otherwise) |
| `test-ipad` | Runs iPadOS Simulator XCTest suite if test targets exist (cleanly skips otherwise) |
| `launch-mac` | Launches the built `MangaStudio-macOS-Touch.app` for visual inspection |
| `open-xcode` | Opens `apps/apple/MangaStudioApple.xcodeproj` in Xcode |
| `check` | Runs full CI + `S4` Tri-App integration gate (`scripts/dev.sh check`) |

## Safety Circuit Breakers & Time/Count Budgets

To prevent runaway loops during autonomous Cloud ↔ Mac sessions, **both** sides enforce independent safety guards:

1. **Wall-Clock Time Limit (`MAX_MIN`, default `60` min)**:
   - Never aborts an active build mid-flight: if time expires during an order, Mac finishes and pushes that order's `.result.md`, then immediately exits/unloads and notifies you.
2. **Order Count Limit (`MAX_ORDERS`, default `10`)**:
   - Stops cleanly once `N` orders have been executed in the session.
3. **Loop & Consecutive Failure Circuit Breaker (`MAX_FAILS`, default `3`)**:
   - Trips immediately on `MAX_FAILS` consecutive `FAIL` receipts **or** on **2 consecutive identical error fingerprints** (`DUPLICATE_ERROR_LOOP`), locking local execution until you review and run `make relay-resume`.
4. **Cloud-Side Bounded Wait & Pre-Dispatch Audit**:
   - Cloud checks `python3 scripts/relay_tool.py guard-check` before emitting each new order and bounds receipt polling via `--timeout` & `--max-polls`.
5. **Two-Way Emergency Stop (Kill Switch)**:
   - Local instant stop: `Ctrl+C` or `make relay-stop` (halts watch/agent and writes `.git/about-paint-relay.paused`).
   - Remote stop from Git: commit `ops/relay/PAUSE` to halt both sides immediately until deleted.

## Daily Usage on MacBook Pro

```bash
# Single fixed manual command
make gonext

# Guarded foreground auto-watch (defaults: 60 min, 10 orders, 3 consecutive FAILs, 30s poll)
make relay-watch
make relay-watch MAX_MIN=30 MAX_ORDERS=5 MAX_FAILS=2 INTERVAL=20

# Guarded macOS background LaunchAgent (auto-unloads cleanly when time/order/fail budget trips)
make relay-install-agent MAX_MIN=90 MAX_ORDERS=12 MAX_FAILS=3

# Emergency stop, status inspection & resume
make relay-stop
make relay-status
make relay-resume
make relay-uninstall-agent
```
