--[[
File: tools/tests/test_banking_quantity_dialog.lua
Purpose: Regression coverage for the banking quantity dialog target snapshot.
]]

BAG_BANK = 2
BAG_BACKPACK = 1

SI_GAMEPAD_SELECT_OPTION = "Select"
SI_DIALOG_CANCEL = "Cancel"
SI_BETTERUI_BANK_SLIDER_MIN = "Min"
SI_BETTERUI_BANK_SLIDER_MAX = "Max"
SI_BETTERUI_SLIDER_KEEPS = "Keeps"
SI_BETTERUI_SLIDER_STAYS = "Stays"
SI_BETTERUI_SLIDER_DEPOSIT = "Deposit"
SI_BETTERUI_SLIDER_WITHDRAW = "Withdraw"
SI_GAMEPAD_INVENTORY_SPLIT_STACK_LEFT_NARRATION = "Left"
SI_GAMEPAD_INVENTORY_SPLIT_STACK_RIGHT_NARRATION = "Right"

GAMEPAD_DIALOGS = { ITEM_SLIDER = "ITEM_SLIDER" }
ESO_Dialogs = {}

local passed, failed = 0, 0
local registeredDialog = nil
local shownDialogData = nil
local releasedDialogs = {}
local moves = {}
local traceEvents = {}
local slotStacks = {}
local slotIdentityCurrent = true

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

local function last_trace(phase)
    for i = #traceEvents, 1, -1 do
        if traceEvents[i].phase == phase then
            return traceEvents[i]
        end
    end
    return nil
end

function GetString(id)
    return tostring(id or "")
end

function zo_clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function GetSlotStackSize(bagId, slotIndex)
    return slotStacks[tostring(bagId) .. ":" .. tostring(slotIndex)] or 0
end

function GetItemLink(bagId, slotIndex)
    return string.format("|Hitem:%s:%s|h", tostring(bagId), tostring(slotIndex))
end

function GetItemName(bagId, slotIndex)
    return string.format("Item %s:%s", tostring(bagId), tostring(slotIndex))
end

function ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)
    return dialog.sliderValue
end

