--[[
File: tools/tests/test_inventory_search_lifecycle.lua
Purpose: Regression coverage for Inventory canonical search lifecycle adoption.
Usage:
  lua tools/tests/test_inventory_search_lifecycle.lua
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

local function assert_true(value, label)
    assert_eq(value, true, label)
end

BETTERUI = {
    Inventory = {
        CONST = {
            LIST_TYPES = {
                CATEGORY = 1,
                ITEM = 2,
                CRAFT_BAG = 3,
            },
        },
    },
    CIM = {
        SharedItemSupport = {
            UpdateTooltipEquippedText = function() end,
            IsItemComparisonEnabled = function()
                return false
            end,
            CompareItem = function()
                return nil
            end,
            ShowComparisonOnTooltip = function() end,
        },
    },
    Interface = {
        SearchMixin = {},
    },
}

BETTERUI.Interface.SearchMixin.IsSearchHeaderActive = function(self)
    return self._searchHeaderActive == true
end

dofile("Modules/Inventory/Loader.lua")

BETTERUI.Inventory.Class = {}

dofile("Modules/Inventory/Core/MixinLoader.lua")
dofile("Modules/Inventory/Core/HeaderManager.lua")

BETTERUI.Inventory.ApplyAllMixins()

print("[Inventory canonical search lifecycle]")

do
    local lifecycle = BETTERUI.Inventory.Class.SEARCH_LIFECYCLE or {}
    assert_eq(lifecycle.clear, "ClearSearchInput", "inventory class exposes canonical clear lifecycle name")
    assert_eq(lifecycle.exit, "ExitSearchMode", "inventory class exposes canonical exit lifecycle name")
    assert_eq(lifecycle.headerActive, "IsHeaderFocused", "inventory class exposes canonical headerActive lifecycle name")
    assert_eq(lifecycle.requestEnter, "RequestHeaderFocus", "inventory class exposes canonical requestEnter lifecycle name")
    assert_eq(lifecycle.onEnter, "OnHeaderEntered", "inventory class exposes canonical onEnter lifecycle name")
end

do
    local calls = {}
    local inventory = setmetatable({
        _searchHeaderActive = true,
        searchQuery = "needle",
        ClearTextSearch = function(self)
            calls[#calls + 1] = "clear"
            self.searchQuery = ""
        end,
        ExitSearchFocus = function(_self)
            calls[#calls + 1] = "exit"
        end,
        RequestEnterHeader = function(_self)
            calls[#calls + 1] = "requestEnter"
        end,
        IsHeaderActive = function()
            return false
        end,
        GetCurrentList = function()
            return nil
        end,
    }, { __index = BETTERUI.Inventory.Class })

    inventory:ClearSearchInput()
    inventory:ExitSearchMode()
    inventory:RequestHeaderFocus()

    assert_eq(inventory.searchQuery, "", "canonical clear lifecycle delegates to ClearTextSearch")
    assert_true(inventory:IsHeaderFocused(), "canonical headerActive lifecycle reports search focus state")
    assert_eq(calls[1], "clear", "canonical clear lifecycle uses the legacy clear implementation")
    assert_eq(calls[2], "exit", "canonical exit lifecycle uses the legacy exit implementation")
    assert_eq(calls[3], "requestEnter", "canonical requestEnter lifecycle uses the legacy request-enter implementation")
    assert_true(type(inventory.OnHeaderEntered) == "function", "canonical onEnter lifecycle is present on the class")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
