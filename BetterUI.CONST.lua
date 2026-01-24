--[[
File: BetterUI.CONST.lua
Purpose: Defines all static constants, configuration values, and layout definitions.
         Serves as the central configuration repository for UI dimensions and defaults.
Mechanics: Populates the BETTERUI.CONST table accessed globally by other modules.
Author: BetterUI Team
Last Modified: 2026-01-23
]]

local _

-- ============================================================================
-- RESEARCH SYSTEM
-- ============================================================================

-- Crafting skill types for research trait tracking
--- Used by: Tooltips and Inventory modules to check research status.
BETTERUI.CONST.CraftingSkillTypes = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_WOODWORKING }

-- ============================================================================
-- UI LAYOUT
-- ============================================================================

BETTERUI.CONST.LAYOUT = {}



-- Panel widths
BETTERUI.CONST.LAYOUT.PANEL = {
    WIDTH = 1350,
    ZO_WIDTH = 470,
    CONTAINER_WIDTH = 1325,
}

-- Backward Compatibility Aliases (XML Support)
BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH = BETTERUI.CONST.LAYOUT.PANEL.WIDTH
BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH = BETTERUI.CONST.LAYOUT.PANEL.ZO_WIDTH
BETTERUI_GAMEPAD_DEFAULT_PANEL_CONTAINER_WIDTH = BETTERUI.CONST.LAYOUT.PANEL.CONTAINER_WIDTH

-- Horizontal padding values
BETTERUI.CONST.LAYOUT.PADDING = {
    DEFAULT = 36,
    OTHER = 10,
    SCREEN = 40,
}

BETTERUI.CONST.LAYOUT.LIST = {
    SCREEN_X_OFFSET = 90,
    ICON_WIDTH = 50,
}

-- Backward Compatibility Aliases (XML Support)
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING = BETTERUI.CONST.LAYOUT.PADDING.DEFAULT
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING_OTHER = BETTERUI.CONST.LAYOUT.PADDING.OTHER
BETTERUI_GAMEPAD_SCREEN_PADDING = BETTERUI.CONST.LAYOUT.PADDING.SCREEN
BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ = BETTERUI.CONST.LAYOUT.PADDING.SCREEN + BETTERUI.CONST.LAYOUT.PADDING.DEFAULT

BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET = BETTERUI.CONST.LAYOUT.LIST.SCREEN_X_OFFSET
BETTERUI_TABBAR_ICON_WIDTH = BETTERUI.CONST.LAYOUT.LIST.ICON_WIDTH

-- ============================================================================
-- LIST ENTRY DIMENSIONS (Shared)
-- ============================================================================

-- Entry widths (used in XML templates)
--- Calculated widths for list rows to ensure they fit within the panel with correct padding.
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH = BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH - (2 * BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING)
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_HWIDTH = BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH - BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET = -20
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT = BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET - BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT = BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH - BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT

-- Header Layout Extras
BETTERUI_SEARCH_BAR_SPACING_Y = 8

-- ============================================================================
-- POSITIONING
-- ============================================================================

-- Quadrant positioning
BETTERUI_GAMEPAD_QUADRANT_1_LEFT = BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING

-- ============================================================================
-- XML TEMPLATE VALUES (Column Layout)
-- ============================================================================
--[[
Constant: BETTERUI.CONST.LAYOUT.COLUMNS
Description: X Offsets and Widths for the inventory grid columns.
Direction: OFFSET_X is Positive (+) moving RIGHT from the left edge of the list entry.
Used By: Inventory list templates.
]]
BETTERUI.CONST.LAYOUT.COLUMNS = {
    SUBMENU = { OFFSET_X = 87, WIDTH = 540 },
    TYPE    = { OFFSET_X = 550, WIDTH = 250 },
    TRAIT   = { OFFSET_X = 810, WIDTH = 180 },
    STAT    = { OFFSET_X = 1000, WIDTH = 130 },
    VALUE   = { OFFSET_X = 1150, WIDTH = 100 },
}

