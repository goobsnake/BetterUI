-- Modules/ResourceOrbFrames/SkillBar/FrontBarPressFeedback.lua
-- Press feedback system: bounce animations, edge flash, hooks for action bar button presses.
-- Extracted from FrontBarManager.lua for maintainability.

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
-- Live accessor: combat-path reads must not deep-clone settings per event.
local GetLiveSettings = (Utils.Settings and Utils.Settings.GetLive) or Utils.GetSettings

-- PRESS FEEDBACK CONSTANTS
local PRESS_FEEDBACK_DEDUPE_WINDOW_MS = 140
local PRESS_FEEDBACK_EDGE_FLASH_MS = 167
local PRESS_FEEDBACK_EDGE_FLASH_ALPHA = 0.95
local BOUNCE_SHRINK_SCALE = 0.9
local BOUNCE_ICON_SHRINK_SCALE = 0.8
local BOUNCE_GROW_SCALE = 1.1
local BOUNCE_FRAME_RESET_TIME_MS = 167
local BOUNCE_ICON_RESET_TIME_MS = 100

-- PRESS FEEDBACK STATE
local m_pressFeedbackHooksInstalled = false
local m_pressFeedbackRootFrame = nil
local m_pressFeedbackLastPlayedMsByButton = {}

-- Forward reference to FrontBarManager's button lookup (set during hook setup)
local m_frontBarContainer = nil
local m_buttonCache = nil

-- Canonical implementation lives in Core/Utils.lua (Utils.Controls).
local GetFrontBarButtonControl = Utils.GetFrontBarButtonControl

-- BUTTON NAME RESOLUTION

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

-- BOUNCE ANIMATION HELPERS

local function ConfigureBounceTimelineSize(timeline, width, height, shrinkScale, resetDurationMs)
    if not timeline then return end
    local shrink = timeline:GetAnimation(1)
    local grow = timeline:GetAnimation(2)
    local reset = timeline:GetAnimation(3)
    if not shrink or not grow or not reset then return end
    shrink:SetStartAndEndWidth(width, width * shrinkScale)
    shrink:SetStartAndEndHeight(height, height * shrinkScale)
    grow:SetStartAndEndWidth(width * shrinkScale, width * BOUNCE_GROW_SCALE)
    grow:SetStartAndEndHeight(height * shrinkScale, height * BOUNCE_GROW_SCALE)
    reset:SetStartAndEndWidth(width * BOUNCE_GROW_SCALE, width)
    reset:SetStartAndEndHeight(height * BOUNCE_GROW_SCALE, height)
    reset:SetDuration(resetDurationMs)
end

--- Stores base frame/icon sizes for press feedback bounce normalization.
---@param buttonControl table Button control to store sizes on
---@param frameWidth number Base frame width
---@param frameHeight number Base frame height
---@param iconWidth number Base icon width
---@param iconHeight number Base icon height
local function SetPressFeedbackBaseSize(buttonControl, frameWidth, frameHeight, iconWidth, iconHeight)
    if not buttonControl then return end
    buttonControl.betterUIPressFeedbackBaseFrameWidth = frameWidth
    buttonControl.betterUIPressFeedbackBaseFrameHeight = frameHeight
    buttonControl.betterUIPressFeedbackBaseIconWidth = iconWidth
    buttonControl.betterUIPressFeedbackBaseIconHeight = iconHeight
end

local function EnsurePressFeedbackState(buttonControl, children)
    if not buttonControl then return nil end
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

    -- Frame dimensions
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
        ConfigureBounceTimelineSize(state.bounceAnimation, frameWidth, frameHeight, BOUNCE_SHRINK_SCALE, BOUNCE_FRAME_RESET_TIME_MS)
        state.lastFrameWidth = frameWidth
        state.lastFrameHeight = frameHeight
    end
    state.resolvedFrameWidth = frameWidth
    state.resolvedFrameHeight = frameHeight

    -- Icon dimensions
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
    local isIconBouncePlaying = state.iconBounceAnimation and state.iconBounceAnimation.IsPlaying and state.iconBounceAnimation:IsPlaying()
    if (not isIconBouncePlaying) and (state.lastIconWidth ~= iconWidth or state.lastIconHeight ~= iconHeight) then
        ConfigureBounceTimelineSize(state.iconBounceAnimation, iconWidth, iconHeight, BOUNCE_ICON_SHRINK_SCALE, BOUNCE_ICON_RESET_TIME_MS)
        state.lastIconWidth = iconWidth
        state.lastIconHeight = iconHeight
    end
    state.resolvedIconWidth = iconWidth
    state.resolvedIconHeight = iconHeight
    return state
end

local function PlayButtonPressFeedback(buttonControl, children, buttonName)
    if not buttonControl then return end
    local nowMs = GetGameTimeMilliseconds()
    local lastPlayedMs = m_pressFeedbackLastPlayedMsByButton[buttonName]
    if lastPlayedMs and (nowMs - lastPlayedMs) <= PRESS_FEEDBACK_DEDUPE_WINDOW_MS then return end
    m_pressFeedbackLastPlayedMsByButton[buttonName] = nowMs
    local state = EnsurePressFeedbackState(buttonControl, children)
    if not state then return end
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

-- USABILITY GATE HELPERS

local function GetNativeActionBarUsableState(slotIndex, hotbarCategory)
    if type(slotIndex) ~= "number" or type(hotbarCategory) ~= "number" then return nil end
    if type(ZO_ActionBar_GetButton) ~= "function" then return nil end
    local nativeButton = ZO_ActionBar_GetButton(slotIndex, hotbarCategory)
    if not nativeButton then return nil end
    if nativeButton.usable ~= nil then return nativeButton.usable end
    return nil
end

