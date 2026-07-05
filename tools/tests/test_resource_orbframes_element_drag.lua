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
CT_CONTROL = "CT_CONTROL"
CT_LABEL = "CT_LABEL"
CT_TEXTURE = "CT_TEXTURE"
CENTER = "CENTER"
TOPLEFT = "TOPLEFT"
BOTTOMRIGHT = "BOTTOMRIGHT"
LEFT = "LEFT"
RIGHT = "RIGHT"
TOP = "TOP"
BOTTOM = "BOTTOM"
DL_OVERLAY = "DL_OVERLAY"
MOUSE_BUTTON_INDEX_LEFT = 1
TEXT_ALIGN_CENTER = "TEXT_ALIGN_CENTER"

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
        children = {},
        handlers = {},
        mouseEnabled = nil,
    }
    function control:GetName() return self.name end
    function control:SetDimensions(width, height) self.dimensions = { width, height } end
    function control:GetDimensions()
        return self.dimensions and self.dimensions[1], self.dimensions and self.dimensions[2]
    end
    function control:SetParent(parent) self.parent = parent end
    function control:ClearAnchors() self.anchor = nil end
    function control:SetAnchor(...) self.anchor = { ... } end
    function control:SetDrawLayer(value) self.drawLayer = value end
    function control:SetDrawLevel(value) self.drawLevel = value end
    function control:SetCenterTexture(value) self.centerTexture = value end
    function control:SetEdgeTexture(...) self.edgeTexture = { ... } end
    function control:SetInsets(...) self.insets = { ... } end
    function control:SetTexture(value) self.texture = value end
    function control:SetTextureRotation(value) self.textureRotation = value end
    function control:SetCenterColor(...) self.centerColor = { ... } end
    function control:SetEdgeColor(...) self.edgeColor = { ... } end
    function control:SetColor(...) self.color = { ... } end
    function control:SetAlpha(value) self.alpha = value end
    function control:SetFont(value) self.font = value end
    function control:SetHorizontalAlignment(value) self.horizontalAlignment = value end
    function control:SetVerticalAlignment(value) self.verticalAlignment = value end
    function control:SetMouseEnabled(value) self.mouseEnabled = value end
    function control:SetHidden(value) self.hidden = value end
    function control:IsHidden() return self.hidden == true end
    function control:SetHandler(name, fn) self.handlers[name] = fn end
    function control:SetText(value) self.text = value end
    return control
end

GuiRoot = NewControl("GuiRoot")

