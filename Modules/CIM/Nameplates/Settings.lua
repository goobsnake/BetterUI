--[[
    BetterUI Nameplate Settings
    Description: Configuration options for BetterUI Nameplate enhancements.
    Part of the General Interface module.
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.Nameplates == nil then BETTERUI.Nameplates = {} end

local NAMEPLATE_SIZE_MIN = 8
local NAMEPLATE_SIZE_MAX = 64
local DEFAULT_NAMEPLATE_SIZE = 16

-- Import shared utility (canonical definition in SettingsAccessor.lua)
local ClampInteger = BETTERUI.ClampInteger

--- @return table settings Nameplate settings table
local function GetNameplateSettings()
    return BETTERUI.GetModuleSettings("Nameplates")
end

--- @return table|nil settings Nameplate settings table (created if needed), or nil
local function EnsureNameplateSettings()
    return BETTERUI.EnsureModuleSettings("Nameplates")
end

--- @return boolean enabled True if nameplate module is enabled in settings
local function IsNameplateEnabled()
    local settings = GetNameplateSettings()
    return settings and settings.m_enabled == true
end

--- Returns the table of LAM settings options for Nameplates.
function BETTERUI.Nameplates.GetSettingsOptions()
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
                (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS and BETTERUI.Nameplates.DEFAULTS.m_enabled) or false
            ),
            getFunc = function()
                return IsNameplateEnabled()
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then return end

                settings.m_enabled = value
                if BETTERUI.Nameplates and BETTERUI.Nameplates.OnEnabledChanged then
                    BETTERUI.Nameplates.OnEnabledChanged(value)
                end
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_FONT")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_FONT_TOOLTIP")),
            choices = BETTERUI.CIM.Font.Localization.GetFilteredFontChoices(
                BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_CHOICES or {},
                BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_VALUES or {}
            ),
            choicesValues = BETTERUI.CIM.Font.Localization.GetFilteredFontValues(
                BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_CHOICES or {},
                BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_VALUES or {}
            ),
            default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.font,
            getFunc = function()
                local defaults = (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS) or { font = "$(BOLD_FONT)" }
                local settings = GetNameplateSettings()
                return (settings and settings.font) or defaults.font
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then return end

                settings.font = value
                if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
                    BETTERUI.Nameplates.ApplyCurrentSettings()
                end
            end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "full",
            scrollable = true,
        },
        {
            type = "dropdown",
            name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_STYLE")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_STYLE_TOOLTIP")),
            choices = BETTERUI.Nameplates and BETTERUI.Nameplates.FONTSTYLE_CHOICES or {},
            choicesValues = BETTERUI.Nameplates and BETTERUI.Nameplates.FONTSTYLE_VALUES or {},
            default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.style,
            getFunc = function()
                local defaults = (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS) or { style = "outline" }
                local settings = GetNameplateSettings()
                return (settings and settings.style) or defaults.style
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then return end

                settings.style = value
                if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
                    BETTERUI.Nameplates.ApplyCurrentSettings()
                end
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
            default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.size or DEFAULT_NAMEPLATE_SIZE,
            getFunc = function()
                local settings = GetNameplateSettings()
                local defaultSize = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS and BETTERUI.Nameplates.DEFAULTS.size or
                    DEFAULT_NAMEPLATE_SIZE
                return ClampInteger(settings and settings.size, NAMEPLATE_SIZE_MIN, NAMEPLATE_SIZE_MAX, defaultSize)
            end,
            setFunc = function(value)
                local settings = EnsureNameplateSettings()
                if not settings then return end

                settings.size = value
                if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
                    BETTERUI.Nameplates.ApplyCurrentSettings()
                end
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
                if settings and BETTERUI.Nameplates then
                    local defaults = BETTERUI.Nameplates.DEFAULTS
                    settings.font = defaults.font
                    settings.style = defaults.style
                    settings.size = defaults.size
                    if BETTERUI.Nameplates.ApplyCurrentSettings then
                        BETTERUI.Nameplates.ApplyCurrentSettings()
                    end
                end
            end,
            disabled = function() return not IsNameplateEnabled() end,
            width = "half",
        },
    }
end

--- Initializes Nameplates default settings.
---
--- Purpose: Ensures Nameplate configuration has valid default values.
--- Mechanics:
--- - Checks for m_enabled state, font path, style (outline/soft-shadow-thick), and size.
--- - Preserves existing values if present.
---
--- References: Called during module initialization.
---
--- @param m_options table The options table to initialize.
--- @return table The initialized options table.
function BETTERUI.Nameplates.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.Nameplates.DEFAULTS
    -- Only set defaults if not already present (preserve existing settings)
    if m_options.m_enabled == nil then m_options.m_enabled = defaults.m_enabled end
    if m_options.font == nil then m_options.font = defaults.font end
    if m_options.style == nil then m_options.style = defaults.style end
    if m_options.size == nil then m_options.size = defaults.size end
    m_options.size = ClampInteger(m_options.size, NAMEPLATE_SIZE_MIN, NAMEPLATE_SIZE_MAX, defaults.size)

    -- Migration: Western-only fonts -> Localized font (for CJK/Russian support)
    -- Only migrate non-English users; English users keep their font selections
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
