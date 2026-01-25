--[[
File: Modules/Inventory/Actions/ItemActionsDialog.lua
Purpose: Manages the "Y-Action" menu (Action Dialog) for inventory items.
         Includes "Use", "Destroy", "Link to Chat", and "Quickslot Assign" integration.
         Hooks the native ZO_GAMEPAD_INVENTORY_ACTION_DIALOG.
]]

local function SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    return list.targetData
end

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
    local CATEGORY_ITEM_ACTION_MODE = 1
    local ITEM_LIST_ACTION_MODE = 2
    local CRAFT_BAG_ACTION_MODE = 3
    local BLOCK_TABBAR_CALLBACK = true

    -- Helper to get Safe Target Data
    local function SafeGetTargetData(list)
        if not list then return nil end
        if list.GetTargetData and type(list.GetTargetData) == "function" then
            return list:GetTargetData()
        end
        return list.selectedData
    end

    local function ActionDialogSetup(dialog, data)
        if self.scene:IsShowing() then
            -- If invoked for quickslot assignment, render the wheel options inside this proven parametric dialog
            if data and data.quickslotAssign and data.target then
                -- Title provided via dialog's dynamic title function; avoid overriding here
                local parametricList = dialog.info.parametricList
                ZO_ClearNumericallyIndexedTable(parametricList)

                local target = data.target
                local hasUnassign = false
                local assignedIndex = nil
                if FindActionSlotMatchingItem then
                    assignedIndex =
                        FindActionSlotMatchingItem(target.bagId, target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                    if assignedIndex then
                        hasUnassign = true
                        -- Ensure the Remove row text is visible; icon not required
                        local removeText = GetString(SI_ITEM_ACTION_REMOVE)
                        if not removeText or removeText == "" then
                            removeText = "Remove"
                        end
                        local unassignEntry = ZO_GamepadEntryData:New(removeText)
                        unassignEntry:SetIconTintOnSelection(true)
                        local normalColor = ZO_NORMAL_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
                        local selectedColor = ZO_SELECTED_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
                        if unassignEntry.SetNameColors then
                            unassignEntry:SetNameColors(normalColor, selectedColor)
                        end
                        unassignEntry.isUnassign = true
                        unassignEntry.setup = ZO_SharedGamepadEntry_OnSetup
                        table.insert(
                            parametricList,
                            { template = "ZO_GamepadMenuEntryTemplate", entryData = unassignEntry }
                        )
                    end
                end

                local function slotLabel(idx)
                    if idx == 4 then
                        return "North"
                    elseif idx == 5 then
                        return "Northwest"
                    elseif idx == 6 then
                        return "West"
                    elseif idx == 7 then
                        return "Southwest"
                    elseif idx == 8 then
                        return "South"
                    elseif idx == 1 then
                        return "Southeast"
                    elseif idx == 2 then
                        return "East"
                    elseif idx == 3 then
                        return "Northeast"
                    end
                    return tostring(idx)
                end

                -- Clockwise ordering starting at North: N, NE, E, SE, S, SW, W, NW
                local orderedSlots = { 4, 3, 2, 1, 8, 7, 6, 5 }
                for _, slotIndex in ipairs(orderedSlots) do
                    local icon = GetSlotTexture and GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
                    local lower = type(icon) == "string" and icon:lower() or nil
                    -- Prefer a clearly visible empty-slot texture when the quickslot is unassigned
                    if not icon or icon == "" or (lower and string.find(lower, "quickslot_empty", 1, true)) then
                        -- Use a known-good icon that exists in this UI: the gamepad quickslot category icon
                        icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
                    end
                    local entryData = ZO_GamepadEntryData:New(slotLabel(slotIndex), icon)
                    if entryData.AddIcon and icon then
                        entryData:AddIcon(icon)
                    end
                    -- Flash all non-current slots; keep the currently assigned slot steady
                    local isCurrent = assignedIndex ~= nil and (slotIndex == assignedIndex)
                    local shouldFlash = not isCurrent
                    entryData.alphaChangeOnSelection = shouldFlash
                    entryData.showBarEvenWhenUnselected = shouldFlash
                    entryData:SetIconTintOnSelection(shouldFlash)
                    entryData.slotIndex = slotIndex
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup
                    local templateName = isCurrent and "ZO_GamepadMenuEntryTemplate" or "ZO_GamepadItemEntryTemplate"
                    table.insert(parametricList, { template = templateName, entryData = entryData })
                end

                dialog.quickslotTarget = target
                dialog:setupFunc()
                if dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                    local offset = hasUnassign and 1 or 0
                    if assignedIndex then
                        -- Map the quickslot index to its position in the ordered list
                        local indexMap = {}
                        for pos, idx in ipairs(orderedSlots) do
                            indexMap[idx] = pos
                        end
                        local listPos = (indexMap[assignedIndex] or 1) + offset
                        dialog.entryList:SetSelectedIndexWithoutAnimation(listPos, true, false)
                    else
                        dialog.entryList:SetSelectedIndexWithoutAnimation(hasUnassign and 2 or 1, true, false)
                    end
                end
                return
            end

            -- Default actions list setup
            -- Title provided via dialog's dynamic title function; avoid overriding here
            dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
                self.itemActions:SetSelectedAction(selectedData and selectedData.action)
            end)

            local function MarkAsJunk()
                -- Silent junk toggle: skip craft bag and locked errors messaging
                if self.actionMode == CRAFT_BAG_ACTION_MODE then
                    return
                end
                local target = SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
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
                    zo_callLater(function()
                        if self.SetActiveKeybinds then
                            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
                        end
                    end, 40)
                end
            end
            -- Note: Lock/unlock callbacks are wrapped later (engine-provided entries are preserved)
            -- so we no longer inject or maintain synthetic lock/unlock helper functions here.
            local function UnmarkAsJunk()
                local target = SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
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
                    zo_callLater(function()
                        if self.SetActiveKeybinds then
                            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
                        end
                    end, 40)
                end
            end

            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            -- Removed injected "Assign Quickslot" action from Y menu per request

            self:RefreshItemActions()

            do
                local target = (self.actionMode == ITEM_LIST_ACTION_MODE)
                    and (self.itemList and SafeGetTargetData(self.itemList))
                    or nil
                local isLocked = false
                if target and target.bagId and target.slotIndex then
                    isLocked = IsItemPlayerLocked(target.bagId, target.slotIndex)
                end
                local canMarkJunk = true
                if target and target.bagId and target.slotIndex then
                    local companionJunkEnabled = BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
                    canMarkJunk = CanItemBeMarkedAsJunk(target.bagId, target.slotIndex)
                        and (companionJunkEnabled or GetItemActorCategory(target.bagId, target.slotIndex) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION)
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
                    local tmpCat = SafeGetTargetData(self.categoryList)
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
                                        -- Immediately refresh item list and actions to restore UI/keybind state
                                        if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
                                            GAMEPAD_INVENTORY:RefreshItemList()
                                        end
                                        if self and self.RefreshItemActions then
                                            self:RefreshItemActions()
                                        end
                                        if self and self.RefreshKeybinds then
                                            self:RefreshKeybinds()
                                        end
                                        -- Ensure the main keybind descriptor becomes active after lock/unlock flows
                                        if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
                                            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
                                            zo_callLater(function()
                                                if self.SetActiveKeybinds then
                                                    self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
                                                end
                                            end, 40)
                                        end
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
                local hideDestroy = SCENE_MANAGER
                    and SCENE_MANAGER.scenes
                    and SCENE_MANAGER.scenes["gamepad_banking"]
                    and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
                local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
                    or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
                -- Hide Mark as Junk for locked items
                local hideMarkJunk = false
                do
                    local target = (self.actionMode == ITEM_LIST_ACTION_MODE)
                        and (self.itemList and SafeGetTargetData(self.itemList))
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
            if self.actionMode == CATEGORY_ITEM_ACTION_MODE then
                --if we refresh item actions we will get a keybind conflict
                local currentList = self:GetCurrentList()
                if currentList then
                    local targetData = SafeGetTargetData(currentList)
                    if currentList == self.categoryList then
                        targetData = self:GenerateItemSlotData(targetData)
                    end
                    self:SetSelectedItemUniqueId(targetData)
                end
            else
                self:RefreshItemActions()
            end
            --refresh so keybinds react to newly selected item
            self:RefreshKeybinds()

            self:OnUpdate()
            if self.actionMode == CATEGORY_ITEM_ACTION_MODE then
                self:RefreshCategoryList()
            end
        end
    end

    local function ActionDialogButtonConfirm(dialog)
        if not (self.scene and self.scene:IsShowing()) then return end

        -- Handle embedded quickslot assignment mode
        if dialog and dialog.data and dialog.data.quickslotAssign and dialog.entryList then
            local target = dialog.data.target or dialog.quickslotTarget
            if target then
                local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                local selected = SafeGetTargetData(dialog.entryList)
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
        local selectedRow = dialog.entryList and SafeGetTargetData(dialog.entryList)
        if selectedRow and selectedRow.isBetterUIDestroy then
            local targetData
            if dialog and dialog.data and dialog.data.target then
                targetData = dialog.data.target
            elseif dialog.entryList and dialog.entryList.GetTargetData then
                targetData = SafeGetTargetData(dialog.entryList)
            else
                local actionMode = self and self.actionMode or nil
                if actionMode == ITEM_LIST_ACTION_MODE and self and self.itemList then
                    targetData = SafeGetTargetData(self.itemList)
                elseif actionMode == CRAFT_BAG_ACTION_MODE and self and self.craftBagList then
                    targetData = SafeGetTargetData(self.craftBagList)
                elseif self and self.categoryList then
                    targetData = self:GenerateItemSlotData(SafeGetTargetData(self.categoryList))
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
            if actionMode == ITEM_LIST_ACTION_MODE then
                targetData = SafeGetTargetData(self.itemList)
            elseif actionMode == CRAFT_BAG_ACTION_MODE then
                targetData = SafeGetTargetData(self.craftBagList)
            else
                targetData = self:GenerateItemSlotData(SafeGetTargetData(self.categoryList))
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
            if actionMode == ITEM_LIST_ACTION_MODE then
                targetData = SafeGetTargetData(self.itemList)
            elseif actionMode == CRAFT_BAG_ACTION_MODE then
                targetData = SafeGetTargetData(self.craftBagList)
            else
                targetData = self:GenerateItemSlotData(SafeGetTargetData(self.categoryList))
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
end

