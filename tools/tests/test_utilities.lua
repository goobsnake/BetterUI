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
    Banking = {
        GetCurrentBank = function()
            return BAG_SUBSCRIBER_BANK
        end,
        GetTransferContext = function()
            return {
                depositTargetBag = BAG_SUBSCRIBER_BANK,
            }
        end,
        Window = {
            list = {
                marker = "bank-list",
            },
        },
        GetSortEntryContext = function()
            return {
                list = BETTERUI.Banking.Window.list,
                sortContext = BETTERUI.Banking.Window,
            }
        end,
    },
}

SCENE_MANAGER = { scenes = {} }
BAG_BANK = 1
BAG_SUBSCRIBER_BANK = 2

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

print("\nTest: SetModuleSessionDisabled applies session-only disable override")
BETTERUI.SetModuleSessionDisabled("Inventory", true)
assert_equal(false, BETTERUI.GetModuleEnabled("Inventory"), "Session disable hides enabled module")
BETTERUI.SetModuleSessionDisabled("Inventory", false)
assert_true(BETTERUI.GetModuleEnabled("Inventory"), "Session re-enable restores module")
assert_nil(BETTERUI._sessionDisabledModules and BETTERUI._sessionDisabledModules["Inventory"],
    "Session re-enable clears the override entry")

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
-- TESTS: Reflective SafeCall surface removed
-- ============================================================================

print("\n=== SafeCall Surface Tests ===\n")
assert_nil(BETTERUI.CIM.Utils.SafeCall, "CIM utility surface no longer exports reflective SafeCall")
assert_nil(BETTERUI.Utils.SafeCall, "Root BetterUI utility surface no longer re-exports SafeCall")

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

assert_nil(BETTERUI.CIM.Utils.GetActiveBankTransferContext,
    "Banking context forwarding helper is removed from CIM utilities")
assert_nil(BETTERUI.CIM.Utils.GetBankingTransferSupport,
    "Banking transfer-support forwarding helper is removed from CIM utilities")
assert_nil(BETTERUI.CIM.Utils.GetBankingSortEntryContext,
    "Banking sort-context forwarding helper is removed from CIM utilities")
assert_nil(BETTERUI.CIM.Utils.CreateInventorySlotActions,
    "Inventory slot-action forwarding helper is removed from CIM utilities")
assert_nil(BETTERUI.CIM.Utils.ClearTrackedInventorySlot,
    "Inventory tracker forwarding helper is removed from CIM utilities")

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
