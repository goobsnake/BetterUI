--[[
File: Modules/Inventory/Constants.lua
Purpose: Constants for the Inventory module.
         Includes search bar positioning and list entry icon sizing.
Last Modified: 2026-01-23
]]

if not BETTERUI.Inventory then BETTERUI.Inventory = {} end
if not BETTERUI.Inventory.CONST then BETTERUI.Inventory.CONST = {} end

-- ============================================================================
-- SEARCH BAR POSITIONING
-- Controls the position of the search input field in inventory headers
-- ============================================================================

BETTERUI_INV_SEARCH_X_OFFSET = 56          -- Horizontal offset from left edge (increase to move right)
BETTERUI_INV_SEARCH_Y_OFFSET = 1           -- Vertical offset from header bottom (increase to move down)
BETTERUI_INV_SEARCH_RIGHT_INSET = -4       -- Right edge inset (more negative = narrower search bar)

-- ============================================================================
-- LIST ENTRY ICON SCALING
-- Used in InventoryList.lua for dynamic icon sizing based on font settings
-- ============================================================================

BETTERUI_LIST_ENTRY_BASE_FONT_SIZE = 24
BETTERUI_LIST_ENTRY_BASE_ICON_SIZE = 34
BETTERUI_LIST_ENTRY_BASE_ICON_OFFSET = -42
BETTERUI_LIST_ENTRY_ICON_OFFSET_FACTOR = 0.4

-- Status & Equipment Indicator Offsets
BETTERUI_STATUS_INDICATOR_OFFSET_X = -2
BETTERUI_EQUIPPED_ICON_OFFSET_X = -2

-- Standard Icon Sizes
BETTERUI_ICON_SIZE_SMALL = 16
BETTERUI_ICON_SIZE_MEDIUM = 24
BETTERUI_ICON_SIZE_LARGE = 34
