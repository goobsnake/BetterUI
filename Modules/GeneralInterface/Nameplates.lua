--- BetterUI Enhanced Nameplates Module
--- Provides customizable nameplate fonts, styles, and sizes for keyboard and gamepad modes
--- Note: ESO Update 41+ requires .slug format fonts. Only built-in ESO fonts are supported.

BETTERUI.Nameplates = BETTERUI.Nameplates or {}

-- ESO built-in fonts (these have .slug versions and work with nameplate APIs)
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

-- Font style options (maps to ESO FONT_STYLE_* constants)
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

-- Default settings
BETTERUI.Nameplates.DEFAULTS = {
    enabled = false,
    font = "EsoUI/Common/Fonts/Univers67.otf",
    style = FONT_STYLE_SOFT_SHADOW_THIN or 5,
    size = 16,
}

-- Legacy migration: converts old string style values to numeric enums
local STYLE_STRING_TO_ENUM = {
    ["normal"] = FONT_STYLE_NORMAL or 0,
    ["outline"] = FONT_STYLE_OUTLINE or 1,
    ["thick-outline"] = FONT_STYLE_THICK_OUTLINE or 2,
    ["shadow"] = FONT_STYLE_SHADOW or 3,
    ["soft-shadow-thick"] = FONT_STYLE_SOFT_SHADOW_THICK or 4,
    ["soft-shadow-thin"] = FONT_STYLE_SOFT_SHADOW_THIN or 5,
}

-- Converts legacy string style to numeric enum
local function NormalizeStyleValue(style)
    if type(style) == "string" then
        return STYLE_STRING_TO_ENUM[style] or (FONT_STYLE_SOFT_SHADOW_THIN or 5)
    end
    return style
end

-- Retrieves current nameplate settings from saved variables
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

-- Applies font settings to both keyboard and gamepad nameplate modes
local function ApplyNameplateFont(font, style, size)
    if not font or not style or not size then return end
    style = NormalizeStyleValue(style)
    local fontString = font .. "|" .. tostring(size)
    SetNameplateKeyboardFont(fontString, style)
    SetNameplateGamepadFont(fontString, style)
end

-- Registers/unregisters event handlers for reapplying fonts on zone changes
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

-- Resets nameplates to ESO default font
local function ResetToDefaults()
    local defaults = BETTERUI.Nameplates.DEFAULTS
    ApplyNameplateFont(defaults.font, defaults.style, defaults.size)
end

-- PUBLIC API --

-- Initializes the Enhanced Nameplates module on addon load
function BETTERUI.Nameplates.Setup()
    local settings = GetSettings()
    if settings.enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
        SetupEvents(true)
    end
end

-- Called when the enabled checkbox is toggled in settings
function BETTERUI.Nameplates.OnEnabledChanged(enabled)
    SetupEvents(enabled)
    if enabled then
        local settings = GetSettings()
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    else
        ResetToDefaults()
    end
end

-- Returns whether Enhanced Nameplates is currently enabled
function BETTERUI.Nameplates.IsEnabled()
    return GetSettings().enabled
end

-- Applies current settings from saved variables (called when settings change)
function BETTERUI.Nameplates.ApplyCurrentSettings()
    local settings = GetSettings()
    if settings.enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    end
end
