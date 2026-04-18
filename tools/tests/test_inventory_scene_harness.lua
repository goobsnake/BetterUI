--[[
File: tools/tests/test_inventory_scene_harness.lua
Purpose: Headless regression harness for the production inventory scene
         filtering, tooltip, and batch-action code paths.

Usage:
  lua tools/tests/test_inventory_scene_harness.lua
]]

if false then
    dofile("Modules/Inventory/Lists/ItemListFiltering.lua")
    dofile("Modules/Inventory/Core/InventoryBatchOps.lua")
end

local testsPassed = 0
local testsFailed = 0

local secureCalls = {}
local dialogCalls = {}
local tooltipCalls = {}
local currentDialogData = nil

local function assertEqual(expected, actual, message)
    if expected == actual then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assertTrue(value, message)
    assertEqual(true, value, message)
end

local function assertBatchStatus(expectedStatus, result, message)
    local actualStatus = type(result) == "table" and result.status or nil
    assertEqual(expectedStatus, actualStatus, message)
end

local function resetRecords()
    secureCalls = {}
    dialogCalls = {}
    tooltipCalls = {}
    currentDialogData = nil
end

local function recordTooltip(kind, ...)
    tooltipCalls[#tooltipCalls + 1] = {
        kind = kind,
        args = { ... },
    }
end

BETTERUI = {
    Debug = function() end,
    CIM = {
        BatchActions = {},
        BatchConfig = {},
        Dialogs = {
            Register = function(_, data)
                currentDialogData = data
            end,
        },
        Utils = {},
        ProtectionPolicy = {},
        SharedItemSupport = {
            UpdateTooltipEquippedText = function() end,
            IsItemComparisonEnabled = function()
                return false
            end,
            CompareItem = function()
                return nil
            end,
            ShowComparisonOnTooltip = function() end,
        },
        MultiSelectMixin = {
            BindDelegates = function(target, methodNames)
                for _, methodName in ipairs(methodNames or {}) do
                    target[methodName] = BETTERUI.CIM.MultiSelectMixin[methodName]
                end
            end,
            IsBatchProcessing = function(self)
                return self.isBatchProcessing == true
            end,
            CanAbortBatch = function()
                return false
            end,
            RequestBatchAbort = function()
                return false
            end,
            ProcessBatchThrottled = function(self, items, actionFn, onComplete, actionName, batchOptions)
                if self._testCaptureBatch then
                    return self:_testCaptureBatch(items, actionFn, onComplete, actionName, batchOptions)
                end
            end,
            BatchLock = function() end,
            BatchUnlock = function() end,
            BatchMarkAsJunk = function() end,
            BatchUnmarkAsJunk = function() end,
        },
    },
    Inventory = {
        Class = {},
        CONST = {
            BATCH_SIZE_INITIAL = 50,
        },
        DefaultSortComparator = function(left, right)
            return tostring(left.sortPriorityName or left.name or "") < tostring(right.sortPriorityName or right.name or "")
        end,
    },
    Banking = {
        GetCurrentBank = function()
            return BAG_BANK
        end,
    },
}

function BETTERUI.CIM.BatchActions.ExtractSlot(itemData)
    local rawData = itemData.dataSource or itemData
    return rawData.bagId, rawData.slotIndex
end

function BETTERUI.CIM.BatchActions.HasItemAtSlot(bagId, slotIndex)
    return (GetSlotStackSize(bagId, slotIndex) or 0) > 0
end

function BETTERUI.CIM.BatchConfig.WithServer(options)
    return { server = options }
end

function BETTERUI.CIM.BatchConfig.WithUi(options)
    return { ui = options }
end

function BETTERUI.CIM.BatchConfig.WithAck(options)
    return { ack = options }
end

function BETTERUI.CIM.BatchConfig.WithPacing(options)
    return { pacing = options }
end

function BETTERUI.CIM.BatchConfig.ComposeBatchOptions(...)
    local merged = {}
    for _, section in ipairs({ ... }) do
        for key, value in pairs(section) do
            merged[key] = value
        end
    end
    return merged
end

BETTERUI.CIM.BatchConfig.BATCH_STEP_STATUS = {
    HANDLED = "handled",
    QUEUED = "queued",
    SKIPPED = "skipped",
    STOPPED = "stopped",
}

