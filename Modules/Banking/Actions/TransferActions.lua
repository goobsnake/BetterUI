--[[
File: Modules/Banking/Actions/TransferActions.lua
Purpose: Manages item transfers and currency actions (Withdraw/Deposit).
         Extracted from Banking.lua to separate action logic from core UI.
Author: BetterUI Team
Last Modified: 2026-01-24
]]

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS & STATE
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

--[[
Function: FindEmptySlotInBag
Description: Helper to find the first empty slot in a specific bag.
param: bagId (number) - The bag ID to search.
return: number|nil - The index of the first empty slot, or nil if full.
]]
--- @param bagId number
--- @return number|nil
local function FindEmptySlotInBag(bagId)
    return FindFirstEmptySlotInBag(bagId)
end

--[[
Function: FindEmptySlotInBank
Description: Helper to find the first empty slot in the currently used bank.
return: number, number - The bag ID and slot index of an empty slot.
]]
--- @return number|nil bagId
--- @return number|nil slotIndex
local function FindEmptySlotInBank()
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        local targetBag = GuildBank.GetDepositTargetBag()
        local emptySlotIndex = FindEmptySlotInBag(targetBag)
        if emptySlotIndex ~= nil then
            return targetBag, emptySlotIndex
        else
            return targetBag, nil
        end
    end

    local currentUsedBank = BETTERUI.Banking.currentUsedBank
    if (IsHouseBankBag(GetBankingBag()) == false) then
        local emptySlotIndexBank = FindEmptySlotInBag(BAG_BANK)
        local emptySlotIndexSubscriber = FindEmptySlotInBag(BAG_SUBSCRIBER_BANK)
        if emptySlotIndexBank ~= nil then
            return BAG_BANK, emptySlotIndexBank
            -- Use API directly instead of relying on global 'esoSubscriber' variable
        elseif IsESOPlusSubscriber() and emptySlotIndexSubscriber ~= nil then
            return BAG_SUBSCRIBER_BANK, emptySlotIndexSubscriber
        else
            return nil
        end
    else
        local emptySlotIndex = FindEmptySlotInBag(currentUsedBank)
        if emptySlotIndex ~= nil then
            return currentUsedBank, emptySlotIndex
        else
            return currentUsedBank, nil
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:MoveItem
Description: Moves an item (Withdraw or Deposit) between bags.
]]
-- Stack-finding logic now uses shared CIM helper: BETTERUI.CIM.Utils.FindStackableSlotInBag
--- @param list table The list to get selected data from
--- @param quantity number|nil The quantity to move (nil = all)
function BETTERUI.Banking.Class:MoveItem(list, quantity)
    local selectedData = list and list:GetSelectedData() or nil
    if not selectedData or not selectedData.bagId or not selectedData.slotIndex then
        -- Nothing to move (empty list, header row, or currency row)
        return
    end
    local fromBag, fromBagIndex = ZO_Inventory_GetBagAndIndex(selectedData)
    local fromBagItemLink = GetItemLink(fromBag, fromBagIndex)
    if quantity == nil then
        quantity = 1
    end

    local function beginCoalescedRefresh(delayMs)
        -- Suppress intermediate refreshes and perform a single rebuild after item move settles
        self._moveCoalesceToken = (self._moveCoalesceToken or 0) + 1
        local myToken = self._moveCoalesceToken
        self._suppressListUpdates = true
        local prevCategoryKey = nil
        if self.bankCategories and self.currentCategoryIndex and self.currentCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[self.currentCategoryIndex]
            if prevCat then
                prevCategoryKey = prevCat.key
            end
        end
        BETTERUI.Banking.Tasks:Schedule("moveCoalesce", delayMs or BETTERUI.CIM.CONST.TIMING.MOVE_COALESCE_DELAY_MS,
            function()
                if myToken ~= self._moveCoalesceToken then return end
                self._suppressListUpdates = false
                self.bankCategories = self:ComputeVisibleBankCategories()
                if prevCategoryKey then
                    local categoryStillExists = false
                    for i, cat in ipairs(self.bankCategories) do
                        if cat.key == prevCategoryKey then
                            categoryStillExists = true
                            break
                        end
                    end
                    if not categoryStillExists then
                        self.currentCategoryIndex = 1
                    end
                end
                local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
                state.suppressHeaderCallback = true
                self:RebuildHeaderCategories()
                state.suppressHeaderCallback = false
                self:RefreshList()
            end)
    end

    -- Guild bank uses dedicated transfer APIs instead of RequestMoveItem
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        if self.currentMode == LIST_WITHDRAW then
            if GetNumBagFreeSlots(BAG_BACKPACK) > 0 then
                local soundCategory = GetItemSoundCategory(fromBag, fromBagIndex)
                PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
                TransferFromGuildBank(fromBagIndex)
            else
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
            end
        else
            if GetNumBagUsedSlots(BAG_GUILDBANK) < GetBagSize(BAG_GUILDBANK) then
                local soundCategory = GetItemSoundCategory(fromBag, fromBagIndex)
                PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
                TransferToGuildBank(fromBag, fromBagIndex)
            else
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_BANK_FULL)
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

    if self.currentMode == LIST_WITHDRAW then
        toBag = BAG_BACKPACK
        toBagEmptyIndex = FindEmptySlotInBag(toBag)
    else
        toBag, toBagEmptyIndex = FindEmptySlotInBank()
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
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
            end
        else
            local banks = { BAG_BANK, BAG_SUBSCRIBER_BANK }
            if IsHouseBankBag(GetBankingBag()) then
                banks = { BETTERUI.Banking.currentUsedBank }
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
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
            end
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:CancelWithdrawDeposit
Description: Cancels the current withdraw/deposit operation.
]]
--- @param list table
function BETTERUI.Banking.Class:CancelWithdrawDeposit(list)
    local DEACTIVATE_SPINNER = false
    if self.confirmationMode then
        self:UpdateSpinnerConfirmation(DEACTIVATE_SPINNER, list)
    else
        SCENE_MANAGER:HideCurrentScene()
    end
