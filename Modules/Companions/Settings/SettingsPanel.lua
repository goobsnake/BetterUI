--[[
File: Modules/Companions/Settings/SettingsPanel.lua
Purpose: LibAddonMenu2 settings panel for the Companions module.
]]

local Companions = BETTERUI.Companions

Companions.Settings = Companions.Settings or {}

---@param mId string Module identifier for LAM panel registration
---@param moduleName string Display name for the settings panel
function Companions.Settings.RegisterPanel(mId, moduleName)
    local panelData = BETTERUI.Init_ModulePanel(moduleName, "Companions Settings")

    local function RefreshCompanionWindow()
        local instance = Companions.instance
        if not (instance and instance.IsSceneShowing and instance:IsSceneShowing()) then
            return
        end

        if instance.RefreshList then
            instance:RefreshList()
        end
        if instance.RefreshCompanionFooter then
            instance:RefreshCompanionFooter()
        end
    end

    local function ResetCompanionGeneralSettings()
        if not (BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup
                and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("Companions", "general")) then
            Companions.SetSetting("enableCompanionEquipment", true)
        end
        RefreshCompanionWindow()
    end

    local optionsData = {
        {
            type = "header",
            name = GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_GENERAL_HEADER")),
            width = "full",
        },
        {
            type = "description",
            text = GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_GENERAL_DESC")),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_ENABLE_EQUIPMENT")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_ENABLE_EQUIPMENT_TOOLTIP")),
            getFunc = function()
                return Companions.GetSetting("enableCompanionEquipment") ~= false
            end,
            setFunc = function(value)
                Companions.SetSetting("enableCompanionEquipment", value)
            end,
            width = "full",
            requiresReload = true,
        },
        {
            type = "button",
            name = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET_TOOLTIP")),
            func = function()
                ResetCompanionGeneralSettings()
            end,
            width = "half",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_INV_QUICK_DESTROY") or "Quick Destroy"),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_INV_QUICK_DESTROY_TOOLTIP") or "Skip confirmation dialog when destroying companion items."),
            getFunc = function()
                return Companions.GetSetting("quickDestroy") == true
            end,
            setFunc = function(value)
                Companions.SetSetting("quickDestroy", value)
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_INV_BATCH_DESTROY") or "Batch Destroy"),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_INV_BATCH_DESTROY_TOOLTIP") or "Allow batch-destroying selected companion items."),
            getFunc = function()
                return Companions.GetSetting("batchDestroy") ~= false
            end,
            setFunc = function(value)
                Companions.SetSetting("batchDestroy", value)
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_INV_BOE_PROTECTION") or "Bind-on-Equip Protection"),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_INV_BOE_PROTECTION_TOOLTIP") or "Show a confirmation dialog before equipping tradable companion items."),
            getFunc = function()
                return Companions.GetSetting("bindOnEquipProtection") ~= false
            end,
            setFunc = function(value)
                Companions.SetSetting("bindOnEquipProtection", value)
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_INV_COMPANION_JUNK") or "Enable Companion Junk"),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_INV_COMPANION_JUNK_TOOLTIP") or "Allow marking companion items as junk."),
            getFunc = function()
                return Companions.GetSetting("enableCompanionJunk") ~= false
            end,
            setFunc = function(value)
                Companions.SetSetting("enableCompanionJunk", value)
                RefreshCompanionWindow()
            end,
            width = "full",
        },
    }

    optionsData[#optionsData + 1] = BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption("Companions", function()
        RefreshCompanionWindow()
    end)

    local fontStrings = {
        header = SI_BETTERUI_COMPANIONS_FONT_HEADER,
        desc = SI_BETTERUI_COMPANIONS_FONT_DESC,
        nameSubmenu = SI_BETTERUI_COMPANIONS_NAME_FONT_SUBMENU,
        nameFont = SI_BETTERUI_COMPANIONS_NAME_FONT,
        nameFontTooltip = SI_BETTERUI_COMPANIONS_NAME_FONT_TOOLTIP,
        nameFontSize = SI_BETTERUI_COMPANIONS_NAME_FONT_SIZE,
        nameFontSizeTooltip = SI_BETTERUI_COMPANIONS_NAME_FONT_SIZE_TOOLTIP,
        nameFontStyle = SI_BETTERUI_COMPANIONS_NAME_FONT_STYLE,
        nameFontStyleTooltip = SI_BETTERUI_COMPANIONS_NAME_FONT_STYLE_TOOLTIP,
        nameReset = SI_BETTERUI_NAME_FONT_RESET,
        nameResetTooltip = SI_BETTERUI_NAME_FONT_RESET_TOOLTIP,
        columnSubmenu = SI_BETTERUI_COMPANIONS_COLUMN_FONT_SUBMENU,
        columnFont = SI_BETTERUI_COMPANIONS_COLUMN_FONT,
        columnFontTooltip = SI_BETTERUI_COMPANIONS_COLUMN_FONT_TOOLTIP,
        columnFontSize = SI_BETTERUI_COMPANIONS_COLUMN_FONT_SIZE,
        columnFontSizeTooltip = SI_BETTERUI_COMPANIONS_COLUMN_FONT_SIZE_TOOLTIP,
        columnFontStyle = SI_BETTERUI_COMPANIONS_COLUMN_FONT_STYLE,
        columnFontStyleTooltip = SI_BETTERUI_COMPANIONS_COLUMN_FONT_STYLE_TOOLTIP,
        columnReset = SI_BETTERUI_COLUMN_FONT_RESET,
        columnResetTooltip = SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP,
    }
    local fontOptions = BETTERUI.CIM.Settings.CreateFontSubmenuOptions(
        "Companions",
        Companions.DEFAULTS,
        Companions.FONT_CHOICES,
        Companions.FONT_VALUES,
        Companions.FONTSTYLE_CHOICES,
        Companions.FONTSTYLE_VALUES,
        fontStrings,
        RefreshCompanionWindow
    )
    for _, opt in ipairs(fontOptions) do
        optionsData[#optionsData + 1] = opt
    end

    if BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.SortSettingsAlphabetically then
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(optionsData, true)
    end

    local LAM = LibAddonMenu2
    if LAM then
        LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
        LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsData)
    end
end
