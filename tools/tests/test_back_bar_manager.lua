--[[
File: tools/tests/test_back_bar_manager.lua
Purpose: Regression coverage for ResourceOrbFrames/SkillBar/BackBarManager.lua
         using the actual module code.

Usage:
  lua tools/tests/test_back_bar_manager.lua
]]

BETTERUI = {
    ResourceOrbFrames = {
        SkillBar = {
            CooldownUtils = {},
        },
        Utils = {},
    },
    CIM = {
        ControlCache = {},
    },
}

local settings = {
    hideBackBar = false,
    backBarOpacity = 0.6,
    cooldownTextSize = 99,
    cooldownTextColor = { 0.1, 0.2, 0.3, 0.4 },
}

function BETTERUI.ResourceOrbFrames.Utils.FindControl(parent, name)
    if not parent then return nil end
    if parent.GetNamedChild then
        local child = parent:GetNamedChild(name)
        if child then
            return child
        end
    end
    return parent.children and parent.children[name] or nil
end

function BETTERUI.ResourceOrbFrames.Utils.GetSettings()
    return settings
end

function BETTERUI.ResourceOrbFrames.Utils.ClampTextSize(value, minValue, maxValue, fallback)
    if type(value) ~= "number" then
        return fallback
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

BETTERUI.CIM.ControlCache.CacheButtonChildren = function(button)
    return button.children
end

LEFT = "LEFT"
RIGHT = "RIGHT"
CENTER = "CENTER"
TOPLEFT = "TOPLEFT"
BOTTOMRIGHT = "BOTTOMRIGHT"
DL_OVERLAY = 1
DT_HIGH = 2
ACTIVE_WEAPON_PAIR_MAIN = 1
HOTBAR_CATEGORY_PRIMARY = 10
HOTBAR_CATEGORY_BACKUP = 11
ANIMATION_TEXTURE = "ANIMATION_TEXTURE"
ANIMATION_PLAYBACK_LOOP = "LOOP"
LOOP_INDEFINITELY = -1

function CreateSimpleAnimation(animationType, control)
    local timeline = {
        playCount = 0,
        stopCount = 0,
        playbackType = nil,
        loopCount = nil,
        PlayFromStart = function(self)
            self.playCount = self.playCount + 1
        end,
        Stop = function(self)
            self.stopCount = self.stopCount + 1
        end,
        SetPlaybackType = function(self, playbackType, loopCount)
            self.playbackType = playbackType
            self.loopCount = loopCount
        end,
    }
    return {
        animationType = animationType,
        control = control,
        timeline = timeline,
        SetImageData = function(self, cellsWide, cellsHigh)
            self.imageData = { cellsWide, cellsHigh }
        end,
        SetFramerate = function(self, framerate)
            self.framerate = framerate
        end,
        GetTimeline = function(self)
            return self.timeline
        end,
    }
end

local currentLevel = 50
local unlockedLevel = 15
local activeWeaponPair = ACTIVE_WEAPON_PAIR_MAIN
local isGamepad = false
local slotTextures = {}
local activationAnimationTextures = {}
local activationHighlights = {}
local costFailures = {}
local stateFailures = {}
local tooltipCalls = {}
local resetCalls = {}
local cooldownWindows = {}

function GetUnitLevel()
    return currentLevel
end

function GetWeaponSwapUnlockedLevel()
    return unlockedLevel
end

function GetActiveWeaponPairInfo()
    return activeWeaponPair
end

function GetSlotTexture(slotIndex, hotbarCategory)
    local key = tostring(slotIndex) .. "_" .. tostring(hotbarCategory)
    return slotTextures[key] or "", nil, activationAnimationTextures[key]
end

function ActionSlotHasActivationHighlight(slotIndex, hotbarCategory)
    return activationHighlights[tostring(slotIndex) .. "_" .. tostring(hotbarCategory)] or false
end

