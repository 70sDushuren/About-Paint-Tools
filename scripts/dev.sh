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
  echo "==> [1/6] Checking 5-language i18n & 1:1 bilingual docs..."
  python3 "$ROOT/scripts/i18n_check.py"

  echo "==> [2/6] Checking Apple .xcstrings & Android strings.xml sync..."
  python3 "$ROOT/scripts/i18n_sync.py" --check-xcstrings --check-android

  echo "==> [3/6] Validating canonical CPFF v1.0 SampleManga project..."
  python3 "$ROOT/scripts/prj_validate.py" "$ROOT/templates/SampleManga"

  echo "==> [4/6] Verifying C11 FFI header (zero warnings)..."
  cc -std=c11 -Wall -Wextra -Werror -fsyntax-only "$ROOT/core/manga-core/include/manga_core.h"

  echo "==> [5/6] Running Rust workspace tests & 3 modular feature slices..."
  cargo test --manifest-path "$ROOT/core/Cargo.toml" --workspace --all-targets
  cargo check --manifest-path "$ROOT/core/Cargo.toml" -p manga-core --no-default-features --features hub
  cargo check --manifest-path "$ROOT/core/Cargo.toml" -p manga-core --no-default-features --features canvas
  cargo check --manifest-path "$ROOT/core/Cargo.toml" -p manga-core --no-default-features --features novel

  echo "==> [6/6] Running Tri-App headless self-checks & S4 Integration Gate..."
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
About-Paint-Tools Unified Workflow Driver (scripts/dev.sh)

Usage:
  ./scripts/dev.sh sync [--force-rust] [--no-open]   Pull latest, incremental Rust XCFramework build, XcodeGen & open Xcode
  ./scripts/dev.sh build-rust [--force]              Incremental (or forced) 3-slice Rust XCFramework build
  ./scripts/dev.sh xcode-gen                         Regenerate apps/apple/MangaStudioApple.xcodeproj from project.yml
  ./scripts/dev.sh run <mac|ipad|duo>                Build (and launch on Mac) an Apple target via xcodebuild
  ./scripts/dev.sh check                             Run full GitHub CI + S4 Tri-App integration gates locally
  ./scripts/dev.sh push "<commit message>"           Run 'check', commit, rebase, and push safely to origin
  ./scripts/dev.sh status                            Show branch, git status, and XCFramework freshness
EOF
}

cmd="${1:-help}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$cmd" in
  sync)              cmd_sync "$@" ;;
  build-rust)
    force=0
    if [ "${1:-}" = "--force" ]; then force=1; fi
    cmd_build_rust "$force"
    ;;
  ensure-rust-xcode) cmd_ensure_rust_xcode ;;
  xcode-gen)         cmd_xcode_gen ;;
  run)               cmd_run "$@" ;;
  check)             cmd_check ;;
  push)              cmd_push "${1:-}" ;;
  status)            cmd_status ;;
  help|-h|--help)    usage ;;
  *)
    echo "error: unknown command '$cmd'" >&2
    usage >&2
    exit 1
    ;;
esac
