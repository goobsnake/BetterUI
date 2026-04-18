--[[
File: tools/tests/test_inventory_multiselect_stow_policy.lua
Purpose: Verifies inventory multi-select counts craft-bag actions through ProtectionPolicy.
Usage:
  lua tools/tests/test_inventory_multiselect_stow_policy.lua
]]

local passed = 0
local failed = 0

local function assert_equal(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

BETTERUI = {
    Inventory = {
        Class = {},
    },
    CIM = {
        MultiSelectMixin = {},
        ProtectionPolicy = {},
    },
}

local recordedDialog = nil
local stowAllowed = false

function BETTERUI.CIM.MultiSelectMixin.BindDelegates()
end

function BETTERUI.CIM.MultiSelectMixin.AnalyzeSelectedItems()
    return {}
end

function BETTERUI.CIM.MultiSelectMixin.CreateDialogEntry(label, callback)
    return { entryData = { text = label, callback = callback } }
end

function BETTERUI.CIM.MultiSelectMixin.AppendCommonBatchEntries()
end

function BETTERUI.Inventory.GetSetting()
    return false
end

function GetSlotStackSize()
    return 5
end

BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag = function(_bagId, _slotIndex)
    return stowAllowed
end

ZO_Dialogs_ShowGamepadDialog = function(name, data)
    recordedDialog = { name = name, data = data }
end

GetString = function(value)
    return tostring(value)
end

zo_strformat = function(_, label, count)
    return string.format("%s (%s)", tostring(label), tostring(count))
end

SI_BETTERUI_SELECT_ALL = "Select All"
SI_BETTERUI_DESELECT_ALL = "Deselect All"
SI_BETTERUI_SELECTED_COUNT = "<<1>> Selected"
SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG = "Add to Craft Bag"
SI_GAMEPAD_SELECT_OPTION = "Select"
SI_GAMEPAD_BACK_OPTION = "Back"
GAMEPAD_DIALOGS = { PARAMETRIC = 1 }
ESO_Dialogs = {}

dofile("Modules/Inventory/Core/InventoryMultiSelect.lua")

local manager = {
    IsActive = function() return true end,
    GetSelectedItems = function()
        return {
            { bagId = 1, slotIndex = 9 },
        }
    end,
}

local inventory = setmetatable({
    multiSelectManager = manager,
    SelectAllItems = function() end,
    BatchStow = function() end,
    ExitSelectionMode = function() end,
}, { __index = BETTERUI.Inventory.Class })

print("[Inventory multi-select stow policy]")

stowAllowed = false
recordedDialog = nil
inventory:ShowBatchActionsMenu()
local entries = recordedDialog and ESO_Dialogs[recordedDialog.name] and ESO_Dialogs[recordedDialog.name].parametricList or {}
assert_equal(#entries, 2, "policy-denied selection omits stow batch action")

stowAllowed = true
recordedDialog = nil
inventory:ShowBatchActionsMenu()
entries = recordedDialog and ESO_Dialogs[recordedDialog.name] and ESO_Dialogs[recordedDialog.name].parametricList or {}
assert_equal(#entries, 3, "policy-allowed selection includes stow batch action")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
