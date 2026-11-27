#!/usr/bin/env bash
# Unified local + cloud development workflow driver for About-Paint-Tools.
# Compatible with macOS default bash 3.2+ and Linux bash 5+.
set -euo pipefail

# Ensure Homebrew & Rust toolchains are reachable even when invoked from Xcode Run Script phases.
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APPLE_DIR="$ROOT/apps/apple"
XCFRAMEWORK="$APPLE_DIR/Frameworks/MangaCore.xcframework"
STAMP_FILE="$APPLE_DIR/.xcframework.stamp"
XCODEPROJ="$APPLE_DIR/MangaStudioApple.xcodeproj"

is_macos() {
  [ "$(uname -s)" = "Darwin" ]
}

# Computes a deterministic SHA-256 fingerprint of all Rust core inputs that affect MangaCore.xcframework.
compute_rust_fingerprint() {
  python3 - "$ROOT" <<'PY'
import hashlib, os, sys

root = sys.argv[1]
paths = [
    os.path.join(root, "core", "Cargo.toml"),
    os.path.join(root, "core", "Cargo.lock"),
    os.path.join(root, "core", "manga-core", "Cargo.toml"),
]
for rel in ("core/manga-core/src", "core/manga-core/include"):
    base = os.path.join(root, rel)
    if os.path.isdir(base):
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames.sort()
            for fname in sorted(filenames):
                paths.append(os.path.join(dirpath, fname))

h = hashlib.sha256()
for p in paths:
    if os.path.isfile(p):
        rel_p = os.path.relpath(p, root).replace("\\", "/")
        h.update(rel_p.encode("utf-8"))
        h.update(b"\0")
        with open(p, "rb") as f:
            h.update(f.read())
        h.update(b"\0")
print(h.hexdigest())
PY
}

xcframework_is_fresh() {
  if [ ! -d "$XCFRAMEWORK" ] || [ ! -f "$STAMP_FILE" ]; then
    return 1
  fi
  local current saved
  current="$(compute_rust_fingerprint)"
  saved="$(cat "$STAMP_FILE" 2>/dev/null || true)"
  [ "$current" = "$saved" ]
}

cmd_build_rust() {
  local force="${1:-0}"
  if ! is_macos; then
    echo "==> [Linux] Building Rust workspace (manga-core + manga-linux-shell)"
    cargo build --manifest-path "$ROOT/core/Cargo.toml" --workspace
    return 0
  fi

  if [ "$force" != "1" ] && xcframework_is_fresh; then
    echo "==> Rust core unchanged — skipping MangaCore.xcframework rebuild (pass --force to rebuild)."
    return 0
  fi

  echo "==> Rebuilding 3-slice MangaCore.xcframework..."
  bash "$ROOT/scripts/build_apple_xcframework.sh"
  compute_rust_fingerprint > "$STAMP_FILE"
  echo "==> Saved incremental build stamp: $STAMP_FILE"
}

cmd_ensure_rust_xcode() {
  # Called from Xcode preBuildScripts. Fast-path when Xcode Cloud already built it or stamp is fresh.
  if [ "${CI:-}" = "TRUE" ] && [ -d "$XCFRAMEWORK" ]; then
    echo "[Xcode Pre-Build] CI=TRUE and MangaCore.xcframework present; skipping."
    return 0
  fi
  cmd_build_rust 0
}

cmd_xcode_gen() {
  if ! is_macos; then
    echo "note: xcodegen is macOS-only; skipping on $(uname -s)."
    return 0
  fi
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not found. Install via: brew install xcodegen" >&2
    exit 1
  fi
  echo "==> Generating $XCODEPROJ from apps/apple/project.yml..."
  (cd "$APPLE_DIR" && xcodegen generate)
}

