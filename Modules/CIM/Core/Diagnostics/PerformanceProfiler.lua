--[[
File: Modules/CIM/Core/PerformanceProfiler.lua
Purpose: Performance profiling utilities for BetterUI debug mode.
         Provides timing hooks, counters, and metrics for optimization.
Author: BetterUI Team
Last Modified: 2026-02-07

STATUS: DORMANT - Kept for future performance debugging needs.
  This module has zero active consumers and is intentionally not integrated.
  Integration options when performance profiling is needed:
  - Add BETTERUI.CIM.Profiler.StartTiming/EndTiming calls around expensive operations
  - Wrap list refresh functions with Profiler.Wrap() for automatic timing
  - Enable via /betterui debug perf or BETTERUI.Debug.perf = true
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Profiler = {}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local profilerEnabled = false
local timings = {}
local counters = {}
local frameMetrics = {}
local startTimes = {}

-- ============================================================================
-- CORE API
-- ============================================================================

--[[
Function: BETTERUI.CIM.Profiler.Enable
Description: Enables performance profiling.
Rationale: Profiling has overhead; only enable when debugging performance.
]]
--- @param enabled boolean Whether to enable profiling
function BETTERUI.CIM.Profiler.Enable(enabled)
    profilerEnabled = enabled
    if not enabled then
        BETTERUI.CIM.Profiler.Reset()
    end
end

--[[
Function: BETTERUI.CIM.Profiler.IsEnabled
Description: Checks if profiling is currently enabled.
]]
--- @return boolean enabled
function BETTERUI.CIM.Profiler.IsEnabled()
    return profilerEnabled
end

--[[
Function: BETTERUI.CIM.Profiler.StartTiming
Description: Starts a timing measurement for a named operation.
Rationale: Mark the beginning of a code section to measure.
]]
--- @param name string The operation identifier
function BETTERUI.CIM.Profiler.StartTiming(name)
    if not profilerEnabled then return end
    startTimes[name] = GetGameTimeMilliseconds()
end

--[[
Function: BETTERUI.CIM.Profiler.EndTiming
Description: Ends a timing measurement and records the duration.
Rationale: Mark the end of a code section and accumulate metrics.
]]
--- @param name string The operation identifier
--- @return number|nil elapsed Milliseconds elapsed, or nil if profiling disabled
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

--[[
Function: BETTERUI.CIM.Profiler.GetTimings
Description: Returns all accumulated timing data.
]]
--- @return table<string, {totalMs: number, count: number, minMs: number, maxMs: number}> timings
function BETTERUI.CIM.Profiler.GetTimings()
    return timings
end

--[[
Function: BETTERUI.CIM.Profiler.GetCounters
Description: Returns all counter values.
]]
--- @return table<string, number> counters
function BETTERUI.CIM.Profiler.GetCounters()
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

-- ============================================================================
-- CONVENIENCE MACROS
-- ============================================================================

--[[
Function: BETTERUI.CIM.Profiler.Wrap
Description: Wraps a function with automatic timing.
Rationale: Easy way to profile existing functions without modifying them.
]]
--- @param name string The timing identifier
--- @param fn function The function to wrap
--- @return function wrapped The wrapped function
function BETTERUI.CIM.Profiler.Wrap(name, fn)
    return function(...)
        BETTERUI.CIM.Profiler.StartTiming(name)
        local results = { fn(...) }
        BETTERUI.CIM.Profiler.EndTiming(name)
        return unpack(results)
    end
end
