--[[
File: Modules/CIM/Core/Batching/BatchConfig.lua
Purpose: Server pacing configuration, timing constants, and shared utility
         helpers for the multi-select batch processing pipeline.

Extracted from: MultiSelectMixin.lua (config/helpers concern)
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.BatchConfig = BETTERUI.CIM.BatchConfig or {}

---@class BETTERUI.CIM.BatchConfig
---@field BATCH_THROTTLE_TIERS BatchThrottleTier[]
---@field DEFAULT_BATCH_THROTTLE_TIERS BatchThrottleTier[]
---@field BATCH_ETA_THRESHOLD number
---@field DEFAULT_ACTION_COST_UNITS number
---@field SERVER_COOLDOWN_EVERY number
---@field SERVER_COOLDOWN_MS number
---@field SERVER_MIN_DELAY_MS number
---@field SERVER_MAX_DELAY_MS number
---@field SERVER_ACK_TIMEOUT_MS number
---@field SERVER_CHUNK_COST_UNITS number
---@field SERVER_CHUNK_PAUSE_MS number
---@field SERVER_AWAIT_INVENTORY_ACK boolean
---@field SERVER_ADAPTIVE_DELAY boolean
---@field SERVER_ADAPTIVE_THRESHOLD number
---@field SERVER_ADAPTIVE_STEP_MS number
---@field SERVER_JITTER_MS number
---@field SERVER_RATE_WINDOW_MS number
---@field SERVER_RATE_MAX_ACTIONS number
---@field SERVER_BATCH_RECOVERY_STATE BatchRecoveryState
---@field BATCH_OPTIONS table
local BatchConfig = BETTERUI.CIM.BatchConfig

---@class BatchThrottleTier
---@field MIN_ITEMS number
---@field DELAY_MS number
---@field SHOW_PROGRESS boolean

---@class BatchOptions
---@field ui table
---@field server table
---@field pacing table
---@field ack table
---@field rateLimit table
---@field postBatch table
---@field lifecycle table
---@field scene table

---@class BatchRecoveryState
---@field cooldownUntilMs number
---@field serverActionTimes number[]

---@class BetterUIBatchStepResult
---@field status string
---@field reason string|nil

---@alias BetterUIBatchCompletionReason
---| "bagFull"
---| "sceneExit"
---| "aborted"
---| "stopped"

---@alias BetterUIBatchCompletionCallback fun(stopReason: BetterUIBatchCompletionReason|nil)

---@class BetterUIBatchRequest
---@field items table[]
---@field step fun(bagId:number, slotIndex:number, itemData:table):BetterUIBatchStepResult|nil
---@field onComplete BetterUIBatchCompletionCallback|nil
---@field actionName string|nil
---@field options BatchOptions|table|nil

---@class BetterUIVendorBatchRequest: BetterUIBatchRequest
---@field mode number

-- THROTTLE TIER CONFIGURATION

local DEFAULT_BATCH_THROTTLE_TIERS = {
    { MIN_ITEMS = 50, DELAY_MS = 125, SHOW_PROGRESS = true },
    { MIN_ITEMS = 10, DELAY_MS = 100, SHOW_PROGRESS = true },
    { MIN_ITEMS = 0,  DELAY_MS = 75,  SHOW_PROGRESS = false },
}

local TIMING = BETTERUI.CIM.CONST.TIMING or {}

BatchConfig.BATCH_THROTTLE_TIERS = TIMING.BATCH_ACTION_THROTTLE_TIERS or DEFAULT_BATCH_THROTTLE_TIERS
BatchConfig.DEFAULT_BATCH_THROTTLE_TIERS = DEFAULT_BATCH_THROTTLE_TIERS
BatchConfig.BATCH_ETA_THRESHOLD = TIMING.BATCH_ETA_THRESHOLD or 50
BatchConfig.DEFAULT_ACTION_COST_UNITS = 1

-- SERVER PACING DEFAULTS

local DEFAULT_SERVER_COOLDOWN_EVERY = 25
local DEFAULT_SERVER_COOLDOWN_MS = 1100
local DEFAULT_SERVER_MIN_DELAY_MS = 125
local DEFAULT_SERVER_MAX_DELAY_MS = 325
local DEFAULT_SERVER_ACK_TIMEOUT_MS = 1800
local DEFAULT_SERVER_CHUNK_COST_UNITS = 36
local DEFAULT_SERVER_CHUNK_PAUSE_MS = 950
local DEFAULT_SERVER_ADAPTIVE_DELAY = true
local DEFAULT_SERVER_ADAPTIVE_THRESHOLD = 8
local DEFAULT_SERVER_ADAPTIVE_STEP_MS = 16
local DEFAULT_SERVER_JITTER_MS = 18
local DEFAULT_SERVER_POST_BATCH_COOLDOWN_BASE_MS = 3000
local DEFAULT_SERVER_POST_BATCH_COOLDOWN_THRESHOLD = 50
local DEFAULT_SERVER_POST_BATCH_COOLDOWN_PER_COST_MS = 35
local DEFAULT_SERVER_POST_BATCH_COOLDOWN_MAX_MS = 9000
local DEFAULT_SERVER_RATE_WINDOW_MS = 60000
local DEFAULT_SERVER_RATE_MAX_ACTIONS = 125

-- RESOLVED SERVER PACING VALUES

BatchConfig.SERVER_COOLDOWN_EVERY = TIMING.BATCH_SERVER_COOLDOWN_EVERY or DEFAULT_SERVER_COOLDOWN_EVERY
BatchConfig.SERVER_COOLDOWN_MS = TIMING.BATCH_SERVER_COOLDOWN_MS or DEFAULT_SERVER_COOLDOWN_MS
BatchConfig.SERVER_MIN_DELAY_MS = TIMING.BATCH_SERVER_MIN_DELAY_MS or DEFAULT_SERVER_MIN_DELAY_MS
BatchConfig.SERVER_MAX_DELAY_MS = TIMING.BATCH_SERVER_MAX_DELAY_MS or DEFAULT_SERVER_MAX_DELAY_MS
BatchConfig.SERVER_ACK_TIMEOUT_MS = TIMING.BATCH_SERVER_ACK_TIMEOUT_MS or DEFAULT_SERVER_ACK_TIMEOUT_MS
BatchConfig.SERVER_CHUNK_COST_UNITS = TIMING.BATCH_SERVER_CHUNK_COST_UNITS or DEFAULT_SERVER_CHUNK_COST_UNITS
BatchConfig.SERVER_CHUNK_PAUSE_MS = TIMING.BATCH_SERVER_CHUNK_PAUSE_MS or DEFAULT_SERVER_CHUNK_PAUSE_MS

local SERVER_AWAIT_INVENTORY_ACK = TIMING.BATCH_SERVER_AWAIT_INVENTORY_ACK
if SERVER_AWAIT_INVENTORY_ACK == nil then
    SERVER_AWAIT_INVENTORY_ACK = true
end
BatchConfig.SERVER_AWAIT_INVENTORY_ACK = SERVER_AWAIT_INVENTORY_ACK

local SERVER_ADAPTIVE_DELAY = TIMING.BATCH_SERVER_ADAPTIVE_DELAY
if SERVER_ADAPTIVE_DELAY == nil then
    SERVER_ADAPTIVE_DELAY = DEFAULT_SERVER_ADAPTIVE_DELAY
end
BatchConfig.SERVER_ADAPTIVE_DELAY = SERVER_ADAPTIVE_DELAY

BatchConfig.SERVER_ADAPTIVE_THRESHOLD = TIMING.BATCH_SERVER_ADAPTIVE_THRESHOLD or DEFAULT_SERVER_ADAPTIVE_THRESHOLD
BatchConfig.SERVER_ADAPTIVE_STEP_MS = TIMING.BATCH_SERVER_ADAPTIVE_STEP_MS or DEFAULT_SERVER_ADAPTIVE_STEP_MS
BatchConfig.SERVER_JITTER_MS = TIMING.BATCH_SERVER_JITTER_MS or DEFAULT_SERVER_JITTER_MS
BatchConfig.SERVER_POST_BATCH_COOLDOWN_BASE_MS = TIMING.BATCH_SERVER_POST_BATCH_COOLDOWN_BASE_MS
    or DEFAULT_SERVER_POST_BATCH_COOLDOWN_BASE_MS
BatchConfig.SERVER_POST_BATCH_COOLDOWN_THRESHOLD = TIMING.BATCH_SERVER_POST_BATCH_COOLDOWN_THRESHOLD
    or DEFAULT_SERVER_POST_BATCH_COOLDOWN_THRESHOLD
BatchConfig.SERVER_POST_BATCH_COOLDOWN_PER_COST_MS = TIMING.BATCH_SERVER_POST_BATCH_COOLDOWN_PER_COST_MS
    or DEFAULT_SERVER_POST_BATCH_COOLDOWN_PER_COST_MS
BatchConfig.SERVER_POST_BATCH_COOLDOWN_MAX_MS = TIMING.BATCH_SERVER_POST_BATCH_COOLDOWN_MAX_MS
    or DEFAULT_SERVER_POST_BATCH_COOLDOWN_MAX_MS
BatchConfig.SERVER_RATE_WINDOW_MS = TIMING.BATCH_SERVER_RATE_WINDOW_MS or DEFAULT_SERVER_RATE_WINDOW_MS
BatchConfig.SERVER_RATE_MAX_ACTIONS = TIMING.BATCH_SERVER_RATE_MAX_ACTIONS or DEFAULT_SERVER_RATE_MAX_ACTIONS

-- DIALOG TIMING CONSTANTS

BatchConfig.BATCH_STATUS_DIALOG_CLOSE_POLL_MS = 25
BatchConfig.BATCH_STATUS_DIALOG_CLOSE_MAX_WAIT_MS = 1800
BatchConfig.BATCH_STATUS_DIALOG_SETTLE_MS = 160

-- SHARED RECOVERY STATE

BatchConfig.SERVER_BATCH_RECOVERY_STATE = {
    cooldownUntilMs = 0,
    serverActionTimes = {},
}

local function ResolveInitialValue(value, defaultValue)
    if value == nil then
        return defaultValue
    end
    return value
end

local function BuildDefaultBatchOptions()
    return {
        ui = {
            suppressUiUpdates = false,
            sceneExitLabel = nil,
        },
        server = {
            serverBound = false,
            costPerItem = BatchConfig.DEFAULT_ACTION_COST_UNITS,
            skipInterBatchCooldown = false,
        },
        pacing = {
            cooldownEvery = 0,
            cooldownMs = 0,
            minServerDelayMs = ResolveInitialValue(BatchConfig.SERVER_MIN_DELAY_MS, 0),
            maxServerDelayMs = ResolveInitialValue(BatchConfig.SERVER_MAX_DELAY_MS, 0),
            chunkCostUnits = ResolveInitialValue(BatchConfig.SERVER_CHUNK_COST_UNITS, 0),
            chunkPauseMs = ResolveInitialValue(BatchConfig.SERVER_CHUNK_PAUSE_MS, 0),
            adaptiveDelay = ResolveInitialValue(BatchConfig.SERVER_ADAPTIVE_DELAY, false),
            adaptiveThreshold = ResolveInitialValue(BatchConfig.SERVER_ADAPTIVE_THRESHOLD, 0),
            adaptiveStepMs = ResolveInitialValue(BatchConfig.SERVER_ADAPTIVE_STEP_MS, 0),
            jitterMs = ResolveInitialValue(BatchConfig.SERVER_JITTER_MS, 0),
        },
        ack = {
            awaitInventoryAck = ResolveInitialValue(BatchConfig.SERVER_AWAIT_INVENTORY_ACK, false),
            ackTimeoutMs = ResolveInitialValue(BatchConfig.SERVER_ACK_TIMEOUT_MS, 0),
            countTowardRateOnSuccess = true,
        },
        rateLimit = {
            enforceRateWindow = true,
            rateLimitWindowMs = ResolveInitialValue(BatchConfig.SERVER_RATE_WINDOW_MS, 0),
            rateLimitMaxActions = ResolveInitialValue(BatchConfig.SERVER_RATE_MAX_ACTIONS, 0),
        },
        postBatch = {
            postBatchCooldownBaseMs = ResolveInitialValue(BatchConfig.SERVER_POST_BATCH_COOLDOWN_BASE_MS, 0),
            postBatchCooldownThreshold = ResolveInitialValue(BatchConfig.SERVER_POST_BATCH_COOLDOWN_THRESHOLD, 0),
            postBatchCooldownPerCostMs = ResolveInitialValue(BatchConfig.SERVER_POST_BATCH_COOLDOWN_PER_COST_MS, 0),
            postBatchCooldownMaxMs = ResolveInitialValue(BatchConfig.SERVER_POST_BATCH_COOLDOWN_MAX_MS, 0),
        },
        lifecycle = {},
        scene = {},
    }
end

local function MergeBatchOptionsInto(target, source)
    if type(source) ~= "table" then
        return
    end

    for group, values in pairs(source) do
        if type(values) == "table" and type(target[group]) == "table" then
            for key, value in pairs(values) do
                target[group][key] = value
            end
        else
            target[group] = values
        end
    end
end

--- Creates a composed options table with known groups.
---@return BatchOptions empty
function BatchConfig.ComposeBatchOptions(...)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "batch options composed", {groupCount = select("#", ...)})
    end
    local options = BuildDefaultBatchOptions()
    for i = 1, select("#", ...) do
        MergeBatchOptionsInto(options, select(i, ...))
    end
    return options
end

function BatchConfig.WithUi(options)
    return { ui = options or {} }
end

function BatchConfig.WithServer(options)
    return { server = options or {} }
end

function BatchConfig.WithPacing(options)
    return { pacing = options or {} }
end

function BatchConfig.WithAck(options)
    return { ack = options or {} }
end

BatchConfig.BATCH_STEP_STATUS = {
    HANDLED = "handled",
    QUEUED = "queued",
    SKIPPED = "skipped",
    STOPPED = "stopped",
}

---@return BetterUIBatchStepResult
function BatchConfig.BatchStepHandled()
    return { status = BatchConfig.BATCH_STEP_STATUS.HANDLED }
end

---@return BetterUIBatchStepResult
function BatchConfig.BatchStepQueued()
    return { status = BatchConfig.BATCH_STEP_STATUS.QUEUED }
end

---@return BetterUIBatchStepResult
function BatchConfig.BatchStepSkipped()
    return { status = BatchConfig.BATCH_STEP_STATUS.SKIPPED }
end

---@param reason string
---@return BetterUIBatchStepResult
function BatchConfig.BatchStepStopped(reason)
    return {
        status = BatchConfig.BATCH_STEP_STATUS.STOPPED,
        reason = reason,
    }
end

---@param result BetterUIBatchStepResult|nil
---@return BetterUIBatchStepResult
function BatchConfig.NormalizeBatchStepResult(result)
    if type(result) == "table" and type(result.status) == "string" then
        local status = result.status
        if status == BatchConfig.BATCH_STEP_STATUS.HANDLED
            or status == BatchConfig.BATCH_STEP_STATUS.QUEUED
            or status == BatchConfig.BATCH_STEP_STATUS.SKIPPED
            or status == BatchConfig.BATCH_STEP_STATUS.STOPPED
        then
            return result
        end
    end

    return BatchConfig.BatchStepHandled()
end

--- Normalizes grouped batch options into a resolved grouped contract.
---@param batchOptions table|nil Batch options
---@return BatchOptions normalizedOptions
function BatchConfig.NormalizeBatchOptions(batchOptions)
    local normalized = BatchConfig.ComposeBatchOptions()

    if type(batchOptions) ~= "table" then
        return normalized
    end

    MergeBatchOptionsInto(normalized, batchOptions)

    return normalized
end

-- UTILITY FUNCTIONS

--- Resolves the appropriate throttle tier for a given total item count.
---@param totalItems number Total number of items in the batch
---@return BatchThrottleTier tier The matching throttle tier
function BatchConfig.ResolveBatchThrottleProfile(totalItems)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "throttle profile resolved", {totalItems = totalItems})
    end
    local tier = nil
    for i = 1, #BatchConfig.BATCH_THROTTLE_TIERS do
        tier = BatchConfig.BATCH_THROTTLE_TIERS[i]
        local minItems = tier.MIN_ITEMS or 0
        if totalItems >= minItems then
            if BETTERUI.Log and BETTERUI.Log.IsActive() then
                BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "throttle profile resolved", {totalItems = totalItems, delayMs = tier.DELAY_MS})
            end
            return tier
        end
    end
    tier = BatchConfig.DEFAULT_BATCH_THROTTLE_TIERS[#BatchConfig.DEFAULT_BATCH_THROTTLE_TIERS]
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "throttle profile resolved", {totalItems = totalItems, delayMs = tier.DELAY_MS})
    end
    return tier
