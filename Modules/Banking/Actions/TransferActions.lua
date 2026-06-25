local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

local function BeginBankTransferFlow(message, data)
    local L = BETTERUI.Log
    if L and L.IsActive and L.IsActive() and L.FlowBegin then
        return L.FlowBegin("bankTransfer", L.CATEGORY.ACTION, message, data)
    end
    return nil
end

local function EndBankTransferFlow(flow, message, data)
    local L = BETTERUI.Log
    if flow and L and L.FlowEnd then
        L.FlowEnd(flow, L.CATEGORY.ACTION, message, data)
    end
end

local function GetTransferItemLink(bag, slot)
    if not (bag and slot and type(GetItemLink) == "function") then
        return nil
    end
    local ok, link = pcall(GetItemLink, bag, slot, LINK_STYLE_BRACKETS)
    if ok and type(link) == "string" and link ~= "" then
        return link
    end
    return nil
end

local function TransferData(bag, slot, data)
    data = data or {}
    if bag ~= nil then data.fromBag = bag end
    if slot ~= nil then data.fromSlot = slot end
    data.item = GetTransferItemLink(bag, slot)
    return data
end

local function TraceBankTransfer(event, phase, bag, slot, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    L.TraceEvent(L.CATEGORY.ACTION, event, phase, TransferData(bag, slot, data or {}))
end

local function WarnBankTransferBlocked(reason, bag, slot, extra)
    local L = BETTERUI.Log
    if not (L and L.Warn) then return end
    extra = TransferData(bag, slot, extra or {})
    extra.reason = reason
    TraceBankTransfer("bank.item_transfer", "blocked", bag, slot, extra)
    L.Warn(L.CATEGORY.ACTION, "bank transfer blocked", extra)
end

---@return BetterUIBankingTransferContext
local function ReadTransferContextSnapshot()
    local readTransferContextSnapshot = BETTERUI.Banking and BETTERUI.Banking.ReadTransferContextSnapshot or nil
    if type(readTransferContextSnapshot) == "function" then
        return readTransferContextSnapshot()
    end
    return {
        kind = BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK,
        interactionBag = BAG_BANK,
        depositTargetBag = BAG_BANK,
        withdrawSourceBags = { BAG_BANK, BAG_SUBSCRIBER_BANK },
        sourceIsFurnitureVault = false,
        targetIsFurnitureVault = false,
    }
end

local function RequireTransferService()
    local requireTransferService = BETTERUI.Banking and BETTERUI.Banking.RequireTransferService or nil
    if type(requireTransferService) ~= "function" then
        return nil, "transfer_service_unavailable"
    end
    return requireTransferService({
        "NotifyTransferDenied",
        "NotifyGuildBankTransferDenied",
        "CanDepositIntoBank",
    }, {
        createIfMissing = false,
    })
end

local function RefreshBankListAfterTransfer(self, delayMs, flow)
    local hadMoveSuppression = self._moveCoalesceSuppressionToken ~= nil
    local externalSuppressed = self._suppressListUpdates == true and not hadMoveSuppression
    self._moveCoalesceToken = (self._moveCoalesceToken or 0) + 1
    local myToken = self._moveCoalesceToken
    self:SetListUpdatesSuppressed(true)
    self._moveCoalesceSuppressionToken = externalSuppressed and nil or myToken
    if (externalSuppressed or hadMoveSuppression) and BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank transfer list refresh coalesced", {
            flow = flow,
            token = myToken,
            mode = self.currentMode,
            external = externalSuppressed,
        })
    end

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
            if externalSuppressed and self._suppressListUpdates == true then
                if BETTERUI.Log then
                    BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank transfer list refresh skipped", {
                        flow = flow,
                        reason = "externalSuppression",
                        token = myToken,
                        mode = self.currentMode,
                    })
                end
                return
            end

            if self._moveCoalesceSuppressionToken == myToken then
                self._moveCoalesceSuppressionToken = nil
                self:SetListUpdatesSuppressed(false)
            end

            if BETTERUI.Log then
                BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank transfer list refresh running", {
                    flow = flow,
                    token = myToken,
                    categoryKey = previousCategoryKey,
                    mode = self.currentMode,
                })
            end

            BETTERUI.Banking.RefreshWindowView(self, {
                preferredCategoryKey = previousCategoryKey,
            })

            if BETTERUI.Log then
                BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank transfer list refresh complete", {
                    flow = flow,
                    token = myToken,
                    categoryKey = previousCategoryKey,
                    mode = self.currentMode,
                })
            end
        end)
