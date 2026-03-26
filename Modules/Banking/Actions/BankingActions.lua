--[[
File: Modules/Banking/Actions/BankingActions.lua
Purpose: Actions dialog setup for the banking interface (Y-button menu).
Extracted from Banking.lua for maintainability.
]]

local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

--[[
Function: BETTERUI.Banking.Class:RefreshItemActions
Description: Updates the context menu actions for the currently selected item.
]]
--- Updates the context menu actions for the currently selected item.
--- @return nil
function BETTERUI.Banking.Class:RefreshItemActions()
    -- Skip itemActions updates when in header sort mode to prevent keybind flicker
    if self.isInHeaderSortMode then
        return
    end
    local targetData = self:GetList().selectedData
    self.itemActions:SetInventorySlot(targetData)
end

--[[
Function: BETTERUI.Banking.Class:InitializeActionsDialog
Description: Initializes the "Y Button" Actions Dialog.
  1. Registers callbacks for dialog setup, finish, and confirmation.
  2. Filters out "Destroy" actions when in Deposit mode to prevent accidents.
  3. Populates the parametric list with valid actions from BETTERUI.Inventory.SlotActions.
  4. Handles the "Confirm" event to execute the selected action (or custom Chat Link logic).
References: Called during Initialize.
]]
--- Initializes the Y Button Actions Dialog with callbacks.
--- @return nil
function BETTERUI.Banking.Class:InitializeActionsDialog()
    local function ActionDialogSetup(dialog)
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
                self.itemActions:SetSelectedAction(selectedData and selectedData.action)
            end)

            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            -- Get target data and set on itemActions before discovering actions
            local targetData = self:GetList() and self:GetList().selectedData or nil

            if targetData then
                -- Ensure slotType is present for discovery (matches Inventory pattern)
                if not targetData.slotType then
                    if self.currentMode == LIST_WITHDRAW then
                        targetData.slotType = SLOT_TYPE_BANK_ITEM
                    else
                        targetData.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
                    end
                end

                -- Set the inventory slot on the outer controller
                self.itemActions:SetInventorySlot(targetData)

                -- Directly discover actions on the inner slotActions object
                if self.itemActions.slotActions then
                    local innerSlotActions = self.itemActions.slotActions
                    innerSlotActions:Clear()
                    innerSlotActions:SetInventorySlot(targetData)
                    ZO_InventorySlot_DiscoverSlotActionsFromActionList(targetData, innerSlotActions)
                end
            end

            -- Refresh item actions after discovery
            self:RefreshItemActions()

            -- Use shared CIM utility for action entry population
            local actions = self.itemActions:GetSlotActions()
            local hideDestroyInDeposit = self.currentMode == LIST_DEPOSIT
            BETTERUI.CIM.PopulateActionEntries(parametricList, actions, {
                hideDestroy = hideDestroyInDeposit,
            })

            -- Add custom "Withdraw Stack" / "Deposit Stack" action for stacked items
            if targetData and targetData.stackCount and targetData.stackCount > 1 then
                local actionName = (self.currentMode == LIST_WITHDRAW)
                    and GetString(SI_BETTERUI_BANK_WITHDRAW_MAX)
                    or GetString(SI_BETTERUI_BANK_DEPOSIT_MAX)
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

            -- Add "Sort" entry for header sort mode access
            if self.list and not self.list:IsEmpty() and self.EnterHeaderSortMode then
                local sortEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_HEADER_SORT))
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

            -- Move "Get Help" to end of list (should always be last action)
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
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            if not self.isInHeaderSortMode then
                self:AddKeybinds()
            end
            self:RefreshItemActions()
        end
    end

    local function ActionDialogButtonConfirm(dialog)
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            local selectedEntry = dialog.entryList and dialog.entryList:GetTargetData()
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
            if selectedName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
                BETTERUI.CIM.HandleLinkToChat(self:GetList().selectedData)
            elseif selectedName == GetString(SI_ITEM_ACTION_BANK_WITHDRAW) or
                selectedName == GetString(SI_ITEM_ACTION_BANK_DEPOSIT) then
                local selectedData = self.list and self.list:GetSelectedData()
                if selectedData then
                    local stackCount = selectedData.stackCount or 1
                    if stackCount > 1 then
                        local isDeposit = (selectedName == GetString(SI_ITEM_ACTION_BANK_DEPOSIT))
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
