--[[
File: tools/tests/test_watchdog.lua
Purpose: Unit tests for the builog anomaly watchdog expectation API.

Usage:
  lua tools/tests/test_watchdog.lua
]]

local passed, failed = 0, 0

local function check(condition, message)
    if condition then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
    end
end

local nowMs = 0
local active = true
local nextTimerId = 0
local timers = {}
local events = {}

function GetFrameTimeMilliseconds()
    return nowMs
end

function zo_callLater(callback, delayMs)
    nextTimerId = nextTimerId + 1
    timers[nextTimerId] = { callback = callback, delayMs = delayMs, removed = false }
    return nextTimerId
end

function zo_removeCallLater(timerId)
    if timers[timerId] then
        timers[timerId].removed = true
    end
end

local function runTimers()
    local pending = timers
    timers = {}
    for _, timer in pairs(pending) do
        if not timer.removed and type(timer.callback) == "function" then
            timer.callback()
        end
    end
end

local function timerCount()
    local count = 0
    for _, timer in pairs(timers) do
        if not timer.removed then count = count + 1 end
    end
    return count
end

BETTERUI = { CIM = {} }
BETTERUI.Log = {
    LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
    CATEGORY = { STATE = "STATE" },
    IsActive = function()
        return active
    end,
    TraceEvent = function(category, event, phase, data, level)
        events[#events + 1] = {
            category = category,
            event = event,
            phase = phase,
            data = data,
            level = level,
        }
    end,
}

dofile("Modules/CIM/Core/Diagnostics/Watchdog.lua")

local Watchdog = BETTERUI.CIM.Watchdog

local function reset()
    if Watchdog and Watchdog.Deactivate then
        Watchdog.Deactivate()
    end
    nowMs = 0
    active = true
    nextTimerId = 0
    timers = {}
    events = {}
end

print("\n=== Watchdog Tests ===\n")

check(type(Watchdog) == "table", "Watchdog is registered under BETTERUI.CIM")
check(type(Watchdog.Expect) == "function", "Watchdog exposes Expect")
check(type(Watchdog.Resolve) == "function", "Watchdog exposes Resolve")
check(type(Watchdog.GetStats) == "function", "Watchdog exposes GetStats")

reset()
active = false
local inactiveOk = Watchdog.Expect("flow", "inactive#1", 1000, { flow = "inactive#1" })
check(inactiveOk == false and Watchdog.GetStats().pending == 0 and timerCount() == 0,
    "Expect is a zero-cost no-op while logging is inactive")

reset()
local expectOk = Watchdog.Expect("flow", "flow#1", 1000, { flow = "flow#1", source = "unit" })
local resolved = Watchdog.Resolve("flow", "flow#1", "completed")
nowMs = 1500
runTimers()
local stats = Watchdog.GetStats()
check(expectOk == true and resolved == true and #events == 0 and stats.pending == 0 and stats.resolved == 1,
    "expect -> resolve clears silently and emits no anomaly")

reset()
Watchdog.Expect("flow", "flow#2", 1000, { flow = "flow#2", source = "unit" })
nowMs = 1200
runTimers()
local anomaly = events[1]
stats = Watchdog.GetStats()
check(#events == 1
    and anomaly.category == "STATE"
    and anomaly.event == "anomaly"
    and anomaly.phase == "detected"
    and anomaly.level == 4
    and anomaly.data.kind == "flow"
    and anomaly.data.key == "flow#2"
    and anomaly.data.source == "unit"
    and anomaly.data.ageMs >= 1000
    and anomaly.data.timeoutMs == 1000
    and stats.pending == 0
    and stats.detected == 1,
    "expired expectation emits one WARN anomaly with kind/key/age/context")

reset()
Watchdog.Expect("list.refresh", "refresh#1", 1000, { flow = "refresh#1" })
check(timerCount() == 1, "Expect schedules one sweep timer while active")
active = false
nowMs = 1200
runTimers()
check(#events == 0 and timerCount() == 0,
    "sweep timer stops without emitting when logging deactivates")

reset()
Watchdog.Expect("flow", "disable#1", 1000, { flow = "disable#1", source = "unit" })
check(Watchdog.GetStats().pending == 1 and timerCount() == 1,
    "Deactivate regression setup has one pending expectation")
Watchdog.Deactivate()
nowMs = 1500
runTimers()
check(#events == 0 and Watchdog.GetStats().pending == 0 and timerCount() == 0,
    "Deactivate clears pending expectations so re-enable cannot emit stale anomalies")

reset()
for i = 1, 65 do
    Watchdog.Expect("overflow", "k" .. tostring(i), 1000, { index = i })
end
stats = Watchdog.GetStats()
local overflow = events[1]
check(stats.pending == 64
    and #events == 1
    and overflow.event == "anomaly"
    and overflow.phase == "overflow"
    and overflow.level == 4
    and overflow.data.kind == "overflow"
    and overflow.data.droppedKey == "k1"
    and Watchdog.Resolve("overflow", "k1", "late") == false,
    "overflow drops the oldest expectation and emits one WARN overflow anomaly")

reset()
Watchdog.Expect("reuse", "k1", 1000, { index = 1 })
Watchdog.Resolve("reuse", "k1", "done")
for i = 2, 64 do
    Watchdog.Expect("reuse", "k" .. tostring(i), 1000, { index = i })
end
Watchdog.Expect("reuse", "k1", 1000, { index = 100 })
Watchdog.Expect("reuse", "k65", 1000, { index = 65 })
local reusedOverflow = events[1]
check(reusedOverflow
    and reusedOverflow.phase == "overflow"
    and reusedOverflow.data.droppedKey == "k2"
    and Watchdog.Resolve("reuse", "k1", "still-live") == true,
    "overflow ignores stale resolved ids and preserves a newer reused key")

print(string.format("\nWatchdog tests: %d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
