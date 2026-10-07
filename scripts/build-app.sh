#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Polish requires macOS and the Xcode command-line tools." >&2
  exit 1
fi
# Keep build products and module caches scoped to this checkout.
BUILD_PATH="${BUILD_PATH:-$(pwd)/.build}"
mkdir -p "$BUILD_PATH"
export CLANG_MODULE_CACHE_PATH="$BUILD_PATH/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_PATH/swift-module-cache"
swift build --scratch-path "$BUILD_PATH" -c release
BIN_PATH="$(swift build --scratch-path "$BUILD_PATH" -c release --show-bin-path)"
APP="$(pwd)/dist/Polish.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist/AppIcon.iconset
cp "$BIN_PATH/Polish" "$APP/Contents/MacOS/Polish"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$(pwd)/dist/AppIcon.iconset"
iconutil -c icns dist/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
