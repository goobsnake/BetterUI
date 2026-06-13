--[[
File: tools/tests/test_inventory_quest_identity.lua
Purpose: Focused regressions for quest inventory rows and stale slot identity guards.
]]

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write(string.format("Assertion failed: %s (expected %s, got %s)\n",
            label, tostring(expected), tostring(actual)))
    end
end

BETTERUI = {
    CIM = { Utils = {} },
    Inventory = {
        Class = {},
        CONST = { BATCH_SIZE_INITIAL = 50 },
        DefaultSortComparator = function(left, right)
            return tostring(left.sortPriorityName or left.name or "") < tostring(right.sortPriorityName or right.name or "")
        end,
    },
}

BAG_BACKPACK = 1
ITEMFILTERTYPE_QUEST = 2
ITEMFILTERTYPE_ARMOR = 3
SLOT_TYPE_QUEST_ITEM = 4
ACTION_TYPE_QUEST_ITEM = 5
HOTBAR_CATEGORY_QUICKSLOT_WHEEL = 6
SI_BETTERUI_EMPTY_LIST = "SI_BETTERUI_EMPTY_LIST"
SI_BETTERUI_SEARCH_NO_RESULTS = "SI_BETTERUI_SEARCH_NO_RESULTS"
SI_GAMEPAD_INVENTORY_QUEST_ITEMS = "SI_GAMEPAD_INVENTORY_QUEST_ITEMS"

function GetString(id)
    return ({
        [SI_BETTERUI_EMPTY_LIST] = "Empty",
        [SI_BETTERUI_SEARCH_NO_RESULTS] = "No results",
        [SI_GAMEPAD_INVENTORY_QUEST_ITEMS] = "Quest",
    })[id] or tostring(id or "")
end

function zo_clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function ZO_ClearNumericallyIndexedTable(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

function ZO_InventorySlot_SetType(itemData, slotType)
    itemData.slotType = slotType
end

function ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, filterType)
    return itemData and itemData.filterType == filterType
end

function FindActionSlotMatchingSimpleAction(actionType, questItemId)
    return actionType == ACTION_TYPE_QUEST_ITEM and questItemId == 8401 and 3 or nil
end

local slotUniqueIds = {}
function GetItemUniqueId(bagId, slotIndex)
    return slotUniqueIds[tostring(bagId) .. ":" .. tostring(slotIndex)]
end

function GetItemLink(bagId, slotIndex)
    return string.format("item:%s:%s", tostring(bagId), tostring(slotIndex))
end

Id64ToString = function(value)
    if type(value) == "string" then
        error("Id64ToString should not receive synthetic quest string ids")
    end
    return "id:" .. tostring(value)
end

-- Slot-identity helpers live in BETTERUI.CIM.Utils (CIM loads before Inventory in
-- production, see BetterUI.txt); load it first so the Inventory.Utils delegations resolve.
dofile("Modules/CIM/Core/Utilities.lua")
dofile("Modules/Inventory/Core/Utils.lua")
dofile("Modules/Inventory/Lists/ItemListFiltering.lua")

function BETTERUI.Inventory.Class:IsBatchProcessing()
    return false
end

function BETTERUI.Inventory.Class:CaptureItemListRefreshTarget()
    return nil, nil
end

function BETTERUI.Inventory.Class:GetCachedSlotData()
    return self.cachedSlots or {}
end

function BETTERUI.Inventory.Class:PopulateInventoryCategoryFields(itemData)
    itemData.bestItemCategoryName = itemData.categoryName
    itemData.bestGamepadItemCategoryName = itemData.categoryName
    itemData.bestItemTypeName = itemData.categoryName
    itemData.sortPriorityName = itemData.categoryName .. itemData.name
end

function BETTERUI.Inventory.Class:ProcessScrollListBatch()
    self.processedBatchData = self.pendingBatchData or {}
    self.itemList:Commit()
end

local function makeInstance()
    return setmetatable({
        cachedSlots = {},
        itemList = {
            committed = false,
            SetNoItemText = function(self, value) self.noItemText = value end,
            Clear = function(self) self.cleared = true end,
            Commit = function(self) self.committed = true end,
        },
        categoryList = {
            selectedData = {},
            dataList = { {} },
            IsEmpty = function(self) return not self.dataList or #self.dataList == 0 end,
            SetSelectedIndexWithoutAnimation = function(self, index)
                self.selectedIndex = index
                self.targetSelectedIndex = index
                self.selectedData = self.dataList[index]
                self.targetData = self.selectedData
            end,
        },
    }, { __index = BETTERUI.Inventory.Class })
end

print("\n=== Inventory Quest Identity Tests ===\n")

local nilCategoryInstance = makeInstance()
nilCategoryInstance.cachedSlots = {
    { name = "Jerkin", bagId = BAG_BACKPACK, slotIndex = 6, filterType = ITEMFILTERTYPE_ARMOR, categoryName = "Armor" },
}
nilCategoryInstance.categoryList.selectedData = nil
nilCategoryInstance.categoryList.dataList = { { filterType = ITEMFILTERTYPE_ARMOR } }
nilCategoryInstance:RefreshItemList()
assert_eq(nilCategoryInstance.categoryList.selectedIndex, 1,
    "RefreshItemList restores category index one when selectedData is missing")
assert_eq(nilCategoryInstance.processedBatchData[1].name, "Jerkin",
    "Recovered category target applies the intended filter")

SHARED_INVENTORY = {
    GenerateFullQuestCache = function()
        return { { [8401] = { name = "Ancient Relic", iconFile = "quest.dds", questIndex = 4, toolIndex = 2, questItemId = 8401 } } }
    end,
}
local questInstance = makeInstance()
questInstance.categoryList.selectedData = { filterType = ITEMFILTERTYPE_QUEST }
questInstance.categoryList.dataList = { questInstance.categoryList.selectedData }
questInstance:RefreshItemList()
local questRow = questInstance.processedBatchData[1]
assert_eq(questRow.slotType, SLOT_TYPE_QUEST_ITEM, "Quest refresh assigns quest slot type")
assert_eq(questRow.bestItemTypeName, "Quest", "Quest refresh supplies safe category metadata")
assert_eq(questRow.uniqueId, "quest:4:2::", "Quest refresh derives a stable non-bag unique id")
assert_eq(questRow.isEquippedInCurrentCategory, true,
    "Quest refresh marks quickslotted quest items as equipped in the current category")

assert_eq(BETTERUI.Inventory.Utils.NormalizeIdentityValue("quest:4:2::"), "quest:4:2::",
    "Synthetic quest unique ids normalize without Id64 conversion")
slotUniqueIds["1:70"] = "old"
local identity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(BAG_BACKPACK, 70, { uniqueId = "old" })
assert_eq(BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(identity, BAG_BACKPACK, 70), true,
    "Captured slot identity initially matches the live slot")
slotUniqueIds["1:70"] = "new"
assert_eq(BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(identity, BAG_BACKPACK, 70), false,
    "Captured slot identity rejects a changed live slot")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
print("All tests passed!")
