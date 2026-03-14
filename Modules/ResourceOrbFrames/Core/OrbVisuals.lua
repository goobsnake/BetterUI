--[[
File: Modules/ResourceOrbFrames/Core/OrbVisuals.lua
Purpose: Handles the creation, layout, and maintenance of Resource Orbs (Health, Magicka, Stamina).
         Contains the BetterUIOrbBar and BetterUIShieldBar classes.
Last Modified: 2026-03-14
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Visuals then BETTERUI.ResourceOrbFrames.Visuals = {} end

local Visuals = BETTERUI.ResourceOrbFrames.Visuals
local Animations = BETTERUI.ResourceOrbFrames.Animations
local NAME = "ResourceOrbFrames"
local DEFAULT_SHIELD_ELECTRIC_COLOR = { 0.4, 0.9, 1, 1 }

--[[
Table: ORB_CONFIG
Description: Maps ESO power types to orb rendering parameters.
Structure: [POWERTYPE_*] = { baseCoordLeft, baseCoordRight, baseAnchorX, iconPath }
  - baseCoordLeft (number):  Left edge of texture coordinate range (0-1 normalized).
  - baseCoordRight (number): Right edge of texture coordinate range (0-1 normalized).
                             A difference of ~0.5 enables half-texture mode (split orb).
  - baseAnchorX (number):    Horizontal anchor offset from orb center (pixels).
                             Non-zero values shift the fill texture sideways (e.g., Stamina=75).
  - iconPath (string|nil):   Optional alchemy icon texture for the power type display.
                             Nil for shield overlay (no standalone icon).
Used By: BetterUIOrbBar:Initialize (unpacked into self.baseCoordLeft, baseCoordRight, baseAnchorX).
]]
local ORB_CONFIG = {
    [POWERTYPE_HEALTH] = { 0, 1, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorehealth.dds' },
    [POWERTYPE_MAGICKA] = { 0, 0.5, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restoremagicka.dds' },
    [POWERTYPE_STAMINA] = { 0.5, 0, 75, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorestamina.dds' },
    [ATTRIBUTE_VISUAL_POWER_SHIELDING] = { 1, 0, 0, nil },
}

-- Local helpers
local function FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

local function GetTextureRootPath()
    return "BetterUI/Modules/ResourceOrbFrames/Textures"
end

local function ResolveTexturePath(filename)
    return string.format("%s/%s", GetTextureRootPath(), filename)
end

-------------------------------------------------------------------------------------------------
-- BetterUIOrbBar Class
-------------------------------------------------------------------------------------------------
BetterUIOrbBar = ZO_Object:Subclass()

function BetterUIOrbBar:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BetterUIOrbBar:Initialize(control, powerType)
    self.control = control
    self.fog = FindControl(control, 'Fog')
    self.fog2 = FindControl(control, 'Fog2')
    self.label = FindControl(control, 'Label')
    self.powerType = powerType
    self.currentValue = 0
    self.minValue = 0
    self.maxValue = 0

    local baseCoordLeft, baseCoordRight, baseAnchorX = unpack(ORB_CONFIG[powerType])
    self.baseCoordLeft = baseCoordLeft
    self.baseCoordRight = baseCoordRight
    self.baseAnchorX = baseAnchorX

    -- Animation state for flow effects (horizontal oscillation)
    self.animState = {
        time = 0,          -- Accumulated time for animation cycle
        rotationAngle = 0, -- Current rotation angle (health orb)
    }
end

function BetterUIOrbBar:UpdateValue(value)
    self.currentValue = value
    self:RefreshVisuals()
    self:RefreshLabel()
end

function BetterUIOrbBar:SetValue(value)
    self:UpdateValue(value)
end

function BetterUIOrbBar:SetMinMax(min, max)
    self:SetRange(min, max)
end

function BetterUIOrbBar:GetValue()
    return self.currentValue
end

function BetterUIOrbBar:GetMinMax()
    return self.minValue, self.maxValue
end

function BetterUIOrbBar:GetMax()
    return self.maxValue
end

function BetterUIOrbBar:SetRange(min, max)
    self.minValue = min
    self.maxValue = max
end

function BetterUIOrbBar:RefreshLabel()
    if self.label ~= nil then
        if self.currentValue >= 1000000 then
            self.label:SetText(string.format("%.1fM", self.currentValue / 1000000))
        elseif self.currentValue >= 1000 then
            self.label:SetText(string.format("%.0fk", self.currentValue / 1000))
        else
            self.label:SetText(string.format("%d", self.currentValue))
        end
    end
end

function BetterUIOrbBar:RefreshVisuals()
    local percent = 0
    if self.currentValue >= self.maxValue then
        percent = 100
    elseif self.maxValue ~= 0 then
        percent = zo_roundToNearest((self.currentValue / self.maxValue) * 100, 0.1)
    end

    percent = zo_max(0, percent - 3) -- Visual adjustment

    local fullWidth = self.fillWidth or 150
    local fullHeight = self.fillHeight or 150

    local visibleHeight = (fullHeight * percent) / 100
    local coordTop = 1 - (percent / 100)

    local fillOffsetX = self.fillOffsetX or 0
    local fillOffsetY = self.fillOffsetY or 0

    local isHalfTexture = math.abs(math.abs(self.baseCoordRight - self.baseCoordLeft) - 0.5) < 0.001

    local halfOffsetX = 0
    if isHalfTexture then
        local isLeft = (self.baseCoordLeft < self.baseCoordRight)
        halfOffsetX = isLeft and (-fullWidth / 4) or (fullWidth / 4)
    end

    local verticalOffset = (fullHeight - visibleHeight) / 2

    if self.fog then
        self.fog:SetDimensions(fullWidth, visibleHeight)

        local left = self.baseCoordLeft
        local right = self.baseCoordRight
        if self.animState and self.animState.currentLeft and self.animState.currentRight then
            left = self.animState.currentLeft
            right = self.animState.currentRight
        end

        self.fog:SetTextureCoords(left, right, coordTop, 1)
        self.fog:ClearAnchors()
        self.fog:SetAnchor(CENTER, self.control, CENTER,
            self.baseAnchorX + halfOffsetX + fillOffsetX,
            verticalOffset + fillOffsetY)
    end

    if self.fog2 ~= nil then
        local bgPadding = self.bgPadding or 1.0
        self.fog2:SetDimensions(fullWidth * bgPadding, fullHeight * bgPadding)
        self.fog2:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, 0, 1)
        self.fog2:ClearAnchors()
        self.fog2:SetAnchor(CENTER, self.control, CENTER,
            self.baseAnchorX + halfOffsetX + fillOffsetX,
            fillOffsetY)
    end
end

--- @param deltaMs number Time since last update in milliseconds
--- @param settings table The module settings
function BetterUIOrbBar:UpdateAnimation(deltaMs, settings)
    if not self.fog or not self.animState then return end

    if not settings.orbAnimFlow then
        -- Reset any animation state when flow is disabled
        if self.animState.rotationAngle and self.animState.rotationAngle ~= 0 then
            self.fog:SetTextureRotation(0)
            self.animState.rotationAngle = 0
        end
        self.animState.currentLeft = nil
        self.animState.currentRight = nil
        return
    end

    -- Animation parameters (unified for all orbs)
    local flowRange = 0.0225 -- Horizontal oscillation range
    local flowSpeed = 6500   -- Speed of oscillation cycle in ms

    self.animState.time = self.animState.time + deltaMs

    -- Calculate oscillation offset (gentle horizontal shift)
    local oscillation = math.sin(self.animState.time / flowSpeed * math.pi * 2) * flowRange

    -- Calculate current fill percent
    local percent = 0
    if self.currentValue >= self.maxValue then
        percent = 100
    elseif self.maxValue ~= 0 then
        percent = zo_roundToNearest((self.currentValue / self.maxValue) * 100, 0.1)
    end
    percent = zo_max(0, percent - 3) -- Visual adjustment
    local coordTop = 1 - (percent / 100)

    -- Apply oscillation to texture coordinates
    local scrolledLeft = self.baseCoordLeft + oscillation
    local scrolledRight = self.baseCoordRight + oscillation
    self.fog:SetTextureCoords(scrolledLeft, scrolledRight, coordTop, 1)

    -- Cache current flow state for RefreshVisuals
    self.animState.currentLeft = scrolledLeft
    self.animState.currentRight = scrolledRight

    -- Ensure no rotation is applied (only use horizontal flow)
    if self.animState.rotationAngle and self.animState.rotationAngle ~= 0 then
        self.fog:SetTextureRotation(0)
        self.animState.rotationAngle = 0
    end
end

-------------------------------------------------------------------------------------------------
-- BetterUIShieldBar Class
-------------------------------------------------------------------------------------------------
BetterUIShieldBar = BetterUIOrbBar:Subclass()

function BetterUIShieldBar:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

-- Shield overlay is always static (no animation)
function BetterUIShieldBar:UpdateAnimation() end

function BetterUIShieldBar:RefreshVisuals()
    if not self.fog then return end

    if self.currentValue <= 0 then
        if not BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY then
            self.fog:SetHidden(true)
        end
        return
    end
    self.fog:SetHidden(false)

    local fullWidth = self.fillWidth or 150
    local fullHeight = self.fillHeight or 150
    local fillOffsetX = self.fillOffsetX or 0
    local fillOffsetY = self.fillOffsetY or 0

    self.fog:SetDimensions(fullWidth, fullHeight)
    self.fog:SetTextureCoords(0, 1, 0, 1)

    self.fog:ClearAnchors()
    self.fog:SetAnchor(CENTER, self.control, CENTER,
        self.baseAnchorX + fillOffsetX,
        fillOffsetY)
end

-------------------------------------------------------------------------------------------------
-- Visual Management Functions
-------------------------------------------------------------------------------------------------

--- @param rootFrame Control The root control frame
function Visuals.UpdateFrameDimensions(rootFrame)
    if not rootFrame then return end
    local settings = GetModuleSettings()
    local scale = settings.scale or 1
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 0

    -- Check against cached state in Animations to decide if we should animate
    local lastScale = Animations.GetLastScale and Animations.GetLastScale()
    local lastOffsetX = Animations.GetLastOffsetX and Animations.GetLastOffsetX()
    local lastOffsetY = Animations.GetLastOffsetY and Animations.GetLastOffsetY()

    -- Only animate if we have cached state (i.e., after first run) and values changed
    local hasState = lastScale ~= nil and lastOffsetX ~= nil and lastOffsetY ~= nil
    local changed = hasState and (
        (math.abs(lastScale - scale) > 0.001)
        or (math.abs(lastOffsetX - offsetX) > 0.001)
        or (math.abs(lastOffsetY - offsetY) > 0.001)
    )

    if changed then
        Animations.AnimateDimensions(rootFrame, scale, offsetX, offsetY)
    else
        -- Instant set (initial load or no change)
        rootFrame:SetScale(scale)
        rootFrame:ClearAnchors()
        rootFrame:SetAnchor(BOTTOM, GuiRoot, BOTTOM, offsetX, -offsetY)
        Animations.SetState(scale, offsetX, offsetY)
    end

    local cfg = BETTERUI_ORB_FRAMES
    local isGamepad = IsInGamepadPreferredMode()
    local frameCfg = isGamepad and cfg.frame.gamepad or cfg.frame.keyboard
    rootFrame:SetDimensions(frameCfg.width, frameCfg.height)
end

--- @param rootFrame Control The root control frame
function Visuals.ApplyThemeVisuals(rootFrame)
    if not rootFrame then return end
    local settings = GetModuleSettings()

    local elements = {
        OrnamentLeft = 'OrnamentLeft.dds',
        OrnamentRight = 'OrnamentRight.dds'
    }

    for controlName, textureName in pairs(elements) do
        local ctrl = FindControl(rootFrame, controlName)
        if ctrl and ctrl.SetTexture then
            ctrl:SetTexture(ResolveTexturePath(textureName))
        end
    end

    local function ApplyOrbTextures(parentName)
        local parent = FindControl(rootFrame, parentName)
        if not parent then return end
        local textures = {
            Fog = 'OrbFill.dds',
            Fog2 = 'OrbFill.dds',
            Border = 'OrbBorder.dds',
            Divide = 'OrbSplitter.dds'
        }
        for childName, textureFile in pairs(textures) do
            local child = FindControl(parent, childName)
            if child and child.SetTexture then
                child:SetTexture(ResolveTexturePath(textureFile))
            end
        end
    end

    ApplyOrbTextures('OrbHealth')
    ApplyOrbTextures('OrbMagicka')
    ApplyOrbTextures('OrbStamina')

    local function UpdateOverlay(parentName, textureFile, showOverlay)
        local parent = FindControl(rootFrame, parentName)
        if not parent then return end

        local overlayName = parent:GetName() .. "CustomOverlay"
        local overlay = _G[overlayName]

        if showOverlay then
            if not overlay then
                overlay = WINDOW_MANAGER:CreateControl(overlayName, parent, CT_TEXTURE)
                overlay:SetAnchor(CENTER, parent, CENTER, 0, 0)
                overlay:SetDimensions(256, 256)
                overlay:SetDrawLayer(DL_CONTROLS)
                overlay:SetDrawLevel(15)
            end
            overlay:SetTexture(ResolveTexturePath(textureFile))
            overlay:SetHidden(false)
        else
            if overlay then overlay:SetHidden(true) end
        end
    end

    UpdateOverlay('OrbHealth', 'Health.dds', settings.hideLeftOrnament)
    UpdateOverlay('OrbResource', 'MagStam.dds', settings.hideRightOrnament)

    local shieldOrb = FindControl(rootFrame, 'OrbShield')
    if shieldOrb then
        local fog = FindControl(shieldOrb, 'Fog')
        if fog then
            fog:SetTexture(ResolveTexturePath('OrbOverlay_Shield.dds'))
            fog:SetColor(unpack(DEFAULT_SHIELD_ELECTRIC_COLOR))
        end
    end
end

-- Additional layout, overlay, and shield setup functions were moved to OrbOverlays.lua.
