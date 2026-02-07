---
description: Perform a comprehensive two-pass code review of the BetterUI codebase with TODO generation or actionable fixes
---

# Code Review Workflow

This workflow performs a thorough code review of the BetterUI addon in two passes, generating actionable TODO items for future iteration.

## Prerequisites

See `AGENTS.md` for project context, skills, and workflows.

---

## Pass 0: Restore Session Context (Required on resume/compaction)

If context may be stale due to long-running or resumed work:

1. Execute `AGENTS.md` → **Session Compaction Recovery (Required)** using its tiered sequence.
2. Apply `AGENTS.md` → **Quota Efficiency Defaults** before running broad scans.
3. If `critical_code_review.md`, `sr_engineering_team_review.md`, or `implementation_plan.md` already exist, resume unresolved findings instead of restarting from scratch.
4. If prior state is ambiguous, ask the user before starting a new pass.

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
Run: `rg --files Modules -g "*.lua"`
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
- All files in `Modules/CIM/Core/` (start with quick outline-style reads for efficiency)
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

1. **Use quick outline-style reads** first to understand structure without reading full content
2. **Batch similar files** - review all `Constants.lua` files together, all `Module.lua` files together
3. **Use `rg`** to find patterns across files:
   ```
   rg -n "d\\(" Modules
   rg -n "TODO" Modules
   rg -n -- "-- TODO:" Modules
   rg -n "pcall" Modules
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

### 2.1 Refresh Guidelines
Re-read `betterui-development-guidelines` before proceeding.

### 2.2 Per-Module Team Review

For **Comprehensive** scope, have each team member (see `betterui-sr-engineering-team` skill) review each module. Use a per-module verdict table:

```markdown
### [Module Name]
| Role | Verdict | Key Finding |
|------|---------|-------------|
| Lua Architect | PASS/FAIL | [Finding] |
| UI/UX Specialist | PASS/FAIL | [Finding] |
| Code Quality Lead | PASS/FAIL | [Finding] |
| Sr. Software Developer | PASS/FAIL | [Finding] |
| QA Gatekeeper | PASS/FAIL | [Finding] |
```

### 2.3 Consolidate Team Verdicts

Create `sr_engineering_team_review.md` with:
- Review metadata (date, scope, files reviewed)
- Per-module verdict tables (from 2.2)
- Consolidated cross-module findings per team member with `TODO(type):` items
- Priority issues summary table (P0/P1/P2 with module, owner, effort)
- All TODOs grouped by type (architecture, refactor, cleanup, doc, fix, optimization)
- Recommendations

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

Add TODO comments using batched edits for efficiency.

**After each phase completes:**

```
Follow /sr-review-gate --phase-review
```

#### 3A.4 Verify & Commit

```
Remove any temporary review artifacts or implementation plans before committing.
Run: luac -p <modified files> (syntax check)
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

### [MODIFY] `Modules/SomeModule/File.lua`

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
- Use batched edits for multiple changes in the same file
- Use targeted patches for single contiguous edits
- Batch by module to maintain context

**After each phase completes:**

```
Follow /sr-review-gate --phase-review
```

**Mandatory**: Every phase must be reviewed before proceeding to the next.

#### 3B.5 Verification

Use the `verification-before-completion` skill:

```
Run: luac -p <modified files> (syntax check)
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
Remove any temporary review artifacts or implementation plans before committing.
Run: git add -A && git commit -m "fix: address code review findings

- [List key changes]
- See sr_engineering_team_review.md for full findings"
```

---

## Command Reference

| Command | Scope | Output | Time |
|---------|-------|--------|------|
| `/code-review` | Standard (~30 files) | Prompts for mode | ~30-45 min |
| `/code-review --quick` | ~10 core files | Prompts for mode | ~15-20 min |
| `/code-review --comprehensive` | All files | Prompts for mode | 2-3 hours |
| `/code-review --todo` | Default scope | Insert TODO comments | Varies |
| `/code-review --action` | Default scope | Actual code fixes | Varies |

Combine scope + output flags freely: `--quick --todo`, `--standard --action`, `--comprehensive --todo`, etc.

---

## Output Artifacts

| Artifact | Purpose |
|----------|---------|
| `critical_code_review.md` | Pass 1 critique with issues and recommendations |
| `sr_engineering_team_review.md` | Pass 2 formal verdicts with additional TODOs |
| `implementation_plan.md` | Plan for TODO insertions or code fixes |

---

## Tips

1. **Use pattern search liberally** - Faster than reading each file
2. **Batch similar files** - All Constants.lua together, all Module.lua together
3. **Track progress** - Update the progress table as you review
4. **Focus on deltas** - If files are similar, note "same issues as X"
5. **Time-box modules** - Don't spend too long on any single module
