-------------------------------------------------------------------------------------------------------------------------------------------------------
--
--    BetterUI Inventory Slot Actions - Item Action Handling
--    This file contains functions for handling item slot actions, including equip, use, bank, and craft bag operations
--
-------------------------------------------------------------------------------------------------------------------------------------------------------

INVENTORY_SLOT_ACTIONS_USE_CONTEXT_MENU = true
INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU = false

-- Main class definition is here
-- Note: these classes WILL be removed in the near future!

BETTERUI.Inventory.SlotActions = ZO_ItemSlotActionsController:Subclass()

-- This is a way to overwrite the ItemSlotAction's primary command. This is done so that "TryUseItem" and other functions use "CallSecureProtected" when activated
--- @param self table: The slot actions controller
--- @param actionStringId number: The string ID for the action name
--- @param actionCallback function: The callback function to execute
--- @param actionType string: The type of action
--- @param visibilityFunction function: Function to determine visibility
--- @param options table: Additional options for the action
local function BETTERUI_AddSlotPrimary(self, actionStringId, actionCallback, actionType, visibilityFunction, options)
    local actionName = actionStringId
    visibilityFunction = function()
	    return not IsUnitDead("player")
	end

	-- The following line inserts a row into the FIRST slotAction table, which corresponds to ACTION_KEY
    table.insert(self.m_slotActions, 1, { actionName, actionCallback, actionType, visibilityFunction, options })
    self.m_hasActions = true

    if(self.m_contextMenuMode and (not options or options ~= "silent") and (not visibilityFunction or visibilityFunction())) then
        AddMenuItem(actionName, actionCallback)
    end
end

--- Attempts to unequip an item from the specified inventory slot
--- @param inventorySlot table: The inventory slot data
local function TryUnequipItem(inventorySlot)
    local equipSlot = ZO_Inventory_GetSlotIndex(inventorySlot)
    UnequipItem(equipSlot)
end

-- Our overwritten TryUseItem allows us to call it securely
local function TryUseItem(inventorySlot) 
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    if slotType == SLOT_TYPE_QUEST_ITEM then
        if inventorySlot then
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
            CallSecureProtected("UseItem",bag, index) -- the problem with the slots gets solved here!
        end
    end
end

--- Attempts to bank an item, either depositing or withdrawing based on current banking state
--- @param inventorySlot table: The inventory slot data
local function TryBankItem(inventorySlot)
    if(PLAYER_INVENTORY:IsBanking()) then
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        if bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK or IsHouseBankBag(bag) then
            --Withdraw
            if DoesBagHaveSpaceFor(BAG_BACKPACK, bag, index) then
                CallSecureProtected("PickupInventoryItem",bag, index)
                CallSecureProtected("PlaceInTransfer")
            else
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
            end
        else
            --Deposit
            if IsItemStolen(bag, index) then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE)
            else
                local bankingBag = GetBankingBag()
                local canAlsoBePlacedInSubscriberBank = bankingBag == BAG_BANK
                if DoesBagHaveSpaceFor(bankingBag, bag, index) or (canAlsoBePlacedInSubscriberBank and DoesBagHaveSpaceFor(BAG_SUBSCRIBER_BANK, bag, index)) then
                    CallSecureProtected("PickupInventoryItem",bag, index)
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
end

--Quick and dirty fix for newly secured inventory calls for craft bag withdraw & deposit
local function TryMoveToInventoryorCraftBag(inventorySlot, targetBag)
    local stackSize
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)

    if bag ~= nil then
        stackSize, maxStackSize = GetSlotStackSize(bag, index)
        if stackSize >= maxStackSize then
            stackSize = maxStackSize
        end
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

--- Checks if an item can be moved to the craft bag
--- @param inventorySlot table: The inventory slot data
--- @return boolean: True if the item can be moved to craft bag
local function CanItemMoveToCraftBag(inventorySlot)
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    return HasCraftBagAccess() and CanItemBeVirtual(bag, index) and not IsItemStolen(bag, index)
end

