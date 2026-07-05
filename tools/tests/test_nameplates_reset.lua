--[[
File: tools/tests/test_nameplates_reset.lua
Purpose: Verify BetterUI nameplate runtime resets and settings helpers.

Usage:
  lua tools/tests/test_nameplates_reset.lua
]]

-- Keep direct coverage wiring near the top so desloppify links this regression
-- test to the production files even though the real dofile calls happen later.
if false then
    dofile("Modules/Nameplates/Positioning.lua")
    dofile("Modules/Nameplates/Settings.lua")
    dofile("Modules/Nameplates/Nameplates.lua")
end

FONT_STYLE_NORMAL = 0
FONT_STYLE_OUTLINE = 1
FONT_STYLE_THICK_OUTLINE = 2
FONT_STYLE_SHADOW = 3
FONT_STYLE_SOFT_SHADOW_THICK = 4
FONT_STYLE_SOFT_SHADOW_THIN = 5

local currentLang = "en"
local originalKeyboardFont = "EsoUI/Common/Fonts/OriginalKeyboard.otf|19"
local originalKeyboardStyle = FONT_STYLE_SHADOW
local originalGamepadFont = "EsoUI/Common/Fonts/OriginalGamepad.otf|21"
local originalGamepadStyle = FONT_STYLE_SOFT_SHADOW_THICK

local appliedKeyboardFont = nil
local appliedKeyboardStyle = nil
local appliedGamepadFont = nil
local appliedGamepadStyle = nil
local unregisterSuppressLog = nil
local applyCurrentSettingsCalls = 0

function GetString(value)
    return tostring(value)
end

function GetCVar(name)
    if name == "language.2" then
        return currentLang
    end
    return nil
end

function GetNameplateKeyboardFont()
    return originalKeyboardFont, originalKeyboardStyle
end

function GetNameplateGamepadFont()
    return originalGamepadFont, originalGamepadStyle
end

function SetNameplateKeyboardFont(font, style)
    appliedKeyboardFont = font
    appliedKeyboardStyle = style
end

function SetNameplateGamepadFont(font, style)
    appliedGamepadFont = font
    appliedGamepadStyle = style
end

BETTERUI = {
    CIM = {
        EventRegistry = {
            Register = function() end,
            UnregisterAll = function(_, suppressLog)
                unregisterSuppressLog = suppressLog
            end,
        },
        RegisterModulePanelWithLogging = function() end,
        Settings = {
            GetSettingDefault = function(_, _, fallback)
                return fallback
            end,
        },
        Font = {
            Localization = {
                GetFilteredFontChoices = function(choices)
                    return choices
                end,
                GetFilteredFontValues = function(_, values)
                    return values
                end,
                -- Mirrors the canonical helper Nameplates now consumes (HUD-003).
                WESTERN_ONLY_FONTS = {
                    ["EsoUI/Common/Fonts/Univers57.otf"] = true,
                    ["EsoUI/Common/Fonts/Univers67.otf"] = true,
                    ["EsoUI/Common/Fonts/FTN57.otf"] = true,
                    ["EsoUI/Common/Fonts/FTN47.otf"] = true,
                    ["EsoUI/Common/Fonts/FTN87.otf"] = true,
                    ["EsoUI/Common/Fonts/ProseAntiquePSMT.otf"] = true,
                    ["EsoUI/Common/Fonts/Handwritten_Bold.otf"] = true,
                    ["EsoUI/Common/Fonts/TrajanPro-Regular.otf"] = true,
                    ["EsoUI/Common/Fonts/Skyrim_Handwritten.otf"] = true,
                    ["EsoUI/Common/Fonts/consola.otf"] = true,
                },
                IsFontWesternOnly = function(fontPath)
                    return BETTERUI.CIM.Font.Localization.WESTERN_ONLY_FONTS[fontPath] == true
                end,
            },
        },
    },
    Nameplates = {},
    ClampInteger = function(value, minValue, maxValue, fallback)
        local numericValue = tonumber(value)
        if numericValue == nil then
            return fallback
        end
        if minValue and numericValue < minValue then
            return minValue
        end
        if maxValue and numericValue > maxValue then
            return maxValue
        end
        return numericValue
    end,
    Settings = {
        Modules = {
            Nameplates = {
                m_enabled = true,
                font = "EsoUI/Common/Fonts/CustomNameplate.otf",
                style = FONT_STYLE_OUTLINE,
                size = 28,
            },
        },
    },
}

