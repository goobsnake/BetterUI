--[[
File: tools/tests/test_vendor_safe_execute.lua
Purpose: Unit tests for the shared vendor safe-execution helper so the
         centralized fallback/notifier behavior stays stable.
Usage:
  lua tools/tests/test_vendor_safe_execute.lua
]]

BETTERUI = {
    Vendor = {},
    CIM = {},
}

local notified = {}
local safeExecuteCalls = {}

local function reset()
    notified = {}
    safeExecuteCalls = {}
    BETTERUI.CIM.SafeExecute = nil
end

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

BETTERUI.CIM.UserNotify = function(context, message)
    notified[#notified + 1] = { context = context, message = message }
end

dofile("Modules/Vendor/Core/VendorSafeExecute.lua")

reset()
BETTERUI.CIM.SafeExecute = function(context, fn, ...)
    safeExecuteCalls[#safeExecuteCalls + 1] = context
    return true, fn(...)
end
local okProxy, resultProxy = BETTERUI.Vendor.ExecuteSafely("Vendor.SafeExecute:Proxy", function(a, b)
    return a + b
end, 2, 3)
assert_true(okProxy, "Vendor.ExecuteSafely delegates through BETTERUI.CIM.SafeExecute when available")
assert_equal(5, resultProxy, "Vendor.ExecuteSafely preserves delegated results")
assert_equal(1, #safeExecuteCalls, "Vendor.ExecuteSafely calls the CIM safe executor once")
assert_equal("Vendor.SafeExecute:Proxy", safeExecuteCalls[1], "Vendor.ExecuteSafely preserves the delegated context")
assert_equal(0, #notified, "Vendor.ExecuteSafely does not notify on delegated success")

reset()
local okFallback, resultFallback = BETTERUI.Vendor.ExecuteSafely("Vendor.SafeExecute:Fallback", function()
    return "ok"
end)
assert_true(okFallback, "Vendor.ExecuteSafely succeeds through direct fallback execution")
assert_equal("ok", resultFallback, "Vendor.ExecuteSafely returns fallback results")
assert_equal(0, #notified, "Vendor.ExecuteSafely does not notify on fallback success")

reset()
local okError, resultError = BETTERUI.Vendor.ExecuteSafely("Vendor.SafeExecute:Error", function()
    error("boom")
end)
assert_equal(false, okError, "Vendor.ExecuteSafely returns false on fallback failure")
assert_true(type(resultError) == "string", "Vendor.ExecuteSafely returns the Lua error text on fallback failure")
assert_equal(1, #notified, "Vendor.ExecuteSafely notifies exactly once on fallback failure")
assert_equal("Vendor.SafeExecute:Error", notified[1].context, "Vendor.ExecuteSafely reports the failing context")

reset()
local okMissing, resultMissing = BETTERUI.Vendor.ExecuteSafely("Vendor.SafeExecute:Missing", nil)
assert_equal(false, okMissing, "Vendor.ExecuteSafely rejects nil functions")
assert_equal(nil, resultMissing, "Vendor.ExecuteSafely returns nil for missing functions")
assert_equal(0, #notified, "Vendor.ExecuteSafely does not notify for missing functions")

if failed > 0 then
    error(string.format("test_vendor_safe_execute.lua failed with %d failure(s)", failed))
end

print(string.format("test_vendor_safe_execute.lua: %d passed", passed))
