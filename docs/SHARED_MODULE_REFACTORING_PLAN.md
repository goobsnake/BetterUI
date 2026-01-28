# Shared Module Refactoring Plan

## Overview

This document outlines a phased approach to refactor the **Inventory** and **Banking** modules to share common code through the **CIM (Common Interface Module)**. The goal is to reduce code duplication, improve maintainability, and ensure consistent behavior across both modules.

## Current State Analysis

### Identified Duplicate Systems

| System | Inventory Location | Banking Location | Shared Location (Target) |
|--------|-------------------|------------------|--------------------------|
| **Position Persistence** | `State/PositionManager.lua` | `State/StateManager.lua` | `CIM/Core/PositionManager.lua` |
| **Header/Tab Management** | `Core/HeaderManager.lua` | `UI/HeaderManager.lua` | `CIM/UI/HeaderManager.lua` |
| **List Management** | `Lists/ItemListManager.lua` | `Lists/BankListManager.lua` | Already uses `CIM.CreateItemEntryData` |
| **Keybind Initialization** | `Keybinds/InventoryKeybinds.lua` | `Keybinds/KeybindManager.lua` | Partial: `CIM/Keybinds/KeybindHelpers.lua` |
| **Category Definitions** | Uses `CIM/Core/CategoryDefinitions.lua` | Uses `CIM/Core/CategoryDefinitions.lua` | ✅ Already shared |
| **Search Integration** | Custom implementation | Custom implementation | `CIM/Core/SearchManager.lua` |
| **Actions Dialog** | `Actions/ItemActionsDialog.lua` | Uses CIM Actions | `CIM/Actions/ActionDialog.lua` |

### Patterns Already Shared in CIM

The following systems have already been consolidated:
- `CategoryDefinitions.lua` - Category filtering logic
- `CreateItemEntryData()` - Item entry creation for lists
- `SettingsFactory.lua` / `IconSettingsFactory.lua` - Settings generation
- `SearchManager.lua` - Text search logic
- `KeybindHelpers.lua` - Trigger keybind creation

---

## Phase 1: Position Persistence Manager (Priority: HIGH)

### Objective
Create a shared `BETTERUI.CIM.PositionManager` that both Inventory and Banking can use for per-category position saving/restoring.

### Current Problems
1. **Duplicate Logic**: Both modules implement save/restore with slight variations
2. **Bug Surface**: Recent bugs (rapid navigation corruption) had to be fixed in both places
3. **Inconsistent API**: Inventory uses `uniqueId + index`, Banking uses only `index`

### Proposed API

```lua
BETTERUI.CIM.PositionManager = {
    -- Core storage (namespaced by module + category)
    _storage = {},  -- Structure: { [moduleName] = { [categoryKey] = { index, uniqueId } } }

    -- Save current list position for a module/category
    SavePosition = function(moduleName, categoryKey, list)
        -- Extracts selectedIndex and uniqueId from list.selectedData
        -- Stores in _storage[moduleName][categoryKey]
    end,

    -- Retrieve saved position for a module/category
    GetSavedPosition = function(moduleName, categoryKey)
        -- Returns { index = N, uniqueId = "..." } or nil
    end,

    -- Restore position on a list (handles uniqueId lookup + fallback)
    RestorePosition = function(moduleName, categoryKey, list, dataList)
        -- Finds item by uniqueId in dataList, falls back to saved index
        -- Sets list selection appropriately
    end,

    -- Generate stable category key from category data
    GetCategoryKey = function(categoryData)
        -- Uses categoryData.key, categoryData.filterType, or other stable identifiers
    end,

    -- Clear saved positions for a module (e.g., on scene exit)
    ClearModule = function(moduleName) end
}
```

### Implementation Steps

1. **Create `Modules/CIM/Core/PositionManager.lua`**
   - Define the shared storage and API
   - Port common logic from Inventory's `PositionManager.lua`
   - Add module namespacing to prevent key collisions