end

--- Finds the first empty slot in a personal or house bank bag.
--- Guild bank deposits are handled separately by MoveItem before this is called.
---@param targetBankBag number|nil Preferred destination bank bag
---@return integer? bag The bank bag ID, or nil if no space
---@return integer? slotIndex The empty slot index, or nil if no space
local function FindEmptySlotInBank(targetBankBag)
    if targetBankBag == nil then
        targetBankBag = ReadTransferContextSnapshot().depositTargetBag or BAG_BANK
    end

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
    local isActionableTransferEntry = BETTERUI.Banking and BETTERUI.Banking.IsActionableTransferEntry or nil
    if type(isActionableTransferEntry) == "function" then
        return isActionableTransferEntry(entryData)
    end

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
    local transferService = BETTERUI.Banking and BETTERUI.Banking.GetTransferService and BETTERUI.Banking.GetTransferService()
    if transferService and type(transferService.NotifyTransferDenied) == "function" then
        transferService.NotifyTransferDenied("Banking.TransferActions.Deposit", targetBankBag, denyReason)
    end
end

local function ExecuteDirectTransfer(bag, index, data)
    data = data or {}
    data.transferPath = "directCursor"
    TraceBankTransfer("bank.item_transfer", "pickup_before", bag, index, data)
    local pickupOk = CallSecureProtected("PickupInventoryItem", bag, index)
    TraceBankTransfer("bank.item_transfer", "pickup_after", bag, index, {
        transferPath = data.transferPath,
        mode = data.mode,
        guild = data.guild,
        toBag = data.toBag,
        pickupOk = pickupOk == true,
    })
    if not pickupOk then
        WarnBankTransferBlocked("pickup_failed", bag, index, data)
        return false, "pickup_failed"
    end

    TraceBankTransfer("bank.item_transfer", "place_before", bag, index, data)
    local placeOk = CallSecureProtected("PlaceInTransfer")
    TraceBankTransfer("bank.item_transfer", "place_after", bag, index, {
        transferPath = data.transferPath,
        mode = data.mode,
        guild = data.guild,
        toBag = data.toBag,
        placeOk = placeOk == true,
    })
    if not placeOk then
        local clearCursor = rawget(_G, "ClearCursor")
        if type(clearCursor) == "function" then pcall(clearCursor) end
        WarnBankTransferBlocked("place_failed", bag, index, data)
        return false, "place_failed"
    end

    TraceBankTransfer("bank.item_transfer", "requested", bag, index, data)
    return true
end

