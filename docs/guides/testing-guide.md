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
| `test_feature_flags.lua` | FeatureFlags | Defaults, overrides, persistence |
| `test_safe_execute.lua` | SafeExecute | Error boundaries, nil handling |
| `test_utilities.lua` | Utilities | WrapValue, SafeCall, SafeIcon |
| `test_sort_comparators.lua` | Sort helpers | Multi-key sorting, nil handling |
| `test_batch_safety.lua` | BatchConfig | Guard-clause validation, batch safety checks |
| `test_nameplates_reset.lua` | Nameplates | Settings reset, font restoration |
| `test_settings_group_resets.lua` | SettingsReset | Per-group reset isolation |
| `test_settings_reset.lua` | SettingsReset | Full reset, partial reset, defaults |
| `test_tooltip_helpers.lua` | Tooltips | Tooltip formatting, nil handling |

> The table above lists the original core-utility suites. The harness now ships a much larger set of module/contract suites under `tools/tests/` (run them all via `run_all_tests.lua`).

#### v3.06 Regression Coverage

These suites were added/extended alongside the v3.06 fix batch:

| File | Covers |
|------|--------|
| `test_cim_batch_lock_policy.lua`, `test_destroy_policy_contracts.lua` | Batch slot-identity re-validation at execution; `ProtectionPolicy.CanDestroyItem` fails closed on a nil `slotType` and on an unavailable `ZO_InventorySlot_CanDestroyItem` probe |
| `test_inventory_junk_carousel_keybinds.lua` | PB-002 — keybind-state Push/Pop, deferred junk-toggle restoration, LB/RB carousel survives a single junk action |
| `test_inventory_primary_action_inplace_update.lua` | PB-006 — primary-action re-resolution on in-place inventory updates |
| `test_inventory_control_name_length.lua` | PB-005 — pooled control names stay under the engine's 63-char limit after the `BUI_GpInv` rename |
| `test_trading_house_sell_filter.lua` | Sell-tab `IsItemSellableOnTradingHouse` / per-guild `CanSellOnTradingHouse` gating; off-scene guild-change guard |
| `test_trading_house_search_presets.lua` | API-version-stamped presets load under `SafeExecute` (corrupt/cross-version presets fail gracefully) |
| `test_vendor_batch_action_counts.lua` | Vendor "Buy All" gating (locked / requirement-failing entries) and batch-identity re-validation |
| `test_tooltip_helpers.lua` | Enhanced-tooltip toggle-off restore and set-collection status tag |
| `test_front_bar_manager.lua` | ORB-001 — `GetSlotAbilityCost` ultimate-slot argument order / cost |
| `test_companion_actions_source.lua` | Companion equipment rows tag `SLOT_TYPE_GAMEPAD_INVENTORY_ITEM` |
| `test_tabbar_selection_dispatch.lua` | MPR-3 — `BETTERUI_TabBarScrollList:SetSelectedIndex` fires the selection callback exactly once (carousel + non-carousel); `SetSelectedIndexWithoutAnimation` passes `forceAnimation=false` and routes suppression to `UpdateAnchors` |
| `test_orb_latch.lua` | MPR-4 — drives the real `ExperienceBar:Update` / orb-label bar code and asserts no redundant `SetText`/`SetFont` on unchanged font/dimensions/anchors/value (per-frame HUD latching) |
| `test_tooltip_helpers.lua` | MPR-4 (extended) — the `AddTopLinesToTopSection` suppression hook returns `true` only in BetterUI-enhanced contexts and `false` otherwise (native/other-addon top lines preserved); PB-004 set-collection tag still appears in-enhancement |

> **Load-order note**: any standalone test that `dofile`s `Inventory/Core/Utils.lua` must load `CIM/Core/Utilities.lua` first — `BETTERUI.Inventory.Utils` delegates slot-identity helpers to `BETTERUI.CIM.Utils` (CIM-before-Inventory).

### Running Tests

```bash
# Run all tests
lua tools/tests/run_all_tests.lua

# Run individual test
lua tools/tests/test_feature_flags.lua

# Syntax validation
luac -p tools/tests/*.lua

# Static validation — run as part of every regular test pass, before commit
bash tools/tests/run_syntax_check.sh      # Lua syntax (luac -p over Modules/)
bash tools/tests/validate_manifest.sh     # BetterUI.txt manifest entries exist
bash tools/tests/validate_types.sh        # EmmyLua annotation coverage
bash tools/tests/validate_planning.sh     # planning docs hold only open items
```

The static validators above are part of the **regular test routine** — run them together with `run_all_tests.lua` before every commit. `validate_planning.sh` fails if `docs/planning/{priority-backlog,feature-requests,project-improvements}.md` still contains an item marked completed or discarded in place; when it does, migrate completed work to `completed-improvements.md` and delete discarded items, then re-run.

### Creating New Tests

1. Create `test_<module_name>.lua` in `tools/tests/`
2. Add minimal ESO stubs for required globals (add a `BETTERUI.Log` stub only if the test asserts on debug output — production call sites are nil-guarded, so tests run without one)
3. Inline or import the module logic under test
4. Use the test harness pattern with `assert_equal`/`assert_true`
5. Return exit code 1 on failure for CI integration

---

## Manual Testing (In-Game)

---

## Pre-Testing Checklist

1. **Backup SavedVariables** - Copy `Documents/Elder Scrolls Online/live/SavedVariables/BetterUI.lua`
2. **Enable builog output** - Logging streams to `live/Logs/Interface.log` in real time (tail it while you play; filter with `grep '[BUI]'`). Pick a preset by intent:
   - `/builog preset info` - INFO/WARN/ERROR milestones, payloads off, tight live-play budget.
   - `/builog preset watch` - DEBUG+ with AI context, snapshots, and flow landmarks; default for live play-test diagnosis.
   - `/builog preset debug` - DEBUG+ without watch enrichment; useful for focused developer flow checks.
   - `/builog preset inspect` - TRACE+ with watch enrichment; richest stream for short repro windows.
   - `/builog preset trace` - TRACE+ without watch enrichment; use only when you need raw step detail.
   - `/builog preset off` - stop file logging and restore error popups.

   Lower-level commands still work under the presets: `/builog on|off`, `/builog level <trace|debug|info|warn|error>`, `/builog mark <text>`, `/builog recent|errors [n]`, `/builog capture [secs]`, `/builog screenshot [label]`, `/builog snapshot`, `/builog check` or `/builog test`, and `/builog status`. `chat on|off` and `popups on|off` are compatibility no-ops for BetterUI breadcrumbs; builog stays file-only while enabled. Logging is inert until enabled, so legacy `/script BETTERUI.Debug("test")` (now routed through `BETTERUI.Log`) only writes once logging is enabled. See [builog-developer-guide.md](../reference/builog-developer-guide.md) for instrumentation standards.
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

---

## Error Reporting

If errors occur:
1. Note exact steps to reproduce
2. Copy error message from chat
3. Check `Documents/Elder Scrolls Online/live/Logs/UIErrors.log`
