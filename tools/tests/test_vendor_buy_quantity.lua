--[[
File: tools/tests/test_vendor_buy_quantity.lua
Purpose: Unit tests for BuyComponent quantity clamping helper.
Usage:
  lua tools/tests/test_vendor_buy_quantity.lua
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

-- Minimal stub environment so BuyComponent.lua can load without ESO APIs.
BETTERUI = {
    Vendor = {
        ExecuteSafely = function(_label, fn, ...)
            local ok, result = pcall(fn, ...)
            if ok then return true, result end
            return false, nil
        end,
    },
    CIM = {
        Utils = {},
        ItemTaxonomy = {
            VENDOR_BUY_CATEGORY_DEFS = {},
        },
        UserAlertText = function() end,
    },
    Log = {
        CATEGORY = {},
        Info = function() end,
    },
}

function GetString(value)
    return tostring(value)
end

dofile("Modules/Vendor/Components/BuyComponent.lua")

print("[Vendor buy quantity clamp]")

local clamp = BETTERUI.Vendor.ClampPurchaseQuantity
assert_eq(type(clamp), "function", "ClampPurchaseQuantity is exposed on Vendor")

-- Normal purchase within budget
assert_eq(clamp(10, 10, 5, 100), 10, "can afford whole stack")

-- Budget-limited
assert_eq(clamp(10, 10, 5, 25), 5, "clamped by money")

-- Stack-limited
assert_eq(clamp(20, 10, 5, 1000), 10, "clamped by stack available")

-- Cannot afford even one
assert_eq(clamp(10, 10, 5, 4), 0, "unaffordable single unit returns 0")

-- Free item
assert_eq(clamp(10, 10, 0, 0), 10, "free item buys whole stack")

-- Zero requested
assert_eq(clamp(0, 10, 5, 100), 0, "zero requested returns 0")

-- Negative requested
assert_eq(clamp(-5, 10, 5, 100), 0, "negative requested returns 0")

-- Zero stack available
assert_eq(clamp(10, 0, 5, 100), 0, "zero stack available returns 0")

-- Nil arguments treated as zero
assert_eq(clamp(nil, 10, 5, 100), 0, "nil requested treated as 0")
assert_eq(clamp(10, nil, 5, 100), 0, "nil stack treated as 0")
assert_eq(clamp(10, 10, nil, 100), 10, "nil unit price treated as free")
assert_eq(clamp(10, 10, 5, nil), 0, "nil money treated as 0")

-- Large numbers
assert_eq(clamp(1000, 1000, 1, 500), 500, "large quantities clamped by budget")

-- Unit price larger than money but exactly divisible
assert_eq(clamp(10, 10, 10, 100), 10, "exact budget buys whole stack")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
