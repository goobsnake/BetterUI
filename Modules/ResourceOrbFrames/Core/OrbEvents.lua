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
    tamrieltomesintrosceneGamepad = true,
    tamrieltomessceneGamepad = true,
    tamrieltomespurchasesceneGamepad = true,
    tamrieltomesrewardpreviewsceneGamepad = true,
    tamrieltomespurchasepreview_gamepad = true,
    tamrieltomesintroscenekeyboard = true,
    tamrieltomesscenekeyboard = true,
    tamrieltomespurchasescenekeyboard = true,
    timedactivitiesgamepad = true,
    timedactivitieskeyboard = true,
    booksetgamepad = true,
}

local function NormalizeSceneName(sceneName)
    return sceneName and tostring(sceneName):lower():gsub("%s+", "") or nil
end

local function GetCurrentSceneName()
    local utils = BETTERUI.CIM and BETTERUI.CIM.Utils
    if utils and type(utils.GetCurrentSceneName) == "function" then
        return utils.GetCurrentSceneName()
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentSceneName) == "function" then
        local ok, sceneName = pcall(function() return SCENE_MANAGER:GetCurrentSceneName() end)
        if ok and sceneName ~= nil then
            return sceneName
        end
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentScene) == "function" then
        local ok, scene = pcall(function() return SCENE_MANAGER:GetCurrentScene() end)
        if ok and scene and type(scene.GetName) == "function" then
            local nameOk, sceneName = pcall(function() return scene:GetName() end)
            if nameOk then return sceneName end
        end
    end
    return nil
end

local function IsConfiguredSpecialScene(sceneName)
    return sceneName ~= nil and SPECIAL_SCENE_NAME_SET[NormalizeSceneName(sceneName)] == true
end

local function IsSpecialSceneNameDrift(sceneName)
    if not sceneName then
        return false
    end
    local normalized = NormalizeSceneName(sceneName)
    return normalized ~= nil and normalized:find("tamrieltomes", 1, true) ~= nil
end

local m_combatIndicatorRootFrame = nil
local m_hasRegisteredCombatIndicators = false
local m_visibilitySceneCallbacksRegistered = false
local m_hudSceneHandlersRegistered = false
local m_lastCombatState = nil

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

local function TraceOrbEvents(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent and L.EnabledFor and L.CATEGORY and L.LEVEL) then return end
    -- Preflight before building any payload so the scene/gamepad lookups and
    -- table allocation run only when tracing is active (BUI-DEEPDIVE-001 P2).
    if not L.EnabledFor(L.LEVEL.DEBUG, L.CATEGORY.STATE) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "resourceOrbs"
    local currentScene = GetCurrentSceneName()
    data.currentScene = currentScene
    if data.scene == nil then
        data.scene = currentScene
    end
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    L.TraceEvent(L.CATEGORY.STATE, event, phase, data)
end

local function TraceCombatChanged(inCombat, source)
    local combat = inCombat == true
    if m_lastCombatState == combat then return end
    local previous = m_lastCombatState
    m_lastCombatState = combat
    TraceOrbEvents("resource_orbs.combat", "changed", {
        fn = source,
        inCombat = combat,
        previous = previous,
    })
end

---@param rootFrame table|nil Root frame to refresh, or nil to use cached frame
function Events.RefreshCombatIndicators(rootFrame)
    local targetRootFrame = rootFrame or m_combatIndicatorRootFrame
    if not targetRootFrame then
        TraceOrbEvents("resource_orbs.combat_indicators", "refresh_skipped", { reason = "missingRoot" })
        return
    end

    local isInCombat = IsUnitInCombat("player")
    TraceOrbEvents("resource_orbs.combat_indicators", "refresh", {
        fn = "Events.RefreshCombatIndicators",
        inCombat = isInCombat,
        hasApply = CI.ApplyCombatIndicators ~= nil,
    })
    if CI.ApplyCombatIndicators then
        CI.ApplyCombatIndicators(targetRootFrame, isInCombat, false)
    end
end

