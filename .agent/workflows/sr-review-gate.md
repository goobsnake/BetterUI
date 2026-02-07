---
description: Mandatory Sr. Engineering Team review gate for bugfix/adhoc work, implementation plans, and phase completions
---

# Sr. Review Gate Workflow

Centralized workflow for mandatory Sr. Engineering Team reviews at critical checkpoints. Ensures all code changes are reviewed from multiple expert perspectives before proceeding.

## Overview

> [!CAUTION]
> **No Fast-Track**: Every review must pass. Even minor issues must be fixed before proceeding.
> Tech debt accumulates from skipping "trivial" issues.

This workflow provides three review modes:
- **Adhoc/Bugfix Review (Default)**: For bugfixes, one-off tasks, and general implementation work
- **Plan Review**: Before executing any implementation plan
- **Phase Review**: After completing each phase, before proceeding to the next

---

## Prerequisites

See `AGENTS.md` for project context, skills, and workflows.

---

## Mode Configuration

| Mode | Trigger | Use When |
|------|---------|----------|
| `default` | No flag passed | Reviewing bugfixes, adhoc tasks, and general code changes |
| `--plan-review` | Before Phase 1 | Reviewing an implementation plan before execution begins |
| `--phase-review` | After each phase | Reviewing completed work before proceeding to next phase |

---

## Step 1: Gather Context

### For Adhoc/Bugfix Review (Default)

Present the following to the review team:
1. **Change Summary**: What was changed and why
2. **Files Changed**: Current working-set file list with key deltas
3. **Risk Check**: Potential regressions and impacted systems
4. **Verification Status**: What has been validated so far

### For Plan Review (`--plan-review`)

Present the following to the review team:
1. **Implementation Plan Summary**: What will be changed and why
2. **Files Affected**: List of files to be created, modified, or deleted
3. **Risk Assessment**: What could go wrong
4. **Verification Plan**: How changes will be validated

### For Phase Review (`--phase-review`)

Present the following to the review team:
1. **Phase Summary**: What was completed in this phase
2. **Files Changed**: List of files that were modified with key changes
3. **Verification Status**: What has been verified so far
4. **Issues Encountered**: Any unexpected problems and how they were resolved

---

## Step 2: Invoke Sr. Engineering Team

Use the `betterui-sr-engineering-team` skill to conduct the review. See the skill for each team member's focus area, key questions, and verdict format.

---

## Step 3: Collect Verdicts

Each team member provides PASS or FAIL with findings, using the verdict format from the `betterui-sr-engineering-team` skill. All 5 must PASS before proceeding.

---

## Step 4: Resolution Loop

> [!IMPORTANT]
> **All 5 team members must PASS before proceeding.**
> There is no exception to this rule.

### If Any FAIL Verdict

1. **Document Issues**: List all findings from FAIL verdicts
2. **Fix Issues**: Address each finding
3. **Re-submit**: Present fixed work to team
4. **Repeat**: Continue until all 5 members PASS

### Resolution Format

```markdown
### Issue Resolution

**Issue 1**: [From Lua Architect]
- **Problem**: [Description]
- **Fix Applied**: [What was changed]
- **Verification**: [How it was verified]

**Issue 2**: [From Code Quality Lead]
- **Problem**: [Description]
- **Fix Applied**: [What was changed]
- **Verification**: [How it was verified]

### Re-Review Request
All identified issues have been addressed. Requesting re-review.
```

---

## Step 5: Final Sign-Off

Once all 5 team members PASS:

```markdown
### Review Gate: PASSED ✓

**Review Type**: [Plan Review / Phase N Review]
**Date**: [Current Date]
**All Team Members**: PASS

Proceeding to [execution / next phase].
```

---

## Quick Invocation

### Before executing an implementation plan:
```
Follow /sr-review-gate --plan-review
```

### After completing a phase:
```
Follow /sr-review-gate --phase-review
```

### For bugfixes and adhoc work (default):
```
Follow /sr-review-gate
```

---

## Integration Points

Workflows that use this review gate:

| Workflow | Plan Review | Phase Review |
|----------|-------------|--------------|
| `/garbage-cleanup` | Before Phase 1 | After each phase |
| `/code-review` | Before Pass 3 | After each implementation phase |
| `/review-todos` | Before implementing TODOs | After implementation |
| `/wrap-up` | N/A | Uses default mode for adhoc final review |

---

## Command Reference

| Command | When to Use |
|---------|-------------|
| `/sr-review-gate` | Default bugfix/adhoc review for current work |
| `/sr-review-gate --plan-review` | Before starting implementation |
| `/sr-review-gate --phase-review` | After completing each phase |

---

## Key Principles

1. **Mandatory**: No skipping reviews, no exceptions
2. **All Must Pass**: Every team member must approve
3. **Fix Before Proceed**: Issues resolved before continuing
4. **No Fast-Track**: Even trivial issues must be addressed
5. **Document Everything**: All findings and resolutions recorded

---

## Tips

1. **Prepare thoroughly** - Gather all context before invoking review
2. **Be specific** - Vague descriptions lead to incomplete reviews
3. **Address root causes** - Don't just fix symptoms
4. **Learn from patterns** - Recurring issues indicate systemic problems
5. **Update tribal knowledge** - New learnings go in TRIBAL_KNOWLEDGE.md
