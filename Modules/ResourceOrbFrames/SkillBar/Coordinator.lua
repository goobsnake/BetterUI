--[[
File: Modules/ResourceOrbFrames/SkillBar/Coordinator.lua
Purpose: Coordinator for the Skill Bar system. Manages overall layout orchestration and animations,
         delegating specific bar logic to sub-modules (FrontBarManager, BackBarManager, etc.).
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

-- State
local m_backBarBaseX = 0
local m_backBarBaseY = 0
local m_swapTimeline = nil

-- Helpers
local FindControl = BETTERUI.ControlUtils.FindControl
local FindOptionalControl = BETTERUI.ControlUtils.FindOptionalControl

local GetSettings = BETTERUI.ResourceOrbFrames.Utils.GetSettings

local function TraceCoordinator(event, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "skillBarCoordinator"
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.STATE or categories.LIFECYCLE, event, phase, data)
end

-- MAIN BAR & LAYOUT ORCHESTRATION

---@param rootFrame table Root ResourceOrbFrames control
local function UpdateBarPositions(rootFrame)
    TraceCoordinator("resource_orbs.skill_bar_layout", "positions_begin", { fn = "UpdateBarPositions", hasRoot = rootFrame ~= nil })
    local actionBarContainer = FindControl(rootFrame, 'ActionBarContainer')
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if not actionBarContainer or not backBarContainer or not bgMiddle then
        TraceCoordinator("resource_orbs.skill_bar_layout", "positions_skipped", {
            fn = "UpdateBarPositions",
            hasActionBar = actionBarContainer ~= nil,
            hasBackBar = backBarContainer ~= nil,
            hasBgMiddle = bgMiddle ~= nil,
        })
        return
    end

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
    TraceCoordinator("resource_orbs.skill_bar_layout", "positions_end", {
        fn = "UpdateBarPositions",
        gamepad = isGamePad,
        bottomX = bottomX,
        bottomY = bottomY,
        backBarX = m_backBarBaseX,
        backBarY = m_backBarBaseY,
    })
end

--- Updates main action bar dimensions and hides native weapon swap.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateMainBarLayout(rootFrame)
    TraceCoordinator("resource_orbs.skill_bar_layout", "main_begin", { fn = "UpdateMainBarLayout", hasRoot = rootFrame ~= nil })
    local isGamePad = IsInGamepadPreferredMode()
    local slots = isGamePad and BETTERUI_ORB_FRAMES.slots.gamepad or BETTERUI_ORB_FRAMES.slots.keyboard
    local width = slots.width
    local offset = slots.spacing
    local totalWidth = (6 * width) + (5 * offset)

    local barParent = FindControl(rootFrame, 'ActionBarContainer')
    if barParent then
        barParent:SetDimensions(totalWidth, width)
        if ZO_ActionBar1WeaponSwap then ZO_ActionBar1WeaponSwap:SetHidden(true) end
    end
    TraceCoordinator("resource_orbs.skill_bar_layout", barParent and "main_end" or "main_skipped", {
        fn = "UpdateMainBarLayout",
        gamepad = isGamePad,
        hasBarParent = barParent ~= nil,
        width = width,
        totalWidth = totalWidth,
    })
end

--- Applies the BetterUI template skin to the action bar and updates sub-bars.
---@param rootFrame table Root ResourceOrbFrames control
---@param layout table Layout config with abilitySlotOffsetX
local function ApplyActionBarSkin(rootFrame, layout)
    local isGamePad = IsInGamepadPreferredMode()
    local template = isGamePad and 'ResourceOrbFrames_Double_Gamepad' or 'ResourceOrbFrames_Double_Keyboard'
    TraceCoordinator("resource_orbs.skill_bar_skin", "begin", {
        fn = "ApplyActionBarSkin",
        template = template,
        gamepad = isGamePad,
        hasRoot = rootFrame ~= nil,
        hasLayout = layout ~= nil,
    })

    if ZO_ActionBar1WeaponSwap then
        ZO_ActionBar1WeaponSwap:SetHidden(true)
        ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1WeaponSwap, true)
    end
    if ZO_ActionBar1KeybindBG then
        ZO_ActionBar1KeybindBG:SetHidden(true)
    end

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

    -- P2 compatibility note: BetterUI intentionally reanchors this native HUD
    -- control so equipment status clears the custom action-bar layout.
    ZO_HUDEquipmentStatus:ClearAnchors()
    ZO_HUDEquipmentStatus:SetAnchor(RIGHT, GuiRoot, RIGHT, -(layout.abilitySlotOffsetX + 13), 0)

    local okTemplate, templateErr = pcall(ApplyTemplateToControl, rootFrame, template)
    if not okTemplate then
        TraceCoordinator("resource_orbs.skill_bar_skin", "template_error", {
            fn = "ApplyActionBarSkin",
            template = template,
            error = tostring(templateErr),
        })
        error(templateErr, 2)
    end

    SkillBar.UpdateBackBar(rootFrame)
    SkillBar.UpdateBackBarLayout(rootFrame)
    SkillBar.SetupBackBarTooltips(rootFrame)

    local indicator = FindOptionalControl(rootFrame, 'ActiveBarIndicator', 'ApplyActionBarSkin')
    if indicator then indicator:SetHidden(true) end
    TraceCoordinator("resource_orbs.skill_bar_skin", "end", {
        fn = "ApplyActionBarSkin",
        template = template,
        hasIndicator = indicator ~= nil,
    })
end

-- Stops an in-flight weapon-swap animation and resets both bars to their resting positions.
-- Safe to call when no animation is running (no-op).
local function StopWeaponSwapAnimation(rootFrame)
    if not (m_swapTimeline and m_swapTimeline:IsPlaying()) then
        TraceCoordinator("resource_orbs.weapon_swap", "stop_skipped", { fn = "StopWeaponSwapAnimation", reason = "notPlaying" })
        return
    end
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if not backBarContainer or not frontBarContainer or not bgMiddle then
        TraceCoordinator("resource_orbs.weapon_swap", "stop_skipped", {
            fn = "StopWeaponSwapAnimation",
            reason = "missingControls",
            hasBackBar = backBarContainer ~= nil,
            hasFrontBar = frontBarContainer ~= nil,
            hasBgMiddle = bgMiddle ~= nil,
        })
        return
    end

    m_swapTimeline:Stop()
    backBarContainer:SetAlpha(1)
    backBarContainer:ClearAnchors()
    backBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, m_backBarBaseX or 0, m_backBarBaseY or 0)
    local frontBarConst = BETTERUI_ORB_FRAMES.bars.customFrontBar
    local barOffsetX = frontBarConst and frontBarConst.offsetX or 0
    local barOffsetY = frontBarConst and frontBarConst.offsetY or 0
    frontBarContainer:SetAlpha(1)
    frontBarContainer:ClearAnchors()
    frontBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, barOffsetX + 10, -15 + barOffsetY)
    SkillBar.UpdateBackBar(rootFrame)
    SkillBar.UpdateFrontBar(rootFrame)
    TraceCoordinator("resource_orbs.weapon_swap", "stopped", { fn = "StopWeaponSwapAnimation" })