function BETTERUI.GetModuleSettings(moduleName)
    return BETTERUI.Settings.Modules[moduleName]
end

function BETTERUI.GetModuleSettingsLive(moduleName)
    return BETTERUI.Settings.Modules[moduleName]
end

function BETTERUI.EnsureModuleSettings(moduleName)
    BETTERUI.Settings.Modules[moduleName] = BETTERUI.Settings.Modules[moduleName] or {}
    return BETTERUI.Settings.Modules[moduleName]
end

local testsPassed = 0
local testsFailed = 0

local function assertEqual(expected, actual, message)
    if expected == actual then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

print("\n=== Nameplates Reset Tests ===\n")

dofile("Modules/Nameplates/Positioning.lua")
dofile("Modules/Nameplates/Settings.lua")
dofile("Modules/Nameplates/Nameplates.lua")

local realApplyCurrentSettings = BETTERUI.Nameplates.ApplyCurrentSettings
BETTERUI.Nameplates.ApplyCurrentSettings = function()
    applyCurrentSettingsCalls = applyCurrentSettingsCalls + 1
end

print("Test: Disabling nameplates restores original runtime fonts")
BETTERUI.Nameplates.Setup()
assertEqual("EsoUI/Common/Fonts/CustomNameplate.otf|28", appliedKeyboardFont, "Custom keyboard font applied while enabled")
assertEqual(FONT_STYLE_OUTLINE, appliedKeyboardStyle, "Custom keyboard style applied while enabled")
assertEqual("EsoUI/Common/Fonts/CustomNameplate.otf|28", appliedGamepadFont, "Custom gamepad font applied while enabled")
assertEqual(FONT_STYLE_OUTLINE, appliedGamepadStyle, "Custom gamepad style applied while enabled")

BETTERUI.Settings.Modules.Nameplates.m_enabled = false
BETTERUI.Nameplates.OnEnabledChanged(false, true)
assertEqual(originalKeyboardFont, appliedKeyboardFont, "Original keyboard font restored on disable")
assertEqual(originalKeyboardStyle, appliedKeyboardStyle, "Original keyboard style restored on disable")
assertEqual(originalGamepadFont, appliedGamepadFont, "Original gamepad font restored on disable")
assertEqual(originalGamepadStyle, appliedGamepadStyle, "Original gamepad style restored on disable")
assertEqual(true, unregisterSuppressLog, "Reset-triggered disable suppresses event cleanup chat")

