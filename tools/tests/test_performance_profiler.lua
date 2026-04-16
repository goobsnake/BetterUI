--[[
File: tools/tests/test_performance_profiler.lua
Purpose: Unit tests for PerformanceProfiler utility.
         Loads production code via dofile.

Usage:
  lua tools/tests/test_performance_profiler.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }

-- Mock game time with incrementing milliseconds
local mockTime = 0
function GetGameTimeMilliseconds()
    return mockTime
end

local chatOutput = {}
function d(msg)
    table.insert(chatOutput, msg)
end

function BETTERUI.Debug(msg) end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Diagnostics/PerformanceProfiler.lua")

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

local function assert_nil(value, message)
    assert_equal(nil, value, message)
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
    BETTERUI.CIM.Profiler.Reset()
    BETTERUI.CIM.Profiler.Enable(false)
    mockTime = 0
    chatOutput = {}
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== PerformanceProfiler Tests ===\n")

-- Test 1: Profiler starts disabled
print("Test: Profiler starts disabled")
reset()
assert_false(BETTERUI.CIM.Profiler.IsEnabled(), "Profiler is disabled by default")

-- Test 2: Enable/Disable toggle
print("\nTest: Enable/Disable toggle")
reset()
BETTERUI.CIM.Profiler.Enable(true)
assert_true(BETTERUI.CIM.Profiler.IsEnabled(), "Profiler is enabled after Enable(true)")
BETTERUI.CIM.Profiler.Enable(false)
assert_false(BETTERUI.CIM.Profiler.IsEnabled(), "Profiler is disabled after Enable(false)")

-- Test 3: StartTiming/EndTiming records elapsed time
print("\nTest: StartTiming/EndTiming records elapsed time")
reset()
BETTERUI.CIM.Profiler.Enable(true)
mockTime = 100
BETTERUI.CIM.Profiler.StartTiming("testOp")
mockTime = 150
local elapsed = BETTERUI.CIM.Profiler.EndTiming("testOp")
assert_equal(50, elapsed, "Elapsed time is 50ms")

-- Test 4: Timing data accumulated correctly
print("\nTest: Timing data accumulated correctly")
local timings = BETTERUI.CIM.Profiler.GetTimings()
assert_not_nil(timings["testOp"], "testOp entry exists")
assert_equal(50, timings["testOp"].totalMs, "Total is 50ms")
assert_equal(1, timings["testOp"].count, "Count is 1")
assert_equal(50, timings["testOp"].minMs, "Min is 50ms")
assert_equal(50, timings["testOp"].maxMs, "Max is 50ms")

-- Test 5: Multiple timings accumulate
print("\nTest: Multiple timings accumulate")
mockTime = 200
BETTERUI.CIM.Profiler.StartTiming("testOp")
mockTime = 230
BETTERUI.CIM.Profiler.EndTiming("testOp")
local timings2 = BETTERUI.CIM.Profiler.GetTimings()
assert_equal(80, timings2["testOp"].totalMs, "Total is 80ms (50+30)")
assert_equal(2, timings2["testOp"].count, "Count is 2")
assert_equal(30, timings2["testOp"].minMs, "Min updated to 30ms")
assert_equal(50, timings2["testOp"].maxMs, "Max stays 50ms")

-- Test 6: StartTiming is no-op when disabled
print("\nTest: StartTiming is no-op when disabled")
reset()
BETTERUI.CIM.Profiler.StartTiming("disabled")
mockTime = 100
local result = BETTERUI.CIM.Profiler.EndTiming("disabled")
assert_nil(result, "EndTiming returns nil when disabled")

-- Test 7: EndTiming returns nil for unstarted timing
print("\nTest: EndTiming returns nil for unstarted timing")
reset()
BETTERUI.CIM.Profiler.Enable(true)
local result2 = BETTERUI.CIM.Profiler.EndTiming("never_started")
assert_nil(result2, "EndTiming returns nil for unstarted")

-- Test 8: Reset clears all data
print("\nTest: Reset clears all data")
reset()
BETTERUI.CIM.Profiler.Enable(true)
mockTime = 0
BETTERUI.CIM.Profiler.StartTiming("willBeReset")
mockTime = 10
BETTERUI.CIM.Profiler.EndTiming("willBeReset")
BETTERUI.CIM.Profiler.Reset()
local timings3 = BETTERUI.CIM.Profiler.GetTimings()
assert_nil(next(timings3), "Timings empty after reset")

-- Test 9: Enable(false) calls Reset
print("\nTest: Enable(false) calls Reset")
BETTERUI.CIM.Profiler.Enable(true)
mockTime = 0
BETTERUI.CIM.Profiler.StartTiming("willBeCleaned")
mockTime = 10
BETTERUI.CIM.Profiler.EndTiming("willBeCleaned")
BETTERUI.CIM.Profiler.Enable(false)
local timings4 = BETTERUI.CIM.Profiler.GetTimings()
assert_nil(next(timings4), "Timings empty after disable")

-- Test 10: Wrap creates a timing wrapper
print("\nTest: Wrap creates a timing wrapper")
reset()
BETTERUI.CIM.Profiler.Enable(true)
local innerCalled = false
local wrapped = BETTERUI.CIM.Profiler.Wrap("wrappedFn", function(a, b)
    innerCalled = true
    return a + b
end)
mockTime = 0
local wrapResult = wrapped(3, 7)
-- Note: both Start and End see same mockTime, so elapsed=0
assert_true(innerCalled, "Inner function was called")
assert_equal(10, wrapResult, "Wrapped function returns correct result")
local timings5 = BETTERUI.CIM.Profiler.GetTimings()
assert_not_nil(timings5["wrappedFn"], "Timing recorded for wrapped function")

-- Test 11: Report prints when enabled
print("\nTest: Report prints when enabled")
reset()
BETTERUI.CIM.Profiler.Enable(true)
mockTime = 0
BETTERUI.CIM.Profiler.StartTiming("reportTest")
mockTime = 25
BETTERUI.CIM.Profiler.EndTiming("reportTest")
chatOutput = {}
BETTERUI.CIM.Profiler.Report()
assert_true(#chatOutput > 0, "Report produced output")

-- Test 12: Report when disabled prints disabled message
print("\nTest: Report when disabled prints disabled message")
reset()
chatOutput = {}
BETTERUI.CIM.Profiler.Report()
assert_true(#chatOutput > 0, "Report produced output when disabled")
assert_true(chatOutput[1]:find("disabled") ~= nil, "Message mentions disabled")

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
