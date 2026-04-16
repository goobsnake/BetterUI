--[[
File: tools/tests/test_feature_flags.lua
Purpose: Unit tests for FeatureFlags utility.
         Loads production code via dofile to ensure tests track implementation.

Usage:
  lua tools/tests/test_feature_flags.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {}, Settings = { FeatureFlags = {} } }

function BETTERUI.Debug(msg)
    -- Silent in tests
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Diagnostics/FeatureFlags.lua")

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

local function assert_not_nil(value, message)
    if value ~= nil then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message .. " (got nil)")
    end
end

local function reset()
    BETTERUI.Settings = { FeatureFlags = {} }
    BETTERUI.CIM.FeatureFlags.ClearOverrides()
    BETTERUI.CIM.FeatureFlags.ResetToDefaults()
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== FeatureFlags Tests ===\n")

-- Test 1: Default enabled flags return true
print("Test: Default enabled flags return true")
reset()
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("ENHANCED_TOOLTIPS"), "ENHANCED_TOOLTIPS is true by default")
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("POSITION_PERSISTENCE"), "POSITION_PERSISTENCE is true by default")
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("BATCH_PROCESSING"), "BATCH_PROCESSING is true by default")

-- Test 2: Default disabled flags return false
print("\nTest: Default disabled flags return false")
reset()
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("DEBUG_LOGGING"), "DEBUG_LOGGING is false by default")
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("PERFORMANCE_METRICS"), "PERFORMANCE_METRICS is false by default")
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("SHIELD_DEBUG"), "SHIELD_DEBUG is false by default")

-- Test 3: Unknown flag returns false
print("\nTest: Unknown flag returns false")
reset()
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("UNKNOWN_FLAG"), "Unknown flag returns false")

-- Test 4: SetEnabled persists to settings
print("\nTest: SetEnabled persists to settings")
reset()
BETTERUI.CIM.FeatureFlags.SetEnabled("DEBUG_LOGGING", true)
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("DEBUG_LOGGING"), "Flag is now enabled")
assert_true(BETTERUI.Settings.FeatureFlags["DEBUG_LOGGING"], "Setting was persisted")

-- Test 5: Override takes precedence over default
print("\nTest: Override takes precedence over default")
reset()
BETTERUI.CIM.FeatureFlags.SetOverride("ENHANCED_TOOLTIPS", false)
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("ENHANCED_TOOLTIPS"), "Override disabled the flag")

-- Test 6: Override takes precedence over saved setting
print("\nTest: Override takes precedence over saved setting")
reset()
BETTERUI.CIM.FeatureFlags.SetEnabled("DEBUG_LOGGING", true)
BETTERUI.CIM.FeatureFlags.SetOverride("DEBUG_LOGGING", false)
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("DEBUG_LOGGING"), "Override takes precedence over setting")

-- Test 7: ClearOverrides restores to saved/default
print("\nTest: ClearOverrides restores to saved/default")
reset()
BETTERUI.CIM.FeatureFlags.SetOverride("ENHANCED_TOOLTIPS", false)
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("ENHANCED_TOOLTIPS"), "Override active")
BETTERUI.CIM.FeatureFlags.ClearOverrides()
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("ENHANCED_TOOLTIPS"), "Restored to default after clear")

-- Test 8: GetAllFlags returns all 6 defined flags
print("\nTest: GetAllFlags returns all defined flags")
reset()
local allFlags = BETTERUI.CIM.FeatureFlags.GetAllFlags()
local count = 0
for _ in pairs(allFlags) do count = count + 1 end
assert_equal(6, count, "GetAllFlags returns 6 flags")
assert_not_nil(allFlags["ENHANCED_TOOLTIPS"], "ENHANCED_TOOLTIPS present")
assert_not_nil(allFlags["DEBUG_LOGGING"], "DEBUG_LOGGING present")
assert_not_nil(allFlags["SHIELD_DEBUG"], "SHIELD_DEBUG present")

-- Test 9: GetAllFlags entries contain definition and enabled state
print("\nTest: GetAllFlags entries have correct structure")
reset()
local flags = BETTERUI.CIM.FeatureFlags.GetAllFlags()
local tooltipEntry = flags["ENHANCED_TOOLTIPS"]
assert_not_nil(tooltipEntry.definition, "Entry has definition")
assert_equal("ENHANCED_TOOLTIPS", tooltipEntry.definition.name, "Definition has correct name")
assert_true(tooltipEntry.enabled, "Entry reflects enabled state")

-- Test 10: ResetToDefaults clears everything
print("\nTest: ResetToDefaults clears everything")
BETTERUI.CIM.FeatureFlags.SetEnabled("DEBUG_LOGGING", true)
BETTERUI.CIM.FeatureFlags.SetOverride("ENHANCED_TOOLTIPS", false)
BETTERUI.CIM.FeatureFlags.ResetToDefaults()
assert_true(BETTERUI.CIM.FeatureFlags.IsEnabled("ENHANCED_TOOLTIPS"), "Enabled flag back to default")
assert_false(BETTERUI.CIM.FeatureFlags.IsEnabled("DEBUG_LOGGING"), "Disabled flag back to default")

-- Test 11: FLAGS constants match actual flag names
print("\nTest: FLAGS constants match flag names")
reset()
assert_equal("ENHANCED_TOOLTIPS", BETTERUI.CIM.FeatureFlags.FLAGS.ENHANCED_TOOLTIPS, "ENHANCED_TOOLTIPS constant correct")
assert_equal("DEBUG_LOGGING", BETTERUI.CIM.FeatureFlags.FLAGS.DEBUG_LOGGING, "DEBUG_LOGGING constant correct")
assert_equal("SHIELD_DEBUG", BETTERUI.CIM.FeatureFlags.FLAGS.SHIELD_DEBUG, "SHIELD_DEBUG constant correct")

-- Test 12: SetEnabled creates Settings tables if nil
print("\nTest: SetEnabled creates Settings tables if nil")
BETTERUI.Settings = nil
BETTERUI.CIM.FeatureFlags.SetEnabled("DEBUG_LOGGING", true)
assert_not_nil(BETTERUI.Settings, "Settings table created")
assert_not_nil(BETTERUI.Settings.FeatureFlags, "FeatureFlags table created")
assert_true(BETTERUI.Settings.FeatureFlags["DEBUG_LOGGING"], "Value was set")

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
