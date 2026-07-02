-- Modules/ResourceOrbFrames/SkillBar/FrontBarCooldowns.lua
-- Cooldown smoothing, visual cooldown rendering, and per-frame cooldown updates.
-- Extracted from FrontBarManager.lua for maintainability.

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
local ClampTextSize = Utils.ClampTextSize
-- Hot-path accessor: live settings table by reference (no deep clone per
-- 16ms tick). Read-only by convention.
local GetLiveSettings = (Utils.Settings and Utils.Settings.GetLive) or Utils.GetSettings
local CooldownUtils = SkillBar.CooldownUtils
local CONST = SkillBar.CONST or {}

local SKILL_TEXT_SIZE_MIN = 12
local SKILL_TEXT_SIZE_MAX = 30

local GetFrontBarButtonControl = Utils.GetFrontBarButtonControl

local function GetCurrentSceneName()
    local utils = BETTERUI.CIM and BETTERUI.CIM.Utils
    if utils and type(utils.GetCurrentSceneName) == "function" then
        return utils.GetCurrentSceneName()
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentSceneName) == "function" then
        local ok, sceneName = pcall(function() return SCENE_MANAGER:GetCurrentSceneName() end)
        if ok then return sceneName end
    end
    return nil
end

local function TraceFrontCooldown(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent and L.EnabledFor and L.CATEGORY and L.LEVEL) then return end
    -- Preflight before building any payload so scene/gamepad lookups and table
    -- allocation run only when tracing is active (BUI-DEEPDIVE-001 P2).
    if not L.EnabledFor(L.LEVEL.DEBUG, L.CATEGORY.ACTION) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "resourceOrbs"
    data.scene = GetCurrentSceneName()
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    L.TraceEvent(L.CATEGORY.ACTION, event, phase, data)
end

--- Sets icon desaturation only when the value changes, avoiding per-frame
--- redundant API calls in the cooldown hot path.
---@param iconControl table|nil Icon texture control
---@param desaturation number Desired desaturation value
local function SetIconDesaturation(iconControl, desaturation)
    if not iconControl then return end
    if iconControl.appliedDesaturation ~= desaturation then
        iconControl.appliedDesaturation = desaturation
        iconControl:SetDesaturation(desaturation)
    end
end

--- Pure decision for StartCooldownIfChanged (HUD-005): a radial restart is
--- needed when a NEW cooldown window begins — either the duration changed, or
--- the same duration was refreshed and the remaining time jumped back up (e.g. a
--- proc or early recast re-applies the cooldown before it ended). Without the
--- remain check the radial keeps animating the old, advanced window while the
--- timer text shows the refreshed value. The +100ms margin ignores normal
--- per-frame downward drift and minor upward API corrections, so the radial is
--- not restarted every tick.
---@param appliedDurationMs number|nil Duration of the currently-animating radial
---@param lastSeenRemainMs number|nil Remaining time observed on the previous tick
---@param durationMs number New cooldown duration
---@param remainMs number New remaining cooldown time
---@return boolean restart Whether the radial cooldown must be (re)started
local function ShouldRestartRadialCooldown(appliedDurationMs, lastSeenRemainMs, durationMs, remainMs)
    if appliedDurationMs ~= durationMs then
        return true
    end
    if lastSeenRemainMs ~= nil and remainMs > lastSeenRemainMs + 100 then
        return true
    end
    return false
end

--- Starts a radial cooldown only when a new cooldown window begins (a duration
--- change or a same-duration refresh), avoiding per-frame reset churn that would
--- freeze the radial animation in the non-gamepad cooldown hot path. The last
--- observed remaining time is latched every tick so a refresh (remaining jumps
--- up) is detected against the previous frame, not the value at last start.
---@param cooldown table Cooldown control
---@param remainMs number Remaining cooldown milliseconds
---@param durationMs number Total cooldown duration milliseconds
local function StartCooldownIfChanged(cooldown, remainMs, durationMs)
    local restart = ShouldRestartRadialCooldown(
        cooldown.appliedCooldownDurationMs, cooldown.lastSeenCooldownRemainMs, durationMs, remainMs)
    cooldown.lastSeenCooldownRemainMs = remainMs
    if not restart then
        return
    end
    cooldown.appliedCooldownDurationMs = durationMs
    cooldown:StartCooldown(remainMs, durationMs, CD_TYPE_RADIAL, nil, false)
