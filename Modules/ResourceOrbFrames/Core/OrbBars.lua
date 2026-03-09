--[[
File: Modules/ResourceOrbFrames/OrbBars.lua
Purpose: Implements rectangular bar frames (XP, Cast, Mount Stamina).
         Contains BetterUIBarFrame and its subclasses.
Last Modified: 2026-02-13
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Bars then BETTERUI.ResourceOrbFrames.Bars = {} end

local Bars = BETTERUI.ResourceOrbFrames.Bars
local NAME = "ResourceOrbFrames"
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
local BAR_TEXT_SIZE_MIN = 5
local BAR_TEXT_SIZE_MAX = 20

local Utils = BETTERUI.ResourceOrbFrames.Utils
local ClampTextSize = Utils.ClampTextSize
local FindControl = Utils.FindControl
local GetModuleSettings = Utils.GetModuleSettings

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

local function CloneColor(color)
    if type(color) ~= "table" then
        return nil
    end
    return {
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        color[4] or 1,
    }
end

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

-------------------------------------------------------------------------------------------------
-- BetterUIBarFrame Class (Base)
-------------------------------------------------------------------------------------------------
BetterUIBarFrame = ZO_Object:Subclass()

function BetterUIBarFrame:New(control)
    local obj = ZO_Object.New(self)
    -- TODO(bug): Assigns to self (class prototype) instead of obj (instance); all instances share the last-assigned control. Currently masked because only one FoodBuffTracker instance uses this constructor; subclasses override via Initialize()
    self.control = control
    return obj
end

function BetterUIBarFrame:Initialize(name, parent, backdropTextureFile, fillTextureFile, backdropTextureBounds,
                                     fillRegion)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    self.control = control
    self.backdropTextureFile = backdropTextureFile or "Bar.dds"
    self.fillTextureFile = fillTextureFile or BETTERUI_BAR_FILL_TEXTURE or
        "esoui/art/miscellaneous/progressbar_genericfill_gloss.dds"
    self.backdropTextureBounds = backdropTextureBounds
    self.fillRegion = fillRegion

    local fill = WINDOW_MANAGER:CreateControl(name .. "Fill", control, CT_TEXTURE)
    fill:SetTexture(ResolveBarTexturePath(self.fillTextureFile))
    fill:SetAnchor(LEFT, control, LEFT, 0, 0)
    self.fill = fill

    local backdrop = WINDOW_MANAGER:CreateControl(name .. "Backdrop", control, CT_TEXTURE)
    backdrop:SetTexture(ResolveBarTexturePath(self.backdropTextureFile))
    backdrop:SetAnchor(CENTER, control, CENTER, 0, 0)
    self.backdrop = backdrop

    local label = WINDOW_MANAGER:CreateControl(name .. "Label", control, CT_LABEL)
    label:SetAnchor(CENTER, control, CENTER, 0, 4)
    label:SetFont("$(BOLD_FONT)|18|thick-outline")
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.label = label

    return control
end

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

function BetterUIBarFrame:UpdateVisuals(current, max, insetX, insetY, barWidth, barHeight)
    if not self.control or self.control:IsHidden() then return end

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

    if self.fill and max > 0 then
        self.fill:SetTexture(ResolveBarTexturePath(self.fillTextureFile))

        local percent = math.min(1, math.max(0, current / max))
        local fillX, fillY
        local fillMaxWidth, fillHeight

        if IsValidRegion(self.fillRegion) then
            local left = barWidth * self.fillRegion.left
            local right = barWidth * self.fillRegion.right
            local top = barHeight * self.fillRegion.top
            local bottom = barHeight * self.fillRegion.bottom
            fillX = left
            fillY = top
            fillMaxWidth = math.max(1, right - left)
            fillHeight = math.max(1, bottom - top)
            self.fill:ClearAnchors()
            self.fill:SetAnchor(TOPLEFT, self.control, TOPLEFT, fillX, fillY)
        else
            fillMaxWidth = barWidth - (2 * insetX)
            fillHeight = barHeight - (2 * insetY)
            self.fill:ClearAnchors()
            self.fill:SetAnchor(LEFT, self.control, LEFT, insetX, 0)
        end

        self.fill:SetDimensions(fillMaxWidth * percent, fillHeight)
        self.fill:SetTextureCoords(0, percent, 0, 1)
    end
end

-------------------------------------------------------------------------------------------------
-- Cast Bar Class
-------------------------------------------------------------------------------------------------
local CastBar = BetterUIBarFrame:Subclass()

function CastBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

function CastBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUICastBar", parent,
        BETTERUI_CAST_BAR_BACKDROP_TEXTURE or "CastBar.dds",
        BETTERUI_CAST_BAR_FILL_TEXTURE or BETTERUI_BAR_FILL_TEXTURE,
        BETTERUI_CAST_BAR_TEXTURE_BOUNDS,
        BETTERUI_CAST_BAR_FILL_REGION)
    self.isCasting = false
    self.duration = 0
    self.postCastHold = 0.5
    self.showCountdown = false
    self.isChanneled = false
    self.startTime = 0
    self.defaultFillColor, self.defaultDepthColor = GetCastBarFillStyle(nil)
    self.currentFillColor = CloneColor(self.defaultFillColor) or { 1, 1, 0.4, 1 }
    self.currentDepthColor = CloneColor(self.defaultDepthColor) or { 0.45, 0.45, 0.18, 1 }
    self.pendingPowerProbeStartMs = 0
    self.lastKnownPowerValues = {
        [COST_TYPE_HEALTH] = select(1, GetUnitPower("player", COST_TYPE_HEALTH)) or 0,
        [COST_TYPE_MAGICKA] = select(1, GetUnitPower("player", COST_TYPE_MAGICKA)) or 0,
        [COST_TYPE_STAMINA] = select(1, GetUnitPower("player", COST_TYPE_STAMINA)) or 0,
    }
    self:ApplyFillStyle(self.currentFillColor, self.currentDepthColor)
    self.label:SetText(GetString(SI_BETTERUI_LABEL_CAST_BAR))

    -- Note: EVENT_SPELL_CASTING_START/STOP don't exist in ESO API.
    -- Casting is tracked via EVENT_ACTION_SLOT_ABILITY_USED below which uses GetAbilityCastInfo().

    local function HideDefaultCastBar()
        if ZO_CastingBar then ZO_CastingBar:SetHidden(true) end
        if ZO_PlayerCastingBar then ZO_PlayerCastingBar:SetHidden(true) end
        if ZO_PlayerProgressBar then ZO_PlayerProgressBar:SetHidden(true) end
        if ZO_GamepadPlayerProgressBar then ZO_GamepadPlayerProgressBar:SetHidden(true) end
        if GAMEPAD_PLAYER_PROGRESS_BAR_FRAGMENT then
            GAMEPAD_PLAYER_PROGRESS_BAR_FRAGMENT:SetHiddenForReason(
                "BetterUICastBar", true)
        end
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
            local castTime, channelTime
            isChanneled, castTime, channelTime = GetAbilityCastInfo(abilityId)
            castDurationMs = math.max(castTime or 0, channelTime or 0)
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
            castDurationMs = BETTERUI_CAST_BAR_INSTANT_DISPLAY_MS or 850
        end

        return abilityName, castDurationMs, isChanneled, showCountdown, castFillColor, castDepthColor
    end

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "SlotAbilityUsed",
        EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
            if not slotIndex then return end
            local hotbar = GetActiveHotbarCategory()
            local name, duration, isChanneled, showCountdown, castFillColor, castDepthColor = ResolveCastDisplayData(
            slotIndex, hotbar)
            if not name or duration <= 0 then return end
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
            if probeStart <= 0 then return end

            local elapsedMs = GetFrameTimeMilliseconds() - probeStart
            if elapsedMs < 0 or elapsedMs > CAST_BAR_POWER_PROBE_WINDOW_MS then
                self.pendingPowerProbeStartMs = 0
                return
            end

            local sampledColor, sampledDepthColor = ResolveCastBarFillColorByPowerType(powerType)
            if sampledColor then
                self.currentFillColor = sampledColor
                self.currentDepthColor = sampledDepthColor or self.defaultDepthColor
                self:ApplyFillStyle(self.currentFillColor, self.currentDepthColor)
            end
            self.pendingPowerProbeStartMs = 0
        end, REGISTER_FILTER_UNIT_TAG, "player")

    self.control:SetHandler("OnUpdate", function() self:Update() end)
