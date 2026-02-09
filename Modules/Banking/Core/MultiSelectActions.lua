--[[
File: Modules/Banking/Core/MultiSelectActions.lua
Purpose: Banking-specific multi-select batch operations.
         BatchTransfer (withdraw/deposit), ShowBatchActionsMenu, and SelectAllItems.
         Common operations (lock, unlock, junk, throttled processing) are provided
         by CIM.MultiSelectMixin via BankingClass.lua delegates.
Author: BetterUI Team
Last Modified: 2026-02-09
]]

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

local MSMixin = BETTERUI.CIM.MultiSelectMixin

-------------------------------------------------------------------------------------------------
-- BANKING-SPECIFIC BATCH OPERATIONS
-------------------------------------------------------------------------------------------------

--- Performs batch withdraw/deposit on all selected items (throttled).
--- Moves items between bank and backpack based on current mode.
function BETTERUI.Banking.Class:BatchTransfer()
    if not self.multiSelectManager then return end
    local items = self.multiSelectManager:GetSelectedItems()
    if not items or #items == 0 then return end

    local isWithdraw = (self.currentMode == LIST_WITHDRAW)
    local actionName = isWithdraw
        and GetString(SI_BETTERUI_BANKING_WITHDRAW)
        or GetString(SI_BETTERUI_BANKING_DEPOSIT)

    self:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
        local rawData = itemData.dataSource or itemData
        local stackCount = rawData.stackCount or itemData.stackCount or 1

        if isWithdraw then
            -- Withdraw: move from bank to backpack
            if not DoesBagHaveSpaceFor(BAG_BACKPACK, bagId, slotIndex) then
                local itemLink = GetItemLink(bagId, slotIndex)
                local stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(BAG_BACKPACK, itemLink)
                if not stackSlot then
                    return false -- Bag full, stop processing
                end
            end
            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, nil, stackCount)
        else
            -- Deposit: move from backpack to bank
            local targetBag, targetSlot
            local currentUsedBank = BETTERUI.Banking.currentUsedBank
            if currentUsedBank == BAG_BANK then
                targetSlot = FindFirstEmptySlotInBag(BAG_BANK)
                if targetSlot then
                    targetBag = BAG_BANK
                elseif IsESOPlusSubscriber() then
                    targetSlot = FindFirstEmptySlotInBag(BAG_SUBSCRIBER_BANK)
                    if targetSlot then
                        targetBag = BAG_SUBSCRIBER_BANK
                    end
                end
            else
                targetSlot = FindFirstEmptySlotInBag(currentUsedBank)
                if targetSlot then
                    targetBag = currentUsedBank
                end
            end

            if not targetBag then
                -- Try finding a stackable slot
                local itemLink = GetItemLink(bagId, slotIndex)
                if currentUsedBank == BAG_BANK then
                    local stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(BAG_BANK, itemLink)
                    if stackSlot then
                        targetBag = BAG_BANK
                    else
                        stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(BAG_SUBSCRIBER_BANK, itemLink)
                        if stackSlot then
                            targetBag = BAG_SUBSCRIBER_BANK
                        end
                    end
                else
                    local stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(currentUsedBank, itemLink)
                    if stackSlot then
                        targetBag = currentUsedBank
                    end
                end
                if not targetBag then
                    return false -- Bank full, stop processing
                end
            end

            CallSecureProtected("RequestMoveItem", bagId, slotIndex, targetBag, nil, stackCount)
        end
        return true
    end, function()
        self:ExitSelectionMode()
    end, actionName)
end

--- Selects all items in the current list.
--- Reopens the batch actions dialog to reflect the updated selection.
function BETTERUI.Banking.Class:SelectAllItems()
    if not self.multiSelectManager then return end

    self.multiSelectManager:SelectAll(self.list)

    ZO_Dialogs_ReleaseDialog("BETTERUI_BANKING_BATCH_ACTIONS_DIALOG")
    zo_callLater(function()
        self:RefreshList()
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
        self:ShowBatchActionsMenu()
    end, 50)
