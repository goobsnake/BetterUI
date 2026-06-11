--[[
File: tools/tests/test_vendor_batching_parallel_contract.lua
Purpose: Verifies vendor batch runtime aligns with shared grouped batch-options
         and explicit step-result contracts.

Usage:
  lua tools/tests/test_vendor_batching_parallel_contract.lua
]]

BAG_BACKPACK = 1
CURT_MONEY = 0
CURT_NONE = -1

local testsPassed = 0
local testsFailed = 0

local buyCalls = {}
local sellCalls = {}
local launderCalls = {}
local buybackCalls = {}
local slotStacks = {}
local canAfford = true
local hasInventorySpace = true
local authorizationAllowed = true

local function assertTrue(condition, message)
    if condition then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        print("  [FAILED] " .. message)
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
end

local function resetState()
    buyCalls = {}
    sellCalls = {}
    launderCalls = {}
    buybackCalls = {}
    slotStacks = {}
    canAfford = true
    hasInventorySpace = true
    authorizationAllowed = true
end

function zo_clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function zo_max(a, b)
    return (a > b) and a or b
end

function zo_ceil(value)
    return math.ceil(value)
end

function zo_floor(value)
    return math.floor(value)
end

function GetString(id)
    return tostring(id)
end

function zo_strformat(fmt, ...)
    if select("#", ...) == 0 then
        return tostring(fmt)
    end
    return string.format(tostring(fmt), ...)
end

function GetSlotStackSize(bagId, slotIndex)
    return slotStacks[string.format("%s:%s", tostring(bagId), tostring(slotIndex))] or 0
end

function BuyStoreItem(entryIndex, quantity)
    table.insert(buyCalls, { entryIndex = entryIndex, quantity = quantity })
end

function SellInventoryItem(bagId, slotIndex, quantity)
    table.insert(sellCalls, { bagId = bagId, slotIndex = slotIndex, quantity = quantity })
end

function LaunderItem(bagId, slotIndex, quantity)
    table.insert(launderCalls, { bagId = bagId, slotIndex = slotIndex, quantity = quantity })
end

function BuybackItem(entryIndex)
    table.insert(buybackCalls, { entryIndex = entryIndex })
end

BETTERUI = {
    CIM = {
        CONST = { TIMING = {} },
    },
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            FENCE_SELL = 3,
            FENCE_LAUNDER = 4,
            BUYBACK = 5,
            SELL_VENGEANCE = 6,
        },
        ACTION = {
            SELL = "vendor_sell",
            SELL_VENGEANCE = "vendor_sell_vengeance",
            FENCE_SELL = "fence_sell",
            FENCE_LAUNDER = "fence_launder",
        },
        instance = {
            CanAfford = function(_, _price, _currencyType)
                return canAfford
            end,
            HasInventorySpace = function()
                return hasInventorySpace
            end,
        },
        AuthorizeInventoryAction = function(_actionType, _bagId, _slotIndex, _vendorInstance)
            return authorizationAllowed
        end,
    },
}

dofile("Modules/CIM/Core/Batching/BatchConfig.lua")
dofile("Modules/Vendor/Core/VendorBatchRuntime.lua")

local BatchRuntime = BETTERUI.Vendor.BatchRuntime
local BatchConfig = BETTERUI.CIM.BatchConfig
local MODE = BETTERUI.Vendor.MODE

print("\n=== Vendor batching contract ===\n")

resetState()
local defaults = BatchRuntime.GetDefaultBatchOptions()
assertTrue(type(defaults) == "table", "GetDefaultBatchOptions returns a table")
assertTrue(type(defaults.server) == "table", "Default options expose grouped server config")
assertTrue(type(defaults.pacing) == "table", "Default options expose grouped pacing config")
assertTrue(type(defaults.ack) == "table", "Default options expose grouped ack config")
assertEqual(true, defaults.server.serverBound, "Default options keep server-bound execution enabled")
assertEqual(145, defaults.pacing.minServerDelayMs, "Default options keep minimum server delay")
assertEqual(330, defaults.pacing.maxServerDelayMs, "Default options keep maximum server delay")
assertEqual(true, defaults.ack.awaitInventoryAck, "Default options keep inventory ACK wait enabled")
assertEqual(nil, defaults.serverBound, "Default options no longer expose flat legacy keys")

