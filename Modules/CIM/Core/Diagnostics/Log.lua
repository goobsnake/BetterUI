--[[
File: Modules/CIM/Core/Diagnostics/Log.lua
Purpose: Unified BetterUI logging facade. Routes leveled, categorized records to
         pluggable sinks. Default routing sends EVERYTHING to the file sink
         (Interface.log) and nothing to chat/popup -- i.e. suppressed-by-default,
         surfaceable on demand via /builog.

Design:
  - Levels: TRACE < DEBUG < INFO < WARN < ERROR.
  - Categories gate instrumentation noise (SCENE/LIST/NAV/...); WARN/ERROR always pass.
  - Sinks: file (Interface.log via InterfaceLog), chat (colored d()). Per-level on/off.
  - Popup surfacing is the global InterfaceLog suppression toggle (errors + file writes
    pop only when popups are enabled); see /builog popups.
  - The logger is INERT unless logging is active (InterfaceLog or CIM.Debug enabled), so
    normal players incur zero cost and see no behavior change. The active-state decision
    is memoized and invalidated by the InterfaceLog/FeatureFlags setters that flip it.
  - Named presets (off/debug/verbose) layer over the low-level knobs for a one-word
    troubleshooting UX; see Log.ApplyPreset.
  - EnabledFor() is the exact preflight gate: hot paths (and the lazy Log.*Lazy
    variants) build NO payload when a record would be dropped.
  - BETTERUI.Debug / DebugError / CIM.Debug.Log become thin wrappers over this, and
    SafeExecute routes caught errors through Log.Error("SAFE", ...).
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local Log = {}
BETTERUI.Log = Log
BETTERUI.CIM.Log = Log

Log.LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 }
local LEVEL_NAME = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }

-- Canonical categories (callers may pass any string; these are the documented set).
Log.CATEGORY = {
    SCENE = "SCENE", LIST = "LIST", NAV = "NAV", KEYBIND = "KEYBIND", FOOTER = "FOOTER",
    CATEGORY = "CATEGORY", SEARCH = "SEARCH", SORT = "SORT", BATCH = "BATCH",
    ACTION = "ACTION", LIFECYCLE = "LIFECYCLE", SAFE = "SAFE", SETTINGS = "SETTINGS",
    -- CONTROL: control resolution/cache (was GENERAL). PERF: timing/budget signals.
    -- STATE: watch-mode startup preamble, heartbeat, and periodic state snapshots.
    CONTROL = "CONTROL", PERF = "PERF", STATE = "STATE",
    GENERAL = "GENERAL",
}

-- Configuration -------------------------------------------------------------
local minLevel = Log.LEVEL.TRACE

-- Payload capture: when false, the optional `data` argument is NOT rendered into
-- the line (the cheap "debug" preset -- message only); when true, key=value /
-- function payloads reach the log (the "verbose" preset). Default true preserves
-- legacy behavior (data always rendered when present).
local payloadCapture = true

-- Last applied named preset (informational; see Log.ApplyPreset). Becomes "custom"
-- once a low-level setter diverges from a preset's shape.
local currentPreset = "custom"

-- Per-level sink masks. Default: file ON, chat OFF (popup is the global suppression toggle).
local function defaultMask() return { file = true, chat = false } end
local sinks = {}
for i = 1, #LEVEL_NAME do sinks[i] = defaultMask() end

-- Categories switched off here drop TRACE/DEBUG records; WARN/ERROR ignore this gate.
local categoryDisabled = {}

local function G(name) return rawget(_G, name) end

-- tostring that can never raise (a hostile/missing __tostring must not break a log call).
-- Defined early so the payload path (Summarize/renderData) can use it too.
local function safeTostring(v, fallback)
    local ok, s = pcall(tostring, v)
    if ok and type(s) == "string" then return s end
    return fallback or ""
end

local function normalizeLogText(v, fallback)
    return (safeTostring(v, fallback or ""):gsub("[\r\n\t]+", " "):gsub("|", "/"))
end

local function normalizeLogToken(v, fallback)
    local s = normalizeLogText(v, fallback or "?"):gsub("%s+", "_")
    if s == "" then return fallback or "?" end
    return s
