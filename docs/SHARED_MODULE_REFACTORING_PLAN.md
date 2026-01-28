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

| Phase | Description | Estimated Effort | Priority |
|-------|-------------|------------------|----------|
| **1** | Position Persistence Manager | 2-3 hours | HIGH |
| **2** | Header/Tab Navigation | 2-3 hours | MEDIUM |
| **3** | List Management | 1-2 hours | MEDIUM |
| **4** | Keybind Consolidation | 1-2 hours | LOW |
| **5** | Search Standardization | 1 hour | LOW |

**Total Estimated Effort**: 7-11 hours

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

---

## Success Criteria

1. **Reduced Code Duplication**: At least 30% reduction in duplicated logic
2. **Single Source of Truth**: Bug fixes apply to all modules automatically
3. **Consistent Behavior**: Inventory and Banking behave identically for shared features
4. **No Regressions**: All existing functionality works as before

---

## Future Considerations

### Additional Modules
Once the pattern is established, other modules could adopt the shared systems:
- **Guild Store** - List management, position persistence
- **Crafting** - Category filtering, search integration
- **Mail** - List management

### Settings Live Refresh
The shared patterns could enable centralized live-refresh for settings changes that affect multiple modules.

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
