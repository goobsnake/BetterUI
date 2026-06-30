# BetterUI Tools

This directory contains utility scripts for development and maintenance.

## Diagnostics

### `builog-monitor/monitor.sh`
Tails BetterUI's live `[BUI]` stream from ESO `interface.log` and prints timed samples for live play-test monitoring.

**Usage:**
```bash
tools/builog-monitor/monitor.sh 5 10 remote
tools/builog-monitor/monitor.sh 2 5 /path/to/interface.log /path/to/Screenshots
```

See `tools/builog-monitor/SKILL.md` for the live-monitor workflow and `docs/reference/builog-developer-guide.md` for instrumentation standards.

### `lint/lint_log_messages.lua`
Checks that log message literals are self-describing phrases rather than terse function-name tokens.

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
.\ConvertPngToDds.ps1 -InputPath '.\Modules\ResourceOrbFrames\Textures' -Profile ResourceOrbFrames -Format DXT5
```

## Deployment

### `Update_BetterUI.ps1`
Deploys addon files to the ESO Live AddOns directory and the configured Live SMB share when available.

### `Update_BetterUI_PTS.ps1`
Deploys addon files to the ESO PTS AddOns directory and the configured PTS SMB share when available.

Both update scripts share `Update_BetterUI_Common.ps1` for copy behavior and SMB/GVFS path resolution.

**Usage:**
```powershell
.\Update_BetterUI.ps1
.\Update_BetterUI_PTS.ps1
```
