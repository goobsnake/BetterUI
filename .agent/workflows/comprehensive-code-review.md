---
description: Perform a comprehensive two-pass code review of the BetterUI codebase with TODO generation or actionable fixes
---

# Comprehensive Code Review Workflow

This workflow performs a thorough code review of the BetterUI addon in two passes, generating actionable TODO items for future iteration.

// turbo-all

## Prerequisites
- Read `betterui-development-guidelines` skill
- Read `betterui-sr-engineering-team` skill
- Have access to `docs/ARCHITECTURE.md` and `docs/TRIBAL_KNOWLEDGE.md`

---

## Review Scope Configuration

Before starting, determine the review scope:

| Scope | Files Reviewed | Use When |
|-------|----------------|----------|
| **Quick** | ~10 core files | Fast sanity check |
| **Standard** | ~30 key files (default) | Regular code reviews |
| **Comprehensive** | All ~156 files | Major releases, deep audits |

If user doesn't specify, use **Standard** scope.

---

## Output Mode Configuration

Determine what action to take after the review:

| Mode | Action | Use When |
|------|--------|----------|
| **--todo** | Insert TODO comments for later | Documenting tech debt, future sprints |
| **--action** | Create plan to fix issues now | Active remediation work |

If user doesn't specify, **ask which mode they want** after Pass 2 completes.

**Mode Behavior:**

| Aspect | --todo Mode | --action Mode |
|--------|-------------|---------------|
| Output | TODO comments in code | Actual code fixes |
| Commit message | `chore: add code review TODOs` | `fix: address code review findings` |
| Implementation plan | Lists TODO insertions | Lists code changes with diffs |
| Verification | Syntax check only | Full verification (syntax + in-game) |
| Sr. Team final review | Not required | Required before commit |

---

## Pass 1: Principal Code Reviewer Critique

Adopt the perspective of a **Sr. Software Developer and Principal Code Reviewer** who is NOT IMPRESSED by everything they see.

### 1.1 Discovery Phase

First, map the entire codebase structure:

```
Run: find_by_name with Extensions: ["lua"] on x:\Git\BetterUI\Modules
```

This gives you the full file inventory. Organize findings by module.

### 1.2 Module-by-Module Review

Review each module systematically. For each module:

#### CIM Module (Core - Review First)
**Priority Files** (always review):
- `Modules/CIM/Constants.lua`
- `Modules/CIM/Module.lua`
- `Modules/CIM/Core/Utilities.lua`
- `Modules/CIM/Core/WindowClass.lua`
- `Modules/CIM/Core/SafeExecute.lua`
- `Modules/CIM/Core/FeatureFlags.lua`
- `Modules/CIM/Core/SceneLifecycleManager.lua`

**Extended Files** (for Standard/Comprehensive):
- All files in `Modules/CIM/Core/` (use `view_file_outline` for efficiency)
- `Modules/CIM/UI/*.lua`
- `Modules/CIM/Lists/*.lua`

#### Inventory Module
**Priority Files**:
- `Modules/Inventory/Constants.lua`
- `Modules/Inventory/Module.lua`
- `Modules/Inventory/Core/InventoryClass.lua`
- `Modules/Inventory/Lists/InventoryList.lua`

**Extended Files**:
- `Modules/Inventory/Core/*.lua`
- `Modules/Inventory/Actions/*.lua`
- `Modules/Inventory/Keybinds/*.lua`

#### Banking Module
**Priority Files**:
- `Modules/Banking/Constants.lua`
- `Modules/Banking/Module.lua`
- `Modules/Banking/Banking.lua`

**Extended Files**:
- `Modules/Banking/Lists/*.lua`
- `Modules/Banking/Actions/*.lua`
- `Modules/Banking/Keybinds/*.lua`

#### ResourceOrbFrames Module
**Priority Files**:
- `Modules/ResourceOrbFrames/Constants.lua`
- `Modules/ResourceOrbFrames/Module.lua`
- `Modules/ResourceOrbFrames/ResourceOrbFrames.lua`

**Extended Files**:
- `Modules/ResourceOrbFrames/Core/*.lua`
- `Modules/ResourceOrbFrames/SkillBar/*.lua`

