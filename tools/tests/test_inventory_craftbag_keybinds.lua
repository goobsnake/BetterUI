--[[
File: tools/tests/test_inventory_craftbag_keybinds.lua
Purpose: Focused regressions for inventory craft-bag switch and quest primary keybinds.
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

local warnings = {}
local traces = {}
local currentScene = "gamepad_inventory_root"
local openedQuestIndex = nil

BETTERUI = {
    Inventory = {
        Keybinds = {},
        CONST = {
            ITEM_LIST_ACTION_MODE = 1,
            CRAFT_BAG_ACTION_MODE = 2,
        },
        Utils = {
            SafeGetTargetData = function(list)
                return list and (list.selectedData or list.targetData) or nil
            end,
        },
    },
    CIM = {
        Keybinds = {},
        UserNotify = function() end,
    },
    Log = {
        CATEGORY = { KEYBIND = "KEYBIND", ACTION = "ACTION" },
        LEVEL = { INFO = "INFO" },
        TraceEvent = function(category, event, phase, data)
            traces[#traces + 1] = { category = category, event = event, phase = phase, data = data }
        end,
        Warn = function(category, message, data)
            warnings[#warnings + 1] = { category = category, message = message, data = data }
        end,
        DescribeItem = function(item, label)
            return {
                label = label,
                uniqueId = item and item.uniqueId,
                questIndex = item and item.questIndex,
                bagId = item and item.bagId,
                slotIndex = item and item.slotIndex,
            }
        end,
    },
}

ITEMFILTERTYPE_QUEST = 10
SLOT_TYPE_QUEST_ITEM = 11
SI_ITEM_ACTION_EQUIP = 20
SI_ITEM_ACTION_UNEQUIP = 21
SI_ITEM_ACTION_USE = 22
SI_ITEM_ACTION_SHOW_MAP = 23
SI_ITEM_ACTION_START_SKILL_RESPEC = 24
SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC = 25
SI_ITEM_ACTION_SHOW_QUEST = 26
SI_ITEM_ACTION_PLACE_FURNITURE = 27
SI_ITEM_ACTION_LINK_TO_CHAT = 28
SI_INVENTORY_BAG_UPGRADE_LABEL = 29

local stringMap = {
    [SI_ITEM_ACTION_EQUIP] = "Equip",
    [SI_ITEM_ACTION_UNEQUIP] = "Unequip",
    [SI_ITEM_ACTION_USE] = "Use",
    [SI_ITEM_ACTION_SHOW_MAP] = "Show on Map",
    [SI_ITEM_ACTION_START_SKILL_RESPEC] = "Open Skills",
    [SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC] = "Open Attributes",
    [SI_ITEM_ACTION_SHOW_QUEST] = "Show Quest in Journal",
    [SI_ITEM_ACTION_PLACE_FURNITURE] = "Place Furniture",
    [SI_ITEM_ACTION_LINK_TO_CHAT] = "Link in Chat",
    [SI_INVENTORY_BAG_UPGRADE_LABEL] = "Bag Upgrade",
}

function GetString(id)
    return stringMap[id] or tostring(id or "")
end

function GetFrameTimeMilliseconds()
    return 1000
end

function ZO_InventoryUtils_DoesNewItemMatchFilterType(target, filterType)
    error("native inventory filter must not be called for BetterUI craft-bag keybind rows")
end

SCENE_MANAGER = {
    GetCurrentSceneName = function()
        return currentScene
    end,
}

SYSTEMS = {
    GetObject = function(_, name)
        if name == "questJournal" then
            return {
                OpenQuestJournalToQuest = function(_, questIndex)
                    openedQuestIndex = questIndex
                end,
            }
        end
        return nil
    end,
}

dofile("Modules/Inventory/Keybinds/CraftBagKeybinds.lua")

local function makeInventory(target)
    local inventory = {
        actionMode = BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE,
        categoryList = {},
        itemList = {
            selectedData = target,
        },
        craftBagList = {},
        IsBatchProcessing = function()
            return false
        end,
        GetCurrentList = function(self)
            return self.itemList
        end,
    }
    return inventory
end

print("\n=== Inventory Craft Bag Keybind Tests ===\n")

local questInventory = makeInventory({
    uniqueId = "quest:4:2::",
    questIndex = 4,
    slotType = SLOT_TYPE_QUEST_ITEM,
})
warnings = {}
traces = {}
local visible, reason = BETTERUI.Inventory.Keybinds.CanShowCraftBagSwitch(questInventory)
assert_eq(visible, false, "Quest item rows hide the craft-bag switch keybind")
assert_eq(reason, "questTarget", "Quest item craft-bag switch hide reason is explicit")
assert_eq(#warnings, 0, "Quest craft-bag switch suppression does not emit warning noise")
assert_eq(traces[1] and traces[1].event, "inventory.craft_bag_switch_keybind",
    "Quest craft-bag switch suppression remains monitor-visible as a trace event")
assert_eq(traces[1] and traces[1].phase, "blocked", "Quest craft-bag switch suppression uses blocked trace phase")
assert_eq(traces[1] and traces[1].data and traces[1].data.reason, "questTarget",
    "Quest craft-bag switch trace keeps the explicit deny reason")

local normalInventory = makeInventory({
    uniqueId = "item:1:2",
    bagId = 1,
    slotIndex = 2,
})
warnings = {}
traces = {}
currentScene = "gamepad_quickslot"
visible, reason = BETTERUI.Inventory.Keybinds.CanShowCraftBagSwitch(normalInventory)
assert_eq(visible, false, "Quickslot scene hides the inventory craft-bag switch keybind")
assert_eq(reason, "sceneMismatch", "Quickslot scene craft-bag switch hide reason is explicit")
assert_eq(#warnings, 0, "Quickslot scene craft-bag switch suppression does not emit warning noise")
assert_eq(traces[1] and traces[1].event, "inventory.craft_bag_switch_keybind",
    "Quickslot scene craft-bag switch suppression remains monitor-visible as a trace event")
assert_eq(traces[1] and traces[1].phase, "blocked", "Quickslot scene craft-bag switch suppression uses blocked trace phase")
assert_eq(traces[1] and traces[1].data and traces[1].data.reason, "sceneMismatch",
    "Quickslot scene craft-bag switch trace keeps the explicit deny reason")

currentScene = "gamepad_inventory_root"
visible, reason = BETTERUI.Inventory.Keybinds.CanShowCraftBagSwitch(normalInventory)
assert_eq(visible, true, "Normal inventory item rows keep the craft-bag switch keybind")
assert_eq(reason, nil, "Visible craft-bag switch has no hidden reason")

local nativePrimaryRan = false
local showQuestSlotActions = {
    m_slotActions = {
        { "Show Quest in Journal", function() nativePrimaryRan = true end },
    },
    GetPrimaryActionName = function()
        return "Show Quest in Journal"
    end,
    DoPrimaryAction = function()
        nativePrimaryRan = true
    end,
}
local showQuestInventory = makeInventory({
    uniqueId = "quest:12:1::",
    questIndex = 12,
    isQuestItem = true,
})
showQuestInventory.itemActions = {
    actionName = "Show Quest in Journal",
    slotActions = showQuestSlotActions,
}

openedQuestIndex = nil
local handled, handleReason, branch = BETTERUI.Inventory.Keybinds.HandlePrimaryKeybind(showQuestInventory)
assert_eq(handled, true, "Primary Show Quest action is handled")
assert_eq(handleReason, nil, "Primary Show Quest action has no failure reason")
assert_eq(branch, "showQuest", "Primary Show Quest action reports a specific branch")
assert_eq(openedQuestIndex, 12, "Primary Show Quest opens the selected quest journal entry")
assert_eq(nativePrimaryRan, false, "Primary Show Quest bypasses the stale native slot-action closure")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
print("All tests passed!")
