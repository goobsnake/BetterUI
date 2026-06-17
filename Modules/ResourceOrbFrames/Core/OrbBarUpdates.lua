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
-- Hot-path accessor: live settings table by reference (no deep clone per
-- frame). Read-only by convention.
local GetLiveSettings = (Utils.Settings and Utils.Settings.GetLive) or Utils.GetSettings

local CastBar = Bars.CastBar
local ExperienceBar = Bars.ExperienceBar
local MountStaminaBar = Bars.MountStaminaBar

local function TraceValueBracketChange(current, max, state)
    if not BETTERUI.Log then
        return
    end

    local percent = 0
    if max and max > 0 then
        percent = math.floor((current / max) * 100)
    end
    local bracket = math.floor(percent / 10)
    if state._betteruiLastValueBracket == bracket then
        return
    end

    state._betteruiLastValueBracket = bracket
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, "orbValueBracket", { cur = current, max = max, pct = percent }) end
end

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
    self.appliedIdleState = false -- re-apply the idle label after this cast
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

--- Applies static cast bar styling (dimensions, backdrop, font, label anchor).
--- Cheap when nothing changed: re-applies only when the style-affecting
--- settings values differ from the last applied ones.
---@param settings table Module settings (live table)
---@return number w Bar width
---@return number h Bar height
function CastBar:ApplyStaticStyle(settings)
    local w = CAST.WIDTH or 250
    local h = CAST.HEIGHT or 150
    local textSize = ClampTextSize(settings.castBarTextSize, BAR_TEXT_SIZE_MIN, BAR_TEXT_SIZE_MAX, 16)
    local color = settings.castBarTextColor or { 1, 1, 1, 1 }
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    if self.appliedTextSize == textSize and self.appliedTextR == r and self.appliedTextG == g
        and self.appliedTextB == b and self.appliedTextA == a then
        return w, h
    end
    self.appliedTextSize = textSize
    self.appliedTextR, self.appliedTextG, self.appliedTextB, self.appliedTextA = r, g, b, a

    self.control:SetDimensions(w, h)
    self.control:SetScale(CAST.SCALE or 1.0)
    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", textSize))
    self.label:SetColor(r, g, b, a)
    local labelOffsetX, labelOffsetY = self:GetLabelAnchorOffsets(w, h,
        CAST.LABEL_OFFSET_X or 0,
        CAST.LABEL_OFFSET_Y or 0)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, labelOffsetX, labelOffsetY)
    return w, h
end

--- Updates cast bar visibility, fill, and label text each frame.
function CastBar:Update()
    local settings = GetLiveSettings()
    if not settings.castBarEnabled then
        self.control:SetHidden(true)
        return
    end

    local w, h = self:ApplyStaticStyle(settings)
    local insetX = CAST.FILL_INSET_X or 40
    local insetY = CAST.FILL_INSET_Y or 55
    local current, max

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
            -- Latch the idle state: skip per-frame GetString/SetText churn
            -- until a cast resets the latch (OnCastStart).
            if self.appliedIdleState ~= true then
                self.appliedIdleState = true
                self.label:SetText(GetString(rawget(_G, "SI_BETTERUI_LABEL_CAST_BAR")))
                if self.fill then self.fill:SetHidden(true) end
            end
        else
            self.control:SetHidden(true)
        end
    end
end

--- Applies static XP bar styling (dimensions, backdrop, font, label anchor).
--- Cheap when nothing changed: re-applies only when the style-affecting
--- settings values differ from the last applied ones (mirrors CastBar /
--- MountStaminaBar ApplyStaticStyle).
---@param settings table Module settings (live table)
---@return number w Bar width
---@return number h Bar height
function ExperienceBar:ApplyStaticStyle(settings)
    local w = XP.WIDTH or 250
    local h = XP.HEIGHT or 150
    local textSize = ClampTextSize(settings.xpBarTextSize, BAR_TEXT_SIZE_MIN, BAR_TEXT_SIZE_MAX, 16)
    local color = settings.xpBarTextColor or { 1, 1, 1, 1 }
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    if self.appliedTextSize == textSize and self.appliedTextR == r and self.appliedTextG == g
        and self.appliedTextB == b and self.appliedTextA == a then
        return w, h
    end
    self.appliedTextSize = textSize
    self.appliedTextR, self.appliedTextG, self.appliedTextB, self.appliedTextA = r, g, b, a

    self.control:SetDimensions(w, h)
    self.control:SetScale(XP.SCALE or 1.0)
    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", textSize))
    self.label:SetColor(r, g, b, a)
    local labelOffsetX, labelOffsetY = self:GetLabelAnchorOffsets(w, h,
        XP.LABEL_OFFSET_X or 0,
        XP.LABEL_OFFSET_Y or 0)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, labelOffsetX, labelOffsetY)
    return w, h
end