end

-- QUICKSLOT COUNT + EMPTY STATE

local function GetQuickslotCountAnchorOffsets()
    local keybindOffsetX = BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_X or 0
    local keybindOffsetY = BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_Y or -2
    local buttonOffsetX = BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_X or 0
    local buttonOffsetY = BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_Y or 1
    return keybindOffsetX, keybindOffsetY, buttonOffsetX, buttonOffsetY
end

--- Positions the quickslot count label relative to button or keybind text.
---@param buttonControl table Quickslot button control
---@param countText table|nil Count label control (resolved from button if nil)
local function AnchorQuickslotCountText(buttonControl, countText)
    if not buttonControl then return end
    local label = countText or buttonControl:GetNamedChild("CountText")
    if not label then return end
    local buttonText = buttonControl:GetNamedChild("ButtonText")
    local keybindOffsetX, keybindOffsetY, buttonOffsetX, buttonOffsetY = GetQuickslotCountAnchorOffsets()
    label:ClearAnchors()
    if buttonText then
        label:SetAnchor(TOP, buttonText, BOTTOM, keybindOffsetX, keybindOffsetY)
    else
        label:SetAnchor(TOP, buttonControl, BOTTOM, buttonOffsetX, buttonOffsetY)
    end
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
end

--- Applies static quickslot count styling (anchor, font, color), latched so
--- the 16ms tick only re-applies it when style-affecting settings change
--- (same pattern as ApplyUltimateNumberStyle in UltimateManager.lua).
---@param buttonControl table Quickslot button control
---@param countText table Count label control
---@param settings table Module settings (live table)
local function ApplyQuickslotCountStyle(buttonControl, countText, settings)
    local textSize = ClampTextSize(settings.quickslotTextSize, SKILL_TEXT_SIZE_MIN, SKILL_TEXT_SIZE_MAX, 27)
    local color = settings.quickslotTextColor or { 1, 1, 1, 1 }
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    if countText.appliedTextSize == textSize and countText.appliedTextR == r
        and countText.appliedTextG == g and countText.appliedTextB == b
        and countText.appliedTextA == a then
        return
    end
    countText.appliedTextSize = textSize
    countText.appliedTextR, countText.appliedTextG, countText.appliedTextB, countText.appliedTextA = r, g, b, a

    countText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", textSize))
    countText:SetColor(r, g, b, a)
    AnchorQuickslotCountText(buttonControl, countText)
end

--- Applies static cooldown timer text styling (draw layer/tier/level, font,
--- color), latched so the 16ms tick only re-applies it on settings change.
---@param label table Timer text label control
---@param textSize number Clamped cooldown text size
---@param color table Cooldown text color {r, g, b, a}
---@param applyFont boolean Whether this label's font follows the text size
local function ApplyCooldownTextStyle(label, textSize, color, applyFont)
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
    if applyFont then
        label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", textSize))
    end
    label:SetColor(r, g, b, a)
end

