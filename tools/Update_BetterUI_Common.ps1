Set-StrictMode -Version Latest

$BetterUIDeployExcludeItems = @(
    '.agent_workspace',
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

function Get-GvfsSmbMountRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GvfsDir,

        [Parameter(Mandatory = $true)]
        [string]$Server,

        [Parameter(Mandatory = $true)]
        [string]$ShareSegment,

        [Parameter(Mandatory = $true)]
        [string]$ShareName
    )

    $candidateRoots = @(
        "$GvfsDir/smb-share:server=$Server,share=$ShareName",
        "$GvfsDir/smb-share:server=$Server,share=$ShareSegment"
    ) | Select-Object -Unique

    foreach ($candidate in $candidateRoots) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return $candidate
        }
    }

    if (-not (Test-Path -LiteralPath $GvfsDir -PathType Container)) {
        return $null
    }

    return Get-ChildItem -LiteralPath $GvfsDir -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            if ($_.Name -notmatch '^smb-share:server=([^,]+),share=(.+)$') {
                return $false
            }

            $mountedServer = $Matches[1]
            $mountedShare = $Matches[2]
            $decodedMountedShare = [System.Uri]::UnescapeDataString($mountedShare)

            return ($mountedServer -ieq $Server) -and (
                ($mountedShare -ieq $ShareSegment) -or
                ($decodedMountedShare -ieq $ShareName)
            )
        } |
        Select-Object -ExpandProperty FullName -First 1
}

function Resolve-BetterUINetworkSharePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Path -notmatch '^smb://') {
        return $Path
    }

    $uri = [System.Uri]$Path
    $segments = @($uri.AbsolutePath.Trim('/') -split '/' | Where-Object { $_ })
    if ($segments.Count -lt 1) {
        throw "SMB URI must include a share name: $Path"
    }

    $shareSegment = $segments[0]
    $shareName = [System.Uri]::UnescapeDataString($shareSegment)
    $relativeSegments = @(
        $segments |
            Select-Object -Skip 1 |
            ForEach-Object { [System.Uri]::UnescapeDataString($_) }
    )

    if ($IsWindows) {
        return Join-PathSegments -Root "\\$($uri.Host)\$shareName" -Segments $relativeSegments
    }

    if ($IsLinux) {
        $uid = id -u
        $gvfsDir = "/run/user/$uid/gvfs"
        $gvfsRoot = Get-GvfsSmbMountRoot `
            -GvfsDir $gvfsDir `
            -Server $uri.Host `
            -ShareSegment $shareSegment `
            -ShareName $shareName

        if (-not $gvfsRoot) {
            $gio = Get-Command gio -ErrorAction SilentlyContinue
            if ($gio) {
                $shareUri = "smb://$($uri.Host)/$shareSegment"
                Write-Host "Mounting network share: $shareUri" -ForegroundColor Yellow
                & $gio.Source mount $shareUri | Out-Null
            }

            $gvfsRoot = Get-GvfsSmbMountRoot `
                -GvfsDir $gvfsDir `
                -Server $uri.Host `
                -ShareSegment $shareSegment `
                -ShareName $shareName
        }

        if (-not $gvfsRoot) {
            $gvfsRoot = "$gvfsDir/smb-share:server=$($uri.Host),share=$shareName"
        }

        return Join-PathSegments -Root $gvfsRoot -Segments $relativeSegments
    }

    return $Path
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

    if (Test-Path -LiteralPath $Target) {
        if ($IsLinux) {
            & rm -rf -- $Target
        } else {
            Remove-Item -LiteralPath $Target -Recurse -Force
        }
    }
    New-Item -ItemType Directory -Path $Target -Force | Out-Null

    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
    $items = Get-ChildItem -LiteralPath $SourceDir -Force -Recurse |
        Where-Object { -not (Test-BetterUIDeployExcludedPath -SourceRoot $sourceRoot -Path $_.FullName) } |
        Sort-Object { $_.FullName.Length }

    foreach ($item in $items) {
        $relativePath = [System.IO.Path]::GetRelativePath($sourceRoot, $item.FullName)
        $relativeSegments = @($relativePath -split '[\\/]') | Where-Object { $_ }
        $destinationPath = Join-PathSegments -Root $Target -Segments $relativeSegments

        if ($item.PSIsContainer) {
            New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
            continue
        }

        $destinationParent = Split-Path $destinationPath -Parent
        if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }

        if ($IsLinux) {
            # Copy-Item is unreliable on GVFS SMB mounts; use native cp per file.
            & cp -- $item.FullName $destinationPath
        } else {
            Copy-Item -LiteralPath $item.FullName -Destination $destinationPath -Force
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
