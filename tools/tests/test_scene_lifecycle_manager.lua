--[[
File: tools/tests/test_scene_lifecycle_manager.lua
Purpose: Unit tests for SceneLifecycleManager — unified scene state change handling.

Usage:
  lua tools/tests/test_scene_lifecycle_manager.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }

function BETTERUI.Debug(msg) end

-- SafeExecute stub that just calls the function
function BETTERUI.CIM.SafeExecute(label, fn, ...)
    fn(...)
end

-- Scene state constants
SCENE_SHOWING = "showing"
SCENE_HIDING = "hiding"
SCENE_HIDDEN = "hidden"

-- Keybind strip mock
local addedGroups = {}
local removedGroups = {}
KEYBIND_STRIP = {
    AddKeybindButtonGroup = function(self, group)
        table.insert(addedGroups, group)
    end,
    RemoveKeybindButtonGroup = function(self, group)
        table.insert(removedGroups, group)
    end,
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

-- EventRegistry mock
BETTERUI.CIM.EventRegistry = {
    _unregisteredModules = {},
    UnregisterAll = function(moduleName)
        table.insert(BETTERUI.CIM.EventRegistry._unregisteredModules, moduleName)
    end,
}

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

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

-- Mock scene that captures callbacks
local function MockScene()
    local scene = { _callbacks = {} }
    function scene:RegisterCallback(event, fn)
        self._callbacks[event] = fn
    end
    function scene:UnregisterCallback(event, fn)
        if self._callbacks[event] == fn then self._callbacks[event] = nil end
    end
    function scene:triggerStateChange(oldState, newState)
        if self._callbacks["StateChange"] then
            self._callbacks["StateChange"](oldState, newState)
        end
    end
    return scene
end

local function reset()
    addedGroups = {}
    removedGroups = {}
    BETTERUI.CIM.EventRegistry._unregisteredModules = {}
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== SceneLifecycleManager Tests ===\n")

-- Test 0: CreateStateChangeHandler builds a callable state router
print("Test: CreateStateChangeHandler builds a callable state router")
reset()
do
    local showingCalls = 0
    local hidingCalls = 0
    local hiddenCalls = 0
    local screen0 = {}
    local handler = BETTERUI.CIM.SceneLifecycle.CreateStateChangeHandler(screen0, {
        onShowing = function()
            showingCalls = showingCalls + 1
        end,
        onHiding = function()
            hidingCalls = hidingCalls + 1
        end,
        onHidden = function()
            hiddenCalls = hiddenCalls + 1
        end,
    })
    assert_true(type(handler) == "function", "CreateStateChangeHandler returns a function")
    handler(SCENE_HIDDEN, SCENE_SHOWING)
    handler(SCENE_SHOWING, SCENE_HIDING)
    handler(SCENE_HIDING, SCENE_HIDDEN)
    assert_equal(1, showingCalls, "CreateStateChangeHandler invokes onShowing")
    assert_equal(1, hidingCalls, "CreateStateChangeHandler invokes onHiding")
    assert_equal(1, hiddenCalls, "CreateStateChangeHandler invokes onHidden")
end

-- Test 1: Register with nil screen does not crash
print("Test: Register with nil screen does not crash")
reset()
BETTERUI.CIM.SceneLifecycle.Register(nil, {})
tests_passed = tests_passed + 1
print("  [OK] nil screen handled gracefully")

-- Test 2: Register with screen without scene does not crash
print("\nTest: Register with screen without scene does not crash")
reset()
BETTERUI.CIM.SceneLifecycle.Register({}, {})
tests_passed = tests_passed + 1
print("  [OK] missing scene handled gracefully")

-- Test 3: SCENE_SHOWING adds keybinds
print("\nTest: SCENE_SHOWING adds keybinds")
reset()
local scene3 = MockScene()
local keybindGroup = { name = "testKeybinds" }
local screen3 = { scene = scene3 }
BETTERUI.CIM.SceneLifecycle.Register(screen3, {
    keybinds = { keybindGroup },
})
scene3:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
assert_equal(1, #addedGroups, "One keybind group added")
assert_equal(keybindGroup, addedGroups[1], "Correct keybind group added")

-- Test 4: SCENE_SHOWING calls onShowing
print("\nTest: SCENE_SHOWING calls onShowing")
reset()
local scene4 = MockScene()
local screen4 = { scene = scene4 }
local showingCalled = false
local showingScreen = nil
BETTERUI.CIM.SceneLifecycle.Register(screen4, {
    onShowing = function(scr, wasPushed)
        showingCalled = true
        showingScreen = scr
    end,
})
scene4:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
assert_true(showingCalled, "onShowing was called")
assert_equal(screen4, showingScreen, "Correct screen passed to onShowing")

-- Test 5: SCENE_HIDING removes keybinds and cancels tasks
print("\nTest: SCENE_HIDING removes keybinds and cancels tasks")
reset()
local scene5 = MockScene()
local screen5 = { scene = scene5 }
local keybindGroup5 = { name = "kb5" }
local tasksCancelled = false
local taskManager = {
    CancelAll = function(self) tasksCancelled = true end,
}
BETTERUI.CIM.SceneLifecycle.Register(screen5, {
    keybinds = { keybindGroup5 },
    taskManager = taskManager,
})
scene5:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
assert_equal(1, #removedGroups, "Keybind group removed on hiding")
assert_true(tasksCancelled, "Tasks cancelled on hiding")

-- Test 6: SCENE_HIDING calls onHiding
print("\nTest: SCENE_HIDING calls onHiding")
reset()
local scene6 = MockScene()
local screen6 = { scene = scene6 }
local hidingCalled = false
BETTERUI.CIM.SceneLifecycle.Register(screen6, {
    onHiding = function(scr)
        hidingCalled = true
    end,
})
scene6:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
assert_true(hidingCalled, "onHiding was called")

-- Test 7: SCENE_HIDDEN unregisters events and calls onHidden
print("\nTest: SCENE_HIDDEN unregisters events and calls onHidden")
reset()
local scene7 = MockScene()
local screen7 = { scene = scene7 }
local hiddenCalled = false
BETTERUI.CIM.SceneLifecycle.Register(screen7, {
    eventRegistryModule = "TestMod",
    onHidden = function(scr)
        hiddenCalled = true
    end,
})
scene7:triggerStateChange(SCENE_HIDING, SCENE_HIDDEN)
assert_true(hiddenCalled, "onHidden was called")
assert_equal(1, #BETTERUI.CIM.EventRegistry._unregisteredModules, "Events unregistered")
assert_equal("TestMod", BETTERUI.CIM.EventRegistry._unregisteredModules[1], "Correct module unregistered")

-- Test 8: Config with no callbacks doesn't crash
print("\nTest: Config with no callbacks doesn't crash")
reset()
local scene8 = MockScene()
local screen8 = { scene = scene8 }
BETTERUI.CIM.SceneLifecycle.Register(screen8, {})
scene8:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
scene8:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
scene8:triggerStateChange(SCENE_HIDING, SCENE_HIDDEN)
tests_passed = tests_passed + 1
print("  [OK] Empty config handles all states without crash")

-- Test 9: one screen driving TWO scenes keeps BOTH lifecycles. Regression for the
-- guild-bank registration clobbering the personal bank scene's handler, which left
-- the bank scene with no OnSceneShowing -> no content/backdrop -> empty window.
print("\nTest: a second scene on the same screen does not clobber the first")
reset()
do
    local sceneA = MockScene()
    local sceneB = MockScene()
    local screenMulti = { scene = sceneA }
    local aShowing, bShowing = 0, 0
    BETTERUI.CIM.SceneLifecycle.Register(screenMulti, { onShowing = function() aShowing = aShowing + 1 end })
    screenMulti.scene = sceneB
    BETTERUI.CIM.SceneLifecycle.Register(screenMulti, { onShowing = function() bShowing = bShowing + 1 end })
    sceneA:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    sceneB:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(1, aShowing, "first scene's lifecycle still fires after a second is registered")
    assert_equal(1, bShowing, "second scene's lifecycle fires")
end

-- Test 10: re-registering the SAME scene on a screen replaces (does not stack).
print("\nTest: re-registering the same scene does not stack handlers")
reset()
do
    local sceneR = MockScene()
    local screenR = { scene = sceneR }
    local count = 0
    BETTERUI.CIM.SceneLifecycle.Register(screenR, { onShowing = function() count = count + 1 end })
    BETTERUI.CIM.SceneLifecycle.Register(screenR, { onShowing = function() count = count + 1 end })
    sceneR:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(1, count, "same-scene re-registration replaces rather than stacks")
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
