--[[
File: Modules/CIM/Constants.lua
Purpose: Constants for the Common Interface Module (CIM).
         Includes Currency Footer configuration, Header/Footer layout geometry, Carousel settings,
         and shared UI constants migrated from BetterUI.CONST.lua.
Last Modified: 2026-01-27
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.CONST then BETTERUI.CIM.CONST = {} end

-- ============================================================================
-- CURRENCY FOOTER CONFIGURATION
-- ============================================================================

-- Maximum currencies that can be displayed in the footer (UI space limit)
BETTERUI_MAX_VISIBLE_CURRENCIES = 12

-- Total available currencies in the system
BETTERUI_TOTAL_CURRENCIES = 12

-- Footer currency layout positions (X coordinates for each column)
BETTERUI_CURRENCY_COLUMNS = { 190, 350, 510, 670, 830, 990 }

-- Footer currency row positions (Y coordinates for each row)
BETTERUI_CURRENCY_ROWS = { 32, 58, 84 }

-- ============================================================================
-- CURRENCY PRESETS
-- ============================================================================

BETTERUI.CURRENCY_PRESETS = {
    default = {
        showCurrencyGold = true,
        orderCurrencyGold = 1,
        showCurrencyAlliancePoints = true,
        orderCurrencyAlliancePoints = 2,
        showCurrencyTelVar = true,
        orderCurrencyTelVar = 3,
        showCurrencyUndauntedKeys = true,
        orderCurrencyUndauntedKeys = 4,
        showCurrencyTransmute = true,
        orderCurrencyTransmute = 5,
        showCurrencyCrowns = true,
        orderCurrencyCrowns = 6,
        showCurrencyCrownGems = true,
        orderCurrencyCrownGems = 7,
        showCurrencyWritVouchers = true,
        orderCurrencyWritVouchers = 8,
        showCurrencyTradeBars = true,
        orderCurrencyTradeBars = 9,
        showCurrencyOutfitTokens = true,
        orderCurrencyOutfitTokens = 10,
        showCurrencySeals = true,
        orderCurrencySeals = 11,
        showCurrencyTomePoints = true,
        orderCurrencyTomePoints = 12,
    },
    pvp = {
        showCurrencyAlliancePoints = true,
        orderCurrencyAlliancePoints = 1,
        showCurrencyTelVar = true,
        orderCurrencyTelVar = 2,
        showCurrencyGold = true,
        orderCurrencyGold = 3,
        showCurrencyTransmute = true,
        orderCurrencyTransmute = 4,
        showCurrencySeals = true,
        orderCurrencySeals = 5,
        showCurrencyUndauntedKeys = true,
        orderCurrencyUndauntedKeys = 6,
        showCurrencyTradeBars = true,
        orderCurrencyTradeBars = 7,
        showCurrencyOutfitTokens = true,
        orderCurrencyOutfitTokens = 8,
        showCurrencyCrowns = false,
        orderCurrencyCrowns = 9,
        showCurrencyCrownGems = false,
        orderCurrencyCrownGems = 10,
        showCurrencyWritVouchers = false,
        orderCurrencyWritVouchers = 11,
        showCurrencyTomePoints = false,
        orderCurrencyTomePoints = 12,
    },
    crafter = {
        showCurrencyGold = true,
        orderCurrencyGold = 1,
        showCurrencyWritVouchers = true,
        orderCurrencyWritVouchers = 2,
        showCurrencyTransmute = true,
        orderCurrencyTransmute = 3,
        showCurrencySeals = true,
        orderCurrencySeals = 4,
        showCurrencyOutfitTokens = true,
        orderCurrencyOutfitTokens = 5,
        showCurrencyTradeBars = true,
        orderCurrencyTradeBars = 6,
        showCurrencyUndauntedKeys = true,
        orderCurrencyUndauntedKeys = 7,
        showCurrencyAlliancePoints = false,
        orderCurrencyAlliancePoints = 8,
        showCurrencyTelVar = false,
        orderCurrencyTelVar = 9,
        showCurrencyCrowns = false,
        orderCurrencyCrowns = 10,
        showCurrencyCrownGems = false,
        orderCurrencyCrownGems = 11,
        showCurrencyTomePoints = false,
        orderCurrencyTomePoints = 12,
    },
    events = {
        showCurrencyTradeBars = true,
        orderCurrencyTradeBars = 1,
        showCurrencySeals = true,
        orderCurrencySeals = 2,
        showCurrencyGold = true,
        orderCurrencyGold = 3,
        showCurrencyCrowns = true,
        orderCurrencyCrowns = 4,
        showCurrencyCrownGems = true,
        orderCurrencyCrownGems = 5,
        showCurrencyTransmute = true,
        orderCurrencyTransmute = 6,
        showCurrencyWritVouchers = true,
        orderCurrencyWritVouchers = 7,
        showCurrencyUndauntedKeys = true,
        orderCurrencyUndauntedKeys = 8,
        showCurrencyAlliancePoints = false,
        orderCurrencyAlliancePoints = 9,
        showCurrencyTelVar = false,
        orderCurrencyTelVar = 10,
        showCurrencyOutfitTokens = false,
        orderCurrencyOutfitTokens = 11,
        showCurrencyTomePoints = false,
        orderCurrencyTomePoints = 12,
    },
}

-- ============================================================================
-- CATEGORY CAROUSEL (Tab Bar Icons)
-- Used for the rotating category icon bar in Inventory and Banking headers
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.CAROUSEL
Description: Configuration for category carousel (tab bar) positioning.
             Contains default values used by Inventory, with module-specific
             overrides available (e.g., Banking.CONST.CAROUSEL).
Used By: CIM/Lists/TabBarScrollList.lua, Banking/UI/HeaderManager.lua
]]
BETTERUI.CIM.CONST.CAROUSEL = {
    --[[
    Field: startOffset
    Description: Horizontal position of first category icon.
    Direction: Positive (+) moves RIGHT.
    ]]
    startOffset = 710,

    --[[
    Field: itemSpacing
    Description: Space between each category icon.
    ]]
    itemSpacing = 50,

    --[[
    Field: verticalOffset
    Description: Vertical offset to align icons with LB/RB buttons.
    Direction: Positive (+) moves DOWN.
    ]]
    verticalOffset = 12,
}


