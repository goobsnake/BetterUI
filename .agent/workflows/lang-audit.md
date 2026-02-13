---
description: Audit and sync language files - removes unused strings, syncs keys across all lang files, and identifies untranslated entries
---

# Language File Audit Workflow

Audit localization with changed-file fast path first, full sweep second.

## Defaults

- Default mode is `--changed-only`.
- Do not touch locale files outside the impacted key set unless `--full` is requested.
- Never ship English placeholders in non-English locales.

## Modes

| Mode | Use When | Default |
|------|----------|---------|
| `--changed-only` | Normal feature work touching a subset of locale keys | Yes |
| `--full` | Release prep or broad localization refactor | No |

## Stop Conditions

- No locale files changed and `--full` is not requested.
- Required translations are unavailable for new keys (escalate instead of placeholder fallback).

## Step 0: Detect Scope

If session state may be stale (resume/compaction/long gap), run AGENTS Session Compaction Recovery Tier 1 first.

```powershell
$changedFiles = git diff --name-only HEAD
$langChanged = $changedFiles | Where-Object { $_ -like "lang/*.lua" }
```

If no locale files changed and `--full` not requested, stop with `N/A`.

## Step 1: Run Audit

```powershell
pwsh -File tools/LanguageMaintenance.ps1 -Mode Audit
```

Review `tools/audit_report.md` for:

- Missing keys
- Key parity issues across locale files
- Untranslated copy-paste risks

## Step 2: Update Locale Files

1. Add missing keys to `lang/en.lua`.
2. Sync locale key sets:

```powershell
pwsh -File tools/LanguageMaintenance.ps1 -Mode Sync
```

3. Provide translated values for every new key in non-English locales in the same change set.
4. If translation is unavailable, stop and escalate to the user (no English placeholders).

## Step 3: Re-Audit

```powershell
pwsh -File tools/LanguageMaintenance.ps1 -Mode Audit
```

Expected: no missing keys and no unintended untranslated additions.

## Step 4: Commit (if applicable)

```powershell
git add lang/
git commit -m "chore(lang): sync locale keys and translations"
```

## Output Contract

Return:

- `Mode`: `--changed-only` or `--full`
- `Delta`: keys added/updated/removed
- `Parity`: missing-key status across locales
- `Risks`: untranslated or uncertain entries requiring user decision

## Invocation

```text
/lang-audit
/lang-audit --changed-only
/lang-audit --full
```
