--[[
File: tools/tests/test_batch_safety.lua
Purpose: Unit tests for the shipped batch processing safety mechanisms.
         Exercises the production MultiSelect throttling path and the real
         InventoryBatchOps pacing presets so re-entry guards, stale pipeline
         callbacks, and adaptive delay behavior stay aligned with runtime code.

Usage:
  lua tools/tests/test_batch_safety.lua
]]

if false then
    dofile("Modules/CIM/Core/Batching/BatchConfig.lua")
    dofile("Modules/CIM/Core/Batching/MultiSelectMixin.lua")
    dofile("Modules/Inventory/Core/InventoryBatchOps.lua")
end

BETTERUI = {
    Debug = function() end,
    CIM = {
        Debug = {},
        CONST = {
            TIMING = {},
        },
        BatchOverlay = {},
        BatchActions = {},
        Utils = {},
        ProtectionPolicy = {},
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
        Dialogs = {
            Register = function() end,
        },
    },
    Inventory = {
        Class = {},
    },
    Banking = {
        GetCurrentBank = function()
            return BAG_BANK
        end,
        GetActiveTransferContext = function()
            return {
                targetBag = BAG_BANK,
            }
        end,
    },
}

local debugOutput = {}
local scheduledCalls = {}
local scheduledDelayHistory = {}
local nextScheduleId = 0
local currentTimeMs = 0

function BETTERUI.CIM.Debug.Log(message, category)
    debugOutput[#debugOutput + 1] = {
        message = message,
        category = category,
    }
end

function BETTERUI.CIM.Debug.IsEnabled()
    return true
end

function zo_max(a, b) return math.max(a or 0, b or 0) end
function zo_min(a, b) return math.min(a or 0, b or 0) end
function zo_ceil(x) return math.ceil(x or 0) end
function zo_clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end
function zo_floor(x) return math.floor(x or 0) end
function zo_random(a, b) return math.floor((a + b) / 2) end
function zo_strformat(fmt, ...)
    local values = { ... }
    return (tostring(fmt):gsub("<<(%d+)>>", function(index)
        return tostring(values[tonumber(index)] or "")
    end))
end

local slotStacks = {}

local function slotKey(bagId, slotIndex)
    return tostring(bagId) .. ":" .. tostring(slotIndex)
end

function GetSlotStackSize(bagId, slotIndex)
    return slotStacks[slotKey(bagId, slotIndex)] or 0
end

function GetString(id)
    return tostring(id or "")
end

function GetGameTimeMilliseconds()
    return currentTimeMs
end

