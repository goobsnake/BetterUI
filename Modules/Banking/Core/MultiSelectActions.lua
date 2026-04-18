--[[
File: Modules/Banking/Core/MultiSelectActions.lua
Purpose: Banking-specific multi-select batch operations.
         BatchTransfer (withdraw/deposit), ShowBatchActionsMenu, and SelectAllItems.
         Common operations (lock, unlock, junk, throttled processing) are provided
         by CIM.MultiSelectMixin via BankingClass.lua delegates.
]]

-- SHARED CONSTANTS
local LIST_WITHDRAW          = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT           = BETTERUI.Banking.LIST_DEPOSIT

local MultiSelectMixin                = BETTERUI.CIM.MultiSelectMixin
local BatchConfig = BETTERUI.CIM.BatchConfig
local BatchStepHandled = BatchConfig.BatchStepHandled
local BatchStepQueued = BatchConfig.BatchStepQueued
local BatchStepSkipped = BatchConfig.BatchStepSkipped
local BatchStepStopped = BatchConfig.BatchStepStopped
local FURNITURE_VAULT_BAG_ID = BAG_FURNITURE_VAULT
local function ResolveBankBag(bankBagId)
    if BETTERUI.Banking.ResolveBankBag then
        return BETTERUI.Banking.ResolveBankBag(bankBagId)
    end
    if bankBagId == nil or bankBagId == 0 then
        return BAG_BANK
    end
    return bankBagId
end

local function GetCurrentBank()
    if BETTERUI.Banking.GetCurrentBank then
        return BETTERUI.Banking.GetCurrentBank()
    end
    return ResolveBankBag(BETTERUI.Banking.currentUsedBank)
end

local function GetBankingWindow()
    return BETTERUI.Banking and BETTERUI.Banking.Window
end

local ExtractSlot = BETTERUI.CIM.BatchActions.ExtractSlot
local HasItemAtSlot = BETTERUI.CIM.BatchActions.HasItemAtSlot

local function ResolveStackCount(itemData, bagId, slotIndex)
    local rawData = itemData.dataSource or itemData
    local requestedStack = rawData.stackCount or itemData.stackCount or 1
    local liveStack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
    if liveStack <= 0 then
        return nil
    end
    return zo_clamp(requestedStack, 1, liveStack)
end

local function IsDepositSupportedForBank(bagId, slotIndex, targetBankBag)
    if targetBankBag == FURNITURE_VAULT_BAG_ID
        and HOUSING_EDITOR_STATE
        and HOUSING_EDITOR_STATE.CanDepositIntoFurnitureVault
        and not HOUSING_EDITOR_STATE:CanDepositIntoFurnitureVault()
    then
        return false, "furniture_vault_locked"
    end

    -- Use shared protection policy for transfer validation
    -- (checks HasItemAtSlot, IsItemStolen, GetItemBindType, guild-bank rules)
    local canTransfer, denyReason = BETTERUI.CIM.ProtectionPolicy.CanTransferItem(bagId, slotIndex, targetBankBag)
    if not canTransfer then
        return false, denyReason
    end

    -- Gemmable furniture check (stolen already verified by CanTransferItem above)
    if targetBankBag == FURNITURE_VAULT_BAG_ID
        and CROWN_GEMIFICATION_MANAGER
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable(bagId, slotIndex) then
        local deny = BETTERUI.CIM.ProtectionPolicy and BETTERUI.CIM.ProtectionPolicy.DENY
        return false, (deny and deny.CROWN_GEMMABLE) or "crown_gemmable"
    end

    return true
end

local function ResolveTransferDeniedStringId(targetBankBag, denyReason)
    if not denyReason then
        return nil
    end

    local deny = BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy and BETTERUI.CIM.ProtectionPolicy.DENY or {}
    if denyReason == "furniture_vault_locked" then
        return IsESOPlusSubscriber and IsESOPlusSubscriber()
            and SI_FURNITURE_VAULT_ERROR_NEED_COLLECTIBLE
            or SI_FURNITURE_VAULT_ERROR_NEED_ESO_PLUS
    end
    if denyReason == deny.STOLEN then
        local targetIsFurnitureVault = IsFurnitureVault and IsFurnitureVault(targetBankBag)
        return targetIsFurnitureVault
            and SI_FURNITURE_VAULT_ERROR_STOLEN_FURNITURE
            or SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE
    end
    if denyReason == deny.CROWN_GEMMABLE then
        return SI_FURNITURE_VAULT_ERROR_GEMMABLE_FURNITURE
    end
    if targetBankBag == BAG_GUILDBANK then
        return rawget(_G, "SI_GAMEPAD_GUILD_BANK_NO_PERMISSION")
    end
    return nil