end

--- Resolves a boolean option with a fallback default.
---@param value any Value to resolve (may be nil or non-boolean)
---@param fallback boolean Default value when value is nil
---@return boolean
function BatchConfig.ResolveBooleanOption(value, fallback)
    if value == nil then
        return fallback
    end
    return value == true
end

--- Resolves a positive integer option with a fallback default.
---@param value any Value to resolve (may be nil or non-numeric)
---@param fallback number Default value when value cannot be converted
---@return number
function BatchConfig.ResolvePositiveIntOption(value, fallback)
    local resolved = tonumber(value)
    if not resolved then
        return fallback
    end
    return zo_max(0, zo_ceil(resolved))
end

--- Resolves a signed jitter offset in range [-maxAbsMs, +maxAbsMs].
---@param maxAbsMs number Maximum absolute jitter in milliseconds
---@return number jitter Signed offset in [-maxAbsMs, +maxAbsMs]
function BatchConfig.ResolveSignedJitter(maxAbsMs)
    if maxAbsMs <= 0 then
        return 0
    end
    if zo_random then
        return zo_random(-maxAbsMs, maxAbsMs)
    end
    return math.random(-maxAbsMs, maxAbsMs)
end

--- Gets the current time in milliseconds using the best available API.
---@return number nowMs Current time in milliseconds
function BatchConfig.GetNowMs()
    if GetGameTimeMilliseconds then
        return GetGameTimeMilliseconds()
    end

    if GetFrameTimeMilliseconds then
        return GetFrameTimeMilliseconds()
    end

    if GetFrameTimeSeconds then
        return zo_floor(GetFrameTimeSeconds() * 1000)
    end

    return 0
