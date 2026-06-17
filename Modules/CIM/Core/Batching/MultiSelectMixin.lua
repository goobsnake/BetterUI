-- Modules/CIM/Core/Batching/MultiSelectMixin.lua
-- Shared multi-select mixin: selection lifecycle + throttled batch pipeline.
-- Delegates to BatchConfig (pacing), BatchOverlay (UI), BatchActions (operations).

--- Shared mixin for inventory-like screens supporting gamepad multi-select behavior.
--- Provides selection lifecycle APIs and throttled batch processing with scene-safe aborts.
---
---

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.MultiSelectMixin = {}
local Mixin = BETTERUI.CIM.MultiSelectMixin
local BatchConfig = BETTERUI.CIM.BatchConfig
local BatchOverlay = BETTERUI.CIM.BatchOverlay
local BatchActions = BETTERUI.CIM.BatchActions

-- MIXIN APPLICATION

local function Noop()
end

local function DefaultGetList(self)
    if type(self) ~= "table" then
        return nil
    end

    return self.list or self.itemList
end

local function NormalizeConfig(config)
    local rawConfig = type(config) == "table" and config or {}

    return {
        getList = type(rawConfig.getList) == "function" and rawConfig.getList or DefaultGetList,
        refreshList = type(rawConfig.refreshList) == "function" and rawConfig.refreshList or Noop,
        refreshKeybinds = type(rawConfig.refreshKeybinds) == "function" and rawConfig.refreshKeybinds or Noop,
        isSceneShowing = type(rawConfig.isSceneShowing) == "function" and rawConfig.isSceneShowing or nil,
        getSceneExitLabel = type(rawConfig.getSceneExitLabel) == "function" and rawConfig.getSceneExitLabel or nil,
    }
end

local function GetConfig(self)
    if type(self) ~= "table" or type(self._multiSelectConfig) ~= "table" then
        return nil
    end

    return self._multiSelectConfig
end

--- Applies the multi-select mixin to a module class instance.
function Mixin.Apply(target, config)
    if type(target) ~= "table" then
        return
    end

    target._multiSelectConfig = NormalizeConfig(config)
end

--- Binds a set of pure delegate methods from the shared mixin onto a target table.
---@param target table
---@param methodNames string[]
function Mixin.BindDelegates(target, methodNames)
    if type(target) ~= "table" or type(methodNames) ~= "table" then
        return
    end

    for _, methodName in ipairs(methodNames) do
        local delegateFn = Mixin[methodName]
        if type(delegateFn) == "function" then
            target[methodName] = delegateFn
        end
    end
end

-- SELECTION MODE LIFECYCLE

function Mixin.EnterSelectionMode(self)
    if self.isInSelectionMode then return end
    if not self.multiSelectManager then return end
    local config = GetConfig(self)
    if not config then return end

    self.isInSelectionMode = true
    self.multiSelectManager:EnterSelectionMode()

    local list = config.getList(self)
    local target = nil
    if list then
        if list.GetSelectedData then
            target = list:GetSelectedData()
        else
            target = list.selectedData
        end
    end
    if target then
        self.multiSelectManager:ToggleSelection(target)
    end

    config.refreshKeybinds(self)
    config.refreshList(self)
end

function Mixin.ExitSelectionMode(self)
    if self.isBatchProcessing then
        Mixin.RequestBatchAbort(self)
        return
    end

    if not self.isInSelectionMode then return end
    local config = GetConfig(self)

    self.isInSelectionMode = false
    self.hadSelections = nil
    self.selectedCount = 0
    if self.multiSelectManager then
        self.multiSelectManager:ExitSelectionMode()
    end

    if config and BatchConfig.IsBatchSceneShowing(self) then
        config.refreshKeybinds(self)
        config.refreshList(self)
    end
end

function Mixin.OnSelectionCountChanged(self, selectedCount)
    local config = GetConfig(self)

    if self.isInSelectionMode and selectedCount > 0 then
        self.selectedCount = selectedCount
        self.hadSelections = true
    else
        self.selectedCount = 0
    end

    if self.isInSelectionMode and selectedCount == 0 and self.hadSelections then
        self.hadSelections = nil
        self:ExitSelectionMode()
        return
    end

    if config and BatchConfig.IsBatchSceneShowing(self) then
        config.refreshKeybinds(self)
    end
