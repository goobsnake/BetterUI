--[[
File: Modules/Banking/Settings/SettingsPanel.lua
Purpose: Extracted LAM settings panel for Banking module.
         Matches Inventory's structure with dedicated Settings folder.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

local LAM = LibAddonMenu2

BETTERUI.Banking = BETTERUI.Banking or {}
BETTERUI.Banking.Settings = BETTERUI.Banking.Settings or {}

--[[
Function: BETTERUI.Banking.Settings.RegisterPanel
Description: Registers the Banking settings panel with LibAddonMenu.
Rationale: Defines the "Banking Improvement Settings" menu structure.
param: mId (string) - The module ID suffix.
param: moduleName (string) - The display name for the panel.
]]
function BETTERUI.Banking.Settings.RegisterPanel(mId, moduleName)
    local panelData = BETTERUI.Init_ModulePanel(moduleName, "Banking Improvement Settings")

    local optionsTable = {
        -- Carousel Navigation
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV),
            tooltip = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP),
            getFunc = function()
                return BETTERUI.Banking.GetSetting("enableCarousel")
            end,
            setFunc = function(value) BETTERUI.Banking.SetSetting("enableCarousel", value) end,
            width = "full",
            requiresReload = true,
        },
        -- Icon Visibility
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_ICON_UNBOUND),
            tooltip = GetString(SI_BETTERUI_ICON_UNBOUND_TOOLTIP),
            getFunc = function()
                local v = BETTERUI.Banking.GetSetting("showIconUnboundItem")
                return v == nil and true or v
            end,
            setFunc = function(value)
                BETTERUI.Banking.SetSetting("showIconUnboundItem", value)
                -- Refresh banking list if visible to apply change immediately
                if BETTERUI.Banking.Class and BETTERUI.Banking.Class.RefreshList then
                    pcall(function() BETTERUI.Banking.Class:RefreshList() end)
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_ICON_ENCHANTMENT),
            tooltip = GetString(SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP),
            getFunc = function()
                local v = BETTERUI.Banking.GetSetting("showIconEnchantment")
                return v == nil and true or v
            end,
            setFunc = function(value)
                BETTERUI.Banking.SetSetting("showIconEnchantment", value)
                -- Refresh banking list if visible to apply change immediately
                if BETTERUI.Banking.Class and BETTERUI.Banking.Class.RefreshList then
                    pcall(function() BETTERUI.Banking.Class:RefreshList() end)
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_ICON_SET_GEAR),
            tooltip = GetString(SI_BETTERUI_ICON_SET_GEAR_TOOLTIP),
            getFunc = function()
                local v = BETTERUI.Banking.GetSetting("showIconSetGear")
                return v == nil and true or v
            end,
            setFunc = function(value)
                BETTERUI.Banking.SetSetting("showIconSetGear", value)
                -- Refresh banking list if visible to apply change immediately
                if BETTERUI.Banking.Class and BETTERUI.Banking.Class.RefreshList then
                    pcall(function() BETTERUI.Banking.Class:RefreshList() end)
                end
            end,
            width = "full",
        },
        -- Font Customization Header
        {
            type = "header",
            name = GetString(SI_BETTERUI_BANK_FONT_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BETTERUI_BANK_FONT_DESC),
            width = "full",
        },
        -- Name Font Submenu
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_BANK_NAME_FONT_SUBMENU),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_BANK_NAME_FONT),
                    tooltip = GetString(SI_BETTERUI_BANK_NAME_FONT_TOOLTIP),
                    choices = BETTERUI.Banking.FONT_CHOICES,
                    choicesValues = BETTERUI.Banking.FONT_VALUES,
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["Banking"] then return BETTERUI.Banking.DEFAULTS.nameFont end
                        return BETTERUI.Settings.Modules["Banking"].nameFont or BETTERUI.Banking.DEFAULTS.nameFont
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Banking"].nameFont = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    scrollable = true,
                    requiresReload = true,
                    default = BETTERUI.Banking.DEFAULTS.nameFont,
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_BANK_NAME_FONT_SIZE),
                    tooltip = GetString(SI_BETTERUI_BANK_NAME_FONT_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function()
                        local settings = BETTERUI.Settings.Modules["Banking"]
                        local val = BETTERUI.Banking.DEFAULTS.nameFontSize
                        if settings then
                            val = settings.nameFontSize or val
                        end
                        return val
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Banking"].nameFontSize = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    requiresReload = true,
                    default = BETTERUI.Banking.DEFAULTS.nameFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_BANK_NAME_FONT_STYLE),
                    tooltip = GetString(SI_BETTERUI_BANK_NAME_FONT_STYLE_TOOLTIP),
                    choices = BETTERUI.Banking.FONTSTYLE_CHOICES,
                    choicesValues = BETTERUI.Banking.FONTSTYLE_VALUES,
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["Banking"] then return BETTERUI.Banking.DEFAULTS.nameFontStyle end
                        return BETTERUI.Settings.Modules["Banking"].nameFontStyle or
                            BETTERUI.Banking.DEFAULTS.nameFontStyle
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Banking"].nameFontStyle = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    requiresReload = true,
                    default = BETTERUI.Banking.DEFAULTS.nameFontStyle,
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_NAME_FONT_RESET),
                    tooltip = GetString(SI_BETTERUI_NAME_FONT_RESET_TOOLTIP),
                    func = function()
                        local defaults = BETTERUI.Banking.DEFAULTS
                        BETTERUI.Settings.Modules["Banking"].nameFont = defaults.nameFont
                        BETTERUI.Settings.Modules["Banking"].nameFontSize = defaults.nameFontSize
                        BETTERUI.Settings.Modules["Banking"].nameFontStyle = defaults.nameFontStyle
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "half",
                },
            },
        },
        -- Column Font Submenu
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_BANK_COLUMN_FONT_SUBMENU),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_BANK_COLUMN_FONT),
                    tooltip = GetString(SI_BETTERUI_BANK_COLUMN_FONT_TOOLTIP),
                    choices = BETTERUI.Banking.FONT_CHOICES,
                    choicesValues = BETTERUI.Banking.FONT_VALUES,
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["Banking"] then return BETTERUI.Banking.DEFAULTS.columnFont end
                        return BETTERUI.Settings.Modules["Banking"].columnFont or BETTERUI.Banking.DEFAULTS.columnFont
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Banking"].columnFont = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    scrollable = true,
                    requiresReload = true,
                    default = BETTERUI.Banking.DEFAULTS.columnFont,
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_BANK_COLUMN_FONT_SIZE),
                    tooltip = GetString(SI_BETTERUI_BANK_COLUMN_FONT_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function()
                        local settings = BETTERUI.Settings.Modules["Banking"]
                        local val = BETTERUI.Banking.DEFAULTS.columnFontSize
                        if settings then
                            val = settings.columnFontSize or val
                        end
                        return val
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Banking"].columnFontSize = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    requiresReload = true,
                    default = BETTERUI.Banking.DEFAULTS.columnFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_BANK_COLUMN_FONT_STYLE),
                    tooltip = GetString(SI_BETTERUI_BANK_COLUMN_FONT_STYLE_TOOLTIP),
                    choices = BETTERUI.Banking.FONTSTYLE_CHOICES,
                    choicesValues = BETTERUI.Banking.FONTSTYLE_VALUES,
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["Banking"] then
                            return BETTERUI.Banking.DEFAULTS
                                .columnFontStyle
                        end
                        return BETTERUI.Settings.Modules["Banking"].columnFontStyle or
                            BETTERUI.Banking.DEFAULTS.columnFontStyle
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["Banking"].columnFontStyle = value
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "full",
                    requiresReload = true,
                    default = BETTERUI.Banking.DEFAULTS.columnFontStyle,
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_COLUMN_FONT_RESET),
                    tooltip = GetString(SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP),
                    func = function()
                        local defaults = BETTERUI.Banking.DEFAULTS
                        BETTERUI.Settings.Modules["Banking"].columnFont = defaults.columnFont
                        BETTERUI.Settings.Modules["Banking"].columnFontSize = defaults.columnFontSize
                        BETTERUI.Settings.Modules["Banking"].columnFontStyle = defaults.columnFontStyle
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
                    width = "half",
                },
            },
        },
    }

    LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
    LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end