--------------------------------------------------------------------------------
-- DESTROY ITEM LOGIC
--------------------------------------------------------------------------------

--- Attempts to destroy an item, dealing with junk status and user confirmation settings.
---
--- Purpose: Safer replacement for `DestroyItem`.
--- Mechanics:
--- 1. Checks if item is Junk or `force` flag is true.
--- 2. If so, destroys immediately (fixing sound and refreshing cache).
--- 3. Returns true if destroyed, false if confirmation (UI) is needed.
--- References: Called by Hooked Destroy and Action Dialog.
function BETTERUI.Inventory.TryDestroyItem(bagId, slotIndex, force)
    if not bagId or not slotIndex then
        return false
    end
    -- Allow destruction if explicitly confirmed or the item is junk
    if force or IsItemJunk(bagId, slotIndex) then
        -- Direct engine destroy path (matches the original working hook behavior)
        SetCursorItemSoundsEnabled(false)
        DestroyItem(bagId, slotIndex)
        -- Proactively refresh inventory caches to reflect removal
        if SHARED_INVENTORY and SHARED_INVENTORY.PerformFullUpdateOnBagCache then
            pcall(function()
                SHARED_INVENTORY:PerformFullUpdateOnBagCache(bagId)
            end)
        end
        -- UI refreshes (safe if scene present)
        zo_callLater(function()
            if GAMEPAD_INVENTORY then
                if GAMEPAD_INVENTORY.RefreshItemList then
                    GAMEPAD_INVENTORY:RefreshItemList()
                end
                if GAMEPAD_INVENTORY.RefreshCategoryList then
                    GAMEPAD_INVENTORY:RefreshCategoryList()
                end
                if GAMEPAD_INVENTORY.RefreshHeader then
                    GAMEPAD_INVENTORY:RefreshHeader(BLOCK_TABBAR_CALLBACK)
                end
            end
        end, 80)
        return true
    end
    return false
