--[[
File: tools/tests/test_debug_commands.lua
Purpose: Regression coverage for BetterUI debug command bootstrap behavior.
Usage:
  lua tools/tests/test_debug_commands.lua
]]

BETTERUI = {
    CIM = {
        Debug = {
            FLAGS = {
                DIRECTIONAL_INPUT = false,
                SCENE_TRANSITIONS = false,
                LIST_OPERATIONS = false,
            },
        },
        FeatureFlags = {
            FLAGS = {
                DEBUG_LOGGING = "DEBUG_LOGGING",
            },
        },
    },
}

SLASH_COMMANDS = {}

local debugEnabled = false
local featureFlagCalls = {}
local output = {}

function BETTERUI.CIM.Debug.IsEnabled()
    return debugEnabled
end

function BETTERUI.CIM.Debug.SetFlag(flagName, enabled)
    BETTERUI.CIM.Debug.FLAGS[flagName] = enabled
end

function BETTERUI.CIM.FeatureFlags.SetEnabled(flagName, enabled)
    featureFlagCalls[#featureFlagCalls + 1] = { flagName = flagName, enabled = enabled }
    debugEnabled = enabled
end

function d(message)
    output[#output + 1] = tostring(message)
end

DIRECTIONAL_INPUT = {
    inputObjects = {},
    inputControls = {},
    inputDeviceConsumed = {},
}

SCENE_MANAGER = {
    scenes = {},
    GetCurrentScene = function()
        return nil
    end,
}

KEYBIND_STRIP = {
    keybinds = nil,
}

function GetControl()
    return nil
end

local function resetState()
    debugEnabled = false
    featureFlagCalls = {}
    output = {}
    BETTERUI.CIM.Debug.FLAGS.DIRECTIONAL_INPUT = false
    BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS = false
    BETTERUI.CIM.Debug.FLAGS.LIST_OPERATIONS = false
end

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

local function assert_contains(lines, needle, label)
    local found = false
    for _, line in ipairs(lines) do
        if tostring(line):find(needle, 1, true) then
            found = true
            break
        end
    end
    assert_true(found, label)
end

dofile("Modules/CIM/Core/Diagnostics/DebugCommands.lua")

print("[DebugCommands bootstrap]")
resetState()
SLASH_COMMANDS["/buidebug"]("")
assert_eq(#featureFlagCalls, 1, "/buidebug enables debug logging through FeatureFlags")
assert_eq(featureFlagCalls[1].flagName, "DEBUG_LOGGING", "/buidebug uses DEBUG_LOGGING flag")
assert_eq(featureFlagCalls[1].enabled, true, "/buidebug enables DEBUG_LOGGING")
assert_true(BETTERUI.CIM.Debug.FLAGS.DIRECTIONAL_INPUT, "/buidebug enables DIRECTIONAL_INPUT flag")
assert_true(BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS, "/buidebug enables SCENE_TRANSITIONS flag")
assert_true(BETTERUI.CIM.Debug.FLAGS.LIST_OPERATIONS, "/buidebug enables LIST_OPERATIONS flag")
assert_contains(output, "Debug logging enabled for /buidebug", "/buidebug reports that debug logging was enabled")
assert_contains(output, "DIRECTIONAL_INPUT - 0 objects registered", "/buidebug runs the directional input inspector")

print("[DebugCommands disable]")
SLASH_COMMANDS["/buidebug"]("off")
assert_eq(#featureFlagCalls, 2, "/buidebug off persists debug logging disable")
assert_eq(featureFlagCalls[2].enabled, false, "/buidebug off disables DEBUG_LOGGING")
assert_eq(BETTERUI.CIM.Debug.FLAGS.DIRECTIONAL_INPUT, false, "/buidebug off clears DIRECTIONAL_INPUT flag")
assert_eq(BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS, false, "/buidebug off clears SCENE_TRANSITIONS flag")
assert_eq(BETTERUI.CIM.Debug.FLAGS.LIST_OPERATIONS, false, "/buidebug off clears LIST_OPERATIONS flag")
assert_contains(output, "Debug logging disabled", "/buidebug off reports disable")

print("[Scene command bootstrap]")
resetState()
SLASH_COMMANDS["/buiscene"]("")
assert_eq(#featureFlagCalls, 1, "/buiscene also enables debug logging when needed")
assert_eq(BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS, true, "/buiscene enables SCENE_TRANSITIONS flag")
assert_contains(output, "Scene States:", "/buiscene runs the scene inspector")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end