end

--- Prunes stale entries from the server action history.
---@param nowMs number Current time in milliseconds
---@param windowMs number Rate-limit window size in milliseconds
---@return number[] history Pruned action timestamps
function BatchConfig.PruneServerActionHistory(nowMs, windowMs)
    local history = BatchConfig.SERVER_BATCH_RECOVERY_STATE.serverActionTimes
    if not history then
        history = {}
        BatchConfig.SERVER_BATCH_RECOVERY_STATE.serverActionTimes = history
    end

    -- Defend against timer rollover/reset (e.g., long session wraparound).
    local newest = history[#history]
    if newest and nowMs < newest then
        history = {}
        BatchConfig.SERVER_BATCH_RECOVERY_STATE.serverActionTimes = history
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "server action history pruned", {retained = #history})
        end
        return history
    end

    local cutoff = nowMs - windowMs
    while history[1] and history[1] <= cutoff do
        table.remove(history, 1)
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "server action history pruned", {retained = #history})
    end
    return history
end

--- Records a server action timestamp.
---@param nowMs number Current time in milliseconds
---@param windowMs number Rate-limit window size in milliseconds
function BatchConfig.RecordServerAction(nowMs, windowMs)
    local history = BatchConfig.PruneServerActionHistory(nowMs, windowMs)
    history[#history + 1] = nowMs
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "server action recorded", {nowMs = nowMs})
    end
end

--- Computes the delay needed before the next server action to stay within rate limits.
---@param nowMs number Current time in milliseconds
---@param windowMs number Rate-limit window size in milliseconds
---@param maxActions number Maximum actions allowed in the window
---@return number delayMs Delay in milliseconds before next action is allowed
function BatchConfig.ComputeServerActionDelayMs(nowMs, windowMs, maxActions)
    if windowMs <= 0 or maxActions <= 0 then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "rate limit delay computed", {delayMs = 0})
        end
        return 0
    end

    local history = BatchConfig.PruneServerActionHistory(nowMs, windowMs)
    if #history < maxActions then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "rate limit delay computed", {delayMs = 0})
        end
        return 0
    end

    local anchorIndex = #history - maxActions + 1
    local anchorTime = history[anchorIndex] or history[1]
    if not anchorTime then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "rate limit delay computed", {delayMs = 0})
        end
        return 0
    end

    local delayMs = zo_max((anchorTime + windowMs) - nowMs, 0)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "rate limit delay computed", {delayMs = delayMs})
    end
    return delayMs
