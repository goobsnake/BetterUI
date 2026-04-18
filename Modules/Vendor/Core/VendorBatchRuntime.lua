--[[
File: Modules/Vendor/Core/VendorBatchRuntime.lua
Purpose: Own vendor batch action execution/throttling so Vendor.lua delegates batch pipeline details.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.BatchRuntime = Vendor.BatchRuntime or {}
local BatchRuntime = Vendor.BatchRuntime

local MODE = assert(Vendor.MODE, "Vendor mode constants must load before batch runtime")

-- VENDOR BATCH OPTIONS (server-bound throttling, matching banking/inventory pacing)
local VENDOR_BATCH_OPTIONS = {
    serverBound = true,
    minServerDelayMs = 145,
    maxServerDelayMs = 330,
    cooldownEvery = 18,
    cooldownMs = 1200,
    chunkCostUnits = 32,
    chunkPauseMs = 1000,
    jitterMs = 18,
}

---@param mode number
---@param itemData table
---@return nil
function BatchRuntime.ExecuteBatchAction(mode, itemData)
    local ds = itemData and (itemData.dataSource or itemData) or nil
    if not ds then
        return
    end

    if mode == MODE.BUY then
        local entryIndex = ds.entryIndex or ds.slotIndex
        if not entryIndex then
            return
        end
        local vendorInstance = Vendor.instance
        if vendorInstance then
            local price = ds.price or 0
            local currencyType = ds.currencyType or ds.currencyType1 or CURT_MONEY
            if currencyType == CURT_NONE then
                currencyType = CURT_MONEY
            end
            if not vendorInstance:CanAfford(price, currencyType) then
                return
            end
            if not vendorInstance:HasInventorySpace() then
                return
            end
        end
        BuyStoreItem(entryIndex, 1)
    elseif mode == MODE.SELL then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local canSell = not Vendor.AuthorizeInventoryAction
                or Vendor.AuthorizeInventoryAction(Vendor.ACTION.SELL, bagId, slotIndex, Vendor.instance)
            if not canSell then
                return
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                SellInventoryItem(bagId, slotIndex, stackSize)
            end
        end
    elseif mode == MODE.FENCE_SELL then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local canSell = not Vendor.AuthorizeInventoryAction
                or Vendor.AuthorizeInventoryAction(Vendor.ACTION.FENCE_SELL, bagId, slotIndex, Vendor.instance)
            if not canSell then
                return
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                SellInventoryItem(bagId, slotIndex, stackSize)
            end
        end
    elseif mode == MODE.FENCE_LAUNDER then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local canLaunder = not Vendor.AuthorizeInventoryAction
                or Vendor.AuthorizeInventoryAction(Vendor.ACTION.FENCE_LAUNDER, bagId, slotIndex, Vendor.instance)
            if not canLaunder then
                return
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                LaunderItem(bagId, slotIndex, stackSize)
            end
        end
    elseif mode == MODE.BUYBACK then
        local entryIndex = ds.entryIndex
        if entryIndex then
            local vendorInstance = Vendor.instance
            if vendorInstance then
                local price = ds.price or 0
                if not vendorInstance:CanAfford(price) then
                    return
                end
                if not vendorInstance:HasInventorySpace() then
                    return
                end
            end
            BuybackItem(entryIndex)
        end
    end
end

---@param mode number
---@return string
function BatchRuntime.ResolveBatchActionName(mode)
    if mode == MODE.BUY then
        return GetString(rawget(_G, "SI_ITEM_ACTION_BUY") or "SI_ITEM_ACTION_BUY")
    elseif mode == MODE.SELL or mode == MODE.FENCE_SELL then
        return GetString(rawget(_G, "SI_ITEM_ACTION_SELL") or "SI_ITEM_ACTION_SELL")
    elseif mode == MODE.FENCE_LAUNDER then
        return GetString(rawget(_G, "SI_ITEM_ACTION_LAUNDER") or "SI_ITEM_ACTION_LAUNDER")
    elseif mode == MODE.BUYBACK then
        return GetString(rawget(_G, "SI_ITEM_ACTION_BUYBACK") or "SI_ITEM_ACTION_BUYBACK")
    end
    return GetString(rawget(_G, "SI_BETTERUI_BATCH_ACTIONS") or "SI_BETTERUI_BATCH_ACTIONS")
end

---@param totalItems integer
---@return table
function BatchRuntime.ResolveBatchDelayPolicy(totalItems)
    local BatchConfig = BETTERUI.CIM.BatchConfig
    local throttleProfile = BatchConfig.ResolveBatchThrottleProfile(totalItems)
    local opts = VENDOR_BATCH_OPTIONS
    local minDelay = opts.minServerDelayMs or 145

    return {
        BatchConfig = BatchConfig,
        baseDelayMs = zo_max(throttleProfile.DELAY_MS or 100, minDelay),
        showProgress = throttleProfile.SHOW_PROGRESS == true or totalItems >= 10,
        minDelay = minDelay,
        maxDelay = opts.maxServerDelayMs or 330,
        cooldownEvery = opts.cooldownEvery or 18,
        cooldownMs = opts.cooldownMs or 1200,
        chunkCostUnits = opts.chunkCostUnits or 32,
        chunkPauseMs = opts.chunkPauseMs or 1000,
        jitterMs = opts.jitterMs or 18,
    }
end

---@param mode number
---@param items table[]
---@param onComplete function|nil
---@return table
function BatchRuntime.CreateBatchRunner(mode, items, onComplete)
    local BatchOverlay = BETTERUI.CIM.BatchOverlay
    local delayPolicy = BatchRuntime.ResolveBatchDelayPolicy(#items)
    local runner = {
        mode = mode,
        items = items,
        onComplete = onComplete,
        totalItems = #items,
        actionName = BatchRuntime.ResolveBatchActionName(mode),
        BatchOverlay = BatchOverlay,
        BatchConfig = delayPolicy.BatchConfig,
        delayPolicy = delayPolicy,
        showProgress = delayPolicy.showProgress,
        processedCount = 0,
        index = 0,
        stopReason = nil,
        nextCooldownAt = delayPolicy.cooldownEvery > 0 and delayPolicy.cooldownEvery or nil,
        nextChunkAt = delayPolicy.chunkCostUnits > 0 and delayPolicy.chunkCostUnits or nil,
    }

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
        Vendor._batchProcessing = false
        Vendor._batchAbortRequested = false

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
            self.BatchOverlay.Show(
                self.actionName,
                function()
                    return self:BuildProgressMainText()
                end,
                function()
                    return self:BuildProgressSecondaryText()
                end
            )
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
            self:Finish()
            return
        end

        if Vendor._batchAbortRequested then
            self.stopReason = "aborted"
            self:Finish()
            return
        end

        self.index = self.index + 1
        if self.index > self.totalItems then
            self:Finish()
            return
        end

        BatchRuntime.ExecuteBatchAction(self.mode, self.items[self.index])
        self.processedCount = self.processedCount + 1

        if self.mode == MODE.BUY or self.mode == MODE.BUYBACK then
            local vendorInstance = Vendor.instance
            if vendorInstance and vendorInstance.HasInventorySpace and not vendorInstance:HasInventorySpace() then
                self.stopReason = "bagFull"
                self:Finish()
                return
            end
        end

        self:RecordServerAction()
        self:UpdateProgress()
        zo_callLater(function()
            self:Step()
        end, self:ResolveDelayMs())
    end

    function runner:StartAfterDialogDismiss(remainingMs)
        if not Vendor._batchProcessing then
            return
        end
        if Vendor._batchAbortRequested then
            self.stopReason = "aborted"
            self:Finish()
            return
        end
        if not self:IsSceneActive() then
            self.stopReason = "sceneExit"
            self:Finish()
            return
        end

        if self.BatchOverlay.IsAnyBatchActionDialogShowing and self.BatchOverlay.IsAnyBatchActionDialogShowing() and remainingMs > 0 then
            zo_callLater(function()
                self:StartAfterDialogDismiss(remainingMs - 25)
            end, 25)
            return
        end

        zo_callLater(function()
            if not Vendor._batchProcessing then
                return
            end
            self:UpdateProgress()
            self:Step()
        end, 160)
    end

    function runner:Start()
        self:StartAfterDialogDismiss(1800)
    end

    return runner
end

---@param mode number
---@param items table[]
---@param onComplete function|nil
---@return nil
function BatchRuntime.ExecuteBatchThrottled(mode, items, onComplete)
    local totalItems = #items
    if totalItems == 0 then
        if onComplete then
            onComplete()
        end
        return
    end

    if mode == MODE.BUYBACK then
        table.sort(items, function(a, b)
            local dsA = a.dataSource or a
            local dsB = b.dataSource or b
            return (dsA.entryIndex or 0) > (dsB.entryIndex or 0)
        end)
    end

    if Vendor._batchProcessing then
        return
    end
    Vendor._batchProcessing = true
    Vendor._batchAbortRequested = false

    local runner = BatchRuntime.CreateBatchRunner(mode, items, onComplete)
    runner:Start()
end

---@return nil
function BatchRuntime.RequestBatchAbort()
    if Vendor._batchProcessing then
        Vendor._batchAbortRequested = true
    end
end
