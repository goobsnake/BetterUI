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
- **Session Resume/Compaction**: Reconstruct context from workflow artifacts before continuing
- **Writing Code**: When adding new functions, tables, or files
- **Refactoring**: When cleaning up old code
- **Documentation**: When adding or updating comments

---

## Quick Reference

| Standard | Rule |
|----------|------|
| File Headers | Required on new `.lua`/`.xml` files and substantial rewrites (avoid mass header-only churn) |
| Function Docs | Required for non-trivial functions |
| Indentation | 4 spaces (match existing) |
| Globals | `BETTERUI.Module.Class` |
| Locals | `camelCase` |
| TODOs | `TODO(type): description` |
| Constants | Module → `Constants.lua`; Shared → `CIM/Constants.lua` |

## Efficiency Defaults

- Work diff-first: inspect changed files before broad scans.
- Prefer targeted `rg -n` queries over whole-file or whole-module reads.
- Do not perform repo-wide style rewrites when implementing focused fixes.
- Keep comments and docs concise; avoid boilerplate text that adds noise.
- Treat `docs/CONTINUITY.md` as read-first during active troubleshooting; defer writes until a durable milestone is validated.

---

## Context Recovery (Compaction-Safe)

If the session is resumed or compacted, do not continue from memory:

1. Execute `AGENTS.md` → **Session Compaction Recovery (Required)**, **Context Freshness Protocol**, and **Quota Efficiency Defaults**.
2. Resume from unresolved artifact findings, not from chat memory.
3. Re-anchor target files with targeted reads/search before editing if they were read long ago.
4. If state is ambiguous, ask the user before proceeding.

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

1. Run `/verify-integrity` (changed-file scope first; full checks when risk is high or user requests)
2. Confirm addon loads without errors in-game when runtime behavior changed
3. Validate no regressions in directly impacted areas

---

## Git Permissions

See `AGENTS.md` § Command Permissions.

---

## Completion Checklist

When a task concludes:

1. ☐ Run `/verify-integrity`
2. ☐ Run `/sr-review-gate --phase-review` for multi-step or high-risk work
3. ☐ Run `/update-tribal-knowledge` only if durable new learnings emerged
4. ☐ Update `docs/CONTINUITY.md` only when addon development state meaningfully changed, and batch that update once per milestone (not per troubleshooting attempt)
