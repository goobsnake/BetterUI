--[[
File: Modules/ResourceOrbFrames/SkillBar/Coordinator.lua
Purpose: Coordinator for the Skill Bar system. Manages overall layout orchestration and animations,
         delegating specific bar logic to sub-modules (FrontBarManager, BackBarManager, etc.).
Author: BetterUI Team
Last Modified: 2026-01-29
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
local NAME = "ResourceOrbFrames"

-- State
local m_backBarBaseX = 0
local m_backBarBaseY = 0
local m_swapTimeline = nil

-- Helpers
local function FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

-- ============================================================================
-- MAIN BAR & LAYOUT ORCHESTRATION
-- ============================================================================

local function UpdateBarPositions(rootFrame)
    local actionBarContainer = FindControl(rootFrame, 'ActionBarContainer')
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if not actionBarContainer or not backBarContainer or not bgMiddle then return end

    local isGamePad = IsInGamepadPreferredMode()
    local bars = BETTERUI_ORB_FRAMES.bars

    local shiftY = bars.shiftY
    local bottomY = (isGamePad and bars.bottom.gamepadY or bars.bottom.keyboardY) + shiftY
    local topY = (isGamePad and bars.top.gamepadY or bars.top.keyboardY) + shiftY
    local bottomX = bars.bottom.x
    local topX = bars.top.x

    local backBarCfg = bars.customBackBar
    local backBarOffsetX = (backBarCfg and backBarCfg.offsetX) or 0
    local backBarOffsetY = (backBarCfg and backBarCfg.offsetY) or 0

    m_backBarBaseX = topX + backBarOffsetX
    m_backBarBaseY = topY + backBarOffsetY

    actionBarContainer:ClearAnchors()
    backBarContainer:ClearAnchors()
    actionBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, bottomX, bottomY)
    backBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, m_backBarBaseX, m_backBarBaseY)
end

local function UpdateMainBarLayout(rootFrame)
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and { abilitySlotWidth = 67, abilitySlotOffsetX = 10 } or
        { abilitySlotWidth = 50, abilitySlotOffsetX = 2 }

    local width = layout.abilitySlotWidth
    local offset = layout.abilitySlotOffsetX
    local totalWidth = (6 * width) + (5 * offset)

    local barParent = FindControl(rootFrame, 'ActionBarContainer')
    if barParent then
        barParent:SetDimensions(totalWidth, width)
        if ZO_ActionBar1WeaponSwap then ZO_ActionBar1WeaponSwap:SetHidden(true) end
    end
end

local function ApplyActionBarSkin(rootFrame, layout)
    local isGamePad = IsInGamepadPreferredMode()
    local template = isGamePad and 'ResourceOrbFrames_Double_Gamepad' or 'ResourceOrbFrames_Double_Keyboard'

    -- TODO(fragile): ZO_ActionBar1WeaponSwap and ZO_ActionBar1KeybindBG accessed without nil guards; will crash if ESO renames these controls
    ZO_ActionBar1WeaponSwap:SetHidden(true)
    ZO_ActionBar1KeybindBG:SetHidden(true)
    ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1WeaponSwap, true)

    if not isGamePad then
        BETTERUI.ResourceOrbFrames.Tasks:Schedule("hideButtonText", 150, function()
            for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
                local btn = ZO_ActionBar_GetButton(i)
                if btn and btn.buttonText then btn.buttonText:SetHidden(true) end
            end
            local qs = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            if qs and qs.buttonText then qs.buttonText:SetHidden(true) end
        end)
    end

    ZO_HUDEquipmentStatus:ClearAnchors()
    ZO_HUDEquipmentStatus:SetAnchor(RIGHT, GuiRoot, RIGHT, -(layout.abilitySlotOffsetX + 13), 0)

    ApplyTemplateToControl(rootFrame, template)

    SkillBar.UpdateBackBar(rootFrame)
    SkillBar.UpdateBackBarLayout(rootFrame)
    SkillBar.SetupBackBarTooltips(rootFrame)

    local indicator = FindControl(rootFrame, 'ActiveBarIndicator')
    if indicator then indicator:SetHidden(true) end
end

