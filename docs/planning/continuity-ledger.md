# BetterUI Continuity Ledger

Last Updated: 2026-03-05
Status: Active

This document is the lightweight session-handoff ledger for ongoing BetterUI work. Keep this file short and current; use Git history for deep historical receipts.

## Snapshot

- Goal: Deliver stable, gamepad-first UI improvements without regressions in Inventory, Banking, and Resource Orb Frames.
- Invariants:
  - Keep shared abstractions in `Modules/CIM/`.
  - Preserve scene lifecycle symmetry (`SHOWING`/`HIDING`/`HIDDEN`) to avoid stuck input states.
  - Avoid broad refactors when targeted fixes are sufficient.

## Current Focus

- Multi-select anti-spam hardening and batch-action safety.
- Resource Orb Frames interaction polish and tooltip behavior parity.
- Documentation normalization and backlog hygiene.

## Working Set

- `Modules/CIM/Core/MultiSelectMixin.lua`
- `Modules/Banking/Core/MultiSelectActions.lua`
- `Modules/Inventory/Core/InventoryClass.lua`
- `Modules/Inventory/Actions/DestroyAction.lua`
- `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua`
- `Modules/ResourceOrbFrames/SkillBar/TooltipManager.lua`
- `docs/planning/project-improvements.md`

## Handoff Checklist

- Update `docs/planning/project-improvements.md` when scope or phase status changes.
- Record durable implementation patterns in `docs/reference/tribal-knowledge.md`.
- Keep `docs/planning/feature-requests.md` for open product/capability requests only.
