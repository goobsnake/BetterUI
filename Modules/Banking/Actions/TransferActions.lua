local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT
local _pendingTransfers = {}
local PENDING_TRANSFER_TIMEOUT_MS = 5000
local PENDING_TRANSFER_SOURCE_EMPTY_SETTLE_MS = 250
local PENDING_TRANSFER_SETTLE_SWEEP_MS = PENDING_TRANSFER_TIMEOUT_MS - PENDING_TRANSFER_SOURCE_EMPTY_SETTLE_MS
local MarkTransferPending
local SweepStaleTransfers
local MaybeRefreshAfterTransfer
local IsActiveBankingWindow
local ScheduleTransferSweeps

local function BeginBankTransferFlow(message, data)
    local L = BETTERUI.Log
    if L and L.IsActive and L.IsActive() and L.FlowBegin then
        return L.FlowBegin("bankTransfer", L.CATEGORY.TRANSFER, message, data)
    end
    return nil
end

local function EndBankTransferFlow(flow, message, data)
    local L = BETTERUI.Log
    if flow and L and L.FlowEnd then
        L.FlowEnd(flow, L.CATEGORY.TRANSFER, message, data)
    end
end

local function GetTransferItemName(bag, slot)
    if not (bag and slot and type(GetItemName) == "function") then
        return nil
    end
    local ok, name = pcall(GetItemName, bag, slot)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

local function GetTransferItemSummary(bag, slot)
    if not (bag and slot) then
        return nil
    end
    local L = BETTERUI.Log
    if L and L.DescribeItem then
        return L.DescribeItem({ bagId = bag, slotIndex = slot }, "item")
    end
    return GetTransferItemName(bag, slot)
end

local function TransferData(bag, slot, data)
    data = data or {}
    if bag ~= nil then data.fromBag = bag end
    if slot ~= nil then data.fromSlot = slot end
    data.item = GetTransferItemSummary(bag, slot)
    return data
end

local function TraceBankTransfer(event, phase, bag, slot, data, level)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    L.TraceEvent(L.CATEGORY.TRANSFER, event, phase, TransferData(bag, slot, data or {}), level)
end

local function WarnBankTransferBlocked(reason, bag, slot, extra)
    local L = BETTERUI.Log
    if not (L and L.Warn) then return end
    extra = TransferData(bag, slot, extra or {})
    extra.reason = reason
    TraceBankTransfer("bank.item_transfer", "blocked", bag, slot, extra)
    L.Warn(L.CATEGORY.TRANSFER, "bank transfer blocked", extra)
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

local function RefreshBankListAfterTransfer(self, delayMs, flow, options)
    options = options or {}
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

            local activeWindow = BETTERUI.Banking and BETTERUI.Banking.Window or nil
            local inactiveWindow = not IsActiveBankingWindow(self)
            local staleWindow = options.requireActiveWindow == true and activeWindow ~= self
            if inactiveWindow or staleWindow then
                if self._moveCoalesceSuppressionToken == myToken then
                    self._moveCoalesceSuppressionToken = nil
                    self:SetListUpdatesSuppressed(false)
                end
                if BETTERUI.Log then
                    BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank transfer list refresh skipped", {
                        flow = flow,
                        reason = inactiveWindow and "inactiveWindow" or "staleWindow",
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
                coalesce = true,
                flow = flow,
                source = "bankTransfer",
                reason = "moveCoalesce",
                token = myToken,
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

function IsActiveBankingWindow(window)
    if not window then
        return false
    end
    if type(window.IsSceneShowing) == "function" then
        local ok, isShowing = pcall(function() return window:IsSceneShowing() end)
        if ok then
            return isShowing == true
        end
    end
    local utils = BETTERUI and BETTERUI.Utils or nil
    local isBankingSceneShowing = utils and utils.IsBankingSceneShowing or nil
    if type(isBankingSceneShowing) == "function" then
        local ok, isShowing = pcall(isBankingSceneShowing)
        if ok then
            return isShowing == true
        end
    end
    return false
end

