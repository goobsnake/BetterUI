--[[
File: tools/tests/test_cooldown_utils.lua
Purpose: Unit tests for ResourceOrbFrames/SkillBar/CooldownUtils.lua using
         the actual module code.
Usage:
  lua tools/tests/test_cooldown_utils.lua
]]

BETTERUI = {
    ResourceOrbFrames = {
        SkillBar = {
            CONST = {
                COOLDOWN_DURATION_THRESHOLD = 1500,
            },
        },
    },
}

TOPLEFT = "TOPLEFT"
DL_OVERLAY = 1
DT_LOW = 2

local cooldownRemainMs = 0
local cooldownDurationMs = 0
local cooldownIsGlobal = false
local effectRemainingMs = 0
local nowMs = 1000

function GetSlotCooldownInfo()
    return cooldownRemainMs, cooldownDurationMs, cooldownIsGlobal
end

function GetActionSlotEffectTimeRemaining()
    return effectRemainingMs
end

function GetGameTimeMilliseconds()
    return nowMs
end

dofile("Modules/ResourceOrbFrames/SkillBar/CooldownUtils.lua")

local CooldownUtils = BETTERUI.ResourceOrbFrames.SkillBar.CooldownUtils

local function NewRevealControl(width, height)
    return {
        cooldownRevealWidth = width,
        cooldownRevealHeight = height,
        width = width,
        height = height,
        GetDimensions = function(self)
            return self.width, self.height
        end,
    }
end

local function NewVisualControl()
    return {
        hidden = nil,
        anchor = nil,
        width = nil,
        dimensions = nil,
        drawLayer = nil,
        drawTier = nil,
        drawLevel = nil,
        ClearAnchors = function(self)
            self.anchor = nil
        end,
        SetAnchor = function(self, ...)
            self.anchor = { ... }
        end,
        SetWidth = function(self, value)
            self.width = value
        end,
        SetDimensions = function(self, width, height)
            self.dimensions = { width, height }
        end,
        SetHidden = function(self, value)
            self.hidden = value
        end,
        SetDrawLayer = function(self, value)
            self.drawLayer = value
        end,
        SetDrawTier = function(self, value)
            self.drawTier = value
        end,
        SetDrawLevel = function(self, value)
            self.drawLevel = value
        end,
    }
end

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected true, got %s", label, tostring(value)))
    end
end

local function assert_nil(value, label)
    if value == nil then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected nil, got %s", label, tostring(value)))
    end
end

print("[BuildStateKey and ClearEffectDuration]")
do
    local stateKey = CooldownUtils.BuildStateKey(3, 1)
    -- Numeric composite key: (hotbarCategory * 1000) + slotIndex
    assert_eq(stateKey, 1003, "state key uses slot and hotbar category")
    assert_eq(CooldownUtils.BuildStateKey(nil, nil), -1001, "state key falls back for nil values")

    CooldownUtils.effectDurationCache[stateKey] = 5000
    CooldownUtils.ClearEffectDuration(stateKey)
    assert_nil(CooldownUtils.effectDurationCache[stateKey], "clear effect duration removes cache entry")
end

print("[ResolveCooldownWindow]")
do
    local stateKey = CooldownUtils.BuildStateKey(4, 2)
    CooldownUtils.effectDurationCache[stateKey] = 4000

    local showCooldown, remainMs, durationMs
    showCooldown, remainMs, durationMs = CooldownUtils.ResolveCooldownWindow(4, 2, false)
    assert_eq(showCooldown, false, "tracking disabled hides cooldown")
    assert_eq(remainMs, 0, "tracking disabled zeroes remaining time")
    assert_eq(durationMs, 0, "tracking disabled zeroes duration")
    assert_nil(CooldownUtils.effectDurationCache[stateKey], "tracking disabled clears cached effect duration")

    cooldownRemainMs = 2200
    cooldownDurationMs = 3500
    effectRemainingMs = 0
    showCooldown, remainMs, durationMs = CooldownUtils.ResolveCooldownWindow(4, 2, true)
    assert_eq(showCooldown, true, "long slot cooldown is shown")
    assert_eq(remainMs, 2200, "slot cooldown remain is returned")
    assert_eq(durationMs, 3500, "slot cooldown duration is returned")

    cooldownIsGlobal = true
    showCooldown, remainMs, durationMs = CooldownUtils.ResolveCooldownWindow(4, 2, true)
    assert_eq(showCooldown, false, "global cooldown is filtered via the API flag")
    assert_eq(remainMs, 2200, "filtered global cooldown still returns the reported remaining time")
    assert_eq(durationMs, 3500, "filtered global cooldown still returns the reported duration")

    cooldownIsGlobal = false
    cooldownRemainMs = 400
    cooldownDurationMs = 1000
    effectRemainingMs = 5000
    showCooldown, remainMs, durationMs = CooldownUtils.ResolveCooldownWindow(4, 2, true)
    assert_eq(showCooldown, true, "effect duration can drive cooldown state")
    assert_eq(remainMs, 5000, "effect remaining time is returned")
    assert_eq(durationMs, 5000, "first effect duration becomes cached duration")

    effectRemainingMs = 2400
    showCooldown, remainMs, durationMs = CooldownUtils.ResolveCooldownWindow(4, 2, true)
    assert_eq(remainMs, 2400, "effect remaining time updates downward")
    assert_eq(durationMs, 5000, "cached effect duration is retained while effect shrinks")

    cooldownRemainMs = 0
    cooldownDurationMs = 0
    effectRemainingMs = 0
    showCooldown, remainMs, durationMs = CooldownUtils.ResolveCooldownWindow(4, 2, true)
    assert_eq(showCooldown, false, "zeroed effect and slot cooldown hides state")
    assert_eq(remainMs, 0, "zeroed cooldown returns zero remaining time")
    assert_eq(durationMs, 0, "zeroed cooldown returns zero duration")
    assert_nil(CooldownUtils.effectDurationCache[stateKey], "cleared cooldown resets cached effect duration")
