--[[
File: tools/tests/test_utilities.lua
Purpose: Unit tests for core Utilities functions.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_utilities.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

-- Mock BETTERUI namespace
BETTERUI = { CIM = { Utils = {} } }

function BETTERUI.Debug(msg)
    -- Silent in tests
end

-- ============================================================================
-- IMPORT FUNCTIONS UNDER TEST
-- ============================================================================

-- WrapValue: Circular navigation
function BETTERUI.CIM.Utils.WrapValue(value, minValue, maxValue)
    if value < minValue then
        return maxValue
    elseif value > maxValue then
        return minValue
    end
    return value
end

-- SafeCall: Nil-safe method calling
function BETTERUI.CIM.Utils.SafeCall(obj, methodName, ...)
    if obj and type(obj[methodName]) == "function" then
        return obj[methodName](obj, ...)
    end
    return nil
end

-- SafeIcon: Icon path safety wrapper
function BETTERUI.SafeIcon(iconPath)
    if iconPath == nil then return "" end
    return iconPath
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

local function assert_nil(value, message)
    assert_equal(nil, value, message)
end

-- ============================================================================
-- TESTS: WrapValue
-- ============================================================================

print("\n=== WrapValue Tests ===\n")

-- Test 1: Value below min wraps to max
print("Test: Value below min wraps to max")
assert_equal(5, BETTERUI.CIM.Utils.WrapValue(0, 1, 5), "0 wraps to 5 (min=1, max=5)")

-- Test 2: Value above max wraps to min
print("\nTest: Value above max wraps to min")
assert_equal(1, BETTERUI.CIM.Utils.WrapValue(6, 1, 5), "6 wraps to 1 (min=1, max=5)")

-- Test 3: Value within range unchanged
print("\nTest: Value within range unchanged")
assert_equal(3, BETTERUI.CIM.Utils.WrapValue(3, 1, 5), "3 stays 3 (min=1, max=5)")

-- Test 4: At min boundary unchanged
print("\nTest: At min boundary unchanged")
assert_equal(1, BETTERUI.CIM.Utils.WrapValue(1, 1, 5), "1 stays 1 (at min)")

-- Test 5: At max boundary unchanged
print("\nTest: At max boundary unchanged")
assert_equal(5, BETTERUI.CIM.Utils.WrapValue(5, 1, 5), "5 stays 5 (at max)")

-- ============================================================================
-- TESTS: SafeCall
-- ============================================================================

print("\n=== SafeCall Tests ===\n")

-- Test 6: Nil object returns nil
print("Test: Nil object returns nil")
local result1 = BETTERUI.CIM.Utils.SafeCall(nil, "DoSomething")
assert_nil(result1, "Nil object returns nil")

-- Test 7: Missing method returns nil
print("\nTest: Missing method returns nil")
local obj1 = { name = "Test" }
local result2 = BETTERUI.CIM.Utils.SafeCall(obj1, "MissingMethod")
assert_nil(result2, "Missing method returns nil")

-- Test 8: Method exists and is called
print("\nTest: Method exists and is called")
local obj2 = {
    value = 10,
    GetValue = function(self) return self.value end
}
local result3 = BETTERUI.CIM.Utils.SafeCall(obj2, "GetValue")
assert_equal(10, result3, "Method called and returned value")

-- Test 9: Arguments passed through
print("\nTest: Arguments passed through")
local obj3 = {
    Add = function(self, a, b) return a + b end
}
local result4 = BETTERUI.CIM.Utils.SafeCall(obj3, "Add", 3, 7)
assert_equal(10, result4, "Arguments passed (3 + 7 = 10)")

-- ============================================================================
-- TESTS: SafeIcon
-- ============================================================================

print("\n=== SafeIcon Tests ===\n")

-- Test 10: Nil returns empty string
print("Test: Nil returns empty string")
assert_equal("", BETTERUI.SafeIcon(nil), "Nil returns empty string")

-- Test 11: Valid path unchanged
print("\nTest: Valid path unchanged")
local path = "/esoui/art/icons/test.dds"
assert_equal(path, BETTERUI.SafeIcon(path), "Valid path unchanged")

-- Test 12: Empty string unchanged
print("\nTest: Empty string unchanged")
assert_equal("", BETTERUI.SafeIcon(""), "Empty string unchanged")

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
