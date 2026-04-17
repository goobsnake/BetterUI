--[[
File: tools/tests/test_scroll_indicator_controls.lua
Purpose: Regression tests for ScrollIndicator control internals.

Usage:
  lua tools/tests/test_scroll_indicator_controls.lua
]]

local passed = 0
local failed = 0

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

local function zo_clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

_G.zo_clamp = zo_clamp

TOPRIGHT = "TOPRIGHT"
BOTTOMRIGHT = "BOTTOMRIGHT"
TOPLEFT = "TOPLEFT"
TOP = "TOP"
BOTTOM = "BOTTOM"
CT_CONTROL = 1
CT_TEXTURE = 2
DT_HIGH = 3
DL_OVERLAY = 4

local function newManagedControl(name, top, height)
    return {
        name = name,
        handlers = {},
        top = top or 0,
        height = height or 100,
        width = 0,
        hidden = false,
        mouseEnabled = false,
        anchors = {},
        SetMouseEnabled = function(self, value)
            self.mouseEnabled = value
        end,
        SetHandler = function(self, eventName, handler)
            self.handlers[eventName] = handler
        end,
        GetTop = function(self)
            return self.top
        end,
        GetHeight = function(self)
            return self.height
        end,
        GetName = function(self)
            return self.name
        end,
        SetHeight = function(self, newHeight)
            self.height = newHeight
        end,
        SetTexture = function(self, value)
            self.texture = value
        end,
        SetTextureCoords = function(self, ...)
            self.textureCoords = { ... }
        end,
        SetDimensions = function(self, width, height)
            self.width = width
            self.height = height
        end,
        SetWidth = function(self, width)
            self.width = width
        end,
        ClearAnchors = function(self)
            self.anchor = nil
            self.anchors = {}
            self.anchorFillTarget = nil
        end,
        SetAnchor = function(self, ...)
            self.anchor = { ... }
            table.insert(self.anchors, self.anchor)
        end,
        SetAnchorFill = function(self, target)
            self.anchorFillTarget = target
        end,
        SetColor = function(self, ...)
            self.color = { ... }
        end,
        SetHidden = function(self, value)
            self.hidden = value
        end,
        SetDrawTier = function(self, value)
            self.drawTier = value
        end,
        SetDrawLayer = function(self, value)
            self.drawLayer = value
        end,
        SetDrawLevel = function(self, value)
            self.drawLevel = value
        end,
    }
end

WINDOW_MANAGER = {
    CreateControl = function(_, name)
        return newManagedControl(name)
    end,
}

local registeredUpdates = {}
local unregisteredUpdates = {}
local registeredEvents = {}
EVENT_MANAGER = {
    RegisterForUpdate = function(_, name, _, callback)
        registeredUpdates[name] = callback
    end,
    UnregisterForUpdate = function(_, name)
        unregisteredUpdates[name] = true
        registeredUpdates[name] = nil
    end,
    RegisterForEvent = function(_, name, _, callback)
        registeredEvents[name] = callback
    end,
}

local queuedCallbacks = {}
function zo_callLater(callback, delay)
    table.insert(queuedCallbacks, { callback = callback, delay = delay })
    callback()
end

local soundCalls = 0
function PlaySound()
    soundCalls = soundCalls + 1
end

MOUSE_BUTTON_INDEX_LEFT = 1
SOUNDS = { HOR_LIST_ITEM_SELECTED = "selected" }
EVENT_GLOBAL_MOUSE_UP = 2

local mouseY = 0
function GetUIMousePosition()
    return 0, mouseY
end

BETTERUI = { CIM = {} }

dofile("Modules/CIM/UI/ScrollIndicatorControls.lua")

local internals = BETTERUI.CIM.ScrollIndicator._Internals

print("[ScrollIndicator controls]")

local first, last = internals.GetSelectableBounds({
    listObject = {
        CalculateFirstSelectableIndex = function()
            return -2
        end,
        CalculateLastSelectableIndex = function()
            return 99
        end,
    },
}, 5)
assert_eq(first, 1, "selectable bounds clamp first index to minimum")
assert_eq(last, 5, "selectable bounds clamp last index to total items")

local function newControl(top, height)
    return {
        handlers = {},
        top = top or 0,
        height = height or 100,
        mouseEnabled = false,
        SetMouseEnabled = function(self, value)
            self.mouseEnabled = value
        end,
        SetHandler = function(self, eventName, handler)
            self.handlers[eventName] = handler
        end,
        GetTop = function(self)
            return self.top
        end,
        GetHeight = function(self)
            return self.height
        end,
        SetHeight = function(self, newHeight)
            self.height = newHeight
        end,
    }
