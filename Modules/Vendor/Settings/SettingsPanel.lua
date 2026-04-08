--[[
File: Modules/Vendor/Settings/SettingsPanel.lua
Purpose: LibAddonMenu2 settings panel for the Vendor module.

Registers:
  - General settings (carousel navigation, batch junk sell)
  - Font customization (Name column, Other columns)
  - Icon visibility toggles
  - Reset button
]]

local Vendor = BETTERUI.Vendor

-- Ensure Settings namespace
Vendor.Settings = Vendor.Settings or {}

-- PANEL REGISTRATION

---@param mId string Module identifier for LAM panel registration
---@param moduleName string Display name for the settings panel
function Vendor.Settings.RegisterPanel(mId, moduleName)
    local panelData = BETTERUI.Init_ModulePanel(moduleName, "Vendor Settings")

    local function RefreshVendorWindow()
        local instance = Vendor.instance
        if not (instance and instance.IsSceneShowing and instance:IsSceneShowing()) then
            return
        end

        if instance.RefreshList then
            instance:RefreshList()
        end
        if instance.RefreshVendorFooter then
            instance:RefreshVendorFooter()
        end
        if instance.RebuildCategoryHeader then
            instance:RebuildCategoryHeader()
        end
        if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
            KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
        end
    end

    local function ResetVendorGeneralSettings()
        if not BETTERUI.CIM.TryCall("CIM.Settings.ResetModuleSettingsByGroup", "Vendor", "general") then
            Vendor.SetSetting("enableCarousel", true)
            Vendor.SetSetting("enableBatchJunkSell", true)
        end
        RefreshVendorWindow()
    end

    local optionsData = {}

    -- GENERAL SETTINGS
    optionsData[#optionsData + 1] = {
        type = "header",
        name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_GENERAL_HEADER")),
    }
    optionsData[#optionsData + 1] = {
        type = "description",
        text = GetString(rawget(_G, "SI_BETTERUI_VENDOR_GENERAL_DESC")),
    }

    -- Carousel Navigation
    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = GetString(rawget(_G, "SI_BETTERUI_ENABLE_CAROUSEL_NAV")),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP")),
        getFunc = function()
            return Vendor.GetSetting("enableCarousel") ~= false
        end,
        setFunc = function(value)
            Vendor.SetSetting("enableCarousel", value)
            RefreshVendorWindow()
        end,
        width = "full",
    }

    -- Batch Junk Sell
    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_BATCH_JUNK_SELL")),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_VENDOR_BATCH_JUNK_SELL_TOOLTIP")),
        getFunc = function()
            return Vendor.GetSetting("enableBatchJunkSell") ~= false
        end,
        setFunc = function(value)
            Vendor.SetSetting("enableBatchJunkSell", value)
            RefreshVendorWindow()
        end,
        width = "full",
    }
    optionsData[#optionsData + 1] = {
        type = "button",
        name = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET")),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET_TOOLTIP")),
        func = function()
            ResetVendorGeneralSettings()
        end,
        width = "half",
    }

    -- ICON SETTINGS
    optionsData[#optionsData + 1] = BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption("Vendor", function()
        RefreshVendorWindow()
    end)

    -- FONT SETTINGS
    optionsData[#optionsData + 1] = {
        type = "header",
        name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_FONT_HEADER")),
    }
    optionsData[#optionsData + 1] = {
        type = "description",
        text = GetString(rawget(_G, "SI_BETTERUI_VENDOR_FONT_DESC")),
    }

    -- Name Column Font
    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_NAME_FONT_SUBMENU")),
        controls = {
            {
                type = "dropdown",
                name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_NAME_FONT")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_VENDOR_NAME_FONT_TOOLTIP")),
                choices = Vendor.FONT_CHOICES,
                choicesValues = Vendor.FONT_VALUES,
                getFunc = function()
                    return Vendor.GetSetting("nameFont") or Vendor.DEFAULTS.nameFont
                end,
                setFunc = function(value)
                    Vendor.SetSetting("nameFont", value)
                end,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_NAME_FONT_SIZE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_VENDOR_NAME_FONT_SIZE_TOOLTIP")),
                min = 10,
                max = 32,
                step = 1,
                getFunc = function()
                    return Vendor.GetSetting("nameFontSize") or Vendor.DEFAULTS.nameFontSize
                end,
                setFunc = function(value)
                    Vendor.SetSetting("nameFontSize", value)
                end,
                width = "full",
            },
            {
                type = "dropdown",
                name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_NAME_FONT_STYLE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_VENDOR_NAME_FONT_STYLE_TOOLTIP")),
                choices = Vendor.FONTSTYLE_CHOICES,
                choicesValues = Vendor.FONTSTYLE_VALUES,
                getFunc = function()
                    return Vendor.GetSetting("nameFontStyle") or Vendor.DEFAULTS.nameFontStyle
                end,
                setFunc = function(value)
                    Vendor.SetSetting("nameFontStyle", value)
                end,
                width = "full",
            },
            -- Name Font Reset
            {
                type = "button",
                name = GetString(rawget(_G, "SI_BETTERUI_NAME_FONT_RESET")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_NAME_FONT_RESET_TOOLTIP")),
                func = function()
                    Vendor.SetSetting("nameFont", Vendor.DEFAULTS.nameFont)
                    Vendor.SetSetting("nameFontSize", Vendor.DEFAULTS.nameFontSize)
                    Vendor.SetSetting("nameFontStyle", Vendor.DEFAULTS.nameFontStyle)
                end,
                width = "full",
            },
        },
    }

    -- Other Columns Font
    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_COLUMN_FONT_SUBMENU")),
        controls = {
            {
                type = "dropdown",
                name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_COLUMN_FONT")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_VENDOR_COLUMN_FONT_TOOLTIP")),
                choices = Vendor.FONT_CHOICES,
                choicesValues = Vendor.FONT_VALUES,
                getFunc = function()
                    return Vendor.GetSetting("columnFont") or Vendor.DEFAULTS.columnFont
                end,
                setFunc = function(value)
                    Vendor.SetSetting("columnFont", value)
                end,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_COLUMN_FONT_SIZE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_VENDOR_COLUMN_FONT_SIZE_TOOLTIP")),
                min = 10,
                max = 32,
                step = 1,
                getFunc = function()
                    return Vendor.GetSetting("columnFontSize") or Vendor.DEFAULTS.columnFontSize
                end,
                setFunc = function(value)
                    Vendor.SetSetting("columnFontSize", value)
                end,
                width = "full",
            },
            {
                type = "dropdown",
                name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_COLUMN_FONT_STYLE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_VENDOR_COLUMN_FONT_STYLE_TOOLTIP")),
                choices = Vendor.FONTSTYLE_CHOICES,
                choicesValues = Vendor.FONTSTYLE_VALUES,
                getFunc = function()
                    return Vendor.GetSetting("columnFontStyle") or Vendor.DEFAULTS.columnFontStyle
                end,
                setFunc = function(value)
                    Vendor.SetSetting("columnFontStyle", value)
                end,
                width = "full",
            },
            -- Column Font Reset
            {
                type = "button",
                name = GetString(rawget(_G, "SI_BETTERUI_COLUMN_FONT_RESET")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP")),
                func = function()
                    Vendor.SetSetting("columnFont", Vendor.DEFAULTS.columnFont)
                    Vendor.SetSetting("columnFontSize", Vendor.DEFAULTS.columnFontSize)
                    Vendor.SetSetting("columnFontStyle", Vendor.DEFAULTS.columnFontStyle)
                end,
                width = "full",
            },
        },
    }

    -- Register panel with LibAddonMenu2
    BETTERUI.CIM.TryCall("CIM.Settings.SortSettingsAlphabetically", optionsData, true)

    local LAM = LibAddonMenu2
    if LAM then
        LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
        LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsData)
    end
end
