--[[
File: Modules/TradingHouse/Module.lua
Purpose: Trading House module scaffold for BetterUI.
         Provides namespace initialization and future integration points
         for enhanced guild store UX.
         Add to MODULE_REGISTRY in BetterUI.lua when ready for activation.

TH-001: Guild store / Trading House overhaul.

This scaffold establishes:
- BETTERUI.TradingHouse namespace
- Foundation for search presets, unit-price display, and batch listing
]]

BETTERUI.TradingHouse = BETTERUI.TradingHouse or {}

local TH = BETTERUI.TradingHouse

-- Scene configuration
TH.SCENE_NAME = "BETTERUI_TRADING_HOUSE"

--- Placeholder: Returns search preset data for the saved search feature.
function TH.GetSearchPresets()
    return {}
end

--- Placeholder: Formats unit price for display.
function TH.FormatUnitPrice(totalPrice, quantity)
    if not totalPrice or not quantity or quantity == 0 then return "" end
    local unitPrice = math.floor(totalPrice / quantity)
    return tostring(unitPrice) .. "g ea"
end
