--[[
File: tools/tests/test_companion_list_selection_restore.lua
Purpose: Verify Companion list rebuilds suppress transient selection callbacks
         and restore the saved row without animation.
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local selectionEvents = {}
local savedCategory
local tooltipUpdateCount = 0
local lastTooltipSelection = "unset"

BETTERUI = {
    Companions = {
        Class = {},
        GetBoundary = function()
            return {
                ExecuteBoundary = function(_, callback)
                    callback()
                    return true
                end,
            }
        end,
    },
    CIM = {
        UI = {
            HeaderSortController = {
                SORT_DIRECTION = { NONE = 0, ASCENDING = 1, DESCENDING = 2 },
            },
        },
        PositionManager = {
            SavePosition = function(_, categoryKey)
                savedCategory = categoryKey
            end,
            RestorePosition = function()
                return 3
            end,
        },
    },
}

ZO_SORT_ORDER_UP = 1
ZO_SORT_ORDER_DOWN = 2

dofile("Modules/Companions/Core/CompanionItemList.lua")

local list = {
    dataList = {
        { dataSource = { name = "Old", uniqueId = "old" } },
    },
    selectedIndex = 1,
}

function list:Clear()
    self.dataList = {}
end

function list:Commit(dontReselect, blockSelectionChangedCallback)
    self.commitDontReselect = dontReselect
    self.commitBlocksSelectionCallback = blockSelectionChangedCallback
    self.selectedIndex = 1
    if not blockSelectionChangedCallback then
        selectionEvents[#selectionEvents + 1] = "commit-default"
    end
end

function list:SetSelectedIndexWithoutAnimation(index)
    self.selectedIndex = index
    selectionEvents[#selectionEvents + 1] = "restore-" .. tostring(index)
end

local screen = setmetatable({ list = list }, { __index = BETTERUI.Companions.Class })

local valueSortList = {
    dataList = {
        { dataSource = { name = "Girdle", sellPrice = 3 } },
        { dataSource = { name = "Gauntlets", sellPrice = 3 } },
    },
}
local valueSortScreen = setmetatable({
    list = valueSortList,
    sortController = {
        GetActiveSortColumn = function()
            return { key = "value" }, 1
        end,
    },
}, { __index = BETTERUI.Companions.Class })

local valueSortOk = pcall(function() valueSortScreen:ApplySortToList() end)
assert_eq(valueSortOk, true, "equal-value rows use the name tie-breaker without error")
assert_eq(valueSortList.dataList[1].dataSource.name, "Gauntlets",
    "equal-value rows sort deterministically by name")

function screen:GetCurrentCategory()
    return { key = "weapons", filterType = 1 }
end

function screen:BuildEquippedItems()
    self.list.dataList[#self.list.dataList + 1] = { dataSource = { name = "One", uniqueId = "one" } }
end

function screen:BuildBackpackItems()
    self.list.dataList[#self.list.dataList + 1] = { dataSource = { name = "Two", uniqueId = "two" } }
    self.list.dataList[#self.list.dataList + 1] = { dataSource = { name = "Three", uniqueId = "three" } }
end

function screen:ApplySortToList() end
function screen:EnsureColumnHeadersVisible() end
function screen:UpdateScrollIndicator() end
function screen:UpdateItemTooltips(selectedData)
    tooltipUpdateCount = tooltipUpdateCount + 1
    lastTooltipSelection = selectedData
end


local ok = screen:RefreshList({ preserveCurrentPosition = true })

assert_eq(ok, true, "refresh succeeds")
assert_eq(savedCategory, "weapons", "refresh saves the active category")
assert_eq(list.commitDontReselect, true, "commit resets only under explicit restore control")
assert_eq(list.commitBlocksSelectionCallback, true, "commit suppresses the transient default-row callback")
assert_eq(#selectionEvents, 1, "only the explicit restored selection is observed")
assert_eq(selectionEvents[1], "restore-3", "saved row is restored after commit")
assert_eq(list.selectedIndex, 3, "final selection remains on the restored row")

screen.BuildEquippedItems = function() end
screen.BuildBackpackItems = function() end
local selectionEventCountBeforeEmptyRefresh = #selectionEvents
local emptyOk = screen:RefreshList({ preserveCurrentPosition = true })

assert_eq(emptyOk, true, "empty search refresh succeeds")
assert_eq(#list.dataList, 0, "empty search keeps the list empty")
assert_eq(#selectionEvents, selectionEventCountBeforeEmptyRefresh,
    "empty search does not restore a nonexistent row")
assert_eq(tooltipUpdateCount, 1, "empty search explicitly clears the stale tooltip")
assert_eq(lastTooltipSelection, nil, "empty search clears tooltip selection data")

print(string.format("test_companion_list_selection_restore.lua: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
