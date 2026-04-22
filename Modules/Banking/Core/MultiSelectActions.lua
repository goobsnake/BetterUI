-- Banking-specific multi-select transfer actions.
local LIST_WITHDRAW          = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT           = BETTERUI.Banking.LIST_DEPOSIT

local MultiSelectMixin                = BETTERUI.CIM.MultiSelectMixin
local BatchConfig = BETTERUI.CIM.BatchConfig
local BatchStepHandled = BatchConfig.BatchStepHandled
local BatchStepQueued = BatchConfig.BatchStepQueued
local BatchStepSkipped = BatchConfig.BatchStepSkipped
local BatchStepStopped = BatchConfig.BatchStepStopped
local FURNITURE_VAULT_BAG_ID = BAG_FURNITURE_VAULT
local ProtectionPolicy = assert(
    BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy,
    "BetterUI: CIM.ProtectionPolicy must load before Banking/Core/MultiSelectActions"
)
local DENY = assert(
    ProtectionPolicy and ProtectionPolicy.DENY,
    "BetterUI: CIM.ProtectionPolicy.DENY must load before Banking/Core/MultiSelectActions"
)
assert(type(ProtectionPolicy.CanTransferItem) == "function",
    "BetterUI: CIM.ProtectionPolicy.CanTransferItem must load before Banking/Core/MultiSelectActions")
assert(type(DENY.STOLEN) == "string", "BetterUI: ProtectionPolicy.DENY.STOLEN must be defined")
assert(type(DENY.CROWN_GEMMABLE) == "string", "BetterUI: ProtectionPolicy.DENY.CROWN_GEMMABLE must be defined")
assert(type(DENY.FURNITURE_VAULT_LOCKED) == "string",
    "BetterUI: ProtectionPolicy.DENY.FURNITURE_VAULT_LOCKED must be defined")
assert(type(DENY.GUILD_PERMISSION) == "string", "BetterUI: ProtectionPolicy.DENY.GUILD_PERMISSION must be defined")

local function ResolveTransferService()
    local getTransferService = BETTERUI.Banking and BETTERUI.Banking.GetTransferService or nil
    if type(getTransferService) == "function" then
        local transferService = getTransferService()
        if type(transferService) == "table" then
            return transferService
        end
    end

    local transferService = BETTERUI.Banking and BETTERUI.Banking.Transfer or nil
    if type(transferService) ~= "table" then
        transferService = {}
        BETTERUI.Banking.Transfer = transferService
    end
    return transferService
end

---@type BetterUIBankingTransferService
local Transfer = ResolveTransferService() or {}

local TRANSFER_DENIAL_ALERT = 1
local TRANSFER_DENIAL_TOAST = 2

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
        return false, DENY.FURNITURE_VAULT_LOCKED
    end

    -- Use shared protection policy for transfer validation
    -- (checks HasItemAtSlot, IsItemStolen, GetItemBindType, guild-bank rules)
    local canTransfer, denyReason = ProtectionPolicy.CanTransferItem(bagId, slotIndex, targetBankBag)
    if not canTransfer then
        return false, denyReason
    end

    -- Gemmable furniture check (stolen already verified by CanTransferItem above)
    if targetBankBag == FURNITURE_VAULT_BAG_ID
        and CROWN_GEMIFICATION_MANAGER
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable(bagId, slotIndex) then
        return false, DENY.CROWN_GEMMABLE
    end

    return true
end

local function ResolveTransferDeniedStringId(targetBankBag, denyReason)
    if not denyReason then
        return nil
    end

    if denyReason == DENY.FURNITURE_VAULT_LOCKED then
        return IsESOPlusSubscriber and IsESOPlusSubscriber()
            and SI_FURNITURE_VAULT_ERROR_NEED_COLLECTIBLE
            or SI_FURNITURE_VAULT_ERROR_NEED_ESO_PLUS
    end
    if denyReason == DENY.STOLEN then
        local targetIsFurnitureVault = IsFurnitureVault and IsFurnitureVault(targetBankBag)
        return targetIsFurnitureVault
            and SI_FURNITURE_VAULT_ERROR_STOLEN_FURNITURE
            or SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE
    end
    if denyReason == DENY.CROWN_GEMMABLE then
        return SI_FURNITURE_VAULT_ERROR_GEMMABLE_FURNITURE
    end
    if denyReason == DENY.GUILD_PERMISSION then
        return rawget(_G, "SI_GAMEPAD_GUILD_BANK_NO_PERMISSION")
    end
    return nil
end

local function ResolveTransferDeniedNotification(targetBankBag, denyReason)
    local stringId = ResolveTransferDeniedStringId(targetBankBag, denyReason)
    if not stringId then
        return nil
    end

    local isFurnitureTransfer
        = denyReason == DENY.FURNITURE_VAULT_LOCKED
        or (IsFurnitureVault and IsFurnitureVault(targetBankBag))

    return {
        stringId = stringId,
        mode = isFurnitureTransfer and TRANSFER_DENIAL_ALERT or TRANSFER_DENIAL_TOAST,
    }
end

