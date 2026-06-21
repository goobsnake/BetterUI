--[[
File: tools/tests/test_log.lua
Purpose: Unit tests for the unified BETTERUI.Log facade.
         Loads production code via dofile so tests track the live module API.

Usage:
  lua tools/tests/test_log.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

local fileLines = {}
local chatLines = {}
local ilEnabled = true

BETTERUI = { CIM = {} }
BETTERUI.CIM.InterfaceLog = {
    IsEnabled = function() return ilEnabled end,
    WriteRaw = function(line) fileLines[#fileLines + 1] = line; return true end,
    -- Presets drive InterfaceLog enable + budget; stub both so ApplyPreset is exercised.
    -- SetEnabled invalidates Log's memoized active-state, mirroring the real module.
    SetEnabled = function(value)
        ilEnabled = value and true or false
        if BETTERUI.Log and BETTERUI.Log.InvalidateActive then BETTERUI.Log.InvalidateActive() end
    end,
    SetBudget = function() end,
}

function d(msg) chatLines[#chatLines + 1] = msg end
function GetGameTimeMilliseconds() return 100 end

dofile("Modules/CIM/Core/Diagnostics/Log.lua")
local Log = BETTERUI.Log

-- Flip the (stubbed) InterfaceLog enable state AND invalidate the logger's memoized
-- active-state, the way the real InterfaceLog.SetEnabled does. Tests that toggle
-- logging directly use this so the IsActive immediacy contract still holds.
local function setLogging(on)
    ilEnabled = on and true or false
    Log.InvalidateActive()
end

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

print("\n=== Log Tests ===\n")

-- Default routing: DEBUG -> file only, formatted with level+category+ts.
fileLines = {}; chatLines = {}
Log.Debug(Log.CATEGORY.GENERAL, "hi")
check(#fileLines == 1, "Debug writes one file line")
check(fileLines[1] and fileLines[1]:find("[BUI] 100 sid=", 1, true) == 1
    and fileLines[1]:find("DEBUG GENERAL | hi", 1, true) ~= nil, "File line carries schema/level/category/ts/message")
check(#chatLines == 0, "Debug does not hit chat by default")

-- Summarize: compact shapes, never full dumps.
check(Log.Summarize({ 10, 20, 30 }) == "[3]", "Summarize array -> [n]")
check(Log.Summarize({ a = 1, b = 2 }):find("^{2:") ~= nil, "Summarize map -> {n:keys}")
check(Log.Summarize(string.rep("x", 100)):find("%.%.%.", 1) ~= nil, "Summarize long string truncates")
check(Log.Summarize(42) == "42", "Summarize number passthrough")

-- data argument is summarized and appended.
fileLines = {}
Log.Info(Log.CATEGORY.LIST, "refresh", { 1, 2, 3, 4 })
check(fileLines[1] and fileLines[1]:find("refresh [4]", 1, true) ~= nil, "data arg summarized into line")

-- record-style data renders key=value (the values reach the log, not just shape).
fileLines = {}
Log.Info(Log.CATEGORY.LIST, "refresh", { count = 7, name = "bag" })
check(fileLines[1] and fileLines[1]:find("count=7", 1, true) ~= nil, "record data renders key=value")
check(fileLines[1] and fileLines[1]:find('name="bag"', 1, true) ~= nil, "record data carries string values")

-- Category gating drops TRACE/DEBUG but never WARN/ERROR.
fileLines = {}
Log.SetCategoryEnabled(Log.CATEGORY.LIST, false)
Log.Debug(Log.CATEGORY.LIST, "should drop")
check(#fileLines == 0, "Disabled category drops DEBUG")
Log.Error(Log.CATEGORY.LIST, "must pass")
check(#fileLines == 1, "Disabled category still passes ERROR")
Log.SetCategoryEnabled(Log.CATEGORY.LIST, true)

-- Min level floor.
fileLines = {}
Log.SetMinLevel(Log.LEVEL.WARN)
Log.Debug(Log.CATEGORY.GENERAL, "below floor")
check(#fileLines == 0, "Records below min level are dropped")
Log.Warn(Log.CATEGORY.GENERAL, "at floor")
check(#fileLines == 1, "Records at/above min level pass")
Log.SetMinLevel(Log.LEVEL.TRACE)

-- Chat sink toggle.
fileLines = {}; chatLines = {}
Log.SetSink(Log.LEVEL.ERROR, "chat", true)
Log.Error(Log.CATEGORY.GENERAL, "boom")
check(#chatLines == 1 and chatLines[1]:find("[BUI:GENERAL]", 1, true) ~= nil, "Chat sink routes to d() when enabled")
check(#fileLines == 1, "ERROR still hits file alongside chat")
Log.SetSink(Log.LEVEL.ERROR, "chat", false)

-- Inert when logging is not active (normal players). Toggling is immediate even
-- though active-state is memoized (the setter invalidates the cache).
fileLines = {}; chatLines = {}
setLogging(false)
check(Log.IsActive() == false, "IsActive() is false when logging disabled")
Log.Error(Log.CATEGORY.GENERAL, "silent")
check(#fileLines == 0 and #chatLines == 0, "Logger is inert when logging is disabled")
setLogging(true)
check(Log.IsActive() == true, "IsActive() is true when logging enabled")

-- ============================================================================
-- PRESETS / EnabledFor / LAZY / PAYLOAD CAPTURE (log-level enhancement)
-- ============================================================================
setLogging(true)
Log.SetMinLevel(Log.LEVEL.TRACE)

-- EnabledFor mirrors the real emit() gate (active + level + category + sink).
check(Log.EnabledFor(Log.LEVEL.TRACE, Log.CATEGORY.GENERAL) == true, "EnabledFor true when active/at-level/sink-on")
setLogging(false)
check(Log.EnabledFor(Log.LEVEL.ERROR, Log.CATEGORY.GENERAL) == false, "EnabledFor false when logging inactive")
setLogging(true)

-- info preset: INFO/WARN/ERROR file-only, min INFO, payloads off.
local appliedOk, presetName = Log.ApplyPreset("info")
check(appliedOk == true and presetName == "info", "ApplyPreset('info') applies and reports its name")
check(Log.GetPreset() == "info", "GetPreset reports info")
check(Log.GetMinLevel() == Log.LEVEL.INFO, "info preset floors min level at INFO")
check(Log.GetPayloadCapture() == false, "info preset disables payload capture")
check(Log.GetSink(Log.LEVEL.DEBUG, "file") == false, "info preset turns off the DEBUG file sink")
check(Log.GetSink(Log.LEVEL.INFO, "file") == true, "info preset keeps the INFO file sink")
fileLines = {}
Log.Debug(Log.CATEGORY.GENERAL, "below floor")
check(#fileLines == 0, "info preset drops DEBUG records")
Log.Info(Log.CATEGORY.GENERAL, "info breadcrumb")
check(#fileLines == 1, "info preset captures INFO")

-- debug preset: DEBUG+ file, min DEBUG, payloads ON (the user-action flow + data).
Log.ApplyPreset("debug")
check(Log.GetPreset() == "debug", "GetPreset reports debug")
check(Log.GetMinLevel() == Log.LEVEL.DEBUG, "debug preset floors min level at DEBUG")
check(Log.GetPayloadCapture() == true, "debug preset enables payload capture")
check(Log.GetSink(Log.LEVEL.DEBUG, "file") == true, "debug preset keeps the DEBUG file sink")
check(Log.GetSink(Log.LEVEL.TRACE, "file") == false, "debug preset turns off the TRACE file sink")
fileLines = {}
Log.Trace(Log.CATEGORY.GENERAL, "trace below floor")
check(#fileLines == 0, "debug preset drops TRACE records")
Log.Debug(Log.CATEGORY.GENERAL, "debug action", { code = 7 })
check(#fileLines == 1, "debug preset captures DEBUG")
check(fileLines[1]:find("code=7", 1, true) ~= nil, "debug preset includes the payload (capture on)")

-- trace preset: everything + payloads. "verbose" is a back-compat alias for trace.
Log.ApplyPreset("verbose")
check(Log.GetPreset() == "trace", "ApplyPreset('verbose') aliases to trace")
Log.ApplyPreset("trace")
check(Log.GetPreset() == "trace", "GetPreset reports trace")
check(Log.GetMinLevel() == Log.LEVEL.TRACE, "trace preset floors min level at TRACE")
check(Log.GetPayloadCapture() == true, "trace preset enables payload capture")
fileLines = {}
Log.Trace(Log.CATEGORY.NAV, "trace", { step = "a" })
check(#fileLines == 1 and fileLines[1]:find("step=", 1, true) ~= nil, "trace preset captures TRACE with payload")

-- A manual low-level override flips the preset label to custom.
Log.SetMinLevel(Log.LEVEL.INFO)
check(Log.GetPreset() == "custom", "a manual SetMinLevel marks the preset custom")

-- Lazy payload: the builder runs only when the record will actually be emitted.
Log.ApplyPreset("verbose")
fileLines = {}
local lazyCalls = 0
Log.TraceLazy(Log.CATEGORY.NAV, "lazy", function() lazyCalls = lazyCalls + 1; return { n = 1 } end)
check(lazyCalls == 1 and #fileLines == 1, "lazy data builder runs and emits when active")
setLogging(false)
Log.TraceLazy(Log.CATEGORY.NAV, "lazy off", function() lazyCalls = lazyCalls + 1; return { n = 2 } end)
check(lazyCalls == 1, "lazy data builder does NOT run when logging is inactive")
setLogging(true)

-- Active-state memoization is invalidated by the setter, so a toggle is observed
-- immediately on the next call (no stale cache).
Log.ApplyPreset("off")
check(Log.IsActive() == false, "ApplyPreset('off') deactivates logging immediately")
Log.ApplyPreset("verbose")
check(Log.IsActive() == true, "ApplyPreset('verbose') reactivates logging immediately")

-- Unknown preset is rejected without changing state.
local badOk = Log.ApplyPreset("nope")
check(badOk == false, "ApplyPreset rejects an unknown preset name")

-- ============================================================================
-- PHASE 1: live schema (sid/seq), watch preset, recent ring, context suffix
-- ============================================================================

-- watch preset: DEBUG+, payloads on, distinct preset label.
Log.ApplyPreset("watch")
check(Log.GetPreset() == "watch", "ApplyPreset('watch') applies and reports its name")
check(Log.GetMinLevel() == Log.LEVEL.DEBUG, "watch preset floors min level at DEBUG")
check(Log.GetPayloadCapture() == true, "watch preset enables payload capture")

-- Every emitted line carries sid= and seq=, and seq is monotonic.
Log.ClearRecent()
fileLines = {}
Log.Debug(Log.CATEGORY.SCENE, "first")
Log.Debug(Log.CATEGORY.SCENE, "second")
check(#fileLines == 2, "watch preset emits DEBUG records")
check(fileLines[1]:find("sid=", 1, true) ~= nil, "line carries sid=")
local seq1 = tonumber(fileLines[1]:match("seq=(%d+)"))
local seq2 = tonumber(fileLines[2]:match("seq=(%d+)"))
check(seq1 ~= nil and seq2 == seq1 + 1, "seq is monotonic across records")

-- Recent-events ring captures dispatched records oldest-to-newest.
local recent = Log.GetRecent()
check(#recent >= 2, "recent ring captures dispatched records")
check(recent[#recent].message:find("second", 1, true) ~= nil, "recent ring is ordered newest-last")
local lastOne = Log.GetRecent(1)
check(#lastOne == 1 and lastOne[1].message:find("second", 1, true) ~= nil, "GetRecent(n) returns the n newest")

-- Context provider appends a suffix to every dispatched line; nil disables it.
Log.SetContextProvider(function() return "scene=bank view=bank" end)
fileLines = {}
Log.Debug(Log.CATEGORY.SCENE, "with ctx")
check(fileLines[1]:find("scene=bank view=bank", 1, true) ~= nil, "context provider suffix is appended")
Log.SetContextProvider(nil)
fileLines = {}
Log.Debug(Log.CATEGORY.SCENE, "no ctx")
check(fileLines[1]:find("scene=bank", 1, true) == nil, "clearing the context provider removes the suffix")

-- sinkDropped is recorded in the ring when the file sink rejects (budget drop).
Log.ClearRecent()
local origWriteRaw = BETTERUI.CIM.InterfaceLog.WriteRaw
BETTERUI.CIM.InterfaceLog.WriteRaw = function() return false end
Log.Debug(Log.CATEGORY.SCENE, "dropped")
BETTERUI.CIM.InterfaceLog.WriteRaw = origWriteRaw
local dr = Log.GetRecent(1)
check(#dr == 1 and dr[1].sinkDropped == true, "ring records sinkDropped when the file sink rejects")

-- ai is a deprecated alias for watch; sid/seq getters back the shared schema.
Log.ApplyPreset("ai")
check(Log.GetPreset() == "watch", "ApplyPreset('ai') aliases to watch")
check(type(Log.GetSessionId()) == "string" and #Log.GetSessionId() > 0, "GetSessionId returns a non-empty id")
local nseq1 = Log.NextSeq()
check(Log.NextSeq() == nseq1 + 1, "NextSeq is monotonic")

-- Flow ids + last-action context.
local f1 = Log.NewFlow("deposit")
check(f1 == "deposit#1", "NewFlow allocates kind#n")
check(Log.NewFlow("deposit") == "deposit#2", "NewFlow increments per kind")
Log.SetLastAction("pressed A", f1)
local la = Log.GetLastAction()
check(la ~= nil and la.message == "pressed A" and la.flow == f1, "SetLastAction/GetLastAction round-trip")

-- Flow envelopes emit begin/end records carrying flow=<id> (watch preset: DEBUG -> file).
fileLines = {}
local flow = Log.FlowBegin("withdraw", Log.CATEGORY.ACTION, "withdraw 50g")
check(type(flow) == "string" and flow:find("withdraw#%d") ~= nil, "FlowBegin returns a flow id")
check(#fileLines == 1 and fileLines[1]:find("[flow begin]", 1, true) ~= nil
    and fileLines[1]:find("flow=" .. flow, 1, true) ~= nil, "FlowBegin emits a begin envelope with flow=<id>")
check(Log.GetLastAction() and Log.GetLastAction().flow == flow, "FlowBegin records the flow as last action")
fileLines = {}
Log.FlowEnd(flow, Log.CATEGORY.ACTION, "done")
check(#fileLines == 1 and fileLines[1]:find("[flow end]", 1, true) ~= nil
    and fileLines[1]:find("flow=" .. flow, 1, true) ~= nil, "FlowEnd emits an end envelope with flow=<id>")

-- Flow envelopes never raise on non-string message/flow (safeTostring guards them).
local hostileMsg = setmetatable({}, { __tostring = function() error("no") end })
check(pcall(function() Log.FlowBegin("x", Log.CATEGORY.ACTION, { bad = true }) end),
    "FlowBegin tolerates a non-string message")
check(pcall(function() Log.FlowEnd({ weird = 1 }, Log.CATEGORY.ACTION, hostileMsg) end),
    "FlowEnd tolerates non-string flow + hostile __tostring message")

-- Dedicated error ring: captures only WARN/ERROR, counts them, returns them in order.
Log.ClearErrors()
Log.Warn(Log.CATEGORY.GENERAL, "w-ring")
Log.Error(Log.CATEGORY.GENERAL, "e-ring")
Log.Debug(Log.CATEGORY.GENERAL, "d-ring") -- DEBUG is not an error
local errs = Log.GetRecentErrors()
check(#errs == 2, "error ring captures only WARN/ERROR (not DEBUG)")
check(errs[1].message:find("w-ring", 1, true) ~= nil and errs[1].level == "WARN", "error ring entry 1 is the WARN")
check(errs[2].message:find("e-ring", 1, true) ~= nil and errs[2].level == "ERROR", "error ring entry 2 is the ERROR")
check(Log.GetErrorCount() == 2, "GetErrorCount counts WARN + ERROR")
Log.ClearErrors()
check(#Log.GetRecentErrors() == 0 and Log.GetErrorCount() == 0, "ClearErrors empties the ring + count")

-- Error ring wraps at its bound (50) + GetRecentErrors(n) returns the last n.
Log.ClearErrors()
for i = 1, 60 do Log.Warn(Log.CATEGORY.GENERAL, "wrap-" .. i) end
local capped = Log.GetRecentErrors()
check(#capped == 50, "error ring is bounded to 50 (wraps)")
check(capped[#capped].message:find("wrap-60", 1, true) ~= nil, "error ring retains the newest")
check(capped[1].message:find("wrap-11", 1, true) ~= nil, "error ring drops the oldest beyond 50")
local last3 = Log.GetRecentErrors(3)
check(#last3 == 3 and last3[3].message:find("wrap-60", 1, true) ~= nil, "GetRecentErrors(n) returns the last n")
check(Log.GetErrorCount() == 60, "GetErrorCount counts all WARN/ERROR, not just retained")
Log.ClearErrors()

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
