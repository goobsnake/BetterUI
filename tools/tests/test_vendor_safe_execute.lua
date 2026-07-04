--[[
File: tools/tests/test_vendor_safe_execute.lua
Purpose: Unit tests for the shared vendor safe-execution helper. BUI-CONS-004
         collapsed Vendor.ExecuteSafely to a thin delegator over
         BETTERUI.CIM.SafeExecute (which is defined unconditionally in
         production), so these tests pin the delegation contract.
Usage:
  lua tools/tests/test_vendor_safe_execute.lua
]]

BETTERUI = {
    Vendor = {},
    CIM = {},
}

local safeExecuteCalls = {}

local passed = 0
local failed = 0

local function assert_equal(expected, actual, label)
    if expected == actual then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_equal(true, value == true, label)
end

-- Production CIM.SafeExecute contract: (ok, result-or-error). Record calls so we
-- can assert the delegator forwards context/fn/args verbatim.
BETTERUI.CIM.SafeExecute = function(context, fn, ...)
    safeExecuteCalls[#safeExecuteCalls + 1] = { context = context, argc = select("#", ...) }
    if type(fn) ~= "function" then
        return false, "No function provided"
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        return false, result
    end
    return true, result
end

dofile("Modules/Vendor/Core/VendorSafeExecute.lua")

-- Delegates a successful call and preserves the returned results + context/args.
local okProxy, resultProxy = BETTERUI.Vendor.ExecuteSafely("Vendor.SafeExecute:Proxy", function(a, b)
    return a + b
end, 2, 3)
assert_true(okProxy, "Vendor.ExecuteSafely delegates through BETTERUI.CIM.SafeExecute")
assert_equal(5, resultProxy, "Vendor.ExecuteSafely preserves delegated results")
assert_equal(1, #safeExecuteCalls, "Vendor.ExecuteSafely calls the CIM safe executor once")
assert_equal("Vendor.SafeExecute:Proxy", safeExecuteCalls[1].context, "Vendor.ExecuteSafely preserves the delegated context")
assert_equal(2, safeExecuteCalls[1].argc, "Vendor.ExecuteSafely forwards trailing arguments to the CIM executor")

-- Delegates error handling to CIM.SafeExecute (returns false + error text).
local okError, resultError = BETTERUI.Vendor.ExecuteSafely("Vendor.SafeExecute:Error", function()
    error("boom")
end)
assert_equal(false, okError, "Vendor.ExecuteSafely returns false when the delegated call fails")
assert_true(type(resultError) == "string", "Vendor.ExecuteSafely returns the delegated error text")

-- Delegates the missing-callback case to CIM.SafeExecute.
local okMissing, resultMissing = BETTERUI.Vendor.ExecuteSafely("Vendor.SafeExecute:Missing", nil)
assert_equal(false, okMissing, "Vendor.ExecuteSafely rejects nil functions via the CIM executor")
assert_equal("No function provided", resultMissing, "Vendor.ExecuteSafely preserves the missing-callback reason")

if failed > 0 then
    error(string.format("test_vendor_safe_execute.lua failed with %d failure(s)", failed))
end

print(string.format("test_vendor_safe_execute.lua: %d passed", passed))
