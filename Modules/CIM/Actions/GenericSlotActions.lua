--[[
File: Modules/CIM/Actions/GenericSlotActions.lua
Purpose: Shared slot action logic for Inventory and Banking modules.
         Provides abstractions for common item actions (split stack, link to chat, etc.).
Author: BetterUI Team
Last Modified: 2026-01-26

Note: This class is not currently used by Inventory/Banking (they use
BETTERUI.Inventory.SlotActions which inherits ZO_ItemSlotActionsController).
These implementations provide a foundation for future refactoring.
]]

local _

if not BETTERUI.CIM then BETTERUI.CIM = {} end

--[[
Class: BETTERUI.CIM.GenericSlotActions
Description: Base class for slot action management.
Rationale: Provides a simple action registry pattern for inventory-like windows.
]]
BETTERUI.CIM.GenericSlotActions = ZO_Object:Subclass()

function BETTERUI.CIM.GenericSlotActions:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BETTERUI.CIM.GenericSlotActions:Initialize()
    self.actions = {}
    self.actionsByName = {}
end

-------------------------------------------------------------------------------------------------
-- ACTION MANAGEMENT
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericSlotActions:AddAction
Description: Adds an action to the available actions list.
param: name (string) - The display name of the action.
param: callback (function) - The function to execute when the action is triggered.
param: options (table|nil) - Optional configuration (visible, order, etc.).
]]
function BETTERUI.CIM.GenericSlotActions:AddAction(name, callback, options)
    local action = {
        name = name,
        callback = callback,
        options = options or {},
    }
    table.insert(self.actions, action)
    self.actionsByName[name] = action
end

--[[
Function: BETTERUI.CIM.GenericSlotActions:ClearActions
Description: Clears all registered actions.
]]
function BETTERUI.CIM.GenericSlotActions:ClearActions()
    self.actions = {}
    self.actionsByName = {}
end

--[[
Function: BETTERUI.CIM.GenericSlotActions:GetAction
Description: Retrieves a specific action by name.
param: actionName (string) - The name of the action to retrieve.
return: table|nil - The action table, or nil if not found.
]]
function BETTERUI.CIM.GenericSlotActions:GetAction(actionName)
    return self.actionsByName[actionName]
end

--[[
Function: BETTERUI.CIM.GenericSlotActions:HasAction
Description: Checks if an action exists by name.
param: actionName (string) - The name of the action to check.
return: boolean - True if the action exists.
]]
function BETTERUI.CIM.GenericSlotActions:HasAction(actionName)
    return self.actionsByName[actionName] ~= nil
end

--[[
Function: BETTERUI.CIM.GenericSlotActions:GetActionCount
Description: Returns the number of registered actions.
return: number - The count of actions.
]]
function BETTERUI.CIM.GenericSlotActions:GetActionCount()
    return #self.actions
end

--[[
Function: BETTERUI.CIM.GenericSlotActions:GetActions
Description: Returns the list of all registered actions.
return: table - Array of action tables.
]]
function BETTERUI.CIM.GenericSlotActions:GetActions()
    return self.actions
end

--[[
Function: BETTERUI.CIM.GenericSlotActions:ExecuteAction
Description: Executes an action by name.
param: actionName (string) - The name of the action to execute.
return: boolean - True if the action was found and executed.
]]
function BETTERUI.CIM.GenericSlotActions:ExecuteAction(actionName)
    local action = self.actionsByName[actionName]
    if action and action.callback then
        action.callback()
        return true
    end
    return false
end

-------------------------------------------------------------------------------------------------
-- COMMON ACTIONS BUILDER
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericSlotActions:BuildCommonActions
Description: Populates standard actions for an inventory slot.
Rationale: Common actions that apply to most item types (Link to Chat, etc.).
Mechanism: Adds actions based on the item's properties.
param: inventorySlot (table) - The inventory slot data.
param: options (table|nil) - Optional configuration.
  - includeLinkToChat (boolean): Whether to add Link to Chat action (default: true).
  - includeSplitStack (boolean): Whether to add Split Stack action (default: true).
]]
function BETTERUI.CIM.GenericSlotActions:BuildCommonActions(inventorySlot, options)
    options = options or {}
    local includeLinkToChat = options.includeLinkToChat ~= false
    local includeSplitStack = options.includeSplitStack ~= false

    self:ClearActions()

    if not inventorySlot then return end

    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then return end

    -- Link to Chat action
    if includeLinkToChat then
        local itemLink = GetItemLink(bag, slot)
        if itemLink and itemLink ~= "" then
            self:AddAction(GetString(SI_ITEM_ACTION_LINK_TO_CHAT), function()
                ZO_LinkHandler_InsertLink(zo_strformat("<<2>>", SI_TOOLTIP_ITEM_NAME, itemLink))
            end)
        end
    end

    -- Split Stack action (only for stackable items with stack > 1)
    if includeSplitStack then
        local stackSize = GetSlotStackSize(bag, slot)
        if stackSize and stackSize > 1 then
            self:AddAction(GetString(SI_ITEM_ACTION_SPLIT_STACK), function()
                if ZO_InventorySlot_TrySplitStack then
                    ZO_InventorySlot_TrySplitStack(inventorySlot)
                end
            end)
        end
    end
end
