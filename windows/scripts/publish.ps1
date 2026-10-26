param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Solution = Join-Path $Root "windows\StandUpReminder.Windows.sln"
$Project = Join-Path $Root "windows\src\StandUpReminder.App\StandUpReminder.App.csproj"
$Output = Join-Path $Root "dist\$Runtime-single"

dotnet restore $Solution
dotnet test $Solution `
    --configuration Release `
    --no-restore `
    --blame-hang-timeout 60s
dotnet publish $Project `
    --configuration Release `
    --runtime $Runtime `
    --self-contained true `
    --output $Output `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=None `
    -p:PublishTrimmed=false

$Executable = Join-Path $Output "StandUpReminder.exe"
if (-not (Test-Path $Executable)) {
    throw "发布失败：未生成 $Executable"
}

Write-Host "已生成：$Executable"
Write-Host "版本：1.1.0（Build 2）"
