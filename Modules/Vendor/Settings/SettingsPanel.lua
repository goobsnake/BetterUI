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
    -- Abbreviate Currency
    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = GetString(rawget(_G, "SI_BETTERUI_ABBREVIATE_CURRENCY") or "Abbreviate Currency"),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_ABBREVIATE_CURRENCY_TOOLTIP") or "Show abbreviated currency values in vendor lists."),
        getFunc = function()
            return Vendor.GetSetting("abbreviateVendorCurrency") ~= false
        end,
        setFunc = function(value)
            Vendor.SetSetting("abbreviateVendorCurrency", value)
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

    -- FONT SETTINGS (shared CIM factory for parity with Banking/Inventory)
    local fontStrings = {
        header = SI_BETTERUI_VENDOR_FONT_HEADER,
        desc = SI_BETTERUI_VENDOR_FONT_DESC,
        nameSubmenu = SI_BETTERUI_VENDOR_NAME_FONT_SUBMENU,
        nameFont = SI_BETTERUI_VENDOR_NAME_FONT,
        nameFontTooltip = SI_BETTERUI_VENDOR_NAME_FONT_TOOLTIP,
        nameFontSize = SI_BETTERUI_VENDOR_NAME_FONT_SIZE,
        nameFontSizeTooltip = SI_BETTERUI_VENDOR_NAME_FONT_SIZE_TOOLTIP,
        nameFontStyle = SI_BETTERUI_VENDOR_NAME_FONT_STYLE,
        nameFontStyleTooltip = SI_BETTERUI_VENDOR_NAME_FONT_STYLE_TOOLTIP,
        nameReset = SI_BETTERUI_NAME_FONT_RESET,
        nameResetTooltip = SI_BETTERUI_NAME_FONT_RESET_TOOLTIP,
        columnSubmenu = SI_BETTERUI_VENDOR_COLUMN_FONT_SUBMENU,
        columnFont = SI_BETTERUI_VENDOR_COLUMN_FONT,
        columnFontTooltip = SI_BETTERUI_VENDOR_COLUMN_FONT_TOOLTIP,
        columnFontSize = SI_BETTERUI_VENDOR_COLUMN_FONT_SIZE,
        columnFontSizeTooltip = SI_BETTERUI_VENDOR_COLUMN_FONT_SIZE_TOOLTIP,
        columnFontStyle = SI_BETTERUI_VENDOR_COLUMN_FONT_STYLE,
        columnFontStyleTooltip = SI_BETTERUI_VENDOR_COLUMN_FONT_STYLE_TOOLTIP,
        columnReset = SI_BETTERUI_COLUMN_FONT_RESET,
        columnResetTooltip = SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP,
    }
    local fontOptions = BETTERUI.CIM.Settings.CreateFontSubmenuOptions(
        "Vendor",
        Vendor.DEFAULTS,
        Vendor.FONT_CHOICES,
        Vendor.FONT_VALUES,
        Vendor.FONTSTYLE_CHOICES,
        Vendor.FONTSTYLE_VALUES,
        fontStrings,
        RefreshVendorWindow
    )
    for _, opt in ipairs(fontOptions) do
        optionsData[#optionsData + 1] = opt
    end

    -- Register panel with LibAddonMenu2
    BETTERUI.CIM.TryCall("CIM.Settings.SortSettingsAlphabetically", optionsData, true)

    local LAM = LibAddonMenu2
    if LAM then
        LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
        LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsData)
    end
end
