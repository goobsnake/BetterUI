--[[
File: tools/tests/test_new_item_tracker.lua
Purpose: Unit tests for NewItemTracker prepare/commit/clear lifecycle.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_new_item_tracker.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {}, Inventory = {} }

local debugOutput = {}
function BETTERUI.Debug(msg)
    table.insert(debugOutput, msg)
end

-- Stub SafeExecute — just call the function
function BETTERUI.CIM.SafeExecute(context, fn, ...)
    if fn then
        fn(...)
        return true
    end
    return false
end

-- Mock SHARED_INVENTORY
local clearedItems = {}
SHARED_INVENTORY = {
    ClearNewStatus = function(self, bagId, slotIndex)
        table.insert(clearedItems, { bagId = bagId, slotIndex = slotIndex })
    end,
}

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/Inventory/Core/NewItemTracker.lua")

local Tracker = BETTERUI.Inventory.NewItemTracker

-- Reset helpers
local function reset()
    debugOutput = {}
    clearedItems = {}
    Tracker.Reset()
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

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== NewItemTracker Tests ===\n")

-- Test 1: Initial state has zero pending
print("Test: Initial state has zero pending")
reset()
assert_equal(0, Tracker.GetPendingCount(), "No items pending initially")

-- Test 2: PrepareForClear stages an item
print("\nTest: PrepareForClear stages an item")
reset()
Tracker.PrepareForClear(1, 10)
assert_equal(1, Tracker.GetPendingCount(), "One item pending after prepare")

-- Test 3: Duplicate prepare does not double-count
print("\nTest: Duplicate prepare does not double-count")
reset()
Tracker.PrepareForClear(1, 10)
Tracker.PrepareForClear(1, 10) -- same item
assert_equal(1, Tracker.GetPendingCount(), "Still one item after duplicate prepare")

-- Test 4: Multiple different items are tracked
print("\nTest: Multiple different items are tracked")
reset()
Tracker.PrepareForClear(1, 10)
Tracker.PrepareForClear(1, 20)
Tracker.PrepareForClear(2, 5)
assert_equal(3, Tracker.GetPendingCount(), "Three different items pending")

-- Test 5: Reset clears all pending
print("\nTest: Reset clears all pending")
reset()
Tracker.PrepareForClear(1, 10)
Tracker.PrepareForClear(1, 20)
assert_equal(2, Tracker.GetPendingCount(), "Two items before reset")
Tracker.Reset()
assert_equal(0, Tracker.GetPendingCount(), "Zero items after reset")

-- Test 6: CommitPendingClears calls ClearNewStatus for each
print("\nTest: CommitPendingClears calls ClearNewStatus for each item")
reset()
Tracker.PrepareForClear(1, 10)
Tracker.PrepareForClear(2, 20)
Tracker.CommitPendingClears()
assert_equal(2, #clearedItems, "Two ClearNewStatus calls made")
assert_equal(0, Tracker.GetPendingCount(), "Pending cleared after commit")

-- Test 7: CommitPendingClears empties pending list
print("\nTest: CommitPendingClears empties pending list")
reset()
Tracker.PrepareForClear(1, 10)
Tracker.CommitPendingClears()
Tracker.CommitPendingClears() -- second commit should be no-op
assert_equal(1, #clearedItems, "Only first commit produced calls")

-- Test 8: ClearImmediate removes from pending and clears
print("\nTest: ClearImmediate removes from pending and clears immediately")
reset()
Tracker.PrepareForClear(1, 10)
Tracker.PrepareForClear(1, 20)
Tracker.ClearImmediate(1, 10)
assert_equal(1, Tracker.GetPendingCount(), "One item removed from pending")
assert_equal(1, #clearedItems, "One immediate clear happened")
assert_equal(1, clearedItems[1].bagId, "Correct bagId cleared")
assert_equal(10, clearedItems[1].slotIndex, "Correct slotIndex cleared")

-- Test 9: PrepareForClear ignores nil bagId
print("\nTest: PrepareForClear ignores nil bagId")
reset()
Tracker.PrepareForClear(nil, 10)
assert_equal(0, Tracker.GetPendingCount(), "Nil bagId ignored")

-- Test 10: PrepareForClear ignores nil slotIndex
print("\nTest: PrepareForClear ignores nil slotIndex")
reset()
Tracker.PrepareForClear(1, nil)
assert_equal(0, Tracker.GetPendingCount(), "Nil slotIndex ignored")

-- Test 11: PrepareFromSelectedData extracts direct fields
print("\nTest: PrepareFromSelectedData extracts direct bagId/slotIndex")
reset()
Tracker.PrepareFromSelectedData({ bagId = 3, slotIndex = 15 })
assert_equal(1, Tracker.GetPendingCount(), "Item prepared from direct fields")

-- Test 12: PrepareFromSelectedData extracts from dataSource
print("\nTest: PrepareFromSelectedData extracts from dataSource")
reset()
Tracker.PrepareFromSelectedData({ dataSource = { bagId = 4, slotIndex = 25 } })
assert_equal(1, Tracker.GetPendingCount(), "Item prepared from dataSource")

-- Test 13: PrepareFromSelectedData handles nil gracefully
print("\nTest: PrepareFromSelectedData handles nil gracefully")
reset()
Tracker.PrepareFromSelectedData(nil)
assert_equal(0, Tracker.GetPendingCount(), "Nil selectedData handled")

-- Test 14: ClearImmediate handles nil gracefully
print("\nTest: ClearImmediate handles nil gracefully")
reset()
Tracker.ClearImmediate(nil, nil)
assert_equal(0, #clearedItems, "No clear for nil params")

-- Test 15: Full lifecycle — prepare, immediate clear, commit rest
print("\nTest: Full lifecycle — prepare, clear one, commit rest")
reset()
Tracker.PrepareForClear(1, 10)
Tracker.PrepareForClear(1, 20)
Tracker.PrepareForClear(1, 30)
Tracker.ClearImmediate(1, 20) -- clear middle one
assert_equal(2, Tracker.GetPendingCount(), "Two remaining after immediate clear")
assert_equal(1, #clearedItems, "One immediate clear")
Tracker.CommitPendingClears()
assert_equal(3, #clearedItems, "Three total clears (1 immediate + 2 commit)")

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