end

--- Checks whether the owning scene is visible for the given module instance.
---@param self table Module instance with optional _multiSelectConfig or IsSceneShowing
---@return boolean showing True if the batch scene is currently visible
function BatchConfig.IsBatchSceneShowing(self)
    local showing = true
    if self and self._multiSelectConfig and self._multiSelectConfig.isSceneShowing then
        showing = self._multiSelectConfig.isSceneShowing(self) == true
    elseif self and self.IsSceneShowing then
        showing = self:IsSceneShowing() == true
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "scene showing", {showing = showing})
    end
    return showing
end

--- Resolves the label shown when a batch is aborted due to scene exit.
---@param self table Module instance with optional _multiSelectConfig
---@param batchOptions table|nil Batch options with optional scene group or sceneExitLabel.
---@return string label Human-readable scene exit label
function BatchConfig.ResolveSceneExitLabel(self, batchOptions)
    if batchOptions then
        if type(batchOptions.scene) == "table" and type(batchOptions.scene.sceneExitLabel) == "string" and batchOptions.scene.sceneExitLabel ~= "" then
            return batchOptions.scene.sceneExitLabel
        end
    end

    if self and self._multiSelectConfig and type(self._multiSelectConfig.getSceneExitLabel) == "function" then
        local configLabel = self._multiSelectConfig.getSceneExitLabel(self)
        if type(configLabel) == "string" and configLabel ~= "" then
            return configLabel
        end
    end

    if GetString and SI_BETTERUI_SCENE_INVENTORY then
        local fallbackLabel = GetString(rawget(_G, "SI_BETTERUI_SCENE_INVENTORY"))
        if type(fallbackLabel) == "string" and fallbackLabel ~= "" then
            return fallbackLabel
        end
    end

    return "Scene"
