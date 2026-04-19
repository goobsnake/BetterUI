--[[
File: tools/tests/test_inventory_actions_support_source.lua
Purpose: Source-level regression checks for shared inventory action modules.

Usage:
  lua tools/tests/test_inventory_actions_support_source.lua
]]

if false then
    dofile("Modules/Inventory/Actions/ActionDialogHooks.lua")
    dofile("Modules/Inventory/Actions/DestroyAction.lua")
    dofile("Modules/Inventory/Actions/EquipAction.lua")
    dofile("Modules/Inventory/Actions/ItemActionHandlers.lua")
    dofile("Modules/Inventory/Actions/ItemActionsDialog.lua")
end

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local actionDialogHooks = read_file("Modules/Inventory/Actions/ActionDialogHooks.lua")
assert_true(actionDialogHooks:find("function BETTERUI%.Inventory%.HookActionDialog%(%)") ~= nil,
    "ActionDialogHooks exposes HookActionDialog")
assert_true(actionDialogHooks:find("BETTERUI%.CIM%.Dialogs%.Register%(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, %{%s*") ~= nil,
    "ActionDialogHooks registers the shared inventory action dialog")
assert_true(actionDialogHooks:find('CALLBACK_MANAGER:FireCallbacks%("BETTERUI_EVENT_ACTION_DIALOG_SETUP", dialog, data%)') ~= nil,
    "ActionDialogHooks routes setup through the BetterUI action-dialog callback")
assert_true(actionDialogHooks:find("CanDestroyTargetWithPolicy%(targetData%)") ~= nil,
    "ActionDialogHooks guards synthetic destroy actions with the shared destroy-policy seam")

local destroyAction = read_file("Modules/Inventory/Actions/DestroyAction.lua")
assert_true(destroyAction:find("function BETTERUI%.Inventory%.TryDestroyItem%(bagId, slotIndex, force, suppressUiRefresh, slotType%)") ~= nil,
    "DestroyAction exposes TryDestroyItem")
assert_true(destroyAction:find("function BETTERUI%.Inventory%.HookDestroyItem%(%)") ~= nil,
    "DestroyAction exposes HookDestroyItem")
assert_true(destroyAction:find("BETTERUI%.CIM%.SafeExecute") ~= nil,
    "DestroyAction routes force destroy through SafeExecute")
assert_true(destroyAction:find("BETTERUI%.Inventory%.CanDestroyItemWithPolicy = CanDestroyItemWithPolicy") ~= nil,
    "DestroyAction exposes shared destroy-policy helper for inventory action callers")

local equipAction = read_file("Modules/Inventory/Actions/EquipAction.lua")
assert_true(equipAction:find("BETTERUI%.Inventory%.EnsureCompanionEquipPatched = EnsureCompanionEquipPatched") ~= nil,
    "EquipAction exposes EnsureCompanionEquipPatched")
assert_true(equipAction:find("function BETTERUI%.Inventory%.Class:TryEquipItem%(inventorySlot, isCallingFromActionDialog%)") ~= nil,
    "EquipAction exposes TryEquipItem")
assert_true(equipAction:find("function BETTERUI%.Inventory%.Class:InitializeEquipSlotDialog%(%)") ~= nil,
    "EquipAction exposes InitializeEquipSlotDialog")

local itemActionHandlers = read_file("Modules/Inventory/Actions/ItemActionHandlers.lua")
assert_true(itemActionHandlers:find("if not BETTERUI%.Inventory%.ActionHandlers then BETTERUI%.Inventory%.ActionHandlers = %{%} end") ~= nil,
    "ItemActionHandlers initializes the shared action-handler table")
assert_true(itemActionHandlers:find("function ActionHandlers%.OnSetup%(self, dialog, data%)") ~= nil,
    "ItemActionHandlers exposes OnSetup")
assert_true(itemActionHandlers:find("function ActionHandlers%.OnFinish%(self%)") ~= nil,
    "ItemActionHandlers exposes OnFinish")
assert_true(itemActionHandlers:find("function ActionHandlers%.OnConfirm%(self, dialog%)") ~= nil,
    "ItemActionHandlers exposes OnConfirm")
assert_true(itemActionHandlers:find("BETTERUI%.CIM%.Utils%.GetBankingSortEntryContext") ~= nil,
    "ItemActionHandlers resolves banking sort context through the shared CIM seam")
assert_true(itemActionHandlers:find("local function CanDestroyTargetData%(targetData%)") ~= nil,
    "ItemActionHandlers centralizes destroy authorization checks for selected targets")
assert_true(itemActionHandlers:find("CanDestroyItemWithPolicy") ~= nil,
    "ItemActionHandlers delegates destroy eligibility checks to shared policy helpers")
assert_true(itemActionHandlers:find("BETTERUI%.Banking%.Class") == nil,
    "ItemActionHandlers no longer reaches into Banking.Class directly")

local itemActionsDialog = read_file("Modules/Inventory/Actions/ItemActionsDialog.lua")
assert_true(itemActionsDialog:find("function BETTERUI%.Inventory%.Class:InitializeItemActions%(%)") ~= nil,
    "ItemActionsDialog exposes InitializeItemActions")
assert_true(itemActionsDialog:find("function BETTERUI%.Inventory%.Class:InitializeActionsDialog%(%)") ~= nil,
    "ItemActionsDialog exposes InitializeActionsDialog")
assert_true(itemActionsDialog:find('CALLBACK_MANAGER:RegisterCallback%("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", function%(dialog%)') ~= nil,
    "ItemActionsDialog wires the confirm callback to the shared action handlers")

if failed > 0 then
    error(string.format("test_inventory_actions_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_inventory_actions_support_source.lua: %d passed", passed))
