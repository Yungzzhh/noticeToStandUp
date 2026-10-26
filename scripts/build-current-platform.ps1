$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

if ($IsWindows) {
    & (Join-Path $Root "windows\scripts\publish.ps1")
    exit $LASTEXITCODE
}

if ($IsMacOS) {
    & bash (Join-Path $Root "scripts/build-app.sh")
    exit $LASTEXITCODE
}

throw "当前系统不受支持；此仓库只提供 macOS 和 Windows 桌面应用。"
