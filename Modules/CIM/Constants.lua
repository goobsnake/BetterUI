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
-- TIMING CONSTANTS
-- Shared timing values for consistent behavior across modules
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.TIMING
Description: Shared timing constants for UI debouncing and coalescing.
             Used by Inventory and Banking to ensure consistent response times.
Used By: PositionManager, HeaderNavigation, list refresh logic.
]]
BETTERUI.CIM.CONST.TIMING = {
    -- ========================================================================
    -- DEBOUNCING & COALESCING
    -- ========================================================================

    -- Debounce for heavy UI updates (ms)
    DEBOUNCE_MS = 50,

    -- Category navigation coalescing delay (ms)
    CATEGORY_CHANGE_DELAY_MS = 100,

    -- Item move coalescing delay (ms)
    MOVE_COALESCE_DELAY_MS = 100,

    -- Tooltip refresh delay (ms)
    TOOLTIP_REFRESH_DELAY_MS = 300,

    -- ========================================================================
    -- KEYBIND TIMING
    -- Used to ensure keybinds are properly registered after scene transitions
    -- ========================================================================

    -- Post-init keybind update delay (ms)
    -- Used after scene showing to ensure keybind strip is ready
    KEYBIND_REFRESH_DELAY_MS = 60,

    -- Secondary/tertiary keybind activation delay (ms)
    -- Shorter delay for additional keybind group registration
    KEYBIND_ACTIVATION_DELAY_MS = 40,

    -- ========================================================================
    -- LIST & CATEGORY REFRESH
    -- ========================================================================

    -- Category list refresh coalescing (ms)
    -- Prevents multiple rapid refreshes when switching categories
    CATEGORY_REFRESH_COALESCE_MS = 80,

    -- Batch processing interval (ms)
    -- Time between batch chunks for large list processing
    BATCH_PROCESS_INTERVAL_MS = 10,

    -- Batch processing sizes
    BATCH_SIZE_INITIAL = 50,
    BATCH_SIZE_REMAINING = 200,

    -- ========================================================================
    -- DIALOG & QUEUE TIMING
    -- ========================================================================

    -- Dialog queue processing timeout (ms)
    -- Used when queuing dialogs (equip, destroy, bind-on-equip)
    DIALOG_QUEUE_TIMEOUT_MS = 120,

    -- List destruction/rebuild delay (ms)
    -- Delay before refreshing list after item operations
    LIST_DESTRUCTION_DELAY_MS = 120,

    -- ========================================================================
    -- SCENE & LAYOUT TIMING
    -- ========================================================================

    -- Weapon swap animation delay for layout updates (ms)
    -- Used by ResourceOrbFrames to delay skill bar layout after weapon swap
    WEAPON_SWAP_LAYOUT_DELAY_MS = 500,

    -- Scene handler delay (ms)
    -- Used by ResourceOrbFrames for post-scene-change updates
    SCENE_HANDLER_DELAY_MS = 200,

    -- Player activated initialization delay (ms)
    -- Delay after EVENT_PLAYER_ACTIVATED before full init
    PLAYER_ACTIVATED_INIT_MS = 100,

    -- Banking directional input fix delay (ms)
    -- Fixes directional input after banking scene transition
    DIRECTIONAL_FIX_DELAY_MS = 60,

    -- Scene show threshold (seconds)
    -- Used for scene ready detection in callbacks
    SCENE_SHOW_THRESHOLD_SEC = 0.2,

    -- Update debounce (seconds, alternative unit)
    -- Equivalent to DEBOUNCE_MS but in seconds for APIs that expect float
    UPDATE_DEBOUNCE_SEC = 0.05,
}


-- ============================================================================
-- MODULE IDENTIFIERS
-- Centralized string constants for CIM PositionManager namespacing
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.MODULES
Description: Module identifier strings for CIM shared services.
             Used by PositionManager to namespace saved positions.
             Eliminates magic string concatenation across modules.
Used By: Inventory/State/PositionManager.lua, Banking/State/StateManager.lua
]]
BETTERUI.CIM.CONST.MODULES = {
    -- Inventory module identifiers
    INVENTORY = "Inventory",
    INVENTORY_ITEMS = "Inventory_Items",
    INVENTORY_CRAFTBAG = "Inventory_CraftBag",

    -- Banking module identifiers
    BANKING = "Banking",
    BANKING_WITHDRAW = "Banking_Withdraw",
    BANKING_DEPOSIT = "Banking_Deposit",
}


-- ============================================================================
-- SEARCH BAR POSITIONING
-- Centralized search bar constants to eliminate duplication across modules
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.SEARCH_BAR
Description: Search bar positioning constants for list-based screens.
             Contains base values (used by Inventory) and module-specific overrides.
Used By: Inventory/Constants.lua, Banking/Constants.lua, SearchManager.lua
]]
BETTERUI.CIM.CONST.SEARCH_BAR = {
    -- Base values (default, used by Inventory)
    BASE = {
        --[[
        Field: X_OFFSET
        Description: Horizontal offset from left edge for search bar.
        Direction: Positive (+) moves RIGHT.
        ]]
        X_OFFSET = 55,
        --[[
        Field: Y_OFFSET
        Description: Vertical offset from header bottom for search bar.
        Direction: Positive (+) moves DOWN.
        ]]
        Y_OFFSET = 1,
        --[[
        Field: RIGHT_INSET
        Description: Right edge inset for search bar width.
        Direction: Negative (-) moves LEFT (narrower).
        ]]
        RIGHT_INSET = -4,
    },
    -- Banking-specific overrides (different header layout)
    BANKING = {
        X_OFFSET = 58,
        Y_OFFSET = 15,
        RIGHT_INSET = -8,
    },
}

