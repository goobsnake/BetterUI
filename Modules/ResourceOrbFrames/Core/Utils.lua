--[[
File: Modules/ResourceOrbFrames/Core/Utils.lua
Purpose: Centralized utilities for the Resource Orb Frames module, resolving duplicates.
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

Utils.FindControl = BETTERUI.ControlUtils.FindControl

--- Module settings accessor alias for brevity in ResourceOrbFrames code.
function Utils.GetSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

--- Attaches a tooltip to an orb control showing current/max resource power.
--- Shared utility to eliminate duplication between OrbOverlays and OrbVisuals.
function Utils.AddOrbTooltip(control, powerType)
    if not control then return end
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, RIGHT, -5, 0)
        local current, max = GetUnitPower("player", powerType)
        SetTooltipText(InformationTooltip, string.format("%d / %d", current, max))
    end)
    control:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

--- Calculates border sizes for left/right orbs based on hide state and scaling.
--- Shared utility to eliminate duplication between OrbOverlays and OrbVisuals.
function Utils.CalculateBorderSizes(cfg, settings)
    local hideLeft = settings.hideLeftOrnament or false
    local hideRight = settings.hideRightOrnament or false
    local leftSize = cfg.orbs.left.borderSize
    local rightSize = cfg.orbs.right.borderSize
    local leftVisibleScale = cfg.orbs.left.visibleScale or 1.0
    local rightVisibleScale = cfg.orbs.right.visibleScale or 1.0

    if hideLeft then
        leftSize = leftSize * (settings.leftOrbSizeScale or 1.0)
    else
        leftSize = leftSize * leftVisibleScale
    end

    if hideRight then
        rightSize = rightSize * (settings.rightOrbSizeScale or 1.0)
    else
        rightSize = rightSize * rightVisibleScale
    end

    return leftSize, rightSize, leftVisibleScale, rightVisibleScale
end

--- Scales a positional value relative to a border size ratio.
function Utils.ScaleForBorder(value, borderSize, baseBorderSize)
    if type(value) ~= "number" then
        return 0
    end
    if type(baseBorderSize) ~= "number" or baseBorderSize <= 0 then
        return value
    end
    return value * (borderSize / baseBorderSize)
end

--- Calculates fill dimensions for all orb resource types.
function Utils.CalculateFillDimensions(cfg, leftBorderSize, rightBorderSize)
    local leftBaseSize = cfg.orbs.left.borderSize or leftBorderSize
    local rightBaseSize = cfg.orbs.right.borderSize or rightBorderSize
    local ScaleForBorder = Utils.ScaleForBorder

    return {
        health = {
            width = math.min(leftBorderSize * cfg.fills.health.scaleW, leftBorderSize),
            height = math.min(leftBorderSize * cfg.fills.health.scaleH, leftBorderSize),
            x = ScaleForBorder(cfg.fills.health.x, leftBorderSize, leftBaseSize),
            y = ScaleForBorder(cfg.fills.health.y, leftBorderSize, leftBaseSize)
        },
        shield = (function()
            local ringSize = leftBorderSize * (cfg.fills.shield.ringScale or 1.2)
            return {
                width = math.min(ringSize * cfg.fills.shield.scaleW, ringSize),
                height = math.min(ringSize * cfg.fills.shield.scaleH, ringSize),
                x = ScaleForBorder(cfg.fills.shield.x, leftBorderSize, leftBaseSize),
                y = ScaleForBorder(cfg.fills.shield.y, leftBorderSize, leftBaseSize)
            }
        end)(),
        magicka = {
            width = math.min(rightBorderSize * cfg.fills.magicka.scaleW, rightBorderSize),
            height = math.min(rightBorderSize * cfg.fills.magicka.scaleH, rightBorderSize),
            x = ScaleForBorder(cfg.fills.magicka.x, rightBorderSize, rightBaseSize),
            y = ScaleForBorder(cfg.fills.magicka.y, rightBorderSize, rightBaseSize)
        },
        stamina = {
            width = math.min(rightBorderSize * cfg.fills.stamina.scaleW, rightBorderSize),
            height = math.min(rightBorderSize * cfg.fills.stamina.scaleH, rightBorderSize),
            x = ScaleForBorder(cfg.fills.stamina.x, rightBorderSize, rightBaseSize),
            y = ScaleForBorder(cfg.fills.stamina.y, rightBorderSize, rightBaseSize)
        },
        resource = {
            width = math.min(rightBorderSize * cfg.fills.resource.scaleW, rightBorderSize),
            height = math.min(rightBorderSize * cfg.fills.resource.scaleH, rightBorderSize)
        }
    }
end

--- Updates the dimensions and anchor of a custom overlay control.
function Utils.UpdateOverlaySize(parent, cfgName, baseSize, cfg)
    if not parent then return end
    local overlayName = parent:GetName() .. "CustomOverlay"
    local overlay = _G[overlayName]
    if overlay and not overlay:IsHidden() then
        local overlayCfg = cfg.overlays and cfg.overlays[cfgName]
        local scale = overlayCfg and overlayCfg.scale or 1.0
        local size = baseSize * scale
        overlay:SetDimensions(size, size)
        overlay:SetAnchor(CENTER, parent, CENTER, overlayCfg and overlayCfg.x or 0, overlayCfg and overlayCfg.y or 0)
    end
end

--- Safely gets a named child control from a parent.
function Utils.GetNamedChildDirect(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

--- Gets a front bar button control with fallback resolution for special buttons.
function Utils.GetFrontBarButtonControl(rootFrame, frontBarContainer, buttonName)
    local GetNamedChildDirect = Utils.GetNamedChildDirect
    local FindControl = Utils.FindControl
    if buttonName == "QuickslotButton" or buttonName == "CompanionButton" then
        return GetNamedChildDirect(rootFrame, buttonName)
            or GetNamedChildDirect(frontBarContainer, buttonName)
            or FindControl(rootFrame, buttonName)
            or FindControl(frontBarContainer, buttonName)
    end
    return GetNamedChildDirect(frontBarContainer, buttonName)
        or FindControl(frontBarContainer, buttonName)
end
