--[[
File: tools/tests/test_inventory_mixin_loader_conventions.lua
Purpose: Keeps the inventory mixin registry safe after the first apply so
         Initialize remains the canonical apply point without breaking late mixins.
Usage:
  lua tools/tests/test_inventory_mixin_loader_conventions.lua
]]

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. label)
    end
end

local function assert_equal(actual, expected, label)
    assert_true(actual == expected, string.format("%s (expected=%s, actual=%s)", label, tostring(expected), tostring(actual)))
end

BETTERUI = {
    Inventory = {},
}

function BETTERUI.Debug()
end

dofile("Modules/Inventory/Loader.lua")

BETTERUI.Inventory.Class = {}

dofile("Modules/Inventory/Core/MixinLoader.lua")

local alpha = function()
    return "alpha"
end
local beta = function()
    return "beta"
end

BETTERUI.Inventory.RegisterMixin("Alpha", alpha)
BETTERUI.Inventory.ApplyAllMixins()

assert_equal(BETTERUI.Inventory.Class.Alpha, alpha, "ApplyAllMixins binds registered mixins onto the class")
assert_true(BETTERUI.Inventory._mixinsApplied, "ApplyAllMixins marks the registry as applied")
assert_true(type(BETTERUI.Inventory.ClassMixins) == "table", "ApplyAllMixins keeps the mixin registry available")

BETTERUI.Inventory.RegisterMixin("Beta", beta)

assert_equal(BETTERUI.Inventory.Class.Beta, beta, "RegisterMixin applies late mixins immediately once the class is live")
assert_equal(BETTERUI.Inventory.ClassMixins.Beta, beta, "RegisterMixin preserves late mixins in the registry")

BETTERUI.Inventory.ApplyAllMixins()

assert_equal(BETTERUI.Inventory.Class.Alpha, alpha, "Reapplying mixins keeps the original binding intact")
assert_equal(BETTERUI.Inventory.Class.Beta, beta, "Reapplying mixins keeps late registrations intact")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
