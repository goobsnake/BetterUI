--[[
File: tools/tests/test_inventory_list_support_source.lua
Purpose: Source-level regression checks for inventory list, loader, and lifecycle support modules.

Usage:
  lua tools/tests/test_inventory_list_support_source.lua
]]

if false then
    dofile("Modules/Inventory/Loader.lua")
    dofile("Modules/Inventory/Module.lua")
    dofile("Modules/Inventory/Keybinds/InventoryKeybinds.lua")
    dofile("Modules/Inventory/Lists/CategoryListManager.lua")
    dofile("Modules/Inventory/Lists/CraftBagListManager.lua")
    dofile("Modules/Inventory/Lists/CraftList.lua")
    dofile("Modules/Inventory/Lists/ItemListFiltering.lua")
    dofile("Modules/Inventory/Lists/ItemListManager.lua")
    dofile("Modules/Inventory/Scene/InventorySceneLifecycle.lua")
    dofile("Modules/Inventory/Settings/CurrencySettings.lua")
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

local inventoryKeybindsSource = read_file("Modules/Inventory/Keybinds/InventoryKeybinds.lua")
assert_true(inventoryKeybindsSource:find("InventoryKeybinds%.IsQuickslottable = BETTERUI%.CIM%.IsQuickslottable") ~= nil,
    "InventoryKeybinds re-exports the shared CIM IsQuickslottable helper")
assert_true(inventoryKeybindsSource:find("GetXButtonActionContext") == nil,
    "InventoryKeybinds no longer carries a deprecated local X-button context shim")
assert_true(inventoryKeybindsSource:find("function BETTERUI%.Inventory%.Class:InitializeKeybindStrip%(%)") ~= nil,
    "InventoryKeybinds exposes InitializeKeybindStrip")

local craftBagKeybindsSource = read_file("Modules/Inventory/Keybinds/CraftBagKeybinds.lua")
assert_true(craftBagKeybindsSource:find("BETTERUI%.CIM%.Keybinds%.GetXButtonActionContext%(self%)") ~= nil,
    "CraftBagKeybinds consumes the shared CIM X-button action-context seam directly")
assert_true(craftBagKeybindsSource:find("InventoryKeybinds%.GetXButtonActionContext%(self%)") == nil,
    "CraftBagKeybinds no longer consumes the Inventory-local X-button action-context alias")

local categoryListSource = read_file("Modules/Inventory/Lists/CategoryListManager.lua")
assert_true(categoryListSource:find("function BETTERUI%.Inventory%.Class:InitializeCategoryList%(%)") ~= nil,
    "CategoryListManager exposes InitializeCategoryList")
assert_true(categoryListSource:find("function BETTERUI%.Inventory%.Class:NewCategoryItem%(filterType, iconFile, FilterFunct, forceAdd, precomputedStats%)") ~= nil,
    "CategoryListManager exposes NewCategoryItem")
assert_true(categoryListSource:find("catDef%.isStatic, stats%)") ~= nil,
    "CategoryListManager forces static categories through the second emptiness gate")
assert_true(categoryListSource:find("local function ComputeStandardCategoryStats%(self, categories%)") ~= nil,
    "CategoryListManager buckets standard category stats in a single bag scan")
assert_true(categoryListSource:find("function BETTERUI%.Inventory%.Class:RefreshCategoryList%(%)") ~= nil,
    "CategoryListManager exposes RefreshCategoryList")

local craftBagListSource = read_file("Modules/Inventory/Lists/CraftBagListManager.lua")
assert_true(craftBagListSource:find("function BETTERUI%.Inventory%.Class:InitializeCraftBagList%(%)") ~= nil,
    "CraftBagListManager exposes InitializeCraftBagList")
assert_true(craftBagListSource:find("function BETTERUI%.Inventory%.Class:RefreshCraftBagList%(%)") ~= nil,
    "CraftBagListManager exposes RefreshCraftBagList")
