--[[
File: tools/tests/test_hook_factory.lua
Purpose: Unit tests for HookFactory (PreHook, PostHook).
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_hook_factory.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = {}

function ZO_PreHook(control, methodName, callback)
    local original = control[methodName]
    control[methodName] = function(self, ...)
        if callback(self, ...) then
            return
        end
        return original(self, ...)
    end
end

function ZO_PostHook(control, methodName, callback)
    local original = control[methodName]
    control[methodName] = function(self, ...)
        local results = { original(self, ...) }
        callback(self, ...)
        local unpack_fn = table.unpack or unpack
        return unpack_fn(results)
    end
end

function SecurePostHook(control, methodName, callback)
    return ZO_PostHook(control, methodName, callback)
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Integration/HookFactory.lua")

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

print("\n=== HookFactory Tests ===\n")

-- Test 1: PreHook executes before original
print("Test: PreHook executes before original")
local order1 = {}
local ctrl1 = {}
ctrl1.DoWork = function(self) table.insert(order1, "original") end
BETTERUI.PreHook(ctrl1, "DoWork", function(self)
    table.insert(order1, "pre")
end)
ctrl1:DoWork()
assert_equal("pre", order1[1], "Pre-hook runs first")
assert_equal("original", order1[2], "Original runs second")

-- Test 2: PreHook returning true aborts original
print("\nTest: PreHook returning true aborts original")
local order2 = {}
local ctrl2 = {}
ctrl2.DoWork = function(self) table.insert(order2, "original") end
BETTERUI.PreHook(ctrl2, "DoWork", function(self)
    table.insert(order2, "pre")
    return true -- abort
end)
ctrl2:DoWork()
assert_equal(1, #order2, "Only pre-hook ran")
assert_equal("pre", order2[1], "Pre-hook executed")

-- Test 3: PreHook returning false does NOT abort
print("\nTest: PreHook returning false does NOT abort")
local order3 = {}
local ctrl3 = {}
ctrl3.DoWork = function(self) table.insert(order3, "original") end
BETTERUI.PreHook(ctrl3, "DoWork", function(self)
    table.insert(order3, "pre")
    return false
end)
ctrl3:DoWork()
assert_equal(2, #order3, "Both functions ran")

-- Test 4: PreHook returning nil does NOT abort
print("\nTest: PreHook returning nil does NOT abort")
local order4 = {}
local ctrl4 = {}
ctrl4.DoWork = function(self) table.insert(order4, "original") end
BETTERUI.PreHook(ctrl4, "DoWork", function(self)
    table.insert(order4, "pre")
    -- no return (nil)
end)
ctrl4:DoWork()
assert_equal(2, #order4, "Both functions ran with nil return")

-- Test 5: PostHook executes after original
print("\nTest: PostHook executes after original")
local order5 = {}
local ctrl5 = {}
ctrl5.DoWork = function(self) table.insert(order5, "original") end
BETTERUI.PostHook(ctrl5, "DoWork", function(self)
    table.insert(order5, "post")
end)
ctrl5:DoWork()
assert_equal("original", order5[1], "Original runs first")
assert_equal("post", order5[2], "Post-hook runs second")

-- Test 6: Arguments are forwarded through PreHook
print("\nTest: Arguments forwarded through PreHook")
local received7 = {}
local ctrl7 = {}
ctrl7.Process = function(self, a, b) received7.original = {a, b} end
BETTERUI.PreHook(ctrl7, "Process", function(self, a, b)
    received7.pre = {a, b}
end)
ctrl7:Process("x", "y")
assert_equal("x", received7.pre[1], "Pre-hook got arg1")
assert_equal("y", received7.pre[2], "Pre-hook got arg2")
assert_equal("x", received7.original[1], "Original got arg1")
assert_equal("y", received7.original[2], "Original got arg2")

-- Test 8: Arguments are forwarded through PostHook
print("\nTest: Arguments forwarded through PostHook")
local received8 = {}
local ctrl8 = {}
ctrl8.Process = function(self, a, b) received8.original = {a, b} end
BETTERUI.PostHook(ctrl8, "Process", function(self, a, b)
    received8.post = {a, b}
end)
ctrl8:Process("a", "b")
assert_equal("a", received8.post[1], "Post-hook got arg1")
assert_equal("b", received8.post[2], "Post-hook got arg2")

-- Test 9: Nil control is handled gracefully
print("\nTest: Nil control handled gracefully")
-- Should not error
BETTERUI.PreHook(nil, "DoWork", function() end)
BETTERUI.PostHook(nil, "DoWork", function() end)
tests_passed = tests_passed + 1
print("  [OK] No error on nil control")

-- Test 10: PreHook returns original's return value
print("\nTest: PreHook preserves original return value")
local ctrl10 = {}
ctrl10.GetValue = function(self) return 42 end
BETTERUI.PreHook(ctrl10, "GetValue", function(self) end)
local result10 = ctrl10:GetValue()
assert_equal(42, result10, "Original return value preserved")

-- Test 11: Multiple hooks can be chained
print("\nTest: Multiple PreHooks chain correctly")
local order11 = {}
local ctrl11 = {}
ctrl11.DoWork = function(self) table.insert(order11, "original") end
BETTERUI.PreHook(ctrl11, "DoWork", function(self) table.insert(order11, "hook1") end)
BETTERUI.PreHook(ctrl11, "DoWork", function(self) table.insert(order11, "hook2") end)
ctrl11:DoWork()
-- hook2 wraps hook1-wrapping-original: hook2 → hook1 → original
assert_equal("hook2", order11[1], "Outer hook runs first")
assert_equal("hook1", order11[2], "Inner hook runs second")
assert_equal("original", order11[3], "Original runs last")

-- Test 12: ReplaceHook API removed from HookFactory source
print("\nTest: ReplaceHook API removed")
local fh = assert(io.open("Modules/CIM/Core/Integration/HookFactory.lua", "r"))
local hookFactorySource = fh:read("*a")
fh:close()
assert_true(hookFactorySource:find("ReplaceHook") == nil,
    "ReplaceHook symbol not present")
assert_true(hookFactorySource:find("position == \"replace\"") == nil,
    "Replace branch removed from hook position switch")

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