end

-------------------------------------------------------------------------------------------------
-- BATCH ACTIONS DIALOG
-------------------------------------------------------------------------------------------------

--- Shows the batch actions menu for multi-selected items.
--- Uses CIM.MultiSelectMixin helpers for item analysis and common dialog entries,
--- then adds Banking-specific Transfer action and mode-aware junk filtering.
function BETTERUI.Banking.Class:ShowBatchActionsMenu()
    if not self.multiSelectManager or not self.multiSelectManager:IsActive() then
        return
    end

    local selectedItems = self.multiSelectManager:GetSelectedItems()
    local selectedCount = #selectedItems
    if selectedCount == 0 then return end

    -- Use shared mixin to analyze selected items
    local counts = MSMixin.AnalyzeSelectedItems(selectedItems)
    local isDepositMode = (self.currentMode == LIST_DEPOSIT)

    -- If in withdraw mode, suppress junk actions (bank items can't be junked)
    if not isDepositMode then
        counts.canMarkJunkCount = 0
        counts.canUnmarkJunkCount = 0
    end

    -- Register dialog on first use
    local dialogName = "BETTERUI_BANKING_BATCH_ACTIONS_DIALOG"
    if not ESO_Dialogs[dialogName] then
        ESO_Dialogs[dialogName] = {
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = function(dialog)
                    local count = dialog and dialog.data and dialog.data.selectedCount or 0
                    return zo_strformat(GetString(SI_BETTERUI_SELECTED_COUNT), count)
                end,
            },
            mainText = {
                text = GetString(SI_BETTERUI_BATCH_ACTIONS_DESC),
            },
            setup = function(dialog)
                dialog:setupFunc()
            end,
            parametricList = {},
            buttons = {
                {
                    keybind = "DIALOG_PRIMARY",
                    text = GetString(SI_GAMEPAD_SELECT_OPTION),
                    callback = function(dialog)
                        local selected = dialog.entryList and dialog.entryList:GetTargetData()
                        if selected and selected.callback then
                            selected.callback()
                        end
                    end,
                },
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = GetString(SI_GAMEPAD_BACK_OPTION),
                    callback = function()
                        zo_callLater(function()
                            if BETTERUI.Banking.Window then
                                KEYBIND_STRIP:UpdateKeybindButtonGroup(
                                    BETTERUI.Banking.Window.coreKeybinds)
                            end
                        end, 50)
                    end,
                },
            },
        }
    end

    -- Build parametric list
    local parametricList = {}

    -- Select All (always first)
    table.insert(parametricList, MSMixin.CreateDialogEntry(
        GetString(SI_BETTERUI_SELECT_ALL),
        function() self:SelectAllItems() end
    ))

    -- Withdraw/Deposit All (primary banking action)
    local transferName = isDepositMode
        and GetString(SI_BETTERUI_BANKING_DEPOSIT)
        or GetString(SI_BETTERUI_BANKING_WITHDRAW)
    table.insert(parametricList, MSMixin.CreateDialogEntry(
        zo_strformat("<<1>> (<<2>>)", transferName, selectedCount),
        function() self:BatchTransfer() end
    ))

    -- Append common batch entries (Lock, Unlock, Mark/Unmark Junk) from mixin
    MSMixin.AppendCommonBatchEntries(parametricList, counts, self)

    -- Deselect All (always last)
    table.insert(parametricList, MSMixin.CreateDialogEntry(
        zo_strformat("<<1>> (<<2>>)", GetString(SI_BETTERUI_DESELECT_ALL), selectedCount),
        function()
            ZO_Dialogs_ReleaseDialog(dialogName)
            zo_callLater(function() self:ExitSelectionMode() end, 50)
        end
    ))

    ESO_Dialogs[dialogName].parametricList = parametricList
    ZO_Dialogs_ShowGamepadDialog(dialogName, { selectedCount = selectedCount })
end
