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
BETTERUI.CIM.Debug.EnsureCommandsRegistered()

print("[DebugCommands bootstrap]")
resetState()
SLASH_COMMANDS["/buidebug"]("")
assert_eq(#featureFlagCalls, 0, "/buidebug does not self-enable debug logging")
assert_eq(BETTERUI.CIM.Debug.FLAGS.DIRECTIONAL_INPUT, false, "/buidebug keeps DIRECTIONAL_INPUT flag unchanged while disabled")
assert_eq(BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS, false, "/buidebug keeps SCENE_TRANSITIONS flag unchanged while disabled")
assert_eq(BETTERUI.CIM.Debug.FLAGS.LIST_OPERATIONS, false, "/buidebug keeps LIST_OPERATIONS flag unchanged while disabled")
assert_contains(output, "/buidebug requires debug mode", "/buidebug reports debug-mode gating when mode is disabled")

print("[DebugCommands on command]")
resetState()
SLASH_COMMANDS["/buidebug"]("on")
assert_eq(#featureFlagCalls, 0, "/buidebug on does not self-enable debug logging")
assert_contains(output, "/buidebug on no longer enables debug mode", "/buidebug on reports explicit external-enable requirement")

print("[DebugCommands inspector with debug mode enabled]")
resetState()
debugEnabled = true
SLASH_COMMANDS["/buidebug"]("")
assert_eq(#featureFlagCalls, 0, "/buidebug inspector does not write feature flags while already enabled")
assert_true(BETTERUI.CIM.Debug.FLAGS.DIRECTIONAL_INPUT, "/buidebug enables DIRECTIONAL_INPUT flag when mode is active")
assert_true(BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS, "/buidebug enables SCENE_TRANSITIONS flag when mode is active")
assert_true(BETTERUI.CIM.Debug.FLAGS.LIST_OPERATIONS, "/buidebug enables LIST_OPERATIONS flag when mode is active")
assert_contains(output, "DIRECTIONAL_INPUT - 0 objects registered", "/buidebug runs the directional input inspector when mode is active")

print("[DebugCommands disable]")
resetState()
debugEnabled = true
SLASH_COMMANDS["/buidebug"]("off")
assert_eq(#featureFlagCalls, 1, "/buidebug off persists debug logging disable")
assert_eq(featureFlagCalls[1].flagName, "DEBUG_LOGGING", "/buidebug off uses DEBUG_LOGGING flag")
assert_eq(featureFlagCalls[1].enabled, false, "/buidebug off disables DEBUG_LOGGING")
assert_eq(BETTERUI.CIM.Debug.FLAGS.DIRECTIONAL_INPUT, false, "/buidebug off clears DIRECTIONAL_INPUT flag")
assert_eq(BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS, false, "/buidebug off clears SCENE_TRANSITIONS flag")
assert_eq(BETTERUI.CIM.Debug.FLAGS.LIST_OPERATIONS, false, "/buidebug off clears LIST_OPERATIONS flag")
assert_contains(output, "Debug logging disabled", "/buidebug off reports disable")

print("[Scene command bootstrap]")
resetState()
SLASH_COMMANDS["/buiscene"]("")
assert_eq(#featureFlagCalls, 0, "/buiscene no longer auto-enables debug logging")
assert_eq(BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS, false, "/buiscene keeps debug flags unchanged while debug mode is off")
assert_contains(output, "/buiscene requires debug mode", "/buiscene reports debug-mode gating when mode is disabled")

print("[Scene command with debug mode enabled]")
resetState()
debugEnabled = true
SLASH_COMMANDS["/buiscene"]("")
assert_eq(#featureFlagCalls, 0, "/buiscene does not mutate feature flags when mode is already enabled")
assert_eq(BETTERUI.CIM.Debug.FLAGS.SCENE_TRANSITIONS, true, "/buiscene enables scene-transition tracing once debug mode is active")
assert_contains(output, "Scene States:", "/buiscene runs the scene inspector when debug mode is active")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