2. **Migrate Inventory**
   - Update `ToSavedPosition()` to call `BETTERUI.CIM.PositionManager.RestorePosition()`
   - Update `SaveListPosition()` to call `BETTERUI.CIM.PositionManager.SavePosition()`
   - Keep module-specific wrapper functions for backwards compatibility

3. **Migrate Banking**
   - Update `ReturnToSaved()` to call shared API
   - Update `SaveListPosition()` to call shared API
   - Remove redundant per-mode storage (use only per-category)

4. **Testing**
   - Verify slow navigation position persistence
   - Verify rapid navigation (LB/RB spam) doesn't corrupt positions
   - Verify cross-mode persistence (Withdraw/Deposit)
   - Verify Inventory/CraftBag position isolation

### Files Changed
- [NEW] `Modules/CIM/Core/PositionManager.lua`
- [MODIFY] `Modules/Inventory/State/PositionManager.lua`
- [MODIFY] `Modules/Banking/State/StateManager.lua`
- [MODIFY] `BetterUI.txt` (add new file to manifest)

### Risk Assessment
**Medium Risk** - Position persistence is critical for UX. Thorough testing required.

---

## Phase 2: Header/Tab Navigation Manager (Priority: MEDIUM)

### Objective
Create shared header management functions for carousel navigation and category cycling.

### Current Problems
1. Both modules implement `CycleCategory` with similar logic
2. Both handle `onSelectedChanged` callbacks with coalescing timers
3. The rapid navigation fix (deferred context update) is duplicated

### Proposed API

```lua
BETTERUI.CIM.HeaderNavigation = {
    -- Cycle to next/previous category in a list
    CycleCategory = function(instance, delta, options)
        -- options.categories: the category list
        -- options.getCurrentIndex: function to get current index
        -- options.setCurrentIndex: function to set new index
        -- options.onSave: function to save position before switch
        -- options.onRefresh: function to refresh list after switch
        -- options.tabBar: optional tabbar to drive selection
    end,

    -- Create coalesced selection change handler
    CreateCoalescedHandler = function(options)
        -- options.delay: coalesce delay (default 100ms)
        -- options.onSave: function to save position
        -- options.onRefresh: function to refresh after coalesce
        -- Returns a callback function suitable for onSelectedChanged
    end
}
```

### Implementation Steps

1. **Create `Modules/CIM/UI/HeaderNavigation.lua`**
2. **Migrate Banking `CycleCategory`** as first consumer
3. **Migrate Inventory `OnTabNext/OnTabPrev`**
4. **Add deferred index update pattern to shared handler**

### Files Changed
- [NEW] `Modules/CIM/UI/HeaderNavigation.lua`
- [MODIFY] `Modules/Banking/UI/HeaderManager.lua`
- [MODIFY] `Modules/Inventory/Core/HeaderManager.lua`
- [MODIFY] `Modules/Inventory/Core/Utils.lua`

### Risk Assessment
**Medium Risk** - Navigation UX is critical. Step-by-step migration with testing.

---

## Phase 3: List Management Consolidation (Priority: MEDIUM)

### Objective
Further consolidate list setup, filtering, and rendering patterns.

### Current Shared Components (Already Done)
- `BETTERUI.CIM.CreateItemEntryData()` - Creates entry data for items
- `BETTERUI.CIM.AddItemEntryToList()` - Adds entries with category headers
- Category matching via `BETTERUI.Inventory.Categories.DoesItemMatchCategory()`

### Additional Consolidation Opportunities

1. **Batch Processing Pattern**
   - Both modules could use a shared batch processor for large lists
   - Extract `ProcessScrollListBatch` pattern to CIM

2. **Sort Comparators**
   - Move `DefaultSortComparator` to CIM (already generic)

3. **Empty List Handling**
   - Standardize "no items" message handling

### Files Changed
- [NEW] `Modules/CIM/Lists/BatchProcessor.lua` (optional)
- [MODIFY] `Modules/CIM/Lists/ItemEntryFactory.lua`

### Risk Assessment
**Low Risk** - Incremental improvements to existing patterns.

