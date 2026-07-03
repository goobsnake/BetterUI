if BETTERUI == nil then BETTERUI = {} end
BETTERUI.Nameplates = BETTERUI.Nameplates or {}
local Nameplates = BETTERUI.Nameplates
local NAMEPLATE_SIZE_MIN = 8
local NAMEPLATE_SIZE_MAX = 64
local DEFAULT_NAMEPLATE_SIZE = 16
local POSITION_OFFSET_MIN = -600
local POSITION_OFFSET_MAX = 600

local function GetCurrentSceneName()
    if SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
        local scene = SCENE_MANAGER:GetCurrentScene()
        if scene and scene.GetName then
            return scene:GetName()
        end
    end
    return nil
end

local function ClampNameplateSize(value, fallback)
    if type(Nameplates.ClampNameplateSize) == "function" then
        return Nameplates.ClampNameplateSize(value, fallback)
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

local function ClampPositionOffset(value)
    local numeric = tonumber(value) or 0
    numeric = math.floor(numeric + 0.5)
    if numeric < POSITION_OFFSET_MIN then
        return POSITION_OFFSET_MIN
    end
    if numeric > POSITION_OFFSET_MAX then
        return POSITION_OFFSET_MAX
    end
    return numeric
end

local function GetNameplateSettings()
    return BETTERUI.GetModuleSettings("Nameplates")
end

local function EnsureNameplateSettings()
    return BETTERUI.EnsureModuleSettings("Nameplates")
end

local function IsNameplateEnabled()
    local settings = GetNameplateSettings()
    return settings and settings.m_enabled == true
end

local function TraceNameplateSetting(settingName, phase, data)
    if not (BETTERUI and BETTERUI.Log and BETTERUI.Log.TraceEvent) then
        return
    end
    data = data or {}
    data.module = data.module or "Nameplates"
    data.feature = data.feature or "nameplates"
    data.setting = data.setting or settingName
    data.scene = data.scene or GetCurrentSceneName()
    if data.enabled == nil then
        data.enabled = IsNameplateEnabled()
    end
    if data.gamepadMode == nil and type(IsInGamepadPreferredMode) == "function" then
        data.gamepadMode = IsInGamepadPreferredMode()
    end
    if BETTERUI.Log.SetLastAction then
        BETTERUI.Log.SetLastAction({ flow = "nameplates.setting", message = tostring(settingName) .. ":" .. phase })
    end
    local categories = BETTERUI.Log.CATEGORY or {}
    BETTERUI.Log.TraceEvent(categories.SETTINGS, "nameplates.setting", phase, data)
end

local function NotifyNameplateToggleChanged(value, suppressCleanupLog)
    local hasHandler = type(Nameplates.OnEnabledChanged) == "function"
    TraceNameplateSetting("m_enabled", hasHandler and "notify" or "notify_skipped", {
        fn = "Nameplates.NotifyNameplateToggleChanged",
        value = value,
        hasHandler = hasHandler,
        suppressCleanupLog = suppressCleanupLog,
    })
    if hasHandler then
        Nameplates.OnEnabledChanged(value, suppressCleanupLog)
    end
end

local function ApplyCurrentNameplateSettings(settingName, value)
    local hasHandler = type(Nameplates.ApplyCurrentSettings) == "function"
    TraceNameplateSetting(settingName or "unknown", hasHandler and "apply_bridge" or "apply_bridge_skipped", {
        fn = "Nameplates.ApplyCurrentNameplateSettings",
        value = value,
        hasHandler = hasHandler,
    })
    if hasHandler then
        Nameplates.ApplyCurrentSettings()
    end
end

