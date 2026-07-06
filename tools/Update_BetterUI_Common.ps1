Set-StrictMode -Version Latest

# Windows PowerShell 5.1 predates the $IsWindows/$IsLinux/$IsMacOS automatic variables
# (PowerShell 6+). Define them so Set-StrictMode does not error when this runs under 5.1.
if (-not (Test-Path variable:IsWindows)) {
    $IsWindows = $true
    $IsLinux = $false
    $IsMacOS = $false
}

$BetterUIDeployExcludeItems = @(
    '.agent_workspace',
    '.claude',
    '.zff-mcp-backups',
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
    '.luacheckrc',
    '.package_tmp'
)

function Test-BetterUIDeployExcludedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $relativePath = [System.IO.Path]::GetRelativePath($SourceRoot, $Path)
    $segments = @($relativePath -split '[\\/]') | Where-Object { $_ }
    foreach ($segment in $segments) {
        if ($segment -in $BetterUIDeployExcludeItems) {
            return $true
        }
    }
    return $false
}

function Remove-BetterUIDeployPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    # Safety: never recursively delete a filesystem / drive root. Guards against a
    # mis-set -DestinationDir or -NetworkShareDir turning this into `rm -rf /`.
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.TrimEnd('/', '\') -eq $pathRoot.TrimEnd('/', '\')) {
        throw "Refusing to recursively delete a filesystem root: $Path"
    }

    if ($IsLinux) {
        # Kernel CIFS and local (ext4) mounts support recursive delete directly.
        # NOTE: never deploy over a GNOME "Connect to Server" / GVFS mount
        # (/run/user/<uid>/gvfs/smb-share:...). gvfsd-smb fails rmdir with EINVAL
        # ("Invalid argument"), so stale directories survive every deploy. Mount the
        # share with the kernel CIFS client instead.
        & rm -rf -- $Path
        if ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $Path)) {
            return
        }
    }

    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $Path) {
        throw "Failed to remove existing deploy target: $Path. A file may be locked (is ESO running?), or the share lacks delete permission."
    }
}

function New-BetterUIDeployDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Deploy directory path cannot be empty.'
    }

    if ($IsLinux) {
        & mkdir -p -- $Path
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create deploy directory: $Path"
        }
    } else {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Deploy directory missing after creation: $Path"
    }
}

function Join-PathSegments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [string[]]$Segments = @()
    )

    $path = $Root
    foreach ($segment in $Segments) {
        $path = Join-Path $path $segment
    }
    return $path
}

function Resolve-BetterUINetworkSharePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Already a local path or a mounted share (e.g. a kernel CIFS mountpoint such as
    # /mnt/eso/live/AddOns/BetterUI). Use as-is.
    if ($Path -notmatch '^smb://') {
        return $Path
    }

    # smb:// URLs are only translated on Windows, where UNC paths are handled natively
    # by the OS. On Linux we deliberately do NOT auto-mount via GVFS: gvfsd-smb cannot
    # delete directories (rmdir -> EINVAL) and leaves stale addon files behind. Mount
    # the share with the kernel CIFS client and pass the mountpoint instead.
    $uri = [System.Uri]$Path
    $segments = @($uri.AbsolutePath.Trim('/') -split '/' | Where-Object { $_ })
    if ($segments.Count -lt 1) {
        throw "SMB URI must include a share name: $Path"
    }

    $shareName = [System.Uri]::UnescapeDataString($segments[0])
    $relativeSegments = @(
        $segments |
            Select-Object -Skip 1 |
            ForEach-Object { [System.Uri]::UnescapeDataString($_) }
    )

    if ($IsWindows) {
        return Join-PathSegments -Root "\\$($uri.Host)\$shareName" -Segments $relativeSegments
    }

    throw @"
smb:// share paths are not supported on Linux: GNOME 'Connect to Server' uses the
GVFS userspace SMB backend, which fails to delete directories (EINVAL) and leaves
stale addon files behind. Mount the share with the kernel CIFS client and pass the
mountpoint instead, e.g. -NetworkShareDir '/mnt/eso/live/AddOns/BetterUI'.
The CIFS mount needs the 'noperm' option, or non-root writes are denied client-side.
"@
}

function Copy-BetterUIAddon {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        throw 'Target directory cannot be empty.'
    }

    # Replace the target wholesale so files deleted/renamed in the repo never linger.
    # A removal failure is fatal by design: it was previously swallowed and the files
    # overlaid, which silently let stale addon files accumulate.
    if (Test-Path -LiteralPath $Target) {
        Remove-BetterUIDeployPath -Path $Target
    }
    New-BetterUIDeployDirectory -Path $Target

    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
    $items = Get-ChildItem -LiteralPath $SourceDir -Force -Recurse |
        Where-Object { -not (Test-BetterUIDeployExcludedPath -SourceRoot $sourceRoot -Path $_.FullName) } |
        Sort-Object { $_.FullName.Length }

    foreach ($item in $items) {
        $relativePath = [System.IO.Path]::GetRelativePath($sourceRoot, $item.FullName)
        $relativeSegments = @($relativePath -split '[\\/]') | Where-Object { $_ }
        $destinationPath = Join-PathSegments -Root $Target -Segments $relativeSegments

        if ($item.PSIsContainer) {
            New-BetterUIDeployDirectory -Path $destinationPath
            continue
        }

        $destinationParent = Split-Path $destinationPath -Parent
        if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
            New-BetterUIDeployDirectory -Path $destinationParent
        }

        if ($IsLinux) {
            # Native cp is robust across CIFS and local (ext4) mounts.
            & cp -- $item.FullName $destinationPath
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to copy deploy file: $($item.FullName) -> $destinationPath"
            }
        } else {
            Copy-Item -LiteralPath $item.FullName -Destination $destinationPath -Force -ErrorAction Stop
        }

        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            throw "Deploy file missing after copy: $destinationPath"
        }
    }

    Write-Host "Files copied successfully to: $Target" -ForegroundColor Green
}

function Invoke-BetterUIDeploy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir,

        [string]$NetworkShareDir
    )

    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        throw "Source directory not found: $SourceDir"
    }

    Copy-BetterUIAddon -SourceDir $SourceDir -Target $DestinationDir

    if ([string]::IsNullOrWhiteSpace($NetworkShareDir)) {
        return
    }

    $resolvedNetworkShareDir = Resolve-BetterUINetworkSharePath -Path $NetworkShareDir
    $shareParent = Split-Path $resolvedNetworkShareDir -Parent
    if (Test-Path -LiteralPath $shareParent) {
        Copy-BetterUIAddon -SourceDir $SourceDir -Target $resolvedNetworkShareDir
    } else {
        Write-Warning "Network share not accessible (is it mounted?): $NetworkShareDir -> $resolvedNetworkShareDir"
    }
}
