--[[
File: Modules/Banking/Actions/TransferActions.lua
Purpose: Manages item transfers and currency actions (Withdraw/Deposit).
         Extracted from Banking.lua to separate action logic from core UI.
Author: BetterUI Team
Last Modified: 2026-01-24
]]

local _

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
local function FindEmptySlotInBag(bagId)
    return FindFirstEmptySlotInBag(bagId)
end

--[[
Function: FindEmptySlotInBank
Description: Helper to find the first empty slot in the currently used bank.
Rationale: Checks main bank, then subscriber bank, or house bank if active.
return: number, number - The bag ID and slot index of an empty slot.
]]
local function FindEmptySlotInBank()
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
function BETTERUI.Banking.Class:MoveItem(list, quantity)
    local selectedData = list and list:GetSelectedData() or nil
    if not selectedData or not selectedData.bagId or not selectedData.slotIndex then
        -- Nothing to move (empty list, header row, or currency row)
        return
    end
    local fromBag, fromBagIndex = ZO_Inventory_GetBagAndIndex(selectedData)
    local stackCount = GetSlotStackSize(fromBag, fromBagIndex)
    local fromBagItemLink = GetItemLink(fromBag, fromBagIndex)
    local toBag
    local toBagEmptyIndex
    local toBagIndex
    local toBagItemLink
    local toBagStackCount
    local toBagStackCountMax
    local isToBagItemStackable
    local inSpinner = false
    if quantity ~= nil then
        --in spinner
        inSpinner = true
    else
        --not in spinner
        if (stackCount > 1) then
            -- display the spinner
            self:UpdateSpinnerConfirmation(true, self.list)
            self:SetSpinnerValue(list:GetSelectedData().stackCount, list:GetSelectedData().stackCount)
            return
        else
            --since stackcount = 1
            quantity = 1
        end
    end

    if self.currentMode == LIST_WITHDRAW then
        --we are withdrawing item from bank/subscriber bank bag
        toBag = BAG_BACKPACK
        toBagEmptyIndex = FindEmptySlotInBag(toBag)
    else
        --we are depositing item to bank/subscriber bank bag
        toBag, toBagEmptyIndex = FindEmptySlotInBank()
    end

    local function beginCoalescedRefresh(delayMs)
        -- Suppress intermediate refreshes and perform a single rebuild after item move settles
        self._moveCoalesceToken = (self._moveCoalesceToken or 0) + 1
        local myToken = self._moveCoalesceToken
        self._suppressListUpdates = true
        -- Capture the current category KEY before the delayed refresh (categories will change)
        local prevCategoryKey = nil
        if self.bankCategories and self.currentCategoryIndex and self.currentCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[self.currentCategoryIndex]
            if prevCat then
                prevCategoryKey = prevCat.key
            end
        end
        zo_callLater(function()
            if myToken ~= self._moveCoalesceToken then return end
            self._suppressListUpdates = false
            -- Recompute categories and refresh once
            self.bankCategories = self:ComputeVisibleBankCategories()
            -- Check if the captured category key still exists in the new list
            if prevCategoryKey then
                local categoryStillExists = false
                for i, cat in ipairs(self.bankCategories) do
                    if cat.key == prevCategoryKey then
                        categoryStillExists = true
                        break
                    end
                end
                if not categoryStillExists then
                    -- Category became empty, force to All Items
                    self.currentCategoryIndex = 1
                end
            end
            -- Suppress callback during rebuild when category has changed (Phase 4.3: Use NavigationState)
            local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
            state.suppressHeaderCallback = true
            self:RebuildHeaderCategories()
            state.suppressHeaderCallback = false
            self:RefreshList()
        end, delayMs or BETTERUI.CIM.CONST.TIMING.MOVE_COALESCE_DELAY_MS)
    end

    if toBagEmptyIndex ~= nil then
        --good to move
        CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagEmptyIndex, quantity)
        beginCoalescedRefresh(100)
        if inSpinner then
            self:UpdateSpinnerConfirmation(false, self.list)
        end
        -- Accomodates full banks with stackable item slots available
    else
        if toBag ~= nil then
            local errorStringId = (toBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or
                SI_INVENTORY_ERROR_BANK_FULL
            -- Get bag size
            local bagSize = GetBagSize(toBag)
            -- Iterate through BAG
            for i = 0, bagSize - 1 do
                local currentItemLink = GetItemLink(toBag, i)
                -- Matches items from origin bag to destination bag
                if currentItemLink == fromBagItemLink then
                    toBagItemLink = currentItemLink
                    isToBagItemStackable = IsItemLinkStackable(toBagItemLink)
                    -- Confirms item matched is stackable
                    if isToBagItemStackable then
                        toBagStackCount, toBagStackCountMax = GetSlotStackSize(toBag, i)
                        if toBagStackCount < toBagStackCountMax then
                            toBagIndex = i
                        end
                    end
                end
            end
            if toBagIndex then
                --good to move item that already has a non-full stack in the destination bag
                CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagIndex, quantity)
                beginCoalescedRefresh(100)
                if inSpinner then
                    self:UpdateSpinnerConfirmation(false, self.list)
                end
            else
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
                if inSpinner then
                    self:UpdateSpinnerConfirmation(false, self.list)
                end
            end
        else
            local banks = { BAG_BANK, BAG_SUBSCRIBER_BANK }
            for bankBags = 1, 2 do
                local bank = banks[bankBags]
                -- Get bag size
                local bagSize = GetBagSize(bank)
                -- Iterate through BAG
                for i = 0, bagSize - 1 do
                    local currentItemLink = GetItemLink(bank, i)
                    -- Matches items from origin bag to destination bag
                    if currentItemLink == fromBagItemLink then
                        toBagItemLink = currentItemLink
                        isToBagItemStackable = IsItemLinkStackable(toBagItemLink)
                        -- Confirms item matched is stackable
                        if isToBagItemStackable then
                            toBagStackCount, toBagStackCountMax = GetSlotStackSize(bank, i)
                            if toBagStackCount < toBagStackCountMax then
                                toBagIndex = i
                                toBag = bank
                            end
                        end
                    end
                end
            end
            if toBagIndex and toBag then
                CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagIndex, quantity)
                beginCoalescedRefresh(100)
                if inSpinner then
                    self:UpdateSpinnerConfirmation(false, self.list)
                end
            else
                local errorStringId = (toBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or
                    SI_INVENTORY_ERROR_BANK_FULL
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
                if inSpinner then
                    self:UpdateSpinnerConfirmation(false, self.list)
                end
            end
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:CancelWithdrawDeposit
Description: Cancels the current withdraw/deposit operation.
]]
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
function BETTERUI.Banking.Class:DisplaySelector(currencyType)
    local currency_max

    if (self.currentMode == LIST_DEPOSIT) then
        currency_max = GetCarriedCurrencyAmount(currencyType)
    else
        currency_max = GetBankedCurrencyAmount(currencyType)
    end

    -- Does the player actually have anything that can be transferred?
    if (currency_max ~= 0) then
        self.selector:SetMaxValue(currency_max)
        self.selector:SetClampValues(0, currency_max)
        self.selector.control:GetParent():SetHidden(false)

        local CURRENCY_TYPE_TO_TEXTURE =
        {
            [CURT_MONEY] = "EsoUI/Art/currency/gamepad/gp_gold.dds",
            [CURT_TELVAR_STONES] = "EsoUI/Art/currency/gamepad/gp_telvar.dds",
            [CURT_ALLIANCE_POINTS] = "esoui/art/currency/gamepad/gp_alliancepoints.dds",
            [CURT_WRIT_VOUCHERS] = "EsoUI/Art/currency/gamepad/gp_writvoucher.dds",
        }

        self.selectorCurrency:SetTexture(CURRENCY_TYPE_TO_TEXTURE[currencyType])

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
