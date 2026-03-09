--[[
File: Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua
Purpose: Manages the Ultimate meter updates and ready animations.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
local ClampTextSize = Utils.ClampTextSize

local ULTIMATE_TEXT_SIZE_MIN = 12
local ULTIMATE_TEXT_SIZE_MAX = 30


local function ApplyUltimateTextAnchor(ultimateButtonControl, ultimateTextControl)
    if not ultimateButtonControl or not ultimateTextControl then
        return
    end

    local offsetX = BETTERUI_ULTIMATE_NUMBER_TEXT_OFFSET_X or 0
    local offsetY = BETTERUI_ULTIMATE_NUMBER_TEXT_OFFSET_Y or -20
    local textHeight = BETTERUI_ULTIMATE_NUMBER_TEXT_HEIGHT or 32

    ultimateTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ultimateTextControl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    ultimateTextControl:SetDimensions(0, textHeight)
    ultimateTextControl:ClearAnchors()
    ultimateTextControl:SetAnchor(BOTTOM, ultimateButtonControl, BOTTOM, offsetX, offsetY)
end

local function PlayUltimateReadyAnimations(btn)
    local readyBurst = btn.readyBurst
    local readyLoop = btn.readyLoop
    local glow = btn.glow
    local glowAnim = btn.glowAnimation

    if not btn.readyBurstTimeline then
        btn.readyBurstTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ResourceOrbFrames_UltimateReadyBurst",
            readyBurst)
        btn.readyLoopTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ResourceOrbFrames_UltimateReadyLoop",
            readyLoop)

        btn.readyBurstTimeline:SetHandler("OnPlay", function()
            -- Sound is handled in UpdateFrontBarUltimateMeter to ensure it plays only once per threshold crossing
        end)

        local function OnStop(timeline)
            if timeline:GetProgress() == 1.0 then
                if readyBurst then readyBurst:SetHidden(true) end
                btn.readyLoopTimeline:PlayFromStart()
                if readyLoop then readyLoop:SetHidden(false) end
            end
        end
        btn.readyBurstTimeline:SetHandler("OnStop", OnStop)
    end

    local isBursting = btn.readyBurstTimeline:IsPlaying()
    local isLooping = btn.readyLoopTimeline:IsPlaying()

    if not isBursting and not isLooping then
        if readyBurst then readyBurst:SetHidden(false) end
        btn.readyBurstTimeline:PlayFromStart()

        -- Also play glow animation
        if glowAnim then
            glowAnim:PingPong(0, 1, 500 * (1 / 3), 1) -- Bounce duration approx 167ms
        end
    elseif not isLooping and not isBursting then
        btn.readyLoopTimeline:PlayFromStart()
        if readyLoop then readyLoop:SetHidden(false) end
    end
end

local function StopUltimateReadyAnimations(btn)
    if btn.readyBurstTimeline then
        btn.readyBurstTimeline:Stop()
        btn.readyLoopTimeline:Stop()
    end
    if btn.readyBurst then btn.readyBurst:SetHidden(true) end
    if btn.readyLoop then btn.readyLoop:SetHidden(true) end
    if btn.glowAnimation then btn.glowAnimation:Stop() end
    if btn.glow then btn.glow:SetAlpha(0) end
end

local function UpdateFrontBarUltimateMeter(rootFrame)
    local frontBarCfg = BETTERUI.GetModuleSettings("ResourceOrbFrames").customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end

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
                        PlayUltimateReadyAnimations(ultBtn)
                        PlaySound(SOUNDS.ABILITY_ULTIMATE_READY)
                    end
                else
                    if ultBtn.isUltimateReady then
                        ultBtn.isUltimateReady = false
                        StopUltimateReadyAnimations(ultBtn)
                    end
                end
            else
                fillLeft:SetHidden(true); fillRight:SetHidden(true)
                if ultBtn.isUltimateReady then
                    ultBtn.isUltimateReady = false
                    StopUltimateReadyAnimations(ultBtn)
                end
            end
        end
    end
end

local function UpdateFrontBarUltimateNumber(rootFrame)
    local settings = BETTERUI.GetModuleSettings("ResourceOrbFrames")
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local countText = ultBtn:GetNamedChild("UltimateText")
        if countText then
            if settings.showUltimateNumber then
                local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
                countText:SetText(currentUltimate)
                countText:SetHidden(false)
                ApplyUltimateTextAnchor(ultBtn, countText)

                local size = ClampTextSize(settings.ultimateTextSize, ULTIMATE_TEXT_SIZE_MIN, ULTIMATE_TEXT_SIZE_MAX, 27)
                local color = settings.ultimateTextColor or { 1, 1, 1, 1 }
                -- Standardize font string format
                countText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", size))
                countText:SetColor(unpack(color))
            else
                countText:SetHidden(true)
            end
        end
    end
end

-------------------------------------------------------------------------------------------------
-- MODULE EXPORTS
-------------------------------------------------------------------------------------------------
SkillBar.PlayUltimateReadyAnimations = PlayUltimateReadyAnimations
SkillBar.StopUltimateReadyAnimations = StopUltimateReadyAnimations
SkillBar.UpdateFrontBarUltimateMeter = UpdateFrontBarUltimateMeter
SkillBar.UpdateFrontBarUltimateNumber = UpdateFrontBarUltimateNumber
