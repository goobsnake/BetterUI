--[[
File: Modules/CIM/Core/SettingsFactory.lua
Purpose: Factory functions for creating standardized settings panels.
         Ensures consistent LAM panel appearance across modules.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

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
