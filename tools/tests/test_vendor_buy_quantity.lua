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

print("[Vendor buy quantity clamp removal pin]")

-- BUI-CLEAN-002: Vendor.ClampPurchaseQuantity was removed. It was reserved for a
-- future quantity spinner but had no callers; the buy flow hardcodes quantity=1.
-- Pin the removal so the dead helper is not silently reintroduced, and confirm
-- BuyComponent still loads cleanly without it.
assert_eq(BETTERUI.Vendor.ClampPurchaseQuantity, nil,
    "ClampPurchaseQuantity is removed from the Vendor surface")
assert_eq(type(BETTERUI.Vendor.BuyComponent), "table",
    "BuyComponent still loads without the quantity-clamp helper")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
