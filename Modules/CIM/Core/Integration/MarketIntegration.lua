--[[
File: Modules/CIM/Core/MarketIntegration.lua
Purpose: Integration with third-party trade addons for price data.
         Supports MasterMerchant, Arkadius Trade Tools, and Tamriel Trade Centre.
]]

-- MARKET PRICE INTEGRATION

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.MarketIntegration = BETTERUI.CIM.MarketIntegration or {}

local MarketIntegration = BETTERUI.CIM.MarketIntegration

local function CloneArray(source)
    local clone = {}
    for index, value in ipairs(source or {}) do
        clone[index] = value
    end
    return clone
end

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

local function CreateMarketPriceInfo(fields)
    return {
        price = fields and fields.price or 0,
        unitPrice = fields and fields.unitPrice or 0,
        sourceKey = fields and fields.sourceKey or nil,
        isAverage = fields and fields.isAverage == true or false,
        averagePrice = fields and fields.averagePrice or nil,
        suggestedPrice = fields and fields.suggestedPrice or nil,
        enabled = fields and fields.enabled == true or false,
        available = fields and fields.available == true or false,
        hasData = fields and fields.hasData == true or false,
    }
end

local EMPTY_MARKET_PRICE_INFO = CreateMarketPriceInfo({})

local function FetchMasterMerchantUnitPrice(itemLink)
    if MasterMerchant == nil then
        return nil
    end

    local mmData = MasterMerchant:itemStats(itemLink, false)
    if mmData and mmData.avgPrice and mmData.avgPrice > 0 then
        return mmData.avgPrice
    end

    return nil
end

local function FetchArkadiusUnitPrice(itemLink)
    if ArkadiusTradeTools == nil then
        return nil
    end

    local modules = ArkadiusTradeTools.Modules
    local salesModule = modules and modules.Sales
    if not salesModule or type(salesModule.GetAveragePricePerItem) ~= "function" then
        return nil
    end

    local avgPrice = salesModule:GetAveragePricePerItem(itemLink, nil, nil)
    if avgPrice and avgPrice > 0 then
        return avgPrice
    end

    return nil
end

local function FetchTTCPriceInfo(itemLink)
    if TamrielTradeCentre == nil then
        return nil
    end

    if TamrielTradeCentrePrice == nil or type(TamrielTradeCentrePrice.GetPriceInfo) ~= "function" then
        return nil
    end

    if TamrielTradeCentre_ItemInfo and type(TamrielTradeCentre_ItemInfo.New) == "function" then
        local itemInfo = TamrielTradeCentre_ItemInfo:New(itemLink)
        local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemInfo)
        if priceInfo then
            return priceInfo
        end
    end

    return TamrielTradeCentrePrice:GetPriceInfo(itemLink)
end

local SOURCE_DEFS = {
    mm = {
        settingKey = "mmIntegration",
        isAvailable = function()
            return MasterMerchant ~= nil
        end,
        fetch = function(itemLink, stackCount)
            local unitPrice = FetchMasterMerchantUnitPrice(itemLink)
            if not unitPrice then
                return EMPTY_MARKET_PRICE_INFO
            end

            return CreateMarketPriceInfo({
                price = unitPrice * stackCount,
                unitPrice = unitPrice,
                sourceKey = "mm",
                isAverage = true,
                averagePrice = unitPrice,
                hasData = true,
            })
        end,
    },
    att = {
        settingKey = "attIntegration",
        isAvailable = function()
            return ArkadiusTradeTools ~= nil
        end,
        fetch = function(itemLink, stackCount)
            local unitPrice = FetchArkadiusUnitPrice(itemLink)
            if not unitPrice then
                return EMPTY_MARKET_PRICE_INFO
            end

            return CreateMarketPriceInfo({
                price = unitPrice * stackCount,
                unitPrice = unitPrice,
                sourceKey = "att",
                isAverage = true,
                averagePrice = unitPrice,
                hasData = true,
            })
        end,
    },
    ttc = {
        settingKey = "ttcIntegration",
        isAvailable = function()
            return TamrielTradeCentre ~= nil
                and TamrielTradeCentrePrice ~= nil
                and type(TamrielTradeCentrePrice.GetPriceInfo) == "function"
        end,
        fetch = function(itemLink, stackCount)
            local priceInfo = FetchTTCPriceInfo(itemLink)
            if not priceInfo then
                return EMPTY_MARKET_PRICE_INFO
            end

            if priceInfo.Avg and priceInfo.Avg > 0 then
                return CreateMarketPriceInfo({
                    price = priceInfo.Avg * stackCount,
                    unitPrice = priceInfo.Avg,
                    sourceKey = "ttc",
                    isAverage = true,
                    averagePrice = priceInfo.Avg,
                    suggestedPrice = priceInfo.SuggestedPrice,
                    hasData = true,
                })
            end

            if priceInfo.SuggestedPrice and priceInfo.SuggestedPrice > 0 then
                return CreateMarketPriceInfo({
                    price = priceInfo.SuggestedPrice * stackCount,
                    unitPrice = priceInfo.SuggestedPrice,
                    sourceKey = "ttc",
                    isAverage = false,
                    suggestedPrice = priceInfo.SuggestedPrice,
                    hasData = true,
                })
            end

            return EMPTY_MARKET_PRICE_INFO
        end,
    },
}

