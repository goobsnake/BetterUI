<#
.SYNOPSIS
Host integration test for incremental Linux BetterUI deployment.

.DESCRIPTION
Runs against temporary local directories. It never touches the configured ESO paths.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolsRoot = Join-Path $PSScriptRoot '..'
. (Join-Path $toolsRoot 'Update_BetterUI_Common.ps1')

$passed = 0
$failed = 0

function Assert-DeployTest {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Condition) {
        $script:passed++
        Write-Host "  [OK] $Message"
    } else {
        $script:failed++
        Write-Host "  [X] $Message"
    }
}

function Set-TestFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $parent = Split-Path $Path -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Content -NoNewline
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("betterui rsync test " + [System.Guid]::NewGuid())
$source = Join-Path $tempRoot 'source'
$target = Join-Path $tempRoot 'AddOns/BetterUI'

try {
    foreach ($scriptPath in @(
        (Join-Path $toolsRoot 'Update_BetterUI_Common.ps1'),
        (Join-Path $toolsRoot 'Update_BetterUI.ps1'),
        (Join-Path $toolsRoot 'Update_BetterUI_PTS.ps1')
    )) {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath,
            [ref]$tokens,
            [ref]$parseErrors
        ) | Out-Null
        Assert-DeployTest -Condition ($parseErrors.Count -eq 0) `
            -Message "PowerShell parser accepts $(Split-Path $scriptPath -Leaf)"
    }

    if (-not $IsLinux) {
        Write-Host 'Linux rsync integration assertions skipped on this platform.'
        exit 0
    }

    New-Item -ItemType Directory -Path $source -Force | Out-Null
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    Set-TestFile -Path (Join-Path $source 'unchanged.txt') -Content 'same'
    Set-TestFile -Path (Join-Path $source 'changed.txt') -Content 'new-content-is-longer'
    Set-TestFile -Path (Join-Path $source 'Nested/new.txt') -Content 'new-file'
    Set-TestFile -Path (Join-Path $source 'tools/development-only.txt') -Content 'excluded'

    Set-TestFile -Path (Join-Path $target 'unchanged.txt') -Content 'same'
    Set-TestFile -Path (Join-Path $target 'changed.txt') -Content 'old-content'
    Set-TestFile -Path (Join-Path $target 'obsolete/removed.txt') -Content 'stale'
    Set-TestFile -Path (Join-Path $target 'tools/stale-development-file.txt') -Content 'stale-excluded'

    $fixedTimestamp = [DateTime]::SpecifyKind([DateTime]'2026-01-02T03:04:05', [DateTimeKind]::Utc)
    (Get-Item -LiteralPath (Join-Path $source 'unchanged.txt')).LastWriteTimeUtc = $fixedTimestamp
    (Get-Item -LiteralPath (Join-Path $target 'unchanged.txt')).LastWriteTimeUtc = $fixedTimestamp

    $overlapRejected = $false
    try {
        Copy-BetterUIAddon -SourceDir $source -Target (Join-Path $source 'nested-target') -DryRun
    } catch {
        $overlapRejected = $_.Exception.Message -like '*must not overlap*'
    }
    Assert-DeployTest -Condition $overlapRejected `
        -Message 'source and target directory trees cannot overlap'

    $rootRejected = $false
    try {
        Copy-BetterUIAddon -SourceDir $source -Target ([System.IO.Path]::GetPathRoot($source)) -DryRun
    } catch {
        $rootRejected = $_.Exception.Message -like '*filesystem root*'
    }
    Assert-DeployTest -Condition $rootRejected `
        -Message 'filesystem-root targets are rejected'

    $symlinkTarget = Join-Path $tempRoot 'symlink-target'
    New-Item -ItemType SymbolicLink -Path $symlinkTarget -Target $source | Out-Null
    $symlinkOverlapRejected = $false
    try {
        Copy-BetterUIAddon -SourceDir $source -Target $symlinkTarget -DryRun
    } catch {
        $symlinkOverlapRejected = $_.Exception.Message -like '*must not overlap*' -or
            $_.Exception.Message -like '*must be different*'
    }
    Assert-DeployTest -Condition $symlinkOverlapRejected `
        -Message 'symlink aliases cannot bypass source-target safety checks'

    $symlinkAncestor = Join-Path $tempRoot 'symlink-ancestor'
    New-Item -ItemType SymbolicLink -Path $symlinkAncestor -Target $source | Out-Null
    $symlinkAncestorRejected = $false
    try {
        Copy-BetterUIAddon -SourceDir $source -Target (Join-Path $symlinkAncestor 'missing-target') -DryRun
    } catch {
        $symlinkAncestorRejected = $_.Exception.Message -like '*symbolic-link*'
    }
    Assert-DeployTest -Condition $symlinkAncestorRejected `
        -Message 'symlink ancestors cannot bypass target safety checks'

    $relativeFixturePath = Get-BetterUIRelativePath `
        -Root $source `
        -Path (Join-Path $source 'Nested/new.txt')
    Assert-DeployTest -Condition (($relativeFixturePath -replace '\\', '/') -eq 'Nested/new.txt') `
        -Message 'PowerShell 5.1-compatible relative-path helper preserves nested paths'

    Copy-BetterUIAddon -SourceDir $source -Target $target -DryRun
    Assert-DeployTest -Condition ((Get-Content -LiteralPath (Join-Path $target 'changed.txt') -Raw) -eq 'old-content') `
        -Message 'dry run does not replace changed files'
    Assert-DeployTest -Condition (Test-Path -LiteralPath (Join-Path $target 'obsolete/removed.txt')) `
        -Message 'dry run does not remove stale files'
    Assert-DeployTest -Condition (Test-Path -LiteralPath (Join-Path $target 'tools/stale-development-file.txt')) `
        -Message 'dry run does not remove stale excluded paths'
    Assert-DeployTest -Condition (-not (Test-Path -LiteralPath (Join-Path $target 'Nested/new.txt'))) `
        -Message 'dry run does not create new files'

    Copy-BetterUIAddon -SourceDir $source -Target $target
    Assert-DeployTest -Condition ((Get-Content -LiteralPath (Join-Path $target 'changed.txt') -Raw) -eq 'new-content-is-longer') `
        -Message 'changed file is updated'
    Assert-DeployTest -Condition ((Get-Content -LiteralPath (Join-Path $target 'Nested/new.txt') -Raw) -eq 'new-file') `
        -Message 'new nested file and directory are created'
    Assert-DeployTest -Condition (-not (Test-Path -LiteralPath (Join-Path $target 'obsolete'))) `
        -Message 'destination directory absent from source is removed'
    Assert-DeployTest -Condition (-not (Test-Path -LiteralPath (Join-Path $target 'tools'))) `
        -Message 'excluded development directory is not deployed'
    Assert-DeployTest -Condition ((Get-Item -LiteralPath (Join-Path $target 'unchanged.txt')).LastWriteTimeUtc -eq $fixedTimestamp) `
        -Message 'unchanged file is not rewritten'

    $changedTimestamp = (Get-Item -LiteralPath (Join-Path $target 'changed.txt')).LastWriteTimeUtc
    Copy-BetterUIAddon -SourceDir $source -Target $target
    Assert-DeployTest -Condition ((Get-Item -LiteralPath (Join-Path $target 'changed.txt')).LastWriteTimeUtc -eq $changedTimestamp) `
        -Message 'second synchronization is a no-op for unchanged files'

} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n=== Test Summary ==="
Write-Host "Passed: $passed"
Write-Host "Failed: $failed"
if ($failed -gt 0) {
    throw "test_update_betterui_deploy.ps1 failed with $failed failure(s)"
}
