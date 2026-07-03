--[[
File: tools/tests/test_orb_combat_indicators.lua
Purpose: Regression coverage for ResourceOrbFrames/Core/OrbCombatIndicators.lua
         using a stubbed ESO control environment.

Usage:
  lua tools/tests/test_orb_combat_indicators.lua
]]

local traceEvents = {}
local unpack = unpack or table.unpack
local settings = {
    m_enabled = true,
    showCombatGlow = false,
    showCombatIcon = true,
    elementPositions = {},
}

BETTERUI = {
    ResourceOrbFrames = {
        Animations = {},
        Utils = {
            Settings = {
                GetLive = function()
                    return settings
                end,
            },
        },
    },
    ControlUtils = {},
    Log = {
        CATEGORY = {
            STATE = "STATE",
        },
        TraceEvent = function(category, event, phase, data)
            traceEvents[#traceEvents + 1] = {
                category = category,
                event = event,
                phase = phase,
                data = data,
            }
        end,
        SetLastAction = function() end,
    },
    ClampNumber = function(value, minValue, maxValue, defaultValue)
        value = tonumber(value)
        if value == nil then return defaultValue end
        if value < minValue then return minValue end
        if value > maxValue then return maxValue end
        return value
    end,
}

function BETTERUI.ControlUtils.FindControl(parent, name)
    if not parent then return nil end
    if parent.GetNamedChild then
        local child = parent:GetNamedChild(name)
        if child then return child end
    end
    return parent.children and parent.children[name] or nil
end

