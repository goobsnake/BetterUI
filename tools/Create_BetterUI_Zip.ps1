<#
.SYNOPSIS
Creates a release zip for BetterUI using the version in BetterUI.txt.

.DESCRIPTION
Builds BetterUI-<version>.zip where <version> is read from:
    ## Version: x.yz
inside BetterUI.txt.

The zip contains a top-level BetterUI folder with addon-ready files and excludes
development-only files/directories matching Update_BetterUI.ps1.

.PARAMETER SourceDir
Repository root containing BetterUI.txt and addon files. Defaults to this script's
parent directory.

.PARAMETER OutputDir
Directory where the zip is written. Defaults to SourceDir.

.PARAMETER ManifestPath
Path to BetterUI.txt. Defaults to <SourceDir>/BetterUI.txt.

.EXAMPLE
.\Create_BetterUI_Zip.ps1

.EXAMPLE
pwsh ./tools/Create_BetterUI_Zip.ps1 -OutputDir ./dist
#>
param(
    [string]$SourceDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutputDir,
    [string]$ManifestPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $OutputDir) {
    $OutputDir = $SourceDir
}

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $SourceDir 'BetterUI.txt'
}

$excludeItems = @(
    '.agent_workspace',
    '.worktrees',
    '.git',
    '.gitignore',
    '.idea',
    '.images',
    '.vscode',
    '.venv',
    'tmp',
    'tools',
    'Source',
    'docs',
    'README.md',
    'LICENSE.md',
    '.luarc.json',
    '.package_tmp'
)

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "Source directory not found: $SourceDir"
}
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest file not found: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $OutputDir -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$versionMatch = Select-String -LiteralPath $ManifestPath -Pattern '^\s*##\s*Version\s*:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $versionMatch) {
    throw "Unable to find '## Version:' in manifest: $ManifestPath"
}

$version = $versionMatch.Matches[0].Groups[1].Value.Trim()
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "Version value is empty in manifest: $ManifestPath"
}

$safeVersion = $version -replace '[<>:\"/\\|?*]', '_'
$zipFileName = "BetterUI-$safeVersion.zip"
$zipPath = Join-Path $OutputDir $zipFileName
$stagingRoot = Join-Path $SourceDir '.package_tmp'
$stagingAddonDir = Join-Path $stagingRoot 'BetterUI'

if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
    Remove-Item -LiteralPath $zipPath -Force
}

if (Test-Path -LiteralPath $stagingRoot -PathType Container) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $stagingAddonDir -Force | Out-Null

try {
    Get-ChildItem -LiteralPath $SourceDir -Force |
    Where-Object {
        $_.Name -notin $excludeItems -and
        $_.Name -ne $zipFileName -and
        $_.Name -notmatch '^BetterUI-.*\.zip$'
    } |
    ForEach-Object {
        $destinationPath = Join-Path $stagingAddonDir $_.Name
        if ($_.PSIsContainer) {
            Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Recurse -Force
        }
        else {
            Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
        }
    }

    Compress-Archive -Path $stagingAddonDir -DestinationPath $zipPath -CompressionLevel Optimal
}
finally {
    if (Test-Path -LiteralPath $stagingRoot -PathType Container) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}

Write-Host "Package created successfully: $zipPath" -ForegroundColor Green