--- Initializes the slot actions controller with custom primary action handling
--- @param alignmentOverride any: Override for keybind alignment
--- @param additionalMouseOverbinds table: Additional mouse over keybinds
--- @param useKeybindStrip boolean: Whether to use keybind strip
function BETTERUI.Inventory.SlotActions:Initialize(alignmentOverride, additionalMouseOverbinds, useKeybindStrip)
    self.alignment = KEYBIND_STRIP_ALIGN_RIGHT

    local slotActions = ZO_InventorySlotActions:New(INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU)
	slotActions.AddSlotPrimaryAction = BETTERUI_AddSlotPrimary -- Add a new function which allows us to neatly add our own slots *with context* of the original!!

    self.slotActions = slotActions
    self.useKeybindStrip = useKeybindStrip == nil and true or useKeybindStrip

    local primaryCommand =
    {
        alignment = alignmentOverride,
        name = function()
            if(self.selectedAction) then
                return slotActions:GetRawActionName(self.selectedAction)
            end

            return self.actionName or ""
        end,
        keybind = "UI_SHORTCUT_PRIMARY",
        order = 500,
        callback = function()
            if self.selectedAction then
                self:DoSelectedAction()
            else
                slotActions:DoPrimaryAction()
            end
        end,
        visible =   function()
                        return slotActions:CheckPrimaryActionVisibility() or self:HasSelectedAction()
                    end,
    }

    local function GetActionString(actionId)
    return GetString(actionId)
end

local function IsPrimaryAction(actionName, actionStringId)
    return actionName == GetActionString(actionStringId)
end

local function ShouldReplacePrimaryAction(primaryAction)
    return IsPrimaryAction(primaryAction, SI_ITEM_ACTION_USE) or
           IsPrimaryAction(primaryAction, SI_ITEM_ACTION_EQUIP) or
           IsPrimaryAction(primaryAction, SI_ITEM_ACTION_UNEQUIP) or
           IsPrimaryAction(primaryAction, SI_ITEM_ACTION_BANK_WITHDRAW) or
           IsPrimaryAction(primaryAction, SI_ITEM_ACTION_BANK_DEPOSIT) or
           IsPrimaryAction(primaryAction, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) or
           IsPrimaryAction(primaryAction, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG)
end

local function SetupSecureAction(slotActions, actionStringId, callback, inventorySlot)
    slotActions:AddSlotPrimaryAction(GetActionString(actionStringId), callback, "primary", nil, {visibleWhenDead = false})
end

local function HandleCraftBagActions(slotActions, inventorySlot, canUseItem)
    if canUseItem then
        SetupSecureAction(slotActions, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG,
            function(...) TryMoveToInventoryorCraftBag(inventorySlot, BAG_VIRTUAL) end, inventorySlot)
        slotActions:AddSlotAction(SI_ITEM_ACTION_USE, function() TryUseItem(inventorySlot) end, "secondary", nil, {visibleWhenDead = false})
    else
        SetupSecureAction(slotActions, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG,
            function(...) TryMoveToInventoryorCraftBag(inventorySlot, BAG_VIRTUAL) end, inventorySlot)
    end
end

