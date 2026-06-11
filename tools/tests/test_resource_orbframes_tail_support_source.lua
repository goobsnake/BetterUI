--[[
File: tools/tests/test_resource_orbframes_tail_support_source.lua
Purpose: Source-level regression checks for the remaining ResourceOrbFrames support modules.

Usage:
  lua tools/tests/test_resource_orbframes_tail_support_source.lua
]]

if false then
    dofile("Modules/ResourceOrbFrames/Core/OrbOverlays.lua")
    dofile("Modules/ResourceOrbFrames/Core/OrbVisuals.lua")
    dofile("Modules/ResourceOrbFrames/Core/Utils.lua")
    dofile("Modules/ResourceOrbFrames/Settings/Defaults.lua")
    dofile("Modules/ResourceOrbFrames/Settings/SettingsSubmenus.lua")
    dofile("Modules/ResourceOrbFrames/SkillBar/Constants.lua")
    dofile("Modules/ResourceOrbFrames/SkillBar/CooldownUtils.lua")
    dofile("Modules/ResourceOrbFrames/SkillBar/Coordinator.lua")
    dofile("Modules/ResourceOrbFrames/SkillBar/TooltipManager.lua")
    dofile("Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua")
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

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local overlaysSource = read_file("Modules/ResourceOrbFrames/Core/OrbOverlays.lua")
assert_true(overlaysSource:find("Those definitions have been removed%. All callers now use the OrbVisuals%.lua versions%.") ~= nil,
    "OrbOverlays documents that the duplicate visual helpers were removed")
assert_true(overlaysSource:find("CustomOverlay") ~= nil,
    "OrbOverlays documents the removed hide-ornament CustomOverlay path")

local visualsSource = read_file("Modules/ResourceOrbFrames/Core/OrbVisuals.lua")
assert_true(visualsSource:find("BetterUIOrbBar = ZO_Object:Subclass%(%)") ~= nil,
    "OrbVisuals defines BetterUIOrbBar")
assert_true(visualsSource:find("function BetterUIOrbBar:Initialize%(control, powerType%)") ~= nil,
    "OrbVisuals exposes BetterUIOrbBar Initialize")
assert_true(visualsSource:find("function BetterUIOrbBar:UpdateAnimation%(deltaMs, settings%)") ~= nil,
    "OrbVisuals exposes BetterUIOrbBar UpdateAnimation")
assert_true(visualsSource:find("function BetterUIShieldBar:RefreshVisuals%(%)") ~= nil,
    "OrbVisuals exposes BetterUIShieldBar RefreshVisuals")
assert_true(visualsSource:find("function Visuals%.UpdateFrameDimensions%(rootFrame%)") ~= nil,
    "OrbVisuals exposes UpdateFrameDimensions")
assert_true(visualsSource:find("function Visuals%.ApplyThemeVisuals%(rootFrame%)") ~= nil,
    "OrbVisuals exposes ApplyThemeVisuals")
assert_true(visualsSource:find("function Visuals%.UpdateOrbLayout%(rootFrame, pools, shieldBar%)") ~= nil,
    "OrbVisuals exposes UpdateOrbLayout")
assert_true(visualsSource:find("function Visuals%.SetupPowerPools%(rootFrame%)") ~= nil,
    "OrbVisuals exposes SetupPowerPools")
assert_true(visualsSource:find("function Visuals%.SetupShieldBar%(rootFrame, pools%)") ~= nil,
    "OrbVisuals exposes SetupShieldBar")

local utilsSource = read_file("Modules/ResourceOrbFrames/Core/Utils.lua")
assert_true(utilsSource:find("function Utils%.ClampTextSize%(value, minValue, maxValue, fallback%)") ~= nil,
    "ROF Utils exposes ClampTextSize")
assert_true(utilsSource:find("function Settings%.Get%(%)") ~= nil,
    "ROF Utils exposes Settings.Get")
assert_true(utilsSource:find("function Settings%.Ensure%(%)") ~= nil,
    "ROF Utils exposes Settings.Ensure")
assert_true(utilsSource:find("function Tooltips%.AddOrbTooltip%(control, powerType%)") ~= nil,
    "ROF Utils exposes AddOrbTooltip")
