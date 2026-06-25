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
    local category = categories.SETTINGS
    if event == "nameplates.event" then
        category = categories.STATE or categories.LIFECYCLE or categories.SETTINGS
    elseif event == "nameplates.font_capture"
        or event == "nameplates.font_apply"
        or event == "nameplates.apply_current"
        or event == "nameplates.reset"
        or event == "nameplates.events" then
        category = categories.LIFECYCLE or categories.STATE or categories.SETTINGS
    end
    BETTERUI.Log.TraceEvent(category, event, phase, data)
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

Nameplates.NormalizeStyleValue = NormalizeStyleValue

local function CloneSettingsValue(source)
    local clone = {}
    for key, value in pairs(source or {}) do
        clone[key] = value
    end
    return clone
end

local function GetFontLocalization()
    return BETTERUI
        and BETTERUI.CIM
        and BETTERUI.CIM.Font
        and BETTERUI.CIM.Font.Localization
        or nil
end

local function ResolveLanguageGroup(currentLang)
    local localization = GetFontLocalization()
    if localization and type(localization.GetCurrentLanguageGroup) == "function" then
        return localization.GetCurrentLanguageGroup()
    end
    local groups = localization and localization.LANGUAGE_GROUPS or nil
    if type(groups) == "table" and currentLang and groups[currentLang] then
        return groups[currentLang]
    end
    if currentLang == "jp" or currentLang == "zh" then
        return "cjk"
    elseif currentLang == "ru" then
        return "cyrillic"
    end
    return "western"
end

local function IsFontLocalizedForCurrentLanguage(fontPath, languageGroup)
    if fontPath and string.sub(fontPath, 1, 2) == "$(" then
        return true
    end

    local localization = GetFontLocalization()
    if localization and type(localization.IsFontLocalizedForLanguage) == "function" then
        return localization.IsFontLocalizedForLanguage(fontPath)
    end

    if languageGroup == "western" then
        return true
    end

    if localization and type(localization.IsFontWesternOnly) == "function" then
        return not localization.IsFontWesternOnly(fontPath)
    end
    local westernOnlyFonts = localization and localization.WESTERN_ONLY_FONTS or nil
    return not (type(westernOnlyFonts) == "table" and westernOnlyFonts[fontPath] == true)
end

