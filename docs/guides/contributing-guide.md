# Contributing to BetterUI

> Thank you for your interest in contributing to BetterUI!

## Getting Started

1. **Read the Architecture**: Review [architecture.md](../reference/architecture.md) before making changes.
2. **Check Existing Code**: Follow established patterns in the files you're modifying.
3. **Use Local Variables**: Never add unintentional globals; use `local` for file-level variables.

## Code Standards

### Naming Conventions

| Scope | Convention | Example |
|-------|------------|---------|
| Globals | `BETTERUI.Module.Class` | `BETTERUI.CIM.Utils.SafeCall` |
| Locals | `camelCase` | `currentCategory` |
| Constants | CamelCase in tables | `BETTERUI.CIM.CONST.TIMING` |

### File Headers

Every Lua file must begin with:

```lua
--[[
File: Modules/[ModuleName]/[FileName].lua
Purpose: [High-level summary]
Author: BetterUI Team
Last Modified: [YYYY-MM-DD]
]]
```

### Function Documentation

Important functions must include:

```lua
--[[
Function: BETTERUI.Module.FunctionName
Description: What the function does.
Rationale: Why it exists.
Mechanism: How it works.
param: paramName (type) - Description.
return: type - Description.
]]
```

### TODOs

Use actionable, typed TODOs:
- `TODO(refactor):` Code works but needs improvement
- `TODO(cleanup):` Dead code or formatting issues
- `TODO(fix):` Known bugs
- `TODO(optimization):` Performance improvements

**Remove TODOs once resolved.**

## Module Structure

All feature modules follow the **Minimal Root** pattern:

```
ModuleName/
├── Constants.lua      # Module-specific constants
├── Module.lua         # Entry point
├── Core/              # Core logic
├── UI/                # Visual components
├── Lists/             # List management
├── Actions/           # Action handlers
├── Keybinds/          # Keybind descriptors
├── State/             # State management
├── Settings/          # LAM settings
└── Templates/         # XML templates
```

## ESO-Specific Guidelines

- **Event Management**: Always unregister events when no longer needed
- **Performance**: Avoid expensive operations in `OnUpdate`; use `zo_callLater` for deferred work
- **API Compatibility**: Check for API existence before calling (e.g., `if GetTomePoints then ... end`)
- **Shared Code**: Place in `Modules/CIM/` - do NOT create new "Shared" folders

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing nil-checks | Always check: `if tbl and tbl.sub then` |
| Leaving `d()` debug statements | Remove before committing |
| Removing comments during refactoring | Update comments, don't delete |
| Hardcoding magic numbers | Extract to `Constants.lua` |

## Testing

ESO addons cannot use automated test frameworks. Before committing:

1. **Syntax Check**: `luac -p <file>`
2. **In-Game Test**: Addon loads without errors; feature works; no regressions
3. **Git Review**: `git diff` shows only intended changes

## Pull Request Checklist

- [ ] Code follows project style conventions
- [ ] File headers are up-to-date
- [ ] Function documentation is complete
- [ ] No debug statements left behind
- [ ] Changes tested in-game
- [ ] Commit message follows conventional format (e.g., `feat(module):`, `fix(module):`)

## Questions?

Open an issue or reach out to the maintainers.
