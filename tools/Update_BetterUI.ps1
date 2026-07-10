<#
.SYNOPSIS
Deploys BetterUI addon files to the ESO Live AddOns directory.

.DESCRIPTION
Synchronizes the repository addon payload to the local ESO Live addon folder and,
when available, the Live BetterUI folder on the configured SMB share. Linux uses
rsync to transfer only changes and remove destination paths absent from the source.

Supports both Windows and Linux (Steam/Proton). Defaults are auto-detected based
on the operating system.

.PARAMETER SourceDir
Repository root to copy from. Defaults to this script's parent directory.

.PARAMETER DestinationDir
Target BetterUI folder under ESO Live AddOns. Auto-detected per OS if omitted.

.PARAMETER NetworkShareDir
Target BetterUI folder on the network share. On Linux this must be an already-mounted
path (kernel CIFS mountpoint), defaulting to /mnt/eso/live/AddOns/BetterUI; on Windows
it defaults to smb://goobers/elder%20scrolls%20online/live/AddOns/BetterUI (resolved to
a native UNC path). Skipped with a warning if the share is not mounted/accessible.

.PARAMETER DryRun
Shows the Linux rsync changes without modifying either deployment target.

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
    [string]$NetworkShareDir,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load shared helpers first: it defines the $IsLinux/$IsWindows fallbacks the default
# blocks below rely on when running under Windows PowerShell 5.1.
. (Join-Path $PSScriptRoot 'Update_BetterUI_Common.ps1')

if (-not $DestinationDir) {
    if ($IsLinux) {
        $DestinationDir = '/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns/BetterUI'
    } else {
        $DestinationDir = Join-Path $env:USERPROFILE 'Documents/Elder Scrolls Online/live/AddOns/BetterUI'
    }
}

if (-not $NetworkShareDir) {
    if ($IsLinux) {
        # Kernel CIFS mountpoint (mount -t cifs with the noperm option). Do NOT point this at an
        # smb:// path or a GNOME/GVFS mount on Linux: GVFS cannot delete directories and
        # leaves stale addon files behind.
        $NetworkShareDir = '/mnt/eso/live/AddOns/BetterUI'
    } else {
        $NetworkShareDir = 'smb://goobers/elder%20scrolls%20online/live/AddOns/BetterUI'
    }
}

Invoke-BetterUIDeploy `
    -SourceDir $SourceDir `
    -DestinationDir $DestinationDir `
    -NetworkShareDir $NetworkShareDir `
    -DryRun:$DryRun
