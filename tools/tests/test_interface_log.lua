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
function zo_callLater(callback, ms)
    capturedDeferred = callback
    return "stub-call-name"
end

function GetGameTimeMilliseconds()
    return 4242
end

ZO_ERROR_FRAME = { suppressErrorDialog = false }
SLASH_COMMANDS = {}

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
check(err:find("hello | world tab", 1, true) ~= nil, "Newlines/tabs flattened to one record")
check(err:find("\n", 1, true) == nil, "Logged line contains no raw newline")

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
local beforeStats = IL.GetStats()
IL.WriteRaw("budget-1")
IL.WriteRaw("budget-2")
IL.WriteRaw("budget-3")
local afterStats = IL.GetStats()
check(afterStats.scheduled - beforeStats.scheduled == 2, "per-frame budget schedules up to the cap")
check(afterStats.dropped - beforeStats.dropped == 1, "per-frame budget drops the overflow record")

-- Restore unlimited + disabled so nothing leaks past these tests.
IL.SetBudget({ maxPerFrame = 0, maxPerSecond = 0, maxPending = 0 })
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
