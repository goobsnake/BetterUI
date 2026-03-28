--[[
File: tools/tests/test_position_manager.lua
Purpose: Unit tests for CIM PositionManager position persistence.
         Validates save/restore, category key generation, and clear operations.

Usage:
  lua tools/tests/test_position_manager.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }

function zo_clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Data/PositionManager.lua")

local PM = BETTERUI.CIM.PositionManager

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

local function assert_nil(value, message)
    assert_equal(nil, value, message)
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== PositionManager Tests ===\n")

-- GetCategoryKey
print("-- GetCategoryKey --")
do
    assert_nil(PM.GetCategoryKey(nil), "GetCategoryKey: nil input returns nil")
    assert_equal("f:5", PM.GetCategoryKey({ filterType = 5 }), "GetCategoryKey: filterType priority")
    assert_equal("dir:1", PM.GetCategoryKey({ onClickDirection = 1 }), "GetCategoryKey: clickDirection priority")
    assert_equal("k:weapons", PM.GetCategoryKey({ key = "weapons" }), "GetCategoryKey: key priority")
    assert_equal("t:Armor", PM.GetCategoryKey({ text = "Armor" }), "GetCategoryKey: text priority")
    assert_equal("idx:3", PM.GetCategoryKey({ index = 3 }), "GetCategoryKey: index fallback")
    assert_equal("idx:", PM.GetCategoryKey({}), "GetCategoryKey: empty table uses idx fallback")

    -- filterType takes priority over other fields
    assert_equal("f:2", PM.GetCategoryKey({ filterType = 2, key = "armor", text = "Armor" }),
        "GetCategoryKey: filterType beats key and text")
end

-- SavePosition and GetSavedPosition
print("\n-- SavePosition / GetSavedPosition --")
do
    -- Save a position
    local mockList = { selectedIndex = 5, selectedData = { uniqueId = "abc123" } }
    PM.SavePosition("Inventory", "f:1", mockList)

    local saved = PM.GetSavedPosition("Inventory", "f:1")
    assert_equal(5, saved.index, "SavePosition: saves index")
    assert_equal("abc123", saved.uniqueId, "SavePosition: saves uniqueId")
end

-- SavePosition with nil inputs
print("\n-- SavePosition nil guards --")
do
    PM.SavePosition(nil, "key", {})
    PM.SavePosition("mod", nil, {})
    PM.SavePosition("mod", "key", nil)
    -- These should all be no-ops, no errors
    tests_passed = tests_passed + 1
    print("  [OK] SavePosition: handles nil inputs without error")
end

-- GetSavedPosition with no data
print("\n-- GetSavedPosition miss --")
do
    assert_nil(PM.GetSavedPosition("NonExistent", "key"), "GetSavedPosition: unknown module returns nil")
    assert_nil(PM.GetSavedPosition(nil, "key"), "GetSavedPosition: nil module returns nil")
    assert_nil(PM.GetSavedPosition("Inventory", nil), "GetSavedPosition: nil key returns nil")
end

-- RestorePosition with uniqueId match
print("\n-- RestorePosition uniqueId --")
do
    local mockList = { selectedIndex = 3, selectedData = { uniqueId = "item42" } }
    PM.SavePosition("TestMod", "f:1", mockList)

    local dataList = {
        { uniqueId = "item10" },
        { uniqueId = "item42" },
        { uniqueId = "item99" },
    }
    local result = PM.RestorePosition("TestMod", "f:1", nil, dataList)
    assert_equal(2, result, "RestorePosition: finds by uniqueId")
end

-- RestorePosition fallback to index
print("\n-- RestorePosition index fallback --")
do
    local mockList = { selectedIndex = 2, selectedData = {} }
    PM.SavePosition("TestMod2", "f:2", mockList)

    local dataList = { { uniqueId = "x" }, { uniqueId = "y" }, { uniqueId = "z" } }
    local result = PM.RestorePosition("TestMod2", "f:2", nil, dataList)
    assert_equal(2, result, "RestorePosition: falls back to saved index")
end

-- RestorePosition clamping
print("\n-- RestorePosition clamping --")
do
    local mockList = { selectedIndex = 100, selectedData = { uniqueId = "gone" } }
    PM.SavePosition("TestMod3", "f:3", mockList)

    local dataList = { { uniqueId = "a" }, { uniqueId = "b" } }
    local result = PM.RestorePosition("TestMod3", "f:3", nil, dataList)
    assert_equal(2, result, "RestorePosition: clamps to list length")
end

-- RestorePosition with empty list
print("\n-- RestorePosition empty --")
do
    local result = PM.RestorePosition("TestMod3", "f:3", nil, {})
    assert_equal(1, result, "RestorePosition: returns 1 for empty dataList")
end

-- RestorePosition with no saved data
print("\n-- RestorePosition no save --")
do
    local dataList = { { uniqueId = "a" } }
    local result = PM.RestorePosition("Unknown", "f:99", nil, dataList)
    assert_equal(1, result, "RestorePosition: returns 1 when no saved data")
end

-- ClearModule
print("\n-- ClearModule --")
do
    local mockList = { selectedIndex = 1, selectedData = {} }
    PM.SavePosition("ClearTest", "f:1", mockList)
    PM.ClearModule("ClearTest")
    assert_nil(PM.GetSavedPosition("ClearTest", "f:1"), "ClearModule: removes all saved positions")
end

-- ClearCategory
print("\n-- ClearCategory --")
do
    local mockList1 = { selectedIndex = 1, selectedData = {} }
    local mockList2 = { selectedIndex = 2, selectedData = {} }
    PM.SavePosition("CatClear", "f:1", mockList1)
    PM.SavePosition("CatClear", "f:2", mockList2)

    PM.ClearCategory("CatClear", "f:1")
    assert_nil(PM.GetSavedPosition("CatClear", "f:1"), "ClearCategory: removes specific category")
    assert_equal(2, PM.GetSavedPosition("CatClear", "f:2").index, "ClearCategory: preserves other categories")
end

-- SavePosition with wrapped list (list.list)
print("\n-- SavePosition wrapped list --")
do
    local innerList = { selectedIndex = 7, selectedData = { uniqueId = "wrapped" } }
    local outerList = { list = innerList }
    PM.SavePosition("WrapTest", "f:1", outerList)

    local saved = PM.GetSavedPosition("WrapTest", "f:1")
    assert_equal(7, saved.index, "SavePosition wrapped: saves inner list index")
    assert_equal("wrapped", saved.uniqueId, "SavePosition wrapped: saves inner list uniqueId")
end

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\n=== Results: %d passed, %d failed ===\n", tests_passed, tests_failed))

if tests_failed > 0 then
    os.exit(1)
end
