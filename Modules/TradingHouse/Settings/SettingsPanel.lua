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
        if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
            KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
        end
    end

    local function ResetTHGeneralSettings()
        if not BETTERUI.CIM.TryCall("CIM.Settings.ResetModuleSettingsByGroup", "TradingHouse", "general") then
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

    -- Name Column Font
    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_FONT_NAME_COLUMN")),
        controls = BETTERUI.CIM.Settings.CreateFontOptions("TradingHouse", "Name", function()
            RefreshTHWindow()
        end),
    }

    -- Other Columns Font
    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_FONT_OTHER_COLUMNS")),
        controls = BETTERUI.CIM.Settings.CreateFontOptions("TradingHouse", "Column", function()
            RefreshTHWindow()
        end),
    }

    -- REGISTER PANEL
    BETTERUI.CIM.Settings.RegisterModulePanel(panelData, optionsData)
end
