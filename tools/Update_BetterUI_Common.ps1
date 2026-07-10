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

function Get-BetterUIRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # System.IO.Path.GetRelativePath is unavailable in Windows PowerShell 5.1.
    # Deploy traversal only accepts descendants, so a validated prefix trim is enough.
    $rootFullPath = [System.IO.Path]::GetFullPath($Root)
    $pathFullPath = [System.IO.Path]::GetFullPath($Path)
    $rootComparable = $rootFullPath.TrimEnd('/', '\')
    $separator = [string][System.IO.Path]::DirectorySeparatorChar
    $rootPrefix = if ([string]::IsNullOrEmpty($rootComparable)) {
        [System.IO.Path]::GetPathRoot($rootFullPath)
    } else {
        $rootComparable + $separator
    }
    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }

    if (-not $pathFullPath.StartsWith($rootPrefix, $comparison)) {
        throw "Deploy path is outside the source root: $Path"
    }

    return $pathFullPath.Substring($rootPrefix.Length)
}

function Test-BetterUIDeployExcludedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $relativePath = Get-BetterUIRelativePath -Root $SourceRoot -Path $Path
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
    # mis-set -DestinationDir or -NetworkShareDir erasing an entire volume.
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.TrimEnd('/', '\') -eq $pathRoot.TrimEnd('/', '\')) {
        throw "Refusing to recursively delete a filesystem root: $Path"
    }

    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $Path) {
        throw "Failed to remove existing deploy target: $Path. A file may be locked (is ESO running?), or the share lacks delete permission."
    }
}

