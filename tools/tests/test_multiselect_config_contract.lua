--[[
File: tools/tests/test_multiselect_config_contract.lua
Purpose: Covers the shared multi-select config seam so missing callbacks do not
         crash lifecycle entry points and Apply always normalizes the contract.
Usage:
  lua tools/tests/test_multiselect_config_contract.lua
]]

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. label)
    end
end

local function assert_equal(actual, expected, label)
    assert_true(actual == expected, string.format("%s (expected=%s, actual=%s)", label, tostring(expected), tostring(actual)))
end

BETTERUI = {
    CIM = {
        BatchConfig = {
            IsBatchSceneShowing = function()
                return true
            end,
        },
        BatchOverlay = {},
        BatchActions = {},
    },
}

dofile("Modules/CIM/Core/Batching/MultiSelectMixin.lua")

local mixin = BETTERUI.CIM.MultiSelectMixin

do
    local target = {}
    mixin.Apply(target, {})

    assert_true(type(target._multiSelectConfig) == "table", "Apply stores a normalized config table")
    assert_true(type(target._multiSelectConfig.getList) == "function", "Apply injects a getList callback")
    assert_true(type(target._multiSelectConfig.refreshList) == "function", "Apply injects a refreshList callback")
    assert_true(type(target._multiSelectConfig.refreshKeybinds) == "function", "Apply injects a refreshKeybinds callback")
end

do
    local entered = 0
    local toggledRow = nil
    local refreshedLists = 0
    local refreshedKeybinds = 0
    local target = {
        list = {
            selectedData = {
                uniqueId = "row-1",
            },
        },
        multiSelectManager = {
            EnterSelectionMode = function()
                entered = entered + 1
            end,
            ToggleSelection = function(_, row)
                toggledRow = row
            end,
        },
    }

    mixin.Apply(target, {
        refreshList = function()
            refreshedLists = refreshedLists + 1
        end,
        refreshKeybinds = function()
            refreshedKeybinds = refreshedKeybinds + 1
        end,
    })

    mixin.EnterSelectionMode(target)

    assert_true(target.isInSelectionMode, "EnterSelectionMode flips selection mode on")
    assert_equal(entered, 1, "EnterSelectionMode delegates to the active manager")
    assert_equal(toggledRow and toggledRow.uniqueId, "row-1", "EnterSelectionMode falls back to target.list when getList is omitted")
    assert_equal(refreshedKeybinds, 1, "EnterSelectionMode refreshes keybinds through the normalized config")
    assert_equal(refreshedLists, 1, "EnterSelectionMode refreshes the list through the normalized config")
end

do
    local ok = pcall(function()
        mixin.EnterSelectionMode({
            multiSelectManager = {
                EnterSelectionMode = function()
                end,
            },
        })
    end)

    assert_true(ok, "EnterSelectionMode ignores missing config instead of throwing")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
