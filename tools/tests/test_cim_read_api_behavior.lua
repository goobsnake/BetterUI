--[[
File: tools/tests/test_cim_read_api_behavior.lua
Purpose: Behavior tests for snapshot/live-table contracts and search lifecycle predicates.

Usage:
  lua tools/tests/test_cim_read_api_behavior.lua
]]

local passed = 0
local failed = 0

local function assert_equal(expected, actual, label)
    if expected == actual then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  [X] %s", label))
        print(string.format("      expected: %s", tostring(expected)))
        print(string.format("      actual:   %s", tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_equal(true, value, label)
end

local function assert_false(value, label)
    assert_equal(false, value, label)
end

print("\n=== CIM Read-API Behavior Tests ===\n")

-- Shared stubs
BETTERUI = {
    CIM = {
        CONST = {
            CraftingSkillTypes = { 1 },
        },
    },
}

function BETTERUI.GetModuleSettings(_)
    return {}
end

function GetNumSmithingResearchLines(_)
    return 0
end

function GetSmithingResearchLineInfo(_, _)
    return nil, nil, 0
end

function GetSmithingResearchLineTraitInfo(_, _, _)
    return nil, nil, false
end

-- Load modules under test
dofile("Modules/CIM/Core/Integration/ResearchCache.lua")
dofile("Modules/CIM/Core/Data/SearchManager.lua")
dofile("Modules/CIM/Core/Integration/OptionalAddonRegistry.lua")
dofile("Modules/CIM/Core/Integration/MarketIntegration.lua")

print("Test: ResearchCache getters expose snapshot vs live semantics")
BETTERUI.CIM.ResearchCache._traits = {
    [1] = {
        [2] = { [3] = true },
    },
}

local researchSnapshot = BETTERUI.CIM.ResearchCache.GetResearch()
researchSnapshot[1][2][3] = false
assert_true(BETTERUI.CIM.ResearchCache.GetResearchLive()[1][2][3], "GetResearch returns an observational snapshot")

local researchLive = BETTERUI.CIM.ResearchCache.GetResearchLive()
researchLive[1][2][3] = false
assert_false(BETTERUI.CIM.ResearchCache.GetResearchLive()[1][2][3], "GetResearchLive returns mutable live state")

print("Test: Search lifecycle predicate does not conflate mode-active with header-active")
local headerStateContext = {
    _searchModeActive = true,
    _searchHeaderActive = false,
}
assert_false(
    BETTERUI.Interface.SearchMixin.IsSearchLifecycleHeaderActive(headerStateContext),
    "header predicate ignores _searchModeActive fallback"
)

headerStateContext._searchHeaderActive = true
assert_true(
    BETTERUI.Interface.SearchMixin.IsSearchLifecycleHeaderActive(headerStateContext),
    "header predicate returns true when _searchHeaderActive is true"
)

local lifecycleMethodContext = {
    SEARCH_LIFECYCLE = { headerActive = "IsHeaderFocused" },
    _searchHeaderActive = false,
}
function lifecycleMethodContext:IsHeaderFocused()
    return true
end
assert_true(
    BETTERUI.Interface.SearchMixin.IsSearchLifecycleHeaderActive(lifecycleMethodContext),
    "header predicate honors canonical lifecycle method when provided"
)

print("Test: MarketIntegration getter APIs are observational")
local orderA = BETTERUI.CIM.MarketIntegration.GetPriorityOrder({ marketPricePriority = "mm_att_ttc" })
orderA[1] = "mutated"
local orderB = BETTERUI.CIM.MarketIntegration.GetPriorityOrder({ marketPricePriority = "mm_att_ttc" })
assert_equal("mm", orderB[1], "GetPriorityOrder returns a copied array")

local emptyPriceA = BETTERUI.CIM.MarketIntegration.GetMarketPriceInfo(nil, 1)
emptyPriceA.price = 999
local emptyPriceB = BETTERUI.CIM.MarketIntegration.GetMarketPriceInfo(nil, 1)
assert_equal(0, emptyPriceB.price, "GetMarketPriceInfo does not return a shared mutable empty table")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))

if failed > 0 then
    os.exit(1)
end
