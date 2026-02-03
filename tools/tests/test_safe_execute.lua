--[[
File: tools/tests/test_safe_execute.lua
Purpose: Unit tests for SafeExecute error boundary utility.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_safe_execute.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

-- Mock BETTERUI namespace
BETTERUI = { CIM = {} }

local debugOutput = {}
function BETTERUI.Debug(msg)
    table.insert(debugOutput, msg)
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

-- Inline SafeExecute implementation for standalone testing
function BETTERUI.CIM.SafeExecute(context, fn, ...)
    if not fn then
        BETTERUI.Debug(string.format("[Error] %s: No function provided", context))
        return false, "No function provided"
    end

    local args = { ... }
    local ok, result = pcall(function()
        return fn(unpack(args))
    end)

    if not ok then
        BETTERUI.Debug(string.format("[Error] %s: %s", context, tostring(result)))
    end

    return ok, result
end

function BETTERUI.CIM.SafeExecuteCallback(eventName, callback, ...)
    return BETTERUI.CIM.SafeExecute("Callback: " .. eventName, callback, ...)
end

-- Reset helper
local function reset()
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

print("\n=== SafeExecute Tests ===\n")

-- Test 1: Successful execution returns true and result
print("Test: Successful execution returns true and result")
reset()
local fn1 = function(a, b) return a + b end
local ok1, result1 = BETTERUI.CIM.SafeExecute("Addition", fn1, 2, 3)
assert_true(ok1, "SafeExecute returns true on success")
assert_equal(5, result1, "Result is correct (2 + 3 = 5)")
assert_equal(0, #debugOutput, "No error logged")

-- Test 2: Error in function is caught
print("\nTest: Error in function is caught")
reset()
local fn2 = function() error("Test error") end
local ok2, result2 = BETTERUI.CIM.SafeExecute("FailingFunc", fn2)
assert_false(ok2, "SafeExecute returns false on error")
assert_equal(1, #debugOutput, "Error was logged")

-- Test 3: Nil function handled gracefully
print("\nTest: Nil function handled gracefully")
reset()
local ok3, result3 = BETTERUI.CIM.SafeExecute("NilTest", nil)
assert_false(ok3, "SafeExecute returns false for nil function")
assert_equal("No function provided", result3, "Correct error message")
assert_equal(1, #debugOutput, "Error was logged")

-- Test 4: Arguments are passed through
print("\nTest: Arguments are passed through")
reset()
local received = {}
local fn4 = function(a, b, c)
    received = { a, b, c }
    return "ok"
end
local ok4 = BETTERUI.CIM.SafeExecute("ArgTest", fn4, "x", "y", "z")
assert_true(ok4, "Execution succeeded")
assert_equal("x", received[1], "First arg passed")
assert_equal("y", received[2], "Second arg passed")
assert_equal("z", received[3], "Third arg passed")

-- Test 5: SafeExecuteCallback adds event prefix
print("\nTest: SafeExecuteCallback adds event prefix")
reset()
local fn5 = function() error("Event error") end
BETTERUI.CIM.SafeExecuteCallback("EVENT_TEST", fn5)
assert_equal(1, #debugOutput, "Error was logged")
local hasPrefix = debugOutput[1]:find("Callback: EVENT_TEST")
assert_true(hasPrefix ~= nil, "Log contains callback prefix")

-- Test 6: Function returning nil still succeeds
print("\nTest: Function returning nil still succeeds")
reset()
local fn6 = function() return nil end
local ok6, result6 = BETTERUI.CIM.SafeExecute("NilReturn", fn6)
assert_true(ok6, "SafeExecute returns true")
assert_equal(nil, result6, "Result is nil as expected")

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