local function GetSettings()
    local settings = BETTERUI.GetModuleSettings("Nameplates")
    if settings and next(settings) then
        if type(settings.style) == "string" then
            settings.style = NormalizeStyleValue(settings.style)
            -- GetModuleSettings returns a detached snapshot; write the
            -- normalized enum to the live table so the migration persists.
            local liveSettings = BETTERUI.GetModuleSettingsLive and BETTERUI.GetModuleSettingsLive("Nameplates") or nil
            if type(liveSettings) == "table" then
                liveSettings.style = settings.style
            else
                TraceNameplates("nameplates.settings", "migration_skipped", {
                    fn = "Nameplates.GetSettings",
                    reason = "missingLiveSettings",
                })
            end
        end
        return settings
    end
    return CloneSettingsValue(Nameplates.DEFAULTS)
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

    local keyboardOk, keyboardFont, keyboardStyle = true, nil, nil
    if type(GetNameplateKeyboardFont) == "function" then
        keyboardOk, keyboardFont, keyboardStyle = pcall(GetNameplateKeyboardFont)
        if keyboardOk then
            originalKeyboardFont, originalKeyboardStyle = keyboardFont, keyboardStyle
        else
            TraceNameplates("nameplates.font_capture", "getter_failed", {
                fn = "Nameplates.CaptureOriginalNameplateFonts",
                target = "keyboard",
                error = tostring(keyboardFont),
            })
        end
    end
    local gamepadOk, gamepadFont, gamepadStyle = true, nil, nil
    if type(GetNameplateGamepadFont) == "function" then
        gamepadOk, gamepadFont, gamepadStyle = pcall(GetNameplateGamepadFont)
        if gamepadOk then
            originalGamepadFont, originalGamepadStyle = gamepadFont, gamepadStyle
        else
            TraceNameplates("nameplates.font_capture", "getter_failed", {
                fn = "Nameplates.CaptureOriginalNameplateFonts",
                target = "gamepad",
                error = tostring(gamepadFont),
            })
        end
    end

    originalFontsCaptured = originalKeyboardFont ~= nil or originalGamepadFont ~= nil
    TraceNameplates("nameplates.font_capture", "end", {
        fn = "Nameplates.CaptureOriginalNameplateFonts",
        captured = originalFontsCaptured,
        keyboardFont = originalKeyboardFont,
        keyboardStyle = originalKeyboardStyle,
        gamepadFont = originalGamepadFont,
        gamepadStyle = originalGamepadStyle,
        keyboardOk = keyboardOk,
        gamepadOk = gamepadOk,
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
    local requestedSize = size
    size = ClampNameplateSize(size, DEFAULT_NAMEPLATE_SIZE)
    TraceNameplates("nameplates.font_apply", "begin", {
        fn = "Nameplates.ApplyNameplateFont",
        font = font,
        style = style,
        size = size,
        requestedSize = requestedSize,
        hasKeyboardSetter = type(SetNameplateKeyboardFont) == "function",
        hasGamepadSetter = type(SetNameplateGamepadFont) == "function",
    })
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SETTINGS, "nameplate font applied", { font = font, style = style, size = size })
    end
    CaptureOriginalNameplateFonts()
    style = NormalizeStyleValue(style)
    local fontString = font .. "|" .. tostring(size)
    local keyboardApplied = false
    local gamepadApplied = false
    local keyboardSkipped = false
    local gamepadSkipped = false
    local keyboardOk = true
    local gamepadOk = true
    local keyboardError = nil
    local gamepadError = nil
    if type(SetNameplateKeyboardFont) == "function" then
        local currentFont, currentStyle
        if type(GetNameplateKeyboardFont) == "function" then
            local ok, currentFontResult, currentStyleResult = pcall(GetNameplateKeyboardFont)
            if ok then
                currentFont, currentStyle = currentFontResult, currentStyleResult
            end
        end
        if currentFont == fontString and currentStyle == style then
            keyboardSkipped = true
        else
            keyboardOk, keyboardError = pcall(SetNameplateKeyboardFont, fontString, style)
            keyboardApplied = keyboardOk == true
            if not keyboardOk then
                TraceNameplates("nameplates.font_apply", "setter_failed", {
                    fn = "Nameplates.ApplyNameplateFont",
                    target = "keyboard",
                    fontString = fontString,
                    style = style,
                    error = tostring(keyboardError),
                })
            end
        end
    end
    if type(SetNameplateGamepadFont) == "function" then
        local currentFont, currentStyle
        if type(GetNameplateGamepadFont) == "function" then
            local ok, currentFontResult, currentStyleResult = pcall(GetNameplateGamepadFont)
            if ok then
                currentFont, currentStyle = currentFontResult, currentStyleResult
            end
        end
        if currentFont == fontString and currentStyle == style then
            gamepadSkipped = true
        else
            gamepadOk, gamepadError = pcall(SetNameplateGamepadFont, fontString, style)
            gamepadApplied = gamepadOk == true
            if not gamepadOk then
                TraceNameplates("nameplates.font_apply", "setter_failed", {
                    fn = "Nameplates.ApplyNameplateFont",
                    target = "gamepad",
                    fontString = fontString,
                    style = style,
                    error = tostring(gamepadError),
                })
            end
        end
    end
    TraceNameplates("nameplates.font_apply", "end", {
        fn = "Nameplates.ApplyNameplateFont",
        fontString = fontString,
        style = style,
        size = size,
        keyboardApplied = keyboardApplied,
        gamepadApplied = gamepadApplied,
        keyboardSkipped = keyboardSkipped,
        gamepadSkipped = gamepadSkipped,
        keyboardOk = keyboardOk,
        gamepadOk = gamepadOk,
        keyboardError = keyboardOk and nil or tostring(keyboardError),
        gamepadError = gamepadOk and nil or tostring(gamepadError),
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
        local keyboardOk = true
        local gamepadOk = true
        local keyboardError = nil
        local gamepadError = nil
        if originalKeyboardFont ~= nil and type(SetNameplateKeyboardFont) == "function" then
            keyboardOk, keyboardError = pcall(SetNameplateKeyboardFont, originalKeyboardFont, originalKeyboardStyle)
        end
        if originalGamepadFont ~= nil and type(SetNameplateGamepadFont) == "function" then
            gamepadOk, gamepadError = pcall(SetNameplateGamepadFont, originalGamepadFont, originalGamepadStyle)
        end
        TraceNameplates("nameplates.reset", "restored_original", {
            fn = "Nameplates.ResetToDefaults",
            keyboardFont = originalKeyboardFont,
            keyboardStyle = originalKeyboardStyle,
            gamepadFont = originalGamepadFont,
            gamepadStyle = originalGamepadStyle,
            keyboardOk = keyboardOk,
            gamepadOk = gamepadOk,
            keyboardError = keyboardOk and nil or tostring(keyboardError),
            gamepadError = gamepadOk and nil or tostring(gamepadError),
        })
        TraceNameplates("nameplates.reset", "end", {
            fn = "Nameplates.ResetToDefaults",
            restored = true,
            originalFontsCaptured = true,
            keyboardOk = keyboardOk,
            gamepadOk = gamepadOk,
        })
        return
    end

    local currentKeyboardFont, currentKeyboardStyle, currentGamepadFont, currentGamepadStyle
    if type(GetNameplateKeyboardFont) == "function" then
        local ok, font, style = pcall(GetNameplateKeyboardFont)
        if ok then
            currentKeyboardFont, currentKeyboardStyle = font, style
        end
    end
    if type(GetNameplateGamepadFont) == "function" then
        local ok, font, style = pcall(GetNameplateGamepadFont)
        if ok then
            currentGamepadFont, currentGamepadStyle = font, style
        end
    end
    TraceNameplates("nameplates.reset", "skipped", {
        fn = "Nameplates.ResetToDefaults",
        reason = "originalFontsNotCaptured",
        currentKeyboardFont = currentKeyboardFont,
        currentKeyboardStyle = currentKeyboardStyle,
        currentGamepadFont = currentGamepadFont,
        currentGamepadStyle = currentGamepadStyle,
        hasKeyboardGetter = type(GetNameplateKeyboardFont) == "function",
        hasGamepadGetter = type(GetNameplateGamepadFont) == "function",
    })
    TraceNameplates("nameplates.reset", "end", {
        fn = "Nameplates.ResetToDefaults",
        restored = false,
        originalFontsCaptured = false,
    })
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
    m_options.style = NormalizeStyleValue(m_options.style)
    m_options.size = ClampNameplateSize(m_options.size, defaults.size)

    local currentLang = GetCVar("language.2") or "en"
    local languageGroup = ResolveLanguageGroup(currentLang)

    if not IsFontLocalizedForCurrentLanguage(m_options.font, languageGroup) then
        TraceNameplates("nameplates.init", "localized_font_fallback", {
            fn = "Nameplates.InitModule",
            language = currentLang,
            languageGroup = languageGroup,
            originalFont = m_options.font,
            fallbackFont = "$(BOLD_FONT)",
        })
        m_options.font = "$(BOLD_FONT)"
    end

    TraceNameplates("nameplates.init", "end", {
        fn = "Nameplates.InitModule",
        language = currentLang,
        languageGroup = languageGroup,
        enabled = m_options.m_enabled,
        font = m_options.font,
        style = m_options.style,
        size = m_options.size,
    })
    return m_options
end
