--[[
File: tools/tests/test_optional_addon_isolation.lua
Purpose: Regression tests for optional third-party addon crash isolation.
Usage:
  lua tools/tests/test_optional_addon_isolation.lua
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_no_error(ok, label)
    assert_eq(ok, true, label)
end

local function assert_count(actual, expected, label)
    if #actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %d, got %d", label, expected, #actual))
    end
end

local function assert_empty_price_info(ok, priceInfo, label)
    assert_no_error(ok, label .. " does not escape GetSourcePriceInfo")
    if ok then
        assert_eq(priceInfo.hasData, false, label .. " returns no price data")
        assert_eq(priceInfo.price, 0, label .. " returns empty price")
    end
end

local function assert_price_info(ok, priceInfo, expectedPrice, label)
    assert_no_error(ok, label .. " does not escape GetSourcePriceInfo")
    if ok then
        assert_eq(priceInfo.sourceKey, "ttc", label .. " uses TTC source")
        if expectedPrice ~= nil then
            assert_eq(priceInfo.price, expectedPrice, label .. " returns expected price")
        end
    end
end

BETTERUI = {
    CIM = {},
    GetModuleSettings = function()
        return {
            mmIntegration = true,
            attIntegration = true,
            ttcIntegration = true,
            marketPricePriority = "mm_att_ttc",
        }
    end,
}

for _, stringId in ipairs({
    "SI_BETTERUI_MARKET_PRIORITY_MM_ATT_TTC",
    "SI_BETTERUI_MARKET_PRIORITY_MM_TTC_ATT",
    "SI_BETTERUI_MARKET_PRIORITY_ATT_MM_TTC",
    "SI_BETTERUI_MARKET_PRIORITY_ATT_TTC_MM",
    "SI_BETTERUI_MARKET_PRIORITY_TTC_MM_ATT",
    "SI_BETTERUI_MARKET_PRIORITY_TTC_ATT_MM",
}) do
    _G[stringId] = stringId
end

function GetString(value)
    return tostring(value)
end

local capturedLogWarnings = {}
local capturedLogInfos = {}
BETTERUI.Log = {
    CATEGORY = {
        GENERAL = "GENERAL",
    },
    Error = function(_, category, message, data)
        capturedLogWarnings[#capturedLogWarnings + 1] = {
            category = category,
            message = message,
            data = data,
        }
    end,
    Warn = function(_, category, message, data)
        capturedLogWarnings[#capturedLogWarnings + 1] = {
            category = category,
            message = message,
            data = data,
        }
    end,
    Info = function(_, category, message, data)
        capturedLogInfos[#capturedLogInfos + 1] = {
            category = category,
            message = message,
            data = data,
        }
    end,
}
BETTERUI.CIM.Log = BETTERUI.Log

dofile("Modules/CIM/Core/Integration/OptionalAddonRegistry.lua")
dofile("Modules/CIM/Core/Integration/MarketIntegration.lua")
dofile("Modules/CIM/Core/Integration/AutoCategoryIntegration.lua")

print("[Optional addon isolation]")

local settings = {
    mmIntegration = true,
    attIntegration = true,
    ttcIntegration = true,
}

MasterMerchant = {
    itemStats = function()
        error("MasterMerchant exploded")
    end,
}
local ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "mm", "|H1:item:1|h", 2, settings)
assert_empty_price_info(ok, priceInfo, "throwing MasterMerchant")

MasterMerchant = {
    itemStats = function()
        return {
            avgPrice = {},
        }
    end,
}
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "mm", "|H1:item:1|h", 2, settings)
assert_empty_price_info(ok, priceInfo, "malformed MasterMerchant price")

ArkadiusTradeTools = {
    Modules = {
        Sales = {
            GetAveragePricePerItem = function()
                error("ATT exploded")
            end,
        },
    },
}
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "att", "|H1:item:1|h", 2, settings)
assert_empty_price_info(ok, priceInfo, "throwing Arkadius Trade Tools")

ArkadiusTradeTools.Modules.Sales.GetAveragePricePerItem = function()
    return {}
end
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "att", "|H1:item:1|h", 2, settings)
assert_empty_price_info(ok, priceInfo, "malformed Arkadius Trade Tools price")

TamrielTradeCentre = true
TamrielTradeCentre_ItemInfo = {
    New = function()
        error("TTC item info exploded")
    end,
}
TamrielTradeCentrePrice = {
    GetPriceInfo = function()
        return {
            Avg = 20,
        }
    end,
}
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_price_info(ok, priceInfo, 40, "throwing TTC item-info factory")

TamrielTradeCentre_ItemInfo.New = function()
    return {
        itemLink = "|H1:item:1|h",
    }
end
TamrielTradeCentrePrice.GetPriceInfo = function()
    error("TTC price exploded")
end
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_empty_price_info(ok, priceInfo, "throwing TTC price lookup")

TamrielTradeCentrePrice.GetPriceInfo = function()
    return {
        Avg = {},
        SuggestedPrice = {},
    }
end
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_empty_price_info(ok, priceInfo, "malformed TTC price info")

