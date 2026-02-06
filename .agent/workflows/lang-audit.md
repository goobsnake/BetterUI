---
description: Audit and sync language files - removes unused strings, syncs keys across all lang files, and identifies untranslated entries
---

# Language File Audit Workflow

This workflow audits the BetterUI localization system to maintain clean, synchronized language files.

## Prerequisites

See `AGENTS.md` for project context. Working directory: `x:\Git\BetterUI`

---

## Phase 1: Run Localization Audit

Run the master audit script to generate a comprehensive report:

// turbo
```powershell
cd x:\Git\BetterUI\tools && .\LocalizationAudit.ps1
```

**Review the output and `tools/audit_report.md` for:**
- Unused strings (defined in `en.lua` but never used in codebase)
- Missing strings (used in code but not defined in `en.lua`)
- Missing keys in foreign language files
- Potentially untranslated strings (exact English matches)

---

## Phase 2: Handle Unused Strings in en.lua

If the audit found unused strings:

1. **Review each unused string** in `lang/en.lua` to confirm it's no longer needed
2. **Remove confirmed dead strings** from `en.lua`
3. **Document removals** if significant strings are being deprecated

> [!WARNING]
> Some strings may be used dynamically or in settings panels. Verify before removing.

---

## Phase 3: Add Missing Strings to en.lua

If the audit found missing strings (used in code but not defined):

1. **Add each missing string** to `lang/en.lua` with appropriate English text
2. Use the naming convention: `SI_BETTERUI_<MODULE>_<DESCRIPTION>`

---

## Phase 4: Sync Foreign Language Files

Run the sync script to propagate en.lua changes to all other language files:

// turbo
```powershell
cd x:\Git\BetterUI\tools && .\fix_langs.ps1
```

**This will:**
- Add missing keys to foreign files (using English as placeholder with `-- TODO: Translate`)
- Remove orphaned keys that no longer exist in `en.lua`

---

## Phase 5: Review Untranslated Strings

The audit report lists strings that match English exactly (potential untranslated copy-pastes).

**For each language file with untranslated strings:**
1. The agent should NOT attempt to translate these automatically
2. Flag them in the report for human translators
3. Optional: Create a translation request document

---

## Phase 6: Verify Final State

Run the audit again to confirm all issues are resolved:

// turbo
```powershell
cd x:\Git\BetterUI\tools && .\LocalizationAudit.ps1
```

**Expected results:**
- 0 unused strings
- 0 missing strings
- All foreign files have matching keys with `en.lua`

---

## Phase 7: Commit Changes (if applicable)

```powershell
git add lang/ tools/audit_report.md tools/used_strings.txt
git commit -m "chore: audit and sync language files"
```

---

## Output Files

| File | Description |
|------|-------------|
| `tools/audit_report.md` | Detailed audit results |
| `tools/used_strings.txt` | Raw list of all used string keys |

---

## Quick Reference

| Task | Command |
|------|---------|
| Full audit | `.\LocalizationAudit.ps1` |
| Sync lang files | `.\fix_langs.ps1` |
| View report | `cat tools/audit_report.md` |
