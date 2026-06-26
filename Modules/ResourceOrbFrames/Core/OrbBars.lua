--[[
File: Modules/ResourceOrbFrames/OrbBars.lua
Purpose: Implements rectangular bar frames (XP, Cast, Mount Stamina).
         Contains BetterUIBarFrame and its subclasses.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Bars then BETTERUI.ResourceOrbFrames.Bars = {} end

local Bars = BETTERUI.ResourceOrbFrames.Bars
local NAME = "ResourceOrbFrames"
local BARS = BETTERUI.ResourceOrbFrames.CONST.BARS
local XP = BARS.XP
local CAST = BARS.CAST
local MOUNT = BARS.MOUNT
local COST_TYPE_HEALTH = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH
local COST_TYPE_MAGICKA = COMBAT_MECHANIC_FLAGS_MAGICKA or POWERTYPE_MAGICKA
local COST_TYPE_STAMINA = COMBAT_MECHANIC_FLAGS_STAMINA or POWERTYPE_STAMINA
local COST_TYPE_ULTIMATE = COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE

local DEFAULT_CAST_BAR_FILL_STYLE = {
    fill = { 1, 1, 0.4, 1 },
    depth = { 0.45, 0.45, 0.18, 1 },
}
local CAST_BAR_ORB_FILL_STYLES = {
    -- Matches orb Fog/Fog2 colors in ResourceOrbFrames.xml
    health = {
        fill = { 1, 0, 0, 1 },       -- Fog color="ff0000"
        depth = { 0.30196, 0, 0, 1 } -- Fog2 color="4d0000"
    },
    magicka = {
        fill = { 0, 0.4, 1, 1 }, -- Fog color="0066ff"
        depth = { 0, 0, 0.2, 1 } -- Fog2 color="000033"
    },
    stamina = {
        fill = { 0, 1, 0, 1 },       -- Fog color="00ff00"
        depth = { 0, 0.30196, 0, 1 } -- Fog2 color="004d00"
    },
}
local CAST_BAR_POWER_PROBE_WINDOW_MS = 450

-- Compatibility: capture the original hidden state of native ESO cast-bar
-- controls before hiding them, and restore on module disable. The suppression
-- is also gated on the module being enabled so EVENT_PLAYER_ACTIVATED cannot
-- re-hide the controls while the module is turned off.
local m_originalPlayerProgressHidden = nil
local m_originalGamepadProgressHidden = nil
local m_defaultCastBarStateCaptured = false

local function IsCastBarSuppressionEnabled()
    return BETTERUI.ResourceOrbFrames
        and BETTERUI.ResourceOrbFrames.IsEnabled
        and BETTERUI.ResourceOrbFrames.IsEnabled() == true
end

local function TraceCastBar(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "resourceOrbs"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.ACTION, event, phase, data)
end

Bars.TraceCastBar = TraceCastBar

local function TraceMountStamina(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "mountStamina"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.ACTION or categories.STATE, event, phase, data)
end

Bars.TraceMountStamina = TraceMountStamina

local function ResolveTexturePath(filename)
    return string.format("%s/%s", "BetterUI/Modules/ResourceOrbFrames/Textures", filename)
end

local function ResolveBarTexturePath(textureFile)
    if not textureFile then return nil end
    if string.find(textureFile, "/", 1, true) or string.find(textureFile, "\\", 1, true) then
        return textureFile
    end
    return ResolveTexturePath(textureFile)
end

local CloneColor = BETTERUI.CloneColor

local function GetCastBarFillStyle(styleKey)
    local style = CAST_BAR_ORB_FILL_STYLES[styleKey]
    if not style then
        style = DEFAULT_CAST_BAR_FILL_STYLE
    end
    return CloneColor(style.fill), CloneColor(style.depth)
end

local function GetAbilityCostForType(abilityId, costType)
    if type(abilityId) ~= "number" or abilityId <= 0 or type(costType) ~= "number" then
        return 0
    end
    local cost = GetAbilityCost(abilityId, costType, nil, "player")
    if type(cost) ~= "number" then
        return 0
    end
    return cost
end

local function GetSlotCostForType(slotIndex, costType, hotbar)
    if type(slotIndex) ~= "number" or type(costType) ~= "number" then
        return 0
    end
    local cost = GetSlotAbilityCost(slotIndex, costType, hotbar)
    if type(cost) ~= "number" then
        return 0
    end
    return cost
end

local function ResolveCastBarFillColor(slotIndex, abilityId, hotbar)
    if type(slotIndex) ~= "number" then
        return GetCastBarFillStyle(nil)
    end

    if ACTION_BAR_ULTIMATE_SLOT_INDEX and slotIndex == (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) then
        return GetCastBarFillStyle(nil)
    end

    if type(abilityId) ~= "number" or abilityId <= 0 then
        return GetCastBarFillStyle(nil)
    end

    -- Match ESOUI tooltip cost classification behavior:
    -- 1) resolve current chained ability id
    -- 2) read mechanic flags via GetAbilityBaseCostInfo
    local costAbilityId = abilityId
    if GetCurrentChainedAbility then
        local chained = GetCurrentChainedAbility(abilityId)
        if type(chained) == "number" and chained > 0 then
            costAbilityId = chained
        end
    end

    local _, mechanicFlags = GetAbilityBaseCostInfo(costAbilityId, nil, "player")
    if type(mechanicFlags) == "number" and mechanicFlags > 0 and ZO_FlagHelpers and ZO_FlagHelpers.MaskHasFlag then
        if ZO_FlagHelpers.MaskHasFlag(mechanicFlags, COST_TYPE_ULTIMATE) then
            return GetCastBarFillStyle(nil)
        end
        if ZO_FlagHelpers.MaskHasFlag(mechanicFlags, COST_TYPE_STAMINA) then
            return GetCastBarFillStyle("stamina")
        end
        if ZO_FlagHelpers.MaskHasFlag(mechanicFlags, COST_TYPE_MAGICKA) then
            return GetCastBarFillStyle("magicka")
        end
        if ZO_FlagHelpers.MaskHasFlag(mechanicFlags, COST_TYPE_HEALTH) then
            return GetCastBarFillStyle("health")
        end
    end

    -- Fallback chain for edge cases where mechanicFlags are unavailable.
    if GetSlotCostForType(slotIndex, COST_TYPE_ULTIMATE, hotbar) > 0 then
        return GetCastBarFillStyle(nil)
    end
    if GetSlotCostForType(slotIndex, COST_TYPE_STAMINA, hotbar) > 0 then
        return GetCastBarFillStyle("stamina")
    end
    if GetSlotCostForType(slotIndex, COST_TYPE_MAGICKA, hotbar) > 0 then
        return GetCastBarFillStyle("magicka")
    end
    if GetSlotCostForType(slotIndex, COST_TYPE_HEALTH, hotbar) > 0 then
        return GetCastBarFillStyle("health")
    end

    if GetAbilityCostForType(costAbilityId, COST_TYPE_ULTIMATE) > 0 then
        return GetCastBarFillStyle(nil)
    end
    if GetAbilityCostForType(costAbilityId, COST_TYPE_STAMINA) > 0 then
        return GetCastBarFillStyle("stamina")
    end
    if GetAbilityCostForType(costAbilityId, COST_TYPE_MAGICKA) > 0 then
        return GetCastBarFillStyle("magicka")
    end
    if GetAbilityCostForType(costAbilityId, COST_TYPE_HEALTH) > 0 then
        return GetCastBarFillStyle("health")
    end

    return GetCastBarFillStyle(nil)
