--[[
File: Modules/CIM/Dialogs/DialogRestore.lua
Purpose: Shared dialog-restore scheduler for the Inventory action-dialog and
         state-restore paths. Both callers previously carried a byte-identical
         trace/log helper plus a 120-retry / 50ms zo_callLater restore loop; this
         centralizes them so the retry cadence and STATE-category tracing stay
         consistent across the two flows.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.DialogRestore = BETTERUI.CIM.DialogRestore or {}

local DialogRestore = BETTERUI.CIM.DialogRestore

local DEFAULT_MAX_RETRIES = 120
local DEFAULT_INTERVAL_MS = 50

--- Trace + log helper for dialog-restore progress. Scans the message for a known
--- phase keyword and emits a STATE-category TraceEvent plus a Warn/Debug line.
--- (Formerly the byte-identical LogInventoryDialogRestore / LogActionDialogRestore.)
---@param message string Human-readable progress message (also drives the trace phase)
---@param data table|nil Structured trace payload
---@param warn boolean|nil When true, routes to Warn + WARN-level trace instead of Debug
function DialogRestore.Log(message, data, warn)
    local L = BETTERUI.Log
    if not L then return end
    if L.TraceEvent then
        local phase = "state"
        if message and message:find("complete", 1, true) then
            phase = "complete"
        elseif message and message:find("waiting", 1, true) then
            phase = "waiting"
        elseif message and message:find("skipped", 1, true) then
            phase = "skipped"
        elseif message and message:find("abandoned", 1, true) then
            phase = "abandoned"
        end
        L.TraceEvent(L.CATEGORY.STATE, "inventory.action_dialog.restore", phase, data, warn and L.LEVEL.WARN or L.LEVEL.INFO)
    end
    if warn and L.Warn then
        L.Warn(L.CATEGORY.STATE, message, data)
    elseif L.Debug then
        L.Debug(L.CATEGORY.STATE, message, data)
    end
end

-- Monotonic per-key sequence counters keep retry task names unique between flows
-- (the game-time-ms component already disambiguates, this is the tiebreaker).
local sequences = {}
local function NextRetryTaskName(sequenceKey, taskName)
    sequences[sequenceKey] = (sequences[sequenceKey] or 0) + 1
    return tostring(taskName)
        .. "_"
        .. tostring((GetGameTimeMilliseconds and GetGameTimeMilliseconds()) or 0)
        .. "_"
        .. tostring(sequences[sequenceKey])
end

--- Schedule a dialog-restore attempt with a bounded retry loop.
--- tryFn(retryTaskName, retriesRemaining) must return truthy once restore has
--- succeeded (or is safely skipped) so the loop stops; while it returns falsey the
--- loop retries every opts.intervalMs up to opts.maxRetries times, then calls
--- opts.onAbandon(retryTaskName). Retries prefer BETTERUI.Inventory.Tasks (which
--- dedupes by task name) and fall back to zo_callLater.
---@param self table Instance the caller's tryFn closes over (passed through untouched)
---@param tryFn fun(retryTaskName: string, retriesRemaining: number): boolean
---@param opts table { taskName, sequenceKey?, maxRetries?, intervalMs?, onAbandon? }
---@return boolean completed true when the first attempt succeeded (no retries scheduled)
function DialogRestore.Schedule(self, tryFn, opts)
    opts = opts or {}
    local maxRetries = opts.maxRetries or DEFAULT_MAX_RETRIES
    local intervalMs = opts.intervalMs or DEFAULT_INTERVAL_MS
    local taskName = opts.taskName or "inventoryDialogRestore"
    local sequenceKey = opts.sequenceKey or taskName
    local retryTaskName = NextRetryTaskName(sequenceKey, taskName)
    local retriesRemaining = maxRetries

    if tryFn(retryTaskName, retriesRemaining) then
        return true
    end

    local function RetryRestore()
        if tryFn(retryTaskName, retriesRemaining) then
            return
        end

        retriesRemaining = retriesRemaining - 1
        if retriesRemaining <= 0 then
            if opts.onAbandon then
                opts.onAbandon(retryTaskName)
            end
            return
        end

        local tasks = BETTERUI.Inventory and BETTERUI.Inventory.Tasks
        if tasks and tasks.Schedule then
            tasks:Schedule(retryTaskName, intervalMs, RetryRestore)
        else
            zo_callLater(RetryRestore, intervalMs)
        end
    end

    RetryRestore()
    return false
end
