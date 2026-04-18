--[[
File: tools/tests/test_cim_shared_runtime.lua
Purpose: Headless runtime coverage for shared CIM support modules that were
         previously exercised mostly through source-shape assertions.

Usage:
  lua tools/tests/test_cim_shared_runtime.lua
]]

BETTERUI = {
    CIM = {},
    Inventory = {},
    Vendor = {},
}

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

local function assert_eq(actual, expected, label)
    assert_true(actual == expected,
        string.format("%s (expected %s, got %s)", label, tostring(expected), tostring(actual)))
end

local soundEvents = {}

SOUNDS = {
    GAMEPAD_MENU_FORWARD = "forward",
    GAMEPAD_MENU_BACK = "back",
    GAMEPAD_MENU_BACKWARD = "backward",
}

function PlaySound(soundId)
    soundEvents[#soundEvents + 1] = soundId
end

ZO_Object = {}

function ZO_Object:Subclass()
    local class = {}
    class.__index = class
    setmetatable(class, { __index = self })
    return class
end

function ZO_Object.New(class)
    return setmetatable({}, class)
end

function Id64ToString(value)
    return string.format("id64:%s", tostring(value))
end

function ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, filterType)
    return itemData and itemData.filterType == filterType
end

local dialogState = {}
local gamepadDialogHidden = true

function ZO_Dialogs_IsShowing(name)
    return dialogState[name] == true
end

function GetControl(name)
    if name ~= "ZO_DialogGamepad1" then
        return nil
    end
    return {
        IsHidden = function()
            return gamepadDialogHidden
        end,
    }
end

SI_BETTERUI_INV_ITEM_ALL = 1
SI_BETTERUI_INV_ITEM_WEAPONS = 2
SI_BETTERUI_INV_ITEM_APPAREL = 3
SI_BETTERUI_INV_ITEM_JEWELRY = 4
SI_BETTERUI_INV_ITEM_CONSUMABLE = 5
SI_BETTERUI_INV_ITEM_MATERIALS = 6
SI_BETTERUI_INV_ITEM_FURNISHING = 7
SI_BETTERUI_INV_ITEM_MISC = 8
SI_BETTERUI_INV_ITEM_JUNK = 9
SI_ITEMFILTERTYPE_COMPANION = 10
ITEMFILTERTYPE_WEAPONS = 11
ITEMFILTERTYPE_ARMOR = 12
ITEMFILTERTYPE_JEWELRY = 13
ITEMFILTERTYPE_CONSUMABLE = 14
ITEMFILTERTYPE_CRAFTING = 15
ITEMFILTERTYPE_FURNISHING = 16
ITEMFILTERTYPE_MISCELLANEOUS = 17

dofile("Modules/CIM/Core/Presentation/SharedItemSupport.lua")
dofile("Modules/CIM/Core/Data/ItemTaxonomy.lua")
dofile("Modules/CIM/Core/Batching/MultiSelectManager.lua")
dofile("Modules/CIM/UI/BatchOverlay.lua")

local SharedItemSupport = BETTERUI.CIM.SharedItemSupport
local ItemTaxonomy = BETTERUI.CIM.ItemTaxonomy
local MultiSelectManager = BETTERUI.CIM.MultiSelectManager
local BatchOverlay = BETTERUI.CIM.BatchOverlay

BETTERUI.Inventory.GetNameFontDescriptor = function()
    return "inventory-name-font"
end

BETTERUI.Vendor.GetColumnFontDescriptor = function()
    return "vendor-column-font"
end

SharedItemSupport.RegisterCategorySupport({
    doesItemMatchCategory = function(itemData, category)
        return itemData and category and itemData.categoryKey == category.key
    end,
    getBestItemCategoryDescription = function(itemData)
        return "shared:" .. tostring(itemData.name)
    end,
})

