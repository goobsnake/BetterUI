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
                -- SetItemIsJunk is ASYNCHRONOUS: IsItemJunk() returns false immediately after,
                -- so any immediate RefreshCategoryList here cannot create the Junk tab.
                -- The engine fires EVENT_INVENTORY_SINGLE_SLOT_UPDATE after processing the change,
                -- which triggers OnInventoryUpdated -> coalesced RefreshCategoryList (80ms).
                SetItemIsJunk(target.bagId, target.slotIndex, true)
                -- Close the actions dialog to restore header/keybind focus
                if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                    ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                end
                -- Invalidate slot data cache so subsequent refreshes get fresh engine data
                if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.InvalidateSlotDataCache then
                    GAMEPAD_INVENTORY:InvalidateSlotDataCache()
                end
                -- Refresh item list and keybinds (category list refresh is deferred via OnInventoryUpdated)
                if GAMEPAD_INVENTORY then
                    if GAMEPAD_INVENTORY.RefreshItemList then
                        GAMEPAD_INVENTORY:RefreshItemList()
                    end
                end
                if self and self.RefreshItemActions then
                    self:RefreshItemActions()
                end
                if self and self.RefreshKeybinds and not self.isInHeaderSortMode then
                    self:RefreshKeybinds()
                end
                -- Ensure the main keybind descriptor becomes active after toggling junk (skip if in header sort mode)
                if self.SetActiveKeybinds and self.mainKeybindStripDescriptor and not self.isInHeaderSortMode then
                    self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
                end
            end
            -- Note: Lock/unlock callbacks are wrapped later (engine-provided entries are preserved)
            -- so we no longer inject or maintain synthetic lock/unlock helper functions here.
            local function UnmarkAsJunk()
                local target = BETTERUI.Inventory.Utils.SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
                if not target then
                    return
                end
                -- SetItemIsJunk is ASYNCHRONOUS (see MarkAsJunk comment).
                -- Category list refresh is handled by OnInventoryUpdated coalesced timer.
                SetItemIsJunk(target.bagId, target.slotIndex, false)
                -- Close the actions dialog to restore header/keybind focus
                if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                    ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                end
                -- Invalidate slot data cache so subsequent refreshes get fresh engine data
                if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.InvalidateSlotDataCache then
                    GAMEPAD_INVENTORY:InvalidateSlotDataCache()
                end
                -- Refresh item list and keybinds (category list refresh is deferred via OnInventoryUpdated)
                if GAMEPAD_INVENTORY then
                    if GAMEPAD_INVENTORY.RefreshItemList then
                        GAMEPAD_INVENTORY:RefreshItemList()
                    end
                end
                if self and self.RefreshItemActions then
                    self:RefreshItemActions()
                end
                if self and self.RefreshKeybinds and not self.isInHeaderSortMode then
                    self:RefreshKeybinds()
                end
                -- Ensure the main keybind descriptor becomes active after toggling junk (skip if in header sort mode)
                if self.SetActiveKeybinds and self.mainKeybindStripDescriptor and not self.isInHeaderSortMode then
                    self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
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

                -- Hide Stow/Retrieve from Y-menu (redundant with A-button and Stack actions)
                local isStowOrRetrieve = (actionName == GetString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG))
                    or (actionName == GetString(SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG))

                -- Hide obsolete "Convert to Style" actions (handled by Outfit Stations now)
                local isConvertStyle = (actionName == GetString(SI_ITEM_ACTION_CONVERT_TO_IMPERIAL_STYLE))
                    or (actionName == GetString(SI_ITEM_ACTION_CONVERT_TO_MORAG_TONG_STYLE))

                if not (hideDestroy and isDestroy) and not hideMarkJunk and not isStowOrRetrieve and not isConvertStyle then
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

            -- Add "Stow Stack" entry for Inventory mode (stow all items at once)
            if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                local itemTarget = self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                if itemTarget and itemTarget.bagId and itemTarget.slotIndex then
                    local stackCount = GetSlotStackSize(itemTarget.bagId, itemTarget.slotIndex) or 1
                    local canStow = BETTERUI.CIM.CanItemMoveToCraftBag(itemTarget)
                    if canStow and stackCount > 1 then
                        local stowStackEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_STOW_STACK))
                        stowStackEntry:SetIconTintOnSelection(true)
                        stowStackEntry.isStowStackAction = true
                        stowStackEntry.itemTarget = itemTarget
                        stowStackEntry.setup = ZO_SharedGamepadEntry_OnSetup

                        local listItem = {
                            template = "ZO_GamepadItemEntryTemplate",
                            entryData = stowStackEntry,
                        }
                        table.insert(parametricList, 1, listItem)
                    end
                end
            end

            -- Add "Retrieve Stack" entry for Craft Bag mode (retrieve all items at once)
            if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                local craftBagTarget = self.craftBagList and
                    BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                if craftBagTarget and craftBagTarget.bagId and craftBagTarget.slotIndex then
                    local stackCount = GetSlotStackSize(craftBagTarget.bagId, craftBagTarget.slotIndex) or 1
                    if stackCount > 1 then
                        local retrieveStackEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_RETRIEVE_STACK))
                        retrieveStackEntry:SetIconTintOnSelection(true)
                        retrieveStackEntry.isRetrieveStackAction = true
                        retrieveStackEntry.itemTarget = craftBagTarget
                        retrieveStackEntry.setup = ZO_SharedGamepadEntry_OnSetup

                        local listItem = {
                            template = "ZO_GamepadItemEntryTemplate",
                            entryData = retrieveStackEntry,
                        }
                        table.insert(parametricList, 1, listItem)
                    end
                end
            end

            -- Add "Sort" entry for header sort mode access
            -- Works for both Inventory (item/craft bag mode) and Banking scenes
            local showSortEntry = false
            local currentList = nil
            local sortContext = nil -- The class instance to call EnterHeaderSortMode on

            -- Check Inventory modes (self is Inventory.Class in this callback)
            if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                currentList = self.itemList
                sortContext = self
                showSortEntry = true
            elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                currentList = self.craftBagList
                sortContext = self
                showSortEntry = true
                -- Check Banking scene - access Banking.Class directly since self is Inventory
            elseif BETTERUI.CIM.Utils.IsBankingSceneShowing() then
                local bankingClass = BETTERUI.Banking and BETTERUI.Banking.Class
                if bankingClass and bankingClass.list then
                    currentList = bankingClass.list
                    sortContext = bankingClass
                    showSortEntry = true
                end
            end

            if showSortEntry and sortContext and sortContext.EnterHeaderSortMode
                and currentList and not currentList:IsEmpty() then
                local sortEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_HEADER_SORT))
                sortEntry:SetIconTintOnSelection(true)
                sortEntry.isSortAction = true
                sortEntry.sortContext = sortContext -- Store which class to call
                sortEntry.setup = ZO_SharedGamepadEntry_OnSetup

                local listItem = {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = sortEntry,
                }
                table.insert(parametricList, listItem)
            end

            -- Move "Get Help" to end of list (should always be last action)
            -- ZO_GamepadEntryData stores text via GetText(), not .name
            local getHelpName = GetString(SI_ITEM_ACTION_REPORT_ITEM)
            local getHelpIndex = nil
            for i, entry in ipairs(parametricList) do
                if entry.entryData and entry.entryData.GetText and entry.entryData:GetText() == getHelpName then
                    getHelpIndex = i
                    break
                end
            end
            if getHelpIndex and getHelpIndex < #parametricList then
                local getHelpEntry = table.remove(parametricList, getHelpIndex)
                table.insert(parametricList, getHelpEntry)
            end

            dialog:setupFunc()
        end
    end
    local function ActionDialogFinish()
        if self.scene:IsShowing() then
            -- make sure to wipe out the keybinds added by dialog (skip if in header sort mode)
            if not self.isInHeaderSortMode then
                self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
            end

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
            --refresh so keybinds react to newly selected item (skip if in header sort mode)
            if not self.isInHeaderSortMode then
                self:RefreshKeybinds()
            end
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

        -- Resolve the selected action from the dialog's parametric list
        local selectedRow = dialog.entryList and BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)

        -- Handle "Sort" entry to enter header sort mode
        if selectedRow and selectedRow.isSortAction then
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            -- Use stored sortContext (could be Inventory or Banking class)
            local sortContext = selectedRow.sortContext or self
            if sortContext and sortContext.EnterHeaderSortMode then
                sortContext:EnterHeaderSortMode()
            end
            return
        end

        -- Handle "Stow Stack" action
        if selectedRow and selectedRow.isStowStackAction then
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)

            local itemTarget = selectedRow.itemTarget
            if itemTarget and BETTERUI.Inventory.Dialogs and BETTERUI.Inventory.Dialogs.StowFullStack then
                BETTERUI.Inventory.Dialogs.StowFullStack(itemTarget)
            end
            return
        end

        -- Handle "Retrieve Stack" action
        if selectedRow and selectedRow.isRetrieveStackAction then
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local itemTarget = selectedRow.itemTarget
            if itemTarget and BETTERUI.Inventory.Dialogs and BETTERUI.Inventory.Dialogs.RetrieveFullStack then
                BETTERUI.Inventory.Dialogs.RetrieveFullStack(itemTarget)
            end
            return
        end

        -- Handle BetterUI synthetic Destroy entry
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

        -- Determine the selected action name from the parametric list entry (not the engine controller,
        -- which can be out of sync with what the user actually selected in the dialog)
        local selectedActionName = selectedRow and selectedRow.text or nil

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

        -- Y-MENU EQUIP FIX: Intercept Equip action and call TryEquipItem with fresh target data.
        -- The engine's action callback captures a stale inventorySlot reference from discovery time.
        if selectedActionName == GetString(SI_ITEM_ACTION_EQUIP) then
            local targetData
            local actionMode = self.actionMode
            if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
            elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
            else
                targetData = self:GenerateItemSlotData(BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList))
            end
            if targetData and targetData.dataSource then
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                -- Call TryEquipItem with fresh data, passing true for isCallingFromActionDialog
                self:TryEquipItem(targetData, true)
            end
            return
        end

        -- Y-MENU SECURE USE FIX: Intercept Use-related actions that require a trusted callstack.
        -- Bypasses the insecure ZOS proxy function to execute safely.
        if selectedActionName == GetString(SI_ITEM_ACTION_USE)
            or selectedActionName == GetString(SI_ITEM_ACTION_SHOW_MAP)
            or selectedActionName == GetString(SI_ITEM_ACTION_START_SKILL_RESPEC)
            or selectedActionName == GetString(SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC) then
            local targetData
            local actionMode = self.actionMode
            if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
            elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
            else
                targetData = self:GenerateItemSlotData(BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList))
            end

            if targetData then
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                local ds = targetData.dataSource or targetData
                local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType and
                    ZO_InventoryUtils_DoesNewItemMatchFilterType(targetData, ITEMFILTERTYPE_QUEST)
                if isQuestItem and ds.toolIndex then
                    UseQuestTool(ds.questIndex, ds.toolIndex)
                elseif isQuestItem and ds.stepIndex and ds.conditionIndex then
                    UseQuestItem(ds.questIndex, ds.stepIndex, ds.conditionIndex)
                else
                    local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
                    if bag and slot then
                        CallSecureProtected("UseItem", bag, slot)
                    end
                end
            end
            return
        end

        -- Fallback: execute the action stored on the selected parametric list entry
        if selectedRow and selectedRow.action then
            local actions = self.itemActions and self.itemActions:GetSlotActions()
            if actions then
                actions:DoAction(selectedRow.action)
            end
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
