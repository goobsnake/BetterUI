--[[
File: tools/tests/test_inventory_multiselect_dialogs.lua
Purpose: Unit tests for INV-001 – batch dialogs routed through BETTERUI.CIM.Dialogs.Register.
         Verifies that ShowBatchActionsMenu and ShowCraftBagBatchActionsMenu register their
         dialogs through the central registry seam, not directly into ESO_Dialogs.

Usage:
  lua tools/tests/test_inventory_multiselect_dialogs.lua
]]

-- ============================================================================
-- MINIMAL ESO / BETTERUI STUBS
-- ============================================================================

GAMEPAD_DIALOGS = { PARAMETRIC = "PARAMETRIC" }
GAMEPAD_INVENTORY = nil

-- ESO_Dialogs should NOT receive any batch dialog registrations after the fix.
ESO_Dialogs = {}

ZO_GamepadEntryData = {}
ZO_GamepadEntryData.__index = ZO_GamepadEntryData
function ZO_GamepadEntryData:New(label)
    return setmetatable({ label = label }, ZO_GamepadEntryData)
end
function ZO_GamepadEntryData:SetIconTintOnSelection() end
ZO_SharedGamepadEntry_OnSetup = function() end

function GetString(id) return tostring(id) end
function zo_strformat(fmt, ...) return tostring(fmt) end
function zo_callLater(fn, ms) end
function rawget(t, k) return t[k] end
function GetSlotStackSize() return 0 end
function ZO_Dialogs_ShowGamepadDialog() end

-- Central dialog registry tracking
local registeredDialogs = {}
local shownDialogs = {}

