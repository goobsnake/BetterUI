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

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.MarketIntegration = BETTERUI.CIM.MarketIntegration or {}

local MarketIntegration = BETTERUI.CIM.MarketIntegration

local PRIORITY_ORDERS = {
    mm_att_ttc = { "mm", "att", "ttc" },
    mm_ttc_att = { "mm", "ttc", "att" },
    att_mm_ttc = { "att", "mm", "ttc" },
    att_ttc_mm = { "att", "ttc", "mm" },
    ttc_mm_att = { "ttc", "mm", "att" },
    ttc_att_mm = { "ttc", "att", "mm" },
}

local PRIORITY_CHOICES = {
    {
        value = "mm_att_ttc",
        labelStringId = SI_BETTERUI_MARKET_PRIORITY_MM_ATT_TTC,
    },
    {
        value = "mm_ttc_att",
        labelStringId = SI_BETTERUI_MARKET_PRIORITY_MM_TTC_ATT,
    },
    {
        value = "att_mm_ttc",
        labelStringId = SI_BETTERUI_MARKET_PRIORITY_ATT_MM_TTC,
    },
    {
        value = "att_ttc_mm",
        labelStringId = SI_BETTERUI_MARKET_PRIORITY_ATT_TTC_MM,
    },
    {
        value = "ttc_mm_att",
        labelStringId = SI_BETTERUI_MARKET_PRIORITY_TTC_MM_ATT,
    },
    {
        value = "ttc_att_mm",
        labelStringId = SI_BETTERUI_MARKET_PRIORITY_TTC_ATT_MM,
    },
}

local function IsModuleToggleEnabled(settings, key)
    return settings and settings[key] ~= false
end

local function GetPriorityKey(settings)
    if not settings then
        return "mm_att_ttc"
    end

    local key = settings.marketPricePriority
    if type(key) ~= "string" or PRIORITY_ORDERS[key] == nil then
        return "mm_att_ttc"
    end
    return key
end

local function FetchMasterMerchantPrice(itemLink, stackCount, settings)
    if MasterMerchant == nil or not IsModuleToggleEnabled(settings, "mmIntegration") then
        return 0
    end

    local mmData = MasterMerchant:itemStats(itemLink, false)
    if mmData and mmData.avgPrice and mmData.avgPrice > 0 then
        return mmData.avgPrice * stackCount
    end

    return 0
end

local function FetchArkadiusPrice(itemLink, stackCount, settings)
    if ArkadiusTradeTools == nil or not IsModuleToggleEnabled(settings, "attIntegration") then
        return 0
    end

    local modules = ArkadiusTradeTools.Modules
    local salesModule = modules and modules.Sales
    if not salesModule or type(salesModule.GetAveragePricePerItem) ~= "function" then
        return 0
    end

    local avgPrice = salesModule:GetAveragePricePerItem(itemLink, nil, nil)
    if avgPrice and avgPrice > 0 then
        return avgPrice * stackCount
    end

    return 0
end

local function FetchTTCPrice(itemLink, stackCount, settings)
    if TamrielTradeCentre == nil or not IsModuleToggleEnabled(settings, "ttcIntegration") then
        return 0
    end

    if TamrielTradeCentrePrice == nil or type(TamrielTradeCentrePrice.GetPriceInfo) ~= "function" then
        return 0
    end

    local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
    if not priceInfo then
        return 0
    end

    if priceInfo.Avg and priceInfo.Avg > 0 then
        return priceInfo.Avg * stackCount
    end

    if priceInfo.SuggestedPrice and priceInfo.SuggestedPrice > 0 then
        return priceInfo.SuggestedPrice * stackCount
    end

    return 0
end

local SOURCE_FETCHERS = {
    mm = FetchMasterMerchantPrice,
    att = FetchArkadiusPrice,
    ttc = FetchTTCPrice,
}

--- Returns localized dropdown choices and values for market source priority.
--- @return table choices
--- @return table choicesValues
function MarketIntegration.GetPriorityChoices()
    local choices = {}
    local values = {}

    for _, entry in ipairs(PRIORITY_CHOICES) do
        choices[#choices + 1] = GetString(entry.labelStringId)
        values[#values + 1] = entry.value
    end

    return choices, values
end

--- Returns the active source order keys for the saved market priority setting.
--- @param settings table|nil GeneralInterface settings table
--- @return table sourceOrder
function MarketIntegration.GetPriorityOrder(settings)
    local key = GetPriorityKey(settings)
    return PRIORITY_ORDERS[key] or PRIORITY_ORDERS.mm_att_ttc
end

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
--- @param itemLink string The item link
--- @param stackCount number|nil The stack size (defaults to 1)
--- @return number totalPrice The calculated total price, or 0 if unavailable
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

    local sourceOrder = MarketIntegration.GetPriorityOrder(tooltipSettings)
    for _, sourceKey in ipairs(sourceOrder) do
        local fetcher = SOURCE_FETCHERS[sourceKey]
        if type(fetcher) == "function" then
            local price = fetcher(itemLink, stackCount, tooltipSettings)
            if price and price > 0 then
                return price
            end
        end
    end

    return 0
end
