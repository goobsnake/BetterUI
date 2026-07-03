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
local quickslotBlock = constantsSource:match("quickslot = %{%s*.-%s*%},")
local quickslotX = quickslotBlock and tonumber(quickslotBlock:match("x = ([%-0-9]+)"))
local quickslotY = quickslotBlock and tonumber(quickslotBlock:match("y = ([%-0-9]+)"))
assert_true(quickslotX == 270,
    "ROF Constants quickslot default sits a few pixels farther left of the lower-row placement")
assert_true(quickslotY == -48,
    "ROF Constants quickslot default raises the icon between the top and bottom skill rows")

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
assert_true(eventsSource:find('local NAME = "BETTERUI_ResourceOrbFrames"', 1, true) ~= nil,
    "OrbEvents prefixes its EVENT_MANAGER namespace suffixes")
assert_true(eventsSource:find('local NAME = "ResourceOrbFrames"', 1, true) == nil,
    "OrbEvents does not build EVENT_MANAGER namespaces from the bare module name")
assert_true(eventsSource:find("function Events%.SetLoopsEnabled%(enabled%)") ~= nil,
    "OrbEvents exposes SetLoopsEnabled")
assert_true(eventsSource:find("function Events%.RequestCooldownVisualScan%(%)") ~= nil,
    "OrbEvents exposes an event-level cooldown scan rearm helper")
assert_true(eventsSource:find("EVENT_ACTION_UPDATE_COOLDOWNS", 1, true) ~= nil,
    "OrbEvents listens for cooldown update events so idle latches can rearm")
assert_true(eventsSource:find('NAME %.%. "_CooldownAbilityUsed"') ~= nil,
    "OrbEvents registers ability-used cooldown scan requests under a prefixed namespace")
assert_true(eventsSource:find("IsCooldownVisualsArmed") ~= nil,
    "OrbEvents references the cooldown visuals armed latch")
assert_true(eventsSource:find("L%.EnabledFor%(L%.LEVEL%.DEBUG, L%.CATEGORY%.STATE%)") ~= nil,
    "OrbEvents trace wrapper preflights with EnabledFor before building payload")
assert_true(eventsSource:find('NAME %.%. "_PlayerDead"') ~= nil,
    "OrbEvents consolidates EVENT_PLAYER_DEAD under a single namespace")
assert_true(eventsSource:find('NAME %.%. "_PlayerAlive", EVENT_PLAYER_ALIVE, OnPlayerAlive') ~= nil,
    "OrbEvents re-enforces native hide state on EVENT_PLAYER_ALIVE")

local orbBarsSource = read_file("Modules/ResourceOrbFrames/Core/OrbBars.lua")
assert_true(orbBarsSource:find('EventRegistry%.Register%("BETTERUI_ResourceOrbFrames"') ~= nil,
    "OrbBars uses BETTERUI_ prefixed EventRegistry namespaces")
assert_true(orbBarsSource:find('EventRegistry%.Register%("ResourceOrbFrames"') == nil,
    "OrbBars has no bare ResourceOrbFrames EventRegistry namespaces")
assert_true(orbBarsSource:find('local NAME = "BETTERUI_ResourceOrbFrames"', 1, true) ~= nil,
    "OrbBars prefixes its EVENT_MANAGER namespace suffixes")

local orbVisualsSource = read_file("Modules/ResourceOrbFrames/Core/OrbVisuals.lua")
assert_true(orbVisualsSource:find('EventRegistry%.RegisterFiltered%("BETTERUI_ResourceOrbFrames"') ~= nil,
    "OrbVisuals uses BETTERUI_ prefixed EventRegistry namespaces")
assert_true(orbVisualsSource:find('EventRegistry%.RegisterFiltered%("ResourceOrbFrames"') == nil,
    "OrbVisuals has no bare ResourceOrbFrames EventRegistry namespaces")
assert_true(orbVisualsSource:find('local NAME = "BETTERUI_ResourceOrbFrames"', 1, true) ~= nil,
    "OrbVisuals prefixes its EVENT_MANAGER namespace suffixes")

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
assert_true(resourceOrbFramesSource:find('local NAME = "BETTERUI_ResourceOrbFrames"', 1, true) ~= nil,
    "ROF root prefixes its EVENT_MANAGER namespace suffixes")
assert_true(resourceOrbFramesSource:find('EventRegistry.Unregister("BETTERUI_ResourceOrbFrames", NAME .. "_InitSetup"', 1, true) ~= nil,
    "ROF root unregisters the one-shot init handler using the tracked module key")
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

local moduleSource = read_file("Modules/ResourceOrbFrames/Module.lua")
assert_true(moduleSource:find('elementPositionsUnlocked = CreateSettingContract%("elementPositionsUnlocked", false%)') ~= nil,
    "ROF settings module exposes a global element-position unlock contract")
assert_true(moduleSource:find("drag%.SetAllElementsUnlocked%(unlocked, GetLiveResourceOrbSettings%)") ~= nil,
    "ROF global unlock setting refreshes all drag handles")
assert_true(moduleSource:find('generalContracts%.elementPositionsUnlocked%.get') ~= nil,
    "ROF top-level position unlock checkbox reads the global unlock contract")
assert_false(moduleSource:find('getFunc = generalContracts%.enableIndependentOrbOffset%.get') ~= nil,
    "ROF settings panel no longer exposes the legacy independent orb offset toggle")

local submenuSource = read_file("Modules/ResourceOrbFrames/Settings/SettingsSubmenus.lua")
assert_true(submenuSource:find("local function AreElementPositionsUnlocked%(shared%)") ~= nil,
    "ROF settings submenus gate element sliders from the global unlock")
assert_true(submenuSource:find("shared%.globalUnlock%.get") ~= nil,
    "ROF settings submenus render one shared unlock control for element positions")
assert_false(submenuSource:find("getFunc = c%.locked%.get") ~= nil,
    "ROF settings submenus no longer render per-element lock checkboxes")

local elementDragSource = read_file("Modules/ResourceOrbFrames/Core/ElementDrag.lua")
assert_true(elementDragSource:find("function Drag%.SetAllElementsUnlocked%(unlocked, settingsGetter%)") ~= nil,
    "ROF element drag exposes a global handle unlock helper")
assert_true(elementDragSource:find('reason = ep and "globalLock" or "missingElementPosition"') ~= nil,
    "ROF element drag rejects mouse-down while the global lock is active")

if failed > 0 then
    error(string.format("test_resource_orbframes_core_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_resource_orbframes_core_support_source.lua: %d passed", passed))