---

## Phase 4: Keybind Consolidation (Priority: LOW)

### Objective
Reduce duplicated keybind definition patterns.

### Current State
- `CIM/Keybinds/KeybindHelpers.lua` already provides `CreateListTriggerKeybinds()`
- Both modules define similar keybind patterns for:
  - Y (Actions menu)
  - L-Stick (Stack items)
  - Quaternary (Clear search)

### Consolidation Opportunities

1. **Standard Keybind Factories**
   ```lua
   BETTERUI.CIM.Keybinds.CreateActionsKeybind(options)
   BETTERUI.CIM.Keybinds.CreateStackKeybind(options)
   BETTERUI.CIM.Keybinds.CreateSearchClearKeybind(options)
   ```

2. **Keybind Strip Management**
   - Shared add/remove/update helpers

### Files Changed
- [MODIFY] `Modules/CIM/Keybinds/KeybindHelpers.lua`
- [MODIFY] `Modules/Inventory/Keybinds/InventoryKeybinds.lua`
- [MODIFY] `Modules/Banking/Keybinds/KeybindManager.lua`

### Risk Assessment
**Low Risk** - Keybind definitions are straightforward.

---

## Phase 5: Search Integration Standardization (Priority: LOW)

### Objective
Ensure both modules use `CIM/Core/SearchManager.lua` consistently.

### Current State
- `SearchManager.lua` exists but may not be fully utilized by both modules
- Both modules have custom search focus/blur handling

### Consolidation Opportunities
1. Standardize search header initialization
2. Standardize search keybind registration
3. Standardize focus/blur behavior

### Files Changed
- [MODIFY] `Modules/CIM/Core/SearchManager.lua`
- [MODIFY] `Modules/Inventory/Core/HeaderManager.lua`
- [MODIFY] `Modules/Banking/UI/HeaderManager.lua`

### Risk Assessment
**Low Risk** - Search is supplementary functionality.

---

## Implementation Timeline

| Phase | Description | Estimated Effort | Priority | Status |
|-------|-------------|------------------|----------|--------|
| **1** | Position Persistence Manager | 2-3 hours | HIGH | ✅ Complete |
| **2** | Header/Tab Navigation | 2-3 hours | MEDIUM | ✅ Complete |
| **3** | List Management | 1-2 hours | MEDIUM | ✅ Complete |
| **4** | Keybind Consolidation | 1-2 hours | LOW | ✅ Complete (factories exist) |
| **5** | Search Standardization | 1 hour | LOW | ✅ Complete (modules use CIM) |
| **6** | Action Dialog Callbacks | 1-2 hours | MEDIUM | ⏸️ Deferred |
| **7** | Utility Functions | 1 hour | MEDIUM | ✅ Complete |
| **8** | Settings Defaults | 1-2 hours | LOW | ✅ Complete |
| **9** | Timing Constants | 0.5 hours | LOW | ✅ Complete |
| **10** | Slot Actions Pattern | 2-3 hours | LOW | ⏸️ Deferred |

**Total Estimated Effort**: 13-20 hours
**Completed**: Phases 1, 2, 3, 4, 5, 7, 8, 9 (~10-13 hours)
**Deferred**: Phases 6 (module-specific), 10 (complex)


---

## Testing Requirements

### Per-Phase Testing
Each phase should include:
1. **Unit verification** - Syntax check (`luac -p`)
2. **Functional testing** - In-game verification of affected features
3. **Regression testing** - Ensure existing functionality is not broken

### Critical Test Cases