end

-- Active-state memoization. The logger only does work when the user opted into
-- logging; that decision is cached and dropped via Log.InvalidateActive() by the
-- InterfaceLog/FeatureFlags setters that can change it (so a toggle still takes
-- effect on the very next call). Log.RefreshActive() forces a recompute for reload
-- boundaries, tests, or after a raw debug global is flipped directly.
local activeCache = nil
local function computeActive()
    local cim = BETTERUI.CIM
    if not cim then return false end
    local il = cim.InterfaceLog
    if il and il.IsEnabled and il.IsEnabled() then return true end
    local dbg = cim.Debug
    if dbg and dbg.IsEnabled and dbg.IsEnabled() then return true end
    return false
end
local function isActive()
    if activeCache == nil then activeCache = computeActive() end
    return activeCache
end

--- Drop the cached active-state so the next check recomputes.
function Log.InvalidateActive() activeCache = nil end

--- Force an immediate active-state recompute and return it.
---@return boolean
function Log.RefreshActive() activeCache = computeActive(); return activeCache end

-- Sinks ---------------------------------------------------------------------
local function sinkFile(line)
    local il = BETTERUI.CIM and BETTERUI.CIM.InterfaceLog
    -- One record = one greppable line: collapse embedded newlines/tabs so a
    -- multi-line value can't split a record (the file is line-oriented for tailers).
    line = tostring(line):gsub("[\r\n]+", " "):gsub("\t", " ")
    if il and il.WriteRaw then return il.WriteRaw(line) end
    if il and il.Write then return il.Write(line) end
end

local function sinkChat(category, text)
    local chat = G("d")
    if type(chat) == "function" then
        chat(string.format("|c0066ff[BUI:%s]|r %s", category, text))
    end
end