end

print("[GetSmoothedRemaining]")
do
    local stateKey = CooldownUtils.BuildStateKey(5, 1)
    CooldownUtils.ResetSmoothedRemaining(stateKey)

    nowMs = 1000
    local smoothed = CooldownUtils.GetSmoothedRemaining(stateKey, 900, 1200)
    assert_eq(smoothed, 900, "first cooldown sample is returned unchanged")

    nowMs = 1100
    smoothed = CooldownUtils.GetSmoothedRemaining(stateKey, 850, 1200)
    assert_eq(smoothed, 800, "smoothed cooldown subtracts elapsed time")

    nowMs = 1200
    smoothed = CooldownUtils.GetSmoothedRemaining(stateKey, 1000, 1200)
    assert_eq(smoothed, 1000, "large cooldown increase resets smoothing state")

    nowMs = 1300
    smoothed = CooldownUtils.GetSmoothedRemaining(stateKey, 700, 1500)
    assert_eq(smoothed, 700, "duration changes reset smoothing state")

    CooldownUtils.ResetSmoothedRemaining(stateKey)
    assert_nil(CooldownUtils.smoothedRemainCache[stateKey], "reset smoothing clears cache entry")

    assert_eq(CooldownUtils.GetSmoothedRemaining(nil, 500, 1000), 500, "missing state key bypasses smoothing")
    assert_eq(CooldownUtils.GetSmoothedRemaining(stateKey, 0, 1000), 0, "non-positive remaining time bypasses smoothing")
end

print("[ApplyLinearVisuals]")
do
    local revealControl = NewRevealControl(40, 80)
    local cooldownEdge = NewVisualControl()
    local cooldownOverlay = NewVisualControl()

    local percentComplete = CooldownUtils.ApplyLinearVisuals(cooldownEdge, cooldownOverlay, revealControl, 250, 1000)
    assert_eq(percentComplete, 0.75, "percent complete is derived from remaining duration")
    assert_eq(cooldownEdge.anchor[1], TOPLEFT, "cooldown edge anchors from top left")
    assert_eq(cooldownEdge.anchor[2], revealControl, "cooldown edge uses reveal control as anchor target")
    assert_eq(cooldownEdge.anchor[5], 20, "cooldown edge offset tracks reveal height")
    assert_eq(cooldownEdge.width, 40, "cooldown edge width matches reveal width")
    assert_eq(cooldownEdge.hidden, false, "cooldown edge is shown")
    assert_eq(cooldownEdge.drawLayer, DL_OVERLAY, "cooldown edge draw layer is set")
    assert_eq(cooldownOverlay.dimensions[1], 40, "cooldown overlay width matches reveal width")
    assert_eq(cooldownOverlay.dimensions[2], 20, "cooldown overlay height matches unrevealed height")
    assert_eq(cooldownOverlay.hidden, false, "cooldown overlay is shown")

    local zeroReveal = NewRevealControl(0, 0)
    percentComplete = CooldownUtils.ApplyLinearVisuals(cooldownEdge, cooldownOverlay, zeroReveal, 500, 1000)
    assert_nil(percentComplete, "zero-sized reveal control suppresses visuals")
    assert_eq(cooldownEdge.hidden, true, "zero-sized reveal control hides cooldown edge")
    assert_eq(cooldownOverlay.hidden, true, "zero-sized reveal control hides cooldown overlay")

    percentComplete = CooldownUtils.ApplyLinearVisuals(nil, cooldownOverlay, revealControl, 500, 1000)
    assert_nil(percentComplete, "missing cooldown edge suppresses visuals")
    assert_eq(cooldownOverlay.hidden, true, "missing cooldown edge still hides overlay")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
