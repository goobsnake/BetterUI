--[[
File: tools/tests/test_resource_orbframes_element_drag.lua
Purpose: Regression coverage for ResourceOrbFrames/Core/ElementDrag.lua global unlock behavior.

Usage:
  lua tools/tests/test_resource_orbframes_element_drag.lua
]]

local settings = {
    elementPositionsUnlocked = false,
    elementPositions = {
        leftOrb = { locked = true, offsetX = 0, offsetY = 0 },
    },
}
local applyCalls = 0
local mouseX, mouseY = 0, 0
local frameMs = 0
local traceEvents = {}

BETTERUI = {
    ResourceOrbFrames = {
        Utils = {
            Settings = {
                GetLive = function()
                    return settings
                end,
            },
        },
    },
    ClampInteger = function(value, minValue, maxValue, defaultValue)
        value = tonumber(value)
        if value == nil then return defaultValue end
        if value < minValue then return minValue end
        if value > maxValue then return maxValue end
        return math.floor(value + 0.5)
    end,
    Log = {
        CATEGORY = { STATE = "STATE" },
        TraceEvent = function(category, event, phase, data)
            traceEvents[#traceEvents + 1] = { category = category, event = event, phase = phase, data = data }
        end,
    },
}

CT_BACKDROP = "CT_BACKDROP"
CENTER = "CENTER"
DL_OVERLAY = "DL_OVERLAY"
MOUSE_BUTTON_INDEX_LEFT = 1

function GetFrameTimeMilliseconds()
    frameMs = frameMs + 100
    return frameMs
end

function GetUIMousePosition()
    return mouseX, mouseY
end

local function NewControl(name)
    local control = {
        name = name,
        handlers = {},
        mouseEnabled = nil,
    }
    function control:GetName() return self.name end
    function control:SetDimensions(width, height) self.dimensions = { width, height } end
    function control:SetAnchor(...) self.anchor = { ... } end
    function control:SetDrawLayer(value) self.drawLayer = value end
    function control:SetDrawLevel(value) self.drawLevel = value end
    function control:SetCenterColor(...) self.centerColor = { ... } end
    function control:SetEdgeColor(...) self.edgeColor = { ... } end
    function control:SetColor(...) self.color = { ... } end
    function control:SetAlpha(value) self.alpha = value end
    function control:SetMouseEnabled(value) self.mouseEnabled = value end
    function control:SetHidden(value) self.hidden = value end
    function control:SetHandler(name, fn) self.handlers[name] = fn end
    return control
end

WINDOW_MANAGER = {
    CreateControl = function(name)
        return NewControl(name)
    end,
}

local host = NewControl("LeftOrbHost")

dofile("Modules/ResourceOrbFrames/Core/ElementDrag.lua")

local Drag = BETTERUI.ResourceOrbFrames.Drag
local handle = Drag.AttachDragHandle(host, "leftOrb", function() return settings end, function()
    applyCalls = applyCalls + 1
end)

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

assert_eq(handle.mouseEnabled, false, "drag handle starts disabled while global lock is active")

mouseX, mouseY = 100, 100
handle.handlers.OnMouseDown(handle, MOUSE_BUTTON_INDEX_LEFT)
assert_eq(settings.elementPositions.leftOrb.offsetX, 0, "locked mouse-down does not mutate X offset")
assert_eq(handle.handlers.OnUpdate, nil, "locked mouse-down does not arm dragging")

Drag.SetAllElementsUnlocked(true, function() return settings end)
assert_eq(settings.elementPositionsUnlocked, true, "SetAllElementsUnlocked stores unlocked state")
assert_eq(handle.mouseEnabled, true, "global unlock enables the drag handle")

mouseX, mouseY = 100, 100
handle.handlers.OnMouseDown(handle, MOUSE_BUTTON_INDEX_LEFT)
mouseX, mouseY = 109, 111
assert_true(type(handle.handlers.OnUpdate) == "function", "unlocked mouse-down arms dragging")
handle.handlers.OnUpdate(handle)
handle.handlers.OnMouseUp(handle, MOUSE_BUTTON_INDEX_LEFT)

assert_eq(settings.elementPositions.leftOrb.offsetX, 9, "unlocked drag updates X offset")
assert_eq(settings.elementPositions.leftOrb.offsetY, 11, "unlocked drag updates Y offset")
assert_true(applyCalls >= 1, "unlocked drag invokes the apply callback")

Drag.SetAllElementsUnlocked(false, function() return settings end)
assert_eq(settings.elementPositionsUnlocked, false, "global lock stores locked state")
assert_eq(handle.mouseEnabled, false, "global lock disables the drag handle")

print("test_resource_orbframes_element_drag.lua: passed")