end

local function ResolveCastBarFillColorByPowerType(powerType)
    if powerType == COST_TYPE_STAMINA then
        return GetCastBarFillStyle("stamina")
    end
    if powerType == COST_TYPE_MAGICKA then
        return GetCastBarFillStyle("magicka")
    end
    if powerType == COST_TYPE_HEALTH then
        return GetCastBarFillStyle("health")
    end
    return nil, nil
end

---@class BetterUIBarFrame : ZO_Object
---@field control table UI control
---@field fill table Fill texture control
---@field backdrop table Backdrop texture control
---@field label table Label control
---@field backdropTextureFile string Backdrop texture path
---@field fillTextureFile string Fill texture path
---@field backdropTextureBounds table|nil Texture coordinate bounds
---@field fillRegion table|nil Normalized fill region {left, right, top, bottom}
BetterUIBarFrame = ZO_Object:Subclass()

---@param control table UI control to wrap
---@return BetterUIBarFrame
function BetterUIBarFrame:New(control)
    local obj = ZO_Object.New(self)
    -- Assign to instance, not class prototype
    obj.control = control
    return obj
end

---@param name string Control name
---@param parent table Parent control
---@param backdropTextureFile string|nil Backdrop texture filename
---@param fillTextureFile string|nil Fill texture filename
---@param backdropTextureBounds table|nil Texture coordinate bounds
---@param fillRegion table|nil Normalized fill region {left, right, top, bottom}
---@return table control The created control
function BetterUIBarFrame:Initialize(name, parent, backdropTextureFile, fillTextureFile, backdropTextureBounds,
                                     fillRegion)
    -- Reuse existing named controls so a retried module setup (idempotent
    -- SetupModule) does not attempt to create duplicate global control names.
    local control = _G[name] or WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    self.control = control
    self.backdropTextureFile = backdropTextureFile or "Bar.dds"
    self.fillTextureFile = fillTextureFile or BARS.FILL_TEXTURE or
        "esoui/art/miscellaneous/progressbar_genericfill_gloss.dds"
    self.backdropTextureBounds = backdropTextureBounds
    self.fillRegion = fillRegion

    local fill = _G[name .. "Fill"] or WINDOW_MANAGER:CreateControl(name .. "Fill", control, CT_TEXTURE)
    fill:SetTexture(ResolveBarTexturePath(self.fillTextureFile))
    fill:SetAnchor(LEFT, control, LEFT, 0, 0)
    self.fill = fill

    local backdrop = _G[name .. "Backdrop"] or WINDOW_MANAGER:CreateControl(name .. "Backdrop", control, CT_TEXTURE)
    backdrop:SetTexture(ResolveBarTexturePath(self.backdropTextureFile))
    backdrop:SetAnchor(CENTER, control, CENTER, 0, 0)
    self.backdrop = backdrop

    local label = _G[name .. "Label"] or WINDOW_MANAGER:CreateControl(name .. "Label", control, CT_LABEL)
    label:SetAnchor(CENTER, control, CENTER, 0, 4)
    label:SetFont("$(BOLD_FONT)|18|thick-outline")
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.label = label

    return control
