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
-- Collision-safe namespace for EVENT_MANAGER RegisterForUpdate loop names.
-- Every other module prefixes its update-loop names with BETTERUI_/BetterUI_;
-- mirror that here so the bare module name cannot collide with another addon.
local UPDATE_NS_PREFIX = "BETTERUI_ResourceOrbFrames"
local COOLDOWN_VISUAL_TICK_MS = 16
local CORE_STATUS_TICK_MS = 100
local ANIMATION_TICK_MS = 33 -- 30fps

-- Import combat indicator module
local CI = BETTERUI.ResourceOrbFrames.CombatIndicators or {}
local SPECIAL_SCENE_HIDE_REASON = "ResourceOrbFramesSpecialScene"
local SPECIAL_SCENE_NAME_SET = {
    TamrielTomesIntroSceneGamepad = true,
    TamrielTomesSceneGamepad = true,
    TamrielTomesPurchaseSceneGamepad = true,
    TamrielTomesRewardPreviewSceneGamepad = true,
    tamrielTomesPurchasePreview_Gamepad = true,
    TamrielTomesIntroSceneKeyboard = true,
    TamrielTomesSceneKeyboard = true,
    TamrielTomesPurchaseSceneKeyboard = true,
    TimedActivitiesGamepad = true,
    TimedActivitiesKeyboard = true,
    bookSetGamepad = true,
}

local m_combatIndicatorRootFrame = nil
local m_hasRegisteredCombatIndicators = false
local m_sceneHandlersRegistered = false

-- Hot-path accessor: returns the live settings table by reference (no deep
-- clone per tick). Read-only by convention.
local OrbUtils = BETTERUI.ResourceOrbFrames.Utils
local GetLiveSettings = (OrbUtils.Settings and OrbUtils.Settings.GetLive) or OrbUtils.GetSettings

--- Canonical m_enabled nil-semantics for this module: nil (not yet
--- initialized) counts as enabled; only an explicit false disables.
local function IsModuleEnabled()
    local settings = GetLiveSettings()
    return not (settings and settings.m_enabled == false)
end

---@param rootFrame table|nil Root frame to refresh, or nil to use cached frame
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

--- Registers combat state events and applies initial combat indicator state.
---@param rootFrame table Root ResourceOrbFrames control
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
    if not IsModuleEnabled() then return end

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

--- Creates HUD scene fragments and registers death/scene-change handlers.
---@param rootFrame table Root ResourceOrbFrames control
---@return function UpdateDeathFragment Callback to manually refresh death visibility
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

    -- IMPORTANT:
    -- Do not replace SCENE_MANAGER methods here. Global scene-manager monkeypatches
    -- can taint protected gamepad execution paths.

    local function IsSpecialSceneActive()
        if not SCENE_MANAGER then
            return false
        end

        local sceneName = nil
        if SCENE_MANAGER.GetCurrentSceneName then
            sceneName = SCENE_MANAGER:GetCurrentSceneName()
        end
        if sceneName == nil and SCENE_MANAGER.GetCurrentScene then
            local scene = SCENE_MANAGER:GetCurrentScene()
            if scene and scene.GetName then
                sceneName = scene:GetName()
            end
        end

        return sceneName ~= nil and SPECIAL_SCENE_NAME_SET[sceneName] == true
    end

    local m_specialSceneCallLaterId = nil
    local function DeferredSyncSpecialSceneVisibility()
        if m_specialSceneCallLaterId then
            zo_removeCallLater(m_specialSceneCallLaterId)
        end

        m_specialSceneCallLaterId = zo_callLater(function()
            m_specialSceneCallLaterId = nil
            fragment:SetHiddenForReason(SPECIAL_SCENE_HIDE_REASON, IsSpecialSceneActive())
        end, 0)
    end

    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(_, _, newState)
            if newState == SCENE_SHOWING
                or newState == SCENE_SHOWN
                or newState == SCENE_HIDING
                or newState == SCENE_HIDDEN
            then
                DeferredSyncSpecialSceneVisibility()
            end
        end)
    end

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_PlayerActivatedSpecialSceneSync",
        EVENT_PLAYER_ACTIVATED, function()
            DeferredSyncSpecialSceneVisibility()
        end)

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

