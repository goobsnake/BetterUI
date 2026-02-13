--[[
File: Modules/ResourceOrbFrames/OrbEvents.lua
Purpose: Manages periodic updates (ticks) and global event registrations (Visibility, Combat).
Last Modified: 2026-02-12
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Events then BETTERUI.ResourceOrbFrames.Events = {} end

local Events = BETTERUI.ResourceOrbFrames.Events
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
local Visuals = BETTERUI.ResourceOrbFrames.Visuals -- If needed
local Animations = BETTERUI.ResourceOrbFrames.Animations
local NAME = "ResourceOrbFrames"
local COOLDOWN_VISUAL_TICK_MS = 16
local CORE_STATUS_TICK_MS = 100
local DEFAULT_COMBAT_GLOW_COLOR = { 1, 0.3, 0.1, 0.8 }

local m_combatIndicatorRootFrame = nil
local m_combatGlowTimelinesByControl = {}
local m_activeCombatGlowControls = {}
local m_combatIconControl = nil
local m_combatIconPulseTimeline = nil
local m_combatIconPulseControl = nil
local m_hasRegisteredCombatIndicators = false
local m_lastCombatState = nil

local function FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

local function GetNamedChildDirect(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

local function ResolveFrontBarContainer(rootFrame)
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

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

local function Clamp(value, minValue, maxValue, fallback)
    local numberValue = tonumber(value)
    if not numberValue then
        numberValue = fallback
    end
    if numberValue < minValue then
        return minValue
    end
    if numberValue > maxValue then
        return maxValue
    end
    return numberValue
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

local function GetCombatIndicatorControls(rootFrame)
    if not rootFrame then
        return nil, nil
    end

    local frontBarContainer = ResolveFrontBarContainer(rootFrame)

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

    local pulseDurationMs = Clamp(BETTERUI_COMBAT_ICON_PULSE_DURATION_MS, 100, 2500, 700)
    local minAlpha = Clamp(BETTERUI_COMBAT_ICON_PULSE_MIN_ALPHA, 0, 1, 0.45)
    local maxAlpha = Clamp(BETTERUI_COMBAT_ICON_PULSE_MAX_ALPHA, minAlpha, 1, 1.0)

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

    local tintR = Clamp(BETTERUI_COMBAT_ICON_TINT_R, 0, 1, 1.0)
    local tintG = Clamp(BETTERUI_COMBAT_ICON_TINT_G, 0, 1, 0.2)
    local tintB = Clamp(BETTERUI_COMBAT_ICON_TINT_B, 0, 1, 0.2)
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

    local frontBarContainer = ResolveFrontBarContainer(rootFrame)
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

    local frontBarContainer = ResolveFrontBarContainer(rootFrame)
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

local function HideAllCombatGlows()
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
    HideAllCombatGlows()

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
    local settings = GetModuleSettings()
    if not settings or not settings.playCombatAudio then
        return
    end

    local soundId = isInCombat and SOUNDS.ACTIVE_COMBAT_TIP_SHOWN or SOUNDS.ACTIVE_COMBAT_TIP_SUCCESS
    if soundId then
        PlaySound(soundId)
    end
end

local function ApplyCombatIndicators(rootFrame, isInCombat, playAudioCue)
    local settings = GetModuleSettings()
    local glow, icon = GetCombatIndicatorControls(rootFrame)

    local frontBarCfg = BETTERUI_ORB_FRAMES and BETTERUI_ORB_FRAMES.bars and BETTERUI_ORB_FRAMES.bars.customFrontBar
    local canRenderIndicators = settings
        and settings.m_enabled
        and frontBarCfg
        and frontBarCfg.m_enabled
        and isInCombat
        and not IsUnitDead("player")

    if not canRenderIndicators then
        HideAllCombatGlows()
        if glow then
            glow:SetHidden(true)
        end
        if icon then
            ApplyCombatIconPulse(icon, false)
            ApplyCombatIconTint(icon, false)
            icon:SetHidden(true)
        end
        m_lastCombatState = false
        return
    end

    if settings.showCombatGlow then
        -- Combat glow color is intentionally fixed to red and not user-configurable.
        ApplyCombatGlow(rootFrame, DEFAULT_COMBAT_GLOW_COLOR)
        if glow then
            glow:SetHidden(true)
        end
    else
        HideAllCombatGlows()
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

    if playAudioCue and m_lastCombatState ~= nil and m_lastCombatState ~= isInCombat then
        TryPlayCombatAudioCue(isInCombat)
    end
    m_lastCombatState = isInCombat
end

function Events.RefreshCombatIndicators(rootFrame)
    local targetRootFrame = rootFrame or m_combatIndicatorRootFrame
    if not targetRootFrame then
        return
    end

    local isInCombat = IsUnitInCombat("player")
    ApplyCombatIndicators(targetRootFrame, isInCombat, false)
end

function Events.SetupCombatIndicators(rootFrame)
    m_combatIndicatorRootFrame = rootFrame
    if not m_combatIndicatorRootFrame then
        return
    end

    if not m_hasRegisteredCombatIndicators then
        m_hasRegisteredCombatIndicators = true

        BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CombatState", EVENT_PLAYER_COMBAT_STATE,
            function(_, inCombat)
                ApplyCombatIndicators(m_combatIndicatorRootFrame, inCombat, true)
            end)

        BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CombatDead", EVENT_PLAYER_DEAD, function()
            ApplyCombatIndicators(m_combatIndicatorRootFrame, false, false)
        end)

        BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CombatAlive", EVENT_PLAYER_ALIVE, function()
            ApplyCombatIndicators(m_combatIndicatorRootFrame, IsUnitInCombat("player"), false)
        end)

        BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CombatActivated", EVENT_PLAYER_ACTIVATED,
            function()
                ApplyCombatIndicators(m_combatIndicatorRootFrame, IsUnitInCombat("player"), false)
            end)
    end

    ApplyCombatIndicators(m_combatIndicatorRootFrame, IsUnitInCombat("player"), false)
