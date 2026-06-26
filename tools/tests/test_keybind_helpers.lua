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
    AddKeybindButtonGroup = function(self, descriptor)
        if self.groups[descriptor] then
            return false
        end
        self.groups[descriptor] = true
        self.added[#self.added + 1] = descriptor
        return true
    end,
    RemoveKeybindButtonGroup = function(self, descriptor)
        if not self.groups[descriptor] then
            return false
        end
        self.groups[descriptor] = nil
        self.removed[#self.removed + 1] = descriptor
        return true
    end,
    HasKeybindButtonGroup = function(self, descriptor)
        return self.groups[descriptor] == true
    end,
    UpdateKeybindButtonGroup = function(self, descriptor)
        self.updated[#self.updated + 1] = descriptor
        return true
    end,
    UpdateCurrentKeybindButtonGroups = function(self)
        self.currentUpdates = self.currentUpdates + 1
        return true
    end,
}

dofile("Modules/CIM/Core/Presentation/KeybindHelpers.lua")

local descriptor = { id = "owned" }

assert_false(BETTERUI.Interface.HasKeybindGroup(nil), "nil descriptor is never present")
assert_true(BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor), "EnsureKeybindGroupAdded adds missing descriptor")
assert_equal(1, #KEYBIND_STRIP.added, "missing descriptor is added once")
assert_equal(1, #KEYBIND_STRIP.updated, "added descriptor is refreshed")

assert_true(BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor), "EnsureKeybindGroupAdded accepts existing descriptor")
assert_equal(1, #KEYBIND_STRIP.added, "existing descriptor is not added twice")
assert_equal(2, #KEYBIND_STRIP.updated, "existing descriptor is refreshed")

assert_true(BETTERUI.Interface.RemoveKeybindGroupIfPresent(descriptor), "present owned descriptor is removed")
assert_equal(1, #KEYBIND_STRIP.removed, "present descriptor removal calls the strip")
assert_false(BETTERUI.Interface.RemoveKeybindGroupIfPresent(descriptor), "absent descriptor removal is skipped")
assert_equal(1, #KEYBIND_STRIP.removed, "absent descriptor is not removed twice")

assert_true(BETTERUI.Interface.UpdateCurrentKeybindGroups(), "current keybind refresh is forwarded")
assert_equal(1, KEYBIND_STRIP.currentUpdates, "current keybind refresh count recorded")

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
