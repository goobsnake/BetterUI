# BetterUI Test Infrastructure

## Overview

This directory contains the BetterUI test infrastructure: standalone Lua tests,
static validation scripts, and a small shared helper surface for test-only
runner support.

## Testing Pyramid

BetterUI follows a 4-level testing strategy:

```
        /\
       /  \     L4: Integration Testing (ESO addon load)
      /----\
     /      \   L3: SafeExecute Boundary Testing
    /--------\ 
   /          \ L2: Manifest Consistency Validation
  /------------\
 /              \ L1: Syntax Validation (luac -p)
/________________\
```

### Level 1: Syntax Validation
- **Purpose**: Ensure all Lua files compile without syntax errors
- **Tool**: `luac -p` (Lua compiler in parse-only mode)
- **Script**: `run_syntax_check.sh`
- **Coverage Goal**: 100% of Lua files in `Modules/`
- **CI Integration**: Runs on every PR and push to main

### Level 2: Manifest Consistency
- **Purpose**: Validate that `BetterUI.txt` manifest references only existing files
- **Script**: `validate_manifest.sh`
- **Coverage Goal**: All file entries in manifest
- **CI Integration**: Runs on every PR and push to main

### Level 3: SafeExecute Boundary Testing
- **Purpose**: Runtime safety net for error catching and reporting
- **Mechanism**: All module boundaries, event handlers, and keybind callbacks wrapped with `SafeExecute`
- **Coverage Goal**: Every public entry point
- **Files**: See `test_safe_execute.lua`

### Level 4: Integration Testing
- **Purpose**: Verify ESO addon loads correctly in game environment
- **Method**: Manual testing + automated load verification
- **Coverage Goal**: Critical user paths (inventory open, banking, item transfers)

## Test Categories

### Syntax and Static Tests
| Test | Script | Purpose |
|------|--------|---------|
| Syntax Check | `run_syntax_check.sh` | Validate Lua syntax |
| Manifest Check | `validate_manifest.sh` | Validate manifest entries |
| Type Coverage | `validate_types.sh` | Check EmmyLua annotation coverage |
| Planning Hygiene | `validate_planning.sh` | Backlog/feature/plan docs hold only open items (no completed/discarded left in place) |

### Runtime Unit Tests
| Test | File | Purpose |
|------|------|---------|
| SafeExecute | `test_safe_execute.lua` | Error boundary testing |
| Deferred Task | `test_deferred_task.lua` | Task scheduling safety |
| Event Registry | `test_event_registry.lua` | Event handler management |
| Feature Flags | `test_feature_flags.lua` | Toggle system testing |
| Batch Safety | `test_batch_safety.lua` | Multi-select operation safety |
| Inventory Scene Harness | `test_inventory_scene_harness.lua` | Production-backed inventory filtering, tooltips, and batch actions |
| Number Formatting | `test_number_formatting.lua` | Localization formatting |
| Sort Comparators | `test_sort_comparators.lua` | Sort function validation |
| Settings Reset | `test_settings_reset.lua` | Settings reset validation |
| Settings Group Resets | `test_settings_group_resets.lua` | Group reset testing |
| Tooltip Helpers | `test_tooltip_helpers.lua` | Tooltip utility testing |
| Utilities | `test_utilities.lua` | Core utility function testing |
| Nameplates Reset | `test_nameplates_reset.lua` | Nameplates settings reset |

## How to Run Tests

### Run Static Validation
```bash
bash tools/tests/run_syntax_check.sh
bash tools/tests/validate_manifest.sh
bash tools/tests/validate_types.sh
bash tools/tests/validate_planning.sh
```

### Run Individual Lua Tests
```bash
lua tools/tests/test_safe_execute.lua
lua tools/tests/test_deferred_task.lua
```

### Run Lua Tests via Test Runner
```bash
# From repository root
lua tools/tests/run_all_tests.lua
```

`run_all_tests.lua` auto-discovers every `test_*.lua` file under
`tools/tests/` except the runner itself. It captures per-test output and uses
both command status and failure signatures (`lua:`, `stack traceback:`,
`FAILED`, `Failed:`) when classifying results.

## How to Add New Tests

### Adding a Syntax/Manifest Test
No changes needed - these are automatically generated from the file structure.

### Adding a Unit Test

1. Create a new test file: `tools/tests/test_<feature_name>.lua`
2. Prefer direct runtime/import coverage over mirrored implementation logic.
3. Follow the local test style used by the suite:

