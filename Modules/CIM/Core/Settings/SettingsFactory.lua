--[[
File: Modules/CIM/Core/SettingsFactory.lua
Purpose: Settings sort helpers, panel factory, and font settings factory.
         Provides alphabetical sorting for LAM controls, module panel creation,
         and font submenu option generation.

Note: Settings metadata registry and default/reset functions are in SettingsMetadata.lua.
]]

-- ============================================================================
-- NAMESPACE INITIALIZATION
-- ============================================================================

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Settings then BETTERUI.CIM.Settings = {} end

-- ============================================================================
-- SETTINGS SORT HELPERS
-- ============================================================================

--- @param name string Raw LAM submenu name (may contain ESO color/texture markup)
--- @return string normalized Lowercase name with markup stripped and whitespace collapsed
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

--- @param controls table LAM controls array (mutated in place)
--- @param startIndex number First index of the contiguous submenu range
--- @param endIndex number Last index of the contiguous submenu range
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
--- @param controls table LAM controls array
--- @return table controls The same table reference, sorted in place
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

--- @param name string Raw setting control name (may contain ESO markup and warning symbols)
--- @return string normalized Lowercase name with markup and symbols stripped
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

--- @param control table LAM control definition
--- @return boolean sortable True if the control type is in the sortable set
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

--- @param controls table LAM controls array (mutated in place)
--- @param startIndex number First index of the contiguous sortable range
--- @param endIndex number Last index of the contiguous sortable range
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
--- @param controls table LAM controls array
--- @param recursive boolean|nil Recurse into submenus (default: true)
--- @return table controls The same table reference, sorted in place
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

-- ============================================================================
-- SETTINGS PANEL FACTORY
-- ============================================================================

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

-- ============================================================================
-- FONT SETTINGS FACTORY
-- ============================================================================

--[[
Function: BETTERUI.CIM.Settings.CreateFontSubmenuOptions
Creates LAM submenu options for font customization.
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