| Feature | Test Case |
|---------|-----------|
| Position Persistence | Navigate categories, scroll, navigate back - position restored |
| Position Persistence | Rapid LB/RB spam - positions not corrupted |
| Position Persistence | Mode switch (Withdraw/Deposit) - positions isolated |
| Header Navigation | Carousel animation works correctly |
| Header Navigation | Tab click works correctly |
| List Management | Large lists load without freezing |
| Keybinds | All buttons function as expected |
| Search | Filter works, clear restores list |
| Action Dialog | Y-menu opens with correct actions in both modules |
| Action Dialog | Split Stack dialog works and list refreshes after |
| Utility Functions | List selection returns correct data in all contexts |
| Utility Functions | Sort order is consistent between Inventory and Banking |
| Settings | Font changes apply correctly in both modules |
| Settings | Icon toggles work with live refresh |
| Timing | Rapid navigation doesn't cause UI glitches |
| Slot Actions | Primary action (A button) works correctly |

---

## Success Criteria

1. **Reduced Code Duplication**: At least 30% reduction in duplicated logic
2. **Single Source of Truth**: Bug fixes apply to all modules automatically
3. **Consistent Behavior**: Inventory and Banking behave identically for shared features
4. **No Regressions**: All existing functionality works as before

---

## Phase 6: Action Dialog Callback Integration (Priority: MEDIUM)

### Objective
Consolidate the duplicate callback registration patterns for action dialogs (Y-menu).

### Current Problems
1. **Duplicate Callbacks**: Both modules register identical callbacks:
   - `BETTERUI_EVENT_ACTION_DIALOG_SETUP`
   - `BETTERUI_EVENT_ACTION_DIALOG_FINISH`
   - `BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM`
   - `BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED`
2. **Identical Logic**: The `CallbackSplitStackFinished` function is nearly identical in both modules

### Proposed API

```lua
BETTERUI.CIM.ActionDialogManager = {
    -- Register standard action dialog callbacks for a module
    RegisterCallbacks = function(moduleInstance, options)
        -- options.onDialogSetup: custom setup handler
        -- options.onDialogFinish: custom finish handler
        -- options.onDialogConfirm: custom confirm handler
        -- options.onSplitStackFinished: custom split stack handler
    end,

    -- Standard split stack finished handler
    HandleSplitStackFinished = function(moduleInstance)
        -- Common refresh logic
    end
}
```

### Files Changed
- [NEW] `Modules/CIM/Actions/ActionDialogManager.lua`
- [MODIFY] `Modules/Inventory/Actions/ItemActionsDialog.lua`
- [MODIFY] `Modules/Banking/Banking.lua`

### Risk Assessment
**Medium Risk** - Action dialog timing is critical for UX.

---

## Phase 7: Utility Functions Consolidation (Priority: MEDIUM)

### Objective
Move shared utility functions from module-specific namespaces to CIM.

### Identified Duplicates

| Function | Current Location | Notes |
|----------|-----------------|-------|
| `SafeGetTargetData()` | `Inventory.Utils` | Used heavily in both modules for safe list selection |
| `DefaultSortComparator()` | `Inventory.Constants` | Already used by Banking via cross-reference |

### Proposed API

```lua
BETTERUI.CIM.Utils = {
    -- Safe retrieval of selected list item data
    SafeGetTargetData = function(list)
        if list and list.GetSelectedData then
            return list:GetSelectedData()
        end
        return nil
    end,

    -- Standard sort comparator for item lists
    DefaultSortComparator = function(left, right)
        return ZO_TableOrderingFunction(left, right, "sortPriorityName",
            BETTERUI.CIM.CONST.SORT_SCHEMA, ZO_SORT_ORDER_UP)
    end
}

-- Move sort schema to CIM
BETTERUI.CIM.CONST.SORT_SCHEMA = { ... }
```

### Implementation Steps
1. Create `BETTERUI.CIM.Utils` namespace in `Modules/CIM/Core/Utilities.lua`
2. Move `SafeGetTargetData` to CIM
3. Move `DefaultSortComparator` and `SORT_SCHEMA` to CIM
4. Update references in both modules to use CIM versions
5. Keep aliases in module namespaces for backwards compatibility

### Files Changed
- [MODIFY] `Modules/CIM/Core/Utilities.lua`
- [MODIFY] `Modules/Inventory/Constants.lua`
- [MODIFY] `Modules/Inventory/Core/Utils.lua`
- [MODIFY] `Modules/Banking/Lists/BankListManager.lua`

