--[[
File: Modules/CIM/Core/DeveloperDebug.lua
Purpose: Consolidated developer debug module for BetterUI.
         Provides diagnostic commands, debug flags, and development utilities.
         DISABLED BY DEFAULT - Enable via DEBUG_LOGGING feature flag or BETTERUI_DEBUG global.
Author: BetterUI Team
Last Modified: 2026-02-08
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Debug = {}

-- Set to true during development to expose developer-only settings in LAM.
-- This is intentionally false for normal users.
BETTERUI.CIM.Debug.SHOW_DEVELOPER_SETTINGS = false

-- ============================================================================
-- DEBUG FLAGS
-- ============================================================================

--[[
Table: BETTERUI.CIM.Debug.FLAGS
Description: Sub-flags for specific debug features.
Rationale: Allows granular control over which debug visualizations are active.
Used By: ResourceOrbFrames, Inventory, Banking modules.
]]
BETTERUI.CIM.Debug.FLAGS = {
    SHIELD_OVERLAY = false,    -- Show shield overlay ring for visual debugging
    DIRECTIONAL_INPUT = false, -- Verbose DIRECTIONAL_INPUT logging
    SCENE_TRANSITIONS = false, -- Log scene state changes
    LIST_OPERATIONS = false,   -- Log list activation/deactivation
    CALLBACK_TRACING = false,  -- Log SafeExecuteCallback lifecycle
}

-- ============================================================================
-- CORE API
-- ============================================================================

--[[
Function: BETTERUI.CIM.Debug.IsEnabled
Description: Checks if debug mode is enabled.
Rationale: Single point of control for all debug features.
Mechanism: Checks FeatureFlags.DEBUG_LOGGING OR global BETTERUI_DEBUG.
References: Called by all debug utilities before executing.
]]
--- @return boolean enabled True if debug mode is active
function BETTERUI.CIM.Debug.IsEnabled()
    -- Check global flag first (backward compatibility)
    if BETTERUI_DEBUG then
        return true
    end

    -- Check FeatureFlags system
    if BETTERUI.CIM.FeatureFlags and BETTERUI.CIM.FeatureFlags.IsEnabled then
        return BETTERUI.CIM.FeatureFlags.IsEnabled("DEBUG_LOGGING")
    end

    return false
end

--- Returns whether developer-only settings should be visible in LAM.
--- Developers can enable this by setting SHOW_DEVELOPER_SETTINGS = true above.
--- @return boolean show True when developer settings should be shown
function BETTERUI.CIM.Debug.ShouldShowDeveloperSettings()
    if BETTERUI_DEBUG then
        return true
    end
    return BETTERUI.CIM.Debug.SHOW_DEVELOPER_SETTINGS == true
end

--[[
Function: BETTERUI.CIM.Debug.Log
Description: Conditional debug logging that respects debug mode state.
Rationale: Wrapper for BETTERUI.Debug that only outputs when debug is enabled.
Mechanism: Checks IsEnabled before printing.
References: Used throughout codebase for development logging.
]]
--- @param message string The message to log
--- @param category? string Optional category prefix (e.g., "Scene", "List")
function BETTERUI.CIM.Debug.Log(message, category)
    if not BETTERUI.CIM.Debug.IsEnabled() then return end

    local prefix = category and string.format("[%s] ", category) or ""
    BETTERUI.Debug(prefix .. message)
end

--[[
Function: BETTERUI.CIM.Debug.SetFlag
Description: Sets a debug sub-flag.
Rationale: Runtime toggling of specific debug features.
]]
--- @param flagName string The flag name from FLAGS table
--- @param enabled boolean The new state
function BETTERUI.CIM.Debug.SetFlag(flagName, enabled)
    if BETTERUI.CIM.Debug.FLAGS[flagName] ~= nil then
        BETTERUI.CIM.Debug.FLAGS[flagName] = enabled
        BETTERUI.CIM.Debug.Log(string.format("Flag %s set to %s", flagName, tostring(enabled)), "Debug")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Sync SHIELD_OVERLAY debug flag from FeatureFlags system
if BETTERUI.CIM.FeatureFlags and BETTERUI.CIM.FeatureFlags.IsEnabled then
    BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY = BETTERUI.CIM.FeatureFlags.IsEnabled("SHIELD_DEBUG")
end
-- Backward compatibility: honor legacy BETTERUI_SHIELD_DEBUG global if set
if BETTERUI_SHIELD_DEBUG then
    BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY = true
end