#### WritUnit Module
**Priority Files**:
- `Modules/WritUnit/Constants.lua`
- `Modules/WritUnit/Module.lua`

**Extended Files**:
- All remaining files in `Modules/WritUnit/`

#### Root Files
- `BetterUI.lua` (entry point)
- `Globals.lua` (if exists)

### 1.3 Efficient Review Strategy

For **Comprehensive** reviews with many files:

1. **Use `view_file_outline`** first to understand structure without reading full content
2. **Batch similar files** - review all `Constants.lua` files together, all `Module.lua` files together
3. **Use `grep_search`** to find patterns across files:
   ```
   grep_search for "d(" to find debug statements
   grep_search for "TODO" to find existing TODOs
   grep_search for "-- TODO:" to find non-compliant TODO format
   grep_search for "pcall" to audit error handling
   ```
4. **Focus on public interfaces** - prioritize exported functions over internal helpers

### 1.4 Track Progress

Create a tracking table as you review:

```markdown
| Module | Files | Reviewed | Issues Found |
|--------|-------|----------|--------------|
| CIM/Core | 38 | 0 | - |
| CIM/UI | 10 | 0 | - |
| CIM/Lists | 10 | 0 | - |
| Inventory | 27 | 0 | - |
| Banking | 16 | 0 | - |
| ResourceOrbFrames | 28 | 0 | - |
| WritUnit | 4 | 0 | - |
| Root | 2 | 0 | - |
```

### 1.5 Generate Critique

Create an artifact file `critical_code_review.md` that includes:

**Structure:**
```markdown
# BetterUI Critical Code Review

**Reviewers**: Sr. Software Developer + Principal Code Reviewer
**Date**: [Current Date]
**Verdict**: [IMPRESSED / NOT IMPRESSED]
**Scope**: [Quick / Standard / Comprehensive]
**Files Reviewed**: [X of Y total files]

## Executive Summary
[2-3 paragraph overview of codebase health]

## Module Health Summary
| Module | Grade | Key Issues |
|--------|-------|------------|
| CIM | [A-F] | [Summary] |
| Inventory | [A-F] | [Summary] |
| Banking | [A-F] | [Summary] |
| ResourceOrbFrames | [A-F] | [Summary] |
| WritUnit | [A-F] | [Summary] |

## 🔴 CRITICAL ISSUES (Must Fix)
[Issues that represent bugs, production risks, or major anti-patterns]
- Include file references with line numbers
- Include code examples
- Include actionable TODO(type) items

## 🟠 MAJOR ISSUES (Should Fix)
[Issues that affect maintainability or consistency]

## 🟡 MODERATE ISSUES (Should Address)
[Issues that are concerning but not blocking]

## 🔵 MINOR ISSUES (Nice to Have)
[Style, documentation, or preference issues]

## Cross-Cutting Concerns
[Issues that appear across multiple modules]

## Recommended Priority Order
[Numbered list of what to fix first]

## What Would I Do Differently?
[Alternative approaches and recommendations]

## Verdict Summary
| Area | Grade | Notes |
|------|-------|-------|
| Architecture | [A-F] | [Notes] |
| Code Quality | [A-F] | [Notes] |
| Documentation | [A-F] | [Notes] |
| Error Handling | [A-F] | [Notes] |
| Consistency | [A-F] | [Notes] |
| Maintainability | [A-F] | [Notes] |
```

**Critique Focus Areas:**
1. Debug statements in production code
2. Error handling consistency
3. Magic numbers and hardcoded values
4. Code duplication (DRY violations)
5. Module organization and Single Responsibility
6. Naming conventions and consistency
7. Documentation completeness
8. Scene lifecycle management
9. Keybind registration/cleanup
10. Global namespace pollution
11. File header compliance
12. TODO format compliance
13. Type annotation coverage
14. Deprecated code still present

---

## Pass 2: Sr. Engineering Team Review

Invoke the `betterui-sr-engineering-team` skill for a formal panel review.

### 2.1 Announce Skill Usage
State: "I'm using the betterui-sr-engineering-team skill for this review."

### 2.2 Refresh Guidelines
Re-read `betterui-development-guidelines` before proceeding.

### 2.3 Per-Module Team Review

For **Comprehensive** scope, have the team review each module:

