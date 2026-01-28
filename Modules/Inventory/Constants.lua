--[[
File: Modules/Inventory/Constants.lua
Purpose: Constants for the Inventory module.
         Includes search bar positioning, list entry icon sizing, and sort schema.
Last Modified: 2026-01-27
]]

if not BETTERUI.Inventory then BETTERUI.Inventory = {} end
if not BETTERUI.Inventory.CONST then BETTERUI.Inventory.CONST = {} end

-- Global Inventory Constants (Migrated from BetterUI.CONST.lua)
if not BETTERUI.CONST.INVENTORY then BETTERUI.CONST.INVENTORY = {} end
BETTERUI.CONST.INVENTORY.DIALOG_QUEUE_TIMEOUT_MS = 300
BETTERUI.CONST.INVENTORY.TOOLTIP_REFRESH_DELAY_MS = BETTERUI.CIM.CONST.TIMING.TOOLTIP_REFRESH_DELAY_MS

-- Action Mode Constants (shared across InventoryClass.lua, Inventory.lua, etc.)
-- These define what type of list interaction is currently active
BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE = 1
BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE = 2
BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE = 3

-- Timing & Batch Constants (delegate to CIM shared values)
-- Debounce for heavy updates (e.g., full inventory refresh)
BETTERUI.Inventory.CONST.DEBOUNCE_MS = BETTERUI.CIM.CONST.TIMING.DEBOUNCE_MS
-- Delay for category refresh to allow for UI settlement
BETTERUI.Inventory.CONST.CATEGORY_REFRESH_DELAY_MS = BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS
-- Batch sizing for large list processing
BETTERUI.Inventory.CONST.BATCH_SIZE_INITIAL = BETTERUI.CIM.CONST.TIMING.BATCH_SIZE_INITIAL
BETTERUI.Inventory.CONST.BATCH_SIZE_REMAINING = BETTERUI.CIM.CONST.TIMING.BATCH_SIZE_REMAINING

-- ============================================================================
-- SEARCH BAR POSITIONING
-- Controls the position of the search input field in inventory headers
-- ============================================================================

--[[
Constant: BETTERUI.Inventory.CONST.SEARCH_X_OFFSET
Description: Horizontal offset from left edge for search bar.
Direction: Positive (+) moves RIGHT.
Used By: Inventory.lua
]]
BETTERUI.Inventory.CONST.SEARCH_X_OFFSET = 55

--[[
Constant: BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET
Description: Vertical offset from header bottom for search bar.
Direction: Positive (+) moves DOWN.
Used By: Inventory.lua
]]
BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET = 1

--[[
Constant: BETTERUI.Inventory.CONST.SEARCH_RIGHT_INSET
Description: Right edge inset for search bar width.
Direction: Negative (-) moves LEFT (narrower).
Used By: Inventory.lua
]]
BETTERUI.Inventory.CONST.SEARCH_RIGHT_INSET = -4

-- ============================================================================
-- LIST ENTRY ICON SCALING
-- Used in InventoryList.lua for dynamic icon sizing based on font settings
-- ============================================================================

BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE = 24
BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_SIZE = 34
BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_OFFSET = -42
BETTERUI.Inventory.CONST.LIST_ENTRY_ICON_OFFSET_FACTOR = 0.4

-- Status & Equipment Indicator Offsets
BETTERUI.Inventory.CONST.STATUS_INDICATOR_OFFSET_X = -2
BETTERUI.Inventory.CONST.EQUIPPED_ICON_OFFSET_X = -2

-- Standard Icon Sizes
BETTERUI.Inventory.CONST.ICON_SIZE_SMALL = 16
BETTERUI.Inventory.CONST.ICON_SIZE_MEDIUM = 24
BETTERUI.Inventory.CONST.ICON_SIZE_LARGE = 34

-- ============================================================================
-- SORT SCHEMA (Migrated from Globals.lua)
-- ============================================================================

--[[
Table: BETTERUI.Inventory.CONST.SORT_SCHEMA
Description: Sort schema for inventory item ordering.
Used By: DefaultSortComparator for gamepad inventory sorting.
]]
BETTERUI.Inventory.CONST.SORT_SCHEMA = {
    sortPriorityName       = { tiebreaker = "bestItemTypeName" },
    bestItemTypeName       = { tiebreaker = "name" },
    name                   = { tiebreaker = "requiredLevel" },
    requiredLevel          = { tiebreaker = "requiredChampionPoints", isNumeric = true },
    requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
    iconFile               = { tiebreaker = "uniqueId" },
    uniqueId               = { isId64 = true },
}

--[[
Function: BETTERUI.Inventory.DefaultSortComparator
Description: Custom comparison function for sorting gamepad inventory items.
Rationale: Defines a specific sort order: Type -> Name -> Level -> CP -> Icon -> ID.
Mechanism: Uses ZO_TableOrderingFunction with BETTERUI.Inventory.CONST.SORT_SCHEMA.
References: Used by the gamepad inventory list (Sort Comparator).
param: left (table) - The first item data.
param: right (table) - The second item data.
return: boolean - True if 'left' should appear before 'right'.
]]
function BETTERUI.Inventory.DefaultSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "sortPriorityName", BETTERUI.Inventory.CONST.SORT_SCHEMA,
        ZO_SORT_ORDER_UP)
end
