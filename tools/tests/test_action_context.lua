--[[
File: tools/tests/test_action_context.lua
Purpose: Regression coverage for ActionContext ownership registration.
Usage:
  lua tools/tests/test_action_context.lua
]]

local passed = 0
local failed = 0
local frame = 0
local freezeFrame = false

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
ITEMFILTERTYPE_QUICKSLOT = 5

SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN = "Assign to quickslot"
SI_BETTERUI_INV_SWITCH_INFO = "Switch info"
SI_ITEM_ACTION_USE = "Use"
SI_ITEM_ACTION_LINK_TO_CHAT = "Link to chat"

function GetFrameTimeMilliseconds()
    if freezeFrame then
        return frame
    end
    frame = frame + 1
    return frame
end

function GetItemFilterTypeInfo(_bagId, _slotIndex)
    return ITEMFILTERTYPE_WEAPONS
end

function ZO_InventoryUtils_DoesNewItemMatchFilterType(target, filterType)
    if filterType == ITEMFILTERTYPE_QUEST then
        return target.isQuestItem == true
    end
    if filterType == ITEMFILTERTYPE_QUICKSLOT then
        return target.isQuickslottable == true
    end
    return false
end

function GetString(value)
    return tostring(value)
end

dofile("Modules/CIM/Keybinds/ActionContext.lua")

assert_true(type(BETTERUI.CIM.IsQuickslottable) == "function",
    "ActionContext exports the shared CIM IsQuickslottable helper")

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

do
    frame = 400
    freezeFrame = true

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

    assert_eq(BETTERUI.CIM.Keybinds.GetXButtonName(inventoryControl), "Assign to quickslot",
        "same-frame cache keeps item-list context scoped to the inventory receiver")
    assert_eq(BETTERUI.CIM.Keybinds.GetXButtonName(craftBagControl), "Link to chat",
        "same-frame cache keeps craft-bag context scoped to the craft-bag receiver")

    freezeFrame = false
end

do
    local warnings = {}
    BETTERUI.Log = {
        CATEGORY = { ACTION = "ACTION", KEYBIND = "KEYBIND" },
        IsActive = function() return false end,
        Warn = function(_, message, data)
            warnings[#warnings + 1] = { message = message, data = data }
        end,
        DescribeItem = function(item, label)
            return { label = label, uniqueId = item and item.uniqueId, bagId = item and item.bagId, slotIndex = item and item.slotIndex }
        end,
    }
    ZO_InventoryUtils_DoesNewItemMatchFilterType = function()
        error("native filter rejected synthetic BetterUI action-context row")
    end
    BETTERUI.CIM.Keybinds.InvalidateActionContext()

    local questControl = {
        actionMode = 20,
        itemList = {
            selectedData = {
                uniqueId = "quest:9:1::",
                questIndex = 9,
                meetsUsageRequirement = true,
            },
        },
    }
    assert_eq(BETTERUI.CIM.Keybinds.GetXButtonName(questControl), "Use",
        "explicit quest action-context rows do not call the native filter")
    assert_eq(#warnings, 0,
        "explicit quest action-context rows do not log native filter failures")

    BETTERUI.CIM.Keybinds.InvalidateActionContext()
    local normalControl = {
        actionMode = 20,
        itemList = {
            selectedData = {
                bagId = 7,
                slotIndex = 8,
                meetsUsageRequirement = false,
            },
        },
    }
    assert_eq(BETTERUI.CIM.Keybinds.GetXButtonName(normalControl), "Switch info",
        "action-context filter failures fail closed without hiding gear info")
    assert_true(#warnings >= 1,
        "action-context native filter failures are monitor-visible")
    assert_eq(warnings[1] and warnings[1].message, "keybind action filter failed",
        "action-context native filter failure logs a canonical reason")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