assert_true(utilsSource:find("function Layout%.CalculateBorderSizes%(cfg, settings%)") ~= nil,
    "ROF Utils exposes CalculateBorderSizes")
assert_true(utilsSource:find("UpdateOverlaySize") == nil,
    "ROF Utils no longer defines the dead UpdateOverlaySize helper")
assert_true(utilsSource:find("function Controls%.GetFrontBarButtonControl%(rootFrame, frontBarContainer, buttonName%)") ~= nil,
    "ROF Utils exposes GetFrontBarButtonControl")
assert_true(utilsSource:find("Utils%.GetFrontBarButtonControl = Controls%.GetFrontBarButtonControl") ~= nil,
    "ROF Utils re-exports the front bar button helper")

local defaultsSource = read_file("Modules/ResourceOrbFrames/Settings/Defaults.lua")
assert_true(defaultsSource:find("local function GetDefaults%(%)") ~= nil,
    "ROF Defaults defines GetDefaults")
assert_true(defaultsSource:find("local function InitializeDefaults%(m_options%)") ~= nil,
    "ROF Defaults defines InitializeDefaults")
assert_true(defaultsSource:find("BETTERUI%.ResourceOrbFrames%.InitializeDefaults = InitializeDefaults") ~= nil,
    "ROF Defaults exports InitializeDefaults")
assert_true(defaultsSource:find("BETTERUI%.ResourceOrbFrames%.GetDefaults = GetDefaults") ~= nil,
    "ROF Defaults exports GetDefaults")
assert_true(defaultsSource:find("Delegated defaults helper for ResourceOrbFrames%.InitModule%.") ~= nil,
    "ROF Defaults documents that Module.lua owns the public init hook")

local settingsSubmenusSource = read_file("Modules/ResourceOrbFrames/Settings/SettingsSubmenus.lua")
assert_true(settingsSubmenusSource:find("BETTERUI%.ResourceOrbFrames%.SettingsSubmenus = %{%}") ~= nil,
    "SettingsSubmenus initializes the submenu namespace")
assert_true(settingsSubmenusSource:find("function Submenus%.BuildSkillBarsSubmenu%(skillBars, shared%)") ~= nil,
    "SettingsSubmenus exposes BuildSkillBarsSubmenu")
assert_true(settingsSubmenusSource:find("function Submenus%.BuildOrbTextSubmenu%(orbText, shared%)") ~= nil,
    "SettingsSubmenus exposes BuildOrbTextSubmenu")
assert_true(settingsSubmenusSource:find("function Submenus%.BuildBarSubmenus%(bars, shared%)") ~= nil,
    "SettingsSubmenus exposes BuildBarSubmenus")
assert_true(settingsSubmenusSource:find("function Submenus%.ApplySubmenuSectionOrdering%(optionsTable%)") ~= nil,
    "SettingsSubmenus exposes ApplySubmenuSectionOrdering")

local skillBarConstantsSource = read_file("Modules/ResourceOrbFrames/SkillBar/Constants.lua")
assert_true(skillBarConstantsSource:find("BETTERUI%.ResourceOrbFrames%.SkillBar%.CONST = %{%s*") ~= nil,
    "SkillBar Constants defines the CONST table")
assert_true(skillBarConstantsSource:find("FRONT_BAR_SLOTS = %{%s*") ~= nil,
    "SkillBar Constants defines FRONT_BAR_SLOTS")
assert_true(skillBarConstantsSource:find("BACK_BAR_SLOTS = %{%s*3, 4, 5, 6, 7, 8 %}") ~= nil,
    "SkillBar Constants defines BACK_BAR_SLOTS")
assert_true(skillBarConstantsSource:find("COOLDOWN_DURATION_THRESHOLD = 1500") ~= nil,
    "SkillBar Constants defines COOLDOWN_DURATION_THRESHOLD")

local cooldownUtilsSource = read_file("Modules/ResourceOrbFrames/SkillBar/CooldownUtils.lua")
assert_true(cooldownUtilsSource:find("function CooldownUtils%.BuildStateKey%(slotIndex, hotbarCategory%)") ~= nil,
    "CooldownUtils exposes BuildStateKey")
