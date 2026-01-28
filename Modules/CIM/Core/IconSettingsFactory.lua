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
        nameStringId = SI_BETTERUI_ICON_UNBOUND,
        tooltipStringId = SI_BETTERUI_ICON_UNBOUND_TOOLTIP,
        defaultValue = true,
    },
    {
        key = "showIconEnchantment",
        nameStringId = SI_BETTERUI_ICON_ENCHANTMENT,
        tooltipStringId = SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP,
        defaultValue = true,
    },
    {
        key = "showIconSetGear",
        nameStringId = SI_BETTERUI_ICON_SET_GEAR,
        tooltipStringId = SI_BETTERUI_ICON_SET_GEAR_TOOLTIP,
        defaultValue = true,
    },
}

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
function BETTERUI.CIM.Settings.CreateIconToggleOptions(moduleName, refreshFn)
    local options = {}

    for _, iconDef in ipairs(ICON_DEFINITIONS) do
        table.insert(options, {
            type = "checkbox",
            name = GetString(iconDef.nameStringId),
            tooltip = GetString(iconDef.tooltipStringId),
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
                    pcall(refreshFn)
                end
            end,
            width = "full",
        })
    end

    return options
end
