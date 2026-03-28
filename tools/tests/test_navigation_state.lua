--[[
File: tools/tests/test_navigation_state.lua
Purpose: Unit tests for CIM NavigationState state machine.
         Validates state transitions, token-based coalescing, and query helpers.

Usage:
  lua tools/tests/test_navigation_state.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Data/NavigationState.lua")

local NS = BETTERUI.CIM.NavigationState

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

local function assert_nil(value, message)
    assert_equal(nil, value, message)
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== NavigationState Tests ===\n")

-- Create
print("-- Create --")
do
    local state = NS.Create()
    assert_equal(0, state.changeToken, "Create: changeToken starts at 0")
    assert_nil(state.pendingCategoryIndex, "Create: pendingCategoryIndex is nil")
    assert_false(state.suppressListUpdates, "Create: suppressListUpdates is false")
    assert_nil(state.suppressListUpdatesToken, "Create: suppressListUpdatesToken is nil")
    assert_false(state.suppressHeaderCallback, "Create: suppressHeaderCallback is false")
    assert_false(state.isCyclingCategory, "Create: isCyclingCategory is false")
    assert_false(state.justToggledMode, "Create: justToggledMode is false")
end

-- StartCategoryChange
print("\n-- StartCategoryChange --")
do
    local state = NS.Create()
    local token = NS.StartCategoryChange(state, 3)
    assert_equal(1, token, "StartCategoryChange: returns token 1")
    assert_equal(1, state.changeToken, "StartCategoryChange: increments changeToken")
    assert_equal(3, state.pendingCategoryIndex, "StartCategoryChange: sets pendingCategoryIndex")
    assert_true(state.suppressListUpdates, "StartCategoryChange: suppresses list updates")
    assert_equal(1, state.suppressListUpdatesToken, "StartCategoryChange: sets suppressListUpdatesToken")
end

-- Sequential StartCategoryChange calls
print("\n-- Sequential StartCategoryChange --")
do
    local state = NS.Create()
    local token1 = NS.StartCategoryChange(state, 2)
    local token2 = NS.StartCategoryChange(state, 5)
    assert_equal(1, token1, "Sequential: first token is 1")
    assert_equal(2, token2, "Sequential: second token is 2")
    assert_equal(5, state.pendingCategoryIndex, "Sequential: last pending wins")
    assert_equal(2, state.suppressListUpdatesToken, "Sequential: latest token for suppression")
end

-- FinishCategoryChange
print("\n-- FinishCategoryChange --")
do
    local state = NS.Create()
    local token = NS.StartCategoryChange(state, 4)
    local result = NS.FinishCategoryChange(state, token)
    assert_true(result, "FinishCategoryChange: succeeds with correct token")
    assert_false(state.suppressListUpdates, "FinishCategoryChange: clears suppression")
    assert_nil(state.suppressListUpdatesToken, "FinishCategoryChange: clears token")
    assert_nil(state.pendingCategoryIndex, "FinishCategoryChange: clears pending index")
end

-- FinishCategoryChange with stale token
print("\n-- FinishCategoryChange stale token --")
do
    local state = NS.Create()
    local token1 = NS.StartCategoryChange(state, 2)
    NS.StartCategoryChange(state, 5) -- new change supersedes
    local result = NS.FinishCategoryChange(state, token1)
    assert_false(result, "FinishCategoryChange: fails with stale token")
    assert_true(state.suppressListUpdates, "FinishCategoryChange: suppression unchanged on stale")
end

-- CancelCategoryChange
print("\n-- CancelCategoryChange --")
do
    local state = NS.Create()
    local token = NS.StartCategoryChange(state, 3)
    local cancelled = NS.CancelCategoryChange(state, token)
    assert_true(cancelled, "CancelCategoryChange: succeeds with correct token")
    assert_false(state.suppressListUpdates, "CancelCategoryChange: clears suppression")
    assert_nil(state.pendingCategoryIndex, "CancelCategoryChange: clears pending index")
end

-- CancelCategoryChange with wrong token
print("\n-- CancelCategoryChange wrong token --")
do
    local state = NS.Create()
    NS.StartCategoryChange(state, 3)
    local cancelled = NS.CancelCategoryChange(state, 999)
    assert_false(cancelled, "CancelCategoryChange: fails with wrong token")
    assert_true(state.suppressListUpdates, "CancelCategoryChange: suppression unchanged")
end

-- IsChangeValid
print("\n-- IsChangeValid --")
do
    local state = NS.Create()
    local token = NS.StartCategoryChange(state, 1)
    assert_true(NS.IsChangeValid(state, token), "IsChangeValid: valid with current token")
    NS.StartCategoryChange(state, 2)
    assert_false(NS.IsChangeValid(state, token), "IsChangeValid: invalid after new change")
end

-- Cycling state helpers
print("\n-- Cycling state --")
do
    local state = NS.Create()
    assert_false(NS.IsCycling(state), "IsCycling: initially false")
    NS.StartCycling(state)
    assert_true(NS.IsCycling(state), "IsCycling: true after StartCycling")
    NS.StopCycling(state)
    assert_false(NS.IsCycling(state), "IsCycling: false after StopCycling")
end

-- Mode toggle and ShouldSuppressCallback
print("\n-- ShouldSuppressCallback --")
do
    local state = NS.Create()
    assert_false(NS.ShouldSuppressCallback(state), "ShouldSuppressCallback: initially false")
    NS.SetModeToggle(state, true)
    assert_true(NS.ShouldSuppressCallback(state), "ShouldSuppressCallback: true when mode toggled")
    NS.SetModeToggle(state, false)
    assert_false(NS.ShouldSuppressCallback(state), "ShouldSuppressCallback: false after clearing toggle")

    state.suppressHeaderCallback = true
    assert_true(NS.ShouldSuppressCallback(state), "ShouldSuppressCallback: true when header suppressed")
end

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\n=== Results: %d passed, %d failed ===\n", tests_passed, tests_failed))

if tests_failed > 0 then
    os.exit(1)
end