print("\nTest: Nameplate settings options drive live updates")
local options = BETTERUI.Nameplates.GetSettingsOptions()
-- The position movers relocated to the General tab (2026-07-04): the panel
-- keeps only the text controls + appearance reset, and the movers are
-- exposed for the General composer via GetPositionSettingsOptions().
assertEqual(6, #options, "Nameplate settings keep text controls and the appearance reset button")
local positionOptions = BETTERUI.Nameplates.GetPositionSettingsOptions()
assertEqual(27, #positionOptions, "Position movers are exposed for the General tab composer without the reticle prompt")

local enabledOption = options[2]
local sizeOption = options[5]
local function FindPositionOption(optionKey)
    for _, option in ipairs(positionOptions) do
        if option.key == optionKey then return option end
    end
    error("position option not found: " .. tostring(optionKey))
end

local unlockPositions = FindPositionOption("nameplatePositionsUnlocked")
local moveCompass = FindPositionOption("moveCompassFrame")
local compassX = FindPositionOption("compassFrameOffsetX")
local moveTargetBar = FindPositionOption("moveTargetBar")
local targetBarY = FindPositionOption("targetBarOffsetY")
local movePlayerInteract = FindPositionOption("movePlayerInteract")
local playerInteractX = FindPositionOption("playerInteractOffsetX")
local moveQuestTracker = FindPositionOption("moveQuestTracker")
local questTrackerX = FindPositionOption("questTrackerOffsetX")
local moveGroupFrames = FindPositionOption("moveGroupFrames")
local groupFramesY = FindPositionOption("groupFramesOffsetY")
local compassScale = FindPositionOption("compassFrameScale")
local resetPositionsButton = FindPositionOption("resetPositions")
local resetButton = options[6]

enabledOption.setFunc(true)
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.m_enabled, "Enabled checkbox updates saved settings")
assertEqual(false, sizeOption.disabled(), "Size slider stays enabled while nameplates are enabled")
assertEqual(false, unlockPositions.disabled(), "Position unlock is available while nameplates are enabled")
unlockPositions.setFunc(true)
moveCompass.setFunc(true)
compassX.setFunc(75)
moveTargetBar.setFunc(true)
targetBarY.setFunc(42)
movePlayerInteract.setFunc(true)
playerInteractX.setFunc(-18)
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.nameplatePositionsUnlocked, "Unlock checkbox updates saved settings")
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.moveCompassFrame, "Compass mover checkbox updates saved settings")
assertEqual(75, BETTERUI.Settings.Modules.Nameplates.compassFrameOffsetX, "Compass X slider updates saved settings")
assertEqual(nil, BETTERUI.Settings.Modules.Nameplates.moveReticlePrompt, "Reticle mover checkbox is no longer seeded by position settings")
assertEqual(nil, BETTERUI.Settings.Modules.Nameplates.reticlePromptOffsetY, "Reticle Y slider is no longer seeded by position settings")
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.moveTargetBar, "Target/NPC bar mover checkbox updates saved settings")
assertEqual(42, BETTERUI.Settings.Modules.Nameplates.targetBarOffsetY, "Target/NPC bar Y slider updates saved settings")
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.movePlayerInteract, "Player-interact mover checkbox updates saved settings")
assertEqual(-18, BETTERUI.Settings.Modules.Nameplates.playerInteractOffsetX, "Player-interact X slider updates saved settings")
moveQuestTracker.setFunc(true)
questTrackerX.setFunc(25)
moveGroupFrames.setFunc(true)
groupFramesY.setFunc(-40)
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.moveQuestTracker, "Quest tracker mover checkbox updates saved settings")
assertEqual(25, BETTERUI.Settings.Modules.Nameplates.questTrackerOffsetX, "Quest tracker X slider updates saved settings")
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.moveGroupFrames, "Companion/group mover checkbox updates saved settings")
assertEqual(-40, BETTERUI.Settings.Modules.Nameplates.groupFramesOffsetY, "Companion/group Y slider updates saved settings")
compassScale.setFunc(1.25)
assertEqual(1.25, BETTERUI.Settings.Modules.Nameplates.compassFrameScale, "Compass scale slider updates saved settings")
FindPositionOption("resetCompassFrame").func()
assertEqual(0, BETTERUI.Settings.Modules.Nameplates.compassFrameOffsetX, "Element reset clears compass X")
assertEqual(1, BETTERUI.Settings.Modules.Nameplates.compassFrameScale, "Element reset restores compass scale")
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.moveCompassFrame, "Element reset leaves the compass Move toggle alone")
assertEqual(42, BETTERUI.Settings.Modules.Nameplates.targetBarOffsetY, "Element reset leaves other elements untouched")

enabledOption.setFunc(false)
assertEqual(false, BETTERUI.Settings.Modules.Nameplates.m_enabled, "Enabled checkbox can disable nameplates")
assertEqual(true, sizeOption.disabled(), "Size slider disables itself when nameplates are disabled")
assertEqual(false, unlockPositions.disabled(), "General HUD position unlock remains available when Enhanced Nameplates is disabled")
assertEqual(false, moveCompass.disabled(), "Compass mover toggle remains available when Enhanced Nameplates is disabled")
assertEqual(false, compassX.disabled(), "Position sliders remain enabled when their HUD element is enabled")

