--[[
File: Modules/ResourceOrbFrames/ResourceOrbFrames.lua
Purpose: Core Orchestrator for the Resource Orb Frames module.
         Coordinates Visuals, Bars, Skills, and Events.
Last Modified: 2026-01-23
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
local ResourceOrbFrames = BETTERUI.ResourceOrbFrames

-- Sub-modules
local Animations = nil -- Loaded on demand or assumed loaded
local Visuals = nil
local Bars = nil
local SkillBar = nil
local Events = nil

local NAME = "ResourceOrbFrames"
local m_rootFrame = nil
local m_isInitialized = false
local m_updateDeathFragment = nil

-- State Containers
local m_pools = {}
local m_shieldBar = nil
local m_experienceBar = nil
local m_castBar = nil
local m_mountStaminaBar = nil
local m_foodTracker = nil

-- Defaults
local DEFAULTS = {
    enabled = true,
    scale = 1.0,
    offsetY = 0,
    useCustomTextures = false,
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
        m_shieldBar:UpdateValue(0) -- Reset visual, will be updated by event if active
        -- Ideally we check current shield value here?
        local currentShield = GetUnitAttributeVisualizerEffectInfo(MSG_VISUAL_SHIELD) or 0
        -- ESO API for shield is complex, usually event driven. 
        -- We'll rely on events.
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
        SkillBar.UpdateBarPositions(m_rootFrame)
        
        -- Custom Front Bar Updates
        local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
        if frontBarCfg and frontBarCfg.enabled then
            SkillBar.UpdateFrontBarLayout(m_rootFrame)
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
    
    -- Update Bar Frames Layout (Anchoring)
    local bgMiddle = FindControl(m_rootFrame, 'BgMiddle')
    local settings = GetModuleSettings()
    
    local function ApplyBarAnchor(bar, cfgPrefix, defaultParent, useOrnamentLogic)
        if not bar or not bar.control or not bgMiddle then return end
        bar.control:ClearAnchors()
        
        local scale = _G[cfgPrefix .. "_SCALE"] or 1.0
        local offsetX = _G[cfgPrefix .. "_OFFSET_X"] or 0
        local offsetY = _G[cfgPrefix .. "_OFFSET_Y"] or 0
        
        -- Special logic for hidden ornaments (XP and Mount bars)
        if useOrnamentLogic == "Left" and settings.hideLeftOrnament then
             local nx = _G[cfgPrefix .. "_NO_ORNAMENT_OFFSET_X"]
             local ny = _G[cfgPrefix .. "_NO_ORNAMENT_OFFSET_Y"]
             if nx and ny then
                 bar.control:SetAnchor(CENTER, bgMiddle, CENTER, nx, ny)
                 return
             end
        elseif useOrnamentLogic == "Right" and settings.hideRightOrnament then
             local nx = _G[cfgPrefix .. "_NO_ORNAMENT_OFFSET_X"]
             local ny = _G[cfgPrefix .. "_NO_ORNAMENT_OFFSET_Y"]
             if nx and ny then
                 bar.control:SetAnchor(CENTER, bgMiddle, CENTER, nx, ny)
                 return
             end
        end
        
        -- Default anchoring (Ornament visible or no special logic)
        -- XP/Mount bars are relative to respective ornaments if visible, OR relative to BgMiddle but with different offsets?
        -- Actually Constants comments say: "Below left ornament" (implied relative to ornament center?)
        -- But offsets are large (-99).
        -- Let's check Constants again. 
        -- XP Bar: "Below left ornament... Y offset from BgMiddle bottom".
        -- Wait, Constants said: "Y offset from BgMiddle bottom (negative = up)"?
        -- Step 392 (Constants Check): "BETTERUI_XP_BAR_OFFSET_Y = -99 -- Y offset from BgMiddle bottom".
        
        -- But Visuals.lua handles `OrnamentLeft` relative to `BgMiddle`.
        -- If ornaments are visible, maybe anchor to ornament?
        -- Constants say: `BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y = -99 -- Y offset from ornament bottom`?
        -- This inconsistency suggests I should anchor to `BgMiddle` or `Ornament` depending on intention.
        -- Given "Cast Bar ... centered above top/back bar", I should anchor CastBar relative to BackBar or BgMiddle.
        
        -- Let's stick to anchoring to `BgMiddle` (center) and applying the offsets, assuming offsets are relative to Center-Center or user specific logic.
        -- BUT the constants say "from BgMiddle bottom".
        -- I'll use `CENTER` to `CENTER` for simplicity if offsets are global coords, OR `BOTTOM` to `BOTTOM`?
        -- Let's look at `Visuals.UpdateOrbLayout`. It anchors Orbs to `CENTER` of `BgMiddle` or `Ornament`.
        
        -- Let's try anchoring to `BgMiddle`, `CENTER`.
        -- If offsets are from `BgMiddle bottom`, then (0, -99) from Bottom is (0, X) from Center.
        -- Constants: "BETTERUI_XP_BAR_OFFSET_Y = -99 -- Y offset from BgMiddle bottom".
        -- In `UpdateOrbLayout`: `leftOrb:SetAnchor(CENTER, bgMiddle, CENTER, ...)`
        
        -- Re-reading Constants (Step 392):
        -- XP Bar: "Y offset from BgMiddle bottom".
        -- Cast Bar: "Y offset from back bar top".
        -- Mount: "Y offset from ornament bottom".
        
        -- I will implement specific logic for each.
    end
    
    if m_experienceBar and m_experienceBar.control then
         m_experienceBar.control:ClearAnchors()
         if settings.hideLeftOrnament then
              local nx = BETTERUI_XP_BAR_NO_ORNAMENT_OFFSET_X or -350
              local ny = BETTERUI_XP_BAR_NO_ORNAMENT_OFFSET_Y or 108
              m_experienceBar.control:SetAnchor(CENTER, bgMiddle, CENTER, nx, ny)
         else
              local leftOrnament = FindControl(m_rootFrame, 'OrnamentLeft')
              if leftOrnament then
                  m_experienceBar.control:SetAnchor(TOP, leftOrnament, BOTTOM, BETTERUI_XP_BAR_OFFSET_X, BETTERUI_XP_BAR_OFFSET_Y)
              else
                  m_experienceBar.control:SetAnchor(BOTTOM, bgMiddle, BOTTOM, -350, -20) -- Fallback
              end
         end
         m_experienceBar:Update()
    end
    
    if m_mountStaminaBar and m_mountStaminaBar.control then
         m_mountStaminaBar.control:ClearAnchors()
         if settings.hideRightOrnament then
              local nx = BETTERUI_MOUNT_STAMINA_BAR_NO_ORNAMENT_OFFSET_X or 375
              local ny = BETTERUI_MOUNT_STAMINA_BAR_NO_ORNAMENT_OFFSET_Y or 108
              m_mountStaminaBar.control:SetAnchor(CENTER, bgMiddle, CENTER, nx, ny)
         else
              local rightOrnament = FindControl(m_rootFrame, 'OrnamentRight')
              if rightOrnament then
                  m_mountStaminaBar.control:SetAnchor(TOP, rightOrnament, BOTTOM, BETTERUI_MOUNT_STAMINA_BAR_OFFSET_X, BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y)
              else
                   m_mountStaminaBar.control:SetAnchor(BOTTOM, bgMiddle, BOTTOM, 350, -20)
              end
         end
         m_mountStaminaBar:Update()
    end
    
    if m_castBar and m_castBar.control then
         m_castBar.control:ClearAnchors()
         local backBarContainer = FindControl(m_rootFrame, 'BackBarContainer')
         if backBarContainer then
             m_castBar.control:SetAnchor(BOTTOM, backBarContainer, TOP, BETTERUI_CAST_BAR_OFFSET_X, BETTERUI_CAST_BAR_OFFSET_Y)
         else
             m_castBar.control:SetAnchor(CENTER, bgMiddle, CENTER, 0, -200)
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
    Animations = BETTERUI.ResourceOrbFrames.Animations
    Visuals = BETTERUI.ResourceOrbFrames.Visuals
    Bars = BETTERUI.ResourceOrbFrames.Bars
    SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
    Events = BETTERUI.ResourceOrbFrames.Events
    
    -- 2. Setup Visual Components
    m_pools = Visuals.SetupPowerPools(control)
    m_shieldBar = Visuals.SetupShieldBar(control, m_pools)
    
    m_foodTracker = Bars.CreateFoodTracker(FindControl(control, 'FoodBar'))
    m_experienceBar = Bars.CreateExperienceBar(control)
    m_castBar = Bars.CreateCastBar(control)
    m_mountStaminaBar = Bars.CreateMountStaminaBar(control)
    
    -- 3. Setup Events & Visibility
    m_updateDeathFragment = Events.SetupVisibilityFragments(control)
    
    -- 4. Apply Initial Skin & Layout
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and LAYOUT_CONFIG.GAMEPAD or LAYOUT_CONFIG.KEYBOARD
    SkillBar.ApplyActionBarSkin(control, layout)
    
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if frontBarCfg and frontBarCfg.enabled then
        -- Reparent specific buttons if needed for animation isolation
        -- (Logic from original: Quickslot and Companion reparented to root)
        local frontBarContainer = FindControl(control, 'FrontBarContainer')
        if frontBarContainer then
            local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
            if qsBtn then qsBtn:SetParent(control) end
            if qsBtn then qsBtn:SetParent(control) end
            local compBtn = FindControl(frontBarContainer, 'CompanionButton')
            if compBtn then compBtn:SetParent(control) end
        end
        
        SkillBar.UpdateFrontBar(control) -- Force content update on load
        
        -- Setup Front Bar specific tooltips/keybinds
        if SkillBar.SetupFrontBarKeybinds then
            SkillBar.SetupFrontBarKeybinds(control)
        end
        if SkillBar.SetupFrontBarTooltips then
            SkillBar.SetupFrontBarTooltips(control)
        end
    end
    
    Visuals.UpdateOrbLayout(control, m_pools, m_shieldBar) -- Initial Orb Layout
    RefreshAllData()

    -- 5. Setup Event Loops
    Events.SetupLoopEvents(control, m_pools, m_shieldBar)
    Events.SetupSceneHandlers(control)
    
    m_isInitialized = true
    
    -- Register Layout Force Update
    CALLBACK_MANAGER:RegisterCallback("BetterUI_ForceLayoutUpdate", ApplyFullLayout)
    
    -- Register Gamepad Switch
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        ReloadUI()
    end)
    
    -- Register Dynamic Bar Updates
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBar", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() 
        SkillBar.WeaponSwapAnimation(control)
        -- Only update skills layout, skip orbs to prevent visual shifts
        zo_callLater(function() ApplyLayout(false, true) end, 500)
    end)
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBarSlots", EVENT_ACTION_SLOTS_FULL_UPDATE, function() 
        SkillBar.UpdateBackBar(control)
        if frontBarCfg and frontBarCfg.enabled then SkillBar.UpdateFrontBar(control) end
        -- Only update skills layout
        ApplyLayout(false, true)
    end)
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "BackBarSlot", EVENT_ACTION_SLOT_UPDATED, function() 
        SkillBar.UpdateBackBar(control)
        if frontBarCfg and frontBarCfg.enabled then SkillBar.UpdateFrontBar(control) end
    end)
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "CompanionState", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
        if frontBarCfg and frontBarCfg.enabled then
            SkillBar.UpdateFrontBarCompanion(control)
        end
        zo_callLater(ApplyFullLayout, 200)
    end)
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "Quickslot", EVENT_ACTIVE_QUICKSLOT_CHANGED, function()
        if frontBarCfg and frontBarCfg.enabled then
            SkillBar.UpdateFrontBarQuickslot(control)
        end
    end)
    
    -- Feature Events (Combat, Ultimate #)
    EVENT_MANAGER:RegisterForEvent(NAME .. "_UltimateNumber", EVENT_POWER_UPDATE, function(_, unitTag, _, powerType)
        if unitTag == "player" and powerType == POWERTYPE_ULTIMATE then
             if SkillBar.UpdateFrontBarUltimateNumber then
                 SkillBar.UpdateFrontBarUltimateNumber(control)
             end
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NAME .. "_UltimateNumber", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_ULTIMATE, REGISTER_FILTER_UNIT_TAG, "player")

    -- Zone Change Cleanup (for subsequent zones after initial setup)
    EVENT_MANAGER:RegisterForEvent(NAME .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
         zo_callLater(function()
             SkillBar.HideNativeActionBar()
             if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
                 PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
             end
             ApplyFullLayout()
             RefreshAllData()
         end, 100)
    end)
end

-- =========================================================================
-- PUBLIC INTERFACE
-- =========================================================================

function ResourceOrbFrames.Initialize(control)
    m_rootFrame = control
    
    -- Defer full setup until player is actually in the world
    -- This ensures all ESO UI fragments and systems are ready
    EVENT_MANAGER:RegisterForEvent(NAME .. "_InitSetup", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(NAME .. "_InitSetup", EVENT_PLAYER_ACTIVATED)
        
        zo_callLater(function()
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
        end, 100)
    end)
end

function ResourceOrbFrames.ApplySettings()
    local settings = GetModuleSettings()
    if not m_rootFrame then return end

    if settings.enabled then
        if not m_isInitialized then
             SetupModule(m_rootFrame)
        end
        m_rootFrame:SetHidden(false)
        ApplyFullLayout()
        RefreshAllData()
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
