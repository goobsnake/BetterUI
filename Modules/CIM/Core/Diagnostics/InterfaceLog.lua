--[[
File: Modules/CIM/Core/Diagnostics/InterfaceLog.lua
Purpose: Stream BetterUI debug breadcrumbs into the game's Interface.log in real time,
         so an external process (e.g. an AI assistant) can tail it while you play.

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
  unlimited by default and is set by the "verbose" preset (see Log.ApplyPreset).

  On disk the engine therefore wraps each emitted line as:
    <ISO-8601 ts±tz> |cff0000Lua Error: <our [BUI] line>
  followed by a short "stack traceback:" block. Consumers filter on the [BUI] tag
  (grep '[BUI]') for a clean breadcrumb stream and ignore those tracebacks; untagged
  "Lua Error:" entries are real game errors whose traceback matters.

Usage (slash command): /builog on | off | preset off|info|watch|debug|trace | test | popups on|off | status
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local InterfaceLog = {}
BETTERUI.CIM.InterfaceLog = InterfaceLog

local TAG = "[BUI]"

local enabled = false          -- session breadcrumb logging on/off
local suppressPopups = true    -- hide the error frame for our log-errors
local savedSuppressState = nil -- prior ZO_ERROR_FRAME.suppressErrorDialog, for restore

-- Backpressure budget for the file sink. 0 = unlimited (default; preserves legacy
-- behavior). The "verbose" preset sets a per-frame/second cap; overflow is dropped
-- and a single coalesced "dropped=N" summary is emitted. (maxPending is reserved for
-- a future batch/queue mode; the sink currently schedules one error per line.)
local budget = { maxPerFrame = 0, maxPerSecond = 0, maxPending = 0 }
local stats = { scheduled = 0, dropped = 0 }
local frameMarker = nil
local emittedThisFrame = 0
local secondWindowStart = nil
local emittedThisSecond = 0
local pendingDrops = 0
local dropSummaryScheduled = false

-- Engine globals are absent in the unit-test harness; resolve them defensively.
local function G(name)
    return rawget(_G, name)
end

local function Timestamp()
    local clock = G("GetGameTimeMilliseconds")
    return type(clock) == "function" and clock() or 0
end

-- A value that stays constant within one rendered frame, so we can count emissions
-- per frame. Falls back to the game clock when the frame clock is unavailable.
local function FrameStamp()
    local frameClock = G("GetFrameTimeMilliseconds")
    if type(frameClock) == "function" then return frameClock() end
    return Timestamp()
end

-- Collapse newlines/tabs so each breadcrumb stays a single greppable record.
local function Flatten(text)
    text = tostring(text)
    text = text:gsub("[\r\n]+", " | ")
    text = text:gsub("\t", " ")
    return text
end

-- Pull the shared session id + next sequence number from the logger so InterfaceLog's
-- own meta-lines (startup header, drop summaries) carry the SAME sid/seq schema as
-- Log.* records and order correctly when interleaved. Log loads after InterfaceLog, so
-- resolve it at call time; degrade to placeholders if it isn't ready.
local function LogMeta()
    local L = BETTERUI.Log
    local sid = (L and L.GetSessionId and L.GetSessionId()) or "------"
    local seq = (L and L.NextSeq and L.NextSeq()) or 0
    return sid, seq
end

local function FormatLine(message)
    local sid, seq = LogMeta()
    return string.format("%s %d sid=%s seq=%d %s", TAG, Timestamp(), sid, seq, Flatten(message))
end

-- Apply/remove global error-dialog suppression, remembering the prior state so a
-- later disable restores exactly what the user (or game) had before.
local function ApplyPopupSuppression(suppress)
    local frame = G("ZO_ERROR_FRAME")
    if type(frame) ~= "table" then return end

    if suppress then
        if savedSuppressState == nil then
            savedSuppressState = frame.suppressErrorDialog and true or false
        end
        frame.suppressErrorDialog = true
    elseif savedSuppressState ~= nil then
        frame.suppressErrorDialog = savedSuppressState
        savedSuppressState = nil
    end
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

-- Returns true while the current frame/second window still has budget headroom,
-- accounting the emission when it does. Unlimited (both caps 0) always allows.
local function budgetAllows()
    if budget.maxPerFrame <= 0 and budget.maxPerSecond <= 0 then return true end

    if budget.maxPerFrame > 0 then
        local fid = FrameStamp()
        if fid ~= frameMarker then frameMarker = fid; emittedThisFrame = 0 end
        if emittedThisFrame >= budget.maxPerFrame then return false end
    end

    if budget.maxPerSecond > 0 then
        local now = Timestamp()
        if secondWindowStart == nil or (now - secondWindowStart) >= 1000 then
            secondWindowStart = now; emittedThisSecond = 0
        end
        if emittedThisSecond >= budget.maxPerSecond then return false end
    end

    emittedThisFrame = emittedThisFrame + 1
    emittedThisSecond = emittedThisSecond + 1
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
    if enabled and suppressPopups then ApplyPopupSuppression(true) end
    error(line, 0)
end

-- Coalesce dropped-record reporting into at most one summary error per ~250ms, so a
-- rate-limited burst does not itself spam the log.
local function ScheduleDropSummary(deferer)
    if dropSummaryScheduled then return end
    dropSummaryScheduled = true
    deferer(function()
        dropSummaryScheduled = false
        local n = pendingDrops
        pendingDrops = 0
        if n > 0 then
            local sid, seq = LogMeta()
            RaiseSuppressed(string.format("%s %d sid=%s seq=%d WARN LOG | dropped=%d reason=rate_limit",
                TAG, Timestamp(), sid, seq, n))
        end
    end, 250)
end

--- Writes one tagged breadcrumb to Interface.log via a deferred, suppressed error.
--- No-ops when disabled or outside the game. Returns true if a write was scheduled.
---@param message any
---@return boolean
-- Schedule a deferred, throwaway, popup-suppressed error carrying exactly `line`.
-- Raised uncaught from a throwaway callback so the engine logs it to Interface.log
-- without aborting caller code; level 0 keeps the engine from prefixing file:line noise.
local function RawEmit(line)
    local deferer = G("zo_callLater")
    if type(deferer) ~= "function" then return false end
    if not budgetAllows() then
        stats.dropped = stats.dropped + 1
        pendingDrops = pendingDrops + 1
        ScheduleDropSummary(deferer)
        return false
    end
    stats.scheduled = stats.scheduled + 1
    deferer(function() RaiseSuppressed(line) end, 0)
    return true
end

function InterfaceLog.Write(message)
    if not enabled then return false end
    return RawEmit(FormatLine(message))
end

--- Writes a pre-formatted line verbatim to Interface.log. Used by BETTERUI.Log, which
--- owns level/category/timestamp formatting. No-ops when disabled or outside the game.
---@param line string
---@return boolean
function InterfaceLog.WriteRaw(line)
    if not enabled then return false end
    -- Defensive: callers (Log.sinkFile) already flatten, but never let a stray newline
    -- split one record across lines for a tailer.
    return RawEmit(Flatten(line))
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
        maxPerFrame = budget.maxPerFrame,
        maxPerSecond = budget.maxPerSecond,
        maxPending = budget.maxPending,
    }
end

--- Controls whether our log-errors suppress the on-screen error frame.
--- NOTE: suppression is global -- real error popups are hidden too (they still log).
---@param suppress boolean
function InterfaceLog.SetSuppressPopups(suppress)
    suppressPopups = suppress and true or false
    ApplyPopupSuppression(enabled and suppressPopups)
end

--- Enables/disables breadcrumb logging for this session.
---@param value boolean
function InterfaceLog.SetEnabled(value)
    enabled = value and true or false
    ApplyPopupSuppression(enabled and suppressPopups)
    -- Enabling/disabling the file sink flips the logger's active state.
    if BETTERUI.Log and BETTERUI.Log.InvalidateActive then BETTERUI.Log.InvalidateActive() end
end

-- ---------------------------------------------------------------------------
-- Slash command (proof of concept; fold into /betterui later if desired)
-- ---------------------------------------------------------------------------

local function Out(msg)
    local chat = G("d")
    if type(chat) == "function" then
        chat("|c0066ff[BetterUI]|r " .. msg)
    end
end

-- Persist the user's explicit /builog intent so logging survives /reloadui. The
-- InterfaceLog 'enabled' flag is otherwise session-only (reset to false each load);
-- RuntimeSetup.Apply restores from these keys after SavedVars load. Guarded so a
-- pre-SavedVars / test-harness call is a silent no-op. preset="" means "plain on"
-- (defaults, no named preset); a named preset ("debug"/"verbose") restores its knobs.
local function PersistLogState(enabled, preset)
    if type(BETTERUI.SetSetting) ~= "function" or not BETTERUI.Settings then return end
    BETTERUI.SetSetting("CIM", "interfaceLogEnabled", enabled and true or false)
    if preset ~= nil then
        BETTERUI.SetSetting("CIM", "interfaceLogPreset", preset)
    end
end

local function SetChatSurface(on)
    local L = BETTERUI.Log
    if not L then Out("Logger not loaded yet."); return end
    -- Surface INFO/WARN/ERROR to chat; TRACE/DEBUG stay file-only to avoid spam.
    L.SetSink(L.LEVEL.INFO, "chat", on)
    L.SetSink(L.LEVEL.WARN, "chat", on)
    L.SetSink(L.LEVEL.ERROR, "chat", on)
end

local function PrintStatus()
    local L = BETTERUI.Log
    Out(string.format("InterfaceLog: %s | popups: %s | path: %s",
        enabled and "|c00ff00ON|r" or "off",
        suppressPopups and "suppressed" or "visible",
        InterfaceLog.IsAvailable() and "ready" or "UNAVAILABLE"))
    if L then
        Out(string.format("Preset: %s | min level: %s | payloads: %s",
            L.GetPreset and tostring(L.GetPreset()):upper() or "?",
            L.GetMinLevel and (({ "TRACE", "DEBUG", "INFO", "WARN", "ERROR" })[L.GetMinLevel()] or "?") or "?",
            (L.GetPayloadCapture and L.GetPayloadCapture()) and "on" or "off"))
        Out(string.format("Logger chat surface (ERROR) = %s", L.GetSink(L.LEVEL.ERROR, "chat") and "on" or "off"))
    end
    local s = InterfaceLog.GetStats()
    Out(string.format("Sink budget: frame=%s sec=%s | scheduled=%d dropped=%d",
        s.maxPerFrame > 0 and tostring(s.maxPerFrame) or "inf",
        s.maxPerSecond > 0 and tostring(s.maxPerSecond) or "inf",
        s.scheduled, s.dropped))
    Out("Real Lua errors always log to Interface.log; [BUI] lines are BetterUI's own stream.")
end

-- capture [seconds]: temporarily raise to TRACE for a bounded window, then auto-revert to
-- the prior preset, so you can grab the next operation in FULL detail without leaving
-- trace running. Cancels a prior pending capture; pcall-guarded.
local captureRevertId = nil
local captureGen = 0
local function StartCapture(secs)
    local L = BETTERUI.Log
    if not (L and L.ApplyPreset and L.GetPreset) then Out("Logger not loaded.") return end
    local later = G("zo_callLater")
    -- Require the timer BEFORE applying trace: without it we could never auto-revert and
    -- would strand the client at TRACE.
    if type(later) ~= "function" then Out("Capture unavailable (no timer); use /builog preset trace manually.") return end
    secs = (type(secs) == "number") and math.max(1, math.min(60, secs)) or 5

    -- Cancel any prior pending capture + bump the generation so a stale/raced callback
    -- (if removal is unavailable or fails) no-ops instead of reverting a newer capture.
    local remove = G("zo_removeCallLater")
    if captureRevertId and type(remove) == "function" then pcall(remove, captureRevertId) end
    captureRevertId = nil
    captureGen = captureGen + 1
    local gen = captureGen

    local prevEnabled = enabled
    local okP, prevPreset = pcall(L.GetPreset)
    if not okP or type(prevPreset) ~= "string" then prevPreset = "debug" end
    if not enabled then InterfaceLog.SetEnabled(true) end
    pcall(L.ApplyPreset, "trace")
    if L.Info then pcall(L.Info, L.CATEGORY.STATE, "capture window started (" .. secs .. "s, was " .. prevPreset .. ")") end
    Out(string.format("Capturing at |c00ff00TRACE|r for %ds, then reverting to %s.", secs, prevPreset))

    captureRevertId = later(function()
        if gen ~= captureGen then return end -- superseded by a newer capture: no-op
        captureRevertId = nil
        -- Restore the prior preset (fall back to debug if it was custom/unknown), then the
        -- prior ENABLED state (capture force-enabled logging if it had been off).
        local pok, applied = pcall(L.ApplyPreset, prevPreset)
        if not (pok and applied) then pcall(L.ApplyPreset, "debug") end
        InterfaceLog.SetEnabled(prevEnabled)
        if L.Info then pcall(L.Info, L.CATEGORY.STATE, "capture window ended") end
    end, secs * 1000)
end

-- Dump the last n records from a Log ring getter (GetRecent / GetRecentErrors) to chat,
-- without tailing the file. Bounded + pcall-guarded so a /builog command can never raise.
local function DumpRecords(getter, n, label)
    if type(getter) ~= "function" then Out("Logger not loaded.") return end
    local ok, records = pcall(getter, n)
    if not ok or type(records) ~= "table" or #records == 0 then
        Out("No " .. label .. " records captured (logging may be off).") return
    end
    Out(string.format("|c0066ff[BetterUI]|r last %d %s record(s):", #records, label))
    for i = 1, #records do
        local r = records[i]
        Out(string.format("  seq=%s %s %s | %s",
            tostring(r.seq), tostring(r.level), tostring(r.category), tostring(r.message)))
    end
end

local function HandleCommand(args)
    local raw = tostring(args or ""):gsub("^%s+", ""):gsub("%s+$", "")

    -- "mark <text>": a user-placed annotation in the live stream (e.g. /builog mark
    -- "about to open bank"). Handled before lower() so the annotation keeps its case.
    local markText = raw:match("^[Mm][Aa][Rr][Kk]%s+(.+)$")
    if markText then
        local L = BETTERUI.Log
        if L and L.Info then
            pcall(L.Info, L.CATEGORY.STATE, "mark: " .. markText)
            Out("Marked: " .. markText)
        else
            Out("Logger not loaded yet.")
        end
        return
    end

    args = raw:lower()

    if args == "on" then
        InterfaceLog.SetEnabled(true)
        PersistLogState(true, "")
        InterfaceLog.Write("logging started -- breadcrumbs are tagged [BUI]; grep '[BUI]' for the clean stream. On disk each is engine-wrapped: <ISO-8601 ts> |cff0000Lua Error: [BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <event> <key=value ...> then a 'stack traceback:' block (ignore it for [BUI] lines). sid groups one UI-load session; seq is a monotonic order. Levels TRACE<DEBUG<INFO<WARN<ERROR. The ISO timestamp is authoritative wall-clock. 'Lua Error:' entries WITHOUT [BUI] are real game errors -- keep their traceback.")
        Out("InterfaceLog |c00ff00ENABLED|r -- [BUI] log streaming to Interface.log (no popups). Tip: /builog preset watch for live AI monitoring, or debug|trace for full capture.")
    elseif args == "off" then
        InterfaceLog.Write("InterfaceLog disabled via /builog off")
        InterfaceLog.SetEnabled(false)
        PersistLogState(false, "")
        Out("InterfaceLog disabled; error popups restored.")
    elseif args:match("^preset%s+%a+$") then
        local name = args:match("^preset%s+(%a+)$")
        local L = BETTERUI.Log
        if L and L.ApplyPreset then
            local applied, presetName = L.ApplyPreset(name)
            if applied then
                -- "off" preset disables; named presets ("debug"/"verbose") stay enabled.
                PersistLogState(presetName ~= "off", presetName ~= "off" and tostring(presetName) or "")
                Out("Log preset = |c00ff00" .. tostring(presetName):upper() .. "|r.")
                PrintStatus()
            else
                Out("Unknown preset. Use off|info|watch|debug|trace.")
            end
        else
            Out("Logger not loaded yet.")
        end
    elseif args == "test" then
        local wasEnabled = enabled
        if not wasEnabled then InterfaceLog.SetEnabled(true) end
        InterfaceLog.Write("PoC test breadcrumb A (direct Write)")
        BETTERUI.Debug("PoC test breadcrumb B (via BETTERUI.Debug)")
        if BETTERUI.Log then BETTERUI.Log.Error("SAFE", "PoC test breadcrumb C (via Log.Error)") end
        Out("Wrote test breadcrumbs -- grep Interface.log for [BUI].")
        if not wasEnabled then Out("(Logging was off; left it ON. Use /builog off to stop.)") end
    elseif args == "popups on" then
        InterfaceLog.SetSuppressPopups(false)
        Out("Error popups will now SHOW (file writes pop too).")
    elseif args == "popups off" then
        InterfaceLog.SetSuppressPopups(true)
        Out("Error popups suppressed (errors still log to file).")
    elseif args == "chat on" then
        SetChatSurface(true)
        Out("Chat surfacing ON for INFO/WARN/ERROR (file logging unchanged).")
    elseif args == "chat off" then
        SetChatSurface(false)
        Out("Chat surfacing OFF (file-only).")
    elseif args:match("^level%s+%a+$") then
        local name = args:match("^level%s+(%a+)$")
        local L = BETTERUI.Log
        local lvl = L and L.LevelFromName(name)
        if lvl then L.SetMinLevel(lvl); Out("Min log level set to " .. name:upper() .. ".")
        else Out("Unknown level. Use trace|debug|info|warn|error.") end
    elseif args == "recent" or args:match("^recent%s+%d+$") then
        local L = BETTERUI.Log
        DumpRecords(L and L.GetRecent, tonumber(args:match("(%d+)")) or 20, "recent")
    elseif args == "errors" or args:match("^errors%s+%d+$") then
        local L = BETTERUI.Log
        DumpRecords(L and L.GetRecentErrors, tonumber(args:match("(%d+)")) or 20, "error")
    elseif args == "capture" or args:match("^capture%s+%d+$") then
        StartCapture(tonumber(args:match("(%d+)")))
    elseif args == "mark" then
        Out("Usage: /builog mark <text>  -- annotates the live log with <text>.")
    elseif args == "snapshot" then
        local W = BETTERUI.CIM and BETTERUI.CIM.WatchMode
        if W and W.Snapshot then
            local ok = pcall(W.Snapshot)
            Out(ok and "Emitted a STATE snapshot to the log." or "Snapshot failed.")
        else Out("Watch mode not loaded.") end
    else
        PrintStatus()
        Out("Usage: /builog on|off | preset off|info|watch|debug|trace | chat on|off | popups on|off | level <lvl> | mark <text> | recent [n] | errors [n] | capture [secs] | snapshot | test | status")
    end
end

if type(G("SLASH_COMMANDS")) == "table" then
    SLASH_COMMANDS["/builog"] = HandleCommand

    -- /buihealth: one-shot health summary in chat (preset, session, error count, file-sink
    -- budget/drops, scene-logger + watch state) without tailing the file. pcall-guarded.
    SLASH_COMMANDS["/buihealth"] = function()
        local out = G("d")
        if type(out) ~= "function" then return end
        -- Fully crash-proof: any partially-loaded/faulty getter must not raise from a slash
        -- command. Per-field nil guards PLUS a top-level pcall belt; `#` only on a table.
        local ok, err = pcall(function()
            local L = BETTERUI.Log
            out("|c0066ff[BetterUI health]|r")
            if L then
                out(string.format("  preset=%s active=%s sid=%s schema=%s",
                    tostring(L.GetPreset and L.GetPreset()),
                    tostring(L.IsActive and L.IsActive()),
                    tostring(L.GetSessionId and L.GetSessionId()),
                    tostring(L.SCHEMA)))
                local errsT = L.GetRecentErrors and L.GetRecentErrors()
                local retained = (type(errsT) == "table") and #errsT or "?"
                out(string.format("  errors=%s (retained=%s) -- /builog errors to list",
                    tostring(L.GetErrorCount and L.GetErrorCount()), tostring(retained)))
            else
                out("  logger not loaded")
            end
            local s = InterfaceLog.GetStats()
            out(string.format("  file: scheduled=%s dropped=%s budget=%s/frame %s/sec",
                tostring(s.scheduled), tostring(s.dropped),
                s.maxPerFrame > 0 and tostring(s.maxPerFrame) or "inf",
                s.maxPerSecond > 0 and tostring(s.maxPerSecond) or "inf"))
            local SL = BETTERUI.CIM and BETTERUI.CIM.SceneLog
            local W = BETTERUI.CIM and BETTERUI.CIM.WatchMode
            out(string.format("  sceneLog=%s watch=%s",
                tostring(SL and SL.IsRegistered and SL.IsRegistered()),
                tostring(W and W.IsActive and W.IsActive())))
        end)
        if not ok then out("  (health check error: " .. tostring(err) .. ")") end
    end
end
