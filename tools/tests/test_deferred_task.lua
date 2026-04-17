--[[
File: tools/tests/test_deferred_task.lua
Purpose: Unit tests for DeferredTask utility.
                 Loads production code via dofile to ensure the public task manager API
                 stays aligned with runtime behavior.

Usage:
  lua tools/tests/test_deferred_task.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

local scheduledCallbacks = {}
local removedCallbacks = {}
local nextId = 1

ZO_Object = {}

function ZO_Object:Subclass()
    local subclass = {}
    subclass.__index = subclass
    return setmetatable(subclass, { __index = self })
end

function ZO_Object.New(class)
    return setmetatable({}, class)
end

function zo_callLater(callback, delayMs)
    local id = nextId
    nextId = nextId + 1
    scheduledCallbacks[id] = {
        callback = callback,
        delayMs = delayMs,
    }
    return id
end

function zo_removeCallLater(id)
    removedCallbacks[id] = true
    scheduledCallbacks[id] = nil
end

BETTERUI = { CIM = {} }

function BETTERUI.Debug(_) end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Lifecycle/DeferredTask.lua")

local function resetScheduler()
    scheduledCallbacks = {}
    removedCallbacks = {}
    nextId = 1
    BETTERUI.CIM.Tasks = nil
end

local function getOnlyScheduledId()
    for id in pairs(scheduledCallbacks) do
        return id
    end
    return nil
end

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

local function assert_false(value, message)
    assert_equal(false, value, message)
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== DeferredTask Tests ===\n")

-- Test 0: Shared manager stays lazy until runtime setup asks for it
print("Test: Shared manager is lazy")
resetScheduler()
assert_equal(nil, BETTERUI.CIM.DeferredTask.GetSharedManager(), "Shared manager is absent immediately after import")
local sharedTasks = BETTERUI.CIM.DeferredTask.EnsureSharedManager()
assert_true(sharedTasks ~= nil, "EnsureSharedManager creates the shared manager")
assert_equal(sharedTasks, BETTERUI.CIM.DeferredTask.GetSharedManager(), "Shared manager becomes discoverable")

-- Test 1: Schedule creates pending task
print("Test: Schedule creates pending task")
resetScheduler()
local tasks = BETTERUI.CIM.DeferredTask.Manager:New()
tasks:Schedule("myTask", 100, function() end)
local scheduledId = getOnlyScheduledId()
assert_true(scheduledId ~= nil, "Task created a deferred callback")
assert_true(tasks:IsPending("myTask"), "Task is pending")
assert_equal(1, tasks:GetPendingCount(), "Pending count is 1")

-- Test 2: Pending task clears after callback runs
print("\nTest: Pending task clears after callback runs")
local callbackCount = 0
resetScheduler()
tasks = BETTERUI.CIM.DeferredTask.Manager:New()
tasks:Schedule("runTask", 75, function()
    callbackCount = callbackCount + 1
end)
scheduledId = getOnlyScheduledId()
scheduledCallbacks[scheduledId].callback()
assert_equal(1, callbackCount, "Callback executed once")
assert_false(tasks:IsPending("runTask"), "Task no longer pending after execution")
assert_equal(0, tasks:GetPendingCount(), "Pending count returns to 0")

-- Test 3: Cancel removes task
print("\nTest: Cancel removes task")
resetScheduler()
tasks = BETTERUI.CIM.DeferredTask.Manager:New()
tasks:Schedule("myTask", 100, function() end)
scheduledId = getOnlyScheduledId()
tasks:Cancel("myTask")
assert_true(removedCallbacks[scheduledId] == true, "Cancel removes the scheduled callback")
assert_false(tasks:IsPending("myTask"), "Task is no longer pending")

-- Test 4: Cancel non-existent task is harmless
print("\nTest: Cancel non-existent task is harmless")
tasks:Cancel("nonexistent")
assert_equal(0, tasks:GetPendingCount(), "Cancel on missing task leaves state unchanged")

-- Test 5: CancelAll clears all tasks
print("\nTest: CancelAll clears all tasks")
resetScheduler()
tasks = BETTERUI.CIM.DeferredTask.Manager:New()
tasks:Schedule("task1", 100, function() end)
tasks:Schedule("task2", 100, function() end)
tasks:Schedule("task3", 100, function() end)
assert_true(tasks:IsPending("task1"), "task1 is pending")
assert_true(tasks:IsPending("task2"), "task2 is pending")
assert_equal(3, tasks:GetPendingCount(), "Three tasks are pending before CancelAll")
tasks:CancelAll()
assert_false(tasks:IsPending("task1"), "task1 cleared")
assert_false(tasks:IsPending("task2"), "task2 cleared")
assert_false(tasks:IsPending("task3"), "task3 cleared")
assert_equal(0, tasks:GetPendingCount(), "Pending count returns to 0 after CancelAll")

-- Test 6: Reschedule replaces existing callback
print("\nTest: Reschedule replaces existing callback")
resetScheduler()
tasks = BETTERUI.CIM.DeferredTask.Manager:New()
local firstCount = 0
local secondCount = 0
tasks:Schedule("replace", 100, function() firstCount = firstCount + 1 end)
local firstId = getOnlyScheduledId()
tasks:Schedule("replace", 250, function() secondCount = secondCount + 1 end)
local secondId = getOnlyScheduledId()
assert_true(firstId ~= secondId, "Reschedule creates a fresh callback id")
assert_true(removedCallbacks[firstId] == true, "Previous callback removed during reschedule")
assert_true(tasks:IsPending("replace"), "Replacement task remains pending")
scheduledCallbacks[secondId].callback()
assert_equal(0, firstCount, "Original callback never ran")
assert_equal(1, secondCount, "Replacement callback ran once")

-- Test 7: EnsureSharedManager is idempotent
print("\nTest: EnsureSharedManager reuses the same shared manager")
resetScheduler()
local firstShared = BETTERUI.CIM.DeferredTask.EnsureSharedManager()
local secondShared = BETTERUI.CIM.DeferredTask.EnsureSharedManager()
assert_equal(firstShared, secondShared, "Shared manager instance is reused")

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))

if tests_failed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
