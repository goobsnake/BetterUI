--[[
-- TODO(architecture): This file is 1000+ lines. Consider splitting:
--   1. OrbSkillBar/FrontBarManager.lua - Front bar updates and layout
--   2. OrbSkillBar/BackBarManager.lua - Back bar updates and layout  
--   3. OrbSkillBar/UltimateManager.lua - Ultimate meter and animations
--   4. OrbSkillBar/TooltipManager.lua - Tooltip setup for skills
-- Target: Each file < 400 lines.
--
File: Modules/ResourceOrbFrames/OrbSkillBar.lua
Purpose: Manages the Front and Back skill bars, including layout, content, and weapon swap animations.
Last Modified: 2026-01-23
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

-------------------------------------------------------------------------------------------------
-- BACK BAR LOGIC
-------------------------------------------------------------------------------------------------

local function CanUseBackupBar()
    return GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()
end

function SkillBar.UpdateBackBar(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    if not CanUseBackupBar() then
        backBarContainer:SetHidden(true)
        return
    end
    
    local activePair = GetActiveWeaponPairInfo()
    local backBarCategory = (activePair == ACTIVE_WEAPON_PAIR_MAIN) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    local settings = GetModuleSettings()
    local backBarOpacity = settings.backBarOpacity or 1
    
    local slots = {3, 4, 5, 6, 7, 8}
    
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            local iconControl = FindControl(btn, 'Icon')
            local icon = GetSlotTexture(slotIndex, backBarCategory)
            
            if iconControl then
                if icon and icon ~= '' then
                    iconControl:SetTexture(icon)
                    iconControl:SetHidden(false)
                    iconControl:SetAlpha(backBarOpacity)
                else
                    iconControl:SetHidden(true)
                end
            end
            
            local backdrop = btn:GetNamedChild("Backdrop")
            if backdrop then backdrop:SetAlpha(backBarOpacity) end
            local border = btn:GetNamedChild("Border")
            if border then border:SetAlpha(backBarOpacity) end
            
            btn.slotIndex = slotIndex
            btn.hotbarCategory = backBarCategory
        end
    end
    
    backBarContainer:SetHidden(false)
end

function SkillBar.UpdateBackBarLayout(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    local isGamePad = IsInGamepadPreferredMode()
    local slotsConfig = isGamePad and BETTERUI_ORB_FRAMES.slots.gamepad or BETTERUI_ORB_FRAMES.slots.keyboard
    
    local backBarCfg = BETTERUI_ORB_FRAMES.bars.customBackBar
    local modeConfig = backBarCfg and (isGamePad and backBarCfg.gamepad or backBarCfg.keyboard) or {}
    
    local buttonSize = modeConfig.buttonSize or slotsConfig.width
    local spacing = modeConfig.spacing or slotsConfig.spacing
    local ultimateSize = modeConfig.ultimateSize or (buttonSize + 6)
    local ultIconSize = modeConfig.ultIconSize or (ultimateSize - 3)
    local ultimateGap = BETTERUI_ORB_FRAMES.bars.ultimateGap
    
    local totalWidth = (5 * buttonSize) + (4 * spacing) + ultimateGap + ultimateSize
    local halfWidth = totalWidth / 2
    
    backBarContainer:SetDimensions(totalWidth, ultimateSize)
    
    for i = 1, 5 do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            btn:SetDimensions(buttonSize, buttonSize)
            btn:ClearAnchors()
            if i == 1 then
                btn:SetAnchor(LEFT, backBarContainer, CENTER, -halfWidth, 0)
            else
                local prevBtn = FindControl(backBarContainer, 'Button' .. (i-1))
                btn:SetAnchor(LEFT, prevBtn, RIGHT, spacing, 0)
            end
            
            local icon = btn:GetNamedChild("Icon")
            if icon then
                local innerSize = buttonSize - 3
                icon:ClearAnchors()
                icon:SetDimensions(innerSize, innerSize)
                icon:SetAnchor(CENTER, btn, CENTER, 0, 0)
            end

            local border = btn:GetNamedChild("Border")
            local backdrop = btn:GetNamedChild("Backdrop")
            if isGamePad then
                if border then border:SetHidden(true) end
                if backdrop then backdrop:SetHidden(false) end
            else
                if border then border:SetHidden(false) end
                if backdrop then backdrop:SetHidden(true) end
            end
        end
    end
    
    local ultBtn = FindControl(backBarContainer, 'Button6')
    if ultBtn then
        local btn5 = FindControl(backBarContainer, 'Button5')
        local ultOffsetX = (backBarCfg and backBarCfg.ultimate and backBarCfg.ultimate.offsetX) or 0
        local ultOffsetY = (backBarCfg and backBarCfg.ultimate and backBarCfg.ultimate.offsetY) or 0
        
        ultBtn:SetDimensions(ultimateSize, ultimateSize)
        ultBtn:ClearAnchors()
        ultBtn:SetAnchor(LEFT, btn5, RIGHT, ultimateGap + BETTERUI_ORB_FRAMES.bars.backUltimateOffsetX + ultOffsetX, ultOffsetY)
        
        -- Store references to glow/burst/loop capability
        ultBtn.readyBurst = ultBtn:GetNamedChild("ReadyBurst")
        ultBtn.readyLoop = ultBtn:GetNamedChild("ReadyLoop")
        ultBtn.glow = ultBtn:GetNamedChild("Glow")
        
        local icon = ultBtn:GetNamedChild("Icon")
        if icon then
            icon:ClearAnchors()
            icon:SetDimensions(ultIconSize, ultIconSize)
            icon:SetAnchor(CENTER, ultBtn, CENTER, 0, 0)
        end
        local border = ultBtn:GetNamedChild("Border")
        local backdrop = ultBtn:GetNamedChild("Backdrop")
        if isGamePad then
            if border then border:SetHidden(true) end
            if backdrop then backdrop:SetHidden(false) end
        else
            if border then border:SetHidden(false) end
            if backdrop then backdrop:SetHidden(true) end
        end
    end
end

function SkillBar.SetupBackBarTooltips(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    local slots = {3, 4, 5, 6, 7, 8}
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            btn:SetMouseEnabled(true)
            btn:SetHandler("OnMouseEnter", function(control)
                local category = control.hotbarCategory
                local slot = control.slotIndex or slotIndex
                
                -- Highlight
                local highlight = control:GetNamedChild("MouseOverHighlight")
                if highlight then highlight:SetHidden(false) end
                
                if category then
                    local slotType = GetSlotType(slot, category)
                    if slotType and slotType ~= ACTION_TYPE_NOTHING then
                        InitializeTooltip(AbilityTooltip, control, RIGHT, -5, 0)
                        AbilityTooltip:SetAction(slot, category)
                    end
                end
            end)
            btn:SetHandler("OnMouseExit", function(control)
                local highlight = control:GetNamedChild("MouseOverHighlight")
                if highlight then highlight:SetHidden(true) end
                ClearTooltip(AbilityTooltip)
            end)
        end
    end
end

function SkillBar.UpdateBackBarCooldowns(rootFrame)
    local activePair = GetActiveWeaponPairInfo()
    local backBarCategory = (activePair == ACTIVE_WEAPON_PAIR_MAIN) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end
    
    local slots = {3, 4, 5, 6, 7, 8}
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            local cooldownOverlay = btn:GetNamedChild("CooldownOverlay")
            local cooldownText = btn:GetNamedChild("CooldownText")
            local icon = btn:GetNamedChild("Icon")
            
            local abilityId = GetSlotBoundId(slotIndex, backBarCategory)
            local remaining = 0
            local showCooldown = false
            
            if abilityId and abilityId > 0 then
                local remMs, durMs = GetSlotCooldownInfo(slotIndex, backBarCategory)
                if remMs and remMs > 0 and durMs and durMs > 1500 then
                    remaining = remMs / 1000
                    showCooldown = true
                end
                if not showCooldown then
                    local effectRemaining = GetActionSlotEffectTimeRemaining(slotIndex, backBarCategory)
                    if effectRemaining and effectRemaining > 0 then
                        remaining = effectRemaining / 1000
                        showCooldown = true
                    end
                end
            end
            
            if cooldownOverlay and cooldownText then
                if showCooldown and remaining > 0.1 then
                    cooldownOverlay:SetHidden(false)
                    if icon then icon:SetDesaturation(1) end
                    cooldownText:SetHidden(false)
                    cooldownText:SetText(string.format("%.1f", remaining))
                else
                    cooldownOverlay:SetHidden(true)
                    cooldownText:SetHidden(true)
                    if icon then icon:SetDesaturation(0) end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------------------------
-- FRONT BAR LOGIC
-------------------------------------------------------------------------------------------------

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
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
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
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
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
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
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
            btn:SetMouseEnabled(true)
            btn:SetHandler("OnMouseEnter", function(control)
                local category = control.hotbarCategory
                local slot = control.slotIndex or mapping.slot
                
                -- Highlight
                local highlight = control:GetNamedChild("MouseOverHighlight")
                if highlight then highlight:SetHidden(false) end
                
                if category then
                    local slotType = GetSlotType(slot, category)
                    if slotType and slotType ~= ACTION_TYPE_NOTHING then
                        InitializeTooltip(AbilityTooltip, control, TOP, 0, 5) -- Tooltip above
                        AbilityTooltip:SetAction(slot, category)
                    end
                end
            end)
            btn:SetHandler("OnMouseExit", function(control)
                 local highlight = control:GetNamedChild("MouseOverHighlight")
                 if highlight then highlight:SetHidden(true) end
                 ClearTooltip(AbilityTooltip)
            end)
        end
    end
end

function SkillBar.SetupFrontBarKeybinds(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
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
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
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

-- Ultimate & Quickslot Updates
function SkillBar.PlayUltimateReadyAnimations(btn)
    local readyBurst = btn.readyBurst
    local readyLoop = btn.readyLoop
    local glow = btn.glow
    local glowAnim = btn.glowAnimation
    
    if not btn.readyBurstTimeline then
        btn.readyBurstTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ResourceOrbFrames_UltimateReadyBurst", readyBurst)
        btn.readyLoopTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ResourceOrbFrames_UltimateReadyLoop", readyLoop)
        
        btn.readyBurstTimeline:SetHandler("OnPlay", function()
            -- Sound is handled in UpdateFrontBarUltimateMeter to ensure it plays only once per threshold crossing
        end)
        
        local function OnStop(timeline)
             if timeline:GetProgress() == 1.0 then
                 readyBurst:SetHidden(true)
                 btn.readyLoopTimeline:PlayFromStart()
                 readyLoop:SetHidden(false)
             end
        end
        btn.readyBurstTimeline:SetHandler("OnStop", OnStop)
    end
    
    local isBursting = btn.readyBurstTimeline:IsPlaying()
    local isLooping = btn.readyLoopTimeline:IsPlaying()
    
    if not isBursting and not isLooping then
        readyBurst:SetHidden(false)
        btn.readyBurstTimeline:PlayFromStart()
        
        -- Also play glow animation
        if glowAnim then
             glowAnim:PingPong(0, 1, 500 * (1/3), 1) -- Bounce duration approx 167ms
        end
    elseif not isLooping and not isBursting then
         btn.readyLoopTimeline:PlayFromStart()
         readyLoop:SetHidden(false)
    end
end

function SkillBar.StopUltimateReadyAnimations(btn)
    if btn.readyBurstTimeline then
        btn.readyBurstTimeline:Stop()
        btn.readyLoopTimeline:Stop()
    end
    if btn.readyBurst then btn.readyBurst:SetHidden(true) end
    if btn.readyLoop then btn.readyLoop:SetHidden(true) end
    if btn.glowAnimation then btn.glowAnimation:Stop() end
    if btn.glow then btn.glow:SetAlpha(0) end
end

function SkillBar.UpdateFrontBarUltimateMeter(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
    
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    
    local CELLS_WIDE = 8
    local CELLS_HIGH = 4
    local TOTAL_FRAMES = 32
    
    local function SetSpriteFrame(texture, frameIndex, mirror)
        if not texture then return end
        local col = frameIndex % CELLS_WIDE
        local row = math.floor(frameIndex / CELLS_WIDE)
        local cellWidth = 1.0 / CELLS_WIDE
        local cellHeight = 1.0 / CELLS_HIGH
        local left = col * cellWidth
        local right = left + cellWidth
        local top = row * cellHeight
        local bottom = top + cellHeight
        
        if mirror then
            local temp = left
            left = right
            right = temp
        end
        texture:SetTextureCoords(left, right, top, bottom)
    end
    
    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local fillLeft = ultBtn:GetNamedChild("FillAnimationLeft")
        local fillRight = ultBtn:GetNamedChild("FillAnimationRight")
        if fillLeft and fillRight then
            local slotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
            local abilityCost = GetSlotAbilityCost(slotIndex, GetActiveHotbarCategory())
            local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
            
            if abilityCost and abilityCost > 0 then
                 local fillPercent = math.min(1, currentUltimate / abilityCost)
                 local frameIndex = math.floor(fillPercent * (TOTAL_FRAMES - 1))
                 SetSpriteFrame(fillLeft, frameIndex, false)
                 SetSpriteFrame(fillRight, frameIndex, true)
                 fillLeft:SetHidden(false); fillRight:SetHidden(false)
                 
                 -- Handle Ultimate Ready Animation
                 if currentUltimate >= abilityCost then
                      if not ultBtn.isUltimateReady then
                           ultBtn.isUltimateReady = true
                           SkillBar.PlayUltimateReadyAnimations(ultBtn)
                           PlaySound(SOUNDS.ABILITY_ULTIMATE_READY)
                      end
                 else
                      if ultBtn.isUltimateReady then
                           ultBtn.isUltimateReady = false
                           SkillBar.StopUltimateReadyAnimations(ultBtn)
                      end
                 end
            else
                 fillLeft:SetHidden(true); fillRight:SetHidden(true)
                 if ultBtn.isUltimateReady then
                      ultBtn.isUltimateReady = false
                      SkillBar.StopUltimateReadyAnimations(ultBtn)
                 end
            end
        end
    end
end

function SkillBar.UpdateFrontBarUltimateNumber(rootFrame)
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local countText = ultBtn:GetNamedChild("CountText")
        if countText then
             local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
             countText:SetText(currentUltimate)
        end
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
    
    -- Add Tooltip Handlers
    if not qsBtn.tooltipHandlersAdded then
        qsBtn:SetMouseEnabled(true)
        qsBtn:SetHandler("OnMouseEnter", function(control)
            local category = control.hotbarCategory
            local slot = control.slotIndex
            
            -- Highlight (Quickslot doesn't have MouseOverHighlight in template? It uses FrontBarButton template? No, it's created manually or likely uses FrontBarButton template if defined in XML)
            -- Wait, QuickslotButton is defined in ResourceOrbFrames.xml usually. Let's assume it might not have the child unless we check/add it.
            -- But if it uses FrontBarButton template, it has it.
            local highlight = control:GetNamedChild("MouseOverHighlight")
            if highlight then highlight:SetHidden(false) end
            
            if category and slot then
                local slotType = GetSlotType(slot, category)
                
                -- Try to show Item Tooltip for Items and Collectibles (using link)
                if slotType == ACTION_TYPE_ITEM or slotType == ACTION_TYPE_COLLECTIBLE then
                     local link = GetSlotItemLink(slot, category)
                     if link and link ~= "" then
                          InitializeTooltip(ItemTooltip, control, LEFT, 5, 0)
                          ItemTooltip:SetLink(link)
                          return
                     end
                end
                
                -- Fallback to AbilityTooltip for everything else or if link failed
                InitializeTooltip(AbilityTooltip, control, LEFT, 5, 0)
                AbilityTooltip:SetAction(slot, category)
            end
        end)
        qsBtn:SetHandler("OnMouseExit", function(control)
            local highlight = control:GetNamedChild("MouseOverHighlight")
            if highlight then highlight:SetHidden(true) end
            ClearTooltip(ItemTooltip)
            ClearTooltip(AbilityTooltip)
        end)
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
    else
        compBtn:SetHidden(true)
    end
end

-- Cooldowns for front bar
function SkillBar.UpdateFrontBarCooldowns(rootFrame)
    local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarCfg or not frontBarCfg.enabled then return end
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

-------------------------------------------------------------------------------------------------
-- MAIN BAR & LAYOUT ORCHESTRATION
-------------------------------------------------------------------------------------------------

function SkillBar.UpdateBarPositions(rootFrame)
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

function SkillBar.UpdateMainBarLayout(rootFrame)
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and { abilitySlotWidth = 67, abilitySlotOffsetX = 10 } or { abilitySlotWidth = 50, abilitySlotOffsetX = 2 }
    
    local width = layout.abilitySlotWidth
    local offset = layout.abilitySlotOffsetX
    local totalWidth = (6 * width) + (5 * offset)
    
    local barParent = FindControl(rootFrame, 'ActionBarContainer')
    if barParent then
        barParent:SetDimensions(totalWidth, width)
        if ZO_ActionBar1WeaponSwap then ZO_ActionBar1WeaponSwap:SetHidden(true) end
    end
end

function SkillBar.ApplyActionBarSkin(rootFrame, layout)
    local isGamePad = IsInGamepadPreferredMode()
    local template = isGamePad and 'ResourceOrbFrames_Double_Gamepad' or 'ResourceOrbFrames_Double_Keyboard'
    
    ZO_ActionBar1WeaponSwap:SetHidden(true)
    ZO_ActionBar1KeybindBG:SetHidden(true)
    ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1WeaponSwap, true)
    
    if not isGamePad then
        zo_callLater(function()
            for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
                local btn = ZO_ActionBar_GetButton(i)
                if btn and btn.buttonText then btn.buttonText:SetHidden(true) end
            end
            local qs = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            if qs and qs.buttonText then qs.buttonText:SetHidden(true) end
        end, 150)
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

function SkillBar.WeaponSwapAnimation(rootFrame)
    local settings = GetModuleSettings()
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')
    
    if not settings.weaponSwapAnimation or not backBarContainer or not frontBarContainer or not bgMiddle then
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
         
         local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
         local barOffsetX = frontBarCfg and frontBarCfg.offsetX or 0
         local barOffsetY = frontBarCfg and frontBarCfg.offsetY or 0
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
              local frontBarCfg = BETTERUI_ORB_FRAMES.bars.customFrontBar
              local frontBaseX = (frontBarCfg.offsetX or 0) + 10
              local frontBaseY = -15 + (frontBarCfg.offsetY or 0)
              
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
