--[[
File: tools/tests/test_trading_house_price_entry.lua
Purpose: Unit tests for Trading House create-listing price entry helpers (TRC-004).
Usage:
  lua tools/tests/test_trading_house_price_entry.lua
]]

BETTERUI = {
    TradingHouse = {},
}

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

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

-- ENGINE / FRAMEWORK STUBS ---------------------------------------------------

MIN_TRADING_HOUSE_POST_PRICE = 1
MAX_PLAYER_CURRENCY = 999999999

function zo_clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

function GetString(stringId)
    return tostring(stringId)
end

function rawget(t, k)
    return t[k]
end

-- LOAD PRODUCTION SOURCE -----------------------------------------------------

dofile("Modules/TradingHouse/Core/PriceEntry.lua")
local PriceEntry = BETTERUI.TradingHouse.PriceEntry

-- TESTS ----------------------------------------------------------------------

print("[ClampListingPrice]")
assert_eq(PriceEntry.ClampListingPrice(500, 1, 1000), 500, "Value inside range preserved")
assert_eq(PriceEntry.ClampListingPrice(0, 10, 1000), 10, "Value below min clamped")
assert_eq(PriceEntry.ClampListingPrice(2000, 10, 1000), 1000, "Value above max clamped")
assert_eq(PriceEntry.ClampListingPrice(99.6, 1, 1000), 100, "Value rounded to integer")
assert_eq(PriceEntry.ClampListingPrice(nil, 1, 1000), 1, "Nil value defaults to min")
assert_eq(PriceEntry.ClampListingPrice(500, nil, nil), 500, "Nil bounds use engine defaults")
assert_eq(PriceEntry.ClampListingPrice(500, 1000, 1), 500, "Swapped min/max handled")

print("[ShouldOfferDigitEntry]")
-- ShouldOfferDigitEntry is the gate the create-listing dialog uses to decide
-- whether to include the exact-digit-price parametric row
-- (TradingHouseRuntimeFlow dialogInfo.setup). Cover both sides of the gate.
-- Row OFFERED (coarse slider cannot reach an exact price):
assert_true(PriceEntry.ShouldOfferDigitEntry(10001), "Just above threshold offers the digit row")
assert_true(PriceEntry.ShouldOfferDigitEntry(999999999), "Max-range default price offers the digit row")
-- Row EXCLUDED (slider is already exact at step 1):
assert_eq(PriceEntry.ShouldOfferDigitEntry(10000), false, "Threshold price uses slider (row excluded)")
assert_eq(PriceEntry.ShouldOfferDigitEntry(100), false, "Small prices use slider (row excluded)")
assert_eq(PriceEntry.ShouldOfferDigitEntry(1), false, "Minimum price uses slider (row excluded)")
assert_eq(PriceEntry.ShouldOfferDigitEntry(nil), false, "Nil price does not offer digit entry")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
