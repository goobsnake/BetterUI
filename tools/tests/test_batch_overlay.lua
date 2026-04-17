--[[
File: tools/tests/test_batch_overlay.lua
Purpose: Regression coverage for the CIM batch status overlay module.

Usage:
  lua tools/tests/test_batch_overlay.lua
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

local function assert_match(text, expected, label)
    if tostring(text):find(expected, 1, true) then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected '%s' in '%s'", label, tostring(expected), tostring(text)))
    end
end

function zo_max(a, b)
    return math.max(a, b)
end

function zo_clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function zo_strlen(value)
    return #(tostring(value or ""))
end

function zo_strformat(_, a, b)
    return string.format("%s: %s", tostring(a or ""), tostring(b or ""))
end

CENTER = "CENTER"
TOP = "TOP"
BOTTOM = "BOTTOM"
TOPLEFT = "TOPLEFT"
BOTTOMRIGHT = "BOTTOMRIGHT"
TEXT_ALIGN_CENTER = "CENTER"
TEXT_ALIGN_TOP = "TOP"
CT_CONTROL = 1
CT_TEXTURE = 2
CT_LABEL = 3
CT_BACKDROP = 4
DL_OVERLAY = 5
DT_HIGH = 6

local function NewControl(name)
    local control = {
        name = name,
        hidden = false,
        text = "",
        width = 0,
        height = 0,
        alpha = nil,
        color = nil,
        children = {},
        anchors = {},
    }

    function control:GetName()
        return self.name or "Anonymous"
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

    function control:SetMouseEnabled(value)
        self.mouseEnabled = value
    end

    function control:SetMovable(value)
        self.movable = value
    end

    function control:SetClampedToScreen(value)
        self.clampedToScreen = value
    end

    function control:SetClipsChildren(value)
        self.clipsChildren = value
    end

    function control:SetHidden(value)
        self.hidden = value
    end

    function control:IsHidden()
        return self.hidden
    end

    function control:ClearAnchors()
        self.anchors = {}
    end

    function control:SetAnchor(...)
        table.insert(self.anchors, { ... })
    end

    function control:SetAnchorFill(target)
        self.anchorFillTarget = target
    end

    function control:SetTexture(value)
        self.texture = value
    end

    function control:SetTextureCoords(...)
        self.textureCoords = { ... }
    end

    function control:SetColor(...)
        self.color = { ... }
    end

    function control:SetCenterTexture(value)
        self.centerTexture = value
    end

    function control:SetEdgeTexture(...)
        self.edgeTexture = { ... }
    end

    function control:SetInsets(...)
        self.insets = { ... }
    end

    function control:SetCenterColor(...)
        self.centerColor = { ... }
    end

    function control:SetEdgeColor(...)
        self.edgeColor = { ... }
    end

    function control:SetFont(value)
        self.font = value
    end

    function control:SetHorizontalAlignment(value)
        self.horizontalAlignment = value
    end

    function control:SetVerticalAlignment(value)
        self.verticalAlignment = value
    end

    function control:SetText(value)
        self.text = value
    end

    function control:GetText()
        return self.text
    end

    function control:GetTextWidth()
        return (self.textWidth ~= nil) and self.textWidth or (#tostring(self.text or "") * 8)
    end

    function control:GetTextHeight()
        return (self.textHeight ~= nil) and self.textHeight or ((self.text and self.text ~= "") and 24 or 0)
    end

    function control:SetWidth(value)
        self.width = value
    end

    function control:SetHeight(value)
        self.height = value
    end

    function control:GetHeight()
        return self.height
    end

    function control:GetWidth()
        return self.width
    end

    function control:SetDimensions(width, height)
        self.width = width
        self.height = height
    end

    return control
end

local controlsByName = {}
local anonymousControlIndex = 0

WINDOW_MANAGER = {
    CreateTopLevelWindow = function(_, name)
        local control = NewControl(name)
        controlsByName[name] = control
        return control
    end,
    CreateControl = function(_, name, parent)
        anonymousControlIndex = anonymousControlIndex + 1
        local resolvedName = name or ("AnonymousControl" .. tostring(anonymousControlIndex))
        local control = NewControl(resolvedName)
        control.parent = parent
        controlsByName[resolvedName] = control
        if parent and parent.children then
            parent.children[resolvedName] = control
        end
        return control
    end,
}

GuiRoot = {
    GetWidth = function()
        return 1920
    end,
}

local activeDialogs = {}
local gamepadDialog = {
    hidden = true,
    IsHidden = function(self)
        return self.hidden
    end,
}

function ZO_Dialogs_IsShowing(name)
    return activeDialogs[name] == true
end

function GetControl(name)
    if name == "ZO_DialogGamepad1" then
        return gamepadDialog
    end
    return controlsByName[name]
end

local queuedCallbacks = {}

function zo_callLater(callback, delay)
    table.insert(queuedCallbacks, { callback = callback, delay = delay })
end

local function RunNextCallback()
    local nextCallback = table.remove(queuedCallbacks, 1)
    if nextCallback then
        nextCallback.callback()
    end
end

BETTERUI = {
    CIM = {
        SafeExecute = function(_, callback)
            return pcall(callback)
        end,
    },
}

dofile("Modules/CIM/UI/BatchOverlay.lua")

local BatchOverlay = BETTERUI.CIM.BatchOverlay
local internals = BatchOverlay._Internals

print("[BatchOverlay]")

assert_true(type(internals) == "table", "batch overlay exports test internals")

local requestFromTable = BatchOverlay.CreateDisplayRequest({
    displayName = "Batch",
    bodyText = "Queued",
    secondaryText = "Hold tight",
})
assert_eq(requestFromTable.displayName, "Batch", "display request preserves table display name")
assert_eq(requestFromTable.secondaryText, "Hold tight", "display request preserves table secondary text")

local requestFromArgs = BatchOverlay.CreateDisplayRequest("Batch", "Queued", "Ready")
assert_eq(requestFromArgs.bodyText, "Queued", "display request stores positional body text")
assert_eq(requestFromArgs.secondaryText, "Ready", "display request stores positional secondary text")

assert_eq(internals.ResolveBatchStatusTextValue(function()
    return 42
end), "42", "status text resolver stringifies callback results")

BETTERUI.CIM.SafeExecute = function()
    return false
end
assert_eq(internals.ResolveBatchStatusTextValue(function()
    return "ignored"
end), "", "status text resolver falls back to empty text on safe-execute failure")
BETTERUI.CIM.SafeExecute = function(_, callback)
    return pcall(callback)
end

activeDialogs["BETTERUI_VENDOR_BATCH_DIALOG"] = true
assert_true(BatchOverlay.IsAnyBatchActionDialogShowing(), "named batch action dialogs block overlay startup")
activeDialogs["BETTERUI_VENDOR_BATCH_DIALOG"] = nil
gamepadDialog.hidden = false
assert_true(BatchOverlay.IsAnyBatchActionDialogShowing(), "visible gamepad dialog blocks overlay startup")
gamepadDialog.hidden = true
assert_true(not BatchOverlay.IsAnyBatchActionDialogShowing(), "dialog check returns false when all dialogs are hidden")

internals.ResetOverlayState()
queuedCallbacks = {}
activeDialogs["BETTERUI_VENDOR_BATCH_DIALOG"] = true

local bodyCalls = 0
BatchOverlay.ShowStatus({
    displayName = "Batch",
    bodyText = function()
        bodyCalls = bodyCalls + 1
        return "Processing"
    end,
    secondaryText = "Keep going",
})

local overlayState = internals.GetOverlayState()
assert_true(overlayState.control:IsHidden(), "overlay stays hidden while a blocking dialog is showing")
assert_eq(bodyCalls, 0, "suppressed overlay does not resolve body text until retry")
assert_eq(#queuedCallbacks, 1, "suppressed overlay schedules a retry")

activeDialogs["BETTERUI_VENDOR_BATCH_DIALOG"] = nil
RunNextCallback()

assert_eq(bodyCalls, 1, "overlay resolves dynamic body text once the dialog clears")
assert_true(not overlayState.control:IsHidden(), "overlay shows after retrying without a blocking dialog")
assert_match(overlayState.mainLabel:GetText(), "Batch: Processing", "main label renders the formatted batch text")
assert_eq(overlayState.secondaryLabel.hidden, false, "secondary label becomes visible for secondary text")
assert_eq(#queuedCallbacks, 1, "dynamic text schedules a follow-up refresh")

BatchOverlay.StopLayoutPulse()
RunNextCallback()
assert_eq(bodyCalls, 1, "layout pulse cancellation prevents stale dynamic refresh callbacks")

BatchOverlay.Hide(50)
assert_true(not overlayState.control:IsHidden(), "delayed hide leaves overlay visible until callback runs")
assert_eq(#queuedCallbacks, 1, "delayed hide schedules a hide callback")
RunNextCallback()
assert_true(overlayState.control:IsHidden(), "delayed hide callback hides the overlay")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