function BETTERUI.CIM.BatchConfig.BatchStepHandled()
    return { status = BETTERUI.CIM.BatchConfig.BATCH_STEP_STATUS.HANDLED }
end

function BETTERUI.CIM.BatchConfig.BatchStepQueued()
    return { status = BETTERUI.CIM.BatchConfig.BATCH_STEP_STATUS.QUEUED }
end

function BETTERUI.CIM.BatchConfig.BatchStepStopped(reason)
    return {
        status = BETTERUI.CIM.BatchConfig.BATCH_STEP_STATUS.STOPPED,
        reason = reason,
    }
end

function BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(_, _, destinationBag)
    return destinationBag == BAG_BANK and 12 or 7
end

function BETTERUI.CIM.Utils.GetActiveBankTargetBag()
    return BAG_BANK
end

function BETTERUI.CIM.ProtectionPolicy.CanTransferItem()
    return true
end

function BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag()
    return true
end

function BETTERUI.CIM.ProtectionPolicy.CanDestroyItem(_, slotIndex)
    return slotIndex ~= 99
end

function BETTERUI.Inventory.TryDestroyItem()
    return true
end

function GetString(id)
    local strings = {
        [SI_BETTERUI_SEARCH_NO_RESULTS] = "No results",
        [SI_BETTERUI_EMPTY_LIST] = "Empty",
        [SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG] = "Retrieve",
        [SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG] = "Stow",
        [SI_DESTROY_ITEM_PROMPT_TITLE] = "Destroy Items",
        [SI_DIALOG_CANCEL] = "Cancel",
        [SI_GAMEPAD_SELECT_OPTION] = "Select",
    }
    return strings[id] or tostring(id or "")
end

function GetItemLink(bagId, slotIndex)
    return string.format("item:%s:%s", tostring(bagId), tostring(slotIndex))
end

function zo_strformat(fmt, ...)
    local values = { ... }
    return (tostring(fmt):gsub("<<(%d+)>>", function(index)
        return tostring(values[tonumber(index)] or "")
    end))
end

function zo_clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function ZO_ClearNumericallyIndexedTable(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

function ZO_InventorySlot_SetType(itemData, slotType)
    itemData.slotType = slotType
end

local slotStacks = {}

function GetSlotStackSize(bagId, slotIndex)
    return slotStacks[tostring(bagId) .. ":" .. tostring(slotIndex)] or 0
end

function DoesBagHaveSpaceFor(destinationBag)
    return destinationBag ~= BAG_FURNITURE_VAULT
end

function IsESOPlusSubscriber()
    return false
end

function CallSecureProtected(name, ...)
    secureCalls[#secureCalls + 1] = {
        name = name,
        args = { ... },
    }
end

function ZO_Dialogs_ShowGamepadDialog(name, data)
    dialogCalls[#dialogCalls + 1] = {
        name = name,
        data = data,
    }
end

GAMEPAD_TOOLTIPS = {
    Reset = function(_, tooltip)
        recordTooltip("reset", tooltip)
    end,
    ResetScrollTooltipToTop = function(_, tooltip)
        recordTooltip("resetScroll", tooltip)
    end,
    LayoutQuestItem = function(_, tooltip, itemId)
        recordTooltip("quest", tooltip, itemId)
    end,
    LayoutBagItem = function(_, tooltip, bagId, slotIndex)
        recordTooltip("bag", tooltip, bagId, slotIndex)
    end,
    GetTooltip = function(_, tooltip)
        return { tooltip = tooltip }
    end,
    GetTooltipContainer = function(_, tooltip)
        return { tooltip = tooltip, container = true }
    end,
}

BETTERUI.Inventory.UpdateTooltipEquippedText = function() end
BETTERUI.Inventory.IsItemComparisonEnabled = function()
    return false
end
BETTERUI.Inventory.ShowComparisonOnTooltip = function() end
BETTERUI.Inventory.StatComparison = {
    Compare = function()
        return nil
    end,
}

function GetQuestToolQuestItemId(questIndex, toolIndex)
    return string.format("tool:%s:%s", tostring(questIndex), tostring(toolIndex))
end

function GetQuestConditionQuestItemId(questIndex, stepIndex, conditionIndex)
    return string.format("condition:%s:%s:%s", tostring(questIndex), tostring(stepIndex), tostring(conditionIndex))
end

function ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, filterType)
    if filterType == ITEMFILTERTYPE_QUEST then
        return itemData.isQuest == true
    elseif filterType == ITEMFILTERTYPE_WEAPONS then
        return itemData.filterType == ITEMFILTERTYPE_WEAPONS or itemData.equipType == EQUIP_TYPE_POISON
    elseif filterType == ITEMFILTERTYPE_ARMOR or filterType == ITEMFILTERTYPE_JEWELRY then
        return itemData.filterType == filterType
    end
    return itemData.filterType == filterType