end

local function EnforceDefaultUIHidden()
    local settings = GetModuleSettings()
    if not settings.m_enabled then return end

    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
    end
    if SkillBar and SkillBar.HideNativeActionBar then
        SkillBar.HideNativeActionBar()
    end
end

-- Debounced version of EnforceDefaultUIHidden to prevent overlapping calls.
-- Multiple rapid events (death, reincarnate, scene change) will coalesce into one call.
local m_hideCallLaterId = nil
local function DeferredEnforceHide(delayMs)
    if m_hideCallLaterId then
        zo_removeCallLater(m_hideCallLaterId)
    end
    m_hideCallLaterId = zo_callLater(function()
        m_hideCallLaterId = nil
        EnforceDefaultUIHidden()
    end, delayMs or 50)
end

--- @param rootFrame Control The root control frame
--- @return function UpdateDeathFragment The death fragment update callback
function Events.SetupVisibilityFragments(rootFrame)
    local fragment = ZO_HUDFadeSceneFragment:New(rootFrame)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    local function UpdateDeathFragment()
        fragment:SetHiddenForReason("Dead", IsUnitDead("player"))
    end

    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
    end

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME, EVENT_PLAYER_DEAD, UpdateDeathFragment)
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME, EVENT_PLAYER_ALIVE, UpdateDeathFragment)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_DeathEnforce", EVENT_PLAYER_DEAD, function()
        DeferredEnforceHide(100)
    end)
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_AliveEnforce", EVENT_PLAYER_ALIVE, function()
        DeferredEnforceHide(100)
    end)
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_Reincarnated", EVENT_PLAYER_REINCARNATED,
        function()
            DeferredEnforceHide(100)
        end)
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_EndSiege", EVENT_END_SIEGE_CONTROL, function()
        DeferredEnforceHide(100)
    end)

    -- Guard: Check SCENE_MANAGER exists before overriding methods
    if SCENE_MANAGER and SCENE_MANAGER.RestoreHUDScene then
        local originalRestoreHUDScene = SCENE_MANAGER.RestoreHUDScene
        SCENE_MANAGER.RestoreHUDScene = function(self, ...)
            local result = originalRestoreHUDScene(self, ...)
            DeferredEnforceHide(50)
            return result
        end
    end

    if SCENE_MANAGER and SCENE_MANAGER.RestoreHUDUIScene then
        local originalRestoreHUDUIScene = SCENE_MANAGER.RestoreHUDUIScene
        SCENE_MANAGER.RestoreHUDUIScene = function(self, ...)
            local result = originalRestoreHUDUIScene(self, ...)
            DeferredEnforceHide(50)
            return result
        end
    end

    local lootScene = SCENE_MANAGER:GetScene("loot")
    if lootScene then
        lootScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                DeferredEnforceHide(50)
            end
        end)
    end
    local lootGamepadScene = SCENE_MANAGER:GetScene("lootGamepad")
    if lootGamepadScene then
        lootGamepadScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                DeferredEnforceHide(50)
            end
        end)
    end

    return UpdateDeathFragment
