BETTERUI.Nameplates = BETTERUI.Nameplates or {}
local Nameplates = BETTERUI.Nameplates
Nameplates.Settings = Nameplates.Settings or {}

local SETTINGS_OWNER = (BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES and BETTERUI.CIM.ARCHETYPES.SETTINGS_OWNER)
    or "settings-owner"
local NAMEPLATE_SIZE_MIN = 8
local NAMEPLATE_SIZE_MAX = 64
local DEFAULT_NAMEPLATE_SIZE = 16

local function GetCurrentSceneName()
    if SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
        local scene = SCENE_MANAGER:GetCurrentScene()
        if scene and scene.GetName then
            return scene:GetName()
        end
    end
    return nil
end

local function TraceNameplates(event, phase, data)
    if not (BETTERUI and BETTERUI.Log and BETTERUI.Log.TraceEvent) then
        return
    end
    data = data or {}
    data.module = data.module or "Nameplates"
    data.feature = data.feature or "nameplates"
    data.scene = data.scene or GetCurrentSceneName()
    if data.gamepadMode == nil and type(IsInGamepadPreferredMode) == "function" then
        data.gamepadMode = IsInGamepadPreferredMode()
    end
    if BETTERUI.Log.SetLastAction then
        BETTERUI.Log.SetLastAction({ flow = event, message = event .. ":" .. phase })
    end
    local categories = BETTERUI.Log.CATEGORY or {}
    BETTERUI.Log.TraceEvent(categories.SETTINGS, event, phase, data)
end

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

local function RegisterNameplateSnapshotProvider()
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if not (watch and watch.RegisterSnapshotProvider) then
        return
    end
    watch.RegisterSnapshotProvider("nameplates", function()
        local settings = GetSettings()
        return string.format("enabled=%s font=%s style=%s size=%s captured=%s kb=%s gp=%s",
            tostring(settings and settings.m_enabled),
            tostring(settings and settings.font),
            tostring(settings and settings.style),
            tostring(settings and settings.size),
            tostring(originalFontsCaptured),
            tostring(originalKeyboardFont ~= nil),
            tostring(originalGamepadFont ~= nil))
    end)
end

local function CaptureOriginalNameplateFonts()
    if originalFontsCaptured then
        TraceNameplates("nameplates.font_capture", "skipped", {
            fn = "Nameplates.CaptureOriginalNameplateFonts",
            reason = "alreadyCaptured",
            hasKeyboardOriginal = originalKeyboardFont ~= nil,
            hasGamepadOriginal = originalGamepadFont ~= nil,
        })
        return
    end

    TraceNameplates("nameplates.font_capture", "begin", {
        fn = "Nameplates.CaptureOriginalNameplateFonts",
        hasKeyboardGetter = type(GetNameplateKeyboardFont) == "function",
        hasGamepadGetter = type(GetNameplateGamepadFont) == "function",
    })

    if type(GetNameplateKeyboardFont) == "function" then
        originalKeyboardFont, originalKeyboardStyle = GetNameplateKeyboardFont()
    end
    if type(GetNameplateGamepadFont) == "function" then
        originalGamepadFont, originalGamepadStyle = GetNameplateGamepadFont()
    end

    originalFontsCaptured = originalKeyboardFont ~= nil or originalGamepadFont ~= nil
    TraceNameplates("nameplates.font_capture", "end", {
        fn = "Nameplates.CaptureOriginalNameplateFonts",
        captured = originalFontsCaptured,
        keyboardFont = originalKeyboardFont,
        keyboardStyle = originalKeyboardStyle,
        gamepadFont = originalGamepadFont,
        gamepadStyle = originalGamepadStyle,
    })
end

local m_warnedMissingFontArgs = false

local function ApplyNameplateFont(font, style, size)
    if not font or not style or not size then
        -- One-time diagnostic: a silent bail here means nameplate fonts
        -- never apply (e.g. style constant resolved to nil).
        TraceNameplates("nameplates.font_apply", "rejected", {
            fn = "Nameplates.ApplyNameplateFont",
            reason = "missingArguments",
            font = font,
            style = style,
            size = size,
        })
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
    TraceNameplates("nameplates.font_apply", "begin", {
        fn = "Nameplates.ApplyNameplateFont",
        font = font,
        style = style,
        size = size,
        hasKeyboardSetter = type(SetNameplateKeyboardFont) == "function",
        hasGamepadSetter = type(SetNameplateGamepadFont) == "function",
    })
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SETTINGS, "nameplate font applied", { font = font, style = style, size = size })
    end
    CaptureOriginalNameplateFonts()
    style = NormalizeStyleValue(style)
    local fontString = font .. "|" .. tostring(size)
    SetNameplateKeyboardFont(fontString, style)
    SetNameplateGamepadFont(fontString, style)
    TraceNameplates("nameplates.font_apply", "end", {
        fn = "Nameplates.ApplyNameplateFont",
        fontString = fontString,
        style = style,
        size = size,
    })
end

