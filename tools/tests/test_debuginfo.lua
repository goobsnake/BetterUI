--[[
File: tools/tests/test_debuginfo.lua
Purpose: Unit tests for DebugInfo.lua (guarded debug.traceback caller capture).
Usage:   lua tools/tests/test_debuginfo.lua
]]

BETTERUI = { CIM = {} }

dofile("Modules/CIM/Core/Diagnostics/DebugInfo.lua")
local DebugInfo = BETTERUI.CIM.DebugInfo

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== DebugInfo Tests ===\n")

-- The Lua test environment HAS debug.traceback (mirrors ESO retail, which exposes it).
check(DebugInfo.HasTraceback() == true, "HasTraceback true when debug.traceback exists")

-- CaptureCallerFrame yields a file:line[:fn] src for a real caller.
local function callerFn()
    return DebugInfo.CaptureCallerFrame(2)
end
local src = callerFn()
check(type(src) == "string" and src:find("%.lua:%d") ~= nil, "CaptureCallerFrame yields file:line src")

-- Traceback is capped to maxChars and reports truncation.
local tb, trunc = DebugInfo.Traceback(1, 20)
check(type(tb) == "string" and #tb <= 20, "Traceback capped to maxChars")
check(trunc == true, "Traceback reports truncated when capped")

-- Graceful degradation when the debug library is absent (defensive, never errors).
local realDebug = debug
debug = nil
check(DebugInfo.HasTraceback() == false, "HasTraceback false when debug is absent")
check(DebugInfo.CaptureCallerFrame() == nil, "CaptureCallerFrame nil when debug is absent")
local tb2 = DebugInfo.Traceback()
check(tb2 == nil, "Traceback nil when debug is absent")
debug = realDebug

-- ESO-format parsing: skip logger frames, return the first APP frame as file:line:fn.
do
    local realTb = debug.traceback
    debug.traceback = function()
        return "stack traceback:\n" ..
            "\t[C]: in function 'error'\n" ..
            "\tuser:/AddOns/BetterUI/Modules/CIM/Core/Diagnostics/Log.lua:50: in function 'Warn'\n" ..
            "\tuser:/AddOns/BetterUI/Modules/CIM/Core/Window/ControlUtils.lua:123: in function 'FindControl'\n" ..
            "\tuser:/AddOns/BetterUI/Modules/X.lua:9: in main chunk"
    end
    check(DebugInfo.CaptureCallerFrame(1) == "Modules/CIM/Core/Window/ControlUtils.lua:123:FindControl",
        "CaptureCallerFrame skips logger frames, returns first app frame:line:function")

    debug.traceback = function() return "stack traceback:\n\t[C]: ?\n\t[C]: in ?" end
    check(DebugInfo.CaptureCallerFrame(1) == nil, "CaptureCallerFrame nil when no .lua frame parses")
    debug.traceback = realTb
end

-- extraSkip: skip a wrapping helper's frames to reach the real caller beyond them.
do
    local realTb = debug.traceback
    debug.traceback = function()
        return "stack traceback:\n" ..
            "\tuser:/AddOns/BetterUI/Modules/CIM/Core/Window/ControlUtils.lua:50: in function 'WarnMissOnce'\n" ..
            "\tuser:/AddOns/BetterUI/Modules/CIM/Core/Window/ControlUtils.lua:88: in function 'FindControl'\n" ..
            "\tuser:/AddOns/BetterUI/Modules/CIM/Bank.lua:21: in function 'setupFooter'"
    end
    check(DebugInfo.CaptureCallerFrame(1, { "Window[/\\]ControlUtils%.lua" }) == "Modules/CIM/Bank.lua:21:setupFooter",
        "extraSkip skips wrapper frames to the real caller")
    debug.traceback = realTb
end

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
