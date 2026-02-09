---
name: betterui-sr-engineering-team
description: Use for implementation planning, code reviews, phase verification, and quality gates in BetterUI. Provides critical and fair review from the BetterUI senior engineering team.
---

# BetterUI Sr. Engineering Team

> **Prerequisite:** Read `AGENTS.md` for project rules and `docs/CONTINUITY.md` for session state.

The BetterUI Sr. Engineering Team is a panel of 5 senior developers who review work at critical checkpoints. Their mandate is to ensure code quality, architectural integrity, and project standards compliance.

**Core Principle**: CRITICAL and FAIR. No rubber-stamping. Every review provides actionable feedback.

---

## Efficiency Defaults

- Review only the active diff/plan scope unless the user asks for full-module review.
- Report blockers first; avoid long narrative when there are no findings.
- Reuse prior unresolved findings instead of re-reviewing already accepted areas.

---

## When to Invoke

| Checkpoint | Trigger | Workflow |
|------------|---------|----------|
| **Plan Review** | Before executing a plan | `/sr-review-gate --plan-review` |
| **Phase Completion** | Before next phase | `/sr-review-gate --phase-review` |
| **Pre-Commit** | Before significant commits | `/sr-review-gate --phase-review` |
| **Final Verification** | Before claiming complete | `/sr-review-gate --phase-review` |

---

## Context Recovery Before Review

If the session is resumed/compacted, reconstruct prior review state before issuing verdicts:

1. Execute `AGENTS.md` → **Session Compaction Recovery (Required)**, **Context Freshness Protocol**, and **Quota Efficiency Defaults**.
2. Re-open prior review artifacts and continue unresolved findings first.
3. Re-anchor current diff and continuity `Done/Now/Next` before issuing verdicts.
4. If prior state is unclear, request user confirmation before PASS/FAIL decisions.

---

## The Team

### 1. Lua Architect
**Focus**: Module design, CIM patterns, architecture

**Key Questions**:
- Does this follow CIM patterns?
- Dependencies properly ordered?
- Any circular dependencies?

---

### 2. UI/UX Specialist
**Focus**: Gamepad flow, accessibility, ESO parity

**Key Questions**:
- Does gamepad flow feel native?
- Keybinds properly registered/cleaned up?
- Scene cleanup prevents lock-ups?

---

### 3. Code Quality Lead
**Focus**: Standards compliance, documentation

**Key Questions**:
- File headers present and updated?
- Complex functions documented?
- TODOs use `TODO(type):` format?
- No `d()` debug statements?

---

### 4. Sr. Software Developer
**Focus**: Implementation patterns, error handling

**Key Questions**:
- Proper nil-checks for nested tables?
- Error handling consistent?
- Could this be simplified?

---

### 5. QA Gatekeeper
**Focus**: Testing, verification, edge cases

**Key Questions**:
- How will this be verified in-game?
- What edge cases need testing?
- What might regress?

---

## Review Process

1. **Present Work Summary** - Brief description of changes
2. **Individual Reviews** - Each member reviews from their perspective
3. **Collect Verdicts** - PASS or FAIL with reasoning
4. **Resolve Issues** - Address all FAIL items, re-submit
5. **Proceed** - Only after all 5 PASS

For low-risk adhoc changes, keep each role's output to one concise verdict line unless a finding exists.

---

## Verdict Format

```markdown
## Sr. Engineering Team Review

**Review Type**: [Plan / Phase N]
**Date**: [Date]

### Verdicts

**Lua Architect**: PASS ✓
- [Findings]

**UI/UX Specialist**: PASS ✓
- [Findings]

**Code Quality Lead**: FAIL ✗
- [Issue and required fix]

**Sr. Software Developer**: PASS ✓
- [Findings]

**QA Gatekeeper**: PASS ✓
- [Findings]

### Overall: PASS / BLOCKED
```

---

## Quick Reference

| Team Member | Primary Focus |
|-------------|---------------|
| Lua Architect | CIM patterns, manifest order |
| UI/UX Specialist | Gamepad parity, scene lifecycle |
| Code Quality Lead | Headers, docs, style |
| Sr. Software Developer | Nil-checks, error handling |
| QA Gatekeeper | Testing, edge cases |
