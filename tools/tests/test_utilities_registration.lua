--[[
File: tools/tests/test_utilities_registration.lua
Purpose: Regression coverage for CIM utility callback registration seams.
Usage:
  lua tools/tests/test_utilities_registration.lua
]]

local passed = 0
local failed = 0
local matcherCalls = {}

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

BETTERUI = {
    CIM = {
        Utils = {},
        Debug = {
            IsEnabled = function()
                return false
            end,
        },
        CONST = {
            SORT_SCHEMA = {},
        },
    },
    Settings = {
        Modules = {},
    },
}

SCENE_MANAGER = { scenes = {} }

function d(msg)
    return msg
end

function ZO_TableOrderingFunction()
    return false
end

ZO_SORT_ORDER_UP = 1

BAG_HOUSE_BANK_ONE = 1
BAG_HOUSE_BANK_TWO = 2
BAG_HOUSE_BANK_THREE = 3
BAG_HOUSE_BANK_FOUR = 4
BAG_HOUSE_BANK_FIVE = 5
BAG_HOUSE_BANK_SIX = 6
BAG_HOUSE_BANK_SEVEN = 7
BAG_HOUSE_BANK_EIGHT = 8
BAG_HOUSE_BANK_NINE = 9
BAG_HOUSE_BANK_TEN = 10

dofile("Modules/CIM/Core/Utilities.lua")

print("[Utilities callback registration]")

assert_true(type(BETTERUI.CIM.Utils.RegisterResearchableTraitMatcher) == "function",
    "utilities expose research matcher registration")

BETTERUI.CIM.Utils.RegisterResearchableTraitMatcher(function(itemLink, bagId)
    table.insert(matcherCalls, { itemLink = itemLink, bagId = bagId })
    return bagId
end)

do
    local total = BETTERUI.CIM.Utils.GetHouseBankTraitMatches("|H1:item|h")
    assert_eq(total, 55, "registered matcher drives house bank aggregation")
    assert_eq(#matcherCalls, 10, "house bank matcher runs once per house bank bag")
    assert_eq(matcherCalls[1].itemLink, "|H1:item|h", "matcher receives the original item link")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
