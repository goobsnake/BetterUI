--[[
File: tools/tests/test_user_notify.lua
Purpose: Unit tests for the UserNotify wrapper in SafeExecute.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_user_notify.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }

local debugOutput = {}
function BETTERUI.Debug(msg)
    table.insert(debugOutput, msg)
end

-- ESO constants
UI_ALERT_CATEGORY_ERROR = 1
SOUNDS = { NEGATIVE_CLICK = 100, GENERAL_ALERT_ERROR = 200 }

-- String table
local stringTable = {
    [1001] = "Inventory is full",
    [1002] = "Cannot deposit stolen items",
    [1003] = "No empty slots",
}

function GetString(stringId)
    return stringTable[stringId] or ("UNKNOWN:" .. tostring(stringId))
end

-- Track ZO_Alert calls
local alertCalls = {}
function ZO_Alert(category, sound, messageStringId)
    table.insert(alertCalls, {
        category = category,
        sound = sound,
        messageStringId = messageStringId,
    })
end

-- Reset helper
local function reset()
    debugOutput = {}
    alertCalls = {}
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Diagnostics/SafeExecute.lua")

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

local function assert_contains(haystack, needle, message)
    if type(haystack) == "string" and haystack:find(needle, 1, true) then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("    Expected to contain: " .. tostring(needle))
        print("    In: " .. tostring(haystack))
    end
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== UserNotify Tests ===\n")

-- Test 1: UserNotify calls ZO_Alert with correct category
print("Test: UserNotify calls ZO_Alert with error category")
reset()
BETTERUI.CIM.UserNotify("Test:Action", 1001)
assert_equal(1, #alertCalls, "One ZO_Alert call made")
assert_equal(UI_ALERT_CATEGORY_ERROR, alertCalls[1].category, "Category is ERROR")

-- Test 2: UserNotify passes messageStringId through
print("\nTest: UserNotify passes messageStringId to ZO_Alert")
reset()
BETTERUI.CIM.UserNotify("Test:Action", 1002)
assert_equal(1002, alertCalls[1].messageStringId, "Message string ID passed through")

-- Test 3: Default sound is SOUNDS.NEGATIVE_CLICK
print("\nTest: Default sound is NEGATIVE_CLICK")
reset()
BETTERUI.CIM.UserNotify("Test:Action", 1001)
assert_equal(SOUNDS.NEGATIVE_CLICK, alertCalls[1].sound, "Default sound is NEGATIVE_CLICK")

-- Test 4: Custom sound overrides default
print("\nTest: Custom sound overrides default")
reset()
BETTERUI.CIM.UserNotify("Test:Action", 1001, SOUNDS.GENERAL_ALERT_ERROR)
assert_equal(SOUNDS.GENERAL_ALERT_ERROR, alertCalls[1].sound, "Custom sound used")

-- Test 5: Debug log is emitted with context
print("\nTest: Debug log contains context label")
reset()
BETTERUI.CIM.UserNotify("TransferActions:GuildWithdraw", 1001)
assert_equal(1, #debugOutput, "One debug message logged")
assert_contains(debugOutput[1], "TransferActions:GuildWithdraw", "Context appears in log")

-- Test 6: Debug log contains resolved message text
print("\nTest: Debug log contains resolved string")
reset()
BETTERUI.CIM.UserNotify("Test:Action", 1001)
assert_contains(debugOutput[1], "Inventory is full", "Resolved message appears in log")

-- Test 7: Debug log has [UserNotify] prefix
print("\nTest: Debug log has [UserNotify] prefix")
reset()
BETTERUI.CIM.UserNotify("Test:Action", 1001)
assert_contains(debugOutput[1], "[UserNotify]", "Log has UserNotify prefix")

-- Test 8: Unknown string ID doesn't crash
print("\nTest: Unknown string ID doesn't crash")
reset()
BETTERUI.CIM.UserNotify("Test:Unknown", 9999)
assert_equal(1, #alertCalls, "ZO_Alert still called")
assert_equal(1, #debugOutput, "Debug still logged")

-- ============================================================================
-- UserNotify text payload Tests
-- ============================================================================

print("\n=== UserNotify text payload Tests ===\n")

-- Test 9: UserNotify calls ZO_Alert with text string
print("Test: UserNotify calls ZO_Alert with text string")
reset()
BETTERUI.CIM.UserNotify("EquipAction:Equip", "Item cannot be equipped")
assert_equal(1, #alertCalls, "One ZO_Alert call made")
assert_equal(UI_ALERT_CATEGORY_ERROR, alertCalls[1].category, "Category is ERROR")
assert_equal("Item cannot be equipped", alertCalls[1].messageStringId, "Text string passed to ZO_Alert")

-- Test 10: UserNotify default sound remains NEGATIVE_CLICK for text
print("\nTest: UserNotify default sound for text payload")
reset()
BETTERUI.CIM.UserNotify("Test:Text", "Some error")
assert_equal(SOUNDS.NEGATIVE_CLICK, alertCalls[1].sound, "Default sound is NEGATIVE_CLICK")

-- Test 11: UserNotify custom sound for text payload
print("\nTest: UserNotify custom sound for text payload")
reset()
BETTERUI.CIM.UserNotify("Test:Text", "Some error", SOUNDS.GENERAL_ALERT_ERROR)
assert_equal(SOUNDS.GENERAL_ALERT_ERROR, alertCalls[1].sound, "Custom sound used")

-- Test 12: UserNotify debug log contains context and text for text payloads
print("\nTest: UserNotify debug log for text payload")
reset()
BETTERUI.CIM.UserNotify("EquipAction:Equip", "Cannot equip while stunned")
assert_equal(1, #debugOutput, "One debug message logged")
assert_contains(debugOutput[1], "EquipAction:Equip", "Context appears in log")
assert_contains(debugOutput[1], "Cannot equip while stunned", "Text appears in log")
assert_contains(debugOutput[1], "[UserNotify]", "Log has UserNotify prefix")

-- Test 13: UserNotifyText is no longer exported publicly
print("\nTest: UserNotifyText export removed")
assert_equal(nil, BETTERUI.CIM.UserNotifyText, "UserNotifyText export removed")

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
