--[[
File: Modules/CIM/Constants.lua
Purpose: Constants for the Common Interface Module (CIM).
         Includes Currency Footer configuration, Header/Footer layout geometry, and Carousel settings.
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

-- Backwards Compatibility Aliases (for Lua code that still uses global names)
BETTERUI_CAROUSEL_START_OFFSET = BETTERUI.CIM.CONST.CAROUSEL.startOffset
BETTERUI_CAROUSEL_ITEM_SPACING = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing
BETTERUI_CAROUSEL_VERTICAL_OFFSET = BETTERUI.CIM.CONST.CAROUSEL.verticalOffset

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

-- Backwards Compatibility Aliases (for Lua code that still uses old names)
BETTERUI_TOOLTIP_MAX_FADE_GRADIENT_SIZE = BETTERUI.CIM.CONST.TOOLTIP_MAX_FADE_GRADIENT_SIZE
BETTERUI_TOOLTIP_X_OFFSET = BETTERUI.CIM.CONST.TOOLTIP_X_OFFSET
BETTERUI_TOOLTIP_Y_OFFSET = BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET
BETTERUI_TOOLTIP_SCROLL_OFFSET_Y = BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y
