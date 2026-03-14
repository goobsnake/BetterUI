--[[
File: tools/tests/test_batch_safety.lua
Purpose: Unit tests for batch processing safety mechanisms:
         - Re-entry guard (prevents concurrent batch pipelines)
         - Pipeline token invalidation (rejects stale timer callbacks)
         - Adaptive backoff (delay increases on consecutive queued actions)
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_batch_safety.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = { Debug = {} } }

local debugOutput = {}
function BETTERUI.Debug(msg) table.insert(debugOutput, msg) end
function BETTERUI.CIM.Debug.Log(msg, cat) table.insert(debugOutput, (cat and ("["..cat.."] ") or "") .. msg) end
function BETTERUI.CIM.Debug.IsEnabled() return true end

-- Minimal zo_* math stubs
function zo_max(a, b) return math.max(a or 0, b or 0) end
function zo_min(a, b) return math.min(a or 0, b or 0) end
function zo_ceil(x) return math.ceil(x or 0) end
function zo_clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function zo_floor(x) return math.floor(x or 0) end

-- ============================================================================
-- EXTRACTED LOGIC UNDER TEST
-- ============================================================================

-- Re-entry guard: simulates the guard in ProcessBatchThrottled
local function TestReentryGuard(instance)
    if instance.isBatchProcessing then
        BETTERUI.CIM.Debug.Log("Batch re-entry rejected: pipeline already active", "Batch")
        return false
    end
    instance.isBatchProcessing = true
    return true
end

-- Pipeline token: simulates token generation and stale check
local function GeneratePipelineToken(instance)
    instance.batchPipelineToken = (instance.batchPipelineToken or 0) + 1
    return instance.batchPipelineToken
end

local function IsPipelineTokenValid(instance, token)
    return token == instance.batchPipelineToken
end

-- Adaptive backoff: simulates delay calculation from BatchConfig logic
local function ComputeAdaptiveDelay(baseDelayMs, consecutiveQueued, adaptiveThreshold, adaptiveStepMs, minDelayMs, maxDelayMs)
    local delay = baseDelayMs
    local over = zo_max(consecutiveQueued - adaptiveThreshold, 0)
    if over > 0 then
        delay = zo_min(maxDelayMs, delay + zo_min(over * adaptiveStepMs, maxDelayMs - minDelayMs))
    end
    return delay
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

local function assert_true(value, message) assert_equal(true, value, message) end
local function assert_false(value, message) assert_equal(false, value, message) end

local function reset()
    debugOutput = {}
end

-- ============================================================================
-- TEST: RE-ENTRY GUARD
-- ============================================================================

print("\n=== Batch Re-Entry Guard Tests ===\n")

-- Test 1: First batch starts successfully
print("Test: First batch starts successfully")
reset()
local instance = { isBatchProcessing = false }
local ok = TestReentryGuard(instance)
assert_true(ok, "First batch should start")
assert_true(instance.isBatchProcessing, "isBatchProcessing flag is set")
assert_equal(0, #debugOutput, "No rejection logged")

-- Test 2: Re-entry is rejected when batch is active
print("\nTest: Re-entry is rejected when batch is active")
reset()
local ok2 = TestReentryGuard(instance)
assert_false(ok2, "Re-entry should be rejected")
assert_equal(1, #debugOutput, "Rejection message was logged")
assert_true(debugOutput[1]:find("re%-entry rejected") ~= nil, "Log message mentions re-entry")

-- Test 3: After batch completes, new batch can start
print("\nTest: After batch completes, new batch can start")
reset()
instance.isBatchProcessing = false
local ok3 = TestReentryGuard(instance)
assert_true(ok3, "New batch should start after previous completes")

-- ============================================================================
-- TEST: PIPELINE TOKEN INVALIDATION
-- ============================================================================

print("\n=== Pipeline Token Tests ===\n")

-- Test 4: Token increments on each batch
print("Test: Token increments on each batch")
reset()
local inst2 = {}
local token1 = GeneratePipelineToken(inst2)
local token2 = GeneratePipelineToken(inst2)
assert_equal(1, token1, "First token is 1")
assert_equal(2, token2, "Second token is 2")

-- Test 5: Current token is valid
print("\nTest: Current token is valid")
assert_true(IsPipelineTokenValid(inst2, token2), "Current token should be valid")

-- Test 6: Stale token is invalid
print("\nTest: Stale token is invalid")
assert_false(IsPipelineTokenValid(inst2, token1), "Old token should be invalid")

-- Test 7: Token after third generation invalidates second
print("\nTest: Token after third generation invalidates second")
local token3 = GeneratePipelineToken(inst2)
assert_false(IsPipelineTokenValid(inst2, token2), "Previous token should be invalid now")
assert_true(IsPipelineTokenValid(inst2, token3), "Latest token should be valid")

-- ============================================================================
-- TEST: ADAPTIVE BACKOFF
-- ============================================================================

print("\n=== Adaptive Backoff Tests ===\n")

local BASE_DELAY = 100
local THRESHOLD = 3
local STEP_MS = 25
local MIN_DELAY = 100
local MAX_DELAY = 500

-- Test 8: No backoff when below threshold
print("Test: No backoff when below threshold")
local delay = ComputeAdaptiveDelay(BASE_DELAY, 2, THRESHOLD, STEP_MS, MIN_DELAY, MAX_DELAY)
assert_equal(BASE_DELAY, delay, "Delay should equal base when consecutive < threshold")

-- Test 9: No backoff at exactly the threshold
print("\nTest: No backoff at exactly the threshold")
delay = ComputeAdaptiveDelay(BASE_DELAY, THRESHOLD, THRESHOLD, STEP_MS, MIN_DELAY, MAX_DELAY)
assert_equal(BASE_DELAY, delay, "Delay should equal base at exactly threshold")

-- Test 10: Backoff starts one past threshold
print("\nTest: Backoff starts one past threshold")
delay = ComputeAdaptiveDelay(BASE_DELAY, THRESHOLD + 1, THRESHOLD, STEP_MS, MIN_DELAY, MAX_DELAY)
assert_equal(BASE_DELAY + STEP_MS, delay, "Delay should increase by one step")

-- Test 11: Backoff scales with consecutiveQueued
print("\nTest: Backoff scales with consecutive count")
delay = ComputeAdaptiveDelay(BASE_DELAY, THRESHOLD + 4, THRESHOLD, STEP_MS, MIN_DELAY, MAX_DELAY)
assert_equal(BASE_DELAY + 4 * STEP_MS, delay, "Delay should increase by 4 steps (200ms)")

-- Test 12: Backoff is capped at max delay
print("\nTest: Backoff is capped at max delay")
delay = ComputeAdaptiveDelay(BASE_DELAY, THRESHOLD + 100, THRESHOLD, STEP_MS, MIN_DELAY, MAX_DELAY)
assert_equal(MAX_DELAY, delay, "Delay should be capped at max")

-- Test 13: Zero threshold means backoff starts at 1
print("\nTest: Zero threshold means backoff starts immediately")
delay = ComputeAdaptiveDelay(BASE_DELAY, 1, 0, STEP_MS, MIN_DELAY, MAX_DELAY)
assert_equal(BASE_DELAY + STEP_MS, delay, "Delay should increase at count=1 with threshold=0")

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
