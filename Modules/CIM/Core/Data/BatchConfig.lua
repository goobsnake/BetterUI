--[[
File: Modules/CIM/Core/BatchConfig.lua
Purpose: Server pacing configuration, timing constants, and shared utility
         helpers for the multi-select batch processing pipeline.

Extracted from: MultiSelectMixin.lua (config/helpers concern)
Author: BetterUI Team
Last Modified: 2026-03-14
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.BatchConfig = BETTERUI.CIM.BatchConfig or {}

local BatchConfig = BETTERUI.CIM.BatchConfig

-------------------------------------------------------------------------------------------------
-- THROTTLE TIER CONFIGURATION
-------------------------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------------------------
-- SERVER PACING DEFAULTS
-------------------------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------------------------
-- RESOLVED SERVER PACING VALUES
-------------------------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------------------------
-- DIALOG TIMING CONSTANTS
-------------------------------------------------------------------------------------------------

BatchConfig.BATCH_STATUS_DIALOG_CLOSE_POLL_MS = 25
BatchConfig.BATCH_STATUS_DIALOG_CLOSE_MAX_WAIT_MS = 1800
BatchConfig.BATCH_STATUS_DIALOG_SETTLE_MS = 160

-------------------------------------------------------------------------------------------------
-- SHARED RECOVERY STATE
-------------------------------------------------------------------------------------------------

BatchConfig.SERVER_BATCH_RECOVERY_STATE = {
    cooldownUntilMs = 0,
    serverActionTimes = {},
}

-------------------------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
-------------------------------------------------------------------------------------------------

--- Resolves the appropriate throttle tier for a given total item count.
--- @param totalItems number
--- @return table tier
function BatchConfig.ResolveBatchThrottleProfile(totalItems)
    for i = 1, #BatchConfig.BATCH_THROTTLE_TIERS do
        local tier = BatchConfig.BATCH_THROTTLE_TIERS[i]
        local minItems = tier.MIN_ITEMS or 0
        if totalItems >= minItems then
            return tier
        end
    end
    return BatchConfig.DEFAULT_BATCH_THROTTLE_TIERS[#BatchConfig.DEFAULT_BATCH_THROTTLE_TIERS]
end

--- Resolves a boolean option with a fallback default.
--- @param value boolean|nil
--- @param fallback boolean
--- @return boolean
function BatchConfig.ResolveBooleanOption(value, fallback)
    if value == nil then
        return fallback
    end
    return value == true
end

--- Resolves a positive integer option with a fallback default.
--- @param value number|nil
--- @param fallback number
--- @return number
function BatchConfig.ResolvePositiveIntOption(value, fallback)
    local resolved = tonumber(value)
    if not resolved then
        return fallback
    end
    return zo_max(0, zo_ceil(resolved))
end

--- Resolves a signed jitter offset in range [-maxAbsMs, +maxAbsMs].
--- @param maxAbsMs number
--- @return number
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
--- @return number
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
--- @param nowMs number
--- @param windowMs number
--- @return table history
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
        return history
    end

    local cutoff = nowMs - windowMs
    while history[1] and history[1] <= cutoff do
        table.remove(history, 1)
    end

    return history
end

--- Records a server action timestamp.
--- @param nowMs number
--- @param windowMs number
function BatchConfig.RecordServerAction(nowMs, windowMs)
    local history = BatchConfig.PruneServerActionHistory(nowMs, windowMs)
    history[#history + 1] = nowMs
end

--- Computes the delay needed before the next server action to stay within rate limits.
--- @param nowMs number
--- @param windowMs number
--- @param maxActions number
--- @return number delayMs
function BatchConfig.ComputeServerActionDelayMs(nowMs, windowMs, maxActions)
    if windowMs <= 0 or maxActions <= 0 then
        return 0
    end

    local history = BatchConfig.PruneServerActionHistory(nowMs, windowMs)
    if #history < maxActions then
        return 0
    end

    local anchorIndex = #history - maxActions + 1
    local anchorTime = history[anchorIndex] or history[1]
    if not anchorTime then
        return 0
    end

    return zo_max((anchorTime + windowMs) - nowMs, 0)
end

--- Checks whether the owning scene is visible for the given module instance.
--- @param self table
--- @return boolean
function BatchConfig.IsBatchSceneShowing(self)
    if self and self._msConfig and self._msConfig.isSceneShowing then
        return self._msConfig.isSceneShowing(self) == true
    end

    if self and self.IsSceneShowing then
        return self:IsSceneShowing() == true
    end

    return true
end

--- Resolves the label shown when a batch is aborted due to scene exit.
--- @param self table
--- @param batchOptions table|nil
--- @return string
function BatchConfig.ResolveSceneExitLabel(self, batchOptions)
    if batchOptions and type(batchOptions.sceneExitLabel) == "string" and batchOptions.sceneExitLabel ~= "" then
        return batchOptions.sceneExitLabel
    end

    if self and self._msConfig and type(self._msConfig.getSceneExitLabel) == "function" then
        local configLabel = self._msConfig.getSceneExitLabel(self)
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
--- @param bagId number
--- @param slotIndex number
--- @return string
function BatchConfig.BuildSlotKey(bagId, slotIndex)
    return tostring(bagId) .. ":" .. tostring(slotIndex)
end

--- Checks if there is an item at the given bag/slot.
--- @param bagId number
--- @param slotIndex number
--- @return boolean
function BatchConfig.HasItemAtSlot(bagId, slotIndex)
    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
    return (stackCount or 0) > 0
end

--- Normalizes and deduplicates a list of batch items.
--- @param items table
--- @return table normalized
function BatchConfig.NormalizeBatchItems(items)
    local normalized = {}
    local seen = {}

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
        end
    end

    return normalized
end

--- Estimates the total batch duration in seconds.
--- @return number estimatedSeconds
function BatchConfig.EstimateBatchDurationSeconds(totalItems, delayMs, cooldownEvery, cooldownMs,
                                                   totalCostUnits, chunkCostUnits, chunkPauseMs, initialDelayMs)
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
--- @param estimatedSeconds number
--- @return string
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
--- @return string
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