--[[
Function: BETTERUI.CIM.GetSearchBarConstants
Description: Returns search bar positioning constants for a specific module.
param: module (string) - "INVENTORY" or "BANKING" (defaults to INVENTORY)
return: table - The search bar constants { X_OFFSET, Y_OFFSET, RIGHT_INSET }
]]
function BETTERUI.CIM.GetSearchBarConstants(module)
    if module == "BANKING" then
        return BETTERUI.CIM.CONST.SEARCH_BAR.BANKING
    end
    return BETTERUI.CIM.CONST.SEARCH_BAR.BASE
end

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
    --[[
    Constant: CONTAINER
    Description: Offsets for list container anchoring relative to header/footer.
    Direction: Negative (-) X moves LEFT from anchor, Positive (+) Y moves DOWN.
    Used By: Banking.lua, WindowClass.lua
    ]]
    CONTAINER = {
        HEADER_X_OFFSET = 0,  -- Indent left from header (shift row data left/right)
        HEADER_Y_OFFSET = 17, -- Push list below header column bar/dividers
        FOOTER_Y_OFFSET = 10, -- Padding above footer
        -- Fixed offset for column headers (decoupled from list position)
        -- Calculation: entry_padding(36) + fine_tune(-35) = +1
        COLUMN_HEADER_X_ADJUST = 1,
    },
}

--[[
Constant: BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET
Description: Y offset for column header labels relative to header bar.
Direction: Positive (+) moves DOWN.
Used By: WindowClass.lua AddColumn method
]]
BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET = 109

--[[
Constant: BETTERUI.CIM.CONST.LAYOUT.COLUMN_WIDTHS
Description: Column widths for header hit regions used in sorting.
Used By: WindowClass.lua AddColumn method
Layout: { NAME, TYPE, TRAIT, STAT, VALUE }
]]
BETTERUI.CIM.CONST.LAYOUT.COLUMN_WIDTHS = { 540, 250, 180, 130, 100 }

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.COLUMNS
Description: X Offsets and Widths for the inventory grid columns.
Direction: OFFSET_X is Positive (+) moving RIGHT from the left edge of the list entry.
Used By: Inventory list templates.
]]
BETTERUI.CIM.CONST.LAYOUT.COLUMNS = {
    SUBMENU = { OFFSET_X = 87, WIDTH = 540 },
    TYPE    = { OFFSET_X = 560, WIDTH = 250 },  -- +10 from 550
    TRAIT   = { OFFSET_X = 820, WIDTH = 180 },  -- +10 from 810
    STAT    = { OFFSET_X = 1010, WIDTH = 130 }, -- +10 from 1000
    VALUE   = { OFFSET_X = 1160, WIDTH = 100 }, -- +10 from 1150
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

    -- Tooltip research status colors (hex strings for inline coloring)
    RESEARCHABLE = "00FF00",   -- Green for "Researchable" text
    FOUND_LOCATION = "FF9900", -- Orange for "Found in X" location text
}

--[[
Table: BETTERUI.CIM.CONST.SEARCH_CHILD_NAMES
Description: Child control names to check for mouse interactivity in search controls.
Rationale: Centralizes fragile hardcoded array for easier maintenance.
Used By: CIM/Core/SearchManager.lua PatchMouseInteractivity function.
]]
BETTERUI.CIM.CONST.SEARCH_CHILD_NAMES = {
    "Edit", "TextField", "SearchEdit", "Input", "Entry",
    "EditBox", "SearchIcon", "Icon", "Texture", "InputContainer"
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
-- SORT SCHEMA
-- Shared sort schema for gamepad inventory-style lists
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.SORT_SCHEMA
Description: Sort schema for gamepad inventory item ordering.
             Defines the sort priority chain: Type -> Name -> Level -> CP -> Icon -> ID.
Used By: DefaultSortComparator for Inventory and Banking list sorting.
]]
BETTERUI.CIM.CONST.SORT_SCHEMA = {
    sortPriorityName       = { tiebreaker = "bestItemTypeName" },
    bestItemTypeName       = { tiebreaker = "name" },
    name                   = { tiebreaker = "requiredLevel" },
    requiredLevel          = { tiebreaker = "requiredChampionPoints", isNumeric = true },
    requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
    iconFile               = { tiebreaker = "uniqueId" },
    uniqueId               = { isId64 = true },
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
        TYPE = 647,   -- +10 from 637
        TRAIT = 907,  -- +10 from 897
        STAT = 1097,  -- +10 from 1087
        VALUE = 1247, -- +10 from 1237
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

-- AUDIT (2026-01-28): Backward compatibility aliases still in use by:
-- TODO(cleanup): P1 OVERDUE - These aliases were planned for v3.0 removal (current version).
-- Complete XML template migration and remove these backward compatibility aliases.
-- See: sr_engineering_team_review.md for priority assignment
-- Estimated effort: 2 hours
--   XML Templates:
--     - Modules/CIM/UI/GenericHeader.xml
--     - Modules/CIM/UI/GenericFooter.xml
--     - Modules/Banking/Templates/BankList.xml
--     - Modules/Inventory/Templates/*.xml
--   Lua Files:
--     - Various legacy imports across Banking and Inventory modules
--
-- These aliases provide global constant names for XML attribute references which
-- cannot use Lua namespace syntax (e.g., BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH).
--
-- TARGET: Audit and remove aliases after all XML templates are migrated to use
-- virtual control offsets or Lua-based initialization. Planned for v3.0 release.

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
