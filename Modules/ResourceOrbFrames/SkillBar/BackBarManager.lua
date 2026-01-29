--[[
File: Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua
Purpose: Manages the Back Bar layout, updates, and cooldown tracking.
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

local function CanUseBackupBar()
    return GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()
end

-- Cached control references (populated by CacheBackBarControls during addon init)
local m_backBarButtonCache = {}
local m_backBarContainer = nil

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

local function UpdateBackBar(rootFrame)
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
    local slots = { 3, 4, 5, 6, 7, 8 }
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

                    local size = settings.cooldownTextSize or 27
                    local color = settings.cooldownTextColor or { 0.86, 0.84, 0.13, 1 }
                    cooldownText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", size))
                    cooldownText:SetColor(unpack(color))
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
-- MODULE EXPORTS
-------------------------------------------------------------------------------------------------
SkillBar.CacheBackBarControls = CacheBackBarControls
SkillBar.UpdateBackBar = UpdateBackBar
SkillBar.UpdateBackBarLayout = UpdateBackBarLayout
SkillBar.SetupBackBarTooltips = SetupBackBarTooltips
SkillBar.UpdateBackBarCooldowns = UpdateBackBarCooldowns
