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

## Daily Usage on MacBook Pro

```bash
make gonext                # Fixed single command: pull, run pending GoNext orders, push paired results
make relay-status          # Show pending/completed order log and LaunchAgent status
make relay-watch           # Foreground polling loop (every 30s)
make relay-install-agent   # Install macOS launchd background agent (every 60s, survives reboot)
make relay-uninstall-agent # Remove macOS launchd background agent
```
