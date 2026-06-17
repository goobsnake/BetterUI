--[[
File: Modules/CIM/Dialogs/DialogRegistry.lua
Purpose: Centralized dialog registration and management.

Used By: Inventory, Banking dialog initialization
Dependencies: ZO_Dialogs_RegisterCustomDialog

Dialogs registered via this registry:
  - CONFIRM_EQUIP_BOE (Inventory/Module.lua)
  - ZO_GAMEPAD_SPLIT_STACK_DIALOG (Inventory/Inventory.lua)
  - BETTERUI_CONFIRM_DESTROY_DIALOG (Inventory/Inventory.lua)
  - ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG (Inventory/Inventory.lua)
  - BETTERUI.Inventory.Dialogs.EQUIP_SLOT (Inventory/Actions/EquipAction.lua)

  - ZO_GAMEPAD_INVENTORY_ACTION_DIALOG (Inventory/Actions/ActionDialogHooks.lua)
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Dialogs then BETTERUI.CIM.Dialogs = {} end

-- DIALOG REGISTRY

--[[
Table: BETTERUI.CIM.Dialogs.Registry
Description: Tracks all registered dialogs for cleanup and management.
Rationale: Provides a single point of truth for dialog registration,
           preventing duplicate registration and enabling cleanup.
]]
BETTERUI.CIM.Dialogs.Registry = {
    _dialogs = {},
}

---@param dialogName string
---@param dialogInfo table
---@param options {overwrite: boolean?}?
---@return boolean
function BETTERUI.CIM.Dialogs.Register(dialogName, dialogInfo, options)
    options = options or {}

    -- Check for duplicate registration
    if BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] and not options.overwrite then
        if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.GENERAL, string.format("[Dialog] '%s' already registered, skipping", dialogName)) end
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

---@param dialogName string
---@return boolean
function BETTERUI.CIM.Dialogs.IsRegistered(dialogName)
    return BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] ~= nil
end

---@param dialogName string
---@param data table?
---@return nil
function BETTERUI.CIM.Dialogs.Show(dialogName, data)
    if not BETTERUI.CIM.Dialogs.IsRegistered(dialogName) then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.GENERAL, string.format("[Dialog] '%s' not registered", dialogName)) end
        return
    end

    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(dialogName, data)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(dialogName, data)
    end
end

---@param label string
---@param actionId string
---@return table
function BETTERUI.CIM.Dialogs.CreateParametricActionEntry(label, actionId)
    local entryData = ZO_GamepadEntryData:New(label)
    entryData:SetIconTintOnSelection(true)
    entryData.actionId = actionId
    entryData.setup = ZO_SharedGamepadEntry_OnSetup
    return {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = entryData,
    }
end

---@return string[]
function BETTERUI.CIM.Dialogs.GetAll()
    local names = {}
    for name, _ in pairs(BETTERUI.CIM.Dialogs.Registry._dialogs) do
        table.insert(names, name)
    end
    return names
end
