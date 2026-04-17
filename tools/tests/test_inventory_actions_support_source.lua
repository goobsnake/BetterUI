--[[
File: tools/tests/test_inventory_actions_support_source.lua
Purpose: Source-level regression checks for shared inventory action modules.

Usage:
  lua tools/tests/test_inventory_actions_support_source.lua
]]

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

local destroyAction = read_file("Modules/Inventory/Actions/DestroyAction.lua")
assert_true(destroyAction:find("function BETTERUI%.Inventory%.TryDestroyItem%(bagId, slotIndex, force, suppressUiRefresh%)") ~= nil,
    "DestroyAction exposes TryDestroyItem")
assert_true(destroyAction:find("function BETTERUI%.Inventory%.HookDestroyItem%(%)") ~= nil,
    "DestroyAction exposes HookDestroyItem")
assert_true(destroyAction:find("BETTERUI%.CIM%.SafeExecute") ~= nil,
    "DestroyAction routes force destroy through SafeExecute")

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
