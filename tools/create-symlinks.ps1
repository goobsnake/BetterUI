<#
.SYNOPSIS
Creates repository symlinks for Claude command mirrors.

.DESCRIPTION
This script replaces `.claude/commands/*.md` with symlinks to `.agent/workflows/*.md`.
Optionally, it also links `CLAUDE.md` to `AGENTS.md`.

Run from repo root (recommended):
  .\tools\create-symlinks.ps1
  .\tools\create-symlinks.ps1 -LinkClaudeDoc

Prerequisites:
- Windows symlink permissions (Developer Mode enabled, or elevated shell)
- Git configured for symlinks when committing (`git config core.symlinks true`)
#>

param(
    # When set, also create `CLAUDE.md -> AGENTS.md`.
    [switch]$LinkClaudeDoc
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$claudeCommandsDir = Join-Path $repoRoot ".claude/commands"
$workflowsDir = Join-Path $repoRoot ".agent/workflows"

$commandMap = @{
    "verify-integrity.md"        = "verify-integrity.md"
    "sr-review-gate.md"          = "sr-review-gate.md"
    "update-tribal-knowledge.md" = "update-tribal-knowledge.md"
    "update-changelog.md"        = "update-changelog.md"
    "code-review.md"             = "code-review.md"
    "wrap-up.md"                 = "wrap-up.md"
    "garbage-cleanup.md"         = "garbage-cleanup.md"
    "lang-audit.md"              = "lang-audit.md"
    "review-todos.md"            = "review-todos.md"
    "scaffold-module.md"         = "scaffold-module.md"
    "feature-requests.md"        = "feature-requests.md"
}

function Test-SymbolicLinkSupport {
    param(
        [string]$BaseDir
    )

    # Preflight guard: prove symlink creation works before modifying real files.
    $tempTarget = Join-Path $BaseDir "__symlink_test_target.tmp"
    $tempLink = Join-Path $BaseDir "__symlink_test_link.tmp"

    try {
        Set-Content -LiteralPath $tempTarget -Value "symlink-test" -NoNewline
        New-Item -ItemType SymbolicLink -Path $tempLink -Target "__symlink_test_target.tmp" | Out-Null
    }
    catch {
        throw "Symbolic links are not permitted in this shell/session. Enable Windows Developer Mode or run an elevated shell."
    }
    finally {
        if (Test-Path -LiteralPath $tempLink) {
            Remove-Item -LiteralPath $tempLink -Force
        }
        if (Test-Path -LiteralPath $tempTarget) {
            Remove-Item -LiteralPath $tempTarget -Force
        }
    }
}

function New-SymlinkFile {
    param(
        [string]$LinkPath,
        [string]$TargetPath
    )

    # Replace existing file/link to keep the operation idempotent.
    if (Test-Path -LiteralPath $LinkPath) {
        Remove-Item -LiteralPath $LinkPath -Force
    }

    # Use a relative target so links remain valid if repo root path changes.
    $relativeTarget = [System.IO.Path]::GetRelativePath((Split-Path -Parent $LinkPath), $TargetPath)
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $relativeTarget | Out-Null
}

Test-SymbolicLinkSupport -BaseDir $claudeCommandsDir

foreach ($commandFile in $commandMap.Keys) {
    $workflowFile = $commandMap[$commandFile]
    $linkPath = Join-Path $claudeCommandsDir $commandFile
    $targetPath = Join-Path $workflowsDir $workflowFile

    if (-not (Test-Path -LiteralPath $targetPath)) {
        throw "Target workflow not found: $targetPath"
    }

    # Example: `.claude/commands/code-review.md` -> `.agent/workflows/comprehensive-code-review.md`
    New-SymlinkFile -LinkPath $linkPath -TargetPath $targetPath
    Write-Host "[OK] $commandFile -> $workflowFile (SymbolicLink)"
}

if ($LinkClaudeDoc.IsPresent) {
    $claudeDoc = Join-Path $repoRoot "CLAUDE.md"
    $agentsDoc = Join-Path $repoRoot "AGENTS.md"

    if (-not (Test-Path -LiteralPath $agentsDoc)) {
        throw "AGENTS.md not found: $agentsDoc"
    }

    New-SymlinkFile -LinkPath $claudeDoc -TargetPath $agentsDoc
    Write-Host "[OK] CLAUDE.md -> AGENTS.md (SymbolicLink)"
}

Write-Host "Done."
