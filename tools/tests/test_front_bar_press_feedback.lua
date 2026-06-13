--[[
File: tools/tests/test_front_bar_press_feedback.lua
Purpose: Unit tests for ResourceOrbFrames/SkillBar/FrontBarPressFeedback.lua
         using the actual module code.
Usage:
  lua tools/tests/test_front_bar_press_feedback.lua
]]

BETTERUI = {
    ResourceOrbFrames = {
        SkillBar = {},
        Utils = {},
    },
}

local moduleSettings = {
    customFrontBar = {
        m_enabled = true,
    },
}

function BETTERUI.ResourceOrbFrames.Utils.GetSettings()
    return moduleSettings
end

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

-- Canonical control helpers (mirrors Core/Utils.lua, consumed by FrontBarPressFeedback)
function BETTERUI.ResourceOrbFrames.Utils.GetNamedChildDirect(parent, name)
    if parent and parent.GetNamedChild then
        return parent:GetNamedChild(name)
    end
    return nil
end

function BETTERUI.ResourceOrbFrames.Utils.GetFrontBarButtonControl(rootFrame, frontBarContainer, buttonName)
    local U = BETTERUI.ResourceOrbFrames.Utils
    if buttonName == "QuickslotButton" or buttonName == "CompanionButton" then
        return U.GetNamedChildDirect(rootFrame, buttonName)
            or U.GetNamedChildDirect(frontBarContainer, buttonName)
            or U.FindControl(rootFrame, buttonName)
            or U.FindControl(frontBarContainer, buttonName)
    end
    return U.GetNamedChildDirect(frontBarContainer, buttonName)
        or U.FindControl(frontBarContainer, buttonName)
end

HOTBAR_CATEGORY_QUICKSLOT_WHEEL = 9
HOTBAR_CATEGORY_COMPANION = 10
ACTION_BAR_ULTIMATE_SLOT_INDEX = 7
ACTION_TYPE_NOTHING = 0
ACTION_TYPE_ITEM = 1
POWERTYPE_ULTIMATE = 11

local nowMs = 1000
local hookCount = 0
local lastHook = nil
local nativeButtonUsable = {}
local slotTypes = {}
local slotItemCounts = {}
local slotAbilityCosts = {}
local slotFailures = {
    cost = {},
    state = {},
    target = {},
    range = {},
}
local currentUltimate = 0

local function SlotKey(slotIndex, hotbarCategory)
    return tostring(slotIndex) .. "_" .. tostring(hotbarCategory)
end

function GetGameTimeMilliseconds()
    return nowMs
end

function GetActiveHotbarCategory()
    return 1
end

function GetCurrentQuickslot()
    return 9
end

function GetSlotType(slotIndex, hotbarCategory)
    return slotTypes[SlotKey(slotIndex, hotbarCategory)] or 2
end

function GetSlotItemCount(slotIndex, hotbarCategory)
    return slotItemCounts[SlotKey(slotIndex, hotbarCategory)] or 0
end

function ActionSlotHasCostFailure(slotIndex, hotbarCategory)
    return slotFailures.cost[SlotKey(slotIndex, hotbarCategory)] or false
end

function ActionSlotHasNonCostStateFailure(slotIndex, hotbarCategory)
    return slotFailures.state[SlotKey(slotIndex, hotbarCategory)] or false
end

function ActionSlotHasTargetFailure(slotIndex, hotbarCategory)
    return slotFailures.target[SlotKey(slotIndex, hotbarCategory)] or false
end

function ActionSlotHasRangeFailure(slotIndex, hotbarCategory)
    return slotFailures.range[SlotKey(slotIndex, hotbarCategory)] or false
end

-- ORB-001: real signature is GetSlotAbilityCost(actionSlotIndex, mechanicType, hotbarCategory);
-- mechanicType (2nd, required) is the combat-mechanic flag, hotbarCategory is the 3rd arg.
function GetSlotAbilityCost(slotIndex, mechanicType, hotbarCategory)
    return slotAbilityCosts[SlotKey(slotIndex, hotbarCategory)] or 0
end

function GetUnitPower()
    return currentUltimate
end

function ZO_ActionBar_GetButton(slotIndex, hotbarCategory)
    local usable = nativeButtonUsable[SlotKey(slotIndex, hotbarCategory)]
    if usable == nil then
        return nil
    end
    return {
        usable = usable,
    }
end

function ZO_PreHook(name, callback)
    hookCount = hookCount + 1
    lastHook = {
        name = name,
        callback = callback,
    }
end

