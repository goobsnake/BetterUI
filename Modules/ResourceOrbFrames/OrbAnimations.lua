--[[
File: Modules/ResourceOrbFrames/OrbAnimations.lua
Purpose: Handles generic animations for the Resource Orb Frames module.
         Includes frame dimension animations (scale/offset) and combat glow helpers.
Last Modified: 2026-01-23
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Animations then BETTERUI.ResourceOrbFrames.Animations = {} end

local Animations = BETTERUI.ResourceOrbFrames.Animations

-- State tracking for dimension animation
local m_dimensionsTimeline = nil
local m_lastScale = nil
local m_lastOffsetY = nil

--- Animates the root frame's scale and vertical position.
--- @param rootFrame control The root frame control.
--- @param targetScale number The target scale.
--- @param targetOffsetY number The target Y offset (inverted, positive moves up).
function Animations.AnimateDimensions(rootFrame, targetScale, targetOffsetY)
    if not rootFrame then return end
    
    -- Stop existing animation
    if m_dimensionsTimeline then m_dimensionsTimeline:Stop() end
    
    if not m_dimensionsTimeline then
        m_dimensionsTimeline = ANIMATION_MANAGER:CreateTimeline()
        
        -- Fade Animation (Flash effect)
        local alphaAnim = m_dimensionsTimeline:InsertAnimation(ANIMATION_ALPHA, rootFrame)
        alphaAnim:SetDuration(250)
        alphaAnim:SetAlphaValues(0.5, 1.0)
        alphaAnim:SetEasingFunction(ZO_EaseInQuadratic)
        
        -- Custom Animation for Scale and Position
        local customAnim = m_dimensionsTimeline:InsertAnimation(ANIMATION_CUSTOM, rootFrame)
        customAnim:SetDuration(300)
        customAnim:SetEasingFunction(ZO_EaseOutQuadratic)
        
        customAnim:SetUpdateFunction(function(anim, progress)
            local currentScale = zo_lerp(anim.startScale, anim.endScale, progress)
            local currentY = zo_lerp(anim.startY, anim.endY, progress)
            
            rootFrame:SetScale(currentScale)
            rootFrame:ClearAnchors()
            -- Invert offsetY: positive settings value means UP, so we used negative anchor Y
            rootFrame:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -currentY)
        end)
    end
    
    -- Setup animation data
    local customAnim = m_dimensionsTimeline:GetFirstAnimationOfType(ANIMATION_CUSTOM)
    customAnim.startScale = rootFrame:GetScale()
    customAnim.endScale = targetScale
    -- Check if we have a valid last offset, otherwise try to get from current anchor
    if m_lastOffsetY then
        customAnim.startY = m_lastOffsetY
    else
        -- Try to derive from current anchor
        local _, _, _, _, _, currentAnchorY = rootFrame:GetAnchor(0)
        -- m_lastOffsetY corresponds to POSITIVE up (inverted in anchor)
        -- Anchor Y = -offsetY
        -- So offsetY = -AnchorY
        customAnim.startY = currentAnchorY and -currentAnchorY or targetOffsetY
    end
    customAnim.endY = targetOffsetY
    
    m_dimensionsTimeline:PlayFromStart()
    
    -- Update state
    m_lastScale = targetScale
    m_lastOffsetY = targetOffsetY
end

--- Updates state without animating (instant set).
--- Use this during initialization to sync state.
function Animations.SetState(scale, offsetY)
    m_lastScale = scale
    m_lastOffsetY = offsetY
end

function Animations.GetLastScale()
    return m_lastScale
end

function Animations.GetLastOffsetY()
    return m_lastOffsetY
end

--- Creates a looping ping-pong alpha animation for combat glow.
--- @param control control The control to animate.
--- @return object The animation timeline.
function Animations.CreateCombatGlow(control)
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local anim = timeline:InsertAnimation(ANIMATION_ALPHA, control, 0)
    anim:SetDuration(800)
    anim:SetAlphaValues(0.3, 0.9)
    anim:SetEasingFunction(ZO_EaseInOutQuadratic)
    timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
    return timeline
end
