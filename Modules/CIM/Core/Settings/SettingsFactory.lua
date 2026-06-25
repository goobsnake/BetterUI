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

local function DescribeSettingsValue(value, depth)
    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end
    if valueType == "string" then
        if #value > 160 then
            return value:sub(1, 157) .. "..."
        end
        return value
    end
    if valueType == "function" then
        return "<function>"
    end
    if valueType ~= "table" then
        return "<" .. valueType .. ">"
    end
    depth = depth or 0
    if depth >= 2 then
        return "<table>"
    end
    local parts = {}
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 6 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = tostring(key) .. "=" .. DescribeSettingsValue(item, depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function DescribeSettingsValues(...)
    local count = select("#", ...)
    if count == 0 then
        return nil
    end
    if count == 1 then
        return DescribeSettingsValue((...))
    end
    local values = {}
    for i = 1, count do
        values[#values + 1] = DescribeSettingsValue(select(i, ...))
    end
    return table.concat(values, "|")
end


local function CapturePcallResults(ok, ...)
    return { ok = ok, n = select("#", ...), ... }
end

local function DescribePackedResults(results)
    if type(results) ~= "table" then return nil end
    return DescribeSettingsValues(unpack(results, 1, results.n or 0))
end

local function ResolveControlTraceName(control)
    if type(control) ~= "table" then return nil end
    if type(control.name) == "function" then
        return "<dynamic>"
    end
    if control.name ~= nil then
        return tostring(control.name)
    end
    if type(control.text) == "function" then
        return "<dynamicText>"
    end
    if control.text ~= nil then
        return tostring(control.text)
    end
    return nil
end

local function SettingsTraceEnabled()
    local L = BETTERUI.Log
    if not L then return false end
    if L.EnabledFor and L.LEVEL and L.CATEGORY then
        return L.EnabledFor(L.LEVEL.INFO, L.CATEGORY.SETTINGS)
    end
    return type(L.TraceEvent) == "function"
end

local function TraceSettings(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    L.TraceEvent(L.CATEGORY.SETTINGS, event, phase, data or {}, L.LEVEL.INFO)
end

local function CountControls(controls)
    if type(controls) ~= "table" then return 0 end
    local count = 0
    for _, control in ipairs(controls) do
        count = count + 1
        if type(control) == "table" and type(control.controls) == "table" then
            count = count + CountControls(control.controls)
        end
    end
    return count
end

local function BuildControlTraceData(panelId, control, path, extra)
    local data = extra or {}
    data.panel = panelId
    data.path = path
    if type(control) == "table" then
        data.type = control.type
        data.name = data.name or ResolveControlTraceName(control)
        data.width = control.width
        data.requiresReload = control.requiresReload == true
        data.hasGet = type(control.getFunc) == "function"
        data.hasSet = type(control.setFunc) == "function"
        data.hasFunc = type(control.func) == "function"
        data.hasDisabled = type(control.disabled) == "function"
        data.hasWarning = type(control.warning) == "function"
        data.default = control.default ~= nil and DescribeSettingsValue(control.default) or nil
        data.min = control.min
        data.max = control.max
        data.step = control.step
    end
    return data
end

--- Wraps each control's setFunc so user-driven setting changes stream to the
--- diagnostics sink (panel + setting name + new value). Inert when logging is
--- inactive — the wrapper only formats a line behind Log.IsActive(); the original
--- setter always runs. Recurses into submenu controls and is idempotent via a
--- private marker so panel refresh/re-registration never stacks wrappers.
local function InstrumentSettingControls(controls, panelId, parentPath)
    if type(controls) ~= "table" then return end
    for index, control in ipairs(controls) do
        if type(control) == "table" then
            local controlPath = parentPath and (parentPath .. "." .. tostring(index)) or tostring(index)
            TraceSettings("settings.control", "registered", BuildControlTraceData(panelId, control, controlPath))
            if type(control.getFunc) == "function" and not control.__buiGetFuncInstrumented then
                local originalGetFunc = control.getFunc
                control.getFunc = function(...)
                    local results = CapturePcallResults(pcall(originalGetFunc, ...))
                    if not results.ok then
                        TraceSettings("settings.control", "get_error", BuildControlTraceData(panelId, control, controlPath, {
                            error = tostring(results[1]),
                        }))
                        error(results[1], 2)
                    end
                    TraceSettings("settings.control", "get", BuildControlTraceData(panelId, control, controlPath, {
                        value = DescribePackedResults(results),
                    }))
                    return unpack(results, 1, results.n)
                end
                control.__buiGetFuncInstrumented = true
            end
            if type(control.setFunc) == "function" and not control.__buiSetFuncInstrumented then
                local originalSetFunc = control.setFunc
                control.setFunc = function(...)
                    local captureValues = SettingsTraceEnabled()
                    local oldValue = nil
                    if captureValues and type(control.getFunc) == "function" then
                        local oldResults = CapturePcallResults(pcall(control.getFunc))
                        oldValue = oldResults.ok and DescribePackedResults(oldResults) or ("error:" .. tostring(oldResults[1]))
                    end
                    TraceSettings("settings.control", "set_before", BuildControlTraceData(panelId, control, controlPath, {
                        oldValue = oldValue,
                        newValue = DescribeSettingsValues(...),
                    }))
                    local results = CapturePcallResults(pcall(originalSetFunc, ...))
                    if not results.ok then
                        TraceSettings("settings.control", "set_error", BuildControlTraceData(panelId, control, controlPath, {
                            oldValue = oldValue,
                            newValue = DescribeSettingsValues(...),
                            error = tostring(results[1]),
                        }))
                        error(results[1], 2)
                    end
                    local newValue = nil
                    if captureValues and type(control.getFunc) == "function" then
                        local newResults = CapturePcallResults(pcall(control.getFunc))
                        newValue = newResults.ok and DescribePackedResults(newResults) or ("error:" .. tostring(newResults[1]))
                    end
                    TraceSettings("settings.control", "set_after", BuildControlTraceData(panelId, control, controlPath, {
                        oldValue = oldValue,
                        newValue = newValue,
                        result = DescribePackedResults(results),
                    }))
                    return unpack(results, 1, results.n)
                end
                control.__buiSetFuncInstrumented = true
            end
            if type(control.func) == "function" and not control.__buiFuncInstrumented then
                local originalFunc = control.func
                control.func = function(...)
                    TraceSettings("settings.control", "button_before", BuildControlTraceData(panelId, control, controlPath, {
                        args = DescribeSettingsValues(...),
                    }))
                    local results = CapturePcallResults(pcall(originalFunc, ...))
                    if not results.ok then
                        TraceSettings("settings.control", "button_error", BuildControlTraceData(panelId, control, controlPath, {
                            error = tostring(results[1]),
                        }))
                        error(results[1], 2)
                    end
                    TraceSettings("settings.control", "button_after", BuildControlTraceData(panelId, control, controlPath, {
                        result = DescribePackedResults(results),
                    }))
                    return unpack(results, 1, results.n)
                end
                control.__buiFuncInstrumented = true
            end
            if type(control.disabled) == "function" and not control.__buiDisabledInstrumented then
                local originalDisabled = control.disabled
                control.disabled = function(...)
                    local result = originalDisabled(...)
                    if BETTERUI.Log and BETTERUI.Log.EnabledFor
                        and BETTERUI.Log.EnabledFor(BETTERUI.Log.LEVEL.TRACE, BETTERUI.Log.CATEGORY.SETTINGS) then
                        TraceSettings("settings.control", "disabled", BuildControlTraceData(panelId, control, controlPath, {
                            result = result == true,
                        }))
                    end
                    return result
                end
                control.__buiDisabledInstrumented = true
            end
            if type(control.warning) == "function" and not control.__buiWarningInstrumented then
                local originalWarning = control.warning
                control.warning = function(...)
                    local result = originalWarning(...)
                    if BETTERUI.Log and BETTERUI.Log.EnabledFor
                        and BETTERUI.Log.EnabledFor(BETTERUI.Log.LEVEL.TRACE, BETTERUI.Log.CATEGORY.SETTINGS) then
                        TraceSettings("settings.control", "warning", BuildControlTraceData(panelId, control, controlPath, {
                            result = DescribeSettingsValue(result),
                        }))
                    end
                    return result
                end
                control.__buiWarningInstrumented = true
            end
            if type(control.controls) == "table" then
                InstrumentSettingControls(control.controls, panelId, controlPath)
            end
        end
    end
end

BETTERUI.CIM.Settings.InstrumentSettingControls = InstrumentSettingControls

function BETTERUI.CIM.Settings.RegisterModulePanel(panelIdOrModuleName, panelData, optionsData)
    local panelId = NormalizePanelRegistrationId(panelIdOrModuleName)
    if not panelId or type(panelData) ~= "table" then
        TraceSettings("settings.panel", "rejected", {
            panel = panelIdOrModuleName,
            reason = "invalid_panel_registration",
        })
        if BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SETTINGS, "settings panel registration invalid",
                { panel = panelIdOrModuleName })
        end
        return nil, "invalid_panel_registration"
    end

    optionsData = type(optionsData) == "table" and optionsData or {}
    TraceSettings("settings.panel", "sort_before", {
        panel = panelId,
        topLevelControls = #optionsData,
        totalControls = CountControls(optionsData),
    })
    BETTERUI.CIM.Settings.SortTopLevelSubmenusAlphabetically(optionsData)
    BETTERUI.CIM.Settings.SortSettingsAlphabetically(optionsData, true)
    TraceSettings("settings.panel", "sort_after", {
        panel = panelId,
        topLevelControls = #optionsData,
        totalControls = CountControls(optionsData),
    })
    InstrumentSettingControls(optionsData, panelId)

    local lam = LibAddonMenu2
    if not lam or not lam.RegisterAddonPanel or not lam.RegisterOptionControls then
        TraceSettings("settings.panel", "rejected", {
            panel = panelId,
            reason = "lam_unavailable",
        })
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SETTINGS, "settings panel LAM unavailable", { panel = panelId }) end
        return nil, "lam_unavailable"
    end

    TraceSettings("settings.panel", "register_before", {
        panel = panelId,
        stage = "addonPanel",
        topLevelControls = #optionsData,
        totalControls = CountControls(optionsData),
    })
    local panelOk = pcall(lam.RegisterAddonPanel, lam, panelId, panelData)
    if not panelOk then
        TraceSettings("settings.panel", "register_failed", {
            panel = panelId,
            stage = "addonPanel",
        })
        if BETTERUI.Log then
            BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.SETTINGS, "settings panel registration failed", { panel = panelId, stage = "addonPanel" })
        end
        return nil, "register_addon_panel_failed"
    end

    TraceSettings("settings.panel", "register_before", {
        panel = panelId,
        stage = "optionControls",
        topLevelControls = #optionsData,
        totalControls = CountControls(optionsData),
    })
    local controlsOk = pcall(lam.RegisterOptionControls, lam, panelId, optionsData)
    if not controlsOk then
        TraceSettings("settings.panel", "register_failed", {
            panel = panelId,
            stage = "optionControls",
        })
        if BETTERUI.Log then
            BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.SETTINGS, "settings panel registration failed", { panel = panelId, stage = "optionControls" })
        end
        return nil, "register_option_controls_failed"
    end

    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SETTINGS, "settings panel registered", { panel = panelId, controls = #optionsData })
    end
    TraceSettings("settings.panel", "registered", {
        panel = panelId,
        topLevelControls = #optionsData,
        totalControls = CountControls(optionsData),
    })
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