function ActionSlotHasCostFailure(slotIndex, hotbarCategory)
    return costFailures[tostring(slotIndex) .. "_" .. tostring(hotbarCategory)] or false
end

function ActionSlotHasNonCostStateFailure(slotIndex, hotbarCategory)
    return stateFailures[tostring(slotIndex) .. "_" .. tostring(hotbarCategory)] or false
end

function GetSlotBoundId(slotIndex)
    return slotIndex * 10
end

function IsInGamepadPreferredMode()
    return isGamepad
end

BETTERUI_ORB_FRAMES = {
    slots = {
        keyboard = { width = 32, spacing = 4 },
        gamepad = { width = 40, spacing = 5 },
    },
    bars = {
        ultimateGap = 9,
        backUltimateOffsetX = 1,
        customBackBar = {
            keyboard = { buttonSize = 32, spacing = 4, ultimateSize = 38, ultIconSize = 35 },
            gamepad = { buttonSize = 40, spacing = 5, ultimateSize = 48, ultIconSize = 45 },
            ultimate = { offsetX = 2, offsetY = 3 },
        },
    },
}

local CooldownUtils = BETTERUI.ResourceOrbFrames.SkillBar.CooldownUtils

function CooldownUtils.ResolveCooldownWindow(slotIndex, hotbarCategory)
    local key = tostring(slotIndex) .. "_" .. tostring(hotbarCategory)
    local entry = cooldownWindows[key]
    if not entry then
        return false, 0, 0, key
    end
    return entry.show, entry.remainMs, entry.durationMs, key
end

function CooldownUtils.GetSmoothedRemaining(_, remainMs)
    return remainMs
end

function CooldownUtils.ApplyLinearVisuals(cooldownEdge, cooldownOverlay, _, remainMs, durationMs)
    cooldownEdge:SetHidden(false)
    cooldownOverlay:SetHidden(false)
    cooldownOverlay.linearArgs = { remainMs, durationMs }
    return 0.5
end

function CooldownUtils.ApplyCooldownTextStyle(label, textSize, color, applyFont)
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

function CooldownUtils.ResetSmoothedRemaining(stateKey)
    resetCalls[stateKey] = true
end

local function NewControl(name)
    local control = {
        name = name,
        children = {},
        hidden = false,
        alpha = nil,
        text = nil,
        anchor = nil,
        dimensions = nil,
        width = 0,
        height = 0,
        desaturation = nil,
    }

    function control:GetNamedChild(childName)
        return self.children[childName]
    end

    function control:SetHidden(value)
        self.hidden = value
    end

    function control:IsHidden()
        return self.hidden
    end

    function control:IsControlHidden()
        return self.hidden
    end

    function control:SetAlpha(value)
        self.alpha = value
    end

    function control:SetTexture(value)
        self.texture = value
    end

    function control:SetDimensions(width, height)
        self.dimensions = { width, height }
        self.width = width
        self.height = height
    end

    function control:SetWidth(value)
        self.width = value
    end

    function control:SetHeight(value)
        self.height = value
    end

    function control:ClearAnchors()
        self.anchor = nil
        self.anchorFill = nil
    end

    function control:SetAnchor(...)
        self.anchor = { ... }
    end

    function control:SetAnchorFill(target)
        self.anchorFill = target
    end

    function control:SetDrawLayer(value)
        self.drawLayer = value
    end

    function control:SetDrawTier(value)
        self.drawTier = value
    end

    function control:SetDrawLevel(value)
        self.drawLevel = value
    end

    function control:SetFont(value)
        self.font = value
    end

    function control:SetColor(...)
        self.color = { ... }
    end

    function control:SetText(value)
        self.text = value
    end

    function control:SetDesaturation(value)
        self.desaturation = value
    end

    return control
end