end

--- @param rootFrame Control The root control frame
--- @param pools table<number, OrbPool> The power type pools
--- @param shieldBar table|nil The shield bar control
--- @param castBar table|nil The cast bar control object
function Events.SetupLoopEvents(rootFrame, pools, shieldBar, castBar)
    -- Core status tick (100ms): usability and ultimate meters/text.
    local function CoreStatusTick()
        local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
        if frontBarCfg and frontBarCfg.m_enabled then
            local isCasting = castBar and castBar.isCasting or false
            SkillBar.UpdateFrontBarUsability(rootFrame, isCasting)
            SkillBar.UpdateFrontBarUltimateMeter(rootFrame)
            SkillBar.UpdateFrontBarUltimateNumber(rootFrame)
        end
    end
    EVENT_MANAGER:RegisterForUpdate(NAME .. "CoreStatus", CORE_STATUS_TICK_MS, CoreStatusTick)

    -- Cooldown visual tick (16ms): smoother reveal animation for front/back bars.
    local function CooldownVisualTick()
        SkillBar.UpdateBackBarCooldowns(rootFrame)
        local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
        if frontBarCfg and frontBarCfg.m_enabled then
            SkillBar.UpdateFrontBarCooldowns(rootFrame)
        end
    end
    EVENT_MANAGER:RegisterForUpdate(NAME .. "CooldownVisuals", COOLDOWN_VISUAL_TICK_MS, CooldownVisualTick)

    -- Animation Tick (33ms = 30fps)
    local lastAnimTime = GetGameTimeMilliseconds()
    local function AnimationTick()
        local settings = GetModuleSettings()
        if not settings.orbAnimFlow then return end

        local now = GetGameTimeMilliseconds()
        local deltaMs = now - lastAnimTime
        lastAnimTime = now

        if pools then
            for powerType, pool in pairs(pools) do
                if pool and pool.UpdateAnimation then
                    pool:UpdateAnimation(deltaMs, settings)
                end
            end
        end
        if shieldBar and shieldBar.UpdateAnimation then
            shieldBar:UpdateAnimation(deltaMs, settings)
        end
    end
    EVENT_MANAGER:RegisterForUpdate(NAME .. "OrbAnimation", 33, AnimationTick)
end

--- @param rootFrame Control The root control frame
function Events.SetupSceneHandlers(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end

    -- Shared callback for HUD scene visibility changes.
    -- Debounced to coalesce rapid scene transitions.
    local m_sceneCallLaterId = nil
    local function OnHUDSceneShowing()
        if m_sceneCallLaterId then
            zo_removeCallLater(m_sceneCallLaterId)
        end
        m_sceneCallLaterId = zo_callLater(function()
            m_sceneCallLaterId = nil
            SkillBar.HideNativeActionBar()
            CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
        end, 50)
    end

    local hudScene = SCENE_MANAGER:GetScene("hud")
    if hudScene then
        hudScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                OnHUDSceneShowing()
            end
        end)
    end

    local hudUIScene = SCENE_MANAGER:GetScene("hudui")
    if hudUIScene then
        hudUIScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                OnHUDSceneShowing()
            end
        end)
    end
end