end

--[[
Function: BETTERUI.Banking.Class:DisplaySelector
Description: Displays the currency selector for depositing/withdrawing funds.
]]
--- @param currencyType number
function BETTERUI.Banking.Class:DisplaySelector(currencyType)
    local currency_max
    local GuildBank = BETTERUI.Banking.GuildBank
    local isGuildBank = GuildBank and GuildBank.IsGuildBankMode()

    if GetMaxCurrencyTransfer then
        local fromLocation
        local toLocation
        if self.currentMode == LIST_DEPOSIT then
            fromLocation = CURRENCY_LOCATION_CHARACTER
            toLocation = isGuildBank and CURRENCY_LOCATION_GUILD_BANK or CURRENCY_LOCATION_BANK
        else
            fromLocation = isGuildBank and CURRENCY_LOCATION_GUILD_BANK or CURRENCY_LOCATION_BANK
            toLocation = CURRENCY_LOCATION_CHARACTER
        end
        currency_max = GetMaxCurrencyTransfer(currencyType, fromLocation, toLocation) or 0
    elseif (self.currentMode == LIST_DEPOSIT) then
        currency_max = GetCarriedCurrencyAmount(currencyType) or 0
    else
        currency_max = GetBankedCurrencyAmount(currencyType) or 0
    end

    -- Does the player actually have anything that can be transferred?
    if (currency_max > 0) then
        self.selector:SetMaxValue(currency_max)
        self.selector:SetClampValues(0, currency_max)
        self.selector.control:GetParent():SetHidden(false)

        self.selectorCurrency:SetTexture(BETTERUI.Banking.CONST.CURRENCY_TEXTURES[currencyType])

        self.selector:Activate()
        self.list:Deactivate()

        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.currencySelectorKeybinds)
    else
        -- No, display an alert
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(SI_BETTERUI_BANK_NO_FUNDS))
    end
end

--[[
Function: BETTERUI.Banking.Class:HideSelector
Description: Hides the currency selector and restores the item list.
]]
--- Hides the currency selector and restores the item list.
--- @return nil
function BETTERUI.Banking.Class:HideSelector()
    self.selector.control:GetParent():SetHidden(true)
    self.selector:Deactivate()
    self.list:Activate()

    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencySelectorKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.currencyKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
end

--[[
Function: BETTERUI.Banking.Class:ShowActions
Description: Shows the actions dialog for the selected item.
    Triggers ActionDialogHooks which handles action discovery and dialog population
    for both Inventory and Banking scenes.
]]
--- Shows the actions dialog for the selected item.
--- @return nil
function BETTERUI.Banking.Class:ShowActions()
    self:RemoveKeybinds()

    -- Clean up enhanced tooltip to prevent border artifacts when action dialog shows
    if BETTERUI.Inventory.CleanupEnhancedTooltip then
        BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
    end

    -- finishedCallback no longer needs to add keybinds since BETTERUI_EVENT_ACTION_DIALOG_FINISH
    -- already calls ActionDialogFinish which handles keybind restoration. Setting nil prevents
    -- the redundant call that was causing keybind strip duplication.
    local function OnActionsFinishedCallback()
        -- Keybinds are restored via ActionDialogFinish callback in Banking.lua
        -- Do not add keybinds here to prevent duplicate keybind strip entries
    end

    local targetData = self:GetList().selectedData

    local dialogData =
    {
        targetData = targetData,
        finishedCallback = OnActionsFinishedCallback,
        itemActions = self.itemActions,
    }

    ZO_Dialogs_ShowPlatformDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, dialogData)
end
