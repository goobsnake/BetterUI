--[[
File: tools/tests/test_orb_events.lua
Purpose: Focused unit tests for ResourceOrbFrames/Core/OrbEvents.lua loop behavior.
Usage:
  lua tools/tests/test_orb_events.lua
]]

BETTERUI = {
    ResourceOrbFrames = {
        Utils = {},
        SkillBar = {},
        CombatIndicators = {},
    },
    CIM = {
        EventRegistry = {
            Register = function() end,
        },
    },
}

local liveSettings = {
    m_enabled = true,
    orbAnimFlow = true,
    customFrontBar = {
        m_enabled = true,
    },
}

BETTERUI.ResourceOrbFrames.Utils.Settings = {
    GetLive = function()
        return liveSettings
    end,
}

local registeredUpdates = {}
EVENT_MANAGER = {
    RegisterForUpdate = function(_, name, intervalMs, callback)
        registeredUpdates[name] = {
            intervalMs = intervalMs,
            callback = callback,
        }
    end,
    UnregisterForUpdate = function(_, name)
        registeredUpdates[name] = nil
    end,
}

local nowMs = 1000
function GetGameTimeMilliseconds()
    return nowMs
end

dofile("Modules/ResourceOrbFrames/Core/OrbEvents.lua")

local Events = BETTERUI.ResourceOrbFrames.Events

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected true, got %s", label, tostring(value)))
    end
end

print("[SetupLoopEvents]")
do
    local poolCalls = {}
    local shieldCalls = {}
    local pools = {
        [1] = {
            UpdateAnimation = function(_, deltaMs, settings)
                poolCalls[#poolCalls + 1] = {
                    deltaMs = deltaMs,
                    orbAnimFlow = settings.orbAnimFlow,
                }
            end,
        },
    }
    local shieldBar = {
        UpdateAnimation = function(_, deltaMs, settings)
            shieldCalls[#shieldCalls + 1] = {
                deltaMs = deltaMs,
                orbAnimFlow = settings.orbAnimFlow,
            }
        end,
    }

    Events.SetupLoopEvents({}, pools, shieldBar, { isCasting = false })

    local animationUpdate = registeredUpdates["BETTERUI_ResourceOrbFramesOrbAnimation"]
    assert_true(type(animationUpdate and animationUpdate.callback) == "function",
        "setup registers the orb animation update loop")

    liveSettings.orbAnimFlow = false
    nowMs = 1033
    animationUpdate.callback()

    assert_eq(#poolCalls, 1, "animation tick still updates orb pools when flow is disabled")
    assert_eq(poolCalls[1].deltaMs, 33, "animation tick forwards elapsed time to orb pools")
    assert_eq(poolCalls[1].orbAnimFlow, false, "animation tick forwards the live disabled-flow setting")
    assert_eq(#shieldCalls, 1, "animation tick still updates the shield bar when flow is disabled")

    liveSettings.m_enabled = false
    nowMs = 1066
    animationUpdate.callback()
    assert_eq(#poolCalls, 1, "disabled module suppresses further orb animation updates")
    assert_eq(#shieldCalls, 1, "disabled module suppresses further shield animation updates")
    liveSettings.m_enabled = true
    liveSettings.orbAnimFlow = true
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