local function HasFallbackPressUseFailure(slotIndex, hotbarCategory)
    if type(slotIndex) ~= "number" or type(hotbarCategory) ~= "number" then return true end
    local slotType = GetSlotType(slotIndex, hotbarCategory)
    if slotType == ACTION_TYPE_NOTHING then return true end
    local hasItemCountFailure = false
    if slotType == ACTION_TYPE_ITEM then
        hasItemCountFailure = (GetSlotItemCount(slotIndex, hotbarCategory) or 0) <= 0
    end
    local hasCostFailure = ActionSlotHasCostFailure and ActionSlotHasCostFailure(slotIndex, hotbarCategory) or false
    local hasStateFailure = ActionSlotHasNonCostStateFailure and ActionSlotHasNonCostStateFailure(slotIndex, hotbarCategory) or false
    local hasTargetFailure = ActionSlotHasTargetFailure and ActionSlotHasTargetFailure(slotIndex, hotbarCategory) or false
    local hasRangeFailure = ActionSlotHasRangeFailure and ActionSlotHasRangeFailure(slotIndex, hotbarCategory) or false
    local hasInsufficientUltimate = false
    local ultimateSlot = ACTION_BAR_ULTIMATE_SLOT_INDEX and (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or nil
    if ultimateSlot and slotIndex == ultimateSlot then
        local requiredUltimate = GetSlotAbilityCost(slotIndex, COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE, hotbarCategory)
        local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
        hasInsufficientUltimate = type(requiredUltimate) == "number" and requiredUltimate > 0 and
            type(currentUltimate) == "number" and currentUltimate < requiredUltimate
    end
    return hasItemCountFailure or hasCostFailure or hasStateFailure or hasTargetFailure or hasRangeFailure or hasInsufficientUltimate
end

-- PLAY FEEDBACK FOR SLOT

--- Plays press feedback animation for a specific action bar slot.
---@param rootFrame table|nil Root frame (uses cached if nil)
---@param slotIndex number Action bar slot index
---@param hotbarCategory number|nil Hotbar category (defaults to active)
---@param bypassUsableGate boolean|nil Skip usability checks
local function PlayFrontBarPressFeedbackForSlot(rootFrame, slotIndex, hotbarCategory, bypassUsableGate)
    local frontBarCfg = GetLiveSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local resolvedRootFrame = rootFrame or m_pressFeedbackRootFrame
    if not resolvedRootFrame then return end

    -- Lazy-resolve container and cache references from FrontBarManager
    if not m_frontBarContainer or (m_frontBarContainer.IsHidden and m_frontBarContainer:IsHidden()) then
        m_frontBarContainer = FindControl(resolvedRootFrame, 'FrontBarContainer')
    end
    m_buttonCache = m_buttonCache or (SkillBar._frontBarButtonCache)

    local activeCategory = GetActiveHotbarCategory()
    local resolvedCategory = hotbarCategory or activeCategory
    local isPrimaryCategory = resolvedCategory == activeCategory
    local isQuickslot = resolvedCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    local isCompanion = resolvedCategory == HOTBAR_CATEGORY_COMPANION
    if not (isPrimaryCategory or isQuickslot or isCompanion) then return end

    local buttonName = ResolvePressFeedbackButtonName(slotIndex, resolvedCategory)
    if not buttonName then return end

    if not bypassUsableGate then
        local nativeUsable = GetNativeActionBarUsableState(slotIndex, resolvedCategory)
        if nativeUsable == false then return end
        if HasFallbackPressUseFailure(slotIndex, resolvedCategory) then return end
    end

    local frontBarContainer = m_frontBarContainer or FindControl(resolvedRootFrame, 'FrontBarContainer')
    local buttonControl = GetFrontBarButtonControl(resolvedRootFrame, frontBarContainer, buttonName)
    if not buttonControl or buttonControl:IsHidden() then return end

    local cachedButton = m_buttonCache and m_buttonCache[buttonName] or nil
    local children = cachedButton and cachedButton.children or nil
    local iconControl = (children and children.Icon) or buttonControl:GetNamedChild("Icon")
    if iconControl and iconControl:IsHidden() then return end
    if not bypassUsableGate then
        local unusableOverlay = (children and children.UnusableOverlay) or buttonControl:GetNamedChild("UnusableOverlay")
        if unusableOverlay and not unusableOverlay:IsHidden() then return end
    end

    PlayButtonPressFeedback(buttonControl, children, buttonName)
end

-- HOOK INSTALLATION

--- Installs ZO_ActionBar_OnActionButtonUp hook for press feedback.
---@param rootFrame table|nil Root frame (uses cached if nil)
local function SetupFrontBarPressFeedbackHooks(rootFrame)
    m_pressFeedbackRootFrame = rootFrame or m_pressFeedbackRootFrame
    if m_pressFeedbackHooksInstalled then return end
    if type(ZO_PreHook) ~= "function" then return end
    ZO_PreHook("ZO_ActionBar_OnActionButtonUp", function(slotNum, hotbarCategory)
        PlayFrontBarPressFeedbackForSlot(m_pressFeedbackRootFrame, slotNum, hotbarCategory)
    end)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "rawHookInstalled", { method = "ZO_ActionBar_OnActionButtonUp", target = type("ZO_ActionBar_OnActionButtonUp") }) end
    m_pressFeedbackHooksInstalled = true
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "frontBarPressFeedbackHooksInstalled") end
end

-- MODULE EXPORTS
SkillBar.SetPressFeedbackBaseSize = SetPressFeedbackBaseSize
SkillBar.SetupFrontBarPressFeedbackHooks = SetupFrontBarPressFeedbackHooks
SkillBar.PlayFrontBarPressFeedbackForSlot = PlayFrontBarPressFeedbackForSlot
