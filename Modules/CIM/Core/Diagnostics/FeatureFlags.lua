--[[
File: Modules/CIM/Core/Diagnostics/FeatureFlags.lua
Purpose: Runtime feature flag system for BetterUI.
         Enables gradual rollout, A/B testing, and safe feature toggling.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.FeatureFlags = {}

-- FEATURE FLAG DEFINITIONS

-- Feature flag definition type is defined in Types.lua as FeatureFlagDefinition

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
    SHIELD_DEBUG = {
        name = "SHIELD_DEBUG",
        description = "Visual debugging of shield overlays on resource orbs",
        defaultEnabled = false,
        version = "3.0",
    },
}

-- Runtime flag state cache
local flagStateCache = {}
local flagOverrides = {}

-- Drop BETTERUI.Log's memoized active-state whenever a flag that can flip the
-- logger's active decision (e.g. DEBUG_LOGGING gates CIM.Debug.IsEnabled) changes
-- at runtime, so a toggle takes effect on the next log call.
local function InvalidateLogActive()
    if BETTERUI.Log and BETTERUI.Log.InvalidateActive then
        BETTERUI.Log.InvalidateActive()
    end
end

local function CloneDefinition(def)
    if type(def) ~= "table" then
        return def
    end

    local clone = {}
    for key, value in pairs(def) do
        clone[key] = value
    end
    return clone
end

-- CORE API

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
    local savedSettings = BETTERUI.Settings
    local settings = savedSettings and savedSettings.FeatureFlags
    if settings and settings[flagName] ~= nil then
        flagStateCache[flagName] = settings[flagName]
        return settings[flagName]
    end

    -- Fall back to default
    local def = FLAG_DEFINITIONS[flagName]
    if def then
        -- Do not cache before SavedVars load (BETTERUI.Settings == nil),
        -- otherwise persisted flag values would be masked for the session.
        if savedSettings ~= nil then
            flagStateCache[flagName] = def.defaultEnabled
        end
        return def.defaultEnabled
    end

    -- Unknown flag - disabled by default
    return false
end

function BETTERUI.CIM.FeatureFlags.SetEnabled(flagName, enabled)
    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.FeatureFlags = BETTERUI.Settings.FeatureFlags or {}
    BETTERUI.Settings.FeatureFlags[flagName] = enabled
    flagStateCache[flagName] = nil -- Clear cache to force re-read
    InvalidateLogActive()
end

--- Clears the runtime flag cache so persisted values are re-read.
--- Called by RuntimeSetup.Apply right after SavedVars load.
function BETTERUI.CIM.FeatureFlags.InvalidateCache()
    flagStateCache = {}
    InvalidateLogActive()
end

function BETTERUI.CIM.FeatureFlags.SetOverride(flagName, enabled)
    flagOverrides[flagName] = enabled
    InvalidateLogActive()
end

--[[
Function: BETTERUI.CIM.FeatureFlags.ClearOverrides
Clears all runtime feature flag overrides.
References: Called when exiting debug mode.
]]
function BETTERUI.CIM.FeatureFlags.ClearOverrides()
    flagOverrides = {}
    InvalidateLogActive()
end

function BETTERUI.CIM.FeatureFlags.GetAllFlags()
    local result = {}
    for name, def in pairs(FLAG_DEFINITIONS) do
        result[name] = {
            definition = CloneDefinition(def),
            enabled = BETTERUI.CIM.FeatureFlags.IsEnabled(name),
        }
    end
    return result
end

--[[
Function: BETTERUI.CIM.FeatureFlags.ResetToDefaults
Resets all feature flags to their default states.
]]
function BETTERUI.CIM.FeatureFlags.ResetToDefaults()
    if BETTERUI.Settings then
        BETTERUI.Settings.FeatureFlags = {}
    end
    flagStateCache = {}
    flagOverrides = {}
    InvalidateLogActive()
end

-- CONVENIENCE CONSTANTS

-- Expose flag names as constants for type safety
BETTERUI.CIM.FeatureFlags.FLAGS = {
    ENHANCED_TOOLTIPS = "ENHANCED_TOOLTIPS",
    POSITION_PERSISTENCE = "POSITION_PERSISTENCE",
    BATCH_PROCESSING = "BATCH_PROCESSING",
    DEBUG_LOGGING = "DEBUG_LOGGING",
    PERFORMANCE_METRICS = "PERFORMANCE_METRICS",
    SHIELD_DEBUG = "SHIELD_DEBUG",
}
