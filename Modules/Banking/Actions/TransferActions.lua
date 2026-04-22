local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT
local CurrencySelector = BETTERUI.Banking.CurrencySelector or {}
local getTransferRules = BETTERUI.Banking and BETTERUI.Banking.GetTransferRules or nil
BETTERUI.Banking.Transfer = BETTERUI.Banking.Transfer
    or (type(getTransferRules) == "function" and getTransferRules())
    or BETTERUI.Banking.TransferRules
    or {}
BETTERUI.Banking.TransferRules = BETTERUI.Banking.Transfer
---@type BetterUIBankingTransferService
local Transfer = BETTERUI.Banking.Transfer

--- Finds the first empty slot in a personal or house bank bag.
--- Guild bank deposits are handled separately by MoveItem before this is called.
---@param targetBankBag number|nil Preferred destination bank bag
---@return integer? bag The bank bag ID, or nil if no space
---@return integer? slotIndex The empty slot index, or nil if no space
local function FindEmptySlotInBank(targetBankBag)
    targetBankBag = targetBankBag or BETTERUI.Banking.GetActiveDepositBag()
    if targetBankBag == BAG_BANK then
        local emptySlotIndexBank = FindFirstEmptySlotInBag(BAG_BANK)
        if emptySlotIndexBank ~= nil then
            return BAG_BANK, emptySlotIndexBank
        end
        if IsESOPlusSubscriber() then
            local emptySlotIndexSubscriber = FindFirstEmptySlotInBag(BAG_SUBSCRIBER_BANK)
            if emptySlotIndexSubscriber ~= nil then
                return BAG_SUBSCRIBER_BANK, emptySlotIndexSubscriber
            end
        end
        return nil, nil
    end

    local emptySlotIndex = FindFirstEmptySlotInBag(targetBankBag)
    if emptySlotIndex ~= nil then
        return targetBankBag, emptySlotIndex
    end
    return nil, nil
end

local function IsActionableBankSlotEntry(entryData)
    if not entryData then
        return false
    end
    if ZO_GamepadBanking and ZO_GamepadBanking.IsEntryDataCurrencyRelated and
        ZO_GamepadBanking.IsEntryDataCurrencyRelated(entryData) then
        return false
    end

    local rawData = entryData.dataSource or entryData
    local bagId = rawData and rawData.bagId or nil
    local slotIndex = rawData and rawData.slotIndex or nil
    if bagId == nil or slotIndex == nil then
        return false
    end

    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
    return stackCount > 0
end

---@param targetBankBag number
---@param denyReason string|nil
local function NotifyDepositBlocked(targetBankBag, denyReason)
    Transfer.NotifyTransferDenied("Banking.TransferActions.Deposit", targetBankBag, denyReason)
end

function BETTERUI.Banking.TryTransferInventorySlot(inventorySlot)
    if not inventorySlot then
        return false, "no_slot"
    end
    if not PLAYER_INVENTORY:IsBanking() then
        return false, "not_banking"
    end

    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local isGuildBankMode = BETTERUI.Banking.IsGuildBankTransfer()
    local isSourceFurnitureVault = IsFurnitureVault and IsFurnitureVault(bag)

    if bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK or IsHouseBankBag(bag) or isSourceFurnitureVault then
        if isGuildBankMode then
            local canTransfer, denyReason = Transfer.NotifyGuildBankTransferDenied(
                "TryTransferItem:GuildWithdraw",
                LIST_WITHDRAW,
                bag,
                index
            )
            if not canTransfer then
                return false, denyReason
            end
        end

        if DoesBagHaveSpaceFor(BAG_BACKPACK, bag, index) then
            CallSecureProtected("PickupInventoryItem", bag, index)
            CallSecureProtected("PlaceInTransfer")
            return true
        end

        BETTERUI.CIM.UserNotify("TryTransferItem:Withdraw", SI_INVENTORY_ERROR_INVENTORY_FULL)
        return false, "inventory_full"
    end

    local bankingBag = BETTERUI.Banking.GetActiveDepositBag()
    if isGuildBankMode then
        local canTransfer, denyReason = Transfer.NotifyGuildBankTransferDenied(
            "TryTransferItem:GuildDeposit",
            LIST_DEPOSIT,
            bag,
            index
        )
        if not canTransfer then
            return false, denyReason
        end
    end

    local canDeposit, denyReason = Transfer.CanDepositIntoBank(bag, index, bankingBag)
    if not canDeposit then
        Transfer.NotifyTransferDenied("TryTransferItem:Deposit", bankingBag, denyReason)
        return false, denyReason
    end

    local canAlsoBePlacedInSubscriberBank = bankingBag == BAG_BANK
    if DoesBagHaveSpaceFor(bankingBag, bag, index)
        or (canAlsoBePlacedInSubscriberBank and DoesBagHaveSpaceFor(BAG_SUBSCRIBER_BANK, bag, index)) then
        CallSecureProtected("PickupInventoryItem", bag, index)
        CallSecureProtected("PlaceInTransfer")
        return true
    end

    if canAlsoBePlacedInSubscriberBank and not IsESOPlusSubscriber() then
        if GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK) > 0 then
            TriggerTutorial(TUTORIAL_TRIGGER_BANK_OVERFULL)
        else
            TriggerTutorial(TUTORIAL_TRIGGER_BANK_FULL_NO_ESO_PLUS)
        end
    end
    ZO_AlertEvent(EVENT_BANK_IS_FULL)
    return false, "bank_full"
