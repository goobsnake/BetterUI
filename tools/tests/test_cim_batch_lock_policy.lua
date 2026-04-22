--[[
File: tools/tests/test_cim_batch_lock_policy.lua
Purpose: Runtime coverage for batch lock/unlock authorization routing through ProtectionPolicy.
Usage:
  lua tools/tests/test_cim_batch_lock_policy.lua
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

local function assert_true(value, label)
    assert_equal(value, true, label)
end

local lockPolicyCalls = 0
local unlockPolicyCalls = 0
local lockAllowedBySlot = {}
local unlockAllowedBySlot = {}
local setLockCalls = {}
local processedPayload = nil
local exitSelectionCalls = 0

local function SlotKey(bagId, slotIndex)
    return string.format("%s:%s", tostring(bagId), tostring(slotIndex))
end

BAG_BACKPACK = 1
SI_ITEM_ACTION_MARK_AS_LOCKED = "lock"
SI_ITEM_ACTION_UNMARK_AS_LOCKED = "unlock"

BETTERUI = {
    CIM = {
        BatchActions = {},
        BatchConfig = {},
        ProtectionPolicy = {},
    },
}

function GetString(value)
    return tostring(value)
end

BETTERUI.CIM.BatchConfig.BatchStepHandled = function()
    return "handled"
end

BETTERUI.CIM.BatchConfig.BatchStepQueued = function()
    return "queued"
end

BETTERUI.CIM.BatchConfig.ComposeBatchOptions = function(...)
    return { ... }
end

BETTERUI.CIM.BatchConfig.WithServer = function(options)
    return options
end

BETTERUI.CIM.BatchConfig.WithUi = function(options)
    return options
end

BETTERUI.CIM.BatchConfig.WithPacing = function(options)
    return options
end

BETTERUI.CIM.BatchConfig.WithAck = function(options)
    return options
end

BETTERUI.CIM.ProtectionPolicy.CanLockItem = function(bagId, slotIndex)
    lockPolicyCalls = lockPolicyCalls + 1
    return lockAllowedBySlot[SlotKey(bagId, slotIndex)] == true
end

BETTERUI.CIM.ProtectionPolicy.CanUnlockItem = function(bagId, slotIndex)
    unlockPolicyCalls = unlockPolicyCalls + 1
    return unlockAllowedBySlot[SlotKey(bagId, slotIndex)] == true
end

function SetItemIsPlayerLocked(bagId, slotIndex, isLocked)
    setLockCalls[#setLockCalls + 1] = {
        bagId = bagId,
        slotIndex = slotIndex,
        isLocked = isLocked,
    }
end

dofile("Modules/CIM/Core/Batching/BatchActions.lua")

print("[CIM batch lock/unlock policy]")

local selectedItems = {
    { bagId = BAG_BACKPACK, slotIndex = 1 },
    { bagId = BAG_BACKPACK, slotIndex = 2 },
    { dataSource = { bagId = BAG_BACKPACK, slotIndex = 3 } },
}

local harness = {
    multiSelectManager = {
        GetSelectedItems = function()
            return selectedItems
        end,
    },
    ProcessBatchThrottled = function(_, payload)
        processedPayload = payload
    end,
    ExitSelectionMode = function()
        exitSelectionCalls = exitSelectionCalls + 1
    end,
}

do
    lockPolicyCalls = 0
    unlockPolicyCalls = 0
    setLockCalls = {}
    processedPayload = nil
    exitSelectionCalls = 0
    lockAllowedBySlot = {
        [SlotKey(BAG_BACKPACK, 1)] = true,
        [SlotKey(BAG_BACKPACK, 2)] = false,
        [SlotKey(BAG_BACKPACK, 3)] = true,
    }

    BETTERUI.CIM.BatchActions.BatchLock(harness)

    assert_true(type(processedPayload) == "table", "BatchLock schedules throttled processing when policy allows candidates")
    assert_equal(#processedPayload.items, 2, "BatchLock filters selected items via ProtectionPolicy.CanLockItem")
    assert_equal(processedPayload.actionName, "lock", "BatchLock keeps lock action label")
    assert_true(lockPolicyCalls >= 3, "BatchLock consults lock policy during candidate filtering")

    local stepResultAllowed = processedPayload.step(BAG_BACKPACK, 1)
    local stepResultDenied = processedPayload.step(BAG_BACKPACK, 2)
    assert_equal(stepResultAllowed, "queued", "BatchLock queues lock operation when policy allows")
    assert_equal(stepResultDenied, "handled", "BatchLock skips lock operation when policy denies")
    assert_equal(#setLockCalls, 1, "BatchLock only toggles lock state for policy-allowed slots")
    assert_equal(setLockCalls[1].isLocked, true, "BatchLock applies player-lock true")

    processedPayload.onComplete()
    assert_equal(exitSelectionCalls, 1, "BatchLock exits selection mode on completion")
end

do
    lockPolicyCalls = 0
    unlockPolicyCalls = 0
    setLockCalls = {}
    processedPayload = nil
    exitSelectionCalls = 0
    unlockAllowedBySlot = {
        [SlotKey(BAG_BACKPACK, 1)] = false,
        [SlotKey(BAG_BACKPACK, 2)] = true,
        [SlotKey(BAG_BACKPACK, 3)] = false,
    }

    BETTERUI.CIM.BatchActions.BatchUnlock(harness)

    assert_true(type(processedPayload) == "table", "BatchUnlock schedules throttled processing when policy allows candidates")
    assert_equal(#processedPayload.items, 1, "BatchUnlock filters selected items via ProtectionPolicy.CanUnlockItem")
    assert_equal(processedPayload.actionName, "unlock", "BatchUnlock keeps unlock action label")
    assert_true(unlockPolicyCalls >= 3, "BatchUnlock consults unlock policy during candidate filtering")

    local stepResultDenied = processedPayload.step(BAG_BACKPACK, 1)
    local stepResultAllowed = processedPayload.step(BAG_BACKPACK, 2)
    assert_equal(stepResultDenied, "handled", "BatchUnlock skips unlock operation when policy denies")
    assert_equal(stepResultAllowed, "queued", "BatchUnlock queues unlock operation when policy allows")
    assert_equal(#setLockCalls, 1, "BatchUnlock only toggles lock state for policy-allowed slots")
    assert_equal(setLockCalls[1].isLocked, false, "BatchUnlock applies player-lock false")

    processedPayload.onComplete()
    assert_equal(exitSelectionCalls, 1, "BatchUnlock exits selection mode on completion")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
