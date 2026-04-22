--[[
File: Modules/CIM/Core/PerformanceProfiler.lua
Purpose: Performance profiling utilities for BetterUI debug mode.
         Provides timing hooks, counters, and metrics for optimization.

STATUS: DORMANT - Kept for future performance debugging needs.
  This module has zero active consumers and is intentionally not integrated.
  Integration options when performance profiling is needed:
  - Add BETTERUI.CIM.Profiler.StartTiming/EndTiming calls around expensive operations
  - Wrap list refresh functions with Profiler.Wrap() for automatic timing
  - Enable via /betterui debug perf or BETTERUI.Debug.perf = true
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Profiler = {}

-- CONFIGURATION

local profilerEnabled = false
local timings = {}
local counters = {}
local startTimes = {}

local function CloneTableShallow(source)
    local clone = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            clone[key] = nested
        else
            clone[key] = value
        end
    end
    return clone
end

-- CORE API

function BETTERUI.CIM.Profiler.Enable(enabled)
    profilerEnabled = enabled
    if not enabled then
        BETTERUI.CIM.Profiler.Reset()
    end
end

function BETTERUI.CIM.Profiler.IsEnabled()
    return profilerEnabled
end

function BETTERUI.CIM.Profiler.StartTiming(name)
    if not profilerEnabled then return end
    startTimes[name] = GetGameTimeMilliseconds()
end

function BETTERUI.CIM.Profiler.EndTiming(name)
    if not profilerEnabled then return nil end

    local endTime = GetGameTimeMilliseconds()
    local startTime = startTimes[name]
    if not startTime then return nil end

    local elapsed = endTime - startTime
    startTimes[name] = nil

    -- Accumulate timing data
    if not timings[name] then
        timings[name] = { totalMs = 0, count = 0, minMs = elapsed, maxMs = elapsed }
    end
    local t = timings[name]
    t.totalMs = t.totalMs + elapsed
    t.count = t.count + 1
    if elapsed < t.minMs then t.minMs = elapsed end
    if elapsed > t.maxMs then t.maxMs = elapsed end

    return elapsed
end

function BETTERUI.CIM.Profiler.GetTimings()
    return CloneTableShallow(timings)
end

function BETTERUI.CIM.Profiler.GetCounters()
    return CloneTableShallow(counters)
end

--- Returns the mutable timings table used internally by the profiler.
function BETTERUI.CIM.Profiler.GetTimingsLive()
    return timings
end

--- Returns the mutable counters table used internally by the profiler.
function BETTERUI.CIM.Profiler.GetCountersLive()
    return counters
end

--[[
Function: BETTERUI.CIM.Profiler.Reset
Description: Clears all accumulated profiling data.
]]
function BETTERUI.CIM.Profiler.Reset()
    timings = {}
    counters = {}
    startTimes = {}
end

--[[
Function: BETTERUI.CIM.Profiler.Report
Description: Prints a profiling report to chat.
Rationale: Quick debug output without needing external tools.
]]
function BETTERUI.CIM.Profiler.Report()
    if not profilerEnabled then
        d("|cff6600[BetterUI Profiler]|r Profiling is disabled")
        return
    end

    d("|c00ccff[BetterUI Profiler]|r Performance Report:")

    -- Timing report
    local sortedTimings = {}
    for name, data in pairs(timings) do
        table.insert(sortedTimings, { name = name, data = data })
    end
    table.sort(sortedTimings, function(a, b) return a.data.totalMs > b.data.totalMs end)

    for _, entry in ipairs(sortedTimings) do
        local timingData = entry.data
        local avgMs = timingData.count > 0 and (timingData.totalMs / timingData.count) or 0
        d(string.format("  %s: %.1fms total, %d calls, avg %.2fms (min %.1f, max %.1f)",
            entry.name, timingData.totalMs, timingData.count, avgMs, timingData.minMs, timingData.maxMs))
    end

    -- Counter report
    if next(counters) then
        d("|c00ccff[Counters]|r")
        for name, count in pairs(counters) do
            d(string.format("  %s: %d", name, count))
        end
    end
end

-- CONVENIENCE MACROS

function BETTERUI.CIM.Profiler.Wrap(name, fn)
    return function(...)
        BETTERUI.CIM.Profiler.StartTiming(name)
        local results = { fn(...) }
        BETTERUI.CIM.Profiler.EndTiming(name)
        return unpack(results)
    end
end
