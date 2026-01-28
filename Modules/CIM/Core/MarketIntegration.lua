--[[
File: Modules/CIM/Core/MarketIntegration.lua
Purpose: Integration with third-party trade addons for price data.
         Supports MasterMerchant, Arkadius Trade Tools, and Tamriel Trade Centre.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-- ============================================================================
-- MARKET PRICE INTEGRATION
-- ============================================================================

--[[
Function: BETTERUI.GetMarketPrice
Description: Retrieves the market price of an item from third-party trade addons.
Rationale: Integration with MM, ATT, and TTC to display price info in tooltips.
Mechanism: Checks which addon integration is enabled in settings.
           Calls the specific addon's API to fetch price data.
           Returns the average price multiplied by stack size.
References: Used by BetterUI.Tooltips and Inventory rows to show value.
param: itemLink (string) - The item link.
param: stackCount (number) - The stack size (defaults to 1).
return: number - The calculated total price, or 0 if unavailable.
]]
function BETTERUI.GetMarketPrice(itemLink, stackCount)
    if not itemLink then return 0 end
    if not BETTERUI.Settings or not BETTERUI.Settings.Modules then
        return 0
    end
    -- Support both GeneralInterface (new) and Tooltips (legacy) settings keys
    local tooltipSettings = BETTERUI.Settings.Modules["GeneralInterface"] or BETTERUI.Settings.Modules["Tooltips"]
    if not tooltipSettings then
        return 0
    end
    stackCount = stackCount or 1

    -- Check MasterMerchant integration first (most commonly used)
    if MasterMerchant ~= nil and tooltipSettings.mmIntegration then
        local mmData = MasterMerchant:itemStats(itemLink, false)
        if mmData and mmData.avgPrice and mmData.avgPrice > 0 then
            return mmData.avgPrice * stackCount
        end
    end

    -- Check Arkadius Trade Tools
    if ArkadiusTradeTools ~= nil and tooltipSettings.attIntegration then
        local avgPrice = ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(itemLink, nil, nil)
        if avgPrice and avgPrice > 0 then
            return avgPrice * stackCount
        end
    end

    -- Check Tamriel Trade Centre
    if TamrielTradeCentre ~= nil and tooltipSettings.ttcIntegration then
        local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
        if priceInfo then
            if priceInfo.Avg then
                return priceInfo.Avg * stackCount
            elseif priceInfo.SuggestedPrice then
                return priceInfo.SuggestedPrice * stackCount
            end
        end
    end

    return 0
end
