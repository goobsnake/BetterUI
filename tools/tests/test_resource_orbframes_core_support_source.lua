--[[
File: tools/tests/test_resource_orbframes_core_support_source.lua
Purpose: Source-level regression checks for ResourceOrbFrames constants and core helper modules.

Usage:
  lua tools/tests/test_resource_orbframes_core_support_source.lua
]]

if false then
    dofile("Modules/ResourceOrbFrames/Constants.lua")
    dofile("Modules/ResourceOrbFrames/Core/OrbAnimations.lua")
    dofile("Modules/ResourceOrbFrames/Core/OrbBarUpdates.lua")
    dofile("Modules/ResourceOrbFrames/Core/OrbCombatIndicators.lua")
    dofile("Modules/ResourceOrbFrames/Core/OrbEvents.lua")
end

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

local function assert_false(value, label)
    assert_true(not value, label)
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
assert_true(combatIndicatorsSource:find("local function GetControlTraceName%(control%)") ~= nil,
    "OrbCombatIndicators has local trace-name helper used by combat icon diagnostics")
assert_true(combatIndicatorsSource:find("local function DescribeControlForTrace%(control, label%)") ~= nil,
    "OrbCombatIndicators can describe controls without depending on the root module")
assert_true(combatIndicatorsSource:find("local function CallOptionalControlMethod%(control, methodName, %.%.%.%)") ~= nil,
    "OrbCombatIndicators guards optional texture-control methods")
assert_true(combatIndicatorsSource:find("didSetTextureCoords = didSetTextureCoords") ~= nil,
    "OrbCombatIndicators logs optional combat-icon texture method availability")

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
assert_true(eventsSource:find('EventRegistry%.Register%("BETTERUI_ResourceOrbFrames"') ~= nil,
    "OrbEvents uses BETTERUI_ prefixed EventRegistry namespaces")
assert_true(eventsSource:find('EventRegistry%.Register%("ResourceOrbFrames"') == nil,
    "OrbEvents has no bare ResourceOrbFrames EventRegistry namespaces")
assert_true(eventsSource:find("function Events%.SetLoopsEnabled%(enabled%)") ~= nil,
    "OrbEvents exposes SetLoopsEnabled")
assert_true(eventsSource:find("IsCooldownVisualsArmed") ~= nil,
    "OrbEvents references the cooldown visuals armed latch")
assert_true(eventsSource:find("L%.EnabledFor%(L%.LEVEL%.DEBUG, L%.CATEGORY%.STATE%)") ~= nil,
    "OrbEvents trace wrapper preflights with EnabledFor before building payload")
assert_true(eventsSource:find('NAME %.%. "_PlayerDead"') ~= nil,
    "OrbEvents consolidates EVENT_PLAYER_DEAD under a single namespace")

local orbBarsSource = read_file("Modules/ResourceOrbFrames/Core/OrbBars.lua")
assert_true(orbBarsSource:find('EventRegistry%.Register%("BETTERUI_ResourceOrbFrames"') ~= nil,
    "OrbBars uses BETTERUI_ prefixed EventRegistry namespaces")
assert_true(orbBarsSource:find('EventRegistry%.Register%("ResourceOrbFrames"') == nil,
    "OrbBars has no bare ResourceOrbFrames EventRegistry namespaces")

local orbVisualsSource = read_file("Modules/ResourceOrbFrames/Core/OrbVisuals.lua")
assert_true(orbVisualsSource:find('EventRegistry%.RegisterFiltered%("BETTERUI_ResourceOrbFrames"') ~= nil,
    "OrbVisuals uses BETTERUI_ prefixed EventRegistry namespaces")
assert_true(orbVisualsSource:find('EventRegistry%.RegisterFiltered%("ResourceOrbFrames"') == nil,
    "OrbVisuals has no bare ResourceOrbFrames EventRegistry namespaces")

local frontBarCooldownsSource = read_file("Modules/ResourceOrbFrames/SkillBar/FrontBarCooldowns.lua")
assert_true(frontBarCooldownsSource:find("L%.EnabledFor%(L%.LEVEL%.DEBUG, L%.CATEGORY%.ACTION%)") ~= nil,
    "FrontBarCooldowns trace wrapper preflights with EnabledFor before building payload")
assert_true(frontBarCooldownsSource:find("ReportButtonCooldownState") ~= nil,
    "FrontBarCooldowns reports per-button cooldown transitions through the armed latch helper")

local backBarManagerSource = read_file("Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua")
assert_true(backBarManagerSource:find("ReportButtonCooldownState") ~= nil,
    "BackBarManager reports per-button cooldown transitions through the armed latch helper")

local resourceOrbFramesSource = read_file("Modules/ResourceOrbFrames/ResourceOrbFrames.lua")
assert_true(resourceOrbFramesSource:find('EventRegistry%.Register%("BETTERUI_ResourceOrbFrames"') ~= nil,
    "ROF root uses BETTERUI_ prefixed EventRegistry namespaces")
assert_true(resourceOrbFramesSource:find('EventRegistry%.Register%("ResourceOrbFrames"') == nil,
    "ROF root has no bare ResourceOrbFrames EventRegistry namespaces")
assert_true(resourceOrbFramesSource:find('EventRegistry%.RegisterFiltered%("ResourceOrbFrames"') == nil,
    "ROF root has no bare ResourceOrbFrames filtered EventRegistry namespaces")
assert_true(resourceOrbFramesSource:find("local function GetROFDeferredTaskRuntime%(%)") ~= nil,
    "ROF root resolves DeferredTask through a lazy runtime getter")
assert_true(resourceOrbFramesSource:find("local function GetROFTasks%(%)") ~= nil,
    "ROF root resolves its lazy task proxy through a helper")
assert_false(resourceOrbFramesSource:find("local ROFDeferredTask = assert%(BETTERUI%.CIM and BETTERUI%.CIM%.DeferredTask,") ~= nil,
    "ROF root no longer asserts CIM.DeferredTask at import time")
assert_true(resourceOrbFramesSource:find("ResourceOrbFrames%.Tasks = ResourceOrbFrames%.Tasks or GetROFDeferredTaskRuntime%(%)%.CreateLazyManagerProxy%(EnsureResourceOrbFramesTaskManager%)") ~= nil,
    "ROF root builds the task proxy only when the helper first resolves runtime services")
assert_true(resourceOrbFramesSource:find("GetROFTasks%(%):Schedule%(") ~= nil,
    "ROF deferred scheduling flows through the lazy task accessor")

assert_true(resourceOrbFramesSource:find("ResourceOrbFrames%.EnsureTaskManager = EnsureResourceOrbFramesTaskManager") ~= nil,
    "ROF root still exposes EnsureTaskManager after the lazy-binding refactor")

if failed > 0 then
    error(string.format("test_resource_orbframes_core_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_resource_orbframes_core_support_source.lua: %d passed", passed))