--- Registers combat state events and applies initial combat indicator state.
---@param rootFrame table Root ResourceOrbFrames control
function Events.SetupCombatIndicators(rootFrame)
    m_combatIndicatorRootFrame = rootFrame
    TraceOrbEvents("resource_orbs.combat_indicators", "setup_begin", {
        fn = "Events.SetupCombatIndicators",
        hasRoot = m_combatIndicatorRootFrame ~= nil,
        registered = m_hasRegisteredCombatIndicators,
    })
    if not m_combatIndicatorRootFrame then
        TraceOrbEvents("resource_orbs.combat_indicators", "setup_skipped", { reason = "missingRoot" })
        return
    end

    if not m_hasRegisteredCombatIndicators then
        m_hasRegisteredCombatIndicators = true

        BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_CombatState", EVENT_PLAYER_COMBAT_STATE,
            function(_, inCombat)
                TraceOrbEvents("resource_orbs.combat_event", "combat_state", { inCombat = inCombat })
                TraceCombatChanged(inCombat, "EVENT_PLAYER_COMBAT_STATE")
                if CI.ApplyCombatIndicators then
                    CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, inCombat, true)
                end
            end)

        -- EVENT_PLAYER_DEAD is handled by the consolidated visibility handler in
        -- SetupVisibilityFragments so combat-indicator, death-fragment, and hide-
        -- enforce actions all fire from a single registration (BUI-DEEPDIVE-001 P2).
        BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_CombatAlive", EVENT_PLAYER_ALIVE, function()
            local inCombat = IsUnitInCombat("player")
            TraceOrbEvents("resource_orbs.combat_event", "alive", { inCombat = inCombat })
            TraceCombatChanged(inCombat, "EVENT_PLAYER_ALIVE")
            if CI.ApplyCombatIndicators then
                CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, inCombat, false)
            end
        end)

        BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_CombatActivated", EVENT_PLAYER_ACTIVATED,
            function()
                local inCombat = IsUnitInCombat("player")
                TraceOrbEvents("resource_orbs.combat_event", "player_activated", { inCombat = inCombat })
                TraceCombatChanged(inCombat, "EVENT_PLAYER_ACTIVATED")
                if CI.ApplyCombatIndicators then
                    CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, inCombat, false)
                end
            end)
    end

    if CI.ApplyCombatIndicators then
        CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, IsUnitInCombat("player"), false)
    end
    TraceOrbEvents("resource_orbs.combat_indicators", "setup_end", {
        registered = m_hasRegisteredCombatIndicators,
        inCombat = IsUnitInCombat("player"),
    })
end

local function EnforceDefaultUIHidden()
    if not IsModuleEnabled() then return end

    TraceOrbEvents("resource_orbs.native_bars", "hide_enforce", { hasAttributeFragment = PLAYER_ATTRIBUTE_BARS_FRAGMENT ~= nil })
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
        TraceOrbEvents("resource_orbs.native_bars", "hide_enforce_rescheduled", {
            previousTaskCanceled = true,
            delayMs = delayMs or 50,
        })
    end
    TraceOrbEvents("resource_orbs.native_bars", "hide_enforce_scheduled", { delayMs = delayMs or 50 })
    m_hideCallLaterId = zo_callLater(function()
        m_hideCallLaterId = nil
        TraceOrbEvents("resource_orbs.native_bars", "hide_enforce_task", { delayMs = delayMs or 50 })
        EnforceDefaultUIHidden()
    end, delayMs or 50)
end

