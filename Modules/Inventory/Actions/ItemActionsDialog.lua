--[[
File: Modules/Inventory/Actions/ItemActionsDialog.lua
Purpose: Manages the "Y-Action" menu (Action Dialog) for inventory items.
         Includes "Use", "Destroy", "Link to Chat", and "Quickslot Assign" integration.
         Hooks the native ZO_GAMEPAD_INVENTORY_ACTION_DIALOG.
]]



--------------------------------------------------------------------------------
-- SLOT ACTIONS HELPER
--------------------------------------------------------------------------------

--- Initializes the action slot manager for item interactions.
---
--- Purpose: Creates the helper object for "Y" button actions.
--- Mechanics: Instantiates `BETTERUI.Inventory.SlotActions`.
function BETTERUI.Inventory.Class:InitializeItemActions()
    self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
end

--------------------------------------------------------------------------------
-- ACTION DIALOG INITIALIZATION (Content Logic)
--------------------------------------------------------------------------------

--- Initializes the actions dialog (Y-button menu).
---
--- Purpose: Configures the contextual action menu.
--- Mechanics:
--- 1. Registers `BETTERUI_EVENT_ACTION_DIALOG_SETUP/FINISH/CONFIRM` callbacks.
--- 2. **Setup**:
---    - Intercepts "Quickslot Assign" mode to show the wheel dialog instead.
---    - Populates standard actions (Use, Split, Link).
---    - Injects "Mark as Junk" / "Unmark as Junk" securely.
---    - Wraps engine "Lock/Unlock" actions to fix dialog release timing.
--- 3. **Confirm**:
---    - Handles Quickslot assignment logic.
---    - Handles "Destroy" logic (with custom "Quick Destroy" option).
---    - Handles "Link to Chat".
---    - Fallback to standard `DoSelectedAction`.
--- References: Called during Initialize.
function BETTERUI.Inventory.Class:InitializeActionsDialog()
    -- Action mode constants for tracking inventory UI state
    -- Action mode constants (must match other files)
    -- Replaced by BETTERUI.Inventory.CONST equivalents
    local BLOCK_TABBAR_CALLBACK = true

    -- Helper to get Safe Target Data


    local function ActionDialogSetup(dialog, data)
        if self.scene:IsShowing() then
            -- If invoked for quickslot assignment, render the wheel options inside this proven parametric dialog
            if data and data.quickslotAssign and data.target then
                -- Use shared CIM utility for quickslot dialog entry building
                local target = data.target
                local quickslotInfo = BETTERUI.CIM.BuildQuickslotDialogEntries(dialog, target)

                dialog.quickslotTarget = target
                dialog:setupFunc()
                BETTERUI.CIM.SetQuickslotDialogSelection(dialog, quickslotInfo)
                return
            end

            -- Default actions list setup
            -- Title provided via dialog's dynamic title function; avoid overriding here
            dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
                self.itemActions:SetSelectedAction(selectedData and selectedData.action)
            end)

            local function MarkAsJunk()
                -- Silent junk toggle: skip craft bag and locked errors messaging
                if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    return
                end
                local target = BETTERUI.Inventory.Utils.SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
                if not target then
                    return
                end
                -- Respect engine gating: do nothing for companion items or items that cannot be marked as junk
                if IsItemPlayerLocked(target.bagId, target.slotIndex) then
                    return
                end
                if not CanItemBeMarkedAsJunk(target.bagId, target.slotIndex) then
                    return
                end
                local companionJunkEnabled = BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
                if not companionJunkEnabled and GetItemActorCategory(target.bagId, target.slotIndex) == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
                    return
                end
                -- Close the actions dialog to restore header/keybind focus
                if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                    ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                end
                SetItemIsJunk(target.bagId, target.slotIndex, true)
                -- Refresh immediately to restore UI/keybind state (avoid leaving stale focus)
                if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
                    GAMEPAD_INVENTORY:RefreshItemList()
                end
                if self and self.RefreshItemActions then
                    self:RefreshItemActions()
                end
                if self and self.RefreshKeybinds then
                    self:RefreshKeybinds()
                end
                -- Ensure the main keybind descriptor becomes active after toggling junk
                if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
                    self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
                    -- NOTE: Removed duplicate zo_callLater call - causes flickering
                end
            end
            -- Note: Lock/unlock callbacks are wrapped later (engine-provided entries are preserved)
            -- so we no longer inject or maintain synthetic lock/unlock helper functions here.
            local function UnmarkAsJunk()
                local target = BETTERUI.Inventory.Utils.SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
                -- Close the actions dialog to restore header/keybind focus
                if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                    ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                end
                SetItemIsJunk(target.bagId, target.slotIndex, false)
                -- Refresh immediately to restore UI/keybind state (avoid leaving stale focus)
                if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
                    GAMEPAD_INVENTORY:RefreshItemList()
                end
                if self and self.RefreshItemActions then
                    self:RefreshItemActions()
                end
                if self and self.RefreshKeybinds then
                    self:RefreshKeybinds()
                end
                -- Ensure the main keybind descriptor becomes active after toggling junk
                if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
                    self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
                    -- NOTE: Removed duplicate zo_callLater call - causes flickering
                end
            end

            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            -- Removed injected "Assign Quickslot" action from Y menu per request

            -- Get target data FIRST and set on itemActions before RefreshItemActions
            -- This ensures the slot actions controller knows what item to populate actions for
            local target = nil
            if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                target = self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
            elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                target = self.craftBagList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
            elseif self.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
                local catData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
                target = catData and self:GenerateItemSlotData(catData)
            end

            if self.itemActions and self.itemActions.SetInventorySlot and target then
                -- Ensure slotType is present for discovery
                if target and not target.slotType then
                    target.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
                end

                self.itemActions:SetInventorySlot(target)
            end

            -- Directly discover actions on the inner slotActions object as safeguard
            if self.itemActions and self.itemActions.slotActions and target then
                local innerSlotActions = self.itemActions.slotActions
                innerSlotActions:Clear()
                innerSlotActions:SetInventorySlot(target)

                -- Force type again just to be safe
                if not target.slotType then target.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM end

                ZO_InventorySlot_DiscoverSlotActionsFromActionList(target, innerSlotActions)
            end

            self:RefreshItemActions()

            -- Debug info removed
            local titleText = GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND)


            local headerData = {
                titleText = titleText,
            }
            ZO_GamepadGenericHeader_RefreshData(dialog.header, headerData)

            do
                local isLocked = false
                if target and target.bagId and target.slotIndex then
                    isLocked = IsItemPlayerLocked(target.bagId, target.slotIndex)
                end
                local canMarkJunk = true
                if target and target.bagId and target.slotIndex then
                    local companionJunkEnabled = BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
                    canMarkJunk = CanItemBeMarkedAsJunk(target.bagId, target.slotIndex)
                        and (companionJunkEnabled or GetItemActorCategory(target.bagId, target.slotIndex) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION)

                    -- Bug 6: Craft Bag items cannot be marked as Junk
                    if target.bagId == BAG_VIRTUAL then
                        canMarkJunk = false
                    end
                end
                -- Do not show Mark/Unmark as Junk for quest items (they are not junkable)
                local isQuestItem = false
                if target then
                    -- Use the shared helper to determine if this is a quest item row
                    if ZO_InventoryUtils_DoesNewItemMatchFilterType then
                        isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)
                    else
                        isQuestItem = (target.questIndex ~= nil) or (target.toolIndex ~= nil)
                    end
                end

                if not isQuestItem then
                    local tmpCat = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
                    if tmpCat and tmpCat.showJunk ~= nil then
                        -- Unmark should remain available even if locked
                        self.itemActions.slotActions:AddSlotAction(SI_BETTERUI_ACTION_UNMARK_AS_JUNK, UnmarkAsJunk,
                            "secondary")
                    else
                        -- Hide Mark as Junk when the item is locked
                        if not isLocked and canMarkJunk then
                            self.itemActions.slotActions:AddSlotAction(SI_BETTERUI_ACTION_MARK_AS_JUNK, MarkAsJunk,
                                "secondary")
                        end
                    end
                end
                -- Ensure engine-provided Lock/Unlock callbacks release the dialog first.
                -- We do this by wrapping the discovered slot action callbacks rather than injecting synthetic entries.
                do
                    local actions = self.itemActions:GetSlotActions()
                    local numActions = actions:GetNumSlotActions()
                    for i = 1, numActions do
                        local action = actions:GetSlotAction(i)
                        local actionName = actions:GetRawActionName(action)
                        local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
                            SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
                            SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
                        if
                            actionName == GetString(SI_ITEM_ACTION_MARK_AS_LOCKED)
                            or actionName == GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED)
                        then
                            -- Find the corresponding entry inside the backing m_slotActions table and wrap its callback
                            for j, slotAction in ipairs(actions.m_slotActions) do
                                if slotAction and slotAction[1] == actionName then
                                    local origCallback = slotAction[2]
                                    slotAction[2] = function(...)
                                        if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                                            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                                        end
                                        -- Call original callback in protected context if it exists
                                        if origCallback then
                                            origCallback(...)
                                        end
                                        -- NOTE: Removed redundant refresh calls here.
                                        -- ActionDialogFinish (finishedCallback) handles:
                                        --   SetActiveKeybinds, RefreshItemActions, RefreshKeybinds
                                        -- Adding them here too caused duplicate updates → flicker
                                    end
                                    -- Only wrap the first matching entry
                                    break
                                end
                            end
                        end
                    end
                end
            end

            local actions = self.itemActions:GetSlotActions()
            local numActions = actions:GetNumSlotActions()

            for i = 1, numActions do
                local action = actions:GetSlotAction(i)
                local actionName = actions:GetRawActionName(action)

                -- In banking scenes (standard or house), hide Destroy/Delete entirely
                local hideDestroy = BETTERUI.CIM.Utils.IsBankingSceneShowing()
                local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
                    or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
                -- Hide Mark as Junk for locked items
                local hideMarkJunk = false
                do
                    local target = (self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE)
                        and (self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList))
                        or nil
                    if
                        target
                        and target.bagId
                        and target.slotIndex
                        and actionName == GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
                    then
                        local actorCat = GetItemActorCategory(target.bagId, target.slotIndex)
                        local canMark = CanItemBeMarkedAsJunk(target.bagId, target.slotIndex)
                        local companionJunkEnabled = BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
                        hideMarkJunk = IsItemPlayerLocked(target.bagId, target.slotIndex)
                            or not canMark
                            or (not companionJunkEnabled and actorCat == GAMEPLAY_ACTOR_CATEGORY_COMPANION)
                    end
                end
                if not (hideDestroy and isDestroy) and not hideMarkJunk then
                    local entryData = ZO_GamepadEntryData:New(actionName)
                    -- Ensure consistent selection visuals for action rows
                    entryData:SetIconTintOnSelection(true)
                    entryData.action = action
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup

                    local listItem = {
                        template = "ZO_GamepadItemEntryTemplate",
                        entryData = entryData,
                    }
                    table.insert(parametricList, listItem)
                end
            end

            dialog:setupFunc()
        end
    end
    local function ActionDialogFinish()
        if self.scene:IsShowing() then
            -- make sure to wipe out the keybinds added by
            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)

            --restore the selected inventory item
            if self.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
                --if we refresh item actions we will get a keybind conflict
                local currentList = self:GetCurrentList()
                if currentList then
                    local targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(currentList)
                    if currentList == self.categoryList then
                        targetData = self:GenerateItemSlotData(targetData)
                    end
                    self:SetSelectedItemUniqueId(targetData)
                end
                -- Note: RefreshCategoryList moved here for category mode only
                self:RefreshCategoryList()
            else
                self:RefreshItemActions()
            end
            --refresh so keybinds react to newly selected item
            self:RefreshKeybinds()
            -- NOTE: Removed OnUpdate() call - it triggers RefreshItemList + RefreshItemActions
            -- which duplicates the refresh we just did, causing flickering.
        end
    end

    local function ActionDialogButtonConfirm(dialog)
        if not (self.scene and self.scene:IsShowing()) then return end

        -- Preserve current selection before action executes
        -- This ensures list position is maintained after equip/unequip/lock/enchant actions
        local currentList = self:GetCurrentList()
        if currentList and currentList.selectedIndex then
            local targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(currentList)
            if targetData then
                targetData.savedIndex = currentList.selectedIndex
                self.currentlySelectedData = targetData
            end
        end

        -- Handle embedded quickslot assignment mode
        if dialog and dialog.data and dialog.data.quickslotAssign and dialog.entryList then
            local target = dialog.data.target or dialog.quickslotTarget
            if target then
                local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                local selected = BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
                if selected and selected.isUnassign then
                    local assigned = FindActionSlotMatchingItem and
                        FindActionSlotMatchingItem(target.bagId, target.slotIndex, quickslot_wheel)
                    if assigned then
                        CallSecureProtected("ClearSlot", assigned, quickslot_wheel)
                        if SOUNDS and PlaySound then
                            PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
                        end
                    end
                else
                    local wheelSlotIndex = (selected and selected.slotIndex) or 4
                    CallSecureProtected("SelectSlotItem", target.bagId, target.slotIndex, wheelSlotIndex, quickslot_wheel)
                    if SOUNDS and PlaySound then
                        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
                    end
                end
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                zo_callLater(function()
                    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
                        GAMEPAD_INVENTORY:RefreshItemList()
                    end
                end, 150)
            end
            return
        end

        -- Handle BetterUI synthetic Destroy entry
        local selectedRow = dialog.entryList and BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
        if selectedRow and selectedRow.isBetterUIDestroy then
            local targetData
            if dialog and dialog.data and dialog.data.target then
                targetData = dialog.data.target
            elseif dialog.entryList and dialog.entryList.GetTargetData then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
            else
                local actionMode = self and self.actionMode or nil
                if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE and self and self.itemList then
                    targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE and self and self.craftBagList then
                    targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                elseif self and self.categoryList then
                    targetData = self:GenerateItemSlotData(BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList))
                end
            end
            local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
            if bag and slot then
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                local link = GetItemLink(bag, slot)
                local quick = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and
                    BETTERUI.Settings.Modules["Inventory"] and
                    BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
                if quick then
                    BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
                else
                    ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
                        { bagId = bag, slotIndex = slot, itemLink = link }, nil, true, true)
                end
            end
            return
        end

        -- Determine the selected action name (prefer dialog.itemActions, fallback to self.itemActions)
        local actionController = (dialog and dialog.itemActions) or (self and self.itemActions) or nil
        local selectedActionName = nil
        if actionController and actionController.selectedAction then
            selectedActionName = ZO_InventorySlotActions:GetRawActionName(actionController.selectedAction)
        end

        -- Intercept engine Destroy/Delete
        if selectedActionName == GetString(SI_ITEM_ACTION_DESTROY) or (SI_ITEM_ACTION_DELETE and selectedActionName == GetString(SI_ITEM_ACTION_DELETE)) then
            local targetData
            local actionMode = self.actionMode
            if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
            elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
            else
                targetData = self:GenerateItemSlotData(BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList))
            end
            local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
            if bag and slot then
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                local link = GetItemLink(bag, slot)
                local quick = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and
                    BETTERUI.Settings.Modules["Inventory"] and
                    BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
                if quick then
                    BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
                else
                    ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
                        { bagId = bag, slotIndex = slot, itemLink = link }, nil, true, true)
                end
            end
            return
        end

        -- Link to chat handling; hide for companion scene
        if selectedActionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
            local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
                SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
                SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
            if isCompanionSceneShowing then
                return
            end
            local targetData
            local actionMode = self.actionMode
            if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
            elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
            else
                targetData = self:GenerateItemSlotData(BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList))
            end
            local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
            if bag and slot then
                local itemLink = GetItemLink(bag, slot)
                if itemLink then
                    ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
                end
            end
            return
        end

        -- Fallback to original action on the action controller (dialog or self)
        if actionController and actionController.DoSelectedAction then
            actionController:DoSelectedAction()
        end
    end
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", ActionDialogSetup)
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", ActionDialogFinish)
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", ActionDialogButtonConfirm)
    -- Ensure our secure companion equip override is applied (with retries if needed)
    if BETTERUI.Inventory.EnsureCompanionEquipPatched then
        BETTERUI.Inventory.EnsureCompanionEquipPatched()
    end

    -- NOTE: ESO_Dialogs registration removed - ActionDialogHooks.lua handles this registration
    -- and includes proper scene detection for both Inventory and Banking.
    -- The previous duplicate registration here overwrote ActionDialogHooks' version,
    -- preventing Banking's Y-menu from working correctly.
end
