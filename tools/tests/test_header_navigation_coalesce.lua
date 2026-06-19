--[[
File: tools/tests/test_header_navigation_coalesce.lua
Purpose: Regression tests for HeaderNavigation.CreateCoalescedHandler timer handling (PB-014c):
         - the zo_callLater handle is stored,
         - a re-fire cancels the previously-scheduled timer (no timer leak),
         - the handle is cleared when the timer fires,
         - CancelPending() cancels an in-flight timer for teardown.

Usage:
  lua tools/tests/test_header_navigation_coalesce.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }
BETTERUI.CIM.CONST = { TIMING = { CATEGORY_CHANGE_DELAY_MS = 50 } }
BETTERUI.CIM.Utils = { WrapValue = function(v, count) return v end }

-- Controllable zo_callLater: capture scheduled callbacks by id; fire on demand.
local nextCallId = 0
local scheduled = {}     -- id -> fn
local removedIds = {}    -- list of ids passed to zo_removeCallLater

function zo_callLater(fn, delay)
    nextCallId = nextCallId + 1
    scheduled[nextCallId] = fn
    return nextCallId
end

function zo_removeCallLater(id)
    table.insert(removedIds, id)
    scheduled[id] = nil
end

local function fire(id)
    local fn = scheduled[id]
    if fn then fn() end
end

dofile("Modules/CIM/Core/Data/NavigationState.lua")
dofile("Modules/CIM/UI/HeaderNavigation.lua")

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

local function contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== HeaderNavigation coalesced-handler timer Tests ===\n")

-- Test 1: handler stores the timer handle on first invocation.
print("Test: scheduled timer handle is stored on state (PB-014c)")
do
    nextCallId = 0; scheduled = {}; removedIds = {}
    local applyCalls = 0
    local handler = BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler({
        onApply = function() applyCalls = applyCalls + 1 end,
    })
    local instance = { currentCategoryIndex = 1 }
    handler(instance, { selectedIndex = 2 })
    local state = instance._navState
    assert_true(state ~= nil, "nav state created")
    assert_true(state._pendingApplyCallId ~= nil, "pending timer handle stored")
end

-- Test 2: re-fire before the timer elapses cancels the previous timer.
print("\nTest: re-fire cancels the previously scheduled timer (no leak)")
do
    nextCallId = 0; scheduled = {}; removedIds = {}
    local applyCalls = 0
    local handler = BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler({
        onApply = function() applyCalls = applyCalls + 1 end,
    })
    local instance = { currentCategoryIndex = 1 }
    handler(instance, { selectedIndex = 2 })
    local firstId = instance._navState._pendingApplyCallId
    handler(instance, { selectedIndex = 3 })
    local secondId = instance._navState._pendingApplyCallId
    assert_true(contains(removedIds, firstId), "first timer was cancelled on re-fire")
    assert_true(firstId ~= secondId, "a new timer handle replaced the old one")

    -- Only the latest timer should apply; firing the stale (removed) id is a no-op.
    fire(firstId)
    assert_equal(0, applyCalls, "stale timer does not apply")
    fire(secondId)
    assert_equal(1, applyCalls, "latest timer applies exactly once")
    assert_equal(nil, instance._navState._pendingApplyCallId, "handle cleared after firing")
end

-- Test 3: sceneCheck=false path clears the handle and skips apply.
print("\nTest: sceneCheck guard prevents apply against hidden scene")
do
    nextCallId = 0; scheduled = {}; removedIds = {}
    local applyCalls = 0
    local handler = BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler({
        sceneCheck = function() return false end,
        onApply = function() applyCalls = applyCalls + 1 end,
    })
    local instance = { currentCategoryIndex = 1 }
    handler(instance, { selectedIndex = 2 })
    fire(instance._navState._pendingApplyCallId or 0)
    assert_equal(0, applyCalls, "onApply skipped when scene is hidden")
end

-- Test 4: CancelPending cancels an in-flight timer (teardown path).
print("\nTest: CancelPending cancels in-flight timer (PB-014c teardown)")
do
    nextCallId = 0; scheduled = {}; removedIds = {}
    local applyCalls = 0
    local handler = BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler({
        onApply = function() applyCalls = applyCalls + 1 end,
    })
    local instance = { currentCategoryIndex = 1 }
    handler(instance, { selectedIndex = 2 })
    local pendingId = instance._navState._pendingApplyCallId
    BETTERUI.CIM.HeaderNavigation.CancelPending(instance)
    assert_true(contains(removedIds, pendingId), "CancelPending removed the timer")
    assert_equal(nil, instance._navState._pendingApplyCallId, "handle cleared by CancelPending")
    -- Firing the cancelled id must not apply.
    fire(pendingId)
    assert_equal(0, applyCalls, "cancelled timer does not apply")
end

-- Test 5: CancelPending on an instance with no state is a safe no-op.
print("\nTest: CancelPending is a safe no-op without pending timer")
do
    BETTERUI.CIM.HeaderNavigation.CancelPending(nil)
    BETTERUI.CIM.HeaderNavigation.CancelPending({})
    tests_passed = tests_passed + 1
    print("  [OK] CancelPending(nil)/CancelPending({}) handled gracefully")
end

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
