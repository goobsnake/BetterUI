--[[
File: Modules/CIM/Core/Integration/MarketIntegration.lua
Purpose: Integration with third-party trade addons for price data.
         Supports MasterMerchant, Arkadius Trade Tools, and Tamriel Trade Centre.
]]

-- MARKET PRICE INTEGRATION

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.MarketIntegration = BETTERUI.CIM.MarketIntegration or {}

local MarketIntegration = BETTERUI.CIM.MarketIntegration
local OptionalAddons = assert(BETTERUI.CIM.OptionalAddons,
    "BetterUI: CIM.OptionalAddons must load before MarketIntegration")
local ADDON_KEYS = assert(OptionalAddons.KEYS,
    "BetterUI: CIM.OptionalAddons.KEYS must load before MarketIntegration")

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

local TTC_FALLBACK_NOTICE = {
    unavailable = {
        warned = false,
    },
    malformed = {
        warned = false,
    },
    apiAvailable = nil,
}

local function MaybeWarnTTCFallback(reason, itemLink)
    if not BETTERUI.Log or type(BETTERUI.Log.Warn) ~= "function" then return end
    local notice = TTC_FALLBACK_NOTICE[reason]
    if not notice or notice.warned then return end
    local message
    if reason == "unavailable" then
        message = "TTC fallback path: TamrielTradeCentre_ItemInfo.New unavailable; using raw itemLink (best-effort, may return nil)"
    elseif reason == "malformed" then
        message = "TTC fallback path: TamrielTradeCentre_ItemInfo.New returned invalid payload; using raw itemLink (best-effort, may return nil)"
    else
        return
    end
    pcall(BETTERUI.Log.Warn, BETTERUI.Log.CATEGORY.GENERAL, message, { itemLink = itemLink })
    notice.warned = true
end

local function TrackTTCItemInfoApiAvailability(itemLink)
    local hasApi = type(TamrielTradeCentre_ItemInfo) == "table" and type(TamrielTradeCentre_ItemInfo.New) == "function"
    if not hasApi and TTC_FALLBACK_NOTICE.apiAvailable ~= false then
        MaybeWarnTTCFallback("unavailable", itemLink)
        TTC_FALLBACK_NOTICE.apiAvailable = false
        TTC_FALLBACK_NOTICE.malformed.warned = false
        return false
    end
    if hasApi and TTC_FALLBACK_NOTICE.apiAvailable == false and BETTERUI.Log and type(BETTERUI.Log.Info) == "function" then
        pcall(BETTERUI.Log.Info, BETTERUI.Log.CATEGORY.GENERAL, "TTC item-info API restored; using TamrielTradeCentre_ItemInfo.New path")
        TTC_FALLBACK_NOTICE.unavailable.warned = false
    end
    if hasApi then
        TTC_FALLBACK_NOTICE.apiAvailable = true
    end
    return hasApi
end

local function CallOptionalAddon(method, self, ...)
    local ok, result = pcall(method, self, ...)
    if not ok then
        if BETTERUI.Log then
            BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.GENERAL, "optional addon call failed", { error = tostring(result) })
        end
        return nil
    end
    return result
end

local function NormalizeNumber(value)
    local valueType = type(value)
    if valueType ~= "number" and valueType ~= "string" then
        return nil
    end
    return tonumber(value)
end

local function FetchMasterMerchantUnitPrice(itemLink)
    if type(MasterMerchant) ~= "table" or type(MasterMerchant.itemStats) ~= "function" then
        return nil
    end

    local mmData = CallOptionalAddon(MasterMerchant.itemStats, MasterMerchant, itemLink, false)
    if type(mmData) ~= "table" then
        return nil
    end

    local avgPrice = NormalizeNumber(mmData.avgPrice)
    if avgPrice and avgPrice > 0 then
        return avgPrice
    end

    return nil
end

local function FetchArkadiusUnitPrice(itemLink)
    if type(ArkadiusTradeTools) ~= "table" then
        return nil
    end

    local modules = ArkadiusTradeTools.Modules
    if type(modules) ~= "table" then
        return nil
    end

    local salesModule = modules and modules.Sales
    if type(salesModule) ~= "table" or type(salesModule.GetAveragePricePerItem) ~= "function" then
        return nil
    end

    local avgPrice = NormalizeNumber(CallOptionalAddon(salesModule.GetAveragePricePerItem, salesModule, itemLink, nil, nil))
    if avgPrice and avgPrice > 0 then
        return avgPrice
    end

    return nil
end