-- Update-loop registration state. Events.SetLoopsEnabled toggles registration
-- so a disabled module pays no per-tick cost (the ticks are not merely
-- early-returning, they are unregistered).
local m_loopTicks = nil
local m_loopsRegistered = false

local function RegisterLoopUpdates()
    if m_loopsRegistered or not m_loopTicks then return end
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NS_PREFIX .. "CoreStatus", CORE_STATUS_TICK_MS, m_loopTicks.coreStatus)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NS_PREFIX .. "CooldownVisuals", COOLDOWN_VISUAL_TICK_MS, m_loopTicks.cooldownVisuals)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NS_PREFIX .. "OrbAnimation", ANIMATION_TICK_MS, m_loopTicks.orbAnimation)
    m_loopsRegistered = true
end

local function UnregisterLoopUpdates()
    if not m_loopsRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NS_PREFIX .. "CoreStatus")
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NS_PREFIX .. "CooldownVisuals")
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NS_PREFIX .. "OrbAnimation")
    m_loopsRegistered = false
end

--- Enables or disables the periodic update loops (idempotent).
--- Called from ResourceOrbFrames.ApplySettings on module enable/disable.
---@param enabled boolean Whether the loops should be running
function Events.SetLoopsEnabled(enabled)
    if enabled then
        RegisterLoopUpdates()
    else
        UnregisterLoopUpdates()
    end
end

--- Registers periodic update ticks for status, cooldowns, and orb animation.
---@param rootFrame table Root ResourceOrbFrames control
---@param pools table<number, BetterUIOrbBar> Power pool instances keyed by powerType
---@param shieldBar BetterUIShieldBar|nil Shield bar instance
---@param castBar table|nil Cast bar instance with isCasting field
function Events.SetupLoopEvents(rootFrame, pools, shieldBar, castBar)
    -- Re-entry safe: drop previously registered loops before rebuilding.
    UnregisterLoopUpdates()

    -- Core status tick (100ms): usability and ultimate meters/text.
    local function CoreStatusTick()
        if not IsModuleEnabled() then return end
        local frontBarCfg = GetLiveSettings().customFrontBar
        if frontBarCfg and frontBarCfg.m_enabled then
            local isCasting = castBar and castBar.isCasting or false
            SkillBar.UpdateFrontBarUsability(rootFrame, isCasting)
            SkillBar.UpdateFrontBarUltimateMeter(rootFrame)
            SkillBar.UpdateFrontBarUltimateNumber(rootFrame)
        end
    end

    -- Cooldown visual tick (16ms): smoother reveal animation for front/back bars.
    local function CooldownVisualTick()
        if not IsModuleEnabled() then return end
        SkillBar.UpdateBackBarCooldowns(rootFrame)
        local frontBarCfg = GetLiveSettings().customFrontBar
        if frontBarCfg and frontBarCfg.m_enabled then
            SkillBar.UpdateFrontBarCooldowns(rootFrame)
        end
    end

    -- Animation Tick (33ms = 30fps)
    local lastAnimTime = GetGameTimeMilliseconds()
    local function AnimationTick()
        if not IsModuleEnabled() then return end
        local settings = GetLiveSettings()
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

    m_loopTicks = {
        coreStatus = CoreStatusTick,
        cooldownVisuals = CooldownVisualTick,
        orbAnimation = AnimationTick,
    }
    RegisterLoopUpdates()
end

--- Registers HUD/HUDUI scene-showing callbacks to keep native action bar hidden.
---@param rootFrame table Root ResourceOrbFrames control
function Events.SetupSceneHandlers(rootFrame)
    -- Registration latch: SetupModule may retry; scene callbacks must not stack.
    if m_sceneHandlersRegistered then return end
    local frontBarCfg = GetLiveSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    m_sceneHandlersRegistered = true

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
