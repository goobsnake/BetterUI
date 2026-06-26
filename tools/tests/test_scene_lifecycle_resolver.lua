--[[
File: tools/tests/test_scene_lifecycle_resolver.lua
Purpose: Regression tests for SceneLifecycleManager lifecycle defects:
         - PB-008: keybindsResolver resolves keybind groups at show/hide time
                   (groups created AFTER Register must still be added).
         - PB-009: Register guards against double-registration and exposes an
                   Unregister seam (re-init must not stack StateChange handlers).
         Legacy `keybinds` array behavior must remain intact.

Usage:
  lua tools/tests/test_scene_lifecycle_resolver.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }

function BETTERUI.CIM.SafeExecute(label, fn, ...)
    fn(...)
end

SCENE_SHOWING = "showing"
SCENE_HIDING = "hiding"
SCENE_HIDDEN = "hidden"

local addedGroups = {}
local removedGroups = {}
KEYBIND_STRIP = {
    AddKeybindButtonGroup = function(self, group) table.insert(addedGroups, group) end,
    RemoveKeybindButtonGroup = function(self, group) table.insert(removedGroups, group) end,
}

BETTERUI.Interface = {
    EnsureKeybindGroupAdded = function(group)
        KEYBIND_STRIP:AddKeybindButtonGroup(group)
        return true
    end,
    RemoveKeybindGroupIfPresent = function(group)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
        return true
    end,
}

dofile("Modules/CIM/Core/Lifecycle/SceneLifecycleManager.lua")

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

-- Mock scene whose RegisterCallback STACKS handlers (matches ESO semantics) so a
-- missing double-registration guard would be observable as multiple firings.
local function MockScene()
    local scene = { _handlers = {} }
    function scene:RegisterCallback(event, fn)
        self._handlers[event] = self._handlers[event] or {}
        table.insert(self._handlers[event], fn)
    end
    function scene:UnregisterCallback(event, fn)
        local list = self._handlers[event]
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == fn then table.remove(list, i) end
        end
    end
    function scene:triggerStateChange(oldState, newState)
        for _, fn in ipairs(self._handlers["StateChange"] or {}) do
            fn(oldState, newState)
        end
    end
    function scene:handlerCount()
        return #(self._handlers["StateChange"] or {})
    end
    return scene
end

local function reset()
    addedGroups = {}
    removedGroups = {}
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== SceneLifecycle resolver / re-registration Tests ===\n")

-- PB-008: keybindsResolver resolves at show-time, not at Register-time.
print("Test: keybindsResolver adds groups created AFTER Register (PB-008)")
reset()
do
    local sceneA = MockScene()
    local screenA = { scene = sceneA }
    local lateGroup = { name = "coreKeybinds" }
    local coreRef = nil -- not created yet at registration time (mirrors InitializeKeybind running later)
    BETTERUI.CIM.SceneLifecycle.Register(screenA, {
        keybindsResolver = function()
            local groups = {}
            if coreRef then groups[#groups + 1] = coreRef end
            return groups
        end,
    })
    -- Simulate InitializeKeybind() creating the group AFTER InitializeScene/Register.
    coreRef = lateGroup
    sceneA:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(1, #addedGroups, "late-created keybind group is added on showing")
    assert_equal(lateGroup, addedGroups[1], "correct late-bound group added")
    sceneA:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assert_equal(1, #removedGroups, "resolver-provided group removed on hiding")
    assert_equal(lateGroup, removedGroups[1], "correct group removed")
end

-- Back-compat: legacy `keybinds` array still works.
print("\nTest: legacy keybinds array still added/removed")
reset()
do
    local sceneC = MockScene()
    local g = { name = "legacy" }
    BETTERUI.CIM.SceneLifecycle.Register({ scene = sceneC }, { keybinds = { g } })
    sceneC:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(g, addedGroups[1], "legacy keybinds array added on showing")
    sceneC:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assert_equal(g, removedGroups[1], "legacy keybinds array removed on hiding")
end

-- PB-009: re-registration must not stack handlers.
print("\nTest: re-registration unregisters prior handler (PB-009)")
reset()
do
    local sceneB = MockScene()
    local screenB = { scene = sceneB }
    local showCount = 0
    local function makeConfig()
        return { onShowing = function() showCount = showCount + 1 end }
    end
    BETTERUI.CIM.SceneLifecycle.Register(screenB, makeConfig())
    BETTERUI.CIM.SceneLifecycle.Register(screenB, makeConfig()) -- re-init
    assert_equal(1, sceneB:handlerCount(), "only one active StateChange handler after re-register")
    sceneB:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(1, showCount, "onShowing fires exactly once (no double)")

    BETTERUI.CIM.SceneLifecycle.Unregister(screenB)
    assert_equal(0, sceneB:handlerCount(), "Unregister removes the handler")
    assert_equal(nil, screenB._sceneLifecycleHandle, "handle cleared after Unregister")
end

-- Unregister with nothing registered is a safe no-op.
print("\nTest: Unregister is a safe no-op when nothing registered")
do
    BETTERUI.CIM.SceneLifecycle.Unregister(nil)
    BETTERUI.CIM.SceneLifecycle.Unregister({})
    tests_passed = tests_passed + 1
    print("  [OK] Unregister(nil)/Unregister({}) handled gracefully")
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
