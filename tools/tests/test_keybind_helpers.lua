--[[
File: tools/tests/test_keybind_helpers.lua
Purpose: Unit tests for guarded KEYBIND_STRIP helper compatibility behavior.

Usage:
  lua tools/tests/test_keybind_helpers.lua
]]

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

print("\n=== KeybindHelpers Tests ===\n")

local warnings = {}
local traces = {}

BETTERUI = {
    Interface = {},
    Log = {
        CATEGORY = {
            KEYBIND = "keybind",
        },
        Warn = function(_, event, data)
            warnings[#warnings + 1] = {
                event = event,
                data = data,
            }
        end,
        Trace = function(_, event, data)
            traces[#traces + 1] = {
                event = event,
                data = data,
            }
        end,
    },
}

KEYBIND_STRIP = {
    added = {},
    removed = {},
    updated = {},
    groups = {},
    currentUpdates = 0,
    topStateReads = 0,
    GetTopKeybindStateIndex = function(self)
        self.topStateReads = self.topStateReads + 1
        return 2
    end,
    GetOrderedNarratableKeybindButtonInfo = function()
        return {
            { keybindName = "A", name = "Buy", enabled = true },
        }
    end,
    AddKeybindButtonGroup = function(self, descriptor, stateIndex)
        self.lastAddStateIndex = stateIndex
        if self.groups[descriptor] then
            return false
        end
        self.groups[descriptor] = true
        self.added[#self.added + 1] = descriptor
        return true
    end,
    RemoveKeybindButtonGroup = function(self, descriptor, stateIndex)
        self.lastRemoveStateIndex = stateIndex
        if not self.groups[descriptor] then
            return false
        end
        self.groups[descriptor] = nil
        self.removed[#self.removed + 1] = descriptor
        return true
    end,
    HasKeybindButtonGroup = function(self, descriptor, stateIndex)
        self.lastHasGroupStateIndex = stateIndex
        return self.groups[descriptor] == true
    end,
    UpdateKeybindButtonGroup = function(self, descriptor, stateIndex)
        self.lastUpdateStateIndex = stateIndex
        self.updated[#self.updated + 1] = descriptor
        return true
    end,
    HasKeybindButton = function(self, entry, stateIndex)
        self.lastHasButtonStateIndex = stateIndex
        return entry.keybind == "UI_SHORTCUT_PRIMARY"
    end,
    UpdateCurrentKeybindButtonGroups = function(self, stateIndex)
        self.lastCurrentUpdateStateIndex = stateIndex
        self.currentUpdates = self.currentUpdates + 1
        return true
    end,
}

dofile("Modules/CIM/Core/Presentation/KeybindHelpers.lua")

local descriptor = {
    { keybind = "UI_SHORTCUT_PRIMARY", name = "Buy" },
    { keybind = "UI_SHORTCUT_NEGATIVE", name = "Back", ethereal = true },
    id = "owned",
}

assert_false(BETTERUI.Interface.HasKeybindGroup(nil), "nil descriptor is never present")
assert_true(BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor), "EnsureKeybindGroupAdded adds missing descriptor")
assert_equal(1, #KEYBIND_STRIP.added, "missing descriptor is added once")
assert_equal(1, #KEYBIND_STRIP.updated, "added descriptor is refreshed")
assert_equal(2, KEYBIND_STRIP.lastAddStateIndex, "missing descriptor is added to the active keybind state")
assert_equal(2, KEYBIND_STRIP.lastUpdateStateIndex, "added descriptor is refreshed in the active keybind state")
assert_equal(2, KEYBIND_STRIP.lastHasGroupStateIndex, "group presence is checked against the active keybind state")
assert_equal(2, KEYBIND_STRIP.lastHasButtonStateIndex, "diagnostic button membership reads the active keybind state")
assert_equal(2, traces[#traces].data.stateIndex, "ensure trace records the active keybind state")
assert_equal(2, traces[#traces].data.topStateIndex, "ensure trace records the top keybind state")
assert_equal("string", type(traces[#traces].data.liveKeybinds), "ensure trace records the live keybind strip summary")
if type(traces[#traces].data.liveKeybinds) == "string" then
    assert_true(traces[#traces].data.liveKeybinds:find("n=1", 1, true) ~= nil,
        "ensure trace records the live keybind strip summary details")
end

assert_true(BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor), "EnsureKeybindGroupAdded accepts existing descriptor")
assert_equal(1, #KEYBIND_STRIP.added, "existing descriptor is not added twice")
assert_equal(2, #KEYBIND_STRIP.updated, "existing descriptor is refreshed")
assert_equal(2, KEYBIND_STRIP.lastUpdateStateIndex, "existing descriptor is refreshed in the active keybind state")

assert_true(BETTERUI.Interface.RemoveKeybindGroupIfPresent(descriptor), "present owned descriptor is removed")
assert_equal(1, #KEYBIND_STRIP.removed, "present descriptor removal calls the strip")
assert_equal(2, KEYBIND_STRIP.lastRemoveStateIndex, "present descriptor is removed from the active keybind state")
assert_false(BETTERUI.Interface.RemoveKeybindGroupIfPresent(descriptor), "absent descriptor removal is skipped")
assert_equal(1, #KEYBIND_STRIP.removed, "absent descriptor is not removed twice")

assert_true(BETTERUI.Interface.UpdateCurrentKeybindGroups(), "current keybind refresh is forwarded")
assert_equal(1, KEYBIND_STRIP.currentUpdates, "current keybind refresh count recorded")
assert_equal(2, KEYBIND_STRIP.lastCurrentUpdateStateIndex, "current keybind refresh targets the active keybind state")

KEYBIND_STRIP.UpdateKeybindButtonGroup = function()
    error("synthetic keybind failure")
end
assert_false(BETTERUI.Interface.UpdateKeybindGroup(descriptor), "keybind helper reports failed guarded calls")
assert_equal(1, #warnings, "keybind helper logs guarded call failures")

KEYBIND_STRIP = nil
assert_false(BETTERUI.Interface.UpdateCurrentKeybindGroups(), "missing KEYBIND_STRIP is handled")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))

if tests_failed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
