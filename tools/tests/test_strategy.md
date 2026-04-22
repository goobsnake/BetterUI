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

### L3: Standalone Lua Runtime Tests
- **Mechanism**: Headless Lua harnesses with focused ESO stubs
- **Coverage**: Shared seams, module boundaries, and regression-prone flows
- **Key Files**: `tools/tests/test_inventory_scene_harness.lua`,
  `tools/tests/test_market_integration.lua`,
  `tools/tests/test_vendor_live_runtime_boundaries.lua`
- **Purpose**: Exercise production-backed behavior without mirroring module
  logic in local test copies
- **Rule**: Coverage credit must come from executed behavior (`dofile`,
  runtime assertions), not dead-code coverage markers

### L4: In-game Integration Testing
- **Method**: ESO load verification + manual testing
- **Coverage**: Critical user paths
- **Purpose**: Verify addon works in the real client/runtime environment

## Runner and suite shape

- `lua tools/tests/run_all_tests.lua` auto-discovers every `test_*.lua` file
  under `tools/tests/` except the runner itself.
- The runner now combines command status with failure signatures such as
  `lua:`, `stack traceback:`, `FAILED`, and `Failed:` instead of trusting a
  success banner alone.
- Shared test-only helpers live under `tools/tests/lib/`; keep this surface
  small and oriented around reusable infrastructure rather than feature logic.
- Avoid `if false then dofile(...) end` coverage wiring. If a file needs test
  coverage, execute a real behavior path through that file.

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

### Source Assertions vs. Behavior
- Prefer behavior tests for high-risk seams (authorization, batch actions,
  bootstrap orchestration, lifecycle transitions).
- Keep source-level assertions only for static contracts that cannot be
  validated meaningfully at runtime (for example, narrow typed-doc coverage).

## Test Execution

### Local Development
```bash
# Run all static checks
bash tools/tests/run_syntax_check.sh
bash tools/tests/validate_manifest.sh
bash tools/tests/validate_types.sh

# Run standalone Lua tests
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
| Runtime Harness Coverage | Growing | Critical flows covered |
| EmmyLua Annotation | ~60% | 90% |
| Unit Test Coverage | ~41% | 70% |

### Tracking
- Syntax/Manifest: Automated in CI
- Runtime harnesses: Tracked via `run_all_tests.lua`
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
