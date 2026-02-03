---
name: betterui-development-guidelines
description: Use ONLY when working on the BetterUI project. Ensures compliance with project standards for Lua/XML, documentation, and verification.
---

# Using Development Guidelines

## Overview

**Announce at start:** "I'm using the betterui-development-guidelines skill for this BetterUI work."

This skill defines the required standards for the BetterUI codebase. Adhering to these guidelines allows us to maintain consistency, readability, and high quality across the project.

**Core Principle**: Code is read much more often than it is written. Optimize for readability and maintainability through standardized documentation and clean structure.

## When to Use

> [!IMPORTANT]
> **BetterUI Only**: This skill is strictly for use when working on the **BetterUI** project (e.g., repository name matches `BetterUI` or related addon files). If you are working on a different project, DO NOT apply these guidelines unless explicitly instructed.

- **Start of Task**: To refresh memory on file header and indentation standards.
- **Writing Code**: When adding new functions, tables, or files.
- **Refactoring**: When cleaning up old code or resolving technical debt.
- **Documentation**: When adding or updating comments.

## Context Refresh Protocol

> [!CAUTION]
> **Long Session Warning**: If you've been working for 10+ tool calls since last reading this skill, re-read it now to ensure you're following BetterUI standards.

**Refresh Triggers** - Re-read this skill when:
- Starting a new phase of implementation
- Before any commit
- Before claiming work is complete
- When you notice standards drift (this is your reminder!)

## Tribal Knowledge

> [!IMPORTANT]
> At session start, read `/docs/TRIBAL_KNOWLEDGE.md` for project history and lessons learned.
> Before completing major work, run `/update-tribal-knowledge` to capture any new discoveries.

**What to record**:
- Solutions that worked (with rationale)
- Mistakes made and how to avoid them
- ESO API quirks discovered
- Module-specific gotchas

**Workflow**: Use `/update-tribal-knowledge` at the end of each development session to systematically capture learnings.

## Quick Reference

| Standard | Rule |
|----------|------|
| File Headers | Required on all `.lua` and `.xml` files |
| Function Docs | Required for non-trivial functions |
| Indentation | 4 spaces (match existing) |
| Globals | `BETTERUI.Module.Class` |
| Locals | `camelCase` |
| TODOs | `TODO(type): description` |
| Constants | Module-specific → `Constants.lua`; Shared → `BetterUI.CONST.lua` |

## ESO-Specific Best Practices

*   **Event Management**: Always unregister events when no longer needed.
*   **Performance**: Avoid expensive operations in `OnUpdate` handlers; use `zo_callLater` for deferred work.
*   **Global Pollution**: Never add unintentional globals; use `local` for all file-level variables. For module-level constants, use the module's specific `Constants.lua` file. For shared or global constants, use `BetterUI.CONST.lua`.
*   **API Compatibility**: Check for API existence before calling (e.g., `if GetTomePoints then ... end`).
*   **esoui Reference Folder**: The `esoui/` directory contains ESO's in-game UI source code. Use it freely for API research, function signatures, and understanding game code patterns. **NEVER modify files within `esoui/`** — it is read-only reference material.

## Core Standards

### 1. Lua Documentation Standards

All Lua files must adhere to the **Block Comment** style.

#### 1.1 File Headers
Every Lua file must begin with a standardized header block.

```lua
--[[
File: Modules/[ModuleName]/[FileName].lua
Purpose: [High-level summary of what this file does]
         [Additional context or architectural notes]
Author: [Author Name]
Last Modified: [YYYY-MM-DD]
]]
```

#### 1.2 Function Documentation
Every function of **significant complexity or public interface** must be documented with a block comment immediately preceding its definition.

**Template:**
```lua
--[[
Function: [FunctionName or Path]
Description: [Concise description of the function's goal]
Rationale: [Why does this function exist? What problem does it solve?]
Mechanism: [How does it work? Key logic steps, important API calls, side effects]
References: [What calls this? (e.g., "Called by Initialize")]
param: [paramName] ([type]) - [Description]
return: [type] - [Description]
TODO: [Optional: Any cleanup/optimization needed]
]]
function MyFunction(param1)
    ...
end
```

**Key Fields:**
*   **Rationale**: Explain the *intent*. Critical for maintenance.
*   **Mechanism**: Explain the *implementation*. Mention key dependencies.