end

SHARED_INVENTORY = {
    GenerateFullQuestCache = function()
        return {
            {
                {
                    name = "Quest Relic",
                    isQuest = true,
                    bagId = BAG_BACKPACK,
                    slotIndex = 30,
                },
            },
        }
    end,
}

GAMEPAD_LEFT_TOOLTIP = "LEFT"
GAMEPAD_RIGHT_TOOLTIP = "RIGHT"
GAMEPAD_DIALOGS = { BASIC = 1 }

BAG_BACKPACK = 1
BAG_WORN = 2
BAG_BANK = 3
BAG_SUBSCRIBER_BANK = 4
BAG_VIRTUAL = 5
BAG_FURNITURE_VAULT = 6

ITEMFILTERTYPE_COMPANION = 10
ITEMFILTERTYPE_QUEST = 11
ITEMFILTERTYPE_WEAPONS = 12
ITEMFILTERTYPE_ARMOR = 13
ITEMFILTERTYPE_JEWELRY = 14
EQUIP_TYPE_POISON = 15
GAMEPLAY_ACTOR_CATEGORY_COMPANION = 16
SLOT_TYPE_QUEST_ITEM = 17

SI_BETTERUI_SEARCH_NO_RESULTS = "SI_BETTERUI_SEARCH_NO_RESULTS"
SI_BETTERUI_EMPTY_LIST = "SI_BETTERUI_EMPTY_LIST"
SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG = "SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG"
SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG = "SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG"
SI_DESTROY_ITEM_PROMPT_TITLE = "SI_DESTROY_ITEM_PROMPT_TITLE"
SI_DIALOG_CANCEL = "SI_DIALOG_CANCEL"
SI_GAMEPAD_SELECT_OPTION = "SI_GAMEPAD_SELECT_OPTION"

dofile("Modules/Inventory/Lists/ItemListFiltering.lua")
dofile("Modules/Inventory/Core/InventoryBatchOps.lua")

