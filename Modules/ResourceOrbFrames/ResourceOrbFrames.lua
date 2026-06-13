--[[
File: Modules/ResourceOrbFrames/ResourceOrbFrames.lua
Purpose: Core Orchestrator for the Resource Orb Frames module.
         Coordinates Visuals, Bars, Skills, and Events.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
local ResourceOrbFrames = BETTERUI.ResourceOrbFrames

-- Sub-modules
local Visuals = nil
local Bars = nil
local SkillBar = nil
local Events = nil

local NAME = "ResourceOrbFrames"
local BARS  -- resolved after Constants.lua loads (in Initialize)
local XP_NO_ORNAMENT_FALLBACK_OFFSET_X = -350
local MOUNT_NO_ORNAMENT_FALLBACK_OFFSET_X = 350
local BAR_FALLBACK_OFFSET_Y = -20

local m_rootFrame = nil
local m_isInitialized = false
local m_updateDeathFragment = nil

-- Cached Control References (avoid repeated FindControl lookups in hot paths)
local m_bgMiddle = nil
local m_frontBarContainer = nil
local m_backBarContainer = nil
local m_leftOrnament = nil
local m_rightOrnament = nil

-- State Containers
local m_pools = {}
local m_shieldBar = nil
local m_experienceBar = nil
local m_castBar = nil
local m_mountStaminaBar = nil

-- Module-specific TaskManager for managed deferred tasks (Phase 1.1)
-- Using module-specific instance prevents ID collisions with other modules
local function GetROFDeferredTaskRuntime()
    local deferredTask = BETTERUI.CIM and BETTERUI.CIM.DeferredTask
    assert(deferredTask, "BetterUI: CIM.DeferredTask must load before ResourceOrbFrames runtime use")
    return deferredTask
end

local function EnsureResourceOrbFramesTaskManager()
    if not ResourceOrbFrames._taskManager then
        ResourceOrbFrames._taskManager = GetROFDeferredTaskRuntime().CreateManager()
    end
    return ResourceOrbFrames._taskManager
end

local function GetROFTasks()
    ResourceOrbFrames.Tasks = ResourceOrbFrames.Tasks or GetROFDeferredTaskRuntime().CreateLazyManagerProxy(EnsureResourceOrbFramesTaskManager)
    return ResourceOrbFrames.Tasks
end

ResourceOrbFrames.EnsureTaskManager = EnsureResourceOrbFramesTaskManager

local Utils = BETTERUI.ResourceOrbFrames.Utils
local SettingsUtils = Utils.Settings
local ControlUtils = Utils.Controls

local GetSettings = SettingsUtils.Get
local GetFrontBarConfig = SettingsUtils.GetCustomFrontBar
local FindControl = ControlUtils.Find

-- UPDATE HELPERS

local function RefreshAllData()
    if not m_isInitialized then return end
    if m_updateDeathFragment then m_updateDeathFragment() end

    -- Update Power Pools
    for powerType, pool in pairs(m_pools) do
        local powerValue, powerMax = GetUnitPower("player", powerType)
        ZO_StatusBar_SmoothTransition(pool, powerValue, powerMax)
    end

    if m_shieldBar then
        local healthMax = m_pools[POWERTYPE_HEALTH] and m_pools[POWERTYPE_HEALTH]:GetMax() or 1
        m_shieldBar:SetRange(0, healthMax)
        if BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY then
            m_shieldBar:UpdateValue(math.floor(healthMax * 0.65)) -- Debug: show 65% shield for visual tuning
        else
            -- Re-query the live shield value instead of zeroing it. Zeroing
            -- blanked an active ward on every refresh until the next
            -- EVENT_UNIT_ATTRIBUTE_VISUAL_* event arrived.
            local shieldValue = 0
            if type(GetUnitAttributeVisualizerEffectInfo) == "function" then
                shieldValue = GetUnitAttributeVisualizerEffectInfo("player",
                    ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION,
                    ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH) or 0
            end
            m_shieldBar:UpdateValue(shieldValue)
        end
    end

    if m_experienceBar then m_experienceBar:Update() end
    if m_castBar then m_castBar:Update() end
    if m_mountStaminaBar then m_mountStaminaBar:Update() end
end

---@param updateOrbs boolean Whether to update orb frame layout
---@param updateSkills boolean Whether to update skill bar layout
local function ApplyLayout(updateOrbs, updateSkills)
    if not m_rootFrame or not m_isInitialized then return end

    if updateSkills then
        -- Update Skill Bar Layouts
        SkillBar.UpdateBackBar(m_rootFrame)
        SkillBar.UpdateBackBarLayout(m_rootFrame)
        SkillBar.UpdateMainBarLayout(m_rootFrame)
        if not SkillBar.IsWeaponSwapAnimating() then
            SkillBar.UpdateBarPositions(m_rootFrame)
        end

        -- Custom Front Bar Updates
        local frontBarCfg = GetFrontBarConfig()
        if frontBarCfg and frontBarCfg.m_enabled then
            if not SkillBar.IsWeaponSwapAnimating() then
                SkillBar.UpdateFrontBarLayout(m_rootFrame)
            end
            SkillBar.UpdateFrontBar(m_rootFrame)
            SkillBar.UpdateFrontBarQuickslot(m_rootFrame)
            SkillBar.UpdateFrontBarCompanion(m_rootFrame)
            SkillBar.UpdateFrontBarUltimateMeter(m_rootFrame)
        end
    end

    if updateOrbs then
        -- Update Visuals Layouts
        Visuals.UpdateFrameDimensions(m_rootFrame)
        Visuals.ApplyThemeVisuals(m_rootFrame)
        Visuals.UpdateOrbLayout(m_rootFrame, m_pools, m_shieldBar)
    end

    -- Update Bar Frames Layout (Anchoring) - use cached control references
    local settings = GetSettings() or {}

    -- Independent orb offset: ornament-anchored branches follow the ornaments
    -- automatically; bgMiddle-anchored branches must add the offset themselves
    -- so the XP/mount bars stay with the orb composite.
    local orbOffsetX = settings.enableIndependentOrbOffset and (settings.orbOffsetX or 0) or 0
    local orbOffsetY = settings.enableIndependentOrbOffset and (settings.orbOffsetY or 0) or 0


    -- Lazily resolve BARS reference (Constants.lua loads before this runs)
    if not BARS then BARS = BETTERUI.ResourceOrbFrames.CONST.BARS end

    if m_experienceBar and m_experienceBar.control then
        m_experienceBar.control:ClearAnchors()
        if settings.hideLeftOrnament then
            local nx = (BARS.XP.NO_ORNAMENT_OFFSET_X or -350) + orbOffsetX
            local ny = (BARS.XP.NO_ORNAMENT_OFFSET_Y or 108) + orbOffsetY
            m_experienceBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, nx, ny)
        else
            if m_leftOrnament then
                m_experienceBar.control:SetAnchor(TOP, m_leftOrnament, BOTTOM, BARS.XP.OFFSET_X,
                    BARS.XP.OFFSET_Y)
            else
                m_experienceBar.control:SetAnchor(BOTTOM, m_bgMiddle, BOTTOM, XP_NO_ORNAMENT_FALLBACK_OFFSET_X + orbOffsetX,
                    BAR_FALLBACK_OFFSET_Y + orbOffsetY)
            end
        end
        m_experienceBar:Update()
    end

    if m_mountStaminaBar and m_mountStaminaBar.control then
        m_mountStaminaBar.control:ClearAnchors()
        if settings.hideRightOrnament then
            local nx = (BARS.MOUNT.NO_ORNAMENT_OFFSET_X or 375) + orbOffsetX
            local ny = (BARS.MOUNT.NO_ORNAMENT_OFFSET_Y or 108) + orbOffsetY
            m_mountStaminaBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, nx, ny)
        else
            if m_rightOrnament then
                m_mountStaminaBar.control:SetAnchor(TOP, m_rightOrnament, BOTTOM, BARS.MOUNT.OFFSET_X,
                    BARS.MOUNT.OFFSET_Y)
            else
                m_mountStaminaBar.control:SetAnchor(BOTTOM, m_bgMiddle, BOTTOM, MOUNT_NO_ORNAMENT_FALLBACK_OFFSET_X + orbOffsetX, BAR_FALLBACK_OFFSET_Y + orbOffsetY)
            end
        end
        m_mountStaminaBar:Update()
    end

    if m_castBar and m_castBar.control then
        m_castBar.control:ClearAnchors()
        if settings.hideBackBar or not m_backBarContainer then
            -- When back bar is hidden (e.g. Oakensoul builds), anchor cast bar to the front bar instead
            if m_frontBarContainer then
                m_castBar.control:SetAnchor(BOTTOM, m_frontBarContainer, TOP, BARS.CAST.OFFSET_X, BARS.CAST.OFFSET_Y)
            else
                m_castBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, BARS.CAST.OFFSET_X, -200)
            end
        else
            m_castBar.control:SetAnchor(BOTTOM, m_backBarContainer, TOP, BARS.CAST.OFFSET_X,
                BARS.CAST.OFFSET_Y)
        end
        m_castBar:Update()
    end
