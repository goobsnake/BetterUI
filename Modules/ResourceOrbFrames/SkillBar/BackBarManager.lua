--[[
File: Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua
Purpose: Manages the Back Bar layout, updates, and cooldown tracking.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
local GetModuleSettings = Utils.GetModuleSettings
local ClampTextSize = Utils.ClampTextSize

local function CanUseBackupBar()
    return GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()
end

-- Cached control references (populated by CacheBackBarControls during addon init)
local m_backBarButtonCache = {}
local m_backBarContainer = nil
local sharedCooldownCaches = SkillBar.SharedCooldownCaches
if not sharedCooldownCaches then
    sharedCooldownCaches = {
        effectDurationBySlotCategory = {},
        smoothedRemainBySlotCategory = {},
    }
    SkillBar.SharedCooldownCaches = sharedCooldownCaches
end
local m_backBarEffectDurationCache = sharedCooldownCaches.effectDurationBySlotCategory
local m_backBarCooldownVisualState = sharedCooldownCaches.smoothedRemainBySlotCategory
local SKILL_TEXT_SIZE_MIN = 12
local SKILL_TEXT_SIZE_MAX = 30

local function BuildCooldownStateKey(slotIndex, hotbarCategory)
    return string.format("%d_%d", slotIndex or -1, hotbarCategory or -1)
end


--[[
Function: CacheBackBarControls
Description: Caches all back bar control references for performance.
Rationale: Avoids repeated GetNamedChild/FindControl lookups in hot paths.
Mechanism: Uses CIM.ControlCache.CacheButtonChildren for each button.
References: Called during addon initialization after controls are created.
param: rootFrame (control) - The root ResourceOrbFrames control
]]
local function CacheBackBarControls(rootFrame)
    if not rootFrame then return end

    m_backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not m_backBarContainer then return end

    -- Cache buttons 1-6 (slots 3-8)
    for i = 1, 6 do
        local btn = FindControl(m_backBarContainer, 'Button' .. i)
        if btn then
            m_backBarButtonCache[i] = {
                control = btn,
                children = BETTERUI.CIM.ControlCache.CacheButtonChildren(btn),
            }
        end
    end
end

--- Helper to get cached back bar button
local function GetCachedBackBarButton(index)
    return m_backBarButtonCache[index]
end

local function ResetSmoothedCooldownRemaining(stateKey)
    if stateKey then
        m_backBarCooldownVisualState[stateKey] = nil
    end
end

local function GetSmoothedCooldownRemaining(stateKey, remainMs, durationMs)
    if not stateKey or not remainMs or remainMs <= 0 or not durationMs or durationMs <= 0 then
        return remainMs
    end

    local nowMs = GetGameTimeMilliseconds()
    local state = m_backBarCooldownVisualState[stateKey]
    if not state
        or state.durationMs ~= durationMs
        or remainMs > ((state.lastReportedRemainMs or remainMs) + 100) then
        m_backBarCooldownVisualState[stateKey] = {
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

local function UpdateBackBar(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end

    local settings = GetModuleSettings()
    if settings.hideBackBar then
        backBarContainer:SetHidden(true)
        return
    end

    if not CanUseBackupBar() then
        backBarContainer:SetHidden(true)
        return
    end

    local activePair = GetActiveWeaponPairInfo()
    local backBarCategory = (activePair == ACTIVE_WEAPON_PAIR_MAIN) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    local backBarOpacity = settings.backBarOpacity or 1

    local slots = { 3, 4, 5, 6, 7, 8 }

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

local function UpdateBackBarLayout(rootFrame)
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
            btn.cooldownRevealWidth = buttonSize
            btn.cooldownRevealHeight = buttonSize
            btn:ClearAnchors()
            if i == 1 then
                btn:SetAnchor(LEFT, backBarContainer, CENTER, -halfWidth, 0)
            else
                local prevBtn = FindControl(backBarContainer, 'Button' .. (i - 1))
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
        ultBtn.cooldownRevealWidth = ultimateSize
        ultBtn.cooldownRevealHeight = ultimateSize
        ultBtn:ClearAnchors()
        ultBtn:SetAnchor(LEFT, btn5, RIGHT, ultimateGap + BETTERUI_ORB_FRAMES.bars.backUltimateOffsetX + ultOffsetX,
            ultOffsetY)

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

local function SetupBackBarTooltips(rootFrame)
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end

    local slots = { 3, 4, 5, 6, 7, 8 }
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            -- Use common/shared TooltipManager
            SkillBar.SetupButtonTooltip(btn, slotIndex, nil, RIGHT, -5, 0)
        end
    end
end

local function UpdateBackBarCooldowns(rootFrame)
    local activePair = GetActiveWeaponPairInfo()
    local backBarCategory = (activePair == ACTIVE_WEAPON_PAIR_MAIN) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    local backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    if not backBarContainer then return end

    local settings = BETTERUI.GetModuleSettings("ResourceOrbFrames")
    local isGamePad = IsInGamepadPreferredMode()
    local cooldownSize = ClampTextSize(settings.cooldownTextSize, SKILL_TEXT_SIZE_MIN, SKILL_TEXT_SIZE_MAX, 27)
    local cooldownColor = settings.cooldownTextColor or { 0.86, 0.84, 0.13, 1 }
    local slots = { 3, 4, 5, 6, 7, 8 }
    for i, slotIndex in ipairs(slots) do
        local cached = GetCachedBackBarButton(i)
        local btn = (cached and cached.control) or FindControl(backBarContainer, 'Button' .. i)
        if btn then
            local children = cached and cached.children or {}
            local cooldownOverlay = children.CooldownOverlay or btn:GetNamedChild("CooldownOverlay")
            local cooldownEdge = children.CooldownEdge or btn:GetNamedChild("CooldownEdge")
            local cooldownText = children.CooldownText or btn:GetNamedChild("CooldownText")
            local icon = children.Icon or btn:GetNamedChild("Icon")

            local remainMs = 0
            local durationMs = 0
            local showCooldown = false
            local stateKey = BuildCooldownStateKey(slotIndex, backBarCategory)
            local effectCacheKey = stateKey

            local abilityId = GetSlotBoundId(slotIndex, backBarCategory)
            if abilityId and abilityId > 0 then
                local remMs, durMs = GetSlotCooldownInfo(slotIndex, backBarCategory)
                if remMs and remMs > 0 and durMs and durMs > 1500 then
                    remainMs = remMs
                    durationMs = durMs
                    showCooldown = true
                end

                if not showCooldown then
                    local effectRemaining = GetActionSlotEffectTimeRemaining(slotIndex, backBarCategory)
                    if effectRemaining and effectRemaining > 0 then
                        remainMs = effectRemaining
                        if not m_backBarEffectDurationCache[effectCacheKey]
                            or m_backBarEffectDurationCache[effectCacheKey] < effectRemaining then
                            m_backBarEffectDurationCache[effectCacheKey] = effectRemaining
                        end
                        durationMs = m_backBarEffectDurationCache[effectCacheKey]
                        showCooldown = true
                    else
                        m_backBarEffectDurationCache[effectCacheKey] = nil
                    end
                end
            else
                m_backBarEffectDurationCache[effectCacheKey] = nil
            end

            if cooldownOverlay and cooldownText then
                if showCooldown and remainMs > 0 and durationMs > 0 then
                    local visualRemainMs = GetSmoothedCooldownRemaining(stateKey, remainMs, durationMs)

                    if isGamePad then
                        local percentComplete = ApplyLinearCooldownVisuals(cooldownEdge, cooldownOverlay, btn,
                            visualRemainMs,
                            durationMs)
                        if icon then
                            if percentComplete ~= nil then
                                icon:SetDesaturation(1 - percentComplete)
                            else
                                icon:SetDesaturation(1)
                            end
                        end
                    else
                        if cooldownEdge then cooldownEdge:SetHidden(true) end
                        if cooldownOverlay then
                            cooldownOverlay:ClearAnchors()
                            cooldownOverlay:SetAnchor(TOPLEFT, btn, TOPLEFT, 0, 0)
                            cooldownOverlay:SetAnchor(BOTTOMRIGHT, btn, BOTTOMRIGHT, 0, 0)
                            cooldownOverlay:SetHidden(false)
                        end
                        if icon then icon:SetDesaturation(1) end
                    end

                    cooldownText:SetHidden(false)
                    cooldownText:SetText(string.format("%.1f", visualRemainMs / 1000))
                    cooldownText:SetDrawLayer(DL_OVERLAY)
                    cooldownText:SetDrawTier(DT_HIGH)
                    cooldownText:SetDrawLevel(10)
                    cooldownText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", cooldownSize))
                    cooldownText:SetColor(unpack(cooldownColor))
                else
                    ResetSmoothedCooldownRemaining(stateKey)
                    cooldownOverlay:SetHidden(true)
                    if cooldownEdge then cooldownEdge:SetHidden(true) end
                    cooldownText:SetHidden(true)
                    if icon then icon:SetDesaturation(0) end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------------------------
-- MODULE EXPORTS
-------------------------------------------------------------------------------------------------
SkillBar.CacheBackBarControls = CacheBackBarControls
SkillBar.UpdateBackBar = UpdateBackBar
SkillBar.UpdateBackBarLayout = UpdateBackBarLayout
SkillBar.SetupBackBarTooltips = SetupBackBarTooltips
SkillBar.UpdateBackBarCooldowns = UpdateBackBarCooldowns
