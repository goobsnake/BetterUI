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

-- Stub: string.gmatch pattern used by TryCall (available in standard Lua)

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

-- Load the production SafeExecute module directly so tests break if the
-- implementation drifts. DebugInfo is optional in production but loaded here so
-- non-string errors can fall back to the SafeExecute call boundary.
dofile("Modules/CIM/Core/Diagnostics/DebugInfo.lua")
dofile("Modules/CIM/Core/Diagnostics/SafeExecute.lua")

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

-- Test 6: Function returning nil still succeeds
print("\nTest: Function returning nil still succeeds")
reset()
local fn6 = function() return nil end
local ok6, result6 = BETTERUI.CIM.SafeExecute("NilReturn", fn6)
assert_true(ok6, "SafeExecute returns true")
assert_equal(nil, result6, "Result is nil as expected")

-- Test 7: SafeCall is no longer exposed publicly
print("\nTest: SafeCall is no longer exposed publicly")
reset()
assert_equal(nil, BETTERUI.CIM.SafeCall, "SafeCall is not exported on BETTERUI.CIM")

-- Test 8: with the unified logger present, caught errors route to Log.Error at the SAFE
-- category and carry a boundary src (file:line) lifted from the error message.
print("\nTest: caught error routes to Log.Error with a boundary src")
reset()
local logErrors = {}
BETTERUI.Log = {
    CATEGORY = { SAFE = "SAFE" },
    Error = function(cat, msg, data) logErrors[#logErrors + 1] = { cat = cat, msg = msg, data = data } end,
}
local fn8 = function() error("boom8") end
local ok8 = BETTERUI.CIM.SafeExecute("Ctx8", fn8)
assert_false(ok8, "SafeExecute returns false on error (logger present)")
assert_equal(1, #logErrors, "caught error routed to Log.Error")
assert_equal("SAFE", logErrors[1].cat, "logged at the SAFE category")
assert_true(logErrors[1].msg:find("Ctx8", 1, true) ~= nil and logErrors[1].msg:find("boom8", 1, true) ~= nil,
    "message carries context + caught error")
assert_true(logErrors[1].data ~= nil and type(logErrors[1].data.src) == "string"
    and logErrors[1].data.src:find("%.lua:%d") ~= nil,
    "boundary src (file:line) lifted from the error message")
BETTERUI.Log = nil

-- Test 9: src parse robustness -- error(table) falls back to a SafeExecute boundary src;
-- a backslash (Windows) repo path normalizes to a repo-relative forward-slash src.
print("\nTest: boundary src parse handles error(table) + backslash paths")
reset()
local logErrors2 = {}
BETTERUI.Log = {
    CATEGORY = { SAFE = "SAFE" },
    Error = function(cat, msg, data) logErrors2[#logErrors2 + 1] = { cat = cat, msg = msg, data = data } end,
}
local okT = BETTERUI.CIM.SafeExecute("CtxT", function() error({ code = 1 }) end)
assert_false(okT, "error(table) returns false")
assert_true(logErrors2[#logErrors2].data ~= nil and type(logErrors2[#logErrors2].data.src) == "string"
    and logErrors2[#logErrors2].data.src:find("test_safe_execute%.lua:%d") ~= nil,
    "error(table) falls back to the SafeExecute boundary src, never raises")
local okB = BETTERUI.CIM.SafeExecute("CtxB", function()
    error("user:\\AddOns\\BetterUI\\Modules\\Foo.lua:5: boom", 0)
end)
assert_false(okB, "backslash-path error returns false")
assert_equal("Modules/Foo.lua:5", logErrors2[#logErrors2].data and logErrors2[#logErrors2].data.src,
    "backslash repo path normalized to repo-relative src")
BETTERUI.Log = nil

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
