--[[
File: Modules/ResourceOrbFrames/OrbEvents.lua
Purpose: Manages periodic updates (ticks) and global event registrations (Visibility, Combat).
Last Modified: 2026-01-23
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Events then BETTERUI.ResourceOrbFrames.Events = {} end

local Events = BETTERUI.ResourceOrbFrames.Events
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
local Visuals = BETTERUI.ResourceOrbFrames.Visuals -- If needed
local NAME = "ResourceOrbFrames"

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
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
    
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEAD, UpdateDeathFragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ALIVE, UpdateDeathFragment)
    
    EVENT_MANAGER:RegisterForEvent(NAME .. "_DeathEnforce", EVENT_PLAYER_DEAD, function()
        zo_callLater(EnforceDefaultUIHidden, 100)
    end)
    EVENT_MANAGER:RegisterForEvent(NAME .. "_AliveEnforce", EVENT_PLAYER_ALIVE, function()
        zo_callLater(EnforceDefaultUIHidden, 100)
    end)
    EVENT_MANAGER:RegisterForEvent(NAME .. "_Reincarnated", EVENT_PLAYER_REINCARNATED, function()
        zo_callLater(EnforceDefaultUIHidden, 100)
    end)
    EVENT_MANAGER:RegisterForEvent(NAME .. "_EndSiege", EVENT_END_SIEGE_CONTROL, function()
        zo_callLater(EnforceDefaultUIHidden, 100)
    end)
    
    if SCENE_MANAGER and SCENE_MANAGER.RestoreHUDScene then
        local originalRestoreHUDScene = SCENE_MANAGER.RestoreHUDScene
        SCENE_MANAGER.RestoreHUDScene = function(self, ...)
            local result = originalRestoreHUDScene(self, ...)
            zo_callLater(EnforceDefaultUIHidden, 50)
            return result
        end
    end
    
    if SCENE_MANAGER and SCENE_MANAGER.RestoreHUDUIScene then
        local originalRestoreHUDUIScene = SCENE_MANAGER.RestoreHUDUIScene
        SCENE_MANAGER.RestoreHUDUIScene = function(self, ...)
            local result = originalRestoreHUDUIScene(self, ...)
            zo_callLater(EnforceDefaultUIHidden, 50)
            return result
        end
    end
    
    local lootScene = SCENE_MANAGER:GetScene("loot")
    if lootScene then
        lootScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                zo_callLater(EnforceDefaultUIHidden, 50)
            end
        end)
    end
    local lootGamepadScene = SCENE_MANAGER:GetScene("lootGamepad")
    if lootGamepadScene then
        lootGamepadScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                zo_callLater(EnforceDefaultUIHidden, 50)
            end
        end)
    end
    
    return UpdateDeathFragment
end

function Events.SetupLoopEvents(rootFrame, pools, shieldBar)
    -- Back Bar Cooldown Tick (100ms)
    local function CooldownTick()
        SkillBar.UpdateBackBarCooldowns(rootFrame)
        local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
        if frontBarCfg and frontBarCfg.m_enabled then
            SkillBar.UpdateFrontBarCooldowns(rootFrame)
            SkillBar.UpdateFrontBarUsability(rootFrame)
            SkillBar.UpdateFrontBarUltimateMeter(rootFrame)
            SkillBar.UpdateFrontBarUltimateNumber(rootFrame)
        end
    end
    EVENT_MANAGER:RegisterForUpdate(NAME .. "BackBarCooldown", 100, CooldownTick)
    
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

function Events.SetupSceneHandlers(rootFrame)
   local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
   if frontBarCfg and frontBarCfg.m_enabled then
        local hudScene = SCENE_MANAGER:GetScene("hud")
        if hudScene then
            hudScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    zo_callLater(function()
                        SkillBar.HideNativeActionBar()
                        -- We need to re-apply layout here? 
                        -- In original code it called ApplyFullLayout().
                        -- ApplyFullLayout is local to core SetupModule.
                        -- We can trigger an event or call global if exposed.
                        -- For now, let's just ensure hiding. 
                        -- The main layout should persist unless cleared.
                        -- But weapon swap animation might have messed anchors if interrupted?
                        -- Ideally we fire an event here that Core listens to.
                        CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end, 50)
                end
            end)
        end
        
        local hudUIScene = SCENE_MANAGER:GetScene("hudui")
        if hudUIScene then
            hudUIScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    zo_callLater(function()
                        SkillBar.HideNativeActionBar()
                        CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end, 50)
                end
            end)
        end
   end
end