function zo_callLater(callback, delayMs)
    nextScheduleId = nextScheduleId + 1
    local entry = {
        id = nextScheduleId,
        callback = callback,
        delayMs = delayMs or 0,
    }
    scheduledCalls[#scheduledCalls + 1] = entry
    scheduledDelayHistory[#scheduledDelayHistory + 1] = entry.delayMs
end

local function resetScheduler()
    scheduledCalls = {}
    scheduledDelayHistory = {}
    nextScheduleId = 0
    currentTimeMs = 0
end

local function runNextScheduled()
    local entry = table.remove(scheduledCalls, 1)
    if not entry then
        return false
    end
    currentTimeMs = currentTimeMs + entry.delayMs
    entry.callback()
    return true
end

local function runAllScheduled(limit)
    local remaining = limit or 100
    while remaining > 0 and runNextScheduled() do
        remaining = remaining - 1
    end
end

BETTERUI.CIM.BatchOverlay.Hide = function() end
BETTERUI.CIM.BatchOverlay.ShowStatus = function() end
BETTERUI.CIM.BatchOverlay.StopLayoutPulse = function() end
BETTERUI.CIM.BatchOverlay.IsAnyBatchActionDialogShowing = function()
    return false
end

BETTERUI.CIM.BatchActions.ExtractSlot = function(itemData)
    local rawData = itemData.dataSource or itemData
    return rawData.bagId, rawData.slotIndex
end

BETTERUI.CIM.BatchActions.HasItemAtSlot = function(bagId, slotIndex)
    return GetSlotStackSize(bagId, slotIndex) > 0
end

BETTERUI.CIM.BatchActions.BatchLock = function() end
BETTERUI.CIM.BatchActions.BatchUnlock = function() end
BETTERUI.CIM.BatchActions.BatchMarkAsJunk = function() end
BETTERUI.CIM.BatchActions.BatchUnmarkAsJunk = function() end
BETTERUI.CIM.BatchActions.AnalyzeSelectedItems = function() end
BETTERUI.CIM.BatchActions.CreateDialogEntry = function() end
BETTERUI.CIM.BatchActions.AppendCommonBatchEntries = function() end

BETTERUI.CIM.Utils.ResolveMoveDestinationSlot = function()
    return 1
end

BETTERUI.CIM.ProtectionPolicy.CanTransferItem = function()
    return true
end

BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag = function()
    return true
end

BETTERUI.CIM.ProtectionPolicy.CanDestroyItem = function()
    return true
end

function DoesBagHaveSpaceFor()
    return true
end

function IsESOPlusSubscriber()
    return false
end

function ZO_Dialogs_ShowGamepadDialog() end
function CallSecureProtected() end

BAG_BACKPACK = 1
BAG_BANK = 2
BAG_SUBSCRIBER_BANK = 3
BAG_FURNITURE_VAULT = 4
GAMEPAD_DIALOGS = { BASIC = 1 }

SI_BETTERUI_BATCH_ACTIONS = "Batch"
SI_BETTERUI_BATCH_PROCESSING_COMPLETE = "Processed <<1>>"
SI_BETTERUI_BATCH_BAG_FULL = "Bag full"
SI_BETTERUI_BATCH_ABORTED_SCENE_EXIT = "Scene exit"
SI_BETTERUI_BATCH_ABORTED_COMPLETE = "Aborted"
SI_BETTERUI_BATCH_PARTIAL_SUCCESS = "Partial"
SI_BETTERUI_SCENE_INVENTORY = "Inventory"
SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG = "Retrieve"
SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG = "Stow"

dofile("Modules/CIM/Core/Batching/BatchConfig.lua")
dofile("Modules/CIM/Core/Batching/MultiSelectMixin.lua")
dofile("Modules/Inventory/Core/InventoryBatchOps.lua")

local BatchStepQueued = BETTERUI.CIM.BatchConfig.BatchStepQueued

local testsPassed = 0
local testsFailed = 0

local function assertEqual(expected, actual, message)
    if expected == actual then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assertTrue(value, message)
    assertEqual(true, value, message)
end

local function assertGreaterThan(left, right, message)
    assertTrue(left > right, message .. string.format(" (%s > %s)", tostring(left), tostring(right)))
end

local function resetEnvironment()
    debugOutput = {}
    slotStacks = {}
    resetScheduler()
    BETTERUI.CIM.BatchConfig.SERVER_BATCH_RECOVERY_STATE = {
        cooldownUntilMs = 0,
        serverActionTimes = {},
    }
end

local function makeBatchItems(count, bagId)
    local items = {}
    local resolvedBag = bagId or BAG_BACKPACK
    for index = 1, count do
        slotStacks[slotKey(resolvedBag, index)] = 1
        items[#items + 1] = {
            bagId = resolvedBag,
            slotIndex = index,
        }
    end
    return items
end

local function createBatchInstance()
    return {
        _multiSelectConfig = {
            isSceneShowing = function()
                return true
            end,
            refreshKeybinds = function() end,
            getSceneExitLabel = function()
                return "Inventory"
            end,
        },
    }
end

local function captureDepositBatchOptions()
    local capturedOptions = nil
    local harness = createBatchInstance()
    harness.multiSelectManager = {
        GetSelectedItems = function()
            slotStacks[slotKey(BAG_BACKPACK, 10)] = 1
            return {
                { bagId = BAG_BACKPACK, slotIndex = 10 },
            }
        end,
    }
    function harness:ExitSelectionMode()
        self.exitedSelection = true
    end

    function harness:ProcessBatchThrottled(request)
        request = request or {}
        capturedOptions = request.options
        local items = request.items or {}
        assertEqual(1, #items, "BatchDeposit forwards the selected inventory item")
        assertTrue(type(request.step) == "function", "BatchDeposit provides the live action closure")
        assertEqual("Depositing", request.actionName, "BatchDeposit preserves its shipped action label")
        if request.onComplete then
            request.onComplete()
        end
    end

    BETTERUI.Inventory.Class.BatchDeposit(harness)
    return capturedOptions
end

print("\n=== Batch Safety Tests (Production Path) ===\n")

resetEnvironment()
local depositBatchOptions = captureDepositBatchOptions()
assertTrue(type(depositBatchOptions) == "table", "Captured the real inventory deposit pacing options")
assertTrue(type(depositBatchOptions.server) == "table", "Inventory deposit options now use the grouped server contract")
assertTrue(depositBatchOptions.server.serverBound == true, "Inventory deposit options remain server-bound")

print("\nTest: Re-entry uses the shipped ProcessBatchThrottled guard")
resetEnvironment()
local reentryInstance = createBatchInstance()
local reentryCalls = 0
local reentryOptions = depositBatchOptions
BETTERUI.CIM.MultiSelectMixin.ProcessBatchThrottled(
    reentryInstance,
    {
        items = makeBatchItems(2),
        step = function()
            reentryCalls = reentryCalls + 1
            return BatchStepQueued()
        end,
        onComplete = nil,
        actionName = "Depositing",
        options = reentryOptions,
    }
)
local initialToken = reentryInstance.batchPipelineToken
BETTERUI.CIM.MultiSelectMixin.ProcessBatchThrottled(
    reentryInstance,
    {
        items = makeBatchItems(1),
        step = function()
            reentryCalls = reentryCalls + 1
            return BatchStepQueued()
        end,
        onComplete = nil,
        actionName = "Depositing",
        options = reentryOptions,
    }
)
assertEqual(initialToken, reentryInstance.batchPipelineToken, "Re-entry does not create a second pipeline token")
assertEqual(0, reentryCalls, "Deferred batch has not executed its first action yet")
assertEqual(1, #debugOutput, "Production guard logs one re-entry rejection")
assertTrue(debugOutput[1].message:find("re%-entry rejected") ~= nil, "Re-entry log message comes from the shipped batch engine")

print("\nTest: ProcessBatchThrottled only accepts request.step in the public request-table contract")
resetEnvironment()
local strictContractInstance = createBatchInstance()
local strictContractCalls = 0
BETTERUI.CIM.MultiSelectMixin.ProcessBatchThrottled(
    strictContractInstance,
    {
        items = makeBatchItems(1),
        fn = function()
            strictContractCalls = strictContractCalls + 1
            return BatchStepQueued()
        end,
        actionName = "Depositing",
        options = reentryOptions,
    }
)
assertEqual(0, strictContractCalls, "Legacy request.fn is ignored by the public ProcessBatchThrottled contract")
assertEqual(1, #debugOutput, "Public contract violation is logged once")
assertTrue(debugOutput[1].message:find("step function missing") ~= nil,
    "Public contract violation logs the missing step callback message")

print("\nTest: Stale timer callbacks are rejected by the production pipeline token guard")
resetEnvironment()
local tokenInstance = createBatchInstance()
local tokenActionCalls = 0
BETTERUI.CIM.MultiSelectMixin.ProcessBatchThrottled(
    tokenInstance,
    {
        items = makeBatchItems(2),
        step = function()
            tokenActionCalls = tokenActionCalls + 1
            return BatchStepQueued()
        end,
        onComplete = nil,
        actionName = "Depositing",
        options = reentryOptions,
    }
)
runNextScheduled()
assertEqual(1, tokenActionCalls, "First scheduled continuation processes the first item")
tokenInstance.batchPipelineToken = tokenInstance.batchPipelineToken + 1
runNextScheduled()
assertEqual(1, tokenActionCalls, "Stale continuation does not process another item after token invalidation")

print("\nTest: Adaptive delay comes from the shipped inventory pacing profile")
resetEnvironment()
local adaptiveInstance = createBatchInstance()
BETTERUI.CIM.MultiSelectMixin.ProcessBatchThrottled(
    adaptiveInstance,
    {
        items = makeBatchItems(9),
        step = function()
            return BatchStepQueued()
        end,
        onComplete = nil,
        actionName = "Depositing",
        options = reentryOptions,
    }
)
runAllScheduled(50)
assertEqual(160, scheduledDelayHistory[1], "Initial settle delay uses the shipped batch dialog settle timing")
assertEqual(145, scheduledDelayHistory[2], "Baseline inter-item delay uses the deposit minimum server delay")
assertEqual(145, scheduledDelayHistory[7], "Delay stays flat through the adaptive threshold")
assertEqual(161, scheduledDelayHistory[8], "Delay increases by one adaptive step once queued actions exceed the threshold")
assertEqual(177, scheduledDelayHistory[9], "Delay keeps scaling on later queued actions with the real inventory profile")
assertGreaterThan(scheduledDelayHistory[8], scheduledDelayHistory[7], "Adaptive backoff increases the scheduled delay after the threshold")

if testsFailed > 0 then
    error(string.format("test_batch_safety.lua failed with %d failure(s)", testsFailed))
end

print(string.format("\nAll tests passed! (%d assertions)", testsPassed))