assert_true(craftBagListSource:find("function BETTERUI%.Inventory%.Class:GetCraftBagCategoryItemCount%(filterType%)") ~= nil,
    "CraftBagListManager exposes GetCraftBagCategoryItemCount")
assert_true(craftBagListSource:find("function BETTERUI%.Inventory%.Class:GetCraftBagCategoryItemCounts%(%)") ~= nil,
    "CraftBagListManager exposes the single-pass GetCraftBagCategoryItemCounts")

local craftListSource = read_file("Modules/Inventory/Lists/CraftList.lua")
assert_true(craftListSource:find("BETTERUI%.Inventory%.CraftList = BETTERUI%.Inventory%.List:Subclass%(%)") ~= nil,
    "CraftList subclasses the shared inventory list class")
assert_true(craftListSource:find("function BETTERUI%.Inventory%.GetFilterComparator%(filterType%)") ~= nil,
    "CraftList exposes the craft bag filter comparator under the Inventory namespace")
assert_true(craftListSource:find("BETTERUI%.Inventory%.CraftListDefaultSortComparator = BETTERUI_CraftList_DefaultItemSortComparator") ~= nil,
    "CraftList exports the default sort comparator under the Inventory namespace")
assert_true(craftListSource:find("function BETTERUI%.Inventory%.CraftList:RefreshList%(%.%.%.%)") ~= nil,
    "CraftList exposes RefreshList (varargs preserve filter/search on argless refreshes)")
assert_true(craftListSource:find("self%.lastFilterType") ~= nil,
    "CraftList remembers the last explicit filter for argless refreshes")
assert_true(craftListSource:find("self%.isDirty = true") ~= nil,
    "CraftList defers hidden refreshes via the base-class dirty contract")
assert_true(craftListSource:find('Tasks:Cancel%("craftBatchProcess"%)') ~= nil,
    "CraftList cancels stale deferred craft-bag batches before rebuilding")
assert_true(craftListSource:find("function BETTERUI%.Inventory%.CraftList:ProcessBatch%(%)") ~= nil,
    "CraftList exposes ProcessBatch")

local itemListFilteringSource = read_file("Modules/Inventory/Lists/ItemListFiltering.lua")
assert_true(itemListFilteringSource:find("function BETTERUI%.Inventory%.Class:GetItemDataFilterComparator%(filteredEquipSlot, nonEquipableFilterType%)") ~= nil,
    "ItemListFiltering exposes GetItemDataFilterComparator")
assert_true(itemListFilteringSource:find("function BETTERUI%.Inventory%.Class:RefreshItemList%(%)") ~= nil,
    "ItemListFiltering exposes RefreshItemList")
assert_true(itemListFilteringSource:find("SafeGetTargetData%(self%.categoryList%)") ~= nil,
    "ItemListFiltering resolves category targets through the safe target-data helper")
assert_true(itemListFilteringSource:find("PrepareQuestItemListEntry") ~= nil,
    "ItemListFiltering prepares quest-cache rows before normal item processing")
assert_true(itemListFilteringSource:find("SafeDoesNewItemMatchFilterType") ~= nil
    and itemListFilteringSource:find("inventory filter match failed", 1, true) ~= nil,
    "ItemListFiltering guards native filter calls and logs filter failures")
assert_true(itemListFilteringSource:find("function BETTERUI%.Inventory%.Class:UpdateItemLeftTooltip%(selectedData%)") ~= nil,
    "ItemListFiltering exposes UpdateItemLeftTooltip")

local itemListManagerSource = read_file("Modules/Inventory/Lists/ItemListManager.lua")
assert_true(itemListManagerSource:find("function BETTERUI%.Inventory%.Class:InitializeItemList%(%)") ~= nil,
    "ItemListManager exposes InitializeItemList")
assert_true(itemListManagerSource:find("function BETTERUI%.Inventory%.Class:IsItemListEmpty%(filteredEquipSlot, nonEquipableFilterType%)") ~= nil,
    "ItemListManager exposes IsItemListEmpty")