local function SetupPrimaryAction(slotActions, actionName, inventorySlot)
    if IsPrimaryAction(actionName, SI_ITEM_ACTION_USE) then
        SetupSecureAction(slotActions, SI_ITEM_ACTION_USE, function(...) TryUseItem(inventorySlot) end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_EQUIP) then
        SetupSecureAction(slotActions, SI_ITEM_ACTION_EQUIP,
            function(...) GAMEPAD_INVENTORY:TryEquipItem(inventorySlot, ZO_Dialogs_IsShowingDialog()) end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_UNEQUIP) then
        SetupSecureAction(slotActions, SI_ITEM_ACTION_UNEQUIP, function(...) TryUnequipItem(inventorySlot) end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_BANK_WITHDRAW) or IsPrimaryAction(actionName, SI_ITEM_ACTION_BANK_DEPOSIT) then
        SetupSecureAction(slotActions, actionName == GetActionString(SI_ITEM_ACTION_BANK_WITHDRAW) and SI_ITEM_ACTION_BANK_WITHDRAW or SI_ITEM_ACTION_BANK_DEPOSIT,
            function(...) TryBankItem(inventorySlot) end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG) then
        SetupSecureAction(slotActions, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG,
            function(...) TryMoveToInventoryorCraftBag(inventorySlot, BAG_BACKPACK) end, inventorySlot)
    end
end

    local function PrimaryCommandHasBind()
        return (self.actionName ~= nil) or self:HasSelectedAction()
    end

    local function PrimaryCommandActivate(inventorySlot)
        slotActions:Clear()
        slotActions:SetInventorySlot(inventorySlot)
        self.selectedAction = nil -- Do not call the update function, just clear the selected action

        if not inventorySlot then
            self.actionName = nil
            return
        end

        ZO_InventorySlot_DiscoverSlotActionsFromActionList(inventorySlot, slotActions)

        local primaryAction = slotActions:GetPrimaryActionName()
        local canUseItem = false

        -- Handle primary action replacement logic
        if primaryAction and ShouldReplacePrimaryAction(primaryAction) then
            table.remove(slotActions.m_slotActions, 1)

            if CanItemMoveToCraftBag(inventorySlot) and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_USE) then
                canUseItem = true
                -- Remove craft bag action from secondary actions
                for i = #slotActions.m_slotActions, 1, -1 do
                    if slotActions.m_slotActions[i][1] == GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) then
                        table.remove(slotActions.m_slotActions, i)
                        break
                    end
                end
            end
        elseif CanItemMoveToCraftBag(inventorySlot) then
            self.actionName = GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG)
            -- Remove craft bag action from secondary actions
            for i = #slotActions.m_slotActions, 1, -1 do
                if slotActions.m_slotActions[i][1] == GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) then
                    table.remove(slotActions.m_slotActions, i)
                    break
                end
            end
        else
            -- No primary action available
            self.actionName = primaryAction
            return
        end

        -- Set the action name for display
        self.actionName = primaryAction or GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG)

        -- Setup secure actions based on action type
        if primaryAction then
            SetupPrimaryAction(slotActions, primaryAction, inventorySlot)
        end

        -- Handle craft bag specific logic
        if CanItemMoveToCraftBag(inventorySlot) and IsPrimaryAction(self.actionName, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) then
            HandleCraftBagActions(slotActions, inventorySlot, canUseItem)
        end
    end

    self:AddSubCommand(primaryCommand, PrimaryCommandHasBind, PrimaryCommandActivate)

    if additionalMouseOverbinds then
        local mouseOverCommand, mouseOverCommandIsVisible
        for i=1, #additionalMouseOverbinds do
            mouseOverCommand =
            {
                alignment = alignmentOverride,
                name = function()
                    return slotActions:GetKeybindActionName(i)
                end,
                keybind = additionalMouseOverbinds[i],
                callback = function() slotActions:DoKeybindAction(i) end,
                visible =   function()
                                return slotActions:CheckKeybindActionVisibility(i)
                            end,
            }

            mouseOverCommandIsVisible = function()
                return slotActions:GetKeybindActionName(i) ~= nil
            end

            self:AddSubCommand(mouseOverCommand, mouseOverCommandIsVisible)
        end
    end
end

function BETTERUI.Inventory.SlotActions:SetInventorySlot(inventorySlot)
    self.inventorySlot = inventorySlot

    for i, command in ipairs(self) do
        if command.activateCallback then
            command.activateCallback(inventorySlot)
        end
    end

    self:RefreshKeybindStrip()
end
