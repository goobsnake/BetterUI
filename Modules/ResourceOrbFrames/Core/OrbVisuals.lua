--[[
File: Modules/ResourceOrbFrames/OrbVisuals.lua
Purpose: Handles the creation, layout, and maintenance of Resource Orbs (Health, Magicka, Stamina).
         Contains the BetterUIOrbBar and BetterUIShieldBar classes.
Last Modified: 2026-01-23
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Visuals then BETTERUI.ResourceOrbFrames.Visuals = {} end

local Visuals = BETTERUI.ResourceOrbFrames.Visuals
local Animations = BETTERUI.ResourceOrbFrames.Animations
local NAME = "ResourceOrbFrames"

-- Constants
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
    local settings = GetModuleSettings()
    if settings.useCustomTextures then
        return "BetterUI/Modules/ResourceOrbFrames/CustomTextures"
    end
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
        self.fog2:SetDimensions(fullWidth, fullHeight)
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

function BetterUIShieldBar:RefreshVisuals()
    if not self.fog then return end

    if self.currentValue <= 0 then
        self.fog:SetHidden(true)
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
    local offsetY = settings.offsetY or 0

    -- Check against cached state in Animations to decide if we should animate
    local lastScale = Animations.GetLastScale and Animations.GetLastScale()
    local lastOffsetY = Animations.GetLastOffsetY and Animations.GetLastOffsetY()

    -- Only animate if we have cached state (i.e., after first run) and values changed
    local hasState = lastScale ~= nil and lastOffsetY ~= nil
    local changed = hasState and ((math.abs(lastScale - scale) > 0.001) or (math.abs(lastOffsetY - offsetY) > 0.001))

    if changed then
        Animations.AnimateDimensions(rootFrame, scale, offsetY)
    else
        -- Instant set (initial load or no change)
        rootFrame:SetScale(scale)
        rootFrame:ClearAnchors()
        rootFrame:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -offsetY)
        Animations.SetState(scale, offsetY)
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
        if fog then fog:SetTexture(ResolveTexturePath('OrbOverlay_Shield.dds')) end
    end
end

-- Layout Calculation Helpers
local function CalculateBorderSizes(cfg, settings)
    local hideLeft = settings.hideLeftOrnament or false
    local hideRight = settings.hideRightOrnament or false
    local leftSize = cfg.orbs.left.borderSize
    local rightSize = cfg.orbs.right.borderSize
    if hideLeft then leftSize = leftSize * (settings.leftOrbSizeScale or 1.0) end
    if hideRight then rightSize = rightSize * (settings.rightOrbSizeScale or 1.0) end
    return leftSize, rightSize
end

local function CalculateFillDimensions(cfg, leftBorderSize, rightBorderSize)
    return {
        health = { width = math.min(leftBorderSize * cfg.fills.health.scaleW, leftBorderSize), height = math.min(leftBorderSize * cfg.fills.health.scaleH, leftBorderSize), x = cfg.fills.health.x, y = cfg.fills.health.y },
        shield = { width = math.min(leftBorderSize * cfg.fills.shield.scaleW, leftBorderSize), height = math.min(leftBorderSize * cfg.fills.shield.scaleH, leftBorderSize), x = cfg.fills.shield.x, y = cfg.fills.shield.y },
        magicka = { width = math.min(rightBorderSize * cfg.fills.magicka.scaleW, rightBorderSize), height = math.min(rightBorderSize * cfg.fills.magicka.scaleH, rightBorderSize), x = cfg.fills.magicka.x, y = cfg.fills.magicka.y },
        stamina = { width = math.min(rightBorderSize * cfg.fills.stamina.scaleW, rightBorderSize), height = math.min(rightBorderSize * cfg.fills.stamina.scaleH, rightBorderSize), x = cfg.fills.stamina.x, y = cfg.fills.stamina.y },
        resource = { width = math.min(rightBorderSize * cfg.fills.resource.scaleW, rightBorderSize), height = math.min(rightBorderSize * cfg.fills.resource.scaleH, rightBorderSize) }
    }
end

function Visuals.UpdateOrbLayout(rootFrame, pools, shieldBar)
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if not bgMiddle then return end

    local cfg = BETTERUI_ORB_FRAMES
    local settings = GetModuleSettings()

    local leftBorderSize, rightBorderSize = CalculateBorderSizes(cfg, settings)
    local fillParams = CalculateFillDimensions(cfg, leftBorderSize, rightBorderSize)

    local leftOrnament = FindControl(rootFrame, 'OrnamentLeft')
    local rightOrnament = FindControl(rootFrame, 'OrnamentRight')

    if leftOrnament then
        local size = cfg.ornaments.left.size * cfg.ornaments.left.scale
        leftOrnament:SetDimensions(size, size)
        leftOrnament:SetAnchor(CENTER, bgMiddle, CENTER, cfg.ornaments.left.x, cfg.ornaments.left.y)
        leftOrnament:SetHidden(settings.hideLeftOrnament)
    end
    if rightOrnament then
        local size = cfg.ornaments.right.size * cfg.ornaments.right.scale
        rightOrnament:SetDimensions(size, size)
        rightOrnament:SetAnchor(CENTER, bgMiddle, CENTER, cfg.ornaments.right.x, cfg.ornaments.right.y)
        rightOrnament:SetHidden(settings.hideRightOrnament)
    end

    local leftOrb = FindControl(rootFrame, 'OrbHealth')
    if leftOrb then
        leftOrb:ClearAnchors()
        if settings.hideLeftOrnament then
            local nx = cfg.orbs.left.noOrnament and cfg.orbs.left.noOrnament.x or
                (cfg.ornaments.left.x + cfg.orbs.left.x)
            local ny = cfg.orbs.left.noOrnament and cfg.orbs.left.noOrnament.y or
                (cfg.ornaments.left.y + cfg.orbs.left.y)
            leftOrb:SetAnchor(CENTER, bgMiddle, CENTER, nx, ny)
        elseif leftOrnament then
            leftOrb:SetAnchor(CENTER, leftOrnament, CENTER, cfg.orbs.left.x, cfg.orbs.left.y)
        end
        leftOrb:SetDimensions(leftBorderSize, leftBorderSize)
        local border = FindControl(leftOrb, 'Border')
        if border then border:SetDimensions(leftBorderSize, leftBorderSize) end
    end

    local rightOrb = FindControl(rootFrame, 'OrbResource')
    if rightOrb then
        rightOrb:ClearAnchors()
        if settings.hideRightOrnament then
            local nx = cfg.orbs.right.noOrnament and cfg.orbs.right.noOrnament.x or
                (cfg.ornaments.right.x + cfg.orbs.right.x)
            local ny = cfg.orbs.right.noOrnament and cfg.orbs.right.noOrnament.y or
                (cfg.ornaments.right.y + cfg.orbs.right.y)
            rightOrb:SetAnchor(CENTER, bgMiddle, CENTER, nx, ny)
        elseif rightOrnament then
            rightOrb:SetAnchor(CENTER, rightOrnament, CENTER, cfg.orbs.right.x, cfg.orbs.right.y)
        end
        rightOrb:SetDimensions(rightBorderSize, rightBorderSize)

        for _, name in ipairs({ 'OrbMagicka', 'OrbStamina' }) do
            local cont = FindControl(rightOrb, name)
            if cont then
                cont:SetDimensions(rightBorderSize, rightBorderSize)
                cont:ClearAnchors()
                cont:SetAnchor(CENTER, rightOrb, CENTER, 0, 0)
                local b = FindControl(cont, 'Border')
                if b then b:SetDimensions(rightBorderSize, rightBorderSize) end
                local div = FindControl(cont, 'Divide')
                if div then
                    div:SetDimensions(cfg.splitter.width, rightBorderSize * cfg.splitter.heightScale)
                    div:SetAnchor(CENTER, cont, CENTER, cfg.splitter.x, cfg.splitter.y)
                end
            end
        end
    end

    local function UpdateOverlaySize(parent, cfgName, baseSize)
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
    UpdateOverlaySize(leftOrb, 'health', leftBorderSize)
    UpdateOverlaySize(rightOrb, 'magStam', rightBorderSize)

    if pools then
        if pools[POWERTYPE_HEALTH] then
            pools[POWERTYPE_HEALTH].fillWidth = fillParams.health.width
            pools[POWERTYPE_HEALTH].fillHeight = fillParams.health.height
            pools[POWERTYPE_HEALTH].fillOffsetX = fillParams.health.x
            pools[POWERTYPE_HEALTH].fillOffsetY = fillParams.health.y
            if pools[POWERTYPE_HEALTH].label then
                pools[POWERTYPE_HEALTH].label:ClearAnchors()
                pools[POWERTYPE_HEALTH].label:SetAnchor(CENTER, pools[POWERTYPE_HEALTH].control, CENTER,
                    cfg.labels.health.x, cfg.labels.health.y)
            end
        end
        if pools[POWERTYPE_MAGICKA] then
            pools[POWERTYPE_MAGICKA].fillWidth = fillParams.magicka.width
            pools[POWERTYPE_MAGICKA].fillHeight = fillParams.magicka.height
            pools[POWERTYPE_MAGICKA].fillOffsetX = fillParams.magicka.x
            pools[POWERTYPE_MAGICKA].fillOffsetY = fillParams.magicka.y
            if pools[POWERTYPE_MAGICKA].label then
                pools[POWERTYPE_MAGICKA].label:ClearAnchors()
                pools[POWERTYPE_MAGICKA].label:SetAnchor(CENTER, pools[POWERTYPE_MAGICKA].control, CENTER,
                    cfg.labels.magicka.x, cfg.labels.magicka.y)
            end
        end
        if pools[POWERTYPE_STAMINA] then
            pools[POWERTYPE_STAMINA].fillWidth = fillParams.stamina.width
            pools[POWERTYPE_STAMINA].fillHeight = fillParams.stamina.height
            pools[POWERTYPE_STAMINA].fillOffsetX = fillParams.stamina.x
            pools[POWERTYPE_STAMINA].fillOffsetY = fillParams.stamina.y
            if pools[POWERTYPE_STAMINA].label then
                pools[POWERTYPE_STAMINA].label:ClearAnchors()
                pools[POWERTYPE_STAMINA].label:SetAnchor(CENTER, pools[POWERTYPE_STAMINA].control, CENTER,
                    cfg.labels.stamina.x, cfg.labels.stamina.y)
            end
        end
    end

    if shieldBar then
        local sOrb = FindControl(rootFrame, 'OrbShield')
        if sOrb then
            local size = leftBorderSize * cfg.fills.shield.ringScale
            sOrb:SetDimensions(size, size)
            sOrb:SetAnchor(CENTER, leftOrb, CENTER, 0, 0)
            local lbl = FindControl(sOrb, 'Label')
            if lbl then lbl:SetAnchor(CENTER, leftOrb, CENTER, cfg.labels.shield.x, cfg.labels.shield.y) end
        end

        shieldBar.fillWidth = fillParams.shield.width
        shieldBar.fillHeight = fillParams.shield.height
        shieldBar.fillOffsetX = fillParams.shield.x
        shieldBar.fillOffsetY = fillParams.shield.y
    end
end

-------------------------------------------------------------------------------------------------
-- Setup Functions
-------------------------------------------------------------------------------------------------
function Visuals.SetupPowerPools(rootFrame)
    local cfg = BETTERUI_ORB_FRAMES

    local pools = {
        [POWERTYPE_HEALTH] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbHealth'), POWERTYPE_HEALTH),
        [POWERTYPE_MAGICKA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbMagicka'), POWERTYPE_MAGICKA),
        [POWERTYPE_STAMINA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbStamina'), POWERTYPE_STAMINA),
    }

    local function AddOrbTooltip(control, powerType)
        if not control then return end
        control:SetMouseEnabled(true)
        control:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, RIGHT, -5, 0)
            local current, max = GetUnitPower("player", powerType)
            SetTooltipText(InformationTooltip, string.format("%d / %d", current, max))
        end)
        control:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    end

    AddOrbTooltip(FindControl(rootFrame, 'OrbHealth'), POWERTYPE_HEALTH)

    local magickaOrb = FindControl(rootFrame, 'OrbMagicka')
    local staminaOrb = FindControl(rootFrame, 'OrbStamina')

    if magickaOrb and staminaOrb then
        local magickaHitBox = WINDOW_MANAGER:CreateControl("BetterUIEndsOrbMagickaHitBox", magickaOrb, CT_CONTROL)
        magickaHitBox:ClearAnchors()
        magickaHitBox:SetAnchor(TOPLEFT, magickaOrb, TOPLEFT, 0, 0)
        magickaHitBox:SetAnchor(BOTTOMRIGHT, magickaOrb, BOTTOM, 0, 0)

        local staminaHitBox = WINDOW_MANAGER:CreateControl("BetterUIEndsOrbStaminaHitBox", staminaOrb, CT_CONTROL)
        staminaHitBox:ClearAnchors()
        staminaHitBox:SetAnchor(TOPLEFT, staminaOrb, TOP, 0, 0)
        staminaHitBox:SetAnchor(BOTTOMRIGHT, staminaOrb, BOTTOMRIGHT, 0, 0)

        AddOrbTooltip(magickaHitBox, POWERTYPE_MAGICKA)
        AddOrbTooltip(staminaHitBox, POWERTYPE_STAMINA)

        magickaOrb:SetMouseEnabled(false)
        staminaOrb:SetMouseEnabled(false)
    end

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "_PowerUpdate", EVENT_POWER_UPDATE,
        function(_, _, _, powerType, powerValue, powerMax)
            local pool = pools[powerType]
            if pool ~= nil then
                ZO_StatusBar_SmoothTransition(pool, powerValue, powerMax)
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")

    return pools
end

function Visuals.SetupShieldBar(rootFrame, pools)
    local shieldBar = BetterUIShieldBar:New(FindControl(rootFrame, 'OrbShield'), ATTRIBUTE_VISUAL_POWER_SHIELDING)

    local debugShield = BETTERUI_SHIELD_DEBUG or false
    if debugShield then
        if shieldBar.control then shieldBar.control:SetHidden(false) end
        if shieldBar.fog then shieldBar.fog:SetHidden(false) end
        shieldBar.label:GetParent():SetHidden(false)
    else
        if shieldBar.control then shieldBar.control:SetHidden(true) end
        shieldBar.label:GetParent():SetHidden(true)
    end

    if shieldBar.label then
        local settings = GetModuleSettings()
        local shieldTextSize = settings.shieldTextSize or 20
        local shieldTextColor = settings.shieldTextColor or { 0, 1, 1, 1 }
        shieldBar.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", shieldTextSize))
        shieldBar.label:SetColor(unpack(shieldTextColor))

        local shieldIcon = FindControl(shieldBar.control, 'ShieldIcon')
        if shieldIcon then
            local iconSize = math.floor(shieldTextSize * 1.25)
            shieldIcon:SetDimensions(iconSize, iconSize)
        end
    end

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "_ShieldAdded",
        EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,
        function(_, _, unitAttributeVisual, _, _, _, value)
            if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                if shieldBar.fog then shieldBar.fog:SetHidden(false) end
                shieldBar.label:GetParent():SetHidden(false)
                ZO_StatusBar_SmoothTransition(shieldBar, value, pools[POWERTYPE_HEALTH]:GetMax())
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "_ShieldUpdated",
        EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,
        function(_, _, unitAttributeVisual, _, _, _, _, newValue)
            if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                ZO_StatusBar_SmoothTransition(shieldBar, newValue, pools[POWERTYPE_HEALTH]:GetMax())
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "_ShieldRemoved",
        EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, _, unitAttributeVisual)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING and not debugShield then
            ZO_StatusBar_SmoothTransition(shieldBar, 0, pools[POWERTYPE_HEALTH]:GetMax())
            shieldBar.label:GetParent():SetHidden(true)
            if shieldBar.fog then shieldBar.fog:SetHidden(true) end
        end
    end, REGISTER_FILTER_UNIT_TAG, "player")

    return shieldBar
end
