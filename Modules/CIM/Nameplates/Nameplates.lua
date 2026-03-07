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

-- Converts legacy string style to numeric enum.
-- Purpose: Ensures backward compatibility for saved settings.
-- Mechanics: Checks if style is string map to enum or return as is.
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
--- Purpose: Accessor for nameplate configuration.
--- Mechanics:
--- - Checks `BETTERUI.Settings`.
--- - Normalizes legacy style strings if found.
--- - Returns DEFAULTS if settings are missing.
---
--- References: Called by Setup, Apply, and Logic functions.
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

-- Applies font settings to keyboard and gamepad nameplates.
---
--- Purpose: Commits configuration to the ESO API.
--- Mechanics:
--- - Normalizes style.
--- - Constructs font definition string (`font|size`).
--- - Calls `SetNameplateKeyboardFont` and `SetNameplateGamepadFont`.
---
--- References: Called by ApplyCurrentSettings and Event Handlers.
---
--- @param font string The font path.
--- @param style string|number The font style.
--- @param size number The font size.
local function ApplyNameplateFont(font, style, size)
    if not font or not style or not size then return end
    CaptureOriginalNameplateFonts()
    style = NormalizeStyleValue(style)
    local fontString = font .. "|" .. tostring(size)
    SetNameplateKeyboardFont(fontString, style)
    SetNameplateGamepadFont(fontString, style)
end

--- Registers or unregisters event handlers for reapplying fonts on zone/mode changes.
---
--- Purpose: Ensures nameplate fonts persist across game states.
--- Mechanics:
--- - `EVENT_PLAYER_ACTIVATED`: Reapplies fonts on zone load.
--- - `EVENT_GAMEPAD_PREFERRED_MODE_CHANGED`: Reapplies fonts when input mode switches.
---
--- References: Called by Setup and OnEnabledChanged.
---
--- @param enabled boolean Whether to register (true) or unregister (false) events
--- @param suppressCleanupLog boolean|nil When true, suppress event cleanup debug output
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

--- Resets nameplates to ESO's default font settings.
---
--- Purpose: Restores vanilla look when module is disabled.
--- Mechanics:
--- - Retrieves DEFAULTS.
--- - Applies default font, style, and size.
---
--- References: Called by OnEnabledChanged(false).
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

--- Sets up the Nameplates module.
---
--- Purpose: Entry point for Nameplate initialization.
--- Mechanics: Check settings; if m_enabled, apply fonts and register events.
--- References: Called by GeneralInterface Setup.
function BETTERUI.Nameplates.Setup()
    local settings = GetSettings()
    if settings.m_enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
        SetupEvents(true)
    end
end

--- Handles enable/disable toggle from settings.
---
--- Purpose: Updates state dynamically when user toggles checkbox.
--- Mechanics:
--- - If m_enabled: Setup events, apply fonts.
--- - If disabled: Unregister events, reset to defaults.
---
--- @param m_enabled boolean The new m_enabled state.
--- @param suppressCleanupLog boolean|nil When true, suppress reset-triggered cleanup debug output
function BETTERUI.Nameplates.OnEnabledChanged(m_enabled, suppressCleanupLog)
    SetupEvents(m_enabled, suppressCleanupLog)
    if m_enabled then
        local settings = GetSettings()
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    else
        ResetToDefaults()
    end
end

-- Returns whether Enhanced Nameplates is m_enabled
--- @return boolean enabled True if nameplates are enabled
function BETTERUI.Nameplates.IsEnabled()
    return GetSettings().m_enabled
end

--- Applies current settings immediately.
---
--- Purpose: Live update callback for settings menu.
--- Mechanics: Applies font settings if m_enabled.
--- References: Called by Slider/Dropdown setters.
function BETTERUI.Nameplates.ApplyCurrentSettings()
    local settings = GetSettings()
    if settings.m_enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    end
end
