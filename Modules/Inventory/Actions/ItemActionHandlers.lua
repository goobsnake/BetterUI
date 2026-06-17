if not BETTERUI.Inventory then BETTERUI.Inventory = {} end
if not BETTERUI.Inventory.ActionHandlers then BETTERUI.Inventory.ActionHandlers = {} end

local ActionHandlers = BETTERUI.Inventory.ActionHandlers

local function RequireDestroyPolicyAuthorizer()
    local inventory = BETTERUI and BETTERUI.Inventory or nil
    local canDestroyItemWithPolicy = inventory and inventory.CanDestroyItemWithPolicy or nil
    if type(canDestroyItemWithPolicy) == "function" then
        return canDestroyItemWithPolicy
    end

    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before inventory action-handler destroy checks")
    local canDestroyItem = policy.CanDestroyItem
    assert(type(canDestroyItem) == "function",
        "BetterUI: CIM.ProtectionPolicy.CanDestroyItem must load before inventory action-handler destroy checks")
    return canDestroyItem
end

local function GetProtectionPolicy()
    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before inventory action-handler junk checks")
    return policy
end

local function RequireProtectionPolicyMethod(methodName)
    local policy = GetProtectionPolicy()
    local method = policy and policy[methodName] or nil
    assert(type(method) == "function",
        string.format("BetterUI: CIM.ProtectionPolicy.%s must load before inventory action-handler junk checks", tostring(methodName)))
    return method
end

local function CanJunkWithPolicy(target)
    if not target or not target.bagId or not target.slotIndex then
        return false
    end
    return RequireProtectionPolicyMethod("CanJunkItem")(target.bagId, target.slotIndex) == true
end

local function CanUnjunkWithPolicy(target)
    if not target or not target.bagId or not target.slotIndex then
        return false
    end
    return RequireProtectionPolicyMethod("CanUnjunkItem")(target.bagId, target.slotIndex) == true
end

local function ToggleJunkState(self, isJunk, target, expectedSlotIdentity)
    if self and self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        return
    end
    -- Prefer the target captured when the dialog entry was built: in category
    -- mode the dialog target differs from the itemList selection.
    target = target or BETTERUI.Inventory.Utils.SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
    if not target then return end

    -- Slot identity gate (mirrors destroy/equip): the action dialog can stay
    -- open across inventory updates, so cancel instead of junk-toggling a slot
    -- that no longer holds the item the entry was built for.
    if expectedSlotIdentity
        and BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(expectedSlotIdentity, target.bagId, target.slotIndex) ~= true then
        BETTERUI.CIM.UserNotify("ItemActionHandlers:JunkStaleSlot",
            GetString(rawget(_G, "SI_BETTERUI_ITEM_CHANGED_CANCELLED")))
        return
    end

    local canToggleJunk
    if isJunk then
        canToggleJunk = CanJunkWithPolicy(target)
    else
        canToggleJunk = CanUnjunkWithPolicy(target)
    end
    if not canToggleJunk then
        return
    end

    SetItemIsJunk(target.bagId, target.slotIndex, isJunk)

    if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
    end
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.InvalidateSlotDataCache then
        GAMEPAD_INVENTORY:InvalidateSlotDataCache()
    end
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
        GAMEPAD_INVENTORY:RefreshItemList()
    end
    -- PB-002: Do NOT perform keybind/list restoration synchronously here. The
    -- gamepad action dialog wraps its lifetime in KEYBIND_STRIP:PushKeybindGroupState()
    -- (on show) / PopKeybindGroupState() (on hide). This handler runs while the
    -- dialog's pushed state is still the top state, so any RefreshItemActions /
    -- RefreshKeybinds / SetActiveKeybinds / EnsureHeaderKeybindsActive call here
    -- mutates the pushed (top) keybind state and corrupts the snapshot that Pop
    -- restores -- which silently drops the ethereal LB/RB carousel keybind group
    -- (BETTERUI_TabBarScrollList.keybindStripDescriptor) after the dialog closes.
    -- The deferred OnFinish -> RestoreInventoryAfterDialog path (which runs AFTER
    -- Pop) is the correct place for keybind/list restoration, so we rely on it.
end

local function ResolveCurrentTarget(self)
    local actionMode = self.actionMode
    if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        return self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
    elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        return self.craftBagList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
    elseif actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
        local catData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
        return catData and self:GenerateItemSlotData(catData)
    end
    return nil