#### 1.3 Variable/Constant Documentation

```lua
--[[
Table: BETTERUI.MyTable
Description: Stores configuration for X.
Used By: [Module.lua, Feature.lua]
]]
local MyTable = { ... }
```

**Offset Constants (X/Y Positioning):**
When defining any offset or positioning constants, always document the directional effect:

```lua
--[[
Constant: BETTERUI_ORB_FRAMES.bars.backUltimateOffsetX
Description: Horizontal offset for the backbar ultimate button.
Direction: Positive (+) moves RIGHT, Negative (-) moves LEFT.
Used By: ResourceOrbFrames.lua
]]
backUltimateOffsetX = -10,

--[[
Constant: BETTERUI_ORB_FRAMES.bars.backUltimateOffsetY
Description: Vertical offset for the backbar ultimate button.
Direction: Positive (+) moves DOWN, Negative (-) moves UP.
Used By: ResourceOrbFrames.lua
]]
backUltimateOffsetY = 5,
```

This allows future developers to tweak positioning without trial-and-error.

### 2. XML Documentation Standards

XML files must include a header comment block at the very top.

**Template:**
```xml
<!--
File: Modules/[ModuleName]/Templates/[FileName].xml
Purpose: Defines UI controls and templates for [Feature].
         [Explanation of key templates defined here]
-->
<GuiXml>
    ...
</GuiXml>
```

**Complex Controls:**
Add comments above complex `<Control>` definitions explaining their role.

### 3. TODO & FIXME Guidelines

Use actionable, structured TODOs. **Remove them once the described task is successfully implemented.**

**Format:** `TODO(type): [Description]`

**Types:**
*   `TODO(refactor)`: Code works but needs structural improvement.
*   `TODO(cleanup)`: Dead code, debug prints, or messy formatting.
*   `TODO(optimization)`: Performance improvements.
*   `TODO(fix)`: Known bug or edge case handling.
*   `TODO(architecture)`: High-level design changes needed.
*   `TODO(doc)`: Missing or accidentally removed documentation.

### 4. General Style Requirements

*   **Indentation**: Use 4 spaces (or match existing file style). Be consistent.
*   **Naming**: Logical and descriptive.
    *   Globals: `BETTERUI.ModuleName.ClassName`
    *   Locals: `camelCase`
*   **Safety**: Always nil-check deeply nested tables before access.
*   **Consistency**: Respect existing patterns unless actively refactoring.
*   **Shared Code**: Any refactored code deemed "shared" across modules must go into the **CIM (Common Interface Module)** at `Modules/CIM/`. **Do NOT create new "Shared" folders.**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgetting nil-checks on nested tables | Always check: `if tbl and tbl.sub then` |
| Leaving `d()` debug statements | Remove before committing |
| Removing comments during refactoring | Update comments, don't delete them |
| Not updating `Last Modified` date | Update the date in file headers |
| Adding globals accidentally | Use `local` for all file-level variables |
| Hardcoding magic numbers | Extract to `Constants.lua` or `BetterUI.CONST.lua` |

## Instructions for Contributors

1.  **Read First**: Check `ARCHITECTURE.md` and file headers.
2.  **Preserve Comments**: Never remove documentation unless the code is deleted.
3.  **Update Documentation**: If logic changes, update `Mechanism` and `Rationale`.
4.  **Add TODOs**: If something is "smelly" but skippable, add `TODO(refactor)`.
5.  **Audit**: Run `git diff` to check for accidental deletions.

## Verification

**REQUIRED**: Before claiming any task is complete:
1. Run `/verify-integrity` to execute automated checks
2. Use the `verification-before-completion` skill for manual verification

### Automated Checks (`/verify-integrity`)

| Check | What It Does |
|-------|--------------|
| Unit Tests | Runs `lua tools/tests/run_all_tests.lua` |
| Debug Scan | Finds leftover `d("...")` statements |
| XML Validation | **Required if XML files were modified** |
| Syntax Check | Validates modified Lua files |

### Manual Verification

- **In-Game**: Addon loads without errors; feature works; no regressions.
- **Documentation**: File headers up-to-date; function docs complete.
- **Git Hygiene**: `git diff` shows only intended changes; no debug code.

