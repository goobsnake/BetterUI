--[[
File: Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua
Purpose: Manages the Back Bar layout, updates, and cooldown tracking.
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
-- Hot-path accessor: live settings table by reference (no deep clone per
-- 16ms tick). Read-only by convention.
local GetLiveSettings = (Utils.Settings and Utils.Settings.GetLive) or Utils.GetSettings
local ClampTextSize = Utils.ClampTextSize
local CooldownUtils = SkillBar.CooldownUtils
local CONST = SkillBar.CONST or {}

-- Cached control references (populated by CacheBackBarControls during addon init)
local m_backBarButtonCache = {}
local m_backBarContainer = nil
local BACK_BAR_SLOTS = CONST.BACK_BAR_SLOTS or { 3, 4, 5, 6, 7, 8 }
local SKILL_TEXT_SIZE_MIN = 12
local SKILL_TEXT_SIZE_MAX = 30

local function TraceBackBar(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "backBar"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.ACTION or categories.STATE, event, phase, data)
end

local function CanUseBackBar()
    return GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()
end

local function GetBackBarContainer(rootFrame)
    if m_backBarContainer then
        return m_backBarContainer
    end
    if not rootFrame then
        return nil
    end
    m_backBarContainer = FindControl(rootFrame, 'BackBarContainer')
    return m_backBarContainer
end

local function GetBackBarHotbarCategory()
    if GetActiveWeaponPairInfo() == ACTIVE_WEAPON_PAIR_MAIN then
        return HOTBAR_CATEGORY_BACKUP
    end
    return HOTBAR_CATEGORY_PRIMARY
end

--[[
Function: CacheBackBarControls
Caches all back bar control references for performance.
References: Called during addon initialization after controls are created.
param: rootFrame (control) - The root ResourceOrbFrames control
]]
---@param rootFrame table Root ResourceOrbFrames control
local function CacheBackBarControls(rootFrame)
    if not rootFrame then return end

    m_backBarContainer = GetBackBarContainer(rootFrame)
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

--- Updates back bar button icons and visibility.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateBackBar(rootFrame)
    local backBarContainer = GetBackBarContainer(rootFrame)
    if not backBarContainer then return end

    local settings = GetLiveSettings()
    if settings.hideBackBar then
        backBarContainer:SetHidden(true)
        TraceBackBar("resource_orbs.back_bar", "updated", {
            fn = "UpdateBackBar",
            hidden = true,
            reason = "settingHidden",
            slotCount = #BACK_BAR_SLOTS,
        })
        return
    end

    if not CanUseBackBar() then
        backBarContainer:SetHidden(true)
        TraceBackBar("resource_orbs.back_bar", "updated", {
            fn = "UpdateBackBar",
            hidden = true,
            reason = "weaponSwapLocked",
            slotCount = #BACK_BAR_SLOTS,
        })
        return
    end

    local backBarCategory = GetBackBarHotbarCategory()
    local backBarOpacity = settings.backBarOpacity or 1

    local slots = BACK_BAR_SLOTS
    local visibleSlots = 0

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
                if icon and icon ~= '' then
                    visibleSlots = visibleSlots + 1
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
    TraceBackBar("resource_orbs.back_bar", "updated", {
        fn = "UpdateBackBar",
        hidden = false,
        category = backBarCategory,
        opacity = backBarOpacity,
        slotCount = #slots,
        visibleSlots = visibleSlots,
    })
end

--- Updates back bar button sizes, positions, and anchor layout.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateBackBarLayout(rootFrame)
    local backBarContainer = GetBackBarContainer(rootFrame)
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
    TraceBackBar("resource_orbs.back_bar_layout", "applied", {
        fn = "UpdateBackBarLayout",
        buttonSize = buttonSize,
        spacing = spacing,
        ultimateSize = ultimateSize,
        totalWidth = totalWidth,
        gamepad = isGamePad,
    })
end

--- Sets up tooltip handlers for back bar buttons.
---@param rootFrame table Root ResourceOrbFrames control
local function SetupBackBarTooltips(rootFrame)
    local backBarContainer = GetBackBarContainer(rootFrame)
    if not backBarContainer then return end

    local slots = BACK_BAR_SLOTS
    for i, slotIndex in ipairs(slots) do
        local btn = FindControl(backBarContainer, 'Button' .. i)
        if btn then
            -- Use common/shared TooltipManager
            SkillBar.SetupButtonTooltip(btn, slotIndex, nil, RIGHT, -5, 0)
        end
    end
end

--- Applies static cooldown text styling (draw order, font, color), latched so
--- the per-frame tick only re-applies it when style-affecting settings change
--- (same pattern as ApplyUltimateNumberStyle in UltimateManager.lua).
---@param label table Cooldown text label control
---@param textSize number Clamped cooldown text size
---@param color table Cooldown text color {r, g, b, a}
local function ApplyCooldownTextStyle(label, textSize, color)
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    if label.appliedTextSize == textSize and label.appliedTextR == r
        and label.appliedTextG == g and label.appliedTextB == b
        and label.appliedTextA == a then
        return
    end
    label.appliedTextSize = textSize
    label.appliedTextR, label.appliedTextG, label.appliedTextB, label.appliedTextA = r, g, b, a

    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawTier(DT_HIGH)
    label:SetDrawLevel(10)
    label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", textSize))
    label:SetColor(r, g, b, a)
end

--- Updates back bar cooldown overlays, text, and reveal animations.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateBackBarCooldowns(rootFrame)
    local backBarCategory = GetBackBarHotbarCategory()
    local backBarContainer = GetBackBarContainer(rootFrame)
    if not backBarContainer then return end
    -- Nothing to render while the back bar is hidden; skip the 6-slot scan.
    if backBarContainer.IsHidden and backBarContainer:IsHidden() then return end

    local settings = GetLiveSettings()
    local isGamePad = IsInGamepadPreferredMode()
    local cooldownSize = ClampTextSize(settings.cooldownTextSize, SKILL_TEXT_SIZE_MIN, SKILL_TEXT_SIZE_MAX, 27)
    local cooldownColor = settings.cooldownTextColor or { 0.86, 0.84, 0.13, 1 }
    local slots = BACK_BAR_SLOTS
    for i, slotIndex in ipairs(slots) do
        local cached = GetCachedBackBarButton(i)
        local button = (cached and cached.control) or FindControl(backBarContainer, 'Button' .. i)
        if button then
            local children = cached and cached.children or {}
            local cooldownOverlay = children.CooldownOverlay or button:GetNamedChild("CooldownOverlay")
            local cooldownEdge = children.CooldownEdge or button:GetNamedChild("CooldownEdge")
            local cooldownText = children.CooldownText or button:GetNamedChild("CooldownText")
            local icon = children.Icon or button:GetNamedChild("Icon")

            local abilityId = GetSlotBoundId(slotIndex, backBarCategory)
            local showCooldown, remainMs, durationMs, stateKey = CooldownUtils.ResolveCooldownWindow(
                slotIndex,
                backBarCategory,
                abilityId and abilityId > 0)

            if cooldownOverlay and cooldownText then
                if showCooldown and remainMs > 0 and durationMs > 0 then
                    if button._betteruiLastCooldownState ~= true then
                        button._betteruiLastCooldownState = true
                        if BETTERUI.Log then
                            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "cooldown start", { buttonIndex = i, slot = slotIndex, hotbarCategory = backBarCategory, abilityId = abilityId, remainMs = remainMs, durationMs = durationMs, stateKey = stateKey })
                        end
                    end
                    local visualRemainMs = CooldownUtils.GetSmoothedRemaining(stateKey, remainMs, durationMs)

                    if isGamePad then
                        local percentComplete = CooldownUtils.ApplyLinearVisuals(cooldownEdge, cooldownOverlay, button,
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
                            cooldownOverlay:SetAnchor(TOPLEFT, button, TOPLEFT, 0, 0)
                            cooldownOverlay:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, 0, 0)
                            cooldownOverlay:SetHidden(false)
                        end
                        if icon then icon:SetDesaturation(1) end
                    end

                    cooldownText:SetHidden(false)
                    cooldownText:SetText(string.format("%.1f", visualRemainMs / 1000))
                    ApplyCooldownTextStyle(cooldownText, cooldownSize, cooldownColor)
                else
                    if button._betteruiLastCooldownState == true then
                        button._betteruiLastCooldownState = false
                        if BETTERUI.Log then
                            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "cooldown end", { buttonIndex = i, slot = slotIndex, hotbarCategory = backBarCategory, abilityId = abilityId, remainMs = remainMs, durationMs = durationMs, stateKey = stateKey })
                        end
                    end
                    CooldownUtils.ResetSmoothedRemaining(stateKey)
                    cooldownOverlay:SetHidden(true)
                    if cooldownEdge then cooldownEdge:SetHidden(true) end
                    cooldownText:SetHidden(true)
                    if icon then icon:SetDesaturation(0) end
                end
            end
        end
    end
end

-- MODULE EXPORTS
SkillBar.CacheBackBarControls = CacheBackBarControls
SkillBar.UpdateBackBar = UpdateBackBar
SkillBar.UpdateBackBarLayout = UpdateBackBarLayout
SkillBar.SetupBackBarTooltips = SetupBackBarTooltips
SkillBar.UpdateBackBarCooldowns = UpdateBackBarCooldowns
SkillBar._BackBarInternals = {
    CanUseBackBar = CanUseBackBar,
    CanUseBackupBar = CanUseBackBar,
    GetBackBarContainer = GetBackBarContainer,
    GetBackBarHotbarCategory = GetBackBarHotbarCategory,
    GetCachedBackBarButton = GetCachedBackBarButton,
}
