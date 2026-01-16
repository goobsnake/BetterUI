# BetterUI Development & Documentation Guidelines

This document serves as the authoritative reference for developers (both human and AI) working on the BetterUI codebase. It defines the required standards for in-code documentation, file headers, function contracts, and TODO management.

## 1. Lua Documentation Standards

All Lua files must adhere to the **Block Comment** style. Do not use legacy LuaDoc (`---`) unless specifically modifying a file that strictly adheres to it and hasn't been migrated yet.

### 1.1 File Headers
Every Lua file must begin with a standardized header block containing the file path, purpose, author (optional), and modification date.

**Template:**
```lua
--[[
File: Modules/[ModuleName]/[FileName].lua
Purpose: [High-level summary of what this file does]
         [Additional context or architectural notes]
Author: [Author Name]
Last Modified: [YYYY-MM-DD]
]]
```

### 1.2 Function Documentation
Every function (public or local) must be documented with a block comment immediately preceding its definition. The comment must explain the *Why* and *How*, not just the *What*.

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
*   **Rationale:** Critical for maintenance. Explain the *intent*.
*   **Mechanism:** Explain the *implementation*. Mention key dependencies or complex logic.

### 1.3 Variable/Constant Documentation
Block comments are preferred for significant tables or constants.

```lua
--[[
Table: BETTERUI.MyTable
Description: Stores configuration for X.
Used By: [Module.lua, Feature.lua]
]]
local MyTable = { ... }
```

## 2. XML Documentation Standards

XML files must include a header comment block at the very top, inside the `<GuiXml>` tag if possible, or immediately preceding it.

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
Add comments above complex `<Control>` definitions to explain their role.
```xml
<!-- 
    Template: BETTERUI_Specific_Row
    Purpose: Row template for the inventory list.
    Structure: Icon (Left), Label (Center), Status (Right).
-->
<Control name="BETTERUI_Specific_Row" ...>
```

## 3. TODO & FIXME Guidelines

We use actionable, structured TODOs to track technical debt and future enhancements.

**Format:**
`TODO(type): [Description]`

**Types:**
*   `TODO(refactor)`: Code works but needs structural improvement.
*   `TODO(cleanup)`: Dead code, debug prints, or messy formatting.
*   `TODO(optimization)`: Performance improvements.
*   `TODO(fix)`: Known bug or edge case handling.
*   `TODO(architecture)`: High-level design changes needed.
*   `TODO(doc)`: Missing or accidentally removed documentation.

**Example:**
```lua
-- TODO(refactor): This loop is O(n^2), consider caching result X to make it O(n).
for k,v in pairs(list) do ... end
```

## 4. General Style Requirements

*   **Indentation:** Use 4 spaces (or match existing file style, usually 4 spaces or 1 tab). Be consistent within the file.
*   **Naming:** logical and descriptive.
    *   Globals: `BETTERUI.ModuleName.ClassName`
    *   Locals: `camelCase`
*   **Safety:** Always nil-check deeply nested tables before access if uncertain.
*   **Consistency:** When editing a file, respect the existing patterns unless you are actively refactoring the entire file.

## 5. Instructions for Contributors (Humans & Agents)

When processing tasks or User Requests:
1.  **Read First**: Check this file, `ARCHITECTURE.md`, and existing file headers to understand the context.
2.  **Preserve Comments**: Never remove documentation comments during refactors unless the code they document is being deleted.
3.  **Update Documentation**: If you change logic, you **MUST** update the `Mechanism` and `Rationale` fields in the function header.
4.  **Add TODOs**: If you see something "smelly" but can't fix it right now, add a `TODO(refactor)`.
5.  **Audit**: After large changes, run a `git diff` to ensure you didn't accidentally nuke file headers.

---

## 6. Verification Checklist

Before submitting or merging changes, complete the following checks:

### 6.1 Syntax Validation
- [ ] **Lua Syntax**: Run `luac -p <file>` on all modified `.lua` files. No errors allowed.
  ```powershell
  Get-ChildItem -Recurse -Filter *.lua | ForEach-Object { luac -p $_.FullName }
  ```
- [ ] **XML Syntax**: Verify XML files parse correctly.
  ```powershell
  [xml](Get-Content "path/to/file.xml" -Raw)
  ```

### 6.2 In-Game Testing
- [ ] **Load Test**: Addon loads without Lua errors in chat.
- [ ] **Feature Test**: Modified feature works as expected.
- [ ] **Regression Test**: Related features (e.g., Inventory after changing CIM) still work.

### 6.3 Documentation Validation
- [ ] **File Headers**: All modified files have up-to-date headers.
- [ ] **Function Comments**: New/changed functions have complete `--[[ ]]` blocks.
- [ ] **No Orphaned TODOs**: Resolved issues have their TODOs removed.

### 6.4 Git Hygiene
- [ ] **Diff Review**: `git diff` shows only intended changes.
- [ ] **No Debug Code**: Remove `d()`, `ddebug()`, or `print()` statements.
- [ ] **Commit Message**: Use a descriptive message (e.g., `fix(inventory): resolve category filter bug`).

---

## 7. Quick Reference

### Key Directories
| Path | Purpose |
|------|---------|
| `docs/` | Project documentation |
| `lang/` | Localization string files |
| `Modules/CIM/` | Common Interface Module (shared UI) |
| `Modules/Inventory/` | Inventory enhancements |
| `Modules/Banking/` | Banking enhancements |
| `Modules/GeneralInterface/` | Tooltips, Nameplates, Resource Orbs |
| `Modules/WritUnit/` | Writ tracking |

### Important Files
| File | Purpose |
|------|---------|
| `BetterUI.txt` | Addon manifest (file load order) |
| `BetterUI.lua` | Entry point, module loading |
| `Globals.lua` | Namespace initialization, utilities |
| `BetterUI.CONST.lua` | UI constants, currency config |
| `docs/ARCHITECTURE.md` | Full architectural overview |

---

## 8. Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)**: Comprehensive project structure, module relationships, and design patterns.
- **[ChangeLog.txt](./ChangeLog.txt)**: Version history and release notes.
- **[Description.txt](./Description.txt)**: User-facing addon description.