end

---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a number Alpha (0-1)
function BetterUIBarFrame:SetColor(r, g, b, a)
    if self.fill then self.fill:SetColor(r, g, b, a) end
end

local function IsValidRegion(region)
    return type(region) == "table"
        and type(region.left) == "number"
        and type(region.right) == "number"
        and type(region.top) == "number"
        and type(region.bottom) == "number"
end

---@param barWidth number Total bar width
---@param barHeight number Total bar height
---@param extraOffsetX number|nil Additional X offset
---@param extraOffsetY number|nil Additional Y offset
---@return number offsetX, number offsetY Label anchor offsets
function BetterUIBarFrame:GetLabelAnchorOffsets(barWidth, barHeight, extraOffsetX, extraOffsetY)
    local offsetX = extraOffsetX or 0
    local offsetY = extraOffsetY or 0

    if IsValidRegion(self.fillRegion) then
        local regionCenterX = (self.fillRegion.left + self.fillRegion.right) * 0.5
        local regionCenterY = (self.fillRegion.top + self.fillRegion.bottom) * 0.5
        offsetX = offsetX + ((regionCenterX - 0.5) * barWidth)
        offsetY = offsetY + ((regionCenterY - 0.5) * barHeight)
    end

    return offsetX, offsetY
end

---@param current number Current value
---@param max number Maximum value
---@param insetX number Horizontal fill inset
---@param insetY number Vertical fill inset
---@param barWidth number Total bar width
---@param barHeight number Total bar height
function BetterUIBarFrame:UpdateVisuals(current, max, insetX, insetY, barWidth, barHeight)
    if not self.control or self.control:IsHidden() then return end

    -- Static backdrop/fill state (textures, coords, anchors) only depends on
    -- bar geometry, which is constant between layout changes. Latch it so the
    -- per-frame OnUpdate path only touches the dynamic fill dimensions.
    if self.appliedBarWidth ~= barWidth or self.appliedBarHeight ~= barHeight
        or self.appliedInsetX ~= insetX or self.appliedInsetY ~= insetY then
        self.appliedBarWidth, self.appliedBarHeight = barWidth, barHeight
        self.appliedInsetX, self.appliedInsetY = insetX, insetY

        if self.backdrop then
            self.backdrop:SetTexture(ResolveBarTexturePath(self.backdropTextureFile))
            self.backdrop:SetDimensions(barWidth, barHeight)
            if IsValidRegion(self.backdropTextureBounds) then
                self.backdrop:SetTextureCoords(
                    self.backdropTextureBounds.left,
                    self.backdropTextureBounds.right,
                    self.backdropTextureBounds.top,
                    self.backdropTextureBounds.bottom)
            else
                self.backdrop:SetTextureCoords(0, 1, 0, 1)
            end
        end

        if self.fill then
            self.fill:SetTexture(ResolveBarTexturePath(self.fillTextureFile))
            self.fill:ClearAnchors()
            if IsValidRegion(self.fillRegion) then
                self.fill:SetAnchor(TOPLEFT, self.control, TOPLEFT,
                    barWidth * self.fillRegion.left,
                    barHeight * self.fillRegion.top)
            else
                self.fill:SetAnchor(LEFT, self.control, LEFT, insetX, 0)
            end
        end
    end

    if self.fill and max > 0 then
        local percent = math.min(1, math.max(0, current / max))
        local fillMaxWidth, fillHeight

        if IsValidRegion(self.fillRegion) then
            local left = barWidth * self.fillRegion.left
            local right = barWidth * self.fillRegion.right
            local top = barHeight * self.fillRegion.top
            local bottom = barHeight * self.fillRegion.bottom
            fillMaxWidth = math.max(1, right - left)
            fillHeight = math.max(1, bottom - top)
        else
            fillMaxWidth = barWidth - (2 * insetX)
            fillHeight = barHeight - (2 * insetY)
        end

        self.fill:SetDimensions(fillMaxWidth * percent, fillHeight)
        self.fill:SetTextureCoords(0, percent, 0, 1)
    end
