--[[
File: Modules/CIM/Core/Settings/SettingsFactory.lua
Purpose: Settings sort helpers, panel factory, and font settings factory.
         Provides alphabetical sorting for LAM controls, module panel creation,
         and font submenu option generation.

Note: Settings metadata registry and default/reset functions are in SettingsMetadata.lua.
]]

-- NAMESPACE INITIALIZATION

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Settings then BETTERUI.CIM.Settings = {} end

-- SETTINGS SORT HELPERS

local function NormalizeSubmenuSortName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalized = name
    normalized = normalized:gsub("|c%x%x%x%x%x%x", "")
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("|t[^|]+|t", "")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", "")
    normalized = normalized:gsub("%s+$", "")

    if zo_strlower then
        return zo_strlower(normalized)
    end
    return string.lower(normalized)
end

local function SortSubmenuRangeByName(controls, startIndex, endIndex)
    local range = {}
    for i = startIndex, endIndex do
        range[#range + 1] = controls[i]
    end

    table.sort(range, function(left, right)
        local leftKey = NormalizeSubmenuSortName(left.name)
        local rightKey = NormalizeSubmenuSortName(right.name)
        if leftKey == rightKey then
            return tostring(left.name) < tostring(right.name)
        end
        return leftKey < rightKey
    end)

    for i = 1, #range do
        controls[startIndex + i - 1] = range[i]
    end
end

--- Sorts contiguous top-level submenu rows alphabetically by display name.
--- Non-submenu controls remain in-place.
function BETTERUI.CIM.Settings.SortTopLevelSubmenusAlphabetically(controls)
    if type(controls) ~= "table" then
        return controls
    end

    local index = 1
    while index <= #controls do
        local control = controls[index]
        local isSubmenu = type(control) == "table" and control.type == "submenu" and type(control.name) == "string"

        if isSubmenu then
            local startIndex = index
            local endIndex = index
            while endIndex + 1 <= #controls do
                local nextControl = controls[endIndex + 1]
                local nextIsSubmenu = type(nextControl) == "table" and nextControl.type == "submenu" and
                    type(nextControl.name) == "string"
                if not nextIsSubmenu then
                    break
                end
                endIndex = endIndex + 1
            end

            if endIndex > startIndex then
                SortSubmenuRangeByName(controls, startIndex, endIndex)
            end
            index = endIndex + 1
        else
            index = index + 1
        end
    end

    return controls
end

local SORTABLE_SETTING_TYPES = {
    checkbox = true,
    colorpicker = true,
    dropdown = true,
    editbox = true,
    slider = true,
    -- Intentionally exclude "button" so reset controls stay in authored bottom position.
}

local function NormalizeSettingSortName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalized = name
    normalized = normalized:gsub("|c%x%x%x%x%x%x", "") -- Color tags
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("|t[^|]+|t", "")      -- Texture tags
    normalized = normalized:gsub("^%s*⚠️%s*", "")
    normalized = normalized:gsub("^%s*⚠%s*", "")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", "")
    normalized = normalized:gsub("%s+$", "")

    if zo_strlower then
        return zo_strlower(normalized)
    end
    return string.lower(normalized)
end

local function IsSortableSettingControl(control)
    if type(control) ~= "table" then
        return false
    end
    local controlType = control.type
    if not controlType or not SORTABLE_SETTING_TYPES[controlType] then
        return false
    end
    return type(control.name) == "string"
end

local function SortSettingControlRange(controls, startIndex, endIndex)
    local range = {}
    for i = startIndex, endIndex do
        range[#range + 1] = controls[i]
    end

    local function GetSortWeight(control)
        if type(control) ~= "table" then
            return 1
        end
        if control.sortAlwaysFirst then
            return 0
        end
        if control.sortAlwaysLast then
            return 2
        end
        return 1
    end

    table.sort(range, function(left, right)
        local leftWeight = GetSortWeight(left)
        local rightWeight = GetSortWeight(right)
        if leftWeight ~= rightWeight then
            return leftWeight < rightWeight
        end

        local leftKey = NormalizeSettingSortName(left.name)
        local rightKey = NormalizeSettingSortName(right.name)
        if leftKey == rightKey then
            return tostring(left.name) < tostring(right.name)
        end
        return leftKey < rightKey
    end)

    for i = 1, #range do
        controls[startIndex + i - 1] = range[i]
    end
end

--- Sorts setting controls alphabetically by display name.
--- Behavior:
--- 1. Sorts only contiguous runs of setting controls (checkbox/dropdown/slider/etc.).
--- 2. Leaves structural controls (header/description/divider/submenu) in place.
--- 3. Optionally recurses into submenu controls.
function BETTERUI.CIM.Settings.SortSettingsAlphabetically(controls, recursive)
    if type(controls) ~= "table" then
        return controls
    end

    if recursive == nil then
        recursive = true
    end

    local index = 1
    while index <= #controls do
        local control = controls[index]

        if recursive and type(control) == "table" and control.type == "submenu" and type(control.controls) == "table" then
            if not control.disableAutoSort then
                BETTERUI.CIM.Settings.SortSettingsAlphabetically(control.controls, true)
            end
        end

        if IsSortableSettingControl(control) then
            local startIndex = index
            local endIndex = index
            while endIndex + 1 <= #controls and IsSortableSettingControl(controls[endIndex + 1]) do
                endIndex = endIndex + 1
            end
            if endIndex > startIndex then
                SortSettingControlRange(controls, startIndex, endIndex)
            end
            index = endIndex + 1
        else
            index = index + 1
        end
    end

    return controls
end

-- SETTINGS PANEL FACTORY

--[[
Function: BETTERUI.Init_ModulePanel
Creates a standardized module configuration panel for LibAddonMenu.
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

local function NormalizePanelRegistrationId(panelIdOrModuleName)
    if panelIdOrModuleName == nil then
        return nil
    end

    local normalized = tostring(panelIdOrModuleName)
    normalized = normalized:gsub("^%s+", "")
    normalized = normalized:gsub("%s+$", "")
    if normalized == "" then
        return nil
    end

    if normalized:find("^BETTERUI_") then
        return normalized
    end
    return "BETTERUI_" .. normalized
end

function BETTERUI.CIM.Settings.RegisterModulePanel(panelIdOrModuleName, panelData, optionsData)
    local panelId = NormalizePanelRegistrationId(panelIdOrModuleName)
    if not panelId or type(panelData) ~= "table" then
        return nil, "invalid_panel_registration"
    end

    optionsData = type(optionsData) == "table" and optionsData or {}
    BETTERUI.CIM.Settings.SortTopLevelSubmenusAlphabetically(optionsData)
    BETTERUI.CIM.Settings.SortSettingsAlphabetically(optionsData, true)

    local lam = LibAddonMenu2
    if not lam or not lam.RegisterAddonPanel or not lam.RegisterOptionControls then
        return nil, "lam_unavailable"
    end

    local panelOk = pcall(lam.RegisterAddonPanel, lam, panelId, panelData)
    if not panelOk then
        return nil, "register_addon_panel_failed"
    end

    local controlsOk = pcall(lam.RegisterOptionControls, lam, panelId, optionsData)
    if not controlsOk then
        return nil, "register_option_controls_failed"
    end

    return panelId
end

-- FONT SETTINGS FACTORY

--[[
Function: BETTERUI.CIM.Settings.CreateFontSubmenuOptions
Creates LAM submenu options for font customization.
Required contract:
{
    moduleName = string,
    defaults = table,
    fontChoices = table,
    fontValues = table,
    styleChoices = table,
    styleValues = table,
    strings = table,
    refreshFn = function|nil
}
1. Creates "Name Font" submenu with dropdown, size slider, style dropdown, reset button
2. Creates "Column Font" submenu with dropdown, size slider, style dropdown, reset button
3. Uses shared BETTERUI.CIM.Font definitions
return: table - Array of LAM options (header, description, 2 submenus)
]]
function BETTERUI.CIM.Settings.CreateFontSubmenuOptions(args)
    if type(args) ~= "table" then
        return {}
    end

    local moduleName = args.moduleName
    local defaults = args.defaults
    local fontChoices = args.fontChoices
    local fontValues = args.fontValues
    local styleChoices = args.styleChoices
    local styleValues = args.styleValues
    local strings = args.strings
    local refreshFn = args.refreshFn or args.refresh
    -- Apply language-based font filtering (non-English users only see compatible fonts)
    local Localization = BETTERUI.CIM.Font.Localization
    local filteredChoices, filteredValues = Localization.GetFilteredFontArrays(fontChoices, fontValues)

    local function getSettings()
        return BETTERUI.GetModuleSettings(moduleName)
    end

    local function ensureSettings()
        return BETTERUI.EnsureModuleSettings(moduleName)
    end

    local function isCIMDisabled()
        return not BETTERUI.GetModuleEnabled("CIM")
    end

    local minFontSize = BETTERUI.CIM.Font.SIZE_MIN or 12
    local maxFontSize = BETTERUI.CIM.Font.SIZE_MAX or 48

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
                    choices = filteredChoices,
                    choicesValues = filteredValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.nameFont end
                        return s.nameFont or defaults.nameFont
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.nameFont = value end
                        if refreshFn then refreshFn() end
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
                    min = minFontSize,
                    max = maxFontSize,
                    step = 1,
                    getFunc = function()
                        local s = getSettings()
                        return BETTERUI.CIM.Font.GetSizeValue((s and s.nameFontSize) or defaults.nameFontSize)
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.nameFontSize = value end
                        if refreshFn then refreshFn() end
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
                        local s = ensureSettings()
                        if s then s.nameFontStyle = value end
                        if refreshFn then refreshFn() end
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
                        local s = ensureSettings()
                        if s then
                            s.nameFont = defaults.nameFont
                            s.nameFontSize = defaults.nameFontSize
                            s.nameFontStyle = defaults.nameFontStyle
                        end
                        if refreshFn then refreshFn() end
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
                    choices = filteredChoices,
                    choicesValues = filteredValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.columnFont end
                        return s.columnFont or defaults.columnFont
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.columnFont = value end
                        if refreshFn then refreshFn() end
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
                    min = minFontSize,
                    max = maxFontSize,
                    step = 1,
                    getFunc = function()
                        local s = getSettings()
                        return BETTERUI.CIM.Font.GetSizeValue((s and s.columnFontSize) or defaults.columnFontSize)
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.columnFontSize = value end
                        if refreshFn then refreshFn() end
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
                        local s = ensureSettings()
                        if s then s.columnFontStyle = value end
                        if refreshFn then refreshFn() end
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
                        local s = ensureSettings()
                        if s then
                            s.columnFont = defaults.columnFont
                            s.columnFontSize = defaults.columnFontSize
                            s.columnFontStyle = defaults.columnFontStyle
                        end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "half",
                },
            },
        },
    }

    return options
end