```markdown
## Module: [ModuleName]
**Files Reviewed**: [List]

### Lua Architect: PASS/FAIL
- [Module-specific findings]

### UI/UX Specialist: PASS/FAIL
- [Module-specific findings]

### Code Quality Lead: PASS/FAIL
- [Module-specific findings]

### Sr. Software Developer: PASS/FAIL
- [Module-specific findings]

### QA Gatekeeper: PASS/FAIL
- [Module-specific findings]
```

### 2.4 Consolidate Team Verdicts

Create an artifact file `sr_engineering_team_review.md` with consolidated verdicts:

**Template:**
```markdown
# BetterUI Sr. Engineering Team Review

**Review Date**: [Current Date]
**Review Type**: [Quick / Standard / Comprehensive] Codebase Audit
**Files Reviewed**: [X of Y]

## Summary
[What was reviewed]

## Per-Module Verdicts

### CIM Module
| Role | Verdict | Key Finding |
|------|---------|-------------|
| Lua Architect | PASS/FAIL | [Finding] |
| UI/UX Specialist | PASS/FAIL | [Finding] |
| Code Quality Lead | PASS/FAIL | [Finding] |
| Sr. Software Developer | PASS/FAIL | [Finding] |
| QA Gatekeeper | PASS/FAIL | [Finding] |

### Inventory Module
[Same table format]

### Banking Module
[Same table format]

### ResourceOrbFrames Module
[Same table format]

### WritUnit Module
[Same table format]

## Consolidated Verdicts

### **Lua Architect**: PASS/FAIL
**Focus**: Module design, CIM patterns, inheritance, architecture
- [Cross-module findings]
- **TODO(architecture)**: [Specific items]

### **UI/UX Specialist**: PASS/FAIL
**Focus**: Gamepad flow, accessibility, ESO native parity
- [Cross-module findings]
- **TODO(refactor)**: [Specific items]

### **Code Quality Lead**: PASS/FAIL
**Focus**: Standards compliance, documentation, style
- [Cross-module findings]
- **TODO(cleanup)**: [Specific items]
- **TODO(doc)**: [Specific items]

### **Sr. Software Developer**: PASS/FAIL
**Focus**: Implementation patterns, clean code, error handling
- [Cross-module findings]
- **TODO(refactor)**: [Specific items]
- **TODO(fix)**: [Specific items]

### **QA Gatekeeper**: PASS/FAIL
**Focus**: Testing strategy, verification, edge cases
- [Cross-module findings]
- **TODO(architecture)**: [Specific items]

## Overall: PASS/BLOCKED

## Priority Issues Summary
| Priority | Issue | Module | Owner | Effort |
|----------|-------|--------|-------|--------|
| P0 | [Critical] | [Module] | [Role] | [Time] |
| P1 | [Major] | [Module] | [Role] | [Time] |
| P2 | [Moderate] | [Module] | [Role] | [Time] |

## All TODOs by Type

### TODO(architecture)
- [ ] [Item with file reference]

### TODO(refactor)
- [ ] [Item with file reference]

### TODO(cleanup)
- [ ] [Item with file reference]

### TODO(doc)
- [ ] [Item with file reference]

### TODO(fix)
- [ ] [Item with file reference]

### TODO(optimization)
- [ ] [Item with file reference]

## Recommendations
[Sprint focus, process improvements, tooling suggestions]
```

---

## Pass 3: Implementation

After the Sr. Engineering Team review, take action based on the selected output mode.

### If Output Mode Not Specified

Ask the user:
> "Would you like me to:
> 1. **Add TODOs** - Insert TODO comments for future iteration (`--todo`)
> 2. **Fix Now** - Create an implementation plan to address issues now (`--action`)"

---

### Pass 3A: TODO Mode (`--todo`)

#### 3A.1 Generate TODO Implementation Plan

Create `implementation_plan.md` with:
- Phased approach (Critical → Major → Minor)
- **Organized by module** for large reviews
- Specific file locations and line numbers
- Exact TODO text to insert (using `TODO(type):` format)
- Syntax verification steps

**Structure:**
```markdown
## Phase 1: [Module Name] TODOs
### [File.lua]
- Line X: `-- TODO(type): description`

## Phase 2: [Next Module] TODOs
...
```

