--[[
File: Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua
Purpose: Manages the Front Bar layout, updates, keybinds, and usability.
Author: BetterUI Team
Last Modified: 2026-03-14

Related modules (loaded before this file):
  FrontBarPressFeedback.lua — Press feedback bounce/flash system
  FrontBarCooldowns.lua     — Cooldown smoothing and per-frame cooldown updates
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
local GetModuleSettings = Utils.GetModuleSettings

local GetFrontBarButtonControl = Utils.GetFrontBarButtonControl

-- Cached control references
local m_buttonCache = {}
local m_frontBarContainer = nil
local m_quickslotBtn = nil
local m_companionBtn = nil
local m_targetFailureLastSeenMsBySlotCategory = {}
local m_nonCostFailureLastSeenMsBySlotCategory = {}

local TARGET_FAILURE_CAST_HOLD_MS = 200
local NON_COST_FAILURE_CAST_HOLD_MS = 250

-- Expose button cache to sibling modules (FrontBarCooldowns, FrontBarPressFeedback)
SkillBar._frontBarButtonCache = m_buttonCache

local function BuildCooldownStateKey(slotIndex, hotbarCategory)
    return string.format("%d_%d", slotIndex or -1, hotbarCategory or -1)
end

--------------------------------------------------------------------------------
-- USABILITY FAILURE LATCHING
--------------------------------------------------------------------------------

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
    if slotIndex ~= ultimateSlotIndex then return false end
    local abilityCost = GetSlotAbilityCost(slotIndex, hotbarCategory)
    if type(abilityCost) ~= "number" or abilityCost <= 0 then return false end
    local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
    if type(currentUltimate) ~= "number" then return false end
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

--------------------------------------------------------------------------------
-- CONTROL CACHING
--------------------------------------------------------------------------------

local function CacheFrontBarControls(rootFrame)
    if not rootFrame then return end
    m_frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not m_frontBarContainer then return end

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

--------------------------------------------------------------------------------
-- HIDE NATIVE ACTION BAR
--------------------------------------------------------------------------------

local function HideNativeActionBar()
    if ZO_ActionBar1 and ZO_ActionBar1.SetHidden then
        ZO_ActionBar1:SetHidden(true)
        if ZO_ActionBar1.SetAlpha then ZO_ActionBar1:SetAlpha(0) end
    end
    if ZO_ActionBarTimer and ZO_ActionBarTimer.SetHidden then
        ZO_ActionBarTimer:SetHidden(true)
    end
end

--------------------------------------------------------------------------------
-- UPDATE FRONT BAR (icons, slot data, highlights)
--------------------------------------------------------------------------------

local function UpdateFrontBar(rootFrame)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local activeCategory = GetActiveHotbarCategory()
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

--------------------------------------------------------------------------------
-- UPDATE USABILITY OVERLAY
--------------------------------------------------------------------------------

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
                local hasLatchedStateFailure = ResolveNonCostFailureWithCastLatch(slotStateKey, hasStateFailure, isCasting, nowMs)
                local hasTargetOrRangeFailure = GetTargetOrRangeFailure(mapping.slot, activeCategory)
                local hasLatchedTargetFailure = ResolveTargetFailureWithCastLatch(slotStateKey, hasTargetOrRangeFailure, isCasting, nowMs)
                local hasInsufficientUlt = HasInsufficientUltimate(mapping.slot, activeCategory)
                local unusable = hasCostFailure or hasLatchedStateFailure or hasLatchedTargetFailure or hasInsufficientUlt
                local hasActiveCooldown = ShouldSuppressUnusableOverlayForCooldown(mapping.slot, activeCategory)
                if unusableOverlay then
                    unusableOverlay:SetHidden(not (unusable and not hasActiveCooldown))
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- TOOLTIPS
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- KEYBINDS
--------------------------------------------------------------------------------

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
                ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, bindings.keyboard, HIDE_UNBOUND, bindings.gamepad)
            end
        end
    end

    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local buttonText = ultBtn:GetNamedChild("ButtonText")
        if buttonText then
            ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, "ACTION_BUTTON_8", HIDE_UNBOUND, "GAMEPAD_ACTION_BUTTON_8")
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
            ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, "ACTION_BUTTON_9", HIDE_UNBOUND, "GAMEPAD_ACTION_BUTTON_9")
        end
        local countText = qsBtn:GetNamedChild("CountText")
        if countText then
            SkillBar.AnchorQuickslotCountText(qsBtn, countText)
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

--------------------------------------------------------------------------------
-- LAYOUT
--------------------------------------------------------------------------------

local function UpdateFrontBarLayout(rootFrame)
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

    -- Imported from FrontBarPressFeedback
    local SetPressFeedbackBaseSize = SkillBar.SetPressFeedbackBaseSize

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
        SkillBar.AnchorQuickslotCountText(qsBtn, qsBtn:GetNamedChild("CountText"))
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

--------------------------------------------------------------------------------
-- QUICKSLOT + COMPANION UPDATES
--------------------------------------------------------------------------------

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
    SkillBar.UpdateQuickslotCountAndEmptyState(qsBtn, nil, settings, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
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
    if not compBtn then return end
    local companionActive = DoesUnitExist("companion") and HasActiveCompanion()
    if companionActive then
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

-------------------------------------------------------------------------------------------------
-- MODULE EXPORTS
-- Press feedback and cooldown exports are set by their respective sibling files.
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
