#!/bin/sh
# Xcode Cloud post-clone hook: installs minimal Rust toolchain, runs Rust core tests,
# and builds MangaCore.xcframework before xcodebuild runs.
set -euo pipefail

echo "=== [Xcode Cloud] Preparing Rust toolchain for About-Paint-Tools ==="
export HOME="${HOME:-/Users/local}"
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"
export PATH="$CARGO_HOME/bin:$PATH"

if ! command -v cargo >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
fi

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../../.." && pwd)}"

echo "=== [Xcode Cloud] Running Rust manga-core unit tests ==="
cargo test --manifest-path "$REPO_ROOT/core/Cargo.toml" -p manga-core

echo "=== [Xcode Cloud] Building MangaCore.xcframework ==="
sh "$REPO_ROOT/scripts/build_apple_xcframework.sh"

echo "=== [Xcode Cloud] Post-clone setup complete ==="