local createdControlNames = {}
WINDOW_MANAGER = {
    CreateTopLevelWindow = function(_, name)
        if name and createdControlNames[name] then
            return nil
        end
        if name then createdControlNames[name] = true end
        local control = NewControl(name)
        control.parent = GuiRoot
        control.isTopLevel = true
        if GuiRoot.children then GuiRoot.children[#GuiRoot.children + 1] = control end
        return control
    end,
    CreateControl = function(_, name, parent, controlType)
        -- Mirror ESO: creating a duplicate control name fails and returns nil.
        if name and createdControlNames[name] then
            return nil
        end
        if name then createdControlNames[name] = true end
        local control = NewControl(name)
        control.parent = parent
        control.controlType = controlType
        if parent and parent.children then
            parent.children[#parent.children + 1] = control
        end
        return control
    end,
}

local host = NewControl("LeftOrbHost")
function host:GetCenter() return 400, 300 end
host:SetHidden(true)

dofile("Modules/ResourceOrbFrames/Core/ElementDrag.lua")

local Drag = BETTERUI.ResourceOrbFrames.Drag
local handle = Drag.AttachDragHandle(host, "leftOrb", function() return settings end, function()
    applyCalls = applyCalls + 1
end, { label = "Left Orb" })

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

local function find_child(control, predicate)
    for _, child in ipairs(control.children or {}) do
        if predicate(child) then return child end
        local nested = find_child(child, predicate)
        if nested then return nested end
    end
    return nil
end

assert_eq(handle.mouseEnabled, false, "drag handle starts disabled while global lock is active")
assert_eq(handle.hidden, false, "drag handle root stays unhidden so unlock can revive it")
assert_eq(handle.alpha, 0, "drag handle is visually hidden while global lock is active")

mouseX, mouseY = 100, 100
handle.handlers.OnMouseDown(handle, MOUSE_BUTTON_INDEX_LEFT)
assert_eq(settings.elementPositions.leftOrb.offsetX, 0, "locked mouse-down does not mutate X offset")
assert_eq(handle.handlers.OnUpdate, nil, "locked mouse-down does not arm dragging")

Drag.SetAllElementsUnlocked(true, function() return settings end)
assert_eq(settings.elementPositionsUnlocked, true, "SetAllElementsUnlocked stores unlocked state")
assert_eq(handle.mouseEnabled, true, "global unlock enables the drag handle")
assert_eq(handle.hidden, false, "global unlock shows the drag handle even when the host element is hidden")
assert_eq(handle.alpha, 1, "global unlock restores drag handle opacity")
assert_true(handle.parent ~= nil and handle.parent.name == "BetterUI_OrbMoverLayer",
    "drag handle is parented to the dedicated mover layer so hidden hosts can still be moved")
assert_eq(handle.parent.isTopLevel, true,
    "the mover layer is a top-level window; GuiRoot children never enter ESO's render list")
assert_eq(handle.parent.parent, GuiRoot, "the mover layer hangs off GuiRoot")
assert_eq(handle.parent.hidden, false, "the mover layer is always shown")
assert_eq(handle.anchor[2], host, "hidden host drag handle stays anchored to the host's real position")
assert_eq(handle.centerTexture, nil,
    "drag handle keeps the engine-default color-fill backdrop (texture overrides regressed visibility)")
assert_eq(handle.edgeTexture, nil,
    "drag handle keeps the engine-default edge fill (texture overrides regressed visibility)")

local fillRect = find_child(handle, function(control)
    return control.controlType == CT_TEXTURE
        and control.name:find("Fill", 1, true) ~= nil
        and control.name:find("Border", 1, true) == nil
end)
assert_true(fillRect ~= nil, "unlocked drag handle creates a solid fill rect")
assert_eq(fillRect.texture, nil,
    "solid fill rect stays untextured so the engine renders it as a solid color")
assert_eq(fillRect.hidden, false, "solid fill rect is visible while unlocked")
local borderRect = find_child(handle, function(control)
    return control.controlType == CT_TEXTURE
        and control.name:find("BorderFill", 1, true) ~= nil
end)
assert_true(borderRect ~= nil, "unlocked drag handle creates a solid border rect")
assert_eq(borderRect.hidden, false, "solid border rect is visible while unlocked")

local label = find_child(handle, function(control) return control.controlType == CT_LABEL end)
assert_true(label ~= nil, "unlocked drag handle creates a readable label")
assert_eq(label.text, "Left Orb", "drag handle label uses the setting name")
assert_eq(label.hidden, false, "unlocked drag handle label is visible")

local arrow = find_child(handle, function(control)
    return control.controlType == CT_TEXTURE
        and control.name:find("MoveIconLeft", 1, true) ~= nil
        and control.name:find("Shadow", 1, true) == nil
end)
assert_true(arrow ~= nil, "unlocked drag handle creates an arrow face texture")
assert_eq(arrow.texture, "EsoUI/Art/Buttons/leftArrow_up.dds",
    "left arrow face uses native gold ESO arrow art")
assert_eq(arrow.textureRotation, nil,
    "arrow face does not rely on runtime texture rotation")
assert_true(arrow.color and arrow.color[1] >= 0.9 and arrow.color[2] >= 0.65 and arrow.color[3] <= 0.45,
    "arrow face uses a gold high-contrast tint instead of black")

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
assert_eq(handle.hidden, false, "global lock leaves the drag handle root available for the next unlock")
assert_eq(handle.alpha, 0, "global lock hides the drag handle visually")

-- A hidden host with no resolvable rect (never laid out) falls back to
-- GuiRoot center so the box stays grabbable.
local unplacedHost = NewControl("XpBarHost")
unplacedHost:SetHidden(true)
local fallbackHandle = Drag.AttachDragHandle(unplacedHost, "xpBar", function() return settings end, function() end)
assert_true(fallbackHandle ~= nil, "attach succeeds for a hidden host without position data")
assert_eq(fallbackHandle.anchor[2], GuiRoot,
    "hidden host without a resolvable rect falls back to GuiRoot center")

-- Host-change reattach must survive ESO's duplicate-name CreateControl
-- failure by reusing the pooled handle control and its cached children.
local rebuiltHost = NewControl("LeftOrbHostRebuilt")
function rebuiltHost:GetCenter() return 420, 360 end
rebuiltHost:SetHidden(true)
local reattached = Drag.AttachDragHandle(rebuiltHost, "leftOrb", function() return settings end, function() end)
assert_true(reattached ~= nil, "host change reattach survives duplicate control names")
assert_eq(reattached, handle, "host change reattach reuses the pooled handle control")
assert_eq(reattached.anchor[2], rebuiltHost, "reattached handle anchors to the new hidden host's position")
assert_eq(reattached.hidden, false, "reattached handle root is revived from the detached state")
local revivedLabel = find_child(reattached, function(control) return control.controlType == CT_LABEL end)
assert_true(revivedLabel ~= nil, "reattached handle revives its pooled label")

print("test_resource_orbframes_element_drag.lua: passed")
