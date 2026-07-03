--[[
File: Modules/CIM/Constants.lua
Purpose: Constants for the Common Interface Module (CIM).
         Includes Currency Footer configuration, Header/Footer layout geometry, Carousel settings,
         and shared UI constants migrated from BetterUI.CONST.lua.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.CONST then BETTERUI.CIM.CONST = {} end

-- TIMING CONSTANTS
-- Shared timing values for consistent behavior across modules

--[[
Table: BETTERUI.CIM.CONST.TIMING
Description: Shared timing constants for UI debouncing and coalescing.
             Used by Inventory and Banking to ensure consistent response times.
Used By: PositionManager, HeaderNavigation, list refresh logic.
]]
BETTERUI.CIM.CONST.TIMING = {
    -- DEBOUNCING & COALESCING

    -- Debounce for heavy UI updates (ms)
    DEBOUNCE_MS = 50,

    -- Category navigation coalescing delay (ms)
    CATEGORY_CHANGE_DELAY_MS = 100,

    -- Item move coalescing delay (ms)
    MOVE_COALESCE_DELAY_MS = 100,

    -- Tooltip refresh delay (ms)
    TOOLTIP_REFRESH_DELAY_MS = 300,

    -- KEYBIND TIMING
    -- Used to ensure keybinds are properly registered after scene transitions

    -- Post-init keybind update delay (ms)
    -- Used after scene showing to ensure keybind strip is ready
    KEYBIND_REFRESH_DELAY_MS = 60,

    -- Secondary/tertiary keybind activation delay (ms)
    -- Shorter delay for additional keybind group registration
    KEYBIND_ACTIVATION_DELAY_MS = 40,

    -- LIST & CATEGORY REFRESH

    -- Category list refresh coalescing (ms)
    -- Prevents multiple rapid refreshes when switching categories
    CATEGORY_REFRESH_COALESCE_MS = 80,

    -- Batch processing interval (ms)
    -- Time between batch chunks for large list processing
    BATCH_PROCESS_INTERVAL_MS = 10,

    -- Batch processing sizes
    BATCH_SIZE_INITIAL = 50,
    BATCH_SIZE_REMAINING = 200,

    -- DIALOG & QUEUE TIMING

    -- Dialog queue processing timeout (ms)
    -- Used when queuing dialogs (equip, destroy, bind-on-equip)
    DIALOG_QUEUE_TIMEOUT_MS = 120,

    -- List destruction/rebuild delay (ms)
    -- Delay before refreshing list after item operations
    LIST_DESTRUCTION_DELAY_MS = 120,

    -- SCENE & LAYOUT TIMING

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

    -- BATCH ACTION THROTTLING
    -- Prevents rate-limit kicks when processing many items at once

    -- Estimated-time display threshold (item count)
    -- ETA messaging is shown for large batches where completion may take noticeable time
    BATCH_ETA_THRESHOLD = 50,

    -- Delay/profile tiers for batch actions
    -- Ordered highest->lowest threshold; first match wins.
    -- Tuned for readability + responsiveness while preserving flood protection.
    BATCH_ACTION_THROTTLE_TIERS = {
        { MIN_ITEMS = 50, DELAY_MS = 125, SHOW_PROGRESS = true },
        { MIN_ITEMS = 10, DELAY_MS = 100, SHOW_PROGRESS = true },
        { MIN_ITEMS = 0,  DELAY_MS = 75,  SHOW_PROGRESS = false },
    },

    -- Server-bound batch pacing guard:
    -- add a fixed cooldown pause every N processed items.
    BATCH_SERVER_COOLDOWN_EVERY = 25,
    BATCH_SERVER_COOLDOWN_MS = 1100,
    BATCH_SERVER_MIN_DELAY_MS = 125,
    BATCH_SERVER_MAX_DELAY_MS = 325,
    BATCH_SERVER_AWAIT_INVENTORY_ACK = true,
    BATCH_SERVER_ACK_TIMEOUT_MS = 1800,
    BATCH_SERVER_CHUNK_COST_UNITS = 36,
    BATCH_SERVER_CHUNK_PAUSE_MS = 950,
    BATCH_SERVER_ADAPTIVE_DELAY = true,
    BATCH_SERVER_ADAPTIVE_THRESHOLD = 8,
    BATCH_SERVER_ADAPTIVE_STEP_MS = 16,
    BATCH_SERVER_JITTER_MS = 18,
    BATCH_SERVER_POST_BATCH_COOLDOWN_BASE_MS = 3000,
    BATCH_SERVER_POST_BATCH_COOLDOWN_THRESHOLD = 50,
    BATCH_SERVER_POST_BATCH_COOLDOWN_PER_COST_MS = 35,
    BATCH_SERVER_POST_BATCH_COOLDOWN_MAX_MS = 9000,
    BATCH_SERVER_RATE_WINDOW_MS = 60000,
    BATCH_SERVER_RATE_MAX_ACTIONS = 125,

}


-- UI CONSTANTS
-- Shared UI magic numbers consolidated for maintainability

--[[
Table: BETTERUI.CIM.CONST.UI
Description: Shared UI constants for list and display configuration.
             Consolidates magic numbers from across modules.
Used By: Banking/Banking.lua, Inventory/UI/TooltipUtils.lua
]]
BETTERUI.CIM.CONST.UI = {
    -- Approximate visible items in banking list (for scroll indicator)
    BANKING_VISIBLE_ITEMS = 10,
}

--[[
Table: BETTERUI.CIM.CONST.TOOLTIP
Description: Tooltip font size configuration.
             Contains size offsets applied to base tooltip font size.
Used By: Inventory/UI/TooltipUtils.lua
]]
BETTERUI.CIM.CONST.TOOLTIP = BETTERUI.CIM.CONST.TOOLTIP or {}
BETTERUI.CIM.CONST.TOOLTIP.FONT_OFFSETS = {
    -- Title font is this many pixels larger than base size
    TITLE = 6,
    -- Value font is this many pixels larger than base size
    VALUE = 4,
}


-- MODULE IDENTIFIERS
-- Centralized string constants for CIM PositionManager namespacing

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

    -- Vendor module identifiers
    VENDOR_BUY = "Vendor_Buy",
    VENDOR_SELL = "Vendor_Sell",
    VENDOR_SELL_VENGEANCE = "Vendor_SellVengeance",
    VENDOR_REPAIR = "Vendor_Repair",
    VENDOR_BUYBACK = "Vendor_Buyback",
    VENDOR_FENCE_SELL = "Vendor_FenceSell",
    VENDOR_FENCE_LAUNDER = "Vendor_FenceLaunder",
    VENDOR_STABLE = "Vendor_Stable",
}


-- SEARCH BAR POSITIONING
-- Centralized search bar constants to eliminate duplication across modules

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
        X_OFFSET = 55,    -- Horizontal anchor shift from left edge (+ right, - left)
        Y_OFFSET = 15,    -- Vertical push below banking header (+ down, - up)
        RIGHT_INSET = -8, -- Width trim from right edge (- left = narrower search box)
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

-- Keep the legacy SearchBar helper path alive for scene modules that still
-- resolve shared search positioning through BETTERUI.CIM.SearchBar.GetConstants.
BETTERUI.CIM.SearchBar = BETTERUI.CIM.SearchBar or {}
BETTERUI.CIM.SearchBar.GetConstants = BETTERUI.CIM.GetSearchBarConstants

-- CURRENCY FOOTER CONFIGURATION

-- Maximum currencies that can be displayed in the footer (UI space limit).
-- ECO-001: raised from 12 to 13 so Archival Fortunes (default order 13) renders.
-- PositionLabels (CIM/UI/CurrencyManager.lua) lays currencies out in 2 rows of
-- dynamically measured, width-justified columns, so 13 currencies fit as
-- 7 columns x 2 rows with no extra row and no footer growth; the fixed
-- BETTERUI_CURRENCY_COLUMNS table below is not used by that layout path.
BETTERUI_MAX_VISIBLE_CURRENCIES = 13

-- Footer currency layout positions (X coordinates for each column)
BETTERUI_CURRENCY_COLUMNS = { 190, 350, 510, 670, 830, 990 }

-- Footer currency row positions (Y coordinates for each row)
BETTERUI_CURRENCY_ROWS = { 32, 58, 84 }

-- CURRENCY PRESETS

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
        showCurrencyArchival = true,
        orderCurrencyArchival = 13,
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
        showCurrencyTomePoints = true,
        orderCurrencyTomePoints = 12,
        showCurrencyArchival = true,
        orderCurrencyArchival = 13,
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
        showCurrencyTomePoints = true,
        orderCurrencyTomePoints = 12,
        showCurrencyArchival = true,
        orderCurrencyArchival = 13,
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
        showCurrencyTomePoints = true,
        orderCurrencyTomePoints = 12,
        showCurrencyArchival = true,
        orderCurrencyArchival = 13,
    },
}