function BETTERUI.Banking.TryTransferInventorySlot(inventorySlot)
    if not inventorySlot then
        return false, "no_slot"
    end
    if not PLAYER_INVENTORY:IsBanking() then
        return false, "not_banking"
    end

    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local transferContext = ReadTransferContextSnapshot()
    local isGuildBankMode = transferContext.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "try transfer inventory slot", {
            bag = bag,
            index = index,
            isGuildBankMode = isGuildBankMode,
        })
    end
    local transferService, transferServiceReason = RequireTransferService()
    if not transferService then
        WarnBankTransferBlocked(transferServiceReason or "transfer_service_missing", bag, index, {
            mode = isGuildBankMode and "guild" or "bank",
        })
        return false, transferServiceReason
    end
    local isSourceFurnitureVault = IsFurnitureVault and IsFurnitureVault(bag)

    if bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK or IsHouseBankBag(bag) or isSourceFurnitureVault then
        if isGuildBankMode then
            local canTransfer, denyReason = transferService.NotifyGuildBankTransferDenied(
                "TryTransferItem:GuildWithdraw",
                LIST_WITHDRAW,
                bag,
                index
            )
            if not canTransfer then
                WarnBankTransferBlocked(denyReason or "guild_transfer_denied", bag, index, {
                    mode = LIST_WITHDRAW,
                    guild = true,
                })
                return false, denyReason
            end
        end

        if DoesBagHaveSpaceFor(BAG_BACKPACK, bag, index) then
            return ExecuteDirectTransfer(bag, index, {
                mode = LIST_WITHDRAW,
                guild = isGuildBankMode,
                toBag = BAG_BACKPACK,
            })
        end

        BETTERUI.CIM.UserNotify("TryTransferItem:Withdraw", SI_INVENTORY_ERROR_INVENTORY_FULL)
        WarnBankTransferBlocked("inventory_full", bag, index, { mode = LIST_WITHDRAW })
        return false, "inventory_full"
    end

    local bankingBag = transferContext.depositTargetBag
    if isGuildBankMode then
        -- depositTargetBag resolves through GetBankingBag(), which never reports
        -- BAG_GUILDBANK; validate guild deposits (rules and capacity) against the
        -- guild bank bag instead of the personal bank.
        bankingBag = BAG_GUILDBANK
        local canTransfer, denyReason = transferService.NotifyGuildBankTransferDenied(
            "TryTransferItem:GuildDeposit",
            LIST_DEPOSIT,
            bag,
            index
        )
        if not canTransfer then
            WarnBankTransferBlocked(denyReason or "guild_transfer_denied", bag, index, {
                mode = LIST_DEPOSIT,
                guild = true,
            })
            return false, denyReason
        end
    end

    local canDeposit, denyReason = transferService.CanDepositIntoBank(bag, index, bankingBag)
    if not canDeposit then
        transferService.NotifyTransferDenied("TryTransferItem:Deposit", bankingBag, denyReason)
        WarnBankTransferBlocked(denyReason or "deposit_denied", bag, index, { mode = LIST_DEPOSIT, toBag = bankingBag })
        return false, denyReason
    end

    local canAlsoBePlacedInSubscriberBank = bankingBag == BAG_BANK
    local resolvedDepositBag = nil
    if DoesBagHaveSpaceFor(bankingBag, bag, index) then
        resolvedDepositBag = bankingBag
    elseif canAlsoBePlacedInSubscriberBank and DoesBagHaveSpaceFor(BAG_SUBSCRIBER_BANK, bag, index) then
        resolvedDepositBag = BAG_SUBSCRIBER_BANK
    end
    if resolvedDepositBag then
        return ExecuteDirectTransfer(bag, index, {
            mode = LIST_DEPOSIT,
            guild = isGuildBankMode,
            toBag = resolvedDepositBag,
        })
    end

    if isGuildBankMode then
        -- Guild bank is full; the ESO-Plus/subscriber-bank messaging below only
        -- applies to the personal bank.
        BETTERUI.CIM.UserNotify("TryTransferItem:GuildDeposit", SI_INVENTORY_ERROR_BANK_FULL)
        WarnBankTransferBlocked("bank_full", bag, index, { mode = LIST_DEPOSIT, toBag = BAG_GUILDBANK })
        return false, "bank_full"
    end
    if canAlsoBePlacedInSubscriberBank and not IsESOPlusSubscriber() then
        if GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK) > 0 then
            TriggerTutorial(TUTORIAL_TRIGGER_BANK_OVERFULL)
        else
            TriggerTutorial(TUTORIAL_TRIGGER_BANK_FULL_NO_ESO_PLUS)
        end
    end
    ZO_AlertEvent(EVENT_BANK_IS_FULL)
    WarnBankTransferBlocked("bank_full", bag, index, { mode = LIST_DEPOSIT, toBag = bankingBag })
    return false, "bank_full"
