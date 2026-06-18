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
}

function d(msg) chatLines[#chatLines + 1] = msg end
function GetGameTimeMilliseconds() return 100 end

dofile("Modules/CIM/Core/Diagnostics/Log.lua")
local Log = BETTERUI.Log

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
local function reset() fileLines = {}; chatLines = {}
    -- re-point the capture closures (they captured the locals by upvalue)
end

print("\n=== Log Tests ===\n")

-- Default routing: DEBUG -> file only, formatted with level+category+ts.
fileLines = {}; chatLines = {}
Log.Debug(Log.CATEGORY.GENERAL, "hi")
check(#fileLines == 1, "Debug writes one file line")
check(fileLines[1] and fileLines[1]:find("[BUI] 100 DEBUG GENERAL | hi", 1, true) ~= nil, "File line carries level/category/ts/message")
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

-- Inert when logging is not active (normal players).
fileLines = {}; chatLines = {}
ilEnabled = false
check(Log.IsActive() == false, "IsActive() is false when logging disabled")
Log.Error(Log.CATEGORY.GENERAL, "silent")
check(#fileLines == 0 and #chatLines == 0, "Logger is inert when logging is disabled")
ilEnabled = true
check(Log.IsActive() == true, "IsActive() is true when logging enabled")

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
