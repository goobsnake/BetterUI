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