cmd_sync() {
  local force_rust=0
  local open_xcode=1
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --force-rust|--force) force_rust=1 ;;
      --no-open) open_xcode=0 ;;
      *) echo "error: unknown sync option '$1'" >&2; exit 1 ;;
    esac
    shift
  done

  cd "$ROOT"
  if [ -z "$(git status --porcelain)" ]; then
    echo "==> [1/3] Pulling latest commits from origin..."
    git pull --rebase
  else
    echo "==> [1/3] Working tree has local edits; skipping 'git pull --rebase' to keep changes safe."
    git status -s
  fi

  if is_macos; then
    echo "==> [2/3] Ensuring 3-slice MangaCore.xcframework is up to date..."
    cmd_build_rust "$force_rust"

    echo "==> [3/3] Refreshing MangaStudioApple.xcodeproj..."
    cmd_xcode_gen

    if [ "$open_xcode" = "1" ]; then
      echo "==> Opening $XCODEPROJ in Xcode..."
      open "$XCODEPROJ"
    fi
  else
    echo "==> [2/3] Checking Rust workspace on Linux..."
    cargo check --manifest-path "$ROOT/core/Cargo.toml" --workspace
    echo "==> [3/3] Sync complete (Linux host)."
  fi
}

cmd_check() {
  cd "$ROOT"
  echo "==> [1/7] Checking 5-language i18n & 1:1 bilingual docs..."
  python3 "$ROOT/scripts/i18n_check.py"

  echo "==> [2/7] Checking Apple .xcstrings & Android strings.xml sync..."
  python3 "$ROOT/scripts/i18n_sync.py" --check-xcstrings --check-android

  echo "==> [3/7] Validating canonical CPFF v1.0 SampleManga project..."
  python3 "$ROOT/scripts/prj_validate.py" "$ROOT/templates/SampleManga"

  echo "==> [4/7] Validating GoNext relay orders against strict allowlist..."
  python3 "$ROOT/scripts/relay_tool.py" validate

  echo "==> [5/7] Verifying C11 FFI header (zero warnings)..."
  cc -std=c11 -Wall -Wextra -Werror -fsyntax-only "$ROOT/core/manga-core/include/manga_core.h"

  echo "==> [6/7] Running Rust workspace tests & 3 modular feature slices..."
  cargo test --manifest-path "$ROOT/core/Cargo.toml" --workspace --all-targets
  cargo check --manifest-path "$ROOT/core/Cargo.toml" -p manga-core --no-default-features --features hub
  cargo check --manifest-path "$ROOT/core/Cargo.toml" -p manga-core --no-default-features --features canvas
  cargo check --manifest-path "$ROOT/core/Cargo.toml" -p manga-core --no-default-features --features novel

  echo "==> [7/7] Running Tri-App headless self-checks & S4 Integration Gate..."
  cargo run --manifest-path "$ROOT/core/Cargo.toml" -p manga-linux-shell -- --app hub --self-check
  cargo run --manifest-path "$ROOT/core/Cargo.toml" -p manga-linux-shell -- --app manga --self-check
  cargo run --manifest-path "$ROOT/core/Cargo.toml" -p manga-linux-shell -- --app novel --self-check
  cargo run --manifest-path "$ROOT/core/Cargo.toml" -p manga-linux-shell -- --integration-check

  echo "OK: All About-Paint-Tools CI & S4 integration gates passed."
}

cmd_run() {
  local target="${1:-mac}"
  if ! is_macos; then
    echo "error: 'run $target' requires macOS with Xcode installed." >&2
    exit 1
  fi

  cmd_build_rust 0
  if [ ! -d "$XCODEPROJ" ]; then
    cmd_xcode_gen
  fi

  local derived="$APPLE_DIR/DerivedData"
  case "$target" in
    mac|macos)
      echo "==> Building MangaStudio-macOS-Touch for My Mac..."
      xcodebuild \
        -project "$XCODEPROJ" \
        -scheme "MangaStudio-macOS-Touch" \
        -configuration Debug \
        -derivedDataPath "$derived" \
        -destination "platform=macOS,arch=arm64" \
        CODE_SIGNING_ALLOWED=NO \
        build
      local app_path="$derived/Build/Products/Debug/MangaStudio-macOS-Touch.app"
      if [ -d "$app_path" ]; then
        echo "==> Launching $app_path"
        open "$app_path"
      else
        echo "OK: Build succeeded. Open Xcode to launch MangaStudio-macOS-Touch."
      fi
      ;;
    ipad|ipados)
      echo "==> Building MangaStudio-iPadOS for Apple Silicon iOS Simulator..."
      xcodebuild \
        -project "$XCODEPROJ" \
        -scheme "MangaStudio-iPadOS" \
        -configuration Debug \
        -derivedDataPath "$derived" \
        -destination "generic/platform=iOS Simulator" \
        CODE_SIGNING_ALLOWED=NO \
        build
      echo "OK: MangaStudio-iPadOS simulator build succeeded. Press Cmd+R in Xcode or run on Simulator."
      ;;
    duo|iphoneduo)
      echo "==> Building MangaStudio-iPhoneDuo for Apple Silicon iOS Simulator..."
      xcodebuild \
        -project "$XCODEPROJ" \
        -scheme "MangaStudio-iPhoneDuo" \
        -configuration Debug \
        -derivedDataPath "$derived" \
        -destination "generic/platform=iOS Simulator" \
        CODE_SIGNING_ALLOWED=NO \
        build
      echo "OK: MangaStudio-iPhoneDuo simulator build succeeded. Press Cmd+R in Xcode or run on Simulator."
      ;;
    *)
      echo "error: unknown target '$target'. Expected: mac | ipad | duo" >&2
      exit 1
      ;;
  esac
}