end

function CastBar:ApplyFillStyle(fillColor, depthColor)
    self.currentFillColor = fillColor or self.defaultFillColor
    self.currentDepthColor = depthColor or self.defaultDepthColor

    if not self.fill then return end

    self.fill:SetColor(unpack(self.currentFillColor))
    self.fill:SetGradientColors(
        ORIENTATION_VERTICAL,
        self.currentDepthColor[1] or 0,
        self.currentDepthColor[2] or 0,
        self.currentDepthColor[3] or 0,
        self.currentDepthColor[4] or 1,
        self.currentFillColor[1] or 1,
        self.currentFillColor[2] or 1,
        self.currentFillColor[3] or 1,
        self.currentFillColor[4] or 1
    )
end

function CastBar:OnCastStart(unitTag, abilityName, castDuration, isChanneled, showCountdown, castFillColor,
                             castDepthColor)
    if unitTag ~= "player" then return end
    local durationSeconds = (castDuration or 0) / 1000
    if durationSeconds <= 0 then return end

    self.isCasting = true
    self.duration = durationSeconds
    self.postCastHold = showCountdown and 0.5 or 0
    self.showCountdown = showCountdown == true
    self.isChanneled = isChanneled == true
    self.startTime = GetFrameTimeSeconds()
    self.abilityName = abilityName
    self.pendingPowerProbeStartMs = GetFrameTimeMilliseconds()
    self:ApplyFillStyle(castFillColor or self.defaultFillColor, castDepthColor or self.defaultDepthColor)
    self.control:SetHidden(false)
    if self.fill then self.fill:SetHidden(false) end
