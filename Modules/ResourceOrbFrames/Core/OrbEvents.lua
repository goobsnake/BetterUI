--[[
File: Modules/ResourceOrbFrames/Core/OrbEvents.lua
Purpose: Manages periodic updates (ticks), event registrations, and scene handlers.
         Combat indicator visuals are in OrbCombatIndicators.lua.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Events then BETTERUI.ResourceOrbFrames.Events = {} end

local Events = BETTERUI.ResourceOrbFrames.Events
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
local NAME = "ResourceOrbFrames"
local COOLDOWN_VISUAL_TICK_MS = 16
local CORE_STATUS_TICK_MS = 100

-- Import combat indicator module
local CI = BETTERUI.ResourceOrbFrames.CombatIndicators or {}

local m_combatIndicatorRootFrame = nil
local m_hasRegisteredCombatIndicators = false

local GetSettings = BETTERUI.ResourceOrbFrames.Utils.GetSettings

function Events.RefreshCombatIndicators(rootFrame)
    local targetRootFrame = rootFrame or m_combatIndicatorRootFrame
    if not targetRootFrame then
        return
    end

    local isInCombat = IsUnitInCombat("player")
    if CI.ApplyCombatIndicators then
        CI.ApplyCombatIndicators(targetRootFrame, isInCombat, false)
    end
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
                if CI.ApplyCombatIndicators then
                    CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, inCombat, true)
                end
            end)

        BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CombatDead", EVENT_PLAYER_DEAD, function()
            if CI.ApplyCombatIndicators then
                CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, false, false)
            end
        end)

        BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CombatAlive", EVENT_PLAYER_ALIVE, function()
            if CI.ApplyCombatIndicators then
                CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, IsUnitInCombat("player"), false)
            end
        end)

        BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CombatActivated", EVENT_PLAYER_ACTIVATED,
            function()
                if CI.ApplyCombatIndicators then
                    CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, IsUnitInCombat("player"), false)
                end
            end)
    end

    if CI.ApplyCombatIndicators then
        CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, IsUnitInCombat("player"), false)
    end
end

local function EnforceDefaultUIHidden()
    local settings = GetSettings()
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
        local settings = GetSettings()
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