end

local function ResolveGuildBankTransferDecision(mode, bagId, slotIndex)
    local GuildBank = BETTERUI.Banking.GuildBank
    if not (GuildBank and GuildBank.IsGuildBankMode()) then
        return true, nil, nil, nil
    end

    local denialText = GuildBank.GetPermissionDenialReason and GuildBank.GetPermissionDenialReason(mode)
    if denialText then
        return false, "guild_permission", denialText, nil
    end

    local targetBag = mode == LIST_WITHDRAW and BAG_BACKPACK or BAG_GUILDBANK
    local canTransfer, denyReason
    if mode == LIST_DEPOSIT then
        canTransfer, denyReason = IsDepositSupportedForBank(bagId, slotIndex, targetBag)
    else
        canTransfer, denyReason = BETTERUI.CIM.ProtectionPolicy.CanTransferItem(bagId, slotIndex, targetBag)
    end

    if canTransfer then
        return true, nil, nil, nil
    end

    local stringId = ResolveTransferDeniedStringId(targetBag, denyReason)
    local text = stringId and GetString(stringId) or nil
    return false, denyReason, text, stringId
end

local function NotifyGuildBankTransferDenied(context, mode, bagId, slotIndex)
    local allowed, denyReason, denialText, stringId = ResolveGuildBankTransferDecision(mode, bagId, slotIndex)
    if allowed then
        return true, nil
    end
    if stringId then
        BETTERUI.CIM.UserNotify(context, stringId)
    elseif denialText then
        BETTERUI.CIM.UserAlertText(context, denialText)
    end
    return false, denyReason
end

--- Resolves where to deposit an item, returning a bag ID or a sentinel string.
---@param bagId number Source bag ID
---@param slotIndex number Source slot index
---@param currentUsedBank number|nil Target bank bag (defaults to BAG_BANK)
---@return number|"unbankable"|"skip" targetBag Bag constant, or "unbankable"/"skip" sentinel
local function ResolveDepositTargetBag(bagId, slotIndex, currentUsedBank)
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        local targetBag = GuildBank.GetDepositTargetBag()
        if BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, targetBag) then
            return targetBag
        end
        local freeSlots = GetBagUseableSize(targetBag) - GetNumBagUsedSlots(targetBag)
        if freeSlots > 0 then return "unbankable" end
        return "skip"
    end

    local targetBankBag = ResolveBankBag(currentUsedBank)

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

-- Expose helpers for unit testing (tools/tests/test_banking_transfer.lua)
BETTERUI.Banking._TransferHelpers = {
    ResolveStackCount = ResolveStackCount,
    IsDepositSupportedForBank = IsDepositSupportedForBank,
    ResolveTransferDeniedStringId = ResolveTransferDeniedStringId,
    ResolveGuildBankTransferDecision = ResolveGuildBankTransferDecision,
    NotifyGuildBankTransferDenied = NotifyGuildBankTransferDenied,
    ResolveDepositTargetBag = ResolveDepositTargetBag,
}

local BANK_TRANSFER_BATCH_OPTIONS = BatchConfig.ComposeBatchOptions(
    BatchConfig.WithServer({
        serverBound = true,
    }),
    BatchConfig.WithAck({
        awaitInventoryAck = true,
    }),
    BatchConfig.WithPacing({
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
    })
)

-- BANKING-SPECIFIC BATCH OPERATIONS

