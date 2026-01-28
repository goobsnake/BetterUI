--[[
File: Modules/Inventory/Settings/FontSettings.lua
Purpose: Manages font definitions and the font customization UI.
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Settings = BETTERUI.Inventory.Settings or {}

-- Font choices/values now use CIM shared definitions (see CIM/Core/FontDefinitions.lua)
BETTERUI.Inventory.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
BETTERUI.Inventory.FONT_VALUES = BETTERUI.CIM.Font.VALUES
BETTERUI.Inventory.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
BETTERUI.Inventory.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
BETTERUI.Inventory.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS

--- Returns the ESO font descriptor for the Name column.
function BETTERUI.Inventory.GetNameFontDescriptor()
    return BETTERUI.CIM.Font.GetModuleFontDescriptor("Inventory", "name")
end

--- Returns the ESO font descriptor for other columns (Type, Trait, Stat, Value).
function BETTERUI.Inventory.GetColumnFontDescriptor()
    return BETTERUI.CIM.Font.GetModuleFontDescriptor("Inventory", "column")
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
                        if BETTERUI_GAMEPAD_INVENTORY and BETTERUI_GAMEPAD_INVENTORY.RefreshItemList then
                            pcall(function() BETTERUI_GAMEPAD_INVENTORY:RefreshItemList() end)
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    scrollable = true,
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
                        if BETTERUI_GAMEPAD_INVENTORY and BETTERUI_GAMEPAD_INVENTORY.RefreshItemList then
                            pcall(function() BETTERUI_GAMEPAD_INVENTORY:RefreshItemList() end)
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
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
                        if BETTERUI_GAMEPAD_INVENTORY and BETTERUI_GAMEPAD_INVENTORY.RefreshItemList then
                            pcall(function() BETTERUI_GAMEPAD_INVENTORY:RefreshItemList() end)
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
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
                        if BETTERUI_GAMEPAD_INVENTORY and BETTERUI_GAMEPAD_INVENTORY.RefreshItemList then
                            pcall(function() BETTERUI_GAMEPAD_INVENTORY:RefreshItemList() end)
                        end
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
                        if BETTERUI_GAMEPAD_INVENTORY and BETTERUI_GAMEPAD_INVENTORY.RefreshItemList then
                            pcall(function() BETTERUI_GAMEPAD_INVENTORY:RefreshItemList() end)
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    scrollable = true,
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
                        if BETTERUI_GAMEPAD_INVENTORY and BETTERUI_GAMEPAD_INVENTORY.RefreshItemList then
                            pcall(function() BETTERUI_GAMEPAD_INVENTORY:RefreshItemList() end)
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
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
                        if BETTERUI_GAMEPAD_INVENTORY and BETTERUI_GAMEPAD_INVENTORY.RefreshItemList then
                            pcall(function() BETTERUI_GAMEPAD_INVENTORY:RefreshItemList() end)
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
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
                        if BETTERUI_GAMEPAD_INVENTORY and BETTERUI_GAMEPAD_INVENTORY.RefreshItemList then
                            pcall(function() BETTERUI_GAMEPAD_INVENTORY:RefreshItemList() end)
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "half",
                },
            },
        },
    }
end
