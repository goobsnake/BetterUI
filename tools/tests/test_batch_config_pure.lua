--[[
File: tools/tests/test_batch_config_pure.lua
Purpose: Unit tests for pure functions in CIM/Core/Data/BatchConfig.lua.
         Tests run standalone with a Lua interpreter (no ESO environment).
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = { CONST = { TIMING = {} } } }
function BETTERUI.Debug() end

function zo_max(a, b) return math.max(a, b) end
function zo_ceil(n) return math.ceil(n) end
function zo_floor(n) return math.floor(n) end
function zo_random(lo, hi) return math.random(lo, hi) end
function zo_strformat(fmt, ...) return string.format(tostring(fmt), ...) end

function GetString(s) return tostring(s or "") end

_G.SI_BETTERUI_BATCH_DURATION_SECONDS = "%ds"
_G.SI_BETTERUI_BATCH_DURATION_MINUTES_SECONDS = "%dm %ds"

-- ============================================================================
-- LOAD MODULE UNDER TEST (inline pure functions)
-- ============================================================================

BETTERUI.CIM.BatchConfig = {}
local BatchConfig = BETTERUI.CIM.BatchConfig

local DEFAULT_BATCH_THROTTLE_TIERS = {
    { MIN_ITEMS = 50, DELAY_MS = 125, SHOW_PROGRESS = true },
    { MIN_ITEMS = 10, DELAY_MS = 100, SHOW_PROGRESS = true },
    { MIN_ITEMS = 0,  DELAY_MS = 75,  SHOW_PROGRESS = false },
}

BatchConfig.BATCH_THROTTLE_TIERS = DEFAULT_BATCH_THROTTLE_TIERS
BatchConfig.DEFAULT_BATCH_THROTTLE_TIERS = DEFAULT_BATCH_THROTTLE_TIERS
BatchConfig.SERVER_BATCH_RECOVERY_STATE = { cooldownUntilMs = 0, serverActionTimes = {} }

function BatchConfig.ResolveBatchThrottleProfile(totalItems)
    for i = 1, #BatchConfig.BATCH_THROTTLE_TIERS do
        local tier = BatchConfig.BATCH_THROTTLE_TIERS[i]
        local minItems = tier.MIN_ITEMS or 0
        if totalItems >= minItems then
            return tier
        end
    end
    return BatchConfig.DEFAULT_BATCH_THROTTLE_TIERS[#BatchConfig.DEFAULT_BATCH_THROTTLE_TIERS]
end

function BatchConfig.ResolveBooleanOption(value, fallback)
    if value == nil then return fallback end
    return value == true
end

function BatchConfig.ResolvePositiveIntOption(value, fallback)
    local resolved = tonumber(value)
    if not resolved then return fallback end
    return zo_max(0, zo_ceil(resolved))
end

function BatchConfig.BuildSlotKey(bagId, slotIndex)
    return tostring(bagId) .. ":" .. tostring(slotIndex)
end

function BatchConfig.PruneServerActionHistory(nowMs, windowMs)
    local history = BatchConfig.SERVER_BATCH_RECOVERY_STATE.serverActionTimes
    if not history then
        history = {}
        BatchConfig.SERVER_BATCH_RECOVERY_STATE.serverActionTimes = history
    end
    local newest = history[#history]
    if newest and nowMs < newest then
        history = {}
        BatchConfig.SERVER_BATCH_RECOVERY_STATE.serverActionTimes = history
        return history
    end
    local cutoff = nowMs - windowMs
    while history[1] and history[1] <= cutoff do
        table.remove(history, 1)
    end
    return history
end

function BatchConfig.RecordServerAction(nowMs, windowMs)
    local history = BatchConfig.PruneServerActionHistory(nowMs, windowMs)
    history[#history + 1] = nowMs
end

function BatchConfig.ComputeServerActionDelayMs(nowMs, windowMs, maxActions)
    if windowMs <= 0 or maxActions <= 0 then return 0 end
    local history = BatchConfig.PruneServerActionHistory(nowMs, windowMs)
    if #history < maxActions then return 0 end
    local anchorIndex = #history - maxActions + 1
    local anchorTime = history[anchorIndex] or history[1]
    if not anchorTime then return 0 end
    return zo_max((anchorTime + windowMs) - nowMs, 0)
end

function BatchConfig.EstimateBatchDurationSeconds(totalItems, delayMs, cooldownEvery, cooldownMs,
                                                   totalCostUnits, chunkCostUnits, chunkPauseMs, initialDelayMs)
    local itemCount = zo_max(totalItems, 0)
    local estimateMs = itemCount * zo_max(delayMs or 0, 0)
    local cooldownUnits = zo_max(totalCostUnits or itemCount, 0)
    if itemCount > 1 and cooldownEvery and cooldownEvery > 0 and cooldownMs and cooldownMs > 0 then
        local cooldownCount = zo_floor(zo_max(cooldownUnits - 1, 0) / cooldownEvery)
        estimateMs = estimateMs + (cooldownCount * cooldownMs)
    end
    if itemCount > 1 and chunkCostUnits and chunkCostUnits > 0 and chunkPauseMs and chunkPauseMs > 0 then
        local chunkCount = zo_floor(zo_max(cooldownUnits - 1, 0) / chunkCostUnits)
        estimateMs = estimateMs + (chunkCount * chunkPauseMs)
    end
    estimateMs = estimateMs + zo_max(initialDelayMs or 0, 0)
    return estimateMs / 1000
end

function BatchConfig.FormatEstimatedBatchDuration(estimatedSeconds)
    local roundedSeconds = zo_max(1, zo_ceil(estimatedSeconds or 0))
    if roundedSeconds < 60 then
        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_DURATION_SECONDS")), roundedSeconds)
    end
    local minutes = zo_floor(roundedSeconds / 60)
    local seconds = roundedSeconds - (minutes * 60)
    return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_DURATION_MINUTES_SECONDS")), minutes, seconds)
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

-- ============================================================================
-- TESTS: ResolveBatchThrottleProfile
-- ============================================================================

print("\n=== ResolveBatchThrottleProfile Tests ===\n")

local tier = BatchConfig.ResolveBatchThrottleProfile(100)
assert_equal(125, tier.DELAY_MS, "100 items -> 125ms delay tier")
assert_true(tier.SHOW_PROGRESS, "100 items -> show progress")

tier = BatchConfig.ResolveBatchThrottleProfile(50)
assert_equal(125, tier.DELAY_MS, "50 items -> 125ms delay tier")

tier = BatchConfig.ResolveBatchThrottleProfile(25)
assert_equal(100, tier.DELAY_MS, "25 items -> 100ms delay tier")

tier = BatchConfig.ResolveBatchThrottleProfile(10)
assert_equal(100, tier.DELAY_MS, "10 items -> 100ms delay tier")

tier = BatchConfig.ResolveBatchThrottleProfile(5)
assert_equal(75, tier.DELAY_MS, "5 items -> 75ms delay tier")
assert_equal(false, tier.SHOW_PROGRESS, "5 items -> no progress")

tier = BatchConfig.ResolveBatchThrottleProfile(0)
assert_equal(75, tier.DELAY_MS, "0 items -> 75ms fallback tier")

-- ============================================================================
-- TESTS: ResolveBooleanOption
-- ============================================================================

print("\n=== ResolveBooleanOption Tests ===\n")

assert_equal(true, BatchConfig.ResolveBooleanOption(true, false), "true value overrides false fallback")
assert_equal(false, BatchConfig.ResolveBooleanOption(false, true), "false value overrides true fallback")
assert_equal(true, BatchConfig.ResolveBooleanOption(nil, true), "nil uses true fallback")
assert_equal(false, BatchConfig.ResolveBooleanOption(nil, false), "nil uses false fallback")
assert_equal(false, BatchConfig.ResolveBooleanOption("yes", true), "non-boolean resolves to false")
assert_equal(false, BatchConfig.ResolveBooleanOption(1, true), "number resolves to false")

-- ============================================================================
-- TESTS: ResolvePositiveIntOption
-- ============================================================================

print("\n=== ResolvePositiveIntOption Tests ===\n")

assert_equal(5, BatchConfig.ResolvePositiveIntOption(5, 10), "integer passes through")
assert_equal(4, BatchConfig.ResolvePositiveIntOption(3.5, 10), "fractional rounds up")
assert_equal(10, BatchConfig.ResolvePositiveIntOption(nil, 10), "nil uses fallback")
assert_equal(10, BatchConfig.ResolvePositiveIntOption("abc", 10), "non-numeric uses fallback")
assert_equal(42, BatchConfig.ResolvePositiveIntOption("42", 10), "numeric string converts")
assert_equal(0, BatchConfig.ResolvePositiveIntOption(-5, 10), "negative clamps to 0")

-- ============================================================================
-- TESTS: BuildSlotKey
-- ============================================================================

print("\n=== BuildSlotKey Tests ===\n")

assert_equal("1:5", BatchConfig.BuildSlotKey(1, 5), "basic key")
assert_equal("0:0", BatchConfig.BuildSlotKey(0, 0), "zero key")
assert_equal("255:63", BatchConfig.BuildSlotKey(255, 63), "large indices")

-- ============================================================================
-- TESTS: PruneServerActionHistory & ComputeServerActionDelayMs
-- ============================================================================

print("\n=== Server Action History Tests ===\n")

-- Reset state
BatchConfig.SERVER_BATCH_RECOVERY_STATE = { cooldownUntilMs = 0, serverActionTimes = {} }

BatchConfig.RecordServerAction(1000, 5000)
BatchConfig.RecordServerAction(2000, 5000)
BatchConfig.RecordServerAction(3000, 5000)
assert_equal(3, #BatchConfig.SERVER_BATCH_RECOVERY_STATE.serverActionTimes, "3 actions recorded")

-- No delay needed (under limit)
local delay = BatchConfig.ComputeServerActionDelayMs(3500, 5000, 5)
assert_equal(0, delay, "under limit -> no delay")

-- At limit
BatchConfig.RecordServerAction(4000, 5000)
BatchConfig.RecordServerAction(4500, 5000)
delay = BatchConfig.ComputeServerActionDelayMs(4600, 5000, 5)
assert_true(delay > 0, "at limit -> delay required")

-- Pruning old entries
BatchConfig.SERVER_BATCH_RECOVERY_STATE = { cooldownUntilMs = 0, serverActionTimes = {100, 200, 300} }
local history = BatchConfig.PruneServerActionHistory(6000, 5000)
assert_equal(0, #history, "old entries pruned")

-- Timer rollover detection
BatchConfig.SERVER_BATCH_RECOVERY_STATE = { cooldownUntilMs = 0, serverActionTimes = {10000, 20000} }
history = BatchConfig.PruneServerActionHistory(5000, 60000)
assert_equal(0, #history, "timer rollover resets history")

-- Edge case: zero/negative params
delay = BatchConfig.ComputeServerActionDelayMs(1000, 0, 5)
assert_equal(0, delay, "zero window -> no delay")
delay = BatchConfig.ComputeServerActionDelayMs(1000, 5000, 0)
assert_equal(0, delay, "zero max actions -> no delay")

-- ============================================================================
-- TESTS: EstimateBatchDurationSeconds
-- ============================================================================

print("\n=== EstimateBatchDurationSeconds Tests ===\n")

local dur = BatchConfig.EstimateBatchDurationSeconds(10, 100)
assert_equal(1.0, dur, "10 items * 100ms = 1s")

dur = BatchConfig.EstimateBatchDurationSeconds(0, 100)
assert_equal(0, dur, "0 items = 0s")

dur = BatchConfig.EstimateBatchDurationSeconds(1, 100)
assert_equal(0.1, dur, "1 item = 0.1s")

-- With cooldowns
dur = BatchConfig.EstimateBatchDurationSeconds(26, 100, 25, 1000)
assert_equal(3.6, dur, "26 items + 1 cooldown = 3.6s")

-- With initial delay
dur = BatchConfig.EstimateBatchDurationSeconds(10, 100, nil, nil, nil, nil, nil, 500)
assert_equal(1.5, dur, "10 items + 500ms initial = 1.5s")

-- ============================================================================
-- TESTS: FormatEstimatedBatchDuration
-- ============================================================================

print("\n=== FormatEstimatedBatchDuration Tests ===\n")

assert_equal("5s", BatchConfig.FormatEstimatedBatchDuration(5), "5 seconds")
assert_equal("1s", BatchConfig.FormatEstimatedBatchDuration(0.5), "rounds up to 1s")
assert_equal("59s", BatchConfig.FormatEstimatedBatchDuration(59), "59 seconds")
assert_equal("1m 0s", BatchConfig.FormatEstimatedBatchDuration(60), "60 seconds -> 1m 0s")
assert_equal("2m 30s", BatchConfig.FormatEstimatedBatchDuration(150), "150s -> 2m 30s")

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== SUMMARY ===")
print("  Passed: " .. tests_passed)
print("  Failed: " .. tests_failed)
print("")

if tests_failed > 0 then
    os.exit(1)
end
