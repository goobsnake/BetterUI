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
TamrielTradeCentrePrice = {
    GetPriceInfo = function()
        return {
            Avg = 3,
        }
    end,
}

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

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
