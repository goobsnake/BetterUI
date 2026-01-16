---------------------------------------------------------------------------------------------------
-- BetterUI - Enhanced Nameplates
--
-- This module allows customization of nameplate fonts, styles, and sizes.
-- It supports:
-- 1. Font Selection: Choose from various built-in ESO fonts.
-- 2. Style Control: Adjust outline, shadow, and other font effects.
-- 3. Size Adjustment: Scale nameplates to preferred size.
-- 4. Cross-Mode Support: Applies settings to both Keyboard and Gamepad modes.
---------------------------------------------------------------------------------------------------

-- Note: ESO Update 41+ uses .slug fonts; only built-in ESO fonts supported

BETTERUI.Nameplates = BETTERUI.Nameplates or {}

-- Available ESO built-in fonts
BETTERUI.Nameplates.FONT_CHOICES = {
    "Univers 57 (Default)",
    "Univers 67 (Bold)",
    "Futura Condensed Light",
    "Futura Condensed Medium",
    "Futura Condensed Bold",
    "Prose Antique",
    "Handwritten Bold",
    "Trajan Pro",
    "Skyrim Handwritten",
    "Consolas",
}

BETTERUI.Nameplates.FONT_VALUES = {
    "EsoUI/Common/Fonts/Univers57.otf",
    "EsoUI/Common/Fonts/Univers67.otf",
    "EsoUI/Common/Fonts/FTN47.otf",
    "EsoUI/Common/Fonts/FTN57.otf",
    "EsoUI/Common/Fonts/FTN87.otf",
    "EsoUI/Common/Fonts/ProseAntiquePSMT.otf",
    "EsoUI/Common/Fonts/Handwritten_Bold.otf",
    "EsoUI/Common/Fonts/TrajanPro-Regular.otf",
    "EsoUI/Common/Fonts/Skyrim_Handwritten.otf",
    "EsoUI/Common/Fonts/consola.otf",
}

-- Font style options (ESO FONT_STYLE_* constants)
BETTERUI.Nameplates.FONTSTYLE_CHOICES = {
    "Normal",
    "Outline",
    "Thick Outline",
    "Shadow",
    "Soft Shadow (Thick)",
    "Soft Shadow (Thin)",
}

BETTERUI.Nameplates.FONTSTYLE_VALUES = {
    FONT_STYLE_NORMAL or 0,
    FONT_STYLE_OUTLINE or 1,
    FONT_STYLE_THICK_OUTLINE or 2,
    FONT_STYLE_SHADOW or 3,
    FONT_STYLE_SOFT_SHADOW_THICK or 4,
    FONT_STYLE_SOFT_SHADOW_THIN or 5,
}

-- Default nameplate settings
BETTERUI.Nameplates.DEFAULTS = {
    enabled = false,
    font = "EsoUI/Common/Fonts/Univers67.otf",
    style = FONT_STYLE_SOFT_SHADOW_THIN or 5,
    size = 16,
}

-- Legacy migration: string style values to numeric enums
local STYLE_STRING_TO_ENUM = {
    ["normal"] = FONT_STYLE_NORMAL or 0,
    ["outline"] = FONT_STYLE_OUTLINE or 1,
    ["thick-outline"] = FONT_STYLE_THICK_OUTLINE or 2,
    ["shadow"] = FONT_STYLE_SHADOW or 3,
    ["soft-shadow-thick"] = FONT_STYLE_SOFT_SHADOW_THICK or 4,
    ["soft-shadow-thin"] = FONT_STYLE_SOFT_SHADOW_THIN or 5,
}

-- Converts legacy string style to numeric enum.
--- @param style string|number The font style (e.g., "outline" or FONT_STYLE_OUTLINE).
--- @return number The corresponding font style enum value.
local function NormalizeStyleValue(style)
    if type(style) == "string" then
        return STYLE_STRING_TO_ENUM[style] or (FONT_STYLE_SOFT_SHADOW_THIN or 5)
    end
    return style
end

--- Retrieves the current nameplate settings from saved variables.
---
--- Handles legacy migration from string-based style values to numeric enums.
--- Falls back to DEFAULTS if settings haven't been loaded yet.
---
--- TODO(cleanup): Legacy migration should be removed after sufficient time has passed
---                for all users to have migrated their saved variables.
---
--- @return table Module settings table with font, style, size, enabled
local function GetSettings()
    if BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Nameplates"] then
        local settings = BETTERUI.Settings.Modules["Nameplates"]
        if type(settings.style) == "string" then
            settings.style = NormalizeStyleValue(settings.style)
        end
        return settings
    end
    return BETTERUI.Nameplates.DEFAULTS
end

-- Applies font settings to keyboard and gamepad nameplates.
--- @param font string The font path.
--- @param style string|number The font style.
--- @param size number The font size.
local function ApplyNameplateFont(font, style, size)
    if not font or not style or not size then return end
    style = NormalizeStyleValue(style)
    local fontString = font .. "|" .. tostring(size)
    SetNameplateKeyboardFont(fontString, style)
    SetNameplateGamepadFont(fontString, style)
end

--- Registers or unregisters event handlers for reapplying fonts on zone/mode changes.
---
--- WHY BOTH EVENTS:
---   - EVENT_PLAYER_ACTIVATED: Fonts can reset on zone transitions, need to reapply
---   - EVENT_GAMEPAD_PREFERRED_MODE_CHANGED: Separate font APIs for keyboard vs gamepad
---
--- TODO(optimization): Consider debouncing rapid event firing
---
--- @param enabled boolean Whether to register (true) or unregister (false) events
local function SetupEvents(enabled)
    if enabled then
        EVENT_MANAGER:RegisterForEvent("BetterUI_Nameplates", EVENT_PLAYER_ACTIVATED, function()
            local settings = GetSettings()
            if settings.enabled then
                ApplyNameplateFont(settings.font, settings.style, settings.size)
            end
        end)
        EVENT_MANAGER:RegisterForEvent("BetterUI_Nameplates_GamepadChange", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
            local settings = GetSettings()
            if settings.enabled then
                ApplyNameplateFont(settings.font, settings.style, settings.size)
            end
        end)
    else
        EVENT_MANAGER:UnregisterForEvent("BetterUI_Nameplates", EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:UnregisterForEvent("BetterUI_Nameplates_GamepadChange", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED)
    end
end

--- Resets nameplates to ESO's default font settings.
---
--- Called when the module is disabled to restore vanilla appearance.
---
--- TODO(enhancement): Store original font before first modification for true restoration
local function ResetToDefaults()
    local defaults = BETTERUI.Nameplates.DEFAULTS
    ApplyNameplateFont(defaults.font, defaults.style, defaults.size)
end

--- Sets up the Nameplates module.
--- Loads settings and applies them if enabled. Register event listeners.
function BETTERUI.Nameplates.Setup()
    local settings = GetSettings()
    if settings.enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
        SetupEvents(true)
    end
end

--- Handles enable/disable toggle from settings.
--- Triggers event setup or teardown and applies/resets fonts accordingly.
--- @param enabled boolean The new enabled state.
function BETTERUI.Nameplates.OnEnabledChanged(enabled)
    SetupEvents(enabled)
    if enabled then
        local settings = GetSettings()
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    else
        ResetToDefaults()
    end
end

-- Returns whether Enhanced Nameplates is enabled
function BETTERUI.Nameplates.IsEnabled()
    return GetSettings().enabled
end

--- Applies current settings immediately.
--- Useful for live preview when changing settings in the menu.
function BETTERUI.Nameplates.ApplyCurrentSettings()
    local settings = GetSettings()
    if settings.enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    end
end
