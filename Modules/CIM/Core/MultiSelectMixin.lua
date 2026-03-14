-- Modules/CIM/Core/MultiSelectMixin.lua
-- Shared multi-select mixin: selection lifecycle + throttled batch pipeline.
-- Delegates to BatchConfig (pacing), BatchOverlay (UI), BatchActions (operations).

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.MultiSelectMixin = {}
local Mixin = BETTERUI.CIM.MultiSelectMixin
local Cfg = BETTERUI.CIM.BatchConfig
local Overlay = BETTERUI.CIM.BatchOverlay
local Actions = BETTERUI.CIM.BatchActions

-------------------------------------------------------------------------------------------------
-- MIXIN APPLICATION
-------------------------------------------------------------------------------------------------

--- Applies the multi-select mixin to a module class instance.
--- @param target table The module class instance
--- @param config table Module-specific callbacks
function Mixin.Apply(target, config)
    target._msConfig = config
end

-------------------------------------------------------------------------------------------------
-- SELECTION MODE LIFECYCLE
-------------------------------------------------------------------------------------------------

function Mixin.EnterSelectionMode(self)
    if self.isInSelectionMode then return end
    if not self.multiSelectManager then return end

    self.isInSelectionMode = true
    self.multiSelectManager:EnterSelectionMode()

    local list = self._msConfig.getList(self)
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

    self._msConfig.refreshKeybinds(self)
    self._msConfig.refreshList(self)
end

function Mixin.ExitSelectionMode(self)
    if self.isBatchProcessing then
        Mixin.RequestBatchAbort(self)
        return
    end

    if not self.isInSelectionMode then return end

    self.isInSelectionMode = false
    self.hadSelections = nil
    self.selectedCount = 0
    if self.multiSelectManager then
        self.multiSelectManager:ExitSelectionMode()
    end

    if Cfg.IsBatchSceneShowing(self) then
        self._msConfig.refreshKeybinds(self)
        self._msConfig.refreshList(self)
    end
end

--- @param selectedCount number
function Mixin.OnSelectionCountChanged(self, selectedCount)
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

    if Cfg.IsBatchSceneShowing(self) then
        self._msConfig.refreshKeybinds(self)
    end
end

--- @return boolean
function Mixin.IsInSelectionMode(self)
    return self.isInSelectionMode or false
end

--- @return boolean
function Mixin.IsBatchProcessing(self)
    return self.isBatchProcessing == true
end

--- @return boolean
function Mixin.CanAbortBatch(self)
    return self.isBatchProcessing == true and self.batchAbortRequested ~= true
end

--- @return boolean
function Mixin.RequestBatchAbort(self)
    if not Mixin.CanAbortBatch(self) then
        return false
    end

    self.batchAbortRequested = true
    if type(self._msBatchWakeHandler) == "function" then
        self._msBatchWakeHandler()
    end

    if Cfg.IsBatchSceneShowing(self) and self._msConfig and self._msConfig.refreshKeybinds then
        self._msConfig.refreshKeybinds(self)
    end

    return true
end

-------------------------------------------------------------------------------------------------
-- THROTTLED BATCH PROCESSING
-------------------------------------------------------------------------------------------------

