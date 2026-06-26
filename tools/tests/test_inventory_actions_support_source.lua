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
    dofile("Modules/Inventory/Actions/SlotActions.lua")
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
assert_true(actionDialogHooks:find("existingActionDialogInfo = ESO_Dialogs and ESO_Dialogs%[ZO_GAMEPAD_INVENTORY_ACTION_DIALOG%]") ~= nil,
    "ActionDialogHooks captures the existing shared action dialog before registering")
assert_true(actionDialogHooks:find("CallExistingActionDialogSetup%(dialog, data%)") ~= nil,
    "ActionDialogHooks delegates unsupported scene setup to the previously registered dialog")
assert_true(actionDialogHooks:find("CallExistingPrimaryCallback%(dialog%)") ~= nil,
    "ActionDialogHooks delegates unsupported scene primary actions to the previous dialog callback")
assert_true(actionDialogHooks:find("CanDestroyTargetWithPolicy%(targetData%)") ~= nil,
    "ActionDialogHooks guards synthetic destroy actions with the shared destroy-policy seam")
assert_true(actionDialogHooks:find("local function GetProtectionPolicy%(") ~= nil,
    "ActionDialogHooks resolves destroy policy through an explicit required policy accessor")
assert_true(actionDialogHooks:find("local function RequireDestroyPolicyMethod%(") ~= nil,
    "ActionDialogHooks requires the destroy-policy method contract explicitly")
assert_true(actionDialogHooks:find("policy and policy%.CanDestroyItem") == nil,
    "ActionDialogHooks fails closed when no destroy-policy seam is available")

local destroyAction = read_file("Modules/Inventory/Actions/DestroyAction.lua")
assert_true(destroyAction:find("function BETTERUI%.Inventory%.TryDestroyItem%(bagId, slotIndex, force, suppressUiRefresh, slotType%)") ~= nil,
    "DestroyAction exposes TryDestroyItem")
assert_true(destroyAction:find("function BETTERUI%.Inventory%.HookDestroyItem%(%)") ~= nil,
    "DestroyAction exposes HookDestroyItem")
assert_true(destroyAction:find("BETTERUI%.CIM%.SafeExecute") ~= nil,
    "DestroyAction routes force destroy through SafeExecute")
assert_true(destroyAction:find("BETTERUI%.Inventory%.CanDestroyItemWithPolicy = CanDestroyItemWithPolicy") ~= nil,
    "DestroyAction exposes shared destroy-policy helper for inventory action callers")
assert_true(destroyAction:find("CaptureSlotIdentity%(bag, index, inventorySlot%)") ~= nil,
    "DestroyAction snapshots slot identity before opening delayed destroy confirmations")

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
assert_true(itemActionHandlers:find("function ActionHandlers%.OnFinish%(self, dialog%)") ~= nil,
    "ItemActionHandlers exposes OnFinish")
assert_true(itemActionHandlers:find("function ActionHandlers%.OnConfirm%(self, dialog%)") ~= nil,
    "ItemActionHandlers exposes OnConfirm")
assert_true(itemActionHandlers:find("BETTERUI%.Banking and BETTERUI%.Banking%.GetSortEntryContext") ~= nil,
    "ItemActionHandlers resolves banking sort context through the Banking-owned seam")
assert_true(itemActionHandlers:find("local function CanDestroyTargetData%(targetData%)") ~= nil,
    "ItemActionHandlers centralizes destroy authorization checks for selected targets")
assert_true(itemActionHandlers:find("CanDestroyItemWithPolicy") ~= nil,
    "ItemActionHandlers delegates destroy eligibility checks to shared policy helpers")
assert_true(itemActionHandlers:find("local function RequireDestroyPolicyAuthorizer%(") ~= nil,
    "ItemActionHandlers resolves destroy authorization through a required policy helper")
assert_true(itemActionHandlers:find("local function RequireProtectionPolicyMethod%(") ~= nil,
    "ItemActionHandlers resolves junk authorization through a required policy helper")
assert_true(itemActionHandlers:find("local function CanJunkWithPolicy%(target%)") ~= nil,
    "ItemActionHandlers exposes a local CanJunkWithPolicy helper")
assert_true(itemActionHandlers:find("local function CanUnjunkWithPolicy%(target%)") ~= nil,
    "ItemActionHandlers exposes a local CanUnjunkWithPolicy helper")
assert_true(itemActionHandlers:find("policy and policy%.CanDestroyItem") == nil,
    "ItemActionHandlers fails closed when no destroy-policy seam is available")
assert_true(itemActionHandlers:find("policy and policy%.CanJunkItem") == nil,
    "ItemActionHandlers fails closed when no junk-policy seam is available")
assert_true(itemActionHandlers:find("policy and policy%.CanUnjunkItem") == nil,
    "ItemActionHandlers fails closed when no unjunk-policy seam is available")
assert_true(itemActionHandlers:find("BETTERUI%.Banking%.Class") == nil,
    "ItemActionHandlers no longer reaches into Banking.Class directly")
assert_true(itemActionHandlers:find('GetString%(rawget%(_G, "SI_ITEM_ACTION_SHOW_QUEST"%)%)') ~= nil,
    "ItemActionHandlers handles the Show-in-Quest-Journal action explicitly")
assert_true(itemActionHandlers:find("OpenQuestJournalToQuest%(ds%.questIndex%)") ~= nil,
    "ItemActionHandlers opens the quest journal from BetterUI's own dataSource questIndex (not the native closure)")
assert_true(itemActionHandlers:find("IsQuestActionTarget") ~= nil
    and itemActionHandlers:find("inventory quest action filter failed", 1, true) ~= nil
    and itemActionHandlers:find("ZO_InventoryUtils_DoesNewItemMatchFilterType%(targetData, ITEMFILTERTYPE_QUEST%)") == nil,
    "ItemActionHandlers guards quest action detection against native filter failures on synthetic rows")

local itemActionsDialog = read_file("Modules/Inventory/Actions/ItemActionsDialog.lua")
assert_true(itemActionsDialog:find("function BETTERUI%.Inventory%.Class:InitializeItemActions%(%)") ~= nil,
    "ItemActionsDialog exposes InitializeItemActions")
assert_true(itemActionsDialog:find("function BETTERUI%.Inventory%.Class:InitializeActionsDialog%(%)") ~= nil,
    "ItemActionsDialog exposes InitializeActionsDialog")
assert_true(itemActionsDialog:find('CALLBACK_MANAGER:RegisterCallback%("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", function%(dialog%)') ~= nil,
    "ItemActionsDialog wires the confirm callback to the shared action handlers")

local slotActions = read_file("Modules/Inventory/Actions/SlotActions.lua")
assert_true(slotActions:find("local function RequireDestroyPolicyAuthorizer%(%s*%)") ~= nil,
    "SlotActions resolves shared destroy authorization through an explicit required seam")
assert_true(slotActions:find("local function CanMarkSlotAsJunkWithoutPolicy%(", 1, true) == nil,
    "SlotActions removes legacy no-policy junk fallback helpers")
assert_true(slotActions:find("if BETTERUI%.Inventory and BETTERUI%.Inventory%.CanDestroyItemWithPolicy then") == nil,
    "SlotActions no longer mixes destroy-policy fallback styles")
assert_true(slotActions:find("return RequireDestroyPolicyAuthorizer%(%)%(bag, slot, inventorySlot and inventorySlot%.slotType%) == true") ~= nil,
    "SlotActions requires explicit destroy-policy approval for primary destroy actions")

if failed > 0 then
    error(string.format("test_inventory_actions_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_inventory_actions_support_source.lua: %d passed", passed))
