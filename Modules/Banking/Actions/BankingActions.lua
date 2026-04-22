local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

---@return nil
function BETTERUI.Banking.Class:RefreshItemActions()
    if self.isInHeaderSortMode then
        return
    end
    local targetData = self:GetList().selectedData
    self.itemActions:SetInventorySlot(targetData)
end

function BETTERUI.Banking.Class:IsFurnitureVaultContext()
    return BETTERUI.Banking.GetTransferState().sourceIsFurnitureVault == true
end

function BETTERUI.Banking.Class:RequestJunkCategoryRefresh(delayMs, preferredCategoryKey)
    local requestedCategoryKey = preferredCategoryKey
    if not requestedCategoryKey then
        if self.GetCurrentCategoryKey then
            requestedCategoryKey = self:GetCurrentCategoryKey()
        elseif self.bankCategories and self.currentCategoryIndex then
            local currentCategory = self.bankCategories[self.currentCategoryIndex]
            requestedCategoryKey = currentCategory and currentCategory.key or nil
        end
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
        if self.RefreshCategoryView then
            self:RefreshCategoryView({
                preferredCategoryKey = requestedCategoryKey,
                refreshKeybinds = true,
            })
            return
        end

        self:RefreshList()
        self:RefreshActiveKeybinds()
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

    local function GetCurrentCategoryKey()
        local category = self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1] or nil
        return category and category.key or nil
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

    local function ToggleBankingItemJunk(targetData, shouldMarkAsJunk)
        if not targetData or not targetData.bagId or not targetData.slotIndex then
            return false
        end
        if self:IsFurnitureVaultContext() then
            return false
        end

        local isCurrentlyJunk = IsItemJunk and IsItemJunk(targetData.bagId, targetData.slotIndex)
        if shouldMarkAsJunk == true then
            if isCurrentlyJunk or not CanJunkWithPolicy(targetData.bagId, targetData.slotIndex) then
                return false
            end
        elseif not isCurrentlyJunk or not CanUnjunkWithPolicy(targetData.bagId, targetData.slotIndex) then
            return false
        end

        SetItemIsJunk(targetData.bagId, targetData.slotIndex, shouldMarkAsJunk)
        self:RequestJunkCategoryRefresh(140, GetCurrentCategoryKey())
        return true
    end

    local function ActionDialogSetup(dialog)
        if BETTERUI.Utils.IsBankingSceneShowing() then
            dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
                self.itemActions:SetSelectedAction(selectedData and selectedData.action)
            end)

            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            local targetData = self:GetList() and self:GetList().selectedData or nil
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

            local isSourceFurnitureVault = BETTERUI.Banking.GetTransferState().sourceIsFurnitureVault == true
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
    end

    local function ActionDialogFinish()
        if BETTERUI.Utils.IsBankingSceneShowing() then
            if not self.isInHeaderSortMode then
                self:AddKeybinds()
            end
            self:RefreshItemActions()
        end
    end

    local function ActionDialogButtonConfirm(dialog)
        if BETTERUI.Utils.IsBankingSceneShowing() then
            local selectedEntry = dialog.entryList and dialog.entryList:GetTargetData()
            if selectedEntry and selectedEntry.isBetterUIStowAllFurniture then
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                self:SaveListPosition()
                if type(StowAllFurnitureItems) == "function" then
                    StowAllFurnitureItems()
                end
                return
            end

            if selectedEntry and selectedEntry.isBetterUIBankJunkToggle then
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                ToggleBankingItemJunk(selectedEntry.targetData, selectedEntry.markAsJunk == true)
                return
            end

            if selectedEntry and selectedEntry.isBetterUIStackTransfer then
                local stackCount = selectedEntry.stackCount or 1
                self:SaveListPosition()
                self:MoveItem(self.list, stackCount)
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                return
            end

            if selectedEntry and selectedEntry.isSortAction then
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                local sortContext = selectedEntry.sortContext or self
                if sortContext and sortContext.EnterHeaderSortMode then
                    sortContext:EnterHeaderSortMode()
                end
                return
            end

            local selectedAction = self.itemActions and self.itemActions.selectedAction or nil
            if not selectedAction then return end
            local selectedName = ZO_InventorySlotActions:GetRawActionName(selectedAction)
            if selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")) then
                BETTERUI.CIM.HandleLinkToChat(self:GetList().selectedData)
            elseif selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_BANK_WITHDRAW")) or
                selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_BANK_DEPOSIT")) then
                local selectedData = self.list and self.list:GetSelectedData()
                if selectedData then
                    local stackCount = selectedData.stackCount or 1
                    if stackCount > 1 then
                        local isDeposit = (selectedName == GetString(rawget(_G, "SI_ITEM_ACTION_BANK_DEPOSIT")))
                        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                        self:SaveListPosition()
                        self:ShowQuantityDialog(isDeposit)
                    else
                        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                        self:SaveListPosition()
                        self:MoveItem(self.list, 1)
                    end
                end
            else
                self.itemActions:DoSelectedAction()
            end
        end
    end

    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", ActionDialogSetup)
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", ActionDialogFinish)
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", ActionDialogButtonConfirm)
end