end

local selectedIndices = {}
local instance = {
    listControl = {
        GetName = function()
            return "TestList"
        end,
    },
    listObject = {
        MovePrevious = function() end,
        MoveNext = function() end,
        CalculateFirstSelectableIndex = function()
            return 2
        end,
        CalculateLastSelectableIndex = function()
            return 5
        end,
        CanSelect = function(_, index)
            return index ~= 3
        end,
        GetNextSelectableIndex = function(_, index)
            return index + 2
        end,
        SetSelectedIndexWithoutAnimation = function(_, index)
            table.insert(selectedIndices, index)
        end,
    },
    controls = {
        upArrow = newControl(),
        downArrow = newControl(),
        thumb = newControl(0, 20),
        track = newControl(0, 100),
        container = newControl(),
    },
    totalItems = 5,
    currentIndex = 2,
}

internals.SetupArrowMouseHandlers(instance)
assert_true(instance.controls.upArrow.mouseEnabled, "arrow handlers enable up-arrow mouse interaction")
assert_true(instance.controls.downArrow.mouseEnabled, "arrow handlers enable down-arrow mouse interaction")

instance.controls.upArrow.handlers.OnMouseDown(nil, MOUSE_BUTTON_INDEX_LEFT)
assert_eq(soundCalls, 1, "up-arrow mouse down plays movement sound")
assert_true(registeredUpdates["BetterUI_ScrollIndicatorArrowRepeat_TestList"] ~= nil, "up-arrow mouse down starts repeat timer")

instance.controls.upArrow.handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_LEFT)
assert_true(unregisteredUpdates["BetterUI_ScrollIndicatorArrowRepeat_TestList"], "up-arrow mouse up stops repeat timer")

instance.controls.downArrow.handlers.OnMouseDown(nil, MOUSE_BUTTON_INDEX_LEFT)
assert_eq(soundCalls, 2, "down-arrow mouse down also plays movement sound")
assert_true(registeredUpdates["BetterUI_ScrollIndicatorArrowRepeat_TestList"] ~= nil, "down-arrow mouse down restarts the repeat timer")
instance.controls.downArrow.handlers.OnMouseExit()
assert_true(unregisteredUpdates["BetterUI_ScrollIndicatorArrowRepeat_TestList"], "down-arrow mouse exit stops the repeat timer")

internals.SetupThumbDragHandlers(instance)
assert_true(instance.controls.thumb.mouseEnabled, "thumb drag handlers enable thumb mouse interaction")
assert_true(type(registeredEvents["BetterUI_ScrollIndicatorThumbDrag_TestList"]) == "function", "thumb drag registers global mouse-up cleanup")

mouseY = 30
instance.controls.thumb.handlers.OnMouseDown(nil, MOUSE_BUTTON_INDEX_LEFT)
instance.controls.container.handlers.OnUpdate()
assert_eq(selectedIndices[#selectedIndices], 4, "thumb drag snaps to next selectable index when target row is blocked")

instance.controls.thumb.handlers.OnMouseUp(nil, MOUSE_BUTTON_INDEX_LEFT)
assert_true(instance.isDragging == false, "thumb mouse up exits dragging mode")

registeredEvents["BetterUI_ScrollIndicatorThumbDrag_TestList"](nil, MOUSE_BUTTON_INDEX_LEFT)
assert_true(instance.isDragging == false, "global mouse-up keeps dragging state cleared")

local indicatorControls = internals.CreateIndicatorControls({
    GetName = function()
        return "IndicatorList"
    end,
}, 7, 8, 9)
assert_eq(indicatorControls.container.anchors[1][1], TOPRIGHT, "indicator container anchors from the list top-right edge")
assert_eq(indicatorControls.container.anchors[1][4], 7, "indicator container respects the horizontal offset override")
assert_eq(indicatorControls.track.width, internals.SCROLL_INDICATOR.TRACK.WIDTH, "indicator track uses the configured track width")
assert_eq(indicatorControls.thumb.texture, internals.SCROLL_INDICATOR.THUMB.TEXTURE, "indicator thumb applies the configured texture")
assert_eq(indicatorControls.thumb.textureCoords[3], internals.SCROLL_INDICATOR.THUMB.TEXTURE_COORDS.top, "indicator thumb applies the configured texture coordinates")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