--- Updates quickslot stack count and empty-slot visuals.
---@param buttonControl table Quickslot button control
---@param children table|nil Cached child control references
---@param settings table Module settings
---@param slotIndex number Action bar slot index
---@param hotbarCategory number Hotbar category constant
---@return boolean hasItem Whether the slot contains an item
local function UpdateQuickslotCountAndEmptyState(buttonControl, children, settings, slotIndex, hotbarCategory)
    if not buttonControl then return false end
    local slotType = GetSlotType(slotIndex, hotbarCategory)
    local isItemSlot = slotType == ACTION_TYPE_ITEM
    local count = nil
    if isItemSlot then count = GetSlotItemCount(slotIndex, hotbarCategory) or 0 end
    local showCount = settings.showQuickslotCount ~= false
    local countText = (children and children.CountText) or buttonControl:GetNamedChild("CountText")
    if countText then
        ApplyQuickslotCountStyle(buttonControl, countText, settings)
        if showCount and isItemSlot and count ~= nil then
            if count ~= countText.appliedText then
                countText.appliedText = count
                countText:SetText(count)
            end
            if countText.appliedHidden ~= false then
                countText.appliedHidden = false
                countText:SetHidden(false)
            end
        else
            if countText.appliedHidden ~= true then
                countText.appliedHidden = true
                countText:SetHidden(true)
            end
        end
    end
    local isEmpty = isItemSlot and (count or 0) <= 0
    local unusableOverlay = (children and children.UnusableOverlay) or buttonControl:GetNamedChild("UnusableOverlay")
    if unusableOverlay then
        local hidden = not isEmpty
        if unusableOverlay.appliedHidden ~= hidden then
            unusableOverlay.appliedHidden = hidden
            unusableOverlay:SetHidden(hidden)
        end
    end
    buttonControl.quickslotCount = count
    buttonControl.quickslotEmpty = isEmpty
    local traceState = table.concat({
        tostring(slotIndex),
        tostring(hotbarCategory),
        tostring(slotType),
        tostring(count),
        tostring(showCount),
        tostring(isEmpty),
        tostring(countText ~= nil),
        tostring(unusableOverlay ~= nil),
    }, ":")
    if buttonControl._betteruiQuickslotCountTraceState ~= traceState then
        buttonControl._betteruiQuickslotCountTraceState = traceState
        TraceFrontCooldown("resource_orbs.quickslot_count", "state", {
            fn = "SkillBar.UpdateQuickslotCountAndEmptyState",
            slot = slotIndex,
            category = hotbarCategory,
            slotType = slotType,
            isItemSlot = isItemSlot,
            count = count,
            showCount = showCount,
            empty = isEmpty,
            hasCountText = countText ~= nil,
            hasUnusableOverlay = unusableOverlay ~= nil,
        })
    end
    return isEmpty
end

-- COOLDOWN SLOT MAPPINGS

local function BuildFrontBarCooldownMappings(activeCategory, currentQuickslot)
    local slotMappings = {}
    local frontBarSlots = CONST.FRONT_BAR_SLOTS or {}
    for _, mapping in ipairs(frontBarSlots) do
        slotMappings[#slotMappings + 1] = {
            buttonName = mapping.buttonName,
            slot = mapping.slot,
            category = activeCategory,
        }
    end

    slotMappings[#slotMappings + 1] = {
        buttonName = "QuickslotButton",
        slot = currentQuickslot,
        category = HOTBAR_CATEGORY_QUICKSLOT_WHEEL,
    }
    slotMappings[#slotMappings + 1] = {
        buttonName = "CompanionButton",
        slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1,
        category = HOTBAR_CATEGORY_COMPANION,
    }

    return slotMappings
end

-- Mapping cache: the slot mappings only change with the active hotbar
-- category or the current quickslot, so rebuild only on those transitions
-- instead of allocating eight tables per 16ms tick.
local m_cachedSlotMappings = nil
local m_cachedMappingCategory = nil
local m_cachedMappingQuickslot = nil

local function GetFrontBarCooldownMappings(activeCategory)
    local currentQuickslot = GetCurrentQuickslot()
    if not m_cachedSlotMappings
        or m_cachedMappingCategory ~= activeCategory
        or m_cachedMappingQuickslot ~= currentQuickslot then
        m_cachedSlotMappings = BuildFrontBarCooldownMappings(activeCategory, currentQuickslot)
        m_cachedMappingCategory = activeCategory
        m_cachedMappingQuickslot = currentQuickslot
    end
    return m_cachedSlotMappings
end

-- UPDATE FRONT BAR COOLDOWNS (per-frame)