#### 3A.2 Plan Review Gate

Before executing, invoke the review gate:

```
Follow /sr-review-gate --plan-review
```

All 5 team members must PASS before proceeding.

#### 3A.3 Execute TODO Insertions With Phase Gates

Add TODO comments using `multi_replace_file_content` for efficiency.

**After each phase completes:**

```
Follow /sr-review-gate --phase-review
```

#### 3A.4 Verify & Commit

```
Run: luac5.1 -p <modified files> (syntax check)
Run: git add -A && git commit -m "chore: add code review TODOs for future iteration"
```

---

### Pass 3B: Action Mode (`--action`)

#### 3B.1 Prioritize Findings

From the Sr. Engineering Team review, prioritize issues:

| Priority | Criteria | Action |
|----------|----------|--------|
| **P0** | Bugs, production risks, crashes | Fix immediately |
| **P1** | DRY violations, inconsistent patterns | Fix in this session |
| **P2** | Missing docs, stale headers | Fix if time permits |
| **P3** | Style, preferences, nice-to-have | Defer or TODO |

#### 3B.2 Generate Action Implementation Plan

Create `implementation_plan.md` with:
- Phased approach (P0 → P1 → P2)
- **Organized by module** for large reviews
- Specific file locations and line numbers
- **Exact code changes** with before/after diffs
- Full verification plan (syntax + in-game testing)
- Rollback instructions

**Structure:**
```markdown
# Implementation Plan: Code Review Fixes

## User Review Required
> [!WARNING]
> This plan modifies production code. Review carefully.

## Phase 1: Critical Fixes (P0)

### [MODIFY] [File.lua](file:///path)

**Issue**: [Description]
**Fix**: [What we're changing]

```diff
- old code
+ new code
```

## Verification Plan
- [ ] Syntax check passes
- [ ] Addon loads without errors
- [ ] [Specific feature] works correctly
- [ ] No regressions in [related area]
```

#### 3B.3 Plan Review Gate

Before executing, invoke the review gate:

```
Follow /sr-review-gate --plan-review
```

All 5 team members must PASS before proceeding.

**Critical**: Do NOT proceed without approval for action mode.

#### 3B.4 Execute Fixes With Phase Gates

Implement changes per the approved plan:
- Use `multi_replace_file_content` for multiple edits in same file
- Use `replace_file_content` for single contiguous edits
- Batch by module to maintain context

**After each phase completes:**

```
Follow /sr-review-gate --phase-review
```

**Mandatory**: Every phase must be reviewed before proceeding to the next.

#### 3B.5 Verification

Use the `verification-before-completion` skill:

```
Run: luac5.1 -p <modified files> (syntax check)
```

Request user to verify in-game if changes affect runtime behavior.

#### 3B.6 Sr. Engineering Team Final Review

Before committing in action mode, invoke the final phase review:

```
Follow /sr-review-gate --phase-review
```

**All 5 team members must PASS** before proceeding.

#### 3B.7 Commit Changes

```
Run: git add -A && git commit -m "fix: address code review findings

- [List key changes]
- See sr_engineering_team_review.md for full findings"
```

---

## Quick Invocation

To run this workflow, simply say:
> "Perform a comprehensive code review of the BetterUI codebase"

Or use the slash command:
> /comprehensive-code-review

---

### Command Reference

#### Base Command
```
/comprehensive-code-review
```
**Behavior**: Uses `--standard` scope and prompts for output mode after Pass 2.

---

#### Scope Modifiers

| Modifier | Files | Time | Use Case |
|----------|-------|------|----------|
| `--quick` | ~10 core files | 15-20 min | Quick sanity check, pre-commit review |
| `--standard` | ~30 key files | 30-45 min | Regular code reviews, feature completion |
| `--comprehensive` | All ~156 files | 2-3 hours | Major releases, deep audits, onboarding |

```
/comprehensive-code-review --quick
```
**What it does**: Reviews only the most critical files - entry points, main classes, and shared constants. Good for verifying nothing is obviously broken.

```
/comprehensive-code-review --standard
```
**What it does**: Reviews priority files in each module plus commonly-edited files. Balances thoroughness with time. **This is the default.**