local function ExecuteDirectTransfer(bag, index, data)
    data = data or {}
    data.transferPath = "directCursor"
    local flow = data.flow or BeginBankTransferFlow("bank transfer direct requested", TransferData(bag, index, data))
    data.flow = flow
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
        EndBankTransferFlow(flow, "bank transfer direct pickup failed", TransferData(bag, index, data))
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
        EndBankTransferFlow(flow, "bank transfer direct place failed", TransferData(bag, index, data))
        return false, "place_failed"
    end

    MarkTransferPending(bag, index, flow)
    local window = BETTERUI.Banking and BETTERUI.Banking.Window or nil
    local refreshScheduled = false
    local refreshReason = window and "inactiveWindow" or "missingWindow"
    TraceBankTransfer("bank.item_transfer", "requested", bag, index, data)
    EndBankTransferFlow(flow, "bank transfer direct requested", TransferData(bag, index, data))
    if IsActiveBankingWindow(window) and MaybeRefreshAfterTransfer then
        refreshScheduled, refreshReason = MaybeRefreshAfterTransfer(window, flow, { requireActiveWindow = true })
    end
    TraceBankTransfer("bank.item_transfer", "refresh_decision", bag, index, {
        transferPath = data.transferPath,
        mode = data.mode,
        guild = data.guild,
        toBag = data.toBag,
        refreshScheduled = refreshScheduled,
        refreshReason = refreshReason,
        suppressed = window and window._suppressListUpdates == true or false,
    })
    ScheduleTransferSweeps()
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

function MaybeRefreshAfterTransfer(self, flow, options)
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
    RefreshBankListAfterTransfer(self, 100, flow, options)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank transfer list refresh scheduled", {
            flow = flow,
            delayMs = 100,
            mode = self and self.currentMode,
        })
    end
    return true, "scheduled"
end

local function MakeTransferKey(bagId, slotIndex)
    return bagId .. ":" .. slotIndex
end

local function PendingTimestamp(entry)
    if type(entry) == "table" then return entry.timestamp end
    return entry
end

local function PendingFlow(entry)
    if type(entry) == "table" then return entry.flow end
    return nil
end

local function CountPendingTransfersRaw()
    local count = 0
    for _ in pairs(_pendingTransfers) do count = count + 1 end
    return count
end

local function WatchdogExpectTransfer(key, bagId, slotIndex, flow)
    local watchdog = BETTERUI.CIM and BETTERUI.CIM.Watchdog
    if watchdog and type(watchdog.Expect) == "function" then
        pcall(watchdog.Expect, "bank.transfer", key, PENDING_TRANSFER_TIMEOUT_MS, {
            bagId = bagId,
            slotIndex = slotIndex,
            flow = flow,
        })
    end
end

local function WatchdogResolveTransfer(key, outcome)
    local watchdog = BETTERUI.CIM and BETTERUI.CIM.Watchdog
    if watchdog and type(watchdog.Resolve) == "function" then
        pcall(watchdog.Resolve, "bank.transfer", key, outcome)
    end
end

local function IsSourceSlotEmpty(bagId, slotIndex)
    if bagId == nil or slotIndex == nil or type(GetSlotStackSize) ~= "function" then
        return false
    end
    local ok, stackCount = pcall(GetSlotStackSize, bagId, slotIndex)
    return ok and tonumber(stackCount) ~= nil and tonumber(stackCount) <= 0
end

local function TrySettleClearedSource(key, entry, bagId, slotIndex, now, source)
    local timestamp = PendingTimestamp(entry)
    if not timestamp then
        return false
    end
    local ageMs = now - timestamp
    if ageMs < PENDING_TRANSFER_SOURCE_EMPTY_SETTLE_MS or not IsSourceSlotEmpty(bagId, slotIndex) then
        return false
    end

    _pendingTransfers[key] = nil
    WatchdogResolveTransfer(key, "confirmed")
    TraceBankTransfer("bank.item_transfer", "confirmed", bagId, slotIndex, {
        source = source,
        reason = "source_empty",
        ageMs = ageMs,
        flow = PendingFlow(entry),
        pendingRemaining = CountPendingTransfersRaw(),
    }, BETTERUI.Log and BETTERUI.Log.LEVEL and BETTERUI.Log.LEVEL.INFO or nil)
    return true
end