--- Creates HUD scene fragments and registers death/scene-change handlers.
---@param rootFrame table Root ResourceOrbFrames control
---@return function UpdateDeathFragment Callback to manually refresh death visibility
function Events.SetupVisibilityFragments(rootFrame)
    local fragment = ZO_HUDFadeSceneFragment:New(rootFrame)
    TraceOrbEvents("resource_orbs.visibility", "setup_begin", { hasRoot = rootFrame ~= nil, hasFragment = fragment ~= nil })
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    local function UpdateDeathFragment()
        local isDead = IsUnitDead("player")
        TraceOrbEvents("resource_orbs.visibility", "death_fragment", { dead = isDead })
        fragment:SetHiddenForReason("Dead", isDead)
    end

    -- Single consolidated death handler: updates the death fragment, forces
    -- combat indicators off, and re-enforces native UI hiding. This replaces the
    -- previous three separate EVENT_PLAYER_DEAD registrations (combat indicators,
    -- death fragment, hide enforce) with one namespace entry.
    local function OnPlayerDead()
        TraceOrbEvents("resource_orbs.combat_event", "dead", {})
        TraceCombatChanged(false, "EVENT_PLAYER_DEAD")
        if CI.ApplyCombatIndicators then
            CI.ApplyCombatIndicators(m_combatIndicatorRootFrame, false, false)
        end
        fragment:SetHiddenForReason("Dead", IsUnitDead("player"))
        DeferredEnforceHide(100)
    end

    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
    end

    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_PlayerDead", EVENT_PLAYER_DEAD, OnPlayerDead)
    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_PlayerAlive", EVENT_PLAYER_ALIVE, UpdateDeathFragment)

    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_Reincarnated", EVENT_PLAYER_REINCARNATED,
        function()
            DeferredEnforceHide(100)
        end)
    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_EndSiege", EVENT_END_SIEGE_CONTROL, function()
        DeferredEnforceHide(100)
    end)

    -- IMPORTANT:
    -- Do not replace SCENE_MANAGER methods here. Global scene-manager monkeypatches
    -- can taint protected gamepad execution paths.

    local function IsSpecialSceneActive()
        local sceneName = GetCurrentSceneName()
        return IsConfiguredSpecialScene(sceneName) or IsSpecialSceneNameDrift(sceneName)
    end

    local m_specialSceneCallLaterId = nil
    local function DeferredSyncSpecialSceneVisibility()
        if m_specialSceneCallLaterId then
            zo_removeCallLater(m_specialSceneCallLaterId)
        end

        m_specialSceneCallLaterId = zo_callLater(function()
            m_specialSceneCallLaterId = nil
            local specialSceneActive = IsSpecialSceneActive()
            TraceOrbEvents("resource_orbs.visibility", "special_scene_sync", { hidden = specialSceneActive })
            fragment:SetHiddenForReason(SPECIAL_SCENE_HIDE_REASON, specialSceneActive)
        end, 0)
    end

    if not m_visibilitySceneCallbacksRegistered then
        m_visibilitySceneCallbacksRegistered = true
        if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
            SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(_, oldState, newState)
                if newState == SCENE_SHOWING
                    or newState == SCENE_SHOWN
                    or newState == SCENE_HIDING
                    or newState == SCENE_HIDDEN
                then
                    TraceOrbEvents("resource_orbs.scene", "state_changed", { oldState = oldState, newState = newState })
                    DeferredSyncSpecialSceneVisibility()
                    DeferredEnforceHide(50)
                end
            end)
        end

        local lootScene = SCENE_MANAGER:GetScene("loot")
        if lootScene then
            lootScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                    TraceOrbEvents("resource_orbs.scene", "loot_exit", { scene = "loot", oldState = oldState, newState = newState })
                    DeferredEnforceHide(50)
                end
            end)
        end
        local lootGamepadScene = SCENE_MANAGER:GetScene("lootGamepad")
        if lootGamepadScene then
            lootGamepadScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                    TraceOrbEvents("resource_orbs.scene", "loot_exit", { scene = "lootGamepad", oldState = oldState, newState = newState })
                    DeferredEnforceHide(50)
                end
            end)
        end
    end

    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_PlayerActivatedSpecialSceneSync",
        EVENT_PLAYER_ACTIVATED, function()
            DeferredSyncSpecialSceneVisibility()
        end)

    TraceOrbEvents("resource_orbs.visibility", "setup_end", { hasFragment = fragment ~= nil })
    return UpdateDeathFragment
end

-- Update-loop registration state. Events.SetLoopsEnabled toggles registration
-- so a disabled module pays no per-tick cost (the ticks are not merely
-- early-returning, they are unregistered).
local m_loopTicks = nil
local m_loopRegistered = {
    coreStatus = false,
    cooldownVisuals = false,
    orbAnimation = false,
}
local LOOP_UPDATE_SUFFIX = {
    coreStatus = "CoreStatus",
    cooldownVisuals = "CooldownVisuals",
    orbAnimation = "OrbAnimation",
}
-- Forces one cooldown scan after the module is enabled so that cooldowns which
-- started while the loop was unregistered are discovered immediately.
local m_cooldownScanNeeded = false

local function RegisterLoopUpdate(name)
    if m_loopRegistered[name] or not m_loopTicks or not m_loopTicks[name] then return end
    local intervalMs = (name == "coreStatus" and CORE_STATUS_TICK_MS)
        or (name == "cooldownVisuals" and COOLDOWN_VISUAL_TICK_MS)
        or (name == "orbAnimation" and ANIMATION_TICK_MS)
        or 100
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NS_PREFIX .. (LOOP_UPDATE_SUFFIX[name] or name), intervalMs, m_loopTicks[name])
    m_loopRegistered[name] = true
end

local function UnregisterLoopUpdate(name)
    if not m_loopRegistered[name] then return end
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NS_PREFIX .. (LOOP_UPDATE_SUFFIX[name] or name))
    m_loopRegistered[name] = false
end

local function RegisterLoopUpdates()
    RegisterLoopUpdate("coreStatus")
    RegisterLoopUpdate("cooldownVisuals")
    RegisterLoopUpdate("orbAnimation")
end

