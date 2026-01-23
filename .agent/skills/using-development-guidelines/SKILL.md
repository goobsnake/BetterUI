---
name: using-development-guidelines
description: Use when starting any coding task, modifying Lua/XML files, writing documentation, or verifying work before completion to ensure compliance with project standards
---

# Using Development Guidelines

## Overview

This skill defines the required standards for the BetterUI codebase. Adhering to these guidelines allows us to maintain consistency, readability, and high quality across the project.

**Core Principle**: Code is read much more often than it is written. Optimize for readability and maintainability through standardized documentation and clean structure.

## When to Use

- **Start of Task**: To refresh memory on file header and indentation standards.
- **Writing Code**: When adding new functions, tables, or files.
- **Refactoring**: When cleaning up old code or resolving technical debt.
- **Documentation**: When adding or updating comments.

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

**REQUIRED**: Before claiming any task is complete, use the `verification-before-completion` skill to ensure all checks pass. Key verification areas:

- **Syntax**: `luac -p <file>` for Lua; XML parsing validation.
- **In-Game**: Addon loads without errors; feature works; no regressions.
- **Documentation**: File headers up-to-date; function docs complete.
- **Git Hygiene**: `git diff` shows only intended changes; no debug code.

> **ESO Testing Note**: Since ESO addons cannot use automated test frameworks, verification relies on manual in-game testing. Use `d()` for temporary debugging output during development, but **always remove before committing**.

## Related Skills

These skills complement the development workflow:

| Skill | When to Use |
|-------|-------------|
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

### Completion Requirements
**CRITICAL**: When a workflow or major task sequence concludes, you **MUST** present the following artifacts to the User before finishing:

1.  **Completed Implementation Plan**: Allow the user to see the final state of the plan with all tasks marked as `[x] Accepted` or `[x] Done`.
2.  **Corrective Action Report**: A dedicated section summarizing any deviations from the original plan and how they were resolved. If no deviations occurred, explicitly state "N/A - implementation proceeded as planned."
    - *Example (deviation)*: "Workflow step 3 failed due to missing dependency; manually installed X to resolve."
    - *Example (pivot)*: "Original plan to modify X was abandoned because Y was found to be a better solution."
    - *Example (none)*: "N/A - implementation proceeded as planned."
3.  **Final Code Review**: A self-conducted review of the changes against the standards defined in this skill, explicitly confirming:
    - No debug prints left behind.
    - Comments were preserved/updated.
    - Consistency with project style.
4.  **Testing & Verification Plan**: A user-facing report with specific instructions for verifying the changes made. This must include:
    - **Reproduction Steps**: How to trigger or exercise the new/fixed functionality in-game.
    - **Expected Behavior**: What the user should observe if the changes are working correctly.
    - **Edge Cases**: Specific configurations, settings, or scenarios that should be tested (e.g., "Test with addon X disabled", "Try with an empty inventory").
    - **Regression Checks**: Areas of the codebase that might be affected by the changes and should be spot-checked.