local tooltipCalls = {}
SharedItemSupport.RegisterTooltipSupport({
    applyTooltipStyles = function()
        tooltipCalls[#tooltipCalls + 1] = "apply"
        return "styled"
    end,
    cleanupEnhancedTooltip = function(tooltipType)
        tooltipCalls[#tooltipCalls + 1] = "cleanup:" .. tostring(tooltipType)
        return "cleaned"
    end,
    updateTooltipEquippedText = function(tooltipType, equipSlot)
        tooltipCalls[#tooltipCalls + 1] = string.format("equipped:%s:%s", tostring(tooltipType), tostring(equipSlot))
        return "updated"
    end,
    isItemComparisonEnabled = function()
        return true
    end,
    compareItem = function(itemLink)
        return "compare:" .. tostring(itemLink)
    end,
    showComparisonOnTooltip = function(container, result)
        return container .. ":" .. result
    end,
})

assert_true(SharedItemSupport.DoesItemMatchCategory({ categoryKey = "weapons" }, { key = "weapons" }),
    "SharedItemSupport uses registered category matcher")
assert_true(SharedItemSupport.DoesItemMatchCategory({ isJunk = true }, { key = "junk", special = "junk" }) == false,
    "registered category matcher overrides fallback behavior when present")
assert_eq(SharedItemSupport.GetBestItemCategoryDescription({ name = "Ruby Ash Bow" }), "shared:Ruby Ash Bow",
    "SharedItemSupport uses registered category describer")
assert_eq(SharedItemSupport.ResolveNameFontDescriptor("Inventory", "Vendor"), "inventory-name-font",
    "SharedItemSupport resolves name descriptors from the primary module")
assert_eq(SharedItemSupport.ResolveColumnFontDescriptor("Inventory", "Vendor"), "vendor-column-font",
    "SharedItemSupport falls back to secondary module column descriptors")
assert_eq(SharedItemSupport.ApplyTooltipStyles(), "styled",
    "SharedItemSupport delegates tooltip style application")
assert_eq(SharedItemSupport.CleanupEnhancedTooltip("item"), "cleaned",
    "SharedItemSupport delegates tooltip cleanup")
assert_eq(SharedItemSupport.UpdateTooltipEquippedText("item", 4), "updated",
    "SharedItemSupport delegates equipped text refresh")
assert_true(SharedItemSupport.IsItemComparisonEnabled(),
    "SharedItemSupport delegates item-comparison enablement")
assert_eq(SharedItemSupport.CompareItem("|H1:item:1|h"), "compare:|H1:item:1|h",
    "SharedItemSupport delegates comparison work")
assert_eq(SharedItemSupport.ShowComparisonOnTooltip("tooltip", "result"), "tooltip:result",
    "SharedItemSupport delegates comparison presentation")

local bankCategories = ItemTaxonomy.BANK_CATEGORY_DEFS
local vendorBuyCategories = ItemTaxonomy.VENDOR_BUY_CATEGORY_DEFS
local vendorSellCategories = ItemTaxonomy.VENDOR_SELL_CATEGORY_DEFS

assert_eq(bankCategories[1].key, "all", "ItemTaxonomy preserves the shared all-category first")
assert_true(bankCategories[#bankCategories - 1].optional == true and bankCategories[#bankCategories - 1].key == "companion",
    "ItemTaxonomy appends the optional companion bank category")
assert_true(bankCategories[#bankCategories].special == "junk" and bankCategories[#bankCategories].key == "junk",
    "ItemTaxonomy appends the bank junk category")
local vendorBuyHasJunk = false
for _, category in ipairs(vendorBuyCategories) do
    if category.key == "junk" or category.special == "junk" then
        vendorBuyHasJunk = true
        break
    end
end
assert_true(vendorBuyHasJunk == false,
    "ItemTaxonomy keeps vendor buy categories free of junk-only extras")
assert_true(vendorSellCategories[#vendorSellCategories].special == "junk",
    "ItemTaxonomy appends the vendor junk category")

local callbackCounts = {}
local listEntries = {
    { dataSource = { uniqueId = 101, bagId = 4, slotIndex = 7, name = "Ruby Ash Bow" } },
    { dataSource = { entryIndex = 9, name = "Buyback Entry" } },
}

local list = {
    GetNumItems = function()
        return #listEntries
    end,
    GetDataForDataIndex = function(_, index)
        return listEntries[index]
    end,
}

local manager = MultiSelectManager.Create(list, function(count)
    callbackCounts[#callbackCounts + 1] = count
end)

assert_true(manager:EnterSelectionMode(), "MultiSelectManager enters selection mode")
assert_eq(MultiSelectManager.GetActiveInstance(), manager,
    "MultiSelectManager exposes the active manager instance")
assert_true(manager:ToggleSelection(listEntries[1]),
    "MultiSelectManager selects wrapped data entries")
assert_true(manager:IsSelected({ uniqueId = 101 }),
    "MultiSelectManager resolves selected aliases through unique ids")
assert_eq(manager:GetSelectedCount(), 1,
    "MultiSelectManager tracks selected item count")

listEntries = {
    { dataSource = { uniqueId = 101, bagId = 9, slotIndex = 3, name = "Ruby Ash Bow+" } },
    { dataSource = { entryIndex = 9, name = "Buyback Entry" } },
}

manager:RefreshSelections()

local selectedAfterRefresh = manager:GetSelectedItems()[1]
assert_eq(selectedAfterRefresh.dataSource.name, "Ruby Ash Bow+",
    "MultiSelectManager refreshes selected entries against the current list data")

manager:SelectAll()
assert_eq(manager:GetSelectedCount(), 2,
    "MultiSelectManager selects every visible item")
assert_eq(manager:BatchOperation(function()
    return true
end), 2, "MultiSelectManager runs batch work across selected items")
assert_true(manager:ExitSelectionMode(), "MultiSelectManager exits selection mode")
assert_eq(MultiSelectManager.GetActiveInstance(), nil,
    "MultiSelectManager clears the active instance on exit")

assert_true(BatchOverlay.IsAnyBatchActionDialogShowing() == false,
    "BatchOverlay reports no dialog when all dialogs are hidden")
dialogState.BETTERUI_VENDOR_BATCH_DIALOG = true
assert_true(BatchOverlay.IsAnyBatchActionDialogShowing(),
    "BatchOverlay reports vendor batch dialogs by name")
dialogState.BETTERUI_VENDOR_BATCH_DIALOG = false
gamepadDialogHidden = false
assert_true(BatchOverlay.IsAnyBatchActionDialogShowing(),
    "BatchOverlay blocks overlay startup while a gamepad dialog is still visible")
gamepadDialogHidden = true

local request = BatchOverlay.CreateDisplayRequest("Sell Junk", "Processing", "2 items left")
assert_eq(request.displayName, "Sell Junk", "BatchOverlay builds display requests from positional arguments")
assert_eq(request.bodyText, "Processing", "BatchOverlay preserves body text")
assert_eq(request.secondaryText, "2 items left", "BatchOverlay preserves secondary text")

local copiedRequest = BatchOverlay.CreateDisplayRequest({
    displayName = "Copy",
    bodyText = "Copied body",
    secondaryText = "Copied secondary",
})
assert_eq(copiedRequest.displayName, "Copy", "BatchOverlay copies table request display names")
assert_eq(copiedRequest.bodyText, "Copied body", "BatchOverlay copies table request body text")
assert_eq(copiedRequest.secondaryText, "Copied secondary", "BatchOverlay copies table request secondary text")

assert_true(#tooltipCalls >= 3, "SharedItemSupport exercised tooltip delegate paths")
assert_true(#soundEvents >= 3, "MultiSelectManager exercised selection-mode sound paths")
assert_true(#callbackCounts >= 3, "MultiSelectManager invoked selection callbacks during lifecycle changes")

print(string.format("\nResults: %d passed, %d failed", passed, failed))

if failed > 0 then
    os.exit(1)
end

print("All tests passed!")
