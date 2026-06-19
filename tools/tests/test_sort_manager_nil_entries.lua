--[[
File: tools/tests/test_sort_manager_nil_entries.lua
Purpose: Regression test for SortManager nil-entry decoration.

Usage:
  lua tools/tests/test_sort_manager_nil_entries.lua
]]

local passed = 0
local failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

BETTERUI = {
    CIM = {},
}

function GetItemQuality()
    return 0
end

function GetItemInfo()
    return nil, 0
end

function GetItemRequiredLevel()
    return 0
end

dofile("Modules/CIM/Core/Data/SortManager.lua")

local SortManager = BETTERUI.CIM.SortManager

print("\n=== SortManager Nil Entry Tests ===\n")

do
    local items = {
        { name = "Bravo" },
        { name = "Charlie" },
        nil,
        { name = "Alpha" },
    }

    local ok, err = pcall(function()
        SortManager.SortItems(items, SortManager.SORT_TYPES.NAME, SortManager.SORT_ORDER.ASCENDING)
    end)

    assert_true(ok, "SortItems tolerates nil entries inside the array sort range")
    assert_equal(nil, err, "SortItems nil-entry regression has no error detail")
end

print("\n=== Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))

if failed > 0 then
    os.exit(1)
end
