---
description: Pre-flight integrity check before committing - runs tests, scans for debug statements, and validates syntax
---

# Verify Integrity Workflow

Fast, reliable pre-commit checks with changed-file scope by default.

## Efficiency Defaults

- Determine changed files once; reuse that list for all checks.
- Run full test suite only when runtime addon paths changed.
- Validate only changed Lua/XML files, not entire directories.

## Stale-Context Guard (when needed)

If session context may be stale (resume/compaction/long gap), run AGENTS Session Compaction Recovery Tier 1 before checks.
Optional quick snapshot: `pwsh -File tools/context_health_check.ps1`.

## Step 0: Build Changed File Set

Prefer staged files; fall back to working-tree diff:

```powershell
$changedFiles = git diff --name-only --cached
if (-not $changedFiles) { $changedFiles = git diff --name-only HEAD }
$changedFiles
```

If empty, stop: there is nothing to verify.

If stale-risk is present and `$changedFiles` conflicts with continuity `Working set`, resolve the mismatch before running checks.
Prefer re-anchoring scope over writing continuity; do not edit `docs/CONTINUITY.md` solely to satisfy this verification step.

Use existing files only for file-content checks:

```powershell
$existingChangedFiles = $changedFiles | Where-Object { Test-Path -LiteralPath $_ }
```

## Step 1: Temporary Artifact Hygiene

Check for workflow artifacts and remove before commit if present:

```powershell
rg --files -g "critical_code_review.md" -g "sr_engineering_team_review.md" -g "implementation_plan.md"
```

## Step 2: Unit Tests (Runtime Changes Only)

Run tests when addon runtime paths changed:

```powershell
$runtimeChanged = $changedFiles | Where-Object { $_ -match "^(Modules/|lang/|BetterUI\\.lua$|BetterUI\\.txt$)" }
if ($runtimeChanged) { lua tools/tests/run_all_tests.lua }
```

If tests fail, stop and fix before commit.

## Step 3: Debug Statement Scan (Changed Lua Only)

```powershell
$luaFiles = $existingChangedFiles | Where-Object { $_ -like "*.lua" }
if ($luaFiles) { rg -n "d\\(\"|d\\('" -- $luaFiles }
```

Expected: no accidental debug output calls.

## Step 4: XML Validation (Changed XML Only)

```powershell
$xmlFiles = $existingChangedFiles | Where-Object { $_ -like "*.xml" }
if ($xmlFiles) {
    $xmlFiles | ForEach-Object {
        Write-Host "Validating $_"
        [xml](Get-Content -LiteralPath $_ -Raw) | Out-Null
    }
}
```

## Step 5: Lua Syntax Check (Changed Lua Only)

```powershell
if ($luaFiles) {
    $luaFiles | ForEach-Object {
        Write-Host "Checking $_"
        luac -p $_
    }
}
```

## Step 6: Summary

Report pass/fail for:

- Unit tests (or skipped with reason)
- Debug scan
- XML validation
- Lua syntax

## Invocation

```text
/verify-integrity
/verify-integrity --full
/verify-integrity --quick
```

Flag behavior:

- `--quick`: skip unit tests unless user explicitly asks
- `--full`: run unit tests regardless of path filtering
