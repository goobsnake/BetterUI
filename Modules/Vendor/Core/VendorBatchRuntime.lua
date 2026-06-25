BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.BatchRuntime = Vendor.BatchRuntime or {}
local BatchRuntime = Vendor.BatchRuntime
local Internal = BatchRuntime._internals or {}
BatchRuntime._internals = Internal

local MODE = assert(Vendor.MODE, "Vendor mode constants must load before batch runtime")

local function GetBatchConfig()
    local batchConfig = BETTERUI.CIM and BETTERUI.CIM.BatchConfig
    assert(batchConfig, "CIM batch config must load before vendor batch runtime")
    return batchConfig
end

local VendorBatchOptionsTemplate = nil

local function GetVendorBatchOptionsTemplate()
    if VendorBatchOptionsTemplate then
        return VendorBatchOptionsTemplate
    end

    local batchConfig = GetBatchConfig()
    VendorBatchOptionsTemplate = batchConfig.ComposeBatchOptions(
        batchConfig.WithServer({
            serverBound = true,
        }),
        batchConfig.WithAck({
            awaitInventoryAck = true,
        }),
        batchConfig.WithPacing({
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

    return VendorBatchOptionsTemplate
end

---@param batchOptions table|nil
---@return BatchOptions
local function ResolveBatchOptions(batchOptions)
    local batchConfig = GetBatchConfig()
    if type(batchOptions) ~= "table" then
        return batchConfig.ComposeBatchOptions(GetVendorBatchOptionsTemplate())
    end

    return batchConfig.ComposeBatchOptions(GetVendorBatchOptionsTemplate(), batchOptions)
end
Internal.ResolveBatchOptions = ResolveBatchOptions

local function AuthorizeVendorInventoryAction(actionType, bagId, slotIndex)
    local authorizeInventoryAction = Vendor.AuthorizeInventoryAction
    assert(type(authorizeInventoryAction) == "function",
        "Vendor.AuthorizeInventoryAction must load before Vendor batch inventory actions")
    local allowed, reason = authorizeInventoryAction(actionType, bagId, slotIndex, Vendor.instance)
    return allowed == true, reason
end

local function IsSellMode(mode)
    return mode == MODE.SELL or (MODE.SELL_VENGEANCE ~= nil and mode == MODE.SELL_VENGEANCE)
end

--- True when carried gold is at the wallet maximum. Selling for gold while at
--- the cap fails server-side, so a regular-sell batch must halt before issuing
--- doomed SellInventoryItem calls. Mirrors SellComponent's IsAtGoldCap (and the
--- native ZO_GamepadStoreSell:CanSell gate); fence sell/launder do NOT use this
--- because stolen-goods sales do not credit the seller's gold wallet.
---@return boolean atCap
local function IsAtGoldCap()
    if type(GetMaxPossibleCurrency) ~= "function" then
        return false
    end
    local carried = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    local maxPossible = GetMaxPossibleCurrency(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    return maxPossible > 0 and carried >= maxPossible
end

local function DescribeBatchItem(ds)
    local L = BETTERUI and BETTERUI.Log
    if L and L.DescribeItem then
        return L.DescribeItem(ds, "batch")
    end
    return ds and (ds.name or ds.itemLink) or nil
end

local function TraceVendorBatch(event, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then
        return
    end

    data = data or {}
    data.module = data.module or "Vendor"
    data.scene = data.scene or rawget(_G, "BETTERUI_VENDOR_SCENE_NAME") or "BETTERUI_VENDOR"
    data.currentScene = data.currentScene or (SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName()) or nil
    data.feature = data.feature or "vendor-batch"
    data.fn = data.fn or "Vendor.BatchRuntime"
    data.functionName = data.functionName or data.fn
    data.modeName = data.modeName or (data.mode ~= nil and Vendor.ResolveModeName and Vendor.ResolveModeName(data.mode)) or nil
    data.batchProcessing = Vendor._batchProcessing == true
    L.TraceEvent(L.CATEGORY.BATCH, event, phase, data)
end

local function NormalizeBatchRuntimeRequest(request)
    assert(type(request) == "table", "Vendor batch runtime expects BetterUIVendorBatchRequest table")
    assert(request.batchOptions == nil,
        "Vendor batch runtime expects request.options; legacy request.batchOptions is not part of the runtime contract")
    return {
        mode = request.mode,
        items = request.items or {},
        onComplete = request.onComplete,
        options = request.options,
        actionName = request.actionName,
    }
end
---@return BatchOptions
function BatchRuntime.GetDefaultBatchOptions()
    return GetBatchConfig().NormalizeBatchOptions(GetVendorBatchOptionsTemplate())
end

---@param mode number
---@param itemData table
---@return BetterUIBatchStepResult
function BatchRuntime.ExecuteBatchAction(mode, itemData)
    local batchConfig = GetBatchConfig()
    local batchStepHandled = batchConfig.BatchStepHandled
    local batchStepQueued = batchConfig.BatchStepQueued
    local batchStepSkipped = batchConfig.BatchStepSkipped
    local batchStepStopped = batchConfig.BatchStepStopped

    local ds = itemData and (itemData.dataSource or itemData) or nil
    if not ds then
        TraceVendorBatch("vendor.batch_step", "skipped", { fn = "BatchRuntime.ExecuteBatchAction", mode = mode, reason = "missingData" })
        return batchStepHandled()
    end

    if mode == MODE.BUY then
        local entryIndex = ds.entryIndex or ds.slotIndex
        if not entryIndex then
            TraceVendorBatch("vendor.batch_step", "skipped", { fn = "BatchRuntime.ExecuteBatchAction", mode = mode, reason = "missingEntryIndex", item = DescribeBatchItem(ds) })
            return batchStepHandled()
        end
        -- Locked entries (missing requirements, already-owned collectible, ...)
        -- cannot be purchased; mirror BuyComponent's single-buy guard so the
        -- batch skips them instead of attempting a doomed BuyStoreItem.
        if ds.meetsRequirementsToBuy == false then
            TraceVendorBatch("vendor.batch_step", "skipped", { fn = "BatchRuntime.ExecuteBatchAction", mode = mode, reason = "requirementsNotMet", entryIndex = entryIndex, item = DescribeBatchItem(ds) })
            return batchStepSkipped()
        end
        -- Stores re-index entries when rows sell out mid-batch; the
        -- entryIndex captured at selection time may now point at a different
        -- item. Re-read the live entry and skip on mismatch.
        if type(GetStoreEntryInfo) == "function" then
            local _, liveName = GetStoreEntryInfo(entryIndex)
            if not liveName or liveName == "" then
                TraceVendorBatch("vendor.batch_step", "skipped", { fn = "BatchRuntime.ExecuteBatchAction", mode = mode, reason = "liveEntryMissing", entryIndex = entryIndex, item = DescribeBatchItem(ds) })
                return batchStepSkipped()
            end
            local liveLink = (type(GetStoreItemLink) == "function") and GetStoreItemLink(entryIndex) or nil
            if ds.itemLink and liveLink then
                if liveLink ~= ds.itemLink then
                    TraceVendorBatch("vendor.batch_step", "skipped", { fn = "BatchRuntime.ExecuteBatchAction", mode = mode, reason = "liveLinkMismatch", entryIndex = entryIndex, expectedItemLink = ds.itemLink, liveItemLink = liveLink, item = DescribeBatchItem(ds) })
                    return batchStepSkipped()
                end
            elseif ds.name then
                -- List rows carry zo_strformat'd names; accept either form.
                local formattedLiveName = liveName
                if type(zo_strformat) == "function" and rawget(_G, "SI_TOOLTIP_ITEM_NAME") ~= nil then
                    formattedLiveName = zo_strformat(SI_TOOLTIP_ITEM_NAME, liveName)
                end
                if ds.name ~= liveName and ds.name ~= formattedLiveName then
                    TraceVendorBatch("vendor.batch_step", "skipped", { fn = "BatchRuntime.ExecuteBatchAction", mode = mode, reason = "liveNameMismatch", entryIndex = entryIndex, expectedName = ds.name, liveName = liveName, formattedLiveName = formattedLiveName, item = DescribeBatchItem(ds) })
                    return batchStepSkipped()
                end
            end
        end
        local vendorInstance = Vendor.instance
        if vendorInstance then
            -- Mirror BuyComponent: gold and alt-currency charges are
            -- independent (alt-currency entries report price == 0, not nil).
            local price = ds.price or 0
            if price > 0 then
                local currencyType = ds.currencyType or CURT_MONEY
                if currencyType == CURT_NONE then
                    currencyType = CURT_MONEY
                end
                if not vendorInstance:CanAfford(price, currencyType) then
                    return batchStepSkipped()
                end
            end
            local price1 = ds.currencyQuantity1 or 0
            local currencyType1 = ds.currencyType1
            if price1 > 0 and currencyType1 and currencyType1 ~= CURT_NONE
                and not vendorInstance:CanAfford(price1, currencyType1) then
                return batchStepSkipped()
            end
            local price2 = ds.currencyQuantity2 or 0
            local currencyType2 = ds.currencyType2
            if price2 > 0 and currencyType2 and currencyType2 ~= CURT_NONE
                and not vendorInstance:CanAfford(price2, currencyType2) then
                return batchStepSkipped()
            end
            -- CanCarry mirrors native CanCarry: craft-bag-virtual items and
            -- partial-stack merges need no free backpack slot.
            if vendorInstance.CanCarry and not vendorInstance:CanCarry(ds.itemLink) then
                return batchStepSkipped()
            elseif not vendorInstance.CanCarry and not vendorInstance:HasInventorySpace() then
                return batchStepSkipped()
            end
        end
        TraceVendorBatch("vendor.batch_step", "request", {
            fn = "Vendor.BatchRuntime.ExecuteBatchAction",
            mode = mode,
            action = "buy",
            entryIndex = entryIndex,
            quantity = 1,
            item = DescribeBatchItem(ds),
        })
        BuyStoreItem(entryIndex, 1)
        TraceVendorBatch("vendor.batch_step", "requested", {
            fn = "Vendor.BatchRuntime.ExecuteBatchAction",
            mode = mode,
            action = "buy",
            entryIndex = entryIndex,
            quantity = 1,
            item = DescribeBatchItem(ds),
        })
        return batchStepQueued()
    elseif IsSellMode(mode) then
        -- Selling for gold while at the wallet cap fails server-side for every
        -- item; halt the batch with feedback instead of issuing N doomed
        -- SellInventoryItem calls. Mirrors the SellComponent gold-cap gate.
        -- Fence sell/launder are handled separately and intentionally skip this.
        if IsAtGoldCap() then
            return batchStepStopped("goldCap")
        end
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local actionType = (mode == MODE.SELL_VENGEANCE and Vendor.ACTION.SELL_VENGEANCE) or Vendor.ACTION.SELL
            local canSell = AuthorizeVendorInventoryAction(actionType, bagId, slotIndex)
            if canSell ~= true then
                return batchStepSkipped()
            end
            -- Re-authorization confirms the slot is still sellable, but not that
            -- it still holds the SELECTED item: an item moved into a freed
            -- slotIndex mid-batch would be sold in its place. Re-check identity.
            if ds.expectedSlotIdentity
                and BETTERUI.CIM.Utils.IsSlotIdentityCurrent(ds.expectedSlotIdentity, bagId, slotIndex) ~= true then
                return batchStepSkipped()
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                TraceVendorBatch("vendor.batch_step", "request", {
                    fn = "Vendor.BatchRuntime.ExecuteBatchAction",
                    mode = mode,
                    action = (mode == MODE.SELL_VENGEANCE and "sellVengeance") or "sell",
                    bagId = bagId,
                    slotIndex = slotIndex,
                    quantity = stackSize,
                    item = DescribeBatchItem(ds),
                })
                SellInventoryItem(bagId, slotIndex, stackSize)
                TraceVendorBatch("vendor.batch_step", "requested", {
                    fn = "Vendor.BatchRuntime.ExecuteBatchAction",
                    mode = mode,
                    action = (mode == MODE.SELL_VENGEANCE and "sellVengeance") or "sell",
                    bagId = bagId,
                    slotIndex = slotIndex,
                    quantity = stackSize,
                    item = DescribeBatchItem(ds),
                })
                return batchStepQueued()
            end
            return batchStepHandled()
        end
        return batchStepHandled()
    elseif mode == MODE.FENCE_SELL then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            -- Per-step fence budget: stop the batch once the daily sell
            -- transactions are exhausted; clamp stacks to what remains.
            local remaining = math.huge
            if GetFenceSellTransactionInfo then
                local totalSells, sellsUsed = GetFenceSellTransactionInfo()
                remaining = (totalSells or 0) - (sellsUsed or 0)
                if remaining <= 0 then
                    return batchStepStopped("fenceLimit")
                end
            end
            local canSell = AuthorizeVendorInventoryAction(Vendor.ACTION.FENCE_SELL, bagId, slotIndex)
            if canSell ~= true then
                return batchStepSkipped()
            end
            -- Re-authorization confirms the slot is still fence-sellable, but not
            -- that it still holds the SELECTED item; re-check identity so an item
            -- moved into a freed slotIndex mid-batch is not fenced in its place.
            if ds.expectedSlotIdentity
                and BETTERUI.CIM.Utils.IsSlotIdentityCurrent(ds.expectedSlotIdentity, bagId, slotIndex) ~= true then
                return batchStepSkipped()
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                local quantity = (remaining < stackSize) and remaining or stackSize
                TraceVendorBatch("vendor.batch_step", "request", {
                    fn = "Vendor.BatchRuntime.ExecuteBatchAction",
                    mode = mode,
                    action = "fenceSell",
                    bagId = bagId,
                    slotIndex = slotIndex,
                    quantity = quantity,
                    remainingFenceTransactions = remaining,
                    item = DescribeBatchItem(ds),
                })
                SellInventoryItem(bagId, slotIndex, quantity)
                TraceVendorBatch("vendor.batch_step", "requested", {
                    fn = "Vendor.BatchRuntime.ExecuteBatchAction",
                    mode = mode,
                    action = "fenceSell",
                    bagId = bagId,
                    slotIndex = slotIndex,
                    quantity = quantity,
                    remainingFenceTransactions = remaining,
                    item = DescribeBatchItem(ds),
                })
                return batchStepQueued()
            end
            return batchStepHandled()
        end
        return batchStepHandled()
    elseif mode == MODE.FENCE_LAUNDER then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            -- Per-step fence budget: stop the batch once the daily launder
            -- transactions are exhausted; clamp stacks to what remains.
            local remaining = math.huge
            if GetFenceLaunderTransactionInfo then
                local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()
                remaining = (totalLaunders or 0) - (laundersUsed or 0)
                if remaining <= 0 then
                    return batchStepStopped("fenceLimit")
                end
            end
            local canLaunder = AuthorizeVendorInventoryAction(Vendor.ACTION.FENCE_LAUNDER, bagId, slotIndex)
            if canLaunder ~= true then
                return batchStepSkipped()
            end
            -- Re-authorization confirms the slot is still launderable, but not
            -- that it still holds the SELECTED item; re-check identity so an item
            -- moved into a freed slotIndex mid-batch is not laundered in its place.
            if ds.expectedSlotIdentity
                and BETTERUI.CIM.Utils.IsSlotIdentityCurrent(ds.expectedSlotIdentity, bagId, slotIndex) ~= true then
                return batchStepSkipped()
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                local quantity = (remaining < stackSize) and remaining or stackSize
                TraceVendorBatch("vendor.batch_step", "request", {
                    fn = "Vendor.BatchRuntime.ExecuteBatchAction",
                    mode = mode,
                    action = "fenceLaunder",
                    bagId = bagId,
                    slotIndex = slotIndex,
                    quantity = quantity,
                    remainingFenceTransactions = remaining,
                    item = DescribeBatchItem(ds),
                })
                LaunderItem(bagId, slotIndex, quantity)
                TraceVendorBatch("vendor.batch_step", "requested", {
                    fn = "Vendor.BatchRuntime.ExecuteBatchAction",
                    mode = mode,
                    action = "fenceLaunder",
                    bagId = bagId,
                    slotIndex = slotIndex,
                    quantity = quantity,
                    remainingFenceTransactions = remaining,
                    item = DescribeBatchItem(ds),
                })
                return batchStepQueued()
            end
            return batchStepHandled()
        end
        return batchStepHandled()
    elseif mode == MODE.BUYBACK then
        local entryIndex = ds.entryIndex
        if entryIndex then
            local vendorInstance = Vendor.instance
            if vendorInstance then
                local price = ds.price or 0
                if not vendorInstance:CanAfford(price) then
                    return batchStepSkipped()
                end
                if vendorInstance.CanCarry and not vendorInstance:CanCarry(ds.itemLink) then
                    return batchStepSkipped()
                elseif not vendorInstance.CanCarry and not vendorInstance:HasInventorySpace() then
                    return batchStepSkipped()
                end
            end
            TraceVendorBatch("vendor.batch_step", "request", {
                fn = "Vendor.BatchRuntime.ExecuteBatchAction",
                mode = mode,
                action = "buyback",
                entryIndex = entryIndex,
                quantity = 1,
                price = ds.price,
                item = DescribeBatchItem(ds),
            })
            BuybackItem(entryIndex)
            TraceVendorBatch("vendor.batch_step", "requested", {
                fn = "Vendor.BatchRuntime.ExecuteBatchAction",
                mode = mode,
                action = "buyback",
                entryIndex = entryIndex,
                quantity = 1,
                price = ds.price,
                item = DescribeBatchItem(ds),
            })
            return batchStepQueued()
        end
        return batchStepHandled()
    end

    return batchStepHandled()
end

---@param mode number
---@return string
function BatchRuntime.ResolveBatchActionName(mode)
    if mode == MODE.BUY then
        return GetString(rawget(_G, "SI_ITEM_ACTION_BUY") or "SI_ITEM_ACTION_BUY")
    elseif IsSellMode(mode) or mode == MODE.FENCE_SELL then
        return GetString(rawget(_G, "SI_ITEM_ACTION_SELL") or "SI_ITEM_ACTION_SELL")
    elseif mode == MODE.FENCE_LAUNDER then
        return GetString(rawget(_G, "SI_ITEM_ACTION_LAUNDER") or "SI_ITEM_ACTION_LAUNDER")
    elseif mode == MODE.BUYBACK then
        return GetString(rawget(_G, "SI_ITEM_ACTION_BUYBACK") or "SI_ITEM_ACTION_BUYBACK")
    end
    return GetString(rawget(_G, "SI_BETTERUI_BATCH_ACTIONS") or "SI_BETTERUI_BATCH_ACTIONS")
end

---@param totalItems integer
---@param batchOptions table|nil
---@return table
local function ResolveBatchDelayPolicy(totalItems, batchOptions)
    local batchConfig = GetBatchConfig()
    local throttleProfile = batchConfig.ResolveBatchThrottleProfile(totalItems)
    local options = ResolveBatchOptions(batchOptions)
    local pacing = options.pacing or {}
    local minDelay = pacing.minServerDelayMs or 145

    return {
        baseDelayMs = zo_max(throttleProfile.DELAY_MS or 100, minDelay),
        -- server.serverBound is part of the public options contract; honor it
        -- the same way the CIM MultiSelectMixin does (force progress UI).
        showProgress = throttleProfile.SHOW_PROGRESS == true or totalItems >= 10
            or (options.server and options.server.serverBound) == true,
        minDelay = minDelay,
        maxDelay = pacing.maxServerDelayMs or 330,
        cooldownEvery = pacing.cooldownEvery or 18,
        cooldownMs = pacing.cooldownMs or 1200,
        chunkCostUnits = pacing.chunkCostUnits or 32,
        chunkPauseMs = pacing.chunkPauseMs or 1000,
        jitterMs = pacing.jitterMs or 18,
        -- ack.awaitInventoryAck is part of the public options contract; the
        -- runner waits for the next inventory update after each mutating step.
        awaitInventoryAck = (options.ack and options.ack.awaitInventoryAck) == true,
        ackTimeoutMs = (options.ack and options.ack.ackTimeoutMs) or 0,
        options = options,
    }
end
Internal.ResolveBatchDelayPolicy = ResolveBatchDelayPolicy

---@param mode number
---@param items table[]
---@param onComplete function|nil
---@param batchOptions table|nil
---@return table
local function CreateBatchRunner(mode, items, onComplete, batchOptions)
    local BatchOverlay = BETTERUI.CIM.BatchOverlay
    local delayPolicy = ResolveBatchDelayPolicy(#items, batchOptions)
    local batchConfig = GetBatchConfig()
    local runner = {
        mode = mode,
        items = items,
        onComplete = onComplete,
        totalItems = #items,
        actionName = BatchRuntime.ResolveBatchActionName(mode),
        BatchOverlay = BatchOverlay,
        BatchConfig = batchConfig,
        batchOptions = delayPolicy.options,
        delayPolicy = delayPolicy,
        showProgress = delayPolicy.showProgress,
        processedCount = 0,
        skippedCount = 0,
        index = 0,
        stopReason = nil,
        nextCooldownAt = delayPolicy.cooldownEvery > 0 and delayPolicy.cooldownEvery or nil,
        nextChunkAt = delayPolicy.chunkCostUnits > 0 and delayPolicy.chunkCostUnits or nil,
        ackCallbacksRegistered = false,
        awaitingAck = false,
        ackReceived = false,
        ackWaitToken = 0,
    }

    -- ack.awaitInventoryAck: after each mutating (queued) step, wait for the
    -- next inventory update callback before continuing — mirroring the CIM
    -- MultiSelectMixin ack pattern — with the pacing delay as the timeout
    -- fallback so a missed event can never stall the batch.
    function runner:RegisterInventoryAckCallbacks()
        if not self.delayPolicy.awaitInventoryAck or self.ackCallbacksRegistered then
            TraceVendorBatch("vendor.batch_ack", "register_skipped", {
                fn = "Vendor.BatchRunner.RegisterInventoryAckCallbacks",
                reason = not self.delayPolicy.awaitInventoryAck and "ackDisabled" or "alreadyRegistered",
                mode = self.mode,
            })
            return
        end
        if not SHARED_INVENTORY or not SHARED_INVENTORY.RegisterCallback then
            TraceVendorBatch("vendor.batch_ack", "register_skipped", {
                fn = "Vendor.BatchRunner.RegisterInventoryAckCallbacks",
                reason = "missingSharedInventory",
                mode = self.mode,
            })
            return
        end
        self.singleSlotAckCallback = function(bagId, slotIndex)
            self:OnInventoryAck(bagId, slotIndex)
        end
        self.fullInventoryAckCallback = function()
            -- Full updates carry no slot identity; accept as a wildcard ack.
            self:OnInventoryAck(nil, nil)
        end
        SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", self.singleSlotAckCallback)
        SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", self.fullInventoryAckCallback)
        self.ackCallbacksRegistered = true
        TraceVendorBatch("vendor.batch_ack", "registered", {
            fn = "Vendor.BatchRunner.RegisterInventoryAckCallbacks",
            mode = self.mode,
            total = self.totalItems,
        })
    end

    function runner:UnregisterInventoryAckCallbacks()
        if not self.ackCallbacksRegistered then
            TraceVendorBatch("vendor.batch_ack", "unregister_skipped", {
                fn = "Vendor.BatchRunner.UnregisterInventoryAckCallbacks",
                reason = "notRegistered",
                mode = self.mode,
            })
            return
        end
        if SHARED_INVENTORY and SHARED_INVENTORY.UnregisterCallback then
            if self.singleSlotAckCallback then
                SHARED_INVENTORY:UnregisterCallback("SingleSlotInventoryUpdate", self.singleSlotAckCallback)
            end
            if self.fullInventoryAckCallback then
                SHARED_INVENTORY:UnregisterCallback("FullInventoryUpdate", self.fullInventoryAckCallback)
            end
        end
        self.singleSlotAckCallback = nil
        self.fullInventoryAckCallback = nil
        self.ackCallbacksRegistered = false
        TraceVendorBatch("vendor.batch_ack", "unregistered", {
            fn = "Vendor.BatchRunner.UnregisterInventoryAckCallbacks",
            mode = self.mode,
        })
    end

    -- A SingleSlot ack only releases the wait when it matches the slot the
    -- current step mutated; unrelated bag updates must not end the wait
    -- early. Steps without slot identity (BUY/BUYBACK deliveries land in an
    -- unknown slot) and FullInventoryUpdate acks match as wildcards.
    function runner:AckMatchesCurrentStep(bagId, slotIndex)
        if bagId == nil or self.expectedAckBagId == nil then
            return true
        end
        if bagId ~= self.expectedAckBagId then
            return false
        end
        return self.expectedAckSlotIndex == nil or slotIndex == self.expectedAckSlotIndex
    end

    function runner:OnInventoryAck(bagId, slotIndex)
        if not self:AckMatchesCurrentStep(bagId, slotIndex) then
            TraceVendorBatch("vendor.batch_ack", "ignored", {
                fn = "Vendor.BatchRunner.OnInventoryAck",
                mode = self.mode,
                bagId = bagId,
                slotIndex = slotIndex,
                expectedBagId = self.expectedAckBagId,
                expectedSlotIndex = self.expectedAckSlotIndex,
            })
            return
        end
        self.ackReceived = true
        TraceVendorBatch("vendor.batch_ack", "received", {
            fn = "Vendor.BatchRunner.OnInventoryAck",
            mode = self.mode,
            bagId = bagId,
            slotIndex = slotIndex,
            awaitingAck = self.awaitingAck == true,
        })
        if self.awaitingAck then
            self.awaitingAck = false
            -- Invalidate the pending ack-timeout fallback before stepping.
            self.ackWaitToken = self.ackWaitToken + 1
            self:Step()
        end
    end

    function runner:ContinueAfterDelay(shouldAwaitAck)
        if not shouldAwaitAck or self.ackReceived then
            TraceVendorBatch("vendor.batch_ack", "continue", {
                fn = "Vendor.BatchRunner.ContinueAfterDelay",
                mode = self.mode,
                shouldAwaitAck = shouldAwaitAck == true,
                ackReceived = self.ackReceived == true,
            })
            self:Step()
            return
        end
        -- Pacing delay elapsed without an inventory ack: keep waiting for the
        -- callback, bounded by ackTimeoutMs (or one more pacing delay).
        self.awaitingAck = true
        self.ackWaitToken = self.ackWaitToken + 1
        local token = self.ackWaitToken
        local timeoutMs = self.delayPolicy.ackTimeoutMs
        if not timeoutMs or timeoutMs <= 0 then
            timeoutMs = self.delayPolicy.baseDelayMs or 145
        end
        TraceVendorBatch("vendor.batch_ack", "waiting", {
            fn = "Vendor.BatchRunner.ContinueAfterDelay",
            mode = self.mode,
            token = token,
            timeoutMs = timeoutMs,
            expectedBagId = self.expectedAckBagId,
            expectedSlotIndex = self.expectedAckSlotIndex,
        })
        zo_callLater(function()
            if self.awaitingAck and token == self.ackWaitToken then
                self.awaitingAck = false
                TraceVendorBatch("vendor.batch_ack", "timeout", {
                    fn = "Vendor.BatchRunner.ContinueAfterDelay.timeout",
                    mode = self.mode,
                    token = token,
                    expectedBagId = self.expectedAckBagId,
                    expectedSlotIndex = self.expectedAckSlotIndex,
                })
                self:Step()
            end
        end, timeoutMs)
    end

    function runner:IsSceneActive()
        return Vendor.instance and Vendor.instance.IsSceneShowing and Vendor.instance:IsSceneShowing()
    end

    function runner:BuildProgressMainText()
        return string.format("Processing (%d/%d)", self.processedCount, self.totalItems)
    end

    function runner:BuildProgressSecondaryText()
        return string.format("Please Wait - Press %s to abort", self.BatchConfig.ResolveBatchAbortBindingMarkup())
    end

    function runner:Finish()
        self:UnregisterInventoryAckCallbacks()
        self.awaitingAck = false
        Vendor._batchProcessing = false
        Vendor._batchAbortRequested = false

        TraceVendorBatch("vendor.batch", "finished", {
            fn = "Vendor.BatchRunner.Finish",
            processed = self.processedCount,
            total = self.totalItems,
            skipped = self.skippedCount or 0,
            stopReason = self.stopReason,
            showProgress = self.showProgress == true,
        })

        if self.showProgress or self.stopReason then
            local completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_PROCESSING_COMPLETE")),
                self.processedCount)
            if self.stopReason == "bagFull" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_BAG_FULL")), self.processedCount,
                    self.totalItems)
            elseif self.stopReason == "sceneExit" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORTED_SCENE_EXIT")), "Vendor",
                    self.processedCount, self.totalItems)
            elseif self.stopReason == "aborted" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORTED_COMPLETE")),
                    self.processedCount, self.totalItems)
            elseif self.processedCount < self.totalItems then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_PARTIAL_SUCCESS")),
                    self.processedCount, self.totalItems)
            end
            self.BatchOverlay.ShowStatus({
                displayName = self.actionName,
                bodyText = completeText,
            })
            self.BatchOverlay.Hide((self.stopReason and 4000) or 2000)
        else
            self.BatchOverlay.Hide()
        end

        if self.onComplete then
            self.onComplete(self.stopReason)
        end
    end

    function runner:RecordServerAction()
        if self.BatchConfig.RecordServerAction then
            self.BatchConfig.RecordServerAction(self.BatchConfig.GetNowMs(), self.BatchConfig.SERVER_RATE_WINDOW_MS)
        end
    end

    function runner:UpdateProgress()
        if self.showProgress then
            self.BatchOverlay.ShowStatus({
                displayName = self.actionName,
                bodyText = function()
                    return self:BuildProgressMainText()
                end,
                secondaryText = function()
                    return self:BuildProgressSecondaryText()
                end,
            })
        end
    end

    function runner:ResolveDelayMs()
        local delayMs = self.delayPolicy.baseDelayMs
        local jitterMs = self.delayPolicy.jitterMs
        local minDelay = self.delayPolicy.minDelay
        local maxDelay = self.delayPolicy.maxDelay

        if jitterMs > 0 and self.BatchConfig.ResolveSignedJitter then
            delayMs = zo_clamp(delayMs + self.BatchConfig.ResolveSignedJitter(jitterMs), minDelay, maxDelay)
        else
            delayMs = zo_clamp(delayMs, minDelay, maxDelay)
        end

        if self.delayPolicy.cooldownMs > 0 and self.nextCooldownAt and self.processedCount >= self.nextCooldownAt then
            delayMs = delayMs + self.delayPolicy.cooldownMs
            while self.nextCooldownAt and self.processedCount >= self.nextCooldownAt do
                self.nextCooldownAt = self.nextCooldownAt + self.delayPolicy.cooldownEvery
            end
        end

        if self.delayPolicy.chunkPauseMs > 0 and self.nextChunkAt and self.processedCount >= self.nextChunkAt then
            delayMs = delayMs + self.delayPolicy.chunkPauseMs
            while self.nextChunkAt and self.processedCount >= self.nextChunkAt do
                self.nextChunkAt = self.nextChunkAt + self.delayPolicy.chunkCostUnits
            end
        end

        return delayMs
    end

    function runner:Step()
        if not self:IsSceneActive() then
            self.stopReason = "sceneExit"
            TraceVendorBatch("vendor.batch", "stopping", {
                fn = "Vendor.BatchRunner.Step",
                reason = "sceneExit",
                processed = self.processedCount,
                total = self.totalItems,
                index = self.index,
            })
            self:Finish()
            return
        end

        if Vendor._batchAbortRequested then
            self.stopReason = "aborted"
            TraceVendorBatch("vendor.batch", "stopping", {
                fn = "Vendor.BatchRunner.Step",
                reason = "aborted",
                processed = self.processedCount,
                total = self.totalItems,
                index = self.index,
            })
            self:Finish()
            return
        end

        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "batch step advanced", {
                index = self.index + 1,
                total = self.totalItems,
                mode = self.mode,
            })
        end

        self.index = self.index + 1
        if self.index > self.totalItems then
            TraceVendorBatch("vendor.batch", "complete_reached", {
                fn = "Vendor.BatchRunner.Step",
                processed = self.processedCount,
                skipped = self.skippedCount or 0,
                total = self.totalItems,
            })
            self:Finish()
            return
        end

        local stepResult = self.BatchConfig.NormalizeBatchStepResult(BatchRuntime.ExecuteBatchAction(self.mode, self.items[self.index]))
        TraceVendorBatch("vendor.batch_step", "result", {
            fn = "Vendor.BatchRunner.Step",
            mode = self.mode,
            index = self.index,
            status = stepResult.status,
            reason = stepResult.reason,
        })

        if stepResult.status == self.BatchConfig.BATCH_STEP_STATUS.STOPPED then
            -- A STOPPED step performed no mutation (e.g. fence limit hit before
            -- the action); do not count it as processed.
            self.stopReason = stepResult.reason or "stopped"
            TraceVendorBatch("vendor.batch", "stopping", {
                fn = "Vendor.BatchRunner.Step",
                reason = self.stopReason,
                index = self.index,
                processed = self.processedCount,
                total = self.totalItems,
            })
            self:Finish()
            return
        end

        -- processedCount counts only QUEUED (actually-mutating) steps so that
        -- the "Processing (x/y)" / completion text and the server-action pacing
        -- windows reflect real purchases/sells. SKIPPED/HANDLED steps (already
        -- handled, re-indexed, unaffordable, filtered) are tracked separately.
        if stepResult.status == self.BatchConfig.BATCH_STEP_STATUS.QUEUED then
            self.processedCount = self.processedCount + 1
        else
            self.skippedCount = (self.skippedCount or 0) + 1
        end

        if self.mode == MODE.BUY or self.mode == MODE.BUYBACK then
            local vendorInstance = Vendor.instance
            if vendorInstance then
                -- Stop the batch only when the NEXT queued item genuinely cannot
                -- be carried: a full backpack still allows craft-bag-virtual
                -- items and partial-stack merges (CanCarry), so use the next
                -- item's itemLink rather than a blanket free-slot test.
                local nextItem = self.items[self.index + 1]
                local nextDs = nextItem and (nextItem.dataSource or nextItem) or nil
                local nextItemLink = nextDs and nextDs.itemLink or nil
                local bagFull
                if vendorInstance.CanCarry then
                    bagFull = not vendorInstance:CanCarry(nextItemLink)
                elseif vendorInstance.HasInventorySpace then
                    bagFull = not vendorInstance:HasInventorySpace()
                end
                if bagFull then
                    self.stopReason = "bagFull"
                    TraceVendorBatch("vendor.batch", "stopping", {
                        fn = "Vendor.BatchRunner.Step",
                        reason = "bagFull",
                        index = self.index,
                        nextItem = DescribeBatchItem(nextDs),
                        processed = self.processedCount,
                        total = self.totalItems,
                    })
                    self:Finish()
                    return
                end
            end
        end

        -- Only QUEUED steps issued a server call; SKIPPED/HANDLED steps mutated
        -- nothing, so recording a server action for them over-throttles the
        -- pacing/cooldown windows against work that never hit the server.
        if stepResult.status == self.BatchConfig.BATCH_STEP_STATUS.QUEUED then
            self:RecordServerAction()
        end
        self:UpdateProgress()

        -- Only mutating steps produce an inventory update to wait for.
        local shouldAwaitAck = self.ackCallbacksRegistered
            and stepResult.status == self.BatchConfig.BATCH_STEP_STATUS.QUEUED
        -- Correlate the wait with this step's own mutation: inventory events
        -- cannot interleave with this call stack, so tagging here happens
        -- before the server ack can arrive. BUY/BUYBACK rows carry no bagId
        -- and therefore match any update (wildcard).
        local stepItem = self.items[self.index]
        local stepDs = stepItem and (stepItem.dataSource or stepItem) or nil
        if shouldAwaitAck and stepDs then
            self.expectedAckBagId = stepDs.bagId
            self.expectedAckSlotIndex = stepDs.slotIndex
        else
            self.expectedAckBagId = nil
            self.expectedAckSlotIndex = nil
        end
        self.ackReceived = false
        self.awaitingAck = false
        local nextDelayMs = self:ResolveDelayMs()
        TraceVendorBatch("vendor.batch_step", "scheduled_next", {
            fn = "Vendor.BatchRunner.Step",
            mode = self.mode,
            index = self.index,
            delayMs = nextDelayMs,
            shouldAwaitAck = shouldAwaitAck == true,
            expectedBagId = self.expectedAckBagId,
            expectedSlotIndex = self.expectedAckSlotIndex,
        })
        zo_callLater(function()
            self:ContinueAfterDelay(shouldAwaitAck)
        end, nextDelayMs)
    end

    function runner:StartAfterDialogDismiss(remainingMs)
        if not Vendor._batchProcessing then
            TraceVendorBatch("vendor.batch_start", "skipped", {
                fn = "Vendor.BatchRunner.StartAfterDialogDismiss",
                reason = "notProcessing",
                mode = self.mode,
            })
            return
        end
        if Vendor._batchAbortRequested then
            self.stopReason = "aborted"
            TraceVendorBatch("vendor.batch_start", "aborted", {
                fn = "Vendor.BatchRunner.StartAfterDialogDismiss",
                mode = self.mode,
                remainingMs = remainingMs,
            })
            self:Finish()
            return
        end
        if not self:IsSceneActive() then
            self.stopReason = "sceneExit"
            TraceVendorBatch("vendor.batch_start", "aborted", {
                fn = "Vendor.BatchRunner.StartAfterDialogDismiss",
                mode = self.mode,
                reason = "sceneExit",
                remainingMs = remainingMs,
            })
            self:Finish()
            return
        end

        if self.BatchOverlay.IsAnyBatchActionDialogShowing and self.BatchOverlay.IsAnyBatchActionDialogShowing() and remainingMs > 0 then
            TraceVendorBatch("vendor.batch_start", "waiting_dialog", {
                fn = "Vendor.BatchRunner.StartAfterDialogDismiss",
                mode = self.mode,
                remainingMs = remainingMs,
            })
            zo_callLater(function()
                self:StartAfterDialogDismiss(remainingMs - 25)
            end, 25)
            return
        end

        zo_callLater(function()
            if not Vendor._batchProcessing then
                TraceVendorBatch("vendor.batch_start", "skipped", {
                    fn = "Vendor.BatchRunner.StartAfterDialogDismiss.startTask",
                    reason = "notProcessing",
                    mode = self.mode,
                })
                return
            end
            self:UpdateProgress()
            TraceVendorBatch("vendor.batch_start", "started", {
                fn = "Vendor.BatchRunner.StartAfterDialogDismiss.startTask",
                mode = self.mode,
                total = self.totalItems,
            })
            self:Step()
        end, 160)
    end

    function runner:Start()
        TraceVendorBatch("vendor.batch_start", "begin", {
            fn = "Vendor.BatchRunner.Start",
            mode = self.mode,
            total = self.totalItems,
            awaitInventoryAck = self.delayPolicy.awaitInventoryAck == true,
            showProgress = self.showProgress == true,
        })
        self:RegisterInventoryAckCallbacks()
        self:StartAfterDialogDismiss(1800)
    end

    return runner
