--[[
File: Modules/ResourceOrbFrames/SkillBar/ActivationHighlight.lua
Purpose: Shared action-slot activation highlight animation helpers.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
local ActivationHighlight = {}

local function IsHidden(control)
    if not control then
        return true
    end
    if control.IsControlHidden then
        return control:IsControlHidden()
    end
    if control.IsHidden then
        return control:IsHidden()
    end
    return control.hidden == true
end

local function GetAnimationTimeline(animation)
    if animation and animation.GetTimeline then
        return animation:GetTimeline()
    end
    return nil
end

local function StopAnimation(control)
    local timeline = GetAnimationTimeline(control and control.animation)
    if timeline and timeline.Stop then
        timeline:Stop()
    end
end

local function EnsureAnimation(control)
    if not control then
        return nil, false
    end
    if control.animation then
        return control.animation, false
    end
    if type(CreateSimpleAnimation) ~= "function" or ANIMATION_TEXTURE == nil then
        return nil, false
    end

    local animation = CreateSimpleAnimation(ANIMATION_TEXTURE, control)
    if not animation then
        return nil, false
    end
    if animation.SetImageData then
        animation:SetImageData(64, 1)
    end
    if animation.SetFramerate then
        animation:SetFramerate(30)
    end
    local timeline = GetAnimationTimeline(animation)
    if timeline and timeline.SetPlaybackType then
        timeline:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
    end
    control.animation = animation
    return animation, true
end

local function ResolveActivationTexture(slotIndex, hotbarCategory)
    if type(GetSlotTexture) ~= "function" then
        return nil
    end
    local _, _, activationTexture = GetSlotTexture(slotIndex, hotbarCategory)
    if activationTexture == "" then
        return nil
    end
    return activationTexture
end

--- Updates an action button activation highlight using ESOUI's 64-frame texture animation convention.
---@param control table|nil ActivationHighlight texture control
---@param slotIndex number Action slot index
---@param hotbarCategory number|nil Hotbar category
---@param showHighlight boolean Whether the highlight should be visible
---@return boolean visible True when the highlight is visible after update
function ActivationHighlight.Update(control, slotIndex, hotbarCategory, showHighlight)
    if not control then
        return false
    end

    local wasShowing = not IsHidden(control)
    if not showHighlight then
        if wasShowing and control.SetHidden then
            control:SetHidden(true)
        end
        StopAnimation(control)
        control._betteruiActivationHighlightShowing = false
        return false
    end

    local activationTexture = ResolveActivationTexture(slotIndex, hotbarCategory)
    if not activationTexture then
        if control.SetHidden then
            control:SetHidden(true)
        end
        if control.SetTexture then
            control:SetTexture(nil)
        end
        StopAnimation(control)
        control._betteruiActivationAnimationTexture = nil
        control._betteruiActivationHighlightShowing = false
        return false
    end

    local textureChanged = control._betteruiActivationAnimationTexture ~= activationTexture
    if textureChanged and control.SetTexture then
        control:SetTexture(activationTexture)
        control._betteruiActivationAnimationTexture = activationTexture
    end

    local animation, createdAnimation = EnsureAnimation(control)
    if control.SetHidden then
        control:SetHidden(false)
    end

    local timeline = GetAnimationTimeline(animation)
    if timeline and timeline.PlayFromStart and (not wasShowing or createdAnimation or textureChanged) then
        timeline:PlayFromStart()
    end
    control._betteruiActivationHighlightShowing = true
    return true
end

SkillBar.ActivationHighlight = ActivationHighlight
