# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-07T00:35Z
> **Provenance:** [TOOL] Removed review artifacts per user request

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
- [2026-02-07] [TOOL] Removed code review artifacts and implementation plan files
- [2026-02-07] [CODE] Implemented P1/P2 fixes (Banking keybinds, tooltip localization, fallback removal, debug gating)
- [2026-02-06] [TOOL] Agent config optimization: moved docs, simplified Claude commands, standardized prerequisites
- [2026-02-06] [TOOL] Created AGENTS.md root configuration
- [2026-02-06] [USER] Approved agent config refactor plan

**Now:**
- Cleanup complete; ready for further fixes or validation

**Next:**
- Run `luac5.1 -p` on modified files and perform in-game validation

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

- `BetterUI.lua`
- `Modules/Banking/Banking.lua`
- `Modules/Banking/Keybinds/KeybindManager.lua`
- `Modules/CIM/UI/ScrollIndicator.lua`
- `Modules/Inventory/Core/InventoryClass.lua`
- `Modules/Inventory/UI/TooltipUtils.lua`
- `docs/CONTINUITY.md`
- `docs/TRIBAL_KNOWLEDGE.md`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-07 | [TOOL] | Removed critical_code_review.md, sr_engineering_team_review.md, implementation_plan.md |
| 2026-02-07 | [CODE] | Replaced Banking keybind strip resets with targeted group removal |
| 2026-02-07 | [CODE] | Localized tooltip cleanup tokens and junk label rendering |
| 2026-02-07 | [CODE] | Removed fallback strings in Feature Flags and search positioning |
| 2026-02-07 | [CODE] | Gated ScrollIndicator diagnostics behind debug flag |
| 2026-02-07 | [USER] | Requested comprehensive code review with action mode |
| 2026-02-06 | [TOOL] | Completed 7-phase agent config optimization |
| 2026-02-06 | [TOOL] | Moved CONTRIBUTING.md + CONTINUITY.md to docs/ |
| 2026-02-06 | [USER] | Requested agent configuration refactor with AGENTS.md |
| 2026-02-06 | [USER] | Approved two-file approach (CONTINUITY + TRIBAL_KNOWLEDGE) |
| 2026-02-06 | [TOOL] | Created AGENTS.md and docs/CONTINUITY.md |