function Nameplates.GetSettingsOptions()
    local function GetPositionDefault(key)
        local defaults = Nameplates.DEFAULTS or {}
        if defaults[key] ~= nil then
            return defaults[key]
        end
        return key:find("Offset", 1, true) and 0 or false
    end

    local function GetBooleanSetting(key)
        local settings = GetNameplateSettings()
        if settings and settings[key] ~= nil then
            return settings[key] == true
        end
        return GetPositionDefault(key) == true
    end

    local function GetOffsetSetting(key)
        local settings = GetNameplateSettings()
        return ClampPositionOffset(settings and settings[key] or GetPositionDefault(key))
    end

    local function SetSettingValue(key, value)
        local settings = EnsureNameplateSettings()
        if not settings then
            TraceNameplateSetting(key, "set_rejected", {
                fn = "Nameplates.Settings.SetSettingValue",
                reason = "settingsUnavailable",
                value = value,
            })
            return
        end
        local normalized = key:find("Offset", 1, true) and ClampPositionOffset(value) or value == true
        TraceNameplateSetting(key, "set_begin", {
            fn = "Nameplates.Settings.SetSettingValue",
            previous = settings[key],
            value = normalized,
        })
        settings[key] = normalized
        TraceNameplateSetting(key, "set_end", {
            fn = "Nameplates.Settings.SetSettingValue",
            value = settings[key],
        })
        ApplyCurrentNameplateSettings(key, normalized)
    end

    local function IsPositionSliderDisabled(elementKey)
        local positioning = Nameplates.Positioning
        if positioning and type(positioning.IsPositionControlDisabled) == "function" then
            return positioning.IsPositionControlDisabled(elementKey)
        end
        return not IsNameplateEnabled() or not GetBooleanSetting("nameplatePositionsUnlocked")
    end

    local function ResetPositionSettings()
        local settings = EnsureNameplateSettings()
        if not settings then
            TraceNameplateSetting("resetPositions", "set_rejected", {
                fn = "Nameplates.Settings.ResetPositionSettings",
                reason = "settingsUnavailable",
            })
            return
        end
        local positioning = Nameplates.Positioning
        TraceNameplateSetting("resetPositions", "set_begin", {
            fn = "Nameplates.Settings.ResetPositionSettings",
            moveCompassFrame = settings.moveCompassFrame,
            compassFrameOffsetX = settings.compassFrameOffsetX,
            compassFrameOffsetY = settings.compassFrameOffsetY,
            moveReticlePrompt = settings.moveReticlePrompt,
            reticlePromptOffsetX = settings.reticlePromptOffsetX,
            reticlePromptOffsetY = settings.reticlePromptOffsetY,
        })
        if positioning and type(positioning.ResetOffsets) == "function" then
            positioning.ResetOffsets(settings)
        else
            settings.nameplatePositionsUnlocked = false
            settings.moveCompassFrame = false
            settings.compassFrameOffsetX = 0
            settings.compassFrameOffsetY = 0
            settings.moveReticlePrompt = false
            settings.reticlePromptOffsetX = 0
            settings.reticlePromptOffsetY = 0
            ApplyCurrentNameplateSettings("resetPositions", "defaults")
        end
        TraceNameplateSetting("resetPositions", "set_end", {
            fn = "Nameplates.Settings.ResetPositionSettings",
            moveCompassFrame = settings.moveCompassFrame,
            compassFrameOffsetX = settings.compassFrameOffsetX,
            compassFrameOffsetY = settings.compassFrameOffsetY,
            moveReticlePrompt = settings.moveReticlePrompt,
            reticlePromptOffsetX = settings.reticlePromptOffsetX,
            reticlePromptOffsetY = settings.reticlePromptOffsetY,
        })
    end

    return {
        {
            type = "description",
            text = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_DESC")),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_ENABLED")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP")),
            default = BETTERUI.CIM.Settings.GetSettingDefault(
                "Nameplates",
                "m_enabled",
                (Nameplates.DEFAULTS and Nameplates.DEFAULTS.m_enabled) or false
            ),
            getFunc = function()
                return IsNameplateEnabled()
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then
                    TraceNameplateSetting("m_enabled", "set_rejected", {
                        fn = "Nameplates.Settings.m_enabled.setFunc",
                        reason = "settingsUnavailable",
                        value = value,
                    })
                    return
                end

                TraceNameplateSetting("m_enabled", "set_begin", {
                    fn = "Nameplates.Settings.m_enabled.setFunc",
                    previous = settings.m_enabled,
                    value = value,
                })
                settings.m_enabled = value
                TraceNameplateSetting("m_enabled", "set_end", {
                    fn = "Nameplates.Settings.m_enabled.setFunc",
                    value = settings.m_enabled,
                })
                NotifyNameplateToggleChanged(value)
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_FONT")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_FONT_TOOLTIP")),
            choices = BETTERUI.CIM.Font.Localization.GetFilteredFontChoices(
                Nameplates.FONT_CHOICES or {},
                Nameplates.FONT_VALUES or {}
            ),
            choicesValues = BETTERUI.CIM.Font.Localization.GetFilteredFontValues(
                Nameplates.FONT_CHOICES or {},
                Nameplates.FONT_VALUES or {}
            ),
            default = Nameplates.DEFAULTS and Nameplates.DEFAULTS.font,
            getFunc = function()
                local defaults = Nameplates.DEFAULTS or { font = "$(BOLD_FONT)" }
                local settings = GetNameplateSettings()
                return (settings and settings.font) or defaults.font
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then
                    TraceNameplateSetting("font", "set_rejected", {
                        fn = "Nameplates.Settings.font.setFunc",
                        reason = "settingsUnavailable",
                        value = value,
                    })
                    return
                end

                TraceNameplateSetting("font", "set_begin", {
                    fn = "Nameplates.Settings.font.setFunc",
                    previous = settings.font,
                    value = value,
                })
                settings.font = value
                TraceNameplateSetting("font", "set_end", {
                    fn = "Nameplates.Settings.font.setFunc",
                    value = settings.font,
                })
                ApplyCurrentNameplateSettings("font", value)
            end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "full",
            scrollable = true,
        },
        {
            type = "dropdown",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_STYLE")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_STYLE_TOOLTIP")),
            choices = Nameplates.FONTSTYLE_CHOICES or {},
            choicesValues = Nameplates.FONTSTYLE_VALUES or {},
            default = Nameplates.DEFAULTS and Nameplates.DEFAULTS.style,
            getFunc = function()
                local defaults = Nameplates.DEFAULTS or { style = FONT_STYLE_OUTLINE or 1 }
                local settings = GetNameplateSettings()
                local style = (settings and settings.style) or defaults.style
                if type(Nameplates.NormalizeStyleValue) == "function" then
                    return Nameplates.NormalizeStyleValue(style)
                end
                return style
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then
                    TraceNameplateSetting("style", "set_rejected", {
                        fn = "Nameplates.Settings.style.setFunc",
                        reason = "settingsUnavailable",
                        value = value,
                    })
                    return
                end

                TraceNameplateSetting("style", "set_begin", {
                    fn = "Nameplates.Settings.style.setFunc",
                    previous = settings.style,
                    value = value,
                })
                settings.style = value
                TraceNameplateSetting("style", "set_end", {
                    fn = "Nameplates.Settings.style.setFunc",
                    value = settings.style,
                })
                ApplyCurrentNameplateSettings("style", value)
            end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_SIZE")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_SIZE_TOOLTIP")),
            min = NAMEPLATE_SIZE_MIN,
            max = NAMEPLATE_SIZE_MAX,
            step = 1,
            default = Nameplates.DEFAULTS and Nameplates.DEFAULTS.size or DEFAULT_NAMEPLATE_SIZE,
            getFunc = function()
                local settings = GetNameplateSettings()
                local defaultSize = Nameplates.DEFAULTS and Nameplates.DEFAULTS.size or DEFAULT_NAMEPLATE_SIZE
                return ClampNameplateSize(settings and settings.size, defaultSize)
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then
                    TraceNameplateSetting("size", "set_rejected", {
                        fn = "Nameplates.Settings.size.setFunc",
                        reason = "settingsUnavailable",
                        value = value,
                    })
                    return
                end

                local defaultSize = Nameplates.DEFAULTS and Nameplates.DEFAULTS.size or DEFAULT_NAMEPLATE_SIZE
                TraceNameplateSetting("size", "set_begin", {
                    fn = "Nameplates.Settings.size.setFunc",
                    previous = settings.size,
                    value = value,
                    effectiveValue = ClampNameplateSize(value, defaultSize),
                })
                settings.size = ClampNameplateSize(value, defaultSize)
                TraceNameplateSetting("size", "set_end", {
                    fn = "Nameplates.Settings.size.setFunc",
                    value = settings.size,
                    effectiveValue = ClampNameplateSize(settings.size, defaultSize),
                })
                ApplyCurrentNameplateSettings("size", settings.size)
            end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "full",
        },
        {
            type = "header",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_POSITION_HEADER")),
            width = "full",
        },
        {
            type = "description",
            text = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_POSITION_DESC")),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_UNLOCK_POSITIONS")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_UNLOCK_POSITIONS_TOOLTIP")),
            default = GetPositionDefault("nameplatePositionsUnlocked"),
            getFunc = function() return GetBooleanSetting("nameplatePositionsUnlocked") end,
            setFunc = function(value) SetSettingValue("nameplatePositionsUnlocked", value) end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_COMPASS")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_COMPASS_TOOLTIP")),
            default = GetPositionDefault("moveCompassFrame"),
            getFunc = function() return GetBooleanSetting("moveCompassFrame") end,
            setFunc = function(value) SetSettingValue("moveCompassFrame", value) end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_COMPASS_OFFSET_X")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_OFFSET_X_TOOLTIP")),
            min = POSITION_OFFSET_MIN,
            max = POSITION_OFFSET_MAX,
            step = 1,
            default = GetPositionDefault("compassFrameOffsetX"),
            getFunc = function() return GetOffsetSetting("compassFrameOffsetX") end,
            setFunc = function(value) SetSettingValue("compassFrameOffsetX", value) end,
            disabled = function() return IsPositionSliderDisabled("compass") end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_COMPASS_OFFSET_Y")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_OFFSET_Y_TOOLTIP")),
            min = POSITION_OFFSET_MIN,
            max = POSITION_OFFSET_MAX,
            step = 1,
            default = GetPositionDefault("compassFrameOffsetY"),
            getFunc = function() return GetOffsetSetting("compassFrameOffsetY") end,
            setFunc = function(value) SetSettingValue("compassFrameOffsetY", value) end,
            disabled = function() return IsPositionSliderDisabled("compass") end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_RETICLE")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_RETICLE_TOOLTIP")),
            default = GetPositionDefault("moveReticlePrompt"),
            getFunc = function() return GetBooleanSetting("moveReticlePrompt") end,
            setFunc = function(value) SetSettingValue("moveReticlePrompt", value) end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_RETICLE_OFFSET_X")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_OFFSET_X_TOOLTIP")),
            min = POSITION_OFFSET_MIN,
            max = POSITION_OFFSET_MAX,
            step = 1,
            default = GetPositionDefault("reticlePromptOffsetX"),
            getFunc = function() return GetOffsetSetting("reticlePromptOffsetX") end,
            setFunc = function(value) SetSettingValue("reticlePromptOffsetX", value) end,
            disabled = function() return IsPositionSliderDisabled("reticle") end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_RETICLE_OFFSET_Y")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_OFFSET_Y_TOOLTIP")),
            min = POSITION_OFFSET_MIN,
            max = POSITION_OFFSET_MAX,
            step = 1,
            default = GetPositionDefault("reticlePromptOffsetY"),
            getFunc = function() return GetOffsetSetting("reticlePromptOffsetY") end,
            setFunc = function(value) SetSettingValue("reticlePromptOffsetY", value) end,
            disabled = function() return IsPositionSliderDisabled("reticle") end,
            width = "full",
        },
        {
            type = "button",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_RESET_POSITIONS")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_RESET_POSITIONS_TOOLTIP")),
            func = ResetPositionSettings,
            disabled = function() return not IsNameplateEnabled() end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_RESET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_RESET_TOOLTIP")),
            func = function()
                local settings = EnsureNameplateSettings()
                if not settings then
                    TraceNameplateSetting("reset", "set_rejected", {
                        fn = "Nameplates.Settings.reset.func",
                        reason = "settingsUnavailable",
                    })
                    return
                end

                local defaults = Nameplates.DEFAULTS
                TraceNameplateSetting("reset", "set_begin", {
                    fn = "Nameplates.Settings.reset.func",
                    previousFont = settings.font,
                    previousStyle = settings.style,
                    previousSize = settings.size,
                    previousPositionsUnlocked = settings.nameplatePositionsUnlocked,
                    previousMoveCompassFrame = settings.moveCompassFrame,
                    previousCompassFrameOffsetX = settings.compassFrameOffsetX,
                    previousCompassFrameOffsetY = settings.compassFrameOffsetY,
                    previousMoveReticlePrompt = settings.moveReticlePrompt,
                    previousReticlePromptOffsetX = settings.reticlePromptOffsetX,
                    previousReticlePromptOffsetY = settings.reticlePromptOffsetY,
                    defaultFont = defaults and defaults.font,
                    defaultStyle = defaults and defaults.style,
                    defaultSize = defaults and defaults.size,
                })
                settings.font = defaults.font
                settings.style = defaults.style
                settings.size = defaults.size
                settings.nameplatePositionsUnlocked = defaults.nameplatePositionsUnlocked
                settings.moveCompassFrame = defaults.moveCompassFrame
                settings.compassFrameOffsetX = defaults.compassFrameOffsetX
                settings.compassFrameOffsetY = defaults.compassFrameOffsetY
                settings.moveReticlePrompt = defaults.moveReticlePrompt
                settings.reticlePromptOffsetX = defaults.reticlePromptOffsetX
                settings.reticlePromptOffsetY = defaults.reticlePromptOffsetY
                TraceNameplateSetting("reset", "set_end", {
                    fn = "Nameplates.Settings.reset.func",
                    font = settings.font,
                    style = settings.style,
                    size = settings.size,
                    positionsUnlocked = settings.nameplatePositionsUnlocked,
                    moveCompassFrame = settings.moveCompassFrame,
                    compassFrameOffsetX = settings.compassFrameOffsetX,
                    compassFrameOffsetY = settings.compassFrameOffsetY,
                    moveReticlePrompt = settings.moveReticlePrompt,
                    reticlePromptOffsetX = settings.reticlePromptOffsetX,
                    reticlePromptOffsetY = settings.reticlePromptOffsetY,
                })
                ApplyCurrentNameplateSettings("reset", "defaults")
            end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "half",
        },
    }
end