end

---@class CastBar : BetterUIBarFrame
---@field isCasting boolean Whether a cast is in progress
---@field duration number Cast duration in seconds
---@field postCastHold number Hold time after cast completes
---@field showCountdown boolean Whether to show countdown text
---@field isChanneled boolean Whether the cast is a channeled ability
---@field startTime number Timestamp when cast started
---@field defaultFillColor table Default fill colour {r,g,b,a}
---@field defaultDepthColor table Default depth colour {r,g,b,a}
---@field currentFillColor table Active fill colour {r,g,b,a}
---@field currentDepthColor table Active depth colour {r,g,b,a}
---@field pendingPowerProbeStartMs number Timestamp for power-probe window
---@field lastKnownPowerValues table<number, number> Cached power values by type
local CastBar = BetterUIBarFrame:Subclass()

---@param parent table Parent control
---@return CastBar
function CastBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

---@param parent table Parent control
function CastBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUICastBar", parent,
        CAST.BACKDROP_TEXTURE or "CastBar.dds",
        CAST.FILL_TEXTURE or BARS.FILL_TEXTURE,
        CAST.TEXTURE_BOUNDS,
        CAST.FILL_REGION)
    self.isCasting = false
    self.duration = 0
    self.postCastHold = 0.5
    self.showCountdown = false
    self.isChanneled = false
    self.startTime = 0
    self.defaultFillColor, self.defaultDepthColor = GetCastBarFillStyle(nil)
    self.currentFillColor = CloneColor(self.defaultFillColor, { 1, 1, 0.4, 1 })
    self.currentDepthColor = CloneColor(self.defaultDepthColor, { 0.45, 0.45, 0.18, 1 })
    self.pendingPowerProbeStartMs = 0
    self.lastKnownPowerValues = {
        [COST_TYPE_HEALTH] = select(1, GetUnitPower("player", COST_TYPE_HEALTH)) or 0,
        [COST_TYPE_MAGICKA] = select(1, GetUnitPower("player", COST_TYPE_MAGICKA)) or 0,
        [COST_TYPE_STAMINA] = select(1, GetUnitPower("player", COST_TYPE_STAMINA)) or 0,
    }
    self:ApplyFillStyle(self.currentFillColor, self.currentDepthColor)
    self.label:SetText(GetString(rawget(_G, "SI_BETTERUI_LABEL_CAST_BAR")))

    -- Note: EVENT_SPELL_CASTING_START/STOP don't exist in ESO API.
    -- Casting is tracked via EVENT_ACTION_SLOT_ABILITY_USED below which uses GetAbilityCastInfo().

    local function HideDefaultCastBar()
        -- U50 control names: ZO_PlayerProgress (keyboard) and
        -- ZO_PlayerProgressBar_Gamepad (gamepad). ESO has no default cast bar
        -- control, and PLAYER_PROGRESS_BAR_FRAGMENT is a plain ZO_SceneFragment
        -- without SetHiddenForReason, so hide the top-level controls directly.
        -- Compatibility: only suppress while the module is enabled, and capture
        -- the original hidden state so it can be restored on disable.
        if not IsCastBarSuppressionEnabled() then
            return
        end

        if ZO_PlayerProgress then
            if not m_defaultCastBarStateCaptured then
                local ok, hidden = pcall(function() return ZO_PlayerProgress:IsHidden() end)
                m_originalPlayerProgressHidden = ok and hidden or false
            end
            ZO_PlayerProgress:SetHidden(true)
        end

        if ZO_PlayerProgressBar_Gamepad then
            if not m_defaultCastBarStateCaptured then
                local ok, hidden = pcall(function() return ZO_PlayerProgressBar_Gamepad:IsHidden() end)
                m_originalGamepadProgressHidden = ok and hidden or false
            end
            ZO_PlayerProgressBar_Gamepad:SetHidden(true)
        end

        m_defaultCastBarStateCaptured = true
    end
    HideDefaultCastBar()
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "HideDefaultCast", EVENT_PLAYER_ACTIVATED,
        HideDefaultCastBar)

    local function ResolveCastDisplayData(slotIndex, hotbar)
        local abilityId = GetSlotBoundId(slotIndex, hotbar)
        local abilityName = nil
        local isChanneled = false
        local castDurationMs = 0
        local showCountdown = false
        local castFillColor = nil
        local castDepthColor = nil

        if abilityId and abilityId > 0 then
            local durationValue
            isChanneled, durationValue = GetAbilityCastInfo(abilityId, nil, "player")
            castDurationMs = tonumber(durationValue) or 0
            abilityName = GetAbilityName(abilityId)
            showCountdown = castDurationMs > 0
            castFillColor, castDepthColor = ResolveCastBarFillColor(slotIndex, abilityId, hotbar)
        end

        if not abilityName or abilityName == "" then
            abilityName = GetSlotName(slotIndex, hotbar)
        end
        if not abilityName or abilityName == "" then
            return nil
        end

        if castDurationMs <= 0 then
            castDurationMs = CAST.INSTANT_DISPLAY_MS or 850
        end

        return abilityName, castDurationMs, isChanneled, showCountdown, castFillColor, castDepthColor
    end

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "SlotAbilityUsed",
        EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
            if not slotIndex then
                TraceCastBar("resource_orbs.cast_bar", "ability_used_skipped", {
                    fn = "CastBar.EVENT_ACTION_SLOT_ABILITY_USED",
                    reason = "missingSlotIndex",
                })
                return
            end
            local hotbar = GetActiveHotbarCategory()
            local name, duration, isChanneled, showCountdown, castFillColor, castDepthColor = ResolveCastDisplayData(
            slotIndex, hotbar)
            local abilityId = type(GetSlotBoundId) == "function" and GetSlotBoundId(slotIndex, hotbar) or nil
            if not name or duration <= 0 then
                TraceCastBar("resource_orbs.cast_bar", "ability_used_skipped", {
                    fn = "CastBar.EVENT_ACTION_SLOT_ABILITY_USED",
                    reason = not name and "missingAbilityName" or "invalidDuration",
                    slot = slotIndex,
                    hotbar = hotbar,
                    abilityId = abilityId,
                    durationMs = duration,
                })
                return
            end
            TraceCastBar("resource_orbs.cast_bar", "ability_used", {
                fn = "CastBar.EVENT_ACTION_SLOT_ABILITY_USED",
                slot = slotIndex,
                hotbar = hotbar,
                abilityId = abilityId,
                abilityName = name,
                durationMs = duration,
                channeled = isChanneled,
                countdown = showCountdown,
                hasColorOverride = castFillColor ~= nil,
            })
            self:OnCastStart("player", name, duration, isChanneled, showCountdown, castFillColor, castDepthColor)
        end, REGISTER_FILTER_UNIT_TAG, "player")

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "CastColorPowerProbe",
        EVENT_POWER_UPDATE, function(_, unitTag, powerPoolIndex, powerType, powerValue)
            if unitTag ~= "player" then return end
            if powerType ~= COST_TYPE_HEALTH and powerType ~= COST_TYPE_MAGICKA and powerType ~= COST_TYPE_STAMINA then
                return
            end

            local previous = self.lastKnownPowerValues and self.lastKnownPowerValues[powerType]
            if self.lastKnownPowerValues then
                self.lastKnownPowerValues[powerType] = powerValue
            end

            if not self.isCasting then return end
            if type(previous) ~= "number" or type(powerValue) ~= "number" then return end
            if previous <= powerValue then return end

            local probeStart = self.pendingPowerProbeStartMs or 0
            if probeStart <= 0 then
                TraceCastBar("resource_orbs.cast_bar", "power_probe_skipped", {
                    fn = "CastBar.EVENT_POWER_UPDATE",
                    reason = "notArmed",
                    powerType = powerType,
                    previous = previous,
                    current = powerValue,
                })
                return
            end

            local elapsedMs = GetFrameTimeMilliseconds() - probeStart
            if elapsedMs < 0 or elapsedMs > CAST_BAR_POWER_PROBE_WINDOW_MS then
                TraceCastBar("resource_orbs.cast_bar", "power_probe_skipped", {
                    fn = "CastBar.EVENT_POWER_UPDATE",
                    reason = "outsideWindow",
                    powerType = powerType,
                    elapsedMs = elapsedMs,
                    windowMs = CAST_BAR_POWER_PROBE_WINDOW_MS,
                })
                self.pendingPowerProbeStartMs = 0
                return
            end

            local sampledColor, sampledDepthColor = ResolveCastBarFillColorByPowerType(powerType)
            if sampledColor then
                self.currentFillColor = sampledColor
                self.currentDepthColor = sampledDepthColor or self.defaultDepthColor
                self:ApplyFillStyle(self.currentFillColor, self.currentDepthColor)
                TraceCastBar("resource_orbs.cast_bar", "power_probe_applied", {
                    fn = "CastBar.EVENT_POWER_UPDATE",
                    powerType = powerType,
                    previous = previous,
                    current = powerValue,
                    elapsedMs = elapsedMs,
                })
            else
                TraceCastBar("resource_orbs.cast_bar", "power_probe_skipped", {
                    fn = "CastBar.EVENT_POWER_UPDATE",
                    reason = "unsupportedPowerType",
                    powerType = powerType,
                })
            end
            self.pendingPowerProbeStartMs = 0
        end, REGISTER_FILTER_UNIT_TAG, "player")

    self.control:SetHandler("OnUpdate", function() self:Update() end)