end

--- Builds a unique slot key for deduplication.
---@param bagId number Bag identifier
---@param slotIndex number Slot index within the bag
---@return string key Unique key in "bagId:slotIndex" format
function BatchConfig.BuildSlotKey(bagId, slotIndex)
    return tostring(bagId) .. ":" .. tostring(slotIndex)
end

--- Checks if there is an item at the given bag/slot.
---@param bagId number Bag identifier
---@param slotIndex number Slot index within the bag
---@return boolean hasItem True if slot has a non-zero stack
function BatchConfig.HasItemAtSlot(bagId, slotIndex)
    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
    return (stackCount or 0) > 0
end

--- Normalizes and deduplicates a list of batch items.
---@param items table[] Array of item data tables with bagId/slotIndex
---@return table[] normalized Deduplicated items with confirmed slot occupancy
function BatchConfig.NormalizeBatchItems(items)
    local normalized = {}
    local seen = {}
    local droppedCount = 0

    for _, itemData in ipairs(items) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex

        if bagId and slotIndex and BatchConfig.HasItemAtSlot(bagId, slotIndex) then
            local slotKey = BatchConfig.BuildSlotKey(bagId, slotIndex)
            if not seen[slotKey] then
                seen[slotKey] = true
                normalized[#normalized + 1] = itemData
            end
        else
            -- Selections without bag/slot ids (e.g. entryIndex-only rows) and
            -- empty slots cannot be batch-processed; count them so the drop is
            -- visible on the debug channel instead of silent.
            droppedCount = droppedCount + 1
        end
    end

    if droppedCount > 0 and BETTERUI and BETTERUI.Log then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.BATCH, string.format("[Batch] NormalizeBatchItems dropped %d unprocessable selection(s)", droppedCount))
    end

    return normalized
