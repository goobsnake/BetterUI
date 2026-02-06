# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-06T08:26Z
> **Provenance:** [USER] Initial creation during agent config refactor

**Reference:** For ESO API quirks, patterns, and lessons learned see [TRIBAL_KNOWLEDGE.md](docs/TRIBAL_KNOWLEDGE.md).

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
- [2026-02-06] [TOOL] Created AGENTS.md root configuration
- [2026-02-06] [TOOL] Created CONTINUITY.md with two-file approach
- [2026-02-06] [USER] Approved agent config refactor plan

**Now:**
- Executing agent configuration refactor (Phase 3-5)

**Next:**
- Streamline skill files to remove duplication
- Update workflows to reference AGENTS.md

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

- `AGENTS.md`
- `CONTINUITY.md`
- `.agent/skills/betterui-development-guidelines/SKILL.md`
- `.agent/skills/betterui-sr-engineering-team/SKILL.md`
- `.agent/workflows/*.md` (8 files)
- `docs/TRIBAL_KNOWLEDGE.md`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-06 | [USER] | Requested agent configuration refactor with AGENTS.md |
| 2026-02-06 | [USER] | Approved two-file approach (CONTINUITY + TRIBAL_KNOWLEDGE) |
| 2026-02-06 | [TOOL] | Created AGENTS.md and CONTINUITY.md |
