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

  On disk the engine therefore wraps each emitted line as:
    <ISO-8601 ts±tz> |cff0000Lua Error: <our [BUI] line>
  followed by a short "stack traceback:" block. Consumers filter on the [BUI] tag
  (grep '[BUI]') for a clean breadcrumb stream and ignore those tracebacks; untagged
  "Lua Error:" entries are real game errors whose traceback matters.

Usage (slash command): /builog on | off | test | popups on|off | status
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local InterfaceLog = {}
BETTERUI.CIM.InterfaceLog = InterfaceLog

local TAG = "[BUI]"

local enabled = false          -- session breadcrumb logging on/off
local suppressPopups = true    -- hide the error frame for our log-errors
local savedSuppressState = nil -- prior ZO_ERROR_FRAME.suppressErrorDialog, for restore

-- Engine globals are absent in the unit-test harness; resolve them defensively.
local function G(name)
    return rawget(_G, name)
end

local function Timestamp()
    local clock = G("GetGameTimeMilliseconds")
    return type(clock) == "function" and clock() or 0
end

-- Collapse newlines/tabs so each breadcrumb stays a single greppable record.
local function Flatten(text)
    text = tostring(text)
    text = text:gsub("[\r\n]+", " | ")
    text = text:gsub("\t", " ")
    return text
end

local function FormatLine(message)
    return string.format("%s %d %s", TAG, Timestamp(), Flatten(message))
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
    deferer(function() error(line, 0) end, 0)
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
    return RawEmit(tostring(line))
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
        Out(string.format("Logger chat surface (ERROR) = %s", L.GetSink(L.LEVEL.ERROR, "chat") and "on" or "off"))
    end
    Out("Real Lua errors always log to Interface.log; [BUI] lines are BetterUI's own stream.")
end

local function HandleCommand(args)
    args = tostring(args or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()

    if args == "on" then
        InterfaceLog.SetEnabled(true)
        InterfaceLog.Write("logging started -- breadcrumbs are tagged [BUI]; grep '[BUI]' for the clean stream. On disk each is engine-wrapped: <ISO-8601 ts> |cff0000Lua Error: [BUI] <gameMs> <LEVEL> <CATEGORY> | <event> <key=value ...> then a 'stack traceback:' block (ignore it for [BUI] lines). Levels TRACE<DEBUG<INFO<WARN<ERROR. The ISO timestamp is authoritative wall-clock. 'Lua Error:' entries WITHOUT [BUI] are real game errors -- keep their traceback.")
        Out("InterfaceLog |c00ff00ENABLED|r -- [BUI] log streaming to Interface.log (no popups).")
    elseif args == "off" then
        InterfaceLog.Write("InterfaceLog disabled via /builog off")
        InterfaceLog.SetEnabled(false)
        Out("InterfaceLog disabled; error popups restored.")
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
    else
        PrintStatus()
        Out("Usage: /builog on|off|test | chat on|off | popups on|off | level <lvl> | status")
    end
end

if type(G("SLASH_COMMANDS")) == "table" then
    SLASH_COMMANDS["/builog"] = HandleCommand
end
