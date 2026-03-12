--[[
File: Modules/Banking/Settings/SettingsPanel.lua
Purpose: Extracted LAM settings panel for Banking module.
         Matches Inventory's structure with dedicated Settings folder.
Author: BetterUI Team
Last Modified: 2026-02-08
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

    local function RefreshBankingWindowList()
        if BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.IsBankingSceneShowing then
            if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then
                return
            end
        end

        local bankingWindow = BETTERUI.Banking and BETTERUI.Banking.Window
        if bankingWindow and bankingWindow.RefreshList then
            bankingWindow:RefreshList()
        end
    end

    local function ApplyTriggerMode(useCategoryJump)
        local bankingWindow = BETTERUI.Banking and BETTERUI.Banking.Window
        if not bankingWindow then return end

        if bankingWindow.SetListsUseTriggerKeybinds then
            bankingWindow:SetListsUseTriggerKeybinds(useCategoryJump)
        end
        if bankingWindow.RefreshKeybinds then
            bankingWindow:RefreshKeybinds()
        end
    end

    local function ResetBankingGeneralSettings()
        if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
            BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("Banking", "general")
        else
            BETTERUI.Banking.SetSetting("enableCarousel", true)
            BETTERUI.Banking.SetSetting("useTriggersForSkip", false)
            BETTERUI.Banking.SetSetting("triggerSpeed", 10)
        end
        
        ApplyTriggerMode(BETTERUI.Banking.GetSetting("useTriggersForSkip"))

        local bankingWindow = BETTERUI.Banking and BETTERUI.Banking.Window
        if bankingWindow and bankingWindow.RebuildHeaderCategories then
            bankingWindow:RebuildHeaderCategories()
        end
        RefreshBankingWindowList()
    end

    local optionsTable = {
        {
            type = "header",
            name = GetString(SI_BETTERUI_BANK_GENERAL_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BETTERUI_BANK_GENERAL_DESC),
            width = "full",
        },
        -- Carousel Navigation
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV),
            tooltip = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP),
            getFunc = function()
                return BETTERUI.Banking.GetSetting("enableCarousel")
            end,
            setFunc = function(value)
                BETTERUI.Banking.SetSetting("enableCarousel", value)
                local bankingWindow = BETTERUI.Banking and BETTERUI.Banking.Window
                if bankingWindow and bankingWindow.RebuildHeaderCategories then
                    bankingWindow:RebuildHeaderCategories()
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_TRIGGER_SKIP_TYPE),
            tooltip = GetString(SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP),
            getFunc = function()
                return BETTERUI.Banking.GetSetting("useTriggersForSkip")
            end,
            setFunc = function(value)
                BETTERUI.Banking.SetSetting("useTriggersForSkip", value)
                ApplyTriggerMode(value)
            end,
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(SI_BETTERUI_TRIGGER_SKIP),
            tooltip = GetString(SI_BETTERUI_TRIGGER_SKIP_TOOLTIP),
            getFunc = function()
                local value = BETTERUI.Banking.GetSetting("triggerSpeed")
                return value and tostring(value) or "10"
            end,
            setFunc = function(value)
                local parsedValue = tonumber(value) or 10
                if parsedValue < 1 then parsedValue = 1 end
                if parsedValue > 1000 then parsedValue = 1000 end
                BETTERUI.Banking.SetSetting("triggerSpeed", parsedValue)
                ApplyTriggerMode(BETTERUI.Banking.GetSetting("useTriggersForSkip"))
            end,
            disabled = function() return not BETTERUI.Banking.GetSetting("useTriggersForSkip") end,
            width = "full",
            sortAlwaysLast = true,
        },
        {
            type = "button",
            name = GetString(SI_BETTERUI_GENERAL_RESET),
            tooltip = GetString(SI_BETTERUI_GENERAL_RESET_TOOLTIP),
            func = function()
                ResetBankingGeneralSettings()
            end,
            width = "half",
        },
        -- Icon Visibility (using shared CIM factory)
    }

    -- Item Icon Customization submenu (using shared CIM factory)
    table.insert(optionsTable, BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption("Banking", function()
        RefreshBankingWindowList()
    end))

    -- Font Customization (using CIM factory)
    local fontStrings = {
        header = SI_BETTERUI_BANK_FONT_HEADER,
        desc = SI_BETTERUI_BANK_FONT_DESC,
        nameSubmenu = SI_BETTERUI_BANK_NAME_FONT_SUBMENU,
        nameFont = SI_BETTERUI_BANK_NAME_FONT,
        nameFontTooltip = SI_BETTERUI_BANK_NAME_FONT_TOOLTIP,
        nameFontSize = SI_BETTERUI_BANK_NAME_FONT_SIZE,
        nameFontSizeTooltip = SI_BETTERUI_BANK_NAME_FONT_SIZE_TOOLTIP,
        nameFontStyle = SI_BETTERUI_BANK_NAME_FONT_STYLE,
        nameFontStyleTooltip = SI_BETTERUI_BANK_NAME_FONT_STYLE_TOOLTIP,
        nameReset = SI_BETTERUI_NAME_FONT_RESET,
        nameResetTooltip = SI_BETTERUI_NAME_FONT_RESET_TOOLTIP,
        columnSubmenu = SI_BETTERUI_BANK_COLUMN_FONT_SUBMENU,
        columnFont = SI_BETTERUI_BANK_COLUMN_FONT,
        columnFontTooltip = SI_BETTERUI_BANK_COLUMN_FONT_TOOLTIP,
        columnFontSize = SI_BETTERUI_BANK_COLUMN_FONT_SIZE,
        columnFontSizeTooltip = SI_BETTERUI_BANK_COLUMN_FONT_SIZE_TOOLTIP,
        columnFontStyle = SI_BETTERUI_BANK_COLUMN_FONT_STYLE,
        columnFontStyleTooltip = SI_BETTERUI_BANK_COLUMN_FONT_STYLE_TOOLTIP,
        columnReset = SI_BETTERUI_COLUMN_FONT_RESET,
        columnResetTooltip = SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP,
    }
    local fontRefreshFn = function()
        RefreshBankingWindowList()
    end
    local fontOptions = BETTERUI.CIM.Settings.CreateFontSubmenuOptions(
        "Banking",
        BETTERUI.Banking.DEFAULTS,
        BETTERUI.Banking.FONT_CHOICES,
        BETTERUI.Banking.FONT_VALUES,
        BETTERUI.Banking.FONTSTYLE_CHOICES,
        BETTERUI.Banking.FONTSTYLE_VALUES,
        fontStrings,
        fontRefreshFn
    )
    for _, opt in ipairs(fontOptions) do
        table.insert(optionsTable, opt)
    end

    -- Alphabetize top-level General settings and all submenu settings.
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.SortSettingsAlphabetically then
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(optionsTable, true)
    end

    LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
    LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end
