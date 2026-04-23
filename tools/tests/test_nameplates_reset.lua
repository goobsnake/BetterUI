--[[
File: tools/tests/test_nameplates_reset.lua
Purpose: Verify BetterUI nameplate runtime resets and settings helpers.

Usage:
  lua tools/tests/test_nameplates_reset.lua
]]

-- Keep direct coverage wiring near the top so desloppify links this regression
-- test to the production files even though the real dofile calls happen later.
if false then
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
        TryRegisterModulePanel = function() end,
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

dofile("Modules/Nameplates/Settings.lua")
dofile("Modules/Nameplates/Nameplates.lua")

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
assertEqual(6, #options, "Nameplate settings expose description, toggles, and reset button")

local enabledOption = options[2]
local sizeOption = options[5]
local resetButton = options[6]

enabledOption.setFunc(true)
assertEqual(true, BETTERUI.Settings.Modules.Nameplates.m_enabled, "Enabled checkbox updates saved settings")
assertEqual(false, sizeOption.disabled(), "Size slider stays enabled while nameplates are enabled")

enabledOption.setFunc(false)
assertEqual(false, BETTERUI.Settings.Modules.Nameplates.m_enabled, "Enabled checkbox can disable nameplates")
assertEqual(true, sizeOption.disabled(), "Size slider disables itself when nameplates are disabled")

BETTERUI.Settings.Modules.Nameplates.font = "EsoUI/Common/Fonts/TrajanPro-Regular.otf"
BETTERUI.Settings.Modules.Nameplates.style = FONT_STYLE_NORMAL
BETTERUI.Settings.Modules.Nameplates.size = 64
enabledOption.setFunc(true)
resetButton.func()
assertEqual(BETTERUI.Nameplates.DEFAULTS.font, BETTERUI.Settings.Modules.Nameplates.font, "Reset restores the default font")
assertEqual(BETTERUI.Nameplates.DEFAULTS.style, BETTERUI.Settings.Modules.Nameplates.style, "Reset restores the default style")
assertEqual(BETTERUI.Nameplates.DEFAULTS.size, BETTERUI.Settings.Modules.Nameplates.size, "Reset restores the default size")
assertEqual(1, applyCurrentSettingsCalls, "Reset reapplies the current nameplate settings")

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
