--[[
File: tools/tests/test_event_registry.lua
Purpose: Unit tests for EventRegistry utility.
         Loads production code via dofile to ensure tests track implementation.

Usage:
  lua tools/tests/test_event_registry.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

local registeredEvents = {}
local addedFilters = {}

EVENT_MANAGER = {
    RegisterForEvent = function(self, namespace, eventId, callback)
        registeredEvents[namespace] = registeredEvents[namespace] or {}
        registeredEvents[namespace][eventId] = callback
    end,
    UnregisterForEvent = function(self, namespace, eventId)
        if registeredEvents[namespace] then
            registeredEvents[namespace][eventId] = nil
        end
    end,
    AddFilterForEvent = function(self, namespace, eventId, filterType, filterValue)
        addedFilters[namespace] = addedFilters[namespace] or {}
        addedFilters[namespace][eventId] = { filterType = filterType, filterValue = filterValue }
    end,
}

BETTERUI = { CIM = {} }

function BETTERUI.Debug(msg)
    -- Silent in tests
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Lifecycle/EventRegistry.lua")

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

local function resetAll()
    registeredEvents = {}
    addedFilters = {}
    BETTERUI.CIM.EventRegistry._registrations = {}
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== EventRegistry Tests ===\n")

-- Test 1: Register adds to tracking
print("Test: Register adds to tracking")
resetAll()
BETTERUI.CIM.EventRegistry.Register("TestModule", "Test_Namespace", 100, function() end)
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "Registration count is 1")
assert_true(BETTERUI.CIM.EventRegistry.GetRegisteredEvents()["TestModule"] ~= nil, "Runtime registry tracks module registrations")

-- Test 2: Multiple registrations tracked
print("\nTest: Multiple registrations tracked")
BETTERUI.CIM.EventRegistry.Register("TestModule", "Test_Namespace2", 101, function() end)
assert_equal(2, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "Registration count is 2")

-- Test 3: UnregisterAll clears module
print("\nTest: UnregisterAll clears module")
BETTERUI.CIM.EventRegistry.UnregisterAll("TestModule")
assert_equal(0, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "Registration count is 0 after unregister")

-- Test 4: Separate modules tracked independently
print("\nTest: Separate modules tracked independently")
resetAll()
BETTERUI.CIM.EventRegistry.Register("ModuleA", "NS_A", 200, function() end)
BETTERUI.CIM.EventRegistry.Register("ModuleB", "NS_B", 201, function() end)
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("ModuleA"), "ModuleA has 1 registration")
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("ModuleB"), "ModuleB has 1 registration")
BETTERUI.CIM.EventRegistry.UnregisterAll("ModuleA")
assert_equal(0, BETTERUI.CIM.EventRegistry.GetRegistrationCount("ModuleA"), "ModuleA cleared")
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("ModuleB"), "ModuleB still has 1")

-- Test 5: Unregister removes specific event
print("\nTest: Unregister removes specific event")
resetAll()
BETTERUI.CIM.EventRegistry.Register("TestModule", "NS1", 300, function() end)
BETTERUI.CIM.EventRegistry.Register("TestModule", "NS2", 301, function() end)
assert_equal(2, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "Starts with 2")
BETTERUI.CIM.EventRegistry.Unregister("TestModule", "NS1", 300)
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "Down to 1 after Unregister")

-- Test 6: Unregister cleans up empty tables
print("\nTest: Unregister cleans up empty tables")
BETTERUI.CIM.EventRegistry.Unregister("TestModule", "NS2", 301)
assert_equal(0, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "Down to 0")

-- Test 7: RegisterFiltered adds filter to EVENT_MANAGER
print("\nTest: RegisterFiltered adds filter to EVENT_MANAGER")
resetAll()
BETTERUI.CIM.EventRegistry.RegisterFiltered("FilterMod", "FilterNS", 400, function() end, 1, 42)
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("FilterMod"), "Filtered registration tracked")
assert_true(addedFilters["FilterNS"] ~= nil, "Filter was added")
assert_equal(1, addedFilters["FilterNS"][400].filterType, "Filter type correct")
assert_equal(42, addedFilters["FilterNS"][400].filterValue, "Filter value correct")

-- Test 8: GetRegistrationCount returns 0 for unknown module
print("\nTest: GetRegistrationCount returns 0 for unknown module")
assert_equal(0, BETTERUI.CIM.EventRegistry.GetRegistrationCount("NonExistent"), "Unknown module returns 0")

-- Test 9: Unregister for non-existent module does not crash
print("\nTest: Unregister for non-existent module does not crash")
BETTERUI.CIM.EventRegistry.Unregister("NoSuchModule", "NS", 999)
tests_passed = tests_passed + 1
print("  [OK] No crash on non-existent module unregister")

-- Test 10: Multiple namespaces on same event tracked correctly
print("\nTest: Multiple namespaces on same event tracked correctly")
resetAll()
BETTERUI.CIM.EventRegistry.Register("TestModule", "NS_A", 500, function() end)
BETTERUI.CIM.EventRegistry.Register("TestModule", "NS_B", 500, function() end)
assert_equal(2, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "Two registrations on same event")
BETTERUI.CIM.EventRegistry.Unregister("TestModule", "NS_A", 500)
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "One left after partial unregister")

-- Cleanup
BETTERUI.CIM.EventRegistry.UnregisterAll("TestModule", true)
BETTERUI.CIM.EventRegistry.UnregisterAll("FilterMod", true)
BETTERUI.CIM.EventRegistry.UnregisterAll("ModuleB", true)

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
