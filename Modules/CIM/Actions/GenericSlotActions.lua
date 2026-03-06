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
--- @param name string The display name of the action
--- @param callback function The function to execute when triggered
--- @param options table|nil Optional configuration
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
            -- UseQuestTool and UseQuestItem are NOT protected functions - call them directly
            -- (this matches how the base game's TryUseQuestItem works in inventoryslot.lua:420)
            -- Do NOT hide the scene manually — ESO's engine handles the scene transition
            -- (e.g., opening book reader, world map) and keeps inventory on the scene stack
            -- so WasSceneOnStack returns true on re-entry, preserving category/position
            if inventorySlot.toolIndex then
                UseQuestTool(inventorySlot.questIndex, inventorySlot.toolIndex)
            elseif inventorySlot.conditionIndex then
                UseQuestItem(inventorySlot.questIndex, inventorySlot.stepIndex, inventorySlot.conditionIndex)
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
--- @param inventorySlot table The inventory slot data
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

    -- Maximum items that can be transferred in a single operation (ESO game limit)
    local MAX_STACK_TRANSFER = 200

    local stackSize, maxStackSize = GetSlotStackSize(bag, index)
    if stackSize >= maxStackSize then
        stackSize = maxStackSize
    end
    -- Cap at max transfer limit
    if stackSize > MAX_STACK_TRANSFER then
        stackSize = MAX_STACK_TRANSFER
    end

    if targetBag ~= BAG_VIRTUAL then
        if DoesBagHaveSpaceFor(targetBag, bag, index) then
            local destinationSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bag, index, targetBag)
            if destinationSlot == nil then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
                return
            end
            CallSecureProtected("PickupInventoryItem", bag, index, stackSize)
            CallSecureProtected("PlaceInInventory", targetBag, destinationSlot)
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
--- @param inventorySlot table The inventory slot data
--- @return boolean canMove True if item can be stowed
function BETTERUI.CIM.CanItemMoveToCraftBag(inventorySlot)
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    return HasCraftBagAccess() and CanItemBeVirtual(bag, index) and not IsItemStolen(bag, index)
end

-- ============================================================================
-- SHARED ACTION SETUP HELPERS
-- ============================================================================
-- These functions provide shared action setup logic that was previously
-- duplicated in Inventory/Actions/SlotActions.lua.

--[[
Function: BETTERUI.CIM.SetupSecureAction
Description: Wraps an action in a secure call if necessary (primarily for USE actions).
Rationale: Ensures protected actions don't fail due to addon taint.
Used By: Inventory/Actions/SlotActions.lua
param: slotActions (table) - The slot actions object.
param: actionStringId (number) - The action string ID constant.
param: callback (function) - The callback to execute.
param: inventorySlot (table) - The inventory slot data.
]]
function BETTERUI.CIM.SetupSecureAction(slotActions, actionStringId, callback, inventorySlot)
    local actionName = GetString(actionStringId)
    if actionStringId == SI_ITEM_ACTION_USE then
        -- Create a wrapper that calls the secure protected function
        local secureCallback = function()
            BETTERUI.CIM.TryUseItem(inventorySlot)
        end
        slotActions:AddSlotPrimaryAction(actionName, secureCallback, "primary", nil, { visibleWhenDead = false })
    else
        slotActions:AddSlotPrimaryAction(actionName, callback, "primary", nil, { visibleWhenDead = false })
    end
end

--[[
Function: BETTERUI.CIM.HandleCraftBagActions
Description: Configures actions related to the Craft Bag (Stow/Retrieve).
Rationale: Handles complex logic for when to show "Stow" vs "Retrieve" vs "Stow & Use".
Used By: Inventory/Actions/SlotActions.lua
param: slotActions (table) - The slot actions object.
param: inventorySlot (table) - The inventory slot data.
param: canUseItem (boolean) - Whether the item is also usable (adds USE as secondary).
]]
function BETTERUI.CIM.HandleCraftBagActions(slotActions, inventorySlot, canUseItem)
    local stowActionName = GetString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG)
    local stowCallback = function()
        -- Use quantity dialog for stacked items
        if BETTERUI.Inventory.Dialogs and BETTERUI.Inventory.Dialogs.TryStowWithQuantity then
            BETTERUI.Inventory.Dialogs.TryStowWithQuantity(inventorySlot)
        else
            BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_VIRTUAL)
        end
    end

    if canUseItem then
        BETTERUI.CIM.SetupSecureAction(slotActions, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG, stowCallback, inventorySlot)
        -- USE as secondary action - also need to be secure
        slotActions:AddSlotAction(SI_ITEM_ACTION_USE, function()
            BETTERUI.CIM.TryUseItem(inventorySlot)
        end, "secondary", nil, { visibleWhenDead = false })
    else
        BETTERUI.CIM.SetupSecureAction(slotActions, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG, stowCallback, inventorySlot)
    end