-- High-density value summary (#7): compact shape, never a full table/array dump.
---@param value any
---@return string
function Log.Summarize(value)
    local t = type(value)
    if t == "table" then
        local len = #value
        local keyCount = 0
        for _ in pairs(value) do keyCount = keyCount + 1 end
        if len > 0 and len == keyCount then
            return string.format("[%d]", len)
        end
        local keys = {}
        for k in pairs(value) do
            keys[#keys + 1] = safeTostring(k, "?")
            if #keys >= 5 then break end
        end
        return string.format("{%d:%s%s}", keyCount, table.concat(keys, ","), keyCount > 5 and ",.." or "")
    elseif t == "string" then
        -- Neutralize the field separator: a payload value must not inject a bare `|`
        -- (the host parser's k=v separator). Quote so a reader sees it's a string value.
        local s = (value:gsub("|", "/"))
        if #s > 80 then return '"' .. s:sub(1, 80) .. '..."' end
        return '"' .. s .. '"'
    elseif t == "userdata" then
        -- Indexing userdata can ITSELF raise (hostile/absent __index), so pcall the lookup.
        local ok, getName = pcall(function() return value.GetName end)
        if ok and type(getName) == "function" then
            local ok2, name = pcall(getName, value)
            if ok2 and name and name ~= "" then return "<ctrl:" .. safeTostring(name) .. ">" end
        end
        return "<userdata>"
    end
    return safeTostring(value)
end

-- Render the optional data argument for a log line. A record-style table (named
-- fields) renders as `key=value key=value` (deterministic key order, values via
-- Summarize, field-capped) so the actual VALUES reach the log -- what an external
-- reader/AI needs to act on, not just the field shape. Pure arrays and scalars
-- defer to Summarize (`[n]` / the value), keeping lines high-density. logfmt-style.
local MAX_LOG_FIELDS = 8
local function renderData(data)
    if type(data) ~= "table" then return Log.Summarize(data) end
    local len = #data
    local keyCount = 0
    for _ in pairs(data) do keyCount = keyCount + 1 end
    if keyCount == 0 then return "{}" end
    if len > 0 and len == keyCount then return Log.Summarize(data) end -- pure array -> [n]

    local keys = {}
    for k in pairs(data) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return safeTostring(a) < safeTostring(b) end)

    local parts = {}
    for i = 1, #keys do
        if i > MAX_LOG_FIELDS then parts[#parts + 1] = ".."; break end
        parts[#parts + 1] = safeTostring(keys[i]) .. "=" .. Log.Summarize(data[keys[i]])
    end
    return table.concat(parts, " ")
end

-- Gating --------------------------------------------------------------------
--- Exact preflight gate: true only when a record at (level, category) would
--- actually reach a sink. Mirrors every check emit() applies -- active state,
--- min level, category gate, AND the sink mask -- so callers can guard expensive
--- payload construction with the SAME decision the logger uses. When this is
--- false nothing is built, rendered, or scheduled.
---@param level number
---@param category string|nil
---@return boolean
function Log.EnabledFor(level, category)
    if type(level) ~= "number" then return false end
    if not isActive() then return false end
    if level < minLevel then return false end
    category = category or Log.CATEGORY.GENERAL
    if level <= Log.LEVEL.DEBUG and categoryDisabled[category] then return false end
    local mask = sinks[level]
    return (mask and (mask.file or mask.chat)) and true or false
end

-- Schema + session/sequence metadata ----------------------------------------
-- Every dispatched record carries `sid` (per-UI-load id; groups reload sessions)
-- and a monotonic `seq`, so a tailing AI/human can order and correlate lines even
-- when the engine interleaves traceback blocks. A bounded in-memory ring backs the
-- "what just happened" reads (/builog recent).
Log.SCHEMA = 1

local sessionId = nil
local seqCounter = 0

-- Guarded numeric read of a global clock fn: returns a number or 0, never raises and
-- never feeds a non-number into math (the contract: a log call can never error).
local function safeClock(name)
    local fn = G(name)
    if type(fn) ~= "function" then return 0 end
    local ok, v = pcall(fn)
    if ok and type(v) == "number" then return v end
    return 0
end

local function ensureSessionId()
    if sessionId == nil then
        -- Combine wall-clock seconds (differs across reloads) with uptime ms so two
        -- loads don't collide even at the same uptime-ms, and the value doesn't wrap
        -- on a short cycle. Non-crypto; it only needs to group one UI-load session.
        -- Lua 5.1 `%` is always non-negative for a positive modulus, so the hex is clean.
        local ms = safeClock("GetGameTimeMilliseconds")
        local stamp = safeClock("GetTimeStamp")
        sessionId = string.format("%04x%04x", math.floor(stamp % 0x10000), math.floor(ms % 0x10000))
    end
    return sessionId
end

local RECENT_RING_SIZE = 100
local recentRing = {}
local recentWriteIdx = 0

local function pushRecent(entry)
    recentWriteIdx = (recentWriteIdx % RECENT_RING_SIZE) + 1
    recentRing[recentWriteIdx] = entry
end

--- Up to `n` most-recent dispatched records, oldest-to-newest. nil/0 = all retained.
---@param n number|nil
---@return table[]
function Log.GetRecent(n)
    local all = {}
    for i = 1, RECENT_RING_SIZE do
        if recentRing[i] then all[#all + 1] = recentRing[i] end
    end
    table.sort(all, function(a, b) return a.seq < b.seq end)
    if type(n) == "number" and n > 0 and #all > n then
        local out = {}
        for i = #all - n + 1, #all do out[#out + 1] = all[i] end
        return out
    end
    return all
end

function Log.ClearRecent() recentRing = {}; recentWriteIdx = 0 end

-- Dedicated WARN/ERROR ring: errors are rare but high-value, and the main 100-entry ring
-- churns in <1s under debug/trace, so a separate smaller ring keeps the last problems
-- available to /builog errors + /buihealth long after they scroll off the main ring.
local ERROR_RING_SIZE = 50
local errorRing = {}
local errorWriteIdx = 0
local errorCount = 0

local function pushError(entry)
    errorWriteIdx = (errorWriteIdx % ERROR_RING_SIZE) + 1
    errorRing[errorWriteIdx] = entry
    errorCount = errorCount + 1
end

--- Up to `n` most-recent WARN/ERROR records, oldest-to-newest. nil/0 = all retained.
---@param n number|nil
---@return table[]
function Log.GetRecentErrors(n)
    local all = {}
    for i = 1, ERROR_RING_SIZE do
        if errorRing[i] then all[#all + 1] = errorRing[i] end
    end
    table.sort(all, function(a, b) return a.seq < b.seq end)
    if type(n) == "number" and n > 0 and #all > n then
        local out = {}
        for i = #all - n + 1, #all do out[#out + 1] = all[i] end
        return out
    end
    return all
end

--- Total WARN/ERROR records seen this session (not just those retained in the ring).
---@return number
function Log.GetErrorCount() return errorCount end
function Log.ClearErrors() errorRing = {}; errorWriteIdx = 0; errorCount = 0 end

-- Context provider: a fn(level, category) -> suffix string appended to every
-- dispatched line. The watch preset sets it to inject scene/view/flow/lastAction so
-- a tailing AI never lacks context; nil (default) means no suffix.
local contextProvider = nil
function Log.SetContextProvider(fn) contextProvider = (type(fn) == "function") and fn or nil end
function Log.GetContextProvider() return contextProvider end

--- Current per-UI-load session id (used by InterfaceLog meta-lines + diagnostics).
---@return string
function Log.GetSessionId() return ensureSessionId() end

--- Allocate the next monotonic sequence number. InterfaceLog uses this for its own
--- meta-lines (drop summaries, the startup header) so EVERY [BUI] line -- Log.* record
--- or InterfaceLog meta-line -- shares one ordered sequence.
---@return number
function Log.NextSeq() seqCounter = seqCounter + 1; return seqCounter end

-- Flow correlation + last-action context. A flow ties the records of one multi-step
-- operation (scene open -> list refresh -> footer; a transfer chain) together via an
-- explicit short id -- no hidden stack/thread-local context (fragile in ESO callbacks).
local flowCounters = {}
--- Allocate a short, session-local flow id like "deposit#3".
---@param kind string|nil
---@return string
function Log.NewFlow(kind)
    if kind == nil then kind = "flow" else kind = normalizeLogToken(kind, "flow") end
    if kind == "" then kind = "flow" end
    flowCounters[kind] = (flowCounters[kind] or 0) + 1
    return kind .. "#" .. flowCounters[kind]
end

local lastAction = nil
--- Record the latest user action so watch-mode context + error records can carry it.
---@param message any
---@param flow string|nil
function Log.SetLastAction(message, flow)
    local msg = (message == nil) and "" or normalizeLogText(message, "")
    lastAction = { message = msg, flow = flow and normalizeLogToken(flow, "?") or nil }
end
---@return table|nil
function Log.GetLastAction() return lastAction end

-- Render + route a record whose gate has ALREADY passed (see EnabledFor). Keeping
-- the sink-mask read and rendering out of the gate keeps EnabledFor cheap, and
-- skips renderData() entirely when payload capture is off.
local function dispatch(level, category, message, data)
    local ts = safeClock("GetGameTimeMilliseconds")
    seqCounter = seqCounter + 1
    local seq = seqCounter
    local sid = ensureSessionId()

    local text = normalizeLogText(message, "") -- never raise on a hostile __tostring
    if data ~= nil and payloadCapture then
        -- belt: the payload render can never raise the log call (renderData is already
        -- safeTostring-guarded, but a pathological value must still not escape).
        local okR, rendered = pcall(renderData, data)
        if okR and type(rendered) == "string" then text = text .. " " .. normalizeLogText(rendered, "") end
    end

    -- Optional context suffix (watch preset): scene/view/flow/lastAction.
    if contextProvider then
        local ok, suffix = pcall(contextProvider, level, category)
        if ok and type(suffix) == "string" and suffix ~= "" then
            text = text .. " " .. normalizeLogText(suffix, "")
        end
    end

    local mask = sinks[level]
    local sinkDropped = false
    if mask.file then
        -- pcall: a sink fault (file flatten, or the external chat `d`) must never escape the
        -- log call -- NEVER-RAISE applies through the sink, not just the render.
        local okF, scheduled = pcall(sinkFile, string.format("[BUI] %d sid=%s seq=%d %s %s | %s",
            ts, sid, seq, LEVEL_NAME[level], category, text))
        sinkDropped = not (okF and scheduled == true) -- error, budget drop, or no sink = not written
    end
    if mask.chat then
        pcall(sinkChat, category, text)
    end

    pushRecent({ seq = seq, t = ts, level = LEVEL_NAME[level], category = category,
        message = text, sinkDropped = sinkDropped })
    if level >= Log.LEVEL.WARN then
        pushError({ seq = seq, t = ts, level = LEVEL_NAME[level], category = category, message = text })
    end
end

-- Core emit -----------------------------------------------------------------
local function emit(level, category, message, data)
    category = category or Log.CATEGORY.GENERAL
    if not Log.EnabledFor(level, category) then return end
    dispatch(level, category, message, data)
end

---@param level number  one of Log.LEVEL
---@param category string
---@param message any
---@param data any|nil   optional structured value, summarized via Log.Summarize
function Log.Write(level, category, message, data) emit(level, category, message, data) end
function Log.Trace(category, message, data) emit(Log.LEVEL.TRACE, category, message, data) end
function Log.Debug(category, message, data) emit(Log.LEVEL.DEBUG, category, message, data) end
function Log.Info(category, message, data)  emit(Log.LEVEL.INFO,  category, message, data) end
function Log.Warn(category, message, data)  emit(Log.LEVEL.WARN,  category, message, data) end
function Log.Error(category, message, data) emit(Log.LEVEL.ERROR, category, message, data) end

-- Flow envelopes: correlate the records of one multi-step operation. FlowBegin allocates
-- a flow id, records it as the last action (so the in-between watch lines carry flow=<id>
-- via the context suffix), and emits a DEBUG "begin" envelope; FlowEnd emits the "end".
-- The flow id rides the message as a BARE `flow=<id>` token (not the data payload, which
-- Summarize would quote) so it appears on the envelope in every preset, in the same bare
-- form the context suffix uses -- one consistent key for the host parser.

--- @return string flow  -- the allocated flow id (pass to FlowEnd)
function Log.FlowBegin(kind, category, message, data)
    local flow = Log.NewFlow(kind) -- always a string
    local msg = (message ~= nil) and normalizeLogText(message, "flow") or normalizeLogText(kind, "flow")
    Log.SetLastAction(msg, flow)
    emit(Log.LEVEL.DEBUG, category or Log.CATEGORY.GENERAL, msg .. " [flow begin] flow=" .. flow, data)
    return flow
end

function Log.FlowEnd(flow, category, message, data)
    local msg = (message ~= nil) and normalizeLogText(message, "flow") or "flow"
    emit(Log.LEVEL.DEBUG, category or Log.CATEGORY.GENERAL,
        msg .. " [flow end] flow=" .. normalizeLogToken(flow, "?"), data)
end

--- Lazy payload variants: the message/data builders run ONLY after the exact gate
--- passes (and `dataFn` only when payload capture is on), so hot paths pay nothing
--- when the record would be dropped. `message` may be a string or a 0-arg function;
--- `dataFn` is a 0-arg function returning the structured value.
---@param level number
---@param category string
---@param message string|function
---@param dataFn function|nil
function Log.WriteLazy(level, category, message, dataFn)
    category = category or Log.CATEGORY.GENERAL
    if not Log.EnabledFor(level, category) then return end
    -- pcall the lazy builders so a raising message()/dataFn() can't escape the log call.
    if type(message) == "function" then
        local okM, m = pcall(message)
        message = (okM and m ~= nil) and m or "<lazy message error>"
    end
    local data = nil
    if payloadCapture and type(dataFn) == "function" then
        local okD, d = pcall(dataFn)
        if okD then data = d end
    end
    dispatch(level, category, message, data)
end
function Log.DebugLazy(category, message, dataFn) Log.WriteLazy(Log.LEVEL.DEBUG, category, message, dataFn) end
function Log.TraceLazy(category, message, dataFn) Log.WriteLazy(Log.LEVEL.TRACE, category, message, dataFn) end

-- Configuration API ---------------------------------------------------------
function Log.SetMinLevel(level)
    if type(level) == "number" and LEVEL_NAME[level] then minLevel = level; currentPreset = "custom" end
end

function Log.GetMinLevel() return minLevel end

---@param level number
---@param sinkName string "file" | "chat"
---@param on boolean
function Log.SetSink(level, sinkName, on)
    if sinks[level] and (sinkName == "file" or sinkName == "chat") then
        sinks[level][sinkName] = on and true or false
        currentPreset = "custom"
    end
end

---@param level number
---@param sinkName string
---@return boolean
function Log.GetSink(level, sinkName)
    return sinks[level] and sinks[level][sinkName] == true or false
end

---@param category string
---@param on boolean
function Log.SetCategoryEnabled(category, on)
    categoryDisabled[category] = (on and nil) or true
end

---@param category string
---@return boolean
function Log.IsCategoryEnabled(category)
    return not categoryDisabled[category]
end

--- Whether optional `data`/payload arguments are rendered into log lines. The
--- "debug" and "trace" presets turn this on; "info" leaves it off (message-only).
---@param on boolean
function Log.SetPayloadCapture(on) payloadCapture = on and true or false; currentPreset = "custom" end
---@return boolean
function Log.GetPayloadCapture() return payloadCapture end

-- Presets -------------------------------------------------------------------
-- Three named tiers (plus off) layered over the low-level knobs, mapped to the
-- standard severity model:
--   off    -> stop file logging, restore error popups, reset the rate-limit budget.
--   info   -> INFO/WARN/ERROR, payloads off. Milestones + problems: "is it working?"
--             Safe to run during live play, so it keeps the TIGHT anti-hitch budget.
--   watch  -> DEBUG+ payloads on, the curated live-AI stream (Phase 3 adds category
--             auto-mute + per-line context + startup preamble + state snapshots).
--   debug  -> DEBUG+ (the user-action flow shows), payloads on. The everyday "what is
--             it doing?" view. LOOSE budget -- a debugger accepts the FPS cost.
--   trace  -> TRACE+ (every step), payloads on. LOOSEST budget; high enough only to
--             stop a runaway hot loop from crashing/freezing the client.
--   inspect-> trace verbosity (TRACE+, payloads) PLUS the full watch enrichment (per-line
--             context suffix + state snapshots + startup preamble + category auto-mute).
--             "watch, at trace depth" -- the richest live-AI stream.
-- "verbose" is accepted as a back-compat alias for "trace". "inspect" is a DISTINCT preset,
-- not an alias (GetPreset() returns "inspect").
local PRESET_NAMES = { off = true, info = true, watch = true, debug = true, trace = true, inspect = true, verbose = true, ai = true }

-- Per-preset file-sink rate limits. info stays tight (FPS-safe for live play); debug,
-- trace, watch and inspect are greatly loosened because an active debugger accepts the
-- FPS cost -- the caps exist only so a pathological hot path can't crash or freeze the
-- client. Sizing: a single-frame inventory/craft-bag list rebuild was observed bursting
-- ~800+ records/frame at inspect depth, so the per-frame caps clear that with headroom
-- (verified: no in-game FPS impact at inspect during heavy scrolling/category switches).
local PRESET_BUDGET = {
    off   = { maxPerFrame = 0,    maxPerSecond = 0,     maxPending = 0 },
    info  = { maxPerFrame = 8,    maxPerSecond = 100,   maxPending = 200 },
    watch = { maxPerFrame = 300,  maxPerSecond = 6000,  maxPending = 6000 },
    debug = { maxPerFrame = 1000, maxPerSecond = 20000, maxPending = 20000 },
    trace = { maxPerFrame = 2000, maxPerSecond = 40000, maxPending = 40000 },
    inspect = { maxPerFrame = 2000, maxPerSecond = 40000, maxPending = 40000 }, -- trace volume + watch enrichment
}

-- file ON for levels >= fileFromLevel (nil = all file sinks off); chat per chatOn.
local function applyAllSinks(fileFromLevel, chatOn)
    for i = 1, #LEVEL_NAME do
        sinks[i].file = (fileFromLevel ~= nil) and (i >= fileFromLevel) or false
        sinks[i].chat = chatOn and true or false
    end
end

---@param name string  "off" | "info" | "watch" | "debug" | "trace"  (alias: "verbose" -> "trace")
---@return boolean applied
---@return string preset
function Log.ApplyPreset(name)
    name = type(name) == "string" and name:lower() or ""
    if not PRESET_NAMES[name] then return false, currentPreset end
    if name == "verbose" then name = "trace" end -- back-compat alias
    if name == "ai" then name = "watch" end -- deprecated alias for "watch"
    local il = BETTERUI.CIM and BETTERUI.CIM.InterfaceLog

    if name == "off" then
        if il and il.SetEnabled then il.SetEnabled(false) end
    elseif name == "info" then
        minLevel = Log.LEVEL.INFO
        applyAllSinks(Log.LEVEL.INFO, false) -- INFO/WARN/ERROR -> file only
        categoryDisabled = {}
        payloadCapture = false
        if il and il.SetEnabled then il.SetEnabled(true) end
    elseif name == "watch" then
        -- Curated live-AI stream. Phase 1: DEBUG+ with payloads at the watch budget.
        -- Phase 3 layers on category auto-mute, a per-line context suffix, a startup
        -- preamble, and periodic state snapshots that make it materially richer than
        -- `debug` for an AI tailing Interface.log in real time.
        minLevel = Log.LEVEL.DEBUG
        applyAllSinks(Log.LEVEL.DEBUG, false)
        categoryDisabled = {}
        payloadCapture = true
        if il and il.SetEnabled then il.SetEnabled(true) end
    elseif name == "debug" then
        minLevel = Log.LEVEL.DEBUG
        applyAllSinks(Log.LEVEL.DEBUG, false) -- DEBUG+ -> file (the user-action flow)
        categoryDisabled = {}
        payloadCapture = true
        if il and il.SetEnabled then il.SetEnabled(true) end
    elseif name == "trace" or name == "inspect" then
        -- inspect shares trace's verbosity knobs; the WatchMode enrichment block below
        -- (Activate for watch OR inspect) is the ONLY thing that distinguishes them.
        minLevel = Log.LEVEL.TRACE
        applyAllSinks(Log.LEVEL.TRACE, false) -- everything -> file
        categoryDisabled = {}
        payloadCapture = true
        if il and il.SetEnabled then il.SetEnabled(true) end
    end

    -- Apply the tier-matched rate-limit budget (see PRESET_BUDGET). Tunable live via
    -- InterfaceLog.SetBudget; overflow is dropped + summarized as dropped=N.
    if il and il.SetBudget and PRESET_BUDGET[name] then il.SetBudget(PRESET_BUDGET[name]) end

    Log.RefreshActive()
    currentPreset = name

    -- Watch-mode enrichment lifecycle (context suffix, preamble, snapshots, mutes).
    -- Resolved lazily: WatchMode loads after Log. Activate for the ENRICHMENT presets
    -- (watch + inspect); Deactivate for every OTHER preset so leaving them cleanly drops
    -- the context provider + restores mutes.
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if watch then
        -- pcall: a watch lifecycle hiccup (preamble/snapshot/mute) must never break
        -- preset application or raise out of the /builog slash command.
        if name == "watch" or name == "inspect" then
            if watch.Activate then pcall(watch.Activate) end
        elseif watch.Deactivate then
            pcall(watch.Deactivate)
        end
    end

    return true, name
end

---@return string
function Log.GetPreset() return currentPreset end

--- Resolve a level number from a name like "warn" (case-insensitive). nil if unknown.
---@param name string
---@return number|nil
function Log.LevelFromName(name)
    if type(name) ~= "string" then return nil end
    return Log.LEVEL[name:upper()]
end

--- Whether logging is currently active (the user enabled InterfaceLog or debug).
--- Memoized; invalidated by the InterfaceLog/FeatureFlags setters. Cheap gate for
--- HOT paths: check this before building an expensive log payload so normal players
--- (logging off) pay nothing, e.g.
---   if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(cat, msg, heavy()) end
--- For an exact (level/category/sink-aware) gate, prefer Log.EnabledFor or the
--- Log.*Lazy variants.
---@return boolean
function Log.IsActive() return isActive() end