-- CATEGORY CAROUSEL (Tab Bar Icons)
-- Used for the rotating category icon bar in Inventory and Banking headers

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


-- HEADER GEOMETRY (Used in GenericHeader.xml)

-- Tuning guidance:
-- * Positive Y offsets move controls DOWN from anchor; negative values move UP.
-- * Increasing heights/size values expands visual footprint and can push nearby rows.
BETTERUI_DIVIDER_HEIGHT = 8                   -- Divider thickness; increase for bolder separator lines.
BETTERUI_HEADER_TABBAR_Y_OFFSET = 25          -- Tab bar vertical offset from header root (+ down, - up).
BETTERUI_HEADER_TABBAR_HEIGHT = 100           -- Tab bar strip height; larger values push list start lower.
BETTERUI_HEADER_Y_OFFSET = 26                 -- Global header block offset from scene anchor (+ down, - up).
BETTERUI_HEADER_TABBAR_LIST_Y_OFFSET = 75     -- Gap between tab bar and list region; larger = more breathing room.
BETTERUI_HEADER_BUMPER_ICON_SIZE = 60         -- LB/RB bumper icon size (square dimensions).
BETTERUI_HEADER_BUMPER_ICON_Y_OFFSET = 5      -- Bumper icon vertical alignment (+ down, - up).
BETTERUI_HEADER_EQUIP_ROW_Y_OFFSET = -5       -- Equip icon row nudge (+ down, - up); more negative raises row.
BETTERUI_HEADER_COLUMN_HEADER_Y_OFFSET = 95   -- Column label baseline position from tab bar anchor (+ down, - up).
BETTERUI_HEADER_DIVIDER_OFFSET_Y = 77         -- First divider Y position below header (+ down, - up).
BETTERUI_HEADER_DIVIDER_OFFSET_Y_SPACED = 81  -- Second divider Y position; larger value increases divider gap.
BETTERUI_HEADER_BOTTOM_DIVIDER_Y_OFFSET = 110 -- Bottom divider position before list body begins (+ down, - up).

-- FOOTER GEOMETRY (Used in GenericFooter.xml and GenericFooter.lua)

BETTERUI_FOOTER_START_X = 190          -- First footer currency column X origin (+ right, - left).
BETTERUI_FOOTER_RIGHT_PADDING = 50     -- Right-side inset for footer content; larger = pulls columns left.
BETTERUI_FOOTER_BOTTOM_OFFSET_Y = -195 -- Footer vertical offset from bottom anchor (+ down, - up).
BETTERUI_FOOTER_DIVIDER_OFFSET_Y = 15  -- Divider offset inside footer container (+ down, - up).

-- UI LAYOUT / TOOLTIP / ICON / SORT CONSTANTS
-- Tooltip layout constants, BETTERUI.CIM.CONST.LAYOUT, the XML layout alias
-- globals, COLORS, SEARCH_CHILD_NAMES, TOOLTIP_DEFAULTS, ICONS, DEFAULTS,
-- SORT_SCHEMA, and HEADER_LAYOUT live in ConstantsUI.lua — the canonical home
-- for UI constants, which the manifest loads immediately after this file.
