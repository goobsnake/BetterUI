---
description: Audit and sync language files - removes unused strings, syncs keys across all lang files, and identifies untranslated entries
---

# Language File Audit Workflow

This workflow audits the BetterUI localization system to maintain clean, synchronized language files.

## Prerequisites

See `AGENTS.md` for project context and `docs/CONTINUITY.md` for session state.

---

## Phase 1: Run Localization Audit

Run the master audit script to generate a comprehensive report:

```powershell
pwsh -File tools/LanguageMaintenance.ps1 -Mode Audit
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

```powershell
pwsh -File tools/LanguageMaintenance.ps1 -Mode Sync
```

**This will:**
- Add/remove keys to align locale file structure with `en.lua`
- Remove orphaned keys that no longer exist in `en.lua`

> [!IMPORTANT]
> Do not leave English placeholder values in non-English locale files. Before completing this workflow, every added key in each locale file must have a translated value.

---

## Phase 5: Resolve Untranslated Strings

The audit report lists strings that match English exactly (potential untranslated copy-pastes).

**For each language file with untranslated strings:**
1. Provide a translated string value in that locale file in the same change set
2. If a translation is unavailable, stop and escalate to the user instead of merging placeholder text
3. Keep untranslated entries at zero before completion

---

## Phase 6: Verify Final State

Run the audit again to confirm all issues are resolved:

```powershell
pwsh -File tools/LanguageMaintenance.ps1 -Mode Audit
```

**Expected results:**
- 0 unused strings
- 0 missing strings
- All foreign files have matching keys with `en.lua`
- 0 untranslated copy-pasted English entries in non-English locale files

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
| Full audit | `pwsh -File tools/LanguageMaintenance.ps1 -Mode Audit` |
| Sync lang files | `pwsh -File tools/LanguageMaintenance.ps1 -Mode Sync` |
| Sync + audit (recommended) | `pwsh -File tools/LanguageMaintenance.ps1 -Mode SyncAndAudit` |
| View report | `cat tools/audit_report.md` |