function ScheduleTransferSweeps()
    if not (BETTERUI.Banking.Tasks and BETTERUI.Banking.Tasks.Schedule) then
        return
    end
    BETTERUI.Banking.Tasks:Schedule("transferSettleSweep", PENDING_TRANSFER_SETTLE_SWEEP_MS, SweepStaleTransfers)
    BETTERUI.Banking.Tasks:Schedule("transferStaleSweep", PENDING_TRANSFER_TIMEOUT_MS + 100, SweepStaleTransfers)
end

function MarkTransferPending(bagId, slotIndex, flow)
    if bagId == nil or slotIndex == nil then
        TraceBankTransfer("bank.item_transfer", "pending_mark_skipped", bagId, slotIndex, {
            reason = "missingSlot",
        })
        return
    end
    local key = MakeTransferKey(bagId, slotIndex)
    _pendingTransfers[key] = {
        timestamp = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0,
        flow = flow,
    }
    WatchdogExpectTransfer(key, bagId, slotIndex, flow)
    TraceBankTransfer("bank.item_transfer", "pending_marked", bagId, slotIndex, {
        pendingAfter = CountPendingTransfersRaw(),
        flow = flow,
    })
end

local function ClearTransferPending(bagId, slotIndex)
    if bagId == nil or slotIndex == nil then return false end
    local key = MakeTransferKey(bagId, slotIndex)
    local entry = _pendingTransfers[key]
    local hadPending = entry ~= nil
    _pendingTransfers[key] = nil
    if hadPending then
        WatchdogResolveTransfer(key, "cleared")
    end
    return hadPending, entry
end

local function IsTransferPending(bagId, slotIndex)
    local key = MakeTransferKey(bagId, slotIndex)
    local entry = _pendingTransfers[key]
    local timestamp = PendingTimestamp(entry)
    if not timestamp then
        return false
    end
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or timestamp
    if TrySettleClearedSource(key, entry, bagId, slotIndex, now, "IsTransferPending") then
        return false
    end
    if (now - timestamp) > PENDING_TRANSFER_TIMEOUT_MS then
        _pendingTransfers[key] = nil
        WatchdogResolveTransfer(key, "expired")
        TraceBankTransfer("bank.item_transfer", "expired", bagId, slotIndex, {
            source = "IsTransferPending",
            ageMs = now - timestamp,
            timeoutMs = PENDING_TRANSFER_TIMEOUT_MS,
            flow = PendingFlow(entry),
            pendingRemaining = CountPendingTransfersRaw(),
        }, BETTERUI.Log and BETTERUI.Log.LEVEL and BETTERUI.Log.LEVEL.WARN or nil)
        return false
    end
    return true
end

function SweepStaleTransfers()
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    for key, entry in pairs(_pendingTransfers) do
        local timestamp = PendingTimestamp(entry)
        local bagId, slotIndex = key:match("^([^:]+):([^:]+)$")
        bagId = tonumber(bagId)
        slotIndex = tonumber(slotIndex)
        if TrySettleClearedSource(key, entry, bagId, slotIndex, now, "SweepStaleTransfers") then
            -- settled by source-slot state
        elseif (now - timestamp) > PENDING_TRANSFER_TIMEOUT_MS then
            _pendingTransfers[key] = nil
            WatchdogResolveTransfer(key, "expired")
            TraceBankTransfer("bank.item_transfer", "expired", bagId, slotIndex, {
                source = "SweepStaleTransfers",
                ageMs = now - timestamp,
                timeoutMs = PENDING_TRANSFER_TIMEOUT_MS,
                flow = PendingFlow(entry),
                pendingRemaining = CountPendingTransfersRaw(),
            }, BETTERUI.Log and BETTERUI.Log.LEVEL and BETTERUI.Log.LEVEL.WARN or nil)
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
    return CountPendingTransfersRaw()
end

