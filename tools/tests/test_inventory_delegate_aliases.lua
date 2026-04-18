--[[
File: tools/tests/test_inventory_delegate_aliases.lua
Purpose: Regression checks for direct inventory multi-select delegate aliases.

Usage:
  lua tools/tests/test_inventory_delegate_aliases.lua
]]

local passed = 0
local failed = 0

local function assert_equal(expected, actual, label)
    if expected == actual then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write(string.format("Assertion failed: %s (expected %s, got %s)\n", label, tostring(expected), tostring(actual)))
    end
end

BAG_FURNITURE_VAULT = 7

BETTERUI = {
    Inventory = {
        Class = {},
    },
    CIM = {
        MultiSelectMixin = {
            BindDelegates = function(target, methodNames)
                for _, methodName in ipairs(methodNames or {}) do
                    target[methodName] = BETTERUI.CIM.MultiSelectMixin[methodName]
                end
            end,
            EnterSelectionMode = function() end,
            ExitSelectionMode = function() end,
            OnSelectionCountChanged = function() end,
            IsInSelectionMode = function()
                return false
            end,
            IsBatchProcessing = function()
                return false
            end,
            CanAbortBatch = function()
                return false
            end,
            RequestBatchAbort = function()
                return false
            end,
            ProcessBatchThrottled = function() end,
            BatchLock = function() end,
            BatchUnlock = function() end,
            BatchMarkAsJunk = function() end,
            BatchUnmarkAsJunk = function() end,
        },
        BatchConfig = {
            ComposeBatchOptions = function(...)
                return { ... }
            end,
            WithServer = function(options)
                return options
            end,
            WithUi = function(options)
                return options
            end,
            WithAck = function(options)
                return options
            end,
            WithPacing = function(options)
                return options
            end,
        },
        BatchActions = {
            ExtractSlot = function(itemData)
                return itemData and itemData.bagId, itemData and itemData.slotIndex
            end,
            HasItemAtSlot = function()
                return true
            end,
        },
        ProtectionPolicy = {},
    },
}

dofile("Modules/Inventory/Core/InventoryMultiSelect.lua")
dofile("Modules/Inventory/Core/InventoryBatchOps.lua")

local class = BETTERUI.Inventory.Class
local mixin = BETTERUI.CIM.MultiSelectMixin

assert_equal(mixin.EnterSelectionMode, class.EnterSelectionMode,
    "InventoryMultiSelect aliases EnterSelectionMode directly to the shared mixin")
assert_equal(mixin.ExitSelectionMode, class.ExitSelectionMode,
    "InventoryMultiSelect aliases ExitSelectionMode directly to the shared mixin")
assert_equal(mixin.OnSelectionCountChanged, class.OnSelectionCountChanged,
    "InventoryMultiSelect aliases OnSelectionCountChanged directly to the shared mixin")
assert_equal(mixin.IsInSelectionMode, class.IsInSelectionMode,
    "InventoryMultiSelect aliases IsInSelectionMode directly to the shared mixin")
assert_equal(mixin.IsBatchProcessing, class.IsBatchProcessing,
    "InventoryBatchOps aliases IsBatchProcessing directly to the shared mixin")
assert_equal(mixin.CanAbortBatch, class.CanAbortBatch,
    "InventoryBatchOps aliases CanAbortBatch directly to the shared mixin")
assert_equal(mixin.RequestBatchAbort, class.RequestBatchAbort,
    "InventoryBatchOps aliases RequestBatchAbort directly to the shared mixin")
assert_equal(mixin.ProcessBatchThrottled, class.ProcessBatchThrottled,
    "InventoryBatchOps aliases ProcessBatchThrottled directly to the shared mixin")
assert_equal(mixin.BatchLock, class.BatchLock,
    "InventoryBatchOps aliases BatchLock directly to the shared mixin")
assert_equal(mixin.BatchUnlock, class.BatchUnlock,
    "InventoryBatchOps aliases BatchUnlock directly to the shared mixin")
assert_equal(mixin.BatchMarkAsJunk, class.BatchMarkAsJunk,
    "InventoryBatchOps aliases BatchMarkAsJunk directly to the shared mixin")
assert_equal(mixin.BatchUnmarkAsJunk, class.BatchUnmarkAsJunk,
    "InventoryBatchOps aliases BatchUnmarkAsJunk directly to the shared mixin")
assert_equal("function", type(BETTERUI.Inventory.CanDestroyInventoryItem),
    "InventoryBatchOps still exposes CanDestroyInventoryItem for batch action menus")

if failed > 0 then
    error(string.format("test_inventory_delegate_aliases.lua failed with %d failure(s)", failed))
end

print(string.format("test_inventory_delegate_aliases.lua: %d passed", passed))
