--[[
File: tools/tests/test_inventory_mixin_loader_conventions.lua
Purpose: Verifies Inventory helper modules bind methods directly onto the class.
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
    CIM = {
        CONST = {
            MODULES = {},
        },
    },
    Interface = {
        SearchMixin = {
            IsSearchHeaderActive = function()
                return false
            end,
        },
    },
}

function BETTERUI.Debug()
end

BETTERUI.Inventory.CONST = {
    LIST_TYPES = {
        CATEGORY = 1,
        ITEM = 2,
        CRAFT_BAG = 3,
    },
}

dofile("Modules/Inventory/Loader.lua")

BETTERUI.Inventory.Class = {}

dofile("Modules/Inventory/State/PositionManager.lua")
dofile("Modules/Inventory/State/ListStateManager.lua")
dofile("Modules/Inventory/Core/HeaderManager.lua")

assert_true(type(BETTERUI.Inventory.Class.ToSavedPosition) == "function",
    "PositionManager binds ToSavedPosition directly onto Inventory.Class")
assert_true(type(BETTERUI.Inventory.Class.SaveListPosition) == "function",
    "PositionManager binds SaveListPosition directly onto Inventory.Class")
assert_true(type(BETTERUI.Inventory.Class.SwitchActiveList) == "function",
    "ListStateManager binds SwitchActiveList directly onto Inventory.Class")
assert_true(type(BETTERUI.Inventory.Class.InitializeHeader) == "function",
    "HeaderManager binds InitializeHeader directly onto Inventory.Class")
assert_equal(BETTERUI.Inventory.Class.SEARCH_LIFECYCLE.clear, "ClearSearchInput",
    "HeaderManager binds the canonical search lifecycle directly onto Inventory.Class")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