BETTERUI.Settings.Modules.Nameplates.font = "EsoUI/Common/Fonts/TrajanPro-Regular.otf"
BETTERUI.Settings.Modules.Nameplates.style = FONT_STYLE_NORMAL
BETTERUI.Settings.Modules.Nameplates.size = 64
enabledOption.setFunc(true)
resetPositionsButton.func()
assertEqual(false, BETTERUI.Settings.Modules.Nameplates.nameplatePositionsUnlocked, "Position reset relocks movement")
assertEqual(false, BETTERUI.Settings.Modules.Nameplates.moveCompassFrame, "Position reset disables compass movement")
assertEqual(0, BETTERUI.Settings.Modules.Nameplates.compassFrameOffsetX, "Position reset clears compass X")
assertEqual(false, BETTERUI.Settings.Modules.Nameplates.moveTargetBar, "Position reset disables target/NPC bar movement")
assertEqual(0, BETTERUI.Settings.Modules.Nameplates.targetBarOffsetY, "Position reset clears target/NPC bar Y")
assertEqual(false, BETTERUI.Settings.Modules.Nameplates.movePlayerInteract, "Position reset disables player-interact movement")
assertEqual(0, BETTERUI.Settings.Modules.Nameplates.playerInteractOffsetX, "Position reset clears player-interact X")
assertEqual(1, BETTERUI.Settings.Modules.Nameplates.compassFrameScale, "Position reset restores the compass scale")
BETTERUI.Settings.Modules.Nameplates.nameplatePositionsUnlocked = true
BETTERUI.Settings.Modules.Nameplates.moveCompassFrame = true
BETTERUI.Settings.Modules.Nameplates.compassFrameOffsetY = 88
BETTERUI.Settings.Modules.Nameplates.moveTargetBar = true
BETTERUI.Settings.Modules.Nameplates.targetBarOffsetX = 33
BETTERUI.Settings.Modules.Nameplates.movePlayerInteract = true
BETTERUI.Settings.Modules.Nameplates.playerInteractOffsetY = -55
applyCurrentSettingsCalls = 0
resetButton.func()
assertEqual(BETTERUI.Nameplates.DEFAULTS.font, BETTERUI.Settings.Modules.Nameplates.font, "Reset restores the default font")
assertEqual(BETTERUI.Nameplates.DEFAULTS.style, BETTERUI.Settings.Modules.Nameplates.style, "Reset restores the default style")
assertEqual(BETTERUI.Nameplates.DEFAULTS.size, BETTERUI.Settings.Modules.Nameplates.size, "Reset restores the default size")
-- Position keys belong to the General-tab movers now: the appearance reset
-- must NOT touch them (the dedicated resetPositions button, asserted above,
-- owns that), so cross-tab tuning survives an appearance reset.
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.nameplatePositionsUnlocked, "Appearance reset leaves position lock alone")
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.moveCompassFrame, "Appearance reset leaves compass mover alone")
assertEqual(88, BETTERUI.Settings.Modules.Nameplates.compassFrameOffsetY, "Appearance reset leaves compass Y offset alone")
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.moveTargetBar, "Appearance reset leaves target/NPC bar mover alone")
assertEqual(33, BETTERUI.Settings.Modules.Nameplates.targetBarOffsetX, "Appearance reset leaves target/NPC bar X offset alone")
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.movePlayerInteract, "Appearance reset leaves player-interact mover alone")
assertEqual(-55, BETTERUI.Settings.Modules.Nameplates.playerInteractOffsetY, "Appearance reset leaves player-interact Y offset alone")
assertEqual(1, applyCurrentSettingsCalls, "Reset reapplies the current nameplate settings")

print("\nTest: Lifecycle apply path migrates legacy string style settings before getters read them")
BETTERUI.Settings.Modules.Nameplates.style = "outline"
realApplyCurrentSettings()
assertEqual(FONT_STYLE_OUTLINE, BETTERUI.Settings.Modules.Nameplates.style,
    "ApplyCurrentSettings migrates legacy string style settings on the live table")
assertEqual(FONT_STYLE_OUTLINE, appliedKeyboardStyle,
    "ApplyCurrentSettings uses the migrated style enum when reapplying the font")

print("\nTest: InitModule clamps size and migrates western fonts for non-English clients")
currentLang = "jp"
local migrated = BETTERUI.Nameplates.InitModule({
    m_enabled = true,
    font = "EsoUI/Common/Fonts/Univers57.otf",
    style = FONT_STYLE_OUTLINE,
    size = 999,
})
assertEqual("$(BOLD_FONT)", migrated.font, "Non-English users migrate western-only fonts to the localized bold font")
assertEqual(64, migrated.size, "InitModule clamps oversize nameplate settings")

currentLang = "en"
local preserved = BETTERUI.Nameplates.InitModule({
    m_enabled = true,
    font = "EsoUI/Common/Fonts/Univers57.otf",
    style = FONT_STYLE_OUTLINE,
    size = 1,
})
assertEqual("EsoUI/Common/Fonts/Univers57.otf", preserved.font, "English clients preserve western font selections")
assertEqual(8, preserved.size, "InitModule clamps undersized nameplate settings to the supported minimum")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
