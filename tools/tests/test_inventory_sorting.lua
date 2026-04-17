--[[
File: tools/tests/test_inventory_sorting.lua
Purpose: Unit tests for InventorySorting header-sort controller wiring and
         comparator behavior across trait, stat, and value columns.
]]

if false then
    dofile("Modules/Inventory/Core/InventorySorting.lua")
end

local controllerInstances = {}
local appliedMixinConfig = nil
local traitTypesBySlot = {}
local itemLinksBySlot = {}
local marketPricesByLink = {}

BETTERUI = {
    Inventory = {
        Class = {},
    },
    CIM = {
        Utils = {},
        UI = {},
        MarketIntegration = {},
    },
}

function BETTERUI.Debug() end

function BETTERUI.CIM.Utils.CompareNils(left, right, nilGoesLast)
    if left == nil and right == nil then
        return false
    end
    if left == nil then
        return not nilGoesLast
    end
    if right == nil then
        return nilGoesLast
    end
    return nil
end

BETTERUI.CIM.MarketIntegration.GetMarketPrice = function(itemLink)
    return marketPricesByLink[itemLink]
end

local HeaderSortController = {
    SORT_DIRECTION = {
        NONE = 0,
        ASCENDING = 1,
        DESCENDING = 2,
    },
}

function HeaderSortController:New(list, columns, onChanged)
    local controller = {
        list = list,
        columns = columns,
        onChanged = onChanged,
        labels = {},
        visualsUpdated = 0,
    }

    function controller:SetColumnLabel(index, label)
        self.labels[index] = label
    end

    function controller:UpdateVisuals()
        self.visualsUpdated = self.visualsUpdated + 1
    end

    controllerInstances[#controllerInstances + 1] = controller
    return controller
end

BETTERUI.CIM.UI.HeaderSortController = HeaderSortController
BETTERUI.CIM.UI.HeaderSortIntegration = {
    ApplyMixin = function(_, config)
        appliedMixinConfig = config
    end,
}

ZO_MovementController = {}

function ZO_MovementController:New(direction)
    return { direction = direction }
end

MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL = "horizontal"
ITEM_TRAIT_TYPE_NONE = 0

local traitNames = {
    [5] = "Sturdy",
    [7] = "Infused",
}

function GetString(prefix, value)
    if prefix == "SI_ITEMTRAITTYPE" then
        return traitNames[value]
    end
    return tostring(value)
end

function GetItemTrait(bagId, slotIndex)
    return traitTypesBySlot[string.format("%s:%s", tostring(bagId), tostring(slotIndex))] or 0
end

function GetItemLink(bagId, slotIndex)
    return itemLinksBySlot[string.format("%s:%s", tostring(bagId), tostring(slotIndex))]
end

BETTERUI_CraftList_DefaultItemSortComparator = function()
    return false
end

dofile("Modules/Inventory/Core/InventorySorting.lua")

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

local function makeInstance()
    local instance = setmetatable({
        itemList = {
            SetSortFunction = function(self, fn)
                self.sortFunction = fn
            end,
        },
        craftBagList = {
            SetSortFunction = function(self, fn)
                self.sortFunction = fn
            end,
        },
        mainKeybindStripDescriptor = { name = "main" },
        currentListType = "itemList",
        header = {
            GetNamedChild = function()
                return nil
            end,
        },
        itemRefreshes = 0,
        craftRefreshes = 0,
    }, { __index = BETTERUI.Inventory.Class })

    function instance:GetCurrentList()
        return self.currentListType == "craftBagList" and self.craftBagList or self.itemList
    end

    function instance:RefreshItemList()
        self.itemRefreshes = self.itemRefreshes + 1
    end

    function instance:RefreshCraftBagList()
        self.craftRefreshes = self.craftRefreshes + 1
    end

    return instance
end

print("\n=== InventorySorting Tests ===\n")

print("-- InitializeHeaderSortController wires list controllers and mixin hooks --")
do
    controllerInstances = {}
    appliedMixinConfig = nil

    local instance = makeInstance()
    instance:InitializeHeaderSortController()

    assert_equal(2, #controllerInstances, "InitializeHeaderSortController creates item and craft controllers")
    assert_equal(instance.itemList, controllerInstances[1].list, "Item controller receives item list")
    assert_equal(instance.craftBagList, controllerInstances[2].list, "Craft controller receives craft bag list")
    assert_equal("horizontal", instance.horizontalMovementController.direction, "Horizontal movement controller created")
    assert_equal(instance.mainKeybindStripDescriptor, appliedMixinConfig.keybindDescriptor,
        "Header sort mixin uses inventory keybind descriptor")
    assert_equal(controllerInstances[1], appliedMixinConfig.headerControllerFn(),
        "Header controller callback resolves the active item-list controller")
end

print("\n-- LinkColumnLabels falls back to ColumnBar children when direct labels are missing --")
do
    local instance = makeInstance()
    instance:InitializeHeaderSortController()

    local labels = {
        Column1Label = { name = "name" },
        Column2Label = { name = "type" },
        Column4Label = { name = "trait" },
        Column5Label = { name = "value" },
        Column6Label = { name = "stat" },
    }

    local columnBar = {
        GetNamedChild = function(_, childName)
            return labels[childName]
        end,
    }

    instance.header = {
        GetNamedChild = function(_, childName)
            if childName == "ColumnBar" then
                return columnBar
            end
            return nil
        end,
    }

    instance:LinkColumnLabels()

    assert_equal(labels.Column1Label, instance.headerSortControllers.itemList.labels[1],
        "First column label is linked from ColumnBar fallback")
    assert_equal(labels.Column5Label, instance.headerSortControllers.craftBagList.labels[5],
        "Value column label is linked for craft bag controller")
end

print("\n-- Trait sorting caches trait names and keeps blanks last --")
do
    local instance = makeInstance()
    instance:InitializeHeaderSortController()
    instance:OnHeaderSortChanged("itemList", "trait", HeaderSortController.SORT_DIRECTION.ASCENDING)
    local originalStringUpper = string.upper
    local upperCalls = 0

    local comparator = instance.currentSortComparators.itemList
    local left = {
        bagId = 1,
        slotIndex = 1,
        dataSource = {
            bagId = 1,
            slotIndex = 1,
        },
    }
    local right = {
        bagId = 1,
        slotIndex = 2,
        dataSource = {
            bagId = 1,
            slotIndex = 2,
        },
    }

    traitTypesBySlot["1:1"] = 5
    traitTypesBySlot["1:2"] = 0
    string.upper = function(value)
        upperCalls = upperCalls + 1
        return originalStringUpper(value)
    end

    assert_true(comparator(left, right), "Trait comparator orders named traits before blanks")
    assert_equal("STURDY", left.dataSource.cached_traitName, "Trait comparator caches the resolved trait name")
    local cachedUpperCalls = upperCalls
    assert_true(comparator(left, right), "Trait comparator continues to work with cached trait names")
    assert_equal(cachedUpperCalls, upperCalls, "Cached trait names are reused without re-uppercasing")
    string.upper = originalStringUpper
    assert_equal(1, instance.itemRefreshes, "Trait sort refreshes the item list")
end

print("\n-- Stat sorting prioritizes alphabetic labels before numeric values and blanks --")
do
    local instance = makeInstance()
    instance:InitializeHeaderSortController()
    instance:OnHeaderSortChanged("itemList", "stat", HeaderSortController.SORT_DIRECTION.ASCENDING)

    local comparator = instance.currentSortComparators.itemList
    assert_true(comparator({ statValue = "Armor" }, { statValue = 150 }),
        "Alphabetic stat values sort before numeric values")
    assert_true(comparator({ statValue = 150 }, { statValue = "-" }),
        "Numeric stat values sort before blanks")
end

print("\n-- Value sorting prefers market price, caches the result, and resets cleanly --")
do
    local instance = makeInstance()
    instance:InitializeHeaderSortController()
    instance:OnHeaderSortChanged("craftBagList", "value", HeaderSortController.SORT_DIRECTION.DESCENDING)

    local comparator = instance.currentSortComparators.craftBagList
    local left = {
        dataSource = {
            bagId = 2,
            slotIndex = 4,
            stackCount = 1,
        },
    }
    local right = {
        dataSource = {
            stackSellPrice = 200,
        },
    }

    itemLinksBySlot["2:4"] = "|H1:item:market|h"
    marketPricesByLink["|H1:item:market|h"] = 900

    assert_true(comparator(left, right), "Descending value sort prefers higher market prices")
    assert_equal(900, left.dataSource.cached_marketPrice, "Value comparator caches resolved market price")
    assert_equal(1, instance.craftRefreshes, "Value sort refreshes the craft bag list")

    instance:OnHeaderSortChanged("craftBagList", "value", HeaderSortController.SORT_DIRECTION.NONE)
    assert_equal(nil, instance.currentSortComparators.craftBagList, "Resetting sort clears the craft bag comparator")
    assert_equal(BETTERUI_CraftList_DefaultItemSortComparator, instance.craftBagList.sortFunction,
        "Resetting craft bag sort restores the default comparator")
    assert_equal(2, instance.craftRefreshes, "Resetting craft bag sort refreshes the list again")
end

print("\n=== Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    os.exit(1)
end