end

--- Estimates the total batch duration in seconds.
---@param totalItems number Number of items in the batch
---@param delayMs number Per-item delay in milliseconds
---@param cooldownEvery number|nil Items between server cooldowns
---@param cooldownMs number|nil Duration of each server cooldown in milliseconds
---@param totalCostUnits number|nil Total cost units (defaults to totalItems)
---@param chunkCostUnits number|nil Cost units per chunk boundary
---@param chunkPauseMs number|nil Pause duration at chunk boundaries
---@param initialDelayMs number|nil Initial delay before first action
---@return number seconds Estimated total batch duration
function BatchConfig.EstimateBatchDurationSeconds(totalItems, delayMs, cooldownEvery, cooldownMs,
                                                   totalCostUnits, chunkCostUnits, chunkPauseMs, initialDelayMs)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "batch duration estimated", {totalItems = totalItems, delayMs = delayMs})
    end
    local itemCount = zo_max(totalItems, 0)
    local estimateMs = itemCount * zo_max(delayMs or 0, 0)
    local cooldownUnits = zo_max(totalCostUnits or itemCount, 0)
    if itemCount > 1 and cooldownEvery and cooldownEvery > 0 and cooldownMs and cooldownMs > 0 then
        local cooldownCount = zo_floor(zo_max(cooldownUnits - 1, 0) / cooldownEvery)
        estimateMs = estimateMs + (cooldownCount * cooldownMs)
    end
    if itemCount > 1 and chunkCostUnits and chunkCostUnits > 0 and chunkPauseMs and chunkPauseMs > 0 then
        local chunkCount = zo_floor(zo_max(cooldownUnits - 1, 0) / chunkCostUnits)
        estimateMs = estimateMs + (chunkCount * chunkPauseMs)
    end
    estimateMs = estimateMs + zo_max(initialDelayMs or 0, 0)
    return estimateMs / 1000
