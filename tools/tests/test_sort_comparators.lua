--[[
File: tools/tests/test_sort_comparators.lua
Purpose: Unit tests for production comparator helpers in Utilities.lua.
         Covers CompareNils and DefaultSortComparator wiring used by list sorting.

Usage:
  lua tools/tests/test_sort_comparators.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

local recordedOrderingCall = nil

BETTERUI = {
    CIM = {
        CONST = {
            SORT_SCHEMA = { marker = "schema" },
        },
        Utils = {},
        Debug = {
            IsEnabled = function()
                return true
            end,
        },
    },
}

ZO_SORT_ORDER_UP = 1

function d(_) end

function ZO_TableOrderingFunction(left, right, key, schema, order)
    recordedOrderingCall = {
        left = left,
        right = right,
        key = key,
        schema = schema,
        order = order,
    }
    return left.sortPriorityName < right.sortPriorityName
end

dofile("Modules/CIM/Core/Utilities.lua")

-- ============================================================================
-- TEST FRAMEWORK
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, test_name)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("[PASS] " .. test_name)
    else
        tests_failed = tests_failed + 1
        print("[FAIL] " .. test_name)
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, test_name)
    if value then
        tests_passed = tests_passed + 1
        print("[PASS] " .. test_name)
    else
        tests_failed = tests_failed + 1
        print("[FAIL] " .. test_name)
    end
end

local function assert_false(value, test_name)
    if not value then
        tests_passed = tests_passed + 1
        print("[PASS] " .. test_name)
    else
        tests_failed = tests_failed + 1
        print("[FAIL] " .. test_name)
    end
end

-- ============================================================================
-- TEST CASES: CompareNils
-- ============================================================================

print("\n=== CompareNils Tests ===\n")

assert_false(BETTERUI.CIM.Utils.CompareNils(nil, nil, true), "CompareNils: both nil returns false")
assert_false(BETTERUI.CIM.Utils.CompareNils(nil, "value", true), "CompareNils: nil sorts last when nilGoesLast=true")
assert_true(BETTERUI.CIM.Utils.CompareNils("value", nil, true), "CompareNils: non-nil sorts first when nilGoesLast=true")
assert_true(BETTERUI.CIM.Utils.CompareNils(nil, "value", false), "CompareNils: nil sorts first when nilGoesLast=false")
assert_false(BETTERUI.CIM.Utils.CompareNils("value", nil, false), "CompareNils: non-nil sorts last when nilGoesLast=false")
assert_equal(nil, BETTERUI.CIM.Utils.CompareNils("a", "b", true), "CompareNils: non-nil pair defers to caller")

-- ============================================================================
-- TEST CASES: DefaultSortComparator
-- ============================================================================

print("\n=== DefaultSortComparator Tests ===\n")

local left = { sortPriorityName = "Alpha" }
local right = { sortPriorityName = "Beta" }
assert_true(BETTERUI.CIM.Utils.DefaultSortComparator(left, right), "DefaultSortComparator returns ordering result")
assert_equal(left, recordedOrderingCall.left, "DefaultSortComparator forwards left item")
assert_equal(right, recordedOrderingCall.right, "DefaultSortComparator forwards right item")
assert_equal("sortPriorityName", recordedOrderingCall.key, "DefaultSortComparator uses sortPriorityName key")
assert_equal(BETTERUI.CIM.CONST.SORT_SCHEMA, recordedOrderingCall.schema, "DefaultSortComparator forwards schema")
assert_equal(ZO_SORT_ORDER_UP, recordedOrderingCall.order, "DefaultSortComparator uses ascending order constant")

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===\n")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    os.exit(1)
else
    print("All tests passed!")
    os.exit(0)
end
