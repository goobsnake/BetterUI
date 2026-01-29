--[[
File: Modules/Banking/Settings/SettingsPanel.lua
Purpose: Extracted LAM settings panel for Banking module.
         Matches Inventory's structure with dedicated Settings folder.
Author: BetterUI Team
Last Modified: 2026-01-28
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
        },
        -- Icon Visibility (using shared CIM factory)
    }

    -- Insert icon toggle options from CIM factory
    local iconOptions = BETTERUI.CIM.Settings.CreateIconToggleOptions("Banking", function()
        if BETTERUI.Banking.Class and BETTERUI.Banking.Class.RefreshList then
            BETTERUI.Banking.Class:RefreshList()
        end
    end)
    for _, opt in ipairs(iconOptions) do
        table.insert(optionsTable, opt)
    end

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
        if BETTERUI.Banking.Class and BETTERUI.Banking.Class.RefreshList then
            BETTERUI.Banking.Class:RefreshList()
        end
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

    LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
    LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end
