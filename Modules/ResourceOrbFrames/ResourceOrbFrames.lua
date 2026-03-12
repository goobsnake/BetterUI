--[[
File: Modules/ResourceOrbFrames/ResourceOrbFrames.lua
Purpose: Core Orchestrator for the Resource Orb Frames module.
         Coordinates Visuals, Bars, Skills, and Events.
Last Modified: 2026-02-13
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
local ResourceOrbFrames = BETTERUI.ResourceOrbFrames

-- Sub-modules
local Visuals = nil
local Bars = nil
local SkillBar = nil
local Events = nil

local NAME = "ResourceOrbFrames"
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
local m_foodTracker = nil

-- Module-specific TaskManager for managed deferred tasks (Phase 1.1)
-- Using module-specific instance prevents ID collisions with other modules
local ROFTasks = BETTERUI.CIM.DeferredTask.Manager:New()
ResourceOrbFrames.Tasks = ROFTasks

-- Defaults
local DEFAULTS = {
    m_enabled = true,
    scale = 1.0,
    offsetY = 0,
    showQuickslotCount = true,
    -- (Other defaults handled in GetModuleSettings or specific components)
}

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames", DEFAULTS)
end

local function FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

-- =========================================================================
-- UPDATE HELPERS
-- =========================================================================

local function RefreshAllData()
    if m_updateDeathFragment then m_updateDeathFragment() end

    -- Update Power Pools
    for powerType, pool in pairs(m_pools) do
        local powerValue, powerMax = GetUnitPower("player", powerType)
        ZO_StatusBar_SmoothTransition(pool, powerValue, powerMax)
    end

    if m_shieldBar then
        local healthMax = m_pools[POWERTYPE_HEALTH] and m_pools[POWERTYPE_HEALTH]:GetMax() or 1
        m_shieldBar:SetRange(0, healthMax)
        if BETTERUI_SHIELD_DEBUG then
            m_shieldBar:UpdateValue(math.floor(healthMax * 0.65)) -- Debug: show 65% shield for visual tuning
        else
            m_shieldBar:UpdateValue(0) -- Reset visual, will be updated by event if active
        end
    end

    if m_foodTracker then m_foodTracker:Update() end
    if m_experienceBar then m_experienceBar:Update() end
    if m_castBar then m_castBar:Update() end
    if m_mountStaminaBar then m_mountStaminaBar:Update() end
end

local function ApplyLayout(updateOrbs, updateSkills)
    if not m_rootFrame then return end

    if updateSkills then
        -- Update Skill Bar Layouts
        SkillBar.UpdateBackBar(m_rootFrame)
        SkillBar.UpdateBackBarLayout(m_rootFrame)
        SkillBar.UpdateMainBarLayout(m_rootFrame)
        if not SkillBar.IsWeaponSwapAnimating() then
            SkillBar.UpdateBarPositions(m_rootFrame)
        end

        -- Custom Front Bar Updates
        local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
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
    local settings = GetModuleSettings()


    if m_experienceBar and m_experienceBar.control then
        m_experienceBar.control:ClearAnchors()
        if settings.hideLeftOrnament then
            local nx = BETTERUI_XP_BAR_NO_ORNAMENT_OFFSET_X or -350
            local ny = BETTERUI_XP_BAR_NO_ORNAMENT_OFFSET_Y or 108
            m_experienceBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, nx, ny)
        else
            if m_leftOrnament then
                m_experienceBar.control:SetAnchor(TOP, m_leftOrnament, BOTTOM, BETTERUI_XP_BAR_OFFSET_X,
                    BETTERUI_XP_BAR_OFFSET_Y)
            else
                m_experienceBar.control:SetAnchor(BOTTOM, m_bgMiddle, BOTTOM, -350, -20) -- Fallback
            end
        end
        m_experienceBar:Update()
    end

    if m_mountStaminaBar and m_mountStaminaBar.control then
        m_mountStaminaBar.control:ClearAnchors()
        if settings.hideRightOrnament then
            local nx = BETTERUI_MOUNT_STAMINA_BAR_NO_ORNAMENT_OFFSET_X or 375
            local ny = BETTERUI_MOUNT_STAMINA_BAR_NO_ORNAMENT_OFFSET_Y or 108
            m_mountStaminaBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, nx, ny)
        else
            if m_rightOrnament then
                m_mountStaminaBar.control:SetAnchor(TOP, m_rightOrnament, BOTTOM, BETTERUI_MOUNT_STAMINA_BAR_OFFSET_X,
                    BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y)
            else
                m_mountStaminaBar.control:SetAnchor(BOTTOM, m_bgMiddle, BOTTOM, 350, -20)
            end
        end
        m_mountStaminaBar:Update()
    end

    if m_castBar and m_castBar.control then
        m_castBar.control:ClearAnchors()
        if settings.hideBackBar or not m_backBarContainer then
            -- When back bar is hidden (e.g. Oakensoul builds), anchor cast bar to the front bar instead
            if m_frontBarContainer then
                m_castBar.control:SetAnchor(BOTTOM, m_frontBarContainer, TOP, BETTERUI_CAST_BAR_OFFSET_X, BETTERUI_CAST_BAR_OFFSET_Y)
            else
                m_castBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, BETTERUI_CAST_BAR_OFFSET_X or 0, -200)
            end
        else
            m_castBar.control:SetAnchor(BOTTOM, m_backBarContainer, TOP, BETTERUI_CAST_BAR_OFFSET_X,
                BETTERUI_CAST_BAR_OFFSET_Y)
        end
        m_castBar:Update()
    end
