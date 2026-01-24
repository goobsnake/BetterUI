--[[
File: Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua
Purpose: Manages the Front Bar layout, updates, keybinds, and usability.
Author: BetterUI Team
Last Modified: 2026-01-23
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local function FindControl(parent, name)
    return BETTERUI.ControlUtils.FindControl(parent, name)
end

local function GetModuleSettings()
    return BETTERUI.GetModuleSettings("ResourceOrbFrames")
end

function SkillBar.HideNativeActionBar()
    if ZO_ActionBar1 and ZO_ActionBar1.SetHidden then
        ZO_ActionBar1:SetHidden(true)
        if ZO_ActionBar1.SetAlpha then ZO_ActionBar1:SetAlpha(0) end
    end
    if ZO_ActionBarTimer and ZO_ActionBarTimer.SetHidden then
        ZO_ActionBarTimer:SetHidden(true)
    end
end

function SkillBar.UpdateFrontBar(rootFrame)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local slotMapping = {
        {buttonName = "Button1", slot = 3},
        {buttonName = "Button2", slot = 4},
        {buttonName = "Button3", slot = 5},
        {buttonName = "Button4", slot = 6},
        {buttonName = "Button5", slot = 7},
        {buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1},
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

function SkillBar.UpdateFrontBarUsability(rootFrame, isCasting)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    if isCasting then return end
    
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local slotMapping = {
        {buttonName = "Button1", slot = 3},
        {buttonName = "Button2", slot = 4},
        {buttonName = "Button3", slot = 5},
        {buttonName = "Button4", slot = 6},
        {buttonName = "Button5", slot = 7},
        {buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1},
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

function SkillBar.SetupFrontBarTooltips(rootFrame)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local slotMapping = {
        {buttonName = "Button1", slot = 3},
        {buttonName = "Button2", slot = 4},
        {buttonName = "Button3", slot = 5},
        {buttonName = "Button4", slot = 6},
        {buttonName = "Button5", slot = 7},
        {buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1},
    }

    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            SkillBar.SetupButtonTooltip(btn, mapping.slot, nil, TOP, 0, 5)
        end
    end
end

function SkillBar.SetupFrontBarKeybinds(rootFrame)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local HIDE_UNBOUND = false
    local slotBindings = {
        [1] = {keyboard = "ACTION_BUTTON_3", gamepad = "GAMEPAD_ACTION_BUTTON_3"},
        [2] = {keyboard = "ACTION_BUTTON_4", gamepad = "GAMEPAD_ACTION_BUTTON_4"},
        [3] = {keyboard = "ACTION_BUTTON_5", gamepad = "GAMEPAD_ACTION_BUTTON_5"},
        [4] = {keyboard = "ACTION_BUTTON_6", gamepad = "GAMEPAD_ACTION_BUTTON_6"},
        [5] = {keyboard = "ACTION_BUTTON_7", gamepad = "GAMEPAD_ACTION_BUTTON_7"},
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
    
    local qsBtn = FindControl(rootFrame, 'QuickslotButton') or FindControl(frontBarContainer, 'QuickslotButton')
    if qsBtn then
         local buttonText = qsBtn:GetNamedChild("ButtonText")
         if buttonText then
             ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, "ACTION_BUTTON_9", HIDE_UNBOUND, "GAMEPAD_ACTION_BUTTON_9")
         end
         local countText = qsBtn:GetNamedChild("CountText")
         if countText then
             countText:ClearAnchors()
             countText:SetAnchor(BOTTOM, qsBtn, BOTTOM, 0, -4)
             countText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
         end
    end
    
    local compBtn = FindControl(rootFrame, 'CompanionButton') or FindControl(frontBarContainer, 'CompanionButton')
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

function SkillBar.UpdateFrontBarLayout(rootFrame)
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
            btn:ClearAnchors()
            if i == 1 then
                btn:SetAnchor(LEFT, frontBarContainer, CENTER, -halfWidth, 0)
            else
                local prevBtn = FindControl(frontBarContainer, 'Button' .. (i-1))
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
    
    local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
    if qsBtn then
        local quickslotCfg = frontBarCfg.quickslotButton
        local baseX = BETTERUI_ORB_FRAMES.bars.quickslot.x
        local baseY = BETTERUI_ORB_FRAMES.bars.quickslot.y
        local offsetX = quickslotCfg.offsetX or 0
        local offsetY = quickslotCfg.offsetY or 0
        local bgMiddle = FindControl(rootFrame, 'BgMiddle')
        
        qsBtn:SetDimensions(buttonSize, buttonSize)
        qsBtn:ClearAnchors()
        if bgMiddle then
            qsBtn:SetAnchor(CENTER, bgMiddle, BOTTOM, baseX + offsetX, baseY + offsetY)
        end
    end
    
    local compBtn = FindControl(frontBarContainer, 'CompanionButton')
    if compBtn then
        local companionCfg = frontBarCfg.companionButton
        local baseX = BETTERUI_ORB_FRAMES.bars.companionUltimate.x
        local baseY = BETTERUI_ORB_FRAMES.bars.companionUltimate.y
        local offsetX = companionCfg.offsetX or 0
        local offsetY = companionCfg.offsetY or 0
        local bgMiddle = FindControl(rootFrame, 'BgMiddle')
        
        compBtn:SetDimensions(ultimateSize, ultimateSize)
        compBtn:ClearAnchors()
        if bgMiddle then
            compBtn:SetAnchor(CENTER, bgMiddle, BOTTOM, baseX + offsetX, baseY + offsetY)
        end
    end
    
    local barOffsetX = frontBarCfg.offsetX or 0
    local barOffsetY = frontBarCfg.offsetY or 0
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    if bgMiddle then
        frontBarContainer:ClearAnchors()
        frontBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, barOffsetX + 10, -15 + barOffsetY)
    end
end

function SkillBar.UpdateFrontBarQuickslot(rootFrame)
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
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
    
    local countText = qsBtn:GetNamedChild("CountText")
    if countText then
        local count = GetSlotItemCount(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if count and count > 0 then
            countText:SetText(count)
            countText:SetHidden(false)
        else
            countText:SetHidden(true)
        end
    end
    qsBtn.slotIndex = slotIndex
    qsBtn.hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    
    if not qsBtn.tooltipHandlersAdded then
        SkillBar.SetupButtonTooltip(qsBtn, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL, LEFT, 5, 0)
        qsBtn.tooltipHandlersAdded = true
    end
end

function SkillBar.UpdateFrontBarCompanion(rootFrame)
    local compBtn = FindControl(rootFrame, 'CompanionButton')
    if not compBtn then 
         local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
         if frontBarContainer then compBtn = FindControl(frontBarContainer, 'CompanionButton') end
    end
    if not compBtn then return end
    
    local companionActive = DoesUnitExist("companion") and HasActiveCompanion()
    if companionActive then
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
            SkillBar.SetupButtonTooltip(compBtn, slotIndex, HOTBAR_CATEGORY_COMPANION, LEFT, 5, 0)
            compBtn.tooltipHandlersAdded = true
        end
    else
        compBtn:SetHidden(true)
    end
end

function SkillBar.UpdateFrontBarCooldowns(rootFrame)
    local frontBarCfg = GetModuleSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local isGamepad = IsInGamepadPreferredMode()
    local slotMapping = {
        {buttonName = "Button1", slot = 3},
        {buttonName = "Button2", slot = 4},
        {buttonName = "Button3", slot = 5},
        {buttonName = "Button4", slot = 6},
        {buttonName = "Button5", slot = 7},
        {buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1},
    }
    
    local settings = GetModuleSettings()
    local cooldownSize = settings.cooldownTextSize or 27
    local cooldownColor = settings.cooldownTextColor or {0.86, 0.84, 0.13, 1}
    
    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            local remainMs, durationMs, isGlobal = GetSlotCooldownInfo(mapping.slot, activeCategory)
            local showCooldown = remainMs and remainMs > 0 and durationMs > 1000 and not isGlobal
            
            local cooldown = btn:GetNamedChild("Cooldown")
            local cooldownEdge = btn:GetNamedChild("CooldownEdge")
            local iconControl = btn:GetNamedChild("Icon")
            local timerText = btn:GetNamedChild("TimerText")
            
            if showCooldown then
                if iconControl then iconControl:SetDesaturation(1) end
                
                if isGamepad then
                    if cooldown then cooldown:SetHidden(true) end
                    if cooldownEdge and iconControl then
                        local percentComplete = 1 - (remainMs / durationMs)
                        local _, iconHeight = iconControl:GetDimensions()
                        local offsetY = (1 - percentComplete) * iconHeight
                        cooldownEdge:ClearAnchors()
                        cooldownEdge:SetAnchor(TOPLEFT, iconControl, TOPLEFT, 0, offsetY)
                        cooldownEdge:SetWidth(iconControl:GetWidth())
                        cooldownEdge:SetHidden(false)
                    end
                else
                     if cooldownEdge then cooldownEdge:SetHidden(true) end
                     if cooldown then
                        cooldown:StartCooldown(remainMs, durationMs, CD_TYPE_RADIAL, nil, false)
                        cooldown:SetHidden(false)
                     end
                end
                
                if timerText then
                    timerText:SetText(string.format("%.1f", remainMs / 1000))
                    timerText:SetHidden(false)
                    timerText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", cooldownSize))
                    timerText:SetColor(unpack(cooldownColor))
                end
            else
                if iconControl then iconControl:SetDesaturation(0) end
                if cooldown then cooldown:SetHidden(true) end
                if cooldownEdge then cooldownEdge:SetHidden(true) end
                if timerText then timerText:SetHidden(true) end
            end
            
            local stackCountText = btn:GetNamedChild("StackCountText")
            if stackCountText then
                 local stackCount = GetActionSlotEffectStackCount(mapping.slot, activeCategory)
                 if stackCount and stackCount > 0 then
                     stackCountText:SetText(stackCount)
                     stackCountText:SetHidden(false)
                 else
                     stackCountText:SetHidden(true)
                 end
            end
        end
    end
end
