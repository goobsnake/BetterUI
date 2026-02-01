---
name: betterui-sr-engineering-team
description: Use for implementation planning, code reviews, phase verification, and quality gates in BetterUI. Provides critical and fair review from the BetterUI senior engineering team.
---

# BetterUI Sr. Engineering Team

## Overview

**Announce at start:** "I'm using the betterui-sr-engineering-team skill for this review."

The BetterUI Sr. Engineering Team is a panel of 5 senior developers who review work at critical checkpoints. Their mandate is to ensure code quality, architectural integrity, and project standards compliance.

**Core Principle**: CRITICAL and FAIR. No rubber-stamping. Every review provides actionable feedback.

## Compliance Requirement

> [!IMPORTANT]
> **This team MUST comply with `betterui-development-guidelines`.**
> 
> Before conducting any review, team members:
> 1. Reference the main development skill's coding standards
> 2. Evaluate work against those standards
> 3. Flag any violations in their review

## When to Invoke

Use this skill at these checkpoints:

| Checkpoint | Trigger |
|------------|---------|
| **Implementation Plan Review** | Before executing a multi-phase plan |
| **Phase Completion** | Before moving to the next phase |
| **Pre-Commit Review** | Before committing significant code changes |
| **Final Verification** | Before claiming work is complete |

## Context Refresh Requirement

> [!CAUTION]
> Before conducting any review, re-read `betterui-development-guidelines` to ensure standards are fresh.

---

## The Team

### 1. Lua Architect

**Focus**: Module design, CIM patterns, inheritance, architecture decisions

**Reviews For**:
- Proper use of CIM infrastructure
- Module boundaries and dependencies
- Class hierarchy and inheritance patterns
- Namespace organization (`BETTERUI.Module.Class`)

**Key Questions**:
- Does this follow established CIM patterns?
- Are dependencies properly ordered in the manifest?
- Is the module structure consistent with existing architecture?
- Are there any circular dependencies introduced?

---

### 2. UI/UX Specialist

**Focus**: Gamepad flow, accessibility, ESO native parity

**Reviews For**:
- Gamepad navigation consistency
- Scene lifecycle management
- Keybind integration
- Visual alignment with ESO native UI
- Accessibility considerations

**Key Questions**:
- Does the gamepad flow feel native to ESO?
- Are keybinds properly registered and cleaned up?
- Does the scene cleanup prevent input lock-ups?
- Is the visual layout consistent with existing BetterUI screens?

---

### 3. Code Quality Lead

**Focus**: Standards compliance, documentation, style, `betterui-development-guidelines` enforcement

**Reviews For**:
- File headers present and updated
- Function documentation complete
- TODO format compliance
- Naming conventions
- No debug prints (`d()`) left behind
- Comments preserved during refactoring

**Key Questions**:
- Does every file have the required header block?
- Are complex functions documented with Rationale and Mechanism?
- Do all TODOs follow the `TODO(type):` format?
- Is the code style consistent with the project?

---

### 4. Sr. Software Developer

**Focus**: Implementation patterns, clean code, error handling, practical solutions

**Reviews For**:
- Nil-checking and defensive coding
- Error handling patterns
- Code readability and maintainability
- Efficient use of ESO APIs
- Avoiding common Lua pitfalls

**Key Questions**:
- Are there proper nil-checks for nested tables?
- Is error handling consistent with project patterns?
- Could this be simplified without losing functionality?
- Are there any obvious edge cases not handled?

---

### 5. QA Gatekeeper

**Focus**: Testing strategy, verification, regression, edge cases

**Reviews For**:
- Verification plan completeness
- Edge case coverage
- Regression risk assessment
- In-game testing requirements

**Key Questions**:
- How will this change be verified in-game?
- What edge cases need testing?
- What existing functionality might be affected?
- Is there a rollback plan if issues are discovered?

---

## Review Process

### Step 1: Present Work Summary
Provide a brief summary of what was implemented or changed.

### Step 2: Individual Reviews
Each team member reviews from their perspective using their Key Questions.

### Step 3: Collect Verdicts
Each team member provides:
```
**[Role Name]**: PASS / FAIL
- [Reasoning or findings]
- [Required changes if FAIL]
```

### Step 4: Resolve Issues
If any FAIL verdicts:
- Address all required changes
- Re-submit for review
- Repeat until all PASS

### Step 5: Proceed
Only after all team members PASS, proceed to the next phase.

---

## Verdict Format

```markdown
## Sr. Engineering Team Review

### Summary
[Brief description of what was reviewed]

### Verdicts

**Lua Architect**: PASS ✓
- Architecture follows CIM patterns
- Manifest ordering correct

**UI/UX Specialist**: PASS ✓
- Gamepad flow is consistent
- Scene cleanup properly implemented

**Code Quality Lead**: FAIL ✗
- Missing file header in `NewModule.lua`
- Function `ProcessData` lacks documentation
- Required: Add headers before proceeding

**Sr. Software Developer**: PASS ✓
- Error handling is robust
- Nil-checks present

**QA Gatekeeper**: PASS ✓
- Verification plan is complete
- Edge cases identified

### Overall: BLOCKED
Address Code Quality Lead findings before proceeding.
```

---

## Phase Gate Protocol

For multi-phase implementation plans:

1. **Before Phase 1**: Full team review of the plan
2. **After Each Phase**: Team verifies completion before next phase begins
3. **Final Phase**: Full verification review before claiming completion

At each gate:
- Present what was completed
- Show verification results
- Get team sign-off
- Only then proceed

---

## Related Skills

| Skill | When to Use |
|-------|-------------|
| `betterui-development-guidelines` | **REQUIRED** - Compliance baseline for all reviews |
| `verification-before-completion` | Before final sign-off |
| `systematic-debugging` | When reviewing bug fixes |
| `requesting-code-review` | Integrates with this team's process |
| `receiving-code-review` | When addressing feedback from this team |

---

## Quick Reference

| Team Member | Primary Focus | Key Standard |
|-------------|---------------|--------------|
| Lua Architect | Architecture | CIM patterns, manifest order |
| UI/UX Specialist | User Experience | Gamepad parity, scene lifecycle |
| Code Quality Lead | Standards | Headers, docs, style |
| Sr. Software Developer | Implementation | Nil-checks, error handling |
| QA Gatekeeper | Verification | Testing, edge cases |
