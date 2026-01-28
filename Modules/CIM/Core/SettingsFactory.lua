--[[
File: Modules/CIM/Core/SettingsFactory.lua
Purpose: Factory functions for creating standardized settings panels.
         Ensures consistent LAM panel appearance across modules.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-- ============================================================================
-- NAMESPACE INITIALIZATION
-- ============================================================================

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Settings then BETTERUI.CIM.Settings = {} end

-- ============================================================================
-- SETTINGS PANEL FACTORY
-- ============================================================================

--[[
Function: BETTERUI.Init_ModulePanel
Description: Creates a standardized module configuration panel for LibAddonMenu.
Rationale: Ensures consistent settings menu appearance across modules.
Mechanism: Returns a table matching LAM's panel specification.
References: Used by all Modules (Inventory, Banking, etc.) in their Initialization.
param: moduleName (string) - The display name of the module.
param: moduleDesc (string) - The description text.
return: table - The LAM panel configuration table.
]]
function BETTERUI.Init_ModulePanel(moduleName, moduleDesc)
    return {
        type = "panel",
        name = "|t24:24:/esoui/art/buttons/gamepad/xbox/nav_xbone_b.dds|t " .. BETTERUI.name .. " (" .. moduleName .. ")",
        displayName = "|c0066ffBETTERUI|r :: " .. moduleDesc,
        author = "prasoc, RockingDice, Goobsnake",
        version = BETTERUI.version,
        slashCommand = "/betterui",
        registerForRefresh = true,
        registerForDefaults = true
    }
end

-- ============================================================================
-- FONT SETTINGS FACTORY
-- ============================================================================

--[[
Function: BETTERUI.CIM.Settings.CreateFontSubmenuOptions
Description: Creates LAM submenu options for font customization.
Rationale: Consolidates identical font settings structure from Banking and Inventory.
Mechanism:
  1. Creates "Name Font" submenu with dropdown, size slider, style dropdown, reset button
  2. Creates "Column Font" submenu with dropdown, size slider, style dropdown, reset button
  3. Uses shared BETTERUI.CIM.Font definitions
param: moduleName (string) - The module name key (e.g., "Banking", "Inventory")
param: defaults (table) - Module-specific defaults with nameFont, nameFontSize, nameFontStyle, columnFont, columnFontSize, columnFontStyle
param: fontChoices (table) - Font name choices array
param: fontValues (table) - Font path values array
param: styleChoices (table) - Font style choices array
param: styleValues (table) - Font style values array
param: strings (table) - Localization string IDs { header, desc, nameSubmenu, nameFont, nameFontTooltip, nameFontSize, nameFontSizeTooltip, nameFontStyle, nameFontStyleTooltip, nameReset, nameResetTooltip, columnSubmenu, columnFont, columnFontTooltip, columnFontSize, columnFontSizeTooltip, columnFontStyle, columnFontStyleTooltip, columnReset, columnResetTooltip }
param: refreshFn (function|nil) - Optional live refresh callback
return: table - Array of LAM options (header, description, 2 submenus)
]]
function BETTERUI.CIM.Settings.CreateFontSubmenuOptions(moduleName, defaults, fontChoices, fontValues, styleChoices,
                                                        styleValues, strings, refreshFn)
    local function getSettings()
        return BETTERUI.Settings.Modules[moduleName]
    end

    local function isCIMDisabled()
        return not BETTERUI.Settings.Modules["CIM"].m_enabled
    end

    local options = {
        -- Font Customization Header
        {
            type = "header",
            name = GetString(strings.header),
            width = "full",
        },
        {
            type = "description",
            text = GetString(strings.desc),
            width = "full",
        },
        -- Name Font Submenu
        {
            type = "submenu",
            name = GetString(strings.nameSubmenu),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(strings.nameFont),
                    tooltip = GetString(strings.nameFontTooltip),
                    choices = fontChoices,
                    choicesValues = fontValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.nameFont end
                        return s.nameFont or defaults.nameFont
                    end,
                    setFunc = function(value)
                        local s = getSettings()
                        if s then s.nameFont = value end
                        if refreshFn then pcall(refreshFn) end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    scrollable = true,
                    default = defaults.nameFont,
                },
                {
                    type = "slider",
                    name = GetString(strings.nameFontSize),
                    tooltip = GetString(strings.nameFontSizeTooltip),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function()
                        local s = getSettings()
                        return (s and s.nameFontSize) or defaults.nameFontSize
                    end,
                    setFunc = function(value)
                        local s = getSettings()
                        if s then s.nameFontSize = value end
                        if refreshFn then pcall(refreshFn) end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    default = defaults.nameFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(strings.nameFontStyle),
                    tooltip = GetString(strings.nameFontStyleTooltip),
                    choices = styleChoices,
                    choicesValues = styleValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.nameFontStyle end
                        return s.nameFontStyle or defaults.nameFontStyle
                    end,
                    setFunc = function(value)
                        local s = getSettings()
                        if s then s.nameFontStyle = value end
                        if refreshFn then pcall(refreshFn) end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    default = defaults.nameFontStyle,
                },
                {
                    type = "button",
                    name = GetString(strings.nameReset),
                    tooltip = GetString(strings.nameResetTooltip),
                    func = function()
                        local s = getSettings()
                        if s then
                            s.nameFont = defaults.nameFont
                            s.nameFontSize = defaults.nameFontSize
                            s.nameFontStyle = defaults.nameFontStyle
                        end
                        if refreshFn then pcall(refreshFn) end
                    end,
                    disabled = isCIMDisabled,
                    width = "half",
                },
            },
        },
        -- Column Font Submenu
        {
            type = "submenu",
            name = GetString(strings.columnSubmenu),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(strings.columnFont),
                    tooltip = GetString(strings.columnFontTooltip),
                    choices = fontChoices,
                    choicesValues = fontValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.columnFont end
                        return s.columnFont or defaults.columnFont
                    end,
                    setFunc = function(value)
                        local s = getSettings()
                        if s then s.columnFont = value end
                        if refreshFn then pcall(refreshFn) end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    scrollable = true,
                    default = defaults.columnFont,
                },
                {
                    type = "slider",
                    name = GetString(strings.columnFontSize),
                    tooltip = GetString(strings.columnFontSizeTooltip),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function()
                        local s = getSettings()
                        return (s and s.columnFontSize) or defaults.columnFontSize
                    end,
                    setFunc = function(value)
                        local s = getSettings()
                        if s then s.columnFontSize = value end
                        if refreshFn then pcall(refreshFn) end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    default = defaults.columnFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(strings.columnFontStyle),
                    tooltip = GetString(strings.columnFontStyleTooltip),
                    choices = styleChoices,
                    choicesValues = styleValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.columnFontStyle end
                        return s.columnFontStyle or defaults.columnFontStyle
                    end,
                    setFunc = function(value)
                        local s = getSettings()
                        if s then s.columnFontStyle = value end
                        if refreshFn then pcall(refreshFn) end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    default = defaults.columnFontStyle,
                },
                {
                    type = "button",
                    name = GetString(strings.columnReset),
                    tooltip = GetString(strings.columnResetTooltip),
                    func = function()
                        local s = getSettings()
                        if s then
                            s.columnFont = defaults.columnFont
                            s.columnFontSize = defaults.columnFontSize
                            s.columnFontStyle = defaults.columnFontStyle
                        end
                        if refreshFn then pcall(refreshFn) end
                    end,
                    disabled = isCIMDisabled,
                    width = "half",
                },
            },
        },
    }

    return options
end