end

--- Hooks the native destroy logic (X button in some contexts).
---
--- Purpose: Redirects engine destruction calls to `TryDestroyItem`.
--- Mechanics: Overwrites `ZO_InventorySlot_InitiateDestroyItem` with a wrapper that checks `quickDestroy` settings.
function BETTERUI.Inventory.HookDestroyItem()
    ZO_InventorySlot_InitiateDestroyItem = function(inventorySlot)
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        local force = false
        if BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Inventory"] then
            force = BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
        end
        return BETTERUI.Inventory.TryDestroyItem(bag, index, force)
    end
end

--------------------------------------------------------------------------------
-- DIALOG HOOKS (System Integration)
--------------------------------------------------------------------------------

--- Hooks the native Y-button Action Dialog.
---
--- Purpose: Replaces or extends the `ZO_GAMEPAD_INVENTORY_ACTION_DIALOG`.
--- Mechanics:
--- - Registers a **custom** dialog with the **same name** as the engine's dialog (`ZO_GAMEPAD_INVENTORY_ACTION_DIALOG`).
--- - This effectively overrides the native dialog definition.
--- - Implements custom `setup` to handle:
---   - Quickslot Assignment (embedded).
---   - Safe "Destroy" (BetterUI replacement).
---   - "Link to Chat" (safety checks).
--- - Implements custom `buttons` (Select/Cancel) to route actions correctly.
function BETTERUI.Inventory.HookActionDialog()
    local function ActionsDialogSetup(dialog, data)
        local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
            SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
            SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()

        -- Guard against data.itemActions being nil (saw this in crash logs)
        if not data.itemActions then
            return
        end

        dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
            data.itemActions:SetSelectedAction(selectedData and selectedData.action)
        end)
        local parametricList = dialog.info.parametricList
        ZO_ClearNumericallyIndexedTable(parametricList)

        dialog.itemActions = data.itemActions
        local actions = data.itemActions:GetSlotActions()
        local numActions = actions:GetNumSlotActions()

        for i = 1, numActions do
            local action = actions:GetSlotAction(i)
            local actionName = actions:GetRawActionName(action)

            local entryData = ZO_GamepadEntryData:New(actionName)
            entryData:SetIconTintOnSelection(true)
            entryData.setup = ZO_SharedGamepadEntry_OnSetup
            -- Intercept Destroy/Delete to route through BetterUI confirm dialog
            local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
                or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
            local inBankScene = SCENE_MANAGER
                and SCENE_MANAGER.scenes
                and SCENE_MANAGER.scenes["gamepad_banking"]
                and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
            if not (isDestroy and inBankScene) then
                -- When in the companion equipment scene, hide the 'Link to Chat' action to avoid insecure SendChatMessage calls
                if actionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) and isCompanionSceneShowing then
                    -- skip adding this action entirely
                else
                    if isDestroy then
                        entryData.isBetterUIDestroy = true
                        entryData.action = nil -- prevent engine destroy from being selected/executed
                    else
                        entryData.action = action
                    end

                    local listItem = {
                        template = "ZO_GamepadItemEntryTemplate",
                        entryData = entryData,
                    }
                    table.insert(parametricList, listItem)
                end
            end
        end

        dialog.finishedCallback = data.finishedCallback

        dialog:setupFunc()
    end

    ZO_Dialogs_RegisterCustomDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, {
        blockDirectionalInput = true,
        canQueue = true,
        setup = function(dialog, data)
            -- Always handle our embedded quickslot mode here for robustness
            if data and data.quickslotAssign and data.target then
                -- Title provided via dialog's dynamic title function; avoid overriding here
                local parametricList = dialog.info.parametricList
                ZO_ClearNumericallyIndexedTable(parametricList)

                local target = data.target
                local hasUnassign = false
                local assignedIndex = nil
                if FindActionSlotMatchingItem then
                    assignedIndex =
                        FindActionSlotMatchingItem(target.bagId, target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                    if assignedIndex then
                        hasUnassign = true
                        local removeText = GetString(SI_ITEM_ACTION_REMOVE)
                        if not removeText or removeText == "" then
                            removeText = "Remove"
                        end
                        local unassignEntry = ZO_GamepadEntryData:New(removeText)
                        unassignEntry:SetIconTintOnSelection(true)
                        -- Ensure text is visible on dark background
                        local normalColor = ZO_NORMAL_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
                        local selectedColor = ZO_SELECTED_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
                        if unassignEntry.SetNameColors then
                            unassignEntry:SetNameColors(normalColor, selectedColor)
                        end
                        unassignEntry.isUnassign = true
                        unassignEntry.setup = ZO_SharedGamepadEntry_OnSetup
                        table.insert(
                            parametricList,
                            { template = "ZO_GamepadMenuEntryTemplate", entryData = unassignEntry }
                        )
                    end
                end

                local function slotLabel(idx)
                    if idx == 4 then
                        return GetString(SI_BETTERUI_DIR_NORTH)
                    elseif idx == 5 then
                        return GetString(SI_BETTERUI_DIR_NORTHWEST)
                    elseif idx == 6 then
                        return GetString(SI_BETTERUI_DIR_WEST)
                    elseif idx == 7 then
                        return GetString(SI_BETTERUI_DIR_SOUTHWEST)
                    elseif idx == 8 then
                        return GetString(SI_BETTERUI_DIR_SOUTH)
                    elseif idx == 1 then
                        return GetString(SI_BETTERUI_DIR_SOUTHEAST)
                    elseif idx == 2 then
                        return GetString(SI_BETTERUI_DIR_EAST)
                    elseif idx == 3 then
                        return GetString(SI_BETTERUI_DIR_NORTHEAST)
                    end
                    return tostring(idx)
                end

                -- Clockwise ordering starting at North: N, NE, E, SE, S, SW, W, NW
                local orderedSlots = { 4, 3, 2, 1, 8, 7, 6, 5 }
                for _, slotIndex in ipairs(orderedSlots) do
                    local icon = GetSlotTexture and GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
                    local lower = type(icon) == "string" and icon:lower() or nil
                    if not icon or icon == "" or (lower and string.find(lower, "quickslot_empty", 1, true)) then
                        icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
                    end
                    local entryData = ZO_GamepadEntryData:New(slotLabel(slotIndex), icon)
                    if entryData.AddIcon and icon then
                        entryData:AddIcon(icon)
                    end
                    -- Flash all non-current slots; keep the currently assigned slot steady
                    local isCurrent = assignedIndex ~= nil and (slotIndex == assignedIndex)
                    local shouldFlash = not isCurrent
                    entryData.alphaChangeOnSelection = shouldFlash
                    entryData.showBarEvenWhenUnselected = shouldFlash
                    entryData:SetIconTintOnSelection(shouldFlash)
                    entryData.slotIndex = slotIndex
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup
                    local templateName = isCurrent and "ZO_GamepadMenuEntryTemplate" or "ZO_GamepadItemEntryTemplate"
                    table.insert(parametricList, { template = templateName, entryData = entryData })
                end

                dialog.quickslotTarget = target
                dialog:setupFunc()
                if dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                    local offset = hasUnassign and 1 or 0
                    if assignedIndex then
                        local indexMap = {}
                        for pos, idx in ipairs(orderedSlots) do
                            indexMap[idx] = pos
                        end
                        local listPos = (indexMap[assignedIndex] or 1) + offset
                        dialog.entryList:SetSelectedIndexWithoutAnimation(listPos, true, false)
                    else
                        dialog.entryList:SetSelectedIndexWithoutAnimation(hasUnassign and 2 or 1, true, false)
                    end
                end
                return
            end
            -- Debug: if the selected action is Equip and the companion scene is active, check if patch is present


            -- Normal BetterUI override path when enabled/visible
            -- Title provided via dialog's dynamic title function; avoid overriding here
            if
                (
                    BETTERUI.Settings.Modules["Inventory"].m_enabled
                    and SCENE_MANAGER.scenes["gamepad_inventory_root"]:IsShowing()
                )
                or (
                    BETTERUI.Settings.Modules["Banking"].m_enabled
                    and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
                )
            then
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_SETUP", dialog, data)
                return
            end
            -- Original function
            ActionsDialogSetup(dialog, data)
        end,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = {
            text = function(dialog)
                if dialog and dialog.data and dialog.data.quickslotAssign then
                    return "Assign Quickslots"
                end
                return GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND)
            end,
        },
        parametricList = {}, --we'll generate the entries on setup
        finishedCallback = function(dialog)
            if
                (
                    BETTERUI.Settings.Modules["Inventory"].m_enabled
                    and SCENE_MANAGER.scenes["gamepad_inventory_root"]:IsShowing()
                )
                or (
                    BETTERUI.Settings.Modules["Banking"].m_enabled
                    and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
                )
            then
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_FINISH", dialog)
                return
            end
            --original function
            dialog.itemActions = nil
            if dialog.finishedCallback then
                dialog.finishedCallback()
            end
            dialog.finishedCallback = nil
        end,

        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    -- Handle embedded quickslot mode regardless of BetterUI override gating
                    if dialog and dialog.data and dialog.data.quickslotAssign and dialog.entryList then
                        local target = dialog.data.target or dialog.quickslotTarget
                        if target then
                            local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                            local selected = SafeGetTargetData(dialog.entryList)
                            if selected and selected.isUnassign then
                                local assigned = FindActionSlotMatchingItem
                                    and FindActionSlotMatchingItem(target.bagId, target.slotIndex, quickslot_wheel)
                                if assigned then
                                    CallSecureProtected("ClearSlot", assigned, quickslot_wheel)
                                    if SOUNDS and PlaySound then
                                        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
                                    end
                                end
                            else
                                local wheelSlotIndex = (selected and selected.slotIndex) or 4
                                CallSecureProtected(
                                    "SelectSlotItem",
                                    target.bagId,
                                    target.slotIndex,
                                    wheelSlotIndex,
                                    quickslot_wheel
                                )
                                if SOUNDS and PlaySound then
                                    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
                                end
                            end
                            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                            zo_callLater(function()
                                if GAMEPAD_INVENTORY then
                                    GAMEPAD_INVENTORY:RefreshItemList()
                                end
                            end, 150)
                        end
                        return
                    end
                    if
                        (
                            BETTERUI.Settings.Modules["Inventory"].m_enabled
                            and SCENE_MANAGER.scenes["gamepad_inventory_root"]:IsShowing()
                        )
                        or (
                            BETTERUI.Settings.Modules["Banking"].m_enabled
                            and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
                        )
                    then
                        CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", dialog)
                        return
                    end
                    -- Handle BetterUI synthetic Destroy and Link to Chat explicitly even outside BetterUI override
                    if ZO_InventorySlotActions and dialog and dialog.itemActions and dialog.itemActions.selectedAction then
                        -- Check if the selected row is a BetterUI Destroy entry
                        local selectedRow = dialog.entryList and SafeGetTargetData(dialog.entryList)
                        if selectedRow and selectedRow.isBetterUIDestroy then
                            local targetData
                            local actionMode = self.actionMode
                            if actionMode == ITEM_LIST_ACTION_MODE then
                                targetData = SafeGetTargetData(self.itemList)
                            elseif actionMode == CRAFT_BAG_ACTION_MODE then
                                targetData = SafeGetTargetData(self.craftBagList)
                            else
                                targetData = self:GenerateItemSlotData(SafeGetTargetData(self.categoryList))
                            end
                            local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                            if bag and slot then
                                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                                local itemLink = GetItemLink(bag, slot)
                                local quick = BETTERUI
                                    and BETTERUI.Settings
                                    and BETTERUI.Settings.Modules
                                    and BETTERUI.Settings.Modules["Inventory"]
                                    and BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
                                if quick then
                                    BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
                                else
                                    ZO_Dialogs_ShowDialog(
                                        "BETTERUI_CONFIRM_DESTROY_DIALOG",
                                        { bagId = bag, slotIndex = slot, itemLink = itemLink },
                                        nil,
                                        true,
                                        true
                                    )
                                end
                            end
                            return
                        end
                        local selectedActionName = nil
                        do
                            local actionController = nil
                            if dialog and dialog.itemActions then
                                actionController = dialog.itemActions
                            elseif self and self.itemActions then
                                actionController = self.itemActions
                            end
                            if actionController and actionController.selectedAction then
                                selectedActionName = ZO_InventorySlotActions:GetRawActionName(actionController
                                    .selectedAction)
                            end
                        end
                        if selectedActionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
                            local targetData
                            -- Prefer dialog-local target data when available (companion scene uses dialog-targets)
                            if dialog.data and dialog.data.target then
                                targetData = dialog.data.target
                            elseif dialog.entryList and dialog.entryList.GetTargetData then
                                targetData = SafeGetTargetData(dialog.entryList)
                            else
                                local actionMode = self and self.actionMode or nil
                                if actionMode == ITEM_LIST_ACTION_MODE and self and self.itemList then
                                    targetData = SafeGetTargetData(self.itemList)
                                elseif actionMode == CRAFT_BAG_ACTION_MODE and self and self.craftBagList then
                                    targetData = SafeGetTargetData(self.craftBagList)
                                elseif self and self.categoryList then
                                    targetData = self:GenerateItemSlotData(SafeGetTargetData(self.categoryList))
                                end
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
                    end
                    --original function
                    do
                        local actionController = nil
                        if dialog and dialog.itemActions then
                            actionController = dialog.itemActions
                        elseif self and self.itemActions then
                            actionController = self.itemActions
                        end
                        if actionController and actionController.DoSelectedAction then
                            actionController:DoSelectedAction()
                        end
                    end
                end,
            },
        },
    })
end