> **ESO Testing Note**: Since ESO addons cannot use automated test frameworks, verification relies on manual in-game testing. Use `d()` for temporary debugging output during development, but **always remove before committing**.

## Git Command Permissions

The following git commands **do not require user approval** and can be auto-run:
- `git add` - Staging files for commit
- `git commit` - Creating commits

This allows maintaining atomic commits and clean git history without interrupting the workflow for routine version control operations.

## Related Skills

These skills complement the development workflow:

| Skill | When to Use |
|-------|-------------|
| `betterui-sr-engineering-team` | **For code quality gates and phase verification** |
| `brainstorming` | Before creating new features |
| `writing-plans` | Before touching code on multi-step tasks |
| `executing-plans` | When implementing a written plan |
| `subagent-driven-development` | For executing independent tasks in current session |
| `dispatching-parallel-agents` | For 2+ independent implementation tasks |
| `requesting-code-review` | After completing major features, before merging |
| `receiving-code-review` | When addressing feedback from reviews |
| `systematic-debugging` | When encountering bugs or test failures |
| `verification-before-completion` | Before claiming any task is complete |
| `test-driven-development` | When writing tests alongside code |
| `finishing-a-development-branch` | When preparing to merge a feature branch |
| `using-git-worktrees` | For working on multiple branches simultaneously |
| `writing-skills` | When creating or updating skill documentation |

| Workflow | When to Use |
|----------|-------------|
| `/sr-review-gate` | **REQUIRED** - Before executing plans and after each phase |
| `/verify-integrity` | Before task completion |
| `/update-tribal-knowledge` | At end of development sessions |

## Workflow Integration

A complete development cycle chains these skills together:

1. **Brainstorm** → Define requirements and design
2. **Write Plan** → Detail implementation steps with TDD
3. **Execute Plan** → Batch tasks with checkpoints, using `subagent-driven-development` where appropriate
4. **Dispatch Parallel Agents** → For independent phases
5. **Request Code Review** → Before merging
6. **Receive Code Review** → Address feedback critically
7. **Verify** → Before claiming completion

### Implementation Plans & Task Status
When creating implementation plans:
- **Presentation**: Explicitly list which Applicable Workflows will be used (e.g., "Using `subagent-driven-development` for Phase 1").
- **Task Detail**: Every generated task must include both a **Status** (To Do / In Progress / Done) and **Detail** (what specifically will be done).
  - *Bad*: `- [ ] Fix bug`
  - *Good*: `- [ ] [To Do] Fix nil reference in Inventory.lua:L123 by adding safety check`

## Development Protocol

**Upon reading this skill file**:
1.  **Acknowledge**: Confirm understanding of these guidelines.
2.  **Identify Workflow Step**: If executing a workflow, state the current step (e.g., "Current Workflow Step: 3").

## Completion Requirements

When a workflow or major task concludes:

### Step 1: Run Verification Workflow
Execute `/verify-integrity` to ensure all automated checks pass.

### Step 2: Capture Tribal Knowledge
Run `/update-tribal-knowledge` to document any API quirks, gotchas, or lessons learned during the session.

### Step 3: Sr. Engineering Team Review

Use the `/sr-review-gate` workflow for structured team review:

```
Follow /sr-review-gate --phase-review
```

### Step 4: Generate Completion Artifacts

1. **`task.md`** - Granular checklist of executed actions (all items checked off)
2. **`verification_plan.md`** - How to verify the changes in-game
3. **`walkthrough.md`** - Must include:
   - **Skills Used**: Table of all skills invoked during the work
   - **Workflows Used**: Table of workflows invoked (e.g., `/verify-integrity`, `/update-tribal-knowledge`)
   - **Sr. Engineering Review Summary**: High-level outcomes from each review checkpoint

The Sr. Engineering Team review covers code quality, standards compliance, and identifies any issues before completion.

### Walkthrough Template

```markdown
## Skills Used
| Skill | Purpose |
|-------|---------|
| `skill-name` | Brief description of how it was used |

## Sr. Engineering Review Summary

### Plan Review - [Date]
**Outcome:** PASS/BLOCKED
- [Key findings]

### Final Review - [Date]  
**Outcome:** PASS
- [Confirmation of standards compliance]
```