capturedLogWarnings = {}
capturedLogInfos = {}
TamrielTradeCentre_ItemInfo = {}
TamrielTradeCentrePrice.GetPriceInfo = function(_, itemRef)
    itemRef = itemRef or _
    if type(itemRef) == "table" and type(itemRef.itemLink) == "string" then
        itemRef = itemRef.itemLink
    end
    if itemRef == "|H1:item:1|h" then
        return {
            Avg = 11,
            SuggestedPrice = 13,
        }
    end
    return {
        Avg = 21,
        SuggestedPrice = 23,
    }
end

ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_no_error(ok, "TTC fallback from missing ItemInfo.New does not error")
assert_eq(priceInfo.hasData, true, "TTC fallback from missing ItemInfo.New returns data")
assert_eq(priceInfo.price, 22, "TTC fallback from missing ItemInfo.New uses raw Avg")
assert_count(capturedLogWarnings, 1, "TTC missing ItemInfo.New emits one warn")

ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_no_error(ok, "repeated TTC fallback from missing ItemInfo.New does not error")
assert_eq(priceInfo.price, 22, "TTC fallback from missing ItemInfo.New returns same data")
assert_count(capturedLogWarnings, 1, "repeated TTC missing ItemInfo.New does not re-warn")

TamrielTradeCentre_ItemInfo.New = function()
    return {
        itemLink = "|H1:item:1|h",
    }
end
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_eq(priceInfo.hasData, true, "TTC API restoration returns data")
assert_eq(priceInfo.price, 22, "TTC API restoration keeps pricing path")
assert_count(capturedLogInfos, 1, "TTC API restoration emits info")

TamrielTradeCentre_ItemInfo.New = function()
    return "bad"
end
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_eq(priceInfo.hasData, true, "TTC malformed ItemInfo.New returns fallback data")
assert_eq(priceInfo.price, 22, "TTC malformed ItemInfo.New keeps fallback pricing")
assert_count(capturedLogWarnings, 2, "TTC malformed ItemInfo.New emits one warn")

ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_eq(priceInfo.hasData, true, "repeated TTC malformed ItemInfo.New does not re-warn")
assert_count(capturedLogWarnings, 2, "repeated TTC malformed ItemInfo.New reuses warning gate")

capturedLogWarnings = {}
capturedLogInfos = {}
TamrielTradeCentre_ItemInfo.New = function()
    return {
        GetItemLink = function()
            return "|H1:item:1|h"
        end,
    }
end
TamrielTradeCentrePrice = {
    GetPriceInfo = function(_, itemRef)
        if type(itemRef) == "table" then
            return nil
        end
        return {
            Avg = 31,
            SuggestedPrice = 33,
        }
    end,
}
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_eq(priceInfo.hasData, true, "TTC item-info object with GetItemLink is converted and priced")
assert_eq(priceInfo.price, 62, "TTC price lookup from extracted itemLink works")
assert_count(capturedLogWarnings, 0, "TTC GetItemLink itemInfo path does not warn")

TamrielTradeCentre_ItemInfo.New = function()
    return {
        itemLink = "|H1:item:1|h",
    }
end
TamrielTradeCentrePrice = {
    GetPriceInfo = nil,
    GetPriceInfoForItem = function(_, itemRef)
        return {
            Avg = 25,
            SuggestedPrice = 26,
        }
    end,
}
ok, priceInfo = pcall(BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo, "ttc", "|H1:item:1|h", 2, settings)
assert_eq(priceInfo.hasData, true, "TTC alternative GetPriceInfoForItem API is supported")
assert_eq(priceInfo.price, 50, "TTC alternative price API still applies stack count")

AutoCategory = {
    Inited = true,
    MatchCategoryRules = function()
        error("AutoCategory exploded")
    end,
}
local useCustomCategory, matched, categoryName, categoryPriority
ok, useCustomCategory, matched, categoryName, categoryPriority = pcall(
    BETTERUI.CIM.AutoCategoryIntegration.GetCustomCategory,
    { bagId = 1, slotIndex = 2 }
)
assert_no_error(ok, "throwing AutoCategory does not escape GetCustomCategory")
if ok then
    assert_eq(useCustomCategory, true, "throwing AutoCategory keeps integration availability")
    assert_eq(matched, false, "throwing AutoCategory returns no match")
    assert_eq(categoryName, "", "throwing AutoCategory returns empty category")
    assert_eq(categoryPriority, 0, "throwing AutoCategory returns zero priority")
end

AutoCategory.MatchCategoryRules = function()
    return "matched", {}, {}
end
ok, useCustomCategory, matched, categoryName, categoryPriority = pcall(
    BETTERUI.CIM.AutoCategoryIntegration.GetCustomCategory,
    { bagId = 1, slotIndex = 2 }
)
assert_no_error(ok, "malformed AutoCategory result does not escape GetCustomCategory")
if ok then
    assert_eq(useCustomCategory, true, "malformed AutoCategory keeps integration availability")
    assert_eq(matched, false, "malformed AutoCategory match normalizes to false")
    assert_eq(categoryName, "", "malformed AutoCategory category normalizes to empty")
    assert_eq(categoryPriority, 0, "malformed AutoCategory priority normalizes to zero")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