local function RequestMoveAndRefresh(self, fromBag, fromBagIndex, toBag, toBagIndex, quantity)
    TraceBankTransfer("bank.item_transfer", "move_requested", fromBag, fromBagIndex, {
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
    MarkTransferPending(fromBag, fromBagIndex, flow)
    if not CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagIndex, quantity) then
        ClearTransferPending(fromBag, fromBagIndex)
        WarnBankTransferBlocked("request_move_failed", fromBag, fromBagIndex, {
            toBag = toBag,
            toSlot = toBagIndex,
            quantity = quantity,
            mode = self and self.currentMode,
        })
        TraceBankTransfer("bank.item_transfer", "failed", fromBag, fromBagIndex, {
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
    ScheduleTransferSweeps()
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
        TraceBankTransfer("bank.item_transfer", "blocked", fromBag, fromBagIndex, {
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

    MarkTransferPending(fromBag, fromBagIndex, flow)
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
    ScheduleTransferSweeps()
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
        local cleared, pendingEntry = ClearTransferPending(bagId, slotIndex)
        local pendingAfter = CountPendingTransfersRaw()
        if cleared then
            TraceBankTransfer("bank.item_transfer", "confirmed", bagId, slotIndex, {
                source = "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
                pendingRemaining = pendingAfter,
                flow = PendingFlow(pendingEntry),
            }, BETTERUI.Log and BETTERUI.Log.LEVEL and BETTERUI.Log.LEVEL.INFO or nil)
        end
        TraceBankTransfer("bank.item_transfer", "pending_cleared", bagId, slotIndex, {
            source = "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
            cleared = cleared == true,
            pendingAfter = pendingAfter,
            flow = PendingFlow(pendingEntry),
        })
    end
    local function OnGuildBankSlotUpdate(source)
        return function(_, slotId, addedByLocalPlayer, itemSoundCategory, isLastUpdateForMessage)
            TraceBankTransfer("bank.item_transfer", "guild_slot_update", BAG_GUILDBANK, slotId, {
                source = source,
                addedByLocalPlayer = addedByLocalPlayer,
                itemSoundCategory = itemSoundCategory,
                isLastUpdateForMessage = isLastUpdateForMessage,
                pendingBefore = BETTERUI.Banking.CountPendingTransfers and BETTERUI.Banking.CountPendingTransfers() or nil,
            })
            local cleared, pendingEntry = ClearTransferPending(BAG_GUILDBANK, slotId)
            local pendingAfter = CountPendingTransfersRaw()
            if cleared then
                TraceBankTransfer("bank.item_transfer", "confirmed", BAG_GUILDBANK, slotId, {
                    source = source,
                    pendingRemaining = pendingAfter,
                    flow = PendingFlow(pendingEntry),
                }, BETTERUI.Log and BETTERUI.Log.LEVEL and BETTERUI.Log.LEVEL.INFO or nil)
            end
            TraceBankTransfer("bank.item_transfer", "pending_cleared", BAG_GUILDBANK, slotId, {
                source = source,
                cleared = cleared == true,
                pendingAfter = pendingAfter,
                flow = PendingFlow(pendingEntry),
            })
        end
    end
    BETTERUI.CIM.EventRegistry.Register("Banking.TransferActions", "BetterUI_Banking_TransferActions_SlotUpdate",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySingleSlotUpdate)
    if EVENT_GUILD_BANK_ITEM_ADDED then
        BETTERUI.CIM.EventRegistry.Register("Banking.TransferActions", "BetterUI_Banking_TransferActions_GuildAdded",
            EVENT_GUILD_BANK_ITEM_ADDED, OnGuildBankSlotUpdate("EVENT_GUILD_BANK_ITEM_ADDED"))
    end
    if EVENT_GUILD_BANK_ITEM_REMOVED then
        BETTERUI.CIM.EventRegistry.Register("Banking.TransferActions", "BetterUI_Banking_TransferActions_GuildRemoved",
            EVENT_GUILD_BANK_ITEM_REMOVED, OnGuildBankSlotUpdate("EVENT_GUILD_BANK_ITEM_REMOVED"))
    end
    if EVENT_GUILD_BANK_UPDATED_QUANTITY then
        BETTERUI.CIM.EventRegistry.Register("Banking.TransferActions", "BetterUI_Banking_TransferActions_GuildQuantity",
            EVENT_GUILD_BANK_UPDATED_QUANTITY, OnGuildBankSlotUpdate("EVENT_GUILD_BANK_UPDATED_QUANTITY"))
    end
end
