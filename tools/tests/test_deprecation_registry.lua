--[[
File: tools/tests/test_deprecation_registry.lua
Purpose: Unit tests for DeprecationRegistry utility.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_deprecation_registry.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

function GetGameTimeMilliseconds()
    return os.time() * 1000
end

-- Mock BETTERUI namespace
BETTERUI = { CIM = {} }

local debugOutput = {}
function BETTERUI.Debug(msg)
    table.insert(debugOutput, msg)
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

-- Inline DeprecationRegistry implementation for standalone testing
BETTERUI.CIM.DeprecationRegistry = {
    _registry = {},
    _warned = {},
    _enabled = true,
}

function BETTERUI.CIM.DeprecationRegistry.Register(oldName, newName, removeVersion)
    BETTERUI.CIM.DeprecationRegistry._registry[oldName] = {
        oldName = oldName,
        newName = newName,
        removeVersion = removeVersion or "future",
        registeredAt = GetGameTimeMilliseconds(),
    }
end

function BETTERUI.CIM.DeprecationRegistry.WarnOnce(oldName)
    if not BETTERUI.CIM.DeprecationRegistry._enabled then return false end
    if BETTERUI.CIM.DeprecationRegistry._warned[oldName] then return false end

    local info = BETTERUI.CIM.DeprecationRegistry._registry[oldName]
    if not info then return false end

    BETTERUI.CIM.DeprecationRegistry._warned[oldName] = true

    local msg = string.format(
        "[Deprecated] '%s' is deprecated, use '%s' instead (removed in %s)",
        info.oldName,
        info.newName,
        info.removeVersion or "future"
    )

    BETTERUI.Debug(msg)
    return true
end

function BETTERUI.CIM.DeprecationRegistry.SetEnabled(enabled)
    BETTERUI.CIM.DeprecationRegistry._enabled = enabled
end

function BETTERUI.CIM.DeprecationRegistry.GetAll()
    local result = {}
    for _, info in pairs(BETTERUI.CIM.DeprecationRegistry._registry) do
        table.insert(result, info)
    end
    return result
end

function BETTERUI.CIM.DeprecationRegistry.CreateShim(oldName, newFn)
    return function(...)
        BETTERUI.CIM.DeprecationRegistry.WarnOnce(oldName)
        return newFn(...)
    end
end

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

-- Test 2: WarnOnce issues warning first time
print("\nTest: WarnOnce issues warning first time")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("DEPRECATED", "REPLACEMENT", "v4.0")
local warned = BETTERUI.CIM.DeprecationRegistry.WarnOnce("DEPRECATED")
assert_true(warned, "WarnOnce returns true first time")
assert_equal(1, #debugOutput, "One debug message logged")

-- Test 3: WarnOnce does not repeat warning
print("\nTest: WarnOnce does not repeat warning")
local warned2 = BETTERUI.CIM.DeprecationRegistry.WarnOnce("DEPRECATED")
assert_false(warned2, "WarnOnce returns false second time")
assert_equal(1, #debugOutput, "Still only one debug message")

-- Test 4: WarnOnce for unregistered returns false
print("\nTest: WarnOnce for unregistered returns false")
resetRegistry()
local warned3 = BETTERUI.CIM.DeprecationRegistry.WarnOnce("UNKNOWN")
assert_false(warned3, "WarnOnce returns false for unregistered")

-- Test 5: SetEnabled disables warnings
print("\nTest: SetEnabled disables warnings")
resetRegistry()
BETTERUI.CIM.DeprecationRegistry.Register("DISABLED_TEST", "NEW", "v5.0")
BETTERUI.CIM.DeprecationRegistry.SetEnabled(false)
local warned4 = BETTERUI.CIM.DeprecationRegistry.WarnOnce("DISABLED_TEST")
assert_false(warned4, "WarnOnce returns false when disabled")
BETTERUI.CIM.DeprecationRegistry.SetEnabled(true)

-- Test 6: CreateShim calls function and warns
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
