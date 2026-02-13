--[[
File: Modules/Inventory/Constants.lua
Purpose: Constants for the Inventory module.
         Includes search bar positioning, list entry icon sizing, and sort schema.
Last Modified: 2026-01-28
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

-- ============================================================================
-- LIST TYPE IDENTIFIERS
-- Centralized string constants for SwitchActiveList and list mode tracking
-- ============================================================================

--[[
Table: BETTERUI.Inventory.CONST.LIST_TYPES
Description: List type identifiers for currentListType tracking in SwitchActiveList.
             These are NOT the names passed to AddList(), but identifiers for mode switching.
Used By: InventoryClass.lua, SwitchActiveList logic.
]]
BETTERUI.Inventory.CONST.LIST_TYPES = {
    CATEGORY = "categoryList",
    ITEM = "itemList",
    CRAFT_BAG = "craftBagList",
}

-- Backward compatibility aliases (global constants for existing code)
-- Register deprecations so external addons get migration guidance
BETTERUI.CIM.DeprecationRegistry.Register(
    "INVENTORY_CATEGORY_LIST",
    "BETTERUI.Inventory.CONST.LIST_TYPES.CATEGORY",
    "v3.1"
)
BETTERUI.CIM.DeprecationRegistry.Register(
    "INVENTORY_ITEM_LIST",
    "BETTERUI.Inventory.CONST.LIST_TYPES.ITEM",
    "v3.1"
)
BETTERUI.CIM.DeprecationRegistry.Register(
    "INVENTORY_CRAFT_BAG_LIST",
    "BETTERUI.Inventory.CONST.LIST_TYPES.CRAFT_BAG",
    "v3.1"
)

-- Note: We keep the direct assignments (not shims) because these are simple
-- string constants accessed frequently in hot paths. The deprecation warning
-- is available via /script BETTERUI.CIM.DeprecationRegistry.GetAll()
-- TODO(cleanup): Remove global compatibility aliases after migration to BETTERUI.Inventory.CONST.LIST_TYPES
-- Global backward compatibility aliases
INVENTORY_CATEGORY_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.CATEGORY
INVENTORY_ITEM_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.ITEM
INVENTORY_CRAFT_BAG_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.CRAFT_BAG

-- Timing & Batch Constants (delegate to CIM shared values)
-- Debounce for heavy updates (e.g., full inventory refresh)
BETTERUI.Inventory.CONST.DEBOUNCE_MS = BETTERUI.CIM.CONST.TIMING.DEBOUNCE_MS
-- Delay for category refresh to allow for UI settlement
BETTERUI.Inventory.CONST.CATEGORY_REFRESH_DELAY_MS = BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS
-- Batch sizing for large list processing
BETTERUI.Inventory.CONST.BATCH_SIZE_INITIAL = BETTERUI.CIM.CONST.TIMING.BATCH_SIZE_INITIAL
BETTERUI.Inventory.CONST.BATCH_SIZE_REMAINING = BETTERUI.CIM.CONST.TIMING.BATCH_SIZE_REMAINING

-- ============================================================================
-- SEARCH BAR POSITIONING (delegate to CIM shared constants)
-- Controls the position of the search input field in inventory headers
-- ============================================================================

-- Use centralized CIM search bar constants (eliminates duplication with Banking)
local searchConst = BETTERUI.CIM.GetSearchBarConstants("INVENTORY")

--[[
Constant: BETTERUI.Inventory.CONST.SEARCH_X_OFFSET
Description: Horizontal offset from left edge for search bar.
Direction: Positive (+) moves RIGHT.
Used By: Inventory.lua
]]
BETTERUI.Inventory.CONST.SEARCH_X_OFFSET = searchConst.X_OFFSET

--[[
Constant: BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET
Description: Vertical offset from header bottom for search bar.
Direction: Positive (+) moves DOWN.
Used By: Inventory.lua
]]
BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET = searchConst.Y_OFFSET

--[[
Constant: BETTERUI.Inventory.CONST.SEARCH_RIGHT_INSET
Description: Right edge inset for search bar width.
Direction: Negative (-) moves LEFT (narrower).
Used By: Inventory.lua
]]
BETTERUI.Inventory.CONST.SEARCH_RIGHT_INSET = searchConst.RIGHT_INSET

-- ============================================================================
-- LIST ENTRY ICON SCALING
-- Used in InventoryList.lua for dynamic icon sizing based on font settings
-- ============================================================================

BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE = 24      -- Baseline row text size; larger values make rows feel denser/taller.
BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_SIZE = 34      -- Icon size paired with base font size; increase for larger row icons.
BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_OFFSET = -42   -- Icon X anchor offset in row (+ right, - left).
BETTERUI.Inventory.CONST.LIST_ENTRY_ICON_OFFSET_FACTOR = 0.4 -- Extra icon X shift per font-size step (higher = icon drifts right faster).

-- Status & Equipment Indicator Offsets
BETTERUI.Inventory.CONST.STATUS_INDICATOR_OFFSET_X = -2 -- Status marker X nudge relative to icon (+ right, - left).
BETTERUI.Inventory.CONST.EQUIPPED_ICON_OFFSET_X = -2    -- Equipped marker X nudge relative to icon (+ right, - left).

-- Standard Icon Sizes
BETTERUI.Inventory.CONST.ICON_SIZE_SMALL = 16  -- Utility icon size for compact indicators.
BETTERUI.Inventory.CONST.ICON_SIZE_MEDIUM = 24 -- Mid-size icon for common row badges.
BETTERUI.Inventory.CONST.ICON_SIZE_LARGE = 34  -- Large icon size matching default list entry icon target.

-- Equipment Icon Base Dimensions (for scaling calculations)
-- Used in InventoryList.lua to scale equip icons proportionally with font size
BETTERUI.Inventory.CONST.EQUIP_ICON_BASE_WIDTH = 28  -- Base equipped-icon width before runtime scaling.
BETTERUI.Inventory.CONST.EQUIP_ICON_BASE_HEIGHT = 24 -- Base equipped-icon height before runtime scaling.

-- ============================================================================
-- SORT SCHEMA (delegating to CIM shared version)
-- ============================================================================

--[[
Table: BETTERUI.Inventory.CONST.SORT_SCHEMA
Description: Sort schema for inventory item ordering.
             Delegates to CIM shared schema for consistency with Banking.
Used By: DefaultSortComparator for gamepad inventory sorting.
]]
BETTERUI.Inventory.CONST.SORT_SCHEMA = BETTERUI.CIM.CONST.SORT_SCHEMA

--[[
Function: BETTERUI.Inventory.DefaultSortComparator
Description: Custom comparison function for sorting gamepad inventory items.
             Delegates to CIM shared comparator for consistency with Banking.
Rationale: Defines a specific sort order: Type -> Name -> Level -> CP -> Icon -> ID.
Mechanism: Delegates to CIM.Utils.DefaultSortComparator.
References: Used by the gamepad inventory list (Sort Comparator).
param: left (table) - The first item data.
param: right (table) - The second item data.
return: boolean - True if 'left' should appear before 'right'.
]]
function BETTERUI.Inventory.DefaultSortComparator(left, right)
    return BETTERUI.CIM.Utils.DefaultSortComparator(left, right)
end