end

local function ApplyFullLayout()
    ApplyLayout(true, true)
end

-- INITIALIZATION HELPERS

local function GetSkillBarModule()
    return SkillBar or BETTERUI.ResourceOrbFrames.SkillBar
end

--- Replays front bar handlers (keybinds, press feedback, tooltips).
---@param control table Root ResourceOrbFrames control
local function SetupFrontBarHandlers(control)
    local skillBar = GetSkillBarModule()
    if skillBar.SetupFrontBarKeybinds then
        skillBar.SetupFrontBarKeybinds(control)
    end
    if skillBar.SetupFrontBarPressFeedbackHooks then
        skillBar.SetupFrontBarPressFeedbackHooks(control)
    end
    if skillBar.SetupFrontBarTooltips then
        skillBar.SetupFrontBarTooltips(control)
    end
end

--- Suppresses native action bar and attribute bars.
local function SuppressNativeBars()
    local skillBar = GetSkillBarModule()
    if skillBar and skillBar.HideNativeActionBar then
        skillBar.HideNativeActionBar()
    end
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
    end
end

--- Registers all dynamic event callbacks after initial component setup.
---@param control table Root ResourceOrbFrames control
local function RegisterDynamicEvents(control)
    -- Layout force update (skip during weapon swap animation to prevent orb shifting)
    CALLBACK_MANAGER:RegisterCallback("BetterUI_ForceLayoutUpdate", function()
        if not SkillBar.IsWeaponSwapAnimating() then
            ApplyFullLayout()
            if Events.RefreshCombatIndicators then
                Events.RefreshCombatIndicators(control)
            end
        end
    end)

    -- Gamepad switch (dynamic re-skin instead of ReloadUI)
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        if not m_isInitialized or not m_rootFrame then return end

        if SkillBar.StopWeaponSwapAnimation then
            SkillBar.StopWeaponSwapAnimation(m_rootFrame)
        end

        -- Re-apply mode-specific XML template and action bar skin.
        local isGP = IsInGamepadPreferredMode()
        local gpLayout = isGP and BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG.GAMEPAD or BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG.KEYBOARD
        SkillBar.ApplyActionBarSkin(m_rootFrame, gpLayout)

        -- Re-cache button children after the re-skin so the cooldown loops
        -- keep using cached controls.
        if SkillBar.CacheFrontBarControls then
            SkillBar.CacheFrontBarControls(m_rootFrame)
        end
        if SkillBar.CacheBackBarControls then
            SkillBar.CacheBackBarControls(m_rootFrame)
        end

        -- Replay the post-skin setup sequence. SetParent is intentionally NOT repeated:
        -- ApplyTemplateToControl does not destroy/recreate controls.
        local cfg = GetFrontBarConfig()
        if cfg and cfg.m_enabled then
            SkillBar.UpdateFrontBar(m_rootFrame)
            SkillBar.UpdateFrontBarQuickslot(m_rootFrame)
            SkillBar.UpdateFrontBarCompanion(m_rootFrame)
            SkillBar.UpdateFrontBarUltimateMeter(m_rootFrame)
            SetupFrontBarHandlers(m_rootFrame)
        end

        ApplyFullLayout()
        RefreshAllData()
        SuppressNativeBars()

        if Events.RefreshCombatIndicators then
            Events.RefreshCombatIndicators(m_rootFrame)
        end
    end)

    -- Dynamic bar updates
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_BackBar", EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
        function()
            SkillBar.WeaponSwapAnimation(control)
            GetROFTasks():Schedule("weaponSwapLayout", BETTERUI.CIM.CONST.TIMING.WEAPON_SWAP_LAYOUT_DELAY_MS,
                function() ApplyLayout(false, true) end)
        end)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_BackBarSlots", EVENT_ACTION_SLOTS_FULL_UPDATE,
        function()
            SkillBar.UpdateBackBar(control)
            local cfg = GetFrontBarConfig()
            if cfg and cfg.m_enabled then SkillBar.UpdateFrontBar(control) end
            ApplyLayout(false, true)
        end)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_BackBarSlot", EVENT_ACTION_SLOT_UPDATED,
        function()
            SkillBar.UpdateBackBar(control)
            local cfg = GetFrontBarConfig()
            if cfg and cfg.m_enabled then SkillBar.UpdateFrontBar(control) end
        end)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CompanionState",
        EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
            local cfg = GetFrontBarConfig()
            if cfg and cfg.m_enabled then
                SkillBar.UpdateFrontBarCompanion(control)
            end
            GetROFTasks():Schedule("companionLayout", BETTERUI.CIM.CONST.TIMING.SCENE_HANDLER_DELAY_MS, ApplyFullLayout)
        end)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_Quickslot", EVENT_ACTIVE_QUICKSLOT_CHANGED,
        function()
            local cfg = GetFrontBarConfig()
            if cfg and cfg.m_enabled then
                SkillBar.UpdateFrontBarQuickslot(control)
            end
        end)

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "_FrontBarPressFeedbackAbilityUsed",
        EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
            if not slotIndex then return end
            local frontBarSettings = GetFrontBarConfig()
            if not frontBarSettings or not frontBarSettings.m_enabled then return end
            if SkillBar.PlayFrontBarPressFeedbackForSlot then
                SkillBar.PlayFrontBarPressFeedbackForSlot(control, slotIndex, nil, true)
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")

    -- Zone change cleanup (for subsequent zones after initial setup)
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED,
        function()
            GetROFTasks():Schedule("playerActivatedRefresh", BETTERUI.CIM.CONST.TIMING.PLAYER_ACTIVATED_INIT_MS, function()
                SuppressNativeBars()
                ApplyFullLayout()
                RefreshAllData()
                if Events.RefreshCombatIndicators then
                    Events.RefreshCombatIndicators(control)
                end
            end)
        end)