end

local function ApplyFullLayout()
    ApplyLayout(true, true)
end

-- =========================================================================
-- INITIALIZATION
-- =========================================================================

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

    -- 3. Setup Visual Components
    m_pools = Visuals.SetupPowerPools(control)
    m_shieldBar = Visuals.SetupShieldBar(control, m_pools)

    m_foodTracker = Bars.CreateFoodTracker(FindControl(control, 'FoodBar'))
    m_experienceBar = Bars.CreateExperienceBar(control)
    m_castBar = Bars.CreateCastBar(control)
    m_mountStaminaBar = Bars.CreateMountStaminaBar(control)

    -- 4. Setup Events & Visibility
    m_updateDeathFragment = Events.SetupVisibilityFragments(control)

    -- 4. Apply Initial Skin & Layout
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and LAYOUT_CONFIG.GAMEPAD or LAYOUT_CONFIG.KEYBOARD
    SkillBar.ApplyActionBarSkin(control, layout)

    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if frontBarCfg and frontBarCfg.m_enabled then
        -- Reparent specific buttons if needed for animation isolation
        -- (Logic from original: Quickslot and Companion reparented to root)
        local frontBarContainer = FindControl(control, 'FrontBarContainer')
        if frontBarContainer then
            local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
            -- NOTE (2026-01-28): Single SetParent is correct for animation isolation. Duplicate call was removed.
            if qsBtn then qsBtn:SetParent(control) end
            local compBtn = FindControl(frontBarContainer, 'CompanionButton')
            if compBtn then compBtn:SetParent(control) end
            if BETTERUI.ControlUtils and BETTERUI.ControlUtils.InvalidateControlCache then
                BETTERUI.ControlUtils.InvalidateControlCache()
            end
        end

        SkillBar.UpdateFrontBar(control) -- Force content update on load

        -- Setup Front Bar specific tooltips/keybinds
        if SkillBar.SetupFrontBarKeybinds then
            SkillBar.SetupFrontBarKeybinds(control)
        end
        if SkillBar.SetupFrontBarPressFeedbackHooks then
            SkillBar.SetupFrontBarPressFeedbackHooks(control)
        end
        if SkillBar.SetupFrontBarTooltips then
            SkillBar.SetupFrontBarTooltips(control)
        end
    end

    Visuals.UpdateOrbLayout(control, m_pools, m_shieldBar) -- Initial Orb Layout
    RefreshAllData()

    -- 5. Setup Event Loops
    Events.SetupLoopEvents(control, m_pools, m_shieldBar, m_castBar)
    Events.SetupSceneHandlers(control)
    if Events.SetupCombatIndicators then
        Events.SetupCombatIndicators(control)
    end

    m_isInitialized = true

    -- Register Layout Force Update (skip during weapon swap animation to prevent orb shifting)
    CALLBACK_MANAGER:RegisterCallback("BetterUI_ForceLayoutUpdate", function()
        if not SkillBar.IsWeaponSwapAnimating() then
            ApplyFullLayout()
            if Events.RefreshCombatIndicators then
                Events.RefreshCombatIndicators(control)
            end
        end
    end)

    -- Register Gamepad Switch
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        ReloadUI()
    end)

    -- Register Dynamic Bar Updates
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_BackBar", EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
        function()
            SkillBar.WeaponSwapAnimation(control)
            -- Only update skills layout, skip orbs to prevent visual shifts
            ROFTasks:Schedule("weaponSwapLayout", BETTERUI.CIM.CONST.TIMING.WEAPON_SWAP_LAYOUT_DELAY_MS,
                function() ApplyLayout(false, true) end)
        end)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_BackBarSlots", EVENT_ACTION_SLOTS_FULL_UPDATE,
        function()
            SkillBar.UpdateBackBar(control)
            if frontBarCfg and frontBarCfg.m_enabled then SkillBar.UpdateFrontBar(control) end
            -- Only update skills layout
            ApplyLayout(false, true)
        end)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_BackBarSlot", EVENT_ACTION_SLOT_UPDATED,
        function()
            SkillBar.UpdateBackBar(control)
            if frontBarCfg and frontBarCfg.m_enabled then SkillBar.UpdateFrontBar(control) end
        end)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_CompanionState",
        EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
            if frontBarCfg and frontBarCfg.m_enabled then
                SkillBar.UpdateFrontBarCompanion(control)
            end
            ROFTasks:Schedule("companionLayout", BETTERUI.CIM.CONST.TIMING.SCENE_HANDLER_DELAY_MS, ApplyFullLayout)
        end)

    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_Quickslot", EVENT_ACTIVE_QUICKSLOT_CHANGED,
        function()
            if frontBarCfg and frontBarCfg.m_enabled then
                SkillBar.UpdateFrontBarQuickslot(control)
            end
        end)

    BETTERUI.CIM.EventRegistry.RegisterFiltered("ResourceOrbFrames", NAME .. "_FrontBarPressFeedbackAbilityUsed",
        EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
            if not slotIndex then
                return
            end

            local frontBarSettings = BETTERUI.GetModuleSettings("ResourceOrbFrames").customFrontBar
            if not frontBarSettings or not frontBarSettings.m_enabled then
                return
            end

            if SkillBar.PlayFrontBarPressFeedbackForSlot then
                SkillBar.PlayFrontBarPressFeedbackForSlot(control, slotIndex, nil, true)
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")



    -- Zone Change Cleanup (for subsequent zones after initial setup)
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED,
        function()
            ROFTasks:Schedule("playerActivatedRefresh", BETTERUI.CIM.CONST.TIMING.PLAYER_ACTIVATED_INIT_MS, function()
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

-- =========================================================================
-- PUBLIC INTERFACE
-- =========================================================================

--- @param control Control The root control
function ResourceOrbFrames.Initialize(control)
    m_rootFrame = control

    -- Defer full setup until player is actually in the world
    -- This ensures all ESO UI fragments and systems are ready
    -- Guard: m_isInitialized check in DeferredTask callback (L331) prevents double SetupModule()
    BETTERUI.CIM.EventRegistry.Register("ResourceOrbFrames", NAME .. "_InitSetup", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(NAME .. "_InitSetup", EVENT_PLAYER_ACTIVATED)

        ROFTasks:Schedule("initModuleSetup", BETTERUI.CIM.CONST.TIMING.DEFERRED_INIT_MS, function()
            local settings = GetModuleSettings()
            if not settings.m_enabled then
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

function ResourceOrbFrames.ApplySettings()
    local settings = GetModuleSettings()
    if not m_rootFrame then return end

    if settings.m_enabled then
        if not m_isInitialized then
            SetupModule(m_rootFrame)
        end
        m_rootFrame:SetHidden(false)
        ApplyFullLayout()
        RefreshAllData()
        if Events.RefreshCombatIndicators then
            Events.RefreshCombatIndicators(m_rootFrame)
        end
    else
        m_rootFrame:SetHidden(true)
        -- Restore Default UI is handled by reload/re-login mostly,
        -- but we could try to unhide?
        -- BetterUI philosophy is usually Reload Required for disable.
    end
end

-- Global XML Handler (Bridge)
function ResourceOrbFrames_Initialize(control)
    ResourceOrbFrames.Initialize(control)
end