end

function Mixin.IsInSelectionMode(self)
    return self.isInSelectionMode or false
end

function Mixin.IsBatchProcessing(self)
    return self.isBatchProcessing == true
end

function Mixin.CanAbortBatch(self)
    return self.isBatchProcessing == true and self.batchAbortRequested ~= true
end

function Mixin.RequestBatchAbort(self)
    if not Mixin.CanAbortBatch(self) then
        return false
    end

    self.batchAbortRequested = true
    if type(self._multiSelectBatchWakeHandler) == "function" then
        self._multiSelectBatchWakeHandler()
    end

    if BatchConfig.IsBatchSceneShowing(self) and self._multiSelectConfig and self._multiSelectConfig.refreshKeybinds then
        self._multiSelectConfig.refreshKeybinds(self)
    end

    return true
end

-- THROTTLED BATCH PROCESSING

local function ResolveBatchRequest(request)
    if type(request) ~= "table" then
        return nil
    end

    local normalized = {
        items = request.items,
        step = request.step,
        onComplete = request.onComplete,
        actionName = request.actionName,
        options = request.options,
    }

    if normalized.items == nil then
        return nil
    end

    if normalized.options == nil then
        normalized.options = {}
    end
    if normalized.actionName == nil then
        normalized.actionName = GetString(rawget(_G, "SI_BETTERUI_BATCH_ACTIONS"))
    end

    return normalized
end

