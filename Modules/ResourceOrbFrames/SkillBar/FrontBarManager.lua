--[[
File: Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua
Purpose: Manages the Front Bar layout, updates, keybinds, and usability.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
local GetModuleSettings = Utils.GetModuleSettings
local ClampTextSize = Utils.ClampTextSize

local function GetNamedChildDirect(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

local function GetFrontBarButtonControl(rootFrame, frontBarContainer, buttonName)
    if buttonName == "QuickslotButton" or buttonName == "CompanionButton" then
        return GetNamedChildDirect(rootFrame, buttonName)
            or GetNamedChildDirect(frontBarContainer, buttonName)
            or FindControl(rootFrame, buttonName)
            or FindControl(frontBarContainer, buttonName)
    end

    return GetNamedChildDirect(frontBarContainer, buttonName)
        or FindControl(frontBarContainer, buttonName)
end

-- Cached control references (populated by CacheControls during addon init)
local m_buttonCache = {}        -- Cache of button controls and their children
local m_frontBarContainer = nil -- Cached reference to the front bar container
local m_quickslotBtn = nil      -- Cached reference to quickslot button
local m_companionBtn = nil      -- Cached reference to companion button
local m_bgMiddle = nil          -- Cached reference to BgMiddle control
local sharedCooldownCaches = SkillBar.SharedCooldownCaches
if not sharedCooldownCaches then
    sharedCooldownCaches = {
        effectDurationBySlotCategory = {},
        smoothedRemainBySlotCategory = {},
    }
    SkillBar.SharedCooldownCaches = sharedCooldownCaches
end
local m_effectDurationCache = sharedCooldownCaches.effectDurationBySlotCategory
local m_cooldownVisualState = sharedCooldownCaches.smoothedRemainBySlotCategory

local SKILL_TEXT_SIZE_MIN = 12
local SKILL_TEXT_SIZE_MAX = 30
local TARGET_FAILURE_CAST_HOLD_MS = 200
local NON_COST_FAILURE_CAST_HOLD_MS = 250
local PRESS_FEEDBACK_DEDUPE_WINDOW_MS = 140
-- ESOUI ActionButton glow pulse is effectively ~167ms (500ms * 1/3).
local PRESS_FEEDBACK_EDGE_FLASH_MS = 167
local PRESS_FEEDBACK_EDGE_FLASH_ALPHA = 0.95
local BOUNCE_SHRINK_SCALE = 0.9
local BOUNCE_ICON_SHRINK_SCALE = 0.8
local BOUNCE_GROW_SCALE = 1.1
local BOUNCE_FRAME_RESET_TIME_MS = 167
local BOUNCE_ICON_RESET_TIME_MS = 100
local m_targetFailureLastSeenMsBySlotCategory = {}
local m_nonCostFailureLastSeenMsBySlotCategory = {}
local m_pressFeedbackHooksInstalled = false
local m_pressFeedbackRootFrame = nil
local m_pressFeedbackLastPlayedMsByButton = {}

local function BuildCooldownStateKey(slotIndex, hotbarCategory)
    return string.format("%d_%d", slotIndex or -1, hotbarCategory or -1)
end

local function GetQuickslotCountAnchorOffsets()
    local keybindOffsetX = BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_X or 0
    local keybindOffsetY = BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_Y or -2
    local buttonOffsetX = BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_X or 0
    local buttonOffsetY = BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_Y or 1
    return keybindOffsetX, keybindOffsetY, buttonOffsetX, buttonOffsetY
end


local function ResolvePressFeedbackButtonName(slotIndex, hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        return "QuickslotButton"
    end

    if hotbarCategory == HOTBAR_CATEGORY_COMPANION then
        return "CompanionButton"
    end

    local ultimateSlot = ACTION_BAR_ULTIMATE_SLOT_INDEX and (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or 8
    if slotIndex == ultimateSlot then
        return "UltimateButton"
    end

    local numericSlot = tonumber(slotIndex)
    if numericSlot and numericSlot >= 3 and numericSlot <= 7 then
        return "Button" .. tostring(numericSlot - 2)
    end

    if numericSlot and numericSlot == GetCurrentQuickslot() then
        return "QuickslotButton"
    end

    return nil
end

local function ConfigureBounceTimelineSize(timeline, width, height, shrinkScale, resetDurationMs)
    if not timeline then
        return
    end

    local shrink = timeline:GetAnimation(1)
    local grow = timeline:GetAnimation(2)
    local reset = timeline:GetAnimation(3)
    if not shrink or not grow or not reset then
        return
    end

    shrink:SetStartAndEndWidth(width, width * shrinkScale)
    shrink:SetStartAndEndHeight(height, height * shrinkScale)

    grow:SetStartAndEndWidth(width * shrinkScale, width * BOUNCE_GROW_SCALE)
    grow:SetStartAndEndHeight(height * shrinkScale, height * BOUNCE_GROW_SCALE)

    reset:SetStartAndEndWidth(width * BOUNCE_GROW_SCALE, width)
    reset:SetStartAndEndHeight(height * BOUNCE_GROW_SCALE, height)
    reset:SetDuration(resetDurationMs)
end

local function SetPressFeedbackBaseSize(buttonControl, frameWidth, frameHeight, iconWidth, iconHeight)
    if not buttonControl then
        return
    end

    buttonControl.betterUIPressFeedbackBaseFrameWidth = frameWidth
    buttonControl.betterUIPressFeedbackBaseFrameHeight = frameHeight
    buttonControl.betterUIPressFeedbackBaseIconWidth = iconWidth
    buttonControl.betterUIPressFeedbackBaseIconHeight = iconHeight
end

local function EnsurePressFeedbackState(buttonControl, children)
    if not buttonControl then
        return nil
    end

    local state = buttonControl.betterUIPressFeedback
    if not state then
        state = {}
        buttonControl.betterUIPressFeedback = state
    end

    state.flipCard = (children and children.FlipCard) or buttonControl:GetNamedChild("FlipCard")
    state.icon = (children and children.Icon) or buttonControl:GetNamedChild("Icon")
    state.pressHighlight = (children and children.PressHighlight) or buttonControl:GetNamedChild("PressHighlight")

    if state.flipCard and not state.bounceAnimation then
        state.bounceAnimation = ANIMATION_MANAGER:CreateTimelineFromVirtual("ActionSlotBounceAnimation", state.flipCard)
    end
    if state.icon and not state.iconBounceAnimation then
        state.iconBounceAnimation = ANIMATION_MANAGER:CreateTimelineFromVirtual("ActionSlotBounceAnimation", state.icon)
    end
    if state.pressHighlight and not state.pressHighlightAnimation then
        state.pressHighlightAnimation = ZO_AlphaAnimation:New(state.pressHighlight)
    end

    local frameWidth = tonumber(buttonControl.betterUIPressFeedbackBaseFrameWidth)
    local frameHeight = tonumber(buttonControl.betterUIPressFeedbackBaseFrameHeight)
    if (not frameWidth or frameWidth <= 0) and state.lastFrameWidth and state.lastFrameWidth > 0 then
        frameWidth = state.lastFrameWidth
    end
    if (not frameHeight or frameHeight <= 0) and state.lastFrameHeight and state.lastFrameHeight > 0 then
        frameHeight = state.lastFrameHeight
    end
    if (not frameWidth or frameWidth <= 0) and state.flipCard and state.flipCard.GetDimensions then
        frameWidth = select(1, state.flipCard:GetDimensions())
    end
    if (not frameHeight or frameHeight <= 0) and state.flipCard and state.flipCard.GetDimensions then
        frameHeight = select(2, state.flipCard:GetDimensions())
    end
    if (not frameWidth or frameWidth <= 0) or (not frameHeight or frameHeight <= 0) then
        frameWidth, frameHeight = buttonControl:GetDimensions()
    end
    frameWidth = (frameWidth and frameWidth > 0) and frameWidth or (ZO_GAMEPAD_ACTION_BUTTON_SIZE or 64)
    frameHeight = (frameHeight and frameHeight > 0) and frameHeight or frameWidth
    local isFrameBouncePlaying = state.bounceAnimation and state.bounceAnimation.IsPlaying and state.bounceAnimation:IsPlaying()
    if (not isFrameBouncePlaying) and (state.lastFrameWidth ~= frameWidth or state.lastFrameHeight ~= frameHeight) then
        ConfigureBounceTimelineSize(state.bounceAnimation, frameWidth, frameHeight, BOUNCE_SHRINK_SCALE,
            BOUNCE_FRAME_RESET_TIME_MS)
        state.lastFrameWidth = frameWidth
        state.lastFrameHeight = frameHeight
    end
    state.resolvedFrameWidth = frameWidth
    state.resolvedFrameHeight = frameHeight

    local iconWidth = tonumber(buttonControl.betterUIPressFeedbackBaseIconWidth)
    local iconHeight = tonumber(buttonControl.betterUIPressFeedbackBaseIconHeight)
    if (not iconWidth or iconWidth <= 0) and state.lastIconWidth and state.lastIconWidth > 0 then
        iconWidth = state.lastIconWidth
    end
    if (not iconHeight or iconHeight <= 0) and state.lastIconHeight and state.lastIconHeight > 0 then
        iconHeight = state.lastIconHeight
    end
    if (not iconWidth or iconWidth <= 0) and state.icon and state.icon.GetDimensions then
        iconWidth = select(1, state.icon:GetDimensions())
    end
    if (not iconHeight or iconHeight <= 0) and state.icon and state.icon.GetDimensions then
        iconHeight = select(2, state.icon:GetDimensions())
    end
    if (not iconWidth or iconWidth <= 0) or (not iconHeight or iconHeight <= 0) then
        iconWidth = frameWidth
        iconHeight = frameHeight
    end
    local isIconBouncePlaying = state.iconBounceAnimation and state.iconBounceAnimation.IsPlaying and
        state.iconBounceAnimation:IsPlaying()
    if (not isIconBouncePlaying) and (state.lastIconWidth ~= iconWidth or state.lastIconHeight ~= iconHeight) then
        ConfigureBounceTimelineSize(state.iconBounceAnimation, iconWidth, iconHeight, BOUNCE_ICON_SHRINK_SCALE,
            BOUNCE_ICON_RESET_TIME_MS)
        state.lastIconWidth = iconWidth
        state.lastIconHeight = iconHeight
    end
    state.resolvedIconWidth = iconWidth
    state.resolvedIconHeight = iconHeight

    return state
end

local function PlayButtonPressFeedback(buttonControl, children, buttonName)
    if not buttonControl then
        return
    end

    local nowMs = GetGameTimeMilliseconds()
    local lastPlayedMs = m_pressFeedbackLastPlayedMsByButton[buttonName]
    if lastPlayedMs and (nowMs - lastPlayedMs) <= PRESS_FEEDBACK_DEDUPE_WINDOW_MS then
        return
    end
    m_pressFeedbackLastPlayedMsByButton[buttonName] = nowMs

    local state = EnsurePressFeedbackState(buttonControl, children)
    if not state then
        return
    end

    if state.flipCard and state.resolvedFrameWidth and state.resolvedFrameHeight then
        state.flipCard:SetDimensions(state.resolvedFrameWidth, state.resolvedFrameHeight)
    end
    if state.icon and state.resolvedIconWidth and state.resolvedIconHeight then
        state.icon:SetDimensions(state.resolvedIconWidth, state.resolvedIconHeight)
    end

    if state.bounceAnimation and (not state.bounceAnimation:IsPlaying()) then
        state.bounceAnimation:PlayFromStart()
    end
    if state.iconBounceAnimation and (not state.iconBounceAnimation:IsPlaying()) then
        state.iconBounceAnimation:PlayFromStart()
    end

    local pressHighlight = state.pressHighlight
    local pressHighlightAnimation = state.pressHighlightAnimation
    if pressHighlight and pressHighlightAnimation then
        pressHighlightAnimation:Stop()
        pressHighlight:SetAlpha(0)
        pressHighlight:SetHidden(false)
        pressHighlightAnimation:PingPong(0, PRESS_FEEDBACK_EDGE_FLASH_ALPHA, PRESS_FEEDBACK_EDGE_FLASH_MS, 1, function()
            if pressHighlight and pressHighlight.SetHidden then
                pressHighlight:SetHidden(true)
                pressHighlight:SetAlpha(0)
            end
        end)
    end
end

local function GetNativeActionBarUsableState(slotIndex, hotbarCategory)
    if type(slotIndex) ~= "number" or type(hotbarCategory) ~= "number" then
        return nil
    end
    if type(ZO_ActionBar_GetButton) ~= "function" then
        return nil
    end

    local nativeButton = ZO_ActionBar_GetButton(slotIndex, hotbarCategory)
    if not nativeButton then
        return nil
    end

    if nativeButton.usable ~= nil then
        return nativeButton.usable
    end

    return nil
end

local function HasFallbackPressUseFailure(slotIndex, hotbarCategory)
    if type(slotIndex) ~= "number" or type(hotbarCategory) ~= "number" then
        return true
    end

    local slotType = GetSlotType(slotIndex, hotbarCategory)
    if slotType == ACTION_TYPE_NOTHING then
        return true
    end

    local hasItemCountFailure = false
    if slotType == ACTION_TYPE_ITEM then
        hasItemCountFailure = (GetSlotItemCount(slotIndex, hotbarCategory) or 0) <= 0
    end

    local hasCostFailure = ActionSlotHasCostFailure and ActionSlotHasCostFailure(slotIndex, hotbarCategory) or false
    local hasStateFailure = ActionSlotHasNonCostStateFailure and ActionSlotHasNonCostStateFailure(slotIndex, hotbarCategory)
        or false
    local hasTargetFailure = ActionSlotHasTargetFailure and ActionSlotHasTargetFailure(slotIndex, hotbarCategory) or false
    local hasRangeFailure = ActionSlotHasRangeFailure and ActionSlotHasRangeFailure(slotIndex, hotbarCategory) or false

    local hasInsufficientUltimate = false
    local ultimateSlot = ACTION_BAR_ULTIMATE_SLOT_INDEX and (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or nil
    if ultimateSlot and slotIndex == ultimateSlot then
        local requiredUltimate = GetSlotAbilityCost(slotIndex, hotbarCategory)
        local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
        hasInsufficientUltimate = type(requiredUltimate) == "number" and requiredUltimate > 0 and
            type(currentUltimate) == "number" and currentUltimate < requiredUltimate
    end

    return hasItemCountFailure or hasCostFailure or hasStateFailure or hasTargetFailure or hasRangeFailure or
        hasInsufficientUltimate
end

local function PlayFrontBarPressFeedbackForSlot(rootFrame, slotIndex, hotbarCategory, bypassUsableGate)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then
        return
    end

    local resolvedRootFrame = rootFrame or m_pressFeedbackRootFrame
    if not resolvedRootFrame then
        return
    end

    if not m_frontBarContainer or m_frontBarContainer:IsHidden() then
        m_frontBarContainer = FindControl(resolvedRootFrame, 'FrontBarContainer')
    end

    local activeCategory = GetActiveHotbarCategory()
    local resolvedCategory = hotbarCategory or activeCategory
    local isPrimaryCategory = resolvedCategory == activeCategory
    local isQuickslot = resolvedCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    local isCompanion = resolvedCategory == HOTBAR_CATEGORY_COMPANION
    if not (isPrimaryCategory or isQuickslot or isCompanion) then
        return
    end

    local buttonName = ResolvePressFeedbackButtonName(slotIndex, resolvedCategory)
    if not buttonName then
        return
    end

    if not bypassUsableGate then
        local nativeUsable = GetNativeActionBarUsableState(slotIndex, resolvedCategory)
        if nativeUsable == false then
            return
        end

        if HasFallbackPressUseFailure(slotIndex, resolvedCategory) then
            return
        end
    end

    local frontBarContainer = m_frontBarContainer or FindControl(resolvedRootFrame, 'FrontBarContainer')
    local buttonControl = GetFrontBarButtonControl(resolvedRootFrame, frontBarContainer, buttonName)
    if not buttonControl or buttonControl:IsHidden() then
        return
    end

    local cachedButton = m_buttonCache and m_buttonCache[buttonName] or nil
    local children = cachedButton and cachedButton.children or nil
    local iconControl = (children and children.Icon) or buttonControl:GetNamedChild("Icon")
    if iconControl and iconControl:IsHidden() then
        return
    end
    if not bypassUsableGate then
        local unusableOverlay = (children and children.UnusableOverlay) or buttonControl:GetNamedChild("UnusableOverlay")
        if unusableOverlay and not unusableOverlay:IsHidden() then
            return
        end
    end

    PlayButtonPressFeedback(buttonControl, children, buttonName)
end

local function SetupFrontBarPressFeedbackHooks(rootFrame)
    m_pressFeedbackRootFrame = rootFrame or m_pressFeedbackRootFrame

    if m_pressFeedbackHooksInstalled then
        return
    end

    if type(ZO_PreHook) ~= "function" then
        return
    end

    ZO_PreHook("ZO_ActionBar_OnActionButtonUp", function(slotNum, hotbarCategory)
        PlayFrontBarPressFeedbackForSlot(m_pressFeedbackRootFrame, slotNum, hotbarCategory)
    end)

    m_pressFeedbackHooksInstalled = true
end

local function GetTargetOrRangeFailure(slotIndex, hotbarCategory)
    local hasTargetFailure = ActionSlotHasTargetFailure and ActionSlotHasTargetFailure(slotIndex, hotbarCategory) or false
    local hasRangeFailure = ActionSlotHasRangeFailure and ActionSlotHasRangeFailure(slotIndex, hotbarCategory) or false
    return hasTargetFailure or hasRangeFailure
end

local function ResolveTargetFailureWithCastLatch(slotStateKey, hasTargetOrRangeFailure, isCasting, nowMs)
    if hasTargetOrRangeFailure then
        m_targetFailureLastSeenMsBySlotCategory[slotStateKey] = nowMs
        return true
    end

    local lastSeenMs = m_targetFailureLastSeenMsBySlotCategory[slotStateKey]
    if isCasting and lastSeenMs and (nowMs - lastSeenMs) <= TARGET_FAILURE_CAST_HOLD_MS then
        return true
    end

    m_targetFailureLastSeenMsBySlotCategory[slotStateKey] = nil
    return false
end

local function ResolveNonCostFailureWithCastLatch(slotStateKey, hasStateFailure, isCasting, nowMs)
    if hasStateFailure then
        m_nonCostFailureLastSeenMsBySlotCategory[slotStateKey] = nowMs
        return true
    end

    local lastSeenMs = m_nonCostFailureLastSeenMsBySlotCategory[slotStateKey]
    if isCasting and lastSeenMs and (nowMs - lastSeenMs) <= NON_COST_FAILURE_CAST_HOLD_MS then
        return true
    end

    m_nonCostFailureLastSeenMsBySlotCategory[slotStateKey] = nil
    return false
end

local function HasInsufficientUltimate(slotIndex, hotbarCategory)
    local ultimateSlotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX and (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or nil
    if slotIndex ~= ultimateSlotIndex then
        return false
    end

    local abilityCost = GetSlotAbilityCost(slotIndex, hotbarCategory)
    if type(abilityCost) ~= "number" or abilityCost <= 0 then
        return false
    end

    local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
    if type(currentUltimate) ~= "number" then
        return false
    end

    return currentUltimate < abilityCost
end

local function ShouldSuppressUnusableOverlayForCooldown(slotIndex, hotbarCategory)
    local remainMs, durationMs, isGlobalCooldown = GetSlotCooldownInfo(slotIndex, hotbarCategory)
    if remainMs and remainMs > 0 and durationMs and durationMs > 1500 and not isGlobalCooldown then
        return true
    end

    local effectRemaining = GetActionSlotEffectTimeRemaining(slotIndex, hotbarCategory)
    return effectRemaining and effectRemaining > 0
end

--[[
Function: CacheFrontBarControls
Description: Caches all front bar control references for performance.
Rationale: Avoids repeated GetNamedChild/FindControl lookups in hot paths (frame updates, cooldowns).
Mechanism: Uses CIM.ControlCache.CacheButtonChildren for each button.
References: Called during addon initialization after controls are created.
param: rootFrame (control) - The root ResourceOrbFrames control
]]
local function CacheFrontBarControls(rootFrame)
    if not rootFrame then return end

    m_frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not m_frontBarContainer then return end

    m_bgMiddle = FindControl(rootFrame, 'BgMiddle')

    -- Cache all button controls and their children
    local CONST = SkillBar.CONST
    for _, mapping in ipairs(CONST.FRONT_BAR_SLOTS) do
        local btn = FindControl(m_frontBarContainer, mapping.buttonName)
        if btn then
            m_buttonCache[mapping.buttonName] = {
                control = btn,
                children = BETTERUI.CIM.ControlCache.CacheButtonChildren(btn),
            }
        end
    end

    -- Cache quickslot and companion buttons
    m_quickslotBtn = FindControl(m_frontBarContainer, 'QuickslotButton') or FindControl(rootFrame, 'QuickslotButton')
    if m_quickslotBtn then
        m_buttonCache["QuickslotButton"] = {
            control = m_quickslotBtn,
            children = BETTERUI.CIM.ControlCache.CacheButtonChildren(m_quickslotBtn),
        }
    end

    m_companionBtn = FindControl(m_frontBarContainer, 'CompanionButton') or FindControl(rootFrame, 'CompanionButton')
    if m_companionBtn then
        m_buttonCache["CompanionButton"] = {
            control = m_companionBtn,
            children = BETTERUI.CIM.ControlCache.CacheButtonChildren(m_companionBtn),
        }
    end
end

--- Helper to get cached button and its children
local function GetCachedButton(buttonName)
    return m_buttonCache[buttonName]
end

local function AnchorQuickslotCountText(buttonControl, countText)
    if not buttonControl then
        return
    end

    local label = countText or buttonControl:GetNamedChild("CountText")
    if not label then
        return
    end

    local buttonText = buttonControl:GetNamedChild("ButtonText")
    local keybindOffsetX, keybindOffsetY, buttonOffsetX, buttonOffsetY = GetQuickslotCountAnchorOffsets()
    label:ClearAnchors()
    if buttonText then
        -- Keep count below the LB/RB glyph text block so numbers do not clip into the keybind icon.
        label:SetAnchor(TOP, buttonText, BOTTOM, keybindOffsetX, keybindOffsetY)
    else
        label:SetAnchor(TOP, buttonControl, BOTTOM, buttonOffsetX, buttonOffsetY)
    end
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
end

local function UpdateQuickslotCountAndEmptyState(buttonControl, children, settings, slotIndex, hotbarCategory)
    if not buttonControl then
        return false
    end

    local slotType = GetSlotType(slotIndex, hotbarCategory)
    local isItemSlot = slotType == ACTION_TYPE_ITEM
    local count = nil
    if isItemSlot then
        count = GetSlotItemCount(slotIndex, hotbarCategory) or 0
    end

    local showCount = settings.showQuickslotCount ~= false
    local quickslotTextSize = ClampTextSize(settings.quickslotTextSize, SKILL_TEXT_SIZE_MIN, SKILL_TEXT_SIZE_MAX, 27)
    local quickslotTextColor = settings.quickslotTextColor or { 1, 1, 1, 1 }
    local countText = (children and children.CountText) or buttonControl:GetNamedChild("CountText")
    if countText then
        countText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", quickslotTextSize))
        countText:SetColor(unpack(quickslotTextColor))
        AnchorQuickslotCountText(buttonControl, countText)
        if showCount and isItemSlot and count ~= nil then
            countText:SetText(count)
            countText:SetHidden(false)
        else
            countText:SetHidden(true)
        end
    end

    local isEmpty = isItemSlot and (count or 0) <= 0
    local unusableOverlay = (children and children.UnusableOverlay) or buttonControl:GetNamedChild("UnusableOverlay")
    if unusableOverlay then
        unusableOverlay:SetHidden(not isEmpty)
    end

    buttonControl.quickslotCount = count
    buttonControl.quickslotEmpty = isEmpty
    return isEmpty
end

local function ResetSmoothedCooldownRemaining(stateKey)
    if stateKey then
        m_cooldownVisualState[stateKey] = nil
    end
end

local function GetSmoothedCooldownRemaining(stateKey, remainMs, durationMs)
    if not stateKey or not remainMs or remainMs <= 0 or not durationMs or durationMs <= 0 then
        return remainMs
    end

    local nowMs = GetGameTimeMilliseconds()
    local state = m_cooldownVisualState[stateKey]
    if not state
        or state.durationMs ~= durationMs
        or remainMs > ((state.lastReportedRemainMs or remainMs) + 100) then
        m_cooldownVisualState[stateKey] = {
            durationMs = durationMs,
            lastReportedRemainMs = remainMs,
            smoothedRemainMs = remainMs,
            lastUpdateMs = nowMs,
        }
        return remainMs
    end

    local elapsedMs = nowMs - (state.lastUpdateMs or nowMs)
    if elapsedMs < 0 then
        elapsedMs = 0
    end

    local smoothedRemainMs = (state.smoothedRemainMs or remainMs) - elapsedMs
    if smoothedRemainMs < 0 then
        smoothedRemainMs = 0
    end
    if smoothedRemainMs > remainMs then
        smoothedRemainMs = remainMs
    end

    state.lastReportedRemainMs = remainMs
    state.smoothedRemainMs = smoothedRemainMs
    state.lastUpdateMs = nowMs
    return smoothedRemainMs
end

local function ApplyLinearCooldownVisuals(cooldownEdge, cooldownOverlay, revealControl, remainMs, durationMs)
    if not cooldownEdge or not revealControl or not remainMs or not durationMs or durationMs <= 0 then
        if cooldownEdge then cooldownEdge:SetHidden(true) end
        if cooldownOverlay then cooldownOverlay:SetHidden(true) end
        return nil
    end

    local revealWidth = revealControl.cooldownRevealWidth
    local revealHeight = revealControl.cooldownRevealHeight
    if not revealWidth or not revealHeight then
        revealWidth, revealHeight = revealControl:GetDimensions()
    end
    if revealWidth <= 0 or revealHeight <= 0 then
        if cooldownEdge then cooldownEdge:SetHidden(true) end
        if cooldownOverlay then cooldownOverlay:SetHidden(true) end
        return nil
    end

    if cooldownOverlay then
        cooldownOverlay:SetHidden(true)
    end

    local percentComplete = 1 - (remainMs / durationMs)
    if percentComplete < 0 then percentComplete = 0 end
    if percentComplete > 1 then percentComplete = 1 end

    local edgeOffsetY = (1 - percentComplete) * revealHeight

    cooldownEdge:ClearAnchors()
    cooldownEdge:SetAnchor(TOPLEFT, revealControl, TOPLEFT, 0, edgeOffsetY)
    cooldownEdge:SetWidth(revealWidth)
    cooldownEdge:SetHidden(false)
    cooldownEdge:SetDrawLayer(DL_OVERLAY)
    cooldownEdge:SetDrawTier(DT_LOW)
    cooldownEdge:SetDrawLevel(1)

    if cooldownOverlay then
        local unrevealedHeight = (1 - percentComplete) * revealHeight
        cooldownOverlay:ClearAnchors()
        cooldownOverlay:SetAnchor(TOPLEFT, revealControl, TOPLEFT, 0, 0)
        cooldownOverlay:SetDimensions(revealWidth, unrevealedHeight)
        cooldownOverlay:SetHidden(false)
        cooldownOverlay:SetDrawLayer(DL_OVERLAY)
        cooldownOverlay:SetDrawTier(DT_LOW)
        cooldownOverlay:SetDrawLevel(0)
    end

    return percentComplete
end

local function HideNativeActionBar()
    if ZO_ActionBar1 and ZO_ActionBar1.SetHidden then
        ZO_ActionBar1:SetHidden(true)
        if ZO_ActionBar1.SetAlpha then ZO_ActionBar1:SetAlpha(0) end
    end
    if ZO_ActionBarTimer and ZO_ActionBarTimer.SetHidden then
        ZO_ActionBarTimer:SetHidden(true)
    end
end

local function UpdateFrontBar(rootFrame)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end

    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    -- TODO(refactor): Use SkillBar.CONST.FRONT_BAR_SLOTS instead of duplicating slot mapping arrays
    local slotMapping = {
        { buttonName = "Button1",        slot = 3 },
        { buttonName = "Button2",        slot = 4 },
        { buttonName = "Button3",        slot = 5 },
        { buttonName = "Button4",        slot = 6 },
        { buttonName = "Button5",        slot = 7 },
        { buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 },
    }

    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            local iconControl = btn:GetNamedChild("Icon")
            local slotTexture = GetSlotTexture(mapping.slot, activeCategory)

            if iconControl then
                if slotTexture and slotTexture ~= "" then
                    iconControl:SetTexture(slotTexture)
                    iconControl:SetHidden(false)
                else
                    iconControl:SetHidden(true)
                end
            end

            btn.slotIndex = mapping.slot
            btn.hotbarCategory = activeCategory

            local highlight = btn:GetNamedChild("ActivationHighlight")
            if highlight then
                local hasHighlight = ActionSlotHasActivationHighlight(mapping.slot, activeCategory)
                local hasCostFailure = ActionSlotHasCostFailure(mapping.slot, activeCategory)
                local hasStateFailure = ActionSlotHasNonCostStateFailure(mapping.slot, activeCategory)
                local isUsable = not hasCostFailure and not hasStateFailure
                highlight:SetHidden(not (hasHighlight and isUsable))
            end
        end
    end
    frontBarContainer:SetHidden(false)
end

local function UpdateFrontBarUsability(rootFrame, isCasting)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end

    local activeCategory = GetActiveHotbarCategory()
    local nowMs = GetGameTimeMilliseconds()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local slotMapping = {
        { buttonName = "Button1",        slot = 3 },
        { buttonName = "Button2",        slot = 4 },
        { buttonName = "Button3",        slot = 5 },
        { buttonName = "Button4",        slot = 6 },
        { buttonName = "Button5",        slot = 7 },
        { buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 },
    }

    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            local iconControl = btn:GetNamedChild("Icon")
            local unusableOverlay = btn:GetNamedChild("UnusableOverlay")

            if iconControl and not iconControl:IsHidden() then
                local slotStateKey = BuildCooldownStateKey(mapping.slot, activeCategory)
                local hasCostFailure = ActionSlotHasCostFailure(mapping.slot, activeCategory)
                local hasStateFailure = ActionSlotHasNonCostStateFailure(mapping.slot, activeCategory)
                local hasLatchedStateFailure = ResolveNonCostFailureWithCastLatch(slotStateKey, hasStateFailure,
                    isCasting, nowMs)
                local hasTargetOrRangeFailure = GetTargetOrRangeFailure(mapping.slot, activeCategory)
                local hasLatchedTargetFailure = ResolveTargetFailureWithCastLatch(slotStateKey, hasTargetOrRangeFailure,
                    isCasting, nowMs)
                local hasInsufficientUltimate = HasInsufficientUltimate(mapping.slot, activeCategory)
                local unusable = hasCostFailure or hasLatchedStateFailure or hasLatchedTargetFailure or
                    hasInsufficientUltimate

                local hasActiveCooldown = ShouldSuppressUnusableOverlayForCooldown(mapping.slot, activeCategory)

                if unusableOverlay then
                    unusableOverlay:SetHidden(not (unusable and not hasActiveCooldown))
                end
            end
        end
    end
end

local function SetupFrontBarTooltips(rootFrame)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local slotMapping = {
        { buttonName = "Button1",        slot = 3 },
        { buttonName = "Button2",        slot = 4 },
        { buttonName = "Button3",        slot = 5 },
        { buttonName = "Button4",        slot = 6 },
        { buttonName = "Button5",        slot = 7 },
        { buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 },
    }

    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            SkillBar.SetupButtonTooltip(btn, mapping.slot, nil, RIGHT, -5, 0)
        end
    end
end

local function SetupFrontBarKeybinds(rootFrame)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end

    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local HIDE_UNBOUND = false
    local slotBindings = {
        [1] = { keyboard = "ACTION_BUTTON_3", gamepad = "GAMEPAD_ACTION_BUTTON_3" },
        [2] = { keyboard = "ACTION_BUTTON_4", gamepad = "GAMEPAD_ACTION_BUTTON_4" },
        [3] = { keyboard = "ACTION_BUTTON_5", gamepad = "GAMEPAD_ACTION_BUTTON_5" },
        [4] = { keyboard = "ACTION_BUTTON_6", gamepad = "GAMEPAD_ACTION_BUTTON_6" },
        [5] = { keyboard = "ACTION_BUTTON_7", gamepad = "GAMEPAD_ACTION_BUTTON_7" },
    }

    for i = 1, 5 do
        local btn = FindControl(frontBarContainer, 'Button' .. i)
        if btn then
            local buttonText = btn:GetNamedChild("ButtonText")
            if buttonText then
                local bindings = slotBindings[i]
                ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, bindings.keyboard, HIDE_UNBOUND,
                    bindings.gamepad)
            end
        end
    end

    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local buttonText = ultBtn:GetNamedChild("ButtonText")
        if buttonText then
            ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, "ACTION_BUTTON_8", HIDE_UNBOUND,
                "GAMEPAD_ACTION_BUTTON_8")
        end
        local isGamepad = IsInGamepadPreferredMode()
        local l = ultBtn:GetNamedChild("LeftKeybind")
        local r = ultBtn:GetNamedChild("RightKeybind")
        if l then l:SetHidden(not isGamepad) end
        if r then r:SetHidden(not isGamepad) end
    end

    local qsBtn = GetFrontBarButtonControl(rootFrame, frontBarContainer, "QuickslotButton")
    if qsBtn then
        local buttonText = qsBtn:GetNamedChild("ButtonText")
        if buttonText then
            ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, "ACTION_BUTTON_9", HIDE_UNBOUND,
                "GAMEPAD_ACTION_BUTTON_9")
        end
        local countText = qsBtn:GetNamedChild("CountText")
        if countText then
            AnchorQuickslotCountText(qsBtn, countText)
        end

        local timerText = qsBtn:GetNamedChild("TimerText")
        if timerText then
            timerText:ClearAnchors()
            timerText:SetAnchor(CENTER, qsBtn, CENTER, 0, 4)
        end
        local cdText = qsBtn:GetNamedChild("CooldownText")
        if cdText then
            cdText:ClearAnchors()
            cdText:SetAnchor(CENTER, qsBtn, CENTER, 0, 0)
        end
    end

    local compBtn = GetFrontBarButtonControl(rootFrame, frontBarContainer, "CompanionButton")
    if compBtn then
        local buttonText = compBtn:GetNamedChild("ButtonText")
        if buttonText then
            ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, "COMMAND_PET", HIDE_UNBOUND, "COMMAND_PET")
        end
        local isGamepad = IsInGamepadPreferredMode()
        local l = compBtn:GetNamedChild("LeftKeybind")
        local r = compBtn:GetNamedChild("RightKeybind")
        if l then l:SetHidden(not isGamepad) end
        if r then r:SetHidden(not isGamepad) end
    end
end

local function UpdateFrontBarLayout(rootFrame)
    -- Check if feature is m_enabled (from settings), but get LAYOUT from constants
    local settingsCfg = GetModuleSettings().customFrontBar
    if not settingsCfg or not settingsCfg.m_enabled then return end

    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg then return end

    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local isGamePad = IsInGamepadPreferredMode()
    local slotsConfig = isGamePad and BETTERUI_ORB_FRAMES.slots.gamepad or BETTERUI_ORB_FRAMES.slots.keyboard
    local modeConfig = isGamePad and frontBarCfg.gamepad or frontBarCfg.keyboard

    local buttonSize = modeConfig.buttonSize or slotsConfig.width
    local spacing = modeConfig.spacing or slotsConfig.spacing
    local ultimateSize = modeConfig.ultimateSize or (buttonSize + 6)
    local ultimateGap = BETTERUI_ORB_FRAMES.bars.ultimateGap

    local totalWidth = (5 * buttonSize) + (4 * spacing) + ultimateGap + ultimateSize
    local halfWidth = totalWidth / 2

    frontBarContainer:SetDimensions(totalWidth, ultimateSize)

    for i = 1, 5 do
        local btn = FindControl(frontBarContainer, 'Button' .. i)
        if btn then
            btn:SetDimensions(buttonSize, buttonSize)
            btn.cooldownRevealWidth = buttonSize
            btn.cooldownRevealHeight = buttonSize
            btn:ClearAnchors()
            if i == 1 then
                btn:SetAnchor(LEFT, frontBarContainer, CENTER, -halfWidth, 0)
            else
                local prevBtn = FindControl(frontBarContainer, 'Button' .. (i - 1))
                btn:SetAnchor(LEFT, prevBtn, RIGHT, spacing, 0)
            end

            local flipCard = btn:GetNamedChild("FlipCard")
            if flipCard then flipCard:SetDimensions(buttonSize - 3, buttonSize - 3) end
            local icon = btn:GetNamedChild("Icon")
            if icon then icon:SetDimensions(buttonSize - 3, buttonSize - 3) end
            SetPressFeedbackBaseSize(btn, buttonSize - 3, buttonSize - 3, buttonSize - 3, buttonSize - 3)
        end
    end

    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local btn5 = FindControl(frontBarContainer, 'Button5')
        local ultOffsetX = frontBarCfg.ultimate.offsetX or 0
        local ultOffsetY = frontBarCfg.ultimate.offsetY or 0

        ultBtn:SetDimensions(ultimateSize, ultimateSize)
        ultBtn.cooldownRevealWidth = ultimateSize
        ultBtn.cooldownRevealHeight = ultimateSize
        ultBtn:ClearAnchors()
        ultBtn:SetAnchor(LEFT, btn5, RIGHT, ultimateGap + ultOffsetX, ultOffsetY)

        -- Store references for easy access
        ultBtn.readyBurst = ultBtn:GetNamedChild("ReadyBurst")
        ultBtn.readyLoop = ultBtn:GetNamedChild("ReadyLoop")
        ultBtn.glow = ultBtn:GetNamedChild("Glow")
        if ultBtn.glow then
            ultBtn.glowAnimation = ZO_AlphaAnimation:New(ultBtn.glow)
            ultBtn.glowAnimation:SetMinMaxAlpha(0, 1)
        end

        local flipCard = ultBtn:GetNamedChild("FlipCard")
        if flipCard then flipCard:SetDimensions(ultimateSize - 3, ultimateSize - 3) end
        local icon = ultBtn:GetNamedChild("Icon")
        if icon then icon:SetDimensions(ultimateSize - 3, ultimateSize - 3) end
        SetPressFeedbackBaseSize(ultBtn, ultimateSize - 3, ultimateSize - 3, ultimateSize - 3, ultimateSize - 3)
    end

    local qsBtn = GetFrontBarButtonControl(rootFrame, frontBarContainer, "QuickslotButton")
    if qsBtn then
        local quickslotCfg = frontBarCfg.quickslotButton
        local baseX = BETTERUI_ORB_FRAMES.bars.quickslot.x
        local baseY = BETTERUI_ORB_FRAMES.bars.quickslot.y
        local offsetX = quickslotCfg.offsetX or 0
        local offsetY = quickslotCfg.offsetY or 0
        local bgMiddle = FindControl(rootFrame, 'BgMiddle')

        qsBtn:SetDimensions(buttonSize, buttonSize)
        qsBtn.cooldownRevealWidth = buttonSize
        qsBtn.cooldownRevealHeight = buttonSize
        qsBtn:ClearAnchors()
        if bgMiddle then
            qsBtn:SetAnchor(CENTER, bgMiddle, BOTTOM, baseX + offsetX, baseY + offsetY)
        end

        local flipCard = qsBtn:GetNamedChild("FlipCard")
        if flipCard then flipCard:SetDimensions(buttonSize - 3, buttonSize - 3) end
        local icon = qsBtn:GetNamedChild("Icon")
        if icon then icon:SetDimensions(buttonSize - 3, buttonSize - 3) end
        SetPressFeedbackBaseSize(qsBtn, buttonSize - 3, buttonSize - 3, buttonSize - 3, buttonSize - 3)
        AnchorQuickslotCountText(qsBtn, qsBtn:GetNamedChild("CountText"))
    end

    local compBtn = GetFrontBarButtonControl(rootFrame, frontBarContainer, "CompanionButton")
    if compBtn then
        local companionCfg = frontBarCfg.companionButton
        local baseX = BETTERUI_ORB_FRAMES.bars.companionUltimate.x
        local baseY = BETTERUI_ORB_FRAMES.bars.companionUltimate.y
        local offsetX = companionCfg.offsetX or 0
        local offsetY = companionCfg.offsetY or 0
        local bgMiddle = FindControl(rootFrame, 'BgMiddle')

        compBtn:SetDimensions(ultimateSize, ultimateSize)
        compBtn.cooldownRevealWidth = ultimateSize
        compBtn.cooldownRevealHeight = ultimateSize
        compBtn:ClearAnchors()
        if bgMiddle then
            compBtn:SetAnchor(CENTER, bgMiddle, BOTTOM, baseX + offsetX, baseY + offsetY)
        end

        local flipCard = compBtn:GetNamedChild("FlipCard")
        if flipCard then flipCard:SetDimensions(ultimateSize - 3, ultimateSize - 3) end
        local icon = compBtn:GetNamedChild("Icon")
        if icon then icon:SetDimensions(ultimateSize - 3, ultimateSize - 3) end
        SetPressFeedbackBaseSize(compBtn, ultimateSize - 3, ultimateSize - 3, ultimateSize - 3, ultimateSize - 3)
    end

    local barOffsetX = frontBarCfg.offsetX or 0
    local barOffsetY = frontBarCfg.offsetY or 0
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if bgMiddle then
        frontBarContainer:ClearAnchors()
        frontBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, barOffsetX + 10, -15 + barOffsetY)
    end
end

local function UpdateFrontBarQuickslot(rootFrame)
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local qsBtn = GetFrontBarButtonControl(rootFrame, frontBarContainer, "QuickslotButton")
    if not qsBtn then return end

    local slotIndex = GetCurrentQuickslot()
    local icon = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    local iconControl = qsBtn:GetNamedChild("Icon")
    if iconControl then
        if icon and icon ~= "" then
            iconControl:SetTexture(icon)
            iconControl:SetHidden(false)
        else
            iconControl:SetHidden(true)
        end
    end

    local settings = BETTERUI.GetModuleSettings("ResourceOrbFrames")
    UpdateQuickslotCountAndEmptyState(qsBtn, nil, settings, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    qsBtn.slotIndex = slotIndex
    qsBtn.hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL

    if not qsBtn.tooltipHandlersAdded then
        SkillBar.SetupButtonTooltip(qsBtn, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL, RIGHT, -5, 0)
        qsBtn.tooltipHandlersAdded = true
    end
end

local function UpdateFrontBarCompanion(rootFrame)
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    local compBtn = GetFrontBarButtonControl(rootFrame, frontBarContainer, "CompanionButton")
    if not compBtn then
        return
    end

    local companionActive = DoesUnitExist("companion") and HasActiveCompanion()
    if companionActive then
        -- Hide ultimate fill animations before showing button - these are visible by default
        -- from the inherited UltimateTemplate but have no companion meter management code
        local fillLeft = compBtn:GetNamedChild("FillAnimationLeft")
        local fillRight = compBtn:GetNamedChild("FillAnimationRight")
        if fillLeft then fillLeft:SetHidden(true) end
        if fillRight then fillRight:SetHidden(true) end

        compBtn:SetHidden(false)
        local slotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
        local icon = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_COMPANION)
        local iconControl = compBtn:GetNamedChild("Icon")
        if iconControl then
            if icon and icon ~= "" then
                iconControl:SetTexture(icon)
                iconControl:SetHidden(false)
            else
                iconControl:SetHidden(true)
            end
        end
        compBtn.slotIndex = slotIndex
        compBtn.hotbarCategory = HOTBAR_CATEGORY_COMPANION

        if not compBtn.tooltipHandlersAdded then
            SkillBar.SetupButtonTooltip(compBtn, slotIndex, HOTBAR_CATEGORY_COMPANION, RIGHT, -5, 0)
            compBtn.tooltipHandlersAdded = true
        end
    else
        compBtn:SetHidden(true)
    end
end

local function UpdateFrontBarCooldowns(rootFrame)
    local frontBarCfg = BETTERUI.GetModuleSettings("ResourceOrbFrames").customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local isGamepad = IsInGamepadPreferredMode()
    local slotMapping = {
        { buttonName = "Button1",         slot = 3,                                  category = activeCategory },
        { buttonName = "Button2",         slot = 4,                                  category = activeCategory },
        { buttonName = "Button3",         slot = 5,                                  category = activeCategory },
        { buttonName = "Button4",         slot = 6,                                  category = activeCategory },
        { buttonName = "Button5",         slot = 7,                                  category = activeCategory },
        { buttonName = "UltimateButton",  slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, category = activeCategory },
        { buttonName = "QuickslotButton", slot = GetCurrentQuickslot(),              category = HOTBAR_CATEGORY_QUICKSLOT_WHEEL },
        { buttonName = "CompanionButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, category = HOTBAR_CATEGORY_COMPANION },
    }

    local settings = BETTERUI.GetModuleSettings("ResourceOrbFrames")
    local cooldownSize = ClampTextSize(settings.cooldownTextSize, SKILL_TEXT_SIZE_MIN, SKILL_TEXT_SIZE_MAX, 27)
    local cooldownColor = settings.cooldownTextColor or { 0.86, 0.84, 0.13, 1 }

    for _, mapping in ipairs(slotMapping) do
        local btn = GetFrontBarButtonControl(rootFrame, frontBarContainer, mapping.buttonName)
        local cooldownStateKey = BuildCooldownStateKey(mapping.slot, mapping.category)

        if btn and not btn:IsHidden() then -- Only update if visible
            -- Get cached children for this button
            local cachedBtn = GetCachedButton(mapping.buttonName)
            local children = cachedBtn and cachedBtn.children or {}
            local baseDesaturation = 0

            if mapping.buttonName == "QuickslotButton" then
                local isQuickslotEmpty = UpdateQuickslotCountAndEmptyState(btn, children, settings, mapping.slot,
                    mapping.category)
                if isQuickslotEmpty then
                    baseDesaturation = 1
                end
            end

            local remainMs, durationMs = GetSlotCooldownInfo(mapping.slot, mapping.category)
            -- Use BackBar logic: stricter duration filter (1500) and ignore isGlobal
            local showCooldown = false
            if remainMs and remainMs > 0 and durationMs and durationMs > 1500 then
                showCooldown = true
            end

            if not showCooldown then
                local effectRemaining = GetActionSlotEffectTimeRemaining(mapping.slot, mapping.category)
                if effectRemaining and effectRemaining > 0 then
                    remainMs = effectRemaining
                    -- Cache the initial duration when effect first appears for accurate percentage calculation
                    local cacheKey = BuildCooldownStateKey(mapping.slot, mapping.category)
                    if not m_effectDurationCache[cacheKey] or m_effectDurationCache[cacheKey] < effectRemaining then
                        m_effectDurationCache[cacheKey] = effectRemaining
                    end
                    durationMs = m_effectDurationCache[cacheKey]
                    showCooldown = true
                else
                    -- Effect ended, clear cache
                    local cacheKey = BuildCooldownStateKey(mapping.slot, mapping.category)
                    m_effectDurationCache[cacheKey] = nil
                end
            end

            -- Respect showQuickslotCooldown setting
            if mapping.buttonName == "QuickslotButton" and not settings.showQuickslotCooldown then
                showCooldown = false
            end

            -- Use cached children (fall back to GetNamedChild only if cache miss)
            local cooldown = children.Cooldown or btn:GetNamedChild("Cooldown")
            local cooldownEdge = children.CooldownEdge or btn:GetNamedChild("CooldownEdge")
            local cooldownOverlay = children.CooldownOverlay or btn:GetNamedChild("CooldownOverlay")
            local iconControl = children.Icon or btn:GetNamedChild("Icon")
            local timerText = children.TimerText or btn:GetNamedChild("TimerText")
            local altTimerText = children.CooldownText or btn:GetNamedChild("CooldownText")

            if showCooldown then
                local visualRemainMs = GetSmoothedCooldownRemaining(cooldownStateKey, remainMs, durationMs)
                if isGamepad then
                    if cooldown then cooldown:SetHidden(true) end
                    local percentComplete = ApplyLinearCooldownVisuals(cooldownEdge, cooldownOverlay, btn, visualRemainMs,
                        durationMs)
                    if iconControl then
                        if percentComplete ~= nil then
                            local cooldownDesaturation = 1 - percentComplete
                            if cooldownDesaturation < baseDesaturation then
                                cooldownDesaturation = baseDesaturation
                            end
                            iconControl:SetDesaturation(cooldownDesaturation)
                        else
                            iconControl:SetDesaturation(math.max(1, baseDesaturation))
                        end
                    end
                else
                    if iconControl then iconControl:SetDesaturation(math.max(1, baseDesaturation)) end
                    if cooldownEdge then cooldownEdge:SetHidden(true) end
                    if cooldownOverlay then cooldownOverlay:SetHidden(true) end
                    if cooldown then
                        cooldown:StartCooldown(remainMs, durationMs, CD_TYPE_RADIAL, nil, false)
                        cooldown:SetHidden(false)
                    end
                end

                -- Text Logic
                local textToSet = string.format("%.1f", visualRemainMs / 1000)
                if timerText then
                    timerText:SetText(textToSet)
                    timerText:SetHidden(false)
                    timerText:SetDrawLayer(DL_OVERLAY)
                    timerText:SetDrawTier(DT_HIGH)
                    timerText:SetDrawLevel(10)

                    timerText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", cooldownSize))
                    timerText:SetColor(unpack(cooldownColor))
                elseif altTimerText then
                    altTimerText:SetText(textToSet)
                    altTimerText:SetHidden(false)
                    altTimerText:SetDrawLayer(DL_OVERLAY)
                    altTimerText:SetDrawTier(DT_HIGH)
                    altTimerText:SetDrawLevel(10)
                    altTimerText:SetColor(unpack(cooldownColor))
                end
            else
                ResetSmoothedCooldownRemaining(cooldownStateKey)
                if iconControl then iconControl:SetDesaturation(baseDesaturation) end
                if cooldownOverlay then cooldownOverlay:SetHidden(true) end
                if cooldown then cooldown:SetHidden(true) end
                if cooldownEdge then cooldownEdge:SetHidden(true) end
                if timerText then timerText:SetHidden(true) end
                if altTimerText then altTimerText:SetHidden(true) end
            end

            local stackCountText = children.StackCountText or btn:GetNamedChild("StackCountText")
            if stackCountText then
                local stackCount = GetActionSlotEffectStackCount(mapping.slot, mapping.category)
                if stackCount and stackCount > 0 then
                    stackCountText:SetText(stackCount)
                    stackCountText:SetHidden(false)
                    stackCountText:SetDrawLayer(DL_OVERLAY)
                    stackCountText:SetDrawTier(DT_HIGH)
                    stackCountText:SetDrawLevel(10)
                else
                    stackCountText:SetHidden(true)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------------------------
-- MODULE EXPORTS
-------------------------------------------------------------------------------------------------
SkillBar.CacheFrontBarControls = CacheFrontBarControls
SkillBar.HideNativeActionBar = HideNativeActionBar
SkillBar.UpdateFrontBar = UpdateFrontBar
SkillBar.UpdateFrontBarUsability = UpdateFrontBarUsability
SkillBar.SetupFrontBarTooltips = SetupFrontBarTooltips
SkillBar.SetupFrontBarKeybinds = SetupFrontBarKeybinds
SkillBar.UpdateFrontBarLayout = UpdateFrontBarLayout
SkillBar.UpdateFrontBarQuickslot = UpdateFrontBarQuickslot
SkillBar.UpdateFrontBarCompanion = UpdateFrontBarCompanion
SkillBar.UpdateFrontBarCooldowns = UpdateFrontBarCooldowns
SkillBar.SetupFrontBarPressFeedbackHooks = SetupFrontBarPressFeedbackHooks
SkillBar.PlayFrontBarPressFeedbackForSlot = PlayFrontBarPressFeedbackForSlot