-- ============================================================================
-- HEADER GEOMETRY (Used in GenericHeader.xml)
-- ============================================================================

BETTERUI_DIVIDER_HEIGHT = 8
BETTERUI_HEADER_TABBAR_Y_OFFSET = 25
BETTERUI_HEADER_TABBAR_HEIGHT = 100
BETTERUI_HEADER_Y_OFFSET = 26
BETTERUI_HEADER_TABBAR_LIST_Y_OFFSET = 75
BETTERUI_HEADER_SELECTED_BG_WIDTH = 50
BETTERUI_HEADER_SELECTED_BG_HEIGHT = 25
BETTERUI_HEADER_SELECTED_BG_Y_OFFSET = 32
BETTERUI_HEADER_BUMPER_ICON_SIZE = 60
BETTERUI_HEADER_BUMPER_ICON_Y_OFFSET = 5
BETTERUI_HEADER_EQUIP_ROW_Y_OFFSET = -5
BETTERUI_HEADER_COLUMN_HEADER_Y_OFFSET = 95
BETTERUI_HEADER_DIVIDER_OFFSET_Y = 77
BETTERUI_HEADER_DIVIDER_OFFSET_Y_SPACED = 81
BETTERUI_HEADER_BOTTOM_DIVIDER_Y_OFFSET = 110

-- ============================================================================
-- FOOTER GEOMETRY (Used in GenericFooter.xml and GenericFooter.lua)
-- ============================================================================

BETTERUI_FOOTER_START_X = 190
BETTERUI_FOOTER_RIGHT_PADDING = 50
BETTERUI_FOOTER_BOTTOM_OFFSET_Y = -195
BETTERUI_FOOTER_DIVIDER_OFFSET_Y = 15

-- ============================================================================
-- TOOLTIP LAYOUT CONSTANTS
-- Migrated from GeneralInterface/Constants.lua
-- ============================================================================

--[[
Constant: BETTERUI.CIM.CONST.TOOLTIP_MAX_FADE_GRADIENT_SIZE
Description: Maximum size for tooltip fade gradient effect.
Used By: Inventory/Module.lua
]]
BETTERUI.CIM.CONST.TOOLTIP_MAX_FADE_GRADIENT_SIZE = 10

--[[
Constant: BETTERUI.CIM.CONST.TOOLTIP_X_OFFSET
Description: Horizontal offset for tooltip positioning.
Direction: Positive (+) moves RIGHT.
Used By: Inventory/Module.lua
]]
BETTERUI.CIM.CONST.TOOLTIP_X_OFFSET = 40