end

local function MaybeRefreshAfterTransfer(self, flow)
    local showingDialog = false
    if type(ZO_Dialogs_IsShowingDialog) == "function" then
        local ok, result = pcall(ZO_Dialogs_IsShowingDialog)
        showingDialog = ok and result == true
    end
    if showingDialog then
        if BETTERUI.Log then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank transfer list refresh skipped", {
                flow = flow,
                reason = "dialogShowing",
                mode = self and self.currentMode,
            })
        end
        return false, "dialogShowing"
    end
    RefreshBankListAfterTransfer(self, 100, flow)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank transfer list refresh scheduled", {
            flow = flow,
            delayMs = 100,
            mode = self and self.currentMode,
        })
    end
    return true, "scheduled"
end

local _pendingTransfers = {}
local PENDING_TRANSFER_TIMEOUT_MS = 5000

local function MakeTransferKey(bagId, slotIndex)
    return bagId .. ":" .. slotIndex
end

local function MarkTransferPending(bagId, slotIndex)
    _pendingTransfers[MakeTransferKey(bagId, slotIndex)] = GetFrameTimeMilliseconds()
end

local function ClearTransferPending(bagId, slotIndex)
    _pendingTransfers[MakeTransferKey(bagId, slotIndex)] = nil
end

local function IsTransferPending(bagId, slotIndex)
    local timestamp = _pendingTransfers[MakeTransferKey(bagId, slotIndex)]
    if not timestamp then
        return false
    end
    if (GetFrameTimeMilliseconds() - timestamp) > PENDING_TRANSFER_TIMEOUT_MS then
        _pendingTransfers[MakeTransferKey(bagId, slotIndex)] = nil
        return false
    end
    return true
end

local function SweepStaleTransfers()
    local now = GetFrameTimeMilliseconds()
    for key, timestamp in pairs(_pendingTransfers) do
        if (now - timestamp) > PENDING_TRANSFER_TIMEOUT_MS then
            _pendingTransfers[key] = nil
        end
    end
end

function BETTERUI.Banking.IsTransferPending(bagId, slotIndex)
    return IsTransferPending(bagId, slotIndex)
end

function BETTERUI.Banking.SweepStaleTransfers()
    SweepStaleTransfers()
end

function BETTERUI.Banking.CountPendingTransfers()
    if GetFrameTimeMilliseconds then SweepStaleTransfers() end
    local count = 0
    for _ in pairs(_pendingTransfers) do count = count + 1 end
    return count
end

