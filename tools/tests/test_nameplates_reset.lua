--[[
File: tools/tests/test_nameplates_reset.lua
Purpose: Verify disabling BetterUI nameplates restores the original runtime fonts.

Usage:
  lua tools/tests/test_nameplates_reset.lua
]]

FONT_STYLE_NORMAL = 0
FONT_STYLE_OUTLINE = 1
FONT_STYLE_THICK_OUTLINE = 2
FONT_STYLE_SHADOW = 3
FONT_STYLE_SOFT_SHADOW_THICK = 4
FONT_STYLE_SOFT_SHADOW_THIN = 5

local originalKeyboardFont = "EsoUI/Common/Fonts/OriginalKeyboard.otf|19"
local originalKeyboardStyle = FONT_STYLE_SHADOW
local originalGamepadFont = "EsoUI/Common/Fonts/OriginalGamepad.otf|21"
local originalGamepadStyle = FONT_STYLE_SOFT_SHADOW_THICK

local appliedKeyboardFont = nil
local appliedKeyboardStyle = nil
local appliedGamepadFont = nil
local appliedGamepadStyle = nil
local unregisterSuppressLog = nil

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
    },
    Nameplates = {},
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

dofile("Modules/CIM/Nameplates/Nameplates.lua")

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

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
