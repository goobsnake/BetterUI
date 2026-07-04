local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

---@return nil
function BETTERUI.Banking.Class:RefreshItemActions()
    if self.isInHeaderSortMode then
        return
    end
    local list = self:GetList()
    if not list or not self.itemActions then return end
    local targetData = list.selectedData
    self.itemActions:SetInventorySlot(targetData)
end

function BETTERUI.Banking.Class:IsFurnitureVaultContext()
    return BETTERUI.Banking.ReadTransferContextSnapshot().sourceIsFurnitureVault == true
end

function BETTERUI.Banking.Class:RequestJunkCategoryRefresh(delayMs, preferredCategoryKey)
    local requestedCategoryKey = preferredCategoryKey
    if not requestedCategoryKey then
        requestedCategoryKey = BETTERUI.Banking.ResolveWindowCategoryKey(self)
    end

    BETTERUI.Banking.Tasks:Schedule("junkCategoryRefresh", delayMs or 140, function()
        if not BETTERUI.Utils.IsBankingSceneShowing() then
            return
        end

        if self:IsBatchProcessing() then
            self:RequestJunkCategoryRefresh(120, requestedCategoryKey)
            return
        end

        self.isDirty = true
        BETTERUI.Banking.RefreshWindowView(self, {
            preferredCategoryKey = requestedCategoryKey,
            refreshKeybinds = true,
        })
    end)
end

---@param self BETTERUI.Banking.Class
---@param targetData table?
local function EnsureTargetSlotType(self, targetData)
    if not targetData or targetData.slotType then
        return
    end

    if self.currentMode == LIST_WITHDRAW then
        targetData.slotType = SLOT_TYPE_BANK_ITEM
    else
        targetData.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
    end
end

---@param self BETTERUI.Banking.Class
---@param targetData table?
local function RebuildDiscoveredActions(self, targetData)
    if not targetData then
        return
    end

    EnsureTargetSlotType(self, targetData)

    self.itemActions:SetInventorySlot(targetData)

    if self.itemActions.slotActions then
        local innerSlotActions = self.itemActions.slotActions
        innerSlotActions:Clear()
        innerSlotActions:SetInventorySlot(targetData)
        ZO_InventorySlot_DiscoverSlotActionsFromActionList(targetData, innerSlotActions)
    end

    self:RefreshItemActions()
end

---@param self BETTERUI.Banking.Class
---@param parametricList table
local function PopulateFilteredActions(self, parametricList)
    local actions = self.itemActions:GetSlotActions()
    local hideDestroyInDeposit = self.currentMode == LIST_DEPOSIT
    local markAsJunkName = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
    local unmarkAsJunkName = GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK)
    BETTERUI.CIM.PopulateActionEntries(parametricList, actions, {
        hideDestroy = hideDestroyInDeposit,
        filterCallback = function(actionName)
            if actionName == markAsJunkName or actionName == unmarkAsJunkName then
                return false
            end
            return true
        end,
    })
end

