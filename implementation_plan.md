# Implementation Plan: Code Review TODOs

## Mode: `--todo`

This plan inserts TODO comments at identified problem locations for future remediation.

---

## Phase 1: CIM Module TODOs

### CIM/Core/WindowClass.lua
- **Line 155**: Insert before `self:GetList():RefreshVisible()`
  ```lua
  -- TODO(fix): Add nil-check before calling RefreshVisible - GetList() may return nil during scene transitions
  ```

### CIM/UI/GenericHeader.lua
- **Line 88**: Insert before control assignment block
  ```lua
  -- TODO(fix): Add nil-checks for chained GetNamedChild calls - crashes if XML structure is missing
  ```
- **Line 97**: Insert before tabBarControl:SetHidden
  ```lua
  -- TODO(fix): Add nil-check for tabBarControl before SetHidden call
  ```

### CIM/UI/GenericFooter.lua
- **Line 68**: Insert before local invSettings assignment
  ```lua
  -- TODO(fix): Add nil-check chain for BETTERUI.Settings.Modules["Inventory"]
  ```

### CIM/Core/RuntimeSetup.lua
- **Line 53**: Insert before the first API patching function
  ```lua
  -- TODO(refactor): Extract common icon patching pattern into helper function - 6 nearly identical blocks follow
  ```

---

## Phase 2: Inventory Module TODOs

### Inventory/Core/InventoryClass.lua
- **Line 728**: Insert before BatchLock function body
  ```lua
  -- TODO(fix): Add nil-check for multiSelectManager and items before iteration
  ```

### Inventory/Lists/InventoryList.lua
- **Line 387**: Insert before control font assignments
  ```lua
  -- TODO(fix): Add nil-checks for GetNamedChild results before calling SetFont
  ```

### Inventory/Lists/ItemListManager.lua
- **Line 615**: Insert before tooltip property access
  ```lua
  -- TODO(fix): Validate tooltip state after data retrieval to prevent corrupted display
  ```

### Inventory/Keybinds/InventoryKeybinds.lua
- **Line 287**: Insert before ZO_Inventory_GetBagAndIndex call
  ```lua
  -- TODO(fix): Add nil-check for targetData before calling ZO_Inventory_GetBagAndIndex
  ```

### Inventory/UI/TooltipUtils.lua
- **Line 284**: Insert before GetItemLinkItemType call
  ```lua
  -- TODO(fix): Add nil-check for itemLink before calling GetItemLinkItemType
  ```

### Inventory/Module.lua
- **Line 71**: Remove duplicate comment (cleanup)
  ```lua
  -- (DELETE duplicate comment line 72)
  ```

### Inventory/Actions/SlotActions.lua
- **Line 36**: Fix FUTURE: to TODO format
  ```lua
  -- TODO(refactor): Add support for custom actions from other addons
  ```

---

## Phase 3: Banking Module TODOs

### Banking/UI/FooterManager.lua
- **Line 23**: Insert before GetNamedChild calls
  ```lua
  -- TODO(fix): Add nil-checks for self.footer and self.footer.footer before GetNamedChild chains
  ```

### Banking/Module.lua
- **Line 58**: Insert before Settings access
  ```lua
  -- TODO(fix): Add nil-check for BETTERUI.Settings and BETTERUI.Settings.Modules before access
  ```

### Banking/Keybinds/KeybindManager.lua
- **Line 42**: Insert before ZO_GamepadBanking call
  ```lua
  -- TODO(fix): Add nil-check for ZO_GamepadBanking before calling IsEntryDataCurrencyRelated
  ```
- **Line 54**: Insert before RemoveAllKeyButtonGroups
  ```lua
  -- TODO(refactor): Replace RemoveAllKeyButtonGroups() with specific group removal to avoid breaking other addons
  ```

### Banking/Dialogs/QuantityDialog.lua
- **Line 44**: Insert before setupFunc call
  ```lua
  -- TODO(fix): Add existence check for dialog.setupFunc before calling
  ```

### Banking/Lists/BankListManager.lua
- **Line 104**: Insert before bag setup logic
  ```lua
  -- TODO(refactor): Extract bag setup logic to shared helper - duplicated at line 227
  ```
- **Line 179**: Insert before category key access
  ```lua
  -- TODO(fix): Ensure activeCategoryForHeader is not nil before accessing .key property
  ```

### Banking/Search/SearchManager.lua
- **Line 104**: Remove duplicate comment (cleanup)
  ```lua
  -- (DELETE duplicate comment lines 106-107)
  ```

---

## Phase 4: ResourceOrbFrames Module TODOs

### ResourceOrbFrames/Core/OrbEvents.lua
- **Line 77**: Insert before SCENE_MANAGER monkey-patching
  ```lua
  -- TODO(architecture): Add existence check and error handling for SCENE_MANAGER method overrides - could break other addons
  ```

### ResourceOrbFrames/ResourceOrbFrames.lua
- **Line 72**: Insert before pool access
  ```lua
  -- TODO(fix): Add nil-check for m_pools and GetMax() result to prevent crash
  ```
- **Line 301**: Insert before fragment call
  ```lua
  -- TODO(fix): Add nil-check for PLAYER_ATTRIBUTE_BARS_FRAGMENT before calling SetHiddenForReason
  ```
- **Line 315**: Insert before SetupModule in deferred handler
  ```lua
  -- TODO(architecture): Add initialization guard to prevent double SetupModule() calls
  ```

### ResourceOrbFrames/SkillBar/FrontBarManager.lua
- **Line 95**: Insert before slot mappings
  ```lua
  -- TODO(refactor): Use SkillBar.CONST.FRONT_BAR_SLOTS instead of duplicating slot mapping arrays
  ```
- **Line 516**: Insert before durationMs assignment
  ```lua
  -- TODO(fix): Suspicious assignment - durationMs = remainMs may break cooldown percentage calculation
  ```

### ResourceOrbFrames/Constants.lua
- **Line 354**: Remove duplicate comment (cleanup)
  ```lua
  -- (DELETE duplicate comment line 355)
  ```

### ResourceOrbFrames/Core/OrbVisuals.lua
- **Line 16**: Insert before ORB_CONFIG table
  ```lua
  -- TODO(doc): Document ORB_CONFIG table structure - indexes and {r, g, b, icon_path} format unclear
  ```

### ResourceOrbFrames/Module.lua
- **Line 133**: Insert before first reset pattern
  ```lua
  -- TODO(refactor): Extract reset settings pattern to single ResetSettings() function - duplicated at lines 332, 509, 689
  ```

---

## Phase 5: WritUnit Module TODOs

### WritUnit/Core/Writ.lua
- **Line 12**: Fix FUTURE: to TODO format
  ```lua
  -- TODO(refactor): Add support for additional crafting types as ESO adds them
  ```

---

## Verification Plan

After TODO insertions:
1. Run `luac5.1 -p` on all modified files to verify syntax
2. Count inserted TODOs: `grep -r "TODO(" Modules/ | wc -l`
3. Verify no debug statements accidentally added

---

## Commit Message

```
chore: add code review TODOs for future iteration

- 19 TODO(fix) for nil-check issues across all modules
- 6 TODO(refactor) for DRY violations and pattern improvements
- 3 duplicate comment cleanups
- 2 FUTURE: to TODO format fixes
- 1 TODO(architecture) for safer SCENE_MANAGER patching
- 1 TODO(doc) for undocumented config table

See critical_code_review.md and sr_engineering_team_review.md for full findings
```
