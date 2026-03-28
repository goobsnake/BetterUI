--[[
File: tools/tests/test_sort_manager.lua
Purpose: Unit tests for CIM SortManager sorting system.
         Validates comparator creation, in-place sorting, sort type registry,
         and settings integration.

Usage:
  lua tools/tests/test_sort_manager.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = { CONST = {} }, Settings = {} }

ZO_Object = {
    Subclass = function(self)
        local o = {}
        setmetatable(o, { __index = self })
        return o
    end
}

function GetItemQuality(bagId, slotIndex) return 0 end
function GetItemInfo(bagId, slotIndex) return nil, 0 end
function GetItemRequiredLevel(bagId, slotIndex) return 0 end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Data/SortManager.lua")

local SM = BETTERUI.CIM.SortManager
local ST = SM.SORT_TYPES
local SO = SM.SORT_ORDER

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

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

local function assert_false(value, message)
    assert_equal(false, value, message)
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== SortManager Tests ===\n")

-- Sort type constants
print("-- Sort type constants --")
do
    assert_equal(1, ST.CATEGORY, "SORT_TYPES.CATEGORY = 1")
    assert_equal(2, ST.NAME, "SORT_TYPES.NAME = 2")
    assert_equal(3, ST.QUALITY, "SORT_TYPES.QUALITY = 3")
    assert_equal(4, ST.STACK_COUNT, "SORT_TYPES.STACK_COUNT = 4")
    assert_equal(5, ST.VALUE, "SORT_TYPES.VALUE = 5")
    assert_equal(6, ST.LEVEL, "SORT_TYPES.LEVEL = 6")
end

-- Name sort ascending
print("\n-- Name sort ascending --")
do
    local items = {
        { name = "Sword" },
        { name = "Axe" },
        { name = "Mace" },
    }
    SM.SortItems(items, ST.NAME, SO.ASCENDING)
    assert_equal("Axe", items[1].name, "Name ascending: Axe first")
    assert_equal("Mace", items[2].name, "Name ascending: Mace second")
    assert_equal("Sword", items[3].name, "Name ascending: Sword third")
end

-- Name sort descending
print("\n-- Name sort descending --")
do
    local items = {
        { name = "Axe" },
        { name = "Sword" },
        { name = "Mace" },
    }
    SM.SortItems(items, ST.NAME, SO.DESCENDING)
    assert_equal("Sword", items[1].name, "Name descending: Sword first")
    assert_equal("Mace", items[2].name, "Name descending: Mace second")
    assert_equal("Axe", items[3].name, "Name descending: Axe third")
end

-- Quality sort
print("\n-- Quality sort --")
do
    local items = {
        { name = "Common", quality = 1 },
        { name = "Legendary", quality = 5 },
        { name = "Rare", quality = 3 },
    }
    SM.SortItems(items, ST.QUALITY, SO.DESCENDING)
    assert_equal("Legendary", items[1].name, "Quality desc: Legendary first")
    assert_equal("Rare", items[2].name, "Quality desc: Rare second")
    assert_equal("Common", items[3].name, "Quality desc: Common third")
end

-- Stack count sort
print("\n-- Stack count sort --")
do
    local items = {
        { name = "A", stackCount = 10 },
        { name = "B", stackCount = 200 },
        { name = "C", stackCount = 1 },
    }
    SM.SortItems(items, ST.STACK_COUNT, SO.DESCENDING)
    assert_equal("B", items[1].name, "Stack desc: largest first")
    assert_equal("A", items[2].name, "Stack desc: medium second")
    assert_equal("C", items[3].name, "Stack desc: smallest third")
end

-- Value sort
print("\n-- Value sort --")
do
    local items = {
        { name = "Cheap", sellPrice = 10 },
        { name = "Expensive", sellPrice = 5000 },
        { name = "Mid", sellPrice = 500 },
    }
    SM.SortItems(items, ST.VALUE, SO.DESCENDING)
    assert_equal("Expensive", items[1].name, "Value desc: expensive first")
    assert_equal("Mid", items[2].name, "Value desc: mid second")
    assert_equal("Cheap", items[3].name, "Value desc: cheap third")
end

-- Level sort
print("\n-- Level sort --")
do
    local items = {
        { name = "Low", requiredLevel = 5 },
        { name = "High", requiredLevel = 50 },
        { name = "Mid", requiredLevel = 25 },
    }
    SM.SortItems(items, ST.LEVEL, SO.ASCENDING)
    assert_equal("Low", items[1].name, "Level asc: lowest first")
    assert_equal("Mid", items[2].name, "Level asc: mid second")
    assert_equal("High", items[3].name, "Level asc: highest third")
end

-- Category sort
print("\n-- Category sort --")
do
    local items = {
        { name = "Item1", bestItemCategoryName = "Weapons" },
        { name = "Item2", bestItemCategoryName = "Armor" },
        { name = "Item3", bestItemCategoryName = "Consumable" },
    }
    SM.SortItems(items, ST.CATEGORY, SO.ASCENDING)
    assert_equal("Item2", items[1].name, "Category asc: Armor first")
    assert_equal("Item3", items[2].name, "Category asc: Consumable second")
    assert_equal("Item1", items[3].name, "Category asc: Weapons third")
end

-- Secondary sort by name for equal values
print("\n-- Secondary sort by name --")
do
    local items = {
        { name = "Zephyr", quality = 3 },
        { name = "Alpha", quality = 3 },
        { name = "Mace", quality = 3 },
    }
    SM.SortItems(items, ST.QUALITY, SO.ASCENDING)
    assert_equal("Alpha", items[1].name, "Secondary: Alpha first when quality equal")
    assert_equal("Mace", items[2].name, "Secondary: Mace second when quality equal")
    assert_equal("Zephyr", items[3].name, "Secondary: Zephyr third when quality equal")
end

-- Nil handling in comparators
print("\n-- Nil handling --")
do
    local comp = SM.CreateComparator(ST.NAME, SO.ASCENDING)
    assert_false(comp(nil, nil), "Nil: both nil returns false")
    assert_false(comp(nil, { name = "A" }), "Nil: nil < item returns false")
    assert_true(comp({ name = "A" }, nil), "Nil: item > nil returns true")
end

-- Empty/nil list handling
print("\n-- Empty list --")
do
    SM.SortItems(nil, ST.NAME)
    SM.SortItems({}, ST.NAME)
    tests_passed = tests_passed + 1
    print("  [OK] SortItems: handles nil and empty without error")
end

-- GetSortTypeName
print("\n-- GetSortTypeName --")
do
    assert_equal("Category", SM.GetSortTypeName(1), "GetSortTypeName: Category")
    assert_equal("Name", SM.GetSortTypeName(2), "GetSortTypeName: Name")
    assert_equal("Unknown", SM.GetSortTypeName(99), "GetSortTypeName: unknown returns Unknown")
end

-- GetAllSortTypes
print("\n-- GetAllSortTypes --")
do
    local types = SM.GetAllSortTypes()
    assert_equal(6, #types, "GetAllSortTypes: returns 6 types")
    assert_equal(1, types[1].id, "GetAllSortTypes: first is id=1")
    assert_equal("Category", types[1].name, "GetAllSortTypes: first is Category")
end

-- Settings integration
print("\n-- Settings integration --")
do
    assert_equal(ST.CATEGORY, SM.GetCurrentSortType("TestModule"), "GetCurrentSortType: default is CATEGORY")
    SM.SetSortType("TestModule", ST.NAME)
    assert_equal(ST.NAME, SM.GetCurrentSortType("TestModule"), "GetCurrentSortType: returns set value")

    assert_equal(SO.ASCENDING, SM.GetCurrentSortOrder("TestModule"), "GetCurrentSortOrder: default is ASCENDING")
    SM.SetSortOrder("TestModule", SO.DESCENDING)
    assert_equal(SO.DESCENDING, SM.GetCurrentSortOrder("TestModule"), "GetCurrentSortOrder: returns set value")
end

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\n=== Results: %d passed, %d failed ===\n", tests_passed, tests_failed))

if tests_failed > 0 then
    os.exit(1)
end
