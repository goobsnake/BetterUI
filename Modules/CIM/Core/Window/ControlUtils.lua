--[[
File: Modules/CIM/Core/Window/ControlUtils.lua
Purpose: Shared UI control utilities used across BetterUI modules.
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.ControlUtils == nil then BETTERUI.ControlUtils = {} end

local function names() return BETTERUI.CIM and BETTERUI.CIM.Names end
local function debugInfo() return BETTERUI.CIM and BETTERUI.CIM.DebugInfo end

-- Human name for a control/parent in log lines (Names handles userdata + pcall guards).
local function nameOf(control, fallback)
    local N = names()
    if N and type(N.Control) == "function" then
        local ok, n = pcall(N.Control, control, fallback)
        if ok and type(n) == "string" then return n end
    end
    return fallback
end

-- Cache for control lookups to avoid repeated parent-chain traversals.
local ControlCache = {}

-- Keys we've already warned a miss for. Negative lookups are NOT cached, so without
-- this a control that stays unresolved re-warns on every call (a per-frame failed
-- lookup floods Interface.log). Warn at most once per key per cache generation;
-- cleared whenever the cache is invalidated so a new layout can re-report.
local warnedMisses = {}

--- Clears the control lookup cache.
--- Rationale: Call this when the UI layout is rebuilt or m_rootFrame changes.
function BETTERUI.ControlUtils.InvalidateControlCache()
    ControlCache = {}
    warnedMisses = {}
    if BETTERUI.Log and type(BETTERUI.Log.Trace) == "function" then
        pcall(BETTERUI.Log.Trace, BETTERUI.Log.CATEGORY.CONTROL, "control cache invalidated")
    end
end

-- Emit a self-describing "FindControl miss" WARN at most once per key per cache
-- generation. The MESSAGE names the missing control + its parent so it survives even
-- with payloads off; the payload adds the caller label + the resolved call site
-- (file:line:function), so a reader knows WHAT was missing, under WHAT, and from WHERE.
local function WarnMissOnce(cacheKey, name, parent, caller)
    if warnedMisses[cacheKey] then return end
    warnedMisses[cacheKey] = true
    local L = BETTERUI.Log
    if not L or type(L.Warn) ~= "function" then return end
    local src
    local DI = debugInfo()
    if DI and type(DI.CaptureCallerFrame) == "function" then
        -- Skip the logger AND ControlUtils' own frames so src points at the real caller
        -- (the extraSkip filter, not the level, is what reaches the real caller).
        local ok, s = pcall(DI.CaptureCallerFrame, 2, { "Window[/\\]ControlUtils%.lua" })
        if ok then src = s end
    end
    local pname = nameOf(parent, "<no-parent>")
    pcall(L.Warn, L.CATEGORY.CONTROL,
        "FindControl miss: no control named '" .. tostring(name) .. "' under parent '" .. pname .. "'",
        { control = name, parent = pname, caller = caller or "<unspecified>", src = src })
end

-- One-time TRACE breadcrumb when a control first RESOLVES (cache hits stay silent --
-- per-hit logging flooded Interface.log and starved the file-sink budget).
local function TraceResolved(parent, name, via, levels, caller)
    local L = BETTERUI.Log
    if not (L and L.IsActive and L.IsActive()) then return end
    if type(L.Trace) ~= "function" then return end
    pcall(L.Trace, L.CATEGORY.CONTROL, "FindControl resolved '" .. tostring(name) .. "' via " .. via,
        { control = name, parent = nameOf(parent, "<no-parent>"), via = via, levels = levels, caller = caller or "<unspecified>" })
end

--- Finds a control by name, handling ESO's complex naming conventions.
---
--- Purpose: Robust control lookup traversing parent hierarchies with caching.
--- Mechanics:
--- 1. Checks `ControlCache` for a hit.
--- 2. Checks direct child (`GetNamedChild`).
--- 3. Walks up 6 levels of parents, checking for global name matches (`ParentName..Name`).
--- 4. Falls back to global `_G[name]`.
--- 5. Stores result in cache.
---
--- References: Used pervasively in this module to find XML-defined controls.
---
---@param parent any        parent control to search under
---@param name string       short control name
---@param caller string|nil optional label of the calling site -- enriches miss/resolved logs
function BETTERUI.ControlUtils.FindControl(parent, name, caller)
    if not parent then
        WarnMissOnce("nil|" .. tostring(name), name, nil, caller)
        return nil
    end

    -- Cache hit is the hot, repeated path: intentionally NOT logged. Per-call hit
    -- breadcrumbs flooded Interface.log (thousands/min) and starved the file sink's
    -- rate-limit budget, dropping other modules' breadcrumbs. Only the one-time
    -- RESOLUTION of a control (below, at TRACE) and true misses are logged.
    local cacheKey = tostring(parent) .. "|" .. name
    local cached = ControlCache[cacheKey]
    if cached then
        return cached
    end

    -- First try a direct child with the given short name. ESO controls are userdata, so
    -- pcall the method calls -- a disposed/odd control must degrade to a miss, never raise
    -- while diagnostics are running.
    local okChild, child = pcall(parent.GetNamedChild, parent, name)
    if okChild and child then
        ControlCache[cacheKey] = child
        TraceResolved(parent, name, "child", 0, caller)
        return child
    end

    -- Try global by several possible name prefixes.
    local probe = parent
    local guards = 0
    while probe ~= nil and guards < 6 do
        local okName, pname = pcall(probe.GetName, probe)
        if okName and type(pname) == "string" then
            local ctrl = _G[pname .. name]
            if ctrl ~= nil then
                ControlCache[cacheKey] = ctrl
                TraceResolved(parent, name, "ancestorGlobal", guards, caller)
                return ctrl
            end
        end
        -- Move to the next ancestor (pcall: GetParent may be absent or raise on userdata).
        local okParent, nextProbe = pcall(probe.GetParent, probe)
        probe = (okParent and nextProbe) or nil
        guards = guards + 1
    end

    -- Fall back to direct global name (name without prefix)
    local globalCtrl = _G[name]
    if globalCtrl then
        ControlCache[cacheKey] = globalCtrl
        TraceResolved(parent, name, "global", guards, caller)
        return globalCtrl
    end

    WarnMissOnce(cacheKey, name, parent, caller)
    return nil
end