end

-- Stack-finding logic now uses shared CIM helper: BETTERUI.CIM.Utils.FindStackableSlotInBag
---@param list table The parametric list to get selected data from
---@param quantity integer? Number of items to move (default 1)
function BETTERUI.Banking.Class:MoveItem(list, quantity)
    local selectedData = list and list:GetSelectedData() or nil
    if not selectedData or not selectedData.bagId or not selectedData.slotIndex then
        -- Nothing to move (empty list, header row, or currency row)
        return
    end
    local fromBag, fromBagIndex = ZO_Inventory_GetBagAndIndex(selectedData)
    local fromBagItemLink = GetItemLink(fromBag, fromBagIndex)
    local isDepositing = (self.currentMode == LIST_DEPOSIT)
    local targetBankBag = BETTERUI.Banking.GetActiveDepositBag()
    if quantity == nil then
        quantity = 1
    end

    local function refreshMoveCoalescedCategoryView(previousCategoryKey)
        if self.RefreshCategoryView then
            self:RefreshCategoryView({
                preferredCategoryKey = previousCategoryKey,
            })
            return
        end

        self.bankCategories = self:ComputeVisibleBankCategories()
        if not self.bankCategories or #self.bankCategories == 0 then
            self.currentCategoryIndex = 1
            self:RefreshList()
            return
        end

        local desiredCategoryIndex = 1
        if previousCategoryKey then
            for i, category in ipairs(self.bankCategories) do
                if category.key == previousCategoryKey then
                    desiredCategoryIndex = i
                    break
                end
            end
        end
        self.currentCategoryIndex = zo_clamp(desiredCategoryIndex, 1, #self.bankCategories)
        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
        state.suppressHeaderCallback = true
        self:RebuildHeaderCategories()
        state.suppressHeaderCallback = false
        self:RefreshList()
    end

    local function beginCoalescedRefresh(delayMs)
        self._moveCoalesceToken = (self._moveCoalesceToken or 0) + 1
        local myToken = self._moveCoalesceToken
        self:SetListUpdatesSuppressed(true)

        local previousCategoryKey
        if self.GetCurrentCategoryKey then
            previousCategoryKey = self:GetCurrentCategoryKey()
        elseif self.bankCategories and self.currentCategoryIndex and self.currentCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[self.currentCategoryIndex]
            previousCategoryKey = prevCat and prevCat.key or nil
        end

        BETTERUI.Banking.Tasks:Schedule("moveCoalesce", delayMs or BETTERUI.CIM.CONST.TIMING.MOVE_COALESCE_DELAY_MS,
            function()
                if myToken ~= self._moveCoalesceToken then
                    return
                end
                self:SetListUpdatesSuppressed(false)
                refreshMoveCoalescedCategoryView(previousCategoryKey)
            end)
    end

    -- Guild bank uses dedicated transfer APIs instead of RequestMoveItem
    local isGuildBank = BETTERUI.Banking.IsGuildBankTransfer()
    if isGuildBank then
        local bagId = fromBag
        local slotIndex = fromBagIndex
        local mode = self.currentMode == LIST_WITHDRAW and LIST_WITHDRAW or LIST_DEPOSIT
        local canTransfer = Transfer.NotifyGuildBankTransferDenied("TransferActions:GuildTransfer", mode, bagId,
            slotIndex)
        if not canTransfer then
            return
        end
        if self.currentMode == LIST_WITHDRAW then
            if GetNumBagFreeSlots(BAG_BACKPACK) > 0 then
                local soundCategory = GetItemSoundCategory(fromBag, fromBagIndex)
                PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
                TransferFromGuildBank(fromBagIndex)
            else
                BETTERUI.CIM.UserNotify("TransferActions:GuildWithdraw", SI_INVENTORY_ERROR_INVENTORY_FULL)
            end
        else
            if GetNumBagUsedSlots(BAG_GUILDBANK) < GetBagSize(BAG_GUILDBANK) then
                local soundCategory = GetItemSoundCategory(fromBag, fromBagIndex)
                PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
                TransferToGuildBank(fromBag, fromBagIndex)
            else
                BETTERUI.CIM.UserNotify("TransferActions:GuildDeposit", SI_INVENTORY_ERROR_BANK_FULL)
            end
        end
        if not ZO_Dialogs_IsShowingDialog() then
            beginCoalescedRefresh(100)
        end
        return
    end

    -- Personal/house bank: existing RequestMoveItem logic
    local toBag
    local toBagEmptyIndex
    local toBagIndex

    if not isDepositing then
        toBag = BAG_BACKPACK
        toBagEmptyIndex = FindFirstEmptySlotInBag(toBag)
    else
        local canDeposit, denyReason = Transfer.CanDepositIntoBank(fromBag, fromBagIndex, targetBankBag)
        if not canDeposit then
            NotifyDepositBlocked(targetBankBag, denyReason)
            return
        end
        toBag, toBagEmptyIndex = FindEmptySlotInBank(targetBankBag)
    end

    if toBagEmptyIndex ~= nil then
        CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagEmptyIndex, quantity)
        if not ZO_Dialogs_IsShowingDialog() then
            beginCoalescedRefresh(100)
        end
    else
        if toBag ~= nil then
            local errorStringId = (toBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or
                SI_INVENTORY_ERROR_BANK_FULL
            toBagIndex = BETTERUI.CIM.Utils.FindStackableSlotInBag(toBag, fromBagItemLink)
            if toBagIndex then
                CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagIndex, quantity)
                if not ZO_Dialogs_IsShowingDialog() then
                    beginCoalescedRefresh(100)
                end
            else
                BETTERUI.CIM.UserNotify("TransferActions:NoStackSlot", errorStringId)
            end
        else
            local banks = { BAG_BANK, BAG_SUBSCRIBER_BANK }
            if BETTERUI.Banking.IsHouseBankTransfer() then
                banks = { targetBankBag }
            end

            for _, bank in ipairs(banks) do
                toBagIndex = BETTERUI.CIM.Utils.FindStackableSlotInBag(bank, fromBagItemLink)
                if toBagIndex then
                    toBag = bank
                    break
                end
            end
            if toBagIndex and toBag then
                CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagIndex, quantity)
                if not ZO_Dialogs_IsShowingDialog() then
                    beginCoalescedRefresh(100)
                end
            else
                local errorStringId = (toBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or
                    SI_INVENTORY_ERROR_BANK_FULL
                BETTERUI.CIM.UserNotify("TransferActions:NoBankSlot", errorStringId)
            end
        end
    end
end

function BETTERUI.Banking.Class:CancelWithdrawDeposit(list)
    local DEACTIVATE_SPINNER = false
    if not self.confirmationMode then
        if self.scene and self.scene.IsShowing and self.scene:IsShowing() then
            SCENE_MANAGER:HideCurrentScene()
        end
        return
    end

    self:UpdateSpinnerConfirmation(DEACTIVATE_SPINNER, list)
end

function BETTERUI.Banking.Class:ShowActions()
    local list = self:GetList()
    local targetData = list and list.selectedData or nil
    if not IsActionableBankSlotEntry(targetData) then
        return
    end

    self:RemoveKeybinds()

    -- Clean up enhanced tooltip to prevent border artifacts when action dialog shows
    if BETTERUI.CIM.SharedItemSupport and BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip then
        BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
    end

    -- finishedCallback no longer needs to add keybinds since BETTERUI_EVENT_ACTION_DIALOG_FINISH
    -- already calls ActionDialogFinish which handles keybind restoration. Setting nil prevents
    -- the redundant call that was causing keybind strip duplication.
    local function OnActionsFinishedCallback()
        -- Keybinds are restored via ActionDialogFinish callback in Banking.lua
        -- Do not add keybinds here to prevent duplicate keybind strip entries
    end

    local dialogData =
    {
        targetData = targetData,
        finishedCallback = OnActionsFinishedCallback,
        itemActions = self.itemActions,
    }

    ZO_Dialogs_ShowPlatformDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, dialogData)
end