### Risk Assessment
**Low Risk** - Pure utility functions with clear behavior.

---

## Phase 8: Settings Defaults Initialization (Priority: LOW)

### Objective
Standardize the settings initialization pattern across modules.

### Current Problems
1. **Duplicate Default Logic**: Both modules have similar `InitModule` patterns
2. **Font Settings Duplication**: Banking manually defines font submenus that Inventory uses via factory
3. **Icon Toggle Duplication**: Already partially addressed by `IconSettingsFactory.lua`

### Consolidation Opportunities

1. **Font Settings Factory Usage**: 
   - Banking should use `BETTERUI.CIM.Settings.CreateFontSubmenuOptions()` like Inventory
   - Currently Banking manually builds its font submenus

2. **Defaults Initialization Pattern**:
   ```lua
   BETTERUI.CIM.Settings.InitializeDefaults = function(moduleName, defaults)
       local m_options = BETTERUI.Settings.Modules[moduleName]
       for key, defaultValue in pairs(defaults) do
           if m_options[key] == nil then
               m_options[key] = defaultValue
           end
       end
       return m_options
   end
   ```

### Files Changed
- [MODIFY] `Modules/CIM/Core/SettingsFactory.lua`
- [MODIFY] `Modules/Banking/Settings/SettingsPanel.lua`
- [MODIFY] `Modules/Inventory/Settings/SettingsPanel.lua`

### Risk Assessment
**Low Risk** - Settings are non-critical and easily reversible.

---

## Phase 9: Timing & Delay Constants (Priority: LOW)

### Objective
Consolidate timing constants into CIM to ensure consistent behavior.

### Current Duplicates

| Constant | Inventory | Banking |
|----------|-----------|---------|
| Debounce delay | `DEBOUNCE_MS = 50` | `MOVE_COALESCE_DELAY_MS = 100` |
| Category refresh delay | `CATEGORY_REFRESH_DELAY_MS = 80` | `CATEGORY_CHANGE_DELAY_MS = 100` |
| Batch sizes | `BATCH_SIZE_INITIAL = 50` | (none) |
| Tooltip refresh | `TOOLTIP_REFRESH_DELAY_MS = 300` | (none) |

### Proposed Consolidation

```lua
BETTERUI.CIM.CONST.TIMING = {
    -- Debounce for heavy UI updates
    DEBOUNCE_MS = 50,
    
    -- Category navigation coalescing
    CATEGORY_CHANGE_DELAY_MS = 100,
    
    -- Item move coalescing
    MOVE_COALESCE_DELAY_MS = 100,
    
    -- Tooltip refresh delay
    TOOLTIP_REFRESH_DELAY_MS = 300,
    
    -- Batch processing
    BATCH_SIZE_INITIAL = 50,
    BATCH_SIZE_REMAINING = 200,
}
```

### Files Changed
- [MODIFY] `Modules/CIM/Constants.lua`
- [MODIFY] `Modules/Inventory/Constants.lua`
- [MODIFY] `Modules/Banking/Constants.lua`

### Risk Assessment
**Low Risk** - Constants are easily changed and tested.

---

## Phase 10: Slot Actions Pattern (Priority: LOW)

### Objective
Extend `CIM/Actions/GenericSlotActions.lua` to be the base for module-specific slot actions.

### Current State
- `BETTERUI.Inventory.SlotActions` extends `ZO_ItemSlotActionsController`
- `BETTERUI.CIM.GenericSlotActions` exists but is not currently used
- Both modules have similar patterns for:
  - Primary action discovery
  - "Use" action handling
  - "Split Stack" action handling
  - "Link to Chat" action handling

### Proposed Approach
1. Enhance `GenericSlotActions` with common action building logic
2. Module-specific SlotActions classes inherit from enhanced base
3. Share common action patterns (Use, Split, Link, Lock/Unlock)

