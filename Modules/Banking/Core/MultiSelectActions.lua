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
local LIST_WITHDRAW          = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT           = BETTERUI.Banking.LIST_DEPOSIT

local MSMixin                = BETTERUI.CIM.MultiSelectMixin
local FURNITURE_VAULT_BAG_ID = BAG_FURNITURE_VAULT

local function ExtractSlot(itemData)
    local rawData = itemData.dataSource or itemData
    return rawData.bagId or itemData.bagId, rawData.slotIndex or itemData.slotIndex
end

local function HasItemAtSlot(bagId, slotIndex)
    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
    return (stackCount or 0) > 0
end

local function ResolveStackCount(itemData, bagId, slotIndex)
    local rawData = itemData.dataSource or itemData
    local requestedStack = rawData.stackCount or itemData.stackCount or 1
    local liveStack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
    if liveStack <= 0 then
        return nil
    end
    return zo_clamp(requestedStack, 1, liveStack)
end

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
local LIST_WITHDRAW          = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT           = BETTERUI.Banking.LIST_DEPOSIT

local MSMixin                = BETTERUI.CIM.MultiSelectMixin
local FURNITURE_VAULT_BAG_ID = BAG_FURNITURE_VAULT

local function ExtractSlot(itemData)
    local rawData = itemData.dataSource or itemData
    return rawData.bagId or itemData.bagId, rawData.slotIndex or itemData.slotIndex
end

local function HasItemAtSlot(bagId, slotIndex)
    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
    return (stackCount or 0) > 0
end

local function ResolveStackCount(itemData, bagId, slotIndex)
    local rawData = itemData.dataSource or itemData
    local requestedStack = rawData.stackCount or itemData.stackCount or 1
    local liveStack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
    if liveStack <= 0 then
        return nil
    end
    return zo_clamp(requestedStack, 1, liveStack)
end

local function IsFurnitureVaultGemmableItem(bagId, slotIndex)
    return CROWN_GEMIFICATION_MANAGER
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable(tonumber(bagId), tonumber(slotIndex))
end

local function IsDepositSupportedForBank(bagId, slotIndex, targetBankBag)
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then
        return false
    end

    if targetBankBag == FURNITURE_VAULT_BAG_ID and IsFurnitureVaultGemmableItem(bagId, slotIndex) then
        return false
    end

    local bindType = GetItemBindType and GetItemBindType(bagId, slotIndex)
    if bindType == BIND_TYPE_ON_PICKUP_BACKPACK then
        return false
    end

    return true
end

local function ResolveDepositTargetBag(bagId, slotIndex, currentUsedBank)
    local targetBankBag = currentUsedBank or BAG_BANK

    if targetBankBag == BAG_BANK then
        -- DoesBagHaveSpaceFor(BAG_BANK) natively returns true if BAG_SUBSCRIBER_BANK has space,
        -- even if BAG_BANK is completely full. We must explicitly verify a slot resolves.
        if BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, BAG_BANK) then
            return BAG_BANK
        end
        if IsESOPlusSubscriber() and BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, BAG_SUBSCRIBER_BANK) then
            return BAG_SUBSCRIBER_BANK
        end

        -- Check if it's an unbankable item or genuinely out of space
        local freeSlots = (GetBagUseableSize(BAG_BANK) - GetNumBagUsedSlots(BAG_BANK))
        if IsESOPlusSubscriber() then
            freeSlots = freeSlots + (GetBagUseableSize(BAG_SUBSCRIBER_BANK) - GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK))
        end
        if freeSlots > 0 then
            return "unbankable"
        end

        return "skip"
    end

    if BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, targetBankBag) then
        return targetBankBag
    end

    local freeSlots = GetBagUseableSize(targetBankBag) - GetNumBagUsedSlots(targetBankBag)
    if freeSlots > 0 then
        return "unbankable"
    end

    return "skip"
end

local BANK_TRANSFER_BATCH_OPTIONS = {
    serverBound = true,
    awaitInventoryAck = true,
    minServerDelayMs = 145,
    maxServerDelayMs = 330,
    cooldownEvery = 18,
    cooldownMs = 1200,
    chunkCostUnits = 32,
    chunkPauseMs = 1000,
    adaptiveDelay = true,
    adaptiveThreshold = 6,
    adaptiveStepMs = 16,
    jitterMs = 18,
}

-------------------------------------------------------------------------------------------------
-- BANKING-SPECIFIC BATCH OPERATIONS
-------------------------------------------------------------------------------------------------

--- Performs batch withdraw/deposit on all selected items (throttled).
--- Moves items between bank and backpack based on current mode.
function BETTERUI.Banking.Class:BatchTransfer()
    if not self.multiSelectManager then return end
    local selectedItems = self.multiSelectManager:GetSelectedItems()
    if not selectedItems or #selectedItems == 0 then return end

    local isWithdraw = (self.currentMode == LIST_WITHDRAW)
    local currentUsedBank = BETTERUI.Banking.currentUsedBank or BAG_BANK
    local actionName = isWithdraw
        and GetString(SI_BETTERUI_BANKING_WITHDRAW)
        or GetString(SI_BETTERUI_BANKING_DEPOSIT)

    local items = {}
    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            if isWithdraw or IsDepositSupportedForBank(bagId, slotIndex, currentUsedBank) then
                items[#items + 1] = itemData
            end
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end

        local stackCount = ResolveStackCount(itemData, bagId, slotIndex)
        if not stackCount then
            return "skip"
        end
        if isWithdraw then
            -- Withdraw: move from bank to backpack
            local destinationSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, BAG_BACKPACK)
            if destinationSlot == nil then
                local freeSlots = GetBagUseableSize(BAG_BACKPACK) - GetNumBagUsedSlots(BAG_BACKPACK)
                if freeSlots == 0 then
                    return false -- Backpack full, abort processing
                end
                return "skip"    -- Item cannot be moved (e.g., restricted)
            end

            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, destinationSlot, stackCount)
        else
            if not IsDepositSupportedForBank(bagId, slotIndex, currentUsedBank) then
                return "skip"
            end

            -- Deposit: move from backpack to bank
            local targetBag = ResolveDepositTargetBag(bagId, slotIndex, currentUsedBank)
            if not targetBag or targetBag == "skip" then
                return false -- Bank full, abort batch
            end
            if targetBag == "unbankable" then
                return "skip" -- Item unbankable, skip this item, do not abort
            end

            local destinationSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, targetBag)
            if destinationSlot == nil then
                return "skip"
            end

            CallSecureProtected("RequestMoveItem", bagId, slotIndex, targetBag, destinationSlot, stackCount)
        end
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, actionName, BANK_TRANSFER_BATCH_OPTIONS)
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
    local currentUsedBank = BETTERUI.Banking.currentUsedBank or BAG_BANK
    local transferCount = 0

    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            if not isDepositMode or IsDepositSupportedForBank(bagId, slotIndex, currentUsedBank) then
                transferCount = transferCount + 1
            end
        end
    end

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
    if transferCount > 0 then
        local transferName = isDepositMode
            and GetString(SI_BETTERUI_BANKING_DEPOSIT)
            or GetString(SI_BETTERUI_BANKING_WITHDRAW)
        table.insert(parametricList, MSMixin.CreateDialogEntry(
            zo_strformat("<<1>> (<<2>>)", transferName, transferCount),
            function() self:BatchTransfer() end
        ))
    end

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