end

-- INITIALIZATION

-- Latches so a retried SetupModule (e.g. after a partial SafeExecute failure
-- in ApplySettings) never double-creates components or double-registers
-- events. Component creation also reuses any controls that already exist.
local m_dynamicEventsRegistered = false

---@param control table Root ResourceOrbFrames control
local function SetupModule(control)
    m_rootFrame = control

    -- 1. Load Sub-modules (ensure they are ready)
    Visuals = BETTERUI.ResourceOrbFrames.Visuals
    Bars = BETTERUI.ResourceOrbFrames.Bars
    SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
    Events = BETTERUI.ResourceOrbFrames.Events

    -- 2. Cache Control References (avoid repeated FindControl lookups in ApplyLayout)
    m_bgMiddle = FindControl(control, 'BgMiddle')
    m_frontBarContainer = FindControl(control, 'FrontBarContainer')
    m_backBarContainer = FindControl(control, 'BackBarContainer')
    m_leftOrnament = FindControl(control, 'OrnamentLeft')
    m_rightOrnament = FindControl(control, 'OrnamentRight')

    -- 3. Setup Visual Components (reuse instances on retried setup)
    if not next(m_pools) then
        m_pools = Visuals.SetupPowerPools(control)
    end
    m_shieldBar = m_shieldBar or Visuals.SetupShieldBar(control, m_pools)
    m_experienceBar = m_experienceBar or Bars.CreateExperienceBar(control)
    m_castBar = m_castBar or Bars.CreateCastBar(control)
    m_mountStaminaBar = m_mountStaminaBar or Bars.CreateMountStaminaBar(control)

    -- 4. Setup Events & Visibility (latched: fragments register callbacks once)
    if not m_updateDeathFragment then
        m_updateDeathFragment = Events.SetupVisibilityFragments(control)
    end

    -- 5. Apply Initial Skin & Layout
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG.GAMEPAD or BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG.KEYBOARD
    SkillBar.ApplyActionBarSkin(control, layout)

    local frontBarCfg = GetFrontBarConfig()
    if frontBarCfg and frontBarCfg.m_enabled then
        local frontBarContainer = FindControl(control, 'FrontBarContainer')
        if frontBarContainer then
            local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
            if qsBtn then qsBtn:SetParent(control) end
            local compBtn = FindControl(frontBarContainer, 'CompanionButton')
            if compBtn then compBtn:SetParent(control) end
            local invalidateControlCache = BETTERUI.ControlUtils and BETTERUI.ControlUtils.InvalidateControlCache
            if type(invalidateControlCache) == "function" then
                invalidateControlCache()
            end
        end
        SkillBar.UpdateFrontBar(control)
        SetupFrontBarHandlers(control)
    end

    -- Cache front/back bar control references after the skin is applied and
    -- the quickslot/companion buttons are reparented, so the 16ms cooldown
    -- loops read cached children instead of GetNamedChild fallbacks.
    if SkillBar.CacheFrontBarControls then
        SkillBar.CacheFrontBarControls(control)
    end
    if SkillBar.CacheBackBarControls then
        SkillBar.CacheBackBarControls(control)
    end

    Visuals.UpdateOrbLayout(control, m_pools, m_shieldBar)
    RefreshAllData()

    -- 6. Setup Event Loops
    Events.SetupLoopEvents(control, m_pools, m_shieldBar, m_castBar)
    Events.SetupSceneHandlers(control)
    if Events.SetupCombatIndicators then
        Events.SetupCombatIndicators(control)
    end

    m_isInitialized = true

    -- 7. Register Dynamic Events (latched against retried setup)
    if not m_dynamicEventsRegistered then
        m_dynamicEventsRegistered = true
        RegisterDynamicEvents(control)
    end
