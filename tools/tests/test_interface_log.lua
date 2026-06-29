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

function GetGameTimeMilliseconds()
    return 4242
end

ZO_ERROR_FRAME = { suppressErrorDialog = false }
SLASH_COMMANDS = {}
local chatOutput = {}

function d(message)
    chatOutput[#chatOutput + 1] = tostring(message)
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

local function check(cond, message)
    if cond then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
    end
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

-- Enabling turns on global popup suppression.
IL.SetEnabled(true)
check(IL.IsEnabled() == true, "Enabled after SetEnabled(true)")
check(ZO_ERROR_FRAME.suppressErrorDialog == true, "Popup suppression applied on enable")

-- Write schedules a deferred error carrying a formatted, flattened line.
local scheduled = IL.Write("hello\nworld\ttab")
check(scheduled == true, "Write returns true while enabled")
check(type(capturedDeferred) == "function", "Write scheduled a deferred callback")

local ok, err = pcall(capturedDeferred)
err = tostring(err)
check(ok == false, "Deferred callback raises an error (engine logs it to file)")
check(err:find("[BUI]", 1, true) ~= nil, "Logged line carries the [BUI] tag")
check(err:find("4242", 1, true) ~= nil, "Logged line carries the timestamp")
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
local firstPendingCallback = capturedDeferreds[callbackStart + 1] and capturedDeferreds[callbackStart + 1].callback
IL.WriteRaw("pending-2")
afterStats = IL.GetStats()
check(afterStats.scheduled - beforeStats.scheduled == 1, "maxPending schedules only available pending capacity")
check(afterStats.dropped - beforeStats.dropped == 1, "maxPending drops overflow while a breadcrumb is pending")
check(afterStats.pending == 1, "maxPending exposes the pending count in diagnostics")
if firstPendingCallback then pcall(firstPendingCallback) end
check(IL.GetStats().pending == 0, "pending count drains when the deferred breadcrumb raises")

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
BETTERUI.Log = {
    LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
    ApplyPreset = function(name) return true, name end,
    GetPreset = function() return "debug" end,
    GetMinLevel = function() return 3 end,
    GetPayloadCapture = function() return false end,
    GetSink = function() return false end,
    SetSink = function() end,
    SetMinLevel = function() end,
    LevelFromName = function() return nil end,
    InvalidateActive = function() end,
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

builog("preset debug")
check(persisted["CIM:interfaceLogEnabled"] == true, "/builog preset debug persists enabled=true")
check(persisted["CIM:interfaceLogPreset"] == "debug", "/builog preset debug persists the preset name")

builog("preset off")
check(persisted["CIM:interfaceLogEnabled"] == false, "/builog preset off persists enabled=false")

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
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
