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

Feature modules use a small set of root contracts. Follow the module's existing archetype instead of forcing every package into one shape. Create only the folders the module actually uses; do not add empty placeholder subdirectories.

- `thin-entrypoint`: `Module.lua` is the canonical root and wires init/setup while delegating runtime behavior into focused files such as `Core/` and `Setup.lua`.
- `settings-owner`: one canonical root file owns both runtime and settings seams. That root may be either `Module.lua` or `<Module>.lua`, depending on the module.
- `runtime-coordinator`: the canonical root coordinates runtime lifecycle and shared services. In most modules this is `Module.lua`; if `<Module>.lua` exists, treat it as a thin helper and move substantial runtime logic under role folders.

```
ModuleName/
├── Module.lua         # Optional canonical root (archetype-dependent)
├── <Module>.lua       # Optional helper or canonical root (archetype-dependent)
├── Constants.lua      # Optional module-specific constants
├── Core/              # Optional core logic
├── UI/                # Optional visual components
├── Lists/             # Optional list management
├── Actions/           # Optional action handlers
├── Keybinds/          # Optional keybind descriptors
├── State/             # Optional state management
├── Settings/          # Optional LAM settings
└── Templates/         # Optional XML templates
```

Examples:
- `Writs` is a `thin-entrypoint` package: [`Module.lua`](../../Modules/Writs/Module.lua) wires lifecycle hooks while [`Core/Writ.lua`](../../Modules/Writs/Core/Writ.lua) owns writ behavior.
- `Nameplates` is a `settings-owner` package with [`Nameplates.lua`](../../Modules/Nameplates/Nameplates.lua) as the canonical root. [`Settings.lua`](../../Modules/Nameplates/Settings.lua) is a helper seam owned by that root and should not own `InitModule` or panel-registration contracts.
- `ResourceOrbFrames` is also a `settings-owner` package, but its canonical root is [`Module.lua`](../../Modules/ResourceOrbFrames/Module.lua). Both shapes are supported; each module should keep one clear owner.

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
