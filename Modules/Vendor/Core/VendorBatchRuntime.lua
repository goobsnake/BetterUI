--[[
File: Modules/Vendor/Core/VendorBatchRuntime.lua
Purpose: Own vendor batch action execution/throttling so Vendor.lua delegates batch pipeline details.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.BatchRuntime = Vendor.BatchRuntime or {}
local BatchRuntime = Vendor.BatchRuntime

local MODE = assert(Vendor.MODE, "Vendor mode constants must load before batch runtime")

local function GetBatchConfig()
    local batchConfig = BETTERUI.CIM and BETTERUI.CIM.BatchConfig
    assert(batchConfig, "CIM batch config must load before vendor batch runtime")
    return batchConfig
end

-- VENDOR BATCH OPTIONS (grouped contract, matching banking/inventory pacing)
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

local function TranslateLegacyBatchOptions(batchOptions)
    if type(batchOptions) ~= "table" then
        return nil
    end

    local legacyKeys = {
        "serverBound",
        "costPerItem",
        "skipInterBatchCooldown",
        "minServerDelayMs",
        "maxServerDelayMs",
        "cooldownEvery",
        "cooldownMs",
        "chunkCostUnits",
        "chunkPauseMs",
        "adaptiveDelay",
        "adaptiveThreshold",
        "adaptiveStepMs",
        "jitterMs",
        "awaitInventoryAck",
        "ackTimeoutMs",
        "countTowardRateOnSuccess",
        "enforceRateWindow",
        "rateLimitWindowMs",
        "rateLimitMaxActions",
        "postBatchCooldownBaseMs",
        "postBatchCooldownThreshold",
        "postBatchCooldownPerCostMs",
        "postBatchCooldownMaxMs",
    }

    local hasLegacyShape = false
    for _, key in ipairs(legacyKeys) do
        if batchOptions[key] ~= nil then
            hasLegacyShape = true
            break
        end
    end
    if not hasLegacyShape then
        return nil
    end

    local batchConfig = GetBatchConfig()
    return batchConfig.ComposeBatchOptions(
        batchConfig.WithServer({
            serverBound = batchOptions.serverBound,
            costPerItem = batchOptions.costPerItem,
            skipInterBatchCooldown = batchOptions.skipInterBatchCooldown,
        }),
        batchConfig.WithPacing({
            minServerDelayMs = batchOptions.minServerDelayMs,
            maxServerDelayMs = batchOptions.maxServerDelayMs,
            cooldownEvery = batchOptions.cooldownEvery,
            cooldownMs = batchOptions.cooldownMs,
            chunkCostUnits = batchOptions.chunkCostUnits,
            chunkPauseMs = batchOptions.chunkPauseMs,
            adaptiveDelay = batchOptions.adaptiveDelay,
            adaptiveThreshold = batchOptions.adaptiveThreshold,
            adaptiveStepMs = batchOptions.adaptiveStepMs,
            jitterMs = batchOptions.jitterMs,
        }),
        batchConfig.WithAck({
            awaitInventoryAck = batchOptions.awaitInventoryAck,
            ackTimeoutMs = batchOptions.ackTimeoutMs,
            countTowardRateOnSuccess = batchOptions.countTowardRateOnSuccess,
        }),
        batchConfig.WithRateLimit({
            enforceRateWindow = batchOptions.enforceRateWindow,
            rateLimitWindowMs = batchOptions.rateLimitWindowMs,
            rateLimitMaxActions = batchOptions.rateLimitMaxActions,
        }),
        batchConfig.WithPostBatch({
            postBatchCooldownBaseMs = batchOptions.postBatchCooldownBaseMs,
            postBatchCooldownThreshold = batchOptions.postBatchCooldownThreshold,
            postBatchCooldownPerCostMs = batchOptions.postBatchCooldownPerCostMs,
            postBatchCooldownMaxMs = batchOptions.postBatchCooldownMaxMs,
        })
    )
end

---@param batchOptions table|nil
---@return BatchOptions
function BatchRuntime.ResolveBatchOptions(batchOptions)
    local batchConfig = GetBatchConfig()
    local translatedLegacyOptions = TranslateLegacyBatchOptions(batchOptions)
    local normalizedOverride = batchConfig.NormalizeBatchOptions(translatedLegacyOptions or batchOptions)
    return batchConfig.ComposeBatchOptions(GetVendorBatchOptionsTemplate(), normalizedOverride)
end

--- Normalizes either a request object or legacy positional signature.
---@param modeOrRequest BetterUIVendorBatchRequest|number
---@param items BetterUIVendorBatchItem[]|nil
---@param onComplete BetterUIBatchCompletionCallback|nil
---@param batchOptions BatchOptions|table|nil
---@return BetterUIVendorBatchRequest
local function ResolveBatchRuntimeRequest(modeOrRequest, items, onComplete, batchOptions)
    if type(modeOrRequest) == "table" and type(items) ~= "function" then
        local hasNamedShape = modeOrRequest.mode ~= nil
            or modeOrRequest.items ~= nil
            or modeOrRequest.onComplete ~= nil
            or modeOrRequest.options ~= nil
            or modeOrRequest.batchOptions ~= nil
            or modeOrRequest.actionName ~= nil

        if hasNamedShape then
            return {
                mode = modeOrRequest.mode,
                items = modeOrRequest.items,
                onComplete = modeOrRequest.onComplete,
                options = modeOrRequest.options or modeOrRequest.batchOptions,
                actionName = modeOrRequest.actionName,
            }
        end
    end

    return {
        mode = modeOrRequest,
        items = items or {},
        onComplete = onComplete,
        options = batchOptions,
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

    local ds = itemData and (itemData.dataSource or itemData) or nil
    if not ds then
        return batchStepHandled()
    end

    if mode == MODE.BUY then
        local entryIndex = ds.entryIndex or ds.slotIndex
        if not entryIndex then
            return batchStepHandled()
        end
        local vendorInstance = Vendor.instance
        if vendorInstance then
            local price = ds.price or 0
            local currencyType = ds.currencyType or ds.currencyType1 or CURT_MONEY
            if currencyType == CURT_NONE then
                currencyType = CURT_MONEY
            end
            if not vendorInstance:CanAfford(price, currencyType) then
                return batchStepSkipped()
            end
            if not vendorInstance:HasInventorySpace() then
                return batchStepSkipped()
            end
        end
        BuyStoreItem(entryIndex, 1)
        return batchStepQueued()
    elseif mode == MODE.SELL then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local canSell = not Vendor.AuthorizeInventoryAction
                or Vendor.AuthorizeInventoryAction(Vendor.ACTION.SELL, bagId, slotIndex, Vendor.instance)
            if not canSell then
                return batchStepSkipped()
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                SellInventoryItem(bagId, slotIndex, stackSize)
                return batchStepQueued()
            end
            return batchStepHandled()
        end
        return batchStepHandled()
    elseif mode == MODE.FENCE_SELL then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local canSell = not Vendor.AuthorizeInventoryAction
                or Vendor.AuthorizeInventoryAction(Vendor.ACTION.FENCE_SELL, bagId, slotIndex, Vendor.instance)
            if not canSell then
                return batchStepSkipped()
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                SellInventoryItem(bagId, slotIndex, stackSize)
                return batchStepQueued()
            end
            return batchStepHandled()
        end
        return batchStepHandled()
    elseif mode == MODE.FENCE_LAUNDER then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local canLaunder = not Vendor.AuthorizeInventoryAction
                or Vendor.AuthorizeInventoryAction(Vendor.ACTION.FENCE_LAUNDER, bagId, slotIndex, Vendor.instance)
            if not canLaunder then
                return batchStepSkipped()
            end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                LaunderItem(bagId, slotIndex, stackSize)
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
                if not vendorInstance:HasInventorySpace() then
                    return batchStepSkipped()
                end
            end
            BuybackItem(entryIndex)
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
---@param batchOptions table|nil
---@return table
function BatchRuntime.ResolveBatchDelayPolicy(totalItems, batchOptions)
    local batchConfig = GetBatchConfig()
    local throttleProfile = batchConfig.ResolveBatchThrottleProfile(totalItems)
    local options = BatchRuntime.ResolveBatchOptions(batchOptions)
    local pacing = options.pacing or {}
    local minDelay = pacing.minServerDelayMs or 145

    return {
        baseDelayMs = zo_max(throttleProfile.DELAY_MS or 100, minDelay),
        showProgress = throttleProfile.SHOW_PROGRESS == true or totalItems >= 10,
        minDelay = minDelay,
        maxDelay = pacing.maxServerDelayMs or 330,
        cooldownEvery = pacing.cooldownEvery or 18,
        cooldownMs = pacing.cooldownMs or 1200,
        chunkCostUnits = pacing.chunkCostUnits or 32,
        chunkPauseMs = pacing.chunkPauseMs or 1000,
        jitterMs = pacing.jitterMs or 18,
        options = options,
    }
end

---@param mode number
---@param items table[]
---@param onComplete function|nil
---@param batchOptions table|nil
---@return table
function BatchRuntime.CreateBatchRunner(mode, items, onComplete, batchOptions)
    local BatchOverlay = BETTERUI.CIM.BatchOverlay
    local delayPolicy = BatchRuntime.ResolveBatchDelayPolicy(#items, batchOptions)
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

        local stepResult = self.BatchConfig.NormalizeBatchStepResult(BatchRuntime.ExecuteBatchAction(self.mode, self.items[self.index]))
        self.processedCount = self.processedCount + 1

        if stepResult.status == self.BatchConfig.BATCH_STEP_STATUS.STOPPED then
            self.stopReason = stepResult.reason or "stopped"
            self:Finish()
            return
        end

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

---@param modeOrRequest BetterUIVendorBatchRequest|number
---@param items BetterUIVendorBatchItem[]|nil
---@param onComplete BetterUIBatchCompletionCallback|nil
---@param batchOptions BatchOptions|table|nil
---@return nil
function BatchRuntime.ExecuteBatchThrottled(modeOrRequest, items, onComplete, batchOptions)
    local request = ResolveBatchRuntimeRequest(modeOrRequest, items, onComplete, batchOptions)
    local mode = request.mode
    local batchItems = request.items or {}
    local totalItems = #batchItems
    if totalItems == 0 then
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
        return
    end
    Vendor._batchProcessing = true
    Vendor._batchAbortRequested = false

    local resolvedOptions = BatchRuntime.ResolveBatchOptions(request.options)
    local runner = BatchRuntime.CreateBatchRunner(mode, batchItems, request.onComplete, resolvedOptions)
    runner:Start()
end

---@return nil
function BatchRuntime.RequestBatchAbort()
    if Vendor._batchProcessing then
        Vendor._batchAbortRequested = true
    end
end