BETTERUI_ORB_FRAMES = {
    slots = {
        gamepad = { width = 64 },
        keyboard = { width = 64 },
    },
    bars = {
        shiftY = 70,
        customFrontBar = {
            m_enabled = true,
            offsetX = 17,
            offsetY = 72,
            quickslotButton = { offsetX = 0, offsetY = 0 },
            gamepad = {},
            keyboard = {},
        },
        customBackBar = {
            offsetY = -5,
        },
        quickslot = { x = 276, y = -35 },
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

BETTERUI_COMBAT_ICON_TEXTURE = "EsoUI/Art/Options/Gamepad/gp_options_combat.dds"
BETTERUI_COMBAT_ICON_SIZE = 46
BETTERUI_COMBAT_ICON_OFFSET_X = 0
BETTERUI_COMBAT_ICON_OFFSET_Y = -8
BETTERUI_COMBAT_ICON_TINT_R = 1
BETTERUI_COMBAT_ICON_TINT_G = 0.2
BETTERUI_COMBAT_ICON_TINT_B = 0.2
BETTERUI_COMBAT_ICON_PULSE_DURATION_MS = 700
BETTERUI_COMBAT_ICON_PULSE_MIN_ALPHA = 0.45
BETTERUI_COMBAT_ICON_PULSE_MAX_ALPHA = 1

CT_TEXTURE = "CT_TEXTURE"
BOTTOM = "BOTTOM"
TOP = "TOP"
BOTTOMLEFT = "BOTTOMLEFT"
TOPLEFT = "TOPLEFT"
CENTER = "CENTER"
DL_CONTROLS = "DL_CONTROLS"
DT_MEDIUM = "DT_MEDIUM"
DL_OVERLAY = "DL_OVERLAY"
DT_HIGH = "DT_HIGH"
ANIMATION_ALPHA = "ANIMATION_ALPHA"
ANIMATION_PLAYBACK_PING_PONG = "ANIMATION_PLAYBACK_PING_PONG"
LOOP_INDEFINITELY = "LOOP_INDEFINITELY"
ZO_EaseInOutQuadratic = function() end

function IsInGamepadPreferredMode() return true end
function IsUnitDead() return false end
function ZO_ClearNumericallyIndexedTable(tbl)
    for i = #tbl, 1, -1 do
        tbl[i] = nil
    end
end

ANIMATION_MANAGER = {
    CreateTimeline = function()
        return {
            playing = false,
            InsertAnimation = function()
                return {
                    SetDuration = function() end,
                    SetAlphaValues = function() end,
                    SetEasingFunction = function() end,
                }
            end,
            SetPlaybackType = function() end,
            IsPlaying = function(self) return self.playing end,
            PlayFromStart = function(self) self.playing = true end,
            Stop = function(self) self.playing = false end,
        }
    end,
}

WINDOW_MANAGER = {
    CreateControl = function(name, parent)
        local control = NewControl(name, parent)
        control:SetHidden(true)
        return control
    end,
}

function NewControl(name, parent)
    local control = {
        name = name,
        parent = parent,
        children = {},
        hidden = false,
        alpha = 1,
        color = nil,
        dimensions = nil,
        anchor = nil,
        texture = nil,
    }

    function control:GetName() return self.name end
    function control:GetNamedChild(childName) return self.children[childName] end
    function control:GetParent() return self.parent end
    function control:SetParent(newParent) self.parent = newParent end
    function control:SetHidden(value) self.hidden = value end
    function control:IsHidden() return self.hidden end
    function control:SetAlpha(value) self.alpha = value end
    function control:SetColor(...) self.color = { ... } end
    function control:SetDimensions(width, height) self.dimensions = { width, height } end
    function control:ClearAnchors() self.anchor = nil end
    function control:SetAnchor(...) self.anchor = { ... } end
    function control:GetAnchor() return unpack(self.anchor or {}) end
    function control:GetWidth() return self.dimensions and self.dimensions[1] or nil end
    function control:GetHeight() return self.dimensions and self.dimensions[2] or nil end
    function control:SetTexture(texture) self.texture = texture end

    if parent then
        parent.children[name] = control
    end
    return control
end

local rootFrame = NewControl("BetterUI_ResourceOrbFrames")
local frontBarContainer = NewControl("FrontBarContainer", rootFrame)
local quickslotButton = NewControl("QuickslotButton", frontBarContainer)
local icon = NewControl("CombatIcon", frontBarContainer)

quickslotButton:SetDimensions(64, 64)
quickslotButton:SetAnchor(CENTER, rootFrame, CENTER, 0, 0)
icon:SetHidden(true)

dofile("Modules/ResourceOrbFrames/Core/OrbCombatIndicators.lua")

BETTERUI.ResourceOrbFrames.CombatIndicators.ApplyCombatIndicators(rootFrame, true, false)

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    if not value then
        error(label)
    end
end

assert_eq(icon.hidden, false, "combat icon is shown when combat icon setting is enabled")
assert_eq(icon.texture, BETTERUI_COMBAT_ICON_TEXTURE, "combat icon texture is applied")
assert_true(icon.anchor ~= nil and icon.anchor[2] == quickslotButton, "combat icon anchors to quickslot button")

local anchorTrace
for _, event in ipairs(traceEvents) do
    if event.event == "resource_orbs.combat_icon_anchor" and event.phase == "anchored" then
        anchorTrace = event
    end
end

assert_true(anchorTrace ~= nil, "combat icon anchor trace is emitted")
assert_eq(anchorTrace.data.didSetTexture, true, "combat icon trace records texture support")
assert_eq(anchorTrace.data.didSetTextureCoords, false, "combat icon trace records missing optional texture coords support")
assert_eq(anchorTrace.data.didSetDrawLayer, false, "combat icon trace records missing optional draw-layer support")

local fallbackRoot = NewControl("FallbackRoot")
local fallbackFrontBar = NewControl("FrontBarContainer", fallbackRoot)
local fallbackBg = NewControl("BgMiddle", fallbackRoot)
icon:SetHidden(true)

BETTERUI.ResourceOrbFrames.CombatIndicators.ApplyCombatIndicators(fallbackRoot, true, false)

local expectedFrontBarY = BETTERUI_ORB_FRAMES.bars.bottom.gamepadY + BETTERUI_ORB_FRAMES.bars.customFrontBar.offsetY
local expectedBackBarY = BETTERUI_ORB_FRAMES.bars.top.gamepadY + BETTERUI_ORB_FRAMES.bars.shiftY + BETTERUI_ORB_FRAMES.bars.customBackBar.offsetY
local expectedQuickslotY = ((expectedFrontBarY + expectedBackBarY) / 2) + BETTERUI_ORB_FRAMES.bars.quickslot.y
local expectedQuickslotX = BETTERUI_ORB_FRAMES.bars.quickslot.x + BETTERUI_ORB_FRAMES.bars.customFrontBar.offsetX
local expectedQuickslotButtonSize = BETTERUI_ORB_FRAMES.slots.gamepad.width
assert_eq(icon.anchor[2], fallbackBg, "combat icon fallback anchors to BgMiddle")
assert_eq(icon.anchor[4], expectedQuickslotX, "combat icon fallback uses the quickslot X anchor")
assert_eq(icon.anchor[5], expectedQuickslotY - (expectedQuickslotButtonSize * 0.5) + BETTERUI_COMBAT_ICON_OFFSET_Y,
    "combat icon fallback uses midpoint quickslot Y anchor")
assert_eq(fallbackFrontBar.name, "FrontBarContainer", "fallback front bar fixture is present")

print("test_orb_combat_indicators.lua: passed")
