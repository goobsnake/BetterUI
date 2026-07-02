--[[
File: Modules/CIM/Core/Diagnostics/Watchdog.lua
Purpose: Expectation watchdog for builog follow-along anomaly detection.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local Watchdog = {}
BETTERUI.CIM.Watchdog = Watchdog

local MAX_PENDING = 64
local SWEEP_INTERVAL_MS = 1000

local pending = {}
local order = {}
local pendingCount = 0
local timerId = nil
local timerScheduled = false
local stats = { detected = 0, resolved = 0 }

local function G(name) return rawget(_G, name) end

local function removeOrderId(id)
    for i = #order, 1, -1 do
        if order[i] == id then
            table.remove(order, i)
        end
    end
end

local function safeTostring(value, fallback)
    local ok, text = pcall(tostring, value)
    if ok and type(text) == "string" and text ~= "" then return text end
    return fallback or "?"
end

local function now()
    local getMs = G("GetFrameTimeMilliseconds")
    if type(getMs) == "function" then
        local ok, value = pcall(getMs)
        if ok and type(value) == "number" then return value end
    end
    return 0
end

local function log()
    return BETTERUI and BETTERUI.Log or nil
end

local function isActive()
    local L = log()
    if not (L and type(L.IsActive) == "function") then return false end
    local ok, active = pcall(L.IsActive)
    return ok and active == true
end

local function compoundKey(kind, key)
    return safeTostring(kind, "unknown") .. "\031" .. safeTostring(key, "unknown")
end

local function copyContext(context)
    local payload = {}
    if type(context) ~= "table" then return payload end
    for k, v in pairs(context) do
        if type(k) == "string" and k ~= "kind" and k ~= "key" and k ~= "ageMs" and k ~= "timeoutMs" then
            payload[k] = v
        end
    end
    return payload
end

local function traceAnomaly(phase, payload)
    local L = log()
    if not (L and type(L.TraceEvent) == "function") then return end
    local category = L.CATEGORY and L.CATEGORY.STATE or "STATE"
    local level = L.LEVEL and L.LEVEL.WARN or nil
    pcall(L.TraceEvent, category, "anomaly", phase, payload, level)
end

local function cancelTimer()
    local remove = G("zo_removeCallLater")
    if timerId and type(remove) == "function" then
        pcall(remove, timerId)
    end
    timerId = nil
    timerScheduled = false
end

local scheduleSweep

local function removePending(id)
    local record = pending[id]
    if not record then return nil end
    pending[id] = nil
    removeOrderId(id)
    pendingCount = math.max(0, pendingCount - 1)
    return record
end

local function dropOldestForOverflow()
    while #order > 0 do
        local id = table.remove(order, 1)
        local record = removePending(id)
        if record then
            traceAnomaly("overflow", {
                kind = record.kind,
                key = record.key,
                droppedKind = record.kind,
                droppedKey = record.key,
                pending = pendingCount,
                maxPending = MAX_PENDING,
            })
            return
        end
    end
end

local function sweep()
    timerId = nil
    timerScheduled = false
    if not isActive() then return end
    if pendingCount <= 0 then return end

    local current = now()
    local expired = {}
    for id, record in pairs(pending) do
        if current - record.startedAt >= record.timeoutMs then
            expired[#expired + 1] = id
        end
    end

    for i = 1, #expired do
        local record = removePending(expired[i])
        if record then
            local payload = copyContext(record.context)
            payload.kind = record.kind
            payload.key = record.key
            payload.ageMs = math.max(0, current - record.startedAt)
            payload.timeoutMs = record.timeoutMs
            stats.detected = stats.detected + 1
            traceAnomaly("detected", payload)
        end
    end

    if pendingCount > 0 then scheduleSweep() end
end

scheduleSweep = function()
    if timerScheduled or pendingCount <= 0 or not isActive() then return end
    local callLater = G("zo_callLater")
    if type(callLater) ~= "function" then return end
    timerScheduled = true
    local ok, id = pcall(callLater, sweep, SWEEP_INTERVAL_MS)
    if ok then
        timerId = id
    else
        timerScheduled = false
        timerId = nil
    end
end

local function expectImpl(kind, key, timeoutMs, context)
    if not isActive() then return false end
    local normalizedKind = safeTostring(kind, "unknown")
    local normalizedKey = safeTostring(key, "unknown")
    local timeout = tonumber(timeoutMs) or SWEEP_INTERVAL_MS
    if timeout < 1 then timeout = SWEEP_INTERVAL_MS end
    local id = compoundKey(normalizedKind, normalizedKey)

    if not pending[id] and pendingCount >= MAX_PENDING then
        dropOldestForOverflow()
    end

    if not pending[id] then
        pendingCount = pendingCount + 1
        order[#order + 1] = id
    end

    pending[id] = {
        kind = normalizedKind,
        key = normalizedKey,
        timeoutMs = timeout,
        startedAt = now(),
        context = copyContext(context),
    }
    scheduleSweep()
    return true
end

local function resolveImpl(kind, key)
    local record = removePending(compoundKey(kind, key))
    if record then
        stats.resolved = stats.resolved + 1
        if pendingCount <= 0 then cancelTimer() end
        return true, record
    end
    if pendingCount <= 0 then cancelTimer() end
    return false
end

function Watchdog.Expect(kind, key, timeoutMs, context)
    local ok, result = pcall(expectImpl, kind, key, timeoutMs, context)
    if ok then return result == true end
    return false
end

function Watchdog.Resolve(kind, key, outcome)
    local ok, result = pcall(resolveImpl, kind, key, outcome)
    if ok then return result == true end
    return false
end

function Watchdog.Deactivate()
    cancelTimer()
    pending = {}
    order = {}
    pendingCount = 0
end

function Watchdog.GetStats()
    local pendingFlows = 0
    for _, record in pairs(pending) do
        if record and record.kind == "flow" then
            pendingFlows = pendingFlows + 1
        end
    end
    return {
        pending = pendingCount,
        pendingFlows = pendingFlows,
        detected = stats.detected,
        resolved = stats.resolved,
    }
end