resetState()
local strictContract = BatchRuntime._internals.ResolveBatchOptions({
    serverBound = false,
    minServerDelayMs = 210,
    maxServerDelayMs = 240,
    cooldownEvery = 5,
    awaitInventoryAck = false,
})
assertEqual(true, strictContract.server.serverBound, "Public runtime contract ignores flat legacy serverBound keys")
assertEqual(145, strictContract.pacing.minServerDelayMs, "Public runtime contract keeps default minimum delay when flat keys are provided")
assertEqual(330, strictContract.pacing.maxServerDelayMs, "Public runtime contract keeps default maximum delay when flat keys are provided")
assertEqual(18, strictContract.pacing.cooldownEvery, "Public runtime contract keeps default cooldown cadence when flat keys are provided")
assertEqual(true, strictContract.ack.awaitInventoryAck, "Public runtime contract keeps grouped ACK defaults when flat keys are provided")

resetState()
local grouped = BatchRuntime._internals.ResolveBatchOptions({
    server = { serverBound = true },
    pacing = { minServerDelayMs = 199 },
})
assertEqual(true, grouped.server.serverBound, "Grouped server options are preserved")
assertEqual(199, grouped.pacing.minServerDelayMs, "Grouped pacing options are preserved")

resetState()
local noItemResult = BatchRuntime.ExecuteBatchAction(MODE.SELL, nil)
assertEqual(BatchConfig.BATCH_STEP_STATUS.HANDLED, noItemResult.status, "Missing item payload returns handled step result")

