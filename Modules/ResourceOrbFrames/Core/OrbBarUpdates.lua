--[[
File: Modules/ResourceOrbFrames/Core/OrbBarUpdates.lua
Purpose: Implements update/refresh behavior for rectangular bar frames.
         Continues the class definitions declared in OrbBars.lua.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Bars then BETTERUI.ResourceOrbFrames.Bars = {} end

local Bars = BETTERUI.ResourceOrbFrames.Bars
local BARS = BETTERUI.ResourceOrbFrames.CONST.BARS
local XP = BARS.XP
local CAST = BARS.CAST
local MOUNT = BARS.MOUNT
local BAR_TEXT_SIZE_MIN = 5
local BAR_TEXT_SIZE_MAX = 20

local Utils = BETTERUI.ResourceOrbFrames.Utils
local ClampTextSize = Utils.ClampTextSize
local GetSettings = Utils.GetSettings

local CastBar = Bars.CastBar
local ExperienceBar = Bars.ExperienceBar
local MountStaminaBar = Bars.MountStaminaBar
local FoodBuffTracker = Bars.FoodBuffTracker

---@param fillColor table|nil Fill colour {r,g,b,a}
---@param depthColor table|nil Depth/gradient colour {r,g,b,a}
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

---@param unitTag string Unit tag (e.g. "player")
---@param abilityName string Display name of the ability
---@param castDuration number Cast duration in milliseconds
---@param isChanneled boolean Whether the ability is channeled
---@param showCountdown boolean Whether to display countdown text
---@param castFillColor table|nil Fill colour override {r,g,b,a}
---@param castDepthColor table|nil Depth colour override {r,g,b,a}
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

---@param unitTag string Unit tag (e.g. "player")
---@param wasInterrupted boolean Whether the cast was interrupted
function CastBar:OnCastStop(unitTag, wasInterrupted)
    if unitTag ~= "player" then return end
    self.isCasting = false
    self.showCountdown = false
    self.isChanneled = false
    self.pendingPowerProbeStartMs = 0
    self:Update()
end

--- Updates cast bar visibility, fill, and label text each frame.
function CastBar:Update()
    local settings = GetSettings()
    if not settings.castBarEnabled then
        self.control:SetHidden(true)
        return
    end

    local w = CAST.WIDTH or 250
    local h = CAST.HEIGHT or 150
    self.control:SetDimensions(w, h)
    self.control:SetScale(CAST.SCALE or 1.0)

    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end

    local insetX = CAST.FILL_INSET_X or 40
    local insetY = CAST.FILL_INSET_Y or 55
    local current, max

    local castTextSize = ClampTextSize(settings.castBarTextSize, BAR_TEXT_SIZE_MIN, BAR_TEXT_SIZE_MAX, 16)
    local castTextColor = settings.castBarTextColor or { 1, 1, 1, 1 }
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", castTextSize))
    self.label:SetColor(unpack(castTextColor))

    local castLabelOffsetX, castLabelOffsetY = self:GetLabelAnchorOffsets(w, h,
        CAST.LABEL_OFFSET_X or 0,
        CAST.LABEL_OFFSET_Y or 0)
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
        local fallbackLabel = GetString(rawget(_G, "SI_BETTERUI_LABEL_CAST_BAR"))
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
            self.label:SetText(GetString(rawget(_G, "SI_BETTERUI_LABEL_CAST_BAR")))
            if self.fill then self.fill:SetHidden(true) end
        else
            self.control:SetHidden(true)
        end
    end
end

--- Updates XP/Champion bar fill and label text.
function ExperienceBar:Update()
    if not self.control then return end
    local settings = GetSettings()

    if not settings.xpBarEnabled then
        self.control:SetHidden(true)
        return
    end
    self.control:SetHidden(false)

    local isChampion = IsUnitChampion("player")
    local current, max, effectiveMax, labelText

    if isChampion then
        local currentCP = GetPlayerChampionPointsEarned()
        current = GetPlayerChampionXP()
        local success, size = BETTERUI.CIM.SafeExecute("OrbBarUpdates.championXP", GetNumChampionXPInChampionPoint, currentCP)
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

    local insetX = XP.FILL_INSET_X or 8
    local insetY = XP.FILL_INSET_Y or 4
    local w = XP.WIDTH or 250
    local h = XP.HEIGHT or 150

    self.control:SetDimensions(w, h)
    self.control:SetScale(XP.SCALE or 1.0)

    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end

    local xpLabelOffsetX, xpLabelOffsetY = self:GetLabelAnchorOffsets(w, h,
        XP.LABEL_OFFSET_X or 0,
        XP.LABEL_OFFSET_Y or 0)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, xpLabelOffsetX, xpLabelOffsetY)

    self:UpdateVisuals(current, effectiveMax, insetX, insetY, w, h)
end

--- Updates mount stamina bar fill, label, and mounted state.
function MountStaminaBar:Update()
    local settings = GetSettings()
    if not settings.mountStaminaBarEnabled then
        self.control:SetHidden(true)
        return
    end

    local w = MOUNT.WIDTH or 250
    local h = MOUNT.HEIGHT or 150
    self.control:SetDimensions(w, h)
    self.control:SetScale(MOUNT.SCALE or 1.0)
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
        MOUNT.LABEL_OFFSET_X or 0,
        MOUNT.LABEL_OFFSET_Y or 0)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, mountLabelOffsetX, mountLabelOffsetY)

    if IsMounted() then
        local current = self.currentValue or 0
        local max = self.maxValue or 1
        if max <= 0 then max = 1 end
        local percent = math.floor((current / max) * 100)
        self.label:SetText(string.format("Mount: %d%%", percent))
        if self.fill then self.fill:SetHidden(false) end
        self:UpdateVisuals(current, max, MOUNT.FILL_INSET_X or 35,
            MOUNT.FILL_INSET_Y or 55, w, h)
    else
        self.label:SetText(GetString(rawget(_G, "SI_BETTERUI_LABEL_MOUNT_STAMINA")))
        if self.fill then self.fill:SetHidden(true) end
    end
end

--- Placeholder update for food buff tracker.
function FoodBuffTracker:Update()
    -- Logic available in repo if needed, minimal placeholder here to prevent errors if referenced
    if self.control and self.control.SetValue then self.control:SetValue(0) end
end

-- Export Factory Functions
---@param parent table Parent control
---@return CastBar
function Bars.CreateCastBar(parent) return CastBar:New(parent) end

---@param parent table Parent control
---@return ExperienceBar
function Bars.CreateExperienceBar(parent) return ExperienceBar:New(parent) end

---@param parent table Parent control
---@return MountStaminaBar
function Bars.CreateMountStaminaBar(parent) return MountStaminaBar:New(parent) end

---@param control table UI control
---@return FoodBuffTracker
function Bars.CreateFoodTracker(control) return FoodBuffTracker:New(control) end
