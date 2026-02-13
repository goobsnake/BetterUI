---
description: Scan esoui reference folder for gamepad QoL features BetterUI lacks, then update docs/FEATURE_REQUESTS.md
---

# Feature Requests Workflow

Targeted `esoui/` gap scan for BetterUI roadmap updates.

## Defaults

- Scope default: `--quick` (high-value adjacent systems only).
- Output default: update `docs/FEATURE_REQUESTS.md`.
- Use `--comprehensive` only for roadmap cycles.

## Stop Conditions

- No meaningful net-new gaps are found for the chosen scope.
- Existing backlog already covers discovered opportunities.
- Requested scope exceeds available evidence quality for prioritization.

## Scope Modes

| Scope | Coverage | Use When |
|-------|----------|----------|
| `--quick` (default) | Inventory, Banking, shared gamepad infra | Routine gap checks |
| `--standard` | Quick + crafting/social/navigation | Quarterly roadmap pass |
| `--comprehensive` | All gamepad systems | Major planning cycle |

## Output Modes

| Mode | Behavior |
|------|----------|
| (none) | Update `docs/FEATURE_REQUESTS.md` |
| `--report-only` | Findings only, no file edits |
| `--diff` | Show only net-new/changed opportunities |

## Step 0: Baseline

If session state may be stale (resume/compaction/long gap), run AGENTS Session Compaction Recovery Tier 1 before scanning.

Read existing feature backlog first:

- `docs/FEATURE_REQUESTS.md`
- Current module coverage from `Modules/`

## Step 1: Build Scan Targets

PowerShell-safe directory mapping:

```powershell
Get-ChildItem -Path esoui -Recurse -Directory -Filter gamepad | Select-Object -ExpandProperty FullName
```

Use scope to filter target directories.

## Step 2: Targeted Discovery

Focus on missing/partial capabilities relative to BetterUI:

```powershell
rg -n "UI_SHORTCUT|keybind|ZO_Dialogs_ShowGamepadDialog" esoui/ingame
rg -n "SCREEN_NARRATION_MANAGER" esoui/ingame --files-with-matches
rg -n "ZO_RadialMenu" esoui --files-with-matches
```

Capture concrete feature gaps with source references.

## Step 3: Gap Matrix

For each candidate, classify:

- Status: `MISSING` or `PARTIAL`
- User impact: Low/Medium/High/Very High
- Effort: Very Low/Low/Medium/High
- Priority: `P0` to `P4`

Skip items already implemented or intentionally out of scope.

## Step 4: Update `docs/FEATURE_REQUESTS.md`

When writing updates:

1. Merge with existing entries; avoid duplicates.
2. Remove implemented items.
3. Re-rank priorities based on current CIM capabilities.
4. Keep implementation notes concrete and scoped.

## Step 5: Summary

Report:

- Added count
- Updated count
- Removed count
- Priority changes

Update `docs/CONTINUITY.md` only if this materially affects addon roadmap execution, and batch into one milestone entry (not per scan iteration).

## Output Contract

Return:

- `Added`, `Updated`, `Removed` counts
- top priority shifts with rationale
- evidence pointers to `esoui/` references for each net-new item

## Invocation

```text
/feature-requests
/feature-requests --standard
/feature-requests --comprehensive
/feature-requests --report-only
/feature-requests --diff
```