local function NewAnimation()
    return {
        widthRange = nil,
        heightRange = nil,
        duration = nil,
        SetStartAndEndWidth = function(self, startValue, endValue)
            self.widthRange = { startValue, endValue }
        end,
        SetStartAndEndHeight = function(self, startValue, endValue)
            self.heightRange = { startValue, endValue }
        end,
        SetDuration = function(self, value)
            self.duration = value
        end,
    }
end

local function NewTimeline()
    return {
        animations = {
            NewAnimation(),
            NewAnimation(),
            NewAnimation(),
        },
        playing = false,
        playCount = 0,
        GetAnimation = function(self, index)
            return self.animations[index]
        end,
        IsPlaying = function(self)
            return self.playing
        end,
        PlayFromStart = function(self)
            self.playCount = self.playCount + 1
            self.playing = true
        end,
    }
end

ANIMATION_MANAGER = {}

function ANIMATION_MANAGER:CreateTimelineFromVirtual(_, _target)
    return NewTimeline()
end

ZO_AlphaAnimation = {}

function ZO_AlphaAnimation:New(control)
    return {
        control = control,
        stopCount = 0,
        pingPongArgs = nil,
        Stop = function(self)
            self.stopCount = self.stopCount + 1
        end,
        PingPong = function(self, startAlpha, endAlpha, durationMs, loopCount, onComplete)
            self.pingPongArgs = { startAlpha, endAlpha, durationMs, loopCount }
            if onComplete then
                onComplete()
            end
        end,
    }
end

ZO_GAMEPAD_ACTION_BUTTON_SIZE = 64

local function NewControl(name, width, height)
    local control = {
        name = name,
        width = width or 64,
        height = height or 64,
        hidden = false,
        alpha = 0,
        children = {},
        setDimensionsCount = 0,
    }

    function control:GetNamedChild(childName)
        return self.children[childName]
    end

    function control:AddNamedChild(childName, child)
        self.children[childName] = child
    end

    function control:GetDimensions()
        return self.width, self.height
    end

    function control:SetDimensions(widthValue, heightValue)
        self.width = widthValue
        self.height = heightValue
        self.setDimensionsCount = self.setDimensionsCount + 1
    end

    function control:IsHidden()
        return self.hidden
    end

    function control:SetHidden(value)
        self.hidden = value
    end

    function control:SetAlpha(value)
        self.alpha = value
    end

    return control
end

dofile("Modules/ResourceOrbFrames/SkillBar/FrontBarPressFeedback.lua")

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

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

local function BuildButtonFixture(buttonName)
    if BETTERUI.ResourceOrbFrames.SkillBar._testLastContainer then
        BETTERUI.ResourceOrbFrames.SkillBar._testLastContainer.hidden = true
    end

    local rootFrame = NewControl("RootFrame")
    local frontBarContainer = NewControl("FrontBarContainer")
    rootFrame:AddNamedChild("FrontBarContainer", frontBarContainer)
    BETTERUI.ResourceOrbFrames.SkillBar._testLastContainer = frontBarContainer

    local button = NewControl(buttonName)
    local flipCard = NewControl(buttonName .. "_FlipCard", 72, 72)
    local icon = NewControl(buttonName .. "_Icon", 64, 64)
    local pressHighlight = NewControl(buttonName .. "_PressHighlight", 64, 64)
    pressHighlight.hidden = true
    local unusableOverlay = NewControl(buttonName .. "_UnusableOverlay", 64, 64)
    unusableOverlay.hidden = true

    button:AddNamedChild("FlipCard", flipCard)
    button:AddNamedChild("Icon", icon)
    button:AddNamedChild("PressHighlight", pressHighlight)
    button:AddNamedChild("UnusableOverlay", unusableOverlay)
    frontBarContainer:AddNamedChild(buttonName, button)

    local buttonCache = SkillBar._frontBarButtonCache or {}
    for key in pairs(buttonCache) do
        buttonCache[key] = nil
    end
    buttonCache[buttonName] = {
        children = {
            FlipCard = flipCard,
            Icon = icon,
            PressHighlight = pressHighlight,
            UnusableOverlay = unusableOverlay,
        },
    }
    SkillBar._frontBarButtonCache = buttonCache

    return {
        rootFrame = rootFrame,
        container = frontBarContainer,
        button = button,
        flipCard = flipCard,
        icon = icon,
        pressHighlight = pressHighlight,
        unusableOverlay = unusableOverlay,
    }
end