end

function CastBar:OnCastStop(unitTag, wasInterrupted)
    if unitTag ~= "player" then return end
    self.isCasting = false
    self.showCountdown = false
    self.isChanneled = false
    self.pendingPowerProbeStartMs = 0
    self:Update()
end

function CastBar:Update()
    local settings = GetModuleSettings()
    if not settings.castBarEnabled then
        self.control:SetHidden(true)
        return
    end

    local w = BETTERUI_CAST_BAR_WIDTH or 250
    local h = BETTERUI_CAST_BAR_HEIGHT or 150
    self.control:SetDimensions(w, h)
    self.control:SetScale(BETTERUI_CAST_BAR_SCALE or 1.0)

    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end

    local insetX = BETTERUI_CAST_BAR_FILL_INSET_X or 40
    local insetY = BETTERUI_CAST_BAR_FILL_INSET_Y or 55
    local current, max = 0, 1

    local castTextSize = ClampTextSize(settings.castBarTextSize, BAR_TEXT_SIZE_MIN, BAR_TEXT_SIZE_MAX, 16)
    local castTextColor = settings.castBarTextColor or { 1, 1, 1, 1 }
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", castTextSize))
    self.label:SetColor(unpack(castTextColor))

    local castLabelOffsetX, castLabelOffsetY = self:GetLabelAnchorOffsets(w, h,
        BETTERUI_CAST_BAR_LABEL_OFFSET_X or 0,
        BETTERUI_CAST_BAR_LABEL_OFFSET_Y or 0)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, castLabelOffsetX, castLabelOffsetY)

    if self.isCasting then
        self.control:SetHidden(false)
        if self.fill then self.fill:SetHidden(false) end

        local now = GetFrameTimeSeconds()
        local elapsed = now - self.startTime
        local remaining = math.max(0, self.duration - elapsed)

        current = remaining
        max = math.max(self.duration, 0.001)

        if current < 0 then current = 0 end
        if current > max then current = max end
        local fallbackLabel = GetString(SI_BETTERUI_LABEL_CAST_BAR)
        if self.showCountdown then
            self.label:SetText(string.format("%s (%.1fs)", self.abilityName or fallbackLabel, remaining))
        else
            self.label:SetText(self.abilityName or fallbackLabel)
        end

        if elapsed > self.duration + (self.postCastHold or 0.5) then
            self:OnCastStop("player", false)
        end
        self:UpdateVisuals(current, max, insetX, insetY, w, h)
        self:ApplyFillStyle(self.currentFillColor, self.currentDepthColor)
    else
        if settings.castBarAlwaysShow then
            self.control:SetHidden(false)
            self.label:SetText(GetString(SI_BETTERUI_LABEL_CAST_BAR))
            if self.fill then self.fill:SetHidden(true) end
        else
            self.control:SetHidden(true)
        end
    end
