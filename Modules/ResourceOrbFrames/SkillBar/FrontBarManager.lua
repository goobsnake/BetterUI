--[[
File: Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua
Purpose: Manages the Front Bar layout, updates, keybinds, and usability.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local function FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

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
local m_effectDurationCache = {} -- Cache of initial effect durations for cooldown percentage calculation
local m_cooldownVisualState = {} -- Lightweight per-slot interpolation cache for smoother reveal animation

local QUICKSLOT_COUNT_OFFSET_Y = 1

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

    label:ClearAnchors()
    label:SetAnchor(TOP, buttonControl, BOTTOM, 0, QUICKSLOT_COUNT_OFFSET_Y)
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
    local quickslotTextSize = settings.quickslotTextSize or 27
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

    if cooldownOverlay then
        local unrevealedHeight = (1 - percentComplete) * revealHeight
        cooldownOverlay:ClearAnchors()
        cooldownOverlay:SetAnchor(TOPLEFT, revealControl, TOPLEFT, 0, 0)
        cooldownOverlay:SetDimensions(revealWidth, unrevealedHeight)
        cooldownOverlay:SetHidden(false)
        cooldownOverlay:SetDrawLayer(DL_OVERLAY)
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
    if isCasting then return end

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
            local unusableOverlay = btn:GetNamedChild("UnusableOverlay")

            if iconControl and not iconControl:IsHidden() then
                local hasCostFailure = ActionSlotHasCostFailure(mapping.slot, activeCategory)
                local hasStateFailure = ActionSlotHasNonCostStateFailure(mapping.slot, activeCategory)
                local unusable = hasCostFailure or hasStateFailure

                local remainMs, durationMs = GetSlotCooldownInfo(mapping.slot, activeCategory)
                local hasActiveCooldown = remainMs and durationMs and remainMs > 0 and durationMs > 0

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
    local cooldownSize = settings.cooldownTextSize or 27
    local cooldownColor = settings.cooldownTextColor or { 0.86, 0.84, 0.13, 1 }

    for _, mapping in ipairs(slotMapping) do
        local btn = GetFrontBarButtonControl(rootFrame, frontBarContainer, mapping.buttonName)
        local cooldownStateKey = string.format("%s_%d_%d", mapping.buttonName, mapping.slot or -1, mapping.category or -1)

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
                    local cacheKey = mapping.slot .. "_" .. (mapping.category or 0)
                    if not m_effectDurationCache[cacheKey] or m_effectDurationCache[cacheKey] < effectRemaining then
                        m_effectDurationCache[cacheKey] = effectRemaining
                    end
                    durationMs = m_effectDurationCache[cacheKey]
                    showCooldown = true
                else
                    -- Effect ended, clear cache
                    local cacheKey = mapping.slot .. "_" .. (mapping.category or 0)
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

                    timerText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", cooldownSize))
                    timerText:SetColor(unpack(cooldownColor))
                elseif altTimerText then
                    altTimerText:SetText(textToSet)
                    altTimerText:SetHidden(false)
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