local function WeaponSwapAnimation(rootFrame)
    local settings = GetModuleSettings()
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')

    if not settings.weaponSwapAnimation or settings.hideBackBar or not backBarContainer or not frontBarContainer or not bgMiddle then
        SkillBar.UpdateBackBar(rootFrame)
        SkillBar.UpdateFrontBar(rootFrame)
        return
    end

    if m_swapTimeline and m_swapTimeline:IsPlaying() then
        m_swapTimeline:Stop()
        SkillBar.UpdateBackBar(rootFrame)
        SkillBar.UpdateFrontBar(rootFrame)

        backBarContainer:SetAlpha(1)
        backBarContainer:ClearAnchors()
        backBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, m_backBarBaseX or 0, m_backBarBaseY or 0)

        local frontBarConst = BETTERUI_ORB_FRAMES.bars.customFrontBar
        local barOffsetX = frontBarConst and frontBarConst.offsetX or 0
        local barOffsetY = frontBarConst and frontBarConst.offsetY or 0
        frontBarContainer:SetAlpha(1)
        frontBarContainer:ClearAnchors()
        frontBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, barOffsetX + 10, -15 + barOffsetY)
    end

    if not m_swapTimeline then
        m_swapTimeline = ANIMATION_MANAGER:CreateTimeline()
        local SLIDE_DIST = 60

        local anim = m_swapTimeline:InsertAnimation(ANIMATION_CUSTOM, backBarContainer)
        anim:SetDuration(300)
        anim:SetEasingFunction(ZO_EaseInOutQuadratic)

        anim:SetUpdateFunction(function(self, progress)
            local backCtr = backBarContainer
            local frontCtr = frontBarContainer
            local bg = FindControl(rootFrame, 'BgMiddle')
            if not backCtr or not frontCtr or not bg then return end
            local frontBarConst = BETTERUI_ORB_FRAMES.bars.customFrontBar or {}
            local frontBaseX = (frontBarConst.offsetX or 0) + 10
            local frontBaseY = -15 + (frontBarConst.offsetY or 0)

            if progress < 0.5 then
                local p = progress * 2
                local alpha = 1 - p
                backCtr:SetAlpha(alpha)
                frontCtr:SetAlpha(alpha)

                local backOffset = SLIDE_DIST * p
                backCtr:ClearAnchors()
                backCtr:SetAnchor(BOTTOM, bg, BOTTOM, m_backBarBaseX, m_backBarBaseY + backOffset)

                local frontOffset = -SLIDE_DIST * p
                frontCtr:ClearAnchors()
                frontCtr:SetAnchor(BOTTOM, bg, BOTTOM, frontBaseX, frontBaseY + frontOffset)
            else
                local p = (progress - 0.5) * 2
                local alpha = p
                backCtr:SetAlpha(alpha)
                frontCtr:SetAlpha(alpha)

                local backOffset = SLIDE_DIST * (1 - p)
                backCtr:ClearAnchors()
                backCtr:SetAnchor(BOTTOM, bg, BOTTOM, m_backBarBaseX, m_backBarBaseY + backOffset)

                local frontOffset = -SLIDE_DIST * (1 - p)
                frontCtr:ClearAnchors()
                frontCtr:SetAnchor(BOTTOM, bg, BOTTOM, frontBaseX, frontBaseY + frontOffset)
            end
        end)

        m_swapTimeline:InsertCallback(function()
            SkillBar.UpdateBackBar(rootFrame)
            SkillBar.UpdateFrontBar(rootFrame)
        end, 150)
    end
    m_swapTimeline:PlayFromStart()
end

local function IsWeaponSwapAnimating()
    return m_swapTimeline and m_swapTimeline:IsPlaying()
end

-------------------------------------------------------------------------------------------------
-- MODULE EXPORTS
-------------------------------------------------------------------------------------------------
SkillBar.UpdateBarPositions = UpdateBarPositions
SkillBar.UpdateMainBarLayout = UpdateMainBarLayout
SkillBar.ApplyActionBarSkin = ApplyActionBarSkin
SkillBar.WeaponSwapAnimation = WeaponSwapAnimation
SkillBar.IsWeaponSwapAnimating = IsWeaponSwapAnimating