end

-------------------------------------------------------------------------------------------------
-- Experience Bar Class
-------------------------------------------------------------------------------------------------
local ExperienceBar = BetterUIBarFrame:Subclass()

function ExperienceBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

function ExperienceBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUIXPBar", parent,
        BETTERUI_XP_BAR_BACKDROP_TEXTURE or "Bar.dds",
        BETTERUI_XP_BAR_FILL_TEXTURE or BETTERUI_BAR_FILL_TEXTURE,
        BETTERUI_XP_BAR_TEXTURE_BOUNDS,
        BETTERUI_XP_BAR_FILL_REGION)
    self:SetColor(0.1, 0.85, 0.8, 1)
end

function ExperienceBar:Update()
    if not self.control then return end
    local settings = GetModuleSettings()

    if not settings.xpBarEnabled then
        self.control:SetHidden(true)
        return
    end
    self.control:SetHidden(false)

    local isChampion = IsUnitChampion("player")
    local current, max, effectiveMax = 0, 0, 0
    local labelText = ""

    if isChampion then
        local currentCP = GetPlayerChampionPointsEarned()
        current = GetPlayerChampionXP()
        -- AUDITED(pcall): Defensive - ESO API may return nil for high CP values
        local success, size = pcall(GetNumChampionXPInChampionPoint, currentCP)
        if success and size then max = size else max = 400000 end
        if max <= 0 then max = 1 end
        effectiveMax = max
        local percent = math.floor((current / max) * 100)
        labelText = string.format("CP: %d (%d%%)", currentCP, percent)
    else
        current = GetUnitXP("player")
        max = GetUnitXPMax("player")
        labelText = string.format("XP: %d / %d", current, max)
        effectiveMax = max
    end

    local size = ClampTextSize(settings.xpBarTextSize, BAR_TEXT_SIZE_MIN, BAR_TEXT_SIZE_MAX, 16)
    local color = settings.xpBarTextColor or { 1, 1, 1, 1 }
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", size))
    self.label:SetColor(unpack(color))
    self.label:SetText(labelText)

    local insetX = BETTERUI_XP_BAR_FILL_INSET_X or 8
    local insetY = BETTERUI_XP_BAR_FILL_INSET_Y or 4
    local w = BETTERUI_XP_BAR_WIDTH or 250
    local h = BETTERUI_XP_BAR_HEIGHT or 150

    self.control:SetDimensions(w, h)
    self.control:SetScale(BETTERUI_XP_BAR_SCALE or 1.0)

    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end

    local xpLabelOffsetX, xpLabelOffsetY = self:GetLabelAnchorOffsets(w, h,
        BETTERUI_XP_BAR_LABEL_OFFSET_X or 0,
        BETTERUI_XP_BAR_LABEL_OFFSET_Y or 0)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, xpLabelOffsetX, xpLabelOffsetY)

    self:UpdateVisuals(current, effectiveMax, insetX, insetY, w, h)
end