-- Backward Compatibility Aliases (XML Support)
BETTERUI_SUBMENU_LABEL_OFFSET_X = BETTERUI.CONST.LAYOUT.COLUMNS.SUBMENU.OFFSET_X
BETTERUI_SUBMENU_LABEL_WIDTH = BETTERUI.CONST.LAYOUT.COLUMNS.SUBMENU.WIDTH
BETTERUI_ITEM_TYPE_OFFSET_X = BETTERUI.CONST.LAYOUT.COLUMNS.TYPE.OFFSET_X
BETTERUI_ITEM_TYPE_WIDTH = BETTERUI.CONST.LAYOUT.COLUMNS.TYPE.WIDTH
BETTERUI_TRAIT_OFFSET_X = BETTERUI.CONST.LAYOUT.COLUMNS.TRAIT.OFFSET_X
BETTERUI_TRAIT_WIDTH = BETTERUI.CONST.LAYOUT.COLUMNS.TRAIT.WIDTH
BETTERUI_STAT_OFFSET_X = BETTERUI.CONST.LAYOUT.COLUMNS.STAT.OFFSET_X
BETTERUI_STAT_WIDTH = BETTERUI.CONST.LAYOUT.COLUMNS.STAT.WIDTH
BETTERUI_VALUE_OFFSET_X = BETTERUI.CONST.LAYOUT.COLUMNS.VALUE.OFFSET_X
BETTERUI_VALUE_WIDTH = BETTERUI.CONST.LAYOUT.COLUMNS.VALUE.WIDTH

-- ============================================================================
-- GLOBAL CONSTANTS (Colors, Icons, Fonts)
-- ============================================================================

BETTERUI.CONST.COLORS = {

    -- Tab bar icon colors for category navigation
    TAB_ICON_GOLD = {1, 0.95, 0.5, 1},      -- Gold tint for category icons
    TAB_ICON_FILTER = {1, 1, 1, 1},          -- White for filter type icons
}

BETTERUI.CONST.TOOLTIP = {
    DEFAULT_FONT_SIZE = 24
}



BETTERUI.CONST.ICONS = {
    EQUIP_MAIN = "BetterUI/Modules/CIM/Images/inv_equip.dds",
    EQUIP_BACKUP = "BetterUI/Modules/CIM/Images/inv_equip_backup.dds",
    EQUIP_SLOT = "BetterUI/Modules/CIM/Images/inv_equip_quickslot.dds",
    NEW_ITEM = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_new.dds",
    DEFAULT_SLOT = "/esoui/art/inventory/inventory_slot.dds"
}
-- Default settings for Common Interface Module components
BETTERUI.CONST.CIM = {
    DEFAULT_TRIGGER_SPEED = 10,
    DEFAULT_RH_SCROLL_SPEED = 50,
    DEFAULT_TOOLTIP_SIZE = 24,
}

BETTERUI.CONST.LAYOUT.TOOLTIP = {
        STATUS_LABEL_OFFSET_Y = 60,
        BODY_OFFSET_Y_ENHANCED = 50,
        PRICE_LABEL_HEIGHT = 32,
        PRICE_LABEL_OFFSET_Y = 5,
    }



BETTERUI.CONST.HEADER_LAYOUT = {
    DIVIDER = {
        --[[
        Constant: DIVIDER.OFFSET_Y
        Description: Vertical offset for the bottom divider.
        Direction: Positive (+) moves DOWN.
        Used By: GenericHeader.xml
        ]]
        OFFSET_Y = 77,
        SPACING = 4,
    },
    --[[
    Constant: COLUMNS
    Description: Horizontal X offsets for grid column headers.
    Direction: Positive (+) moves RIGHT from the left anchor.
    Used By: GenericHeader.xml
    ]]
    COLUMNS = {
        NAME = 87,
        TYPE = 637,
        TRAIT = 897,
        STAT = 1087,
        VALUE = 1237,
    },
    EQUIP_SLOT = {
        --[[
        Constant: EQUIP_SLOT.BACKUP_X
        Description: Horizontal offset for the 'Equip' text label for backup slots.
        Direction: Negative (-) moves LEFT from the right anchor.
        Used By: GenericHeader.xml
        ]]
        BACKUP_X = -210,
        ICON_GAP_X = 45,
    },
    OFFSETS = {
        --[[
        Constant: OFFSETS.MAIN_HAND_X / BACKUP_HAND_X
        Description: Horizontal anchor offsets for equipment icons.
        Direction: Negative (-) moves LEFT from the anchor point.
        Used By: GenericHeader.xml
        ]]
        MAIN_HAND_X = -155,
        BACKUP_HAND_X = -155
    }
}