BETTERUI = {
    Inventory = {
        Class = {},
        Utils = {
            SafeGetTargetData = function() return nil end,
        },
        CanDestroyInventoryItem = function() return false end,
        GetSetting = function() return false end,
    },
    CIM = {
        MultiSelectMixin = {
            BindDelegates = function(cls, names)
                -- no-op: delegates are bound at game startup
            end,
            AnalyzeSelectedItems = function(items)
                return { lockCount = 0, unlockCount = 0, junkCount = 0 }
            end,
            CreateDialogEntry = function(label, cb)
                return {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = {
                        label = label,
                        callback = cb,
                        setup = function() end,
                        SetIconTintOnSelection = function() end,
                    },
                }
            end,
            AppendCommonBatchEntries = function(list, counts, self) end,
        },
        Dialogs = {
            Registry = { _dialogs = {} },
            Register = function(name, info, opts)
                registeredDialogs[name] = info
                return true
            end,
            IsRegistered = function(name) return registeredDialogs[name] ~= nil end,
            Show = function(name, data)
                shownDialogs[#shownDialogs + 1] = name
            end,
            CreateParametricActionEntry = function(label, actionId) return {} end,
        },
        Keybinds = {
            GetSelectAllLabel   = function() return "Select All" end,
            GetDeselectAllLabel = function(count) return "Deselect All (" .. tostring(count) .. ")" end,
        },
        ProtectionPolicy = {
            CanStowToCraftBag = function() return false end,
        },
    },
    Log = {
        Debug    = function() end,
        CATEGORY = { BATCH = "BATCH" },
    },
    Utils = {
        IsInventorySceneShowing = function() return false end,
    },
}

dofile("Modules/Inventory/Core/InventoryMultiSelect.lua")
local Class = BETTERUI.Inventory.Class

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0
local function check(cond, message)
    if cond then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
    end
end

print("\n=== InventoryMultiSelect Dialog Registry Tests (INV-001) ===\n")

-- Helper: build a stub instance with multi-select active
local function makeInventoryInstance(items)
    items = items or { { bagId = 1, slotIndex = 1 } }
    local inst = setmetatable({}, { __index = Class })
    inst.multiSelectManager = {
        IsActive        = function() return true end,
        GetSelectedItems = function() return items end,
    }
    inst.craftBagMultiSelectManager = {
        IsActive        = function() return true end,
        GetSelectedItems = function() return items end,
    }
    inst.GetCurrentList = function() return nil end
    inst.RefreshItemList   = function() end
    inst.RefreshKeybinds   = function() end
    inst.RefreshCraftBagList = function() end
    return inst
end

-- ============================================================================
-- ShowBatchActionsMenu: dialog goes through Dialogs.Register
-- ============================================================================

registeredDialogs = {}
shownDialogs      = {}
ESO_Dialogs       = {}

local inv = makeInventoryInstance()
inv:ShowBatchActionsMenu()

check(
    registeredDialogs["BETTERUI_BATCH_ACTIONS_DIALOG"] ~= nil,
    "ShowBatchActionsMenu registers BETTERUI_BATCH_ACTIONS_DIALOG via Dialogs.Register"
)
check(
    ESO_Dialogs["BETTERUI_BATCH_ACTIONS_DIALOG"] == nil,
    "ShowBatchActionsMenu does NOT write BETTERUI_BATCH_ACTIONS_DIALOG directly into ESO_Dialogs"
)
check(
    #shownDialogs == 1 and shownDialogs[1] == "BETTERUI_BATCH_ACTIONS_DIALOG",
    "ShowBatchActionsMenu calls Dialogs.Show with the correct dialog name"
)

-- ============================================================================
-- ShowBatchActionsMenu: Register called only once (idempotent across calls)
-- ============================================================================

local registerCallCount = 0
local origRegister = BETTERUI.CIM.Dialogs.Register
BETTERUI.CIM.Dialogs.Register = function(name, info, opts)
    registerCallCount = registerCallCount + 1
    return origRegister(name, info, opts)
end

inv:ShowBatchActionsMenu()
inv:ShowBatchActionsMenu()
check(registerCallCount == 0, "Dialogs.Register NOT called again on subsequent ShowBatchActionsMenu calls")

BETTERUI.CIM.Dialogs.Register = origRegister

-- ============================================================================
-- ShowBatchActionsMenu: parametricList is updated on the registered info
-- ============================================================================

local batchInfo = registeredDialogs["BETTERUI_BATCH_ACTIONS_DIALOG"]
check(
    type(batchInfo) == "table" and type(batchInfo.parametricList) == "table",
    "Registered batch dialog info has a parametricList table"
)
check(
    #batchInfo.parametricList >= 2,
    "parametricList has at least Select All + Deselect All entries"
)

-- ============================================================================
-- ShowCraftBagBatchActionsMenu: dialog goes through Dialogs.Register
-- ============================================================================

registeredDialogs["BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG"] = nil
shownDialogs = {}
ESO_Dialogs  = {}

inv:ShowCraftBagBatchActionsMenu()

check(
    registeredDialogs["BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG"] ~= nil,
    "ShowCraftBagBatchActionsMenu registers BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG via Dialogs.Register"
)
check(
    ESO_Dialogs["BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG"] == nil,
    "ShowCraftBagBatchActionsMenu does NOT write dialog directly into ESO_Dialogs"
)
check(
    #shownDialogs == 1 and shownDialogs[1] == "BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG",
    "ShowCraftBagBatchActionsMenu calls Dialogs.Show with the correct dialog name"
)

-- ============================================================================
-- Both dialogs share the same template structure (buttons, gamepadInfo)
-- ============================================================================

local cbInfo   = registeredDialogs["BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG"]
local invInfo  = registeredDialogs["BETTERUI_BATCH_ACTIONS_DIALOG"]

check(
    cbInfo ~= nil and invInfo ~= nil,
    "Both dialog infos are present in the registry"
)
check(
    cbInfo.gamepadInfo ~= nil and cbInfo.gamepadInfo.dialogType == GAMEPAD_DIALOGS.PARAMETRIC,
    "CraftBag dialog has correct gamepadInfo.dialogType"
)
check(
    invInfo.gamepadInfo ~= nil and invInfo.gamepadInfo.dialogType == GAMEPAD_DIALOGS.PARAMETRIC,
    "Inventory batch dialog has correct gamepadInfo.dialogType"
)
check(
    type(cbInfo.buttons) == "table" and #cbInfo.buttons == 2,
    "CraftBag dialog has exactly 2 buttons (PRIMARY + NEGATIVE)"
)
check(
    cbInfo.buttons[1].keybind == "DIALOG_PRIMARY" and cbInfo.buttons[2].keybind == "DIALOG_NEGATIVE",
    "CraftBag dialog button keybinds are PRIMARY then NEGATIVE"
)
check(
    cbInfo ~= invInfo,
    "CraftBag and inventory dialogs are separate table instances"
)

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))

if tests_failed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
