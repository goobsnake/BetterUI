--- BetterUI Constants File
--- This file contains all constant values used throughout the BetterUI addon.
--- Constants are organized by category and only include values that are actually used.

local _

-- ============================================================================
-- RESEARCH SYSTEM CONSTANTS
-- ============================================================================

--- Array of crafting skill types for research trait tracking
--- @type table<number, number> - Array of CRAFTING_TYPE_* constants
BETTERUI.CONST.CraftingSkillTypes = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_WOODWORKING }

-- ============================================================================
-- UI LAYOUT CONSTANTS
-- ============================================================================

--- Default panel width for gamepad UI elements
--- @type number
BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH = 1350

--- Alternative panel width for certain gamepad UI elements
--- @type number
BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH = 470

--- Standard horizontal padding for gamepad UI elements
--- @type number
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING = 36

--- Alternative horizontal padding for specific UI elements
--- @type number
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING_OTHER = 10

--- Screen padding for gamepad UI layout
--- @type number
BETTERUI_GAMEPAD_SCREEN_PADDING = 40

--- Total horizontal padding for lists (used in calculations)
--- @type number
BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ = BETTERUI_GAMEPAD_SCREEN_PADDING + BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING

--- X offset to the left limit of entry text
--- @type number
BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET = 90

--- Default panel container width for tab bars and headers
--- @type number
BETTERUI_GAMEPAD_DEFAULT_PANEL_CONTAINER_WIDTH = 1325

--- Tab bar icon width for UI elements
--- @type number
BETTERUI_TABBAR_ICON_WIDTH = 50

-- ============================================================================
-- LIST ENTRY CONSTANTS
-- ============================================================================

--- Calculated width for list entries (used in XML templates)
--- @type number
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH = BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH - (2 * BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING)

--- Half-width for list entries (used in XML templates)
--- @type number
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_HWIDTH = BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH - BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING

--- Icon X offset for list entries (used in XML templates)
--- @type number
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET = -20

--- Indent for list entries (used in XML templates)
--- @type number
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT = BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET - BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ

--- Width after indent for list entries (used in XML templates)
--- @type number
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT = BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH - BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT

-- ============================================================================
-- POSITIONING CONSTANTS
-- ============================================================================

--- Left position for quadrant 1 in gamepad UI layout
--- @type number
BETTERUI_GAMEPAD_QUADRANT_1_LEFT = BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING

-- ============================================================================
-- ACTION MODE CONSTANTS
-- ============================================================================

--- Action mode for category item interactions
--- @type number
CATEGORY_ITEM_ACTION_MODE = 1

-- ============================================================================
-- UI POSITIONING CONSTANTS (XML Template Values)
-- ============================================================================

--- Label offset X position for sub-menu entries
--- @type number
BETTERUI_SUBMENU_LABEL_OFFSET_X = 87

--- Label width for sub-menu entries
--- @type number
BETTERUI_SUBMENU_LABEL_WIDTH = 540

--- Item type label offset from main label
--- @type number
BETTERUI_ITEM_TYPE_OFFSET_X = 550

--- Item type label width
--- @type number
BETTERUI_ITEM_TYPE_WIDTH = 250

--- Trait label offset from main label
--- @type number
BETTERUI_TRAIT_OFFSET_X = 810

--- Trait label width
--- @type number
BETTERUI_TRAIT_WIDTH = 160

--- Stat label offset from main label
--- @type number
BETTERUI_STAT_OFFSET_X = 980

--- Value label offset from main label
--- @type number
BETTERUI_VALUE_OFFSET_X = 1100

--- Equipped icon offset from main icon
--- @type number
BETTERUI_EQUIPPED_ICON_OFFSET_X = -25

--- Status indicator offset from icon
--- @type number
BETTERUI_STATUS_INDICATOR_OFFSET_X = -10