function Mixin.ProcessBatchThrottled(self, items, actionFn, onComplete, actionName, batchOptions)
    items = Cfg.NormalizeBatchItems(items or {})
    local totalItems = #items
    if totalItems == 0 then
        if onComplete then onComplete() end
        return
    end
    if self.isBatchProcessing then
        BETTERUI.CIM.Debug.Log("Batch re-entry rejected: pipeline already active", "Batch")
        return
    end

    -- Pipeline token: monotonically increasing counter that invalidates stale timers
    self.batchPipelineToken = (self.batchPipelineToken or 0) + 1
    local pipelineToken = self.batchPipelineToken

    local index = 0
    local processedCount = 0
    local processedCost = 0
    local stopReason = nil
    local throttleProfile = Cfg.ResolveBatchThrottleProfile(totalItems)
    local batchDelayMs = throttleProfile.DELAY_MS or 75
    local showProgress = throttleProfile.SHOW_PROGRESS == true
    local showEta = totalItems >= Cfg.BATCH_ETA_THRESHOLD
    local options = batchOptions or {}
    local isServerBound = options.serverBound == true
    if isServerBound then showProgress = true end
    local suppressUiUpdates = options.suppressUiUpdates == true
    local sceneExitLabel = Cfg.ResolveSceneExitLabel(self, options)
    local requestedCost = tonumber(options.costPerItem)
    local actionCost = Cfg.DEFAULT_ACTION_COST_UNITS
    if requestedCost and requestedCost > 0 then
        actionCost = zo_max(Cfg.DEFAULT_ACTION_COST_UNITS, zo_ceil(requestedCost))
    end
    local totalCostUnits = totalItems * actionCost
    local cooldownEvery, cooldownMs = 0, 0
    local minServerDelayMs, maxServerDelayMs = 0, 0
    local awaitInventoryAck, ackTimeoutMs = false, 0
    local chunkCostUnits, chunkPauseMs = 0, 0
    local adaptiveDelay, adaptiveThreshold, adaptiveStepMs = false, 0, 0
    local jitterMs = 0
    local skipInterBatchCooldown = false
    local postBatchCooldownBaseMs, postBatchCooldownThreshold = 0, 0
    local postBatchCooldownPerCostMs, postBatchCooldownMaxMs = 0, 0
    local enforceRateWindow, rateLimitWindowMs, rateLimitMaxActions = false, 0, 0
    local countTowardRateOnSuccess = false
    local startupDelayMs = 0
    local nextCooldownAt, nextChunkAt = nil, nil

    if isServerBound then
        cooldownEvery = Cfg.ResolvePositiveIntOption(options.cooldownEvery, Cfg.SERVER_COOLDOWN_EVERY)
        cooldownMs = Cfg.ResolvePositiveIntOption(options.cooldownMs, Cfg.SERVER_COOLDOWN_MS)
        minServerDelayMs = Cfg.ResolvePositiveIntOption(options.minServerDelayMs, Cfg.SERVER_MIN_DELAY_MS)
        maxServerDelayMs = Cfg.ResolvePositiveIntOption(options.maxServerDelayMs, Cfg.SERVER_MAX_DELAY_MS)
        maxServerDelayMs = zo_max(maxServerDelayMs, minServerDelayMs)
        awaitInventoryAck = Cfg.ResolveBooleanOption(options.awaitInventoryAck, Cfg.SERVER_AWAIT_INVENTORY_ACK)
        ackTimeoutMs = Cfg.ResolvePositiveIntOption(options.ackTimeoutMs, Cfg.SERVER_ACK_TIMEOUT_MS)
        chunkCostUnits = Cfg.ResolvePositiveIntOption(options.chunkCostUnits, Cfg.SERVER_CHUNK_COST_UNITS)
        chunkPauseMs = Cfg.ResolvePositiveIntOption(options.chunkPauseMs, Cfg.SERVER_CHUNK_PAUSE_MS)
        adaptiveDelay = Cfg.ResolveBooleanOption(options.adaptiveDelay, Cfg.SERVER_ADAPTIVE_DELAY)
        adaptiveThreshold = Cfg.ResolvePositiveIntOption(options.adaptiveThreshold, Cfg.SERVER_ADAPTIVE_THRESHOLD)
        adaptiveStepMs = Cfg.ResolvePositiveIntOption(options.adaptiveStepMs, Cfg.SERVER_ADAPTIVE_STEP_MS)
        jitterMs = Cfg.ResolvePositiveIntOption(options.jitterMs, Cfg.SERVER_JITTER_MS)
        skipInterBatchCooldown = Cfg.ResolveBooleanOption(options.skipInterBatchCooldown, false)
        postBatchCooldownBaseMs = Cfg.ResolvePositiveIntOption(options.postBatchCooldownBaseMs, Cfg.SERVER_POST_BATCH_COOLDOWN_BASE_MS)
        postBatchCooldownThreshold = Cfg.ResolvePositiveIntOption(options.postBatchCooldownThreshold, Cfg.SERVER_POST_BATCH_COOLDOWN_THRESHOLD)
        postBatchCooldownPerCostMs = Cfg.ResolvePositiveIntOption(options.postBatchCooldownPerCostMs, Cfg.SERVER_POST_BATCH_COOLDOWN_PER_COST_MS)
        postBatchCooldownMaxMs = Cfg.ResolvePositiveIntOption(options.postBatchCooldownMaxMs, Cfg.SERVER_POST_BATCH_COOLDOWN_MAX_MS)
        enforceRateWindow = Cfg.ResolveBooleanOption(options.enforceRateWindow, true)
        rateLimitWindowMs = Cfg.ResolvePositiveIntOption(options.rateLimitWindowMs, Cfg.SERVER_RATE_WINDOW_MS)
        rateLimitMaxActions = Cfg.ResolvePositiveIntOption(options.rateLimitMaxActions, Cfg.SERVER_RATE_MAX_ACTIONS)
        countTowardRateOnSuccess = Cfg.ResolveBooleanOption(options.countTowardRateOnSuccess, true)

        if not SHARED_INVENTORY then awaitInventoryAck = false end
        if cooldownEvery > 0 then nextCooldownAt = cooldownEvery end
        if chunkCostUnits > 0 then nextChunkAt = chunkCostUnits end

        if not skipInterBatchCooldown then
            startupDelayMs = zo_max((Cfg.SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs or 0) - Cfg.GetNowMs(), 0)
        end
        if enforceRateWindow and rateLimitWindowMs > 0 and rateLimitMaxActions > 0 then
            startupDelayMs = zo_max(startupDelayMs, Cfg.ComputeServerActionDelayMs(Cfg.GetNowMs(), rateLimitWindowMs, rateLimitMaxActions))
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
        Overlay.StopLayoutPulse()
    end

    local function ClearPendingContinuation()
        waitToken = waitToken + 1
        self_ref._msBatchWakeHandler = nil
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
        self_ref._msBatchWakeHandler = Continue
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
        if waitingForInventoryAck and type(self_ref._msBatchWakeHandler) == "function" then
            self_ref._msBatchWakeHandler()
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
    Overlay.Hide()
    RegisterInventoryAckCallbacks()

    self.isBatchProcessing = true
    self.batchAbortRequested = false
    self.batchSuppressUiUpdates = suppressUiUpdates and true or nil

    local displayName = actionName or GetString(SI_BETTERUI_BATCH_ACTIONS)
    if self._msConfig and self._msConfig.refreshKeybinds then
        self._msConfig.refreshKeybinds(self)
    end

    local estimatedDurationMs = nil
    local batchStartedAtMs = Cfg.GetNowMs()
    local countdownPausedTotalMs = 0
    local countdownPauseStartedAtMs = nil
    if showProgress and showEta then
        local estimatedSeconds = Cfg.EstimateBatchDurationSeconds(
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
        local elapsedMs = Cfg.GetNowMs() - batchStartedAtMs
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

        if Cfg.IsBatchSceneShowing(self_ref) and self_ref._msConfig and self_ref._msConfig.refreshKeybinds then
            self_ref._msConfig.refreshKeybinds(self_ref)
        end
        ClearQueuedStillProcessingAnnouncements()

        if showProgress or stopReason then
            local completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_COMPLETE), processedCount)
            if stopReason == "bagFull" then
                completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_BAG_FULL), processedCount, totalItems)
            elseif stopReason == "sceneExit" then
                completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_ABORTED_SCENE_EXIT), sceneExitLabel or "Scene", processedCount, totalItems)
            elseif stopReason == "aborted" then
                completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_ABORTED_COMPLETE), processedCount, totalItems)
            elseif processedCount < totalItems then
                completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_PARTIAL_SUCCESS), processedCount, totalItems)
            end
            Overlay.Show(displayName, completeText)
            Overlay.Hide((stopReason and 4000) or 2000)
        else
            Overlay.Hide()
        end

        if isServerBound and processedCost > 0 then
            local nowMs = Cfg.GetNowMs()
            local postCooldownMs = 0
            local threshold = zo_max(postBatchCooldownThreshold, 0)
            if threshold == 0 or processedCost >= threshold then
                local extra = zo_max(processedCost - threshold, 0)
                postCooldownMs = postBatchCooldownBaseMs + (extra * postBatchCooldownPerCostMs)
                postCooldownMs = zo_clamp(postCooldownMs, 0, postBatchCooldownMaxMs)
            end
            if postCooldownMs > 0 then
                Cfg.SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs = zo_max(
                    Cfg.SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs or 0, nowMs + postCooldownMs)
            end
        end

        self_ref.batchAbortRequested = nil
        self_ref.batchSuppressUiUpdates = nil
        self_ref._msBatchWakeHandler = nil
        stillProcessingWaitUntilMs = 0
        stillProcessingAnnouncementActive = false
        Overlay.StopLayoutPulse()
        if onComplete then onComplete(stopReason) end
    end

    local function ResolveStillProcessingWaitMs(nowMs, waitMs)
        local resolvedNow = nowMs or Cfg.GetNowMs()
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
        local nowMs = Cfg.GetNowMs()
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
            return string.format("Processing (%d/%d) ~%s", processedCount, totalItems, Cfg.FormatEstimatedBatchDuration(remainingMs / 1000))
        end
        return string.format("Processing (%d/%d)", processedCount, totalItems)
    end

    local function BuildStillProcessingSecondaryText()
        local remainingWaitMs = ResolveStillProcessingWaitMs(Cfg.GetNowMs(), nil)
        if remainingWaitMs > 0 then
            return string.format("Continuing in %ds to prevent message rate limit logoff", zo_max(1, zo_ceil(remainingWaitMs / 1000)))
        end
        return string.format("Please Wait - Press %s to abort", Cfg.ResolveBatchAbortBindingMarkup())
    end

    local function ShowStillProcessingAnnouncement(waitMs, forceRecreate)
        if not showProgress then return end
        if waitMs and waitMs > 0 then ResolveStillProcessingWaitMs(Cfg.GetNowMs(), waitMs) end
        if stillProcessingAnnouncementActive and not forceRecreate then return end
        if forceRecreate then ClearQueuedStillProcessingAnnouncements() end
        Overlay.Show(displayName, BuildStillProcessingMainText, BuildStillProcessingSecondaryText)
        stillProcessingAnnouncementActive = true
    end

    processNext = function()
        -- Pipeline token guard: reject stale timer callbacks from previous batch
        if pipelineToken ~= self_ref.batchPipelineToken then return end
        local actionQueued = false
        local bagId, slotIndex = nil, nil
        while true do
            if not Cfg.IsBatchSceneShowing(self_ref) then stopReason = "sceneExit"; finishBatch(); return end
            if self_ref.batchAbortRequested then stopReason = "aborted"; finishBatch(); return end
            if announceAfterCooldown then announceAfterCooldown = false; ShowStillProcessingAnnouncement() end

            if isServerBound and enforceRateWindow then
                local rateDelay = Cfg.ComputeServerActionDelayMs(Cfg.GetNowMs(), rateLimitWindowMs, rateLimitMaxActions)
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
                local result = actionFn(bagId, slotIndex, itemData)
                if result == false then
                    stopReason = "bagFull"
                elseif result == "skip" then
                    consecutiveQueuedActions = 0; skipToNext = true
                elseif type(result) == "string" and result ~= "" and result ~= "queued" then
                    stopReason = result
                else
                    processedCount = processedCount + 1
                    processedCost = processedCost + actionCost
                    actionQueued = (result == "queued")
                    consecutiveQueuedActions = actionQueued and (consecutiveQueuedActions + 1) or 0
                    if isServerBound and enforceRateWindow and (actionQueued or countTowardRateOnSuccess) then
                        Cfg.RecordServerAction(Cfg.GetNowMs(), rateLimitWindowMs)
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
                baseDelayMs = zo_clamp(baseDelayMs + Cfg.ResolveSignedJitter(jitterMs), minServerDelayMs, maxServerDelayMs)
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
            if self_ref.batchAbortRequested or not Cfg.IsBatchSceneShowing(self_ref) then
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
        if not Cfg.IsBatchSceneShowing(self_ref) then stopReason = "sceneExit"; finishBatch(); return end

        local dialogShowing = Overlay.IsAnyBatchActionDialogShowing()
        if dialogShowing and remainingWaitMs > 0 then
            zo_callLater(function()
                StartBatchAfterDialogDismiss(zo_max(remainingWaitMs - Cfg.BATCH_STATUS_DIALOG_CLOSE_POLL_MS, 0), settleDelayMs)
            end, Cfg.BATCH_STATUS_DIALOG_CLOSE_POLL_MS)
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

    StartBatchAfterDialogDismiss(Cfg.BATCH_STATUS_DIALOG_CLOSE_MAX_WAIT_MS, Cfg.BATCH_STATUS_DIALOG_SETTLE_MS)
end

-------------------------------------------------------------------------------------------------
-- BATCH OPERATION DELEGATES
-------------------------------------------------------------------------------------------------

Mixin.BatchLock = Actions.BatchLock
Mixin.BatchUnlock = Actions.BatchUnlock
Mixin.BatchMarkAsJunk = Actions.BatchMarkAsJunk
Mixin.BatchUnmarkAsJunk = Actions.BatchUnmarkAsJunk
Mixin.AnalyzeSelectedItems = Actions.AnalyzeSelectedItems
Mixin.CreateDialogEntry = Actions.CreateDialogEntry
Mixin.AppendCommonBatchEntries = Actions.AppendCommonBatchEntries
