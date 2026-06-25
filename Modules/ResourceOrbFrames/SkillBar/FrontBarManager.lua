--[[
File: Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua
Purpose: Manages the Front Bar layout, updates, keybinds, and usability.

Related modules (loaded before this file):
  CooldownUtils.lua         — Shared cooldown state and rendering helpers
  FrontBarPressFeedback.lua — Press feedback bounce/flash system
  FrontBarCooldowns.lua     — Cooldown smoothing and per-frame cooldown updates
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
local GetSettings = Utils.GetSettings
-- Hot-path accessor: live settings table by reference (no deep clone per
-- 100ms tick). Read-only by convention.
local GetLiveSettings = (Utils.Settings and Utils.Settings.GetLive) or Utils.GetSettings
local CooldownUtils = SkillBar.CooldownUtils
local CONST = SkillBar.CONST or {}
local COOLDOWN_DURATION_THRESHOLD = CONST.COOLDOWN_DURATION_THRESHOLD or 1500
-- Canonical keybind constants (SkillBar/Constants.lua)
local SLOT_KEYBINDS = CONST.SLOT_KEYBINDS or {}
local HIDE_UNBOUND = CONST.HIDE_UNBOUND == true
local FRONT_BAR_SLOTS = CONST.FRONT_BAR_SLOTS or {
    { buttonName = "Button1",        slot = 3 },
    { buttonName = "Button2",        slot = 4 },
    { buttonName = "Button3",        slot = 5 },
    { buttonName = "Button4",        slot = 6 },
    { buttonName = "Button5",        slot = 7 },
    { buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 },
}

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

local function TraceFrontBar(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "resourceOrbs"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.ACTION, event, phase, data)
end

-- Expose button cache to sibling modules (FrontBarCooldowns, FrontBarPressFeedback)
SkillBar._frontBarButtonCache = m_buttonCache

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

local function FindFrontBarOptionalButton(rootFrame, controlName)
    if m_frontBarContainer then
        local containerControl = FindControl(m_frontBarContainer, controlName)
        if containerControl then
            return containerControl
        end
    end
    if not rootFrame then
        return nil
    end
    return FindControl(rootFrame, controlName)
end

local function HasInsufficientUltimate(slotIndex, hotbarCategory)
    local ultimateSlotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX and (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or nil
    if slotIndex ~= ultimateSlotIndex then return false end
    local abilityCost = GetSlotAbilityCost(slotIndex, COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE, hotbarCategory)
    if type(abilityCost) ~= "number" or abilityCost <= 0 then return false end
    local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE)
    if type(currentUltimate) ~= "number" then return false end
    return currentUltimate < abilityCost
end

local function ShouldSuppressUnusableOverlayForCooldown(slotIndex, hotbarCategory)
    local remainMs, durationMs, isGlobalCooldown = GetSlotCooldownInfo(slotIndex, hotbarCategory)
    if remainMs and remainMs > 0 and durationMs and durationMs > COOLDOWN_DURATION_THRESHOLD and not isGlobalCooldown then
        return true
    end
    local effectRemaining = GetActionSlotEffectTimeRemaining(slotIndex, hotbarCategory)
    return effectRemaining and effectRemaining > 0
end

-- CONTROL CACHING

--- Caches front bar button controls and their children for efficient lookup.
---@param rootFrame table Root ResourceOrbFrames control
local function CacheFrontBarControls(rootFrame)
    if not rootFrame then return end
    m_frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not m_frontBarContainer then return end

    for _, mapping in ipairs(FRONT_BAR_SLOTS) do
        local btn = FindControl(m_frontBarContainer, mapping.buttonName)
        if btn then
            m_buttonCache[mapping.buttonName] = {
                control = btn,
                children = BETTERUI.CIM.ControlCache.CacheButtonChildren(btn),
            }
        end
    end

    m_quickslotBtn = FindFrontBarOptionalButton(rootFrame, 'QuickslotButton')
    if m_quickslotBtn then
        m_buttonCache["QuickslotButton"] = {
            control = m_quickslotBtn,
            children = BETTERUI.CIM.ControlCache.CacheButtonChildren(m_quickslotBtn),
        }
    end

    m_companionBtn = FindFrontBarOptionalButton(rootFrame, 'CompanionButton')
    if m_companionBtn then
        m_buttonCache["CompanionButton"] = {
            control = m_companionBtn,
            children = BETTERUI.CIM.ControlCache.CacheButtonChildren(m_companionBtn),
        }
    end
end

-- HIDE NATIVE ACTION BAR

--- Hides the native ESO action bar and timer.
local function HideNativeActionBar()
    if ZO_ActionBar1 and ZO_ActionBar1.SetHidden then
        ZO_ActionBar1:SetHidden(true)
        if ZO_ActionBar1.SetAlpha then ZO_ActionBar1:SetAlpha(0) end
    end
    if ZO_ActionBarTimer and ZO_ActionBarTimer.SetHidden then
        ZO_ActionBarTimer:SetHidden(true)
    end
end

--- Restores the native ESO action bar and timer after ResourceOrbFrames is disabled.
local function RestoreNativeActionBar()
    if ZO_ActionBar1 and ZO_ActionBar1.SetHidden then
        ZO_ActionBar1:SetHidden(false)
        if ZO_ActionBar1.SetAlpha then ZO_ActionBar1:SetAlpha(1) end
    end
    if ZO_ActionBarTimer and ZO_ActionBarTimer.SetHidden then
        ZO_ActionBarTimer:SetHidden(false)
    end
    if ZO_ActionBar1WeaponSwap then
        if ZO_WeaponSwap_SetPermanentlyHidden then
            ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1WeaponSwap, false)
        end
        if ZO_ActionBar1WeaponSwap.SetHidden then ZO_ActionBar1WeaponSwap:SetHidden(false) end
    end
    if ZO_ActionBar1KeybindBG and ZO_ActionBar1KeybindBG.SetHidden then
        ZO_ActionBar1KeybindBG:SetHidden(false)
    end
end

-- UPDATE FRONT BAR (icons, slot data, highlights)

--- Updates front bar button icons, slot data, and highlights.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateFrontBar(rootFrame)
    local frontBarCfg = GetLiveSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local activeCategory = GetActiveHotbarCategory()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local slotMapping = FRONT_BAR_SLOTS
    local traceSlots = {}
    local stateParts = {}

    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            local iconControl = btn:GetNamedChild("Icon")
            local slotTexture = GetSlotTexture(mapping.slot, activeCategory)
            local abilityId = type(GetSlotBoundId) == "function" and GetSlotBoundId(mapping.slot, activeCategory) or nil
            local hasHighlight = ActionSlotHasActivationHighlight(mapping.slot, activeCategory)
            local hasCostFailure = ActionSlotHasCostFailure(mapping.slot, activeCategory)
            local hasStateFailure = ActionSlotHasNonCostStateFailure(mapping.slot, activeCategory)
            local isUsable = not hasCostFailure and not hasStateFailure
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
                highlight:SetHidden(not (hasHighlight and isUsable))
            end
            table.insert(traceSlots, {
                buttonName = mapping.buttonName,
                slot = mapping.slot,
                abilityId = abilityId,
                texture = slotTexture,
                hasHighlight = hasHighlight,
                hasCostFailure = hasCostFailure,
                hasStateFailure = hasStateFailure,
                isUsable = isUsable,
            })
            table.insert(stateParts, table.concat({
                tostring(mapping.buttonName),
                tostring(mapping.slot),
                tostring(abilityId),
                tostring(slotTexture),
                tostring(hasHighlight),
                tostring(hasCostFailure),
                tostring(hasStateFailure),
            }, ":"))
        end
    end
    local stateKey = table.concat(stateParts, "|")
    if frontBarContainer._betteruiLastFrontBarTraceState ~= stateKey then
        frontBarContainer._betteruiLastFrontBarTraceState = stateKey
        TraceFrontBar("resource_orbs.front_bar", "refreshed", {
            fn = "UpdateFrontBar",
            activeCategory = activeCategory,
            slotCount = #traceSlots,
            slots = traceSlots,
        })
    end
    frontBarContainer:SetHidden(false)
end

-- UPDATE USABILITY OVERLAY

--- Updates unusable overlays on front bar buttons based on cost/state/target failures.
---@param rootFrame table Root ResourceOrbFrames control
---@param isCasting boolean Whether the player is currently casting
local function UpdateFrontBarUsability(rootFrame, isCasting)
    local frontBarCfg = GetLiveSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local activeCategory = GetActiveHotbarCategory()
    local nowMs = GetGameTimeMilliseconds()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local slotMapping = FRONT_BAR_SLOTS

    for _, mapping in ipairs(slotMapping) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            local iconControl = btn:GetNamedChild("Icon")
            local unusableOverlay = btn:GetNamedChild("UnusableOverlay")
            if iconControl and not iconControl:IsHidden() then
                local slotStateKey = CooldownUtils.BuildStateKey(mapping.slot, activeCategory)
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
                local stateTraceKey = table.concat({
                    tostring(mapping.slot),
                    tostring(activeCategory),
                    tostring(hasCostFailure),
                    tostring(hasLatchedStateFailure),
                    tostring(hasLatchedTargetFailure),
                    tostring(hasInsufficientUlt),
                    tostring(hasActiveCooldown),
                    tostring(unusable),
                }, ":")
                if btn._betteruiUsabilityTraceKey ~= stateTraceKey then
                    btn._betteruiUsabilityTraceKey = stateTraceKey
                    TraceFrontBar("resource_orbs.front_bar_usability", "refreshed", {
                        fn = "UpdateFrontBarUsability",
                        buttonName = mapping.buttonName,
                        slotIndex = mapping.slot,
                        hotbarCategory = activeCategory,
                        costFailure = hasCostFailure,
                        stateFailure = hasLatchedStateFailure,
                        targetFailure = hasLatchedTargetFailure,
                        insufficientUltimate = hasInsufficientUlt,
                        cooldownSuppressed = hasActiveCooldown,
                        unusable = unusable,
                        overlayVisible = unusable and not hasActiveCooldown,
                    })
                end
            end
        end
    end
end

-- TOOLTIPS

--- Sets up tooltip handlers on front bar ability buttons.
---@param rootFrame table Root ResourceOrbFrames control
local function SetupFrontBarTooltips(rootFrame)
    local frontBarCfg = GetSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    for _, mapping in ipairs(FRONT_BAR_SLOTS) do
        local btn = FindControl(frontBarContainer, mapping.buttonName)
        if btn then
            SkillBar.SetupButtonTooltip(btn, mapping.slot, nil, RIGHT, -5, 0)
        end
    end
end

-- KEYBINDS

--- Sets up keybind labels on front bar buttons.
---@param rootFrame table Root ResourceOrbFrames control
local function SetupFrontBarKeybinds(rootFrame)
    local frontBarCfg = GetSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    local registeredKeybinds = 0
    local keybindEntries = {}

    for i = 1, 5 do
        local btn = FindControl(frontBarContainer, 'Button' .. i)
        if btn then
            local buttonText = btn:GetNamedChild("ButtonText")
            local bindings = SLOT_KEYBINDS[i]
            if buttonText and bindings then
                ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, bindings.keyboard, HIDE_UNBOUND, bindings.gamepad)
                registeredKeybinds = registeredKeybinds + 1
                keybindEntries[#keybindEntries + 1] = {
                    buttonName = "Button" .. tostring(i),
                    slotIndex = FRONT_BAR_SLOTS[i] and FRONT_BAR_SLOTS[i].slot or nil,
                    keyboardBinding = bindings.keyboard,
                    gamepadBinding = bindings.gamepad,
                    visible = true,
                }
            end
        end
    end

    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local buttonText = ultBtn:GetNamedChild("ButtonText")
        if buttonText then
            ZO_Keybindings_RegisterLabelForBindingUpdate(buttonText, "ACTION_BUTTON_8", HIDE_UNBOUND, "GAMEPAD_ACTION_BUTTON_8")
            registeredKeybinds = registeredKeybinds + 1
            keybindEntries[#keybindEntries + 1] = {
                buttonName = "UltimateButton",
                slotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX and ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 or nil,
                keyboardBinding = "ACTION_BUTTON_8",
                gamepadBinding = "GAMEPAD_ACTION_BUTTON_8",
                visible = true,
            }
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
            registeredKeybinds = registeredKeybinds + 1
            keybindEntries[#keybindEntries + 1] = {
                buttonName = "QuickslotButton",
                slotIndex = ACTION_BAR_QUICKSLOT_SLOT_INDEX,
                keyboardBinding = "ACTION_BUTTON_9",
                gamepadBinding = "GAMEPAD_ACTION_BUTTON_9",
                visible = true,
            }
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
            registeredKeybinds = registeredKeybinds + 1
            keybindEntries[#keybindEntries + 1] = {
                buttonName = "CompanionButton",
                keyboardBinding = "COMMAND_PET",
                gamepadBinding = "COMMAND_PET",
                visible = true,
            }
        end
        local isGamepad = IsInGamepadPreferredMode()
        local l = compBtn:GetNamedChild("LeftKeybind")
        local r = compBtn:GetNamedChild("RightKeybind")
        if l then l:SetHidden(not isGamepad) end
        if r then r:SetHidden(not isGamepad) end
    end
    TraceFrontBar("resource_orbs.front_bar_keybinds", "setup_end", {
        registered = registeredKeybinds,
        hasUltimate = ultBtn ~= nil,
        hasQuickslot = qsBtn ~= nil,
        hasCompanion = compBtn ~= nil,
        gamepad = IsInGamepadPreferredMode(),
        keybinds = keybindEntries,
    })
