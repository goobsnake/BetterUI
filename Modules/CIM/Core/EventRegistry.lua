--[[
File: Modules/CIM/Core/EventRegistry.lua
Purpose: Centralized event registration with cleanup support.
         Tracks all EVENT_MANAGER registrations to enable proper cleanup
         when modules are disabled or scenes are hidden.
Author: BetterUI Team
Last Modified: 2026-01-29

Usage:
    -- Register an event with tracking
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", "ROF_PowerUpdate", EVENT_POWER_UPDATE, handler)

    -- Unregister all events for a module
    BETTERUI.CIM.EventRegistry.UnregisterAll("ResourceOrbFrames")
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.EventRegistry = {}

-- ============================================================================
-- INTERNAL STATE
-- ============================================================================

---@type table<string, table<number, string[]>> Module -> {eventId -> [namespaces]}
local registrations = {}

-- ============================================================================
-- CORE API
-- ============================================================================

--- Register an event with tracking for later cleanup.
--- @param moduleName string Module identifier (e.g., "ResourceOrbFrames", "Inventory")
--- @param namespace string Event namespace (unique string for this registration)
--- @param eventId number ESO event constant (e.g., EVENT_POWER_UPDATE)
--- @param callback function Event handler function
function BETTERUI.CIM.EventRegistry.Register(moduleName, namespace, eventId, callback)
    -- Initialize module tracking if needed
    registrations[moduleName] = registrations[moduleName] or {}
    registrations[moduleName][eventId] = registrations[moduleName][eventId] or {}

    -- Track the namespace for this event
    table.insert(registrations[moduleName][eventId], namespace)

    -- Perform the actual registration
    EVENT_MANAGER:RegisterForEvent(namespace, eventId, callback)
end

--- Register an event with a filter.
--- @param moduleName string Module identifier
--- @param namespace string Event namespace
--- @param eventId number ESO event constant
--- @param callback function Event handler function
--- @param filterType number Filter type constant
--- @param filterValue any Filter value
function BETTERUI.CIM.EventRegistry.RegisterFiltered(moduleName, namespace, eventId, callback, filterType, filterValue)
    -- Register the event first
    BETTERUI.CIM.EventRegistry.Register(moduleName, namespace, eventId, callback)

    -- Add the filter
    EVENT_MANAGER:AddFilterForEvent(namespace, eventId, filterType, filterValue)
end

--- Unregister all events for a specific module.
--- Call this when a module is disabled or its scene is hidden.
--- @param moduleName string Module identifier to clean up
--- @param suppressLog boolean|nil When true, skip debug/chat output for this cleanup
function BETTERUI.CIM.EventRegistry.UnregisterAll(moduleName, suppressLog)
    local moduleRegs = registrations[moduleName]
    if not moduleRegs then return end

    for eventId, namespaces in pairs(moduleRegs) do
        for _, namespace in ipairs(namespaces) do
            EVENT_MANAGER:UnregisterForEvent(namespace, eventId)
        end
    end

    registrations[moduleName] = nil

    if not suppressLog then
        BETTERUI.Debug(string.format("[EventRegistry] Unregistered all events for module: %s", moduleName))
    end
end

--- Unregister a specific event for a module.
--- @param moduleName string Module identifier
--- @param namespace string The namespace to unregister
--- @param eventId number The event ID to unregister
function BETTERUI.CIM.EventRegistry.Unregister(moduleName, namespace, eventId)
    local moduleRegs = registrations[moduleName]
    if not moduleRegs or not moduleRegs[eventId] then return end

    -- Remove from tracking
    local namespaces = moduleRegs[eventId]
    for i = #namespaces, 1, -1 do
        if namespaces[i] == namespace then
            table.remove(namespaces, i)
            break
        end
    end

    -- Clean up empty tables
    if #namespaces == 0 then
        moduleRegs[eventId] = nil
    end
    if not next(moduleRegs) then
        registrations[moduleName] = nil
    end

    -- Unregister from EVENT_MANAGER
    EVENT_MANAGER:UnregisterForEvent(namespace, eventId)
end

--- Get the count of registered events for a module.
--- @param moduleName string Module identifier
--- @return number count Total number of event registrations
function BETTERUI.CIM.EventRegistry.GetRegistrationCount(moduleName)
    local count = 0
    local moduleRegs = registrations[moduleName]
    if moduleRegs then
        for _, namespaces in pairs(moduleRegs) do
            count = count + #namespaces
        end
    end
    return count
end

