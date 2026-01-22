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

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgetting nil-checks on nested tables | Always check: `if tbl and tbl.sub then` |
| Leaving `d()` debug statements | Remove before committing |
| Removing comments during refactoring | Update comments, don't delete them |
| Not updating `Last Modified` date | Update the date in file headers |
| Adding globals accidentally | Use `local` for all file-level variables |

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