local function UnregisterLoopUpdates()
    UnregisterLoopUpdate("coreStatus")
    UnregisterLoopUpdate("cooldownVisuals")
    UnregisterLoopUpdate("orbAnimation")
    local CooldownUtils = SkillBar.CooldownUtils
    if CooldownUtils and CooldownUtils.ResetCooldownVisualArming then
        CooldownUtils.ResetCooldownVisualArming()
    end
end

--- Enables or disables the periodic update loops (idempotent).
--- Called from ResourceOrbFrames.ApplySettings on module enable/disable.
---@param enabled boolean Whether the loops should be running
local function AnyLoopRegistered()
    return m_loopRegistered.coreStatus or m_loopRegistered.cooldownVisuals or m_loopRegistered.orbAnimation
end

function Events.SetLoopsEnabled(enabled)
    TraceOrbEvents("resource_orbs.loops", enabled and "enable_requested" or "disable_requested", {
        registered = AnyLoopRegistered(),
        hasTicks = m_loopTicks ~= nil,
    })
    if enabled then
        m_cooldownScanNeeded = true
        RegisterLoopUpdates()
    else
        UnregisterLoopUpdates()
    end
    TraceOrbEvents("resource_orbs.loops", enabled and "enabled" or "disabled", { registered = AnyLoopRegistered() })
end

--- Registers periodic update ticks for status, cooldowns, and orb animation.
---@param rootFrame table Root ResourceOrbFrames control
---@param pools table<number, BetterUIOrbBar> Power pool instances keyed by powerType
---@param shieldBar BetterUIShieldBar|nil Shield bar instance
---@param castBar table|nil Cast bar instance with isCasting field
function Events.SetupLoopEvents(rootFrame, pools, shieldBar, castBar)
    local poolCount = 0
    if pools then
        for _ in pairs(pools) do
            poolCount = poolCount + 1
        end
    end
    TraceOrbEvents("resource_orbs.loops", "setup_begin", {
        hasRoot = rootFrame ~= nil,
        poolCount = poolCount,
        hasShield = shieldBar ~= nil,
        hasCast = castBar ~= nil,
    })
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
    -- The armed latch skips the per-button scan entirely when no ability is on
    -- cooldown, cutting idle work on the hot path (BUI-DEEPDIVE-001 P2).
    local function CooldownVisualTick()
        if not IsModuleEnabled() then return end
        local CooldownUtils = SkillBar.CooldownUtils
        local armed = not (CooldownUtils and CooldownUtils.IsCooldownVisualsArmed)
            or CooldownUtils.IsCooldownVisualsArmed()
        if not armed and not m_cooldownScanNeeded then
            return
        end
        m_cooldownScanNeeded = false
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
    m_cooldownScanNeeded = true
    RegisterLoopUpdates()
    TraceOrbEvents("resource_orbs.loops", "setup_end", { registered = AnyLoopRegistered() })
end

--- Registers HUD/HUDUI scene-showing callbacks to keep native action bar hidden.
---@param rootFrame table Root ResourceOrbFrames control
function Events.SetupSceneHandlers(rootFrame)
    -- Registration latch: SetupModule may retry; scene callbacks must not stack.
    if m_hudSceneHandlersRegistered then
        TraceOrbEvents("resource_orbs.scene_handlers", "setup_skipped", { reason = "alreadyRegistered" })
        return
    end
    local frontBarCfg = GetLiveSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then
        TraceOrbEvents("resource_orbs.scene_handlers", "setup_skipped", { reason = "frontBarDisabled" })
        return
    end
    m_hudSceneHandlersRegistered = true
    TraceOrbEvents("resource_orbs.scene_handlers", "setup_begin", { hasRoot = rootFrame ~= nil })

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
            TraceOrbEvents("resource_orbs.scene_handlers", "hud_showing_task", { firedForceLayout = true })
            CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
        end, 50)
    end

    local hudScene = SCENE_MANAGER:GetScene("hud")
    if hudScene then
        hudScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                TraceOrbEvents("resource_orbs.scene_handlers", "hud_state", { scene = "hud", oldState = oldState, newState = newState })
                OnHUDSceneShowing()
            end
        end)
    end

    local hudUIScene = SCENE_MANAGER:GetScene("hudui")
    if hudUIScene then
        hudUIScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                TraceOrbEvents("resource_orbs.scene_handlers", "hud_state", { scene = "hudui", oldState = oldState, newState = newState })
                OnHUDSceneShowing()
            end
        end)
    end
    TraceOrbEvents("resource_orbs.scene_handlers", "setup_end", { registered = m_hudSceneHandlersRegistered })
end