end

-- PUBLIC INTERFACE

--- Initializes the ResourceOrbFrames module from the XML OnInitialized handler.
---@param control table Root UI control created from XML template
function ResourceOrbFrames.Initialize(control)
    m_rootFrame = control

    -- Defer full setup until player is actually in the world
    -- This ensures all ESO UI fragments and systems are ready
    -- Guard: m_isInitialized check in DeferredTask callback (L331) prevents double SetupModule()
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_InitSetup", EVENT_PLAYER_ACTIVATED, function()
        -- Unregister through the registry so its bookkeeping stays accurate.
        BETTERUI.CIM.EventRegistry.Unregister("ResourceOrbFrames", NAME .. "_InitSetup", EVENT_PLAYER_ACTIVATED)

        GetROFTasks():Schedule("initModuleSetup", BETTERUI.CIM.CONST.TIMING.DEFERRED_INIT_MS, function()
            local settings = GetSettings()
            if not settings or not settings.m_enabled then
                m_rootFrame:SetHidden(true)
                return
            end

            if not m_isInitialized then
                SetupModule(control)
            end

            -- Enforce state after setup
            SkillBar.HideNativeActionBar()
            if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
                PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
            end
            ApplyFullLayout()
            RefreshAllData()
            if Events.RefreshCombatIndicators then
                Events.RefreshCombatIndicators(control)
            end
        end)
    end)
