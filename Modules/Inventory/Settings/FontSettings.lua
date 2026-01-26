--[[
File: Modules/Inventory/Settings/FontSettings.lua
Purpose: Manages font definitions and the font customization UI.
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Settings = BETTERUI.Inventory.Settings or {}

-- Shared font choices for Inventory
BETTERUI.Inventory.FONT_CHOICES = {
    "Univers 57 (Default)",
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

BETTERUI.Inventory.FONT_VALUES = {
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

BETTERUI.Inventory.FONTSTYLE_CHOICES = {
    "Normal",
    "Outline",
    "Thick Outline",
    "Shadow",
    "Soft Shadow (Thick)",
    "Soft Shadow (Thin)",
}

BETTERUI.Inventory.FONTSTYLE_VALUES = {
    "",                  -- Normal (no style suffix)
    "outline",           -- Outline
    "thick-outline",     -- Thick Outline
    "shadow",            -- Shadow
    "soft-shadow-thick", -- Soft Shadow (Thick)
    "soft-shadow-thin",  -- Soft Shadow (Thin)
}

BETTERUI.Inventory.DEFAULTS = {
    nameFont = "EsoUI/Common/Fonts/FTN57.otf",
    nameFontSize = 24,
    nameFontStyle = "",
    columnFont = "EsoUI/Common/Fonts/FTN57.otf",
    columnFontSize = 24,
    columnFontStyle = "",
}

--- Converts a font size setting to a pixel value.
local function GetFontSizeValue(sizeValue)
    if type(sizeValue) == "number" then
        return sizeValue
    end
    return 24
end

--- Returns the ESO font descriptor for the Name column.
function BETTERUI.Inventory.GetNameFontDescriptor()
    local s = BETTERUI.Settings.Modules["Inventory"]
    local d = BETTERUI.Inventory.DEFAULTS
    local path = s.nameFont or d.nameFont
    local size = GetFontSizeValue(s.nameFontSize or d.nameFontSize)
    local style = s.nameFontStyle or d.nameFontStyle
    return style ~= "" and string.format("%s|%d|%s", path, size, style) or string.format("%s|%d", path, size)
end

--- Returns the ESO font descriptor for other columns (Type, Trait, Stat, Value).
function BETTERUI.Inventory.GetColumnFontDescriptor()
    local s = BETTERUI.Settings.Modules["Inventory"]
    local d = BETTERUI.Inventory.DEFAULTS
    local path = s.columnFont or d.columnFont
    local size = GetFontSizeValue(s.columnFontSize or d.columnFontSize)
    local style = s.columnFontStyle or d.columnFontStyle
    return style ~= "" and string.format("%s|%d|%s", path, size, style) or string.format("%s|%d", path, size)
end

--- Returns the LAM control list for Font Customization.
function BETTERUI.Inventory.Settings.GetFontOptions()
    return {
        {
            type = "header",
            name = GetString(SI_BETTERUI_INV_FONT_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BETTERUI_INV_FONT_DESC),
            width = "full",
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_INV_NAME_FONT_SUBMENU),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_INV_NAME_FONT),
                    tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_TOOLTIP),
                    choices = BETTERUI.Inventory.FONT_CHOICES,
                    choicesValues = BETTERUI.Inventory.FONT_VALUES,
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["Inventory"] then
                            return BETTERUI.Inventory.DEFAULTS.nameFont
                        end
                        return BETTERUI.Settings.Modules["Inventory"].nameFont or
                            BETTERUI.Inventory.DEFAULTS.nameFont
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Inventory"].nameFont = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    scrollable = true,
                    requiresReload = true,
                    default = BETTERUI.Inventory.DEFAULTS.nameFont,
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_INV_NAME_FONT_SIZE),
                    tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function()
                        local settings = BETTERUI.Settings.Modules["Inventory"]
                        local val = BETTERUI.Inventory.DEFAULTS.nameFontSize
                        if settings then
                            val = settings.nameFontSize or val
                        end
                        return val
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Inventory"].nameFontSize = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    requiresReload = true,
                    default = BETTERUI.Inventory.DEFAULTS.nameFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_INV_NAME_FONT_STYLE),
                    tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_STYLE_TOOLTIP),
                    choices = BETTERUI.Inventory.FONTSTYLE_CHOICES,
                    choicesValues = BETTERUI.Inventory.FONTSTYLE_VALUES,
                    getFunc = function()
                        return BETTERUI.Settings.Modules["Inventory"].nameFontStyle or
                            BETTERUI.Inventory.DEFAULTS.nameFontStyle
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Inventory"].nameFontStyle = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    requiresReload = true,
                    default = BETTERUI.Inventory.DEFAULTS.nameFontStyle,
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_NAME_FONT_RESET),
                    tooltip = GetString(SI_BETTERUI_NAME_FONT_RESET_TOOLTIP),
                    func = function()
                        local d = BETTERUI.Inventory.DEFAULTS
                        local s = BETTERUI.Settings.Modules["Inventory"]
                        s.nameFont = d.nameFont
                        s.nameFontSize = d.nameFontSize
                        s.nameFontStyle = d.nameFontStyle
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_INV_COLUMN_FONT_SUBMENU),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_INV_COLUMN_FONT),
                    tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_TOOLTIP),
                    choices = BETTERUI.Inventory.FONT_CHOICES,
                    choicesValues = BETTERUI.Inventory.FONT_VALUES,
                    getFunc = function()
                        return BETTERUI.Settings.Modules["Inventory"].columnFont or
                            BETTERUI.Inventory.DEFAULTS.columnFont
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Inventory"].columnFont = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    scrollable = true,
                    requiresReload = true,
                    default = BETTERUI.Inventory.DEFAULTS.columnFont,
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_INV_COLUMN_FONT_SIZE),
                    tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function()
                        local settings = BETTERUI.Settings.Modules["Inventory"]
                        local val = BETTERUI.Inventory.DEFAULTS.columnFontSize
                        if settings then
                            val = settings.columnFontSize or val
                        end
                        return val
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Inventory"].columnFontSize = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    requiresReload = true,
                    default = BETTERUI.Inventory.DEFAULTS.columnFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_INV_COLUMN_FONT_STYLE),
                    tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_STYLE_TOOLTIP),
                    choices = BETTERUI.Inventory.FONTSTYLE_CHOICES,
                    choicesValues = BETTERUI.Inventory.FONTSTYLE_VALUES,
                    getFunc = function()
                        return BETTERUI.Settings.Modules["Inventory"].columnFontStyle or
                            BETTERUI.Inventory.DEFAULTS.columnFontStyle
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Inventory"].columnFontStyle = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    requiresReload = true,
                    default = BETTERUI.Inventory.DEFAULTS.columnFontStyle,
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_COLUMN_FONT_RESET),
                    tooltip = GetString(SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP),
                    func = function()
                        local d = BETTERUI.Inventory.DEFAULTS
                        local s = BETTERUI.Settings.Modules["Inventory"]
                        s.columnFont = d.columnFont
                        s.columnFontSize = d.columnFontSize
                        s.columnFontStyle = d.columnFontStyle
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "half",
                },
            },
        },
    }
end