end

--[[
Function: BETTERUI.CIM.SecureOpenSkills
Description: Wraps the "Open Skills" action callback in a secure call.
Rationale: The engine's "Open Skills" callback may call UseItem directly,
           which causes tainting errors. This wrapper ensures CallSecureProtected is used.
Used By: Inventory/Actions/SlotActions.lua
param: slotActions (table) - The slot actions object.
param: inventorySlot (table) - The inventory slot data.
]]
function BETTERUI.CIM.SecureOpenSkills(slotActions, inventorySlot)
    local INDEX_ACTION_CALLBACK = 2
    for i, action in ipairs(slotActions.m_slotActions) do
        local actionName = action[1]
        -- TODO(localization): Hardcoded English string "Open Skills" breaks non-English clients; use GetString(SI_ITEM_ACTION_*) or equivalent
        if actionName == "Open Skills" then
            local wrappedCallback = function()
                if inventorySlot then
                    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
                    CallSecureProtected("UseItem", bag, index)
                end
            end
            action[INDEX_ACTION_CALLBACK] = wrappedCallback
        end
    end
end

--[[
Function: BETTERUI.CIM.DeduplicateActions
Description: Removes duplicate entries from the slot actions list.
Rationale: Multiple code paths may add the same action (e.g., "Stow"); this
           ensures the Y-button actions menu doesn't show duplicates.
Used By: Inventory/Actions/SlotActions.lua
param: slotActions (table) - The slot actions object to deduplicate.
]]
function BETTERUI.CIM.DeduplicateActions(slotActions)
    local seen = {}
    for i = #slotActions.m_slotActions, 1, -1 do
        local entry = slotActions.m_slotActions[i]
        local name = entry and entry[1]
        if name and seen[name] then
            table.remove(slotActions.m_slotActions, i)
        else
            if name then
                seen[name] = true
            end
        end
    end
end

--[[
Function: BETTERUI.CIM.IsSlotInCraftBag
Description: Checks if the inventory slot represents an item inside the Craft Bag.
Used By: Inventory/Actions/SlotActions.lua, CIM.ResolveCraftBagState
param: inventorySlot (table) - The inventory slot data.
return: boolean - True if the item is in the Craft Bag.
]]
function BETTERUI.CIM.IsSlotInCraftBag(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    return slotType == SLOT_TYPE_CRAFT_BAG_ITEM
end

--[[
Function: BETTERUI.CIM.ResolveCraftBagState
Description: Determines the correct primary action based on Craft Bag context.
Rationale: Items in Craft Bag should show "Retrieve"; items in Inventory should
           show "Stow" if eligible.
Used By: Inventory/Actions/SlotActions.lua
param: slotActions (table) - The slot actions object.
param: inventorySlot (table) - The inventory slot data.
param: primaryAction (string) - The current primary action name.
param: canUseItem (boolean) - Whether the item is also usable.
return: string - The resolved action name for display.
]]
function BETTERUI.CIM.ResolveCraftBagState(slotActions, inventorySlot, primaryAction, canUseItem)
    local stowActionName = GetString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG)
    local retrieveActionName = GetString(SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG)
    local actionName = primaryAction or stowActionName
    local isInCraftBag = BETTERUI.CIM.IsSlotInCraftBag(inventorySlot)

    if isInCraftBag then
        -- CRAFT BAG VIEW: Remove "Stow" from actions entirely, keep "Retrieve" as primary
        for i = #slotActions.m_slotActions, 1, -1 do
            if slotActions.m_slotActions[i][1] == stowActionName then
                table.remove(slotActions.m_slotActions, i)
            end
        end
        -- Ensure Retrieve is primary action for craft bag items
        actionName = retrieveActionName
    elseif BETTERUI.CIM.CanItemMoveToCraftBag(inventorySlot) then
        -- INVENTORY VIEW: Force "Stow" as primary for eligible items
        -- Remove any existing craft-bag entries to avoid duplicates
        for i = #slotActions.m_slotActions, 1, -1 do
            if slotActions.m_slotActions[i][1] == stowActionName then
                table.remove(slotActions.m_slotActions, i)
            end
        end

        -- Use the helper to add the primary craft-bag action
        BETTERUI.CIM.HandleCraftBagActions(slotActions, inventorySlot, canUseItem)

        -- We forced Stow to be primary; clear any prior split-stack override
        slotActions._betterui_primaryOverride = nil

        -- Ensure the displayed action name is "Stow"
        actionName = stowActionName
    end
    return actionName
end