local function ResolveGuildBankTransferDecision(mode, bagId, slotIndex)
    local transferState = BETTERUI.Banking.GetTransferState()
    if transferState.kind ~= BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK then
        return true, nil, nil, nil
    end

    local GuildBank = BETTERUI.Banking.GuildBank
    local permissionDenial = GuildBank.GetPermissionDenial and GuildBank.GetPermissionDenial(mode)
    if permissionDenial then
        return false,
            permissionDenial.reason or DENY.GUILD_PERMISSION,
            permissionDenial.text,
            permissionDenial.stringId
    end

    local targetBag = mode == LIST_WITHDRAW and BAG_BACKPACK or BAG_GUILDBANK
    local canTransfer, denyReason
    if mode == LIST_DEPOSIT then
        canTransfer, denyReason = IsDepositSupportedForBank(bagId, slotIndex, targetBag)
    else
        canTransfer, denyReason = ProtectionPolicy.CanTransferItem(bagId, slotIndex, targetBag)
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
---@param transferBankBag number|nil Resolved destination bank bag (defaults to BAG_BANK)
---@return number|"unbankable"|"skip" targetBag Bag constant, or "unbankable"/"skip" sentinel
local function ResolveDepositTargetBag(bagId, slotIndex, transferBankBag)
    local transferState = BETTERUI.Banking.GetTransferState()
    if transferState.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK then
        local targetBag = transferState.depositTargetBag
        if BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, targetBag) then
            return targetBag
        end
        local freeSlots = GetBagUseableSize(targetBag) - GetNumBagUsedSlots(targetBag)
        if freeSlots > 0 then return "unbankable" end
        return "skip"
    end

    local destinationBankBag = transferBankBag
    if destinationBankBag == nil or destinationBankBag == 0 then
        destinationBankBag = BAG_BANK
    end

    if destinationBankBag == BAG_BANK then
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

    if BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, destinationBankBag) then
        return destinationBankBag
    end

    local freeSlots = GetBagUseableSize(destinationBankBag) - GetNumBagUsedSlots(destinationBankBag)
    if freeSlots > 0 then
        return "unbankable"
    end

    return "skip"
end

---@param bagId BagId
---@param slotIndex SlotIndex
---@param targetBankBag BagId
---@return boolean canDeposit
---@return string|nil denyReason
Transfer.CanDepositIntoBank = IsDepositSupportedForBank

---@param context string
---@param targetBankBag BagId
---@param denyReason string|nil
---@return nil
Transfer.NotifyTransferDenied = function(context, targetBankBag, denyReason)
    if not denyReason then
        return
    end

    local notification = ResolveTransferDeniedNotification(targetBankBag, denyReason)
    if not notification or not notification.stringId then
        return
    end

    if notification.mode == TRANSFER_DENIAL_ALERT then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, notification.stringId)
        return
    end

    BETTERUI.CIM.UserNotify(context, notification.stringId)
end

---@param mode number
---@param bagId BagId
---@param slotIndex SlotIndex
---@return boolean canTransfer
---@return string|nil denyReason
---@return string|nil denialText
---@return string|nil denialStringId
Transfer.ResolveGuildBankTransferDecision = ResolveGuildBankTransferDecision

---@param context string
---@param mode number
---@param bagId BagId
---@param slotIndex SlotIndex
---@return boolean canTransfer
---@return string|nil denyReason
Transfer.NotifyGuildBankTransferDenied = NotifyGuildBankTransferDenied

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
    local transferState = BETTERUI.Banking.GetTransferState()
    local transferDestinationBankBag = transferState.depositTargetBag
    local isGuildMode = transferState.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
    local guildTransferMode = isWithdraw and LIST_WITHDRAW or LIST_DEPOSIT
    local actionName = isWithdraw
        and GetString(rawget(_G, "SI_BETTERUI_BANKING_WITHDRAW"))
        or GetString(rawget(_G, "SI_BETTERUI_BANKING_DEPOSIT"))

    local items = {}
    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local canTransfer = isWithdraw or IsDepositSupportedForBank(bagId, slotIndex, transferDestinationBankBag)
            if isGuildMode then
                canTransfer = ResolveGuildBankTransferDecision(guildTransferMode, bagId, slotIndex)
            end
            if canTransfer then
                items[#items + 1] = itemData
            end
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled({
        items = items,
        step = function(bagId, slotIndex, itemData)
            if not HasItemAtSlot(bagId, slotIndex) then
                return BatchStepHandled()
            end

            local stackCount = ResolveStackCount(itemData, bagId, slotIndex)
            if not stackCount then
                return BatchStepSkipped()
            end

            -- Guild bank uses dedicated transfer APIs
            if isGuildMode then
                local canTransfer = ResolveGuildBankTransferDecision(guildTransferMode, bagId, slotIndex)
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
                if not IsDepositSupportedForBank(bagId, slotIndex, transferDestinationBankBag) then
                    return BatchStepSkipped()
                end

                local targetBag = ResolveDepositTargetBag(bagId, slotIndex, transferDestinationBankBag)
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
        end,
        onComplete = function()
            self:ExitSelectionMode()
        end,
        actionName = actionName,
        options = BANK_TRANSFER_BATCH_OPTIONS,
    })
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
    local transferState = BETTERUI.Banking.GetTransferState()
    local transferDestinationBankBag = transferState.depositTargetBag
    local isGuildMode = transferState.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
    local guildTransferMode = isDepositMode and LIST_DEPOSIT or LIST_WITHDRAW
    local transferCount = 0
    local firstTransferDeniedLabel = nil

    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local canTransfer = not isDepositMode or IsDepositSupportedForBank(bagId, slotIndex, transferDestinationBankBag)
            if isGuildMode then
                local allowed, _, denialText = ResolveGuildBankTransferDecision(guildTransferMode, bagId, slotIndex)
                canTransfer = allowed
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
                            guildTransferMode,
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
