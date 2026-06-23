<#
.SYNOPSIS
Deploys BetterUI addon files to the ESO PTS AddOns directory.

.DESCRIPTION
Copies the repository addon payload to the local ESO PTS addon folder and, when
available, the PTS BetterUI folder on the configured SMB share. Existing target
folders are replaced to avoid stale addon files.

Supports both Windows and Linux (Steam/Proton). Defaults are auto-detected based
on the operating system.

.PARAMETER SourceDir
Repository root to copy from. Defaults to this script's parent directory.

.PARAMETER DestinationDir
Target BetterUI folder under ESO PTS AddOns. Auto-detected per OS if omitted.

.PARAMETER NetworkShareDir
Target BetterUI folder on the network share. Defaults to
smb://goobers/elder%20scrolls%20online/pts/AddOns/BetterUI.
Skipped with a warning if the share cannot be mounted/accessed.

.EXAMPLE
.\Update_BetterUI_PTS.ps1

.EXAMPLE
.\Update_BetterUI_PTS.ps1 -SourceDir 'X:\Git\BetterUI'

.EXAMPLE
pwsh ./tools/Update_BetterUI_PTS.ps1   # Linux (Ubuntu 24.04 / Steam Proton)
#>
param(
    [string]$SourceDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$DestinationDir,
    [string]$NetworkShareDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $DestinationDir) {
    if ($IsLinux) {
        $DestinationDir = '/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/pts/AddOns/BetterUI'
    } else {
        $DestinationDir = Join-Path $env:USERPROFILE 'Documents/Elder Scrolls Online/pts/AddOns/BetterUI'
    }
}

if (-not $NetworkShareDir) {
    $NetworkShareDir = 'smb://goobers/elder%20scrolls%20online/pts/AddOns/BetterUI'
}

. (Join-Path $PSScriptRoot 'Update_BetterUI_Common.ps1')

Invoke-BetterUIDeploy `
    -SourceDir $SourceDir `
    -DestinationDir $DestinationDir `
    -NetworkShareDir $NetworkShareDir
