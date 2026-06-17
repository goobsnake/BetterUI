BETTERUI.Nameplates = BETTERUI.Nameplates or {}
local Nameplates = BETTERUI.Nameplates
Nameplates.Settings = Nameplates.Settings or {}

local SETTINGS_OWNER = (BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES and BETTERUI.CIM.ARCHETYPES.SETTINGS_OWNER)
    or "settings-owner"
local NAMEPLATE_SIZE_MIN = 8
local NAMEPLATE_SIZE_MAX = 64
local DEFAULT_NAMEPLATE_SIZE = 16

local function ClampNameplateSize(value, fallback)
    local clampInteger = BETTERUI and BETTERUI.ClampInteger
    if type(clampInteger) == "function" then
        return clampInteger(value, NAMEPLATE_SIZE_MIN, NAMEPLATE_SIZE_MAX, fallback)
    end

    local numeric = tonumber(value)
    if not numeric then
        return fallback
    end

    local rounded = math.floor(numeric + 0.5)
    if rounded < NAMEPLATE_SIZE_MIN then
        return NAMEPLATE_SIZE_MIN
    end
    if rounded > NAMEPLATE_SIZE_MAX then
        return NAMEPLATE_SIZE_MAX
    end
    return rounded
end

Nameplates.ClampNameplateSize = ClampNameplateSize

---@type BetterUIModuleArchetypeSettingsOwner
Nameplates.ARCHETYPE = SETTINGS_OWNER
---@type BetterUIModuleRootContract
Nameplates.ROOT_CONTRACT = {
    name = "Nameplates",
    archetype = Nameplates.ARCHETYPE,
    init = true,
    setup = true,
}

-- ESO Update 41+ uses .slug fonts; only built-in ESO fonts are supported here.
Nameplates.FONT_CHOICES = {
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

Nameplates.FONT_VALUES = {
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

Nameplates.FONTSTYLE_CHOICES = {
    "Normal",
    "Outline",
    "Thick Outline",
    "Shadow",
    "Soft Shadow (Thick)",
    "Soft Shadow (Thin)",
}

-- Numeric hedges mirror CIM DefaultsRegistry: FONT_STYLE_* globals may be nil
-- in stripped/test environments, so fall back to the engine enum values.
Nameplates.FONTSTYLE_VALUES = {
    FONT_STYLE_NORMAL or 0,
    FONT_STYLE_OUTLINE or 1,
    FONT_STYLE_OUTLINE_THICK or 2,
    FONT_STYLE_SHADOW or 3,
    FONT_STYLE_SOFT_SHADOW_THICK or 4,
    FONT_STYLE_SOFT_SHADOW_THIN or 5,
}

Nameplates.DEFAULTS = {
    m_enabled = false,
    font = "$(BOLD_FONT)", -- Uses ESO's localized font for CJK support
    style = FONT_STYLE_SOFT_SHADOW_THIN or 5,
    size = DEFAULT_NAMEPLATE_SIZE,
}

local STYLE_STRING_TO_ENUM = {
    ["normal"] = FONT_STYLE_NORMAL or 0,
    ["outline"] = FONT_STYLE_OUTLINE or 1,
    ["thick-outline"] = FONT_STYLE_OUTLINE_THICK or 2,
    ["shadow"] = FONT_STYLE_SHADOW or 3,
    ["soft-shadow-thick"] = FONT_STYLE_SOFT_SHADOW_THICK or 4,
    ["soft-shadow-thin"] = FONT_STYLE_SOFT_SHADOW_THIN or 5,
}

local function NormalizeStyleValue(style)
    if type(style) == "string" then
        return STYLE_STRING_TO_ENUM[style] or FONT_STYLE_SOFT_SHADOW_THIN or 5
    end
    return style
end

local function GetSettings()
    local settings = BETTERUI.GetModuleSettings("Nameplates")
    if settings and next(settings) then
        if type(settings.style) == "string" then
            settings.style = NormalizeStyleValue(settings.style)
            -- GetModuleSettings returns a detached snapshot; write the
            -- normalized enum to the live table so the migration persists.
            BETTERUI.GetModuleSettingsLive("Nameplates").style = settings.style
        end
        return settings
    end
    return Nameplates.DEFAULTS
end

local function GetNameplatePanelOptions()
    if type(Nameplates.GetSettingsOptions) == "function" then
        return Nameplates.GetSettingsOptions()
    end
    return {}
end

local function InitPanel(mId, moduleName)
    local panelData = BETTERUI.Init_ModulePanel(
        moduleName,
        GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_HEADER"))
    )
    BETTERUI.CIM.Settings.RegisterModulePanel(mId, panelData, GetNameplatePanelOptions())
end

Nameplates.Settings.RegisterPanel = InitPanel

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

local m_warnedMissingFontArgs = false

local function ApplyNameplateFont(font, style, size)
    if not font or not style or not size then
        -- One-time diagnostic: a silent bail here means nameplate fonts
        -- never apply (e.g. style constant resolved to nil).
        if BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SETTINGS, "nameplate style unresolved", { font = font, style = style, size = size })
        end
        if not m_warnedMissingFontArgs and BETTERUI.DebugError then
            m_warnedMissingFontArgs = true
            BETTERUI.DebugError(string.format(
                "[Nameplates] ApplyNameplateFont skipped: font=%s style=%s size=%s",
                tostring(font), tostring(style), tostring(size)))
        end
        return
    end
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SETTINGS, "nameplateApplyFont", { font = font, style = style, size = size })
    end
    CaptureOriginalNameplateFonts()
    style = NormalizeStyleValue(style)
    local fontString = font .. "|" .. tostring(size)
    SetNameplateKeyboardFont(fontString, style)
    SetNameplateGamepadFont(fontString, style)
end

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

    local defaults = Nameplates.DEFAULTS
    ApplyNameplateFont(defaults.font, defaults.style, defaults.size)
end

function Nameplates.Setup()
    BETTERUI.CIM.RegisterModulePanelWithLogging(Nameplates, "Nameplates", "Nameplates", "Nameplates")

    local settings = GetSettings()
    if settings.m_enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
        SetupEvents(true)
    end
end

function Nameplates.OnEnabledChanged(m_enabled, suppressCleanupLog)
    SetupEvents(m_enabled, suppressCleanupLog)
    if m_enabled then
        local settings = GetSettings()
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    else
        ResetToDefaults()
    end
end

function Nameplates.ApplyCurrentSettings()
    local settings = GetSettings()
    if settings.m_enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    end
end

function Nameplates.InitModule(m_options)
    m_options = m_options or {}
    local defaults = Nameplates.DEFAULTS
    if m_options.m_enabled == nil then m_options.m_enabled = defaults.m_enabled end
    if m_options.font == nil then m_options.font = defaults.font end
    if m_options.style == nil then m_options.style = defaults.style end
    if m_options.size == nil then m_options.size = defaults.size end
    m_options.size = ClampNameplateSize(m_options.size, defaults.size)

    local currentLang = GetCVar("language.2") or "en"
    local isEnglish = (currentLang == "en")

    if not isEnglish then
        if m_options.font and BETTERUI.CIM.Font.Localization.IsFontWesternOnly(m_options.font) then
            m_options.font = "$(BOLD_FONT)"
        end
    end

    return m_options
end
