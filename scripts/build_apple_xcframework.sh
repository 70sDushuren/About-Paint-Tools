#!/usr/bin/env bash
# Builds a 3-slice universal Apple XCFramework (iOS Device + Apple Silicon iOS Simulator + Apple Silicon macOS)
# from Rust `core/manga-core` for Xcode local development and CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_MANIFEST="$ROOT/core/Cargo.toml"
HEADER_DIR="$ROOT/core/manga-core/include"
OUT_DIR="$ROOT/apps/apple/Frameworks"
XCFRAMEWORK="$OUT_DIR/MangaCore.xcframework"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: build_apple_xcframework.sh must be run on macOS with Xcode installed." >&2
  exit 1
fi

for target in aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-darwin; do
  if ! rustup target list --installed | grep -qx "$target"; then
    echo "==> Adding missing Rust target: $target"
    rustup target add "$target"
  fi
done

echo "==> [1/4] Building manga-core for iOS / iPadOS Device (aarch64-apple-ios)"
cargo build --manifest-path "$CORE_MANIFEST" -p manga-core --release --target aarch64-apple-ios

echo "==> [2/4] Building manga-core for Apple Silicon iOS / iPadOS Simulator (aarch64-apple-ios-sim)"
cargo build --manifest-path "$CORE_MANIFEST" -p manga-core --release --target aarch64-apple-ios-sim

echo "==> [3/4] Building manga-core for Apple Silicon macOS (aarch64-apple-darwin)"
cargo build --manifest-path "$CORE_MANIFEST" -p manga-core --release --target aarch64-apple-darwin

echo "==> [4/4] Packaging $XCFRAMEWORK"
rm -rf "$XCFRAMEWORK"
mkdir -p "$OUT_DIR"

xcodebuild -create-xcframework \
  -library "$ROOT/core/target/aarch64-apple-ios/release/libmanga_core.a"     -headers "$HEADER_DIR" \
  -library "$ROOT/core/target/aarch64-apple-ios-sim/release/libmanga_core.a" -headers "$HEADER_DIR" \
  -library "$ROOT/core/target/aarch64-apple-darwin/release/libmanga_core.a"  -headers "$HEADER_DIR" \
  -output "$XCFRAMEWORK"

echo "OK: Built $XCFRAMEWORK (iOS Device + iOS Simulator + macOS Apple Silicon)"
