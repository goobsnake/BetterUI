---
name: betterui-development-guidelines
description: Use ONLY when working on the BetterUI project. Ensures compliance with project standards for Lua/XML, documentation, and verification.
---

# BetterUI Development Guidelines

> **Prerequisite:** Read `AGENTS.md` for project rules and `docs/CONTINUITY.md` for session state.

## When to Use

> [!IMPORTANT]
> **BetterUI Only**: This skill is strictly for use when working on the BetterUI project.

- **Start of Task**: Refresh memory on file header and indentation standards
- **Writing Code**: When adding new functions, tables, or files
- **Refactoring**: When cleaning up old code
- **Documentation**: When adding or updating comments

---

## Quick Reference

| Standard | Rule |
|----------|------|
| File Headers | Required on all `.lua` and `.xml` files |
| Function Docs | Required for non-trivial functions |
| Indentation | 4 spaces (match existing) |
| Globals | `BETTERUI.Module.Class` |
| Locals | `camelCase` |
| TODOs | `TODO(type): description` |
| Constants | Module → `Constants.lua`; Shared → `CIM/Constants.lua` |

---

## Lua Documentation Standards

### File Headers
Every Lua file must begin with:

```lua
--[[
File: Modules/[ModuleName]/[FileName].lua
Purpose: [High-level summary]
Author: [Author Name]
Last Modified: [YYYY-MM-DD]
]]
```

### Function Documentation
Every function of significant complexity:

```lua
--[[
Function: [FunctionName]
Description: [Concise description]
Rationale: [Why does this exist?]
Mechanism: [How does it work?]
References: [What calls this?]
param: [paramName] ([type]) - [Description]
return: [type] - [Description]
]]
function MyFunction(param1)
    ...
end
```

### Offset Constants
Always document directional effect:

```lua
--[[
Constant: offsetX
Direction: Positive (+) RIGHT, Negative (-) LEFT
]]
```

---

## XML Documentation Standards

```xml
<!--
File: Modules/[ModuleName]/Templates/[FileName].xml
Purpose: [What this defines]
-->
<GuiXml>
    ...
</GuiXml>
```

---

## TODO Format

Use: `TODO(type): [Description]`

| Type | Purpose |
|------|---------|
| `TODO(refactor)` | Needs structural improvement |
| `TODO(cleanup)` | Dead code, debug prints |
| `TODO(optimization)` | Performance improvements |
| `TODO(fix)` | Known bug or edge case |
| `TODO(architecture)` | High-level design changes |
| `TODO(doc)` | Missing documentation |

---

## ESO-Specific Best Practices

* **Event Management**: Always unregister events when no longer needed
* **Performance**: Avoid expensive operations in `OnUpdate`; use `zo_callLater`
* **Global Pollution**: Use `local`; module constants in `Constants.lua`
* **API Compatibility**: Check existence before calling (e.g., `if GetTomePoints then`)
* **esoui Reference**: Read-only reference material, never modify

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgetting nil-checks | `if tbl and tbl.sub then` |
| Leaving `d()` debug statements | Remove before commit |
| Removing comments during refactoring | Update comments, don't delete |
| Not updating `Last Modified` | Update in file headers |
| Hardcoding magic numbers | Extract to `Constants.lua` |

---

## Verification Requirements

Before claiming any task is complete:

1. Run `/verify-integrity` workflow (see `.agent/workflows/verify-integrity.md` for details)
2. Confirm addon loads without errors in-game
3. No regressions in related areas

---

## Git Permissions

See `AGENTS.md` § Command Permissions.

---

## Completion Checklist

When a task concludes:

1. ☐ Run `/verify-integrity`
2. ☐ Run `/update-tribal-knowledge` if new learnings
3. ☐ Run `/sr-review-gate --phase-review`
4. ☐ Update `CONTINUITY.md` with outcomes
