if BETTERUI == nil then BETTERUI = {} end
BETTERUI.GeneralInterface = BETTERUI.GeneralInterface or {}
local GeneralInterface = BETTERUI.GeneralInterface
BETTERUI.Nameplates = BETTERUI.Nameplates or {}
local Nameplates = BETTERUI.Nameplates
GeneralInterface.Nameplates = Nameplates

local NAMEPLATE_SIZE_MIN = 8
local NAMEPLATE_SIZE_MAX = 64
local DEFAULT_NAMEPLATE_SIZE = 16
local ClampInteger = BETTERUI.ClampInteger

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

local function NotifyNameplateToggleChanged(value)
    if type(Nameplates.OnEnabledChanged) == "function" then
        Nameplates.OnEnabledChanged(value)
    end
end

local function ApplyCurrentNameplateSettings()
    if type(Nameplates.ApplyCurrentSettings) == "function" then
        Nameplates.ApplyCurrentSettings()
    end
end

function Nameplates.GetSettingsOptions()
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
                if not settings then return end

                settings.m_enabled = value
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
                if not settings then return end

                settings.font = value
                ApplyCurrentNameplateSettings()
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
                local defaults = Nameplates.DEFAULTS or { style = "outline" }
                local settings = GetNameplateSettings()
                return (settings and settings.style) or defaults.style
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then return end

                settings.style = value
                ApplyCurrentNameplateSettings()
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
                return ClampInteger(settings and settings.size, NAMEPLATE_SIZE_MIN, NAMEPLATE_SIZE_MAX, defaultSize)
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then return end

                settings.size = value
                ApplyCurrentNameplateSettings()
            end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "full",
        },
        {
            type = "button",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_RESET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_RESET_TOOLTIP")),
            func = function()
                local settings = EnsureNameplateSettings()
                if settings then
                    local defaults = Nameplates.DEFAULTS
                    settings.font = defaults.font
                    settings.style = defaults.style
                    settings.size = defaults.size
                    if Nameplates.ApplyCurrentSettings then
                        Nameplates.ApplyCurrentSettings()
                    end
                end
            end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "half",
        },
    }
end

function Nameplates.InitModule(m_options)
    m_options = m_options or {}
    local defaults = Nameplates.DEFAULTS
    if m_options.m_enabled == nil then m_options.m_enabled = defaults.m_enabled end
    if m_options.font == nil then m_options.font = defaults.font end
    if m_options.style == nil then m_options.style = defaults.style end
    if m_options.size == nil then m_options.size = defaults.size end
    m_options.size = ClampInteger(m_options.size, NAMEPLATE_SIZE_MIN, NAMEPLATE_SIZE_MAX, defaults.size)

    local currentLang = GetCVar("language.2") or "en"
    local isEnglish = (currentLang == "en")

    if not isEnglish then
        local westernOnlyFonts = {
            ["EsoUI/Common/Fonts/Univers57.otf"] = true,
            ["EsoUI/Common/Fonts/Univers67.otf"] = true,
            ["EsoUI/Common/Fonts/FTN57.otf"] = true,
            ["EsoUI/Common/Fonts/FTN47.otf"] = true,
            ["EsoUI/Common/Fonts/FTN87.otf"] = true,
            ["EsoUI/Common/Fonts/ProseAntiquePSMT.otf"] = true,
            ["EsoUI/Common/Fonts/Handwritten_Bold.otf"] = true,
            ["EsoUI/Common/Fonts/TrajanPro-Regular.otf"] = true,
            ["EsoUI/Common/Fonts/Skyrim_Handwritten.otf"] = true,
            ["EsoUI/Common/Fonts/consola.otf"] = true,
        }
        if m_options.font and westernOnlyFonts[m_options.font] then
            m_options.font = "$(BOLD_FONT)"
        end
    end

    return m_options
end