end

--- Plays the weapon-swap slide animation for front and back bars.
---@param rootFrame table Root ResourceOrbFrames control
local function WeaponSwapAnimation(rootFrame)
    local settings = GetSettings()
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    TraceCoordinator("resource_orbs.weapon_swap", "begin", {
        fn = "WeaponSwapAnimation",
        enabled = settings and settings.weaponSwapAnimation,
        hideBackBar = settings and settings.hideBackBar,
        hasBackBar = backBarContainer ~= nil,
        hasFrontBar = frontBarContainer ~= nil,
        hasBgMiddle = bgMiddle ~= nil,
    })

    if not settings.weaponSwapAnimation or settings.hideBackBar or not backBarContainer or not frontBarContainer or not bgMiddle then
        SkillBar.UpdateBackBar(rootFrame)
        SkillBar.UpdateFrontBar(rootFrame)
        TraceCoordinator("resource_orbs.weapon_swap", "skipped", {
            fn = "WeaponSwapAnimation",
            reason = not settings.weaponSwapAnimation and "settingDisabled"
                or settings.hideBackBar and "backBarHidden"
                or "missingControls",
        })
        return
    end

    if m_swapTimeline and m_swapTimeline:IsPlaying() then
        StopWeaponSwapAnimation(rootFrame)
    end

    if not m_swapTimeline then
        m_swapTimeline = ANIMATION_MANAGER:CreateTimeline()
        local SLIDE_DIST = 60
        local animationBgMiddle = bgMiddle

        local anim = m_swapTimeline:InsertAnimation(ANIMATION_CUSTOM, backBarContainer)
        anim:SetDuration(300)
        anim:SetEasingFunction(ZO_EaseInOutQuadratic)

        anim:SetUpdateFunction(function(self, progress)
            local backCtr = backBarContainer
            local frontCtr = frontBarContainer
            local bg = animationBgMiddle
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
        TraceCoordinator("resource_orbs.weapon_swap", "timeline_created", { fn = "WeaponSwapAnimation" })
    end
    m_swapTimeline:PlayFromStart()
    TraceCoordinator("resource_orbs.weapon_swap", "play", { fn = "WeaponSwapAnimation" })
end

---@return boolean isAnimating Whether a weapon swap animation is in progress
local function IsWeaponSwapAnimating()
    return m_swapTimeline and m_swapTimeline:IsPlaying()
end

-- MODULE EXPORTS
SkillBar.UpdateBarPositions = UpdateBarPositions
SkillBar.UpdateMainBarLayout = UpdateMainBarLayout
SkillBar.ApplyActionBarSkin = ApplyActionBarSkin
SkillBar.StopWeaponSwapAnimation = StopWeaponSwapAnimation
SkillBar.WeaponSwapAnimation = WeaponSwapAnimation
SkillBar.IsWeaponSwapAnimating = IsWeaponSwapAnimating
