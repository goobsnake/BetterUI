--[[
File: Modules/CIM/ControlUtils.lua
Purpose: Shared UI control utilities used across BetterUI modules.
Author: BetterUI Team
Last Modified: 2026-01-22
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.ControlUtils == nil then BETTERUI.ControlUtils = {} end

-- Cache for control lookups to avoid repeated parent-chain traversals.
local ControlCache = {}

--- Clears the control lookup cache.
--- Rationale: Call this when the UI layout is rebuilt or m_rootFrame changes.
function BETTERUI.ControlUtils.InvalidateControlCache()
    ControlCache = {}
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
--- @param parent Control The parent control to search from
--- @param name string The short name of the control to find (e.g., "Icon", "Button1")
--- @return Control|nil The found control, or nil if not found
function BETTERUI.ControlUtils.FindControl(parent, name)
    if not parent then return nil end

    -- Check cache first
    local cacheKey = tostring(parent) .. "|" .. name
    if ControlCache[cacheKey] then
        return ControlCache[cacheKey]
    end

    -- First try to grab a direct child with the given short name
    local child = parent:GetNamedChild(name)
    if child then
        ControlCache[cacheKey] = child
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
        return globalCtrl
    end

    return nil
end
