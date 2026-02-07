---
description: Find and remove dead code, orphaned files, deprecated usage, and unused references from the codebase
---

# Garbage Cleanup Workflow

Comprehensive dead code detection and cleanup workflow. Identifies unused files, orphaned code, deprecated usage, and unreferenced functions.

## Prerequisites

See `AGENTS.md` for project context, skills, and workflows.

---

## Scope Configuration

| Scope | Files Analyzed | Use When |
|-------|----------------|----------|
| `--core` | CIM module only (~50 files) | Focused cleanup of shared infrastructure |
| `--all` | All modules (~156 files) | Full codebase garbage collection |

**Default**: `--core` (safer, faster)

---

## Output Mode

| Mode | Action | Use When |
|------|--------|----------|
| (none) | Report only | Discovery, understanding scope |
| `--plan` | Create implementation plan | Ready to proceed with cleanup |

---

## Step 1: Discover Deprecated Usage Candidates

Create an initial candidate list by scanning for deprecation indicators:

```powershell
rg -n -i "deprecated|legacy|obsolete|to be removed|remove in" Modules
```

Then validate each candidate manually before classifying it as deprecated usage.

---

## Step 2: Scan for Dead Files

### 2.1 Find Unreferenced Lua Files

Identify Lua files not referenced in the manifest (`BetterUI.txt`):

```powershell
$manifest = Get-Content BetterUI.txt |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith(";") -and -not $_.StartsWith("##") }
Get-ChildItem -Recurse -Filter "*.lua" Modules | ForEach-Object {
    $relPath = $_.FullName.Replace((Resolve-Path .).Path + "\\", "").Replace("\", "/")
    if (-not ($manifest -contains $relPath)) { $relPath }
}
```

### 2.2 Find Orphaned XML Templates

Identify XML templates not referenced by any Lua file:

```powershell
Get-ChildItem -Recurse -Filter "*.xml" Modules/ | ForEach-Object { $template = $_.BaseName; if (-not (Get-ChildItem -Recurse -Filter "*.lua" Modules/ | Select-String -Pattern $template -Quiet)) { $_.FullName } }
```

### 2.3 Find Unused Image Assets

Identify .dds files not referenced anywhere:

```powershell
Get-ChildItem -Recurse -Filter "*.dds" Modules/ | ForEach-Object { $img = $_.BaseName; if (-not (Get-ChildItem -Recurse -Include "*.lua","*.xml" Modules/ | Select-String -Pattern $img -Quiet)) { $_.FullName } }
```

---

## Step 3: Scan for Dead Code

### 3.1 Unused Local Functions

Use `rg` to find local functions and verify they're called:

```powershell
rg -n --glob "*.lua" "^local function" Modules/CIM
```

For each local function found, verify it's referenced elsewhere in the same file.

### 3.2 Unused Global Functions

Find functions in the BETTERUI namespace that aren't called:

```powershell
rg -n --glob "*.lua" "^function BETTERUI\\." Modules
```

Cross-reference with usage across the codebase.

### 3.3 Deprecated API Usage

Search for usage of deprecated APIs from your candidate list:

```powershell
rg -n --glob "*.lua" "DEPRECATED_PATTERN" Modules
```

> [!NOTE]
> Replace `DEPRECATED_PATTERN` with verified symbols/names from Step 1.

---

## Step 4: Scan for Orphaned References

### 4.1 String Keys in Localization

Check for unused localization strings:

```powershell
pwsh -File tools/LanguageMaintenance.ps1 -Mode Audit
```

Review the audit report for unused strings.

### 4.2 Constants Never Used

Find constants defined but never referenced:

```powershell
rg -n "^CONST\\." Modules/CIM/Constants.lua
```

For each constant, verify it's used elsewhere.

---

## Step 5: Generate Findings Report

Create a structured report of all findings:

```markdown
# Garbage Cleanup Findings

**Date**: {YYYY-MM-DD}
**Scope**: [core / all]
**Files Analyzed**: {count}

## Summary

| Category | Items Found | Severity |
|----------|-------------|----------|
| Dead Files | X | HIGH |
| Dead Code | X | MEDIUM |
| Deprecated Usage | X | HIGH |
| Orphaned Strings | X | LOW |
| Unused Constants | X | LOW |

## Dead Files (Not in Manifest)

| File | Last Modified | Recommendation |
|------|---------------|----------------|
| `path/to/file.lua` | {date} | DELETE / MIGRATE |

## Dead Code (Unreferenced Functions)

| File | Function | Lines | Recommendation |
|------|----------|-------|----------------|
| `path/to/file.lua` | `functionName` | L100-150 | DELETE / REFACTOR |

## Deprecated API Usage

| Location | Deprecated API | Replacement |
|----------|----------------|-------------|
| `file.lua:L50` | `BETTERUI.OldAPI` | `BETTERUI.NewAPI` |

## Orphaned Resources

| Resource Type | Path | Recommendation |
|---------------|------|----------------|
| XML Template | `path/to/template.xml` | DELETE |
| Image Asset | `path/to/image.dds` | DELETE |
| Lang String | `SI_BETTERUI_OLD` | REMOVE |

## Risk Assessment

| Change | Risk Level | Mitigation |
|--------|------------|------------|
| Delete file X | LOW | Not referenced |
| Remove function Y | MEDIUM | Verify no dynamic calls |
| Update API Z | HIGH | Multiple callers |
```

---

## Step 6: Sr. Engineering Team Findings Review

Before creating an implementation plan, invoke the `/sr-review-gate` workflow:

```
Follow /sr-review-gate --plan-review
```

Present the findings report to the team. All 5 members must PASS before proceeding.

---

## Step 7: Create Implementation Plan (if `--plan` specified)

Only after Sr. Engineering Team approval, create `implementation_plan.md`:

```markdown
# Implementation Plan: Garbage Cleanup

## User Review Required

> [!WARNING]
> This plan deletes files and removes code. Review carefully.
> Consider creating a backup branch before proceeding.

## Phase 1: Safe Deletions (No Risk)

Files/code with zero references that are safe to remove.

### [DELETE] `Modules/SomeModule/filename.lua`
**Reason**: Not in manifest, not imported anywhere

---

## Phase 2: Deprecated Migrations (Low Risk)

Migrate deprecated API usage to current patterns.

### [MODIFY] `Modules/SomeModule/filename.lua`

**Change**: Replace deprecated `OldAPI` with `NewAPI`

```diff
- local result = BETTERUI.OldAPI()
+ local result = BETTERUI.NewAPI()
```

---

## Phase 3: Dead Code Removal (Medium Risk)

Unreferenced functions/constants that appear safe to remove.

> [!CAUTION]
> Verify no dynamic calls before removing.

### [MODIFY] `Modules/SomeModule/filename.lua`

**Remove**: Lines 100-150 (`unusedFunction`)

---

## Verification Plan

- [ ] All tests pass (`lua tools/tests/run_all_tests.lua`)
- [ ] Addon loads without errors
- [ ] No functionality regressions in affected modules
- [ ] Sr. Engineering Team final approval

## Rollback Plan

```powershell
git checkout HEAD~1 -- <affected files>
```
```

---

## Step 8: Plan Review Gate

Before executing the implementation plan:

```
Follow /sr-review-gate --plan-review
```

All 5 team members must PASS before proceeding to execution.

---

## Step 9: Execute With Phase Gates

After each phase completes:

```
Follow /sr-review-gate --phase-review
```

**Mandatory**: Every phase must be reviewed before proceeding to the next.
- Phase 1 complete → Phase review → Phase 2
- Phase 2 complete → Phase review → Phase 3
- Phase 3 complete → Final phase review → Commit

---

## Quick Invocation

### Report only (discovery):
```
/garbage-cleanup --core
/garbage-cleanup --all
```

### With implementation plan:
```
/garbage-cleanup --core --plan
/garbage-cleanup --all --plan
```

---

## Command Reference

| Command | Behavior |
|---------|----------|
| `/garbage-cleanup` | Core scope, report only |
| `/garbage-cleanup --all` | All modules, report only |
| `/garbage-cleanup --plan` | Core scope, with implementation plan |
| `/garbage-cleanup --all --plan` | Full cleanup with implementation plan |

---

## Workflow Steps Summary

1. **Discover**: Build deprecated usage candidates from code search
2. **Scan**: Find dead files, dead code, deprecated usage, orphaned resources
3. **Report**: Generate structured findings
4. **Review**: Sr. Engineering Team approval
5. **Plan** (if `--plan`): Create implementation plan
6. **Execute**: Implement approved changes
7. **Verify**: Run tests, check addon loads
8. **Commit**: `chore: remove dead code and deprecated items`

---

## Tips

1. **Start with `--core`** - CIM is most critical, clean it first
2. **Be conservative** - False positives are costly (removing used code)
3. **Check dynamic patterns** - Lua can call functions via string names
4. **Review metatable usage** - `__index` metamethods can hide references
5. **Keep candidate rules explicit** - Save validated deprecation patterns in your findings report