function MarketIntegration.GetSourcePriceInfo(sourceKey, itemLink, stackCount, settings)
    local sourceDef = SOURCE_DEFS[sourceKey]
    if not sourceDef then
        return CreateMarketPriceInfo({})
    end

    local enabled = IsModuleToggleEnabled(settings, sourceDef.settingKey)
    local available = sourceDef.isAvailable()
    if not itemLink or not enabled or not available then
        return CreateMarketPriceInfo({
            sourceKey = sourceKey,
            enabled = enabled,
            available = available,
        })
    end

    local sourceInfo = sourceDef.fetch(itemLink, stackCount or 1)
    return CreateMarketPriceInfo({
        price = sourceInfo.price,
        unitPrice = sourceInfo.unitPrice,
        sourceKey = sourceInfo.sourceKey or sourceKey,
        isAverage = sourceInfo.isAverage,
        averagePrice = sourceInfo.averagePrice,
        suggestedPrice = sourceInfo.suggestedPrice,
        enabled = enabled,
        available = available,
        hasData = sourceInfo.hasData,
    })
end

local function FetchSourcePrice(sourceKey, itemLink, stackCount, settings)
    local sourceInfo = MarketIntegration.GetSourcePriceInfo(sourceKey, itemLink, stackCount, settings)
    if sourceInfo.hasData then
        return sourceInfo
    end

    return CreateMarketPriceInfo({})
end

--- Returns localized dropdown choices and values for market source priority.
---@return string[] choices
---@return string[] values
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
---@param settings table?
---@return string[] sourceOrder
function MarketIntegration.GetPriorityOrder(settings)
    local key = GetPriorityKey(settings)
    return CloneArray(PRIORITY_ORDERS[key] or PRIORITY_ORDERS.mm_att_ttc)
end

--- Returns the mutable priority-order table referenced by the selected key.
function MarketIntegration.GetPriorityOrderLive(settings)
    local key = GetPriorityKey(settings)
    return PRIORITY_ORDERS[key] or PRIORITY_ORDERS.mm_att_ttc
end

---@param itemLink string?
---@param stackCount integer?
---@return table
function MarketIntegration.GetMarketPriceInfo(itemLink, stackCount)
    if not itemLink then
        return CreateMarketPriceInfo({})
    end
    local generalInterfaceSettings = BETTERUI.GetModuleSettings("GeneralInterface") or {}
    stackCount = stackCount or 1

    local sourceOrder = MarketIntegration.GetPriorityOrder(generalInterfaceSettings)
    for _, sourceKey in ipairs(sourceOrder) do
        local priceInfo = FetchSourcePrice(sourceKey, itemLink, stackCount, generalInterfaceSettings)
        if priceInfo and priceInfo.price and priceInfo.price > 0 then
            return priceInfo
        end
    end

    return CreateMarketPriceInfo({})
end

---@param itemLink string?
---@param stackCount integer?
---@return number
---@return boolean
---@return string|nil
function MarketIntegration.GetMarketPrice(itemLink, stackCount)
    local priceInfo = MarketIntegration.GetMarketPriceInfo(itemLink, stackCount)
    return priceInfo.price or 0, priceInfo.isAverage == true, priceInfo.sourceKey
end

BETTERUI.GetMarketPrice = MarketIntegration.GetMarketPrice
