--[[
File: tools/tests/test_number_formatting.lua
Purpose: Unit tests for live NumberFormatting utility functions.
                 Loads production code from CIM/Core/Presentation/NumberFormatting.lua.

Usage:
  lua tools/tests/test_number_formatting.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

-- Stub ZO_CommaDelimitNumber (ESO API)
BETTERUI = {}

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Presentation/NumberFormatting.lua")

-- ============================================================================
-- TEST FRAMEWORK
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, test_name)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("[PASS] " .. test_name)
    else
        tests_failed = tests_failed + 1
        print("[FAIL] " .. test_name)
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
    end
end

-- ============================================================================
-- TEST CASES: DisplayNumber
-- ============================================================================

print("\n=== DisplayNumber Tests ===\n")

assert_equal("0", BETTERUI.DisplayNumber(0), "DisplayNumber: 0 returns '0'")
assert_equal("100", BETTERUI.DisplayNumber(100), "DisplayNumber: 100 returns '100'")
assert_equal("1,000", BETTERUI.DisplayNumber(1000), "DisplayNumber: 1000 returns '1,000'")
assert_equal("1,000,000", BETTERUI.DisplayNumber(1000000), "DisplayNumber: 1M returns '1,000,000'")
assert_equal("12,345,678", BETTERUI.DisplayNumber(12345678), "DisplayNumber: 12345678 returns '12,345,678'")
assert_equal("-1,234.5", BETTERUI.DisplayNumber(-1234.5), "DisplayNumber: preserves negative sign and fraction")

-- ============================================================================
-- TEST CASES: FormatNumber
-- ============================================================================

print("\n=== FormatNumber Tests ===\n")

assert_equal("0", BETTERUI.FormatNumber(nil), "FormatNumber: nil returns '0'")
assert_equal("0", BETTERUI.FormatNumber(0), "FormatNumber: 0 returns '0'")
assert_equal("999", BETTERUI.FormatNumber(999, { case = "upper" }), "FormatNumber: <1000 upper-case keeps integer")
assert_equal("1.50K", BETTERUI.FormatNumber(1500, { case = "upper", style = "fixed", decimals = 2 }), "FormatNumber: fixed uppercase K suffix")
assert_equal("1.50k", BETTERUI.FormatNumber(1500, { case = "lower", style = "smart" }), "FormatNumber: smart lowercase K suffix")
assert_equal("15.0K", BETTERUI.FormatNumber(15000, { case = "upper", style = "smart" }), "FormatNumber: smart decimals shrink at larger values")
assert_equal("1.23M", BETTERUI.FormatNumber(1234567, { case = "upper", style = "fixed", decimals = 2 }), "FormatNumber: fixed uppercase M suffix")
assert_equal("2K", BETTERUI.FormatNumber(2000, { case = "upper", style = "fixed", decimals = 2 }), "FormatNumber: fixed exact K value drops decimals")
assert_equal("2M", BETTERUI.FormatNumber(2000000, { case = "upper", style = "fixed", decimals = 2 }), "FormatNumber: fixed exact M value drops decimals")
assert_equal("2B", BETTERUI.FormatNumber(2000000000, { case = "upper", style = "fixed", decimals = 2 }), "FormatNumber: fixed exact B value drops decimals")
assert_equal("-1.50k", BETTERUI.FormatNumber(-1500, { case = "lower", style = "fixed", decimals = 2 }), "FormatNumber: preserves negative sign")

-- ============================================================================
-- TEST CASES: Legacy wrappers
-- ============================================================================

print("\n=== Legacy Wrapper Tests ===\n")

assert_equal("1.50k", BETTERUI.AbbreviateNumber(1500), "AbbreviateNumber: legacy lowercase wrapper")
assert_equal("1.50K", BETTERUI.FormatAbbreviatedNumber(1500), "FormatAbbreviatedNumber: legacy uppercase wrapper")
assert_equal("0", BETTERUI.roundNumber(nil, 2), "roundNumber: nil input returns '0' string")
assert_equal("1.23", BETTERUI.roundNumber(1.239, 2), "roundNumber: floors to requested precision")
assert_equal("7", BETTERUI.roundNumber(7.9, 0), "roundNumber: honors zero decimals")
assert_equal("3", BETTERUI.roundNumber(3.7), "roundNumber: missing decimals defaults to 0")

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===\n")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    os.exit(1)
else
    print("All tests passed!")
    os.exit(0)
end
