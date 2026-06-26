--[[
File: Modules/TradingHouse/Settings/SettingsPanel.lua
Purpose: LibAddonMenu2 settings panel for the Trading House module.

Registers:
  - General settings (carousel navigation)
  - Font customization (Name column, Other columns)
  - Icon visibility toggles
  - Reset button
]]

local TH = BETTERUI.TradingHouse

-- Ensure Settings namespace
TH.Settings = TH.Settings or {}

-- PANEL REGISTRATION

---@param mId string Module identifier for LAM panel registration
---@param moduleName string Display name for the settings panel
function TH.Settings.RegisterPanel(mId, moduleName)
    local panelData = BETTERUI.Init_ModulePanel(moduleName, "Trading House Settings")

    local function RefreshTHWindow()
        local instance = TH.instance
        if not (instance and instance.IsSceneShowing and instance:IsSceneShowing()) then
            return
        end

        if instance.RefreshList then
            instance:RefreshList()
        end
        if instance.RefreshTHFooter then
            instance:RefreshTHFooter()
        end
        if instance.UpdateTabHeader then
            instance:UpdateTabHeader()
        end
        local updateCurrentKeybinds = BETTERUI.Interface and BETTERUI.Interface.UpdateCurrentKeybindGroups
        if updateCurrentKeybinds then
            updateCurrentKeybinds()
        end
    end

    local function ResetTHGeneralSettings()
        if not (BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup
                and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("TradingHouse", "general")) then
            TH.SetSetting("enableCarousel", true)
        end
        RefreshTHWindow()
    end

    local optionsData = {}

    -- GENERAL SETTINGS
    optionsData[#optionsData + 1] = {
        type = "header",
        name = GetString(rawget(_G, "SI_BETTERUI_TH_GENERAL_HEADER")),
    }
    optionsData[#optionsData + 1] = {
        type = "description",
        text = GetString(rawget(_G, "SI_BETTERUI_TH_GENERAL_DESC")),
    }

    -- Carousel Navigation
    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = GetString(rawget(_G, "SI_BETTERUI_ENABLE_CAROUSEL_NAV")),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP")),
        getFunc = function()
            return TH.GetSetting("enableCarousel") ~= false
        end,
        setFunc = function(value)
            TH.SetSetting("enableCarousel", value)
            RefreshTHWindow()
        end,
        width = "full",
    }

    optionsData[#optionsData + 1] = {
        type = "button",
        name = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET")),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET_TOOLTIP")),
        func = function()
            ResetTHGeneralSettings()
        end,
        width = "half",
    }

    -- ICON SETTINGS
    optionsData[#optionsData + 1] = BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption("TradingHouse", function()
        RefreshTHWindow()
    end)

    -- FONT SETTINGS
    optionsData[#optionsData + 1] = {
        type = "header",
        name = GetString(rawget(_G, "SI_BETTERUI_TH_FONT_HEADER")),
    }
    optionsData[#optionsData + 1] = {
        type = "description",
        text = GetString(rawget(_G, "SI_BETTERUI_TH_FONT_DESC")),
    }

    local fontStrings = {
        header = SI_BETTERUI_TH_FONT_HEADER,
        desc = SI_BETTERUI_TH_FONT_DESC,
        nameSubmenu = SI_BETTERUI_FONT_NAME_COLUMN,
        nameFont = SI_BETTERUI_BANK_NAME_FONT,
        nameFontTooltip = SI_BETTERUI_BANK_NAME_FONT_TOOLTIP,
        nameFontSize = SI_BETTERUI_BANK_NAME_FONT_SIZE,
        nameFontSizeTooltip = SI_BETTERUI_BANK_NAME_FONT_SIZE_TOOLTIP,
        nameFontStyle = SI_BETTERUI_BANK_NAME_FONT_STYLE,
        nameFontStyleTooltip = SI_BETTERUI_BANK_NAME_FONT_STYLE_TOOLTIP,
        nameReset = SI_BETTERUI_NAME_FONT_RESET,
        nameResetTooltip = SI_BETTERUI_NAME_FONT_RESET_TOOLTIP,
        columnSubmenu = SI_BETTERUI_FONT_OTHER_COLUMNS,
        columnFont = SI_BETTERUI_BANK_COLUMN_FONT,
        columnFontTooltip = SI_BETTERUI_BANK_COLUMN_FONT_TOOLTIP,
        columnFontSize = SI_BETTERUI_BANK_COLUMN_FONT_SIZE,
        columnFontSizeTooltip = SI_BETTERUI_BANK_COLUMN_FONT_SIZE_TOOLTIP,
        columnFontStyle = SI_BETTERUI_BANK_COLUMN_FONT_STYLE,
        columnFontStyleTooltip = SI_BETTERUI_BANK_COLUMN_FONT_STYLE_TOOLTIP,
        columnReset = SI_BETTERUI_COLUMN_FONT_RESET,
        columnResetTooltip = SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP,
    }
    local fontOptions = BETTERUI.CIM.Settings.CreateFontSubmenuOptions({
        moduleName = "TradingHouse",
        defaults = TH.DEFAULTS,
        fontChoices = TH.FONT_CHOICES,
        fontValues = TH.FONT_VALUES,
        styleChoices = TH.FONTSTYLE_CHOICES,
        styleValues = TH.FONTSTYLE_VALUES,
        strings = fontStrings,
        refreshFn = RefreshTHWindow,
    })
    for _, option in ipairs(fontOptions) do
        optionsData[#optionsData + 1] = option
    end

    -- REGISTER PANEL
    if BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.RegisterModulePanel then
        local panelId, panelReason = BETTERUI.CIM.Settings.RegisterModulePanel(mId, panelData, optionsData)
        if panelId then
            return true, panelId
        end
        return false, panelReason or "register_module_panel_failed"
    end

    return false, "missing_register_module_panel"
end