local function makeInventoryInstance()
    local itemList = {
        noItemText = nil,
        cleared = false,
        selectedIndex = 1,
        SetNoItemText = function(self, text)
            self.noItemText = text
        end,
        Clear = function(self)
            self.cleared = true
        end,
        GetSelectedIndex = function(self)
            return self.selectedIndex
        end,
    }

    local instance = {
        itemList = itemList,
        categoryList = {
            selectedData = {},
            IsEmpty = function(self)
                return self.selectedData == nil
            end,
        },
        cachedBags = {},
        currentlySelectedData = {},
    }

    function instance:IsBatchProcessing()
        return false
    end

    function instance:CaptureItemListRefreshTarget()
        return "unique-id", 5
    end

    function instance:GetCachedSlotData(...)
        local bags = { ... }
        local items = {}
        for _, bagId in ipairs(bags) do
            local bagItems = self.cachedBags[bagId] or {}
            for _, item in ipairs(bagItems) do
                items[#items + 1] = item
            end
        end
        return items
    end

    function instance:PopulateInventoryCategoryFields(itemData)
        itemData.sortPriorityName = itemData.categoryName or itemData.name
        itemData.categoryPopulationCount = (itemData.categoryPopulationCount or 0) + 1
    end

    function instance:ProcessScrollListBatch()
        self.processedBatchData = self.pendingBatchData
        self.processedContext = self.pendingContext
    end

    function instance:UpdateRightTooltip(selectedData)
        self.rightTooltipItem = selectedData
    end

    function instance:ExitCraftBagSelectionMode()
        self.exitedCraftBagSelection = true
    end

    function instance:ExitSelectionMode()
        self.exitedSelection = true
    end

    function instance:_testCaptureBatch(items, actionFn, onComplete, actionName, batchOptions)
        self.capturedBatch = {
            items = items,
            actionFn = actionFn,
            onComplete = onComplete,
            actionName = actionName,
            batchOptions = batchOptions,
        }
    end

    return setmetatable(instance, { __index = BETTERUI.Inventory.Class })
end

local function setSlotStack(bagId, slotIndex, count)
    slotStacks[tostring(bagId) .. ":" .. tostring(slotIndex)] = count
end

print("\n=== Inventory Scene Harness Tests ===\n")

print("Test: RefreshItemList respects category filtering and search")
resetRecords()
local refreshInstance = makeInventoryInstance()
refreshInstance.cachedBags[BAG_BACKPACK] = {
    { name = "Potion", bagId = BAG_BACKPACK, slotIndex = 1, filterType = ITEMFILTERTYPE_WEAPONS, categoryName = "Potions" },
    { name = "Apple", bagId = BAG_BACKPACK, slotIndex = 2, filterType = ITEMFILTERTYPE_ARMOR, categoryName = "Food" },
}
refreshInstance.cachedBags[BAG_WORN] = {
    { name = "Sword", bagId = BAG_WORN, slotIndex = 3, filterType = ITEMFILTERTYPE_WEAPONS, categoryName = "Weapons" },
}
refreshInstance.searchQuery = "po"
refreshInstance.categoryList.selectedData = {}
refreshInstance:RefreshItemList()
assertEqual("No results", refreshInstance.itemList.noItemText, "Search query flips the empty-state copy to the search string")
assertEqual(1, #refreshInstance.processedBatchData, "Search filtering keeps only matching items")
assertEqual("Potion", refreshInstance.processedBatchData[1].name, "Search filtering preserves the matching inventory entry")
assertEqual(1, refreshInstance.processedBatchData[1].categoryPopulationCount, "Refresh populates category fields before sorting")

print("\nTest: RefreshItemList supports equipped-only category refresh")
resetRecords()
local equippedInstance = makeInventoryInstance()
equippedInstance.cachedBags[BAG_BACKPACK] = {
    { name = "Potion", bagId = BAG_BACKPACK, slotIndex = 4, filterType = ITEMFILTERTYPE_WEAPONS, categoryName = "Potions" },
}
equippedInstance.cachedBags[BAG_WORN] = {
    { name = "Shield", bagId = BAG_WORN, slotIndex = 5, filterType = ITEMFILTERTYPE_ARMOR, categoryName = "Equipped" },
}
equippedInstance.categoryList.selectedData = { showEquipped = true }
equippedInstance:RefreshItemList()
assertEqual("Empty", equippedInstance.itemList.noItemText, "Default empty-state copy is used when no search query is active")
assertEqual(1, #equippedInstance.processedBatchData, "Equipped category refresh only keeps worn items")
assertEqual("Shield", equippedInstance.processedBatchData[1].name, "Equipped category refresh uses the live worn-bag cache")

print("\nTest: UpdateItemLeftTooltip routes quest and comparison tooltips through production code")
resetRecords()
local tooltipInstance = makeInventoryInstance()
tooltipInstance.switchInfo = { enabled = true }
tooltipInstance:UpdateItemLeftTooltip({
    bagId = BAG_BACKPACK,
    slotIndex = 20,
    dataSource = { bagId = BAG_BACKPACK, slotIndex = 20 },
    isQuest = true,
    questIndex = 9,
    toolIndex = 3,
})
assertEqual("quest", tooltipCalls[2].kind, "Quest items route to the quest tooltip layout")
assertEqual("tool:9:3", tooltipCalls[2].args[2], "Quest tooltip layout receives the quest item id")

resetRecords()
tooltipInstance:UpdateItemLeftTooltip({
    bagId = BAG_BACKPACK,
    slotIndex = 21,
    dataSource = { bagId = BAG_BACKPACK, slotIndex = 21 },
    filterType = ITEMFILTERTYPE_WEAPONS,
})
assertEqual("resetScroll", tooltipCalls[1].kind, "Tooltip refresh resets the right tooltip scroll position first")
assertEqual(21, tooltipInstance.rightTooltipItem.slotIndex, "Equippable items use the comparison tooltip when switchInfo is active")

print("\nTest: BatchRetrieve and BatchStow execute the production action closures")
resetRecords()
local craftBagInstance = makeInventoryInstance()
craftBagInstance.craftBagMultiSelectManager = {
    GetSelectedItems = function()
        return {
            { bagId = BAG_VIRTUAL, slotIndex = 40, stackCount = 2 },
        }
    end,
}
setSlotStack(BAG_VIRTUAL, 40, 2)
craftBagInstance:BatchRetrieve()
assertEqual(1, #craftBagInstance.capturedBatch.items, "BatchRetrieve forwards selected craft-bag items")
assertEqual("Retrieve", craftBagInstance.capturedBatch.actionName, "BatchRetrieve uses the shipped action label")
assertBatchStatus("queued", craftBagInstance.capturedBatch.actionFn(BAG_VIRTUAL, 40, craftBagInstance.capturedBatch.items[1]),
    "BatchRetrieve action queues a pickup/place workflow")
craftBagInstance.capturedBatch.onComplete()
assertEqual("PickupInventoryItem", secureCalls[1].name, "BatchRetrieve uses the live pickup call")
assertEqual("PlaceInInventory", secureCalls[2].name, "BatchRetrieve deposits into the backpack with the live secure call")
assertTrue(craftBagInstance.exitedCraftBagSelection == true, "BatchRetrieve completion exits craft-bag selection mode")

resetRecords()
local stowInstance = makeInventoryInstance()
stowInstance.multiSelectManager = {
    GetSelectedItems = function()
        return {
            { bagId = BAG_BACKPACK, slotIndex = 41, stackCount = 3 },
        }
    end,
}
setSlotStack(BAG_BACKPACK, 41, 3)
stowInstance:BatchStow()
assertEqual(1, #stowInstance.capturedBatch.items, "BatchStow forwards selected backpack items")
assertBatchStatus("queued", stowInstance.capturedBatch.actionFn(BAG_BACKPACK, 41, stowInstance.capturedBatch.items[1]),
    "BatchStow action queues a pickup/place workflow")
stowInstance.capturedBatch.onComplete()
assertEqual(BAG_VIRTUAL, secureCalls[2].args[1], "BatchStow places items into the craft bag")
assertTrue(stowInstance.exitedSelection == true, "BatchStow completion exits selection mode")

print("\nTest: BatchDeposit and BatchDestroy stay wired to the production handlers")
resetRecords()
local depositInstance = makeInventoryInstance()
depositInstance.multiSelectManager = {
    GetSelectedItems = function()
        return {
            { bagId = BAG_BACKPACK, slotIndex = 50, stackCount = 4 },
        }
    end,
}
setSlotStack(BAG_BACKPACK, 50, 4)
depositInstance:BatchDeposit()
assertEqual("Depositing", depositInstance.capturedBatch.actionName, "BatchDeposit preserves its production action label")
assertBatchStatus("queued", depositInstance.capturedBatch.actionFn(BAG_BACKPACK, 50, depositInstance.capturedBatch.items[1]),
    "BatchDeposit queues a live RequestMoveItem call")
assertEqual("RequestMoveItem", secureCalls[1].name, "BatchDeposit uses the production move request")
assertEqual(BAG_BANK, secureCalls[1].args[3], "BatchDeposit targets the active bank bag")

resetRecords()
local destroyInstance = makeInventoryInstance()
destroyInstance.multiSelectManager = {
    GetSelectedItems = function()
        return {
            { bagId = BAG_BACKPACK, slotIndex = 60, slotType = 1 },
            { bagId = BAG_BACKPACK, slotIndex = 99, slotType = 1 },
        }
    end,
}
destroyInstance:BatchDestroy()
assertEqual(1, #dialogCalls, "BatchDestroy opens the production confirmation dialog")
assertEqual("BETTERUI_BATCH_DESTROY_DIALOG", dialogCalls[1].name, "BatchDestroy uses the shipped dialog id")
assertEqual(1, dialogCalls[1].data.itemCount, "BatchDestroy only forwards destroyable items into the dialog payload")
assertEqual(60, dialogCalls[1].data.itemsToDestroy[1].slotIndex, "BatchDestroy payload keeps the destroyable slot coordinates")

if testsFailed > 0 then
    error(string.format("test_inventory_scene_harness.lua failed with %d failure(s)", testsFailed))
end

print(string.format("\nAll tests passed! (%d assertions)", testsPassed))
