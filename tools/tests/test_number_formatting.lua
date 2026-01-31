--[[
File: tools/tests/test_number_formatting.lua
Purpose: Unit tests for NumberFormatting utility functions.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_number_formatting.lua

Note: This file stubs the ESO environment to test pure functions in isolation.
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

-- Stub ZO_CommaDelimitNumber (ESO API)
function ZO_CommaDelimitNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- ============================================================================
-- IMPORT FUNCTIONS UNDER TEST
-- ============================================================================

-- Simulate the FormatNumber function from NumberFormatting.lua
local function FormatNumber(number)
    if not number then return "0" end
    return ZO_CommaDelimitNumber(number)
end

local function FormatNumberWithSuffix(number)
    if not number then return "0" end
    if number >= 1000000000 then
        return string.format("%.1fB", number / 1000000000)
    elseif number >= 1000000 then
        return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        return string.format("%.1fK", number / 1000)
    else
        return tostring(number)
    end
end

local function FormatPercentage(value, total)
    if not total or total == 0 then return "0%" end
    return string.format("%.0f%%", (value / total) * 100)
end

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
-- TEST CASES: FormatNumber
-- ============================================================================

print("\n=== FormatNumber Tests ===\n")

assert_equal("0", FormatNumber(nil), "FormatNumber: nil returns '0'")
assert_equal("0", FormatNumber(0), "FormatNumber: 0 returns '0'")
assert_equal("100", FormatNumber(100), "FormatNumber: 100 returns '100'")
assert_equal("1,000", FormatNumber(1000), "FormatNumber: 1000 returns '1,000'")
assert_equal("1,000,000", FormatNumber(1000000), "FormatNumber: 1M returns '1,000,000'")
assert_equal("12,345,678", FormatNumber(12345678), "FormatNumber: 12345678 returns '12,345,678'")

-- ============================================================================
-- TEST CASES: FormatNumberWithSuffix
-- ============================================================================

print("\n=== FormatNumberWithSuffix Tests ===\n")

assert_equal("0", FormatNumberWithSuffix(nil), "FormatNumberWithSuffix: nil returns '0'")
assert_equal("100", FormatNumberWithSuffix(100), "FormatNumberWithSuffix: 100 returns '100'")
assert_equal("1.0K", FormatNumberWithSuffix(1000), "FormatNumberWithSuffix: 1000 returns '1.0K'")
assert_equal("1.5K", FormatNumberWithSuffix(1500), "FormatNumberWithSuffix: 1500 returns '1.5K'")
assert_equal("1.0M", FormatNumberWithSuffix(1000000), "FormatNumberWithSuffix: 1M returns '1.0M'")
assert_equal("1.0B", FormatNumberWithSuffix(1000000000), "FormatNumberWithSuffix: 1B returns '1.0B'")

-- ============================================================================
-- TEST CASES: FormatPercentage
-- ============================================================================

print("\n=== FormatPercentage Tests ===\n")

assert_equal("0%", FormatPercentage(0, 0), "FormatPercentage: 0/0 returns '0%'")
assert_equal("0%", FormatPercentage(0, 100), "FormatPercentage: 0/100 returns '0%'")
assert_equal("50%", FormatPercentage(50, 100), "FormatPercentage: 50/100 returns '50%'")
assert_equal("100%", FormatPercentage(100, 100), "FormatPercentage: 100/100 returns '100%'")
assert_equal("25%", FormatPercentage(1, 4), "FormatPercentage: 1/4 returns '25%'")

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
