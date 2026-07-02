--[[
File: tools/tests/test_orb_events.lua
Purpose: Focused unit tests for ResourceOrbFrames/Core/OrbEvents.lua loop behavior.
Usage:
  lua tools/tests/test_orb_events.lua
]]

BETTERUI = {
    ResourceOrbFrames = {
        Utils = {},
        SkillBar = {
            CooldownUtils = {},
        },
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

print("[CooldownVisualTick arming]")
do
    local backBarCalls = 0
    local frontBarCalls = 0
    BETTERUI.ResourceOrbFrames.SkillBar.UpdateBackBarCooldowns = function()
        backBarCalls = backBarCalls + 1
    end
    BETTERUI.ResourceOrbFrames.SkillBar.UpdateFrontBarCooldowns = function()
        frontBarCalls = frontBarCalls + 1
    end

    -- Reset state and rebuild loops so CooldownVisualTick uses the new stubs.
    Events.SetupLoopEvents({}, {}, nil, { isCasting = false })
    local cooldownUpdate = registeredUpdates["BETTERUI_ResourceOrbFramesCooldownVisuals"]
    assert_true(type(cooldownUpdate and cooldownUpdate.callback) == "function",
        "setup registers the cooldown visuals update loop")

    -- SetupLoopEvents requests an initial scan, so the first tick always runs.
    BETTERUI.ResourceOrbFrames.SkillBar.CooldownUtils.IsCooldownVisualsArmed = function()
        return false
    end
    cooldownUpdate.callback()
    assert_eq(backBarCalls, 1, "first cooldown tick performs the requested initial scan")
    assert_eq(frontBarCalls, 1, "first cooldown tick scans the front bar during initial scan")

    -- With no active cooldowns, subsequent ticks should early-return without scanning.
    cooldownUpdate.callback()
    assert_eq(backBarCalls, 1, "disarmed cooldown tick skips back bar scan")
    assert_eq(frontBarCalls, 1, "disarmed cooldown tick skips front bar scan")

    -- When armed, the tick should scan both bars again.
    BETTERUI.ResourceOrbFrames.SkillBar.CooldownUtils.IsCooldownVisualsArmed = function()
        return true
    end
    cooldownUpdate.callback()
    assert_eq(backBarCalls, 2, "armed cooldown tick runs back bar scan")
    assert_eq(frontBarCalls, 2, "armed cooldown tick runs front bar scan")

    -- Module disable unregisters the loop.
    Events.SetLoopsEnabled(false)
    assert_eq(registeredUpdates["BETTERUI_ResourceOrbFramesCooldownVisuals"], nil,
        "disabling loops unregisters the cooldown visuals update")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