```
/comprehensive-code-review --comprehensive
```
**What it does**: Reviews EVERY Lua file in the codebase. Uses `view_file_outline` and `grep_search` for efficiency. Generates per-module verdicts from Sr. Engineering Team.

---

#### Output Mode Modifiers

| Modifier | Output | Commit Type | Final Review |
|----------|--------|-------------|--------------|
| `--todo` | TODO comments inserted | `chore:` | Not required |
| `--action` | Actual code fixes | `fix:` | Required (all 5 PASS) |

```
/comprehensive-code-review --todo
```
**What it does**: After review, inserts `TODO(type):` comments at identified problem locations. These serve as markers for future work. Code functionality unchanged.

**Example output**:
```lua
-- TODO(refactor): Extract search focus handlers to CIM/Core/SearchManager.lua
-- This code duplicates Banking.lua L261-320 (~60 lines identical)
```

```
/comprehensive-code-review --action
```
**What it does**: After review, creates an implementation plan with actual code fixes. Prioritizes by severity (P0→P1→P2). Requires explicit approval before any changes. Sr. Engineering Team must approve fixes before commit.

**Example output**:
```diff
- zo_callLater(function() d("[BetterUI Banking] FILE LOADED") end, 2000)
+ -- Debug statement removed per code review
```

---

#### Combined Commands

**Quick review, mark for later:**
```
/comprehensive-code-review --quick --todo
```
**Use when**: You want a fast sanity check and to document any issues found without fixing them now. Good for end-of-day reviews.

---

**Quick review, fix critical issues now:**
```
/comprehensive-code-review --quick --action
```
**Use when**: You suspect there are critical issues (debug statements, crashes) and want to fix them immediately. Only reviews core files, only fixes P0 issues.

---

**Standard review, mark for later:**
```
/comprehensive-code-review --standard --todo
```
**Use when**: Regular code review before a release. Documents tech debt across main modules without blocking release. **Most common usage.**

---

**Standard review, fix now:**
```
/comprehensive-code-review --standard --action
```
**Use when**: You have time to address issues found during review. Fixes P0 and P1 issues, documents P2/P3 as TODOs.

---

**Comprehensive audit, mark for later:**
```
/comprehensive-code-review --comprehensive --todo
```
**Use when**: Major version release or onboarding new contributor. Creates complete picture of codebase health. Generates many TODOs.

---

**Comprehensive audit, fix everything:**
```
/comprehensive-code-review --comprehensive --action
```
**Use when**: Dedicated cleanup sprint. Reviews entire codebase and fixes all P0/P1/P2 issues. **Expect 2-4 hour session.** Multiple Sr. Team checkpoints.

---

### Workflow Steps

**Pass 1-2** (same for both modes):
1. Discover all files in the codebase
2. Review files based on scope (Quick: ~10, Standard: ~30, Comprehensive: all)
3. Generate Pass 1 critique (Principal Reviewer perspective)
4. Generate Pass 2 review (Sr. Engineering Team verdicts per module)

**Pass 3 - TODO Mode** (`--todo`):
5. Create plan for TODO insertions
6. Request approval, insert TODOs
7. Commit with `chore:` prefix

**Pass 3 - Action Mode** (`--action`):
5. Prioritize findings (P0 → P1 → P2)
6. Create plan with actual code fixes
7. Request approval (blocked until approved)
8. Execute fixes
9. Run verification
10. Sr. Engineering Team final review
11. Commit with `fix:` prefix

---

## Output Artifacts

| Artifact | Purpose |
|----------|---------|
| `critical_code_review.md` | Pass 1 critique with issues and recommendations |
| `sr_engineering_team_review.md` | Pass 2 formal verdicts with additional TODOs |
| `implementation_plan.md` | Plan for adding TODOs to codebase |

---

## Tips for Comprehensive Reviews

1. **Use grep_search liberally** - Pattern search is faster than reading each file
2. **Review by file type** - All Constants.lua together, all Module.lua together
3. **Track progress** - Update the progress table as you go
4. **Parallel view_file_outline** - Use parallel tool calls to scan multiple files
5. **Focus on deltas** - If files are similar, note "same issues as X"
6. **Time-box modules** - Don't spend too long on any single module