cmd_push() {
  local msg="${1:-}"
  if [ -z "$msg" ]; then
    echo "error: commit message required. Usage: ./scripts/dev.sh push \"feat(...): message\"" >&2
    exit 1
  fi

  cd "$ROOT"
  if [ -z "$(git status --porcelain)" ]; then
    echo "Nothing to commit (working tree clean)."
    return 0
  fi

  echo "==> Running full local CI check before committing..."
  cmd_check

  echo "==> Staging changes:"
  git status -s
  git add -A
  git commit -m "$msg"

  echo "==> Rebasing onto origin and pushing..."
  git pull --rebase
  git push
  echo "OK: Checked, committed, and pushed to origin."
}

cmd_ipad_setup_signing() {
  local team_id="${1:-}"
  local bundle_prefix="${2:-}"
  if [ -z "$team_id" ]; then
    echo "error: TEAM_ID is required. Usage: make ipad-setup-signing TEAM_ID=XXXXXXXXXX [BUNDLE_PREFIX=com.yourname.aboutpaint]" >&2
    exit 1
  fi
  local cfg="$APPLE_DIR/LocalSigning.xcconfig"
  {
    echo "// Generated by 'make ipad-setup-signing' (gitignored; preserved across 'make sync' & XcodeGen)"
    echo "DEVELOPMENT_TEAM = $team_id"
    if [ -n "$bundle_prefix" ]; then
      echo "ABOUT_PAINT_BUNDLE_PREFIX = $bundle_prefix"
    fi
  } > "$cfg"
  echo "OK: Wrote persistent local signing override -> $cfg"
  if is_macos; then
    cmd_xcode_gen
  fi
}

cmd_ipad_devices() {
  if ! is_macos; then
    echo "error: ipad-devices requires macOS with Xcode installed." >&2
    exit 1
  fi
  echo "==> Discovering connected physical iPad / iOS devices via devicectl..."
  xcrun devicectl list devices
}

cmd_build_ipad_device() {
  if ! is_macos; then
    echo "error: build-ipad-device requires macOS with Xcode installed." >&2
    exit 1
  fi
  cmd_build_rust 0
  [ -d "$XCODEPROJ" ] || cmd_xcode_gen
  local derived="$APPLE_DIR/DerivedData"
  echo "==> Building MangaStudio-iPadOS for REAL iPadOS arm64 Device (generic/platform=iOS)..."
  xcodebuild \
    -project "$XCODEPROJ" \
    -scheme "MangaStudio-iPadOS" \
    -configuration Debug \
    -derivedDataPath "$derived" \
    -destination "generic/platform=iOS" \
    CODE_SIGNING_ALLOWED=NO \
    build
  echo "OK: Physical iPadOS arm64 device build succeeded (links aarch64-apple-ios Rust slice)."
}

