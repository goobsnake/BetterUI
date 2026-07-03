--[[
File: tools/tests/test_market_integration.lua
Purpose: Regression tests for migrated market-price settings ownership in
         CIM/Core/Integration/MarketIntegration.lua.
Usage:
  lua tools/tests/test_market_integration.lua
]]

if false then
    dofile("Modules/CIM/Core/Integration/MarketIntegration.lua")
end

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

local function assert_contains(haystack, needle, label)
    if haystack and haystack:find(needle, 1, true) then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- missing %s", label, tostring(needle)))
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack and not haystack:find(needle, 1, true) then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- unexpected %s", label, tostring(needle)))
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local moduleSettings = {
    GeneralInterface = {},
    Tooltips = {},
}

BETTERUI = {
    CIM = {},
    GetModuleSettings = function(moduleName)
        return moduleSettings[moduleName] or {}
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

MasterMerchant = {
    itemStats = function()
        return { avgPrice = 10 }
    end,
}

ArkadiusTradeTools = {
    Modules = {
        Sales = {
            GetAveragePricePerItem = function()
                return 5
            end,
        },
    },
}

TamrielTradeCentre = true
TamrielTradeCentre_ItemInfo = {
    New = function(_, itemLink)
        return {
            itemLink = itemLink,
        }
    end,
}
TamrielTradeCentrePrice = {
    GetPriceInfo = function(_, itemRef)
        if type(itemRef) == "table" and itemRef.itemLink then
            return {
                Avg = 3,
                SuggestedPrice = 4,
            }
        end
        return {
            Avg = 3,
        }
    end,
}
dofile("Modules/CIM/Core/Integration/OptionalAddonRegistry.lua")
dofile("Modules/CIM/Core/Integration/MarketIntegration.lua")

print("[Market integration]")

moduleSettings.GeneralInterface = {}
moduleSettings.Tooltips = {
    mmIntegration = false,
    marketPricePriority = "ttc_mm_att",
}
local priceInfo = BETTERUI.CIM.MarketIntegration.GetMarketPriceInfo("|H1:item:1|h", 2)
assert_eq(priceInfo.sourceKey, "mm", "legacy Tooltips priority no longer controls runtime source selection")
assert_eq(priceInfo.price, 20, "legacy Tooltips integration toggles no longer suppress market prices")

moduleSettings.GeneralInterface = {
    mmIntegration = false,
    attIntegration = true,
    marketPricePriority = "att_mm_ttc",
}
moduleSettings.Tooltips = {
    mmIntegration = true,
}
priceInfo = BETTERUI.CIM.MarketIntegration.GetMarketPriceInfo("|H1:item:1|h", 2)
assert_eq(priceInfo.sourceKey, "att", "GeneralInterface priority stays authoritative for runtime market prices")
assert_eq(priceInfo.price, 10, "GeneralInterface integration toggles drive runtime fetch selection")

local ttcInfo = BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo("ttc", "|H1:item:1|h", 2,
    moduleSettings.GeneralInterface)
assert_eq(ttcInfo.averagePrice, 3, "source price info exposes TTC average pricing through the shared adapter")
assert_eq(ttcInfo.suggestedPrice, 4, "source price info preserves TTC suggested pricing for tooltip formatting")
assert_eq(ttcInfo.enabled, true, "source price info reports GeneralInterface enablement")
assert_eq(ttcInfo.available, true, "source price info reports addon availability")

local ttcWarningCount = 0
local ttcMode = "success"
BETTERUI.Log = {
    CATEGORY = { GENERAL = "GENERAL" },
    Warn = function()
        ttcWarningCount = ttcWarningCount + 1
    end,
}
TamrielTradeCentrePrice.GetPriceInfo = function(_, itemRef)
    if ttcMode == "success" and type(itemRef) == "table" and itemRef.itemLink then
        return { Avg = 3 }
    end
    return nil
end
ttcMode = "fail"
BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo("ttc", "|H1:item:malformed1|h", 1, moduleSettings.GeneralInterface)
ttcMode = "success"
BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo("ttc", "|H1:item:valid|h", 1, moduleSettings.GeneralInterface)
ttcMode = "fail"
BETTERUI.CIM.MarketIntegration.GetSourcePriceInfo("ttc", "|H1:item:malformed2|h", 1, moduleSettings.GeneralInterface)
assert_eq(ttcWarningCount, 1, "TTC malformed fallback warning is latched across intermittent successful calls")

local tooltipSource = read_file("Modules/GeneralInterface/Tooltips/Tooltips.lua")
assert_contains(tooltipSource, "marketIntegration.GetSourcePriceInfo(",
    "tooltips route market source lookups through MarketIntegration")
assert_not_contains(tooltipSource, "MasterMerchant:itemStats(",
    "tooltips no longer read Master Merchant directly")
assert_not_contains(tooltipSource, "ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(",
    "tooltips no longer read Arkadius pricing directly")
assert_not_contains(tooltipSource, "TamrielTradeCentrePrice:GetPriceInfo(",
    "tooltips no longer read TTC pricing directly")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
