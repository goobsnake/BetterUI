--[[
File: tools/tests/test_front_bar_manager.lua
Purpose: Regression coverage for ResourceOrbFrames/SkillBar/FrontBarManager.lua
         using the actual module code.

Usage:
  lua tools/tests/test_front_bar_manager.lua
]]

local traceEvents = {}
local lastAction = nil

BETTERUI = {
    ResourceOrbFrames = {
        SkillBar = {
            CONST = {
                COOLDOWN_DURATION_THRESHOLD = 1500,
                FRONT_BAR_SLOTS = {
                    { buttonName = "Button1", slot = 3 },
                    { buttonName = "Button2", slot = 4 },
                    { buttonName = "Button3", slot = 5 },
                    { buttonName = "Button4", slot = 6 },
                    { buttonName = "Button5", slot = 7 },
                    { buttonName = "UltimateButton", slot = 8 },
                },
                SLOT_KEYBINDS = {
                    [1] = { keyboard = "ACTION_BUTTON_3", gamepad = "GAMEPAD_ACTION_BUTTON_3" },
                    [2] = { keyboard = "ACTION_BUTTON_4", gamepad = "GAMEPAD_ACTION_BUTTON_4" },
                    [3] = { keyboard = "ACTION_BUTTON_5", gamepad = "GAMEPAD_ACTION_BUTTON_5" },
                    [4] = { keyboard = "ACTION_BUTTON_6", gamepad = "GAMEPAD_ACTION_BUTTON_6" },
                    [5] = { keyboard = "ACTION_BUTTON_7", gamepad = "GAMEPAD_ACTION_BUTTON_7" },
                },
                HIDE_UNBOUND = false,
            },
            CooldownUtils = {},
        },
        Utils = {},
    },
    CIM = {
        ControlCache = {},
    },
    Log = {
        CATEGORY = {
            ACTION = "ACTION",
            GENERAL = "GENERAL",
        },
        SetLastAction = function(action)
            lastAction = action
        end,
        TraceEvent = function(category, event, phase, data)
            traceEvents[#traceEvents + 1] = {
                category = category,
                event = event,
                phase = phase,
                data = data,
            }
        end,
    },
}

