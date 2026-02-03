--[[
File: tools/tests/test_feature_flags.lua
Purpose: Unit tests for FeatureFlags utility.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_feature_flags.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

-- Mock BETTERUI namespace with Settings
BETTERUI = {
    CIM = {},
    Settings = {
        FeatureFlags = {}
    }
}

function BETTERUI.Debug(msg)
    -- Silent in tests
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

-- Inline FeatureFlags implementation for standalone testing
BETTERUI.CIM.FeatureFlags = {}

local FLAG_DEFINITIONS = {
    TEST_FLAG_ENABLED = {
        name = "TEST_FLAG_ENABLED",
        description = "Test flag that is enabled by default",
        defaultEnabled = true,
        version = "1.0",
    },
    TEST_FLAG_DISABLED = {
        name = "TEST_FLAG_DISABLED",
        description = "Test flag that is disabled by default",
        defaultEnabled = false,
        version = "1.0",
    },
}

local flagStateCache = {}
local flagOverrides = {}

function BETTERUI.CIM.FeatureFlags.IsEnabled(flagName)
    -- Check runtime override first
    if flagOverrides[flagName] ~= nil then
        return flagOverrides[flagName]
    end

    -- Check cached state
    if flagStateCache[flagName] ~= nil then
        return flagStateCache[flagName]
    end

    -- Check saved settings
    local settings = BETTERUI.Settings and BETTERUI.Settings.FeatureFlags
    if settings and settings[flagName] ~= nil then
        flagStateCache[flagName] = settings[flagName]
        return settings[flagName]
    end

    -- Fall back to default
    local def = FLAG_DEFINITIONS[flagName]
    if def then
        flagStateCache[flagName] = def.defaultEnabled
        return def.defaultEnabled
    end

    -- Unknown flag - disabled by default
    return false
end

function BETTERUI.CIM.FeatureFlags.SetEnabled(flagName, enabled)
    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.FeatureFlags = BETTERUI.Settings.FeatureFlags or {}
    BETTERUI.Settings.FeatureFlags[flagName] = enabled
    flagStateCache[flagName] = nil
end

function BETTERUI.CIM.FeatureFlags.SetOverride(flagName, enabled)
    flagOverrides[flagName] = enabled
end

function BETTERUI.CIM.FeatureFlags.ClearOverrides()
    flagOverrides = {}
end

function BETTERUI.CIM.FeatureFlags.GetAllFlags()
    local result = {}
    for name, def in pairs(FLAG_DEFINITIONS) do
        result[name] = {
            definition = def,
            enabled = BETTERUI.CIM.FeatureFlags.IsEnabled(name),
        }
    end
    return result
end

function BETTERUI.CIM.FeatureFlags.ResetToDefaults()
    if BETTERUI.Settings then
        BETTERUI.Settings.FeatureFlags = {}
    end
    flagStateCache = {}
    flagOverrides = {}
end

-- Reset helper for tests
local function reset()
    BETTERUI.Settings = { FeatureFlags = {} }
    flagStateCache = {}
    flagOverrides = {}
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

print("\n=== FeatureFlags Tests ===\n")

-- Test 1: Default enabled flag returns true
print("Test: Default enabled flag returns true")
reset()
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_ENABLED"), "Enabled flag is true by default")

-- Test 2: Default disabled flag returns false
print("\nTest: Default disabled flag returns false")
reset()
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_DISABLED"), "Disabled flag is false by default")

-- Test 3: Unknown flag returns false
print("\nTest: Unknown flag returns false")
reset()
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("UNKNOWN_FLAG"), "Unknown flag returns false")

-- Test 4: SetEnabled persists to settings
print("\nTest: SetEnabled persists to settings")
reset()
BETTERUI.CIM.FeatureFlags.SetEnabled("TEST_FLAG_DISABLED", true)
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_DISABLED"), "Flag is now enabled")
assert_true(BETTERUI.Settings.FeatureFlags["TEST_FLAG_DISABLED"], "Setting was persisted")

-- Test 5: Override takes precedence over default
print("\nTest: Override takes precedence over default")
reset()
BETTERUI.CIM.FeatureFlags.SetOverride("TEST_FLAG_ENABLED", false)
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_ENABLED"), "Override disabled the flag")

-- Test 6: Override takes precedence over saved setting
print("\nTest: Override takes precedence over saved setting")
reset()
BETTERUI.CIM.FeatureFlags.SetEnabled("TEST_FLAG_DISABLED", true)
BETTERUI.CIM.FeatureFlags.SetOverride("TEST_FLAG_DISABLED", false)
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_DISABLED"), "Override takes precedence over setting")

-- Test 7: ClearOverrides restores to saved/default
print("\nTest: ClearOverrides restores to saved/default")
reset()
BETTERUI.CIM.FeatureFlags.SetOverride("TEST_FLAG_ENABLED", false)
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_ENABLED"), "Override active")
BETTERUI.CIM.FeatureFlags.ClearOverrides()
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_ENABLED"), "Restored to default after clear")

-- Test 8: GetAllFlags returns all defined flags
print("\nTest: GetAllFlags returns all defined flags")
reset()
local allFlags = BETTERUI.CIM.FeatureFlags.GetAllFlags()
local count = 0
for _ in pairs(allFlags) do count = count + 1 end
assert_equal(2, count, "GetAllFlags returns 2 flags")
assert_true(allFlags["TEST_FLAG_ENABLED"] ~= nil, "TEST_FLAG_ENABLED is in result")
assert_true(allFlags["TEST_FLAG_DISABLED"] ~= nil, "TEST_FLAG_DISABLED is in result")

-- Test 9: ResetToDefaults clears everything
print("\nTest: ResetToDefaults clears everything")
BETTERUI.CIM.FeatureFlags.SetEnabled("TEST_FLAG_DISABLED", true)
BETTERUI.CIM.FeatureFlags.SetOverride("TEST_FLAG_ENABLED", false)
BETTERUI.CIM.FeatureFlags.ResetToDefaults()
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_ENABLED"), "Enabled flag back to default")
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("TEST_FLAG_DISABLED"), "Disabled flag back to default")

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
