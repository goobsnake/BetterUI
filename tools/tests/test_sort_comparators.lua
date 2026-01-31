--[[
File: tools/tests/test_sort_comparators.lua
Purpose: Unit tests for sort comparator functions.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_sort_comparators.lua

Note: This file stubs the ESO environment to test pure functions in isolation.
]]

-- ============================================================================
-- SORT COMPARATOR FUNCTIONS (Extracted for Testing)
-- ============================================================================

-- Basic numeric comparator
local function CompareNumbers(a, b, ascending)
    if ascending then
        return (a or 0) < (b or 0)
    else
        return (a or 0) > (b or 0)
    end
end

-- String comparator with nil handling
local function CompareStrings(a, b, ascending)
    a = a or ""
    b = b or ""
    if ascending then
        return a < b
    else
        return a > b
    end
end

-- Multi-key comparator (name, then level)
local function CompareItems(item1, item2)
    -- First compare by name
    local name1 = item1.name or ""
    local name2 = item2.name or ""
    if name1 ~= name2 then
        return name1 < name2
    end
    -- Then by level
    local level1 = item1.level or 0
    local level2 = item2.level or 0
    return level1 < level2
end

-- ============================================================================
-- TEST FRAMEWORK
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

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
-- TEST CASES: CompareNumbers
-- ============================================================================

print("\n=== CompareNumbers Tests ===\n")

assert_true(CompareNumbers(1, 2, true), "CompareNumbers: 1 < 2 ascending")
assert_false(CompareNumbers(2, 1, true), "CompareNumbers: 2 not < 1 ascending")
assert_true(CompareNumbers(2, 1, false), "CompareNumbers: 2 > 1 descending")
assert_false(CompareNumbers(1, 2, false), "CompareNumbers: 1 not > 2 descending")
assert_false(CompareNumbers(1, 1, true), "CompareNumbers: 1 not < 1 ascending")
assert_true(CompareNumbers(nil, 1, true), "CompareNumbers: nil (0) < 1 ascending")
assert_false(CompareNumbers(nil, nil, true), "CompareNumbers: nil not < nil ascending")

-- ============================================================================
-- TEST CASES: CompareStrings
-- ============================================================================

print("\n=== CompareStrings Tests ===\n")

assert_true(CompareStrings("apple", "banana", true), "CompareStrings: apple < banana ascending")
assert_false(CompareStrings("banana", "apple", true), "CompareStrings: banana not < apple ascending")
assert_true(CompareStrings("banana", "apple", false), "CompareStrings: banana > apple descending")
assert_false(CompareStrings("apple", "banana", false), "CompareStrings: apple not > banana descending")
assert_true(CompareStrings(nil, "apple", true), "CompareStrings: nil ('') < 'apple' ascending")

-- ============================================================================
-- TEST CASES: CompareItems (Multi-key)
-- ============================================================================

print("\n=== CompareItems Tests ===\n")

local item1 = { name = "Sword", level = 10 }
local item2 = { name = "Sword", level = 20 }
local item3 = { name = "Axe", level = 30 }

assert_true(CompareItems(item3, item1), "CompareItems: Axe < Sword (by name)")
assert_false(CompareItems(item1, item3), "CompareItems: Sword not < Axe (by name)")
assert_true(CompareItems(item1, item2), "CompareItems: Sword L10 < Sword L20 (same name, by level)")
assert_false(CompareItems(item2, item1), "CompareItems: Sword L20 not < Sword L10 (same name)")

-- Nil handling
local item_nil_name = { name = nil, level = 5 }
local item_nil_level = { name = "Bow", level = nil }

assert_true(CompareItems(item_nil_name, item1), "CompareItems: nil name < 'Sword'")
assert_true(CompareItems(item_nil_level, item1), "CompareItems: 'Bow' < 'Sword' (by name)")

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
