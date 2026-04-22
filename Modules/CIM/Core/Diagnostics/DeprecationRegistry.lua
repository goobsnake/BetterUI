--[[
File: Modules/CIM/Core/DeprecationRegistry.lua
Purpose: Tracks deprecated APIs and issues one-time warnings to aid migration.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

-- DEPRECATION REGISTRY

BETTERUI.CIM.DeprecationRegistry = {
    -- Storage for registered deprecations
    _registry = {},
    -- Track which warnings have been issued (one-time)
    _warned = {},
    -- Whether warnings are enabled (disable for production)
    _enabled = true,
}

local function CloneDeprecationInfo(info)
    if type(info) ~= "table" then
        return info
    end

    return {
        oldName = info.oldName,
        newName = info.newName,
        removeVersion = info.removeVersion,
        registeredAt = info.registeredAt,
    }
end

--- Records a deprecated alias with its replacement.
function BETTERUI.CIM.DeprecationRegistry.Register(oldName, newName, removeVersion)
    BETTERUI.CIM.DeprecationRegistry._registry[oldName] = {
        oldName = oldName,
        newName = newName,
        removeVersion = removeVersion or "future",
        registeredAt = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0,
    }
end

--- Issues a one-time deprecation warning in debug output.
function BETTERUI.CIM.DeprecationRegistry.WarnOnce(oldName)
    if not BETTERUI.CIM.DeprecationRegistry._enabled then return false end
    if BETTERUI.CIM.DeprecationRegistry._warned[oldName] then return false end

    local info = BETTERUI.CIM.DeprecationRegistry._registry[oldName]
    if not info then return false end

    BETTERUI.CIM.DeprecationRegistry._warned[oldName] = true

    local msg = string.format(
        "[Deprecated] '%s' is deprecated, use '%s' instead (removed in %s)",
        info.oldName,
        info.newName,
        info.removeVersion or "future"
    )

    if BETTERUI.Debug then
        BETTERUI.Debug(msg)
    end

    return true
end

--- Enables or disables deprecation warnings globally.
function BETTERUI.CIM.DeprecationRegistry.SetEnabled(enabled)
    BETTERUI.CIM.DeprecationRegistry._enabled = enabled
end

--- Returns all registered deprecations.
function BETTERUI.CIM.DeprecationRegistry.GetAll()
    local result = {}
    for _, info in pairs(BETTERUI.CIM.DeprecationRegistry._registry) do
        table.insert(result, CloneDeprecationInfo(info))
    end
    return result
end

--- Returns the mutable internal registry table.
--- Callers should prefer `GetAll` unless live mutation is intentional.
function BETTERUI.CIM.DeprecationRegistry.GetRegistryLive()
    return BETTERUI.CIM.DeprecationRegistry._registry
end

--- Creates a wrapper function that warns on first use and delegates to replacement.
--- Caller is responsible for registering the old name before creating the shim.
function BETTERUI.CIM.DeprecationRegistry.CreateShim(oldName, newFn)
    return function(...)
        BETTERUI.CIM.DeprecationRegistry.WarnOnce(oldName)
        return newFn(...)
    end
end