end
Internal.CreateBatchRunner = CreateBatchRunner

---@param request BetterUIVendorBatchRequest
function BatchRuntime.ExecuteBatchThrottled(request)
    request = NormalizeBatchRuntimeRequest(request)
    local mode = request.mode
    local batchItems = request.items or {}
    local totalItems = #batchItems

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "vendor batch started", {
            mode = mode,
            totalItems = totalItems
        })
    end

    if totalItems == 0 then
        TraceVendorBatch("vendor.batch", "start_skipped", {
            fn = "Vendor.BatchRuntime.ExecuteBatchThrottled",
            reason = "empty",
            mode = mode,
            actionName = request.actionName,
        })
        if request.onComplete then
            request.onComplete()
        end
        return
    end

    if mode == MODE.BUYBACK then
        table.sort(batchItems, function(a, b)
            local dsA = a.dataSource or a
            local dsB = b.dataSource or b
            return (dsA.entryIndex or 0) > (dsB.entryIndex or 0)
        end)
    end

    if Vendor._batchProcessing then
        -- A batch is already running; invoke onComplete with a "busy" reason so
        -- callers can release their selection state instead of leaving it
        -- dangling (matches the empty-list early return above, which also fires
        -- onComplete). Callers treat any reason like the stopReason arg they
        -- already accept from Finish().
        TraceVendorBatch("vendor.batch", "start_skipped", {
            fn = "Vendor.BatchRuntime.ExecuteBatchThrottled",
            reason = "busy",
            mode = mode,
            total = totalItems,
            actionName = request.actionName,
        })
        if request.onComplete then
            request.onComplete("busy")
        end
        return
    end
    Vendor._batchProcessing = true
    Vendor._batchAbortRequested = false

    local resolvedOptions = Internal.ResolveBatchOptions(request.options)
    local runner = Internal.CreateBatchRunner(mode, batchItems, request.onComplete, resolvedOptions)
    TraceVendorBatch("vendor.batch", "started", {
        fn = "Vendor.BatchRuntime.ExecuteBatchThrottled",
        mode = mode,
        total = totalItems,
        actionName = request.actionName,
        awaitInventoryAck = runner.delayPolicy and runner.delayPolicy.awaitInventoryAck == true or false,
        showProgress = runner.showProgress == true,
    })
    runner:Start()
end

---@return nil
function BatchRuntime.RequestBatchAbort()
    if Vendor._batchProcessing then
        TraceVendorBatch("vendor.batch", "abort_requested", {
            fn = "Vendor.BatchRuntime.RequestBatchAbort",
            processed = Vendor.instance and Vendor.instance.processedCount or 0,
        })
        Vendor._batchAbortRequested = true
    else
        TraceVendorBatch("vendor.batch", "abort_skipped", {
            fn = "Vendor.BatchRuntime.RequestBatchAbort",
            reason = "notProcessing",
        })
    end
end