end

-- LAYOUT

--- Updates front bar button sizes, positions, and anchor layout.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateFrontBarLayout(rootFrame)
    local frontBarSettings = GetSettings().customFrontBar
    if not frontBarSettings or not frontBarSettings.m_enabled then return end
    local frontBarLayoutConfig = BETTERUI_ORB_FRAMES.bars.customFrontBar
    if not frontBarLayoutConfig then return end
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    local bgMiddle = FindControl(rootFrame, 'BgMiddle')

    local isGamePad = IsInGamepadPreferredMode()
    local slotsConfig = isGamePad and BETTERUI_ORB_FRAMES.slots.gamepad or BETTERUI_ORB_FRAMES.slots.keyboard
    local modeConfig = isGamePad and frontBarLayoutConfig.gamepad or frontBarLayoutConfig.keyboard

    local buttonSize = modeConfig.buttonSize or slotsConfig.width
    local spacing = modeConfig.spacing or slotsConfig.spacing
    local ultimateSize = modeConfig.ultimateSize or (buttonSize + 6)
    local buttonInnerSize = buttonSize - 3
    local ultimateInnerSize = ultimateSize - 3
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
            if flipCard then flipCard:SetDimensions(buttonInnerSize, buttonInnerSize) end
            local icon = btn:GetNamedChild("Icon")
            if icon then icon:SetDimensions(buttonInnerSize, buttonInnerSize) end
            SetPressFeedbackBaseSize(btn, buttonInnerSize, buttonInnerSize, buttonInnerSize, buttonInnerSize)
        end
    end

    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local btn5 = FindControl(frontBarContainer, 'Button5')
        local ultOffsetX = frontBarLayoutConfig.ultimate.offsetX or 0
        local ultOffsetY = frontBarLayoutConfig.ultimate.offsetY or 0
        ultBtn:SetDimensions(ultimateSize, ultimateSize)
        ultBtn.cooldownRevealWidth = ultimateSize
        ultBtn.cooldownRevealHeight = ultimateSize
        ultBtn:ClearAnchors()
        ultBtn:SetAnchor(LEFT, btn5, RIGHT, ultimateGap + ultOffsetX, ultOffsetY)
        ultBtn.readyBurst = ultBtn:GetNamedChild("ReadyBurst")
        ultBtn.readyLoop = ultBtn:GetNamedChild("ReadyLoop")
        ultBtn.glow = ultBtn:GetNamedChild("Glow")
        -- Create the glow animation once; layout runs repeatedly and must not
        -- leak a new ZO_AlphaAnimation per pass.
        if ultBtn.glow and not ultBtn.glowAnimation then
            ultBtn.glowAnimation = ZO_AlphaAnimation:New(ultBtn.glow)
            ultBtn.glowAnimation:SetMinMaxAlpha(0, 1)
        end
        local flipCard = ultBtn:GetNamedChild("FlipCard")
        if flipCard then flipCard:SetDimensions(ultimateInnerSize, ultimateInnerSize) end
        local icon = ultBtn:GetNamedChild("Icon")
        if icon then icon:SetDimensions(ultimateInnerSize, ultimateInnerSize) end
        SetPressFeedbackBaseSize(ultBtn, ultimateInnerSize, ultimateInnerSize, ultimateInnerSize, ultimateInnerSize)
    end

    -- Whole-bar offset (customFrontBar.offsetX/offsetY). The container anchor
    -- uses it below; quickslot/companion anchor to BgMiddle directly, so they
    -- must add it themselves to move with the bar.
    local barOffsetX = frontBarLayoutConfig.offsetX or 0
    local barOffsetY = frontBarLayoutConfig.offsetY or 0

    local qsBtn = GetFrontBarButtonControl(rootFrame, frontBarContainer, "QuickslotButton")
    if qsBtn then
        local quickslotCfg = frontBarLayoutConfig.quickslotButton
        local baseX = BETTERUI_ORB_FRAMES.bars.quickslot.x
        local baseY = BETTERUI_ORB_FRAMES.bars.quickslot.y
        local offsetX = quickslotCfg.offsetX or 0
        local offsetY = quickslotCfg.offsetY or 0
        qsBtn:SetDimensions(buttonSize, buttonSize)
        qsBtn.cooldownRevealWidth = buttonSize
        qsBtn.cooldownRevealHeight = buttonSize
        qsBtn:ClearAnchors()
        if bgMiddle then
            qsBtn:SetAnchor(CENTER, bgMiddle, BOTTOM, baseX + offsetX + barOffsetX, baseY + offsetY + barOffsetY)
        end
        local flipCard = qsBtn:GetNamedChild("FlipCard")
        if flipCard then flipCard:SetDimensions(buttonInnerSize, buttonInnerSize) end
        local icon = qsBtn:GetNamedChild("Icon")
        if icon then icon:SetDimensions(buttonInnerSize, buttonInnerSize) end
        SetPressFeedbackBaseSize(qsBtn, buttonInnerSize, buttonInnerSize, buttonInnerSize, buttonInnerSize)
        SkillBar.AnchorQuickslotCountText(qsBtn, qsBtn:GetNamedChild("CountText"))
    end

    local compBtn = GetFrontBarButtonControl(rootFrame, frontBarContainer, "CompanionButton")
    if compBtn then
        local companionCfg = frontBarLayoutConfig.companionButton
        local baseX = BETTERUI_ORB_FRAMES.bars.companionUltimate.x
        local baseY = BETTERUI_ORB_FRAMES.bars.companionUltimate.y
        local offsetX = companionCfg.offsetX or 0
        local offsetY = companionCfg.offsetY or 0
        compBtn:SetDimensions(ultimateSize, ultimateSize)
        compBtn.cooldownRevealWidth = ultimateSize
        compBtn.cooldownRevealHeight = ultimateSize
        compBtn:ClearAnchors()
        if bgMiddle then
            compBtn:SetAnchor(CENTER, bgMiddle, BOTTOM, baseX + offsetX + barOffsetX, baseY + offsetY + barOffsetY)
        end
        local flipCard = compBtn:GetNamedChild("FlipCard")
        if flipCard then flipCard:SetDimensions(ultimateInnerSize, ultimateInnerSize) end
        local icon = compBtn:GetNamedChild("Icon")
        if icon then icon:SetDimensions(ultimateInnerSize, ultimateInnerSize) end
        SetPressFeedbackBaseSize(compBtn, ultimateInnerSize, ultimateInnerSize, ultimateInnerSize, ultimateInnerSize)
    end

    if bgMiddle then
        frontBarContainer:ClearAnchors()
        frontBarContainer:SetAnchor(BOTTOM, bgMiddle, BOTTOM, barOffsetX + 10, -15 + barOffsetY)
    end
    TraceFrontBar("resource_orbs.front_bar_layout", "applied", {
        fn = "UpdateFrontBarLayout",
        buttonSize = buttonSize,
        spacing = spacing,
        ultimateSize = ultimateSize,
        barOffsetX = barOffsetX,
        barOffsetY = barOffsetY,
        totalWidth = totalWidth,
        hasQuickslot = qsBtn ~= nil,
        hasCompanion = compBtn ~= nil,
        hasUltimate = ultBtn ~= nil,
        gamepad = isGamePad,
    })