end

local function CanDestroyTargetData(targetData)
    if not targetData then
        return false
    end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(targetData)
    if not bagId or not slotIndex then
        return false
    end

    local ds = targetData.dataSource or targetData
    local slotType = ds and ds.slotType or targetData.slotType
    if BETTERUI.Inventory and BETTERUI.Inventory.CanDestroyItemWithPolicy then
        return BETTERUI.Inventory.CanDestroyItemWithPolicy(bagId, slotIndex, slotType)
    end

    return RequireDestroyPolicyAuthorizer()(bagId, slotIndex, slotType) == true
end

function ActionHandlers.OnSetup(self, dialog, data)
    if not self.scene:IsShowing() then return end

    dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
        self.itemActions:SetSelectedAction(selectedData and selectedData.action)
    end)

    local parametricList = dialog.info.parametricList
    ZO_ClearNumericallyIndexedTable(parametricList)

    local target = ResolveCurrentTarget(self)

    if self.itemActions and self.itemActions.SetInventorySlot and target then
        if target and not target.slotType then
            target.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
        end
        self.itemActions:SetInventorySlot(target)
    end

    if self.itemActions and self.itemActions.slotActions and target then
        local innerSlotActions = self.itemActions.slotActions
        innerSlotActions:Clear()
        innerSlotActions:SetInventorySlot(target)
        if not target.slotType then target.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM end
        ZO_InventorySlot_DiscoverSlotActionsFromActionList(target, innerSlotActions)
    end

    self:RefreshItemActions()

    local titleText = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND"))
    local markAsJunkName = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
    local unmarkAsJunkName = GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK)
    local betterMarkAsJunkName = GetString(SI_BETTERUI_ACTION_MARK_AS_JUNK)
    local betterUnmarkAsJunkName = GetString(SI_BETTERUI_ACTION_UNMARK_AS_JUNK)
    local showJunkToggleEntry = false
    local junkToggleEntryText = nil
    local junkToggleEntryCallback = nil
    local headerData = { titleText = titleText }
    ZO_GamepadGenericHeader_RefreshData(dialog.header, headerData)

    local isLocked = target and target.bagId and target.slotIndex
        and BETTERUI.CIM.ProtectionPolicy.IsItemPlayerLocked(target.bagId, target.slotIndex)
        or false
    local canMarkJunk = target and CanJunkWithPolicy(target)

    local isQuestItem = false
    if target then
        if ZO_InventoryUtils_DoesNewItemMatchFilterType then
            isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)
        else
            isQuestItem = (target.questIndex ~= nil) or (target.toolIndex ~= nil)
        end
    end

    local canDestroyTarget = target and CanDestroyTargetData(target) or false

    if not isQuestItem then
        local isJunk = false
        if target and target.bagId and target.slotIndex and IsItemJunk then
            isJunk = IsItemJunk(target.bagId, target.slotIndex) == true
        end

        -- Capture the slot identity alongside the target so the deferred
        -- toggle can be cancelled if the slot changes while the dialog is up
        -- (mirrors destroy/equip).
        local expectedSlotIdentity = target and target.bagId and target.slotIndex
            and BETTERUI.Inventory.Utils.CaptureSlotIdentity(target.bagId, target.slotIndex, target)
            or nil

        if isJunk then
            showJunkToggleEntry = true
            junkToggleEntryText = betterUnmarkAsJunkName
            junkToggleEntryCallback = function() ToggleJunkState(self, false, target, expectedSlotIdentity) end
        elseif not isLocked and canMarkJunk then
            showJunkToggleEntry = true
            junkToggleEntryText = betterMarkAsJunkName
            junkToggleEntryCallback = function() ToggleJunkState(self, true, target, expectedSlotIdentity) end
        end
    end

    do
        local actions = self.itemActions:GetSlotActions()
        local numActions = actions:GetNumSlotActions()
        for i = 1, numActions do
            local action = actions:GetSlotAction(i)
            local actionName = actions:GetRawActionName(action)
            if actionName == GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_LOCKED"))
                or actionName == GetString(rawget(_G, "SI_ITEM_ACTION_UNMARK_AS_LOCKED")) then
                for j, slotAction in ipairs(actions.m_slotActions) do
                    if slotAction and slotAction[1] == actionName then
                        local origCallback = slotAction[2]
                        slotAction[2] = function(...)
                            if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                            end
                            if origCallback then origCallback(...) end
                        end
                        break
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

        local hideDestroy = BETTERUI.Utils.IsBankingSceneShowing() or (target and not canDestroyTarget)
        local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
        local hideMarkJunk = false
        do
            local t = (self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE)
                and (self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList))
                or nil
            if t and actionName == GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_JUNK")) then
                hideMarkJunk = not CanJunkWithPolicy(t)
            end
        end

        local isStowOrRetrieve = (actionName == GetString(rawget(_G, "SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG")))
            or (actionName == GetString(rawget(_G, "SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG")))
        local isConvertStyle = (actionName == GetString(rawget(_G, "SI_ITEM_ACTION_CONVERT_TO_IMPERIAL_STYLE")))
            or (actionName == GetString(rawget(_G, "SI_ITEM_ACTION_CONVERT_TO_MORAG_TONG_STYLE")))
        local isJunkToggleAction = actionName == markAsJunkName
            or actionName == unmarkAsJunkName
            or actionName == betterMarkAsJunkName
            or actionName == betterUnmarkAsJunkName

        if not (hideDestroy and isDestroy)
            and not hideMarkJunk
            and not isJunkToggleAction
            and not isStowOrRetrieve
            and not isConvertStyle then
            local entryData = ZO_GamepadEntryData:New(actionName)
            entryData:SetIconTintOnSelection(true)
            entryData.action = action
            entryData.setup = ZO_SharedGamepadEntry_OnSetup
            table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
        end
    end

    if showJunkToggleEntry and junkToggleEntryText and junkToggleEntryCallback then
        local junkToggleEntry = ZO_GamepadEntryData:New(junkToggleEntryText)
        junkToggleEntry:SetIconTintOnSelection(true)
        junkToggleEntry.isJunkToggleAction = true
        junkToggleEntry.junkToggleCallback = junkToggleEntryCallback
        junkToggleEntry.setup = ZO_SharedGamepadEntry_OnSetup
        table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = junkToggleEntry })
    end

    if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        local itemTarget = self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
        if itemTarget and itemTarget.bagId and itemTarget.slotIndex then
            local stackCount = GetSlotStackSize(itemTarget.bagId, itemTarget.slotIndex) or 1
            local canStow = BETTERUI.CIM.CanItemMoveToCraftBag(itemTarget)
            if canStow and stackCount > 1 then
                local e = ZO_GamepadEntryData:New(GetString(rawget(_G, "SI_BETTERUI_STOW_STACK")))
                e:SetIconTintOnSelection(true)
                e.isStowStackAction = true
                e.itemTarget = itemTarget
                e.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, 1, { template = "ZO_GamepadItemEntryTemplate", entryData = e })
            end
        end
    end

    if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        local craftBagTarget = self.craftBagList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
        if craftBagTarget and craftBagTarget.bagId and craftBagTarget.slotIndex then
            local stackCount = GetSlotStackSize(craftBagTarget.bagId, craftBagTarget.slotIndex) or 1
            if stackCount > 1 then
                local e = ZO_GamepadEntryData:New(GetString(rawget(_G, "SI_BETTERUI_RETRIEVE_STACK")))
                e:SetIconTintOnSelection(true)
                e.isRetrieveStackAction = true
                e.itemTarget = craftBagTarget
                e.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, 1, { template = "ZO_GamepadItemEntryTemplate", entryData = e })
            end
        end
    end

    local showSortEntry = false
    local currentList = nil
    local sortContext = nil
    if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        currentList = self.itemList
        sortContext = self
        showSortEntry = true
    elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        currentList = self.craftBagList
        sortContext = self
        showSortEntry = true
    elseif BETTERUI.Utils.IsBankingSceneShowing() then
        local getBankingSortContext = BETTERUI.Banking and BETTERUI.Banking.GetSortEntryContext or nil
        local bankingSortContext = type(getBankingSortContext) == "function" and getBankingSortContext() or nil
        if bankingSortContext then
            currentList = bankingSortContext.list
            sortContext = bankingSortContext.sortContext
            showSortEntry = true
        end
    end

    if showSortEntry and sortContext and sortContext.EnterHeaderSortMode
        and currentList and not currentList:IsEmpty() then
        local sortEntry = ZO_GamepadEntryData:New(GetString(rawget(_G, "SI_BETTERUI_HEADER_SORT")))
        sortEntry:SetIconTintOnSelection(true)
        sortEntry.isSortAction = true
        sortEntry.sortContext = sortContext
        sortEntry.setup = ZO_SharedGamepadEntry_OnSetup
        table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = sortEntry })
    end

    local getHelpName = GetString(rawget(_G, "SI_ITEM_ACTION_REPORT_ITEM"))
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

