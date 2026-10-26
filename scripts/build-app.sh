#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/StandUpReminder.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

python3 "$ROOT_DIR/scripts/test-icon-assets.py"

swift build --package-path "$ROOT_DIR" -c release
BIN_DIR="$(swift build --package-path "$ROOT_DIR" -c release --show-bin-path)"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/StandUpReminder" "$MACOS_DIR/StandUpReminder"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Resources/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"
cp "$ROOT_DIR/Resources/MenuBarIcon@2x.png" "$RESOURCES_DIR/MenuBarIcon@2x.png"

plutil -lint "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

SOURCE_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT_DIR/Resources/Info.plist")"
SOURCE_BUILD="$(plutil -extract CFBundleVersion raw -o - "$ROOT_DIR/Resources/Info.plist")"
BUNDLE_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$CONTENTS_DIR/Info.plist")"
BUNDLE_BUILD="$(plutil -extract CFBundleVersion raw -o - "$CONTENTS_DIR/Info.plist")"
FIRST_HIGHLIGHT="$(plutil -extract SURReleaseHighlights.0 raw -o - "$CONTENTS_DIR/Info.plist")"

if [[ "$SOURCE_VERSION" != "$BUNDLE_VERSION" || "$SOURCE_BUILD" != "$BUNDLE_BUILD" ]]; then
    echo "错误：源码与 App 包内版本不一致。" >&2
    exit 1
fi

if [[ -z "$FIRST_HIGHLIGHT" ]]; then
    echo "错误：App 包内缺少版本更新摘要。" >&2
    exit 1
fi

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "已生成：$APP_DIR"
echo "版本：${BUNDLE_VERSION}（Build ${BUNDLE_BUILD}）"
echo "建议将应用拖到 /Applications 后再开启“登录时自动启动”。"