### Files Changed
- [MODIFY] `Modules/CIM/Actions/GenericSlotActions.lua`
- [MODIFY] `Modules/Inventory/Actions/SlotActions.lua`
- [NEW] `Modules/Banking/Actions/SlotActions.lua` (if needed)

### Risk Assessment
**Medium Risk** - Slot actions are core to item interaction UX.

---

## Consolidated Summary

### All Identified Consolidation Targets

| # | System | Priority | Est. Effort | Risk | Modules Affected |
|---|--------|----------|-------------|------|------------------|
| 1 | Position Persistence | HIGH | 2-3 hrs | Medium | Inventory, Banking |
| 2 | Header/Tab Navigation | MEDIUM | 2-3 hrs | Medium | Inventory, Banking |
| 3 | List Management | MEDIUM | 1-2 hrs | Low | Inventory, Banking |
| 4 | Keybind Consolidation | LOW | 1-2 hrs | Low | Inventory, Banking |
| 5 | Search Standardization | LOW | 1 hr | Low | Inventory, Banking |
| 6 | Action Dialog Callbacks | MEDIUM | 1-2 hrs | Medium | Inventory, Banking |
| 7 | Utility Functions | MEDIUM | 1 hr | Low | Inventory, Banking |
| 8 | Settings Defaults | LOW | 1-2 hrs | Low | Inventory, Banking |
| 9 | Timing Constants | LOW | 0.5 hrs | Low | Inventory, Banking |
| 10 | Slot Actions Pattern | LOW | 2-3 hrs | Medium | Inventory, Banking |

**Total Estimated Effort**: 13-20 hours

### Recommended Implementation Order

1. **Phase 1**: Position Persistence (highest bug surface, most duplicated logic) - ✅ **COMPLETE**
2. **Phase 7**: Utility Functions (quick win, low risk, enables other phases) - ✅ **COMPLETE**
3. **Phase 2**: Header/Tab Navigation (fixes shared rapid-navigation bugs) - ✅ **COMPLETE**
4. **Phase 6**: Action Dialog Callbacks (reduces callback complexity) - ⏸️ **DEFERRED** (too module-specific)
5. **Phase 3**: List Management (incremental improvements) - ✅ **COMPLETE**
6. **Phase 9**: Timing Constants (quick consolidation) - ✅ **COMPLETE**
7. **Phase 8**: Settings Defaults (uses existing factory pattern)
8. **Phase 4**: Keybind Consolidation (incremental)
9. **Phase 5**: Search Standardization (incremental)
10. **Phase 10**: Slot Actions Pattern (complex, defer if needed)

---

## Future Considerations

### Additional Modules
Once the pattern is established, other modules could adopt the shared systems:
- **Guild Store** - List management, position persistence
- **Crafting** - Category filtering, search integration
- **Mail** - List management

### Settings Live Refresh
The shared patterns could enable centralized live-refresh for settings changes that affect multiple modules.

### Potential Phase 11+
Additional consolidation opportunities identified during implementation:
- **Scene State Change Handlers**: Common pattern for `RegisterCallback("StateChange", ...)` 
- **Keybind Strip Management**: Add/Remove/Update guards to prevent overlap artifacts
- **List Lifecycle Hooks**: Standardized "Refresh-Filter-Sort-Select" loop

---

## Appendix: Current File Sizes

For reference, here are the current file sizes indicating potential duplication:

| File | Size |
|------|------|
| `Inventory/State/PositionManager.lua` | 7.5 KB |
| `Banking/State/StateManager.lua` | 10.5 KB |
| `Inventory/Core/HeaderManager.lua` | 6.8 KB |
| `Banking/UI/HeaderManager.lua` | 9.0 KB |
| `Inventory/Lists/ItemListManager.lua` | 25.1 KB |
| `Banking/Lists/BankListManager.lua` | 21.4 KB |
| `Inventory/Keybinds/InventoryKeybinds.lua` | 13.4 KB |
| `Banking/Keybinds/KeybindManager.lua` | 13.5 KB |

**Total potential consolidation target**: ~35-40 KB could be reduced to ~20-25 KB of shared code.
