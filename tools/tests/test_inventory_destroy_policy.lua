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

-- =====================================================================
-- Contract: real Policy.CanDestroyItem with a nil slotType still enforces
-- IsItemPlayerLocked (deny when locked) and never errors. The engine destroy
-- probe is skipped when slotType is nil (defense-in-depth only), so the lock +
-- existence checks remain the gate. Loads the REAL ProtectionPolicy so this
-- guards the shipped policy, not the DestroyAction seam mock used above.
-- =====================================================================
do
    print("\n[ProtectionPolicy nil-slotType contract]")

    -- Minimal engine + namespace mocks the real ProtectionPolicy needs at load.
    local lockedState = {}
    local function slotPolicyKey(bagId, slotIndex)
        return tostring(bagId) .. ":" .. tostring(slotIndex)
    end

    function IsItemPlayerLocked(bagId, slotIndex)
        return lockedState[slotPolicyKey(bagId, slotIndex)] == true
    end

    -- Present so the existence gate passes; identity is irrelevant here.
    BETTERUI.CIM.BatchConfig = BETTERUI.CIM.BatchConfig or {}
    BETTERUI.CIM.BatchConfig.HasItemAtSlot = function()
        return true
    end

    -- If this is ever called with a nil slotType the probe guard is broken;
    -- record the call so we can assert it is NOT exercised on the nil path.
    local destroyProbeCalls = 0
    function ZO_InventorySlot_CanDestroyItem()
        destroyProbeCalls = destroyProbeCalls + 1
        return true
    end

    -- Debug log is gated; provide a recorder so the nil-slotType note path is
    -- exercised without requiring real chat output.
    local debugNotes = {}
    BETTERUI.CIM.Debug = BETTERUI.CIM.Debug or {}
    BETTERUI.CIM.Debug.IsEnabled = function() return true end
    BETTERUI.CIM.Debug.Log = function(message)
        debugNotes[#debugNotes + 1] = message
    end

    GetItemActorCategory = GetItemActorCategory or function() return nil end
    GAMEPLAY_ACTOR_CATEGORY_COMPANION = GAMEPLAY_ACTOR_CATEGORY_COMPANION or 1
    BAG_VIRTUAL = BAG_VIRTUAL or 100
    BETTERUI.GetSetting = BETTERUI.GetSetting or function(_, _, default) return default end

    -- Load the real policy; this replaces the DestroyAction-seam mock above,
    -- which has already finished its assertions.
    dofile("Modules/CIM/Actions/ProtectionPolicy.lua")
    local Policy = BETTERUI.CIM.ProtectionPolicy

    -- Case 1: nil slotType, item NOT locked -> allowed, no error, probe skipped.
    destroyProbeCalls = 0
    lockedState = {}
    local ok1, allowed1, reason1 = pcall(Policy.CanDestroyItem, 1, 2, nil)
    assert_equal(ok1, true, "CanDestroyItem(bag, slot, nil) does not error when unlocked")
    assert_equal(allowed1, true, "nil slotType + unlocked item is still destroyable")
    assert_equal(reason1, nil, "nil slotType allow path returns no deny reason")
    assert_equal(destroyProbeCalls, 0, "engine destroy probe is skipped when slotType is nil")

    -- Case 2: nil slotType, item LOCKED -> denied via PLAYER_LOCKED, no error.
    destroyProbeCalls = 0
    lockedState = { [slotPolicyKey(1, 2)] = true }
    local ok2, allowed2, reason2 = pcall(Policy.CanDestroyItem, 1, 2, nil)
    assert_equal(ok2, true, "CanDestroyItem(bag, slot, nil) does not error when locked")
    assert_equal(allowed2, false, "nil slotType still DENIES a player-locked item")
    assert_equal(reason2, Policy.DENY.PLAYER_LOCKED, "lock gate still applies with nil slotType")
    assert_equal(destroyProbeCalls, 0, "engine destroy probe stays skipped on the locked nil-slotType path")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
