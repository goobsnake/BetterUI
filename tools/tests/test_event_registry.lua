--[[
File: tools/tests/test_event_registry.lua
Purpose: Unit tests for EventRegistry utility.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_event_registry.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

-- Mock EVENT_MANAGER
local registeredEvents = {}
EVENT_MANAGER = {
    RegisterForEvent = function(namespace, eventId, callback)
        registeredEvents[namespace] = registeredEvents[namespace] or {}
        registeredEvents[namespace][eventId] = callback
    end,
    UnregisterForEvent = function(namespace, eventId)
        if registeredEvents[namespace] then
            registeredEvents[namespace][eventId] = nil
        end
    end,
    IsRegistered = function(namespace, eventId)
        return registeredEvents[namespace] and registeredEvents[namespace][eventId] ~= nil
    end
}

-- Mock BETTERUI namespace
BETTERUI = { CIM = {} }

function BETTERUI.Debug(msg)
    -- Silent in tests
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

-- Inline the EventRegistry implementation for standalone testing
BETTERUI.CIM.EventRegistry = {
    _registrations = {}
}

local registrations = BETTERUI.CIM.EventRegistry._registrations

function BETTERUI.CIM.EventRegistry.Register(moduleName, namespace, eventId, callback)
    registrations[moduleName] = registrations[moduleName] or {}
    registrations[moduleName][eventId] = registrations[moduleName][eventId] or {}
    table.insert(registrations[moduleName][eventId], namespace)
    EVENT_MANAGER:RegisterForEvent(namespace, eventId, callback)
end

function BETTERUI.CIM.EventRegistry.UnregisterAll(moduleName)
    local moduleRegs = registrations[moduleName]
    if not moduleRegs then return end

    for eventId, namespaces in pairs(moduleRegs) do
        for _, namespace in ipairs(namespaces) do
            EVENT_MANAGER:UnregisterForEvent(namespace, eventId)
        end
    end
    registrations[moduleName] = nil
end

function BETTERUI.CIM.EventRegistry.GetRegistrationCount(moduleName)
    local moduleRegs = registrations[moduleName]
    if not moduleRegs then return 0 end

    local count = 0
    for _, namespaces in pairs(moduleRegs) do
        count = count + #namespaces
    end
    return count
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

print("\n=== EventRegistry Tests ===\n")

-- Test 1: Register adds to tracking
print("Test: Register adds to tracking")
BETTERUI.CIM.EventRegistry.Register("TestModule", "Test_Namespace", 100, function() end)
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("TestModule"), "Registration count is 1")

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
BETTERUI.CIM.EventRegistry.Register("ModuleA", "NS_A", 200, function() end)
BETTERUI.CIM.EventRegistry.Register("ModuleB", "NS_B", 201, function() end)
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("ModuleA"), "ModuleA has 1 registration")
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("ModuleB"), "ModuleB has 1 registration")
BETTERUI.CIM.EventRegistry.UnregisterAll("ModuleA")
assert_equal(0, BETTERUI.CIM.EventRegistry.GetRegistrationCount("ModuleA"), "ModuleA cleared")
assert_equal(1, BETTERUI.CIM.EventRegistry.GetRegistrationCount("ModuleB"), "ModuleB still has 1")

-- Cleanup
BETTERUI.CIM.EventRegistry.UnregisterAll("ModuleB")

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
