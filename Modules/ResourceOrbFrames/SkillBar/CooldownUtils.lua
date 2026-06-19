--[[
File: Modules/ResourceOrbFrames/SkillBar/CooldownUtils.lua
Purpose: Shared SkillBar cooldown helpers for state keys, timing, smoothing, and linear visuals.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
local CONST = SkillBar.CONST or {}
local COOLDOWN_DURATION_THRESHOLD = CONST.COOLDOWN_DURATION_THRESHOLD or 1500

local sharedCooldownCaches = SkillBar.SharedCooldownCaches
if not sharedCooldownCaches then
    sharedCooldownCaches = {
        effectDurationBySlotCategory = {},
        smoothedRemainBySlotCategory = {},
    }
    SkillBar.SharedCooldownCaches = sharedCooldownCaches
end

local effectDurationCache = sharedCooldownCaches.effectDurationBySlotCategory
local smoothedRemainCache = sharedCooldownCaches.smoothedRemainBySlotCategory

local CooldownUtils = {}

-- Numeric composite key (hotbarCategory * 1000 + slotIndex) avoids per-tick
-- string.format allocations in the 16ms cooldown hot path. Slot indices are
-- well below 1000, so the composite is collision-free.
---@param slotIndex number|nil
---@param hotbarCategory number|nil
---@return number stateKey
function CooldownUtils.BuildStateKey(slotIndex, hotbarCategory)
    return ((hotbarCategory or -1) * 1000) + (slotIndex or -1)
end

---@param stateKey number|nil
function CooldownUtils.ClearEffectDuration(stateKey)
    if stateKey then
        effectDurationCache[stateKey] = nil
    end
end

---@param slotIndex number
---@param hotbarCategory number
---@param canTrack boolean|nil
---@return boolean showCooldown
---@return number remainMs
---@return number durationMs
---@return number stateKey
function CooldownUtils.ResolveCooldownWindow(slotIndex, hotbarCategory, canTrack)
    local stateKey = CooldownUtils.BuildStateKey(slotIndex, hotbarCategory)
    if canTrack == false then
        CooldownUtils.ClearEffectDuration(stateKey)
        return false, 0, 0, stateKey
    end

    local remainMs, durationMs, isGlobalCooldown = GetSlotCooldownInfo(slotIndex, hotbarCategory)
    if remainMs and remainMs > 0 and durationMs and durationMs > COOLDOWN_DURATION_THRESHOLD and not isGlobalCooldown then
        return true, remainMs, durationMs, stateKey
    end

    local effectRemaining = GetActionSlotEffectTimeRemaining(slotIndex, hotbarCategory)
    if effectRemaining and effectRemaining > 0 then
        local cachedDuration = effectDurationCache[stateKey]
        if not cachedDuration or cachedDuration < effectRemaining then
            cachedDuration = effectRemaining
            effectDurationCache[stateKey] = cachedDuration
        end
        return true, effectRemaining, cachedDuration, stateKey
    end

    CooldownUtils.ClearEffectDuration(stateKey)
    return false, remainMs or 0, durationMs or 0, stateKey
end

---@param stateKey number|nil
function CooldownUtils.ResetSmoothedRemaining(stateKey)
    if stateKey then
        smoothedRemainCache[stateKey] = nil
    end
end

---@param stateKey number|nil
---@param remainMs number|nil
---@param durationMs number|nil
---@return number|nil smoothedRemainMs
function CooldownUtils.GetSmoothedRemaining(stateKey, remainMs, durationMs)
    if not stateKey or not remainMs or remainMs <= 0 or not durationMs or durationMs <= 0 then
        return remainMs
    end

    local nowMs = GetGameTimeMilliseconds()
    local smoothState = smoothedRemainCache[stateKey]
    if not smoothState
        or smoothState.durationMs ~= durationMs
        or remainMs > ((smoothState.lastReportedRemainMs or remainMs) + 100) then
        smoothedRemainCache[stateKey] = {
            durationMs = durationMs,
            lastReportedRemainMs = remainMs,
            smoothedRemainMs = remainMs,
            lastUpdateMs = nowMs,
        }
        return remainMs
    end

    local elapsedMs = math.max(0, nowMs - (smoothState.lastUpdateMs or nowMs))
    local smoothedRemainMs = math.max(0, math.min(remainMs, (smoothState.smoothedRemainMs or remainMs) - elapsedMs))

    smoothState.lastReportedRemainMs = remainMs
    smoothState.smoothedRemainMs = smoothedRemainMs
    smoothState.lastUpdateMs = nowMs
    return smoothedRemainMs
end

---@param cooldownEdge table|nil
---@param cooldownOverlay table|nil
local function HideLinearVisuals(cooldownEdge, cooldownOverlay)
    if cooldownEdge then
        cooldownEdge:SetHidden(true)
        cooldownEdge.appliedLinearHidden = true
    end
    if cooldownOverlay then
        cooldownOverlay:SetHidden(true)
        cooldownOverlay.appliedLinearHidden = true
    end
end

---@param cooldownEdge table|nil
---@param cooldownOverlay table|nil
---@param revealControl table|nil
---@param remainMs number|nil
---@param durationMs number|nil
---@return number|nil percentComplete
function CooldownUtils.ApplyLinearVisuals(cooldownEdge, cooldownOverlay, revealControl, remainMs, durationMs)
    if not cooldownEdge or not revealControl or not remainMs or not durationMs or durationMs <= 0 then
        HideLinearVisuals(cooldownEdge, cooldownOverlay)
        return nil
    end

    local revealWidth = revealControl.cooldownRevealWidth
    local revealHeight = revealControl.cooldownRevealHeight
    if not revealWidth or not revealHeight then
        revealWidth, revealHeight = revealControl:GetDimensions()
    end
    if revealWidth <= 0 or revealHeight <= 0 then
        HideLinearVisuals(cooldownEdge, cooldownOverlay)
        return nil
    end

    local percentComplete = 1 - (remainMs / durationMs)
    if percentComplete < 0 then percentComplete = 0 end
    if percentComplete > 1 then percentComplete = 1 end

    local edgeOffsetY = (1 - percentComplete) * revealHeight

    -- Latch static edge state (anchor target, draw layer/tier/level, width).
    -- Only the Y offset is dynamic, so SetAnchor runs every frame; everything
    -- else is applied only when the control has not been prepared yet or the
    -- anchor target changed.
    if not cooldownEdge.appliedLinearStatic or cooldownEdge.appliedLinearRevealControl ~= revealControl then
        cooldownEdge.appliedLinearStatic = true
        cooldownEdge.appliedLinearRevealControl = revealControl
        cooldownEdge:ClearAnchors()
        cooldownEdge:SetDrawLayer(DL_OVERLAY)
        cooldownEdge:SetDrawTier(DT_LOW)
        cooldownEdge:SetDrawLevel(1)
        cooldownEdge.appliedLinearWidth = revealWidth
        cooldownEdge:SetWidth(revealWidth)
    elseif cooldownEdge.appliedLinearWidth ~= revealWidth then
        cooldownEdge.appliedLinearWidth = revealWidth
        cooldownEdge:SetWidth(revealWidth)
    end
    if cooldownEdge.appliedLinearHidden ~= false then
        cooldownEdge.appliedLinearHidden = false
        cooldownEdge:SetHidden(false)
    end
    cooldownEdge:SetAnchor(TOPLEFT, revealControl, TOPLEFT, 0, edgeOffsetY)

    if cooldownOverlay then
        if not cooldownOverlay.appliedLinearStatic or cooldownOverlay.appliedLinearRevealControl ~= revealControl then
            cooldownOverlay.appliedLinearStatic = true
            cooldownOverlay.appliedLinearRevealControl = revealControl
            cooldownOverlay:ClearAnchors()
            cooldownOverlay:SetAnchor(TOPLEFT, revealControl, TOPLEFT, 0, 0)
            cooldownOverlay:SetDrawLayer(DL_OVERLAY)
            cooldownOverlay:SetDrawTier(DT_LOW)
            cooldownOverlay:SetDrawLevel(0)
        end
        if cooldownOverlay.appliedLinearHidden ~= false then
            cooldownOverlay.appliedLinearHidden = false
            cooldownOverlay:SetHidden(false)
        end
        local unrevealedHeight = (1 - percentComplete) * revealHeight
        cooldownOverlay:SetDimensions(revealWidth, unrevealedHeight)
    end

    return percentComplete
end

CooldownUtils.HideLinearVisuals = HideLinearVisuals

CooldownUtils.effectDurationCache = effectDurationCache
CooldownUtils.smoothedRemainCache = smoothedRemainCache

SkillBar.CooldownUtils = CooldownUtils
