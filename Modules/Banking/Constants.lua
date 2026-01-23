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

BETTERUI_BANKING_CAROUSEL_START_OFFSET = 705   -- Horizontal position for banking carousel (increase to move right)
BETTERUI_BANKING_CAROUSEL_VERTICAL_OFFSET = -1  -- Vertical offset for banking (lower value moves icons up)

-- ============================================================================
-- SEARCH BAR POSITIONING
-- Controls the position of the search input field in banking headers
-- ============================================================================

BETTERUI_BANK_SEARCH_X_OFFSET = 58         -- Horizontal offset from left edge (increase to move right)
BETTERUI_BANK_SEARCH_Y_OFFSET = 15         -- Vertical offset from header bottom (increase to move down)
BETTERUI_BANK_SEARCH_RIGHT_INSET = -8      -- Right edge inset (more negative = narrower search bar)
