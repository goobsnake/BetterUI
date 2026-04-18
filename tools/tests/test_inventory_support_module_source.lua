--[[
File: tools/tests/test_inventory_support_module_source.lua
Purpose: Source-level regression checks for shared inventory support modules.

Usage:
  lua tools/tests/test_inventory_support_module_source.lua
]]

if false then
    dofile("Modules/Inventory/Constants.lua")
    dofile("Modules/Inventory/Core/CategoryDefinitions.lua")
    dofile("Modules/Inventory/Core/InventoryMultiSelect.lua")
    dofile("Modules/Inventory/Core/Utils.lua")
    dofile("Modules/Inventory/Dialogs/CraftBagQuantityDialog.lua")
    dofile("Modules/Inventory/Dialogs/InventoryDialogs.lua")
    dofile("Modules/Inventory/Keybinds/CraftBagKeybinds.lua")
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

local constantsSource = read_file("Modules/Inventory/Constants.lua")
assert_true(constantsSource:find("BETTERUI%.Inventory%.CONST%.LIST_TYPES = %{%s*") ~= nil,
    "Inventory constants define shared list type identifiers")
assert_true(constantsSource:find("function BETTERUI%.Inventory%.CONST%.GetSearchConstants%(%)") ~= nil,
    "Inventory constants expose GetSearchConstants")
assert_true(constantsSource:find("function BETTERUI%.Inventory%.DefaultSortComparator%(left, right%)") ~= nil,
    "Inventory constants expose DefaultSortComparator")

local categorySource = read_file("Modules/Inventory/Core/CategoryDefinitions.lua")
assert_true(categorySource:find("BETTERUI%.Inventory%.Categories%.CraftBag = %{%s*") ~= nil,
    "CategoryDefinitions defines craft bag categories")
assert_true(categorySource:find("BETTERUI%.Inventory%.Categories%.Inventory = %{%s*") ~= nil,
    "CategoryDefinitions defines inventory categories")
assert_true(categorySource:find("function BETTERUI%.Inventory%.Categories%.DoesItemMatchCategory%(itemData, category%)") ~= nil,
    "CategoryDefinitions exposes DoesItemMatchCategory")
assert_true(categorySource:find("function BETTERUI%.Inventory%.Categories%.GetCategoryTypeFromWeaponType%(bagId, slotIndex%)") ~= nil,
    "CategoryDefinitions exposes GetCategoryTypeFromWeaponType")

local multiSelectSource = read_file("Modules/Inventory/Core/InventoryMultiSelect.lua")
assert_true(multiSelectSource:find("Class%.EnterSelectionMode = MultiSelectMixin%.EnterSelectionMode") ~= nil,
    "InventoryMultiSelect wires EnterSelectionMode through the shared mixin delegate")
assert_true(multiSelectSource:find("function Class:ShowBatchActionsMenu%(%)") ~= nil,
    "InventoryMultiSelect exposes ShowBatchActionsMenu")
assert_true(multiSelectSource:find("function Class:EnterCraftBagSelectionMode%(%)") ~= nil,
    "InventoryMultiSelect exposes EnterCraftBagSelectionMode")
assert_true(multiSelectSource:find("function Class:ShowCraftBagBatchActionsMenu%(%)") ~= nil,
    "InventoryMultiSelect exposes ShowCraftBagBatchActionsMenu")

local utilsSource = read_file("Modules/Inventory/Core/Utils.lua")
assert_true(utilsSource:find("function BETTERUI%.Inventory%.Utils%.OnTabNext%(parent, successful%)") ~= nil,
    "Inventory utils expose OnTabNext")
assert_true(utilsSource:find("function BETTERUI%.Inventory%.Utils%.OnTabPrev%(parent, successful%)") ~= nil,
    "Inventory utils expose OnTabPrev")
assert_true(utilsSource:find("BETTERUI%.Inventory%.Utils%.SafeGetTargetData = BETTERUI%.Utils%.SafeGetTargetData") ~= nil,
    "Inventory utils alias SafeGetTargetData to the shared helper")

local craftBagDialogSource = read_file("Modules/Inventory/Dialogs/CraftBagQuantityDialog.lua")
assert_true(craftBagDialogSource:find("function BETTERUI%.Inventory%.Dialogs%.InitializeCraftBagQuantityDialog%(%)") ~= nil,
    "CraftBagQuantityDialog exposes InitializeCraftBagQuantityDialog")
assert_true(craftBagDialogSource:find("function BETTERUI%.Inventory%.Dialogs%.ShowCraftBagQuantityDialog%(inventorySlot, isStow%)") ~= nil,
    "CraftBagQuantityDialog exposes ShowCraftBagQuantityDialog")
assert_true(craftBagDialogSource:find("BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED") ~= nil,
    "CraftBagQuantityDialog defines the finished callback event")

local inventoryDialogsSource = read_file("Modules/Inventory/Dialogs/InventoryDialogs.lua")
assert_true(inventoryDialogsSource:find("function BETTERUI%.Inventory%.Class:InitializeSplitStackDialog%(%)") ~= nil,
    "InventoryDialogs exposes InitializeSplitStackDialog")
assert_true(inventoryDialogsSource:find("function BETTERUI%.Inventory%.Class:InitializeConfirmDestroyDialog%(%)") ~= nil,
    "InventoryDialogs exposes InitializeConfirmDestroyDialog")
assert_true(inventoryDialogsSource:find("function BETTERUI%.Inventory%.Class:InitializeConfirmDestroyArmoryItemDialog%(%)") ~= nil,
    "InventoryDialogs exposes InitializeConfirmDestroyArmoryItemDialog")

local craftBagKeybindsSource = read_file("Modules/Inventory/Keybinds/CraftBagKeybinds.lua")
assert_true(craftBagKeybindsSource:find("function InventoryKeybinds%.GetActionsTargetList%(self%)") ~= nil,
    "CraftBagKeybinds exposes GetActionsTargetList")
assert_true(craftBagKeybindsSource:find("function InventoryKeybinds%.HasStableActionsTarget%(self%)") ~= nil,
    "CraftBagKeybinds exposes HasStableActionsTarget")
assert_true(craftBagKeybindsSource:find("function InventoryKeybinds%.GetPrimaryKeybindName%(self%)") ~= nil,
    "CraftBagKeybinds exposes GetPrimaryKeybindName")

if failed > 0 then
    error(string.format("test_inventory_support_module_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_inventory_support_module_source.lua: %d passed", passed))