--- Performs batch withdraw/deposit on all selected items (throttled).
--- Moves items between bank and backpack based on current mode.
function BETTERUI.Banking.Class:BatchTransfer()
    if not self.multiSelectManager then return end
    local selectedItems = self.multiSelectManager:GetSelectedItems()
    if not selectedItems or #selectedItems == 0 then return end

    local isWithdraw = (self.currentMode == LIST_WITHDRAW)
    local currentUsedBank = GetCurrentBank()
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        currentUsedBank = BAG_GUILDBANK
    end
    local actionName = isWithdraw
        and GetString(rawget(_G, "SI_BETTERUI_BANKING_WITHDRAW"))
        or GetString(rawget(_G, "SI_BETTERUI_BANKING_DEPOSIT"))

    local items = {}
    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local canTransfer = isWithdraw or IsDepositSupportedForBank(bagId, slotIndex, currentUsedBank)
            if GuildBank and GuildBank.IsGuildBankMode() then
                canTransfer = ResolveGuildBankTransferDecision(isWithdraw and LIST_WITHDRAW or LIST_DEPOSIT, bagId, slotIndex)
            end
            if canTransfer then
                items[#items + 1] = itemData
            end
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
        if not HasItemAtSlot(bagId, slotIndex) then
            return BatchStepHandled()
        end

        local stackCount = ResolveStackCount(itemData, bagId, slotIndex)
        if not stackCount then
            return BatchStepSkipped()
        end

        -- Guild bank uses dedicated transfer APIs
        local GuildBankAdapter = BETTERUI.Banking.GuildBank
        if GuildBankAdapter and GuildBankAdapter.IsGuildBankMode() then
            local canTransfer = ResolveGuildBankTransferDecision(isWithdraw and LIST_WITHDRAW or LIST_DEPOSIT, bagId, slotIndex)
            if not canTransfer then
                return BatchStepSkipped()
            end
            if isWithdraw then
                if GetNumBagFreeSlots(BAG_BACKPACK) == 0 then
                    return BatchStepStopped("bagFull")
                end
                TransferFromGuildBank(slotIndex)
            else
                if not IsDepositSupportedForBank(bagId, slotIndex, BAG_GUILDBANK) then
                    return BatchStepSkipped()
                end
                if GetNumBagUsedSlots(BAG_GUILDBANK) >= GetBagSize(BAG_GUILDBANK) then
                    return BatchStepStopped("bagFull")
                end
                TransferToGuildBank(bagId, slotIndex)
            end
            return BatchStepQueued()
        end

        -- Personal/house bank: existing RequestMoveItem logic
        if isWithdraw then
            local destinationSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, BAG_BACKPACK)
            if destinationSlot == nil then
                local freeSlots = GetBagUseableSize(BAG_BACKPACK) - GetNumBagUsedSlots(BAG_BACKPACK)
                if freeSlots == 0 then
                    return BatchStepStopped("bagFull")
                end
                return BatchStepSkipped()
            end

            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, destinationSlot, stackCount)
        else
            if not IsDepositSupportedForBank(bagId, slotIndex, currentUsedBank) then
                return BatchStepSkipped()
            end

            local targetBag = ResolveDepositTargetBag(bagId, slotIndex, currentUsedBank)
            if not targetBag or targetBag == "skip" then
                return BatchStepStopped("bagFull")
            end
            if targetBag == "unbankable" then
                return BatchStepSkipped()
            end

            ---@cast targetBag number
            local destinationSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, targetBag)
            if destinationSlot == nil then
                return BatchStepSkipped()
            end

            CallSecureProtected("RequestMoveItem", bagId, slotIndex, targetBag, destinationSlot, stackCount)
        end
        return BatchStepQueued()
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