local function SetupEvents(enabled, suppressCleanupLog)
    TraceNameplates("nameplates.events", enabled and "register" or "unregister", {
        fn = "Nameplates.SetupEvents",
        enabled = enabled,
        suppressCleanupLog = suppressCleanupLog,
    })
    if enabled then
        BETTERUI.CIM.EventRegistry.Register("Nameplates", "BetterUI_Nameplates", EVENT_PLAYER_ACTIVATED, function()
            local settings = GetSettings()
            TraceNameplates("nameplates.event", "player_activated", {
                fn = "Nameplates.EVENT_PLAYER_ACTIVATED",
                enabled = settings and settings.m_enabled,
                font = settings and settings.font,
                style = settings and settings.style,
                size = settings and settings.size,
            })
            if settings.m_enabled then
                ApplyNameplateFont(settings.font, settings.style, settings.size)
            end
        end)
        BETTERUI.CIM.EventRegistry.Register("Nameplates", "BetterUI_Nameplates_GamepadChange",
            EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
            function()
                local settings = GetSettings()
                TraceNameplates("nameplates.event", "gamepad_mode_changed", {
                    fn = "Nameplates.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED",
                    enabled = settings and settings.m_enabled,
                    font = settings and settings.font,
                    style = settings and settings.style,
                    size = settings and settings.size,
                })
                if settings.m_enabled then
                    ApplyNameplateFont(settings.font, settings.style, settings.size)
                end
            end)
    else
        BETTERUI.CIM.EventRegistry.UnregisterAll("Nameplates", suppressCleanupLog)
    end
end

local function ResetToDefaults()
    TraceNameplates("nameplates.reset", "begin", {
        fn = "Nameplates.ResetToDefaults",
        originalFontsCaptured = originalFontsCaptured,
        hasKeyboardOriginal = originalKeyboardFont ~= nil,
        hasGamepadOriginal = originalGamepadFont ~= nil,
    })
    if originalFontsCaptured then
        if originalKeyboardFont ~= nil then
            SetNameplateKeyboardFont(originalKeyboardFont, originalKeyboardStyle)
        end
        if originalGamepadFont ~= nil then
            SetNameplateGamepadFont(originalGamepadFont, originalGamepadStyle)
        end
        TraceNameplates("nameplates.reset", "restored_original", {
            fn = "Nameplates.ResetToDefaults",
            keyboardFont = originalKeyboardFont,
            keyboardStyle = originalKeyboardStyle,
            gamepadFont = originalGamepadFont,
            gamepadStyle = originalGamepadStyle,
        })
        return
    end

    local defaults = Nameplates.DEFAULTS
    TraceNameplates("nameplates.reset", "fallback_defaults", {
        fn = "Nameplates.ResetToDefaults",
        font = defaults.font,
        style = defaults.style,
        size = defaults.size,
    })
    ApplyNameplateFont(defaults.font, defaults.style, defaults.size)
end

function Nameplates.Setup()
    TraceNameplates("nameplates.setup", "begin", { fn = "Nameplates.Setup" })
    RegisterNameplateSnapshotProvider()
    BETTERUI.CIM.RegisterModulePanelWithLogging(Nameplates, "Nameplates", "Nameplates", "Nameplates")

    local settings = GetSettings()
    TraceNameplates("nameplates.setup", "settings_loaded", {
        fn = "Nameplates.Setup",
        enabled = settings and settings.m_enabled,
        font = settings and settings.font,
        style = settings and settings.style,
        size = settings and settings.size,
    })
    if settings.m_enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
        SetupEvents(true)
    end
    TraceNameplates("nameplates.setup", "end", { fn = "Nameplates.Setup", enabled = settings and settings.m_enabled })
end

function Nameplates.OnEnabledChanged(m_enabled, suppressCleanupLog)
    TraceNameplates("nameplates.enabled_changed", "received", {
        fn = "Nameplates.OnEnabledChanged",
        enabled = m_enabled,
        suppressCleanupLog = suppressCleanupLog,
    })
    SetupEvents(m_enabled, suppressCleanupLog)
    if m_enabled then
        local settings = GetSettings()
        TraceNameplates("nameplates.enabled_changed", "apply_enabled", {
            fn = "Nameplates.OnEnabledChanged",
            font = settings and settings.font,
            style = settings and settings.style,
            size = settings and settings.size,
        })
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    else
        TraceNameplates("nameplates.enabled_changed", "apply_disabled", { fn = "Nameplates.OnEnabledChanged" })
        ResetToDefaults()
    end
end

function Nameplates.ApplyCurrentSettings()
    local settings = GetSettings()
    TraceNameplates("nameplates.apply_current", settings.m_enabled and "apply" or "skipped", {
        fn = "Nameplates.ApplyCurrentSettings",
        enabled = settings and settings.m_enabled,
        font = settings and settings.font,
        style = settings and settings.style,
        size = settings and settings.size,
    })
    if settings.m_enabled then
        ApplyNameplateFont(settings.font, settings.style, settings.size)
    end
end

function Nameplates.InitModule(m_options)
    TraceNameplates("nameplates.init", "begin", {
        fn = "Nameplates.InitModule",
        enabled = m_options and m_options.m_enabled,
        font = m_options and m_options.font,
        style = m_options and m_options.style,
        size = m_options and m_options.size,
    })
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
            TraceNameplates("nameplates.init", "localized_font_fallback", {
                fn = "Nameplates.InitModule",
                language = currentLang,
                originalFont = m_options.font,
                fallbackFont = "$(BOLD_FONT)",
            })
            m_options.font = "$(BOLD_FONT)"
        end
    end

    TraceNameplates("nameplates.init", "end", {
        fn = "Nameplates.InitModule",
        language = currentLang,
        isEnglish = isEnglish,
        enabled = m_options.m_enabled,
        font = m_options.font,
        style = m_options.style,
        size = m_options.size,
    })
    return m_options
end
