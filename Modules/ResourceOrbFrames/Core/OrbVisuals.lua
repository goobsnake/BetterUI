--[[
File: Modules/ResourceOrbFrames/OrbVisuals.lua
Purpose: Handles the creation, layout, and maintenance of Resource Orbs (Health, Magicka, Stamina).
         Contains the BetterUIOrbBar and BetterUIShieldBar classes.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Visuals then BETTERUI.ResourceOrbFrames.Visuals = {} end

local Visuals = BETTERUI.ResourceOrbFrames.Visuals
local Animations = BETTERUI.ResourceOrbFrames.Animations
local NAME = "ResourceOrbFrames"
local DEFAULT_SHIELD_ELECTRIC_COLOR = { 0.4, 0.9, 1, 1 }

--- ORB_CONFIG: Per-powertype orb fill texture-coordinate configuration.
--- Indexed by ESO POWERTYPE_* or ATTRIBUTE_VISUAL_* constants.
--- Each entry is an array: { baseCoordLeft, baseCoordRight, baseAnchorX }
---   [1] baseCoordLeft  (number) — base left texture coordinate of the fill window
---   [2] baseCoordRight (number) — base right texture coordinate of the fill window
---   [3] baseAnchorX    (number) — base fill anchor X offset in pixels (scaled by border size)
local ORB_CONFIG = {
    [POWERTYPE_HEALTH]  = { 0,   1,   0 },
    [POWERTYPE_MAGICKA] = { 0,   0.5, 0 },
    [POWERTYPE_STAMINA] = { 0.5, 0,   75 },
    [ATTRIBUTE_VISUAL_POWER_SHIELDING] = { 1, 0, 0 },
}

-- Local helpers
local FindControl = BETTERUI.ControlUtils.FindControl
local FindOptionalControl = BETTERUI.ControlUtils.FindOptionalControl
local GetSettings = BETTERUI.ResourceOrbFrames.Utils.GetSettings

local function GetElemOffset(settings, key)
    local ep = settings and settings.elementPositions
    if not ep or not ep[key] then return 0, 0 end
    return ep[key].offsetX or 0, ep[key].offsetY or 0
end

local function GetTextureRootPath()
    return "BetterUI/Modules/ResourceOrbFrames/Textures"
end

local function ResolveTexturePath(filename)
    return string.format("%s/%s", GetTextureRootPath(), filename)
end

local function TraceOrbVisuals(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "orbVisuals"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.STATE or categories.ACTION, event, phase, data)
end

local function InitializeOrbState(orbBar, powerType)
    orbBar.powerType = powerType
    orbBar.currentValue = 0
    orbBar.minValue = 0
    orbBar.maxValue = 0

    local baseCoordLeft, baseCoordRight, baseAnchorX = unpack(ORB_CONFIG[powerType])
    orbBar.baseCoordLeft = baseCoordLeft
    orbBar.baseCoordRight = baseCoordRight
    orbBar.baseAnchorX = baseAnchorX

    orbBar.animState = {
        time = 0,
        rotationAngle = 0,
    }
end

---@class BetterUIOrbBar : ZO_Object
---@field control table Parent UI control
---@field fog table Fill texture control
---@field fog2 table Background fill texture control
---@field label table|nil Text label control
---@field powerType number ESO POWERTYPE_* constant
---@field currentValue number Current resource value
---@field minValue number Minimum resource value
---@field maxValue number Maximum resource value
---@field baseCoordLeft number Left texture coordinate base
---@field baseCoordRight number Right texture coordinate base
---@field baseAnchorX number Base anchor X offset
---@field animState table Animation state for flow effects
BetterUIOrbBar = ZO_Object:Subclass()

---@param ... any Forwarded to Initialize
---@return BetterUIOrbBar
function BetterUIOrbBar:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

---@param control table Parent UI control
---@param powerType number ESO POWERTYPE_* constant
function BetterUIOrbBar:Initialize(control, powerType)
    self.control = control
    self.fog = FindControl(control, 'Fog')
    self.fog2 = FindControl(control, 'Fog2')
    self.label = FindControl(control, 'Label')
    InitializeOrbState(self, powerType)
end

---@param value number New resource value to display
function BetterUIOrbBar:UpdateValue(value)
    self.currentValue = value
    self:RefreshVisuals()
    self:RefreshLabel()
    local L = BETTERUI.Log
    if not (L and L.Trace) then return end
    local categories = L.CATEGORY or {}
    local levels = L.LEVEL or {}
    if L.EnabledFor and not L.EnabledFor(levels.TRACE, categories.GENERAL) then return end
    local percent = 0
    local max = self.maxValue
    if max and max > 0 then
        percent = math.floor((value / max) * 100)
    end
    local bracket = math.floor(percent / 10)
    if self._betteruiLastValueBracket ~= bracket then
        self._betteruiLastValueBracket = bracket
        L.Trace(categories.GENERAL, "orb value bracket", {
            module = "ResourceOrbFrames",
            feature = "resourceOrbs",
            powerType = self.powerType,
            cur = value,
            max = max,
            pct = percent,
            bracket = bracket,
        })
    end
end

---@param value number New resource value
function BetterUIOrbBar:SetValue(value)
    self:UpdateValue(value)
end

---@param min number Minimum range value
---@param max number Maximum range value
function BetterUIOrbBar:SetMinMax(min, max)
    self:SetRange(min, max)
end

---@return number value Current resource value
function BetterUIOrbBar:GetValue()
    return self.currentValue
end

---@return number min Minimum value
---@return number max Maximum value
function BetterUIOrbBar:GetMinMax()
    return self.minValue, self.maxValue
end

---@return number max Maximum value
function BetterUIOrbBar:GetMax()
    return self.maxValue
end

---@param min number Minimum resource value
---@param max number Maximum resource value
function BetterUIOrbBar:SetRange(min, max)
    self.minValue = min
    self.maxValue = max
end

function BetterUIOrbBar:RefreshLabel()
    if self.label ~= nil then
        local labelText
        if self.currentValue >= 1000000 then
            labelText = string.format("%.1fM", self.currentValue / 1000000)
        elseif self.currentValue >= 1000 then
            labelText = string.format("%.0fk", self.currentValue / 1000)
        else
            labelText = string.format("%d", self.currentValue)
        end
        -- Driven every animation frame during the 500ms smooth-transition after
        -- each power change; the bucketed string is identical across most of
        -- those frames. Latch it and skip the redundant SetText.
        if labelText ~= self._lastLabelText then
            self._lastLabelText = labelText
            self.label:SetText(labelText)
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

---@class BetterUIShieldBar : BetterUIOrbBar
---@field fillWidth number|nil Shield fill width override
---@field fillHeight number|nil Shield fill height override
---@field fillOffsetX number|nil Shield fill X offset
---@field fillOffsetY number|nil Shield fill Y offset
BetterUIShieldBar = BetterUIOrbBar:Subclass()

---@param ... any Forwarded to Initialize
---@return BetterUIShieldBar
function BetterUIShieldBar:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BetterUIShieldBar:Initialize(control, powerType)
    self.control = control
    self.fog = FindControl(control, 'Fog')
    self.fog2 = nil
    self.label = FindControl(control, 'Label')
    InitializeOrbState(self, powerType)
end

-- Shield overlay is always static (no animation)
function BetterUIShieldBar:UpdateAnimation() end

function BetterUIShieldBar:RefreshVisuals()
    if not self.fog then return end

    if self.currentValue <= 0 then
        if not BETTERUI_SHIELD_DEBUG then
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

-- Visual Management Functions

---@param rootFrame table Root ResourceOrbFrames control
function Visuals.UpdateFrameDimensions(rootFrame)
    if not rootFrame then return end
    local settings = GetSettings()
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
        -- Anchor to GuiRoot intentionally: orb frames are HUD-level overlays independent of scene fragments.
        rootFrame:SetAnchor(BOTTOM, GuiRoot, BOTTOM, offsetX, -offsetY)
        Animations.SetState(scale, offsetX, offsetY)
    end

    local cfg = BETTERUI_ORB_FRAMES
    local isGamepad = IsInGamepadPreferredMode()
    local frameCfg = isGamepad and cfg.frame.gamepad or cfg.frame.keyboard
    rootFrame:SetDimensions(frameCfg.width, frameCfg.height)
end

---@param rootFrame table Root ResourceOrbFrames control
function Visuals.ApplyThemeVisuals(rootFrame)
    if not rootFrame then return end

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

    local function ApplyOrbTextures(parentName, textures)
        local parent = FindControl(rootFrame, parentName)
        if not parent then return end
        for _, texture in ipairs(textures) do
            local childName = texture[1]
            local textureFile = texture[2]
            local child = FindControl(parent, childName)
            if child and child.SetTexture then
                child:SetTexture(ResolveTexturePath(textureFile))
            end
        end
    end

    ApplyOrbTextures('OrbHealth', {
        { 'Fog', 'OrbFill.dds' },
        { 'Fog2', 'OrbFill.dds' },
        { 'Border', 'OrbBorder.dds' },
    })
    ApplyOrbTextures('OrbMagicka', {
        { 'Fog', 'OrbFill.dds' },
        { 'Fog2', 'OrbFill.dds' },
        { 'Border', 'OrbBorder.dds' },
        { 'Divide', 'OrbSplitter.dds' },
    })
    ApplyOrbTextures('OrbStamina', {
        { 'Fog', 'OrbFill.dds' },
        { 'Fog2', 'OrbFill.dds' },
    })

    local shieldOrb = FindControl(rootFrame, 'OrbShield')
    if shieldOrb then
        local fog = FindControl(shieldOrb, 'Fog')
        if fog then
            fog:SetTexture(ResolveTexturePath('OrbOverlay_Shield.dds'))
            fog:SetColor(unpack(DEFAULT_SHIELD_ELECTRIC_COLOR))
        end
    end
end

-- Layout Calculation Helpers
-- Import shared utilities (canonical definitions in Utils.lua)
local ScaleForBorder = BETTERUI.ResourceOrbFrames.Utils.ScaleForBorder
local CalculateBorderSizes = BETTERUI.ResourceOrbFrames.Utils.CalculateBorderSizes
local CalculateFillDimensions = BETTERUI.ResourceOrbFrames.Utils.CalculateFillDimensions

---@param rootFrame table Root ResourceOrbFrames control
---@param pools table<number, BetterUIOrbBar> Power type to orb bar mapping
---@param shieldBar BetterUIShieldBar|nil Shield bar instance
function Visuals.UpdateOrbLayout(rootFrame, pools, shieldBar)
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if not bgMiddle then return end

    local cfg = BETTERUI_ORB_FRAMES
    local settings = GetSettings()

    local leftBorderSize, rightBorderSize, leftVisibleScale, rightVisibleScale = CalculateBorderSizes(cfg, settings)
    local fillParams = CalculateFillDimensions(cfg, leftBorderSize, rightBorderSize)

    local leftOrnament = FindControl(rootFrame, 'OrnamentLeft')
    local rightOrnament = FindControl(rootFrame, 'OrnamentRight')

    -- Independent orb offset moves the whole orb composite: the ornaments
    -- shift, and ornament-anchored orbs follow them (no double-apply).
    local orbOffsetX = settings.enableIndependentOrbOffset and (settings.orbOffsetX or 0) or 0
    local orbOffsetY = settings.enableIndependentOrbOffset and (settings.orbOffsetY or 0) or 0
    local loX, loY = GetElemOffset(settings, "leftOrb")
    local roX, roY = GetElemOffset(settings, "rightOrb")

    if leftOrnament then
        local size = cfg.ornaments.left.size * cfg.ornaments.left.scale
        leftOrnament:SetDimensions(size, size)
        leftOrnament:SetAnchor(CENTER, bgMiddle, CENTER, cfg.ornaments.left.x + orbOffsetX + loX, cfg.ornaments.left.y + orbOffsetY + loY)
        leftOrnament:SetHidden(settings.hideLeftOrnament)
    end
    if rightOrnament then
        local size = cfg.ornaments.right.size * cfg.ornaments.right.scale
        rightOrnament:SetDimensions(size, size)
        rightOrnament:SetAnchor(CENTER, bgMiddle, CENTER, cfg.ornaments.right.x + orbOffsetX + roX, cfg.ornaments.right.y + orbOffsetY + roY)
        rightOrnament:SetHidden(settings.hideRightOrnament)
    end

    local leftOrb = FindControl(rootFrame, 'OrbHealth')
    local leftBranch = "missingOrb"
    if leftOrb then
        leftOrb:ClearAnchors()
        if settings.hideLeftOrnament then
            leftBranch = "noOrnament"
            local nx = ((cfg.orbs.left.noOrnament and cfg.orbs.left.noOrnament.x ~= nil)
                and cfg.orbs.left.noOrnament.x or (cfg.ornaments.left.x + cfg.orbs.left.x)) + orbOffsetX + loX
            local ny = ((cfg.orbs.left.noOrnament and cfg.orbs.left.noOrnament.y ~= nil)
                and cfg.orbs.left.noOrnament.y or (cfg.ornaments.left.y + cfg.orbs.left.y)) + orbOffsetY + loY
            leftOrb:SetAnchor(CENTER, bgMiddle, CENTER, nx, ny)
        elseif leftOrnament then
            leftBranch = "ornament"
            -- Ornament anchor already carries the orb offset; don't re-apply.
            leftOrb:SetAnchor(CENTER, leftOrnament, CENTER,
                cfg.orbs.left.x * leftVisibleScale,
                cfg.orbs.left.y * leftVisibleScale)
        else
            leftBranch = "bgMiddleFallback"
            -- Fallback: ornament expected but not found; anchor to bgMiddle
            leftOrb:SetAnchor(CENTER, bgMiddle, CENTER,
                cfg.ornaments.left.x + cfg.orbs.left.x + orbOffsetX + loX,
                cfg.ornaments.left.y + cfg.orbs.left.y + orbOffsetY + loY)
        end
        leftOrb:SetDimensions(leftBorderSize, leftBorderSize)
        local border = FindControl(leftOrb, 'Border')
        if border then border:SetDimensions(leftBorderSize, leftBorderSize) end
    end

    local rightOrb = FindControl(rootFrame, 'OrbResource')
    local rightBranch = "missingOrb"
    if rightOrb then
        rightOrb:ClearAnchors()
        if settings.hideRightOrnament then
            rightBranch = "noOrnament"
            local nx = ((cfg.orbs.right.noOrnament and cfg.orbs.right.noOrnament.x ~= nil)
                and cfg.orbs.right.noOrnament.x or (cfg.ornaments.right.x + cfg.orbs.right.x)) + orbOffsetX + roX
            local ny = ((cfg.orbs.right.noOrnament and cfg.orbs.right.noOrnament.y ~= nil)
                and cfg.orbs.right.noOrnament.y or (cfg.ornaments.right.y + cfg.orbs.right.y)) + orbOffsetY + roY
            rightOrb:SetAnchor(CENTER, bgMiddle, CENTER, nx, ny)
        elseif rightOrnament then
            rightBranch = "ornament"
            -- Ornament anchor already carries the orb offset; don't re-apply.
            rightOrb:SetAnchor(CENTER, rightOrnament, CENTER,
                cfg.orbs.right.x * rightVisibleScale,
                cfg.orbs.right.y * rightVisibleScale)
        else
            rightBranch = "bgMiddleFallback"
            rightOrb:SetAnchor(CENTER, bgMiddle, CENTER,
                cfg.ornaments.right.x + cfg.orbs.right.x + orbOffsetX + roX,
                cfg.ornaments.right.y + cfg.orbs.right.y + orbOffsetY + roY)
        end
        rightOrb:SetDimensions(rightBorderSize, rightBorderSize)

        for _, name in ipairs({ 'OrbMagicka', 'OrbStamina' }) do
            local cont = FindControl(rightOrb, name)
            if cont then
                cont:SetDimensions(rightBorderSize, rightBorderSize)
                cont:ClearAnchors()
                cont:SetAnchor(CENTER, rightOrb, CENTER, 0, 0)
                local b
                if name == 'OrbStamina' then
                    b = FindOptionalControl(cont, 'Border', 'Visuals.UpdateOrbLayout')
                else
                    b = FindControl(cont, 'Border', 'Visuals.UpdateOrbLayout')
                end
                if b then b:SetDimensions(rightBorderSize, rightBorderSize) end
                local div
                if name == 'OrbStamina' then
                    div = FindOptionalControl(cont, 'Divide', 'Visuals.UpdateOrbLayout')
                else
                    div = FindControl(cont, 'Divide', 'Visuals.UpdateOrbLayout')
                end
                if div then
                    local rightBaseSize = cfg.orbs.right.borderSize or rightBorderSize
                    local splitterWidth = math.min(
                        ScaleForBorder(cfg.splitter.width, rightBorderSize, rightBaseSize),
                        rightBorderSize)
                    local splitterOffsetX = ScaleForBorder(cfg.splitter.x, rightBorderSize, rightBaseSize)
                    local splitterOffsetY = ScaleForBorder(cfg.splitter.y, rightBorderSize, rightBaseSize)
                    div:SetDimensions(splitterWidth, rightBorderSize * cfg.splitter.heightScale)
                    div:SetAnchor(CENTER, cont, CENTER, splitterOffsetX, splitterOffsetY)
                end
            end
        end
    end

    if pools then
        -- Refresh label font/color from current settings (enables realtime updates)
        local fontSettings = {
            [POWERTYPE_HEALTH]  = { size = settings.healthTextSize or 20,  color = settings.healthTextColor or { 1, 1, 1, 1 } },
            [POWERTYPE_MAGICKA] = { size = settings.magickaTextSize or 20, color = settings.magickaTextColor or { 1, 1, 1, 1 } },
            [POWERTYPE_STAMINA] = { size = settings.staminaTextSize or 20, color = settings.staminaTextColor or { 1, 1, 1, 1 } },
        }

        -- Original orb control size from XML (used to scale baseAnchorX)
        local BASE_ORB_CONTROL_SIZE = 150

        local bgPad = BETTERUI.ResourceOrbFrames.CONST.ORBS_BG_FILL_PADDING or {}

        if pools[POWERTYPE_HEALTH] then
            pools[POWERTYPE_HEALTH].fillWidth = fillParams.health.width
            pools[POWERTYPE_HEALTH].fillHeight = fillParams.health.height
            pools[POWERTYPE_HEALTH].fillOffsetX = fillParams.health.x
            pools[POWERTYPE_HEALTH].fillOffsetY = fillParams.health.y
            pools[POWERTYPE_HEALTH].bgPadding = bgPad.health or 1.0
            pools[POWERTYPE_HEALTH].baseAnchorX = ORB_CONFIG[POWERTYPE_HEALTH][3] * (leftBorderSize / BASE_ORB_CONTROL_SIZE)
            if pools[POWERTYPE_HEALTH].label then
                pools[POWERTYPE_HEALTH].label:ClearAnchors()
                pools[POWERTYPE_HEALTH].label:SetAnchor(CENTER, pools[POWERTYPE_HEALTH].control, CENTER,
                    ScaleForBorder(cfg.labels.health.x, leftBorderSize, cfg.orbs.left.borderSize),
                    ScaleForBorder(cfg.labels.health.y, leftBorderSize, cfg.orbs.left.borderSize))
                local fs = fontSettings[POWERTYPE_HEALTH]
                pools[POWERTYPE_HEALTH].label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", fs.size))
                pools[POWERTYPE_HEALTH].label:SetColor(unpack(fs.color))
            end
        end
        if pools[POWERTYPE_MAGICKA] then
            pools[POWERTYPE_MAGICKA].fillWidth = fillParams.magicka.width
            pools[POWERTYPE_MAGICKA].fillHeight = fillParams.magicka.height
            pools[POWERTYPE_MAGICKA].fillOffsetX = fillParams.magicka.x
            pools[POWERTYPE_MAGICKA].fillOffsetY = fillParams.magicka.y
            pools[POWERTYPE_MAGICKA].bgPadding = bgPad.magicka or 1.0
            pools[POWERTYPE_MAGICKA].baseAnchorX = ORB_CONFIG[POWERTYPE_MAGICKA][3] * (rightBorderSize / BASE_ORB_CONTROL_SIZE)
            if pools[POWERTYPE_MAGICKA].label then
                pools[POWERTYPE_MAGICKA].label:ClearAnchors()
                pools[POWERTYPE_MAGICKA].label:SetAnchor(CENTER, pools[POWERTYPE_MAGICKA].control, CENTER,
                    ScaleForBorder(cfg.labels.magicka.x, rightBorderSize, cfg.orbs.right.borderSize),
                    ScaleForBorder(cfg.labels.magicka.y, rightBorderSize, cfg.orbs.right.borderSize))
                local fs = fontSettings[POWERTYPE_MAGICKA]
                pools[POWERTYPE_MAGICKA].label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", fs.size))
                pools[POWERTYPE_MAGICKA].label:SetColor(unpack(fs.color))
            end
        end
        if pools[POWERTYPE_STAMINA] then
            pools[POWERTYPE_STAMINA].fillWidth = fillParams.stamina.width
            pools[POWERTYPE_STAMINA].fillHeight = fillParams.stamina.height
            pools[POWERTYPE_STAMINA].fillOffsetX = fillParams.stamina.x
            pools[POWERTYPE_STAMINA].fillOffsetY = fillParams.stamina.y
            pools[POWERTYPE_STAMINA].bgPadding = bgPad.stamina or 1.0
            pools[POWERTYPE_STAMINA].baseAnchorX = ORB_CONFIG[POWERTYPE_STAMINA][3] * (rightBorderSize / BASE_ORB_CONTROL_SIZE)
            if pools[POWERTYPE_STAMINA].label then
                pools[POWERTYPE_STAMINA].label:ClearAnchors()
                pools[POWERTYPE_STAMINA].label:SetAnchor(CENTER, pools[POWERTYPE_STAMINA].control, CENTER,
                    ScaleForBorder(cfg.labels.stamina.x, rightBorderSize, cfg.orbs.right.borderSize),
                    ScaleForBorder(cfg.labels.stamina.y, rightBorderSize, cfg.orbs.right.borderSize))
                local fs = fontSettings[POWERTYPE_STAMINA]
                pools[POWERTYPE_STAMINA].label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", fs.size))
                pools[POWERTYPE_STAMINA].label:SetColor(unpack(fs.color))
            end
        end
    end

    if shieldBar then
        local sOrb = FindControl(rootFrame, 'OrbShield')
        if sOrb then
            local size = leftBorderSize * cfg.fills.shield.ringScale
            sOrb:SetDimensions(size, size)
            if leftOrb then
                sOrb:SetAnchor(CENTER, leftOrb, CENTER, 0, 0)
            else
                sOrb:SetAnchor(CENTER, bgMiddle, CENTER,
                    cfg.ornaments.left.x + cfg.orbs.left.x + orbOffsetX + loX,
                    cfg.ornaments.left.y + cfg.orbs.left.y + orbOffsetY + loY)
            end
            local lbl = FindControl(sOrb, 'Label')
            if lbl then
                lbl:SetAnchor(CENTER, leftOrb, CENTER,
                    ScaleForBorder(cfg.labels.shield.x, leftBorderSize, cfg.orbs.left.borderSize),
                    ScaleForBorder(cfg.labels.shield.y, leftBorderSize, cfg.orbs.left.borderSize))
                local shieldTextSize = settings.shieldTextSize or 20
                local shieldTextColor = settings.shieldTextColor or DEFAULT_SHIELD_ELECTRIC_COLOR
                lbl:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", shieldTextSize))
                lbl:SetColor(unpack(shieldTextColor))
            end
        end

        shieldBar.fillWidth = fillParams.shield.width
        shieldBar.fillHeight = fillParams.shield.height
        shieldBar.fillOffsetX = fillParams.shield.x
        shieldBar.fillOffsetY = fillParams.shield.y
    end
    TraceOrbVisuals("resource_orbs.orb_layout", "applied", {
        fn = "Visuals.UpdateOrbLayout",
        leftBranch = leftBranch,
        rightBranch = rightBranch,
        leftBorderSize = leftBorderSize,
        rightBorderSize = rightBorderSize,
        orbOffsetX = orbOffsetX,
        orbOffsetY = orbOffsetY,
        hideLeftOrnament = settings.hideLeftOrnament == true,
        hideRightOrnament = settings.hideRightOrnament == true,
        hasShield = shieldBar ~= nil,
    })
end

-- Setup Functions
---@param rootFrame table Root ResourceOrbFrames control
---@return table<number, BetterUIOrbBar> pools Power type to orb bar mapping
function Visuals.SetupPowerPools(rootFrame)

    local pools = {
        [POWERTYPE_HEALTH] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbHealth'), POWERTYPE_HEALTH),
        [POWERTYPE_MAGICKA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbMagicka'), POWERTYPE_MAGICKA),
        [POWERTYPE_STAMINA] = BetterUIOrbBar:New(FindControl(rootFrame, 'OrbStamina'), POWERTYPE_STAMINA),
    }

    -- Apply font and color settings to resource labels (same style as shield: bold + thick-outline)
    local settings = GetSettings()
    local fontSettings = {
        [POWERTYPE_HEALTH]  = { size = settings.healthTextSize or 20,  color = settings.healthTextColor or { 1, 1, 1, 1 } },
        [POWERTYPE_MAGICKA] = { size = settings.magickaTextSize or 20, color = settings.magickaTextColor or { 1, 1, 1, 1 } },
        [POWERTYPE_STAMINA] = { size = settings.staminaTextSize or 20, color = settings.staminaTextColor or { 1, 1, 1, 1 } },
    }
    for powerType, fontCfg in pairs(fontSettings) do
        local label = pools[powerType] and pools[powerType].label
        if label then
            label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", fontCfg.size))
            label:SetColor(unpack(fontCfg.color))
        end
    end

    -- Import shared tooltip utility (canonical definition in Utils.lua)
    local AddOrbTooltip = BETTERUI.ResourceOrbFrames.Utils.AddOrbTooltip

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

    BETTERUI.CIM.EventRegistry.RegisterFiltered("BETTERUI_ResourceOrbFrames", NAME .. "_PowerUpdate", EVENT_POWER_UPDATE,
        function(_, _, _, powerType, powerValue, powerMax)
            local pool = pools[powerType]
            if pool ~= nil then
                ZO_StatusBar_SmoothTransition(pool, powerValue, powerMax)
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")

    return pools
end

---@param rootFrame table Root ResourceOrbFrames control
---@param pools table<number, BetterUIOrbBar> Power pools for health max fallback
---@return BetterUIShieldBar shieldBar The created shield bar instance
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
        local settings = GetSettings()
        local shieldTextSize = settings.shieldTextSize or 20
        local shieldTextColor = settings.shieldTextColor or DEFAULT_SHIELD_ELECTRIC_COLOR
        shieldBar.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", shieldTextSize))
        shieldBar.label:SetColor(unpack(shieldTextColor))
        if shieldBar.fog then
            shieldBar.fog:SetColor(unpack(DEFAULT_SHIELD_ELECTRIC_COLOR))
        end
    end

    BETTERUI.CIM.EventRegistry.RegisterFiltered("BETTERUI_ResourceOrbFrames", NAME .. "_ShieldAdded",
        EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,
        function(_, _, unitAttributeVisual, _, _, _, value)
            if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                if shieldBar.fog then shieldBar.fog:SetHidden(false) end
                shieldBar.label:GetParent():SetHidden(false)
                ZO_StatusBar_SmoothTransition(shieldBar, value, pools[POWERTYPE_HEALTH]:GetMax())
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")

    BETTERUI.CIM.EventRegistry.RegisterFiltered("BETTERUI_ResourceOrbFrames", NAME .. "_ShieldUpdated",
        EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,
        function(_, _, unitAttributeVisual, _, _, _, _, newValue)
            if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                ZO_StatusBar_SmoothTransition(shieldBar, newValue, pools[POWERTYPE_HEALTH]:GetMax())
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")

    BETTERUI.CIM.EventRegistry.RegisterFiltered("BETTERUI_ResourceOrbFrames", NAME .. "_ShieldRemoved",
        EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, _, unitAttributeVisual)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING and not debugShield then
            ZO_StatusBar_SmoothTransition(shieldBar, 0, pools[POWERTYPE_HEALTH]:GetMax())
            shieldBar.label:GetParent():SetHidden(true)
            if shieldBar.fog then shieldBar.fog:SetHidden(true) end
        end
    end, REGISTER_FILTER_UNIT_TAG, "player")

    return shieldBar
end