-- BATCH ACTIONS DIALOG

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
    local counts = MultiSelectMixin.AnalyzeSelectedItems(selectedItems)
    local isDepositMode = (self.currentMode == LIST_DEPOSIT)
    local currentUsedBank = GetCurrentBank()
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        currentUsedBank = BAG_GUILDBANK
    end
    local transferCount = 0
    local firstTransferDeniedLabel = nil

    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local canTransfer = not isDepositMode or IsDepositSupportedForBank(bagId, slotIndex, currentUsedBank)
            if GuildBank and GuildBank.IsGuildBankMode() then
                local _, _, denialText = ResolveGuildBankTransferDecision(
                    isDepositMode and LIST_DEPOSIT or LIST_WITHDRAW,
                    bagId,
                    slotIndex
                )
                canTransfer = ResolveGuildBankTransferDecision(isDepositMode and LIST_DEPOSIT or LIST_WITHDRAW, bagId, slotIndex)
                if not canTransfer and not firstTransferDeniedLabel and denialText then
                    firstTransferDeniedLabel = denialText
                end
            end
            if canTransfer then
                transferCount = transferCount + 1
            end
        end
    end

    -- Furniture Vault does not support junk status in either mode.
    local suppressJunkActions = self.IsFurnitureVaultContext and self:IsFurnitureVaultContext()
    if suppressJunkActions then
        counts.canMarkJunkCount = 0
        counts.canUnmarkJunkCount = 0
    end

    -- Register dialog on first use
    local dialogName = "BETTERUI_BANKING_BATCH_ACTIONS_DIALOG"
    if not ESO_Dialogs[dialogName] then
        local dialogInfo = {
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = function(dialog)
                    local count = dialog and dialog.data and dialog.data.selectedCount or 0
                    return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_SELECTED_COUNT")), count)
                end,
            },
            mainText = {
                text = GetString(rawget(_G, "SI_BETTERUI_BATCH_ACTIONS_DESC")),
            },
            setup = function(dialog)
                dialog:setupFunc()
            end,
            parametricList = {},
            buttons = {
                {
                    keybind = "DIALOG_PRIMARY",
                    text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
                    callback = function(dialog)
                        local selected = dialog.entryList and dialog.entryList:GetTargetData()
                        if selected and selected.callback then
                            selected.callback()
                        end
                    end,
                },
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
                    callback = function()
                        zo_callLater(function()
                            local window = GetBankingWindow()
                            if window then
                                KEYBIND_STRIP:UpdateKeybindButtonGroup(window.coreKeybinds)
                            end
                        end, 50)
                    end,
                },
            },
        }
        if BETTERUI.CIM and BETTERUI.CIM.Dialogs and BETTERUI.CIM.Dialogs.Register then
            BETTERUI.CIM.Dialogs.Register(dialogName, dialogInfo, { overwrite = true })
        elseif ZO_Dialogs_RegisterCustomDialog then
            ZO_Dialogs_RegisterCustomDialog(dialogName, dialogInfo)
        else
            ESO_Dialogs[dialogName] = dialogInfo
        end
    end

    -- Build parametric list
    local parametricList = {}

    -- Select All (always first)
    table.insert(parametricList, MultiSelectMixin.CreateDialogEntry(
        GetString(rawget(_G, "SI_BETTERUI_SELECT_ALL")),
        function() self:SelectAllItems() end
    ))

    -- Withdraw/Deposit All (primary banking action)
    if transferCount > 0 then
        local transferName = isDepositMode
            and GetString(rawget(_G, "SI_BETTERUI_BANKING_DEPOSIT"))
            or GetString(rawget(_G, "SI_BETTERUI_BANKING_WITHDRAW"))
        table.insert(parametricList, MultiSelectMixin.CreateDialogEntry(
            zo_strformat("<<1>> (<<2>>)", transferName, transferCount),
            function() self:BatchTransfer() end
        ))
    elseif firstTransferDeniedLabel then
        table.insert(parametricList, MultiSelectMixin.CreateDialogEntry(
            firstTransferDeniedLabel,
            function()
                for _, itemData in ipairs(selectedItems) do
                    local bagId, slotIndex = ExtractSlot(itemData)
                    if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
                        NotifyGuildBankTransferDenied(
                            "Banking.BatchTransfer",
                            isDepositMode and LIST_DEPOSIT or LIST_WITHDRAW,
                            bagId,
                            slotIndex
                        )
                        break
                    end
                end
            end
        ))
    end

    -- Append common batch entries (Lock, Unlock, Mark/Unmark Junk) from mixin
    MultiSelectMixin.AppendCommonBatchEntries(parametricList, counts, self)

    -- Deselect All (always last)
    table.insert(parametricList, MultiSelectMixin.CreateDialogEntry(
        zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_BETTERUI_DESELECT_ALL")), selectedCount),
        function()
            ZO_Dialogs_ReleaseDialog(dialogName)
            zo_callLater(function() self:ExitSelectionMode() end, 50)
        end
    ))

    local dialogInfo = ESO_Dialogs[dialogName]
    if not dialogInfo then
        return
    end
    dialogInfo.parametricList = parametricList
    ZO_Dialogs_ShowGamepadDialog(dialogName, { selectedCount = selectedCount })
end