--- Processes selected items through a throttled batch pipeline.
--- Contract: callers pass a `BetterUIBatchRequest` table.
---@param self table
---@param request BetterUIBatchRequest
function Mixin.ProcessBatchThrottled(self, request)
    request = ResolveBatchRequest(request)
    if request == nil then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.BATCH, "Batch request malformed; expected a request-table contract") end
        return
    end
    local stepFn = request.step
    local items = request.items or {}
    local action = request.actionName
    local options = request.options
    local onBatchComplete = request.onComplete

    local shouldNormalizeItems = true
    if type(options) == "table" and type(options.lifecycle) == "table" then
        local normalizeItems = options.lifecycle.normalizeItems
        if type(normalizeItems) == "boolean" then
            shouldNormalizeItems = normalizeItems
        end
    end

    if shouldNormalizeItems then
        items = BatchConfig.NormalizeBatchItems(items)
    else
        if type(items) ~= "table" then
            items = {}
        end
    end
    local totalItems = #items
    if totalItems == 0 then
        if onBatchComplete then onBatchComplete(nil) end
        return
    end
    if self.isBatchProcessing then
        if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.BATCH, "Batch re-entry rejected: pipeline already active") end
        return
    end

    -- Pipeline token: monotonically increasing counter that invalidates stale timers
    self.batchPipelineToken = (self.batchPipelineToken or 0) + 1
    local pipelineToken = self.batchPipelineToken

    local index = 0
    local processedCount = 0
    local processedCost = 0
    local stopReason = nil
    local throttleProfile = BatchConfig.ResolveBatchThrottleProfile(totalItems)
    local batchDelayMs = throttleProfile.DELAY_MS or 75
    local showProgress = throttleProfile.SHOW_PROGRESS == true
    local showEta = totalItems >= BatchConfig.BATCH_ETA_THRESHOLD
    options = BatchConfig.NormalizeBatchOptions(options)
    local isServerBound = options.server.serverBound == true
    if isServerBound then showProgress = true end
    local suppressUiUpdates = options.ui.suppressUiUpdates == true
    local sceneExitLabel = BatchConfig.ResolveSceneExitLabel(self, options)
    local requestedCost = tonumber(options.server.costPerItem)
    local actionCost = BatchConfig.DEFAULT_ACTION_COST_UNITS
    if requestedCost and requestedCost > 0 then
        actionCost = zo_max(BatchConfig.DEFAULT_ACTION_COST_UNITS, zo_ceil(requestedCost))
    end
    local totalCostUnits = totalItems * actionCost
    local cooldownEvery = options.pacing.cooldownEvery or 0
    local cooldownMs = options.pacing.cooldownMs or 0
    local minServerDelayMs = options.pacing.minServerDelayMs or 0
    local maxServerDelayMs = options.pacing.maxServerDelayMs or 0
    local awaitInventoryAck = BatchConfig.ResolveBooleanOption(options.ack.awaitInventoryAck, false)
    local ackTimeoutMs = options.ack.ackTimeoutMs or 0
    local chunkCostUnits = options.pacing.chunkCostUnits or 0
    local chunkPauseMs = options.pacing.chunkPauseMs or 0
    local adaptiveDelay = BatchConfig.ResolveBooleanOption(options.pacing.adaptiveDelay, false)
    local adaptiveThreshold = options.pacing.adaptiveThreshold or 0
    local adaptiveStepMs = options.pacing.adaptiveStepMs or 0
    local jitterMs = options.pacing.jitterMs or 0
    local skipInterBatchCooldown = BatchConfig.ResolveBooleanOption(options.server.skipInterBatchCooldown, false)
    local postBatchCooldownBaseMs = options.postBatch.postBatchCooldownBaseMs or 0
    local postBatchCooldownThreshold = options.postBatch.postBatchCooldownThreshold or 0
    local postBatchCooldownPerCostMs = options.postBatch.postBatchCooldownPerCostMs or 0
    local postBatchCooldownMaxMs = options.postBatch.postBatchCooldownMaxMs or 0
    local enforceRateWindow = BatchConfig.ResolveBooleanOption(options.rateLimit.enforceRateWindow, false)
    local rateLimitWindowMs = options.rateLimit.rateLimitWindowMs or 0
    local rateLimitMaxActions = options.rateLimit.rateLimitMaxActions or 0
    local countTowardRateOnSuccess = BatchConfig.ResolveBooleanOption(options.ack.countTowardRateOnSuccess, false)
    local startupDelayMs = 0
    local nextCooldownAt, nextChunkAt = nil, nil

    if isServerBound then
        cooldownEvery = BatchConfig.ResolvePositiveIntOption(cooldownEvery, BatchConfig.SERVER_COOLDOWN_EVERY)
        cooldownMs = BatchConfig.ResolvePositiveIntOption(cooldownMs, BatchConfig.SERVER_COOLDOWN_MS)
        minServerDelayMs = BatchConfig.ResolvePositiveIntOption(minServerDelayMs, BatchConfig.SERVER_MIN_DELAY_MS)
        maxServerDelayMs = BatchConfig.ResolvePositiveIntOption(maxServerDelayMs, BatchConfig.SERVER_MAX_DELAY_MS)
        maxServerDelayMs = zo_max(maxServerDelayMs, minServerDelayMs)
        awaitInventoryAck = BatchConfig.ResolveBooleanOption(awaitInventoryAck, BatchConfig.SERVER_AWAIT_INVENTORY_ACK)
        ackTimeoutMs = BatchConfig.ResolvePositiveIntOption(ackTimeoutMs, BatchConfig.SERVER_ACK_TIMEOUT_MS)
        chunkCostUnits = BatchConfig.ResolvePositiveIntOption(chunkCostUnits, BatchConfig.SERVER_CHUNK_COST_UNITS)
        chunkPauseMs = BatchConfig.ResolvePositiveIntOption(chunkPauseMs, BatchConfig.SERVER_CHUNK_PAUSE_MS)
        adaptiveDelay = BatchConfig.ResolveBooleanOption(adaptiveDelay, BatchConfig.SERVER_ADAPTIVE_DELAY)
        adaptiveThreshold = BatchConfig.ResolvePositiveIntOption(adaptiveThreshold, BatchConfig.SERVER_ADAPTIVE_THRESHOLD)
        adaptiveStepMs = BatchConfig.ResolvePositiveIntOption(adaptiveStepMs, BatchConfig.SERVER_ADAPTIVE_STEP_MS)
        jitterMs = BatchConfig.ResolvePositiveIntOption(jitterMs, BatchConfig.SERVER_JITTER_MS)
        skipInterBatchCooldown = BatchConfig.ResolveBooleanOption(skipInterBatchCooldown, false)
        postBatchCooldownBaseMs = BatchConfig.ResolvePositiveIntOption(postBatchCooldownBaseMs, BatchConfig.SERVER_POST_BATCH_COOLDOWN_BASE_MS)
        postBatchCooldownThreshold = BatchConfig.ResolvePositiveIntOption(postBatchCooldownThreshold, BatchConfig.SERVER_POST_BATCH_COOLDOWN_THRESHOLD)
        postBatchCooldownPerCostMs = BatchConfig.ResolvePositiveIntOption(postBatchCooldownPerCostMs, BatchConfig.SERVER_POST_BATCH_COOLDOWN_PER_COST_MS)
        postBatchCooldownMaxMs = BatchConfig.ResolvePositiveIntOption(postBatchCooldownMaxMs, BatchConfig.SERVER_POST_BATCH_COOLDOWN_MAX_MS)
        enforceRateWindow = BatchConfig.ResolveBooleanOption(enforceRateWindow, true)
        rateLimitWindowMs = BatchConfig.ResolvePositiveIntOption(rateLimitWindowMs, BatchConfig.SERVER_RATE_WINDOW_MS)
        rateLimitMaxActions = BatchConfig.ResolvePositiveIntOption(rateLimitMaxActions, BatchConfig.SERVER_RATE_MAX_ACTIONS)
        countTowardRateOnSuccess = BatchConfig.ResolveBooleanOption(countTowardRateOnSuccess, true)

        if not SHARED_INVENTORY then awaitInventoryAck = false end
        if cooldownEvery > 0 then nextCooldownAt = cooldownEvery end
        if chunkCostUnits > 0 then nextChunkAt = chunkCostUnits end

        if not skipInterBatchCooldown then
            startupDelayMs = zo_max((BatchConfig.SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs or 0) - BatchConfig.GetNowMs(), 0)
        end
        if enforceRateWindow and rateLimitWindowMs > 0 and rateLimitMaxActions > 0 then
            startupDelayMs = zo_max(startupDelayMs, BatchConfig.ComputeServerActionDelayMs(BatchConfig.GetNowMs(), rateLimitWindowMs, rateLimitMaxActions))
        else
            enforceRateWindow = false
        end
    end

    local effectiveDelayMs = zo_max(0, batchDelayMs)
    local self_ref = self
    local announceAfterCooldown = false
    local consecutiveQueuedActions = 0
    local waitToken = 0
    local processNext
    local stillProcessingAnnouncementActive = false
    local stillProcessingWaitUntilMs = 0
    local awaitingInventoryAckForAction = false
    local ackReceivedForAction = false
    local waitingForInventoryAck = false
    local expectedAckBagId, expectedAckSlotIndex = nil, nil
    local inventoryAckCallbacksRegistered = false
    local inventoryAckSingleSlotCallback, inventoryAckFullCallback = nil, nil

    local function ClearQueuedStillProcessingAnnouncements()
        stillProcessingAnnouncementActive = false
        BatchOverlay.StopLayoutPulse()
    end

    local function ClearPendingContinuation()
        waitToken = waitToken + 1
        self_ref._multiSelectBatchWakeHandler = nil
    end

    local function ResetInventoryAckState()
        awaitingInventoryAckForAction = false
        ackReceivedForAction = false
        waitingForInventoryAck = false
        expectedAckBagId = nil
        expectedAckSlotIndex = nil
    end

    local function UnregisterInventoryAckCallbacks()
        if not inventoryAckCallbacksRegistered then
            inventoryAckSingleSlotCallback = nil
            inventoryAckFullCallback = nil
            return
        end
        if SHARED_INVENTORY then
            SHARED_INVENTORY:UnregisterCallback("SingleSlotInventoryUpdate", inventoryAckSingleSlotCallback)
            SHARED_INVENTORY:UnregisterCallback("FullInventoryUpdate", inventoryAckFullCallback)
        end
        inventoryAckCallbacksRegistered = false
        inventoryAckSingleSlotCallback = nil
        inventoryAckFullCallback = nil
    end

    local function ScheduleContinuation(delayMs, callback)
        local resumeFn = callback or processNext
        ClearPendingContinuation()
        local token = waitToken
        local function Continue()
            if token ~= waitToken then return end
            ClearPendingContinuation()
            resumeFn()
        end
        self_ref._multiSelectBatchWakeHandler = Continue
        zo_callLater(Continue, zo_max(0, delayMs))
    end

    local function HandleInventoryAck(updatedBagId, updatedSlotIndex)
        if not awaitingInventoryAckForAction then return end
        if expectedAckBagId ~= nil then
            if updatedBagId ~= nil and updatedBagId ~= expectedAckBagId then return end
            if updatedBagId ~= nil and expectedAckSlotIndex ~= nil and updatedSlotIndex ~= nil and updatedSlotIndex ~= expectedAckSlotIndex then
                return
            end
        end
        ackReceivedForAction = true
        if waitingForInventoryAck and type(self_ref._multiSelectBatchWakeHandler) == "function" then
            self_ref._multiSelectBatchWakeHandler()
        end
    end

    local function ExtractAckBagAndSlot(...)
        local bagId, slotIndex = nil, nil
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            if type(value) == "number" then
                if bagId == nil then bagId = value
                else slotIndex = value; break end
            end
        end
        if bagId ~= nil and (bagId < 0 or bagId > 10000) then bagId = nil; slotIndex = nil end
        if slotIndex ~= nil and (slotIndex < 0 or slotIndex > 10000) then slotIndex = nil end
        return bagId, slotIndex
    end

    if type(stepFn) ~= "function" then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.BATCH, "Batch step function missing for throttled processing") end
        return
    end

    local function RegisterInventoryAckCallbacks()
        if not awaitInventoryAck or inventoryAckCallbacksRegistered or not SHARED_INVENTORY then return end
        inventoryAckSingleSlotCallback = function(...)
            HandleInventoryAck(ExtractAckBagAndSlot(...))
        end
        inventoryAckFullCallback = function() HandleInventoryAck(nil, nil) end
        SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", inventoryAckSingleSlotCallback)
        SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", inventoryAckFullCallback)
        inventoryAckCallbacksRegistered = true
    end

    ClearQueuedStillProcessingAnnouncements()
    BatchOverlay.Hide()
    RegisterInventoryAckCallbacks()

    self.isBatchProcessing = true
    self.batchAbortRequested = false
    self.batchSuppressUiUpdates = suppressUiUpdates and true or nil

    local displayName = action or GetString(rawget(_G, "SI_BETTERUI_BATCH_ACTIONS"))
    if self._multiSelectConfig and self._multiSelectConfig.refreshKeybinds then
        self._multiSelectConfig.refreshKeybinds(self)
    end

    local estimatedDurationMs = nil
    local batchStartedAtMs = BatchConfig.GetNowMs()
    local countdownPausedTotalMs = 0
    local countdownPauseStartedAtMs = nil
    if showProgress and showEta then
        local estimatedSeconds = BatchConfig.EstimateBatchDurationSeconds(
            totalItems, effectiveDelayMs, cooldownEvery, cooldownMs,
            totalCostUnits, chunkCostUnits, chunkPauseMs, startupDelayMs
        )
        estimatedDurationMs = zo_max(1000, zo_ceil((estimatedSeconds or 0) * 1000))
    end

    local function finishBatch()
        ClearPendingContinuation()
        ResetInventoryAckState()
        UnregisterInventoryAckCallbacks()
        self_ref.isBatchProcessing = false

        -- Record batch diagnostics summary for debugging via /buibatch
        local elapsedMs = BatchConfig.GetNowMs() - batchStartedAtMs
        self_ref.lastBatchSummary = {
            action     = displayName,
            totalItems = totalItems,
            processed  = processedCount,
            cost       = processedCost,
            elapsedMs  = elapsedMs,
            avgDelayMs = processedCount > 0 and (elapsedMs / processedCount) or 0,
            abortReason = stopReason,
            pipelineToken = pipelineToken,
        }

        if BatchConfig.IsBatchSceneShowing(self_ref) and self_ref._multiSelectConfig and self_ref._multiSelectConfig.refreshKeybinds then
            self_ref._multiSelectConfig.refreshKeybinds(self_ref)
        end
        ClearQueuedStillProcessingAnnouncements()

        if showProgress or stopReason then
            local completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_PROCESSING_COMPLETE")), processedCount)
            if stopReason == "bagFull" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_BAG_FULL")), processedCount, totalItems)
            elseif stopReason == "sceneExit" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORTED_SCENE_EXIT")), sceneExitLabel or "Scene", processedCount, totalItems)
            elseif stopReason == "aborted" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORTED_COMPLETE")), processedCount, totalItems)
            elseif processedCount < totalItems then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_PARTIAL_SUCCESS")), processedCount, totalItems)
            end
            BatchOverlay.ShowStatus({
                displayName = displayName,
                bodyText = completeText,
            })
            BatchOverlay.Hide((stopReason and 4000) or 2000)
        else
            BatchOverlay.Hide()
        end

        if isServerBound and processedCost > 0 then
            local nowMs = BatchConfig.GetNowMs()
            local postCooldownMs = 0
            local threshold = zo_max(postBatchCooldownThreshold, 0)
            if threshold == 0 or processedCost >= threshold then
                local extra = zo_max(processedCost - threshold, 0)
                postCooldownMs = postBatchCooldownBaseMs + (extra * postBatchCooldownPerCostMs)
                postCooldownMs = zo_clamp(postCooldownMs, 0, postBatchCooldownMaxMs)
            end
            if postCooldownMs > 0 then
                BatchConfig.SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs = zo_max(
                    BatchConfig.SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs or 0, nowMs + postCooldownMs)
            end
        end

        self_ref.batchAbortRequested = nil
        self_ref.batchSuppressUiUpdates = nil
        self_ref._multiSelectBatchWakeHandler = nil
        stillProcessingWaitUntilMs = 0
        stillProcessingAnnouncementActive = false
        BatchOverlay.StopLayoutPulse()
        if onBatchComplete then onBatchComplete(stopReason) end
    end

    local function ResolveStillProcessingWaitMs(nowMs, waitMs)
        local resolvedNow = nowMs or BatchConfig.GetNowMs()
        if waitMs and waitMs > 0 then
            stillProcessingWaitUntilMs = zo_max(stillProcessingWaitUntilMs, resolvedNow + waitMs)
        end
        local remaining = zo_max(stillProcessingWaitUntilMs - resolvedNow, 0)
        if remaining > 0 then
            if countdownPauseStartedAtMs == nil then countdownPauseStartedAtMs = resolvedNow end
        elseif countdownPauseStartedAtMs ~= nil then
            countdownPausedTotalMs = countdownPausedTotalMs + zo_max(resolvedNow - countdownPauseStartedAtMs, 0)
            countdownPauseStartedAtMs = nil
        end
        return remaining
    end

    local function ComputeRemainingDeterministicPauseMs()
        local rem = 0
        if cooldownMs > 0 and cooldownEvery > 0 and nextCooldownAt and nextCooldownAt <= totalCostUnits then
            rem = rem + zo_max(zo_floor((totalCostUnits - nextCooldownAt) / cooldownEvery) + 1, 0) * cooldownMs
        end
        if chunkPauseMs > 0 and chunkCostUnits > 0 and nextChunkAt and nextChunkAt <= totalCostUnits then
            rem = rem + zo_max(zo_floor((totalCostUnits - nextChunkAt) / chunkCostUnits) + 1, 0) * chunkPauseMs
        end
        return rem
    end

    local function BuildStillProcessingMainText()
        local nowMs = BatchConfig.GetNowMs()
        local remainingWaitMs = ResolveStillProcessingWaitMs(nowMs, nil)
        if estimatedDurationMs and estimatedDurationMs > 0 then
            local pausedMs = countdownPausedTotalMs
            if remainingWaitMs > 0 and countdownPauseStartedAtMs ~= nil then
                pausedMs = pausedMs + zo_max(nowMs - countdownPauseStartedAtMs, 0)
            end
            local elapsedMs = zo_max(nowMs - batchStartedAtMs - pausedMs, 0)
            local remainingItems = zo_max(totalItems - processedCount, 0)
            local remainingMs = zo_max(estimatedDurationMs - elapsedMs, 0)
            local pauseBudget = ComputeRemainingDeterministicPauseMs() + remainingWaitMs
            if remainingItems > 0 and processedCount > 0 and elapsedMs > 0 then
                remainingMs = zo_max(remainingMs, (elapsedMs / processedCount) * remainingItems + pauseBudget)
            else
                remainingMs = remainingMs + pauseBudget
            end
            local etaFormat = GetString(rawget(_G, "SI_BETTERUI_BATCH_PROGRESS_ETA_FORMAT")) or "Processing (%d/%d) ~%s"
            return string.format(etaFormat, processedCount, totalItems, BatchConfig.FormatEstimatedBatchDuration(remainingMs / 1000))
        end
        local progressFormat = GetString(rawget(_G, "SI_BETTERUI_BATCH_PROGRESS_FORMAT")) or "Processing (%d/%d)"
        return string.format(progressFormat, processedCount, totalItems)
    end

    local function BuildStillProcessingSecondaryText()
        local remainingWaitMs = ResolveStillProcessingWaitMs(BatchConfig.GetNowMs(), nil)
        if remainingWaitMs > 0 then
            local waitFormat = GetString(rawget(_G, "SI_BETTERUI_BATCH_RATE_LIMIT_WAIT_FORMAT"))
                or "Continuing in %ds to prevent message rate limit logoff"
            return string.format(waitFormat, zo_max(1, zo_ceil(remainingWaitMs / 1000)))
        end
        local abortFormat = GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORT_HINT_FORMAT"))
            or "Please Wait - Press %s to abort"
        return string.format(abortFormat, BatchConfig.ResolveBatchAbortBindingMarkup())
    end

    local function ShowStillProcessingAnnouncement(waitMs, forceRecreate)
        if not showProgress then return end
        if waitMs and waitMs > 0 then ResolveStillProcessingWaitMs(BatchConfig.GetNowMs(), waitMs) end
        if stillProcessingAnnouncementActive and not forceRecreate then return end
        if forceRecreate then ClearQueuedStillProcessingAnnouncements() end
        BatchOverlay.ShowStatus({
            displayName = displayName,
            bodyText = BuildStillProcessingMainText,
            secondaryText = BuildStillProcessingSecondaryText,
        })
        stillProcessingAnnouncementActive = true
    end

    processNext = function()
        -- Pipeline token guard: reject stale timer callbacks from previous batch
        if pipelineToken ~= self_ref.batchPipelineToken then return end
        local actionQueued
        local bagId, slotIndex
        while true do
            if not BatchConfig.IsBatchSceneShowing(self_ref) then stopReason = "sceneExit"; finishBatch(); return end
            if self_ref.batchAbortRequested then stopReason = "aborted"; finishBatch(); return end
            if announceAfterCooldown then announceAfterCooldown = false; ShowStillProcessingAnnouncement() end

            if isServerBound and enforceRateWindow then
                local rateDelay = BatchConfig.ComputeServerActionDelayMs(BatchConfig.GetNowMs(), rateLimitWindowMs, rateLimitMaxActions)
                if rateDelay > 0 then
                    ShowStillProcessingAnnouncement(rateDelay)
                    ScheduleContinuation(rateDelay, processNext)
                    return
                end
            end

            index = index + 1
            if index > totalItems then finishBatch(); return end

            local itemData = items[index]
            local rawData = itemData.dataSource or itemData
            bagId = rawData.bagId or itemData.bagId
            slotIndex = rawData.slotIndex or itemData.slotIndex
            actionQueued = false
            local skipToNext = false

            if bagId and slotIndex then
                local stepResult = BatchConfig.NormalizeBatchStepResult(stepFn(bagId, slotIndex, itemData))
                if stepResult.status == BatchConfig.BATCH_STEP_STATUS.STOPPED then
                    stopReason = stepResult.reason or "bagFull"
                elseif stepResult.status == BatchConfig.BATCH_STEP_STATUS.SKIPPED then
                    consecutiveQueuedActions = 0; skipToNext = true
                else
                    processedCount = processedCount + 1
                    processedCost = processedCost + actionCost
                    actionQueued = (stepResult.status == BatchConfig.BATCH_STEP_STATUS.QUEUED)
                    consecutiveQueuedActions = actionQueued and (consecutiveQueuedActions + 1) or 0
                    if isServerBound and enforceRateWindow and (actionQueued or countTowardRateOnSuccess) then
                        BatchConfig.RecordServerAction(BatchConfig.GetNowMs(), rateLimitWindowMs)
                    end
                end
            else
                consecutiveQueuedActions = 0
            end

            if stopReason then finishBatch(); return end
            if not skipToNext then break end
        end

        local baseDelayMs = effectiveDelayMs
        if isServerBound then
            baseDelayMs = zo_max(baseDelayMs, minServerDelayMs)
            if adaptiveDelay and actionQueued and adaptiveStepMs > 0 and maxServerDelayMs > minServerDelayMs then
                local over = zo_max(consecutiveQueuedActions - adaptiveThreshold, 0)
                if over > 0 then
                    baseDelayMs = zo_min(maxServerDelayMs, baseDelayMs + zo_min(over * adaptiveStepMs, maxServerDelayMs - minServerDelayMs))
                end
            end
            if jitterMs > 0 then
                baseDelayMs = zo_clamp(baseDelayMs + BatchConfig.ResolveSignedJitter(jitterMs), minServerDelayMs, maxServerDelayMs)
            else
                baseDelayMs = zo_clamp(baseDelayMs, minServerDelayMs, maxServerDelayMs)
            end
        end

        local nextDelayMs = baseDelayMs
        if processedCount < totalItems and cooldownMs > 0 and nextCooldownAt and processedCost >= nextCooldownAt then
            nextDelayMs = nextDelayMs + cooldownMs
            announceAfterCooldown = true
            while nextCooldownAt and processedCost >= nextCooldownAt do nextCooldownAt = nextCooldownAt + cooldownEvery end
        end
        if processedCount < totalItems and chunkPauseMs > 0 and nextChunkAt and processedCost >= nextChunkAt then
            nextDelayMs = nextDelayMs + chunkPauseMs
            announceAfterCooldown = true
            while nextChunkAt and processedCost >= nextChunkAt do nextChunkAt = nextChunkAt + chunkCostUnits end
        end

        local shouldAwaitAck = awaitInventoryAck and actionQueued
        if shouldAwaitAck then
            awaitingInventoryAckForAction = true
            ackReceivedForAction = false
            waitingForInventoryAck = false
            expectedAckBagId = bagId
            expectedAckSlotIndex = slotIndex
        else
            ResetInventoryAckState()
        end

        ScheduleContinuation(nextDelayMs, function()
            if self_ref.batchAbortRequested or not BatchConfig.IsBatchSceneShowing(self_ref) then
                ResetInventoryAckState(); processNext(); return
            end
            if shouldAwaitAck and not ackReceivedForAction then
                waitingForInventoryAck = true
                ScheduleContinuation(ackTimeoutMs, function() ResetInventoryAckState(); processNext() end)
                return
            end
            ResetInventoryAckState(); processNext()
        end)
    end

    local function StartBatchAfterDialogDismiss(remainingWaitMs, settleDelayMs)
        if not self_ref.isBatchProcessing then return end
        if self_ref.batchAbortRequested then stopReason = "aborted"; finishBatch(); return end
        if not BatchConfig.IsBatchSceneShowing(self_ref) then stopReason = "sceneExit"; finishBatch(); return end

        local dialogShowing = BatchOverlay.IsAnyBatchActionDialogShowing()
        if dialogShowing and remainingWaitMs > 0 then
            zo_callLater(function()
                StartBatchAfterDialogDismiss(zo_max(remainingWaitMs - BatchConfig.BATCH_STATUS_DIALOG_CLOSE_POLL_MS, 0), settleDelayMs)
            end, BatchConfig.BATCH_STATUS_DIALOG_CLOSE_POLL_MS)
            return
        end
        if (not dialogShowing) and (settleDelayMs or 0) > 0 then
            zo_callLater(function() StartBatchAfterDialogDismiss(remainingWaitMs, 0) end, settleDelayMs)
            return
        end

        ShowStillProcessingAnnouncement(startupDelayMs, true)
        if startupDelayMs > 0 then ScheduleContinuation(startupDelayMs, processNext)
        else processNext() end
    end

    StartBatchAfterDialogDismiss(BatchConfig.BATCH_STATUS_DIALOG_CLOSE_MAX_WAIT_MS, BatchConfig.BATCH_STATUS_DIALOG_SETTLE_MS)
end

-- BATCH OPERATION DELEGATES

Mixin.BatchLock = BatchActions.BatchLock
Mixin.BatchUnlock = BatchActions.BatchUnlock
Mixin.BatchMarkAsJunk = BatchActions.BatchMarkAsJunk
Mixin.BatchUnmarkAsJunk = BatchActions.BatchUnmarkAsJunk
Mixin.AnalyzeSelectedItems = BatchActions.AnalyzeSelectedItems
Mixin.CreateDialogEntry = BatchActions.CreateDialogEntry
Mixin.AppendCommonBatchEntries = BatchActions.AppendCommonBatchEntries
