--[[
File: tools/tests/test_utilities.lua
Purpose: Unit tests for core Utilities functions.
                 Loads production Utilities helpers so tests guard the live module API.

Usage:
  lua tools/tests/test_utilities.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

local debugOutput = {}

BETTERUI = {
    CIM = {
        Utils = {},
        Debug = {
            IsEnabled = function()
                return true
            end,
        },
        CONST = {
            SORT_SCHEMA = {},
        },
    },
    Settings = {
        Modules = {
            Inventory = { m_enabled = true },
            Banking = { m_enabled = false },
            Legacy = { enabled = true },
        },
    },
}

SCENE_MANAGER = { scenes = {} }

function d(msg)
    table.insert(debugOutput, msg)
    return msg
end

function ZO_TableOrderingFunction()
    return false
end

ZO_SORT_ORDER_UP = 1

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Utilities.lua")

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
-- TESTS: Module enablement helpers
-- ============================================================================

print("\n=== Module Enablement Tests ===\n")

print("Test: GetModuleEnabled uses canonical m_enabled flag")
assert_true(BETTERUI.GetModuleEnabled("Inventory"), "Inventory enabled via m_enabled")
assert_equal(false, BETTERUI.GetModuleEnabled("Banking"), "Banking disabled via m_enabled")
assert_equal(false, BETTERUI.GetModuleEnabled("Legacy"), "Legacy enabled key is ignored")
assert_equal(false, BETTERUI.GetModuleEnabled("Missing"), "Missing module defaults to disabled")

print("\nTest: SetModuleEnabled applies session-only disable override")
BETTERUI.SetModuleEnabled("Inventory", false)
assert_equal(false, BETTERUI.GetModuleEnabled("Inventory"), "Session disable hides enabled module")
BETTERUI.SetModuleEnabled("Inventory", true)
assert_true(BETTERUI.GetModuleEnabled("Inventory"), "Session re-enable restores module")

-- ============================================================================
-- TESTS: WrapValue
-- ============================================================================

print("\n=== WrapValue Tests ===\n")

-- Test 1: Value below min wraps to max
print("Test: Value below min wraps to max")
assert_equal(5, BETTERUI.CIM.Utils.WrapValue(0, 5), "0 wraps to 5 (max=5)")

-- Test 2: Value above max wraps to min
print("\nTest: Value above max wraps to min")
assert_equal(1, BETTERUI.CIM.Utils.WrapValue(6, 5), "6 wraps to 1 (max=5)")

-- Test 3: Value within range unchanged
print("\nTest: Value within range unchanged")
assert_equal(3, BETTERUI.CIM.Utils.WrapValue(3, 5), "3 stays 3 (max=5)")

-- Test 4: Boundary values stay in range
print("\nTest: Boundary values stay in range")
assert_equal(1, BETTERUI.CIM.Utils.WrapValue(1, 5), "1 stays 1")
assert_equal(5, BETTERUI.CIM.Utils.WrapValue(5, 5), "5 stays 5")

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

-- Test 13: Debug prefixes messages when enabled
print("\nTest: Debug prefixes messages")
local debugMessage = BETTERUI.Debug("hello")
assert_true(debugMessage:find("BETTERUI") ~= nil, "Debug output contains addon prefix")

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
