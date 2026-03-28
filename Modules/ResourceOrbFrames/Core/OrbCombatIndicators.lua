--[[
File: Modules/ResourceOrbFrames/Core/OrbCombatIndicators.lua
Purpose: Combat indicator visuals (glows, icons, pulse animations) for the ResourceOrbFrames module.
         Split from OrbEvents.lua for maintainability.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.CombatIndicators then BETTERUI.ResourceOrbFrames.CombatIndicators = {} end

local CombatIndicators = BETTERUI.ResourceOrbFrames.CombatIndicators
local Animations = BETTERUI.ResourceOrbFrames.Animations
local DEFAULT_COMBAT_GLOW_COLOR = { 1, 0.3, 0.1, 0.8 }

local m_combatGlowTimelinesByControl = {}
local m_activeCombatGlowControls = {}
local m_combatIconControl = nil
local m_combatIconPulseTimeline = nil
local m_combatIconPulseControl = nil

local FindControl = BETTERUI.ControlUtils.FindControl

local function GetNamedChildDirect(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

local GetSettings = BETTERUI.ResourceOrbFrames.Utils.GetSettings

local ClampNumber = BETTERUI.ClampNumber

--- Resolves the front bar container control from the root frame.
---@param rootFrame table Root ResourceOrbFrames control
---@return table|nil frontBarContainer The front bar container, or nil
function CombatIndicators.ResolveFrontBarContainer(rootFrame)
    if not rootFrame then
        return nil
    end

    local direct = GetNamedChildDirect(rootFrame, "FrontBarContainer")
    if direct then
        return direct
    end

    local rootName = rootFrame.GetName and rootFrame:GetName() or nil
    if type(rootName) == "string" and rootName ~= "" then
        return _G[rootName .. "FrontBarContainer"] or _G[rootName .. "BgMiddleFrontBarContainer"]
    end

    return nil
end

local function ResolveCombatIconTexturePath()
    if type(BETTERUI_COMBAT_ICON_TEXTURE) == "string" and BETTERUI_COMBAT_ICON_TEXTURE ~= "" then
        return BETTERUI_COMBAT_ICON_TEXTURE
    end

    if ZO_GetGamepadRoleIcon and LFG_ROLE_DPS then
        local iconPath = ZO_GetGamepadRoleIcon(LFG_ROLE_DPS)
        if type(iconPath) == "string" and iconPath ~= "" then
            return iconPath
        end
    end

    if ZO_GetKeyboardRoleIcon and LFG_ROLE_DPS then
        local iconPath = ZO_GetKeyboardRoleIcon(LFG_ROLE_DPS)
        if type(iconPath) == "string" and iconPath ~= "" then
            return iconPath
        end
    end

    return "EsoUI/Art/LFG/LFG_icon_dps.dds"
end

local function EnsureCombatIconControl(rootFrame, frontBarContainer)
    if not rootFrame then
        return nil
    end

    if not m_combatIconControl then
        local rootName = rootFrame.GetName and rootFrame:GetName() or nil
        local frontBarName = frontBarContainer and frontBarContainer.GetName and frontBarContainer:GetName() or nil

        m_combatIconControl = (frontBarContainer and GetNamedChildDirect(frontBarContainer, "CombatIcon"))
            or GetNamedChildDirect(rootFrame, "CombatIcon")
            or (type(frontBarName) == "string" and frontBarName ~= "" and _G[frontBarName .. "CombatIcon"] or nil)
            or (type(rootName) == "string" and rootName ~= "" and (_G[rootName .. "FrontBarContainerCombatIcon"]
                or _G[rootName .. "BgMiddleFrontBarContainerCombatIcon"]) or nil)

        if not m_combatIconControl then
            m_combatIconControl = WINDOW_MANAGER:CreateControl("BetterUI_ResourceOrbFrames_CombatIcon", rootFrame, CT_TEXTURE)
            m_combatIconControl:SetHidden(true)
        end
    end

    if m_combatIconControl.GetParent and m_combatIconControl:GetParent() ~= rootFrame then
        m_combatIconControl:SetParent(rootFrame)
    end

    return m_combatIconControl
end

--- Gets the glow and icon combat indicator controls.
---@param rootFrame table Root ResourceOrbFrames control
---@return table|nil glow Glow texture control, or nil
---@return table|nil icon Icon texture control, or nil
function CombatIndicators.GetCombatIndicatorControls(rootFrame)
    if not rootFrame then
        return nil, nil
    end

    local frontBarContainer = CombatIndicators.ResolveFrontBarContainer(rootFrame)

    local glow = frontBarContainer and GetNamedChildDirect(frontBarContainer, "CombatGlow") or nil
    local icon = EnsureCombatIconControl(rootFrame, frontBarContainer)
    return glow, icon
end

local function ResolveQuickslotButton(rootFrame, frontBarContainer)
    local rootName = rootFrame and rootFrame.GetName and rootFrame:GetName() or nil
    local frontBarName = frontBarContainer and frontBarContainer.GetName and frontBarContainer:GetName() or nil

    if frontBarContainer then
        local quickslotFromFrontBar = GetNamedChildDirect(frontBarContainer, "QuickslotButton")
        if quickslotFromFrontBar then
            return quickslotFromFrontBar
        end
    end

    if type(frontBarName) == "string" and frontBarName ~= "" then
        local prefixedName = frontBarName .. "QuickslotButton"
        local quickslotByFrontBarName = _G[prefixedName]
        if quickslotByFrontBarName then
            return quickslotByFrontBarName
        end
    end

    if type(rootName) == "string" and rootName ~= "" then
        local rootCandidates = {
            rootName .. "FrontBarContainerQuickslotButton",
            rootName .. "BgMiddleFrontBarContainerQuickslotButton",
        }
        for _, globalName in ipairs(rootCandidates) do
            if _G[globalName] then
                return _G[globalName]
            end
        end
    end

    local quickslotFromRoot = GetNamedChildDirect(rootFrame, "QuickslotButton")
    if quickslotFromRoot then
        return quickslotFromRoot
    end

    return nil
end

local function ResolveQuickslotAnchorFallback(rootFrame)
    if not rootFrame or not BETTERUI_ORB_FRAMES or not BETTERUI_ORB_FRAMES.bars then
        return nil
    end

    local barsCfg = BETTERUI_ORB_FRAMES.bars
    local quickslotCfg = barsCfg.quickslot
    local frontBarCfg = barsCfg.customFrontBar
    local slotCfg = frontBarCfg and frontBarCfg.quickslotButton
    if not quickslotCfg or not slotCfg then
        return nil
    end

    local bgMiddle = FindControl(rootFrame, "BgMiddle")
    if not bgMiddle then
        return nil
    end

    local isGamepad = IsInGamepadPreferredMode()
    local slotsCfg = BETTERUI_ORB_FRAMES.slots and (isGamepad and BETTERUI_ORB_FRAMES.slots.gamepad or BETTERUI_ORB_FRAMES.slots.keyboard)
    local modeCfg = frontBarCfg and (isGamepad and frontBarCfg.gamepad or frontBarCfg.keyboard)
    local buttonSize = (modeCfg and modeCfg.buttonSize) or (slotsCfg and slotsCfg.width) or 64
    buttonSize = math.max(1, tonumber(buttonSize) or 64)

    local quickslotX = (quickslotCfg.x or 0) + (slotCfg.offsetX or 0)
    local quickslotY = (quickslotCfg.y or 0) + (slotCfg.offsetY or 0)
    return bgMiddle, quickslotX, quickslotY, buttonSize
end

local function StopCombatIconPulse()
    if m_combatIconPulseTimeline and m_combatIconPulseTimeline.IsPlaying and m_combatIconPulseTimeline:IsPlaying() then
        m_combatIconPulseTimeline:Stop()
    end
end

local function EnsureCombatIconPulseTimeline(iconControl)
    if not iconControl then
        return nil
    end

    if m_combatIconPulseControl ~= iconControl then
        m_combatIconPulseControl = iconControl
        m_combatIconPulseTimeline = nil
    end

    if m_combatIconPulseTimeline then
        return m_combatIconPulseTimeline
    end

    local pulseDurationMs = ClampNumber(BETTERUI_COMBAT_ICON_PULSE_DURATION_MS, 100, 2500, 700)
    local minAlpha = ClampNumber(BETTERUI_COMBAT_ICON_PULSE_MIN_ALPHA, 0, 1, 0.45)
    local maxAlpha = ClampNumber(BETTERUI_COMBAT_ICON_PULSE_MAX_ALPHA, minAlpha, 1, 1.0)

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local anim = timeline:InsertAnimation(ANIMATION_ALPHA, iconControl, 0)
    anim:SetDuration(pulseDurationMs)
    anim:SetAlphaValues(minAlpha, maxAlpha)
    anim:SetEasingFunction(ZO_EaseInOutQuadratic)
    timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)

    m_combatIconPulseTimeline = timeline
    return m_combatIconPulseTimeline
end

local function ApplyCombatIconPulse(iconControl, isEnabled)
    if not iconControl then
        return
    end

    if not isEnabled then
        StopCombatIconPulse()
        iconControl:SetAlpha(1)
        return
    end

    local timeline = EnsureCombatIconPulseTimeline(iconControl)
    if timeline and timeline.IsPlaying and not timeline:IsPlaying() then
        timeline:PlayFromStart()
    end
end

local function ApplyCombatIconTint(iconControl, isEnabled)
    if not iconControl then
        return
    end

    if not isEnabled then
        iconControl:SetColor(1, 1, 1, 1)
        return
    end

    local tintR = ClampNumber(BETTERUI_COMBAT_ICON_TINT_R, 0, 1, 1.0)
    local tintG = ClampNumber(BETTERUI_COMBAT_ICON_TINT_G, 0, 1, 0.2)
    local tintB = ClampNumber(BETTERUI_COMBAT_ICON_TINT_B, 0, 1, 0.2)
    iconControl:SetColor(tintR, tintG, tintB, 1)
end

local function AnchorCombatIcon(rootFrame, iconControl)
    if not rootFrame or not iconControl then
        return
    end

    local iconSize = tonumber(BETTERUI_COMBAT_ICON_SIZE) or 32
    local offsetX = tonumber(BETTERUI_COMBAT_ICON_OFFSET_X) or 0
    local offsetY = tonumber(BETTERUI_COMBAT_ICON_OFFSET_Y) or -5
    if iconSize < 1 then
        iconSize = 1
    end

    local frontBarContainer = CombatIndicators.ResolveFrontBarContainer(rootFrame)
    local quickslotButton = ResolveQuickslotButton(rootFrame, frontBarContainer)

    iconControl:SetDimensions(iconSize, iconSize)
    iconControl:ClearAnchors()
    if quickslotButton then
        -- Default placement: above quickslot for high visibility.
        iconControl:SetAnchor(BOTTOM, quickslotButton, TOP, offsetX, offsetY)
    else
        local bgMiddle, quickslotX, quickslotY, quickslotButtonSize = ResolveQuickslotAnchorFallback(rootFrame)
        if bgMiddle then
            local quickslotTopY = quickslotY - (quickslotButtonSize * 0.5)
            iconControl:SetAnchor(BOTTOM, bgMiddle, BOTTOM, quickslotX + offsetX, quickslotTopY + offsetY)
        elseif frontBarContainer then
            -- Fallback when quickslot controls are unavailable: top-left front bar anchor model.
            iconControl:SetAnchor(BOTTOMLEFT, frontBarContainer, TOPLEFT, offsetX, offsetY)
        else
            iconControl:SetAnchor(CENTER, rootFrame, CENTER, offsetX, offsetY)
        end
    end

    local iconTexture = ResolveCombatIconTexturePath()
    iconControl:SetTexture(iconTexture)
    iconControl:SetTextureCoords(0, 1, 0, 1)
    iconControl:SetDrawLayer(DL_OVERLAY)
    iconControl:SetDrawTier(DT_HIGH)
    iconControl:SetDrawLevel(200)
    iconControl:SetDesaturation(0)
end

local function GetGlowTargets(rootFrame)
    local targets = {}
    if not rootFrame then
        return targets
    end

    local frontBarContainer = CombatIndicators.ResolveFrontBarContainer(rootFrame)
    if frontBarContainer then
        local rootName = rootFrame.GetName and rootFrame:GetName() or nil
        local frontBarName = frontBarContainer.GetName and frontBarContainer:GetName() or nil
        local frontButtons = {
            "Button1",
            "Button2",
            "Button3",
            "Button4",
            "Button5",
            "UltimateButton",
            "QuickslotButton",
            "CompanionButton",
        }

        for _, buttonName in ipairs(frontButtons) do
            local buttonControl = GetNamedChildDirect(frontBarContainer, buttonName)
            if not buttonControl and type(frontBarName) == "string" and frontBarName ~= "" then
                buttonControl = _G[frontBarName .. buttonName]
            end
            if not buttonControl and type(rootName) == "string" and rootName ~= "" then
                buttonControl = _G[rootName .. "FrontBarContainer" .. buttonName]
                    or _G[rootName .. "BgMiddleFrontBarContainer" .. buttonName]
            end
            if not buttonControl then
                buttonControl = GetNamedChildDirect(rootFrame, buttonName)
            end
            if buttonControl and not buttonControl:IsHidden() then
                local glow = GetNamedChildDirect(buttonControl, "Glow") or FindControl(buttonControl, "Glow")
                if glow then
                    table.insert(targets, glow)
                end
            end
        end
    end

    return targets
end

--- Stops all active combat glow animations and hides glow controls.
function CombatIndicators.HideAllCombatGlows()
    for control, timeline in pairs(m_combatGlowTimelinesByControl) do
        if timeline and timeline.IsPlaying and timeline:IsPlaying() then
            timeline:Stop()
        end
        if control then
            control:SetAlpha(0)
            control:SetHidden(true)
        end
    end
    ZO_ClearNumericallyIndexedTable(m_activeCombatGlowControls)
end

local function ApplyCombatGlow(rootFrame, glowColor)
    local glowTargets = GetGlowTargets(rootFrame)
    CombatIndicators.HideAllCombatGlows()

    for _, glowControl in ipairs(glowTargets) do
        glowControl:SetColor(unpack(glowColor))
        -- Keep glow beneath keybind glyphs/text (A/LB/RB/etc.) so pulse does not wash over input hints.
        glowControl:SetDrawLayer(DL_CONTROLS)
        glowControl:SetDrawTier(DT_MEDIUM)
        glowControl:SetDrawLevel(5)
        glowControl:SetHidden(false)

        local timeline = m_combatGlowTimelinesByControl[glowControl]
        if not timeline and Animations and Animations.CreateCombatGlow then
            timeline = Animations.CreateCombatGlow(glowControl)
            m_combatGlowTimelinesByControl[glowControl] = timeline
        end

        if timeline and timeline.IsPlaying and not timeline:IsPlaying() then
            timeline:PlayFromStart()
        end

        table.insert(m_activeCombatGlowControls, glowControl)
    end
end

local function TryPlayCombatAudioCue(isInCombat)
    local settings = GetSettings()
    if not settings or not settings.playCombatAudio then
        return
    end

    local soundId = isInCombat and SOUNDS.ACTIVE_COMBAT_TIP_SHOWN or SOUNDS.ACTIVE_COMBAT_TIP_SUCCESS
    if soundId then
        PlaySound(soundId)
    end
end

--- Internal state for tracking combat transitions
CombatIndicators._lastCombatState = nil

--- Applies or removes combat indicator visuals (glows, icons, audio cues).
---@param rootFrame table Root ResourceOrbFrames control
---@param isInCombat boolean Whether the player is in combat
---@param playAudioCue boolean Whether to play audio on combat state change
function CombatIndicators.ApplyCombatIndicators(rootFrame, isInCombat, playAudioCue)
    local settings = GetSettings()
    local glow, icon = CombatIndicators.GetCombatIndicatorControls(rootFrame)

    local frontBarCfg = BETTERUI_ORB_FRAMES and BETTERUI_ORB_FRAMES.bars and BETTERUI_ORB_FRAMES.bars.customFrontBar
    local canRenderIndicators = settings
        and settings.m_enabled
        and frontBarCfg
        and frontBarCfg.m_enabled
        and isInCombat
        and not IsUnitDead("player")

    if not canRenderIndicators then
        CombatIndicators.HideAllCombatGlows()
        if glow then
            glow:SetHidden(true)
        end
        if icon then
            ApplyCombatIconPulse(icon, false)
            ApplyCombatIconTint(icon, false)
            icon:SetHidden(true)
        end
        CombatIndicators._lastCombatState = false
        return
    end

    if settings.showCombatGlow then
        -- Combat glow color is intentionally fixed to red and not user-configurable.
        ApplyCombatGlow(rootFrame, DEFAULT_COMBAT_GLOW_COLOR)
        if glow then
            glow:SetHidden(true)
        end
    else
        CombatIndicators.HideAllCombatGlows()
        if glow then
            glow:SetHidden(true)
        end
    end

    if icon then
        AnchorCombatIcon(rootFrame, icon)
        local showCombatIcon = settings.showCombatIcon == true
        if showCombatIcon then
            icon:SetHidden(false)
            ApplyCombatIconTint(icon, true)
            ApplyCombatIconPulse(icon, true)
        else
            ApplyCombatIconPulse(icon, false)
            ApplyCombatIconTint(icon, false)
            icon:SetHidden(true)
        end
    end

    if playAudioCue and CombatIndicators._lastCombatState ~= nil and CombatIndicators._lastCombatState ~= isInCombat then
        TryPlayCombatAudioCue(isInCombat)
    end
    CombatIndicators._lastCombatState = isInCombat
end