local function NewButton(name)
    local button = NewControl(name)
    button.children.Icon = NewControl(name .. "Icon")
    button.children.Backdrop = NewControl(name .. "Backdrop")
    button.children.Border = NewControl(name .. "Border")
    button.children.ActivationHighlight = NewControl(name .. "ActivationHighlight")
    button.children.ActivationHighlight:SetHidden(true)
    button.children.CooldownOverlay = NewControl(name .. "CooldownOverlay")
    button.children.CooldownEdge = NewControl(name .. "CooldownEdge")
    button.children.CooldownText = NewControl(name .. "CooldownText")
    button.children.ReadyBurst = NewControl(name .. "ReadyBurst")
    button.children.ReadyLoop = NewControl(name .. "ReadyLoop")
    button.children.Glow = NewControl(name .. "Glow")
    return button
end

local rootFrame = NewControl("Root")
local backBarContainer = NewControl("BackBarContainer")
rootFrame.children.BackBarContainer = backBarContainer
for i = 1, 6 do
    backBarContainer.children["Button" .. i] = NewButton("Button" .. i)
end

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
SkillBar.SetupButtonTooltip = function(button, slotIndex)
    table.insert(tooltipCalls, { button = button.name, slotIndex = slotIndex })
end

dofile("Modules/ResourceOrbFrames/SkillBar/ActivationHighlight.lua")
dofile("Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua")

local internals = SkillBar._BackBarInternals

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

print("[BackBarManager]")

assert_true(type(internals) == "table", "back bar manager exports test internals")

currentLevel = 50
unlockedLevel = 15
assert_true(internals.CanUseBackupBar(), "backup bar is available once the swap level is unlocked")
currentLevel = 10
assert_true(not internals.CanUseBackupBar(), "backup bar is unavailable before weapon swap unlock")
currentLevel = 50

SkillBar.CacheBackBarControls(rootFrame)
assert_eq(internals.GetCachedBackBarButton(1).children.Icon, backBarContainer.children.Button1.children.Icon, "cached back bar children are preserved for later updates")

settings.hideBackBar = true
SkillBar.UpdateBackBar(rootFrame)
assert_true(backBarContainer.hidden, "back bar update hides the container when the feature is disabled")

settings.hideBackBar = false
activeWeaponPair = ACTIVE_WEAPON_PAIR_MAIN
slotTextures["3_" .. HOTBAR_CATEGORY_BACKUP] = "icon-3"
activationAnimationTextures["3_" .. HOTBAR_CATEGORY_BACKUP] = "back-proc-animation"
activationHighlights["3_" .. HOTBAR_CATEGORY_BACKUP] = true
slotTextures["8_" .. HOTBAR_CATEGORY_BACKUP] = "icon-8"
SkillBar.UpdateBackBar(rootFrame)
assert_true(not backBarContainer.hidden, "back bar update shows the container when enabled")
assert_eq(backBarContainer.children.Button1.children.Icon.texture, "icon-3", "back bar update applies slot textures to button icons")
assert_eq(backBarContainer.children.Button1.children.Icon.alpha, settings.backBarOpacity, "back bar update applies the configured icon opacity")
assert_eq(backBarContainer.children.Button1.slotIndex, 3, "back bar update stores the source slot index on the button")
assert_eq(backBarContainer.children.Button1.hotbarCategory, HOTBAR_CATEGORY_BACKUP, "back bar update stores the active back bar category on the button")
local backProcHighlight = backBarContainer.children.Button1.children.ActivationHighlight
assert_true(not backProcHighlight.hidden, "back bar update shows activation highlights for ready back-bar slots")
assert_eq(backProcHighlight.texture, "back-proc-animation",
    "back bar activation highlight uses the slot animation texture")
