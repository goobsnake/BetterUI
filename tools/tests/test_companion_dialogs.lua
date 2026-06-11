--[[
File: tools/tests/test_companion_dialogs.lua
Purpose: Regression tests for companion action and batch dialog behavior.

Usage:
  lua tools/tests/test_companion_dialogs.lua
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

local registrations = {}
local registerCounts = {}
local executedActions = {}
local dialogSetupCalls = 0
local delayedCalls = {}
local destroyCalls = {}
local destroyDialogCalls = {}
local shownGamepadDialogs = {}
local lockCalls = {}
local junkCalls = {}

local selectedItems = {
    { bagId = 1, slotIndex = 10 },
    { dataSource = { bagId = 2, slotIndex = 20 } },
}

local multiSelect = {
    selectedCount = 2,
    numItems = 5,
    selectAllCount = 0,
    clearSelectionsCount = 0,
}

function multiSelect:GetSelectedItems()
    return selectedItems
end

function multiSelect:GetSelectedCount()
    return self.selectedCount
end

function multiSelect:SelectAll()
    self.selectAllCount = self.selectAllCount + 1
end

function multiSelect:ClearSelections()
    self.clearSelectionsCount = self.clearSelectionsCount + 1
end

BETTERUI = {
    CIM = {
        Utils = {
            SafeGetTargetData = function(list)
                if not list then
                    return nil
                end
                if list.GetTargetData then
                    return list:GetTargetData()
                end
                if list.GetSelectedData then
                    return list:GetSelectedData()
                end
                return list.selectedData
            end,
        },
        Dialogs = {
            CreateParametricActionEntry = function(name, actionId)
                return {
                    template = "entry",
                    entryData = {
                        name = name,
                        actionId = actionId,
                    },
                }
            end,
        },
    },
    Companions = {
        instance = {
            list = {
                GetNumItems = function()
                    return multiSelect.numItems
                end,
            },
        },
        multiSelectManager = multiSelect,
        settings = {
            enableCompanionJunk = true,
            batchDestroy = true,
            quickDestroy = false,
        },
        BuildActionList = function(selectedData)
            return {
                { id = "equip", name = "Equip" },
                { id = "link", name = "Link" },
            }
        end,
        CanExecuteAction = function(actionId, selectedData)
            local data = selectedData.dataSource or selectedData
            if not data or not data.bagId or not data.slotIndex then
                return false
            end
            return actionId == "lock"
                or actionId == "unlock"
                or actionId == "junk"
                or actionId == "unjunk"
                or actionId == "destroy"
        end,
        ExecuteAction = function(actionId, selectedData)
            table.insert(executedActions, { actionId = actionId, selectedData = selectedData })
            local data = selectedData.dataSource or selectedData
            local bagId = data and data.bagId
            local slotIndex = data and data.slotIndex
            if actionId == "lock" then
                SetItemPlayerLocked(bagId, slotIndex, true)
            elseif actionId == "unlock" then
                SetItemPlayerLocked(bagId, slotIndex, false)
            elseif actionId == "junk" then
                SetItemIsJunk(bagId, slotIndex, true)
            elseif actionId == "unjunk" then
                SetItemIsJunk(bagId, slotIndex, false)
            elseif actionId == "destroy" then
                if BETTERUI.Companions.settings.quickDestroy then
                    DestroyItem(bagId, slotIndex)
                else
                    BETTERUI.Companions.ShowCompanionDestroyDialog(bagId, slotIndex)
                end
            end
        end,
        GetSetting = function(key)
            return BETTERUI.Companions.settings[key]
        end,
        ShowCompanionDestroyDialog = function(bagId, slotIndex)
            table.insert(destroyDialogCalls, { bagId = bagId, slotIndex = slotIndex })
        end,
        QuickDestroyCompanionItem = function(bagId, slotIndex, slotType)
            DestroyItem(bagId, slotIndex)
            return true
        end,
    },
}

GAMEPAD_DIALOGS = { PARAMETRIC = 1 }
SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND = "action"
SI_DIALOG_CANCEL = "cancel"
SI_GAMEPAD_SELECT_OPTION = "select"
SI_BETTERUI_INV_BATCH_ACTIONS = "batch"
SI_BETTERUI_INV_ACTION_DESELECT_ALL = "deselect all"
SI_ITEM_ACTION_MARK_AS_JUNK = "junk"
SI_ITEM_ACTION_UNMARK_AS_JUNK = "unjunk"
SI_ITEM_ACTION_MARK_AS_LOCKED = "lock"
SI_ITEM_ACTION_UNMARK_AS_LOCKED = "unlock"
SI_ITEM_ACTION_DESTROY = "destroy"

function GetString(value)
    return tostring(value)
end

ZO_GamepadEntryData = {}
function ZO_GamepadEntryData:New(name)
    return {
        name = name,
        SetIconTintOnSelection = function() end,
    }
end

function ZO_ClearNumericallyIndexedTable(tbl)
    for i = #tbl, 1, -1 do
        tbl[i] = nil
    end
end

function ZO_Dialogs_IsDialogRegistered(name)
    return registrations[name] ~= nil
end

function ZO_Dialogs_RegisterCustomDialog(name, info)
    registrations[name] = info
    registerCounts[name] = (registerCounts[name] or 0) + 1
end

function ZO_Dialogs_ShowGamepadDialog(name, data)
    table.insert(shownGamepadDialogs, { name = name, data = data })
end

function SetItemPlayerLocked(bagId, slotIndex, locked)
    table.insert(lockCalls, { bagId = bagId, slotIndex = slotIndex, locked = locked })
end

function SetItemIsJunk(bagId, slotIndex, isJunk)
    table.insert(junkCalls, { bagId = bagId, slotIndex = slotIndex, isJunk = isJunk })
end

function DestroyItem(bagId, slotIndex)
    table.insert(destroyCalls, { bagId = bagId, slotIndex = slotIndex })
end

function zo_callLater(callback, delay)
    table.insert(delayedCalls, delay)
    callback()
end

dofile("Modules/Companions/Dialogs/CompanionDialogs.lua")

print("[Companion dialogs]")

BETTERUI.Companions.RegisterDialogs()
assert_true(registrations["BETTERUI_COMPANION_ACTION_DIALOG"] ~= nil, "registers companion action dialog")
assert_true(registrations["BETTERUI_COMPANION_BATCH_DIALOG"] ~= nil, "registers companion batch dialog")

BETTERUI.Companions.RegisterDialogs()
assert_eq(registerCounts["BETTERUI_COMPANION_ACTION_DIALOG"], 1, "action dialog registration is idempotent")
assert_eq(registerCounts["BETTERUI_COMPANION_BATCH_DIALOG"], 1, "batch dialog registration is idempotent")

local actionDialog = registrations["BETTERUI_COMPANION_ACTION_DIALOG"]
local actionData = { bagId = 3, slotIndex = 30 }
local actionRuntimeDialog = {
    data = { selectedData = actionData },
    info = actionDialog,
    entryList = {
        GetTargetData = function()
            return { actionId = "link" }
        end,
    },
    setupFunc = function()
        dialogSetupCalls = dialogSetupCalls + 1
    end,
}

actionDialog.setup(actionRuntimeDialog)
assert_eq(#actionDialog.parametricList, 2, "action setup builds entries from BuildActionList")
actionDialog.buttons[2].callback(actionRuntimeDialog)
assert_eq(#executedActions, 1, "action callback executes selected action")
assert_eq(executedActions[1].actionId, "link", "action callback forwards action id")
assert_eq(executedActions[1].selectedData, actionData, "action callback forwards selected item data")
assert_eq(dialogSetupCalls, 1, "action setup triggers dialog setup function")

local batchDialog = registrations["BETTERUI_COMPANION_BATCH_DIALOG"]
batchDialog.parametricList = batchDialog.parametricList or {}
local batchRuntimeDialog = {
    info = batchDialog,
    entryList = {
        GetTargetData = function()
            return { actionId = "selectAll" }
        end,
    },
    setupFunc = function()
        dialogSetupCalls = dialogSetupCalls + 1
    end,
}

batchDialog.setup(batchRuntimeDialog)
assert_true(#batchDialog.parametricList >= 6, "batch setup includes core action entries")
batchDialog.buttons[2].callback(batchRuntimeDialog)
assert_eq(multiSelect.selectAllCount, 1, "batch callback handles selectAll")

batchRuntimeDialog.entryList.GetTargetData = function()
    return { actionId = "deselectAll" }
end
batchDialog.buttons[2].callback(batchRuntimeDialog)
assert_eq(multiSelect.clearSelectionsCount, 1, "batch callback handles deselectAll")

batchRuntimeDialog.entryList.GetTargetData = function()
    return { actionId = "lock" }
end
batchDialog.buttons[2].callback(batchRuntimeDialog)
assert_eq(#lockCalls, 2, "batch lock applies to each selected item")
assert_eq(lockCalls[1].locked, true, "batch lock uses locked=true")

batchRuntimeDialog.entryList.GetTargetData = function()
    return { actionId = "junk" }
end
batchDialog.buttons[2].callback(batchRuntimeDialog)
assert_eq(#junkCalls, 2, "batch junk applies to each selected item")
assert_eq(junkCalls[1].isJunk, true, "batch junk marks items as junk")

BETTERUI.Companions.settings.quickDestroy = false
batchRuntimeDialog.entryList.GetTargetData = function()
    return { actionId = "destroy" }
end
batchDialog.buttons[2].callback(batchRuntimeDialog)
assert_eq(#destroyDialogCalls, 0, "batch destroy does not queue per-item confirmation dialogs")
assert_eq(#shownGamepadDialogs, 1, "batch destroy shows a single confirmation dialog when quickDestroy is false")
assert_eq(shownGamepadDialogs[1].name, "BETTERUI_COMPANION_BATCH_DESTROY_DIALOG",
    "batch destroy uses the batch confirmation dialog")
assert_eq(shownGamepadDialogs[1].data.itemCount, 2, "batch confirmation reports the eligible item count")
assert_eq(#destroyCalls, 0, "batch destroy does not hard destroy before confirmation")

local batchDestroyDialog = registrations["BETTERUI_COMPANION_BATCH_DESTROY_DIALOG"]
assert_true(batchDestroyDialog ~= nil, "registers companion batch destroy dialog")
batchDestroyDialog.buttons[2].callback({ data = shownGamepadDialogs[1].data })
assert_eq(#destroyCalls, 2, "confirming the batch destroy dialog quick-destroys each selected item")

destroyCalls = {}
BETTERUI.Companions.settings.quickDestroy = true
batchDialog.buttons[2].callback(batchRuntimeDialog)
assert_eq(#destroyCalls, 2, "batch destroy hard destroys when quickDestroy is true")
assert_eq(#shownGamepadDialogs, 1, "quickDestroy batch destroy skips the confirmation dialog")
assert_eq(delayedCalls[1], 0, "batch actions start with immediate delay")
assert_eq(delayedCalls[2], 80, "batch actions stagger repeated operations")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
