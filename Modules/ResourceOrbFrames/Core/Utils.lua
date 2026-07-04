--[[
File: Modules/ResourceOrbFrames/Core/Utils.lua
Purpose: Centralized utilities for the Resource Orb Frames module, resolving duplicates.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Utils then BETTERUI.ResourceOrbFrames.Utils = {} end

local Utils = BETTERUI.ResourceOrbFrames.Utils
Utils.Settings = Utils.Settings or {}
Utils.Layout = Utils.Layout or {}
Utils.Controls = Utils.Controls or {}
Utils.Tooltips = Utils.Tooltips or {}

local Settings = Utils.Settings
local Layout = Utils.Layout
local Controls = Utils.Controls
local Tooltips = Utils.Tooltips

---@param value any Value to clamp (converted via tonumber)
---@param minValue number Minimum allowed text size
---@param maxValue number Maximum allowed text size
---@param fallback number Value returned when input is not a number
---@return number size Clamped and rounded text size
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

Controls.Find = BETTERUI.ControlUtils.FindControl
Controls.FindOptional = BETTERUI.ControlUtils.FindOptionalControl

--- Module settings snapshot accessor for brevity in ResourceOrbFrames code.
---@return table settings Detached module settings snapshot
function Settings.Get()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

---@return table settings Live module settings table
function Settings.GetLive()
    return BETTERUI.GetModuleSettingsLive("ResourceOrbFrames")
end

---@return table settings Module settings table, creating it if needed
function Settings.Ensure()
    return BETTERUI.EnsureModuleSettings("ResourceOrbFrames")
end

---@return table|nil settings Custom front bar settings table, or nil when unavailable
function Settings.GetCustomFrontBar()
    local settings = Settings.Get()
    return settings and settings.customFrontBar
end

local function InstallPostHookHandler(control, handlerName, hookFn, hookedField)
    if not control or control[hookedField] then return end

    local installed = false
    if type(ZO_PostHookHandler) == "function" then
        ZO_PostHookHandler(control, handlerName, hookFn)
        installed = true
    elseif type(control.SetHandler) == "function" then
        local previousHandler = control.GetHandler and control:GetHandler(handlerName) or nil
        control:SetHandler(handlerName, function(...)
            if type(previousHandler) == "function" then
                previousHandler(...)
            end
            hookFn(...)
        end)
        installed = true
    end

    if installed then
        control[hookedField] = true
    end
end

--- Attaches a tooltip to an orb control showing current/max resource power.
---@param control table|nil UI control to attach tooltip handlers to
---@param powerType number ESO POWERTYPE_* constant
function Tooltips.AddOrbTooltip(control, powerType)
    if not control then return end
    control:SetMouseEnabled(true)
    control._betteruiOrbTooltipPowerType = powerType

    InstallPostHookHandler(control, "OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, RIGHT, -5, 0)
        local current, max = GetUnitPower("player", self._betteruiOrbTooltipPowerType or powerType)
        SetTooltipText(InformationTooltip, string.format("%d / %d", current, max))
    end, "_betteruiOrbTooltipEnterHooked")

    InstallPostHookHandler(control, "OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end, "_betteruiOrbTooltipExitHooked")
end

--- Calculates border sizes for left/right orbs based on hide state and scaling.
---@param cfg table Orb frames configuration table (BETTERUI_ORB_FRAMES)
---@param settings table Module settings from saved variables
---@return number leftSize Computed left orb border size
---@return number rightSize Computed right orb border size
---@return number leftVisibleScale Left orb visible scale factor
---@return number rightVisibleScale Right orb visible scale factor
function Layout.CalculateBorderSizes(cfg, settings)
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
---@param value number|any Value to scale
---@param borderSize number Current border size
---@param baseBorderSize number Reference border size for ratio calculation
---@return number scaled Scaled value (0 if input is not a number)
function Layout.ScaleForBorder(value, borderSize, baseBorderSize)
    if type(value) ~= "number" then
        return 0
    end
    if type(baseBorderSize) ~= "number" or baseBorderSize <= 0 then
        return value
    end
    return value * (borderSize / baseBorderSize)
end

--- Calculates fill dimensions for all orb resource types.
---@param cfg table Orb frames configuration table
---@param leftBorderSize number Computed left orb border size
---@param rightBorderSize number Computed right orb border size
---@return table fills Table with health/shield/magicka/stamina/resource dimension entries
function Layout.CalculateFillDimensions(cfg, leftBorderSize, rightBorderSize)
    local leftBaseSize = cfg.orbs.left.borderSize or leftBorderSize
    local rightBaseSize = cfg.orbs.right.borderSize or rightBorderSize
    local ScaleForBorder = Layout.ScaleForBorder

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

--- Safely gets a named child control from a parent.
---@param parent table|nil Parent UI control with GetNamedChild method
---@param name string Child control name suffix
---@return table|nil child The child control, or nil
function Controls.GetNamedChildDirect(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

--- Gets a front bar button control with fallback resolution for special buttons.
---@param rootFrame table Root ResourceOrbFrames control
---@param frontBarContainer table Front bar container control
---@param buttonName string Button name to resolve (e.g. "QuickslotButton")
---@return table|nil control The resolved button control, or nil
function Controls.GetFrontBarButtonControl(rootFrame, frontBarContainer, buttonName)
    local GetNamedChildDirect = Controls.GetNamedChildDirect
    local FindControl = Controls.Find
    if buttonName == "QuickslotButton" or buttonName == "CompanionButton" then
        return GetNamedChildDirect(rootFrame, buttonName)
            or GetNamedChildDirect(frontBarContainer, buttonName)
            or FindControl(rootFrame, buttonName)
            or FindControl(frontBarContainer, buttonName)
    end
    return GetNamedChildDirect(frontBarContainer, buttonName)
        or FindControl(frontBarContainer, buttonName)
end

Utils.FindControl = Controls.Find
Utils.GetSettings = Settings.Get
Utils.GetSettingsLive = Settings.GetLive
Utils.GetCustomFrontBar = Settings.GetCustomFrontBar
Utils.AddOrbTooltip = Tooltips.AddOrbTooltip
Utils.CalculateBorderSizes = Layout.CalculateBorderSizes
Utils.ScaleForBorder = Layout.ScaleForBorder
Utils.CalculateFillDimensions = Layout.CalculateFillDimensions
Utils.GetNamedChildDirect = Controls.GetNamedChildDirect
Utils.GetFrontBarButtonControl = Controls.GetFrontBarButtonControl

--- Current scene name via the shared CIM utility (BUI-CONS-003 re-export). Keeps
--- the ROF module's dependency on CIM narrow to this one file.
---@return string|nil sceneName
function Utils.GetCurrentSceneName()
    local cim = BETTERUI.CIM and BETTERUI.CIM.Utils
    return cim and cim.GetCurrentSceneName and cim.GetCurrentSceneName() or nil
end

-- Shared element-drag tracer (BUI-CONS-002). Single definition consumed by
-- ElementDrag, SettingsSubmenus, ResourceOrbFrames, and Module, replacing four
-- byte-identical hand-rolled copies. Category matches the prior wrappers (STATE,
-- GENERAL fallback). Drag deltas fire at high frequency, so last-action tagging
-- stays off as before.
Utils.TraceDrag = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{
        module = "ResourceOrbFrames",
        feature = "element-drag",
        category = (BETTERUI.Log.CATEGORY or {}).STATE or "STATE",
        setLastAction = false,
    }
    or function() end
