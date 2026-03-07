--[[
File: Modules/CIM/Dialogs/DialogRegistry.lua
Purpose: Centralized dialog registration and management.
Author: BetterUI Team
Last Modified: 2026-02-02

Used By: Inventory, Banking dialog initialization
Dependencies: ZO_Dialogs_RegisterCustomDialog

Dialogs registered via this registry:
  - CONFIRM_EQUIP_BOE (Inventory/Module.lua)
  - ZO_GAMEPAD_SPLIT_STACK_DIALOG (Inventory/Inventory.lua)
  - BETTERUI_CONFIRM_DESTROY_DIALOG (Inventory/Inventory.lua)
  - ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG (Inventory/Inventory.lua)
  - BETTERUI_EQUIP_SLOT_DIALOG (Inventory/Actions/EquipAction.lua)

  - ZO_GAMEPAD_INVENTORY_ACTION_DIALOG (Inventory/Actions/ActionDialogHooks.lua)
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Dialogs then BETTERUI.CIM.Dialogs = {} end

-- ============================================================================
-- DIALOG REGISTRY
-- ============================================================================

--[[
Table: BETTERUI.CIM.Dialogs.Registry
Description: Tracks all registered dialogs for cleanup and management.
Rationale: Provides a single point of truth for dialog registration,
           preventing duplicate registration and enabling cleanup.
]]
BETTERUI.CIM.Dialogs.Registry = {
    _dialogs = {},
}

--[[
Function: BETTERUI.CIM.Dialogs.Register
Description: Registers a dialog with ZO_Dialogs and tracks it in the registry.
param: dialogName (string) - The unique dialog name.
param: dialogInfo (table) - The dialog configuration table.
param: options (table|nil) - Optional: { overwrite = false }
return: boolean - True if registration succeeded.
]]
--- @param dialogName string The unique dialog name
--- @param dialogInfo table The dialog configuration table
--- @param options table|nil Optional configuration
--- @return boolean success True if registration succeeded
function BETTERUI.CIM.Dialogs.Register(dialogName, dialogInfo, options)
    options = options or {}

    -- Check for duplicate registration
    if BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] and not options.overwrite then
        BETTERUI.Debug(string.format("[Dialog] '%s' already registered, skipping", dialogName))
        return false
    end

    -- Register with ZO_Dialogs
    if ZO_Dialogs_RegisterCustomDialog then
        ZO_Dialogs_RegisterCustomDialog(dialogName, dialogInfo)
    end

    -- Track in registry
    BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] = {
        name = dialogName,
        info = dialogInfo,
        registeredAt = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0,
    }

    return true
end

--[[
Function: BETTERUI.CIM.Dialogs.IsRegistered
Description: Checks if a dialog is registered.
param: dialogName (string) - The dialog name to check.
return: boolean - True if registered.
]]
--- @param dialogName string The dialog name to check
--- @return boolean registered True if registered
function BETTERUI.CIM.Dialogs.IsRegistered(dialogName)
    return BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] ~= nil
end

--[[
Function: BETTERUI.CIM.Dialogs.Show
Description: Shows a registered dialog.
param: dialogName (string) - The dialog name to show.
param: data (table|nil) - Optional data to pass to the dialog.
]]
--- @param dialogName string The dialog name to show
--- @param data table|nil Optional data to pass to the dialog
function BETTERUI.CIM.Dialogs.Show(dialogName, data)
    if not BETTERUI.CIM.Dialogs.IsRegistered(dialogName) then
        BETTERUI.Debug(string.format("[Dialog] '%s' not registered", dialogName))
        return
    end

    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(dialogName, data)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(dialogName, data)
    end
end

--[[
Function: BETTERUI.CIM.Dialogs.GetAll
Description: Returns all registered dialog names.
return: table - Array of dialog names.
]]
--- @return table dialogNames Array of registered dialog names
function BETTERUI.CIM.Dialogs.GetAll()
    local names = {}
    for name, _ in pairs(BETTERUI.CIM.Dialogs.Registry._dialogs) do
        table.insert(names, name)
    end
    return names
end