local function RequestMoveAndRefresh(self, fromBag, fromBagIndex, toBag, toBagIndex, quantity)
    TraceBankTransfer("bank.item_transfer", "requested", fromBag, fromBagIndex, {
        toBag = toBag,
        toSlot = toBagIndex,
        quantity = quantity,
        mode = self and self.currentMode,
    })
    local flow = BeginBankTransferFlow("bank transfer move requested", TransferData(fromBag, fromBagIndex, {
        toBag = toBag,
        toSlot = toBagIndex,
        quantity = quantity,
        mode = self and self.currentMode,
    }))
    MarkTransferPending(fromBag, fromBagIndex)
    if not CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagIndex, quantity) then
        ClearTransferPending(fromBag, fromBagIndex)
        WarnBankTransferBlocked("request_move_failed", fromBag, fromBagIndex, {
            toBag = toBag,
            toSlot = toBagIndex,
            quantity = quantity,
            mode = self and self.currentMode,
        })
        TraceBankTransfer("bank.item_transfer", "request_failed", fromBag, fromBagIndex, {
            toBag = toBag,
            toSlot = toBagIndex,
            quantity = quantity,
            mode = self and self.currentMode,
            reason = "request_move_failed",
        })
        EndBankTransferFlow(flow, "bank transfer move failed", TransferData(fromBag, fromBagIndex, {
            toBag = toBag,
            toSlot = toBagIndex,
            quantity = quantity,
        }))
        local stringId = rawget(_G, "SI_BETTERUI_ITEM_MOVE_FAILED")
        BETTERUI.CIM.UserNotify("TransferActions:RequestMoveItem",
            stringId and GetString(stringId) or "Item move request failed")
        return false
    end
    BETTERUI.Banking.Tasks:Schedule("transferStaleSweep", PENDING_TRANSFER_TIMEOUT_MS + 100, SweepStaleTransfers)
    local refreshScheduled, refreshReason = MaybeRefreshAfterTransfer(self, flow)
    TraceBankTransfer("bank.item_transfer", "refresh_decision", fromBag, fromBagIndex, {
        toBag = toBag,
        toSlot = toBagIndex,
        quantity = quantity,
        mode = self and self.currentMode,
        pending = BETTERUI.Banking.CountPendingTransfers and BETTERUI.Banking.CountPendingTransfers() or nil,
        refreshScheduled = refreshScheduled,
        refreshReason = refreshReason,
        suppressed = self and self._suppressListUpdates == true,
    })
    EndBankTransferFlow(flow, "bank transfer refresh decision", TransferData(fromBag, fromBagIndex, {
        toBag = toBag,
        toSlot = toBagIndex,
        pending = BETTERUI.Banking.CountPendingTransfers and BETTERUI.Banking.CountPendingTransfers() or nil,
        refreshScheduled = refreshScheduled,
        refreshReason = refreshReason,
        suppressed = self and self._suppressListUpdates == true,
    }))
    return true
end

local function ResolveTransferDestinationSlot(fromBag, fromBagIndex, toBag)
    local itemLink = GetItemLink(fromBag, fromBagIndex)
    if itemLink and itemLink ~= "" then
        local stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(toBag, itemLink)
        if stackSlot ~= nil then
            return stackSlot
        end
    end
    return FindFirstEmptySlotInBag(toBag)
end

local function ExecuteGuildBankMove(self, transferService, fromBag, fromBagIndex)
    local mode = self.currentMode == LIST_WITHDRAW and LIST_WITHDRAW or LIST_DEPOSIT
    TraceBankTransfer("bank.item_transfer", "guild_requested", fromBag, fromBagIndex, {
        mode = mode,
        guild = true,
    })
    local flow = BeginBankTransferFlow("guild bank transfer requested", TransferData(fromBag, fromBagIndex, {
        mode = mode,
    }))
    local canTransfer, denyReason = transferService.NotifyGuildBankTransferDenied("TransferActions:GuildTransfer", mode, fromBag,
        fromBagIndex)
    if not canTransfer then
        WarnBankTransferBlocked(denyReason or "guild_transfer_denied", fromBag, fromBagIndex, {
            mode = mode,
            guild = true,
        })
        TraceBankTransfer("bank.item_transfer", "denied", fromBag, fromBagIndex, {
            mode = mode,
            guild = true,
            reason = denyReason or "guild_transfer_denied",
        })
        EndBankTransferFlow(flow, "guild bank transfer denied", TransferData(fromBag, fromBagIndex, {
            mode = mode,
            reason = denyReason,
        }))
        return
    end

    local requested = false
    local denyReason
    if self.currentMode == LIST_WITHDRAW then
        if ResolveTransferDestinationSlot(fromBag, fromBagIndex, BAG_BACKPACK) ~= nil then
            local soundCategory = GetItemSoundCategory(fromBag, fromBagIndex)
            PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
            TransferFromGuildBank(fromBagIndex)
            requested = true
        else
            denyReason = "inventoryFull"
            BETTERUI.CIM.UserNotify("TransferActions:GuildWithdraw", SI_INVENTORY_ERROR_INVENTORY_FULL)
        end
    else
        if ResolveTransferDestinationSlot(fromBag, fromBagIndex, BAG_GUILDBANK) ~= nil then
            local soundCategory = GetItemSoundCategory(fromBag, fromBagIndex)
            PlayItemSound(soundCategory, ITEM_SOUND_ACTION_PICKUP)
            TransferToGuildBank(fromBag, fromBagIndex)
            requested = true
        else
            denyReason = "guildBankFull"
            BETTERUI.CIM.UserNotify("TransferActions:GuildDeposit", SI_INVENTORY_ERROR_BANK_FULL)
        end
    end

    if not requested then
        TraceBankTransfer("bank.item_transfer", "blocked", fromBag, fromBagIndex, {
            mode = mode,
            guild = true,
            reason = denyReason,
        })
        EndBankTransferFlow(flow, "guild bank transfer blocked", TransferData(fromBag, fromBagIndex, {
            mode = mode,
            reason = denyReason,
        }))
        return
    end

    local refreshScheduled, refreshReason = MaybeRefreshAfterTransfer(self, flow)
    TraceBankTransfer("bank.item_transfer", "refresh_decision", fromBag, fromBagIndex, {
        mode = mode,
        guild = true,
        refreshScheduled = refreshScheduled,
        refreshReason = refreshReason,
        suppressed = self and self._suppressListUpdates == true,
    })
    EndBankTransferFlow(flow, "guild bank transfer refresh decision", TransferData(fromBag, fromBagIndex, {
        mode = mode,
        refreshScheduled = refreshScheduled,
        refreshReason = refreshReason,
        suppressed = self and self._suppressListUpdates == true,
    }))
