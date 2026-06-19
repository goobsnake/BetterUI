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
    if cooldownEdge then cooldownEdge:SetHidden(true) end
    if cooldownOverlay then cooldownOverlay:SetHidden(true) end
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

CooldownUtils.effectDurationCache = effectDurationCache
CooldownUtils.smoothedRemainCache = smoothedRemainCache

SkillBar.CooldownUtils = CooldownUtils
