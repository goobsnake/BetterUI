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
        defaultValue = true,
    },
    {
        key = "showIconEnchantment",
        iconKey = "ENCHANTED",
        iconSize = 20,
        nameStringId = SI_BETTERUI_ICON_ENCHANTMENT,
        tooltipStringId = SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP,
        defaultValue = true,
    },
    {
        key = "showIconSetGear",
        iconKey = "SET_ITEM",
        iconSize = 20,
        nameStringId = SI_BETTERUI_ICON_SET_GEAR,
        tooltipStringId = SI_BETTERUI_ICON_SET_GEAR_TOOLTIP,
        defaultValue = true,
    },
    {
        key = "showIconResearchableTrait",
        iconKey = "RESEARCHABLE_TRAIT",
        iconSize = 20,
        name = "Item Icon - Researchable Trait",
        tooltip = "Show an icon after items with traits you can research.",
        defaultValue = true,
    },
    {
        key = "showIconUnknownRecipe",
        iconKey = "RECIPE_UNKNOWN",
        iconSize = 20,
        name = "Item Icon - Unknown Recipe",
        tooltip = "Show an icon after recipe items that are not yet learned.",
        defaultValue = true,
    },
    {
        key = "showIconUnknownBook",
        iconKey = "BOOK_UNKNOWN",
        iconSize = 20,
        name = "Item Icon - Unknown Book",
        tooltip = "Show an icon after books or lorebooks that are not yet learned.",
        defaultValue = true,
    },
}

local DEFAULT_SETTING_ICON_SIZE = 20
local ICON_SUBMENU_NAME = "Item Icon Customization"
local ICON_SUBMENU_TOOLTIP = "Configure which status icons appear next to item names."
local ICON_SUBMENU_DESCRIPTION =
    "Choose which item-state icons to display in Inventory and Banking lists. " ..
    "Icons scale with Name column font size and can be toggled individually."

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

local function FormatSettingName(iconDef)
    local baseName = ResolveDisplayString(iconDef.nameStringId, iconDef.name)
    local iconTexture = GetIconTexture(iconDef)

    if type(zo_iconFormat) == "function" and iconTexture and iconTexture ~= "" then
        local iconSize = iconDef.iconSize or DEFAULT_SETTING_ICON_SIZE
        return zo_iconFormat(iconTexture, iconSize, iconSize) .. " " .. baseName
    end

    return baseName
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
        table.insert(options, {
            type = "checkbox",
            name = FormatSettingName(iconDef),
            tooltip = ResolveDisplayString(iconDef.tooltipStringId, iconDef.tooltip),
            getFunc = function()
                local settings = BETTERUI.Settings.Modules[moduleName]
                if not settings then return iconDef.defaultValue end
                local v = settings[iconDef.key]
                return v == nil and iconDef.defaultValue or v
            end,
            setFunc = function(value)
                local settings = BETTERUI.Settings.Modules[moduleName]
                if settings then
                    settings[iconDef.key] = value
                end
                -- Live refresh
                if refreshFn then
                    refreshFn()
                end
            end,
            width = "full",
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
            text = ICON_SUBMENU_DESCRIPTION,
            width = "full",
        },
    }

    local toggleOptions = BETTERUI.CIM.Settings.CreateIconToggleOptions(moduleName, refreshFn)
    for _, option in ipairs(toggleOptions) do
        controls[#controls + 1] = option
    end

    return {
        type = "submenu",
        name = ICON_SUBMENU_NAME,
        tooltip = ICON_SUBMENU_TOOLTIP,
        controls = controls,
    }
end
