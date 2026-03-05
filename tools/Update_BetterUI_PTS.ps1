<#
.SYNOPSIS
Deploys BetterUI addon files to the ESO PTS AddOns directory.

.DESCRIPTION
Copies the repository addon payload to the local ESO PTS addon folder after
removing the existing destination folder. Excludes development-only files and
directories (tools, docs, git metadata, agent config, etc).

.PARAMETER SourceDir
Repository root to copy from. Defaults to this script's parent directory.

.PARAMETER DestinationDir
Target BetterUI folder under ESO PTS AddOns.

.EXAMPLE
.\Update_BetterUI_PTS.ps1

.EXAMPLE
.\Update_BetterUI_PTS.ps1 -SourceDir 'X:\Git\BetterUI'
#>
param(
    [string]$SourceDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$DestinationDir = "$env:USERPROFILE\Documents\Elder Scrolls Online\pts\AddOns\BetterUI"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$excludeItems = @(
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
    '.luarc.json'
)

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "Source directory not found: $SourceDir"
}

# Replace the destination directory to avoid stale addon files.
if (Test-Path -LiteralPath $DestinationDir) {
    Remove-Item -LiteralPath $DestinationDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null

Get-ChildItem -LiteralPath $SourceDir -Force |
Where-Object { $_.Name -notin $excludeItems } |
ForEach-Object {
    $destinationPath = Join-Path $DestinationDir $_.Name
    if ($_.PSIsContainer) {
        Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
    }
}

Write-Host "Files copied successfully to: $DestinationDir" -ForegroundColor Green
