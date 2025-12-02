-- BetterUI Inventory Slot Actions
-- Item action handling: equip, use, bank, and craft bag operations

INVENTORY_SLOT_ACTIONS_USE_CONTEXT_MENU = true
INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU = false

BETTERUI.Inventory.SlotActions = ZO_ItemSlotActionsController:Subclass()

-- Inserts a primary action at the front of the slot actions table
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

-- Override the engine's TryUseItem to use CallSecureProtected for private functions
-- This ensures that special item callbacks (like TryStartSkillRespec) work correctly
function TryUseItem(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    if slotType == SLOT_TYPE_QUEST_ITEM then
        if inventorySlot then
            if inventorySlot.toolIndex then
                CallSecureProtected("UseQuestTool", inventorySlot.questIndex, inventorySlot.toolIndex)
            elseif inventorySlot.conditionIndex then
                CallSecureProtected("UseQuestItem", inventorySlot.questIndex, inventorySlot.stepIndex, inventorySlot.conditionIndex)
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

--- Checks if the inventory slot is currently in the craft bag (not regular inventory)
--- @param inventorySlot table: The inventory slot data
--- @return boolean: True if the item is in the craft bag
local function IsSlotInCraftBag(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    return slotType == SLOT_TYPE_CRAFT_BAG_ITEM
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
            local n = nil
            if(self.selectedAction) then
                n = slotActions:GetRawActionName(self.selectedAction)
            end
            if not n then
                n = self.actionName
            end
            return n or ""
        end,
        keybind = "UI_SHORTCUT_PRIMARY",
        order = 500,
        callback = function()
            if self.selectedAction then
                self:DoSelectedAction()
            else
                if slotActions._betterui_primaryOverride then
                    slotActions._betterui_primaryOverride()
                else
                    slotActions:DoPrimaryAction()
                end
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
            -- Note: Split stack is intentionally NOT included here so it remains
            -- available in the Y (actions) list. We still wire it up as a
            -- primary action below so A can invoke the split dialog when needed.
    end

    local function SetupSecureAction(slotActions, actionStringId, callback, inventorySlot)
        -- For USE actions, we must ensure UseItem/UseQuestItem is called via CallSecureProtected
        -- actionStringId is the raw string constant (e.g., SI_ITEM_ACTION_USE), not the localized string
        if actionStringId == SI_ITEM_ACTION_USE then
            -- Create a wrapper that calls the secure protected function
            local secureCallback = function()
                local slotType = ZO_InventorySlot_GetType(inventorySlot)
                if slotType == SLOT_TYPE_QUEST_ITEM then
                    if inventorySlot then
                        if inventorySlot.toolIndex then
                            CallSecureProtected("UseQuestTool", inventorySlot.questIndex, inventorySlot.toolIndex)
                        elseif inventorySlot.conditionIndex then
                            CallSecureProtected("UseQuestItem", inventorySlot.questIndex, inventorySlot.stepIndex, inventorySlot.conditionIndex)
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
            slotActions:AddSlotPrimaryAction(GetActionString(actionStringId), secureCallback, "primary", nil, {visibleWhenDead = false})
        else
            -- For non-USE actions, use the callback as-is
            slotActions:AddSlotPrimaryAction(GetActionString(actionStringId), callback, "primary", nil, {visibleWhenDead = false})
        end
    end

    local function HandleCraftBagActions(slotActions, inventorySlot, canUseItem)
        if canUseItem then
            SetupSecureAction(slotActions, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG,
                function(...) TryMoveToInventoryorCraftBag(inventorySlot, BAG_VIRTUAL) end, inventorySlot)
            -- USE as secondary action - also need to be secure
            slotActions:AddSlotAction(SI_ITEM_ACTION_USE, function()
                local slotType = ZO_InventorySlot_GetType(inventorySlot)
                if slotType == SLOT_TYPE_QUEST_ITEM then
                    if inventorySlot then
                        if inventorySlot.toolIndex then
                            CallSecureProtected("UseQuestTool", inventorySlot.questIndex, inventorySlot.toolIndex)
                        elseif inventorySlot.conditionIndex then
                            CallSecureProtected("UseQuestItem", inventorySlot.questIndex, inventorySlot.stepIndex, inventorySlot.conditionIndex)
                        end
                    end
                else
                    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
                    local usable, onlyFromActionSlot = IsItemUsable(bag, index)
                    if usable and not onlyFromActionSlot then
                        CallSecureProtected("UseItem", bag, index)
                    end
                end
            end, "secondary", nil, {visibleWhenDead = false})
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
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_SPLIT_STACK) then
            -- Wire Split Stack as a primary action so A can open the split dialog while
            -- leaving the action present in the Y actions list.
            slotActions:AddSlotPrimaryAction(GetActionString(SI_ITEM_ACTION_SPLIT_STACK), function()
                if ZO_InventorySlot_TrySplitStack then
                    ZO_InventorySlot_TrySplitStack(inventorySlot)
                end
            end, "primary", nil, {visibleWhenDead = false})
        end

        local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes["companionEquipmentGamepad"] and SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
        if actionName == GetActionString(SI_ITEM_ACTION_LINK_TO_CHAT) and isCompanionSceneShowing then
                -- Do not add Link to Chat action when in companion equipment scene to avoid insecure chat submits
                return
        end
    end

    local function PrimaryCommandHasBind()
        -- Avoid showing the primary (A) bind when the primary action is "Link to Chat",
        -- because the X button already exposes this action in the inventory UI and
        -- duplicating it on A is redundant and confusing.
        if self.actionName == GetActionString(SI_ITEM_ACTION_LINK_TO_CHAT) then
            return false
        end
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

        -- For special items like "Open Skills", replace the discovered callback with a secure version
        -- The engine's callbacks may call functions that require secure context
        local INDEX_ACTION_CALLBACK = 2
        for i, action in ipairs(slotActions.m_slotActions) do
            local actionName = action[1]
            
            -- For "Open Skills", replace with a secure wrapper that uses the item properly
            if actionName == "Open Skills" then
                local wrappedCallback = function()
                    if inventorySlot then
                        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
                        -- Use CallSecureProtected to consume the item securely
                        CallSecureProtected("UseItem", bag, index)
                    end
                end
                action[INDEX_ACTION_CALLBACK] = wrappedCallback
            end
        end

    local primaryAction = slotActions:GetPrimaryActionName()
    local canUseItem = false

        -- If no primary action was identified by the engine, use the first discovered action
        if not primaryAction and #slotActions.m_slotActions > 0 then
            primaryAction = slotActions.m_slotActions[1][1]
        end

        -- Handle primary action replacement logic
        if primaryAction and ShouldReplacePrimaryAction(primaryAction) then
            table.remove(slotActions.m_slotActions, 1)

            -- Only apply Stow logic for items NOT already in the craft bag
            if not IsSlotInCraftBag(inventorySlot) and CanItemMoveToCraftBag(inventorySlot) and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_USE) then
                canUseItem = true
                -- Remove craft bag action from secondary actions
                for i = #slotActions.m_slotActions, 1, -1 do
                    if slotActions.m_slotActions[i][1] == GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) then
                        table.remove(slotActions.m_slotActions, i)
                        break
                    end
                end
            end
        elseif not primaryAction then
            -- No primary action available and not a craft bag item
            self.actionName = nil
            return
        end

        -- If the primary action is Split Stack, set a lightweight per-slot override
        -- so the A button will invoke the engine split flow while leaving the
        -- action present in the Y (actions) list.
        if primaryAction and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_SPLIT_STACK) then
            slotActions._betterui_primaryOverride = function()
                if ZO_InventorySlot_TrySplitStack then
                    ZO_InventorySlot_TrySplitStack(inventorySlot)
                end
            end
        else
            slotActions._betterui_primaryOverride = nil
        end

        -- Set the action name for display
        self.actionName = primaryAction or GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG)

        -- Handle craft bag vs inventory actions:
        -- - In CRAFT BAG: "Retrieve" should be primary, "Stow" should NOT appear
        -- - In INVENTORY: "Stow" should be primary for eligible items
        local isInCraftBag = IsSlotInCraftBag(inventorySlot)
        
        if isInCraftBag then
            -- CRAFT BAG VIEW: Remove "Stow" from actions entirely, keep "Retrieve" as primary
            for i = #slotActions.m_slotActions, 1, -1 do
                if slotActions.m_slotActions[i][1] == GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) then
                    table.remove(slotActions.m_slotActions, i)
                end
            end
            -- Ensure Retrieve is primary action
            if IsPrimaryAction(primaryAction, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG) then
                self.actionName = GetActionString(SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG)
            end
        elseif CanItemMoveToCraftBag(inventorySlot) then
            -- INVENTORY VIEW: Force "Stow" as primary for eligible items
            -- Remove any existing craft-bag entries to avoid duplicates
            for i = #slotActions.m_slotActions, 1, -1 do
                if slotActions.m_slotActions[i][1] == GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) then
                    table.remove(slotActions.m_slotActions, i)
                end
            end

            -- Use the helper to add the primary craft-bag action (and USE as secondary when appropriate)
            HandleCraftBagActions(slotActions, inventorySlot, canUseItem)
            -- We forced Stow to be primary; clear any prior split-stack override so
            -- the A key invokes the newly-added Stow primary rather than the old
            -- split-stack override which may still be set earlier.
            slotActions._betterui_primaryOverride = nil

            -- Ensure the displayed action name is "Stow"
            self.actionName = GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG)
        end

        -- Setup secure actions based on action type
        if primaryAction then
            -- Check if this is a known action type we handle
            if IsPrimaryAction(primaryAction, SI_ITEM_ACTION_USE) or
               IsPrimaryAction(primaryAction, SI_ITEM_ACTION_EQUIP) or
               IsPrimaryAction(primaryAction, SI_ITEM_ACTION_UNEQUIP) or
               IsPrimaryAction(primaryAction, SI_ITEM_ACTION_BANK_WITHDRAW) or
               IsPrimaryAction(primaryAction, SI_ITEM_ACTION_BANK_DEPOSIT) or
               IsPrimaryAction(primaryAction, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG) then
                SetupPrimaryAction(slotActions, primaryAction, inventorySlot)
            end
            -- Ensure Split Stack also gets wired as a primary action so A will
            -- open the split dialog while leaving the action available in Y.
            if IsPrimaryAction(primaryAction, SI_ITEM_ACTION_SPLIT_STACK) then
                SetupPrimaryAction(slotActions, primaryAction, inventorySlot)
            end
        end

        -- (Craft-bag handling is consolidated above; nothing needed here.)

        -- Deduplicate discovered slot actions by name so we don't show the same
        -- action (for example, "Stow") multiple times in the Y actions menu.
        do
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
    end

    self:AddSubCommand(primaryCommand, PrimaryCommandHasBind, PrimaryCommandActivate)

    if additionalMouseOverbinds then
        local mouseOverCommand, mouseOverCommandIsVisible
        for i=1, #additionalMouseOverbinds do
                mouseOverCommand =
            {
                alignment = alignmentOverride,
                name = function()
                    local n = slotActions:GetKeybindActionName(i)
                    return n or ""
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
