--[[
File: Modules/CIM/Core/Window/ControlUtils.lua
Purpose: Shared UI control utilities used across BetterUI modules.
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.ControlUtils == nil then BETTERUI.ControlUtils = {} end

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
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, "controlCacheInvalidated") end
end

-- Emit a "findControl miss" WARN at most once per key per cache generation.
local function WarnMissOnce(key)
    if warnedMisses[key] then return end
    warnedMisses[key] = true
    if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.GENERAL, "findControl miss", { cacheKey = key }) end
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
function BETTERUI.ControlUtils.FindControl(parent, name)
    if not parent then
        WarnMissOnce(tostring(parent) .. "|" .. name)
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

    -- First try to grab a direct child with the given short name
    local child = parent:GetNamedChild(name)
    if child then
        ControlCache[cacheKey] = child
        if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, "findControl resolved", { cacheKey = cacheKey, levelsChecked = 0, via = "child" }) end
        return child
    end

    -- Try global by several possible name prefixes.
    local probe = parent
    local guards = 0
    while probe ~= nil and guards < 6 do
        local globalName = probe:GetName() .. name
        local ctrl = _G[globalName]
        if ctrl ~= nil then
            ControlCache[cacheKey] = ctrl
            if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, "findControl resolved", { cacheKey = cacheKey, levelsChecked = guards, via = "ancestorGlobal" }) end
            return ctrl
        end
        -- Move to the next ancestor.
        if probe.GetParent then
            probe = probe:GetParent()
        else
            probe = nil
        end
        guards = guards + 1
    end

    -- Fall back to direct global name (name without prefix)
    local globalCtrl = _G[name]
    if globalCtrl then
        ControlCache[cacheKey] = globalCtrl
        if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, "findControl resolved", { cacheKey = cacheKey, levelsChecked = guards, via = "global" }) end
        return globalCtrl
    end

    WarnMissOnce(cacheKey)
    return nil
end
