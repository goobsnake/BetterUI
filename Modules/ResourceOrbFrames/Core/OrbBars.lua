--[[
File: Modules/ResourceOrbFrames/OrbBars.lua
Purpose: Implements rectangular bar frames (XP, Cast, Mount Stamina).
         Contains BetterUIBarFrame and its subclasses.
Last Modified: 2026-02-11
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Bars then BETTERUI.ResourceOrbFrames.Bars = {} end

local Bars = BETTERUI.ResourceOrbFrames.Bars
local NAME = "ResourceOrbFrames"

-- Local helpers
local function FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

local function ResolveTexturePath(filename)
    -- Check custom texture setting
    local settings = GetModuleSettings()
    local path = "BetterUI/Modules/ResourceOrbFrames/Textures"
    if settings.useCustomTextures then
        path = "BetterUI/Modules/ResourceOrbFrames/CustomTextures"
    end
    return string.format("%s/%s", path, filename)
end

-------------------------------------------------------------------------------------------------
-- BetterUIBarFrame Class (Base)
-------------------------------------------------------------------------------------------------
BetterUIBarFrame = ZO_Object:Subclass()

function BetterUIBarFrame:New(control)
    local obj = ZO_Object.New(self)
    self.control = control
    return obj
end

function BetterUIBarFrame:Initialize(name, parent, backdropTextureFile, backdropTextureBounds, fillRegion)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    self.control = control
    self.backdropTextureFile = backdropTextureFile or "Bar.dds"
    self.backdropTextureBounds = backdropTextureBounds
    self.fillRegion = fillRegion

    local fill = WINDOW_MANAGER:CreateControl(name .. "Fill", control, CT_TEXTURE)
    fill:SetTexture(BETTERUI_BAR_FILL_TEXTURE or "esoui/art/miscellaneous/progressbar_genericfill_gloss.dds")
    fill:SetAnchor(LEFT, control, LEFT, 0, 0)
    self.fill = fill

    local backdrop = WINDOW_MANAGER:CreateControl(name .. "Backdrop", control, CT_TEXTURE)
    backdrop:SetTexture(ResolveTexturePath(self.backdropTextureFile))
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
        -- Keep backdrop texture in sync with live "Use Custom Textures" toggles.
        self.backdrop:SetTexture(ResolveTexturePath(self.backdropTextureFile))
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
    BetterUIBarFrame.Initialize(self, "BetterUICastBar", parent, "CastBar.dds", BETTERUI_CAST_BAR_TEXTURE_BOUNDS,
        BETTERUI_CAST_BAR_FILL_REGION)
    self.isCasting = false
    self.duration = 0
    self.startTime = 0
    self:SetColor(1, 1, 0.4, 1)
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

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "SlotAbilityUsed",
        EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
            local hotbar = GetActiveHotbarCategory()
            local abilityId = GetSlotBoundId(slotIndex, hotbar)
            if not abilityId or abilityId == 0 then return end
            if IsSlotToggled(slotIndex) then return end
            local isChanneled, castTime, channelTime = GetAbilityCastInfo(abilityId)
            local duration = math.max(castTime or 0, channelTime or 0)
            if duration <= 0 then return end
            local name = GetAbilityName(abilityId)
            self:OnCastStart("player", name, duration, isChanneled)
        end, REGISTER_FILTER_UNIT_TAG, "player")

    self.control:SetHandler("OnUpdate", function() self:Update() end)
end

function CastBar:OnCastStart(unitTag, abilityName, castDuration, isChanneled)
    if unitTag ~= "player" then return end
    self.isCasting = true
    self.duration = castDuration / 1000
    self.startTime = GetFrameTimeSeconds()
    self.abilityName = abilityName
    self.control:SetHidden(false)
end

function CastBar:OnCastStop(unitTag, wasInterrupted)
    if unitTag ~= "player" then return end
    self.isCasting = false
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

    local castTextSize = settings.castBarTextSize or 16
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
        max = self.duration

        if current < 0 then current = 0 end
        if current > max then current = max end
        self.label:SetText(string.format("%s (%.1fs)", self.abilityName or "Casting", remaining))

        if elapsed > self.duration + 0.5 then
            self:OnCastStop("player", false)
        end
        self:UpdateVisuals(current, max, insetX, insetY, w, h)
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
    BetterUIBarFrame.Initialize(self, "BetterUIXPBar", parent, "Bar.dds", BETTERUI_XP_BAR_TEXTURE_BOUNDS,
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

    local size = settings.xpBarTextSize or 16
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
    BetterUIBarFrame.Initialize(self, "BetterUIMountStaminaBar", parent, "MountBar.dds",
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

    local size = settings.mountStaminaBarTextSize or 16
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