end

--- Formats an estimated duration in seconds as a human-readable string.
---@param estimatedSeconds number Duration in seconds
---@return string formatted Human-readable duration string
function BatchConfig.FormatEstimatedBatchDuration(estimatedSeconds)
    local roundedSeconds = zo_max(1, zo_ceil(estimatedSeconds or 0))
    if roundedSeconds < 60 then
        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_DURATION_SECONDS")), roundedSeconds)
    end

    local minutes = zo_floor(roundedSeconds / 60)
    local seconds = roundedSeconds - (minutes * 60)
    return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_DURATION_MINUTES_SECONDS")), minutes, seconds)
end

--- Resolves the batch abort keybinding markup for display.
---@return string bindingMarkup Keybind display text or icon markup
function BatchConfig.ResolveBatchAbortBindingMarkup()
    if not ZO_Keybindings_GetHighestPriorityBindingStringFromAction then
        return "Y"
    end

    local bindingMarkup = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
        "UI_SHORTCUT_TERTIARY",
        KEYBIND_TEXT_OPTIONS_FULL_NAME,
        KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP
    )
    if bindingMarkup and bindingMarkup ~= "" then
        return bindingMarkup
    end

    local fallbackBinding = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
        "UI_SHORTCUT_TERTIARY",
        KEYBIND_TEXT_OPTIONS_FULL_NAME,
        KEYBIND_TEXTURE_OPTIONS_NONE
    )
    if fallbackBinding and fallbackBinding ~= "" then
        return fallbackBinding
    end

    return "Y"
end