resetState()
authorizationAllowed = false
slotStacks["1:9"] = 8
local deniedSellResult = BatchRuntime.ExecuteBatchAction(MODE.SELL, { bagId = BAG_BACKPACK, slotIndex = 9 })
assertEqual(BatchConfig.BATCH_STEP_STATUS.SKIPPED, deniedSellResult.status, "Authorization failure returns skipped step result")
assertEqual(0, #sellCalls, "Authorization failure does not perform vendor sell call")

resetState()
authorizationAllowed = true
slotStacks["1:9"] = 8
local queuedSellResult = BatchRuntime.ExecuteBatchAction(MODE.SELL, { bagId = BAG_BACKPACK, slotIndex = 9 })
assertEqual(BatchConfig.BATCH_STEP_STATUS.QUEUED, queuedSellResult.status, "Valid sell action returns queued step result")
assertEqual(1, #sellCalls, "Valid sell action performs vendor sell call")
assertEqual(8, sellCalls[1].quantity, "Sell action forwards full stack count")

resetState()
authorizationAllowed = true
slotStacks["1:10"] = 4
local queuedVengeanceResult = BatchRuntime.ExecuteBatchAction(MODE.SELL_VENGEANCE,
    { bagId = BAG_BACKPACK, slotIndex = 10 })
assertEqual(BatchConfig.BATCH_STEP_STATUS.QUEUED, queuedVengeanceResult.status,
    "Valid sell vengeance action returns queued step result")
assertEqual(1, #sellCalls, "Valid sell vengeance action performs vendor sell call")
assertEqual(4, sellCalls[1].quantity, "Sell vengeance action forwards full stack count")

resetState()
canAfford = false
local deniedBuyResult = BatchRuntime.ExecuteBatchAction(MODE.BUY, { entryIndex = 4, price = 99999, currencyType = CURT_MONEY })
assertEqual(BatchConfig.BATCH_STEP_STATUS.SKIPPED, deniedBuyResult.status, "Unaffordable buy returns skipped step result")
assertEqual(0, #buyCalls, "Unaffordable buy does not call BuyStoreItem")

resetState()
canAfford = true
hasInventorySpace = true
local queuedBuyResult = BatchRuntime.ExecuteBatchAction(MODE.BUY, { entryIndex = 4, price = 50, currencyType = CURT_MONEY })
assertEqual(BatchConfig.BATCH_STEP_STATUS.QUEUED, queuedBuyResult.status, "Valid buy action returns queued step result")
assertEqual(1, #buyCalls, "Valid buy action performs BuyStoreItem call")
assertEqual(1, buyCalls[1].quantity, "Buy action uses quantity of one per batch step")

resetState()
slotStacks["1:3"] = 2
local queuedLaunderResult = BatchRuntime.ExecuteBatchAction(MODE.FENCE_LAUNDER, { bagId = BAG_BACKPACK, slotIndex = 3 })
assertEqual(BatchConfig.BATCH_STEP_STATUS.QUEUED, queuedLaunderResult.status, "Valid fence launder returns queued step result")
assertEqual(1, #launderCalls, "Valid fence launder performs LaunderItem call")

resetState()
canAfford = true
hasInventorySpace = true
local queuedBuybackResult = BatchRuntime.ExecuteBatchAction(MODE.BUYBACK, { entryIndex = 12, price = 80 })
assertEqual(BatchConfig.BATCH_STEP_STATUS.QUEUED, queuedBuybackResult.status, "Valid buyback returns queued step result")
assertEqual(1, #buybackCalls, "Valid buyback performs BuybackItem call")

resetState()
local batchRuntimeCall = {}
local originalCreateRunner = BatchRuntime._internals.CreateBatchRunner
local originalResolveOptions = BatchRuntime._internals.ResolveBatchOptions
local originalBuybackItems = {
    { entryIndex = 2, price = 80 },
    { entryIndex = 5, price = 40 },
    { entryIndex = 1, price = 20 },
}

BatchRuntime._internals.CreateBatchRunner = function(mode, items, onComplete, batchOptions)
    batchRuntimeCall.mode = mode
    batchRuntimeCall.items = items
    batchRuntimeCall.batchOptions = batchOptions
    batchRuntimeCall.onComplete = onComplete
    return {
        Start = function()
            batchRuntimeCall.started = true
        end,
    }
end
BatchRuntime._internals.ResolveBatchOptions = function(options)
    batchRuntimeCall.resolvedOptions = options
    return options
end

BatchRuntime.ExecuteBatchThrottled({
    mode = MODE.BUYBACK,
    items = { unpack(originalBuybackItems) },
    onComplete = function()
        batchRuntimeCall.completed = true
    end,
    options = { server = { serverBound = false } },
})
BatchRuntime._internals.CreateBatchRunner = originalCreateRunner
BatchRuntime._internals.ResolveBatchOptions = originalResolveOptions

assertEqual(MODE.BUYBACK, batchRuntimeCall.mode, "Vendor batch runtime accepts named request mode")
assertEqual(3, #batchRuntimeCall.items, "Vendor batch runtime preserves all request items")
assertTrue(batchRuntimeCall.items[1].entryIndex == 5 and batchRuntimeCall.items[2].entryIndex == 2 and batchRuntimeCall.items[3].entryIndex == 1,
    "Vendor batch runtime preserves buyback request-ordering contract after sorting")
assertTrue(batchRuntimeCall.batchOptions and batchRuntimeCall.batchOptions.server and batchRuntimeCall.batchOptions.server.serverBound == false,
    "Vendor batch runtime forwards resolved options from the request/options contract")
assertEqual(true, batchRuntimeCall.started, "Vendor batch runtime still starts the runner contract after request parsing")

resetState()
local legacyRequestAccepted, _ = pcall(function()
    BatchRuntime.ExecuteBatchThrottled({
        mode = MODE.SELL,
        items = { { bagId = BAG_BACKPACK, slotIndex = 1 } },
        batchOptions = { server = { serverBound = false } },
    })
end)
assertEqual(false, legacyRequestAccepted, "Vendor batch runtime rejects legacy request.batchOptions contract shape")

-- Batch BUY re-validates the captured entry index against the live store
-- entry (stores re-index when rows sell out) and skips on mismatch.
resetState()
local storeEntries = { [4] = { name = "Original Item", link = "|H1:item:1|h|h" } }
function GetStoreEntryInfo(entryIndex)
    local entry = storeEntries[entryIndex]
    if not entry then
        return nil, nil
    end
    return "icon.dds", entry.name
end
function GetStoreItemLink(entryIndex)
    local entry = storeEntries[entryIndex]
    return entry and entry.link or nil
end

local matchedBuy = BatchRuntime.ExecuteBatchAction(MODE.BUY,
    { entryIndex = 4, price = 50, currencyType = CURT_MONEY, name = "Original Item", itemLink = "|H1:item:1|h|h" })
assertEqual(BatchConfig.BATCH_STEP_STATUS.QUEUED, matchedBuy.status, "Batch BUY proceeds when the live entry still matches")
assertEqual(1, #buyCalls, "Matching batch BUY performs BuyStoreItem call")

resetState()
storeEntries[4] = { name = "Different Item", link = "|H1:item:2|h|h" }
local mismatchedLinkBuy = BatchRuntime.ExecuteBatchAction(MODE.BUY,
    { entryIndex = 4, price = 50, currencyType = CURT_MONEY, name = "Original Item", itemLink = "|H1:item:1|h|h" })
assertEqual(BatchConfig.BATCH_STEP_STATUS.SKIPPED, mismatchedLinkBuy.status, "Batch BUY skips when the live item link no longer matches")
assertEqual(0, #buyCalls, "Mismatched batch BUY does not call BuyStoreItem")

resetState()
storeEntries[4] = { name = "Different Item" }
local mismatchedNameBuy = BatchRuntime.ExecuteBatchAction(MODE.BUY,
    { entryIndex = 4, price = 50, currencyType = CURT_MONEY, name = "Original Item" })
assertEqual(BatchConfig.BATCH_STEP_STATUS.SKIPPED, mismatchedNameBuy.status, "Batch BUY skips when the live entry name no longer matches")
assertEqual(0, #buyCalls, "Name-mismatched batch BUY does not call BuyStoreItem")

resetState()
storeEntries[4] = nil
local vanishedBuy = BatchRuntime.ExecuteBatchAction(MODE.BUY,
    { entryIndex = 4, price = 50, currencyType = CURT_MONEY, name = "Original Item" })
assertEqual(BatchConfig.BATCH_STEP_STATUS.SKIPPED, vanishedBuy.status, "Batch BUY skips when the entry no longer exists")

GetStoreEntryInfo = nil
GetStoreItemLink = nil

-- ack.awaitInventoryAck: the runner waits for the next inventory update after
-- each mutating step, with the pacing delay as the timeout fallback.
resetState()
BETTERUI.Vendor._batchProcessing = false
BETTERUI.Vendor._batchAbortRequested = false

local scheduledCallbacks = {}
function zo_callLater(fn, _delayMs)
    table.insert(scheduledCallbacks, fn)
end
local function runNextScheduled()
    local fn = table.remove(scheduledCallbacks, 1)
    if fn then fn() end
end

local inventoryAckCallbacks = {}
SHARED_INVENTORY = {
    RegisterCallback = function(_, callbackName, callback)
        inventoryAckCallbacks[callbackName] = callback
    end,
    UnregisterCallback = function(_, callbackName, _callback)
        inventoryAckCallbacks[callbackName] = nil
    end,
}
BETTERUI.CIM.BatchOverlay = {
    ShowStatus = function() end,
    Hide = function() end,
    IsAnyBatchActionDialogShowing = function() return false end,
}
BETTERUI.Vendor.instance.IsSceneShowing = function() return true end

slotStacks["1:9"] = 8
slotStacks["1:10"] = 4
slotStacks["1:11"] = 5
local batchCompleted = false
BatchRuntime.ExecuteBatchThrottled({
    mode = MODE.SELL,
    items = {
        { bagId = BAG_BACKPACK, slotIndex = 9 },
        { bagId = BAG_BACKPACK, slotIndex = 10 },
        { bagId = BAG_BACKPACK, slotIndex = 11 },
    },
    onComplete = function()
        batchCompleted = true
    end,
})

assertTrue(inventoryAckCallbacks["SingleSlotInventoryUpdate"] ~= nil,
    "Runner registers the inventory ack callback when ack.awaitInventoryAck is enabled")

runNextScheduled() -- StartAfterDialogDismiss settle -> first Step()
assertEqual(1, #sellCalls, "First mutating step executes immediately")

runNextScheduled() -- pacing delay elapsed -> waits for the inventory ack
assertEqual(1, #sellCalls, "Second step is held until the inventory ack arrives")

inventoryAckCallbacks["SingleSlotInventoryUpdate"](BAG_BACKPACK, 99)
assertEqual(1, #sellCalls, "Unrelated single-slot ack does not release the wait")

inventoryAckCallbacks["SingleSlotInventoryUpdate"](BAG_BACKPACK, 9)
assertEqual(2, #sellCalls, "Matching single-slot ack releases the next step")

runNextScheduled() -- stale ack-timeout fallback from step 1 must be a no-op
assertEqual(2, #sellCalls, "Stale ack timeout does not double-step")

runNextScheduled() -- pacing delay for step 2 -> waits for ack again
assertEqual(2, #sellCalls, "Third step is held until an ack arrives")

inventoryAckCallbacks["FullInventoryUpdate"]()
assertEqual(3, #sellCalls, "FullInventoryUpdate releases the wait as a wildcard ack")

runNextScheduled() -- stale ack-timeout fallback from step 2 must be a no-op
assertEqual(3, #sellCalls, "Stale ack timeout does not double-step after a wildcard ack")

runNextScheduled() -- pacing delay for step 3 -> waits for ack again
assertEqual(false, batchCompleted, "Batch is still awaiting the final ack")

runNextScheduled() -- ack timeout fallback releases the batch (no ack arrived)
assertEqual(true, batchCompleted, "Ack timeout fallback completes the batch without an inventory event")
assertTrue(inventoryAckCallbacks["SingleSlotInventoryUpdate"] == nil
    and inventoryAckCallbacks["FullInventoryUpdate"] == nil,
    "Runner unregisters inventory ack callbacks when the batch finishes")

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    error(string.format("test_vendor_batching_parallel_contract.lua failed with %d failure(s)", testsFailed))
end

print("\nAll tests passed!")
