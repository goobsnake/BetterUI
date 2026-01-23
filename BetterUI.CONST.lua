-- BetterUI.CONST.lua
---
--- Purpose: Defines all static constants, configuration values, and layout definitions used throughout the BetterUI addon.
---          This file serves as the central configuration repository for UI dimensions, positioning, and default values.
--- Mechanics: Populates the BETTERUI.CONST table which is accessed globally by other modules.
--- References: Referenced by virtually all modules (Inventory, Banking, GeneralInterface) for layout and logical constants.
---

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


-- Panel widths
--- Defines the standard width for the gamepad interface right-hand panel.
BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH = 1350
BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH = 470

-- Horizontal padding values
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING = 36
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING_OTHER = 10
BETTERUI_GAMEPAD_SCREEN_PADDING = 40
BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ = BETTERUI_GAMEPAD_SCREEN_PADDING + BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING

-- List positioning
BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET = 90
BETTERUI_GAMEPAD_DEFAULT_PANEL_CONTAINER_WIDTH = 1325
BETTERUI_TABBAR_ICON_WIDTH = 50

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
-- TODO: Consider moving these to a layout configuration table instead of global variables to reduce namespace pollution.
-- Note: These are referenced directly in XML templates via their global names.

-- Sub-menu label positioning
BETTERUI_SUBMENU_LABEL_OFFSET_X = 87
BETTERUI_SUBMENU_LABEL_WIDTH = 540

-- Item type column
BETTERUI_ITEM_TYPE_OFFSET_X = 550
BETTERUI_ITEM_TYPE_WIDTH = 250

-- Trait column
BETTERUI_TRAIT_OFFSET_X = 810
BETTERUI_TRAIT_WIDTH = 180

-- Stat column
BETTERUI_STAT_OFFSET_X = 1000
BETTERUI_STAT_WIDTH = 130

-- Value column
BETTERUI_VALUE_OFFSET_X = 1150
BETTERUI_VALUE_WIDTH = 100

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

BETTERUI.CONST.LAYOUT = {
    TOOLTIP = {
        STATUS_LABEL_OFFSET_Y = 60,
        BODY_OFFSET_Y_ENHANCED = 50,
        PRICE_LABEL_HEIGHT = 32,
        PRICE_LABEL_OFFSET_Y = 5,
    }
}

BETTERUI.CONST.INVENTORY = {
    DIALOG_QUEUE_TIMEOUT_MS = 300,  -- Delay before showing secondary dialogs to avoid ESO dialog queue issues
    TOOLTIP_REFRESH_DELAY_MS = 300,  -- Debounce for tooltip updates during navigation
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