function ActionHandlers.OnFinish(self)
    local function RestoreInventoryAfterDialog()
        if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
            return false
        end

        local sceneShowing = (self.scene and self.scene:IsShowing())
            or (BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.IsInventorySceneShowing and
                BETTERUI.CIM.Utils.IsInventorySceneShowing())
        if not sceneShowing then
            return false
        end

        if self.isInCraftBagSelectionMode and self.RefreshCraftBagList then
            self:RefreshCraftBagList()
        elseif self.isInSelectionMode and self.RefreshItemList then
            self:RefreshItemList()
        end

        if not self.isInHeaderSortMode then
            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
        end

        if self.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
            local currentList = self:GetCurrentList()
            if currentList then
                local targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(currentList)
                if currentList == self.categoryList then
                    targetData = self:GenerateItemSlotData(targetData)
                end
                self:SetSelectedItemUniqueId(targetData)
            end
            self:RefreshCategoryList()
        else
            self:RefreshItemActions()
        end

        if not self.isInHeaderSortMode then
            self:RefreshKeybinds()
        end

        -- Dialogs deactivate the header tab bar; reactivate it so LB/RB keep
        -- paging the category carousel after any action-dialog flow.
        if self.EnsureHeaderKeybindsActive and not self.isInHeaderSortMode then
            self:EnsureHeaderKeybindsActive()
        end
        return true
    end

    if RestoreInventoryAfterDialog() then
        return
    end

    local retriesRemaining = 120
    local retryTaskName = "actionDialogFinishRestore_" .. tostring((GetGameTimeMilliseconds and GetGameTimeMilliseconds()) or
        0)
    local function RetryRestore()
        if RestoreInventoryAfterDialog() then
            return
        end
        retriesRemaining = retriesRemaining - 1
        if retriesRemaining <= 0 then
            return
        end
        if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Schedule then
            BETTERUI.Inventory.Tasks:Schedule(retryTaskName, 50, RetryRestore)
        else
            zo_callLater(RetryRestore, 50)
        end
    end

    RetryRestore()
