--[[
File: tools/tests/test_action_context.lua
Purpose: Regression coverage for ActionContext ownership registration.
Usage:
  lua tools/tests/test_action_context.lua
]]

local passed = 0
local failed = 0
local frame = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

BETTERUI = {
    CIM = {
        Keybinds = {},
    },
}

ITEMFILTERTYPE_QUEST = 1
ITEMFILTERTYPE_WEAPONS = 2
ITEMFILTERTYPE_ARMOR = 3
ITEMFILTERTYPE_JEWELRY = 4

SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN = "Assign to quickslot"
SI_BETTERUI_INV_SWITCH_INFO = "Switch info"
SI_ITEM_ACTION_USE = "Use"
SI_ITEM_ACTION_LINK_TO_CHAT = "Link to chat"

function GetFrameTimeMilliseconds()
    frame = frame + 1
    return frame
end

function GetItemFilterTypeInfo(_bagId, _slotIndex)
    return ITEMFILTERTYPE_WEAPONS
end

function ZO_InventoryUtils_DoesNewItemMatchFilterType(target, filterType)
    return filterType == ITEMFILTERTYPE_QUEST and target.isQuestItem == true
end

function IsQuickslottable(target)
    return target.isQuickslottable == true
end

function GetString(value)
    return tostring(value)
end

dofile("Modules/CIM/Keybinds/ActionContext.lua")

print("[ActionContext ownership registration]")

BETTERUI.CIM.Keybinds.RegisterInventoryActionModes({
    itemList = 20,
    craftBag = 30,
    category = 10,
})

do
    local inventoryControl = {
        actionMode = 20,
        itemList = {
            selectedData = {
                bagId = 1,
                slotIndex = 2,
                meetsUsageRequirement = true,
                isQuickslottable = true,
            },
        },
    }

    assert_eq(BETTERUI.CIM.Keybinds.GetXButtonName(inventoryControl), "Assign to quickslot",
        "item list action mode uses the registered inventory contract")
    assert_true(BETTERUI.CIM.Keybinds.GetXButtonVisible(inventoryControl),
        "registered item list mode stays visible for usable items")
end

do
    local craftBagControl = {
        actionMode = 30,
        craftBagList = {
            selectedData = {
                bagId = 3,
                slotIndex = 4,
                meetsUsageRequirement = false,
                isQuickslottable = false,
            },
        },
    }

    assert_eq(BETTERUI.CIM.Keybinds.GetXButtonName(craftBagControl), "Link to chat",
        "craft bag action mode uses the registered craft bag contract")
    assert_true(BETTERUI.CIM.Keybinds.GetXButtonVisible(craftBagControl),
        "registered craft bag mode remains visible")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
