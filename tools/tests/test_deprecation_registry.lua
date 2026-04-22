--[[
File: tools/tests/test_deprecation_registry.lua
Purpose: Unit tests for DeprecationRegistry utility.
         Loads production code via dofile to ensure tests track implementation.

Usage:
  lua tools/tests/test_deprecation_registry.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

function GetGameTimeMilliseconds()
    return os.time() * 1000
end

BETTERUI = { CIM = {} }

local debugOutput = {}
function BETTERUI.Debug(msg)
    table.insert(debugOutput, msg)
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Diagnostics/DeprecationRegistry.lua")

-- Reset for tests
local function resetRegistry()
    BETTERUI.CIM.DeprecationRegistry._registry = {}
    BETTERUI.CIM.DeprecationRegistry._warned = {}
    BETTERUI.CIM.DeprecationRegistry._enabled = true
    debugOutput = {}
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

print("\n=== DeprecationRegistry Tests ===\n")

-- Test 1: Register adds to registry
print("Test: Register adds to registry")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("OLD_API", "NEW_API", "v3.1")
local all = BETTERUI.CIM.DeprecationRegistry.GetAll()
assert_equal(1, #all, "Registry has 1 entry")
assert_equal("OLD_API", all[1].oldName, "oldName is correct")
assert_equal("NEW_API", all[1].newName, "newName is correct")
assert_equal("v3.1", all[1].removeVersion, "removeVersion is correct")

-- Test 2: Register without removeVersion defaults to "future"
print("\nTest: Register without removeVersion defaults to future")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("OLD2", "NEW2")
local all2 = BETTERUI.CIM.DeprecationRegistry.GetAll()
assert_equal("future", all2[1].removeVersion, "Default removeVersion is future")

-- Test 3: WarnOnce issues warning first time
print("\nTest: WarnOnce issues warning first time")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("DEPRECATED", "REPLACEMENT", "v4.0")
local warned = BETTERUI.CIM.DeprecationRegistry.WarnOnce("DEPRECATED")
assert_true(warned, "WarnOnce returns true first time")
assert_equal(1, #debugOutput, "One debug message logged")

-- Test 4: WarnOnce does not repeat warning
print("\nTest: WarnOnce does not repeat warning")
local warned2 = BETTERUI.CIM.DeprecationRegistry.WarnOnce("DEPRECATED")
assert_false(warned2, "WarnOnce returns false second time")
assert_equal(1, #debugOutput, "Still only one debug message")

-- Test 5: WarnOnce for unregistered returns false
print("\nTest: WarnOnce for unregistered returns false")
resetRegistry()
local warned3 = BETTERUI.CIM.DeprecationRegistry.WarnOnce("UNKNOWN")
assert_false(warned3, "WarnOnce returns false for unregistered")

-- Test 6: SetEnabled disables warnings
print("\nTest: SetEnabled disables warnings")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("DISABLED_TEST", "NEW", "v5.0")
BETTERUI.CIM.DeprecationRegistry.SetEnabled(false)
local warned4 = BETTERUI.CIM.DeprecationRegistry.WarnOnce("DISABLED_TEST")
assert_false(warned4, "WarnOnce returns false when disabled")
assert_equal(0, #debugOutput, "No debug output when disabled")
BETTERUI.CIM.DeprecationRegistry.SetEnabled(true)

-- Test 7: CreateShim calls function and warns
print("\nTest: CreateShim calls function and warns")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("OLD_FUNC", "NEW_FUNC", "v6.0")
local callCount = 0
local shim = BETTERUI.CIM.DeprecationRegistry.CreateShim("OLD_FUNC", function(x)
    callCount = callCount + 1
    return x * 2
end)
local result = shim(5)
assert_equal(10, result, "Shim returns correct value")
assert_equal(1, callCount, "Underlying function called")
assert_equal(1, #debugOutput, "Warning was issued")

-- Test 8: CreateShim only warns once across multiple calls
print("\nTest: CreateShim only warns once across multiple calls")
local result2 = shim(3)
assert_equal(6, result2, "Shim still works on second call")
assert_equal(2, callCount, "Function called again")
assert_equal(1, #debugOutput, "Still only one warning")

-- Test 9: Warning message contains correct content
print("\nTest: Warning message contains correct content")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("API_V1", "API_V2", "v7.0")
BETTERUI.CIM.DeprecationRegistry.WarnOnce("API_V1")
local msg = debugOutput[1]
assert_true(msg:find("API_V1") ~= nil, "Message contains old name")
assert_true(msg:find("API_V2") ~= nil, "Message contains new name")
assert_true(msg:find("v7.0") ~= nil, "Message contains version")

-- Test 10: Multiple deprecations tracked independently
print("\nTest: Multiple deprecations tracked independently")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("FUNC_A", "FUNC_A2", "v8.0")
BETTERUI.CIM.DeprecationRegistry.Register("FUNC_B", "FUNC_B2", "v9.0")
local all3 = BETTERUI.CIM.DeprecationRegistry.GetAll()
assert_equal(2, #all3, "Registry has 2 entries")
BETTERUI.CIM.DeprecationRegistry.WarnOnce("FUNC_A")
BETTERUI.CIM.DeprecationRegistry.WarnOnce("FUNC_B")
assert_equal(2, #debugOutput, "Both warnings issued")

-- Test 11: GetAll returns observational copies
print("\nTest: GetAll returns observational copies")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("SNAPSHOT_OLD", "SNAPSHOT_NEW", "v10.0")
local exported = BETTERUI.CIM.DeprecationRegistry.GetAll()
exported[1].newName = "MUTATED_EXTERNAL"
local exportedAgain = BETTERUI.CIM.DeprecationRegistry.GetAll()
assert_equal("SNAPSHOT_NEW", exportedAgain[1].newName, "Mutating GetAll result does not alter registry entries")

-- Test 12: GetRegistryLive exposes mutable registry table intentionally
print("\nTest: GetRegistryLive exposes mutable registry table intentionally")
local liveRegistry = BETTERUI.CIM.DeprecationRegistry.GetRegistryLive()
liveRegistry.LIVE_ALIAS = {
    oldName = "LIVE_ALIAS",
    newName = "LIVE_NEW",
    removeVersion = "future",
    registeredAt = 0,
}
assert_true(BETTERUI.CIM.DeprecationRegistry.WarnOnce("LIVE_ALIAS"), "Live registry mutation is observable by WarnOnce")

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
