--[[
File: Modules/CIM/Core/DeveloperDebug.lua
Purpose: Consolidated developer debug module for BetterUI.
         Provides diagnostic commands, debug flags, and development utilities.
         DISABLED BY DEFAULT - Enable via DEBUG_LOGGING feature flag or BETTERUI_DEBUG global.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Debug = {}

-- Set to true during development to expose developer-only settings in LAM.
-- This is intentionally false for normal users.
BETTERUI.CIM.Debug.SHOW_DEVELOPER_SETTINGS = false

-- DEBUG FLAGS

--[[
Table: BETTERUI.CIM.Debug.FLAGS
Sub-flags for specific debug features.
Used By: ResourceOrbFrames, Inventory, Banking modules.
]]
BETTERUI.CIM.Debug.FLAGS = {
    SHIELD_OVERLAY = false,    -- Show shield overlay ring for visual debugging
    DIRECTIONAL_INPUT = false, -- Verbose DIRECTIONAL_INPUT logging
    SCENE_TRANSITIONS = false, -- Log scene state changes
    LIST_OPERATIONS = false,   -- Log list activation/deactivation
    CALLBACK_TRACING = false,  -- Log SafeExecuteCallback lifecycle
}

-- CORE API

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
function BETTERUI.CIM.Debug.ShouldShowDeveloperSettings()
    if BETTERUI_DEBUG then
        return true
    end
    return BETTERUI.CIM.Debug.SHOW_DEVELOPER_SETTINGS == true
end

function BETTERUI.CIM.Debug.Log(message, category)
    if not BETTERUI.CIM.Debug.IsEnabled() then return end

    local prefix = category and string.format("[%s] ", category) or ""
    BETTERUI.Debug(prefix .. message)
end

function BETTERUI.CIM.Debug.SetFlag(flagName, enabled)
    if BETTERUI.CIM.Debug.FLAGS[flagName] ~= nil then
        BETTERUI.CIM.Debug.FLAGS[flagName] = enabled
        BETTERUI.CIM.Debug.Log(string.format("Flag %s set to %s", flagName, tostring(enabled)), "Debug")
    end
end

-- INITIALIZATION

-- Sync SHIELD_OVERLAY debug flag from FeatureFlags system
if BETTERUI.CIM.FeatureFlags and BETTERUI.CIM.FeatureFlags.IsEnabled then
    BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY = BETTERUI.CIM.FeatureFlags.IsEnabled("SHIELD_DEBUG")
end
-- Backward compatibility: honor legacy BETTERUI_SHIELD_DEBUG global if set
if BETTERUI_SHIELD_DEBUG then
    BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY = true
end