print("[SetPressFeedbackBaseSize]")
do
    local fixture = BuildButtonFixture("Button1")
    SkillBar.SetPressFeedbackBaseSize(fixture.button, 80, 82, 70, 72)
    assert_eq(fixture.button.betterUIPressFeedbackBaseFrameWidth, 80, "base frame width is cached")
    assert_eq(fixture.button.betterUIPressFeedbackBaseFrameHeight, 82, "base frame height is cached")
    assert_eq(fixture.button.betterUIPressFeedbackBaseIconWidth, 70, "base icon width is cached")
    assert_eq(fixture.button.betterUIPressFeedbackBaseIconHeight, 72, "base icon height is cached")
end

print("[PlayFrontBarPressFeedbackForSlot]")
do
    local fixture = BuildButtonFixture("Button1")
    SkillBar.SetPressFeedbackBaseSize(fixture.button, 80, 80, 72, 72)

    nativeButtonUsable[SlotKey(3, 1)] = true
    slotTypes[SlotKey(3, 1)] = 2
    nowMs = 1000

    SkillBar.PlayFrontBarPressFeedbackForSlot(fixture.rootFrame, 3, 1, false)

    local state = fixture.button.betterUIPressFeedback
    assert_true(state ~= nil, "press feedback state is created on first play")
    assert_eq(state.bounceAnimation.playCount, 1, "frame bounce animation plays")
    assert_eq(state.iconBounceAnimation.playCount, 1, "icon bounce animation plays")
    assert_eq(fixture.flipCard.width, 80, "flip card dimensions reset to cached base size")
    assert_eq(fixture.icon.width, 72, "icon dimensions reset to cached base size")
    assert_eq(fixture.pressHighlight.hidden, true, "press highlight is hidden after animation callback")
    assert_eq(fixture.pressHighlight.alpha, 0, "press highlight alpha is reset after animation callback")

    SkillBar.PlayFrontBarPressFeedbackForSlot(fixture.rootFrame, 3, 1, false)
    assert_eq(state.bounceAnimation.playCount, 1, "dedupe window suppresses immediate replay")

    state.bounceAnimation.playing = false
    state.iconBounceAnimation.playing = false
    nowMs = 1200
    SkillBar.PlayFrontBarPressFeedbackForSlot(fixture.rootFrame, 3, 1, false)
    assert_eq(state.bounceAnimation.playCount, 2, "replay occurs once dedupe window expires")
end

print("[PlayFrontBarPressFeedbackForSlot usability gates]")
do
    local fixture = BuildButtonFixture("Button1")
    SkillBar.SetPressFeedbackBaseSize(fixture.button, 80, 80, 72, 72)

    nativeButtonUsable[SlotKey(3, 1)] = true
    slotTypes[SlotKey(3, 1)] = 2
    fixture.unusableOverlay.hidden = false
    nowMs = 1500

    SkillBar.PlayFrontBarPressFeedbackForSlot(fixture.rootFrame, 3, 1, false)
    local state = fixture.button.betterUIPressFeedback
    assert_true(state == nil, "visible unusable overlay blocks feedback without bypass")

    SkillBar.PlayFrontBarPressFeedbackForSlot(fixture.rootFrame, 3, 1, true)
    state = fixture.button.betterUIPressFeedback
    assert_true(state ~= nil, "bypass flag allows feedback despite unusable overlay")

    local quickslotFixture = BuildButtonFixture("QuickslotButton")
    SkillBar.SetPressFeedbackBaseSize(quickslotFixture.button, 80, 80, 72, 72)
    quickslotFixture.rootFrame:AddNamedChild("QuickslotButton", quickslotFixture.button)
    nativeButtonUsable[SlotKey(9, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)] = true
    slotTypes[SlotKey(9, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)] = ACTION_TYPE_ITEM
    slotItemCounts[SlotKey(9, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)] = 0
    nowMs = 1700

    SkillBar.PlayFrontBarPressFeedbackForSlot(
        quickslotFixture.rootFrame,
        9,
        HOTBAR_CATEGORY_QUICKSLOT_WHEEL,
        false)
    assert_true(
        quickslotFixture.button.betterUIPressFeedback == nil,
        "empty quickslot item count blocks press feedback")
end

print("[SetupFrontBarPressFeedbackHooks]")
do
    hookCount = 0
    lastHook = nil

    local fixture = BuildButtonFixture("Button1")
    SkillBar.SetupFrontBarPressFeedbackHooks(fixture.rootFrame)
    SkillBar.SetupFrontBarPressFeedbackHooks(fixture.rootFrame)

    assert_eq(hookCount, 1, "press feedback hook installs once")
    assert_eq(lastHook.name, "ZO_ActionBar_OnActionButtonUp", "press feedback installs the expected hook")
    assert_true(type(lastHook.callback) == "function", "press feedback hook captures a callback")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
