--[[
File: Modules/CIM/SettingsAccessor.lua
Purpose: Provides safe module settings access with automatic nil-checking.
         Eliminates repetitive nil checks when accessing BETTERUI.Settings.Modules.
Author: BetterUI Team
Last Modified: 2026-01-23
]]

if not BETTERUI then BETTERUI = {} end

--- Gets settings for a module with automatic nil-safety.
--- @param moduleName string The module name (e.g., "Inventory", "ResourceOrbFrames")
--- @param defaults table|nil Optional defaults table to fall back to
--- @return table The module settings or defaults
function BETTERUI.GetModuleSettings(moduleName, defaults)
    if BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules[moduleName] then
        return BETTERUI.Settings.Modules[moduleName]
    end
    return defaults or {}
end

--- Gets a specific setting value with fallback.
--- @param moduleName string The module name
--- @param key string The setting key
--- @param default any The default value
--- @return any The setting value or default
function BETTERUI.GetSetting(moduleName, key, default)
    local settings = BETTERUI.GetModuleSettings(moduleName)
    if settings[key] ~= nil then
        return settings[key]
    end
    return default
end
