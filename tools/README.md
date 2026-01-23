# BetterUI Tools

This directory contains utility scripts for development and maintenance.

## Localization

### `LocalizationAudit.ps1`
The master localization audit tool. Run this script to perform a complete check of the localization system.

**Usage:**
```powershell
.\LocalizationAudit.ps1
```

**What it does:**
1.  **Scans Codebase**: Generates a list of all `SI_BETTERUI_` string keys used in the Lua/XML files.
2.  **Audits Language Keys**:
    *   Checks `en.lua` keys against the `SI_BETTERUI_` naming convention.
    *   Checks foreign language files (e.g., `de.lua`, `fr.lua`) for missing keys compared to `en.lua`.
    *   Checks for "Extra" keys in foreign files that are not in English (potential orphans).
3.  **Audits String Usage**:
    *   Identifies unused strings (defined in `en.lua` but never used in code).
    *   Identifies missing strings (used in code but undefined in `en.lua`).
4.  **Audits Translations**:
    *   Checks foreign files for strings that match the English text exactly (potential untranslated copy-pastes).
    
**Output:**
*   Generates a detailed report at `tools/audit_report.md`.
*   Saves the raw list of used keys to `tools/used_strings.txt`.

### `fix_langs.ps1`
A utility to batch-fix common issues in language files (e.g., renaming keys).

## Graphics

### `ConvertPngToDds.ps1`
Converts PNG images to ESO-compatible DDS format using `texconv.exe`.

**Usage:**
```powershell
.\ConvertPngToDds.ps1 -InputPath "path/to/texture.png"
```

## Deployment

### `helper_script.ps1` / `helper_script_pts.ps1`
Deployment scripts to copy the addon to the live/PTS `AddOns` folder for testing.
