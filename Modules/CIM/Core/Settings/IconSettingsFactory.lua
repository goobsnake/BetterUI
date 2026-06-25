--[[
File: Modules/CIM/Core/Settings/IconSettingsFactory.lua
Purpose: Shared factory for generating icon visibility toggle LAM settings.
         Eliminates duplicate settings code between Banking and Inventory.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Settings = BETTERUI.CIM.Settings or {}

--[[
Table: ICON_DEFINITIONS
Defines the standard icon toggles shared across modules.
Used By: CreateIconToggleOptions
]]
local ICON_DEFINITIONS = {
    {
        key = "showIconUnboundItem",
        iconKey = "UNBOUND",
        -- This texture has more internal padding than the custom 16x16 icons.
        -- Use a slightly larger preview so visual weight matches adjacent rows.
        iconSize = 24,
        nameStringId = SI_BETTERUI_ICON_UNBOUND,
        tooltipStringId = SI_BETTERUI_ICON_UNBOUND_TOOLTIP,
    },
    {
        key = "showIconEnchantment",
        iconKey = "ENCHANTED",
        iconSize = 20,
        nameStringId = SI_BETTERUI_ICON_ENCHANTMENT,
        tooltipStringId = SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP,
    },
    {
        key = "showIconSetGear",
        iconKey = "SET_ITEM",
        iconSize = 20,
        nameStringId = SI_BETTERUI_ICON_SET_GEAR,
        tooltipStringId = SI_BETTERUI_ICON_SET_GEAR_TOOLTIP,
    },
    {
        key = "showIconResearchableTrait",
        iconKey = "RESEARCHABLE_TRAIT",
        iconSize = 20,
        nameStringId = SI_BETTERUI_ICON_RESEARCHABLE_TRAIT,
        tooltipStringId = SI_BETTERUI_ICON_RESEARCHABLE_TRAIT_TOOLTIP,
    },
    {
        key = "showIconUnknownRecipe",
        iconKey = "RECIPE_UNKNOWN",
        iconSize = 20,
        nameStringId = SI_BETTERUI_ICON_UNKNOWN_RECIPE,
        tooltipStringId = SI_BETTERUI_ICON_UNKNOWN_RECIPE_TOOLTIP,
    },
    {
        key = "showIconUnknownBook",
        iconKey = "BOOK_UNKNOWN",
        iconSize = 20,
        nameStringId = SI_BETTERUI_ICON_UNKNOWN_BOOK,
        tooltipStringId = SI_BETTERUI_ICON_UNKNOWN_BOOK_TOOLTIP,
    },
}

local DEFAULT_SETTING_ICON_SIZE = 20
local ICON_SUBMENU_NAME_STRING_ID = SI_BETTERUI_ICON_SUBMENU_HEADER
local ICON_SUBMENU_TOOLTIP_STRING_ID = SI_BETTERUI_ICON_SUBMENU_TOOLTIP
local ICON_SUBMENU_DESCRIPTION_STRING_ID = SI_BETTERUI_ICON_SUBMENU_DESC
local ICON_SUBMENU_RESET_STRING_ID = SI_BETTERUI_ICON_SUBMENU_RESET
local ICON_SUBMENU_RESET_TOOLTIP_STRING_ID = SI_BETTERUI_ICON_SUBMENU_RESET_TOOLTIP

local function ResolveDisplayString(nameStringId, text)
    if nameStringId then
        return GetString(nameStringId)
    end
    return text or ""
end

local function GetIconTexture(iconDef)
    local iconTable = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.ICONS
    if not iconTable or not iconDef.iconKey then
        return nil
    end
    return iconTable[iconDef.iconKey]
end

local function FormatSettingName(iconDef, nameStringId, nameText)
    local baseName = ResolveDisplayString(nameStringId, nameText)
    local iconTexture = GetIconTexture(iconDef)

    if type(zo_iconFormat) == "function" and iconTexture and iconTexture ~= "" then
        local iconSize = iconDef.iconSize or DEFAULT_SETTING_ICON_SIZE
        return zo_iconFormat(iconTexture, iconSize, iconSize) .. " " .. baseName
    end

    return baseName
end

local function GetIconToggleDefault(moduleName, iconDef)
    local metadata = BETTERUI.CIM.Settings.GetSettingMetadata(moduleName, iconDef.key)
    local defaultValue = iconDef.defaultValue
    if defaultValue == nil then
        defaultValue = true
    end
    if metadata and metadata.defaultValue ~= nil then
        defaultValue = metadata.defaultValue
    end
    return defaultValue, metadata
end

local function GetModuleSettings(moduleName)
    if type(BETTERUI.GetModuleSettings) == "function" then
        return BETTERUI.GetModuleSettings(moduleName)
    end

    if BETTERUI.Settings and BETTERUI.Settings.Modules then
        return BETTERUI.Settings.Modules[moduleName] or {}
    end

    return {}
end

local function EnsureModuleSettings(moduleName)
    if type(BETTERUI.EnsureModuleSettings) == "function" then
        return BETTERUI.EnsureModuleSettings(moduleName)
    end

    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
    if type(BETTERUI.Settings.Modules[moduleName]) ~= "table" then
        BETTERUI.Settings.Modules[moduleName] = {}
    end

    return BETTERUI.Settings.Modules[moduleName]
end

local function TraceIconSetting(moduleName, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = moduleName
    data.feature = "iconSettings"
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.SETTINGS or categories.SETTING or "SETTINGS", "settings.icon", phase, data)
end

local function SetIconSetting(moduleName, settings, key, value, source)
    if not settings then
        TraceIconSetting(moduleName, "set_skipped", {
            key = key,
            newValue = value,
            source = source,
            reason = "missingSettings",
        })
        return false
    end
    local oldValue = settings[key]
    settings[key] = value
    TraceIconSetting(moduleName, "set", {
        key = key,
        oldValue = oldValue,
        newValue = value,
        changed = oldValue ~= value,
        source = source,
    })
    return true
end

local function ResetIconCustomizationSettings(moduleName, refreshFn)
    -- Registry reset first; the manual fallback only runs when the registry
    -- is absent or reports it did not handle the group (returns non-true).
    local settingsApi = BETTERUI.CIM.Settings
    local registryHandled = false
    TraceIconSetting(moduleName, "reset_begin", {
        group = "iconCustomization",
        hasRegistry = settingsApi and type(settingsApi.ResetModuleSettingsByGroup) == "function",
    })
    if settingsApi and type(settingsApi.ResetModuleSettingsByGroup) == "function" then
        registryHandled = settingsApi.ResetModuleSettingsByGroup(moduleName, "iconCustomization") == true
    end
    if not registryHandled then
        local settings = EnsureModuleSettings(moduleName)
        if settings then
            for _, iconDef in ipairs(ICON_DEFINITIONS) do
                local defaultValue = GetIconToggleDefault(moduleName, iconDef)
                SetIconSetting(moduleName, settings, iconDef.key, defaultValue, "reset")
            end
        end
    end

    TraceIconSetting(moduleName, "reset_end", {
        group = "iconCustomization",
        registryHandled = registryHandled,
    })
    if refreshFn then
        refreshFn()
    end
end

---@param moduleName string
---@param refreshFn fun()?
---@return table[]
function BETTERUI.CIM.Settings.CreateIconToggleOptions(moduleName, refreshFn)
    local options = {}

    for _, iconDef in ipairs(ICON_DEFINITIONS) do
        local defaultValue, metadata = GetIconToggleDefault(moduleName, iconDef)

        local nameStringId = (metadata and metadata.labelStringId) or iconDef.nameStringId
        local tooltipStringId = (metadata and metadata.tooltipStringId) or iconDef.tooltipStringId

        table.insert(options, {
            type = "checkbox",
            name = FormatSettingName(iconDef, nameStringId, iconDef.name),
            tooltip = ResolveDisplayString(tooltipStringId, iconDef.tooltip),
            getFunc = function()
                local settings = GetModuleSettings(moduleName)
                if not settings then return defaultValue end
                local v = settings[iconDef.key]
                return v == nil and defaultValue or v
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings(moduleName)
                if settings then
                    SetIconSetting(moduleName, settings, iconDef.key, value, "checkbox")
                end
                -- Live refresh
                if refreshFn then
                    refreshFn()
                end
            end,
            width = "full",
            default = defaultValue,
        })
    end

    return options
end

--[[
Function: BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption
Creates a dedicated submenu for item icon customization controls.
param: moduleName (string) - The module name key in BETTERUI.Settings.Modules.
param: refreshFn (function) - Callback to refresh visible lists after settings changes.
return: table - A LAM submenu option containing icon toggles.
]]
---@param moduleName string
---@param refreshFn fun()?
---@return table
function BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption(moduleName, refreshFn)
    local controls = {
        {
            type = "description",
            text = GetString(ICON_SUBMENU_DESCRIPTION_STRING_ID),
            width = "full",
        },
    }

    local toggleOptions = BETTERUI.CIM.Settings.CreateIconToggleOptions(moduleName, refreshFn)
    for _, option in ipairs(toggleOptions) do
        controls[#controls + 1] = option
    end

    controls[#controls + 1] = {
        type = "button",
        name = GetString(ICON_SUBMENU_RESET_STRING_ID),
        tooltip = GetString(ICON_SUBMENU_RESET_TOOLTIP_STRING_ID),
        func = function()
            ResetIconCustomizationSettings(moduleName, refreshFn)
        end,
        width = "half",
    }

    return {
        type = "submenu",
        name = GetString(ICON_SUBMENU_NAME_STRING_ID),
        tooltip = GetString(ICON_SUBMENU_TOOLTIP_STRING_ID),
        controls = controls,
    }
end