cmd_run_ipad_device() {
  local device_filter="${1:-iPad}"
  if ! is_macos; then
    echo "error: run-ipad-device requires macOS with Xcode installed." >&2
    exit 1
  fi
  local signing_cfg="$APPLE_DIR/LocalSigning.xcconfig"
  if [ ! -f "$signing_cfg" ]; then
    echo "error: $signing_cfg not found." >&2
    echo "Run once first: make ipad-setup-signing TEAM_ID=<YOUR_10_CHAR_TEAM_ID> [BUNDLE_PREFIX=com.yourname.aboutpaint]" >&2
    exit 1
  fi

  cmd_build_rust 0
  cmd_xcode_gen

  local tmp_json
  tmp_json="$(mktemp)"
  xcrun devicectl list devices --json-output "$tmp_json" >/dev/null
  local device_info
  device_info="$(python3 - "$tmp_json" "$device_filter" <<'PY'
import json, sys
path, needle = sys.argv[1], sys.argv[2].lower()
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
devices = data.get("result", {}).get("devices", [])
for d in devices:
    props = d.get("deviceProperties", {})
    hw = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    name = props.get("name", "")
    platform = hw.get("platform", "")
    state = conn.get("tunnelState", "") or conn.get("pairingState", "")
    if platform == "iOS" and (needle in name.lower() or "ipad" in hw.get("marketingName", "").lower() or needle in d.get("identifier", "").lower()):
        udid = hw.get("udid") or d.get("identifier")
        core_id = d.get("identifier")
        print(f"{udid}\t{core_id}\t{name}\t{state}")
        sys.exit(0)
sys.exit(1)
PY
  )" || {
    rm -f "$tmp_json"
    echo "error: No connected iPad matching '$device_filter' found." >&2
    echo "Connect your iPad Pro 13-inch (M5) via USB-C, unlock it, enable Developer Mode, and run 'make ipad-devices'." >&2
    exit 1
  }
  rm -f "$tmp_json"

  local udid core_id dev_name
  udid="$(printf '%s' "$device_info" | cut -f1)"
  core_id="$(printf '%s' "$device_info" | cut -f2)"
  dev_name="$(printf '%s' "$device_info" | cut -f3)"
  echo "==> Target physical iPad: $dev_name (UDID: $udid)"

  local derived="$APPLE_DIR/DerivedData"
  echo "==> Building signed MangaStudio-iPadOS for physical iPad Pro..."
  xcodebuild \
    -project "$XCODEPROJ" \
    -scheme "MangaStudio-iPadOS" \
    -configuration Debug \
    -derivedDataPath "$derived" \
    -destination "id=$udid" \
    -allowProvisioningUpdates \
    build

  local app_path="$derived/Build/Products/Debug-iphoneos/MangaStudio-iPadOS.app"
  if [ ! -d "$app_path" ]; then
    echo "error: Built app not found at $app_path" >&2
    exit 1
  fi

  local bundle_id
  bundle_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_path/Info.plist")"
  echo "==> Installing $app_path ($bundle_id) onto $dev_name..."
  xcrun devicectl device install app --device "$core_id" "$app_path"

  echo "==> Launching $bundle_id on $dev_name..."
  xcrun devicectl device process launch --device "$core_id" "$bundle_id" || true
  echo "OK: Deployed & launched AboutPaint iPad ($bundle_id) on $dev_name!"
}

cmd_archive_ipad_testflight() {
  if ! is_macos; then
    echo "error: archive-ipad-testflight requires macOS with Xcode installed." >&2
    exit 1
  fi
  if [ ! -f "$APPLE_DIR/LocalSigning.xcconfig" ]; then
    echo "error: apps/apple/LocalSigning.xcconfig not found. Run: make ipad-setup-signing TEAM_ID=<YOUR_TEAM_ID>" >&2
    exit 1
  fi
  cmd_build_rust 0
  cmd_xcode_gen
  local archive_path="$APPLE_DIR/build/MangaStudio-iPadOS.xcarchive"
  rm -rf "$archive_path"
  mkdir -p "$APPLE_DIR/build"
  echo "==> Archiving Release MangaStudio-iPadOS for TestFlight..."
  xcodebuild \
    -project "$XCODEPROJ" \
    -scheme "MangaStudio-iPadOS" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$archive_path" \
    -allowProvisioningUpdates \
    archive
  echo "OK: Created TestFlight archive -> $archive_path"
  echo "==> Opening archive in Xcode Organizer (click 'Distribute App' -> 'TestFlight & App Store')..."
  open "$archive_path"
}

