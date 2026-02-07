---
description: Pre-flight integrity check before committing - runs tests, scans for debug statements, and validates syntax
---

# Verify Integrity Workflow

A one-stop pre-commit verification that ensures code quality before pushing changes.

## Prerequisites

See `AGENTS.md` for project context and `docs/CONTINUITY.md` for session state.

---

## Pre-Step: Restore Session Context (Required on resume/compaction)

If context may be stale due to a long or resumed session:

1. Execute `AGENTS.md` → **Session Compaction Recovery (Required)** using its tiered sequence.
2. Apply `AGENTS.md` → **Quota Efficiency Defaults** (smallest sufficient scope, targeted reads, reuse artifacts).
3. Confirm there are no unresolved prior review/integrity findings before running checks.

---

## Step 0: Remove Temporary Review Artifacts

Before committing, ensure canonical workflow artifacts are not tracked:

```powershell
rg --files -g "critical_code_review.md" -g "sr_engineering_team_review.md" -g "implementation_plan.md"
```

**Expected**: No results. If any appear, delete them before proceeding.

---

## Step 1: Run Test Suite

Execute the Lua unit tests to verify core functionality:

```powershell
lua tools/tests/run_all_tests.lua
```

**Expected**: All tests pass. If any fail, stop and investigate before proceeding.

---

## Step 2: Scan for Debug Statements

Search for leftover debug calls that should not be committed:

```powershell
rg -n --glob "*.lua" "d\\(\"" Modules | rg -v -- "-- DEBUG|if.*debug"
```

**What to look for**:
- `d("...")` - BetterUI debug output
- `zo_callLater(function() d(` - Delayed debug output

**Expected**: No results, or only intentional debug statements with `-- DEBUG` comments.

> [!WARNING]
> If you find unexpected debug statements, remove them before committing.

---

## Step 3: XML Validation (Required if XML Modified)

> [!IMPORTANT]
> This step is **REQUIRED** if any XML files were modified. Do not skip.

Check if XML files were modified:

```powershell
$changedFiles = git diff --name-only HEAD
$xmlFiles = $changedFiles | Where-Object { $_ -like "*.xml" }
$xmlFiles
```

If any XML files appear, validate them:

```powershell
$xmlFiles | ForEach-Object { Write-Host "Validating $_"; [xml](Get-Content $_) } 2>&1 | Select-String -Pattern "Exception"
```

**Expected**: No parsing exceptions. If validation fails, fix the XML before proceeding.

---

## Step 4: Lua Syntax Check (Required if Lua Modified)

> [!IMPORTANT]
> This step is **REQUIRED** if any Lua files were modified. Do not skip.

Check if Lua files were modified:

```powershell
$changedFiles = if ($changedFiles) { $changedFiles } else { git diff --name-only HEAD }
$luaFiles = $changedFiles | Where-Object { $_ -like "*.lua" }
$luaFiles
```

If any Lua files appear, validate their syntax:

```powershell
$luaFiles | ForEach-Object { Write-Host "Checking $_"; luac -p $_ }
```

**Expected**: No syntax errors. If validation fails, fix the Lua before proceeding.

---

## Step 5: Summary

After all checks pass:

| Check | Status |
|-------|--------|
| Unit Tests | ✓ PASS |
| Debug Scan | ✓ CLEAN |
| XML Validation | ✓ VALID (or N/A) |
| Syntax Check | ✓ PASS |

**Ready to commit!**

---

## Quick Invocation

```
/verify-integrity
```

Or before any commit:
> "Run a quick integrity check before I commit"

---

## Flags

| Flag | Behavior |
|------|----------|
| `--quick` | Skip XML validation and syntax check (Steps 3-4) |
| `--full` | Include all checks (default) |
