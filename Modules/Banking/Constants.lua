--[[
File: Modules/Banking/Constants.lua
Purpose: Constants for the Banking module.
         Includes search bar positioning and carousel overrides.
Last Modified: 2026-01-23
]]

if not BETTERUI.Banking then BETTERUI.Banking = {} end
if not BETTERUI.Banking.CONST then BETTERUI.Banking.CONST = {} end

-- ============================================================================
-- CATEGORY CAROUSEL OVERRIDES
-- Banking-specific carousel overrides (nil means use default)
-- ============================================================================

--[[
Constant: BETTERUI_BANKING_CAROUSEL_START_OFFSET
Description: Horizontal position for banking carousel.
Direction: Positive (+) moves RIGHT.
Used By: Banking.lua
]]
BETTERUI_BANKING_CAROUSEL_START_OFFSET = 705

--[[
Constant: BETTERUI_BANKING_CAROUSEL_VERTICAL_OFFSET
Description: Vertical offset for banking carousel.
Direction: Positive (+) moves DOWN, Negative (-) moves UP.
Used By: Banking.lua
]]
BETTERUI_BANKING_CAROUSEL_VERTICAL_OFFSET = -1

-- ============================================================================
-- SEARCH BAR POSITIONING
-- Controls the position of the search input field in banking headers
-- ============================================================================

--[[
Constant: BETTERUI_BANK_SEARCH_X_OFFSET
Description: Horizontal offset from left edge for search bar.
Direction: Positive (+) moves RIGHT.
Used By: Banking.lua
]]
BETTERUI_BANK_SEARCH_X_OFFSET = 58

--[[
Constant: BETTERUI_BANK_SEARCH_Y_OFFSET
Description: Vertical offset from header bottom for search bar.
Direction: Positive (+) moves DOWN.
Used By: Banking.lua
]]
BETTERUI_BANK_SEARCH_Y_OFFSET = 15

--[[
Constant: BETTERUI_BANK_SEARCH_RIGHT_INSET
Description: Right edge inset for search bar width.
Direction: Negative (-) moves LEFT (narrower).
Used By: Banking.lua
]]
BETTERUI_BANK_SEARCH_RIGHT_INSET = -8

-- ============================================================================
-- UI TWEAKS
-- Magic numbers extracted from Banking.lua and StateManager.lua
-- ============================================================================

--[[
Constant: BETTERUI_BANK_LIST_MAX_OFFSET
Description: Maximum vertical offset for the banking list.
Used By: Banking.lua
]]
BETTERUI_BANK_LIST_MAX_OFFSET = 30

--[[
Constant: BETTERUI_BANK_HEADER_PADDING_SCALE
Description: Scale factor for header padding to align with list.
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
BETTERUI_BANK_DEPOSIT_ARROW_ROTATION = 3.1415 -- Pi
