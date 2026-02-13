---
description: Mandatory Sr. Engineering Team review gate for adhoc work, implementation plans, and phase completions
---

# Sr. Review Gate Workflow

Use this gate for quality decisions, not ceremony.

## Defaults

- Review active diff or active plan scope only.
- Reuse unresolved findings; do not re-review already accepted areas.
- Keep verdicts compact unless blockers exist.
- Treat `docs/CONTINUITY.md` as read-only during gate loops; do not write continuity per verdict cycle.

## Stop Conditions

- Review mode is `--plan-review` but no active implementation plan exists.
- Review mode is `--phase-review` but phase scope cannot be identified from diff/continuity.
- Recovered state conflicts with requested gate scope and user confirmation is unavailable.

## Modes

| Mode | Trigger | Use When |
|------|---------|----------|
| `default` | No flag passed | Bugfixes/adhoc implementation review |
| `--plan-review` | Before execution | Approving an implementation plan |
| `--phase-review` | After each phase | Verifying completed phase work |

## Step 0: Resume Guard (if context may be stale)

1. Execute `AGENTS.md` Session Compaction Recovery Tier 1 fingerprint:
   - `git rev-parse --abbrev-ref HEAD`
   - `git rev-parse --short HEAD`
   - `git status --short`
   - optional: `pwsh -File tools/context_health_check.ps1`
2. Re-anchor continuity with targeted scan:
   - `rg -n "^\*\*Done|^\*\*Now:|^\*\*Next:|^## Open Questions|^## Working Set" docs/CONTINUITY.md`
3. If state is unclear, run Tier 2 (`git diff --name-only HEAD` + artifact discovery).
4. Continue only after `Done / Now / Next` is clear and aligned with active review scope.

## Step 1: Gather Minimal Context

Use the smallest sufficient context:

```powershell
git diff --name-only HEAD
```

Then inspect targeted diffs for changed files only.

For `--plan-review`, read only the active plan and touched-file list.

For `--phase-review`, verify recovered `Done / Now / Next` in continuity still matches the phase being reviewed before issuing verdicts.

## Step 2: Run Sr. Team Review

Use `betterui-sr-engineering-team` and return one verdict per role:

- Lua Architect
- UI/UX Specialist
- Code Quality Lead
- Sr. Software Developer
- QA Gatekeeper

## Step 3: Verdict and Resolution Loop

All 5 roles must PASS before proceeding.

Compact output format:

```markdown
## Sr. Engineering Team Review

**Review Type**: [Default / Plan / Phase]

- Lua Architect: PASS/FAIL - [short reason]
- UI/UX Specialist: PASS/FAIL - [short reason]
- Code Quality Lead: PASS/FAIL - [short reason]
- Sr. Software Developer: PASS/FAIL - [short reason]
- QA Gatekeeper: PASS/FAIL - [short reason]

**Overall**: PASS / BLOCKED
```

If any FAIL:

1. List only blocking findings with file references.
2. Fix all blockers.
3. Re-run this gate on the same scope.

## Step 4: Continue

- `default`: continue current task.
- `--plan-review`: start implementation.
- `--phase-review`: continue to next phase or wrap-up.
- If a completed phase introduced durable addon-state changes, perform at most one batched continuity update after the gate loop is clean.

## Output Contract

Return:

- `Review Type`: Default / Plan / Phase
- five role verdict lines in the standard format
- `Overall`: PASS / BLOCKED
- `Blocking Findings`: only when BLOCKED, each with file reference

## Invocation

```text
/sr-review-gate
/sr-review-gate --plan-review
/sr-review-gate --phase-review
```
