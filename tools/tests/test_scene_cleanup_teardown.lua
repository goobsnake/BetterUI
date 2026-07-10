--[[
File: tools/tests/test_scene_cleanup_teardown.lua
Purpose: Regression tests for SceneCleanup.CleanupInputState teardown wiring:
         - PB-014e: headerSortKeybindDescriptor is removed from the strip AND
                    nil'd out symmetrically (no dangling reference).
         - PB-014d: a screen-held ListRefreshManager has Cancel() called so an
                    in-flight coalesced refresh + RestorePosition cannot run after teardown.
         - PB-014c: HeaderNavigation.CancelPending is invoked during cleanup.

Usage:
  lua tools/tests/test_scene_cleanup_teardown.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }

local removedGroups = {}
KEYBIND_STRIP = {
    RemoveKeybindButtonGroup = function(self, group) table.insert(removedGroups, group) end,
    AddKeybindButtonGroup = function(self, group) end,
}

BETTERUI.Interface = {
    RemoveKeybindGroupIfPresent = function(group)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
        return true
    end,
}

dofile("Modules/CIM/Core/Lifecycle/SceneCleanup.lua")

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

local function contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== SceneCleanup teardown Tests ===\n")

-- PB-014e: headerSortKeybindDescriptor removed AND nil'd symmetrically.
print("Test: headerSortKeybindDescriptor removed and nil'd (PB-014e)")
do
    removedGroups = {}
    local desc = { name = "headerSort" }
    local activeDesc = { name = "activeHeaderSort" }
    local screen = {
        headerSortKeybindDescriptor = desc,
        _activeHeaderSortKeybindDescriptor = activeDesc,
    }
    BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
    assert_true(contains(removedGroups, desc), "headerSortKeybindDescriptor removed from strip")
    assert_equal(nil, screen.headerSortKeybindDescriptor, "headerSortKeybindDescriptor nil'd out")
    assert_equal(nil, screen._activeHeaderSortKeybindDescriptor, "_activeHeaderSortKeybindDescriptor nil'd out (existing behavior)")
end

-- PB-014d: screen-held refresh manager Cancel() invoked.
print("\nTest: screen refresh manager Cancel() invoked on cleanup (PB-014d)")
do
    removedGroups = {}
    local cancelled = false
    local screen = {
        refreshManager = {
            Cancel = function(self) cancelled = true end,
        },
    }
    BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
    assert_true(cancelled, "refreshManager:Cancel() called during cleanup")
end

-- PB-014d: alternate conventional field name also covered.
print("\nTest: listRefreshManager alias Cancel() invoked")
do
    removedGroups = {}
    local cancelled = false
    local screen = {
        listRefreshManager = {
            Cancel = function(self) cancelled = true end,
        },
    }
    BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
    assert_true(cancelled, "listRefreshManager:Cancel() called during cleanup")
end

-- PB-014c wiring: HeaderNavigation.CancelPending invoked with the screen.
print("\nTest: HeaderNavigation.CancelPending invoked on cleanup (PB-014c wiring)")
do
    removedGroups = {}
    local cancelArg = nil
    BETTERUI.CIM.HeaderNavigation = {
        CancelPending = function(s) cancelArg = s end,
    }
    local screen = { id = "screenX" }
    BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
    assert_equal(screen, cancelArg, "CancelPending called with the screen being cleaned up")
    BETTERUI.CIM.HeaderNavigation = nil
end

print("\nTest: list deactivation deduplicates direct, wrapped, and alias references")
do
    local primaryCalls = 0
    local selectorCalls = 0
    local wrappedCalls = 0
    local innerCalls = 0
    local primary = { Deactivate = function() primaryCalls = primaryCalls + 1 end }
    local selector = { Deactivate = function() selectorCalls = selectorCalls + 1 end }
    local inner = { Deactivate = function() innerCalls = innerCalls + 1 end }
    local wrapped
    wrapped = {
        list = inner,
        Deactivate = function()
            wrappedCalls = wrappedCalls + 1
            wrapped.list = nil
        end,
    }
    local screen = { list = primary, selector = selector }

    BETTERUI.CIM.SceneCleanup.DeactivateLists(
        screen,
        primary,
        selector,
        wrapped,
        wrapped
    )

    assert_equal(1, primaryCalls, "primary list deactivated once")
    assert_equal(1, selectorCalls, "selector deactivated once")
    assert_equal(1, wrappedCalls, "wrapper deactivated once")
    assert_equal(1, innerCalls, "wrapped inner list deactivated once")
end

print("\nTest: self-referential list wrapper deactivates once")
do
    local calls = 0
    local list = { Deactivate = function() calls = calls + 1 end }
    list.list = list

    BETTERUI.CIM.SceneCleanup.DeactivateLists({ list = list }, list)

    assert_equal(1, calls, "self-referential list deactivated once")
end

-- Cleanup with a bare screen (no managers/descriptors) is a safe no-op.
print("\nTest: cleanup with bare screen does not crash")
do
    BETTERUI.CIM.SceneCleanup.CleanupInputState({})
    BETTERUI.CIM.SceneCleanup.CleanupInputState(nil)
    tests_passed = tests_passed + 1
    print("  [OK] bare/nil screen handled gracefully")
end

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
