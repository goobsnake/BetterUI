---
name: betterui-sr-engineering-team
description: Five-role BetterUI review panel for plan reviews, phase gates, and critical code quality decisions. Use for /sr-review-gate and explicit critical reviews; do not use for trivial non-code requests.
---

# BetterUI Sr. Engineering Team

Use this skill for structured PASS/FAIL quality gates.

## Trigger Phrases

- "/sr-review-gate"
- "review this plan before implementation"
- "phase review" or "quality gate"
- "do a critical review of these changes"

## Do Not Trigger

- Trivial informational requests with no code/plan artifact.
- Formatting-only checks with no behavioral risk.
- Non-BetterUI repositories.

## Minimal Inputs

1. Active review mode (`default`, `--plan-review`, `--phase-review`).
2. Scope artifact (active diff or implementation plan).
3. Current constraints from `AGENTS.md` plus continuity `Done/Now/Next`.

## Roles and Pass Criteria

- Lua Architect: CIM patterns, dependency order, module boundaries.
- UI/UX Specialist: gamepad flow, keybind lifecycle, scene cleanup.
- Code Quality Lead: standards compliance, readability, debug/TODO hygiene.
- Sr. Software Developer: defect risk, state handling, simplification opportunities.
- QA Gatekeeper: validation adequacy, edge cases, regression exposure.

A role fails only on blocking issues with concrete file evidence.

## Review Procedure

1. Confirm mode and scope; review diff-first unless broader scope was requested.
2. Reuse unresolved blockers; do not reopen previously accepted findings.
3. Issue one concise verdict per role.
4. If any role fails, list blockers only, require fixes, and rerun the same gate scope.
5. Pass only when all five roles pass.

## Output Contract

Use this exact structure:

```markdown
## Sr. Engineering Team Review
**Review Type**: [Default | Plan | Phase]
- Lua Architect: PASS/FAIL - [reason]
- UI/UX Specialist: PASS/FAIL - [reason]
- Code Quality Lead: PASS/FAIL - [reason]
- Sr. Software Developer: PASS/FAIL - [reason]
- QA Gatekeeper: PASS/FAIL - [reason]
**Overall**: PASS / BLOCKED
```

Add `Blocking Findings` only when `Overall` is `BLOCKED`.

## Troubleshooting

- If context may be stale, run AGENTS Session Compaction Recovery Tier 1 before reviewing.
- If review scope and recovered state conflict, ask the user before issuing verdicts.