--- Updates cooldown overlays and text for all front bar buttons.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateFrontBarCooldowns(rootFrame)
    local settings = GetLiveSettings()
    local frontBarCfg = settings.customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local isGamepad = IsInGamepadPreferredMode()
    local slotMapping = GetFrontBarCooldownMappings(activeCategory)

    local cooldownSize = ClampTextSize(settings.cooldownTextSize, SKILL_TEXT_SIZE_MIN, SKILL_TEXT_SIZE_MAX, 27)
    local cooldownColor = settings.cooldownTextColor or { 0.86, 0.84, 0.13, 1 }

    -- Access shared button cache from FrontBarManager
    local buttonCache = SkillBar._frontBarButtonCache

    for _, mapping in ipairs(slotMapping) do
        local cachedBtn = buttonCache and buttonCache[mapping.buttonName] or nil
        local btn = (cachedBtn and cachedBtn.control)
            or GetFrontBarButtonControl(rootFrame, frontBarContainer, mapping.buttonName)

        if btn and not btn:IsHidden() then
            local children = cachedBtn and cachedBtn.children or {}
            local baseDesaturation = 0

            if mapping.buttonName == "QuickslotButton" then
                local isQuickslotEmpty = UpdateQuickslotCountAndEmptyState(btn, children, settings, mapping.slot, mapping.category)
                if isQuickslotEmpty then baseDesaturation = 1 end
            end

            local showCooldown, remainMs, durationMs, cooldownStateKey = CooldownUtils.ResolveCooldownWindow(
                mapping.slot,
                mapping.category)

            if mapping.buttonName == "QuickslotButton" and not settings.showQuickslotCooldown then
                showCooldown = false
            end

            local cooldown = children.Cooldown or btn:GetNamedChild("Cooldown")
            local cooldownEdge = children.CooldownEdge or btn:GetNamedChild("CooldownEdge")
            local cooldownOverlay = children.CooldownOverlay or btn:GetNamedChild("CooldownOverlay")
            local iconControl = children.Icon or btn:GetNamedChild("Icon")
            local timerText = children.TimerText or btn:GetNamedChild("TimerText")
            local altTimerText = children.CooldownText or btn:GetNamedChild("CooldownText")
            local abilityId = type(GetSlotBoundId) == "function" and GetSlotBoundId(mapping.slot, mapping.category) or nil

            if showCooldown then
                local cooldownStateChanged = CooldownUtils.ReportButtonCooldownState
                    and CooldownUtils.ReportButtonCooldownState(btn, true)
                    or false
                if cooldownStateChanged then
                    TraceFrontCooldown("resource_orbs.cooldown", "start", {
                        button = mapping.buttonName,
                        slot = mapping.slot,
                        category = mapping.category,
                        abilityId = abilityId,
                        remainMs = remainMs,
                        duration = durationMs,
                        stateKey = cooldownStateKey,
                    })
                end
                local visualRemainMs = CooldownUtils.GetSmoothedRemaining(cooldownStateKey, remainMs, durationMs)
                if isGamepad then
                    if cooldown and cooldown.appliedHidden ~= true then
                        cooldown.appliedHidden = true
                        cooldown:SetHidden(true)
                        cooldown.appliedCooldownDurationMs = nil
                        cooldown.lastSeenCooldownRemainMs = nil
                    end
                    local percentComplete = CooldownUtils.ApplyLinearVisuals(cooldownEdge, cooldownOverlay, btn, visualRemainMs, durationMs)
                    if iconControl then
                        if percentComplete ~= nil then
                            local cooldownDesaturation = 1 - percentComplete
                            if cooldownDesaturation < baseDesaturation then
                                cooldownDesaturation = baseDesaturation
                            end
                            SetIconDesaturation(iconControl, cooldownDesaturation)
                        else
                            SetIconDesaturation(iconControl, 1)
                        end
                    end
                else
                    SetIconDesaturation(iconControl, 1)
                    CooldownUtils.HideLinearVisuals(cooldownEdge, cooldownOverlay)
                    if cooldown then
                        StartCooldownIfChanged(cooldown, remainMs, durationMs)
                        if cooldown.appliedHidden ~= false then
                            cooldown.appliedHidden = false
                            cooldown:SetHidden(false)
                        end
                    end
                end

                local textToSet = string.format("%.1f", visualRemainMs / 1000)
                if timerText then
                    if textToSet ~= timerText.appliedText then
                        timerText.appliedText = textToSet
                        timerText:SetText(textToSet)
                    end
                    if timerText.appliedHidden ~= false then
                        timerText.appliedHidden = false
                        timerText:SetHidden(false)
                    end
                    ApplyCooldownTextStyle(timerText, cooldownSize, cooldownColor, true)
                elseif altTimerText then
                    if textToSet ~= altTimerText.appliedText then
                        altTimerText.appliedText = textToSet
                        altTimerText:SetText(textToSet)
                    end
                    if altTimerText.appliedHidden ~= false then
                        altTimerText.appliedHidden = false
                        altTimerText:SetHidden(false)
                    end
                    ApplyCooldownTextStyle(altTimerText, cooldownSize, cooldownColor, false)
                end
            else
                local cooldownStateChanged = CooldownUtils.ReportButtonCooldownState
                    and CooldownUtils.ReportButtonCooldownState(btn, false)
                    or false
                if cooldownStateChanged then
                    TraceFrontCooldown("resource_orbs.cooldown", "end", {
                        button = mapping.buttonName,
                        slot = mapping.slot,
                        category = mapping.category,
                        abilityId = abilityId,
                        remainMs = remainMs,
                        duration = durationMs,
                        stateKey = cooldownStateKey,
                    })
                end
                CooldownUtils.ResetSmoothedRemaining(cooldownStateKey)
                SetIconDesaturation(iconControl, baseDesaturation)
                CooldownUtils.HideLinearVisuals(cooldownEdge, cooldownOverlay)
                if cooldown then
                    if cooldown.appliedHidden ~= true then
                        cooldown.appliedHidden = true
                        cooldown:SetHidden(true)
                    end
                    cooldown.appliedCooldownDurationMs = nil
                    cooldown.lastSeenCooldownRemainMs = nil
                end
                if timerText and timerText.appliedHidden ~= true then
                    timerText.appliedHidden = true
                    timerText:SetHidden(true)
                end
                if altTimerText and altTimerText.appliedHidden ~= true then
                    altTimerText.appliedHidden = true
                    altTimerText:SetHidden(true)
                end
            end

            local stackCountText = children.StackCountText or btn:GetNamedChild("StackCountText")
            if stackCountText then
                local stackCount = GetActionSlotEffectStackCount(mapping.slot, mapping.category)
                if stackCount and stackCount > 0 then
                    if stackCount ~= stackCountText.appliedText then
                        stackCountText.appliedText = stackCount
                        stackCountText:SetText(stackCount)
                    end
                    if stackCountText.appliedHidden ~= false then
                        stackCountText.appliedHidden = false
                        stackCountText:SetHidden(false)
                    end
                    -- Static draw ordering: latch once instead of per tick.
                    if not stackCountText.appliedDrawOrder then
                        stackCountText.appliedDrawOrder = true
                        stackCountText:SetDrawLayer(DL_OVERLAY)
                        stackCountText:SetDrawTier(DT_HIGH)
                        stackCountText:SetDrawLevel(10)
                    end
                else
                    if stackCountText.appliedHidden ~= true then
                        stackCountText.appliedHidden = true
                        stackCountText:SetHidden(true)
                    end
                end
            end
        end
    end
end

-- MODULE EXPORTS
SkillBar.UpdateFrontBarCooldowns = UpdateFrontBarCooldowns
SkillBar.AnchorQuickslotCountText = AnchorQuickslotCountText
SkillBar.UpdateQuickslotCountAndEmptyState = UpdateQuickslotCountAndEmptyState
-- Exported for unit tests (HUD-005 radial restart-on-refresh logic).
SkillBar.ShouldRestartRadialCooldown = ShouldRestartRadialCooldown
SkillBar.StartCooldownIfChanged = StartCooldownIfChanged
