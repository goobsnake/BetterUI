--[[
File: tools/tests/test_perf.lua
Purpose: Unit tests for Perf.lua — gated timing markers.
Usage:   lua tools/tests/test_perf.lua
]]

BETTERUI = { CIM = {} }

local gameMs = 0
function GetGameTimeMilliseconds() return gameMs end

local cap = { debug = {} }
local perfEnabled = true
BETTERUI.Log = {
    LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
    CATEGORY = { PERF = "PERF" },
    EnabledFor = function(_level, _cat) return perfEnabled end,
    Debug = function(cat, msg, data) cap.debug[#cap.debug + 1] = { cat = cat, msg = msg, data = data } end,
}

dofile("Modules/CIM/Core/Diagnostics/Perf.lua")
local Perf = BETTERUI.CIM.Perf

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== Perf Tests ===\n")

-- Begin returns a token when PERF on; End emits a PERF record with elapsed ms + fields.
gameMs = 100
local t = Perf.Begin("op")
check(type(t) == "table" and t.label == "op", "Begin returns a token when PERF is on")
gameMs = 130
Perf.End(t, { items = 5 })
check(#cap.debug == 1, "End emits a PERF record")
check(cap.debug[1].cat == "PERF" and cap.debug[1].msg:find("op took 30ms", 1, true) ~= nil,
    "record names the label + elapsed ms")
check(cap.debug[1].data.ms == 30 and cap.debug[1].data.items == 5, "data carries ms + merged fields")

-- Begin returns nil when PERF off (hot-path no-cost); End no-ops on a nil token.
perfEnabled = false
local t2 = Perf.Begin("op2")
check(t2 == nil, "Begin returns nil when PERF is off")
local before = #cap.debug
Perf.End(t2)
check(#cap.debug == before, "End no-ops on a nil token")

-- Measure forwards ALL return values incl embedded nils; off = direct call, no record.
perfEnabled = true
local a, b, c = Perf.Measure("m", function() return 1, nil, 3 end)
check(a == 1 and b == nil and c == 3, "Measure forwards results incl embedded nils")
check(#cap.debug == before + 1, "Measure emits one record when PERF on")
perfEnabled = false
local d0 = #cap.debug
local r = Perf.Measure("m2", function() return "z" end)
check(r == "z" and #cap.debug == d0, "Measure off: direct call, no record, no overhead")

-- Measure propagates fn errors and emits NO record for the failed span.
perfEnabled = true
local before2 = #cap.debug
local okE = pcall(function() Perf.Measure("err", function() error("boom") end) end)
check(okE == false, "Measure propagates fn errors (does not swallow)")
check(#cap.debug == before2, "Measure emits no record when fn raises")

-- Double-End on a token emits at most one record (token is consumed).
gameMs = 300
local t3 = Perf.Begin("dup")
gameMs = 310
local b3 = #cap.debug
Perf.End(t3)
Perf.End(t3)
check(#cap.debug == b3 + 1, "double Perf.End emits only one record (token consumed)")

-- Trailing-nil arity is preserved through Measure.
local n = select("#", Perf.Measure("tn", function() return 1, nil end))
check(n == 2, "Measure preserves trailing-nil arity")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