local settings = {
    customFrontBar = {
        m_enabled = true,
    },
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

function BETTERUI.ResourceOrbFrames.Utils.GetFrontBarButtonControl(rootFrame, frontBarContainer, name)
    return BETTERUI.ResourceOrbFrames.Utils.FindControl(frontBarContainer, name)
        or BETTERUI.ResourceOrbFrames.Utils.FindControl(rootFrame, name)
end

BETTERUI.CIM.ControlCache.CacheButtonChildren = function(button)
    return button.children
end

ACTION_BAR_ULTIMATE_SLOT_INDEX = 7
ACTION_BAR_FIRST_NORMAL_SLOT_INDEX = 3
ACTION_BAR_SLOTS_PER_PAGE = 5
HOTBAR_CATEGORY_QUICKSLOT_WHEEL = 9
HOTBAR_CATEGORY_COMPANION = 10
POWERTYPE_ULTIMATE = 11
COMBAT_MECHANIC_FLAGS_ULTIMATE = 64
LEFT = "LEFT"
RIGHT = "RIGHT"
CENTER = "CENTER"
BOTTOM = "BOTTOM"
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

local tooltipCalls = {}
local keybindCalls = {}
local quickslotAnchorCalls = 0
local quickslotStateCalls = {}
local pressFeedbackCalls = {}
local texturesBySlot = {}
local activationAnimationTextures = {}
local activationHighlights = {}
local costFailures = {}
local stateFailures = {}
local targetFailures = {}
local nativeActionButtons = {}
local rangeFailures = {}
local abilityCosts = {}
local slotCooldowns = {}
local effectDurations = {}
local nowMs = 1000
local currentUltimate = 0
local activeHotbarCategory = 1
local currentQuickslot = 9
local companionExists = false
local companionActive = false
local isGamepad = true

function GetActiveHotbarCategory()
    return activeHotbarCategory
end

function GetCurrentQuickslot()
    return currentQuickslot
end

function GetSlotTexture(slotIndex, hotbarCategory)
    local key = tostring(slotIndex) .. "_" .. tostring(hotbarCategory)
    return texturesBySlot[key] or "", nil, activationAnimationTextures[key]
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

function ActionSlotHasTargetFailure(slotIndex, hotbarCategory)
    return targetFailures[tostring(slotIndex) .. "_" .. tostring(hotbarCategory)] or false
end

function ActionSlotHasRangeFailure(slotIndex, hotbarCategory)
    return rangeFailures[tostring(slotIndex) .. "_" .. tostring(hotbarCategory)] or false
end

local lastSlotAbilityCostArgs = nil

-- ORB-001: real signature is GetSlotAbilityCost(actionSlotIndex, mechanicType, hotbarCategory).
-- The mechanicType (2nd) arg is required and must be the ultimate combat-mechanic flag for the
-- ultimate slot; hotbarCategory is the 3rd arg. Record args so the regression test can assert them.
function GetSlotAbilityCost(slotIndex, mechanicType, hotbarCategory)
    lastSlotAbilityCostArgs = { slotIndex = slotIndex, mechanicType = mechanicType, hotbarCategory = hotbarCategory }
    return abilityCosts[tostring(slotIndex) .. "_" .. tostring(hotbarCategory)] or 0
end

function GetUnitPower()
    return currentUltimate
end

function GetSlotCooldownInfo(slotIndex, hotbarCategory)
    local entry = slotCooldowns[tostring(slotIndex) .. "_" .. tostring(hotbarCategory)] or {}
    return entry.remainMs or 0, entry.durationMs or 0, entry.isGlobalCooldown or false
end

function GetActionSlotEffectTimeRemaining(slotIndex, hotbarCategory)
    return effectDurations[tostring(slotIndex) .. "_" .. tostring(hotbarCategory)] or 0
end

function GetGameTimeMilliseconds()
    return nowMs
end

function ZO_Keybindings_RegisterLabelForBindingUpdate(label, keyboardBinding, _, gamepadBinding)
    table.insert(keybindCalls, {
        label = label.name,
        keyboardBinding = keyboardBinding,
        gamepadBinding = gamepadBinding,
    })
end

function IsInGamepadPreferredMode()
    return isGamepad
end

function DoesUnitExist()
    return companionExists
end

function HasActiveCompanion()
    return companionActive
end

ZO_ActionBar1 = {
    hidden = false,
    alpha = 1,
    SetHidden = function(self, value)
        self.hidden = value
    end,
    SetAlpha = function(self, value)
        self.alpha = value
    end,
}

ZO_ActionBarTimer = {
    hidden = false,
    SetHidden = function(self, value)
        self.hidden = value
    end,
}

ZO_ActionBar1KeybindBG = {
    hidden = false,
    SetHidden = function(self, value)
        self.hidden = value
    end,
}

ZO_ActionBar1WeaponSwap = {
    hidden = false,
    permanentlyHidden = false,
    SetHidden = function(self, value)
        self.hidden = value
    end,
}

function ZO_WeaponSwap_SetPermanentlyHidden(control, value)
    control.permanentlyHidden = value
end

local function NewNativeActionButton(name)
    return {
        name = name,
        hidden = false,
        alpha = 1,
        SetHidden = function(self, value)
            self.hidden = value
        end,
        SetAlpha = function(self, value)
            self.alpha = value
        end,
        slot = {
            name = name .. "Slot",
            hidden = false,
            alpha = 1,
            SetHidden = function(self, value)
                self.hidden = value
            end,
            SetAlpha = function(self, value)
                self.alpha = value
            end,
        },
        buttonText = {
            name = name .. "Text",
            hidden = false,
            SetHidden = function(self, value)
                self.hidden = value
            end,
        },
    }
end

for slot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
    nativeActionButtons[tostring(slot) .. "_nil"] = NewNativeActionButton("NativeSlot" .. tostring(slot))
end
nativeActionButtons["1_" .. tostring(HOTBAR_CATEGORY_QUICKSLOT_WHEEL)] = NewNativeActionButton("NativeQuickslot")

function ZO_ActionBar_GetButton(slot, hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        return nativeActionButtons["1_" .. tostring(HOTBAR_CATEGORY_QUICKSLOT_WHEEL)]
    end
    return nativeActionButtons[tostring(slot) .. "_" .. tostring(hotbarCategory)]
end

ZO_AlphaAnimation = {}
function ZO_AlphaAnimation:New(control)
    return {
        control = control,
        SetMinMaxAlpha = function(self, minAlpha, maxAlpha)
            self.minMaxAlpha = { minAlpha, maxAlpha }
        end,
    }
end

BETTERUI_ORB_FRAMES = {
    slots = {
        keyboard = { width = 32, spacing = 4 },
        gamepad = { width = 40, spacing = 5 },
    },
    bars = {
        shiftY = 70,
        ultimateGap = 8,
        quickslot = { x = -120, y = 2 },
        companionUltimate = { x = 120, y = 40 },
        customFrontBar = {
            offsetX = 4,
            offsetY = 6,
            keyboard = { buttonSize = 32, spacing = 4, ultimateSize = 38 },
            gamepad = { buttonSize = 40, spacing = 5, ultimateSize = 48 },
            ultimate = { offsetX = 3, offsetY = 2 },
            quickslotButton = { offsetX = 7, offsetY = 8 },
            companionButton = { offsetX = -9, offsetY = 10 },
        },
        customBackBar = {
            offsetY = -5,
        },
        bottom = {
            gamepadY = -15,
            keyboardY = -15,
        },
        top = {
            gamepadY = -95,
            keyboardY = -95,
        },
    },
}

local CooldownUtils = BETTERUI.ResourceOrbFrames.SkillBar.CooldownUtils
function CooldownUtils.BuildStateKey(slotIndex, hotbarCategory)
    return tostring(slotIndex) .. "_" .. tostring(hotbarCategory)
end

local function NewControl(name)
    local control = {
        name = name,
        children = {},
        hidden = false,
        anchor = nil,
        dimensions = nil,
        text = nil,
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

    function control:SetTexture(value)
        self.texture = value
    end

    function control:SetDimensions(width, height)
        self.dimensions = { width, height }
    end

    function control:ClearAnchors()
        self.anchor = nil
    end

    function control:SetAnchor(...)
        self.anchor = { ... }
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

    function control:SetParent(parent)
        self.parent = parent
    end

    return control
end

local function NewButton(name)
    local button = NewControl(name)
    button.children.Icon = NewControl(name .. "Icon")
    button.children.UnusableOverlay = NewControl(name .. "UnusableOverlay")
    button.children.ActivationHighlight = NewControl(name .. "ActivationHighlight")
    button.children.ActivationHighlight:SetHidden(true)
    button.children.ButtonText = NewControl(name .. "ButtonText")
    button.children.ButtonText.name = name .. "ButtonText"
    button.children.LeftKeybind = NewControl(name .. "LeftKeybind")
    button.children.RightKeybind = NewControl(name .. "RightKeybind")
    button.children.CountText = NewControl(name .. "CountText")
    button.children.TimerText = NewControl(name .. "TimerText")
    button.children.CooldownText = NewControl(name .. "CooldownText")
    button.children.FlipCard = NewControl(name .. "FlipCard")
    button.children.Glow = NewControl(name .. "Glow")
    button.children.ReadyBurst = NewControl(name .. "ReadyBurst")
    button.children.ReadyLoop = NewControl(name .. "ReadyLoop")
    button.children.FillAnimationLeft = NewControl(name .. "FillAnimationLeft")
    button.children.FillAnimationRight = NewControl(name .. "FillAnimationRight")
    return button
end

local rootFrame = NewControl("Root")
local bgMiddle = NewControl("BgMiddle")
local frontBarContainer = NewControl("FrontBarContainer")
rootFrame.children.BgMiddle = bgMiddle
rootFrame.children.FrontBarContainer = frontBarContainer
for i = 1, 5 do
    frontBarContainer.children["Button" .. i] = NewButton("Button" .. i)
end
frontBarContainer.children.UltimateButton = NewButton("UltimateButton")
frontBarContainer.children.QuickslotButton = NewButton("QuickslotButton")
frontBarContainer.children.CompanionButton = NewButton("CompanionButton")

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
SkillBar.SetupButtonTooltip = function(button, slotIndex, hotbarCategory)
    table.insert(tooltipCalls, {
        button = button.name,
        slotIndex = slotIndex,
        hotbarCategory = hotbarCategory,
    })
end

SkillBar.AnchorQuickslotCountText = function(button, label)
    quickslotAnchorCalls = quickslotAnchorCalls + 1
    label.anchoredTo = button.name
end

SkillBar.UpdateQuickslotCountAndEmptyState = function(button, _, _, slotIndex, hotbarCategory)
    table.insert(quickslotStateCalls, {
        button = button.name,
        slotIndex = slotIndex,
        hotbarCategory = hotbarCategory,
    })
    return false
end

SkillBar.SetPressFeedbackBaseSize = function(button, width, height)
    table.insert(pressFeedbackCalls, {
        button = button.name,
        width = width,
        height = height,
    })
end

dofile("Modules/ResourceOrbFrames/SkillBar/ActivationHighlight.lua")
dofile("Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua")

local internals = SkillBar._FrontBarInternals

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

local function count_trace(event, phase)
    local count = 0
    for _, entry in ipairs(traceEvents) do
        if entry.event == event and entry.phase == phase then
            count = count + 1
        end
    end
    return count
end

print("[FrontBarManager]")

assert_true(type(internals) == "table", "front bar manager exports test internals")

local slotStateKey = CooldownUtils.BuildStateKey(3, activeHotbarCategory)
assert_true(internals.ResolveTargetFailureWithCastLatch(slotStateKey, true, false, nowMs), "target failure helper reports immediate failures")
assert_true(internals.ResolveTargetFailureWithCastLatch(slotStateKey, false, true, nowMs + 100), "target failure helper latches recent failures during casting")
assert_true(not internals.ResolveTargetFailureWithCastLatch(slotStateKey, false, true, nowMs + 500), "target failure helper clears expired cast latches")

assert_true(internals.ResolveNonCostFailureWithCastLatch(slotStateKey, true, false, nowMs), "non-cost failure helper reports immediate failures")
assert_true(internals.ResolveNonCostFailureWithCastLatch(slotStateKey, false, true, nowMs + 100), "non-cost failure helper latches recent failures during casting")
assert_true(not internals.ResolveNonCostFailureWithCastLatch(slotStateKey, false, true, nowMs + 500), "non-cost failure helper clears expired cast latches")

abilityCosts["8_" .. activeHotbarCategory] = 100
currentUltimate = 50
lastSlotAbilityCostArgs = nil
assert_true(internals.HasInsufficientUltimate(8, activeHotbarCategory), "ultimate helper flags insufficient ultimate power")
-- ORB-001 regression: the ultimate-cost call must pass the ultimate combat-mechanic flag as the
-- REQUIRED 2nd (mechanicType) arg and the hotbar category as the 3rd arg, so a non-zero ultimate
-- cost actually resolves (a 2-arg call put the category in the mechanicType slot and read cost 0).
assert_true(lastSlotAbilityCostArgs ~= nil, "ultimate helper invokes GetSlotAbilityCost")
assert_eq(lastSlotAbilityCostArgs.slotIndex, 8, "ultimate cost queries the ultimate slot index")
assert_eq(lastSlotAbilityCostArgs.mechanicType, COMBAT_MECHANIC_FLAGS_ULTIMATE, "ultimate cost passes COMBAT_MECHANIC_FLAGS_ULTIMATE as the mechanicType (2nd) arg")
assert_eq(lastSlotAbilityCostArgs.hotbarCategory, activeHotbarCategory, "ultimate cost passes the hotbar category as the 3rd arg")
assert_true(not internals.HasInsufficientUltimate(3, activeHotbarCategory), "ultimate helper ignores non-ultimate slots")

slotCooldowns["3_" .. activeHotbarCategory] = { remainMs = 2000, durationMs = 4000, isGlobalCooldown = false }
assert_true(internals.ShouldSuppressUnusableOverlayForCooldown(3, activeHotbarCategory), "cooldown helper suppresses unusable overlays for long cooldowns")
slotCooldowns["3_" .. activeHotbarCategory] = { remainMs = 0, durationMs = 0, isGlobalCooldown = false }
effectDurations["3_" .. activeHotbarCategory] = 1000
assert_true(internals.ShouldSuppressUnusableOverlayForCooldown(3, activeHotbarCategory), "cooldown helper suppresses unusable overlays for active effects")
effectDurations["3_" .. activeHotbarCategory] = 0

SkillBar.CacheFrontBarControls(rootFrame)
assert_true(SkillBar._frontBarButtonCache.Button1 ~= nil, "front bar cache stores primary buttons")
assert_true(SkillBar._frontBarButtonCache.QuickslotButton ~= nil, "front bar cache stores the quickslot button")

SkillBar.HideNativeActionBar()
assert_true(ZO_ActionBar1.hidden, "hide native action bar hides the default action bar")
assert_true(ZO_ActionBarTimer.hidden, "hide native action bar hides the default timer")
assert_true(ZO_ActionBar1KeybindBG.hidden, "hide native action bar hides the native keybind background")
assert_true(ZO_ActionBar1WeaponSwap.hidden, "hide native action bar hides the native weapon swap control")
assert_true(ZO_ActionBar1WeaponSwap.permanentlyHidden, "hide native action bar permanently hides the native weapon swap control")
assert_true(nativeActionButtons["3_nil"].slot.hidden, "hide native action bar hides the first normal native button slot")
assert_eq(nativeActionButtons["3_nil"].slot.alpha, 0, "hide native action bar zeroes native button slot alpha")
assert_true(nativeActionButtons["3_nil"].buttonText.hidden, "hide native action bar hides the first normal native button text")
assert_true(nativeActionButtons["7_nil"].buttonText.hidden, "hide native action bar hides the last normal native button text")
assert_true(nativeActionButtons["1_" .. tostring(HOTBAR_CATEGORY_QUICKSLOT_WHEEL)].slot.hidden,
    "hide native action bar hides the native quickslot button slot")
assert_true(nativeActionButtons["1_" .. tostring(HOTBAR_CATEGORY_QUICKSLOT_WHEEL)].buttonText.hidden,
    "hide native action bar hides the native quickslot button text")
assert_true(count_trace("resource_orbs.native_action_bar", "hidden") == 1,
    "hide native action bar emits a builog trace")
assert_eq(traceEvents[#traceEvents].data.nativeQuickslotHidden, true,
    "hide native action bar trace records native quickslot suppression")
assert_true(lastAction ~= nil and lastAction.flow == "resource_orbs.native_action_bar",
    "hide native action bar updates last-action diagnostics")
SkillBar.RestoreNativeActionBar()
assert_true(not ZO_ActionBar1WeaponSwap.hidden, "restore native action bar restores the native weapon swap control")
assert_true(not ZO_ActionBar1WeaponSwap.permanentlyHidden, "restore native action bar clears permanent weapon swap hiding")
assert_true(not nativeActionButtons["3_nil"].slot.hidden, "restore native action bar restores the first normal native button slot")
assert_eq(nativeActionButtons["3_nil"].slot.alpha, 1, "restore native action bar restores native button slot alpha")
assert_true(not nativeActionButtons["3_nil"].buttonText.hidden, "restore native action bar restores the first normal native button text")
assert_true(not nativeActionButtons["1_" .. tostring(HOTBAR_CATEGORY_QUICKSLOT_WHEEL)].slot.hidden,
    "restore native action bar restores the native quickslot button slot")
assert_true(count_trace("resource_orbs.native_action_bar", "restored") == 1,
    "restore native action bar emits a builog trace")

texturesBySlot["3_" .. activeHotbarCategory] = "front-icon-3"
activationAnimationTextures["3_" .. activeHotbarCategory] = "front-proc-animation"
activationHighlights["3_" .. activeHotbarCategory] = true
SkillBar.UpdateFrontBar(rootFrame)
assert_eq(frontBarContainer.children.Button1.children.Icon.texture, "front-icon-3", "front bar update applies slot textures")
assert_true(not frontBarContainer.children.Button1.children.ActivationHighlight.hidden, "front bar update shows activation highlights for usable slots")
local frontProcHighlight = frontBarContainer.children.Button1.children.ActivationHighlight
assert_eq(frontProcHighlight.texture, "front-proc-animation",
    "front bar activation highlight uses the slot animation texture")
assert_true(frontProcHighlight.animation ~= nil, "front bar activation highlight creates a texture animation")
if frontProcHighlight.animation then
    assert_eq(frontProcHighlight.animation.imageData[1], 64,
        "front bar activation highlight is configured as a 64-frame horizontal animation")
    assert_eq(frontProcHighlight.animation.framerate, 30,
        "front bar activation highlight uses the native action-button framerate")
    assert_eq(frontProcHighlight.animation.timeline.playbackType, ANIMATION_PLAYBACK_LOOP,
        "front bar activation highlight loops like the native action button")
    assert_eq(frontProcHighlight.animation.timeline.playCount, 1,
        "front bar activation highlight starts the texture animation")
end

activationAnimationTextures["3_" .. activeHotbarCategory] = nil
SkillBar.UpdateFrontBar(rootFrame)
assert_true(frontProcHighlight.hidden,
    "front bar update hides activation highlights when the native animation texture is missing")
assert_eq(frontProcHighlight.texture, nil,
    "front bar activation highlight clears stale animation texture when native data is missing")
activationAnimationTextures["3_" .. activeHotbarCategory] = "front-proc-animation"

costFailures["3_" .. activeHotbarCategory] = true
slotCooldowns["3_" .. activeHotbarCategory] = { remainMs = 0, durationMs = 0, isGlobalCooldown = false }
SkillBar.UpdateFrontBarUsability(rootFrame, false)
assert_true(not frontBarContainer.children.Button1.children.UnusableOverlay.hidden, "front bar usability shows overlays for unusable abilities")

costFailures["3_" .. activeHotbarCategory] = false
slotCooldowns["3_" .. activeHotbarCategory] = { remainMs = 2000, durationMs = 4000, isGlobalCooldown = false }
SkillBar.UpdateFrontBarUsability(rootFrame, false)
assert_true(frontBarContainer.children.Button1.children.UnusableOverlay.hidden, "front bar usability hides overlays when cooldown visuals should take precedence")

tooltipCalls = {}
SkillBar.SetupFrontBarTooltips(rootFrame)
assert_eq(#tooltipCalls, 6, "front bar tooltip setup registers handlers for every front bar ability button")
assert_eq(tooltipCalls[6].slotIndex, 8, "front bar tooltip setup includes the ultimate slot")

keybindCalls = {}
quickslotAnchorCalls = 0
SkillBar.SetupFrontBarKeybinds(rootFrame)
assert_eq(#keybindCalls, 8, "front bar keybind setup registers button labels for skills, quickslot, and companion")
assert_eq(quickslotAnchorCalls, 1, "front bar keybind setup reanchors the quickslot count label")
assert_true(not frontBarContainer.children.UltimateButton.children.LeftKeybind.hidden, "front bar keybind setup shows gamepad ultimate labels in gamepad mode")

pressFeedbackCalls = {}
SkillBar.UpdateFrontBarLayout(rootFrame)
assert_eq(frontBarContainer.children.Button1.dimensions[1], 40, "front bar layout sizes normal buttons from config")
assert_eq(frontBarContainer.children.UltimateButton.dimensions[1], 48, "front bar layout sizes the ultimate button from config")
assert_eq(frontBarContainer.children.QuickslotButton.anchor[4], BETTERUI_ORB_FRAMES.bars.quickslot.x + BETTERUI_ORB_FRAMES.bars.customFrontBar.quickslotButton.offsetX + BETTERUI_ORB_FRAMES.bars.customFrontBar.offsetX, "front bar layout positions the quickslot button relative to the orb frame plus the whole-bar offset")
local expectedFrontBarY = BETTERUI_ORB_FRAMES.bars.bottom.gamepadY + BETTERUI_ORB_FRAMES.bars.customFrontBar.offsetY
local expectedBackBarY = BETTERUI_ORB_FRAMES.bars.top.gamepadY + BETTERUI_ORB_FRAMES.bars.shiftY + BETTERUI_ORB_FRAMES.bars.customBackBar.offsetY
local expectedQuickslotY = ((expectedFrontBarY + expectedBackBarY) / 2) + BETTERUI_ORB_FRAMES.bars.quickslot.y + BETTERUI_ORB_FRAMES.bars.customFrontBar.quickslotButton.offsetY
assert_eq(frontBarContainer.children.QuickslotButton.anchor[5], expectedQuickslotY, "front bar layout positions quickslot vertically between the skill bars")
assert_eq(frontBarContainer.children.CompanionButton.anchor[4], BETTERUI_ORB_FRAMES.bars.companionUltimate.x + BETTERUI_ORB_FRAMES.bars.customFrontBar.companionButton.offsetX + BETTERUI_ORB_FRAMES.bars.customFrontBar.offsetX, "front bar layout positions the companion button relative to the orb frame plus the whole-bar offset")
assert_eq(frontBarContainer.children.CompanionButton.anchor[5], BETTERUI_ORB_FRAMES.bars.companionUltimate.y + BETTERUI_ORB_FRAMES.bars.customFrontBar.companionButton.offsetY + BETTERUI_ORB_FRAMES.bars.customFrontBar.offsetY, "front bar layout applies the whole-bar Y offset to the companion button")
assert_true(frontBarContainer.children.UltimateButton.glowAnimation ~= nil, "front bar layout rebuilds the ultimate glow animation")
assert_true(#pressFeedbackCalls >= 7, "front bar layout refreshes press-feedback sizing for all front bar buttons")

tooltipCalls = {}
quickslotStateCalls = {}
texturesBySlot["9_" .. HOTBAR_CATEGORY_QUICKSLOT_WHEEL] = "quickslot-icon"
SkillBar.UpdateFrontBarQuickslot(rootFrame)
assert_eq(frontBarContainer.children.QuickslotButton.children.Icon.texture, "quickslot-icon", "front bar quickslot update applies the quickslot icon")
assert_eq(frontBarContainer.children.QuickslotButton.slotIndex, 9, "front bar quickslot update stores the quickslot slot index")
assert_eq(frontBarContainer.children.QuickslotButton.hotbarCategory, HOTBAR_CATEGORY_QUICKSLOT_WHEEL, "front bar quickslot update stores the quickslot hotbar category")
assert_true(frontBarContainer.children.QuickslotButton.tooltipHandlersAdded, "front bar quickslot update adds tooltip handlers on first refresh")
assert_eq(#quickslotStateCalls, 1, "front bar quickslot update delegates count/empty-state refreshes")

companionExists = false
companionActive = false
SkillBar.UpdateFrontBarCompanion(rootFrame)
assert_true(frontBarContainer.children.CompanionButton.hidden, "front bar companion update hides the companion button when no companion is active")

companionExists = true
companionActive = true
texturesBySlot["8_" .. HOTBAR_CATEGORY_COMPANION] = "companion-icon"
tooltipCalls = {}
SkillBar.UpdateFrontBarCompanion(rootFrame)
assert_true(not frontBarContainer.children.CompanionButton.hidden, "front bar companion update shows the button for active companions")
assert_eq(frontBarContainer.children.CompanionButton.children.Icon.texture, "companion-icon", "front bar companion update applies the companion icon")
assert_eq(frontBarContainer.children.CompanionButton.hotbarCategory, HOTBAR_CATEGORY_COMPANION, "front bar companion update stores the companion hotbar category")
assert_true(frontBarContainer.children.CompanionButton.tooltipHandlersAdded, "front bar companion update adds tooltip handlers on first refresh")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
