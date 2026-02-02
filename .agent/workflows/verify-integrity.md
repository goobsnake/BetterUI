---
description: Pre-flight integrity check before committing - runs tests, scans for debug statements, and validates syntax
---

# Verify Integrity Workflow

A one-stop pre-commit verification that ensures code quality before pushing changes.

// turbo-all

## Prerequisites
- Read `betterui-development-guidelines` skill

---

## Step 1: Run Test Suite

Execute the Lua unit tests to verify core functionality:

```powershell
cd x:\Git\BetterUI && lua tools/tests/run_all_tests.lua
```

**Expected**: All tests pass. If any fail, stop and investigate before proceeding.

---

## Step 2: Scan for Debug Statements

Search for leftover debug calls that should not be committed:

```powershell
cd x:\Git\BetterUI && grep -rn --include="*.lua" "d(\"" Modules/ | grep -v "-- DEBUG" | grep -v "if.*debug"
```

**What to look for**:
- `d("...")` - BetterUI debug output
- `zo_callLater(function() d(` - Delayed debug output

**Expected**: No results, or only intentional debug statements with `-- DEBUG` comments.

> [!WARNING]
> If you find unexpected debug statements, remove them before committing.

---

## Step 3: (Optional) XML Validation

If XML files were modified, validate them:

```powershell
cd x:\Git\BetterUI && Get-ChildItem -Recurse -Filter "*.xml" Modules/ | ForEach-Object { [xml](Get-Content $_.FullName) } 2>&1 | Select-String -Pattern "Exception"
```

**Expected**: No parsing exceptions.

---

## Step 4: Syntax Check Modified Files

For each modified Lua file (from `git status`), validate syntax:

```powershell
cd x:\Git\BetterUI && git diff --name-only HEAD | Where-Object { $_ -like "*.lua" } | ForEach-Object { Write-Host "Checking $_"; luac5.1 -p $_ }
```

> [!NOTE]
> If `luac5.1` is not available, skip this step. The test suite (Step 1) implicitly validates syntax.

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

