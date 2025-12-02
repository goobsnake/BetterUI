--- BetterUI Enhanced Nameplates Module
--- Provides customizable nameplate fonts, styles, and sizes for both keyboard and gamepad modes

-- ============================================================================
-- CONSTANTS
-- ============================================================================

BETTERUI.Nameplates = BETTERUI.Nameplates or {}

--- Font choices displayed in the settings dropdown
BETTERUI.Nameplates.FONT_CHOICES = {
    -- Custom fonts bundled with BetterUI
    "Cinzel Bold",
    "Cinzel Decorative Bold",
    "Uncial Antiqua",
    "MedievalSharp",
    "IM Fell English SC",
    "Almendra Bold",
    "Pirata One",
    "Metamorphous",
    "Fondamento Italic",
    "Grenze Gotisch Bold",
    "Vollkorn Bold",
    "Cardo Bold",
    "Cormorant Garamond Bold",
    "Spectral Bold",
    "Crimson Text Bold",
    "Della Respira",
    "Cormorant SC Bold",
    "Old Standard TT Bold",
    "Eczar Bold",
    "Sorts Mill Goudy",
    -- ESO built-in fonts
    "Univers 57 (ESO Default)",
    "Univers 67 (ESO Bold)",
    "Futura Condensed Light",
    "Futura Condensed Medium",
    "Futura Condensed Bold",
    "Prose Antique",
    "Handwritten Bold",
    "Trajan Pro",
}

--- Font file paths corresponding to FONT_CHOICES
BETTERUI.Nameplates.FONT_VALUES = {
    -- Custom fonts bundled with BetterUI (Fantasy/Medieval)
    "BetterUI/Modules/GeneralInterface/fonts/Cinzel-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/CinzelDecorative-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/UncialAntiqua-Regular.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/MedievalSharp.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/IMFellEnglishSC-Regular.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/Almendra-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/PirataOne-Regular.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/Metamorphous-Regular.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/Fondamento-Italic.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/GrenzeGotisch-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/Vollkorn-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/Cardo-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/CormorantGaramond-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/Spectral-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/CrimsonText-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/DellaRespira-Regular.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/CormorantSC-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/OldStandardTT-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/Eczar-Bold.ttf",
    "BetterUI/Modules/GeneralInterface/fonts/SortsMillGoudy-Regular.ttf",
    -- ESO built-in fonts
    "EsoUI/Common/Fonts/Univers57.otf",
    "EsoUI/Common/Fonts/Univers67.otf",
    "EsoUI/Common/Fonts/FTN47.otf",
    "EsoUI/Common/Fonts/FTN57.otf",
    "EsoUI/Common/Fonts/FTN87.otf",
    "EsoUI/Common/Fonts/ProseAntiquePSMT.otf",
    "EsoUI/Common/Fonts/Handwritten_Bold.otf",
    "EsoUI/Common/Fonts/TrajanPro-Regular.otf",
}

--- Font style display names
BETTERUI.Nameplates.FONTSTYLE_CHOICES = {
    "Normal",
    "Outline",
    "Thick Outline",
    "Shadow",
    "Soft Shadow (Thick)",
    "Soft Shadow (Thin)",
}

--- Font style values (ESO string constants)
BETTERUI.Nameplates.FONTSTYLE_VALUES = {
    "normal",
    "outline",
    "thick-outline",
    "shadow",
    "soft-shadow-thick",
    "soft-shadow-thin",
}

--- Default settings for Enhanced Nameplates
BETTERUI.Nameplates.DEFAULTS = {
    enabled = false,
    font = "EsoUI/Common/Fonts/Univers67.otf",
    style = "soft-shadow-thin",
    size = 16,
}

-- ============================================================================
-- LOCAL FUNCTIONS
-- ============================================================================

--- Gets the current nameplate settings from saved variables
--- @return table: The current nameplate settings
local function GetSettings()
    if BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Nameplates"] then
        return BETTERUI.Settings.Modules["Nameplates"]
    end
    return BETTERUI.Nameplates.DEFAULTS
end

--- Applies the nameplate font settings to the game
--- Handles both keyboard and gamepad modes automatically
--- @param font string: The font file path
--- @param style string: The font style string
--- @param size number: The font size
local function ApplyNameplateFont(font, style, size)
    if not font or not style or not size then return end
    
    -- Construct the font string in ESO format: "path|size|style"
    local fontString = font .. "|" .. tostring(size) .. "|" .. style
    
    if IsInGamepadPreferredMode() then
        local currentFont, currentStyle = GetNameplateGamepadFont()
        if currentFont ~= font or currentStyle ~= style then
            SetNameplateGamepadFont(fontString, style)
        end
    else
        local currentFont, currentStyle = GetNameplateKeyboardFont()
        if currentFont ~= font or currentStyle ~= style then
            SetNameplateKeyboardFont(fontString, style)
        end
    end
end

--- Sets up event handlers for the Enhanced Nameplates feature
--- @param enabled boolean: Whether to register or unregister events
local function SetupEvents(enabled)
    if enabled then
        -- Re-apply font settings when player enters a new zone or activates
        EVENT_MANAGER:RegisterForEvent("BetterUI_Nameplates", EVENT_PLAYER_ACTIVATED, function()
            local settings = GetSettings()
            if settings.enabled then
                ApplyNameplateFont(settings.font, settings.style, settings.size)
            end
        end)
        
        -- Re-apply when gamepad mode changes
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

--- Resets nameplate font to ESO defaults
local function ResetToDefaults()
    local defaults = BETTERUI.Nameplates.DEFAULTS
    ApplyNameplateFont(defaults.font, defaults.style, defaults.size)
end

--- Sets up the Enhanced Nameplates module
--- Called during addon initialization
function BETTERUI.Nameplates.Setup()
    local settings = GetSettings()
    
    -- Apply settings if enabled
    if settings.enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
        SetupEvents(true)
    end
    
    ddebug("Enhanced Nameplates module loaded")
end

--- Called when the enabled setting is changed from the settings panel
--- @param enabled boolean: The new enabled state
function BETTERUI.Nameplates.OnEnabledChanged(enabled)
    SetupEvents(enabled)
    if enabled then
        local settings = GetSettings()
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    else
        ResetToDefaults()
    end
end

--- Returns whether the Enhanced Nameplates feature is currently enabled
--- @return boolean: True if enabled
function BETTERUI.Nameplates.IsEnabled()
    return GetSettings().enabled
end

--- Applies current nameplate settings from saved variables
--- Called by settings panel when font, style, or size changes
function BETTERUI.Nameplates.ApplyCurrentSettings()
    local settings = GetSettings()
    if settings.enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    end
end
