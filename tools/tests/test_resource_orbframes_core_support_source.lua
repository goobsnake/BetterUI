--[[
File: tools/tests/test_resource_orbframes_core_support_source.lua
Purpose: Source-level regression checks for ResourceOrbFrames constants and core helper modules.

Usage:
  lua tools/tests/test_resource_orbframes_core_support_source.lua
]]

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local constantsSource = read_file("Modules/ResourceOrbFrames/Constants.lua")
assert_true(constantsSource:find("if not BETTERUI%.ResourceOrbFrames then BETTERUI%.ResourceOrbFrames = %{%} end") ~= nil,
    "ROF Constants initializes the ResourceOrbFrames namespace")
assert_true(constantsSource:find("if not BETTERUI%.ResourceOrbFrames%.CONST then BETTERUI%.ResourceOrbFrames%.CONST = %{%} end") ~= nil,
    "ROF Constants initializes the CONST namespace")
assert_true(constantsSource:find("BETTERUI%.ResourceOrbFrames%.CONST%.LAYOUT_CONFIG = %{%s*") ~= nil,
    "ROF Constants defines the shared layout config")
assert_true(constantsSource:find("BETTERUI%.ResourceOrbFrames%.CONST%.ORBS_DIMENSIONS = %{%s*") ~= nil,
    "ROF Constants defines the orb dimensions table")
assert_true(constantsSource:find("BETTERUI_ORB_FRAMES = %{%s*") ~= nil,
    "ROF Constants defines the root BETTERUI_ORB_FRAMES configuration")

local animationsSource = read_file("Modules/ResourceOrbFrames/Core/OrbAnimations.lua")
assert_true(animationsSource:find("function Animations%.AnimateDimensions%(rootFrame, targetScale, targetOffsetX, targetOffsetY%)") ~= nil,
    "OrbAnimations exposes AnimateDimensions")
assert_true(animationsSource:find("function Animations%.SetState%(scale, offsetX, offsetY%)") ~= nil,
    "OrbAnimations exposes SetState")
assert_true(animationsSource:find("function Animations%.GetLastScale%(%)") ~= nil,
    "OrbAnimations exposes GetLastScale")
assert_true(animationsSource:find("function Animations%.GetLastOffsetX%(%)") ~= nil,
    "OrbAnimations exposes GetLastOffsetX")
assert_true(animationsSource:find("function Animations%.GetLastOffsetY%(%)") ~= nil,
    "OrbAnimations exposes GetLastOffsetY")
assert_true(animationsSource:find("function Animations%.CreateCombatGlow%(control%)") ~= nil,
    "OrbAnimations exposes CreateCombatGlow")

local barUpdatesSource = read_file("Modules/ResourceOrbFrames/Core/OrbBarUpdates.lua")
assert_true(barUpdatesSource:find("function CastBar:ApplyFillStyle%(fillColor, depthColor%)") ~= nil,
    "OrbBarUpdates exposes CastBar ApplyFillStyle")
assert_true(barUpdatesSource:find("function CastBar:OnCastStart%(unitTag, abilityName, castDuration, isChanneled, showCountdown, castFillColor,") ~= nil,
    "OrbBarUpdates exposes CastBar OnCastStart")
assert_true(barUpdatesSource:find("function CastBar:Update%(%)") ~= nil,
    "OrbBarUpdates exposes CastBar Update")
assert_true(barUpdatesSource:find("function ExperienceBar:Update%(%)") ~= nil,
    "OrbBarUpdates exposes ExperienceBar Update")
assert_true(barUpdatesSource:find("function MountStaminaBar:Update%(%)") ~= nil,
    "OrbBarUpdates exposes MountStaminaBar Update")
assert_true(barUpdatesSource:find("function FoodBuffTracker:Update%(%)") ~= nil,
    "OrbBarUpdates exposes FoodBuffTracker Update")
assert_true(barUpdatesSource:find("function Bars%.CreateCastBar%(parent%) return CastBar:New%(parent%) end") ~= nil,
    "OrbBarUpdates exposes the cast bar factory")

local combatIndicatorsSource = read_file("Modules/ResourceOrbFrames/Core/OrbCombatIndicators.lua")
assert_true(combatIndicatorsSource:find("function CombatIndicators%.ResolveFrontBarContainer%(rootFrame%)") ~= nil,
    "OrbCombatIndicators exposes ResolveFrontBarContainer")
assert_true(combatIndicatorsSource:find("function CombatIndicators%.GetCombatIndicatorControls%(rootFrame%)") ~= nil,
    "OrbCombatIndicators exposes GetCombatIndicatorControls")
assert_true(combatIndicatorsSource:find("function CombatIndicators%.HideAllCombatGlows%(%)") ~= nil,
    "OrbCombatIndicators exposes HideAllCombatGlows")
assert_true(combatIndicatorsSource:find("function CombatIndicators%.ApplyCombatIndicators%(rootFrame, isInCombat, playAudioCue%)") ~= nil,
    "OrbCombatIndicators exposes ApplyCombatIndicators")

local eventsSource = read_file("Modules/ResourceOrbFrames/Core/OrbEvents.lua")
assert_true(eventsSource:find("function Events%.RefreshCombatIndicators%(rootFrame%)") ~= nil,
    "OrbEvents exposes RefreshCombatIndicators")
assert_true(eventsSource:find("function Events%.SetupCombatIndicators%(rootFrame%)") ~= nil,
    "OrbEvents exposes SetupCombatIndicators")
assert_true(eventsSource:find("function Events%.SetupVisibilityFragments%(rootFrame%)") ~= nil,
    "OrbEvents exposes SetupVisibilityFragments")
assert_true(eventsSource:find("function Events%.SetupLoopEvents%(rootFrame, pools, shieldBar, castBar%)") ~= nil,
    "OrbEvents exposes SetupLoopEvents")
assert_true(eventsSource:find("function Events%.SetupSceneHandlers%(rootFrame%)") ~= nil,
    "OrbEvents exposes SetupSceneHandlers")

if failed > 0 then
    error(string.format("test_resource_orbframes_core_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_resource_orbframes_core_support_source.lua: %d passed", passed))