--- Updates XP/Champion bar fill and label text.
--- Runs on a raw per-frame OnUpdate; latches static style (ApplyStaticStyle)
--- and the computed label text / current+max so the steady-state per-frame
--- cost is a few cheap reads plus comparisons.
function ExperienceBar:Update()
    if not self.control then return end
    local settings = GetLiveSettings()

    if not settings.xpBarEnabled then
        self.control:SetHidden(true)
        return
    end
    self.control:SetHidden(false)

    local w, h = self:ApplyStaticStyle(settings)
    local insetX = XP.FILL_INSET_X or 8
    local insetY = XP.FILL_INSET_Y or 4

    local isChampion = IsUnitChampion("player")
    local current, effectiveMax, labelText

    if isChampion then
        local currentCP = GetPlayerChampionPointsEarned()
        current = GetPlayerChampionXP()
        local max
        local success, size = BETTERUI.CIM.SafeExecute("OrbBarUpdates.championXP", GetNumChampionXPInChampionPoint, currentCP)
        if success and size then
            max = size
        else
            max = 400000
            if BETTERUI.Log then
                BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, "champion XP fallback used")
            end
        end
        if max <= 0 then max = 1 end
        effectiveMax = max
        local percent = math.floor((current / max) * 100)
        labelText = string.format("CP: %d (%d%%)", currentCP, percent)
    else
        -- GetUnitXP/GetUnitXPMax can return nil at edge cases (e.g. max-level
        -- non-champion); coerce to numbers before %d / arithmetic.
        current = GetUnitXP("player") or 0
        effectiveMax = GetUnitXPMax("player") or 0
        labelText = string.format("XP: %d / %d", current, effectiveMax)
    end

    -- Latch the label text and value state: skip SetText / UpdateVisuals churn
    -- when nothing changed since the last frame.
    if labelText ~= self.appliedLabelText then
        self.appliedLabelText = labelText
        self.label:SetText(labelText)
    end

    if current ~= self.appliedCurrent or effectiveMax ~= self.appliedEffectiveMax then
        self.appliedCurrent = current
        self.appliedEffectiveMax = effectiveMax
        self:UpdateVisuals(current, effectiveMax, insetX, insetY, w, h)
    end

    TraceValueBracketChange(current, effectiveMax, self)
end

--- Applies static mount bar styling (dimensions, backdrop, font, label anchor).
--- Cheap when nothing changed: re-applies only when the style-affecting
--- settings values differ from the last applied ones.
---@param settings table Module settings (live table)
---@return number w Bar width
---@return number h Bar height
function MountStaminaBar:ApplyStaticStyle(settings)
    local w = MOUNT.WIDTH or 250
    local h = MOUNT.HEIGHT or 150
    local textSize = ClampTextSize(settings.mountStaminaBarTextSize, BAR_TEXT_SIZE_MIN, BAR_TEXT_SIZE_MAX, 16)
    local color = settings.mountStaminaBarTextColor or { 1, 1, 1, 1 }
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    if self.appliedTextSize == textSize and self.appliedTextR == r and self.appliedTextG == g
        and self.appliedTextB == b and self.appliedTextA == a then
        return w, h
    end
    self.appliedTextSize = textSize
    self.appliedTextR, self.appliedTextG, self.appliedTextB, self.appliedTextA = r, g, b, a

    self.control:SetDimensions(w, h)
    self.control:SetScale(MOUNT.SCALE or 1.0)
    if self.backdrop then
        self.backdrop:SetDimensions(w, h)
        self.backdrop:ClearAnchors()
        self.backdrop:SetAnchor(CENTER, self.control, CENTER, 0, 0)
    end
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", textSize))
    self.label:SetColor(r, g, b, a)
    local labelOffsetX, labelOffsetY = self:GetLabelAnchorOffsets(w, h,
        MOUNT.LABEL_OFFSET_X or 0,
        MOUNT.LABEL_OFFSET_Y or 0)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, labelOffsetX, labelOffsetY)
    return w, h
end

--- Updates mount stamina bar fill, label, and mounted state.
function MountStaminaBar:Update()
    local settings = GetLiveSettings()
    if not settings.mountStaminaBarEnabled then
        self.control:SetHidden(true)
        return
    end

    local w, h = self:ApplyStaticStyle(settings)
    self.control:SetHidden(false)

    if IsMounted() then
        self.appliedMountedState = true
        local current = self.currentValue or 0
        local max = self.maxValue or 1
        if max <= 0 then max = 1 end
        local percent = math.floor((current / max) * 100)
        self.label:SetText(string.format("Mount: %d%%", percent))
        if self.fill then self.fill:SetHidden(false) end
        self:UpdateVisuals(current, max, MOUNT.FILL_INSET_X or 35,
            MOUNT.FILL_INSET_Y or 55, w, h)
        TraceValueBracketChange(current, max, self)
    else
        -- Skip per-tick label/fill churn while unmounted: apply the idle
        -- state once and latch until the mounted state changes.
        if self.appliedMountedState ~= false then
            self.appliedMountedState = false
            self.label:SetText(GetString(rawget(_G, "SI_BETTERUI_LABEL_MOUNT_STAMINA")))
            if self.fill then self.fill:SetHidden(true) end
        end
        self._betteruiLastValueBracket = nil
    end
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
