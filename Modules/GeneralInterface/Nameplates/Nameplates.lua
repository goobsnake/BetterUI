-- BetterUI - Enhanced Nameplates
--
-- This module allows customization of nameplate fonts, styles, and sizes.
-- It supports:
-- 1. Font Selection: Choose from various built-in ESO fonts.
-- 2. Style Control: Adjust outline, shadow, and other font effects.
-- 3. Size Adjustment: Scale nameplates to preferred size.
-- 4. Cross-Mode Support: Applies settings to both Keyboard and Gamepad modes.

-- Note: ESO Update 41+ uses .slug fonts; only built-in ESO fonts supported

BETTERUI.Nameplates = BETTERUI.Nameplates or {}

-- Available ESO built-in fonts
BETTERUI.Nameplates.FONT_CHOICES = {
    "System Default (Localized)", -- Uses ESO's language-appropriate bold font
    "Antique (Localized)",        -- Stylized serif, localized for CJK
    "Handwritten (Localized)",    -- Handwritten style, localized for CJK
    "Stone Tablet (Localized)",   -- Carved stone style, localized for CJK
    "Univers 57",
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
    "$(BOLD_FONT)",         -- ESO's localized bold font
    "$(ANTIQUE_FONT)",      -- Resolves to ProseAntique (Western) or KafuPenji (JP) or MYoyo (ZH)
    "$(HANDWRITTEN_FONT)",  -- Resolves to Handwritten_Bold (Western) or localized equivalent
    "$(STONE_TABLET_FONT)", -- Resolves to TrajanPro (Western) or localized equivalent
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
    m_enabled = false,
    font = "$(BOLD_FONT)", -- Uses ESO's localized font for CJK support
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

-- Converts legacy string style values to the numeric enum used by the API.
local function NormalizeStyleValue(style)
    if type(style) == "string" then
        return STYLE_STRING_TO_ENUM[style] or (FONT_STYLE_SOFT_SHADOW_THIN or 5)
    end
    return style
end

--- Returns nameplate settings with legacy style values normalized.
local function GetSettings()
    local settings = BETTERUI.GetModuleSettings("Nameplates")
    if settings and next(settings) then
        if type(settings.style) == "string" then
            settings.style = NormalizeStyleValue(settings.style)
        end
        return settings
    end
    return BETTERUI.Nameplates.DEFAULTS
end

local originalKeyboardFont = nil
local originalKeyboardStyle = nil
local originalGamepadFont = nil
local originalGamepadStyle = nil
local originalFontsCaptured = false

local function CaptureOriginalNameplateFonts()
    if originalFontsCaptured then
        return
    end

    if type(GetNameplateKeyboardFont) == "function" then
        originalKeyboardFont, originalKeyboardStyle = GetNameplateKeyboardFont()
    end
    if type(GetNameplateGamepadFont) == "function" then
        originalGamepadFont, originalGamepadStyle = GetNameplateGamepadFont()
    end

    originalFontsCaptured = originalKeyboardFont ~= nil or originalGamepadFont ~= nil
end

--- Applies the configured font to keyboard and gamepad nameplates.
local function ApplyNameplateFont(font, style, size)
    if not font or not style or not size then return end
    CaptureOriginalNameplateFonts()
    style = NormalizeStyleValue(style)
    local fontString = font .. "|" .. tostring(size)
    SetNameplateKeyboardFont(fontString, style)
    SetNameplateGamepadFont(fontString, style)
end

--- Registers or unregisters the events that reapply nameplate fonts.
local function SetupEvents(enabled, suppressCleanupLog)
    if enabled then
        BETTERUI.CIM.EventRegistry.Register("Nameplates", "BetterUI_Nameplates", EVENT_PLAYER_ACTIVATED, function()
            local settings = GetSettings()
            if settings.m_enabled then
                ApplyNameplateFont(settings.font, settings.style, settings.size)
            end
        end)
        BETTERUI.CIM.EventRegistry.Register("Nameplates", "BetterUI_Nameplates_GamepadChange",
            EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
            function()
                local settings = GetSettings()
                if settings.m_enabled then
                    ApplyNameplateFont(settings.font, settings.style, settings.size)
                end
            end)
    else
        BETTERUI.CIM.EventRegistry.UnregisterAll("Nameplates", suppressCleanupLog)
    end
end

--- Restores the captured nameplate fonts or falls back to module defaults.
local function ResetToDefaults()
    if originalFontsCaptured then
        if originalKeyboardFont ~= nil then
            SetNameplateKeyboardFont(originalKeyboardFont, originalKeyboardStyle)
        end
        if originalGamepadFont ~= nil then
            SetNameplateGamepadFont(originalGamepadFont, originalGamepadStyle)
        end
        return
    end

    local defaults = BETTERUI.Nameplates.DEFAULTS
    ApplyNameplateFont(defaults.font, defaults.style, defaults.size)
end

--- Applies the saved nameplate settings when the module starts enabled.
function BETTERUI.Nameplates.Setup()
    local settings = GetSettings()
    if settings.m_enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
        SetupEvents(true)
    end
end

--- Applies or removes the Nameplates font override when the setting changes.
function BETTERUI.Nameplates.OnEnabledChanged(m_enabled, suppressCleanupLog)
    SetupEvents(m_enabled, suppressCleanupLog)
    if m_enabled then
        local settings = GetSettings()
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    else
        ResetToDefaults()
    end
end

--- Returns whether the Nameplates module is enabled.
function BETTERUI.Nameplates.IsEnabled()
    return GetSettings().m_enabled
end

--- Reapplies the current font settings immediately when the module is enabled.
function BETTERUI.Nameplates.ApplyCurrentSettings()
    local settings = GetSettings()
    if settings.m_enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    end
end
