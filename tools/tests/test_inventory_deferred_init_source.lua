--[[
File: tools/tests/test_inventory_deferred_init_source.lua
Purpose: Guards the Inventory deferred-init split so dialog compatibility,
         list bootstrap, and callback wiring stay behind named helpers.
Usage:
  lua tools/tests/test_inventory_deferred_init_source.lua
]]

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

print("test_inventory_deferred_init_source")

local inventory = read_file("Modules/Inventory/Inventory.lua")
local inventoryClass = read_file("Modules/Inventory/Core/InventoryClass.lua")
local equipAction = read_file("Modules/Inventory/Actions/EquipAction.lua")

assert_contains(inventory, "local function InitializeDeferredInventoryState(self)",
    "Inventory deferred init exposes an explicit state phase helper")
assert_contains(inventory, "local function InitializeDeferredInventoryLists(self)",
    "Inventory deferred init exposes an explicit list phase helper")
assert_contains(inventory, "local function InitializeDeferredInventoryDialogs(self)",
    "Inventory deferred init exposes an explicit dialog phase helper")
assert_contains(inventory, "local function RegisterDeferredInventoryCallbacks(self, refreshHeader, refreshSelectedData)",
    "Inventory deferred init exposes an explicit callback registration helper")
assert_contains(inventory, "local function EnsureLegacyEquipSlotDialogAlias()",
    "Inventory keeps the legacy equip dialog alias behind a compatibility helper")
assert_contains(inventory, "function BETTERUI.Inventory.GetEquipSlotDialogName()",
    "Inventory exposes a canonical equip dialog accessor")
assert_contains(inventory, "InitializeDeferredInventoryState(self)",
    "OnDeferredInitialize delegates state setup through the helper")
assert_contains(inventory, "InitializeDeferredInventoryLists(self)",
    "OnDeferredInitialize delegates list setup through the helper")
assert_contains(inventory, "InitializeDeferredInventoryDialogs(self)",
    "OnDeferredInitialize delegates dialog setup through the helper")
assert_contains(inventory, "RegisterDeferredInventoryCallbacks(self, RefreshHeader, RefreshSelectedData)",
    "OnDeferredInitialize delegates callback wiring through the helper")
assert_contains(inventory, "BETTERUI_EQUIP_SLOT_DIALOG = BETTERUI.Inventory.GetEquipSlotDialogName()",
    "the legacy global alias is assigned from the canonical dialog accessor")
assert_not_contains(inventoryClass, "self:InitializeItemActions()",
    "InventoryClass.Initialize no longer performs item-action setup before deferred readiness")
assert_not_contains(inventoryClass, "self:InitializeActionsDialog()",
    "InventoryClass.Initialize no longer performs action-dialog setup before deferred readiness")

assert_contains(equipAction, "BETTERUI.Inventory.GetEquipSlotDialogName()",
    "EquipAction uses the canonical namespaced dialog accessor")
assert_not_contains(equipAction, 'or "BETTERUI_EQUIP_SLOT_DIALOG"',
    "EquipAction no longer falls back to an inline legacy dialog string")

print("  OK")
