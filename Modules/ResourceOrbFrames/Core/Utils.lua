--[[
File: Modules/ResourceOrbFrames/Core/Utils.lua
Purpose: Centralized utilities for the Resource Orb Frames module, resolving duplicates.
Author: BetterUI Team
Last Modified: 2026-03-09
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Utils then BETTERUI.ResourceOrbFrames.Utils = {} end

local Utils = BETTERUI.ResourceOrbFrames.Utils

function Utils.ClampTextSize(value, minValue, maxValue, fallback)
    local numeric = tonumber(value)
    if not numeric then
        return fallback
    end
    local rounded = math.floor(numeric + 0.5)
    if rounded < minValue then
        return minValue
    end
    if rounded > maxValue then
        return maxValue
    end
    return rounded
end

function Utils.FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

function Utils.GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end
