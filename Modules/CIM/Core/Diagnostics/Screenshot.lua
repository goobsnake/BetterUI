--[[
File: Modules/CIM/Core/Diagnostics/Screenshot.lua
Purpose: In-game screenshot capture hooks for builog live testing.

ESO provides TakeScreenshot() and EVENT_SCREENSHOT_SAVED(directory, filename). This
module wraps them with opt-in auto capture, duplicate-aware throttling, and [BUI]
markers so diagnostics can correlate warnings/errors and user captures with saved
screenshot files.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local Screenshot = {}
BETTERUI.CIM.Screenshot = Screenshot

local VALID_AUTO_MODE = { off = true, error = true, warn = true }
local autoMode = "off"
local requestCounter = 0
local shotCount = 0
local userShotCount = 0
local suppressedCount = 0
local pendingIds = {}
local pendingById = {}
local expiredIds = {}
local expiredById = {}
local lastByFingerprint = {}
local recentShotTimes = {}
local emittingMarker = false
local registeredSaved = false
local registeredTooFrequent = false
local EXPIRED_CORRELATION_GRACE_MS = 5000

local DEFAULT_LIMITS = {
    duplicateMs = 120000,
    burstWindowMs = 60000,
    burstLimit = 8,
    sessionLimit = 40,
    pendingTtlMs = 15000,
}
local limits = {
    duplicateMs = DEFAULT_LIMITS.duplicateMs,
    burstWindowMs = DEFAULT_LIMITS.burstWindowMs,
    burstLimit = DEFAULT_LIMITS.burstLimit,
    sessionLimit = DEFAULT_LIMITS.sessionLimit,
    pendingTtlMs = DEFAULT_LIMITS.pendingTtlMs,
}

local EXPECTED_REASONS = {
    cannotAfford = true,
    protectionPolicy = true,
    protected = true,
    userDenied = true,
    noChoice = true,
    singleStack = true,
    headerSort = true,
}

local SKIP_WARN_CATEGORIES = {
    LOG = true,
    PERF = true,
    SCREENSHOT = true,
}

local function G(name) return rawget(_G, name) end

local function safeTostring(value, fallback)
    local ok, s = pcall(tostring, value)
    if ok and type(s) == "string" then return s end
    return fallback or ""
end

local function nowMs()
    local fn = G("GetGameTimeMilliseconds")
    if type(fn) == "function" then
        local ok, value = pcall(fn)
        if ok and type(value) == "number" then return value end
    end
    return math.floor((os.clock and os.clock() or 0) * 1000)
end

local function normalizeText(value, fallback)
    local s = safeTostring(value, fallback or "")
    s = s:gsub("[\r\n\t]+", " "):gsub("|", "/")
    s = s:gsub("sid=[0-9a-fA-F]+", "sid=?")
    s = s:gsub("seq=%d+", "seq=?")
    s = s:gsub("flow=[%w_#%-]+", "flow=?")
    s = s:gsub("%d%d%d%d+%-%d%d%-%d%d[T ][%d:%.%-+Z]+", "<time>")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return fallback or "" end
    return s
end

local function normalizeToken(value, fallback)
    local s = normalizeText(value, fallback or "?"):gsub("%s+", "_")
    if s == "" then return fallback or "?" end
    return s
end

local function lower(value)
    return normalizeText(value, ""):lower()
end

local function normalizeFingerprintMessage(value)
    local s = normalizeText(value, "-")
    s = s:gsub("0x%x+", "0x?")
    s = s:gsub("%d%d%d+", "?")
    return s
end

local function normalizeFingerprintToken(value, fallback)
    local s = normalizeFingerprintMessage(value or fallback or "?"):gsub("%s+", "_")
    if s == "" then return fallback or "?" end
    return s
end

local function sanitizeDirectory(value)
    local s = normalizeText(value, "")
    s = s:gsub("\\", "/")
    local folded = s:lower()
    local esoStart = folded:find("elder scrolls online", 1, true)
    if esoStart then return s:sub(esoStart) end
    local liveStart = folded:find("live/screenshots", 1, true)
    if liveStart then return s:sub(liveStart) end
    if s:find("/", 1, true) or s:find(":", 1, true) then return "<redacted>" end
    return s
end

local function logCategory()
    local L = BETTERUI.Log
    return (L and L.CATEGORY and L.CATEGORY.SCREENSHOT) or "SCREENSHOT"
end

local function emitMarker(message, data)
    if emittingMarker then return end
    local L = BETTERUI.Log
    if not (L and type(L.Info) == "function") then return end
    emittingMarker = true
    pcall(L.Info, logCategory(), message, data)
    emittingMarker = false
end

local function sessionId()
    local L = BETTERUI.Log
    if L and type(L.GetSessionId) == "function" then
        local ok, sid = pcall(L.GetSessionId)
        if ok and sid ~= nil then return normalizeToken(sid, "session") end
    end
    return "session"
end

local function nextRequestId(t)
    requestCounter = requestCounter + 1
    return sessionId() .. "-" .. tostring(t or nowMs()) .. "-" .. tostring(requestCounter)
end

local function copyDefaults()
    limits.duplicateMs = DEFAULT_LIMITS.duplicateMs
    limits.burstWindowMs = DEFAULT_LIMITS.burstWindowMs
    limits.burstLimit = DEFAULT_LIMITS.burstLimit
    limits.sessionLimit = DEFAULT_LIMITS.sessionLimit
    limits.pendingTtlMs = DEFAULT_LIMITS.pendingTtlMs
end

local function pruneRecent(t)
    local window = limits.burstWindowMs
    while #recentShotTimes > 0 and (t - recentShotTimes[1]) > window do
        table.remove(recentShotTimes, 1)
    end
end

local function emitExpiredRequest(request, t)
    emitMarker("screenshot requested", {
        id = request.id,
        trigger = request.trigger,
        source = request.source or "auto",
        label = request.label,
        status = "expired",
        reason = "pending_ttl",
        ageMs = t - request.t,
        fingerprint = request.fingerprint,
    })
end

local function pruneExpiredCorrelations(t)
    local kept = {}
    for i = 1, #expiredIds do
        local id = expiredIds[i]
        local request = expiredById[id]
        if request and (t - (request.expiredAt or t)) <= EXPIRED_CORRELATION_GRACE_MS then
            kept[#kept + 1] = id
        else
            expiredById[id] = nil
        end
    end
    expiredIds = kept
end

local function rememberExpiredRequest(request, t)
    if not request or not request.id then return end
    request.expiredAt = t
    expiredById[request.id] = request
    expiredIds[#expiredIds + 1] = request.id
    pruneExpiredCorrelations(t)
end

local function prunePending(t)
    local ttl = limits.pendingTtlMs
    if ttl <= 0 then return end
    local kept = {}
    for i = 1, #pendingIds do
        local id = pendingIds[i]
        local request = pendingById[id]
        if request and (t - request.t) <= ttl then
            kept[#kept + 1] = id
        else
            if request then
                emitExpiredRequest(request, t)
                rememberExpiredRequest(request, t)
            end
            pendingById[id] = nil
        end
    end
    pendingIds = kept
end

local function isPlayerInCombat()
    local fn = G("IsUnitInCombat")
    if type(fn) ~= "function" then return false end
    local ok, inCombat = pcall(fn, "player")
    return ok and inCombat == true
end

local function rememberShot(t, fingerprint)
    shotCount = shotCount + 1
    recentShotTimes[#recentShotTimes + 1] = t
    if fingerprint and fingerprint ~= "" then lastByFingerprint[fingerprint] = t end
end

local function pushPending(id, request)
    local t = nowMs()
    prunePending(t)
    pruneExpiredCorrelations(t)
    pendingIds[#pendingIds + 1] = id
    pendingById[id] = request
end

local function removePending(id)
    if id == nil or pendingById[id] == nil then return end
    pendingById[id] = nil
    local kept = {}
    for i = 1, #pendingIds do
        if pendingIds[i] ~= id then kept[#kept + 1] = pendingIds[i] end
    end
    pendingIds = kept
end

local function popPendingRaw()
    local id = table.remove(pendingIds, 1)
    if id == nil then return nil end
    local request = pendingById[id]
    pendingById[id] = nil
    return request
end

local function popExpiredCorrelation(t)
    pruneExpiredCorrelations(t)
    local id = table.remove(expiredIds, 1)
    if id == nil then return nil end
    local request = expiredById[id]
    expiredById[id] = nil
    return request
end

local function isExpired(request, t)
    return request and limits.pendingTtlMs > 0 and (t - request.t) > limits.pendingTtlMs
end

local function isBeyondExpiredGrace(request, t)
    return request and limits.pendingTtlMs > 0
        and (t - request.t) > (limits.pendingTtlMs + EXPIRED_CORRELATION_GRACE_MS)
end

local function popCorrelatableRequest(t)
    local request = popExpiredCorrelation(t)
    if request then return request, true end

    while true do
        request = popPendingRaw()
        if not request then return nil, false end
        if isBeyondExpiredGrace(request, t) then
            emitExpiredRequest(request, t)
        else
            local expired = isExpired(request, t)
            if expired then emitExpiredRequest(request, t) end
            return request, expired
        end
    end
end

local function canCapture(t, fingerprint, manual)
    pruneRecent(t)
    if limits.sessionLimit > 0 and shotCount >= limits.sessionLimit then
        return false, "session_limit"
    end
    if limits.burstLimit > 0 and #recentShotTimes >= limits.burstLimit then
        return false, "burst_limit"
    end
    if not manual and fingerprint and fingerprint ~= "" then
        local last = lastByFingerprint[fingerprint]
        if last and (t - last) < limits.duplicateMs then
            return false, "duplicate"
        end
    end
    return true, "allowed"
end

local function registerEvent(namespace, eventId, callback)
    local registry = BETTERUI.CIM and BETTERUI.CIM.EventRegistry
    if registry and type(registry.Register) == "function" then
        local ok, registered = pcall(registry.Register, "Diagnostics.Screenshot", namespace, eventId, callback)
        return ok and registered == true
    end
    local eventManager = G("EVENT_MANAGER")
    if eventManager and type(eventManager.RegisterForEvent) == "function" then
        local ok, registered = pcall(function()
            return eventManager:RegisterForEvent(namespace, eventId, callback)
        end)
        return ok and registered ~= false
    end
    return false
end

local function ensureEventRegistration()
    local savedEvent = G("EVENT_SCREENSHOT_SAVED")
    if not registeredSaved and savedEvent ~= nil then
        registeredSaved = registerEvent("BetterUI_ScreenshotSaved", savedEvent, function(a, b, c)
            if c ~= nil then
                Screenshot.OnSaved(b, c)
            else
                Screenshot.OnSaved(a, b)
            end
        end)
    end
    local tooFrequentEvent = G("EVENT_FEEDBACK_TOO_FREQUENT_SCREENSHOT")
    if not registeredTooFrequent and tooFrequentEvent ~= nil then
        registeredTooFrequent = registerEvent("BetterUI_ScreenshotTooFrequent", tooFrequentEvent, function()
            Screenshot.OnTooFrequent()
        end)
    end
end

local function fingerprintFor(record)
    record = type(record) == "table" and record or {}
    local data = type(record.data) == "table" and record.data or {}
    local parts = {
        normalizeToken(record.levelName or record.level, "LEVEL"),
        normalizeToken(record.category, "GENERAL"),
        normalizeToken(data.eventName, "-"),
        normalizeToken(data.phaseName, "-"),
        normalizeFingerprintToken(data.caller, "-"),
        normalizeToken(data.src, "-"),
        normalizeToken(data.reason, "-"),
        normalizeFingerprintMessage(record.message),
    }
    return lower(table.concat(parts, "|"))
end

local function shouldAutoCaptureWarn(record)
    local category = normalizeToken(record.category, "GENERAL")
    if SKIP_WARN_CATEGORIES[category] then return false end
    local data = type(record.data) == "table" and record.data or {}
    local reason = normalizeToken(data.reason, "")
    if EXPECTED_REASONS[reason] then return false end
    return true
end

local function requestCapture(opts)
    opts = type(opts) == "table" and opts or {}
    local t = nowMs()
    local manual = opts.manual == true
    local trigger = normalizeToken(opts.trigger, manual and "manual" or "auto")
    local source = manual and "user" or "auto"
    local label = normalizeText(opts.label, "")
    local fingerprint = opts.fingerprint or ""
    local id = nextRequestId(t)

    ensureEventRegistration()

    local takeScreenshot = G("TakeScreenshot")
    if type(takeScreenshot) ~= "function" then
        emitMarker("screenshot request", {
            id = id, trigger = trigger, label = label, status = "unavailable",
            source = source, reason = "missing_TakeScreenshot", fingerprint = fingerprint,
        })
        return false, "unavailable"
    end

    if not manual and isPlayerInCombat() then
        suppressedCount = suppressedCount + 1
        emitMarker("screenshot request", {
            id = id, trigger = trigger, label = label, status = "suppressed",
            source = source, reason = "combat", fingerprint = fingerprint,
        })
        return false, "combat"
    end

    local allowed, reason = canCapture(t, fingerprint, manual)
    if not allowed then
        suppressedCount = suppressedCount + 1
        emitMarker("screenshot request", {
            id = id, trigger = trigger, label = label, status = "suppressed",
            source = source, reason = reason, fingerprint = fingerprint,
        })
        return false, reason
    end

    emitMarker("screenshot request", {
        id = id, trigger = trigger, label = label, status = "pending",
        source = source, fingerprint = fingerprint, sourceLevel = opts.sourceLevel,
        sourceCategory = opts.sourceCategory,
    })

    pushPending(id, {
        id = id, t = t, trigger = trigger, label = label, fingerprint = fingerprint,
        source = source, sourceLevel = opts.sourceLevel, sourceCategory = opts.sourceCategory,
    })

    local ok, result = pcall(takeScreenshot)
    if not ok or result == false then
        removePending(id)
        emitMarker("screenshot requested", {
            id = id, trigger = trigger, label = label, status = "failed",
            source = source,
            reason = ok and "TakeScreenshot_returned_false" or "TakeScreenshot_error",
            error = ok and nil or normalizeText(result, "error"),
            fingerprint = fingerprint,
        })
        return false, "failed"
    end

    rememberShot(t, fingerprint)
    if source == "user" then userShotCount = userShotCount + 1 end
    emitMarker("screenshot requested", {
        id = id, trigger = trigger, label = label, status = "requested",
        source = source, fingerprint = fingerprint,
    })
    return true, "requested", id
end

function Screenshot.RequestManual(label)
    return requestCapture({ manual = true, trigger = "manual", label = label or "" })
end

function Screenshot.OnLogRecord(record)
    if autoMode == "off" then return end
    if type(record) ~= "table" then return end
    local category = normalizeToken(record.category, "GENERAL")
    if category == "SCREENSHOT" then return end
    local data = type(record.data) == "table" and record.data or {}
    local level = tonumber(record.level) or 0
    local L = BETTERUI.Log
    local levels = L and L.LEVEL or {}
    local warnLevel = levels.WARN or 4
    local errorLevel = levels.ERROR or 5

    local explicit = data.screenshot == true
    local shouldCapture = explicit
    if not shouldCapture and level >= errorLevel then
        shouldCapture = true
    elseif not shouldCapture and autoMode == "warn" and level >= warnLevel then
        shouldCapture = shouldAutoCaptureWarn(record)
    end
    if not shouldCapture then return end

    local fingerprint = fingerprintFor(record)
    return requestCapture({
        manual = false,
        trigger = explicit and "explicit" or "auto",
        label = data.screenshotLabel or data.reason or record.category or "",
        fingerprint = fingerprint,
        sourceLevel = record.levelName,
        sourceCategory = record.category,
    })
end

function Screenshot.OnSaved(directory, filename)
    local t = nowMs()
    local request, expired = popCorrelatableRequest(t)
    if not request then
        userShotCount = userShotCount + 1
        emitMarker("screenshot saved", {
            id = nextRequestId(t),
            trigger = "external",
            source = "user",
            status = "saved",
            requested = false,
            correlation = "event",
            directory = sanitizeDirectory(directory),
            filename = normalizeText(filename, ""),
        })
        return
    end
    emitMarker("screenshot saved", {
        id = request.id,
        trigger = request.trigger,
        source = request.source or "auto",
        status = "saved",
        requested = true,
        correlation = expired and "expired_fifo" or "fifo",
        late = expired or nil,
        ageMs = t - request.t,
        directory = sanitizeDirectory(directory),
        filename = normalizeText(filename, ""),
        fingerprint = request.fingerprint,
        sourceLevel = request.sourceLevel,
        sourceCategory = request.sourceCategory,
    })
end

function Screenshot.OnTooFrequent()
    local t = nowMs()
    local request, expired = popCorrelatableRequest(t)
    suppressedCount = suppressedCount + 1
    emitMarker("screenshot requested", {
        id = request and request.id or "engine",
        trigger = request and request.trigger or "external",
        source = request and request.source or "user",
        label = request and request.label or nil,
        status = "failed",
        reason = "engine_too_frequent",
        requested = request ~= nil,
        correlation = request and (expired and "expired_fifo" or "fifo") or "event",
        fingerprint = request and request.fingerprint or nil,
    })
end

function Screenshot.SetAutoMode(mode)
    mode = type(mode) == "string" and mode:lower() or ""
    if not VALID_AUTO_MODE[mode] then return false, autoMode end
    autoMode = mode
    return true, autoMode
end

function Screenshot.GetAutoMode() return autoMode end

function Screenshot.GetStatus()
    local t = nowMs()
    pruneRecent(t)
    prunePending(t)
    pruneExpiredCorrelations(t)
    return {
        autoMode = autoMode,
        shots = shotCount,
        userShots = userShotCount,
        suppressed = suppressedCount,
        pending = #pendingIds,
        burst = #recentShotTimes,
        burstLimit = limits.burstLimit,
        sessionLimit = limits.sessionLimit,
        duplicateMs = limits.duplicateMs,
        pendingTtlMs = limits.pendingTtlMs,
    }
end

function Screenshot._ResetForTests()
    autoMode = "off"
    requestCounter = 0
    shotCount = 0
    userShotCount = 0
    suppressedCount = 0
    pendingIds = {}
    pendingById = {}
    expiredIds = {}
    expiredById = {}
    lastByFingerprint = {}
    recentShotTimes = {}
    emittingMarker = false
    registeredSaved = false
    registeredTooFrequent = false
    copyDefaults()
end

function Screenshot._SetLimitsForTests(nextLimits)
    if type(nextLimits) ~= "table" then return end
    for key, value in pairs(nextLimits) do
        if limits[key] ~= nil and type(value) == "number" then limits[key] = value end
    end
end

ensureEventRegistration()