```lua
--[[
File: tools/tests/test_<feature_name>.lua
Purpose: <What this test validates>
Usage:
  lua tools/tests/test_<feature_name>.lua
]]

-- Test counter
local passed = 0
local failed = 0

-- Helper function
local function assertEqual(actual, expected, message)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", message, tostring(expected), tostring(actual)))
    end
end

-- Run tests
print("[<Feature Name>]")

-- Add your test cases here
-- assertEqual(actual, expected, "Test description")

if failed > 0 then
    error(string.format("test_<feature_name>.lua failed with %d failure(s)", failed))
end

print(string.format("test_<feature_name>.lua: %d passed", passed))
```

No manual registration is needed; `run_all_tests.lua` auto-discovers
`test_*.lua`.

### Shared helpers

Shared test-only helpers live under `tools/tests/lib/`. Keep this surface
small and focused on infrastructure that is reused across the suite (for
example, the runner classification helpers in
`tools/tests/lib/TestRunnerSupport.lua`).

### Coverage wiring for delayed imports

If a test needs a long stub/setup section before it can safely `dofile` the
production module, keep the `dofile` on an executable path in the same test
run (for example via a helper you call after setup completes). Avoid
non-executing coverage hints such as `if false then dofile(...) end`; coverage
should come from code paths that actually execute.

## Coverage Goals

### Current Status
- Syntax validation: ~100%
- Manifest validation: ~100%
- Runtime unit tests: ~41%
- EmmyLua type annotations: Tracked via `validate_types.sh`

### Target Status
- L1 Syntax: 100%
- L2 Manifest: 100%
- L3 SafeExecute: 100% of public entry points
- L4 Integration: Critical paths covered

## CI Integration

### GitHub Actions Workflow
```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Syntax Check
        run: bash tools/tests/run_syntax_check.sh
      - name: Manifest Check
        run: bash tools/tests/validate_manifest.sh
      - name: Type Coverage Check
        run: bash tools/tests/validate_types.sh
```

### Pre-commit Hooks
Add to `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: local
    hooks:
      - id: lua-syntax
        name: Lua Syntax Check
        entry: bash tools/tests/run_syntax_check.sh
        language: system
        files: \.lua$
```

## SafeExecute as Test Infrastructure

BetterUI uses `SafeExecute` as its primary runtime safety net. All module boundaries, event handlers, and keybind callbacks are wrapped with `SafeExecute` to catch and report errors without crashing the addon.

### Usage Pattern
```lua
-- Wrap module entry points
BETTERUI.CIM.SafeExecute("ModuleName.Init", function()
    -- Module initialization code
end)

-- Wrap event handlers
EVENT_MANAGER:RegisterCallback(EVENT_NAME, function(...)
    BETTERUI.CIM.SafeExecute("ModuleName.EventHandler", function(...)
        -- Event handling code
    end, ...)
end)
```

### Benefits
1. Errors are caught and logged without breaking the addon
2. Error context includes the module/function name
3. Stack traces are preserved for debugging
4. Users see graceful degradation instead of UI breakage

## Settings and Type Safety

### Settings Access Protocol
All settings access goes through typed accessor protocols:

```lua
-- Type-safe settings access
--- @param key string The setting key
--- @return boolean
function Module.GetBooleanSetting(key)
    local value = BETTERUI.Settings.Modules.ModuleName[key]
    if type(value) == "boolean" then
        return value
    end
    return false -- default
end
```

### Migration Path Validation
Settings migrations have version-gated validation:

```lua
-- Version-gated migration
if savedVars.version < 3 then
    -- Migrate old settings format
    MigrateV2ToV3(savedVars)
    savedVars.version = 3
end
```

## Debugging Test Failures

### Syntax Errors
```bash
# Get detailed error
luac -p Modules/Path/To/File.lua
```

### Manifest Errors
```bash
# Check specific manifest entry
grep "Modules/Path/To/File.lua" BetterUI.txt
ls -la Modules/Path/To/File.lua
```

### Runtime Test Failures
```bash
# Run with verbose output
lua tools/tests/test_<name>.lua -v
```

## Contributing

When contributing new features:

1. Add corresponding unit tests in `tools/tests/`
2. Ensure all Lua files pass syntax validation
3. Update manifest if adding new files
4. Add EmmyLua annotations for type safety
5. Wrap public entry points with `SafeExecute`

## Resources

- [Lua Test Framework Documentation](https://luaunit.readthedocs.io/)
- [ESO Addon Development Guide](https://wiki.esoui.com/Getting_Started)
- [EmmyLua Annotation Reference](https://emmylua.github.io/annotation.html)
