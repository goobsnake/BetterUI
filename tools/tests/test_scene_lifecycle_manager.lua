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
local activeGroups = {}
local purgedGroups = {}
KEYBIND_STRIP = {
    AddKeybindButtonGroup = function(self, group)
        table.insert(addedGroups, group)
        activeGroups[group] = true
        return true
    end,
    RemoveKeybindButtonGroup = function(self, group)
        if not activeGroups[group] then return false end
        table.insert(removedGroups, group)
        activeGroups[group] = nil
        return true
    end,
}

BETTERUI.Interface = {
    EnsureKeybindGroupAdded = function(group)
        KEYBIND_STRIP:AddKeybindButtonGroup(group)
        return true
    end,
    RemoveKeybindGroupIfPresent = function(group)
        return KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
    end,
    RemoveKeybindGroupFromAllStates = function(group)
        table.insert(purgedGroups, group)
        local removed = KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
        return removed, removed and 1 or 0
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
    local scene = { _callbacks = {}, _state = SCENE_HIDDEN }
    function scene:RegisterCallback(event, fn)
        self._callbacks[event] = fn
    end
    function scene:UnregisterCallback(event, fn)
        if self._callbacks[event] == fn then self._callbacks[event] = nil end
    end
    function scene:IsShowing()
        return self._state == SCENE_SHOWING
    end
    function scene:triggerStateChange(oldState, newState)
        self._state = newState
        if self._callbacks["StateChange"] then
            self._callbacks["StateChange"](oldState, newState)
        end
    end
    return scene
end

local function reset()
    addedGroups = {}
    removedGroups = {}
    activeGroups = {}
    purgedGroups = {}
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
assert_equal(1, #purgedGroups, "Keybind group receives an all-state purge on hiding")
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

-- Test 11: mutable keybindsResolver returning A on SHOWING and B later still removes A.
print("\nTest: mutable keybindsResolver removes the SHOWING snapshot even when resolver changes")
reset()
do
    local scene11 = MockScene()
    local screen11 = { scene = scene11 }
    local groupA = { name = "A" }
    local groupB = { name = "B" }
    local resolverResult = { groupA }
    BETTERUI.CIM.SceneLifecycle.Register(screen11, {
        keybindsResolver = function() return resolverResult end,
    })
    scene11:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(1, #addedGroups, "SHOWING adds one group")
    assert_equal(groupA, addedGroups[1], "SHOWING adds group A")
    resolverResult[1] = groupB
    scene11:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assert_equal(1, #removedGroups, "HIDING removes exactly the SHOWING snapshot")
    assert_equal(groupA, removedGroups[1], "HIDING removes group A, not the later-resolved group B")
end

-- Test 12: multi-scene registration identifies the captured firing scene after screen.scene mutates.
print("\nTest: captured registered scene is identified after screen.scene mutates")
reset()
do
    local loggedScenes = {}
    BETTERUI.Log = {
        CATEGORY = { SCENE = "scene", KEYBIND = "keybind" },
        Trace = function(cat, msg, ctx)
            if ctx and ctx.scene then table.insert(loggedScenes, ctx.scene) end
        end,
        Info = function(cat, msg, ctx)
            if ctx and ctx.scene then table.insert(loggedScenes, ctx.scene) end
        end,
        Warn = function(...) end,
        DescribeKeybindDescriptor = function(group, action) return tostring(group) end,
        DescribeKeybindDescriptors = function(groups, prefix) return tostring(#(groups or {})) end,
    }
    local scene12a = MockScene()
    local scene12b = MockScene()
    function scene12a:GetName() return "CapturedSceneA" end
    function scene12b:GetName() return "CapturedSceneB" end
    local screen12 = { scene = scene12a }
    BETTERUI.CIM.SceneLifecycle.Register(screen12, {})
    screen12.scene = scene12b
    BETTERUI.CIM.SceneLifecycle.Register(screen12, {})
    loggedScenes = {}
    scene12a:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal("CapturedSceneA", loggedScenes[1], "firing sceneA is identified by captured registered scene")
    BETTERUI.Log = nil
end

-- Test 13: HIDDEN re-cancels tasks and cleans the SHOWING snapshot (direct-HIDDEN fallback).
print("\nTest: HIDDEN re-cancels tasks and cleans the SHOWING snapshot")
reset()
do
    local scene13 = MockScene()
    local screen13 = { scene = scene13 }
    local group13 = { name = "snapshotGroup" }
    local cancelCount = 0
    local taskManager = { CancelAll = function(self) cancelCount = cancelCount + 1 end }
    BETTERUI.CIM.SceneLifecycle.Register(screen13, {
        keybinds = { group13 },
        taskManager = taskManager,
    })
    scene13:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(1, #addedGroups, "SHOWING adds the snapshot group")
    scene13:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assert_equal(1, cancelCount, "HIDING calls CancelAll once")
    assert_equal(1, #removedGroups, "HIDING removes the snapshot group")
    scene13:triggerStateChange(SCENE_HIDING, SCENE_HIDDEN)
    assert_equal(2, cancelCount, "HIDDEN re-cancels tasks")
    assert_equal(1, #removedGroups, "no over-remove from HIDDEN after HIDING")

    -- Direct-HIDDEN fallback: skip HIDING and go straight from SHOWING to HIDDEN.
    reset()
    cancelCount = 0
    scene13:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(1, #addedGroups, "direct-fallback SHOWING adds the group")
    scene13:triggerStateChange(SCENE_SHOWING, SCENE_HIDDEN)
    assert_equal(1, #removedGroups, "direct HIDDEN cleans the SHOWING snapshot")
    assert_equal(group13, removedGroups[1], "direct HIDDEN removes the correct snapshot group")
    assert_equal(1, cancelCount, "direct HIDDEN cancels tasks")
end

-- Test 14: HIDING→SHOWING re-entry uses a new snapshot without leaking/over-removing.
print("\nTest: HIDING→SHOWING re-entry uses a new snapshot without leaking/over-removing")
reset()
do
    local scene14 = MockScene()
    local screen14 = { scene = scene14 }
    local groupA = { name = "entryA" }
    local groupB = { name = "entryB" }
    local resolverResult = { groupA }
    BETTERUI.CIM.SceneLifecycle.Register(screen14, {
        keybindsResolver = function() return resolverResult end,
    })
    scene14:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assert_equal(1, #addedGroups, "first SHOWING adds one group")
    assert_equal(groupA, addedGroups[1], "first SHOWING adds group A")
    scene14:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assert_equal(1, #removedGroups, "HIDING removes group A")
    resolverResult = { groupB }
    scene14:triggerStateChange(SCENE_HIDING, SCENE_SHOWING)
    assert_equal(2, #addedGroups, "re-entry SHOWING adds group B")
    assert_equal(groupB, addedGroups[2], "re-entry SHOWING adds the new group B")
    scene14:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assert_equal(2, #removedGroups, "final HIDING removes exactly one group")
    assert_equal(groupB, removedGroups[2], "final HIDING removes group B, not A again")
end

-- Test 15: HIDING performs its authoritative all-state purge after onHiding,
-- so teardown callbacks cannot accidentally reacquire scene keybinds.
print("\nTest: HIDING purges keybinds after teardown callbacks")
reset()
do
    local scene15 = MockScene()
    local screen15 = { scene = scene15 }
    local group15 = { name = "reacquiredDuringHiding" }
    BETTERUI.CIM.SceneLifecycle.Register(screen15, {
        keybinds = { group15 },
        onHiding = function()
            BETTERUI.Interface.EnsureKeybindGroupAdded(group15)
        end,
    })
    scene15:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    scene15:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assert_equal(false, activeGroups[group15] == true,
        "HIDING callback cannot leave its scene keybind active")
    assert_equal(group15, purgedGroups[#purgedGroups],
        "HIDING uses the all-state purge helper for the owned group")
end

-- Test 16: HIDDEN runs a final purge after onHidden. Dialog/keybind state pops
-- and late cleanup callbacks therefore cannot resurrect the hidden scene.
print("\nTest: HIDDEN performs a final post-callback all-state purge")
reset()
do
    local scene16 = MockScene()
    local screen16 = { scene = scene16 }
    local group16 = { name = "reacquiredDuringHidden" }
    BETTERUI.CIM.SceneLifecycle.Register(screen16, {
        keybinds = { group16 },
        onHidden = function()
            BETTERUI.Interface.EnsureKeybindGroupAdded(group16)
        end,
    })
    scene16:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    scene16:triggerStateChange(SCENE_SHOWING, SCENE_HIDDEN)
    assert_equal(false, activeGroups[group16] == true,
        "HIDDEN callback cannot leave its scene keybind active")
    assert_equal(group16, purgedGroups[#purgedGroups],
        "HIDDEN finalizes ownership with an all-state purge")
end

-- Test 17: direct SHOWING to HIDDEN runs the HIDING teardown exactly once.
print("\nTest: direct HIDDEN runs HIDING teardown exactly once")
reset()
do
    local scene17 = MockScene()
    local screen17 = { scene = scene17 }
    local hidingCalls = 0
    local hiddenCalls = 0
    local releasedDialogOwners = 0
    BETTERUI.CIM.Dialogs = {
        ReleaseOwned = function(owner)
            if owner == screen17 then releasedDialogOwners = releasedDialogOwners + 1 end
        end,
    }
    BETTERUI.CIM.SceneLifecycle.Register(screen17, {
        onHiding = function() hidingCalls = hidingCalls + 1 end,
        onHidden = function() hiddenCalls = hiddenCalls + 1 end,
    })
    scene17:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    scene17:triggerStateChange(SCENE_SHOWING, SCENE_HIDDEN)
    assert_equal(1, hidingCalls, "direct HIDDEN invokes onHiding once")
    assert_equal(1, hiddenCalls, "direct HIDDEN invokes onHidden once")
    assert_equal(2, releasedDialogOwners,
        "direct HIDDEN releases scene-owned dialogs before and after teardown callbacks")
    BETTERUI.CIM.Dialogs = nil
end

-- Test 18: replacing a visible scene lifecycle disposes old ownership and
-- synchronizes the replacement handler to the current visible state.
print("\nTest: visible re-registration transfers lifecycle ownership")
reset()
do
    local scene18 = MockScene()
    local screen18 = { scene = scene18 }
    local groupA = { name = "registeredA" }
    local groupB = { name = "registeredB" }
    BETTERUI.CIM.SceneLifecycle.Register(screen18, { keybinds = { groupA } })
    scene18:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    BETTERUI.CIM.SceneLifecycle.Register(screen18, { keybinds = { groupB } })
    assert_equal(false, activeGroups[groupA] == true,
        "re-registration purges the previous visible lifecycle group")
    assert_equal(true, activeGroups[groupB] == true,
        "replacement lifecycle immediately acquires its visible group")
end

-- Test 19: disposing between HIDING and HIDDEN must not re-run teardown
-- callbacks that the HIDING transition already executed.
print("\nTest: dispose after HIDING runs teardown exactly once")
reset()
do
    local scene19 = MockScene()
    local screen19 = { scene = scene19 }
    local hidingCalls = 0
    local group19 = { name = "disposedAfterHiding" }
    BETTERUI.CIM.SceneLifecycle.Register(screen19, {
        keybinds = { group19 },
        onHiding = function() hidingCalls = hidingCalls + 1 end,
    })
    scene19:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    scene19:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    BETTERUI.CIM.SceneLifecycle.Unregister(screen19, scene19)
    assert_equal(1, hidingCalls, "dispose after HIDING does not re-run onHiding")
    assert_equal(false, activeGroups[group19] == true,
        "disposed lifecycle leaves no active keybind group")
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
