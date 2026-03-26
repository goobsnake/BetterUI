# BetterUI Test Strategy

## Testing Pyramid

BetterUI implements a 4-layer testing pyramid:

```
    ^
   / \      L4: Integration Testing (ESO addon load)
  /---\     
 /     \    L3: SafeExecute Boundary Testing (runtime verification)
/-------\
|       |   L2: Manifest Consistency Validation
|       |
|-------|
|       |   L1: Syntax Validation (luac -p)
|_______|
```

### L1: Syntax Validation
- **Tool**: `luac -p` (parse-only mode)
- **Coverage**: 100% of Lua files
- **Script**: `tools/tests/run_syntax_check.sh`
- **Purpose**: Catch syntax errors before runtime

### L2: Manifest Consistency
- **Tool**: Custom shell script
- **Coverage**: All `BetterUI.txt` entries
- **Script**: `tools/tests/validate_manifest.sh`
- **Purpose**: Ensure referenced files exist on disk

### L3: SafeExecute Boundary Testing
- **Mechanism**: Runtime error wrapping
- **Coverage**: Every public entry point
- **Key File**: `Modules/CIM/Core/SafeExecute.lua`
- **Purpose**: Graceful error handling without UI breakage

### L4: Integration Testing
- **Method**: In-game load verification + manual testing
- **Coverage**: Critical user paths
- **Purpose**: Verify addon works in actual ESO environment

## SafeExecute as Test Infrastructure

BetterUI uses SafeExecute as its primary runtime safety net.
All module boundaries, event handlers, and keybind callbacks
are wrapped with SafeExecute to catch and report errors.

### Implementation Pattern

```lua
-- Module initialization
BETTERUI.CIM.SafeExecute(function()
    Module.Initialize()
end, "ModuleName.Initialize")

-- Event handler registration
EVENT_MANAGER:RegisterForEvent("EventName", function(eventCode, ...)
    BETTERUI.CIM.SafeExecute(function(...)
        Module.HandleEvent(...)
    end, "ModuleName.HandleEvent")
end)
```

### Error Handling Behavior

1. **Catch**: All errors are caught via `pcall`
2. **Log**: Errors are logged with context (module/function name)
3. **Report**: Stack traces are preserved for debugging
4. **Recover**: Execution continues; addon remains functional

## Coverage Strategy

### Entry Points
Every public entry point must be wrapped with SafeExecute:
- Module `Initialize()` functions
- Event handlers (all `RegisterForEvent` callbacks)
- Keybind callbacks
- UI control event handlers (`OnMouseUp`, `OnEffectivelyShown`, etc.)
- Slash command handlers

### Settings Access
All settings access goes through typed accessor protocols:
- Boolean settings: `GetBooleanSetting()` with type validation
- Number settings: `GetNumberSetting()` with range validation
- String settings: `GetStringSetting()` with default fallback

### Migration Paths
Settings migrations have version-gated validation:
- Each migration has a source and target version
- Validation ensures migrations run in correct order
- Rollback procedures for failed migrations

## Test Execution

### Local Development
```bash
# Run all static checks
bash tools/tests/run_syntax_check.sh
bash tools/tests/validate_manifest.sh
bash tools/tests/validate_types.sh

# Run unit tests
lua tools/tests/run_all_tests.lua
```

### CI/CD Pipeline
```yaml
test:
  stage: test
  script:
    - bash tools/tests/run_syntax_check.sh
    - bash tools/tests/validate_manifest.sh
    - bash tools/tests/validate_types.sh
    - lua tools/tests/run_all_tests.lua
```

## Metrics and Goals

### Current Metrics
| Metric | Current | Target |
|--------|---------|--------|
| Syntax Coverage | 100% | 100% |
| Manifest Coverage | 100% | 100% |
| SafeExecute Coverage | ~75% | 100% |
| EmmyLua Annotation | ~60% | 90% |
| Unit Test Coverage | ~41% | 70% |

### Tracking
- Syntax/Manifest: Automated in CI
- SafeExecute: Manual audit per module
- EmmyLua: Tracked via `validate_types.sh`
- Unit Tests: Tracked via test runner output

## Risk Areas

### High Priority
1. Banking transaction handlers (item loss risk)
2. Settings migrations (data corruption risk)
3. Multi-select batch operations (consistency risk)

### Medium Priority
1. Scene lifecycle callbacks
2. Tooltip generation
3. Sort comparators

### Low Priority
1. Debug/logging utilities
2. Visual only features (animations)
3. Non-critical UI elements
