--[[
File: tools/tests/support/DeprecationRegistry.lua
Purpose: Test-only registry for deprecated API shims.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

BETTERUI.CIM.DeprecationRegistry = {
    _registry = {},
    _warned = {},
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

function BETTERUI.CIM.DeprecationRegistry.Register(oldName, newName, removeVersion)
    BETTERUI.CIM.DeprecationRegistry._registry[oldName] = {
        oldName = oldName,
        newName = newName,
        removeVersion = removeVersion or "future",
        registeredAt = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0,
    }
end

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

function BETTERUI.CIM.DeprecationRegistry.SetEnabled(enabled)
    BETTERUI.CIM.DeprecationRegistry._enabled = enabled
end

function BETTERUI.CIM.DeprecationRegistry.GetAll()
    local result = {}
    for _, info in pairs(BETTERUI.CIM.DeprecationRegistry._registry) do
        table.insert(result, CloneDeprecationInfo(info))
    end
    return result
end

function BETTERUI.CIM.DeprecationRegistry.GetRegistryLive()
    return BETTERUI.CIM.DeprecationRegistry._registry
end

function BETTERUI.CIM.DeprecationRegistry.CreateShim(oldName, newFn)
    return function(...)
        BETTERUI.CIM.DeprecationRegistry.WarnOnce(oldName)
        return newFn(...)
    end
end