assert_true(cooldownUtilsSource:find("function CooldownUtils%.ResolveCooldownWindow%(slotIndex, hotbarCategory, canTrack%)") ~= nil,
    "CooldownUtils exposes ResolveCooldownWindow")
assert_true(cooldownUtilsSource:find("function CooldownUtils%.GetSmoothedRemaining%(stateKey, remainMs, durationMs%)") ~= nil,
    "CooldownUtils exposes GetSmoothedRemaining")
assert_true(cooldownUtilsSource:find("function CooldownUtils%.ApplyLinearVisuals%(cooldownEdge, cooldownOverlay, revealControl, remainMs, durationMs%)") ~= nil,
    "CooldownUtils exposes ApplyLinearVisuals")
assert_true(cooldownUtilsSource:find("SkillBar%.CooldownUtils = CooldownUtils") ~= nil,
    "CooldownUtils exports itself onto the SkillBar namespace")

local coordinatorSource = read_file("Modules/ResourceOrbFrames/SkillBar/Coordinator.lua")
assert_true(coordinatorSource:find("SkillBar%.UpdateBarPositions = UpdateBarPositions") ~= nil,
    "Coordinator exports UpdateBarPositions")
assert_true(coordinatorSource:find("SkillBar%.UpdateMainBarLayout = UpdateMainBarLayout") ~= nil,
    "Coordinator exports UpdateMainBarLayout")
assert_true(coordinatorSource:find("SkillBar%.ApplyActionBarSkin = ApplyActionBarSkin") ~= nil,
    "Coordinator exports ApplyActionBarSkin")
assert_true(coordinatorSource:find("SkillBar%.WeaponSwapAnimation = WeaponSwapAnimation") ~= nil,
    "Coordinator exports WeaponSwapAnimation")
assert_true(coordinatorSource:find("SkillBar%.IsWeaponSwapAnimating = IsWeaponSwapAnimating") ~= nil,
    "Coordinator exports IsWeaponSwapAnimating")

local tooltipManagerSource = read_file("Modules/ResourceOrbFrames/SkillBar/TooltipManager.lua")
assert_true(tooltipManagerSource:find("local function SetupButtonTooltip%(control, slotIndex, category, point, offsetX, offsetY%)") ~= nil,
    "TooltipManager defines SetupButtonTooltip")
assert_true(tooltipManagerSource:find("SkillBar%.SetupButtonTooltip = SetupButtonTooltip") ~= nil,
    "TooltipManager exports SetupButtonTooltip")

local ultimateManagerSource = read_file("Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua")
assert_true(ultimateManagerSource:find("local function ApplyUltimateTextAnchor%(ultimateButtonControl, ultimateTextControl%)") ~= nil,
    "UltimateManager defines ApplyUltimateTextAnchor")
assert_true(ultimateManagerSource:find("local function UpdateFrontBarUltimateMeter%(rootFrame%)") ~= nil,
    "UltimateManager defines UpdateFrontBarUltimateMeter")
assert_true(ultimateManagerSource:find("local function UpdateFrontBarUltimateNumber%(rootFrame%)") ~= nil,
    "UltimateManager defines UpdateFrontBarUltimateNumber")
assert_true(ultimateManagerSource:find("SkillBar%.PlayUltimateReadyAnimations = PlayUltimateReadyAnimations") ~= nil,
    "UltimateManager exports PlayUltimateReadyAnimations")
assert_true(ultimateManagerSource:find("SkillBar%.UpdateFrontBarUltimateMeter = UpdateFrontBarUltimateMeter") ~= nil,
    "UltimateManager exports UpdateFrontBarUltimateMeter")
assert_true(ultimateManagerSource:find("SkillBar%.UpdateFrontBarUltimateNumber = UpdateFrontBarUltimateNumber") ~= nil,
    "UltimateManager exports UpdateFrontBarUltimateNumber")

if failed > 0 then
    error(string.format("test_resource_orbframes_tail_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_resource_orbframes_tail_support_source.lua: %d passed", passed))
