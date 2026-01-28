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

-- ============================================================================
-- SHARED ITEM ACTION HELPERS
-- ============================================================================
-- These functions provide common item action implementations used by
-- Inventory and Banking modules. They handle secure API calls.

--[[
Function: BETTERUI.CIM.TryUseItem
Description: Attempts to use an item from the specified inventory slot.
Rationale: Handles quest items vs standard items with secure calls.
Used By: Inventory/Actions/SlotActions.lua
param: inventorySlot (table) - The inventory slot data with bagId/slotIndex.
]]
function BETTERUI.CIM.TryUseItem(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    if slotType == SLOT_TYPE_QUEST_ITEM then
        if inventorySlot then
            if inventorySlot.toolIndex then
                CallSecureProtected("UseQuestTool", inventorySlot.questIndex, inventorySlot.toolIndex)
            elseif inventorySlot.conditionIndex then
                CallSecureProtected("UseQuestItem", inventorySlot.questIndex, inventorySlot.stepIndex,
                    inventorySlot.conditionIndex)
            end
        end
    else
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        local usable, onlyFromActionSlot = IsItemUsable(bag, index)
        if usable and not onlyFromActionSlot then
            CallSecureProtected("UseItem", bag, index)
        end
    end
end

--[[
Function: BETTERUI.CIM.TryBankItem
Description: Handles banking deposit/withdraw for an item.
Rationale: Centralized banking logic with space checks and error handling.
Used By: Inventory/Actions/SlotActions.lua, Banking/Actions/TransferActions.lua
param: inventorySlot (table) - The inventory slot data.
]]
function BETTERUI.CIM.TryBankItem(inventorySlot)
    if not PLAYER_INVENTORY:IsBanking() then return end

    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK or IsHouseBankBag(bag) then
        -- Withdraw
        if DoesBagHaveSpaceFor(BAG_BACKPACK, bag, index) then
            CallSecureProtected("PickupInventoryItem", bag, index)
            CallSecureProtected("PlaceInTransfer")
        else
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
        end
    else
        -- Deposit
        if IsItemStolen(bag, index) then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE)
        else
            local bankingBag = GetBankingBag()
            local canAlsoBePlacedInSubscriberBank = bankingBag == BAG_BANK
            if DoesBagHaveSpaceFor(bankingBag, bag, index) or (canAlsoBePlacedInSubscriberBank and DoesBagHaveSpaceFor(BAG_SUBSCRIBER_BANK, bag, index)) then
                CallSecureProtected("PickupInventoryItem", bag, index)
                CallSecureProtected("PlaceInTransfer")
            else
                if canAlsoBePlacedInSubscriberBank and not IsESOPlusSubscriber() then
                    if GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK) > 0 then
                        TriggerTutorial(TUTORIAL_TRIGGER_BANK_OVERFULL)
                    else
                        TriggerTutorial(TUTORIAL_TRIGGER_BANK_FULL_NO_ESO_PLUS)
                    end
                end
                ZO_AlertEvent(EVENT_BANK_IS_FULL)
            end
        end
    end
end

--[[
Function: BETTERUI.CIM.TryMoveToCraftBag
Description: Moves an item between Backpack and Craft Bag.
Rationale: Handles stow/retrieve with proper stack handling.
Used By: Inventory/Actions/SlotActions.lua
param: inventorySlot (table) - The inventory slot data.
param: targetBag (number) - BAG_BACKPACK or BAG_VIRTUAL.
]]
function BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, targetBag)
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag then return end

    local stackSize, maxStackSize = GetSlotStackSize(bag, index)
    if stackSize >= maxStackSize then
        stackSize = maxStackSize
    end

    if targetBag ~= BAG_VIRTUAL then
        if DoesBagHaveSpaceFor(targetBag, bag, index) then
            local emptySlotIndex = FindFirstEmptySlotInBag(targetBag)
            CallSecureProtected("PickupInventoryItem", bag, index, stackSize)
            CallSecureProtected("PlaceInInventory", targetBag, emptySlotIndex)
        else
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
        end
    else
        CallSecureProtected("PickupInventoryItem", bag, index, stackSize)
        CallSecureProtected("PlaceInInventory", targetBag, 0)
    end
end

--[[
Function: BETTERUI.CIM.CanItemMoveToCraftBag
Description: Checks if an item is eligible for Craft Bag.
Rationale: Requires ESO+ access, item compatibility, and not stolen.
Used By: Inventory/Actions/SlotActions.lua
param: inventorySlot (table) - The inventory slot data.
return: boolean - True if item can be stowed.
]]
function BETTERUI.CIM.CanItemMoveToCraftBag(inventorySlot)
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    return HasCraftBagAccess() and CanItemBeVirtual(bag, index) and not IsItemStolen(bag, index)
end
