#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SYSTEM_NAME="$(uname -s)"

case "$SYSTEM_NAME" in
    Darwin)
        exec bash "$ROOT_DIR/scripts/build-app.sh"
        ;;
    Linux)
        echo "当前平台是 Linux；此仓库只提供 macOS 和 Windows 桌面应用。" >&2
        exit 1
        ;;
    MINGW*|MSYS*|CYGWIN*)
        if ! command -v pwsh >/dev/null 2>&1; then
            echo "未找到 PowerShell 7（pwsh），请在 Windows PowerShell 中运行 windows/scripts/publish.ps1。" >&2
            exit 1
        fi
        exec pwsh -File "$ROOT_DIR/windows/scripts/publish.ps1"
        ;;
    *)
        echo "不支持的平台：$SYSTEM_NAME" >&2
        exit 1
        ;;
esac