local function FetchTTCPriceInfo(itemLink)
    if TamrielTradeCentre == nil then
        return nil
    end

    if type(TamrielTradeCentrePrice) ~= "table" or type(TamrielTradeCentrePrice.GetPriceInfo) ~= "function" then
        return nil
    end

    local hasItemInfoApi = TrackTTCItemInfoApiAvailability(itemLink)
    if hasItemInfoApi then
        local itemInfo = CallOptionalAddon(TamrielTradeCentre_ItemInfo.New, TamrielTradeCentre_ItemInfo, itemLink)
        if type(itemInfo) == "table" then
            local priceInfo = CallOptionalAddon(TamrielTradeCentrePrice.GetPriceInfo, TamrielTradeCentrePrice, itemInfo)
            if type(priceInfo) == "table" then
                TTC_FALLBACK_NOTICE.malformed.warned = false
                return priceInfo
            end
        else
            MaybeWarnTTCFallback("malformed", itemLink)
        end
    end

    local priceInfo = CallOptionalAddon(TamrielTradeCentrePrice.GetPriceInfo, TamrielTradeCentrePrice, itemLink)
    if type(priceInfo) == "table" then
        return priceInfo
    end
    return nil
end

local SOURCE_DEFS = {
    mm = {
        settingKey = "mmIntegration",
        addonKey = ADDON_KEYS.MASTER_MERCHANT,
        isAvailable = function()
            return OptionalAddons.IsLoaded(ADDON_KEYS.MASTER_MERCHANT)
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
        addonKey = ADDON_KEYS.ARKADIUS_TRADE_TOOLS,
        isAvailable = function()
            return OptionalAddons.IsLoaded(ADDON_KEYS.ARKADIUS_TRADE_TOOLS)
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
        addonKey = ADDON_KEYS.TAMRIEL_TRADE_CENTRE,
        isAvailable = function()
            return OptionalAddons.IsLoaded(ADDON_KEYS.TAMRIEL_TRADE_CENTRE)
                and type(TamrielTradeCentrePrice) == "table"
                and type(TamrielTradeCentrePrice.GetPriceInfo) == "function"
        end,
        fetch = function(itemLink, stackCount)
            local priceInfo = FetchTTCPriceInfo(itemLink)
            if not priceInfo then
                return EMPTY_MARKET_PRICE_INFO
            end

            local avgPrice = NormalizeNumber(priceInfo.Avg)
            local suggestedPrice = NormalizeNumber(priceInfo.SuggestedPrice)
            if avgPrice and avgPrice > 0 then
                return CreateMarketPriceInfo({
                    price = avgPrice * stackCount,
                    unitPrice = avgPrice,
                    sourceKey = "ttc",
                    isAverage = true,
                    averagePrice = avgPrice,
                    suggestedPrice = suggestedPrice,
                    hasData = true,
                })
            end

            if suggestedPrice and suggestedPrice > 0 then
                return CreateMarketPriceInfo({
                    price = suggestedPrice * stackCount,
                    unitPrice = suggestedPrice,
                    sourceKey = "ttc",
                    isAverage = false,
                    suggestedPrice = suggestedPrice,
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
    local availableOk, available = pcall(sourceDef.isAvailable)
    if not availableOk then
        if BETTERUI.Log then
            BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.GENERAL, "market source availability check failed", { source = sourceKey, error = tostring(available) })
        end
    end
    available = availableOk and available == true or false
    if not itemLink or not enabled or not available then
        return CreateMarketPriceInfo({
            sourceKey = sourceKey,
            enabled = enabled,
            available = available,
        })
    end

    local ok, sourceInfo = pcall(sourceDef.fetch, itemLink, stackCount or 1)
    if not ok or type(sourceInfo) ~= "table" then
        if BETTERUI.Log then
            BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.GENERAL, "market source price fetch failed", { source = sourceKey, error = tostring(sourceInfo) })
        end
        sourceInfo = EMPTY_MARKET_PRICE_INFO
    end
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
    return CloneArray(PRIORITY_ORDERS[key] or PRIORITY_ORDERS.mm_att_ttc)
end

---@param itemLink string?
---@param stackCount integer?
---@return table
function MarketIntegration.GetMarketPriceInfo(itemLink, stackCount)
    if not itemLink then
        return CreateMarketPriceInfo({})
    end
    -- Hot path (called per list row): use the live settings table instead of
    -- GetModuleSettings, which deep-clones the module table on every call.
    -- The returned table is read-only by convention. Fall back to the cloning
    -- accessor when SettingsAccessor has not loaded (standalone test harness).
    local getSettings = BETTERUI.GetModuleSettingsLive or BETTERUI.GetModuleSettings
    if not getSettings then
        return CreateMarketPriceInfo({})
    end
    local generalInterfaceSettings = getSettings("GeneralInterface")
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
