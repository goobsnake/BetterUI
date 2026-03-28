--[[
File: Modules/Loot/Module.lua
Purpose: Enhanced loot window module scaffold for BetterUI.
         Provides namespace initialization for the gamepad loot window.
         Add to MODULE_REGISTRY in BetterUI.lua when ready for activation.

ECO-001: Enhanced gamepad loot window with BetterUI styling.

This scaffold establishes:
- BETTERUI.Loot namespace
- Foundation for market price integration in loot display
]]

BETTERUI.Loot = BETTERUI.Loot or {}

local Loot = BETTERUI.Loot

-- Scene configuration
Loot.SCENE_NAME = "BETTERUI_LOOT"

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
