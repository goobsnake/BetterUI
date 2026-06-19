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
    normal players incur zero cost and see no behavior change.
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

-- The logger only does work when the user has opted into logging. Computed live
-- (not memoized) so toggling InterfaceLog/Debug takes effect immediately -- the
-- cost is a few table lookups behind FeatureFlags' own cache.
local function isActive()
    local cim = BETTERUI.CIM
    if not cim then return false end
    local il = cim.InterfaceLog
    if il and il.IsEnabled and il.IsEnabled() then return true end
    local dbg = cim.Debug
    if dbg and dbg.IsEnabled and dbg.IsEnabled() then return true end
    return false
end

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
            keys[#keys + 1] = tostring(k)
            if #keys >= 5 then break end
        end
        return string.format("{%d:%s%s}", keyCount, table.concat(keys, ","), keyCount > 5 and ",.." or "")
    elseif t == "string" then
        if #value > 80 then return '"' .. value:sub(1, 80) .. '..."' end
        return '"' .. value .. '"'
    elseif t == "userdata" then
        local getName = value.GetName
        if type(getName) == "function" then
            local ok, name = pcall(getName, value)
            if ok and name and name ~= "" then return "<ctrl:" .. tostring(name) .. ">" end
        end
        return "<userdata>"
    end
    return tostring(value)
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
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    local parts = {}
    for i = 1, #keys do
        if i > MAX_LOG_FIELDS then parts[#parts + 1] = ".."; break end
        parts[#parts + 1] = tostring(keys[i]) .. "=" .. Log.Summarize(data[keys[i]])
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

-- Render + route a record whose gate has ALREADY passed (see EnabledFor). Keeping
-- the sink-mask read and rendering out of the gate keeps EnabledFor cheap, and
-- skips renderData() entirely when payload capture is off.
local function dispatch(level, category, message, data)
    local clock = G("GetGameTimeMilliseconds")
    local ts = type(clock) == "function" and clock() or 0
    local text = tostring(message)
    if data ~= nil and payloadCapture then text = text .. " " .. renderData(data) end

    local mask = sinks[level]
    if mask.file then
        sinkFile(string.format("[BUI] %d %s %s | %s", ts, LEVEL_NAME[level], category, text))
    end
    if mask.chat then
        sinkChat(category, text)
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
    if type(message) == "function" then message = message() end
    local data = nil
    if payloadCapture and type(dataFn) == "function" then data = dataFn() end
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
--- "verbose" preset turns this on; "debug" turns it off (message-only, cheap).
---@param on boolean
function Log.SetPayloadCapture(on) payloadCapture = on and true or false; currentPreset = "custom" end
---@return boolean
function Log.GetPayloadCapture() return payloadCapture end

-- Presets -------------------------------------------------------------------
-- Named user-facing log levels layered over the low-level knobs. The canonical
-- way to turn logging on for troubleshooting:
--   off     -> stop file logging, restore error popups, reset rate-limit budget.
--   debug   -> low-volume capture of WARN/ERROR only (real failures + SafeExecute
--              pcall/nil-function errors), payloads off. Cheap to run live.
--   verbose -> full TRACE+ capture, all categories on, payloads on. High volume;
--              InterfaceLog applies a per-frame/second budget so it can't hitch.
local PRESET_NAMES = { off = true, debug = true, verbose = true }

-- file ON for levels >= fileFromLevel (nil = all file sinks off); chat per chatOn.
local function applyAllSinks(fileFromLevel, chatOn)
    for i = 1, #LEVEL_NAME do
        sinks[i].file = (fileFromLevel ~= nil) and (i >= fileFromLevel) or false
        sinks[i].chat = chatOn and true or false
    end
end

---@param name string  "off" | "debug" | "verbose"
---@return boolean applied
---@return string preset
function Log.ApplyPreset(name)
    name = type(name) == "string" and name:lower() or ""
    if not PRESET_NAMES[name] then return false, currentPreset end
    local il = BETTERUI.CIM and BETTERUI.CIM.InterfaceLog

    if name == "off" then
        if il and il.SetBudget then il.SetBudget({ maxPerFrame = 0, maxPerSecond = 0, maxPending = 0 }) end
        if il and il.SetEnabled then il.SetEnabled(false) end
    elseif name == "debug" then
        minLevel = Log.LEVEL.WARN
        applyAllSinks(Log.LEVEL.WARN, false) -- WARN/ERROR -> file only
        categoryDisabled = {}
        payloadCapture = false
        if il and il.SetBudget then il.SetBudget({ maxPerFrame = 0, maxPerSecond = 0, maxPending = 0 }) end
        if il and il.SetEnabled then il.SetEnabled(true) end
    elseif name == "verbose" then
        minLevel = Log.LEVEL.TRACE
        applyAllSinks(Log.LEVEL.TRACE, false) -- everything -> file
        categoryDisabled = {}
        payloadCapture = true
        -- Bound the deferred-error file sink so a verbose burst on a hot path can't
        -- hitch a frame: <=8 lines/frame (the anti-hitch cap) and <=100/sec sustained;
        -- overflow is dropped + summarized. Tunable via /builog or InterfaceLog.SetBudget.
        if il and il.SetBudget then il.SetBudget({ maxPerFrame = 8, maxPerSecond = 100, maxPending = 200 }) end
        if il and il.SetEnabled then il.SetEnabled(true) end
    end

    currentPreset = name
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
--- Cheap gate for HOT paths: check this before building an expensive log payload
--- so normal players (logging off) pay nothing, e.g.
---   if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(cat, msg, heavy()) end
--- For an exact (level/category/sink-aware) gate, prefer Log.EnabledFor or the
--- Log.*Lazy variants.
---@return boolean
function Log.IsActive() return isActive() end
