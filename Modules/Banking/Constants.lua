--[[
File: Modules/Banking/Constants.lua
Purpose: Constants for the Banking module.
         Includes search bar positioning and carousel overrides.
Last Modified: 2026-01-28
]]

if not BETTERUI.Banking then BETTERUI.Banking = {} end
if not BETTERUI.Banking.CONST then BETTERUI.Banking.CONST = {} end

-- ============================================================================
-- CATEGORY CAROUSEL OVERRIDES
-- Banking-specific carousel overrides (differs from CIM defaults)
-- ============================================================================

--[[
Table: BETTERUI.Banking.CONST.CAROUSEL
Description: Banking-specific carousel positioning overrides.
             These values differ from the CIM defaults to account for
             the Banking header layout differences.
Used By: Banking/UI/HeaderManager.lua
]]
BETTERUI.Banking.CONST.CAROUSEL = {
    --[[
    Field: startOffset
    Description: Horizontal position for banking carousel (slightly left of default).
    Direction: Positive (+) moves RIGHT.
    ]]
    startOffset = 705,

    --[[
    Field: verticalOffset
    Description: Vertical offset for banking carousel (higher than default).
    Direction: Positive (+) moves DOWN, Negative (-) moves UP.
    ]]
    verticalOffset = -1,
}

-- ============================================================================
-- SEARCH BAR POSITIONING (delegate to CIM shared constants)
-- Controls the position of the search input field in banking headers
-- ============================================================================

-- Use centralized CIM search bar constants (eliminates duplication with Inventory)
local searchConst = BETTERUI.CIM.GetSearchBarConstants("BANKING")

--[[
Table: BETTERUI.Banking.CONST.SEARCH
Description: Search bar positioning constants for Banking module.
             Delegates to CIM shared constants for single source of truth.
Used By: Banking.lua
]]
BETTERUI.Banking.CONST.SEARCH = {
    X_OFFSET = searchConst.X_OFFSET,       -- Horizontal position from header left (+ right, - left).
    Y_OFFSET = searchConst.Y_OFFSET,       -- Vertical drop from header anchor (+ down, - up).
    RIGHT_INSET = searchConst.RIGHT_INSET, -- Right-edge inset for width (- left = narrower box).
}



-- ============================================================================
-- CURRENCY TEXTURES
-- Icons for currency type selectors in deposit/withdraw dialogs
-- ============================================================================

--[[
Table: BETTERUI.Banking.CONST.CURRENCY_TEXTURES
Description: Maps currency type constants to their gamepad icon paths.
Used By: TransferActions.lua (DisplaySelector)
]]
BETTERUI.Banking.CONST.CURRENCY_TEXTURES = {
    [CURT_MONEY] = "EsoUI/Art/currency/gamepad/gp_gold.dds",
    [CURT_TELVAR_STONES] = "EsoUI/Art/currency/gamepad/gp_telvar.dds",
    [CURT_ALLIANCE_POINTS] = "esoui/art/currency/gamepad/gp_alliancepoints.dds",
    [CURT_WRIT_VOUCHERS] = "EsoUI/Art/currency/gamepad/gp_writvoucher.dds",
}

-- ============================================================================
-- UI TWEAKS
-- Magic numbers extracted from Banking.lua and StateManager.lua
-- ============================================================================

--[[
Constant: BETTERUI_BANK_LIST_MAX_OFFSET
Description: Maximum vertical offset for the banking list.
Direction: Positive (+) moves the list DOWN from its base anchor.
Visual Effect: Increasing this allows more downward drift before clamp; decreasing keeps list tighter to header.
Used By: Banking.lua
]]
BETTERUI_BANK_LIST_MAX_OFFSET = 30

--[[
Constant: BETTERUI_BANK_HEADER_PADDING_SCALE
Description: Scale factor for header padding to align with list.
Visual Effect: >1 increases header side padding (content pulls inward), <1 reduces padding (content stretches outward).
Used By: Banking.lua
]]
BETTERUI_BANK_HEADER_PADDING_SCALE = 0.75

--[[
Constant: BETTERUI_BANK_INACTIVE_LABEL_COLOR
Description: Color for inactive footer toggle buttons (Withdraw/Deposit).
Used By: StateManager.lua
Format: {R, G, B, A}
]]
BETTERUI_BANK_INACTIVE_LABEL_COLOR = { 0.26, 0.26, 0.26, 1 }

--[[
Constant: BETTERUI_BANK_DEPOSIT_ARROW_ROTATION
Description: Rotation (radians) for the selection background arrow in Deposit mode.
Used By: StateManager.lua
]]
BETTERUI_BANK_DEPOSIT_ARROW_ROTATION = math.pi

-- ============================================================================
-- TIMING CONSTANTS (delegate to CIM shared values)
-- Delay values for coalescing operations and UI updates
-- ============================================================================

--[[
Constant: BETTERUI_BANK_MOVE_COALESCE_DELAY_MS
Description: Delay (ms) after item move before refreshing list.
             Allows multiple rapid moves to be coalesced into a single refresh.
Used By: TransferActions.lua
]]
BETTERUI_BANK_MOVE_COALESCE_DELAY_MS = BETTERUI.CIM.CONST.TIMING.MOVE_COALESCE_DELAY_MS

--[[
Constant: BETTERUI_BANK_CATEGORY_CHANGE_DELAY_MS
Description: Delay (ms) after category change before rebuilding list.
             Prevents jarring updates during rapid category switching.
Used By: HeaderManager.lua
]]
BETTERUI_BANK_CATEGORY_CHANGE_DELAY_MS = BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS

-- ============================================================================
-- SCENE CONSTANTS
-- Moved from InterfaceLibrary.lua
-- ============================================================================

--[[
Constant: BETTERUI_BANKING_SCENE_NAME
Description: Scene name used for banking interface registration.
Used By: Banking.lua, WindowClass.lua (ToggleScene)
]]
BETTERUI_BANKING_SCENE_NAME = "BETTERUI_BANKING"

--[[
Constant: BETTERUI.Banking.BANKING_INTERACTION
Description: Interaction table for creating the banking scene.
Used By: Banking.lua (Initialize)
]]
BETTERUI.Banking.BANKING_INTERACTION = {
    type = "Banking",
    interactTypes = { INTERACTION_BANK },
}
