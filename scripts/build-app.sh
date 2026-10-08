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
BUILD_ARGS=(--scratch-path "$BUILD_PATH" -c release)
# UNIVERSAL=1 builds for Apple Silicon and Intel; it requires full Xcode, not only the Command Line Tools.
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
APP="$(pwd)/dist/Polish.app"
rm -rf "$APP" dist/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist/AppIcon.iconset
cp "$BIN_PATH/Polish" "$APP/Contents/MacOS/Polish"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"
swift scripts/make-icon.swift "$(pwd)/dist/AppIcon.iconset"
iconutil -c icns dist/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built: $APP ($(lipo -archs "$APP/Contents/MacOS/Polish"))"