end

function ActionHandlers.OnConfirm(self, dialog)
    if not (self.scene and self.scene:IsShowing()) then return end

    local currentList = self:GetCurrentList()
    if currentList and currentList.selectedIndex then
        local targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(currentList)
        if targetData then
            targetData.savedIndex = currentList.selectedIndex
            self.currentlySelectedData = targetData
        end
    end

    local selectedRow = dialog.entryList and BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)

    if selectedRow and selectedRow.isSortAction then
        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        local sortContext = selectedRow.sortContext or self
        if sortContext and sortContext.EnterHeaderSortMode then
            -- Defer until the action dialog has fully released its keybind state. Calling
            -- EnterHeaderSortMode synchronously here applies the header-sort keybind swap to the
            -- dialog's (about-to-pop) keybind state, so the sort keybinds are discarded when the
            -- dialog closes and the strip falls back to the inventory keybinds.
            local attempts = 60
            local function EnterSortWhenDialogClosed()
                attempts = attempts - 1
                if attempts > 0 and ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
                    if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Schedule then
                        BETTERUI.Inventory.Tasks:Schedule("enterHeaderSortAfterDialog", 10, EnterSortWhenDialogClosed)
                    elseif zo_callLater then
                        zo_callLater(EnterSortWhenDialogClosed, 10)
                    end
                    return
                end
                sortContext:EnterHeaderSortMode()
            end
            EnterSortWhenDialogClosed()
        end
        return
    end

    if selectedRow and selectedRow.isStowStackAction then
        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        local itemTarget = selectedRow.itemTarget
        if itemTarget then
            BETTERUI.Inventory.InvokeDialog("StowFullStack", itemTarget)
        end
        return
    end

    if selectedRow and selectedRow.isRetrieveStackAction then
        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        local itemTarget = selectedRow.itemTarget
        if itemTarget then
            BETTERUI.Inventory.InvokeDialog("RetrieveFullStack", itemTarget)
        end
        return
    end

    if selectedRow and selectedRow.isJunkToggleAction then
        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        if selectedRow.junkToggleCallback then
            selectedRow.junkToggleCallback()
        end
        return
    end

    if selectedRow and selectedRow.isBetterUIDestroy then
        local targetData
        if dialog and dialog.data and dialog.data.target then
            targetData = dialog.data.target
        elseif dialog.entryList and dialog.entryList.GetTargetData then
            targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
        else
            targetData = ResolveCurrentTarget(self)
        end
        local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
        if bag and slot then
            if not CanDestroyTargetData(targetData) then
                return
            end
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local ds = targetData.dataSource or targetData
            local slotType = ds and ds.slotType or targetData.slotType
            local link = GetItemLink(bag, slot)
            local quick = BETTERUI.GetSetting("Inventory", "quickDestroy", false) == true
            if quick then
                BETTERUI.Inventory.TryDestroyItem(bag, slot, true, false, slotType)
            else
                local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bag, slot, targetData)
                ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
                    {
                        bagId = bag,
                        slotIndex = slot,
                        slotType = slotType,
                        itemLink = link,
                        expectedSlotIdentity = expectedSlotIdentity,
                    }, nil, true, true)
            end
        end
        return
    end

    local selectedActionName = selectedRow and selectedRow.text or nil

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_SPLIT_STACK")) then
        local targetData = ResolveCurrentTarget(self)
        if targetData and ZO_InventorySlot_TrySplitStack then
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            ZO_InventorySlot_TrySplitStack(targetData)
        end
        return
    end

    if selectedActionName == GetString(SI_ITEM_ACTION_DESTROY) then
        local targetData = ResolveCurrentTarget(self)
        local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
        if bag and slot then
            if not CanDestroyTargetData(targetData) then
                return
            end
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local ds = targetData.dataSource or targetData
            local slotType = ds and ds.slotType or targetData.slotType
            local link = GetItemLink(bag, slot)
            local quick = BETTERUI.GetSetting("Inventory", "quickDestroy", false) == true
            if quick then
                BETTERUI.Inventory.TryDestroyItem(bag, slot, true, false, slotType)
            else
                local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bag, slot, targetData)
                ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
                    {
                        bagId = bag,
                        slotIndex = slot,
                        slotType = slotType,
                        itemLink = link,
                        expectedSlotIdentity = expectedSlotIdentity,
                    }, nil, true, true)
            end
        end
        return
    end

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")) then
        local isCompanionScene = SCENE_MANAGER and SCENE_MANAGER.scenes
            and SCENE_MANAGER.scenes["companionEquipmentGamepad"]
            and SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
        if isCompanionScene then return end
        local targetData = ResolveCurrentTarget(self)
        local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
        if bag and slot then
            local itemLink = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
            if itemLink and itemLink ~= "" then
                ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink))
            end
        end
        return
    end

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_EQUIP")) then
        local targetData = ResolveCurrentTarget(self)
        if targetData and targetData.dataSource then
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            self:TryEquipItem(targetData, true)
        end
        return
    end

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
        or selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_SHOW_MAP"))
        or selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_SKILL_RESPEC"))
        or selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC")) then
        local targetData = ResolveCurrentTarget(self)
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
                    if not CallSecureProtected("UseItem", bag, slot) then
                        local failedStringId = rawget(_G, "SI_BETTERUI_SECURE_ACTION_FAILED")
                        BETTERUI.CIM.UserNotify("ItemActionHandlers:UseItem",
                            (failedStringId and GetString(failedStringId))
                            or "The action could not be completed.")
                    end
                end
            end
        end
        return
    end

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_PLACE_FURNITURE")) then
        local targetData = ResolveCurrentTarget(self)
        if targetData then
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local ds = targetData.dataSource or targetData
            local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
            if bag and slot and ZO_CanPlaceItemInCurrentHouse(bag, slot) then
                ZO_TryPlaceFurnitureFromInventorySlot(bag, slot)
            end
        end
        return
    end

    if selectedRow and selectedRow.action then
        local slotActions = self.itemActions and self.itemActions:GetSlotActions()
        if slotActions then
            slotActions:DoAction(selectedRow.action)
        end
    end
end
