---
description: Pre-flight integrity check before committing - runs tests, scans for debug statements, and validates syntax
---

# Verify Integrity Workflow

A one-stop pre-commit verification that ensures code quality before pushing changes.

## Prerequisites

See `AGENTS.md` for project context and `docs/CONTINUITY.md` for session state.

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
git diff --name-only HEAD | Where-Object { $_ -like "*.xml" }
```

If any XML files appear, validate them:

```powershell
git diff --name-only HEAD | Where-Object { $_ -like "*.xml" } | ForEach-Object { Write-Host "Validating $_"; [xml](Get-Content $_) } 2>&1 | Select-String -Pattern "Exception"
```

**Expected**: No parsing exceptions. If validation fails, fix the XML before proceeding.

---

## Step 4: Lua Syntax Check (Required if Lua Modified)

> [!IMPORTANT]
> This step is **REQUIRED** if any Lua files were modified. Do not skip.

Check if Lua files were modified:

```powershell
git diff --name-only HEAD | Where-Object { $_ -like "*.lua" }
```

If any Lua files appear, validate their syntax:

```powershell
git diff --name-only HEAD | Where-Object { $_ -like "*.lua" } | ForEach-Object { Write-Host "Checking $_"; luac5.1 -p $_ }
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

