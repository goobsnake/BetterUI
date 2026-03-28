--[[
File: Modules/Loot/Module.lua
Purpose: Enhanced loot window module scaffold for BetterUI.
         Provides namespace initialization and scene interception
         for the gamepad loot window.

ECO-001: Enhanced gamepad loot window with BetterUI styling.

This scaffold establishes:
- BETTERUI.Loot namespace
- Scene interception for gamepad_loot
- Foundation for market price integration in loot display
]]

BETTERUI.Loot = BETTERUI.Loot or {}

local Loot = BETTERUI.Loot

-- Scene configuration
Loot.SCENE_NAME = "BETTERUI_LOOT"

--- Module setup function — called from BetterUI main initialization.
--- Registers namespace and loot scene detection.
function Loot.Setup()
    -- Register for loot events to detect when loot window should show
    if EVENT_MANAGER then
        EVENT_MANAGER:RegisterForEvent("BetterUI_Loot",
            EVENT_LOOT_RECEIVED, function(_, receivedBy, itemLink, quantity, _, _, _, _, _, _, _)
                -- Future: Enhanced loot notification with market price
                Loot.lastLootLink = itemLink
                Loot.lastLootQuantity = quantity
            end)
    end

    Loot.initialized = true
end

--- Check if the Loot module has been initialized.
--- @return boolean initialized
function Loot.IsInitialized()
    return Loot.initialized == true
end

--- Placeholder: Gets market price context for a looted item.
--- @param itemLink string The item link
--- @return string|nil priceText Formatted price text, or nil
function Loot.GetMarketPriceContext(itemLink)
    if not itemLink or itemLink == "" then return nil end

    -- Future: Integrate with TTC/MM/ATT price sources
    -- Uses same infrastructure as BETTERUI.GetInventoryPriceInfo
    local ok, priceLines = BETTERUI.CIM.SafeExecute("Loot:GetMarketPriceContext", BETTERUI.GetInventoryPriceInfo, itemLink, nil, nil, nil)
    if ok and priceLines and #priceLines > 0 then
        return table.concat(priceLines, " | ")
    end
    return nil
end
