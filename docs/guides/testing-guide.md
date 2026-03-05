# BetterUI Testing Procedures

## Overview

While ESO addons cannot use in-game automated test frameworks, BetterUI uses **standalone Lua unit tests** for core utility functions. These tests run outside the game using a standard Lua interpreter.

---

## Automated Tests (Standalone)

Located in `tools/tests/`, these test files can be run without ESO:

### Test Files

| File | Module | Tests |
|------|--------|-------|
| `test_number_formatting.lua` | NumberFormatting | Comma delimiting, suffixes (K/M/B), percentages |
| `test_event_registry.lua` | EventRegistry | Registration tracking, bulk unregister |
| `test_deferred_task.lua` | DeferredTask | Scheduling, cancellation, debounce |
| `test_deprecation_registry.lua` | DeprecationRegistry | Warnings, shims, one-time logging |
| `test_dependency_resolver.lua` | DependencyResolver | Circular deps, topological sort |
| `test_feature_flags.lua` | FeatureFlags | Defaults, overrides, persistence |
| `test_safe_execute.lua` | SafeExecute | Error boundaries, nil handling |
| `test_utilities.lua` | Utilities | WrapValue, SafeCall, SafeIcon |
| `test_sort_comparators.lua` | Sort helpers | Multi-key sorting, nil handling |

### Running Tests

```bash
# Run all tests
lua tools/tests/run_all_tests.lua

# Run individual test
lua tools/tests/test_dependency_resolver.lua

# Syntax validation
luac -p tools/tests/*.lua
```

### Creating New Tests

1. Create `test_<module_name>.lua` in `tools/tests/`
2. Add minimal ESO stubs for required globals
3. Inline or import the module logic under test
4. Use the test harness pattern with `assert_equal`/`assert_true`
5. Return exit code 1 on failure for CI integration

---

## Manual Testing (In-Game)

---

## Pre-Testing Checklist

1. **Backup SavedVariables** - Copy `Documents/Elder Scrolls Online/live/SavedVariables/BetterUI.lua`
2. **Enable debug output** - `/script BETTERUI.Debug("test")` should print `[BETTERUI] test`
3. **Clear UI errors** - `/reloadui` before starting session

---

## Module: Inventory

### Basic Functionality
- [ ] Open inventory (gamepad mode)
- [ ] Categories load and display correctly
- [ ] Item sorting works (by type, name, level)
- [ ] Item icons and names display correctly

### Keybind Actions
- [ ] **A button** - Primary action (equip/use)
- [ ] **X button** - Secondary action (quickslot/compare/link)
- [ ] **Y button** - Actions menu opens with valid options
- [ ] **L-Stick** - Stack all items
- [ ] **R-Stick** - Switch between bags
- [ ] **LB/RB** - Category navigation

### Search
- [ ] Search box appears and accepts input
- [ ] Filter updates list in real-time
- [ ] Clear search restores full list
- [ ] D-pad down exits search to list

### Tooltips
- [ ] Hover shows item tooltip
- [ ] Compare tooltip shows (if enabled)
- [ ] Trade prices show (if MM/ATT/TTC enabled)

---

## Module: Banking

### Basic Functionality
- [ ] Visit bank NPC
- [ ] Banking UI opens
- [ ] Category tabs navigate correctly
- [ ] Items display with correct icons/names

### Keybind Actions
- [ ] **A button** - Deposit/withdraw
- [ ] **Y button** - Actions menu
- [ ] **LB/RB** - Category navigation
- [ ] **L-Stick** - Stack all

### Search
- [ ] Search filters bank items
- [ ] Clear search works

---

## Module: Store (After Override Removal)

### Vendor Interaction
- [ ] Visit any vendor NPC
- [ ] Store UI opens without errors
- [ ] Buy items works
- [ ] Sell items works
- [ ] Buyback works
- [ ] Repair works (at armorer)

---

## Module: Resource Orbs

### Display
- [ ] Health/Magicka/Stamina orbs display
- [ ] Values update correctly
- [ ] Ultimate bar displays

---

## Regression Tests

### After Code Changes
1. `/reloadui` - No Lua errors
2. Open inventory - Verify fully functional
3. Visit bank - Verify fully functional
4. Visit store - Verify fully functional

### Backward Compatibility
- [ ] `ddebug("test")` works (deprecated alias)
- [ ] `BETTERUI_GamepadInventory_DefaultItemSortComparator` works (deprecated alias)

---

## Error Reporting

If errors occur:
1. Note exact steps to reproduce
2. Copy error message from chat
3. Check `Documents/Elder Scrolls Online/live/Logs/UIErrors.log`