function Assert-BetterUIDeployTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        throw 'Target directory cannot be empty.'
    }

    $targetCandidate = [System.IO.Path]::GetFullPath($Target)
    $targetCandidateRoot = [System.IO.Path]::GetPathRoot($targetCandidate)
    $currentCandidate = $targetCandidateRoot
    $candidateSegments = @(
        $targetCandidate.Substring($targetCandidateRoot.Length) -split '[\\/]' |
            Where-Object { $_ }
    )
    foreach ($segment in $candidateSegments) {
        $currentCandidate = Join-Path $currentCandidate $segment
        if (-not (Test-Path -LiteralPath $currentCandidate)) {
            break
        }
        $candidateItem = Get-Item -LiteralPath $currentCandidate -Force
        if (($candidateItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Source and target directory trees must not overlap through symbolic-link targets: $Target"
        }
    }

    $sourceFullPath = (Resolve-Path -LiteralPath $SourceDir).Path
    $targetFullPath = if (Test-Path -LiteralPath $Target) {
        $targetItem = Get-Item -LiteralPath $Target -Force
        $targetItem.FullName
    } else {
        [System.IO.Path]::GetFullPath($Target)
    }
    $targetRoot = [System.IO.Path]::GetPathRoot($targetFullPath)
    $sourceComparable = $sourceFullPath.TrimEnd('/', '\')
    $targetComparable = $targetFullPath.TrimEnd('/', '\')
    $targetRootComparable = $targetRoot.TrimEnd('/', '\')

    if ($targetComparable -eq $targetRootComparable) {
        throw "Refusing to synchronize a filesystem root: $Target"
    }

    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    if ([string]::Equals($sourceComparable, $targetComparable, $comparison)) {
        throw "Source and target directories must be different: $SourceDir"
    }

    $separator = [string][System.IO.Path]::DirectorySeparatorChar
    $sourcePrefix = $sourceComparable + $separator
    $targetPrefix = $targetComparable + $separator
    if ($targetComparable.StartsWith($sourcePrefix, $comparison) -or
        $sourceComparable.StartsWith($targetPrefix, $comparison)) {
        throw "Source and target directory trees must not overlap: $SourceDir -> $Target"
    }

    return $targetComparable
}

function Invoke-BetterUIRsync {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$Target,

        [switch]$DryRun
    )

    $rsync = Get-Command rsync -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $rsync) {
        throw "rsync is required for Linux BetterUI deployment. Install rsync and retry."
    }

    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('/', '\')
    $targetRoot = Assert-BetterUIDeployTarget -SourceDir $sourceRoot -Target $Target
    $rsyncArgs = @(
        '-rlt',
        '--delete',
        '--delete-delay',
        '--delete-excluded',
        '--delay-updates',
        '--omit-dir-times',
        '--modify-window=1',
        '--itemize-changes',
        '--human-readable'
    )

    foreach ($excludedItem in $BetterUIDeployExcludeItems) {
        $rsyncArgs += "--exclude=$excludedItem"
    }
    if ($DryRun) {
        $rsyncArgs += '--dry-run'
    }

    # Trailing separators synchronize directory contents instead of nesting the
    # repository and target directories. Array splatting preserves spaces literally.
    $rsyncArgs += '--'
    $rsyncArgs += "$sourceRoot/"
    $rsyncArgs += "$targetRoot/"

    & $rsync.Source @rsyncArgs
    $rsyncExitCode = $LASTEXITCODE
    if ($rsyncExitCode -ne 0) {
        throw "rsync deployment failed with exit code ${rsyncExitCode}: $sourceRoot -> $targetRoot"
    }

    if ($DryRun) {
        Write-Host "Dry run completed for: $targetRoot" -ForegroundColor Yellow
    } else {
        Write-Host "Files synchronized successfully to: $targetRoot" -ForegroundColor Green
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

    New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null

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
        [string]$Target,

        [switch]$DryRun
    )

    $targetRoot = Assert-BetterUIDeployTarget -SourceDir $SourceDir -Target $Target

    if ($IsLinux) {
        Invoke-BetterUIRsync -SourceDir $SourceDir -Target $targetRoot -DryRun:$DryRun
        return
    }

    if ($DryRun) {
        Write-Host "Dry run: Windows deployment would replace $targetRoot" -ForegroundColor Yellow
        return
    }

    # Windows retains the existing replace behavior because rsync is not a standard
    # PowerShell dependency there. Linux uses the incremental mirror above.
    if (Test-Path -LiteralPath $targetRoot) {
        Remove-BetterUIDeployPath -Path $targetRoot
    }
    New-BetterUIDeployDirectory -Path $targetRoot

    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
    $items = Get-ChildItem -LiteralPath $SourceDir -Force -Recurse |
        Where-Object { -not (Test-BetterUIDeployExcludedPath -SourceRoot $sourceRoot -Path $_.FullName) } |
        Sort-Object { $_.FullName.Length }

    foreach ($item in $items) {
        $relativePath = Get-BetterUIRelativePath -Root $sourceRoot -Path $item.FullName
        $relativeSegments = @($relativePath -split '[\\/]') | Where-Object { $_ }
        $destinationPath = Join-PathSegments -Root $targetRoot -Segments $relativeSegments

        if ($item.PSIsContainer) {
            New-BetterUIDeployDirectory -Path $destinationPath
            continue
        }

        $destinationParent = Split-Path $destinationPath -Parent
        if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
            New-BetterUIDeployDirectory -Path $destinationParent
        }

        Copy-Item -LiteralPath $item.FullName -Destination $destinationPath -Force -ErrorAction Stop

        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            throw "Deploy file missing after copy: $destinationPath"
        }
    }

    Write-Host "Files copied successfully to: $targetRoot" -ForegroundColor Green
}

function Invoke-BetterUIDeploy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir,

        [string]$NetworkShareDir,

        [switch]$DryRun
    )

    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        throw "Source directory not found: $SourceDir"
    }

    Copy-BetterUIAddon -SourceDir $SourceDir -Target $DestinationDir -DryRun:$DryRun

    if ([string]::IsNullOrWhiteSpace($NetworkShareDir)) {
        return
    }

    $resolvedNetworkShareDir = Resolve-BetterUINetworkSharePath -Path $NetworkShareDir
    $shareParent = Split-Path $resolvedNetworkShareDir -Parent
    if (Test-Path -LiteralPath $shareParent) {
        Copy-BetterUIAddon -SourceDir $SourceDir -Target $resolvedNetworkShareDir -DryRun:$DryRun
    } else {
        Write-Warning "Network share not accessible (is it mounted?): $NetworkShareDir -> $resolvedNetworkShareDir"
    }
}
