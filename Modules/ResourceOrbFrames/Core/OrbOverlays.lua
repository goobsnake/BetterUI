--[[
File: Modules/ResourceOrbFrames/Core/OrbOverlays.lua
Purpose: Handles resource orb layout, overlay sizing, and shield setup visuals.
Last Modified: 2026-03-14
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Visuals then BETTERUI.ResourceOrbFrames.Visuals = {} end

local Visuals = BETTERUI.ResourceOrbFrames.Visuals
local NAME = "ResourceOrbFrames"
local DEFAULT_SHIELD_ELECTRIC_COLOR = { 0.4, 0.9, 1, 1 }

local ORB_CONFIG = {
    [POWERTYPE_HEALTH] = { 0, 1, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorehealth.dds' },
    [POWERTYPE_MAGICKA] = { 0, 0.5, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restoremagicka.dds' },
    [POWERTYPE_STAMINA] = { 0.5, 0, 75, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorestamina.dds' },
    [ATTRIBUTE_VISUAL_POWER_SHIELDING] = { 1, 0, 0, nil },
}

local function FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

-- Layout Calculation Helpers
local function ScaleForBorder(value, borderSize, baseBorderSize)
    if type(value) ~= "number" then
        return 0
    end
    if type(baseBorderSize) ~= "number" or baseBorderSize <= 0 then
        return value
    end
    return value * (borderSize / baseBorderSize)
end

local function CalculateBorderSizes(cfg, settings)
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

local function CalculateFillDimensions(cfg, leftBorderSize, rightBorderSize)
    local leftBaseSize = cfg.orbs.left.borderSize or leftBorderSize
    local rightBaseSize = cfg.orbs.right.borderSize or rightBorderSize

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

function Visuals.UpdateOrbLayout(rootFrame, pools, shieldBar)
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if not bgMiddle then return end

    local cfg = BETTERUI_ORB_FRAMES
    local settings = GetModuleSettings()

    local leftBorderSize, rightBorderSize, leftVisibleScale, rightVisibleScale = CalculateBorderSizes(cfg, settings)
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
            leftOrb:SetAnchor(CENTER, leftOrnament, CENTER, cfg.orbs.left.x * leftVisibleScale,
                cfg.orbs.left.y * leftVisibleScale)
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
            rightOrb:SetAnchor(CENTER, rightOrnament, CENTER, cfg.orbs.right.x * rightVisibleScale,
                cfg.orbs.right.y * rightVisibleScale)
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
        -- Refresh label font/color from current settings (enables realtime updates)
        local fontSettings = {
            [POWERTYPE_HEALTH]  = { size = settings.healthTextSize or 20,  color = settings.healthTextColor or { 1, 1, 1, 1 } },
            [POWERTYPE_MAGICKA] = { size = settings.magickaTextSize or 20, color = settings.magickaTextColor or { 1, 1, 1, 1 } },
            [POWERTYPE_STAMINA] = { size = settings.staminaTextSize or 20, color = settings.staminaTextColor or { 1, 1, 1, 1 } },
        }

        -- Original orb control size from XML (used to scale baseAnchorX)
        local BASE_ORB_CONTROL_SIZE = 150

        local bgPad = BETTERUI.CONST.ORBS.BG_FILL_PADDING or {}

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
            sOrb:SetAnchor(CENTER, leftOrb, CENTER, 0, 0)
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

    -- Apply font and color settings to resource labels (same style as shield: bold + thick-outline)
    local settings = GetModuleSettings()
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

    local debugShield = BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY or false
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
        local shieldTextColor = settings.shieldTextColor or DEFAULT_SHIELD_ELECTRIC_COLOR
        shieldBar.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", shieldTextSize))
        shieldBar.label:SetColor(unpack(shieldTextColor))
        if shieldBar.fog then
            shieldBar.fog:SetColor(unpack(DEFAULT_SHIELD_ELECTRIC_COLOR))
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
