--[[
File: Modules/CIM/Core/DeprecationRegistry.lua
Purpose: Tracks deprecated APIs and issues warnings to help migrate legacy code.
Author: BetterUI Team
Last Modified: 2026-01-31

Used By: Constants.lua (legacy global aliases), Module initializers
Dependencies: BETTERUI.Debug
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

-- ============================================================================
-- DEPRECATION REGISTRY
-- ============================================================================

--[[
Table: BETTERUI.CIM.DeprecationRegistry
Description: Registry for tracking deprecated aliases and issuing one-time warnings.
Rationale: Helps developers migrate from legacy APIs while maintaining backward compatibility.
Mechanism:
  1. Register() records a deprecated alias with its replacement.
  2. WarnOnce() logs a warning the first time the alias is accessed.
  3. GetMigrationGuide() returns all registered deprecations for documentation.
]]
BETTERUI.CIM.DeprecationRegistry = {
    -- Storage for registered deprecations
    _registry = {},
    -- Track which warnings have been issued (one-time)
    _warned = {},
    -- Whether warnings are enabled (disable for production)
    _enabled = true,
}

--[[
Function: BETTERUI.CIM.DeprecationRegistry.Register
Description: Registers a deprecated API and its replacement.
param: oldName (string) - The deprecated API name.
param: newName (string) - The replacement API name.
param: removeVersion (string|nil) - Version when the old API will be removed.
]]
--- @param oldName string The deprecated API name
--- @param newName string The replacement API name
--- @param removeVersion string|nil Version when the old API will be removed
function BETTERUI.CIM.DeprecationRegistry.Register(oldName, newName, removeVersion)
    BETTERUI.CIM.DeprecationRegistry._registry[oldName] = {
        oldName = oldName,
        newName = newName,
        removeVersion = removeVersion or "future",
        registeredAt = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0,
    }
end

--[[
Function: BETTERUI.CIM.DeprecationRegistry.WarnOnce
Description: Issues a one-time deprecation warning in debug output.
param: oldName (string) - The deprecated API name.
return: boolean - True if warning was issued, false if already warned.
]]
--- @param oldName string The deprecated API name
--- @return boolean warned True if warning was issued
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

--[[
Function: BETTERUI.CIM.DeprecationRegistry.SetEnabled
Description: Enables or disables deprecation warnings.
param: enabled (boolean) - Whether to enable warnings.
]]
--- @param enabled boolean Whether to enable warnings
function BETTERUI.CIM.DeprecationRegistry.SetEnabled(enabled)
    BETTERUI.CIM.DeprecationRegistry._enabled = enabled
end

--[[
Function: BETTERUI.CIM.DeprecationRegistry.GetAll
Description: Returns all registered deprecations for documentation.
return: table - Array of deprecation info tables.
]]
--- @return table deprecations Array of deprecation info
function BETTERUI.CIM.DeprecationRegistry.GetAll()
    local result = {}
    for _, info in pairs(BETTERUI.CIM.DeprecationRegistry._registry) do
        table.insert(result, info)
    end
    return result
end

--[[
Function: BETTERUI.CIM.DeprecationRegistry.CreateShim
Description: Creates a wrapper function that warns on use and delegates to replacement.
param: oldName (string) - The deprecated function name.
param: newFn (function) - The replacement function.
return: function - A wrapper that warns once then calls newFn.
]]
--- @param oldName string The deprecated function name
--- @param newFn function The replacement function
--- @return function shim Wrapper that warns and delegates
function BETTERUI.CIM.DeprecationRegistry.CreateShim(oldName, newFn)
    return function(...)
        BETTERUI.CIM.DeprecationRegistry.WarnOnce(oldName)
        return newFn(...)
    end
end

-- ============================================================================
-- REGISTER KNOWN DEPRECATIONS
-- Add entries here as APIs are deprecated
-- ============================================================================

-- Example registrations (uncomment when deprecating):
-- BETTERUI.CIM.DeprecationRegistry.Register("BETTERUI_OLD_CONSTANT", "BETTERUI.CIM.CONST.NEW_CONSTANT", "v3.1")