cmd_status() {
  cd "$ROOT"
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  echo "Repository : $ROOT"
  echo "Branch     : $branch ($(git rev-parse --short HEAD))"
  if is_macos; then
    if xcframework_is_fresh; then
      echo "XCFramework: FRESH ($XCFRAMEWORK)"
    else
      echo "XCFramework: STALE or MISSING (run 'make sync' or 'make build-rust')"
    fi
    if [ -d "$XCODEPROJ" ]; then
      echo "XcodeProj  : PRESENT ($XCODEPROJ)"
    else
      echo "XcodeProj  : MISSING (run 'make xcode')"
    fi
    if [ -f "$APPLE_DIR/LocalSigning.xcconfig" ]; then
      echo "iPad Sign  : CONFIGURED ($APPLE_DIR/LocalSigning.xcconfig)"
    else
      echo "iPad Sign  : NOT CONFIGURED (run 'make ipad-setup-signing TEAM_ID=...')"
    fi
  else
    echo "Host OS    : $(uname -s) (Cloud/Linux mode)"
  fi
  echo "Git Status :"
  if [ -z "$(git status --porcelain)" ]; then
    echo "  (clean)"
  else
    git status -s | sed 's/^/  /'
  fi
}

usage() {
  cat <<'EOF'
About-Paint-Tools Unified Workflow Driver (scripts/dev.sh) — iPad Pro 13" (M5) Primary

Usage:
  ./scripts/dev.sh sync [--force-rust] [--no-open]           Pull latest, incremental Rust XCFramework build, XcodeGen & open Xcode
  ./scripts/dev.sh ipad-setup-signing <TEAM_ID> [PREFIX]     Save persistent local Apple Team ID (survives make sync/xcodegen)
  ./scripts/dev.sh ipad-devices                              List connected physical iPad Pro devices (USB/Wi-Fi)
  ./scripts/dev.sh build-ipad-device                         Verify real arm64 iPadOS device build (aarch64-apple-ios)
  ./scripts/dev.sh run-ipad-device [DEVICE_FILTER]           Build, sign, install & launch onto connected physical iPad Pro!
  ./scripts/dev.sh archive-ipad-testflight                   Create Release .xcarchive and open Xcode Organizer for TestFlight
  ./scripts/dev.sh build-rust [--force]                      Incremental (or forced) 3-slice Rust XCFramework build
  ./scripts/dev.sh xcode-gen                                 Regenerate apps/apple/MangaStudioApple.xcodeproj from project.yml
  ./scripts/dev.sh run <mac|ipad|duo>                        Build Simulator / Mac target via xcodebuild
  ./scripts/dev.sh check                                     Run full GitHub CI + S4 Tri-App integration gates locally
  ./scripts/dev.sh push "<commit message>"                   Run 'check', commit, rebase, and push safely to origin
  ./scripts/dev.sh status                                    Show branch, signing config, git status & XCFramework freshness
EOF
}

cmd="${1:-help}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$cmd" in
  sync)                    cmd_sync "$@" ;;
  ipad-setup-signing)      cmd_ipad_setup_signing "${1:-}" "${2:-}" ;;
  ipad-devices)            cmd_ipad_devices ;;
  build-ipad-device)       cmd_build_ipad_device ;;
  run-ipad-device)         cmd_run_ipad_device "${1:-iPad}" ;;
  archive-ipad-testflight) cmd_archive_ipad_testflight ;;
  build-rust)
    force=0
    if [ "${1:-}" = "--force" ]; then force=1; fi
    cmd_build_rust "$force"
    ;;
  ensure-rust-xcode)       cmd_ensure_rust_xcode ;;
  xcode-gen)               cmd_xcode_gen ;;
  run)                     cmd_run "$@" ;;
  check)                   cmd_check ;;
  push)                    cmd_push "${1:-}" ;;
  status)                  cmd_status ;;
  help|-h|--help)          usage ;;
  *)
    echo "error: unknown command '$cmd'" >&2
    usage >&2
    exit 1
    ;;
esac