end

---@class ExperienceBar : BetterUIBarFrame
local ExperienceBar = BetterUIBarFrame:Subclass()

---@param parent table Parent control
---@return ExperienceBar
function ExperienceBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

---@param parent table Parent control
function ExperienceBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUIXPBar", parent,
        XP.BACKDROP_TEXTURE or "Bar.dds",
        XP.FILL_TEXTURE or BARS.FILL_TEXTURE,
        XP.TEXTURE_BOUNDS,
        XP.FILL_REGION)
    self:SetColor(0.1, 0.85, 0.8, 1)
end

---@class MountStaminaBar : BetterUIBarFrame
---@field currentValue number Current mount stamina
---@field maxValue number Maximum mount stamina
local MountStaminaBar = BetterUIBarFrame:Subclass()

---@param parent table Parent control
---@return MountStaminaBar
function MountStaminaBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

---@param parent table Parent control
function MountStaminaBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUIMountStaminaBar", parent,
        MOUNT.BACKDROP_TEXTURE or "MountBar.dds",
        MOUNT.FILL_TEXTURE or BARS.FILL_TEXTURE,
        MOUNT.TEXTURE_BOUNDS, MOUNT.FILL_REGION)
    self:SetColor(0, 0.8, 0.2, 1)
    self.label:SetText(GetString(rawget(_G, "SI_BETTERUI_LABEL_MOUNT_STAMINA")))

    if IsMounted() then
        local current, max = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
        self.currentValue = current
        self.maxValue = max
    end

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "MountStaminaMount", EVENT_MOUNTED_STATE_CHANGED,
        function(_, isMounted)
            self:OnMountedStateChanged(isMounted)
        end)

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "MountStaminaPower", EVENT_POWER_UPDATE,
        function(_, unitTag, powerPoolIndex, powerType, powerValue, powerMax)
            if unitTag == "player" and powerType == COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA then
                self.currentValue = powerValue
                self.maxValue = powerMax
            end
        end, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)

    self.control:SetHandler("OnUpdate", function() self:Update() end)