---@return nil
function BETTERUI.Banking.Class:InitializeActionsDialog()
    local function GetProtectionPolicy()
        local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
        assert(type(policy) == "table", "BetterUI: CIM.ProtectionPolicy must load before banking junk-policy checks")
        return policy
    end

    local function RequireProtectionPolicyMethod(methodName)
        local policy = GetProtectionPolicy()
        local method = policy and policy[methodName] or nil
        assert(type(method) == "function",
            string.format("BetterUI: CIM.ProtectionPolicy.%s must load before banking junk-policy checks", tostring(methodName)))
        return method
    end

    local function CanJunkWithPolicy(bagId, slotIndex)
        return RequireProtectionPolicyMethod("CanJunkItem")(bagId, slotIndex) == true
    end

    local function CanUnjunkWithPolicy(bagId, slotIndex)
        return RequireProtectionPolicyMethod("CanUnjunkItem")(bagId, slotIndex) == true
    end

    local function CanShowBankingJunkActions(targetData)
        if not targetData or not targetData.bagId or not targetData.slotIndex then
            return false
        end
        if self:IsFurnitureVaultContext() then
            return false
        end
        local isJunk = IsItemJunk and IsItemJunk(targetData.bagId, targetData.slotIndex) == true
        if isJunk then
            return CanUnjunkWithPolicy(targetData.bagId, targetData.slotIndex)
        end
        return CanJunkWithPolicy(targetData.bagId, targetData.slotIndex)
    end

    local function UnregisterDialogSelectionCallback(dialog)
        local entryList = dialog and dialog.entryList or nil
        local callback = dialog and dialog._betteruiBankingActionSelectionCallback or nil
        if not callback then
            return true
        end
        if not (entryList and entryList.RemoveOnSelectedDataChangedCallback) then
            return false
        end
        entryList:RemoveOnSelectedDataChangedCallback(callback)
        dialog._betteruiBankingActionSelectionCallback = nil
        return true
    end

    local function RegisterDialogSelectionCallback(dialog)
        local entryList = dialog and dialog.entryList or nil
        if not (entryList and entryList.SetOnSelectedDataChangedCallback) then
            return
        end
        if not UnregisterDialogSelectionCallback(dialog) then
            return
        end
        local callback = function(list, selectedData)
            self.itemActions:SetSelectedAction(selectedData and selectedData.action)
        end
        dialog._betteruiBankingActionSelectionCallback = callback
        entryList:SetOnSelectedDataChangedCallback(callback)
    end

    local function TraceBankingActionDialog(event, phase, data)
        local L = BETTERUI.Log
        if not (L and L.TraceEvent) then return end
        L.TraceEvent(L.CATEGORY.ACTION, event, phase, data)
    end

    local function DescribeBankTarget(targetData)
        local L = BETTERUI.Log
        if L and L.DescribeItem and targetData then
            return L.DescribeItem(targetData, "target")
        end
        return nil
    end

    local function ToggleBankingItemJunk(targetData, shouldMarkAsJunk)
        if not targetData or not targetData.bagId or not targetData.slotIndex then
            TraceBankingActionDialog("bank.junk_toggle", "blocked", {
                reason = "missingTarget",
                requestedJunk = shouldMarkAsJunk == true,
            })
            return false
        end
        if self:IsFurnitureVaultContext() then
            TraceBankingActionDialog("bank.junk_toggle", "blocked", {
                reason = "furnitureVault",
                requestedJunk = shouldMarkAsJunk == true,
                target = DescribeBankTarget(targetData),
            })
            return false
        end

        local isCurrentlyJunk = IsItemJunk and IsItemJunk(targetData.bagId, targetData.slotIndex)
        if shouldMarkAsJunk == true then
            if isCurrentlyJunk or not CanJunkWithPolicy(targetData.bagId, targetData.slotIndex) then
                TraceBankingActionDialog("bank.junk_toggle", "blocked", {
                    reason = isCurrentlyJunk and "alreadyJunk" or "protectionPolicy",
                    requestedJunk = true,
                    target = DescribeBankTarget(targetData),
                })
                return false
            end
        elseif not isCurrentlyJunk or not CanUnjunkWithPolicy(targetData.bagId, targetData.slotIndex) then
            TraceBankingActionDialog("bank.junk_toggle", "blocked", {
                reason = not isCurrentlyJunk and "notJunk" or "protectionPolicy",
                requestedJunk = false,
                target = DescribeBankTarget(targetData),
            })
            return false
        end

        TraceBankingActionDialog("bank.junk_toggle", "before", {
            requestedJunk = shouldMarkAsJunk == true,
            wasJunk = isCurrentlyJunk == true,
            categoryKey = BETTERUI.Banking.ResolveWindowCategoryKey(self),
            target = DescribeBankTarget(targetData),
        })
        SetItemIsJunk(targetData.bagId, targetData.slotIndex, shouldMarkAsJunk)
        self:RequestJunkCategoryRefresh(140, BETTERUI.Banking.ResolveWindowCategoryKey(self))
        TraceBankingActionDialog("bank.junk_toggle", "after", {
            requestedJunk = shouldMarkAsJunk == true,
            refreshScheduled = true,
            categoryKey = BETTERUI.Banking.ResolveWindowCategoryKey(self),
            target = DescribeBankTarget(targetData),
        })
        return true
    end

    local function ActionDialogSetup(dialog)
        if BETTERUI.Utils.IsBankingSceneShowing() then
            RegisterDialogSelectionCallback(dialog)

            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            local targetData = self:GetList() and self:GetList().selectedData or nil
            TraceBankingActionDialog("bank.action_dialog", "begin", {
                mode = self.currentMode,
                target = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(targetData, "target") or nil,
                selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(self.list, "selection") or nil,
            })
            RebuildDiscoveredActions(self, targetData)
            PopulateFilteredActions(self, parametricList)

            if targetData and targetData.stackCount and targetData.stackCount > 1 then
                local actionName = (self.currentMode == LIST_WITHDRAW)
                    and GetString(rawget(_G, "SI_BETTERUI_BANK_WITHDRAW_MAX"))
                    or GetString(rawget(_G, "SI_BETTERUI_BANK_DEPOSIT_MAX"))
                local stackCount = targetData.stackCount

                local entryData = ZO_GamepadEntryData:New(actionName)
                entryData:SetIconTintOnSelection(true)
                entryData.setup = ZO_SharedGamepadEntry_OnSetup
                entryData.isBetterUIStackTransfer = true
                entryData.stackCount = stackCount

                local moveMaxAction = {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = entryData,
                }
                table.insert(parametricList, 1, moveMaxAction)
            end

            local isSourceFurnitureVault = BETTERUI.Banking.ReadTransferContextSnapshot().sourceIsFurnitureVault == true
            local canShowStowAllFurniture = (self.currentMode == LIST_DEPOSIT)
                and isSourceFurnitureVault
                and HOUSING_EDITOR_STATE
                and HOUSING_EDITOR_STATE.CanDepositIntoFurnitureVault
                and HOUSING_EDITOR_STATE:CanDepositIntoFurnitureVault()
                and (type(StowAllFurnitureItems) == "function")
            if canShowStowAllFurniture then
                local stowAllEntry = ZO_GamepadEntryData:New(GetString(SI_ITEM_ACTION_STOW_ALL_FURNITURE))
                stowAllEntry:SetIconTintOnSelection(true)
                stowAllEntry.isBetterUIStowAllFurniture = true
                stowAllEntry.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, 1, {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = stowAllEntry,
                })
            end

            if CanShowBankingJunkActions(targetData) then
                local isJunk = IsItemJunk and IsItemJunk(targetData.bagId, targetData.slotIndex)
                local canMarkAsJunk = CanJunkWithPolicy(targetData.bagId, targetData.slotIndex)
                local junkActionName = nil
                local markAsJunk = false
                if isJunk then
                    junkActionName = GetString(SI_BETTERUI_ACTION_UNMARK_AS_JUNK)
                    markAsJunk = false
                elseif canMarkAsJunk then
                    junkActionName = GetString(SI_BETTERUI_ACTION_MARK_AS_JUNK)
                    markAsJunk = true
                end

                if junkActionName then
                    local junkEntry = ZO_GamepadEntryData:New(junkActionName)
                    junkEntry:SetIconTintOnSelection(true)
                    junkEntry.isBetterUIBankJunkToggle = true
                    junkEntry.markAsJunk = markAsJunk
                    junkEntry.targetData = targetData
                    junkEntry.setup = ZO_SharedGamepadEntry_OnSetup
                    table.insert(parametricList, {
                        template = "ZO_GamepadItemEntryTemplate",
                        entryData = junkEntry,
                    })
                end
            end

            if self.list and not self.list:IsEmpty() and self.EnterHeaderSortMode then
                local sortEntry = ZO_GamepadEntryData:New(GetString(rawget(_G, "SI_BETTERUI_HEADER_SORT")))
                sortEntry:SetIconTintOnSelection(true)
                sortEntry.isSortAction = true
                sortEntry.sortContext = self
                sortEntry.setup = ZO_SharedGamepadEntry_OnSetup

                local listItem = {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = sortEntry,
                }
                table.insert(parametricList, listItem)
                if BETTERUI.Log then
                    BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "bank dialog sort entry added", {
                        fn = "Banking.ActionDialogSetup",
                        mode = self.currentMode,
                        headerSort = self.isInHeaderSortMode == true,
                        listItems = self.list.GetNumItems and self.list:GetNumItems() or nil,
                        main = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or nil,
                    })
                end
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
            TraceBankingActionDialog("bank.action_dialog", "end", {
                mode = self.currentMode,
                entryCount = #parametricList,
                selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
            })
        end
    end

    local function ActionDialogFinish(dialog)
        UnregisterDialogSelectionCallback(dialog)
        local closeCause = dialog and dialog._betteruiCloseCause or "dismissed"
        if BETTERUI.Utils.IsBankingSceneShowing() then
            local pendingHeaderSort = self._pendingHeaderSortFromDialog == true
            if BETTERUI.Log then
                BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "bank dialog finish restore", {
                    fn = "Banking.ActionDialogFinish",
                    closeCause = closeCause,
                    headerSort = self.isInHeaderSortMode == true,
                    pendingHeaderSort = pendingHeaderSort,
                    main = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or nil,
                })
            end
            TraceBankingActionDialog("bank.action_dialog.finish", "begin", {
                mode = self.currentMode,
                closeCause = closeCause,
                headerSort = self.isInHeaderSortMode == true,
                pendingHeaderSort = pendingHeaderSort,
                main = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or nil,
            })
            if not self.isInHeaderSortMode and not pendingHeaderSort then
                self:AddKeybinds()
            end
            if not pendingHeaderSort then
                self:RefreshItemActions()
            end
            TraceBankingActionDialog("bank.action_dialog.finish", "end", {
                mode = self.currentMode,
                closeCause = closeCause,
                headerSort = self.isInHeaderSortMode == true,
                pendingHeaderSort = pendingHeaderSort,
                skippedKeybindRestore = pendingHeaderSort,
                main = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or nil,
            })
        end
    end

    local function ActionDialogButtonConfirm(dialog)
        if BETTERUI.Utils.IsBankingSceneShowing() then
            local selectedEntry = dialog.entryList and dialog.entryList:GetTargetData()
            TraceBankingActionDialog("bank.action_dialog", "confirm", {
                mode = self.currentMode,
                selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
                isSort = selectedEntry and selectedEntry.isSortAction == true,
                isStackTransfer = selectedEntry and selectedEntry.isBetterUIStackTransfer == true,
                isJunkToggle = selectedEntry and selectedEntry.isBetterUIBankJunkToggle == true,
                isStowAllFurniture = selectedEntry and selectedEntry.isBetterUIStowAllFurniture == true,
            })
            if selectedEntry and selectedEntry.isBetterUIStowAllFurniture then
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "before", {
                    branch = "stow_all_furniture",
                    mode = self.currentMode,
                })
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                self:SaveListPosition()
                local invoked = false
                if type(StowAllFurnitureItems) == "function" then
                    StowAllFurnitureItems()
                    invoked = true
                end
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "after", {
                    branch = "stow_all_furniture",
                    mode = self.currentMode,
                    releaseRequested = true,
                    invoked = invoked,
                    savedListPosition = true,
                })
                return
            end

            if selectedEntry and selectedEntry.isBetterUIBankJunkToggle then
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "before", {
                    branch = "junk_toggle",
                    mode = self.currentMode,
                    markAsJunk = selectedEntry.markAsJunk == true,
                    target = DescribeBankTarget(selectedEntry.targetData),
                })
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                local toggled = ToggleBankingItemJunk(selectedEntry.targetData, selectedEntry.markAsJunk == true)
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "after", {
                    branch = "junk_toggle",
                    mode = self.currentMode,
                    markAsJunk = selectedEntry.markAsJunk == true,
                    releaseRequested = true,
                    result = toggled == true,
                    target = DescribeBankTarget(selectedEntry.targetData),
                })
                return
            end

            if selectedEntry and selectedEntry.isBetterUIStackTransfer then
                local stackCount = selectedEntry.stackCount or 1
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "before", {
                    branch = "stack_transfer",
                    mode = self.currentMode,
                    stackCount = stackCount,
                    selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(self.list, "selection") or nil,
                })
                self:SaveListPosition()
                self:MoveItem(self.list, stackCount)
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "after", {
                    branch = "stack_transfer",
                    mode = self.currentMode,
                    stackCount = stackCount,
                    releaseRequested = true,
                    moveRequested = true,
                    savedListPosition = true,
                })
                return
            end

            if selectedEntry and selectedEntry.isSortAction then
                local sortContext = selectedEntry.sortContext or self
                self._pendingHeaderSortFromDialog = true
                if sortContext then
                    sortContext._pendingHeaderSortFromDialog = true
                end
                TraceBankingActionDialog("bank.action_dialog.sort", "release_dialog", {
                    mode = self.currentMode,
                    pendingHeaderSort = true,
                    selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
                })
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                if BETTERUI.Log then
                    BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "bank dialog sort confirmed", {
                        fn = "Banking.ActionDialogButtonConfirm",
                        mode = self.currentMode,
                        headerSort = sortContext and sortContext.isInHeaderSortMode == true,
                        main = BETTERUI.Log.DescribeKeybindDescriptor and sortContext and BETTERUI.Log.DescribeKeybindDescriptor(sortContext.mainKeybindStripDescriptor, "main") or nil,
                    })
                end
                if sortContext and sortContext.EnterHeaderSortMode then
                    local attempts = 60
                    local function EnterSortWhenDialogClosed()
                        attempts = attempts - 1
                        if attempts > 0 and ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
                            TraceBankingActionDialog("bank.action_dialog.sort", "waiting_for_close", {
                                attempts = attempts,
                                headerSort = sortContext and sortContext.isInHeaderSortMode == true,
                                pendingHeaderSort = sortContext and sortContext._pendingHeaderSortFromDialog == true,
                                main = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptor and sortContext and BETTERUI.Log.DescribeKeybindDescriptor(sortContext.mainKeybindStripDescriptor, "main") or nil,
                            })
                            if BETTERUI.Banking.Tasks and BETTERUI.Banking.Tasks.Schedule then
                                BETTERUI.Banking.Tasks:Schedule("enterHeaderSortAfterDialog", 10, EnterSortWhenDialogClosed)
                                return
                            elseif type(zo_callLater) == "function" then
                                zo_callLater(EnterSortWhenDialogClosed, 10)
                                return
                            end
                            if sortContext then
                                sortContext._pendingHeaderSortFromDialog = nil
                            end
                            if sortContext ~= self then
                                self._pendingHeaderSortFromDialog = nil
                            end
                            TraceBankingActionDialog("bank.action_dialog.sort", "enter_skipped", {
                                reason = "missingScheduler",
                                attemptsRemaining = attempts,
                                headerSort = sortContext and sortContext.isInHeaderSortMode == true,
                                pendingHeaderSort = false,
                            })
                            return
                        end
                        local entered = sortContext:EnterHeaderSortMode()
                        if sortContext then
                            sortContext._pendingHeaderSortFromDialog = nil
                        end
                        if sortContext ~= self then
                            self._pendingHeaderSortFromDialog = nil
                        end
                        TraceBankingActionDialog("bank.action_dialog.sort", "enter_attempted", {
                            entered = entered == true,
                            attemptsRemaining = attempts,
                            headerSort = sortContext and sortContext.isInHeaderSortMode == true,
                            pendingHeaderSort = false,
                            main = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptor and sortContext and BETTERUI.Log.DescribeKeybindDescriptor(sortContext.mainKeybindStripDescriptor, "main") or nil,
                        })
                    end
                    EnterSortWhenDialogClosed()
                else
                    if sortContext then
                        sortContext._pendingHeaderSortFromDialog = nil
                    end
                    if sortContext ~= self then
                        self._pendingHeaderSortFromDialog = nil
                    end
                    TraceBankingActionDialog("bank.action_dialog.sort", "enter_skipped", {
                        reason = "missingSortContext",
                        pendingHeaderSort = false,
                    })
                end
                return
            end

            local selectedAction = self.itemActions and self.itemActions.selectedAction or nil
            if not selectedAction then
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "blocked", {
                    branch = "native_slot_action",
                    mode = self.currentMode,
                    reason = "missingSelectedAction",
                })
                return
            end
            local selectedName = ZO_InventorySlotActions:GetRawActionName(selectedAction)
            if selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")) then
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "before", {
                    branch = "link_to_chat",
                    mode = self.currentMode,
                    selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(self.list, "selection") or nil,
                })
                BETTERUI.CIM.HandleLinkToChat(self:GetList().selectedData)
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "after", {
                    branch = "link_to_chat",
                    mode = self.currentMode,
                    invoked = true,
                })
            elseif selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_BANK_WITHDRAW")) or
                selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_BANK_DEPOSIT")) then
                local selectedData = self.list and self.list:GetSelectedData()
                if selectedData then
                    local stackCount = selectedData.stackCount or 1
                    local guildBank = BETTERUI.Banking.GuildBank
                    local isGuildBankMode = guildBank and guildBank.IsGuildBankMode() or false
                    local branch = selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_BANK_WITHDRAW")) and "withdraw" or "deposit"
                    TraceBankingActionDialog("bank.action_dialog.confirm_branch", "before", {
                        branch = branch,
                        mode = self.currentMode,
                        stackCount = stackCount,
                        guild = isGuildBankMode,
                        target = DescribeBankTarget(selectedData),
                    })
                    if stackCount > 1 and not isGuildBankMode then
                        local isDeposit = (selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_BANK_DEPOSIT")))
                        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                        self:SaveListPosition()
                        self:ShowQuantityDialog(isDeposit)
                        TraceBankingActionDialog("bank.action_dialog.confirm_branch", "after", {
                            branch = branch,
                            mode = self.currentMode,
                            stackCount = stackCount,
                            guild = isGuildBankMode,
                            releaseRequested = true,
                            quantityDialog = true,
                            savedListPosition = true,
                            target = DescribeBankTarget(selectedData),
                        })
                    else
                        -- Guild bank transfer APIs always move the whole stack,
                        -- so the quantity dialog is skipped in guild-bank mode.
                        self:SaveListPosition()
                        self:MoveItem(self.list, stackCount)
                        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                        TraceBankingActionDialog("bank.action_dialog.confirm_branch", "after", {
                            branch = branch,
                            mode = self.currentMode,
                            stackCount = stackCount,
                            guild = isGuildBankMode,
                            releaseRequested = true,
                            moveRequested = true,
                            savedListPosition = true,
                            target = DescribeBankTarget(selectedData),
                        })
                    end
                else
                    TraceBankingActionDialog("bank.action_dialog.confirm_branch", "blocked", {
                        branch = selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_BANK_WITHDRAW")) and "withdraw" or "deposit",
                        mode = self.currentMode,
                        reason = "missingSelectedData",
                    })
                end
            else
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "before", {
                    branch = "native_slot_action",
                    mode = self.currentMode,
                    action = selectedName,
                })
                self.itemActions:DoSelectedAction()
                TraceBankingActionDialog("bank.action_dialog.confirm_branch", "after", {
                    branch = "native_slot_action",
                    mode = self.currentMode,
                    action = selectedName,
                    invoked = true,
                })
            end
        end
    end

    if not (CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback) then
        return
    end

    local previousCallbacks = self._betteruiBankingActionDialogCallbacks
    if previousCallbacks then
        if not CALLBACK_MANAGER.UnregisterCallback then
            return
        end
        CALLBACK_MANAGER:UnregisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", previousCallbacks.setup)
        CALLBACK_MANAGER:UnregisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", previousCallbacks.finish)
        CALLBACK_MANAGER:UnregisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", previousCallbacks.confirm)
    end

    self._betteruiBankingActionDialogCallbacks = {
        setup = ActionDialogSetup,
        finish = ActionDialogFinish,
        confirm = ActionDialogButtonConfirm,
    }
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", ActionDialogSetup)
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", ActionDialogFinish)
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", ActionDialogButtonConfirm)
end
