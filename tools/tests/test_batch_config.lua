--[[
File: tools/tests/test_batch_config.lua
Purpose: Unit tests for CIM BatchConfig pacing configuration and utilities.
         Validates throttle tier resolution, rate limiting, slot key generation,
         duration estimation, and server action history management.

Usage:
  lua tools/tests/test_batch_config.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = { CONST = { TIMING = {} } } }

function zo_max(a, b) return math.max(a, b) end
function zo_ceil(x) return math.ceil(x) end
function zo_floor(x) return math.floor(x) end
function zo_random(a, b) return math.random(a, b) end
function GetSlotStackSize(bagId, slotIndex)
    -- Return different values based on slot to simulate inventory
    if slotIndex == 0 then return 5 end
    if slotIndex == 1 then return 10 end
    return 0 -- empty slot
end
function GetString(key) return key or "" end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Data/BatchConfig.lua")

local BC = BETTERUI.CIM.BatchConfig

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
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
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

print("\n=== BatchConfig Tests ===\n")

-- ResolveBatchThrottleProfile
print("-- ResolveBatchThrottleProfile --")
do
    local tier = BC.ResolveBatchThrottleProfile(100)
    assert_equal(125, tier.DELAY_MS, "ThrottleProfile: 100 items gets 125ms tier")
    assert_true(tier.SHOW_PROGRESS, "ThrottleProfile: 100 items shows progress")

    tier = BC.ResolveBatchThrottleProfile(25)
    assert_equal(100, tier.DELAY_MS, "ThrottleProfile: 25 items gets 100ms tier")

    tier = BC.ResolveBatchThrottleProfile(5)
    assert_equal(75, tier.DELAY_MS, "ThrottleProfile: 5 items gets 75ms tier")
    assert_false(tier.SHOW_PROGRESS, "ThrottleProfile: 5 items no progress")

    tier = BC.ResolveBatchThrottleProfile(0)
    assert_equal(75, tier.DELAY_MS, "ThrottleProfile: 0 items gets lowest tier")
end

-- ResolveBooleanOption
print("\n-- ResolveBooleanOption --")
do
    assert_true(BC.ResolveBooleanOption(nil, true), "BooleanOption: nil returns fallback true")
    assert_false(BC.ResolveBooleanOption(nil, false), "BooleanOption: nil returns fallback false")
    assert_true(BC.ResolveBooleanOption(true, false), "BooleanOption: true overrides false fallback")
    assert_false(BC.ResolveBooleanOption(false, true), "BooleanOption: false overrides true fallback")
    assert_false(BC.ResolveBooleanOption("string", true), "BooleanOption: non-bool returns false")
end

-- ResolvePositiveIntOption
print("\n-- ResolvePositiveIntOption --")
do
    assert_equal(42, BC.ResolvePositiveIntOption(42, 10), "PositiveInt: valid number returns it")
    assert_equal(10, BC.ResolvePositiveIntOption(nil, 10), "PositiveInt: nil returns fallback")
    assert_equal(10, BC.ResolvePositiveIntOption("abc", 10), "PositiveInt: non-numeric returns fallback")
    assert_equal(0, BC.ResolvePositiveIntOption(-5, 10), "PositiveInt: negative clamped to 0")
    assert_equal(5, BC.ResolvePositiveIntOption("5", 10), "PositiveInt: string number parsed")
end

-- ResolveSignedJitter
print("\n-- ResolveSignedJitter --")
do
    assert_equal(0, BC.ResolveSignedJitter(0), "SignedJitter: 0 max returns 0")
    assert_equal(0, BC.ResolveSignedJitter(-1), "SignedJitter: negative max returns 0")

    -- For positive max, result should be in range
    local result = BC.ResolveSignedJitter(10)
    assert_true(result >= -10 and result <= 10, "SignedJitter: result in range [-10, 10]")
end

-- BuildSlotKey
print("\n-- BuildSlotKey --")
do
    assert_equal("1:5", BC.BuildSlotKey(1, 5), "BuildSlotKey: bag 1 slot 5")
    assert_equal("0:0", BC.BuildSlotKey(0, 0), "BuildSlotKey: bag 0 slot 0")
end

-- HasItemAtSlot
print("\n-- HasItemAtSlot --")
do
    assert_true(BC.HasItemAtSlot(1, 0), "HasItemAtSlot: slot 0 has items (5)")
    assert_true(BC.HasItemAtSlot(1, 1), "HasItemAtSlot: slot 1 has items (10)")
    assert_false(BC.HasItemAtSlot(1, 99), "HasItemAtSlot: slot 99 is empty (0)")
end

-- NormalizeBatchItems
print("\n-- NormalizeBatchItems --")
do
    local items = {
        { bagId = 1, slotIndex = 0 },
        { bagId = 1, slotIndex = 0 },  -- duplicate
        { bagId = 1, slotIndex = 1 },
        { bagId = 1, slotIndex = 99 }, -- empty slot
    }
    local result = BC.NormalizeBatchItems(items)
    assert_equal(2, #result, "NormalizeBatchItems: deduplicates and filters empty")

    -- With dataSource wrapper
    local wrappedItems = {
        { dataSource = { bagId = 1, slotIndex = 0 } },
        { dataSource = { bagId = 1, slotIndex = 1 } },
    }
    result = BC.NormalizeBatchItems(wrappedItems)
    assert_equal(2, #result, "NormalizeBatchItems: handles dataSource wrapper")
end

-- EstimateBatchDurationSeconds
print("\n-- EstimateBatchDurationSeconds --")
do
    -- Simple: 10 items at 100ms each = 1.0 seconds
    local est = BC.EstimateBatchDurationSeconds(10, 100, nil, nil, nil, nil, nil, nil)
    assert_equal(1.0, est, "EstimateDuration: 10 items * 100ms = 1.0s")

    -- With cooldowns: 10 items, 100ms each, cooldown every 5 items for 500ms
    est = BC.EstimateBatchDurationSeconds(10, 100, 5, 500, nil, nil, nil, nil)
    -- 10 * 100 = 1000ms items + floor((10-1)/5) * 500 = 1 * 500 = 500ms cooldowns = 1500ms = 1.5s
    assert_equal(1.5, est, "EstimateDuration: with cooldowns")

    -- With initial delay
    est = BC.EstimateBatchDurationSeconds(5, 100, nil, nil, nil, nil, nil, 200)
    -- 5 * 100 = 500 + 200 initial = 700ms = 0.7s
    assert_equal(0.7, est, "EstimateDuration: with initial delay")

    -- Zero items
    est = BC.EstimateBatchDurationSeconds(0, 100, nil, nil, nil, nil, nil, nil)
    assert_equal(0, est, "EstimateDuration: 0 items = 0s")
end

-- PruneServerActionHistory
print("\n-- PruneServerActionHistory --")
do
    -- Reset recovery state
    BC.SERVER_BATCH_RECOVERY_STATE = { cooldownUntilMs = 0, serverActionTimes = {} }

    -- Record some actions
    BC.RecordServerAction(1000, 60000)
    BC.RecordServerAction(2000, 60000)
    BC.RecordServerAction(3000, 60000)

    local history = BC.PruneServerActionHistory(3000, 60000)
    assert_equal(3, #history, "PruneHistory: all within window")

    -- Prune with tight window
    history = BC.PruneServerActionHistory(3000, 1500)
    assert_equal(2, #history, "PruneHistory: oldest pruned outside window")
end

-- ComputeServerActionDelayMs
print("\n-- ComputeServerActionDelayMs --")
do
    BC.SERVER_BATCH_RECOVERY_STATE = { cooldownUntilMs = 0, serverActionTimes = {} }

    -- Under the limit: no delay
    for i = 1, 5 do
        BC.RecordServerAction(i * 100, 60000)
    end
    local delay = BC.ComputeServerActionDelayMs(600, 60000, 10)
    assert_equal(0, delay, "ComputeDelay: under limit returns 0")

    -- At/over the limit
    BC.SERVER_BATCH_RECOVERY_STATE = { cooldownUntilMs = 0, serverActionTimes = {} }
    for i = 1, 10 do
        BC.RecordServerAction(i * 100, 60000)
    end
    delay = BC.ComputeServerActionDelayMs(1100, 60000, 10)
    assert_true(delay >= 0, "ComputeDelay: at limit returns non-negative delay")

    -- Edge cases
    delay = BC.ComputeServerActionDelayMs(1000, 0, 10)
    assert_equal(0, delay, "ComputeDelay: 0 window returns 0")
    delay = BC.ComputeServerActionDelayMs(1000, 60000, 0)
    assert_equal(0, delay, "ComputeDelay: 0 maxActions returns 0")
end

-- IsBatchSceneShowing
print("\n-- IsBatchSceneShowing --")
do
    -- nil self returns true (default)
    assert_true(BC.IsBatchSceneShowing(nil), "SceneShowing: nil self returns true")

    -- self with IsSceneShowing method
    local mockSelf = { IsSceneShowing = function() return true end }
    assert_true(BC.IsBatchSceneShowing(mockSelf), "SceneShowing: delegates to IsSceneShowing")

    mockSelf.IsSceneShowing = function() return false end
    assert_false(BC.IsBatchSceneShowing(mockSelf), "SceneShowing: returns false when scene hidden")

    -- self with _multiSelectConfig.isSceneShowing
    local configSelf = {
        _multiSelectConfig = { isSceneShowing = function() return true end }
    }
    assert_true(BC.IsBatchSceneShowing(configSelf), "SceneShowing: delegates to config callback")
end

-- ResolveSceneExitLabel
print("\n-- ResolveSceneExitLabel --")
do
    -- From batchOptions
    local label = BC.ResolveSceneExitLabel({}, { sceneExitLabel = "My Scene" })
    assert_equal("My Scene", label, "SceneExitLabel: from batchOptions")

    -- From config callback
    local selfWithConfig = {
        _multiSelectConfig = { getSceneExitLabel = function() return "Config Scene" end }
    }
    label = BC.ResolveSceneExitLabel(selfWithConfig, nil)
    assert_equal("Config Scene", label, "SceneExitLabel: from config callback")

    -- Default fallback
    label = BC.ResolveSceneExitLabel({}, nil)
    assert_equal("Scene", label, "SceneExitLabel: default fallback")
end

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\n=== Results: %d passed, %d failed ===\n", tests_passed, tests_failed))

if tests_failed > 0 then
    os.exit(1)
end
