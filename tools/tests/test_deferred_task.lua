--[[
File: tools/tests/test_deferred_task.lua
Purpose: Unit tests for DeferredTask utility.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_deferred_task.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

local scheduledUpdates = {}
local nextId = 1

EVENT_MANAGER = {
    RegisterForUpdate = function(name, delay, callback)
        scheduledUpdates[name] = { delay = delay, callback = callback }
        return nextId
    end,
    UnregisterForUpdate = function(name)
        scheduledUpdates[name] = nil
    end
}

function GetGameTimeMilliseconds()
    return os.time() * 1000
end

-- Mock BETTERUI namespace
BETTERUI = { CIM = {} }

function BETTERUI.Debug(msg)
    -- Silent in tests
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

-- Inline DeferredTask implementation for standalone testing
local DeferredTask = {}
DeferredTask.__index = DeferredTask

function DeferredTask:New(prefix)
    local obj = setmetatable({}, self)
    obj._prefix = prefix or "DeferredTask"
    obj._scheduled = {}
    return obj
end

function DeferredTask:Schedule(name, delayMs, callback)
    local fullName = self._prefix .. "_" .. name

    -- Cancel existing if any
    if self._scheduled[name] then
        EVENT_MANAGER:UnregisterForUpdate(fullName)
    end

    self._scheduled[name] = true
    EVENT_MANAGER:RegisterForUpdate(fullName, delayMs, function()
        EVENT_MANAGER:UnregisterForUpdate(fullName)
        self._scheduled[name] = nil
        callback()
    end)
end

function DeferredTask:Cancel(name)
    if self._scheduled[name] then
        local fullName = self._prefix .. "_" .. name
        EVENT_MANAGER:UnregisterForUpdate(fullName)
        self._scheduled[name] = nil
        return true
    end
    return false
end

function DeferredTask:CancelAll()
    for name, _ in pairs(self._scheduled) do
        local fullName = self._prefix .. "_" .. name
        EVENT_MANAGER:UnregisterForUpdate(fullName)
    end
    self._scheduled = {}
end

function DeferredTask:IsScheduled(name)
    return self._scheduled[name] == true
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

-- Test 1: Schedule creates pending task
print("Test: Schedule creates pending task")
local tasks = DeferredTask:New("Test")
tasks:Schedule("myTask", 100, function() end)
assert_true(tasks:IsScheduled("myTask"), "Task is scheduled")

-- Test 2: Cancel removes task
print("\nTest: Cancel removes task")
local cancelled = tasks:Cancel("myTask")
assert_true(cancelled, "Cancel returns true")
assert_false(tasks:IsScheduled("myTask"), "Task is no longer scheduled")

-- Test 3: Cancel non-existent task returns false
print("\nTest: Cancel non-existent task returns false")
local result = tasks:Cancel("nonexistent")
assert_false(result, "Cancel returns false for non-existent")

-- Test 4: CancelAll clears all tasks
print("\nTest: CancelAll clears all tasks")
tasks:Schedule("task1", 100, function() end)
tasks:Schedule("task2", 100, function() end)
tasks:Schedule("task3", 100, function() end)
assert_true(tasks:IsScheduled("task1"), "task1 is scheduled")
assert_true(tasks:IsScheduled("task2"), "task2 is scheduled")
tasks:CancelAll()
assert_false(tasks:IsScheduled("task1"), "task1 cleared")
assert_false(tasks:IsScheduled("task2"), "task2 cleared")
assert_false(tasks:IsScheduled("task3"), "task3 cleared")

-- Test 5: Reschedule replaces existing
print("\nTest: Reschedule replaces existing")
local callCount = 0
tasks:Schedule("replace", 100, function() callCount = callCount + 1 end)
tasks:Schedule("replace", 100, function() callCount = callCount + 10 end)
assert_true(tasks:IsScheduled("replace"), "Task still scheduled after replace")

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
