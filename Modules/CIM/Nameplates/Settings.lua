--[[
    BetterUI Nameplate Settings
    Description: Configuration options for BetterUI Nameplate enhancements.
    Part of the General Interface module.
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.Nameplates == nil then BETTERUI.Nameplates = {} end

local LAM = LibAddonMenu2

--- Returns the table of LAM settings options for Nameplates.
function BETTERUI.Nameplates.GetSettingsOptions()
    return {
        {
            type = "header",
            name = GetString(SI_BETTERUI_NAMEPLATES_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BETTERUI_NAMEPLATES_DESC),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_NAMEPLATES_ENABLED),
            tooltip = GetString(SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP),
            default = false,
            getFunc = function()
                return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].m_enabled) or
                    false
            end,
            setFunc = function(value)
                if BETTERUI.Settings.Modules["Nameplates"] then
                    BETTERUI.Settings.Modules["Nameplates"].m_enabled = value
                    if BETTERUI.Nameplates and BETTERUI.Nameplates.OnEnabledChanged then
                        BETTERUI.Nameplates.OnEnabledChanged(value)
                    end
                end
            end,
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(SI_BETTERUI_NAMEPLATES_FONT),
            tooltip = GetString(SI_BETTERUI_NAMEPLATES_FONT_TOOLTIP),
            choices = BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_CHOICES or {},
            choicesValues = BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_VALUES or {},
            default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.font,
            getFunc = function()
                local defaults = (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS) or { font = "$(BOLD_FONT)" }
                return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].font) or
                    defaults.font
            end,
            setFunc = function(value)
                if BETTERUI.Settings.Modules["Nameplates"] then
                    BETTERUI.Settings.Modules["Nameplates"].font = value
                    if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
                        BETTERUI.Nameplates.ApplyCurrentSettings()
                    end
                end
            end,
            disabled = function()
                return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].m_enabled)
            end,
            width = "full",
            scrollable = true,
        },
        {
            type = "dropdown",
            name = GetString(SI_BETTERUI_NAMEPLATES_STYLE),
            tooltip = GetString(SI_BETTERUI_NAMEPLATES_STYLE_TOOLTIP),
            choices = BETTERUI.Nameplates and BETTERUI.Nameplates.FONTSTYLE_CHOICES or {},
            choicesValues = BETTERUI.Nameplates and BETTERUI.Nameplates.FONTSTYLE_VALUES or {},
            default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.style,
            getFunc = function()
                local defaults = (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS) or { style = "outline" }
                return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].style) or
                    defaults.style
            end,
            setFunc = function(value)
                if BETTERUI.Settings.Modules["Nameplates"] then
                    BETTERUI.Settings.Modules["Nameplates"].style = value
                    if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
                        BETTERUI.Nameplates.ApplyCurrentSettings()
                    end
                end
            end,
            disabled = function()
                return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].m_enabled)
            end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_BETTERUI_NAMEPLATES_SIZE),
            tooltip = GetString(SI_BETTERUI_NAMEPLATES_SIZE_TOOLTIP),
            min = 8,
            max = 64,
            step = 1,
            default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.size or 16,
            getFunc = function()
                return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].size) or 16
            end,
            setFunc = function(value)
                if BETTERUI.Settings.Modules["Nameplates"] then
                    BETTERUI.Settings.Modules["Nameplates"].size = value
                    if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
                        BETTERUI.Nameplates.ApplyCurrentSettings()
                    end
                end
            end,
            disabled = function()
                return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].m_enabled)
            end,
            width = "full",
        },
        {
            type = "button",
            name = GetString(SI_BETTERUI_NAMEPLATES_RESET),
            tooltip = GetString(SI_BETTERUI_NAMEPLATES_RESET_TOOLTIP),
            func = function()
                if BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Nameplates then
                    local defaults = BETTERUI.Nameplates.DEFAULTS
                    BETTERUI.Settings.Modules["Nameplates"].font = defaults.font
                    BETTERUI.Settings.Modules["Nameplates"].style = defaults.style
                    BETTERUI.Settings.Modules["Nameplates"].size = defaults.size
                    if BETTERUI.Nameplates.ApplyCurrentSettings then
                        BETTERUI.Nameplates.ApplyCurrentSettings()
                    end
                end
            end,
            disabled = function()
                return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].m_enabled)
            end,
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

    -- Migration: Hardcoded Western fonts -> Localized font (for CJK support)
    local westernFontPaths = {
        ["EsoUI/Common/Fonts/Univers57.otf"] = true,
        ["EsoUI/Common/Fonts/Univers67.otf"] = true,
        ["EsoUI/Common/Fonts/FTN57.otf"] = true,
        ["EsoUI/Common/Fonts/FTN47.otf"] = true,
        ["EsoUI/Common/Fonts/FTN87.otf"] = true,
    }
    if m_options.font and westernFontPaths[m_options.font] then
        m_options.font = "$(BOLD_FONT)"
    end

    return m_options
end
