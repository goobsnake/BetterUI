--[[
File: tools/tests/test_resource_orbframes.lua
Purpose: Regression coverage for Modules/ResourceOrbFrames/ResourceOrbFrames.lua
         using the actual module code.

Usage:
  lua tools/tests/test_resource_orbframes.lua
]]

local settings = {
    m_enabled = true,
    customFrontBar = {
        m_enabled = true,
    },
    hideLeftOrnament = false,
    hideRightOrnament = false,
    hideBackBar = false,
}

local tryCalls = {}
local registeredEvents = {}
local filteredEvents = {}
local callbackRegistrations = {}
local eventUnregisters = {}
local fragmentCalls = {}
local skillCalls = {}
local visualCalls = {}
local barCalls = {}
local eventCalls = {}

local function CountCall(store, key)
    store[key] = (store[key] or 0) + 1
end

local function NewControl(name)
    local control = {
        name = name,
        children = {},
        hidden = false,
        anchor = nil,
        dimensions = nil,
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

    function control:SetParent(parent)
        self.parent = parent
    end

    function control:ClearAnchors()
        self.anchor = nil
    end

    function control:SetAnchor(...)
        self.anchor = { ... }
    end

    function control:SetDimensions(width, height)
        self.dimensions = { width, height }
    end

    return control
end

BETTERUI = {
    ResourceOrbFrames = {
        Utils = {
            Settings = {},
            Controls = {},
        },
        SkillBar = {},
        Visuals = {},
        Bars = {},
        Events = {},
        CONST = {
            BARS = {
                XP = { OFFSET_X = 0, OFFSET_Y = 0, NO_ORNAMENT_OFFSET_X = -350, NO_ORNAMENT_OFFSET_Y = 108 },
                MOUNT = { OFFSET_X = 0, OFFSET_Y = 0, NO_ORNAMENT_OFFSET_X = 375, NO_ORNAMENT_OFFSET_Y = 108 },
                CAST = { OFFSET_X = 0, OFFSET_Y = -24 },
            },
            LAYOUT_CONFIG = {
                KEYBOARD = { mode = "keyboard" },
                GAMEPAD = { mode = "gamepad" },
            },
        },
    },
    ControlUtils = {
        InvalidateControlCache = function()
            tryCalls["ControlUtils.InvalidateControlCache"] = (tryCalls["ControlUtils.InvalidateControlCache"] or 0) + 1
        end,
    },
    CIM = {
        DeferredTask = {
            Manager = {
                New = function()
                    return {
                        Schedule = function(_, _, _, callback)
                            callback()
                        end,
                    }
                end,
            },
            CreateManager = function()
                return BETTERUI.CIM.DeferredTask.Manager.New()
            end,
            CreateLazyManagerProxy = function(factory)
                return setmetatable({}, {
                    __index = function(_, key)
                        local manager = factory()
                        return manager and manager[key]
                    end,
                })
            end,
        },
        EventRegistry = {},
        CONST = {
            TIMING = {
                DEFERRED_INIT_MS = 1,
                WEAPON_SWAP_LAYOUT_DELAY_MS = 1,
                SCENE_HANDLER_DELAY_MS = 1,
                PLAYER_ACTIVATED_INIT_MS = 1,
            },
        },
        SafeExecute = function(_, callback, ...)
            return pcall(callback, ...)
        end,
        TryCall = function(path)
            tryCalls[path] = (tryCalls[path] or 0) + 1
            return true
        end,
        Debug = {
            FLAGS = {
                SHIELD_OVERLAY = false,
            },
        },
    },
}

function BETTERUI.ResourceOrbFrames.Utils.Settings.Get()
    return settings
end

function BETTERUI.ResourceOrbFrames.Utils.Settings.GetCustomFrontBar()
    return settings and settings.customFrontBar
end

function BETTERUI.ResourceOrbFrames.Utils.Controls.Find(parent, name)
    if not parent then return nil end
    if parent.GetNamedChild then
        local child = parent:GetNamedChild(name)
        if child then
            return child
        end
    end
    return parent.children and parent.children[name] or nil
end

function BETTERUI.CIM.EventRegistry.Register(_, name, eventCode, callback)
    registeredEvents[name] = { eventCode = eventCode, callback = callback }
end

function BETTERUI.CIM.EventRegistry.Unregister(_, name, eventCode)
    registeredEvents[name] = nil
    -- Mirror the real registry: bookkeeping plus EVENT_MANAGER unregistration.
    EVENT_MANAGER:UnregisterForEvent(name, eventCode)
end

function BETTERUI.CIM.EventRegistry.RegisterFiltered(_, name, eventCode, callback)
    filteredEvents[name] = { eventCode = eventCode, callback = callback }
end

CALLBACK_MANAGER = {
    RegisterCallback = function(_, name)
        callbackRegistrations[name] = (callbackRegistrations[name] or 0) + 1
    end,
}

EVENT_MANAGER = {
    UnregisterForEvent = function(_, name, eventCode)
        table.insert(eventUnregisters, { name = name, eventCode = eventCode })
    end,
}

PLAYER_ATTRIBUTE_BARS_FRAGMENT = {
    SetHiddenForReason = function(_, reason, hidden)
        table.insert(fragmentCalls, { reason = reason, hidden = hidden })
    end,
}

EVENT_PLAYER_ACTIVATED = 1
EVENT_ACTIVE_WEAPON_PAIR_CHANGED = 2
EVENT_ACTION_SLOTS_FULL_UPDATE = 3
EVENT_ACTION_SLOT_UPDATED = 4
EVENT_ACTIVE_COMPANION_STATE_CHANGED = 5
EVENT_ACTIVE_QUICKSLOT_CHANGED = 6
EVENT_ACTION_SLOT_ABILITY_USED = 7
EVENT_GAMEPAD_PREFERRED_MODE_CHANGED = 8
REGISTER_FILTER_UNIT_TAG = 9
POWERTYPE_HEALTH = 1
CENTER = "CENTER"
TOP = "TOP"
BOTTOM = "BOTTOM"

function IsInGamepadPreferredMode()
    return false
end

function GetUnitPower(_, powerType)
    if powerType == POWERTYPE_HEALTH then
        return 90, 100
    end
    return 10, 20
end

function ZO_StatusBar_SmoothTransition()
    CountCall(visualCalls, "SmoothTransition")
end

local poolControl = {
    GetMax = function()
        return 100
    end,
}

function BETTERUI.ResourceOrbFrames.Visuals.SetupPowerPools()
    CountCall(visualCalls, "SetupPowerPools")
    return {
        [POWERTYPE_HEALTH] = poolControl,
    }
end

function BETTERUI.ResourceOrbFrames.Visuals.SetupShieldBar()
    CountCall(visualCalls, "SetupShieldBar")
    return {
        SetRange = function() end,
        UpdateValue = function() end,
    }
end

function BETTERUI.ResourceOrbFrames.Visuals.UpdateFrameDimensions()
    CountCall(visualCalls, "UpdateFrameDimensions")
end

function BETTERUI.ResourceOrbFrames.Visuals.ApplyThemeVisuals()
    CountCall(visualCalls, "ApplyThemeVisuals")
end

function BETTERUI.ResourceOrbFrames.Visuals.UpdateOrbLayout()
    CountCall(visualCalls, "UpdateOrbLayout")
end

function BETTERUI.ResourceOrbFrames.Bars.CreateFoodTracker()
    CountCall(barCalls, "CreateFoodTracker")
    return {
        Update = function()
            CountCall(barCalls, "FoodTrackerUpdate")
        end,
    }
end

local function NewBar(key)
    return {
        control = NewControl(key .. "Control"),
        Update = function()
            CountCall(barCalls, key .. "Update")
        end,
    }
end

function BETTERUI.ResourceOrbFrames.Bars.CreateExperienceBar()
    CountCall(barCalls, "CreateExperienceBar")
    return NewBar("ExperienceBar")
end

function BETTERUI.ResourceOrbFrames.Bars.CreateCastBar()
    CountCall(barCalls, "CreateCastBar")
    return NewBar("CastBar")
end

function BETTERUI.ResourceOrbFrames.Bars.CreateMountStaminaBar()
    CountCall(barCalls, "CreateMountStaminaBar")
    return NewBar("MountBar")
end

function BETTERUI.ResourceOrbFrames.Events.SetupVisibilityFragments()
    CountCall(eventCalls, "SetupVisibilityFragments")
    return function()
        CountCall(eventCalls, "UpdateDeathFragment")
    end
end

function BETTERUI.ResourceOrbFrames.Events.SetupLoopEvents()
    CountCall(eventCalls, "SetupLoopEvents")
end

function BETTERUI.ResourceOrbFrames.Events.SetupSceneHandlers()
    CountCall(eventCalls, "SetupSceneHandlers")
end

function BETTERUI.ResourceOrbFrames.Events.SetupCombatIndicators()
    CountCall(eventCalls, "SetupCombatIndicators")
end

function BETTERUI.ResourceOrbFrames.Events.RefreshCombatIndicators()
    CountCall(eventCalls, "RefreshCombatIndicators")
end

local function RecordSkillCall(name)
    CountCall(skillCalls, name)
end

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
function SkillBar.ApplyActionBarSkin()
    RecordSkillCall("ApplyActionBarSkin")
end
function SkillBar.UpdateFrontBar()
    RecordSkillCall("UpdateFrontBar")
end
function SkillBar.UpdateFrontBarQuickslot()
    RecordSkillCall("UpdateFrontBarQuickslot")
end
function SkillBar.UpdateFrontBarCompanion()
    RecordSkillCall("UpdateFrontBarCompanion")
end
function SkillBar.UpdateFrontBarUltimateMeter()
    RecordSkillCall("UpdateFrontBarUltimateMeter")
end
function SkillBar.SetupFrontBarKeybinds()
    RecordSkillCall("SetupFrontBarKeybinds")
end
function SkillBar.SetupFrontBarPressFeedbackHooks()
    RecordSkillCall("SetupFrontBarPressFeedbackHooks")
end
function SkillBar.SetupFrontBarTooltips()
    RecordSkillCall("SetupFrontBarTooltips")
end
function SkillBar.HideNativeActionBar()
    RecordSkillCall("HideNativeActionBar")
end
function SkillBar.UpdateBackBar()
    RecordSkillCall("UpdateBackBar")
end
function SkillBar.UpdateBackBarLayout()
    RecordSkillCall("UpdateBackBarLayout")
end
function SkillBar.UpdateMainBarLayout()
    RecordSkillCall("UpdateMainBarLayout")
end
function SkillBar.UpdateBarPositions()
    RecordSkillCall("UpdateBarPositions")
end
function SkillBar.UpdateFrontBarLayout()
    RecordSkillCall("UpdateFrontBarLayout")
end
function SkillBar.IsWeaponSwapAnimating()
    return false
end
function SkillBar.SetupCombatIndicators()
    RecordSkillCall("SetupCombatIndicators")
end

local rootFrame = NewControl("Root")
local bgMiddle = NewControl("BgMiddle")
local frontBarContainer = NewControl("FrontBarContainer")
local backBarContainer = NewControl("BackBarContainer")
local leftOrnament = NewControl("OrnamentLeft")
local rightOrnament = NewControl("OrnamentRight")
local foodBar = NewControl("FoodBar")
local quickslotButton = NewControl("QuickslotButton")
local companionButton = NewControl("CompanionButton")

frontBarContainer.children.QuickslotButton = quickslotButton
frontBarContainer.children.CompanionButton = companionButton
rootFrame.children.BgMiddle = bgMiddle
rootFrame.children.FrontBarContainer = frontBarContainer
rootFrame.children.BackBarContainer = backBarContainer
rootFrame.children.OrnamentLeft = leftOrnament
rootFrame.children.OrnamentRight = rightOrnament
rootFrame.children.FoodBar = foodBar

dofile("Modules/ResourceOrbFrames/ResourceOrbFrames.lua")

local ResourceOrbFrames = BETTERUI.ResourceOrbFrames
local internals = ResourceOrbFrames._Internals

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

print("[ResourceOrbFrames]")

assert_true(type(internals) == "table", "resource orb frames exports test internals")

internals.SetupFrontBarHandlers(rootFrame)
assert_eq(skillCalls.SetupFrontBarKeybinds, 1, "front bar handler setup replays front bar keybind wiring")
assert_eq(skillCalls.SetupFrontBarPressFeedbackHooks, 1, "front bar handler setup replays press-feedback hooks")
assert_eq(skillCalls.SetupFrontBarTooltips, 1, "front bar handler setup replays front bar tooltips")

internals.SuppressNativeBars()
assert_eq(skillCalls.HideNativeActionBar, 1, "native bar suppression hides the default action bar")
assert_eq(fragmentCalls[#fragmentCalls].reason, "ResourceOrbFrames", "native bar suppression hides the attribute fragment for the module reason")

ResourceOrbFrames.Initialize(rootFrame)
assert_true(registeredEvents["ResourceOrbFrames_InitSetup"] ~= nil, "initialize registers a deferred setup callback for player activation")
registeredEvents["ResourceOrbFrames_InitSetup"].callback()

assert_eq(eventUnregisters[1].name, "ResourceOrbFrames_InitSetup", "deferred initialization unregisters the one-shot player activated callback")
assert_eq(skillCalls.ApplyActionBarSkin, 1, "deferred initialization reapplies the action bar skin")
assert_true((skillCalls.UpdateFrontBar or 0) >= 1, "deferred initialization refreshes the front bar")
assert_true((skillCalls.UpdateFrontBarQuickslot or 0) >= 1, "deferred initialization refreshes the quickslot button")
assert_true((skillCalls.UpdateFrontBarCompanion or 0) >= 1, "deferred initialization refreshes the companion button")
assert_eq(quickslotButton.parent, rootFrame, "deferred initialization hoists the quickslot button out of the front bar container")
assert_eq(companionButton.parent, rootFrame, "deferred initialization hoists the companion button out of the front bar container")
assert_eq(tryCalls["ControlUtils.InvalidateControlCache"], 1, "deferred initialization invalidates cached control references after reparenting")
assert_true((eventCalls.RefreshCombatIndicators or 0) >= 1, "deferred initialization refreshes combat indicators after setup")

settings.m_enabled = false
ResourceOrbFrames.ApplySettings()
assert_true(rootFrame.hidden, "apply settings hides the root frame when the module is disabled")

settings.m_enabled = true
ResourceOrbFrames.ApplySettings()
assert_true(not rootFrame.hidden, "apply settings shows the root frame when the module is enabled")
assert_true((barCalls.CastBarUpdate or 0) >= 1, "apply settings refreshes bar visuals after enabling the module")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
