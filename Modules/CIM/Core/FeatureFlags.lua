--[[
File: Modules/CIM/Core/FeatureFlags.lua
Purpose: Runtime feature flag system for BetterUI.
         Enables gradual rollout, A/B testing, and safe feature toggling.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.FeatureFlags = {}

-- ============================================================================
-- FEATURE FLAG DEFINITIONS
-- ============================================================================

-- Feature flag definition type is defined in Types.lua as FeatureFlagDefinition

--- @type table<string, FeatureFlagDefinition>
local FLAG_DEFINITIONS = {
    -- Core Features
    ENHANCED_TOOLTIPS = {
        name = "ENHANCED_TOOLTIPS",
        description = "Enhanced tooltip display with trait matching and research status",
        defaultEnabled = true,
        version = "2.0",
    },
    POSITION_PERSISTENCE = {
        name = "POSITION_PERSISTENCE",
        description = "Remember scroll position when returning to lists",
        defaultEnabled = true,
        version = "2.5",
    },
    -- Experimental Features
    BATCH_PROCESSING = {
        name = "BATCH_PROCESSING",
        description = "Process large item lists in batches to prevent UI hangs",
        defaultEnabled = true,
        version = "2.9",
    },
    DEBUG_LOGGING = {
        name = "DEBUG_LOGGING",
        description = "Enable verbose debug logging to chat",
        defaultEnabled = false,
        version = "1.0",
    },
    PERFORMANCE_METRICS = {
        name = "PERFORMANCE_METRICS",
        description = "Track and report performance metrics (dev mode)",
        defaultEnabled = false,
        version = "3.0",
    },
    -- TODO(bug): Duplicate PERFORMANCE_METRICS key was here -- second definition silently overwrote the first in Lua; removed the duplicate
    -- TODO(feature): Add SHIELD_DEBUG flag definition for visual debugging of shield overlays
}

-- Runtime flag state cache
local flagStateCache = {}
local flagOverrides = {}

-- ============================================================================
-- CORE API
-- ============================================================================

--[[
Function: BETTERUI.CIM.FeatureFlags.IsEnabled
Description: Checks if a feature flag is enabled.
Rationale: Single point of control for feature availability.
Mechanism: Checks overrides first, then saved settings, then defaults.
References: Called throughout the addon to gate feature-specific code.
]]
--- @param flagName string The feature flag identifier
--- @return boolean enabled True if the feature is enabled
function BETTERUI.CIM.FeatureFlags.IsEnabled(flagName)
    -- Check runtime override first
    if flagOverrides[flagName] ~= nil then
        return flagOverrides[flagName]
    end

    -- Check cached state
    if flagStateCache[flagName] ~= nil then
        return flagStateCache[flagName]
    end

    -- Check saved settings
    local settings = BETTERUI.Settings and BETTERUI.Settings.FeatureFlags
    if settings and settings[flagName] ~= nil then
        flagStateCache[flagName] = settings[flagName]
        return settings[flagName]
    end

    -- Fall back to default
    local def = FLAG_DEFINITIONS[flagName]
    if def then
        flagStateCache[flagName] = def.defaultEnabled
        return def.defaultEnabled
    end

    -- Unknown flag - disabled by default
    return false
end

--[[
Function: BETTERUI.CIM.FeatureFlags.SetEnabled
Description: Sets a feature flag's enabled state (persisted to saved variables).
Rationale: Allows runtime toggling of features via settings or debug commands.
Mechanism: Updates saved settings and clears cache.
References: Settings panels, debug slash commands.
]]
--- @param flagName string The feature flag identifier
--- @param enabled boolean The new enabled state
function BETTERUI.CIM.FeatureFlags.SetEnabled(flagName, enabled)
    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.FeatureFlags = BETTERUI.Settings.FeatureFlags or {}
    BETTERUI.Settings.FeatureFlags[flagName] = enabled
    flagStateCache[flagName] = nil -- Clear cache to force re-read
end

--[[
Function: BETTERUI.CIM.FeatureFlags.SetOverride
Description: Sets a temporary runtime override for a feature flag.
Rationale: Useful for testing or debug mode without persisting changes.
Mechanism: Stores override in memory-only table.
References: Debug commands, unit tests.
]]
--- @param flagName string The feature flag identifier
--- @param enabled boolean|nil The override state, or nil to clear override
function BETTERUI.CIM.FeatureFlags.SetOverride(flagName, enabled)
    flagOverrides[flagName] = enabled
end

--[[
Function: BETTERUI.CIM.FeatureFlags.ClearOverrides
Description: Clears all runtime feature flag overrides.
Rationale: Reset to saved/default state.
References: Called when exiting debug mode.
]]
function BETTERUI.CIM.FeatureFlags.ClearOverrides()
    flagOverrides = {}
end

--[[
Function: BETTERUI.CIM.FeatureFlags.GetAllFlags
Description: Returns all defined feature flags with their current states.
Rationale: For settings UI and debug display.
]]
--- @return table<string, {definition: FeatureFlagDefinition, enabled: boolean}> flags
function BETTERUI.CIM.FeatureFlags.GetAllFlags()
    local result = {}
    for name, def in pairs(FLAG_DEFINITIONS) do
        result[name] = {
            definition = def,
            enabled = BETTERUI.CIM.FeatureFlags.IsEnabled(name),
        }
    end
    return result
end

--[[
Function: BETTERUI.CIM.FeatureFlags.ResetToDefaults
Description: Resets all feature flags to their default states.
Rationale: Recovery option for corrupted settings.
]]
function BETTERUI.CIM.FeatureFlags.ResetToDefaults()
    if BETTERUI.Settings then
        BETTERUI.Settings.FeatureFlags = {}
    end
    flagStateCache = {}
    flagOverrides = {}
end

-- ============================================================================
-- CONVENIENCE CONSTANTS
-- ============================================================================

-- Expose flag names as constants for type safety
BETTERUI.CIM.FeatureFlags.FLAGS = {
    ENHANCED_TOOLTIPS = "ENHANCED_TOOLTIPS",
    POSITION_PERSISTENCE = "POSITION_PERSISTENCE",
    BATCH_PROCESSING = "BATCH_PROCESSING",
    DEBUG_LOGGING = "DEBUG_LOGGING",
    PERFORMANCE_METRICS = "PERFORMANCE_METRICS",
}