--[[
Constant: BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET
Description: Vertical offset for tooltip positioning.
Direction: Positive (+) moves DOWN, Negative (-) moves UP.
Used By: Inventory/Module.lua
]]
BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET = -100

--[[
Constant: BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y
Description: Vertical offset for tooltip scroll container.
Direction: Positive (+) moves DOWN.
Used By: Inventory/UI/TooltipUtils.lua
]]
BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y = 40

-- ============================================================================
-- RESEARCH SYSTEM (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.CraftingSkillTypes
Description: Crafting skill types for research trait tracking.
Used By: Tooltips and Inventory modules to check research status.
]]
BETTERUI.CIM.CONST.CraftingSkillTypes = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER,
    CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_WOODWORKING }

-- ============================================================================
-- UI LAYOUT (Migrated from BetterUI.CONST.lua)
-- ============================================================================

BETTERUI.CIM.CONST.LAYOUT = {}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.PANEL
Description: Panel width configurations for inventory/banking screens.
Used By: XML templates and list managers.
]]
BETTERUI.CIM.CONST.LAYOUT.PANEL = {
    WIDTH = 1350,
    ZO_WIDTH = 470,
    CONTAINER_WIDTH = 1325,
}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.PADDING
Description: Horizontal padding values for UI elements.
Used By: XML templates and list entry calculations.
]]
BETTERUI.CIM.CONST.LAYOUT.PADDING = {
    DEFAULT = 36,
    OTHER = 10,
    SCREEN = 40,
}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.LIST
Description: List positioning and icon sizing.
Used By: Inventory and Banking list templates.
]]
BETTERUI.CIM.CONST.LAYOUT.LIST = {
    SCREEN_X_OFFSET = 90,
    ICON_WIDTH = 50,
}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.COLUMNS
Description: X Offsets and Widths for the inventory grid columns.
Direction: OFFSET_X is Positive (+) moving RIGHT from the left edge of the list entry.
Used By: Inventory list templates.
]]
BETTERUI.CIM.CONST.LAYOUT.COLUMNS = {
    SUBMENU = { OFFSET_X = 87, WIDTH = 540 },
    TYPE    = { OFFSET_X = 550, WIDTH = 250 },
    TRAIT   = { OFFSET_X = 810, WIDTH = 180 },
    STAT    = { OFFSET_X = 1000, WIDTH = 130 },
    VALUE   = { OFFSET_X = 1150, WIDTH = 100 },
}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.TOOLTIP
Description: Tooltip positioning offsets for enhanced tooltips.
Used By: CIM tooltip layout.
]]
BETTERUI.CIM.CONST.LAYOUT.TOOLTIP = {
    STATUS_LABEL_OFFSET_Y = 60,
    BODY_OFFSET_Y_ENHANCED = 50,
    PRICE_LABEL_HEIGHT = 32,
    PRICE_LABEL_OFFSET_Y = 5,
}

-- Backward Compatibility Aliases (XML Support) - PANEL
BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH = BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH
BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH = BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH
BETTERUI_GAMEPAD_DEFAULT_PANEL_CONTAINER_WIDTH = BETTERUI.CIM.CONST.LAYOUT.PANEL.CONTAINER_WIDTH

-- Backward Compatibility Aliases (XML Support) - PADDING
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING = BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING_OTHER = BETTERUI.CIM.CONST.LAYOUT.PADDING.OTHER
BETTERUI_GAMEPAD_SCREEN_PADDING = BETTERUI.CIM.CONST.LAYOUT.PADDING.SCREEN
BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ = BETTERUI.CIM.CONST.LAYOUT.PADDING.SCREEN +
    BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT

-- Backward Compatibility Aliases (XML Support) - LIST
BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET = BETTERUI.CIM.CONST.LAYOUT.LIST.SCREEN_X_OFFSET
BETTERUI_TABBAR_ICON_WIDTH = BETTERUI.CIM.CONST.LAYOUT.LIST.ICON_WIDTH

-- Backward Compatibility Aliases (XML Support) - LIST ENTRY DIMENSIONS
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH = BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH -
    (2 * BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING)
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_HWIDTH = BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH -
    BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET = -20
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT = BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET -
    BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT = BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH -
    BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT

-- Backward Compatibility Aliases (XML Support) - HEADER
BETTERUI_SEARCH_BAR_SPACING_Y = 8