end

--- Applies current settings to the orb frames, toggling visibility and layout.
---@return nil
function ResourceOrbFrames.ApplySettings()
    local settings = GetSettings()
    if not m_rootFrame then return end
    if not settings then return end

    if settings.m_enabled then
        if not m_isInitialized then
            -- Attempt initialization; if it fails, bail out
            local ok = BETTERUI.CIM.SafeExecute("ResourceOrbFrames:SetupModule", SetupModule, m_rootFrame)
            if not ok then
                return
            end
        end
        -- Double-check initialization succeeded before proceeding
        if not m_isInitialized then
            return
        end
        m_rootFrame:SetHidden(false)
        -- Re-register the periodic update loops on enable.
        if Events.SetLoopsEnabled then
            Events.SetLoopsEnabled(true)
        end
        ApplyFullLayout()
        RefreshAllData()
        if Events.RefreshCombatIndicators then
            Events.RefreshCombatIndicators(m_rootFrame)
        end
    else
        m_rootFrame:SetHidden(true)
        -- Stop the periodic update loops so a disabled module pays no
        -- per-tick cost (re-registered on enable above).
        local events = Events or BETTERUI.ResourceOrbFrames.Events
        if events and events.SetLoopsEnabled then
            events.SetLoopsEnabled(false)
        end
        -- Restore Default UI is handled by reload/re-login mostly,
        -- but we could try to unhide?
        -- BetterUI philosophy is usually Reload Required for disable.
    end
end

--- Global XML Handler (Bridge)
---@param control table Root UI control from XML
function ResourceOrbFrames_Initialize(control)
    ResourceOrbFrames.Initialize(control)
end

ResourceOrbFrames._Internals = {
    SetupFrontBarHandlers = SetupFrontBarHandlers,
    SuppressNativeBars = SuppressNativeBars,
}