assert_true(backProcHighlight.animation ~= nil, "back bar activation highlight creates a texture animation")
if backProcHighlight.animation then
    assert_eq(backProcHighlight.animation.imageData[1], 64,
        "back bar activation highlight is configured as a 64-frame horizontal animation")
    assert_eq(backProcHighlight.animation.framerate, 30,
        "back bar activation highlight uses the native action-button framerate")
    assert_eq(backProcHighlight.animation.timeline.playbackType, ANIMATION_PLAYBACK_LOOP,
        "back bar activation highlight loops like the native action button")
    assert_eq(backProcHighlight.animation.timeline.playCount, 1,
        "back bar activation highlight starts the texture animation")
end

costFailures["3_" .. HOTBAR_CATEGORY_BACKUP] = true
SkillBar.UpdateBackBar(rootFrame)
assert_true(backProcHighlight.hidden,
    "back bar update suppresses activation highlights while cost failure is active")
costFailures["3_" .. HOTBAR_CATEGORY_BACKUP] = false

stateFailures["3_" .. HOTBAR_CATEGORY_BACKUP] = true
SkillBar.UpdateBackBar(rootFrame)
assert_true(backProcHighlight.hidden,
    "back bar update suppresses activation highlights while state failure is active")
stateFailures["3_" .. HOTBAR_CATEGORY_BACKUP] = false

activationAnimationTextures["3_" .. HOTBAR_CATEGORY_BACKUP] = nil
SkillBar.UpdateBackBar(rootFrame)
assert_true(backProcHighlight.hidden,
    "back bar update hides activation highlights when the native animation texture is missing")
assert_eq(backProcHighlight.texture, nil,
    "back bar activation highlight clears stale animation texture when native data is missing")
activationAnimationTextures["3_" .. HOTBAR_CATEGORY_BACKUP] = "back-proc-animation"

isGamepad = false
SkillBar.UpdateBackBarLayout(rootFrame)
assert_eq(backBarContainer.dimensions[1], 223.0, "keyboard layout computes the expected container width")
assert_true(not backBarContainer.children.Button1.children.Border.hidden, "keyboard layout keeps borders visible")
assert_true(backBarContainer.children.Button1.children.Backdrop.hidden, "keyboard layout hides the backdrop")

isGamepad = true
SkillBar.UpdateBackBarLayout(rootFrame)
assert_true(backBarContainer.children.Button1.children.Border.hidden, "gamepad layout hides keyboard borders")
assert_true(not backBarContainer.children.Button1.children.Backdrop.hidden, "gamepad layout shows the backdrop")
assert_eq(backBarContainer.children.Button6.dimensions[1], 48, "gamepad layout sizes the ultimate button from config")

SkillBar.SetupBackBarTooltips(rootFrame)
assert_eq(#tooltipCalls, 6, "back bar tooltip setup registers handlers for every back bar slot")
assert_eq(tooltipCalls[6].slotIndex, 8, "back bar tooltip setup includes the ultimate slot")

cooldownWindows = {
    ["3_" .. HOTBAR_CATEGORY_BACKUP] = { show = true, remainMs = 2500, durationMs = 5000 },
}
isGamepad = true
SkillBar.UpdateBackBarCooldowns(rootFrame)
assert_true(not backBarContainer.children.Button1.children.CooldownText.hidden, "gamepad cooldown update shows the cooldown text when a cooldown is active")
assert_eq(backBarContainer.children.Button1.children.CooldownText.text, "2.5", "cooldown text uses the smoothed remaining time")
assert_eq(backBarContainer.children.Button1.children.CooldownText.font, "$(BOLD_FONT)|30|thick-outline", "cooldown text size is clamped through the shared helper")
assert_eq(backBarContainer.children.Button1.children.CooldownText.color[1], 0.1, "cooldown text uses the configured color")

cooldownWindows = {}
SkillBar.UpdateBackBarCooldowns(rootFrame)
assert_true(backBarContainer.children.Button1.children.CooldownOverlay.hidden, "cooldown update hides the overlay when the slot is no longer cooling down")
assert_true(resetCalls["3_" .. HOTBAR_CATEGORY_BACKUP], "cooldown update resets smoothing state when a slot leaves cooldown")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