-- Backward Compatibility Aliases (XML Support) - POSITIONING
BETTERUI_GAMEPAD_QUADRANT_1_LEFT = BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING

-- Backward Compatibility Aliases (XML Support) - COLUMNS
BETTERUI_SUBMENU_LABEL_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.SUBMENU.OFFSET_X
BETTERUI_SUBMENU_LABEL_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.SUBMENU.WIDTH
BETTERUI_ITEM_TYPE_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TYPE.OFFSET_X
BETTERUI_ITEM_TYPE_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TYPE.WIDTH
BETTERUI_TRAIT_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TRAIT.OFFSET_X
BETTERUI_TRAIT_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TRAIT.WIDTH
BETTERUI_STAT_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.STAT.OFFSET_X
BETTERUI_STAT_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.STAT.WIDTH
BETTERUI_VALUE_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.VALUE.OFFSET_X
BETTERUI_VALUE_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.VALUE.WIDTH

-- ============================================================================
-- COLORS (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.COLORS
Description: Color definitions for UI elements.
Used By: Tab bar icons and category navigation.
]]
BETTERUI.CIM.CONST.COLORS = {
    -- Tab bar icon colors for category navigation
    TAB_ICON_GOLD = { 1, 0.95, 0.5, 1 }, -- Gold tint for category icons
    TAB_ICON_FILTER = { 1, 1, 1, 1 },    -- White for filter type icons
}

-- ============================================================================
-- TOOLTIP DEFAULTS (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.TOOLTIP_DEFAULTS
Description: Default font sizing for tooltips.
Used By: Tooltip rendering.
]]
BETTERUI.CIM.CONST.TOOLTIP_DEFAULTS = {
    DEFAULT_FONT_SIZE = 24
}

-- ============================================================================
-- ICONS (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.ICONS
Description: Icon paths for equipment and item status indicators.
Used By: Inventory and Banking list rendering.
]]
BETTERUI.CIM.CONST.ICONS = {
    EQUIP_MAIN = "BetterUI/Modules/CIM/Images/inv_equip.dds",
    EQUIP_BACKUP = "BetterUI/Modules/CIM/Images/inv_equip_backup.dds",
    EQUIP_SLOT = "BetterUI/Modules/CIM/Images/inv_equip_quickslot.dds",
    NEW_ITEM = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_new.dds",
    DEFAULT_SLOT = "/esoui/art/inventory/inventory_slot.dds"
}

-- ============================================================================
-- CIM DEFAULTS (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.DEFAULTS
Description: Default settings for Common Interface Module components.
Used By: CIM initialization and settings panels.
]]
BETTERUI.CIM.CONST.DEFAULTS = {
    DEFAULT_TRIGGER_SPEED = 10,
    DEFAULT_RH_SCROLL_SPEED = 50,
    DEFAULT_TOOLTIP_SIZE = 24,
}

-- ============================================================================
-- HEADER LAYOUT (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.HEADER_LAYOUT
Description: Layout constants for GenericHeader positioning.
Used By: GenericHeader.xml and GenericHeader.lua.
]]
BETTERUI.CIM.CONST.HEADER_LAYOUT = {
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

-- ============================================================================
-- BACKWARDS COMPATIBILITY ALIASES
-- ============================================================================

-- Tooltip legacy aliases
BETTERUI_TOOLTIP_MAX_FADE_GRADIENT_SIZE = BETTERUI.CIM.CONST.TOOLTIP_MAX_FADE_GRADIENT_SIZE
BETTERUI_TOOLTIP_X_OFFSET = BETTERUI.CIM.CONST.TOOLTIP_X_OFFSET
BETTERUI_TOOLTIP_Y_OFFSET = BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET
BETTERUI_TOOLTIP_SCROLL_OFFSET_Y = BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y

-- Legacy namespace aliases (for code still using BETTERUI.CONST.*)
BETTERUI.CONST.LAYOUT = BETTERUI.CIM.CONST.LAYOUT
BETTERUI.CONST.COLORS = BETTERUI.CIM.CONST.COLORS
BETTERUI.CONST.TOOLTIP = BETTERUI.CIM.CONST.TOOLTIP_DEFAULTS
BETTERUI.CONST.ICONS = BETTERUI.CIM.CONST.ICONS
BETTERUI.CONST.CIM = BETTERUI.CIM.CONST.DEFAULTS