function ZO_Dialogs_ReleaseDialogOnButtonPress(name)
    releasedDialogs[#releasedDialogs + 1] = name
end

function ZO_Dialogs_RegisterCustomDialog(name, descriptor)
    registeredDialog = descriptor
    registeredDialog.name = name
    ESO_Dialogs[name] = descriptor
end

function ZO_Dialogs_ShowGamepadDialog(name, data)
    shownDialogData = data
    shownDialogData.dialogName = name
end

function ZO_Keybindings_GetHighestPriorityBindingStringFromAction()
    return ""
end

function GetGameTimeMilliseconds()
    return 12345
end

BETTERUI = {
    Log = {
        CATEGORY = { ACTION = "action" },
        LEVEL = { INFO = "info" },
        TraceEvent = function(_, event, phase, data)
            traceEvents[#traceEvents + 1] = { event = event, phase = phase, data = data }
        end,
        Debug = function() end,
        Info = function() end,
        DescribeItem = function(data)
            return string.format("%s:%s", tostring(data and data.bagId), tostring(data and data.slotIndex))
        end,
    },
    CIM = {
        Utils = {
            CaptureSlotIdentity = function(bagId, slotIndex)
                return { bagId = bagId, slotIndex = slotIndex }
            end,
            IsSlotIdentityCurrent = function(identity, bagId, slotIndex)
                return slotIdentityCurrent and identity and identity.bagId == bagId and identity.slotIndex == slotIndex
            end,
        },
    },
    Banking = { Class = {}, GetWindow = function() return BETTERUI.Banking and BETTERUI.Banking.Window or nil end },
}

local list = {
    selectedData = nil,
    GetSelectedData = function(self)
        return self.selectedData
    end,
}

local window = {
    list = list,
    suppressWrites = {},
    GetList = function(self)
        return self.list
    end,
    SetListUpdatesSuppressed = function(self, value)
        self._suppressListUpdates = value == true
        self.suppressWrites[#self.suppressWrites + 1] = self._suppressListUpdates
    end,
    MoveItem = function(_, moveList, quantity)
        local selectedData = moveList:GetSelectedData()
        moves[#moves + 1] = {
            bagId = selectedData.bagId,
            slotIndex = selectedData.slotIndex,
            quantity = quantity,
        }
    end,
}

BETTERUI.Banking.Window = window

dofile("Modules/CIM/Dialogs/DialogRegistry.lua")
dofile("Modules/Banking/Dialogs/QuantityDialog.lua")
BETTERUI.Banking.InitializeQuantityDialog()

print("[Banking quantity dialog]")

list.selectedData = { bagId = BAG_BANK, slotIndex = 4, stackCount = 5 }
slotStacks["2:4"] = 3
BETTERUI.Banking.Class.ShowQuantityDialog(window, false)
assert_eq(shownDialogData.bagId, BAG_BANK, "dialog captures original bag")
assert_eq(shownDialogData.slotIndex, 4, "dialog captures original slot")
assert_true(shownDialogData.expectedSlotIdentity ~= nil, "dialog captures slot identity")
assert_eq(window._suppressListUpdates, true, "dialog suppresses list updates while open")

list.selectedData = { bagId = BAG_BACKPACK, slotIndex = 9, stackCount = 1 }
registeredDialog.buttons[1].callback({ data = shownDialogData, sliderValue = 5 })
assert_eq(moves[1].bagId, BAG_BANK, "confirm moves the captured bag, not current list selection")
assert_eq(moves[1].slotIndex, 4, "confirm moves the captured slot, not current list selection")
assert_eq(moves[1].quantity, 3, "confirm clamps quantity to the live stack")
assert_eq(window._suppressListUpdates, false, "confirm clears list-update suppression")
assert_eq(releasedDialogs[#releasedDialogs], BETTERUI_BANK_QUANTITY_DIALOG, "confirm releases the quantity dialog")

shownDialogData = nil
list.selectedData = { bagId = BAG_BANK, slotIndex = 5, stackCount = 4 }
slotStacks["2:5"] = 4
slotIdentityCurrent = false
BETTERUI.Banking.Class.ShowQuantityDialog(window, false)
registeredDialog.buttons[1].callback({ data = shownDialogData, sliderValue = 2 })
assert_eq(#moves, 1, "stale slot identity blocks the move")
assert_eq(last_trace("confirm_blocked").data.reason, "staleSlot", "stale slot records blocked reason")
assert_eq(traceEvents[#traceEvents].phase, "suppression_cleared", "stale slot still clears suppression")
assert_eq(traceEvents[#traceEvents].data.result, "confirm_blocked", "stale slot suppression records blocked result")
assert_eq(window._suppressListUpdates, false, "stale slot clears list-update suppression")

shownDialogData = nil
slotIdentityCurrent = true
list.selectedData = { bagId = BAG_BANK, slotIndex = 6, stackCount = 4 }
slotStacks["2:6"] = 4
BETTERUI.Banking.Class.ShowQuantityDialog(window, false)
registeredDialog.buttons[1].callback({ data = shownDialogData, sliderValue = 0 })
assert_eq(#moves, 1, "invalid quantity blocks the move")
assert_eq(last_trace("confirm_blocked").data.reason, "invalidQuantity", "invalid quantity records blocked reason")
assert_eq(traceEvents[#traceEvents].data.result, "confirm_blocked", "invalid quantity clears suppression as blocked")
assert_eq(window._suppressListUpdates, false, "invalid quantity clears list-update suppression")

shownDialogData = nil
list.selectedData = { bagId = BAG_BANK, slotIndex = 7, stackCount = 4 }
slotStacks["2:7"] = 0
BETTERUI.Banking.Class.ShowQuantityDialog(window, false)
registeredDialog.buttons[1].callback({ data = shownDialogData, sliderValue = 2 })
assert_eq(#moves, 1, "empty live stack blocks the move")
assert_eq(last_trace("confirm_blocked").data.reason, "emptyLiveStack", "empty live stack records blocked reason")
assert_eq(traceEvents[#traceEvents].data.result, "confirm_blocked", "empty live stack clears suppression as blocked")
assert_eq(window._suppressListUpdates, false, "empty live stack clears list-update suppression")

shownDialogData = nil
list.selectedData = { bagId = BAG_BANK, slotIndex = 8, stackCount = 4 }
slotStacks["2:8"] = 4
BETTERUI.Banking.Class.ShowQuantityDialog(window, false)
registeredDialog.buttons[1].callback({})
assert_eq(#moves, 1, "missing dialog data blocks the move")
assert_eq(last_trace("confirm_blocked").data.reason, "missingDialogData", "missing dialog data records blocked reason")
assert_eq(traceEvents[#traceEvents].data.result, "confirm_blocked", "missing dialog data clears suppression as blocked")
assert_eq(window._suppressListUpdates, false, "missing dialog data clears list-update suppression")

shownDialogData = nil
list.selectedData = { bagId = BAG_BANK, slotIndex = 9, stackCount = 4 }
slotStacks["2:9"] = 4
BETTERUI.Banking.Class.ShowQuantityDialog(window, false)
local originalMoveItem = window.MoveItem
window.MoveItem = nil
registeredDialog.buttons[1].callback({ data = shownDialogData, sliderValue = 2 })
window.MoveItem = originalMoveItem
assert_eq(#moves, 1, "missing MoveItem blocks the move")
assert_eq(last_trace("confirm_blocked").data.reason, "missingMoveItem", "missing MoveItem records blocked reason")
assert_eq(traceEvents[#traceEvents].data.result, "confirm_blocked", "missing MoveItem clears suppression as blocked")
assert_eq(window._suppressListUpdates, false, "missing MoveItem clears list-update suppression")

shownDialogData = nil
list.selectedData = { bagId = BAG_BANK, slotIndex = 10, stackCount = 4 }
slotStacks["2:10"] = 4
BETTERUI.Banking.Class.ShowQuantityDialog(window, false)
registeredDialog.buttons[2].callback({ data = shownDialogData })
assert_eq(#moves, 1, "cancel does not move an item")
assert_eq(last_trace("closed").data.result, "cancel", "cancel records closed result")
assert_eq(traceEvents[#traceEvents].data.result, "cancel", "cancel clears suppression as cancel")
assert_eq(window._suppressListUpdates, false, "cancel clears list-update suppression")

shownDialogData = nil
list.selectedData = { bagId = BAG_BANK, slotIndex = 11, stackCount = 4 }
slotStacks["2:11"] = 4
BETTERUI.Banking.Class.ShowQuantityDialog(window, false)
registeredDialog.noChoiceCallback({ data = shownDialogData })
assert_eq(#moves, 1, "no-choice close does not move an item")
assert_eq(last_trace("closed").data.result, "no_choice", "no-choice close records closed result")
assert_eq(traceEvents[#traceEvents].data.result, "no_choice", "no-choice close clears suppression")
assert_eq(window._suppressListUpdates, false, "no-choice close clears list-update suppression")

local setupDialog = {
    data = { isDeposit = false, sliderMin = 1, sliderMax = 4, sliderStartValue = 2 },
    _betteruiLastSliderTraceKey = "stale",
    _betteruiLastSliderTraceBucket = 5,
    GetNamedChild = function()
        return nil
    end,
}
registeredDialog.setup(setupDialog, setupDialog.data)
assert_eq(setupDialog._betteruiLastSliderTraceKey, nil, "setup resets slider trace key")
assert_eq(setupDialog._betteruiLastSliderTraceBucket, nil, "setup resets slider trace bucket")

local sliderPreviewDialog = {
    data = { bagId = BAG_BANK, slotIndex = 12, sliderMin = 1, sliderMax = 101, isDeposit = false },
    sliderValue1 = {
        text = nil,
        SetText = function(self, value) self.text = value end,
    },
    sliderValue2 = {
        text = nil,
        SetText = function(self, value) self.text = value end,
    },
}
local sliderTraceCountBefore = #traceEvents
registeredDialog.OnSliderValueChanged(sliderPreviewDialog, nil, 41)
registeredDialog.OnSliderValueChanged(sliderPreviewDialog, nil, 41)
registeredDialog.OnSliderValueChanged(sliderPreviewDialog, nil, 49)
local sliderTraceCountAfter = #traceEvents
assert_eq(sliderPreviewDialog.sliderValue1.text, "52", "slider preview updates the remaining count label")
assert_eq(sliderPreviewDialog.sliderValue2.text, "49", "slider preview updates the selected count label")
assert_eq(sliderTraceCountAfter - sliderTraceCountBefore, 1, "shared slider preview helper coalesces duplicate bucket traces")
assert_eq(sliderPreviewDialog._betteruiLastSliderTraceBucket, 4, "shared slider preview helper records the active trace bucket")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