end

local function ExecutePersonalOrHouseMove(self, transferContext, transferService, fromBag, fromBagIndex, fromBagItemLink,
                                          quantity)
    local isDepositing = (self.currentMode == LIST_DEPOSIT)
    local targetBankBag = transferContext.depositTargetBag
    local toBag
    local toBagEmptyIndex
    local toBagIndex

    if not isDepositing then
        toBag = BAG_BACKPACK
        toBagEmptyIndex = FindFirstEmptySlotInBag(toBag)
    else
        local canDeposit, denyReason = transferService.CanDepositIntoBank(fromBag, fromBagIndex, targetBankBag)
        if not canDeposit then
            NotifyDepositBlocked(targetBankBag, denyReason)
            WarnBankTransferBlocked(denyReason or "deposit_denied", fromBag, fromBagIndex, {
                mode = LIST_DEPOSIT,
                toBag = targetBankBag,
            })
            return
        end
        toBag, toBagEmptyIndex = FindEmptySlotInBank(targetBankBag)
    end

    if toBagEmptyIndex ~= nil then
        RequestMoveAndRefresh(self, fromBag, fromBagIndex, toBag, toBagEmptyIndex, quantity)
        return
    end

    if toBag ~= nil then
        local errorStringId = (toBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
        toBagIndex = BETTERUI.CIM.Utils.FindStackableSlotInBag(toBag, fromBagItemLink)
        if toBagIndex then
            RequestMoveAndRefresh(self, fromBag, fromBagIndex, toBag, toBagIndex, quantity)
        else
            BETTERUI.CIM.UserNotify("TransferActions:NoStackSlot", errorStringId)
            WarnBankTransferBlocked(errorStringId == SI_INVENTORY_ERROR_INVENTORY_FULL and "inventory_full" or "bank_full",
                fromBag, fromBagIndex, { mode = self.currentMode, toBag = toBag })
        end
        return
    end

    -- The subscriber bank only accepts items while an ESO Plus subscription is active.
    local banks = { BAG_BANK }
    if IsESOPlusSubscriber() then
        banks[#banks + 1] = BAG_SUBSCRIBER_BANK
    end
    if transferContext.kind == BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK then
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
        RequestMoveAndRefresh(self, fromBag, fromBagIndex, toBag, toBagIndex, quantity)
        return
    end

    local errorStringId = (toBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
    BETTERUI.CIM.UserNotify("TransferActions:NoBankSlot", errorStringId)
    WarnBankTransferBlocked(errorStringId == SI_INVENTORY_ERROR_INVENTORY_FULL and "inventory_full" or "bank_full",
        fromBag, fromBagIndex, { mode = self.currentMode, toBag = toBag or targetBankBag })
end

---@param list table The parametric list to get selected data from
---@param quantity integer? Number of items to move (default 1)
function BETTERUI.Banking.Class:MoveItem(list, quantity)
    local selectedData = list and list:GetSelectedData() or nil
    local resolveListEntrySlot = BETTERUI.Banking and BETTERUI.Banking.ResolveListEntrySlot or nil
    local fromBag = nil
    local fromBagIndex = nil
    if type(resolveListEntrySlot) == "function" then
        fromBag, fromBagIndex = resolveListEntrySlot(selectedData)
    elseif selectedData then
        fromBag = selectedData.bagId
        fromBagIndex = selectedData.slotIndex
    end

    if fromBag == nil or fromBagIndex == nil then
        -- Nothing to move (empty list, header row, or currency row)
        TraceBankTransfer("bank.item_transfer", "skipped", nil, nil, {
            reason = "no_slot",
            mode = self and self.currentMode,
            selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(list, "selection") or nil,
        })
        return
    end

    local fromBagItemLink = GetItemLink(fromBag, fromBagIndex)
    local transferContext = ReadTransferContextSnapshot()
    local transferService, transferServiceReason = RequireTransferService()
    if not transferService then
        TraceBankTransfer("bank.item_transfer", "skipped", fromBag, fromBagIndex, {
            reason = transferServiceReason or "transfer_service_missing",
            mode = self and self.currentMode,
        })
        return false, transferServiceReason
    end
    if quantity == nil then
        quantity = 1
    end

    local isGuildBank = transferContext.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "move item", {
            fromBag = fromBag,
            fromBagIndex = fromBagIndex,
            quantity = quantity,
            isGuildBank = isGuildBank,
        })
    end

    TraceBankTransfer("bank.item_transfer", "route", fromBag, fromBagIndex, {
        mode = self and self.currentMode,
        quantity = quantity,
        guild = isGuildBank == true,
        context = transferContext and transferContext.kind,
    })

    -- Guild bank uses dedicated transfer APIs instead of RequestMoveItem
    if isGuildBank then
        ExecuteGuildBankMove(self, transferService, fromBag, fromBagIndex)
        return
    end

    ExecutePersonalOrHouseMove(self, transferContext, transferService, fromBag, fromBagIndex, fromBagItemLink, quantity)
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
    local bagId, slotIndex
    if BETTERUI.Banking.ResolveListEntrySlot then
        bagId, slotIndex = BETTERUI.Banking.ResolveListEntrySlot(targetData)
    end
    bagId = bagId or targetData.bagId
    slotIndex = slotIndex or targetData.slotIndex
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "bank action dialog shown", TransferData(bagId, slotIndex, {
            mode = self.currentMode,
        }))
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

-- Register for inventory slot updates to clear pending transfer markers.
-- This prevents the deposit keybind from staying disabled after the server confirms the move.
if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.EventRegistry then
    local function OnInventorySingleSlotUpdate(_, bagId, slotIndex)
        TraceBankTransfer("bank.item_transfer", "slot_update", bagId, slotIndex, {
            source = "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
            pendingBefore = BETTERUI.Banking.CountPendingTransfers and BETTERUI.Banking.CountPendingTransfers() or nil,
        })
        ClearTransferPending(bagId, slotIndex)
        TraceBankTransfer("bank.item_transfer", "pending_cleared", bagId, slotIndex, {
            source = "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
            pendingAfter = BETTERUI.Banking.CountPendingTransfers and BETTERUI.Banking.CountPendingTransfers() or nil,
        })
    end
    BETTERUI.CIM.EventRegistry.Register("Banking.TransferActions", "BetterUI_Banking_TransferActions_SlotUpdate",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySingleSlotUpdate)
end
