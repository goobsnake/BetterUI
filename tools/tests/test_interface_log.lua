--[[
File: tools/tests/test_interface_log.lua
Purpose: Unit tests for the InterfaceLog diagnostics module (PoC).
         Loads production code via dofile so tests track the live module API.

Usage:
  lua tools/tests/test_interface_log.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }
function BETTERUI.Debug(msg) end

local capturedDeferred = nil
local capturedDeferreds = {}
function zo_callLater(callback, ms)
    capturedDeferred = callback
    capturedDeferreds[#capturedDeferreds + 1] = { callback = callback, ms = ms }
    return "stub-call-name"
end

local fakeTime = 4242
function GetGameTimeMilliseconds()
    return fakeTime
end

ZO_ERROR_FRAME = { suppressErrorDialog = false }
SLASH_COMMANDS = {}
local chatOutput = {}
EVENT_PLAYER_DEACTIVATED = 9001
local registeredEvents = {}
EVENT_MANAGER = {}
function EVENT_MANAGER:RegisterForEvent(name, eventCode, callback)
    registeredEvents[name] = { eventCode = eventCode, callback = callback }
    return true
end

function d(message)
    chatOutput[#chatOutput + 1] = tostring(message)
end

local exitCalls = {}
function ReloadUI(scope)
    exitCalls[#exitCalls + 1] = { name = "ReloadUI", scope = scope }
    return "reload:" .. tostring(scope)
end
function LogOut()
    exitCalls[#exitCalls + 1] = { name = "LogOut" }
    return "logout"
end
function Quit()
    exitCalls[#exitCalls + 1] = { name = "Quit" }
    return "quit"
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Diagnostics/InterfaceLog.lua")
local IL = BETTERUI.CIM.InterfaceLog

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0
local failed_messages = {}

local function check(cond, message)
    if cond then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        failed_messages[#failed_messages + 1] = message
        print("  [X] " .. message)
    end
end

local function runDeferredsSince(startIndex)
    local errors = {}
    for i = (startIndex or 0) + 1, #capturedDeferreds do
        local deferred = capturedDeferreds[i]
        local callback = deferred and deferred.callback
        if type(callback) == "function" then
            local ok, err = pcall(callback)
            if not ok then errors[#errors + 1] = tostring(err) end
        end
    end
    return table.concat(errors, "\n")
end

local function isValidUtf8(text)
    local i = 1
    while i <= #text do
        local b = text:byte(i)
        if b < 0x80 then
            i = i + 1
        elseif b >= 0xC2 and b <= 0xDF then
            local b2 = text:byte(i + 1)
            if not (b2 and b2 >= 0x80 and b2 <= 0xBF) then return false end
            i = i + 2
        elseif b >= 0xE0 and b <= 0xEF then
            local b2, b3 = text:byte(i + 1), text:byte(i + 2)
            if not (b2 and b2 >= 0x80 and b2 <= 0xBF and b3 and b3 >= 0x80 and b3 <= 0xBF) then return false end
            i = i + 3
        elseif b >= 0xF0 and b <= 0xF4 then
            local b2, b3, b4 = text:byte(i + 1), text:byte(i + 2), text:byte(i + 3)
            if not (b2 and b2 >= 0x80 and b2 <= 0xBF and b3 and b3 >= 0x80 and b3 <= 0xBF and b4 and b4 >= 0x80 and b4 <= 0xBF) then return false end
            i = i + 4
        else
            return false
        end
    end
    return true
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== InterfaceLog Tests ===\n")

-- Disabled by default: nothing is written or scheduled.
check(IL.IsEnabled() == false, "Disabled by default")
check(IL.Write("nope") == false, "Write no-ops while disabled")
check(capturedDeferred == nil, "No error scheduled while disabled")

-- Slash command registers at load.
check(type(SLASH_COMMANDS["/builog"]) == "function", "/builog command registered")
check(registeredEvents.BetterUI_InterfaceLogReloadQuiesce
    and registeredEvents.BetterUI_InterfaceLogReloadQuiesce.eventCode == EVENT_PLAYER_DEACTIVATED,
    "reload quiesce event registered")

-- Enabling turns on global popup suppression.
IL.SetEnabled(true)
check(IL.IsEnabled() == true, "Enabled after SetEnabled(true)")
check(ZO_ERROR_FRAME.suppressErrorDialog == true, "Popup suppression applied on enable")
IL.SetSuppressPopups(false)
check(IL.GetSuppressPopups() == true, "legacy popup suppression setter remains file-only")
check(ZO_ERROR_FRAME.suppressErrorDialog == true, "generated builog breadcrumbs stay popup-suppressed")

-- Write schedules a deferred error carrying a formatted, flattened line.
local scheduled = IL.Write("hello\nworld\ttab")
check(scheduled == true, "Write returns true while enabled")
check(type(capturedDeferred) == "function", "Write scheduled a deferred callback")

local ok, err = pcall(capturedDeferred)
err = tostring(err)
check(ok == false, "Deferred callback raises an error (engine logs it to file)")
check(err:find("[BUI]", 1, true) ~= nil, "Logged line carries the [BUI] tag")
check(err:find("4242", 1, true) ~= nil, "Logged line carries the timestamp")
check(err:find("sid=00000000", 1, true) ~= nil, "Fallback session id is parser-safe hex")
-- Newlines collapse to a SPACE, never the ` | ` field separator (which would split one
-- record into bogus fields for a host parser); tabs collapse to a space too.
check(err:find("hello world tab", 1, true) ~= nil, "Newlines/tabs flattened to one record (space, not the | separator)")
check(err:find("\n", 1, true) == nil, "Logged line contains no raw newline")

capturedDeferred = nil
IL.Write("pipe | value")
local okPipe, errPipe = pcall(capturedDeferred)
errPipe = tostring(errPipe)
check(okPipe == false, "Deferred pipe test raises an error")
check(errPipe:find("pipe / value", 1, true) ~= nil, "Payload pipe separators are flattened for parser-stable records")

-- Disabling restores the prior suppression state.
IL.SetEnabled(false)
check(IL.IsEnabled() == false, "Disabled after SetEnabled(false)")
check(ZO_ERROR_FRAME.suppressErrorDialog == false, "Prior suppression state restored on disable")

-- ============================================================================
-- BUDGET (file-sink backpressure / rate limit)
-- ============================================================================

-- Default budget is unlimited.
IL.SetBudget({ maxPerFrame = 0, maxPerSecond = 0, maxPending = 0 })
check(IL.GetStats().maxPerFrame == 0, "default file-sink budget is unlimited")

-- Per-frame cap: GetGameTimeMilliseconds is constant in this harness, so every write
-- shares one frame window and the third past a cap of 2 is dropped + counted.
IL.SetEnabled(true)
IL.SetBudget({ maxPerFrame = 2, maxPerSecond = 0, maxPending = 0 })
local budgetCallbackStart = #capturedDeferreds
local beforeStats = IL.GetStats()
IL.WriteRaw("budget-1")
IL.WriteRaw("budget-2")
IL.WriteRaw("budget-3")
local afterStats = IL.GetStats()
check(afterStats.scheduled - beforeStats.scheduled == 2, "per-frame budget schedules up to the cap")
check(afterStats.dropped - beforeStats.dropped == 1, "per-frame budget drops the overflow record")
for i = budgetCallbackStart + 1, #capturedDeferreds do
    pcall(capturedDeferreds[i].callback)
end
check(IL.GetStats().pending == 0, "pending count drains after scheduled budget callbacks run")

-- maxPending cap: only one in-flight deferred breadcrumb is allowed until its callback runs.
IL.SetBudget({ maxPerFrame = 0, maxPerSecond = 0, maxPending = 1 })
capturedDeferred = nil
local callbackStart = #capturedDeferreds
beforeStats = IL.GetStats()
IL.WriteRaw("pending-1")
IL.WriteRaw("pending-2")
afterStats = IL.GetStats()
check(afterStats.scheduled - beforeStats.scheduled == 1, "maxPending schedules only available pending capacity")
check(afterStats.dropped - beforeStats.dropped == 1, "maxPending drops overflow while a breadcrumb is pending")
check(afterStats.pending == 1, "maxPending exposes the pending count in diagnostics")
runDeferredsSince(callbackStart)
check(IL.GetStats().pending == 0, "pending count drains when the deferred breadcrumb raises")

-- Priority detection is anchored to the header. A payload containing " WARN " must
-- not promote an otherwise normal LIST record past the active frame budget.
IL.SetBudget({ maxPerFrame = 1, maxPerSecond = 0, maxPending = 100 })
local headerOnlyStart = #capturedDeferreds
beforeStats = IL.GetStats()
for i = 1, 4 do
    IL.WriteRaw(string.format("[BUI] 4242 sid=test seq=%d INFO LIST | payload contains WARN marker", i))
end
afterStats = IL.GetStats()
check(afterStats.scheduled - beforeStats.scheduled == 1,
    "payload WARN text does not promote a non-priority header past the frame cap")
check(afterStats.dropped - beforeStats.dropped == 3,
    "non-priority payload WARN overflow uses the normal rate limit")
runDeferredsSince(headerOnlyStart)

-- Priority lines can exceed normal frame/second caps, but only up to the bounded 4x
-- priority allowance and with a distinct drop reason.
IL.SetBudget({ maxPerFrame = 1, maxPerSecond = 0, maxPending = 100 })
local priorityCapStart = #capturedDeferreds
beforeStats = IL.GetStats()
for i = 1, 5 do
    IL.WriteRaw(string.format("[BUI] 4242 sid=test seq=%d WARN LOG | priority frame cap", i))
end
afterStats = IL.GetStats()
check(afterStats.scheduled - beforeStats.scheduled == 4,
    "priority frame budget allows up to 4x the active frame cap")
check(afterStats.dropped - beforeStats.dropped == 1,
    "priority frame budget drops overflow beyond the 4x cap")
local priorityCapErrors = runDeferredsSince(priorityCapStart)
check(priorityCapErrors:find("reason=priority_rate_limit", 1, true) ~= nil,
    "priority frame overflow emits the priority_rate_limit summary reason; got " .. priorityCapErrors)

-- Priority lines still respect maxPending.
IL.SetBudget({ maxPerFrame = 0, maxPerSecond = 0, maxPending = 1 })
local priorityPendingStart = #capturedDeferreds
beforeStats = IL.GetStats()
IL.WriteRaw("[BUI] 4242 sid=test seq=1 ERROR LOG | priority pending cap 1")
IL.WriteRaw("[BUI] 4242 sid=test seq=2 ERROR LOG | priority pending cap 2")
afterStats = IL.GetStats()
check(afterStats.scheduled - beforeStats.scheduled == 1,
    "priority maxPending schedules only available pending capacity")
check(afterStats.dropped - beforeStats.dropped == 1,
    "priority maxPending drops overflow while a breadcrumb is pending")
local priorityPendingErrors = runDeferredsSince(priorityPendingStart)
check(priorityPendingErrors:find("reason=priority_rate_limit", 1, true) ~= nil,
    "priority maxPending overflow emits the priority_rate_limit summary reason; got " .. priorityPendingErrors)

-- Pregame zero-clock transport should not consume the per-second window.
IL.SetBudget({ maxPerFrame = 0, maxPerSecond = 1, maxPending = 0 })
local originalFakeTime = fakeTime
fakeTime = 0
local zeroClockStart = #capturedDeferreds
beforeStats = IL.GetStats()
IL.WriteRaw("[BUI] 0 sid=test seq=1 INFO LIST | zero clock 1")
IL.WriteRaw("[BUI] 0 sid=test seq=2 INFO LIST | zero clock 2")
IL.WriteRaw("[BUI] 0 sid=test seq=3 INFO LIST | zero clock 3")
fakeTime = 100
IL.WriteRaw("[BUI] 100 sid=test seq=4 INFO LIST | first real second")
IL.WriteRaw("[BUI] 100 sid=test seq=5 INFO LIST | first real second overflow")
afterStats = IL.GetStats()
check(afterStats.scheduled - beforeStats.scheduled == 4,
    "Timestamp zero skips per-second accounting until the first real clock tick")
check(afterStats.dropped - beforeStats.dropped == 1,
    "first real second still enforces the per-second cap")
runDeferredsSince(zeroClockStart)
fakeTime = originalFakeTime

-- RawEmit is the single line-length choke point.
IL.SetBudget({ maxPerFrame = 0, maxPerSecond = 0, maxPending = 0 })
local longLine = "[BUI] 4242 sid=test seq=99 INFO LOG | " .. string.rep("x", 3000)
capturedDeferred = nil
IL.WriteRaw(longLine)
local okLong, longErr = pcall(capturedDeferred)
longErr = tostring(longErr)
check(okLong == false, "long InterfaceLog line still raises through the file sink")
check(#longErr <= 2048, "long InterfaceLog line is capped at 2048 characters")
check(longErr:sub(-#"truncated=1") == "truncated=1", "truncated InterfaceLog line carries the truncated marker")

local truncationMarker = " truncated=1"
local utf8PrefixLength = 2048 - #truncationMarker
local twoByteChar = string.char(0xC3, 0xA9)
local utf8BoundaryLine = string.rep("x", utf8PrefixLength - 1) .. twoByteChar .. string.rep("y", 32)
capturedDeferred = nil
IL.WriteRaw(utf8BoundaryLine)
local okUtf8, utf8Err = pcall(capturedDeferred)
utf8Err = tostring(utf8Err)
check(okUtf8 == false, "UTF-8 boundary line still raises through the file sink")
check(#utf8Err <= 2048, "UTF-8 boundary line remains capped at 2048 characters")
check(utf8Err:sub(-#"truncated=1") == "truncated=1", "UTF-8 boundary truncation carries the marker")
check(isValidUtf8(utf8Err), "UTF-8 boundary truncation preserves a valid byte sequence")

-- Restore unlimited + disabled so nothing leaks past these tests.
IL.SetBudget({ maxPerFrame = 0, maxPerSecond = 0, maxPending = 0 })
IL.SetEnabled(false)

-- ============================================================================
-- PERSISTENCE: /builog intent is written to CIM settings so it survives /reloadui
-- ============================================================================

-- Minimal SavedVars + settings-accessor stubs so PersistLogState has a sink.
local persisted = {}
function BETTERUI.SetSetting(moduleName, key, value) persisted[moduleName .. ":" .. key] = value; return true end
function BETTERUI.GetSetting(moduleName, key, default)
    local v = persisted[moduleName .. ":" .. key]
    if v == nil then return default end
    return v
end
BETTERUI.Settings = { Modules = {} }

-- Minimal Log facade so the /builog preset branch (ApplyPreset + PrintStatus) resolves.
local sinkState = {}
local logPreset = "debug"
local logMinLevel = 3
local logPayloadCapture = false
local logPrivacyMode = false
local function applyTestPreset(name)
    name = tostring(name or ""):lower()
    if name == "off" then
        logPreset = "off"
        logMinLevel = 3
        logPayloadCapture = false
    elseif name == "info" then
        logPreset = "info"
        logMinLevel = 3
        logPayloadCapture = false
    elseif name == "watch" or name == "debug" then
        logPreset = name
        logMinLevel = 2
        logPayloadCapture = true
    elseif name == "trace" or name == "inspect" then
        logPreset = name
        logMinLevel = 1
        logPayloadCapture = true
    else
        return false, logPreset
    end
    return true, logPreset
end
BETTERUI.Log = {
    LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
    CATEGORY = { STATE = "STATE" },
    ApplyPreset = applyTestPreset,
    GetPreset = function() return logPreset end,
    GetMinLevel = function() return logMinLevel end,
    GetPayloadCapture = function() return logPayloadCapture end,
    GetSink = function(level, sinkName) return sinkState[tostring(level) .. ":" .. tostring(sinkName)] == true end,
    SetSink = function(level, sinkName, on)
        sinkState[tostring(level) .. ":" .. tostring(sinkName)] = on and true or false
    end,
    SetMinLevel = function(level, preservePreset)
        if type(level) == "number" then
            logMinLevel = level
            if not preservePreset then logPreset = "custom" end
        end
    end,
    SetPayloadCapture = function(on, preservePreset)
        logPayloadCapture = on and true or false
        if not preservePreset then logPreset = "custom" end
    end,
    SetPrivacyMode = function(on) logPrivacyMode = on and true or false end,
    GetPrivacyMode = function() return logPrivacyMode end,
    LevelFromName = function(name)
        local levels = { trace = 1, debug = 2, info = 3, warn = 4, error = 5 }
        return levels[tostring(name or ""):lower()]
    end,
    InvalidateActive = function() end,
    Info = function() end,
}
local screenshotRequests = {}
local screenshotAutoMode = "off"
BETTERUI.CIM.Screenshot = {
    RequestManual = function(label)
        screenshotRequests[#screenshotRequests + 1] = label
        return true, "requested"
    end,
    SetAutoMode = function(mode)
        if mode == "off" or mode == "error" or mode == "warn" then
            screenshotAutoMode = mode
            return true, mode
        end
        return false, screenshotAutoMode
    end,
    GetAutoMode = function() return screenshotAutoMode end,
    GetStatus = function()
        return { autoMode = screenshotAutoMode, shots = 2, suppressed = 1, pending = 0, sessionLimit = 40 }
    end,
}

local builog = SLASH_COMMANDS["/builog"]
check(type(builog) == "function", "/builog slash command is registered")

sinkState = {}
IL.SetChatSurface(true)
check(sinkState["3:chat"] == false and sinkState["4:chat"] == false and sinkState["5:chat"] == false,
    "SetChatSurface(true) is forced file-only")
check(IL.GetChatSurface() == false, "GetChatSurface always reports disabled")
check(persisted["CIM:interfaceLogChat"] == false, "legacy chat surface preference is cleared to false")

chatOutput = {}
builog("chat on")
check(IL.GetChatSurface() == false and table.concat(chatOutput, "\n"):find("file-only", 1, true) ~= nil,
    "/builog chat on cannot enable chat surfacing")

builog("on")
check(persisted["CIM:interfaceLogEnabled"] == true, "/builog on persists interfaceLogEnabled=true")
check(persisted["CIM:interfaceLogPreset"] == "", "/builog on persists empty preset (plain on)")

IL.SetBudget({ maxPerFrame = 2, maxPerSecond = 4, maxPending = 6 })
chatOutput = {}
builog("status")
local statusText = table.concat(chatOutput, "\n")
check(statusText:find("Sink budget: frame=2 sec=4 pending=", 1, true) ~= nil
    and statusText:find("/6", 1, true) ~= nil,
    "/builog status reports frame/sec and pending/maxPending budget")
check(statusText:find("privacy=off", 1, true) ~= nil,
    "/builog status reports privacy=off by default")
check(statusText:find("Usage:", 1, true) == nil,
    "/builog status prints status without falling through to generic usage")

chatOutput = {}
builog("privacy on")
statusText = table.concat(chatOutput, "\n")
check(logPrivacyMode == true and persisted["CIM:interfaceLogPrivacy"] == true,
    "/builog privacy on enables and persists privacy mode")
check(statusText:find("privacy=on", 1, true) ~= nil,
    "/builog privacy on status reports privacy=on")
chatOutput = {}
builog("privacy off")
statusText = table.concat(chatOutput, "\n")
check(logPrivacyMode == false and persisted["CIM:interfaceLogPrivacy"] == false,
    "/builog privacy off disables and persists privacy mode")
check(statusText:find("privacy=off", 1, true) ~= nil,
    "/builog privacy off status reports privacy=off")

local health = SLASH_COMMANDS["/buihealth"]
chatOutput = {}
check(type(health) == "function", "/buihealth slash command is registered")
check(pcall(health), "/buihealth command is safe")
local healthText = table.concat(chatOutput, "\n")
check(healthText:find("file: scheduled=", 1, true) ~= nil
    and healthText:find("pending=", 1, true) ~= nil
    and healthText:find("/6", 1, true) ~= nil
    and healthText:find("dropped=", 1, true) ~= nil
    and healthText:find("budget=2/frame 4/sec", 1, true) ~= nil,
    "/buihealth reports scheduled, pending/maxPending, dropped, and budget")

chatOutput = {}
check(pcall(builog, "test") and table.concat(chatOutput, "\n"):find("Wrote diagnostic breadcrumbs", 1, true) ~= nil,
    "/builog test aliases the diagnostic check command")

builog("preset debug")
check(persisted["CIM:interfaceLogEnabled"] == true, "/builog preset debug persists enabled=true")
check(persisted["CIM:interfaceLogPreset"] == "debug", "/builog preset debug persists the preset name")

builog("preset off")
check(persisted["CIM:interfaceLogEnabled"] == false, "/builog preset off persists enabled=false")

IL.SetEnabled(true)
logPreset = "custom"
logMinLevel = 4
logPayloadCapture = false
local captureStart = #capturedDeferreds
builog("capture 1")
check(logPreset == "trace" and logMinLevel == 1 and logPayloadCapture == true,
    "/builog capture temporarily switches to trace payload capture")
local captureRevert = capturedDeferreds[#capturedDeferreds] and capturedDeferreds[#capturedDeferreds].callback
check(#capturedDeferreds > captureStart and type(captureRevert) == "function",
    "/builog capture schedules an auto-revert callback")
if type(captureRevert) == "function" then pcall(captureRevert) end
check(logPreset == "custom" and logMinLevel == 4 and logPayloadCapture == false and IL.IsEnabled() == true,
    string.format("/builog capture restores custom preset knobs and enabled state (preset=%s level=%s payload=%s enabled=%s)",
        tostring(logPreset), tostring(logMinLevel), tostring(logPayloadCapture), tostring(IL.IsEnabled())))

IL.SetEnabled(true)
logPreset = "debug"
logMinLevel = 4
logPayloadCapture = false
local namedCaptureStart = #capturedDeferreds
builog("capture 1")
check(logPreset == "trace" and logMinLevel == 1 and logPayloadCapture == true,
    "/builog capture switches a named-preset snapshot to trace payload capture")
local namedCaptureRevert = capturedDeferreds[#capturedDeferreds] and capturedDeferreds[#capturedDeferreds].callback
check(#capturedDeferreds > namedCaptureStart and type(namedCaptureRevert) == "function",
    "/builog capture schedules a named-preset auto-revert callback")
if type(namedCaptureRevert) == "function" then pcall(namedCaptureRevert) end
check(logPreset == "debug" and logMinLevel == 4 and logPayloadCapture == false and IL.IsEnabled() == true,
    string.format("/builog capture restores captured knobs even when the snapshot preset is named (preset=%s level=%s payload=%s enabled=%s)",
        tostring(logPreset), tostring(logMinLevel), tostring(logPayloadCapture), tostring(IL.IsEnabled())))

builog("on")
builog("off")
check(persisted["CIM:interfaceLogEnabled"] == false, "/builog off persists enabled=false")

-- Screenshot command surface stays routed through the screenshot service. Auto mode is
-- persisted separately from the main /builog on/off state and restored after reload.
screenshotRequests = {}
builog("screenshot")
check(#screenshotRequests == 1 and screenshotRequests[1] == "", "/builog screenshot requests a manual capture")
builog("screenshot manual Label")
check(#screenshotRequests == 2 and screenshotRequests[2] == "manual Label",
    "/builog screenshot <label> preserves label text")
builog("screenshot auto warn")
check(screenshotAutoMode == "warn", "/builog screenshot auto warn enables WARN auto capture")
builog("screenshot auto error")
check(screenshotAutoMode == "error", "/builog screenshot auto error enables ERROR auto capture")
builog("screenshot auto off")
check(screenshotAutoMode == "off", "/builog screenshot auto off disables auto capture")
check(persisted["CIM:interfaceLogEnabled"] == false,
    "/builog screenshot auto changes do not persist interfaceLogEnabled")
check(persisted["CIM:interfaceLogScreenshotAutoMode"] == "off",
    "/builog screenshot auto changes persist the screenshot auto mode separately")
check(pcall(builog, "screenshot status"), "/builog screenshot status is safe")

-- Pre-SavedVars guard: with no Settings table the write is a silent no-op, not a crash.
BETTERUI.Settings = nil
check(pcall(builog, "on"), "/builog on does not error when Settings is absent (pre-SavedVars guard)")
BETTERUI.Settings = { Modules = {} }

IL.SetEnabled(false)

-- ============================================================================
-- POPUP SUPPRESSION: raising a breadcrumb re-asserts ZO_ERROR_FRAME suppression
-- ============================================================================

-- Even if something clears suppression mid-session (the error frame's Initialize, or
-- a restore that ran before the frame existed), raising a breadcrumb must re-apply it
-- so our throwaway errors never reach the UI error viewer (gamepad or keyboard).
ZO_ERROR_FRAME.suppressErrorDialog = false
IL.SetEnabled(true)
ZO_ERROR_FRAME.suppressErrorDialog = false  -- simulate a mid-session reset
capturedDeferred = nil
IL.WriteRaw("reassert-test")
check(type(capturedDeferred) == "function", "WriteRaw scheduled a deferred emit")
pcall(capturedDeferred)  -- runs RaiseSuppressed -> error(); pcall swallows the throwaway
check(ZO_ERROR_FRAME.suppressErrorDialog == true, "raising a breadcrumb re-asserts popup suppression")
IL.SetEnabled(false)

-- ============================================================================
-- POPUP SUPPRESSION: a breadcrumb is DROPPED (not raised) while ZO_ERROR_FRAME is absent
-- ============================================================================

-- Mid-/reloadui the error frame is torn down and recreated. In that window we cannot set
-- suppressErrorDialog, so raising our throwaway error would be UNSUPPRESSED -- the engine
-- queues it and pops the error viewer once the frame returns (the first-/reloadui popup
-- bug). The sink must therefore drop the breadcrumb rather than raise it.
local savedFrame = ZO_ERROR_FRAME
ZO_ERROR_FRAME = nil
check(pcall(IL.SetEnabled, true), "SetEnabled does not error when ZO_ERROR_FRAME is absent")
local suppressedBefore = IL.GetStats().suppressed
capturedDeferred = nil
check(pcall(IL.WriteRaw, "frame-absent-test"), "WriteRaw does not error when ZO_ERROR_FRAME is absent")
check(type(capturedDeferred) == "function", "WriteRaw scheduled a deferred emit (frame absent)")
-- RaiseSuppressed must take the DROP path: pcall returns true (no error raised).
check(pcall(capturedDeferred) == true, "breadcrumb is dropped (not raised) while the error frame is absent")
check(IL.GetStats().suppressed == suppressedBefore + 1, "suppression-guard drop is counted")
ZO_ERROR_FRAME = savedFrame
IL.SetEnabled(false)

-- ...and once the frame is back, the same path RAISES normally (error reaches Interface.log).
ZO_ERROR_FRAME.suppressErrorDialog = false
IL.SetEnabled(true)
capturedDeferred = nil
IL.WriteRaw("frame-present-test")
check(pcall(capturedDeferred) == false, "breadcrumb is raised once the error frame exists again")
check(ZO_ERROR_FRAME.suppressErrorDialog == true, "suppression re-asserted before raising (frame present)")
IL.SetEnabled(false)

-- ============================================================================
-- RELOAD QUIESCE: BetterUI breadcrumbs are not raised during player deactivation
-- ============================================================================

ZO_ERROR_FRAME.suppressErrorDialog = false
IL.SetEnabled(true)
capturedDeferred = nil
IL.WriteRaw("[BUI] 4242 sid=test seq=exit DEBUG STATE | queued before ReloadUI")
local preReloadUiCallback = capturedDeferred
check(type(preReloadUiCallback) == "function", "pre-ReloadUI breadcrumb scheduled")
check(ReloadUI("ingame") == "reload:ingame", "ReloadUI hook preserves original return value")
check(exitCalls[#exitCalls] and exitCalls[#exitCalls].name == "ReloadUI", "ReloadUI hook calls the original function")
check(IL.IsQuiescing() == true, "ReloadUI hook enters InterfaceLog quiesce before teardown")
check(pcall(preReloadUiCallback) == true, "pre-ReloadUI deferred breadcrumb is canceled by generation guard")
fakeTime = fakeTime + 6000
check(IL.IsQuiescing() == false, "ReloadUI hook quiesce expires")

capturedDeferred = nil
IL.WriteRaw("[BUI] 4242 sid=test seq=0 DEBUG STATE | queued before reload scene")
local preUnsafeSceneCallback = capturedDeferred
check(type(preUnsafeSceneCallback) == "function", "pre-scene breadcrumb scheduled before reload scene")
local suppressedBeforeUnsafeScene = IL.GetStats().suppressed
check(IL.WriteRaw('[BUI] 4242 sid=test seq=1 DEBUG SCENE | scene hudui hiding (from shown) scene="hudui" to="hiding"') == false,
    "hudui hiding scene breadcrumb is dropped before it can popup during reload")
check(IL.IsQuiescing() == true, "hudui hiding scene breadcrumb enters reload quiesce before player deactivation")
check(pcall(preUnsafeSceneCallback) == true, "pre-scene deferred breadcrumb is canceled by reload-scene generation guard")
check(capturedDeferred == preUnsafeSceneCallback, "hudui hiding scene breadcrumb does not schedule a new throwaway error")
check(IL.GetStats().suppressed == suppressedBeforeUnsafeScene + 1, "unsafe reload-scene drop is counted")
fakeTime = fakeTime + 6000
check(IL.IsQuiescing() == false, "reload-scene quiesce expires before later logging resumes")

capturedDeferred = nil
IL.WriteRaw("[BUI] 4242 sid=test seq=2 DEBUG STATE | pre reload queued breadcrumb")
local preReloadCallback = capturedDeferred
local reloadHandler = registeredEvents.BetterUI_InterfaceLogReloadQuiesce.callback
check(type(preReloadCallback) == "function", "pre-reload breadcrumb scheduled")
check(type(reloadHandler) == "function", "reload quiesce callback is available")
reloadHandler()
check(IL.IsQuiescing() == true, "player deactivation enters InterfaceLog quiesce")
check(pcall(preReloadCallback) == true, "pre-quiesce deferred breadcrumb is canceled by generation guard")

local suppressedBeforeQuiesce = IL.GetStats().suppressed
capturedDeferred = nil
check(IL.WriteRaw("[BUI] 4242 sid=test seq=3 DEBUG STATE | during reload quiesce") == false,
    "quiesce blocks new BetterUI breadcrumbs")
check(capturedDeferred == nil, "quiesce does not schedule a throwaway error")
check(IL.GetStats().suppressed == suppressedBeforeQuiesce + 1, "quiesced breadcrumb drop is counted")
fakeTime = fakeTime + 6000
check(IL.IsQuiescing() == false, "quiesce expires after the reload guard window")
capturedDeferred = nil
check(IL.WriteRaw("post-quiesce-test") == true, "file breadcrumb scheduling resumes after quiesce")
if capturedDeferred then pcall(capturedDeferred) end
IL.SetEnabled(false)

-- A callback captured before /builog off must stay stale even if logging is turned back on
-- before the deferred callback fires.
ZO_ERROR_FRAME.suppressErrorDialog = false
IL.SetEnabled(true)
capturedDeferred = nil
IL.WriteRaw("stale-generation-test")
local staleGenerationCallback = capturedDeferred
IL.SetEnabled(false)
IL.SetEnabled(true)
check(pcall(staleGenerationCallback) == true, "stale deferred breadcrumb is dropped across off/on generation changes")
IL.SetEnabled(false)

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
if tests_failed > 0 then
    print("Failed assertions:")
    for i = 1, #failed_messages do
        print("  - " .. failed_messages[i])
    end
end

if tests_failed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
