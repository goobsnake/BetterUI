--[[
File: Modules/TradingHouse/Module.lua
Purpose: Trading House module scaffold for BetterUI.
         Provides namespace initialization, scene registration hooks,
         and future integration points for enhanced guild store UX.

TH-001: Guild store / Trading House overhaul.

This scaffold establishes:
- BETTERUI.TradingHouse namespace
- Scene interception for gamepad_trading_house
- Foundation for search presets, unit-price display, and batch listing
]]

BETTERUI.TradingHouse = BETTERUI.TradingHouse or {}

local TH = BETTERUI.TradingHouse

-- Scene configuration
TH.SCENE_NAME = "BETTERUI_TRADING_HOUSE"

--- Module setup function — called from BetterUI main initialization.
--- Currently registers the namespace and scene interception hook.
function TH.Setup()
    -- Register scene interception: redirect gamepad_trading_house to BetterUI
    -- NOTE: Full implementation requires custom scene, fragment, and list management.
    -- This scaffold only establishes the interception hook.

    -- Defer scene swap until the native scene is created by the game
    local function OnTradingHouseSceneCreated()
        if SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes["gamepad_trading_house"] then
            -- Mark as interceptable for future BetterUI replacement
            TH.nativeSceneAvailable = true
        end
    end

    -- Attempt lazy detection
    if SCENE_MANAGER then
        EVENT_MANAGER:RegisterForEvent("BetterUI_TradingHouse",
            EVENT_OPEN_TRADING_HOUSE, function()
                OnTradingHouseSceneCreated()
            end)
    end
end

--- Check if the Trading House module has been enabled and initialized.
--- @return boolean initialized
function TH.IsInitialized()
    return TH.nativeSceneAvailable == true
end

--- Placeholder: Returns search preset data for the saved search feature.
--- @return table presets Empty table (placeholder for future implementation)
function TH.GetSearchPresets()
    return {}
end

--- Placeholder: Formats unit price for display.
--- @param totalPrice number Total price
--- @param quantity number Stack quantity
--- @return string formatted Formatted unit price string
function TH.FormatUnitPrice(totalPrice, quantity)
    if not totalPrice or not quantity or quantity == 0 then return "" end
    local unitPrice = math.floor(totalPrice / quantity)
    return tostring(unitPrice) .. "g ea"
end
