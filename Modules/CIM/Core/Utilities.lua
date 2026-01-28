--[[
File: Modules/CIM/Core/Utilities.lua
Purpose: Core utility functions for the BetterUI addon.
         Provides debug logging, module status checks, and icon safety wrappers.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-- ============================================================================
-- DEBUG LOGGING
-- ============================================================================

--[[
Function: BETTERUI.Debug
Description: Prints a debug message to chat with BetterUI prefix.
Rationale: Standardized debug logging for development.
Mechanism: Prefixes the message with cyan [BETTERUI] tag and prints to chat.
References: Used globally throughout the addon for debug logging.
param: str (string) - The message string to display.
]]
function BETTERUI.Debug(str)
    return d("|c0066ff[BETTERUI]|r " .. str)
end

-- ============================================================================
-- MODULE STATUS
-- ============================================================================

--[[
Function: BETTERUI.GetModuleEnabled
Description: Checks if a specific BetterUI module is enabled.
Rationale: Handles potential inconsistency between 'm_enabled' and 'enabled' setting keys.
Mechanism: Checks saved settings for the module's enabled state.
References: Used during module initialization to check if module should load.
param: moduleName (string) - The key of the module in BETTERUI.Settings.Modules.
return: boolean - True if the module is enabled.
]]
function BETTERUI.GetModuleEnabled(moduleName)
    if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return false end
    local settings = BETTERUI.Settings.Modules[moduleName]
    if not settings then return false end

    -- Check standard key first
    if settings.m_enabled ~= nil then
        return settings.m_enabled
    end
    -- Fallback to legacy key
    if settings.enabled ~= nil then
        return settings.enabled
    end

    return false
end

-- ============================================================================
-- ICON UTILITIES
-- ============================================================================

--[[
Function: BETTERUI.SafeIcon
Description: Safely returns an icon path string.
Rationale: Prevents crashes or errors when passing nil icon paths to ESO API functions.
Mechanism: Checks if iconPath is nil; returns empty string if so, otherwise returns original path.
References: Used by Inventory, Banking, and Writ lists to ensure icon validity.
param: iconPath (string|nil) - The path to the icon texture.
return: string - The icon path or an empty string.
]]
function BETTERUI.SafeIcon(iconPath)
    if iconPath == nil then return "" end
    return iconPath
end
