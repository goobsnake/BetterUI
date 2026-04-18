--[[
File: tools/tests/test_companions_error_wrappers.lua
Purpose: Regression tests for companion refresh and teardown error wrappers.

Usage:
  lua tools/tests/test_companions_error_wrappers.lua
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

local function assert_contains(haystack, needle, label)
    if type(haystack) == "string" and haystack:find(needle, 1, true) then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- missing '%s' in '%s'", label, tostring(needle), tostring(haystack)))
    end
end

BETTERUI = {
    Companions = {
        Class = {},
    },
    CIM = {},
}

function BETTERUI.Debug(_) end

SI_BETTERUI_INV_ITEM_ALL = "all"
SI_BETTERUI_INV_ITEM_WEAPONS = "weapons"
SI_BETTERUI_INV_ITEM_APPAREL = "apparel"
SI_BETTERUI_INV_ITEM_JEWELRY = "jewelry"
SI_BETTERUI_INV_ITEM_CONSUMABLE = "consumables"
SI_BETTERUI_INV_ITEM_MATERIALS = "materials"
SI_BETTERUI_INV_ITEM_FURNISHING = "furnishing"
SI_BETTERUI_INV_ITEM_MISC = "misc"
SI_BETTERUI_INV_ITEM_EQUIPPED = "equipped"
SI_BETTERUI_INV_ITEM_JUNK = "junk"
SI_BETTERUI_INV_ITEM_STOLEN = "stolen"
ITEMFILTERTYPE_WEAPONS = 1
ITEMFILTERTYPE_ARMOR = 2
ITEMFILTERTYPE_JEWELRY = 3
ITEMFILTERTYPE_CONSUMABLE = 4
ITEMFILTERTYPE_CRAFTING = 5
ITEMFILTERTYPE_FURNISHING = 6
ITEMFILTERTYPE_MISCELLANEOUS = 7

BETTERUI.CIM.RegisterModuleAccessors = function() end
BETTERUI.CIM.ApplyModuleSharedSettingsStatics = function() end
BETTERUI.CIM.TryRegisterModulePanel = function() end

local function countRegistrations(obj)
    local count = 0
    for _, registered in ipairs(DIRECTIONAL_INPUT.inputObjects) do
        if registered == obj then
            count = count + 1
        end
    end
    return count
end

DIRECTIONAL_INPUT = {
    inputObjects = {},
}

function DIRECTIONAL_INPUT:IsListening(obj)
    return countRegistrations(obj) > 0
end

function DIRECTIONAL_INPUT:Deactivate(obj)
    for index = #self.inputObjects, 1, -1 do
        if self.inputObjects[index] == obj then
            table.remove(self.inputObjects, index)
            return
        end
    end
end

dofile("Modules/Companions/Core/CompanionsRuntime.lua")
dofile("Modules/Companions/Core/CompanionListManager.lua")
dofile("Modules/Companions/Core/CompanionItemList.lua")
dofile("Modules/Companions/Module.lua")

print("[Companions error wrappers]")

assert_eq(type(BETTERUI.Companions.WrapBoundaryError), "function",
    "Companions runtime exposes WrapBoundaryError as a callable alias")
assert_eq(BETTERUI.Companions.WrapBoundaryError("RefreshList", "boom"), "[Companions] RefreshList failed: boom",
    "WrapBoundaryError preserves the shared companion error format")
local boundaryOk, boundaryValue = BETTERUI.Companions.ExecuteBoundary("Companions alias test", function(left, right)
    return left + right
end, 2, 3)
assert_eq(boundaryOk, true, "ExecuteBoundary alias preserves successful execution results")
assert_eq(boundaryValue, 5, "ExecuteBoundary alias forwards varargs to the shared boundary helper")

local refreshHarness = setmetatable({
    list = {
        Clear = function()
            error("refresh boom")
        end,
    },
}, { __index = BETTERUI.Companions.Class })

local refreshOk, refreshErr = refreshHarness:RefreshList()
assert_eq(refreshOk, false, "RefreshList surfaces failures instead of swallowing them")
assert_contains(refreshErr, "[Companions] RefreshList failed:", "RefreshList wraps errors with a stable companion context")
assert_eq(refreshHarness._isRefreshing, false, "RefreshList clears the refreshing guard after failure")

local list = {
    SetDirectionalInputEnabled = function() end,
    IsActive = function()
        return true
    end,
    Deactivate = function()
        error("list deactivate boom")
    end,
}

DIRECTIONAL_INPUT.inputObjects = { list }

local teardownHarness = setmetatable({
    list = list,
}, { __index = BETTERUI.Companions.Class })

local teardownOk, teardownErr = teardownHarness:ForceReleaseDirectionalInput()
assert_eq(teardownOk, false, "ForceReleaseDirectionalInput preserves teardown failures")
assert_contains(teardownErr, "[Companions] ForceReleaseDirectionalInput failed:", "teardown failures use the same stable wrapper contract")
assert_eq(countRegistrations(list), 0, "ForceReleaseDirectionalInput still releases directional input registrations")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
