--[[
File: Modules/CIM/Core/IconSettingsFactory.lua
Purpose: Shared factory for generating icon visibility toggle LAM settings.
         Eliminates duplicate settings code between Banking and Inventory.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Settings = BETTERUI.CIM.Settings or {}

--[[
Table: ICON_DEFINITIONS
Description: Defines the standard icon toggles shared across modules.
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
    local modules = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
    if not modules then
        return nil
    end
    return modules[moduleName]
end

local function EnsureModuleSettings(moduleName)
    if not BETTERUI or not BETTERUI.Settings then
        return nil
    end
    BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
    if type(BETTERUI.Settings.Modules[moduleName]) ~= "table" then
        BETTERUI.Settings.Modules[moduleName] = {}
    end
    return BETTERUI.Settings.Modules[moduleName]
end

local function ResetIconCustomizationSettings(moduleName, refreshFn)
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup(moduleName, "iconCustomization")
    else
        local settings = EnsureModuleSettings(moduleName)
        if settings then
            for _, iconDef in ipairs(ICON_DEFINITIONS) do
                local defaultValue = GetIconToggleDefault(moduleName, iconDef)
                settings[iconDef.key] = defaultValue
            end
        end
    end

    if refreshFn then
        refreshFn()
    end
end

--[[
Function: BETTERUI.CIM.Settings.CreateIconToggleOptions
Description: Creates LAM checkbox options for icon visibility toggles.
Rationale: Consolidates identical icon toggle logic from Banking and Inventory.
Mechanism:
  1. Iterates through ICON_DEFINITIONS
  2. Creates a checkbox for each with get/set functions targeting the module settings
  3. Includes live refresh callback via refreshFn
param: moduleName (string) - The module name key in BETTERUI.Settings.Modules (e.g., "Banking", "Inventory")
param: refreshFn (function) - Function to call after setting change for live refresh
return: table - Array of LAM checkbox options
]]
--- @param moduleName string The module name key in BETTERUI.Settings.Modules
--- @param refreshFn function Function to call after setting change for live refresh
--- @return table[] options Array of LAM checkbox options
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
                    settings[iconDef.key] = value
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
Description: Creates a dedicated submenu for item icon customization controls.
Rationale: Keeps Inventory/Banking settings focused as icon options expand.
param: moduleName (string) - The module name key in BETTERUI.Settings.Modules.
param: refreshFn (function) - Callback to refresh visible lists after settings changes.
return: table - A LAM submenu option containing icon toggles.
]]
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
