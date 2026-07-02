--[[
File: Modules/CIM/Core/Diagnostics/InterfaceLog.lua
Purpose: Stream BetterUI debug breadcrumbs into the game's Interface.log in real time,
         so diagnostics can be reviewed while you play.

Mechanism (proof of concept):
  The retail client exposes NO API to write arbitrary text to Interface.log -- the
  WriteToInterfaceLog global exists only in ZOS internal builds (hence the
  `if WriteToInterfaceLog then` guards throughout ESOUI). However, the engine DOES
  write every uncaught Lua error to Interface.log in real time. So to emit a log line
  we deliberately raise a tagged, *deferred*, *throwaway* error:
    - deferred via zo_callLater so the stack unwind never aborts caller code;
    - popup suppressed via ZO_ERROR_FRAME.suppressErrorDialog so no error frame appears
      (verified: suppression hides the dialog but the line still logs to file).

  Real Lua errors already land in Interface.log for free -- this module only adds the
  BetterUI breadcrumb stream on top of that.

  Because each persisted line costs one deferred error (+ an engine traceback block),
  high-volume logging is rate-limited by an optional per-frame/second BUDGET so a
  burst on a hot path can't schedule thousands of errors and hitch a frame; overflow
  is dropped and summarized once as `dropped=N reason=rate_limit`. The budget is
  unlimited by default and is set by named presets (see Log.ApplyPreset).

  On disk the engine therefore wraps each emitted line as:
    <ISO-8601 ts±tz> |cff0000Lua Error: <our [BUI] line>
  followed by a short "stack traceback:" block. Consumers filter on the [BUI] tag
  (grep '[BUI]') for a clean breadcrumb stream and ignore those tracebacks; untagged
  "Lua Error:" entries are real game errors whose traceback matters.

Usage (slash command): /builog on | off | preset off|info|watch|debug|trace|inspect | chat on|off | popups on|off | privacy on|off | level <lvl> | mark <text> | recent|errors [n] | capture [secs] | screenshot [label] | screenshot auto off|error|warn | snapshot | report | check|test | status
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local InterfaceLog = {}
BETTERUI.CIM.InterfaceLog = InterfaceLog

local TAG = "[BUI]"
local MAX_LINE_LENGTH = 2048
local TRUNCATED_MARKER = " truncated=1"

local enabled = false          -- session breadcrumb logging on/off
local suppressPopups = true    -- kept for saved-state compatibility; our log-errors are always suppressed
local savedSuppressState = nil -- prior ZO_ERROR_FRAME.suppressErrorDialog, for restore

-- Backpressure budget for the file sink. 0 = unlimited (default; preserves legacy
-- behavior). Log presets set per-frame/second caps; overflow is dropped
-- and a single coalesced "dropped=N" summary is emitted. maxPending caps deferred
-- breadcrumbs that have been scheduled but not yet raised, protecting frame recovery
-- after a burst.
local budget = { maxPerFrame = 0, maxPerSecond = 0, maxPending = 0 }
local stats = { scheduled = 0, dropped = 0, suppressed = 0 }
local frameMarker = nil
local emittedThisFrame = 0
local secondWindowStart = nil
local emittedThisSecond = 0
local pendingDropsByReason = {}
local dropSummaryScheduled = false
local pendingCount = 0
local emitGeneration = 0
local quiesceUntilMs = 0
local DEFAULT_RELOAD_QUIESCE_MS = 5000
local reloadExitHooks = {}
local reloadExitFunctionNames = { "ReloadUI", "LogOut", "Quit" }

-- Engine globals are absent in the unit-test harness; resolve them defensively.
local function G(name)
    return rawget(_G, name)
end

local function Timestamp()
    local clock = G("GetGameTimeMilliseconds")
    return type(clock) == "function" and clock() or 0
end

local Flatten

local function ResetPendingDrops()
    pendingDropsByReason = {}
end

local function HasPendingDrops()
    for _, n in pairs(pendingDropsByReason) do
        if n and n > 0 then return true end
    end
    return false
end

local function TakePendingDropSummary()
    local priorityDrops = pendingDropsByReason.priority_rate_limit or 0
    if priorityDrops > 0 then
        pendingDropsByReason.priority_rate_limit = nil
        return "priority_rate_limit", priorityDrops
    end
    local normalDrops = pendingDropsByReason.rate_limit or 0
    if normalDrops > 0 then
        pendingDropsByReason.rate_limit = nil
        return "rate_limit", normalDrops
    end
    for reason, n in pairs(pendingDropsByReason) do
        if n and n > 0 then
            pendingDropsByReason[reason] = nil
            reason = Flatten(reason, true):gsub("%s+", "_")
            if reason == "" then reason = "rate_limit" end
            return reason, n
        end
        pendingDropsByReason[reason] = nil
    end
    return nil, 0
end

-- A value that stays constant within one rendered frame, so we can count emissions
-- per frame. Falls back to the game clock when the frame clock is unavailable.
local function FrameStamp()
    local frameClock = G("GetFrameTimeMilliseconds")
    if type(frameClock) == "function" then return frameClock() end
    return Timestamp()
end

local function IsQuiescing()
    return quiesceUntilMs > Timestamp()
end

local function EnterQuiesce(durationMs)
    local duration = tonumber(durationMs) or DEFAULT_RELOAD_QUIESCE_MS
    if duration < 0 then duration = 0 end
    local untilMs = Timestamp() + duration
    if untilMs > quiesceUntilMs then quiesceUntilMs = untilMs end
    emitGeneration = emitGeneration + 1
    ResetPendingDrops()
    dropSummaryScheduled = false
    return true
end

-- Collapse newlines/tabs so each breadcrumb stays a single greppable record. Newlines
-- collapse to a SPACE -- never the ` | ` field separator (which would split one record into
-- bogus fields for a host parser); matches Log.sinkFile's single-space collapse. tostring is
-- guarded so a non-string meta-line argument can't raise.
function Flatten(text, neutralizePipes)
    local ok, s = pcall(tostring, text)
    text = (ok and type(s) == "string") and s or "<?>"
    text = text:gsub("[\r\n]+", " ")
    text = text:gsub("\t", " ")
    if neutralizePipes then
        text = text:gsub("|", "/")
    end
    return text
end

-- Pull the shared session id + next sequence number from the logger so InterfaceLog's
-- own meta-lines (startup header, drop summaries) carry the SAME sid/seq schema as
-- Log.* records and order correctly when interleaved. Log loads after InterfaceLog, so
-- resolve it at call time; degrade to placeholders if it isn't ready.
local function LogMeta()
    local L = BETTERUI.Log
    local sid = (L and L.GetSessionId and L.GetSessionId()) or "00000000"
    local seq = (L and L.NextSeq and L.NextSeq()) or 0
    return sid, seq
end

local function FormatLine(message)
    local sid, seq = LogMeta()
    -- Carry an INFO LOG level/category so these meta-lines (startup header, disabled marker,
    -- test breadcrumbs) match the SAME `<LEVEL> <CATEGORY> | <event>` shape the host parser
    -- expects -- otherwise a tailer would drop them.
    return string.format("%s %d sid=%s seq=%d INFO LOG | %s", TAG, Timestamp(), sid, seq, Flatten(message, true))
end

-- Apply/remove global error-dialog suppression, remembering the prior state so a
-- later disable restores exactly what the user (or game) had before. Returns true when
-- the requested state is guaranteed in effect; returns FALSE only when asked to suppress
-- but ZO_ERROR_FRAME does not yet exist as a table -- i.e. mid-/reloadui, while the error
-- frame is being torn down/recreated. In that window we cannot set suppressErrorDialog,
-- so the caller (RaiseSuppressed) must NOT raise an error it can't suppress.
---@param suppress boolean
---@return boolean guaranteed
local function ApplyPopupSuppression(suppress)
    local frame = G("ZO_ERROR_FRAME")
    if type(frame) ~= "table" then return not suppress end

    if suppress then
        if savedSuppressState == nil then
            savedSuppressState = frame.suppressErrorDialog and true or false
        end
        frame.suppressErrorDialog = true
    elseif savedSuppressState ~= nil then
        frame.suppressErrorDialog = savedSuppressState
        savedSuppressState = nil
    end
    return true
end

---@return boolean
function InterfaceLog.IsEnabled()
    return enabled
end

--- Whether the in-game logging path is usable (false in tests / pregame).
---@return boolean
function InterfaceLog.IsAvailable()
    return type(G("zo_callLater")) == "function"
end

local PRIORITY_CATEGORIES = {
    STATE = true,
    SCENE = true,
    LIFECYCLE = true,
    ACTION = true,
    TRANSFER = true,
    DIALOG = true,
    KEYBIND = true,
}

local function EffectiveCap(cap, priority)
    if cap <= 0 then return 0 end
    return priority and (cap * 4) or cap
end

-- Returns true while the current frame/second window still has budget headroom,
-- accounting the emission when it does. Unlimited (both caps 0) always allows.
local function budgetAllows(priority)
    local maxPerFrame = EffectiveCap(budget.maxPerFrame, priority == true)
    local maxPerSecond = EffectiveCap(budget.maxPerSecond, priority == true)
    if maxPerFrame <= 0 and maxPerSecond <= 0 then return true end

    if maxPerFrame > 0 then
        local fid = FrameStamp()
        if fid ~= frameMarker then frameMarker = fid; emittedThisFrame = 0 end
        if emittedThisFrame >= maxPerFrame then return false end
    end

    local countSecond = false
    if maxPerSecond > 0 then
        local now = Timestamp()
        if now > 0 then
            countSecond = true
            if secondWindowStart == nil or (now - secondWindowStart) >= 1000 then
                secondWindowStart = now; emittedThisSecond = 0
            end
            if emittedThisSecond >= maxPerSecond then return false end
        end
    end

    if maxPerFrame > 0 then emittedThisFrame = emittedThisFrame + 1 end
    if countSecond then emittedThisSecond = emittedThisSecond + 1 end
    return true
end

local function IsPriorityLine(line)
    if type(line) ~= "string" then return false end
    local header = line:match("^(.-) | ") or line
    local level, category = header:match("%s([A-Z]+)%s+([A-Z]+)$")
    -- Verbose presets may rate-limit TRACE/DEBUG chatter, but warning/error
    -- breadcrumbs plus replay-critical UI transitions must survive.
    return level == "WARN"
        or level == "ERROR"
        or PRIORITY_CATEGORIES[category] == true
end

local function IsUnsafeReloadSceneLine(line)
    if type(line) ~= "string" then return false end
    if line:find(" DEBUG SCENE |", 1, true) == nil then return false end
    return line:find("scene hudui hiding", 1, true) ~= nil
        or (line:find('scene="hudui"', 1, true) ~= nil and line:find('to="hiding"', 1, true) ~= nil)
end

local function DropReloadSceneLine(line)
    if not IsUnsafeReloadSceneLine(line) then return false end
    EnterQuiesce(DEFAULT_RELOAD_QUIESCE_MS)
    stats.suppressed = stats.suppressed + 1
    return true
end

-- Raise one of OUR throwaway breadcrumb errors. CRITICALLY, re-assert popup
-- suppression FIRST: the engine writes every uncaught error to Interface.log (what we
-- want) but ALSO shows the UI error viewer unless ZO_ERROR_FRAME.suppressErrorDialog
-- is set. That flag is reset to false by the error frame's own Initialize, and the
-- persisted-state restore can run before the frame exists, so applying suppression
-- once at enable-time is not enough -- in gamepad mode every unsuppressed breadcrumb
-- pops the error viewer (and they queue, undismissable). Re-asserting through
-- ApplyPopupSuppression at raise time is bulletproof and preserves save/restore, so
-- /builog off still restores the player's real error popups.
local function RaiseSuppressed(line)
    -- A breadcrumb deferred via zo_callLater can fire AFTER /builog off (which restored the
    -- player's real error popups). Bail before error() so a stale in-flight emit can't pop
    -- the error viewer once logging is disabled.
    if not enabled then return end
    if IsQuiescing() then
        stats.suppressed = stats.suppressed + 1
        return
    end
    if DropReloadSceneLine(line) then return end
    -- When suppression is requested but cannot be guaranteed (ZO_ERROR_FRAME is mid-recreate
    -- during a /reloadui), DROP this breadcrumb instead of raising it. Raising an error we
    -- can't suppress is exactly what leaks the (undismissable, in gamepad) error viewer: the
    -- engine queues the unsuppressed error and pops it once the frame returns. A breadcrumb
    -- lost across a reloadui boundary (where sid changes anyway) is the right trade.
    if not ApplyPopupSuppression(true) then
        stats.suppressed = stats.suppressed + 1
        return
    end
    error(line, 0)
end

-- Coalesce dropped-record reporting into at most one summary error per ~250ms, so a
-- rate-limited burst does not itself spam the log.
local function ScheduleDropSummary(deferer)
    if dropSummaryScheduled then return end
    dropSummaryScheduled = true
    local gen = emitGeneration
    deferer(function()
        dropSummaryScheduled = false
        if gen ~= emitGeneration then return end
        local reason, n = TakePendingDropSummary()
        if HasPendingDrops() then ScheduleDropSummary(deferer) end
        if n > 0 then
            local sid, seq = LogMeta()
            RaiseSuppressed(string.format("%s %d sid=%s seq=%d WARN LOG | dropped=%d reason=%s",
                TAG, Timestamp(), sid, seq, n, reason))
        end
    end, 250)
end

local function RecordDrop(reason, deferer)
    reason = type(reason) == "string" and reason or "rate_limit"
    stats.dropped = stats.dropped + 1
    pendingDropsByReason[reason] = (pendingDropsByReason[reason] or 0) + 1
    ScheduleDropSummary(deferer)
end

local function Utf8SafePrefix(line, maxBytes)
    if maxBytes >= #line then return line end
    local cut = maxBytes
    while cut > 0 do
        local nextByte = line:byte(cut + 1)
        if nextByte == nil or nextByte < 0x80 or nextByte > 0xBF then break end
        cut = cut - 1
    end
    if cut < 1 then return "" end
    return line:sub(1, cut)
end

local function CapLineLength(line)
    if type(line) ~= "string" or #line <= MAX_LINE_LENGTH then return line end
    local prefixLength = MAX_LINE_LENGTH - #TRUNCATED_MARKER
    if prefixLength < 1 then return line:sub(1, MAX_LINE_LENGTH) end
    return Utf8SafePrefix(line, prefixLength) .. TRUNCATED_MARKER
end

--- Writes one tagged breadcrumb to Interface.log via a deferred, suppressed error.
--- No-ops when disabled or outside the game. Returns true if a write was scheduled.
---@param message any
---@return boolean
-- Schedule a deferred, throwaway, popup-suppressed error carrying exactly `line`.
-- Raised uncaught from a throwaway callback so the engine logs it to Interface.log
-- without aborting caller code; level 0 keeps the engine from prefixing file:line noise.
local function RawEmit(line, priority)
    local deferer = G("zo_callLater")
    if type(deferer) ~= "function" then return false end
    line = CapLineLength(line)
    if IsQuiescing() then
        stats.suppressed = stats.suppressed + 1
        return false
    end
    if DropReloadSceneLine(line) then return false end
    priority = priority == true
    if budget.maxPending > 0 and pendingCount >= budget.maxPending then
        RecordDrop(priority and "priority_rate_limit" or "rate_limit", deferer)
        return false
    end
    if not budgetAllows(priority) then
        RecordDrop(priority and "priority_rate_limit" or "rate_limit", deferer)
        return false
    end
    stats.scheduled = stats.scheduled + 1
    pendingCount = pendingCount + 1
    local gen = emitGeneration
    deferer(function()
        if pendingCount > 0 then pendingCount = pendingCount - 1 end
        if gen ~= emitGeneration then return end
        RaiseSuppressed(line)
    end, 0)
    return true
end

function InterfaceLog.Write(message)
    if not enabled then return false end
    local line = FormatLine(message)
    return RawEmit(line, IsPriorityLine(line))
end

--- Writes a pre-formatted line verbatim to Interface.log. Used by BETTERUI.Log, which
--- owns level/category/timestamp formatting. No-ops when disabled or outside the game.
---@param line string
---@return boolean
function InterfaceLog.WriteRaw(line)
    if not enabled then return false end
    -- Defensive: callers (Log.sinkFile) already flatten, but never let a stray newline
    -- split one record across lines for a tailer.
    line = Flatten(line, false)
    return RawEmit(line, IsPriorityLine(line))
end

--- Sets the file-sink rate-limit budget. Pass any subset of:
---   { maxPerFrame = n, maxPerSecond = n, maxPending = n }   (0 disables that cap)
--- Resets the current windows so the new budget starts clean.
---@param opts table
function InterfaceLog.SetBudget(opts)
    if type(opts) ~= "table" then return end
    if type(opts.maxPerFrame) == "number" then budget.maxPerFrame = opts.maxPerFrame end
    if type(opts.maxPerSecond) == "number" then budget.maxPerSecond = opts.maxPerSecond end
    if type(opts.maxPending) == "number" then budget.maxPending = opts.maxPending end
    frameMarker = nil; emittedThisFrame = 0
    secondWindowStart = nil; emittedThisSecond = 0
end

--- Returns scheduled/dropped counters and the active budget for diagnostics.
---@return table
function InterfaceLog.GetStats()
    return {
        scheduled = stats.scheduled,
        dropped = stats.dropped,
        suppressed = stats.suppressed,
        pending = pendingCount,
        maxPerFrame = budget.maxPerFrame,
        maxPerSecond = budget.maxPerSecond,
        maxPending = budget.maxPending,
    }
end

--- Compatibility setter for the old popup option.
--- BetterUI's own log transport is always file-only while builog is enabled.
---@param suppress boolean
function InterfaceLog.SetSuppressPopups(suppress)
    -- BetterUI's Interface.log transport is deliberately implemented with
    -- throwaway Lua errors; letting those reach the native error frame makes
    -- builog unusable. Preserve the setter for saved-vars/slash compatibility,
    -- but enforce file-only breadcrumbs whenever builog is enabled.
    suppressPopups = true
    ApplyPopupSuppression(enabled)
end

---@return boolean
function InterfaceLog.GetSuppressPopups()
    return true
end

function InterfaceLog.Quiesce(durationMs)
    return EnterQuiesce(durationMs)
end

function InterfaceLog.IsQuiescing()
    return IsQuiescing()
end

--- Enables/disables breadcrumb logging for this session.
---@param value boolean
function InterfaceLog.SetEnabled(value)
    local nextEnabled = value and true or false
    if enabled ~= nextEnabled then
        emitGeneration = emitGeneration + 1
        ResetPendingDrops()
        dropSummaryScheduled = false
    end
    enabled = nextEnabled
    ApplyPopupSuppression(enabled)
    InterfaceLog.InstallReloadQuiesceHooks()
    -- Enabling/disabling the file sink flips the logger's active state.
    if BETTERUI.Log and BETTERUI.Log.InvalidateActive then BETTERUI.Log.InvalidateActive() end
end

local function ResolveEventManager()
    local eventManager = G("EVENT_MANAGER")
    if type(eventManager) == "table" then return eventManager end
    local getter = G("GetEventManager")
    if type(getter) == "function" then
        local ok, value = pcall(getter)
        if ok then return value end
    end
    return nil
end

function InterfaceLog.RegisterReloadQuiesce()
    local eventManager = ResolveEventManager()
    local eventCode = G("EVENT_PLAYER_DEACTIVATED")
    if type(eventManager) ~= "table" or type(eventManager.RegisterForEvent) ~= "function" or eventCode == nil then
        return false
    end
    local ok, registered = pcall(function()
        return eventManager:RegisterForEvent("BetterUI_InterfaceLogReloadQuiesce", eventCode, function()
            InterfaceLog.Quiesce(DEFAULT_RELOAD_QUIESCE_MS)
        end)
    end)
    return ok and registered ~= false
end

function InterfaceLog.InstallReloadQuiesceHooks()
    local installed = false
    for _, name in ipairs(reloadExitFunctionNames) do
        local current = G(name)
        local existing = reloadExitHooks[name]
        if existing and current == existing.wrapper then
            installed = true
        elseif type(current) == "function" then
            local original = current
            local wrapper = function(...)
                InterfaceLog.Quiesce(DEFAULT_RELOAD_QUIESCE_MS)
                return original(...)
            end
            local ok = pcall(function()
                _G[name] = wrapper
            end)
            if ok then
                reloadExitHooks[name] = { original = original, wrapper = wrapper }
                installed = true
            end
        end
    end
    return installed
end

InterfaceLog.RegisterReloadQuiesce()
InterfaceLog.InstallReloadQuiesceHooks()

-- ---------------------------------------------------------------------------
-- Persisted builog settings surface
-- ---------------------------------------------------------------------------

-- Persist the user's explicit /builog intent so logging survives /reloadui. The
-- InterfaceLog 'enabled' flag is otherwise session-only (reset to false each load);
-- RuntimeSetup.Apply restores from these keys after SavedVars load. Guarded so a
-- pre-SavedVars / test-harness call is a silent no-op. preset="" means "plain on"
-- (defaults, no named preset); a named preset restores its logging knobs.
local LEVEL_NAMES_BY_VALUE = { [1] = "trace", [2] = "debug", [3] = "info", [4] = "warn", [5] = "error" }

local function LevelNameFromValue(level)
    return LEVEL_NAMES_BY_VALUE[level] or "info"
end

local function TraceBuilogSetting(key, value)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent and L.CATEGORY and L.CATEGORY.SETTINGS and L.LEVEL) then return end
    L.TraceEvent(L.CATEGORY.SETTINGS, "settings.builog", "write", {
        key = key,
        value = tostring(value),
    }, L.LEVEL.INFO)
end

local function PersistLogSetting(key, value)
    if type(BETTERUI.SetSetting) ~= "function" or not BETTERUI.Settings then return end
    BETTERUI.SetSetting("CIM", key, value)
end

local function PersistLogState(enabled, preset)
    PersistLogSetting("interfaceLogEnabled", enabled and true or false)
    if preset ~= nil then
        PersistLogSetting("interfaceLogPreset", preset)
    end
end

local function ForceChatSurfaceOff()
    local L = BETTERUI.Log
    if not (L and L.SetSink and L.LEVEL) then
        return false
    end
    -- Builog is file-only. Keep this legacy helper as a forced-off compatibility
    -- path so old saved state or /builog chat on cannot leak diagnostics to chat.
    L.SetSink(L.LEVEL.INFO, "chat", false)
    L.SetSink(L.LEVEL.WARN, "chat", false)
    L.SetSink(L.LEVEL.ERROR, "chat", false)
    return true
end

function InterfaceLog.SetLoggingEnabled(value, source)
    local nextEnabled = value and true or false
    local sourceName = type(source) == "string" and source or "settings panel"
    if not nextEnabled then
        TraceBuilogSetting("enabled", false)
        InterfaceLog.Write("builog disabled via " .. sourceName)
        local watchdog = BETTERUI.CIM and BETTERUI.CIM.Watchdog
        if watchdog and type(watchdog.Deactivate) == "function" then
            pcall(watchdog.Deactivate)
        end
    end
    InterfaceLog.SetEnabled(nextEnabled)
    ForceChatSurfaceOff()
    PersistLogState(nextEnabled, "")
    if nextEnabled then
        InterfaceLog.Write("builog enabled via " .. sourceName)
        TraceBuilogSetting("enabled", true)
    end
    return true
end

function InterfaceLog.ApplyLogPreset(name)
    local L = BETTERUI.Log
    if not (L and L.ApplyPreset) then return false, "logger_unavailable" end
    local applied, presetName = L.ApplyPreset(name)
    if applied then
        ForceChatSurfaceOff()
        local normalized = tostring(presetName or "")
        PersistLogState(normalized ~= "off", normalized ~= "off" and normalized or "")
        PersistLogSetting("interfaceLogMinLevel", "")
        TraceBuilogSetting("preset", normalized)
    end
    return applied, presetName
end

function InterfaceLog.SetChatSurface(on, persist)
    if not ForceChatSurfaceOff() then return false end
    if persist ~= false then
        PersistLogSetting("interfaceLogChat", false)
        TraceBuilogSetting("chat", false)
    end
    return on ~= true
end

function InterfaceLog.GetChatSurface()
    return false
end

function InterfaceLog.SetPopupSuppression(suppress, persist)
    local nextSuppress = true
    InterfaceLog.SetSuppressPopups(true)
    if persist ~= false then
        PersistLogSetting("interfaceLogSuppressPopups", nextSuppress)
        TraceBuilogSetting("popups", "suppressed")
    end
    return suppress ~= false
end

function InterfaceLog.GetMinLevelName()
    local L = BETTERUI.Log
    local level = L and L.GetMinLevel and L.GetMinLevel()
    return LevelNameFromValue(level)
end

function InterfaceLog.SetPrivacyMode(on, persist)
    local L = BETTERUI.Log
    if not (L and L.SetPrivacyMode) then return false end
    local enabledPrivacy = on and true or false
    L.SetPrivacyMode(enabledPrivacy)
    if persist ~= false then
        PersistLogSetting("interfaceLogPrivacy", enabledPrivacy)
        TraceBuilogSetting("privacy", enabledPrivacy and "on" or "off")
    end
    return true
end

function InterfaceLog.GetPrivacyMode()
    local L = BETTERUI.Log
    return (L and L.GetPrivacyMode and L.GetPrivacyMode() == true) or false
end

function InterfaceLog.SetMinLevelSetting(name, persist)
    local L = BETTERUI.Log
    local level = L and L.LevelFromName and L.LevelFromName(name)
    if not (level and L.SetMinLevel) then return false, InterfaceLog.GetMinLevelName() end
    L.SetMinLevel(level)
    local levelName = LevelNameFromValue(level)
    if persist ~= false then
        PersistLogSetting("interfaceLogMinLevel", levelName)
        TraceBuilogSetting("minLevel", levelName)
    end
    return true, levelName
end

function InterfaceLog.SetScreenshotAutoMode(mode, persist)
    local S = BETTERUI.CIM and BETTERUI.CIM.Screenshot
    if not (S and S.SetAutoMode) then return false, "unavailable" end
    local ok, applied = S.SetAutoMode(mode)
    if ok and persist ~= false then
        PersistLogSetting("interfaceLogScreenshotAutoMode", applied)
        TraceBuilogSetting("screenshotAuto", applied)
    end
    return ok, applied
end

function InterfaceLog.GetScreenshotAutoMode()
    local S = BETTERUI.CIM and BETTERUI.CIM.Screenshot
    if S and S.GetAutoMode then return S.GetAutoMode() end
    return "off"
end

-- Slash-command handlers and registration live in BuilogCommands.lua.
