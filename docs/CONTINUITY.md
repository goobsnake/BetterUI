# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-07T21:08Z
> **Provenance:** [CODE] Fixed 3 bugs: banking keyboard toggle, tooltip label hiding, Seals currency display

**Reference:** For ESO API quirks, patterns, and lessons learned see [TRIBAL_KNOWLEDGE.md](TRIBAL_KNOWLEDGE.md).

---

## Snapshot (≤25 lines)

**Goal:** Maintain high-quality ESO addon with gamepad-first UI modernization

**Success Criteria:**
- All modules follow CIM patterns
- Consistent gamepad navigation across scenes
- Clean code with comprehensive documentation
- No regressions in existing functionality

**Invariants:**
- Never modify `esoui/` reference folder
- All code must load without errors in-game
- Follow `betterui-development-guidelines` for all changes
- Shared code goes in `Modules/CIM/`, never new "Shared" folders

---

## State

**Done (recent ≤7):**
- [2026-02-07] [CODE] Fixed Seals currency display: `CURT_SEALS` renamed from `CURT_ENDEAVOR_SEALS` — added compat alias like Trade Bars
- [2026-02-07] [CODE] Fixed tooltip label hiding regression: hooks on `ZO_Tooltip` class table don't affect `zo_mixin`'d instances; moved to per-instance overrides
- [2026-02-07] [CODE] Fixed banking keyboard toggle (I/G/M keys) causing blurry screen by intercepting `SCENE_MANAGER:Toggle/Show` during banking
- [2026-02-07] [CODE] Fixed Junk category tab not appearing when marking items as junk (SetItemIsJunk is async)
- [2026-02-07] [CODE] Finalized scroll thumb backdrop replacement with native gamepad divider sample
- [2026-02-07] [CODE] Fixed 4 inventory bugs: sort consistency, quickslot icons, quest item use, quickslot unassign
- [2026-02-07] [CODE] Implemented P1/P2 fixes (Banking keybinds, tooltip localization, fallback removal, debug gating)

**Now:**
- Session complete

**Next:**
- Continue opportunistic modularization work for Inventory/CIM hotspots as needed

---

## Decisions

| ID | Status | Date | Decision |
|----|--------|------|----------|
| D001 | ACTIVE | 2026-02-06 | Two-file approach: CONTINUITY.md for session state, TRIBAL_KNOWLEDGE.md for permanent learnings |

---

## Open Questions

(None currently)

---

## Working Set (≤12 paths)

- `docs/CONTINUITY.md`
- `docs/TRIBAL_KNOWLEDGE.md`
- `Modules/Banking/Banking.lua`
- `Modules/CIM/Core/EnhancementModule.lua`
- `Modules/CIM/UI/CurrencyManager.lua`
- `Modules/Inventory/UI/TooltipUtils.lua`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-07 | [CODE] | Fixed Seals currency: `CURT_SEALS` → `CURT_SEALS or CURT_ENDEAVOR_SEALS` compat alias (same pattern as Trade Bars) |
| 2026-02-07 | [CODE] | Fixed tooltip hiding: `zo_mixin` copies methods from class to instance at init time; must hook per-instance, not class table |
| 2026-02-07 | [CODE] | Fixed banking keyboard toggle: intercept `SCENE_MANAGER:Toggle/Show` with re-entrancy guard during active banking |
| 2026-02-07 | [CODE] | Removed `BetterUI_RecursiveHide` from TooltipUtils.lua — native labels now suppressed at source via `AddTopLinesToTopSection` hook |
| 2026-02-07 | [CODE] | Fixed Junk tab bug: `SetItemIsJunk()` is async, moved coalesced `RefreshCategoryList` outside dialog if/else in `OnInventoryUpdated` |
| 2026-02-07 | [CODE] | Finalized ScrollIndicator thumb texture (`gp_nav1_horDividerFlat.dds` center-row sampling) |
| 2026-02-07 | [CODE] | Added cleanup requirement for temporary review artifacts before commit |
| 2026-02-07 | [CODE] | Fixed profiler report shadowing bug and updated module enable documentation |
| 2026-02-07 | [CODE] | Replaced Banking keybind strip resets with targeted group removal |
| 2026-02-07 | [CODE] | Localized tooltip cleanup tokens and junk label rendering |
| 2026-02-06 | [TOOL] | Completed 7-phase agent config optimization |
| 2026-02-06 | [TOOL] | Moved CONTRIBUTING.md + CONTINUITY.md to docs/ |
| 2026-02-06 | [USER] | Requested agent configuration refactor with AGENTS.md |
| 2026-02-06 | [USER] | Approved two-file approach (CONTINUITY + TRIBAL_KNOWLEDGE) |
| 2026-02-06 | [TOOL] | Created AGENTS.md and docs/CONTINUITY.md |