-------------------------------------------------------------------------------------------------
-- Mount Stamina Bar Class
-------------------------------------------------------------------------------------------------
local MountStaminaBar = BetterUIBarFrame:Subclass()

function MountStaminaBar:New(parent)
    local obj = ZO_Object.New(self)
    obj:Initialize(parent)
    return obj
end

function MountStaminaBar:Initialize(parent)
    BetterUIBarFrame.Initialize(self, "BetterUIMountStaminaBar", parent,
        BETTERUI_MOUNT_STAMINA_BAR_BACKDROP_TEXTURE or "MountBar.dds",
        BETTERUI_MOUNT_STAMINA_BAR_FILL_TEXTURE or BETTERUI_BAR_FILL_TEXTURE,
        BETTERUI_MOUNT_STAMINA_BAR_TEXTURE_BOUNDS, BETTERUI_MOUNT_STAMINA_BAR_FILL_REGION)
    self:SetColor(0, 0.8, 0.2, 1)
    self.label:SetText(GetString(SI_BETTERUI_LABEL_MOUNT_STAMINA))

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

function MountStaminaBar:OnMountedStateChanged(isMounted)
    if isMounted then
        local current, max = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
        self.currentValue = current
        self.maxValue = max
    end
end

function MountStaminaBar:Update()
    local settings = GetModuleSettings()
    if not settings.mountStaminaBarEnabled then
        self.control:SetHidden(true)
        return
    end

    local w = BETTERUI_MOUNT_STAMINA_BAR_WIDTH or 250
    local h = BETTERUI_MOUNT_STAMINA_BAR_HEIGHT or 150
    self.control:SetDimensions(w, h)
    self.control:SetScale(BETTERUI_MOUNT_STAMINA_BAR_SCALE or 1.0)
    self.control:SetHidden(false)

    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end

    local size = ClampTextSize(settings.mountStaminaBarTextSize, BAR_TEXT_SIZE_MIN, BAR_TEXT_SIZE_MAX, 16)
    local color = settings.mountStaminaBarTextColor or { 1, 1, 1, 1 }
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", size))
    self.label:SetColor(unpack(color))
    local mountLabelOffsetX, mountLabelOffsetY = self:GetLabelAnchorOffsets(w, h,
        BETTERUI_MOUNT_STAMINA_BAR_LABEL_OFFSET_X or 0,
        BETTERUI_MOUNT_STAMINA_BAR_LABEL_OFFSET_Y or 0)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, mountLabelOffsetX, mountLabelOffsetY)

    if IsMounted() then
        local current = self.currentValue or 0
        local max = self.maxValue or 1
        if max <= 0 then max = 1 end
        local percent = math.floor((current / max) * 100)
        self.label:SetText(string.format("Mount: %d%%", percent))
        if self.fill then self.fill:SetHidden(false) end
        self:UpdateVisuals(current, max, BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_X or 35,
            BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_Y or 55, w, h)
    else
        self.label:SetText(GetString(SI_BETTERUI_LABEL_MOUNT_STAMINA))
        if self.fill then self.fill:SetHidden(true) end
    end
end

-------------------------------------------------------------------------------------------------
-- Food Buff Tracker (Legacy/Unused but kept for safety)
-------------------------------------------------------------------------------------------------
local FoodBuffTracker = ZO_Object:Subclass()

function FoodBuffTracker:New(control)
    local obj = ZO_Object.New(self)
    obj.control = control
    return obj
end

function FoodBuffTracker:Update()
    -- Logic available in repo if needed, minimal placeholder here to prevent errors if referenced
    if self.control and self.control.SetValue then self.control:SetValue(0) end
end

-- Export Factory Functions
function Bars.CreateCastBar(parent) return CastBar:New(parent) end

function Bars.CreateExperienceBar(parent) return ExperienceBar:New(parent) end

function Bars.CreateMountStaminaBar(parent) return MountStaminaBar:New(parent) end

function Bars.CreateFoodTracker(control) return FoodBuffTracker:New(control) end
