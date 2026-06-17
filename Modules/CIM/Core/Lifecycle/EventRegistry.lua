-- Centralized EVENT_MANAGER registration tracking and cleanup.

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.EventRegistry = BETTERUI.CIM.EventRegistry or {}

local EventRegistry = BETTERUI.CIM.EventRegistry

local function EnsureRuntimeState()
    EventRegistry._registrations = EventRegistry._registrations or {}
    return EventRegistry._registrations
end

local function CopyRegistrations(registrations)
    local snapshot = {}
    for moduleName, moduleRegs in pairs(registrations) do
        local moduleSnapshot = {}
        for eventId, namespaces in pairs(moduleRegs) do
            local namespaceSnapshot = {}
            for i = 1, #namespaces do
                namespaceSnapshot[i] = namespaces[i]
            end
            moduleSnapshot[eventId] = namespaceSnapshot
        end
        snapshot[moduleName] = moduleSnapshot
    end
    return snapshot
end

--- Register an event with tracking for later cleanup.
---@param moduleName string Module name to track the registration under
---@param namespace string Unique namespace for EVENT_MANAGER registration
---@param eventId number ESO event constant
---@param callback function Event handler function
---@return boolean registered True when EVENT_MANAGER accepted the registration
function EventRegistry.Register(moduleName, namespace, eventId, callback)
    -- RegisterForEvent returns false on failure (e.g. duplicate namespace+event);
    -- only track registrations that actually took effect.
    local registered = EVENT_MANAGER:RegisterForEvent(namespace, eventId, callback)
    if not registered then
        if BETTERUI.Log then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "RegisterForEvent rejected (duplicate?)", {
                module = moduleName, namespace = namespace, event = eventId })
        end
        return false
    end

    local registrations = EnsureRuntimeState()
    registrations[moduleName] = registrations[moduleName] or {}
    registrations[moduleName][eventId] = registrations[moduleName][eventId] or {}

    table.insert(registrations[moduleName][eventId], namespace)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "register", {
            module = moduleName, events = EventRegistry.GetRegistrationCount(moduleName) })
    end
    return true
end

--- Register an event with a filter.
---@param moduleName string Module name
---@param namespace string Unique namespace
---@param eventId number ESO event constant
---@param callback function Event handler
---@param filterType number ESO filter type constant
---@param filterValue any Filter value
---@return boolean registered True when the underlying registration succeeded
function EventRegistry.RegisterFiltered(moduleName, namespace, eventId, callback, filterType, filterValue)
    -- Only add the filter when the registration actually took effect;
    -- Register already logs and skips rejected/duplicate registrations.
    if not EventRegistry.Register(moduleName, namespace, eventId, callback) then
        return false
    end

    EVENT_MANAGER:AddFilterForEvent(namespace, eventId, filterType, filterValue)
    return true
end

--- Unregister all events for a specific module.
---@param moduleName string Module name to clean up
---@param suppressLog boolean|nil When true, skip debug logging
function EventRegistry.UnregisterAll(moduleName, suppressLog)
    local registrations = EnsureRuntimeState()
    local moduleRegs = registrations[moduleName]
    if not moduleRegs then return end

    local eventCount = EventRegistry.GetRegistrationCount(moduleName)

    for eventId, namespaces in pairs(moduleRegs) do
        for _, namespace in ipairs(namespaces) do
            EVENT_MANAGER:UnregisterForEvent(namespace, eventId)
        end
    end

    registrations[moduleName] = nil

    if not suppressLog then
        if BETTERUI.Log then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "Unregistered all events for module", { module = moduleName })
        end
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "unregisterAll", { module = moduleName, events = eventCount }) end
end

--- Unregister a specific event for a module.
---@param moduleName string Module name
---@param namespace string Original namespace used in Register
---@param eventId number ESO event constant
function EventRegistry.Unregister(moduleName, namespace, eventId)
    local registrations = EnsureRuntimeState()
    local moduleRegs = registrations[moduleName]
    if not moduleRegs or not moduleRegs[eventId] then return end

    local namespaces = moduleRegs[eventId]
    for i = #namespaces, 1, -1 do
        if namespaces[i] == namespace then
            table.remove(namespaces, i)
            break
        end
    end

    if #namespaces == 0 then
        moduleRegs[eventId] = nil
    end
    if not next(moduleRegs) then
        registrations[moduleName] = nil
    end

    EVENT_MANAGER:UnregisterForEvent(namespace, eventId)
end

--- Get the count of registered events for a module.
---@param moduleName string Module name to count
---@return number count Total registered event handlers
function EventRegistry.GetRegistrationCount(moduleName)
    local registrations = EnsureRuntimeState()
    local count = 0
    local moduleRegs = registrations[moduleName]
    if moduleRegs then
        for _, namespaces in pairs(moduleRegs) do
            count = count + #namespaces
        end
    end
    return count
end

function EventRegistry.GetRegisteredEvents()
    return CopyRegistrations(EnsureRuntimeState())
end

EventRegistry.EnsureRuntimeState = EnsureRuntimeState
