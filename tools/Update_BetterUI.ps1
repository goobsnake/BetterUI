<#
.SYNOPSIS
Deploys BetterUI addon files to the ESO Live AddOns directory.

.DESCRIPTION
Copies the repository addon payload to the local ESO Live addon folder after
removing the existing destination folder. Excludes development-only files and
directories (tools, docs, git metadata, agent config, etc).

Supports both Windows and Linux (Steam/Proton). The default destination is
auto-detected based on the operating system.

.PARAMETER SourceDir
Repository root to copy from. Defaults to this script's parent directory.

.PARAMETER DestinationDir
Target BetterUI folder under ESO Live AddOns. Auto-detected per OS if omitted.

.PARAMETER NetworkShareDir
Target BetterUI folder on the network share. Defaults to
smb://10.133.10.10/addons/BetterUI (GVFS path on Linux, UNC on Windows).
Skipped with a warning if the share is not mounted/accessible.

.EXAMPLE
.\Update_BetterUI.ps1

.EXAMPLE
.\Update_BetterUI.ps1 -SourceDir 'X:\Git\BetterUI'

.EXAMPLE
pwsh ./tools/Update_BetterUI.ps1   # Linux (Ubuntu 24.04 / Steam Proton)
#>
param(
    [string]$SourceDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$DestinationDir,
    [string]$NetworkShareDir
)

if (-not $DestinationDir) {
    if ($IsLinux) {
        $DestinationDir = Join-Path $HOME '.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns/BetterUI'
    } else {
        $DestinationDir = Join-Path $env:USERPROFILE 'Documents/Elder Scrolls Online/live/AddOns/BetterUI'
    }
}

if (-not $NetworkShareDir) {
    if ($IsLinux) {
        $uid = id -u
        $NetworkShareDir = "/run/user/$uid/gvfs/smb-share:server=10.133.10.10,share=addons/BetterUI"
    } else {
        $NetworkShareDir = '\\10.133.10.10\addons\BetterUI'
    }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$excludeItems = @(
    '.agent_workspace',
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
    '.luacheckrc'
)

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "Source directory not found: $SourceDir"
}

function Deploy-Addon {
    param([string]$Target)

    if (Test-Path -LiteralPath $Target) {
        if ($IsLinux) {
            & rm -rf -- $Target
        } else {
            Remove-Item -LiteralPath $Target -Recurse -Force
        }
    }
    New-Item -ItemType Directory -Path $Target -Force | Out-Null

    $items = Get-ChildItem -LiteralPath $SourceDir -Force |
        Where-Object { $_.Name -notin $excludeItems }

    if ($IsLinux) {
        # Copy-Item is unreliable on GVFS SMB mounts; use native cp instead.
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                & cp -r -- $item.FullName $Target
            } else {
                & cp -- $item.FullName $Target
            }
        }
    } else {
        foreach ($item in $items) {
            $destinationPath = Join-Path $Target $item.Name
            if ($item.PSIsContainer) {
                Copy-Item -LiteralPath $item.FullName -Destination $destinationPath -Recurse -Force
            } else {
                Copy-Item -LiteralPath $item.FullName -Destination $destinationPath -Force
            }
        }
    }

    Write-Host "Files copied successfully to: $Target" -ForegroundColor Green
}

# Deploy to local ESO AddOns directory.
Deploy-Addon -Target $DestinationDir

# Deploy to network share.
$shareParent = Split-Path $NetworkShareDir -Parent
if (Test-Path -LiteralPath $shareParent) {
    Deploy-Addon -Target $NetworkShareDir
} else {
    Write-Warning "Network share not accessible (is it mounted?): $shareParent"
}
