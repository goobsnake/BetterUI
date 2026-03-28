--[[
File: tools/tests/test_vendor_tabs.lua
Purpose: Unit tests for tab resolution logic in Vendor/Vendor.lua.
         Tests run standalone with a Lua interpreter (no ESO environment).
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { Vendor = { MODE = { BUY = 1, SELL = 2, REPAIR = 3, BUYBACK = 4, FENCE_SELL = 5, FENCE_LAUNDER = 6 } } }
function GetString(s) return tostring(s or "") end
function rawget(t, k) return t[k] end

-- ============================================================================
-- REPLICATE VENDOR TAB LOGIC UNDER TEST
-- ============================================================================

local MODE = BETTERUI.Vendor.MODE

local VENDOR_TABS = {
    { mode = MODE.BUY,     name = function() return "Buy" end },
    { mode = MODE.SELL,    name = function() return "Sell" end },
    { mode = MODE.REPAIR,  name = function() return "Repair" end },
    { mode = MODE.BUYBACK, name = function() return "Buyback" end },
}

local FENCE_TABS = {
    { mode = MODE.FENCE_SELL,    name = function() return "Fence Sell" end },
    { mode = MODE.FENCE_LAUNDER, name = function() return "Fence Launder" end },
}

-- State variables (mirroring Vendor.lua locals)
local isFenceInteraction = false
local fenceEnableSell = false
local fenceEnableLaunder = false

local function GetActiveTabs()
    if isFenceInteraction then
        local tabs = {}
        if fenceEnableSell then
            tabs[#tabs + 1] = FENCE_TABS[1]
        end
        if fenceEnableLaunder then
            tabs[#tabs + 1] = FENCE_TABS[2]
        end
        if #tabs == 0 then
            tabs[1] = FENCE_TABS[1]
        end
        return tabs
    end
    return VENDOR_TABS
end

-- Helpers to set state for tests
local function setRegularStore()
    isFenceInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false
end

local function setFence(sell, launder)
    isFenceInteraction = true
    fenceEnableSell = sell
    fenceEnableLaunder = launder
end

-- ============================================================================
-- TEST INFRASTRUCTURE
-- ============================================================================

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

-- ============================================================================
-- TESTS: GetActiveTabs
-- ============================================================================

print("[GetActiveTabs]")

-- Regular store returns all 4 vendor tabs
setRegularStore()
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 4, "regular store: 4 tabs")
    assert_eq(tabs[1].mode, MODE.BUY, "regular store: first tab is BUY")
    assert_eq(tabs[2].mode, MODE.SELL, "regular store: second tab is SELL")
    assert_eq(tabs[3].mode, MODE.REPAIR, "regular store: third tab is REPAIR")
    assert_eq(tabs[4].mode, MODE.BUYBACK, "regular store: fourth tab is BUYBACK")
end

-- Fence with both sell and launder
setFence(true, true)
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 2, "fence both: 2 tabs")
    assert_eq(tabs[1].mode, MODE.FENCE_SELL, "fence both: first is FENCE_SELL")
    assert_eq(tabs[2].mode, MODE.FENCE_LAUNDER, "fence both: second is FENCE_LAUNDER")
end

-- Fence with only sell
setFence(true, false)
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 1, "fence sell-only: 1 tab")
    assert_eq(tabs[1].mode, MODE.FENCE_SELL, "fence sell-only: FENCE_SELL")
end

-- Fence with only launder
setFence(false, true)
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 1, "fence launder-only: 1 tab")
    assert_eq(tabs[1].mode, MODE.FENCE_LAUNDER, "fence launder-only: FENCE_LAUNDER")
end

-- Fence with neither (safety fallback)
setFence(false, false)
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 1, "fence none: safety fallback 1 tab")
    assert_eq(tabs[1].mode, MODE.FENCE_SELL, "fence none: safety fallback is FENCE_SELL")
end

-- Tab name functions return strings
setRegularStore()
do
    local tabs = GetActiveTabs()
    assert_eq(type(tabs[1].name()), "string", "tab name returns string")
end

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