assert_true(itemListManagerSource:find("function BETTERUI%.Inventory%.Class:GetCategoryItemCount%(nonEquipableFilterType%)") ~= nil,
    "ItemListManager exposes GetCategoryItemCount")
assert_true(itemListManagerSource:find("function BETTERUI%.Inventory%.Class:PopulateInventoryCategoryFields%(itemData%)") ~= nil,
    "ItemListManager exposes PopulateInventoryCategoryFields")

local loaderSource = read_file("Modules/Inventory/Loader.lua")
assert_true(loaderSource:find("Deferred class installers") == nil,
    "Inventory loader no longer declares deferred installer seams")

local manifestSource = read_file("BetterUI.txt")
local loaderIndex = manifestSource:find("Modules\\Inventory\\Loader.lua", 1, true)
local classIndex = manifestSource:find("Modules\\Inventory\\Core\\InventoryClass.lua", 1, true)
local positionIndex = manifestSource:find("Modules\\Inventory\\State\\PositionManager.lua", 1, true)
local listStateIndex = manifestSource:find("Modules\\Inventory\\State\\ListStateManager.lua", 1, true)
assert_true(loaderIndex ~= nil and classIndex ~= nil and positionIndex ~= nil and listStateIndex ~= nil
        and loaderIndex < classIndex and classIndex < positionIndex and positionIndex < listStateIndex,
    "Inventory manifest loads InventoryClass before state helpers attach methods")
assert_true(manifestSource:find("Modules\\Inventory\\Core\\MixinLoader.lua", 1, true) == nil,
    "Inventory manifest no longer uses MixinLoader")

local moduleSource = read_file("Modules/Inventory/Module.lua")
assert_true(moduleSource:find("Inventory%.ROOT_CONTRACT = %{%s*") ~= nil,
    "Inventory module defines the root contract")
assert_true(moduleSource:find("function Inventory%.InitModule%(m_options%)") ~= nil,
    "Inventory module exposes InitModule")
assert_true(moduleSource:find("function Inventory%.Setup%(%)") ~= nil,
    "Inventory module exposes Setup")

local sceneSource = read_file("Modules/Inventory/Scene/InventorySceneLifecycle.lua")
assert_true(sceneSource:find("function BETTERUI%.Inventory%.Class:OnStateChanged%(oldState, newState%)") ~= nil,
    "InventorySceneLifecycle exposes OnStateChanged")
assert_true(sceneSource:find("function BETTERUI%.Inventory%.RegisterSceneLifecycle%(screen%)") ~= nil,
    "InventorySceneLifecycle exposes an explicit lifecycle registration seam")
assert_true(sceneSource:find("CreateStateChangeHandler") ~= nil,
    "InventorySceneLifecycle uses the shared SceneLifecycle adapter path")
assert_true(sceneSource:find("BETTERUI%.Inventory%.RegisterSceneLifecycle%(self%)") ~= nil,
    "InventorySceneLifecycle routes native scene callbacks through the explicit registration seam")
assert_true(sceneSource:find("HandleInventoryStateChange%(self, oldState, newState%)") == nil,
    "InventorySceneLifecycle no longer falls back to a second local state-change orchestration path")

local currencySource = read_file("Modules/Inventory/Settings/CurrencySettings.lua")
assert_true(currencySource:find("local CURRENCY_DATA = %{%s*") ~= nil,
    "CurrencySettings defines the shared currency metadata table")
assert_true(currencySource:find("function BETTERUI%.ApplyCurrencyPreset%(presetName%)") ~= nil,
    "CurrencySettings exposes ApplyCurrencyPreset")
assert_true(currencySource:find("function BETTERUI%.Inventory%.Settings%.GetCurrencyOptions%(%)") ~= nil,
    "CurrencySettings exposes GetCurrencyOptions")

if failed > 0 then
    error(string.format("test_inventory_list_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_inventory_list_support_source.lua: %d passed", passed))
