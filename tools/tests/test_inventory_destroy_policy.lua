--[[
File: tools/tests/test_inventory_destroy_policy.lua
Purpose: Runtime coverage for inventory quick-destroy honoring the shared policy seam.
Usage:
  lua tools/tests/test_inventory_destroy_policy.lua
]]

local passed = 0
local failed = 0

local function assert_equal(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local destroyCalls = {}
local scheduledTasks = {}
local cacheRefreshes = 0
local allowDestroy = true
local lastPolicySlotType = nil

BETTERUI = {
    CIM = {},
    Inventory = {
        Tasks = {},
    },
}

BETTERUI.CIM.SafeExecute = function(_label, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        return false, result
    end
    return true, result
end

BETTERUI.CIM.ProtectionPolicy = {
    CanDestroyItem = function(_bagId, _slotIndex, slotType)
        lastPolicySlotType = slotType
        return allowDestroy
    end,
}

BETTERUI.Inventory.Tasks.Schedule = function(name, delayMs, callback)
    scheduledTasks[#scheduledTasks + 1] = { name = name, delayMs = delayMs, callback = callback }
end

function DestroyItem(bagId, slotIndex)
    destroyCalls[#destroyCalls + 1] = { bagId = bagId, slotIndex = slotIndex }
end

function SetCursorItemSoundsEnabled()
end

SHARED_INVENTORY = {
    PerformFullUpdateOnBagCache = function()
        cacheRefreshes = cacheRefreshes + 1
    end,
}

GAMEPAD_INVENTORY = {
    RefreshItemList = function() end,
    RefreshCategoryList = function() end,
    RefreshHeader = function() end,
}

dofile("Modules/Inventory/Actions/DestroyAction.lua")

print("[Inventory destroy policy]")

do
    destroyCalls = {}
    scheduledTasks = {}
    cacheRefreshes = 0
    allowDestroy = false
    lastPolicySlotType = nil

    local destroyed = BETTERUI.Inventory.TryDestroyItem(1, 2, true, true, 777)

    assert_equal(destroyed, false, "policy denial blocks forced destroy")
    assert_equal(#destroyCalls, 0, "policy denial avoids engine destroy call")
    assert_equal(#scheduledTasks, 0, "policy denial skips refresh scheduling")
    assert_equal(cacheRefreshes, 0, "policy denial skips cache refresh")
    assert_equal(lastPolicySlotType, 777, "policy denial receives slot-type destroy context")
end

do
    destroyCalls = {}
    scheduledTasks = {}
    cacheRefreshes = 0
    allowDestroy = true
    lastPolicySlotType = nil

    local destroyed = BETTERUI.Inventory.TryDestroyItem(1, 2, true, false, 888)

    assert_equal(destroyed, true, "policy-approved forced destroy succeeds")
    assert_equal(#destroyCalls, 1, "policy-approved destroy reaches engine call")
    assert_equal(#scheduledTasks, 1, "successful destroy schedules UI refresh")
    assert_equal(cacheRefreshes, 1, "successful destroy refreshes bag cache")
    assert_equal(lastPolicySlotType, 888, "policy-approved destroy receives slot-type context")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
