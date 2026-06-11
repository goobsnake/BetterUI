# BetterUI Tools

This directory contains utility scripts for development and maintenance.

## Localization

### `LanguageMaintenance.ps1`
Unified localization script for sync + audit workflows.

**Usage:**
```powershell
.\LanguageMaintenance.ps1
.\LanguageMaintenance.ps1 -Mode Sync
.\LanguageMaintenance.ps1 -Mode Audit
.\LanguageMaintenance.ps1 -Mode SyncAndAudit
```

**Outputs (Audit / SyncAndAudit):**
- `tools/audit_report.md`
- `tools/used_strings.txt`

## Graphics

### `ConvertPngToDds.ps1`
Converts textures with `texconv.exe` to ESO-compatible DDS output.

**Usage:**
```powershell
.\ConvertPngToDds.ps1 -InputPath '.\Modules\CIM\Textures' -Format DXT5 -ResizePow2
.\ConvertPngToDds.ps1 -InputPath '.\Modules\ResourceOrbFrames\CustomTextures' -Profile ResourceOrbFrames -Format DXT5
```

## Deployment

### `Update_BetterUI.ps1`
Deploys addon files to the ESO Live AddOns directory.

### `Update_BetterUI_PTS.ps1`
Deploys addon files to the ESO PTS AddOns directory.

**Usage:**
```powershell
.\Update_BetterUI.ps1
.\Update_BetterUI_PTS.ps1
```