end

---@param isMounted boolean Whether the player is mounted
function MountStaminaBar:OnMountedStateChanged(isMounted)
    if isMounted then
        local current, max = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
        self.currentValue = current
        self.maxValue = max
    end
    TraceMountStamina("resource_orbs.mount_stamina", "mounted_changed", {
        fn = "MountStaminaBar.OnMountedStateChanged",
        isMounted = isMounted == true,
        current = self.currentValue,
        max = self.maxValue,
    })
end

--- Restores the hidden state of the native cast-bar controls that were
--- suppressed by HideDefaultCastBar. Called from ResourceOrbFrames.RestoreNativeBars.
function Bars.RestoreDefaultCastBar()
    if not m_defaultCastBarStateCaptured then
        return
    end

    if ZO_PlayerProgress then
        pcall(function() ZO_PlayerProgress:SetHidden(m_originalPlayerProgressHidden) end)
    end

    if ZO_PlayerProgressBar_Gamepad then
        pcall(function() ZO_PlayerProgressBar_Gamepad:SetHidden(m_originalGamepadProgressHidden) end)
    end

    -- Reset capture so the next enable re-captures the current state rather
    -- than assuming the UI still matches the initial load state.
    m_defaultCastBarStateCaptured = false
end

-- Share class tables with OrbBarUpdates.lua before factory functions are attached.
Bars.BetterUIBarFrame = BetterUIBarFrame
Bars.CastBar = CastBar
Bars.ExperienceBar = ExperienceBar
Bars.MountStaminaBar = MountStaminaBar