end

-- QUICKSLOT + COMPANION UPDATES

--- Updates quickslot button icon, count, and tooltip.
---@param rootFrame table Root ResourceOrbFrames control
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
    local settings = GetSettings()
    local quickslotEmpty = SkillBar.UpdateQuickslotCountAndEmptyState(qsBtn, nil, settings, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    qsBtn.slotIndex = slotIndex
    qsBtn.hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    local quickslotTraceState = table.concat({ tostring(slotIndex), tostring(icon), tostring(qsBtn.quickslotCount), tostring(quickslotEmpty) }, ":")
    if qsBtn._betteruiTraceState ~= quickslotTraceState then
        qsBtn._betteruiTraceState = quickslotTraceState
        TraceFrontBar("resource_orbs.quickslot", "updated", {
            slot = slotIndex,
            icon = icon,
            count = qsBtn.quickslotCount,
            empty = quickslotEmpty,
        })
    end
    if not qsBtn.tooltipHandlersAdded then
        SkillBar.SetupButtonTooltip(qsBtn, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL, RIGHT, -5, 0)
        qsBtn.tooltipHandlersAdded = true
    end
end

--- Updates companion button visibility, icon, and tooltip.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateFrontBarCompanion(rootFrame)
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
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
        local companionTraceState = table.concat({ tostring(companionActive), tostring(slotIndex), tostring(icon) }, ":")
        if compBtn._betteruiTraceState ~= companionTraceState then
            compBtn._betteruiTraceState = companionTraceState
            TraceFrontBar("resource_orbs.companion_button", "updated", {
                active = companionActive,
                slot = slotIndex,
                icon = icon,
                hidden = false,
            })
        end
        if not compBtn.tooltipHandlersAdded then
            SkillBar.SetupButtonTooltip(compBtn, slotIndex, HOTBAR_CATEGORY_COMPANION, RIGHT, -5, 0)
            compBtn.tooltipHandlersAdded = true
        end
    else
        compBtn:SetHidden(true)
        if compBtn._betteruiTraceState ~= "inactive" then
            compBtn._betteruiTraceState = "inactive"
            TraceFrontBar("resource_orbs.companion_button", "updated", {
                active = false,
                hidden = true,
            })
        end
    end
end

-- MODULE EXPORTS
-- Press feedback and cooldown exports are set by their respective sibling files.
SkillBar.CacheFrontBarControls = CacheFrontBarControls
SkillBar.HideNativeActionBar = HideNativeActionBar
SkillBar.RestoreNativeActionBar = RestoreNativeActionBar
SkillBar.UpdateFrontBar = UpdateFrontBar
SkillBar.UpdateFrontBarUsability = UpdateFrontBarUsability
SkillBar.SetupFrontBarTooltips = SetupFrontBarTooltips
SkillBar.SetupFrontBarKeybinds = SetupFrontBarKeybinds
SkillBar.UpdateFrontBarLayout = UpdateFrontBarLayout
SkillBar.UpdateFrontBarQuickslot = UpdateFrontBarQuickslot
SkillBar.UpdateFrontBarCompanion = UpdateFrontBarCompanion
SkillBar._FrontBarInternals = {
    GetTargetOrRangeFailure = GetTargetOrRangeFailure,
    ResolveTargetFailureWithCastLatch = ResolveTargetFailureWithCastLatch,
    ResolveNonCostFailureWithCastLatch = ResolveNonCostFailureWithCastLatch,
    HasInsufficientUltimate = HasInsufficientUltimate,
    ShouldSuppressUnusableOverlayForCooldown = ShouldSuppressUnusableOverlayForCooldown,
    TARGET_FAILURE_CAST_HOLD_MS = TARGET_FAILURE_CAST_HOLD_MS,
    NON_COST_FAILURE_CAST_HOLD_MS = NON_COST_FAILURE_CAST_HOLD_MS,
}
