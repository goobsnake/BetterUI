--[[
File: tools/tests/test_destroy_policy_contracts.lua
Purpose: Runtime assertions for destroy-policy fail-closed behavior when policy seams are unavailable.

Usage:
  lua tools/tests/test_destroy_policy_contracts.lua
]]

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print("Assertion failed: " .. label)
    end
end

local function assert_false(value, label)
    assert_true(not value, label)
end

local function get_upvalue(func, name)
    for i = 1, 32 do
        local upName, upValue = debug.getupvalue(func, i)
        if not upName then
            return nil
        end
        if upName == name then
            return upValue
        end
    end
    return nil
end

-- Test contract for ActionDialogHooks' destroy policy helper.
do
    BETTERUI = {
        CIM = {
            Dialogs = {
                Register = function() end,
            },
        },
        Inventory = { Utils = {} },
        Utils = {
            IsInventorySceneShowing = function() return true end,
            IsBankingSceneShowing = function() return false end,
        },
        GetModuleEnabled = function() return true end,
    }

    function BETTERUI.Inventory.Utils.SafeGetTargetData(target)
        return target
    end
    function ZO_Inventory_GetBagAndIndex(target)
        return target.bagId, target.slotIndex
    end

    loadfile("Modules/Inventory/Actions/ActionDialogHooks.lua")()
    local canDestroyTargetWithPolicy = get_upvalue(BETTERUI.Inventory.HookActionDialog, "CanDestroyTargetWithPolicy")
    assert_true(type(canDestroyTargetWithPolicy) == "function", "ActionDialogHooks exposes destroy-policy helper as a closure upvalue")

    local ok, _ = pcall(canDestroyTargetWithPolicy, { bagId = 3, slotIndex = 4, dataSource = { slotType = 7 } })
    assert_false(ok, "ActionDialogHooks fails closed with assertion when CIM.ProtectionPolicy is missing")
end

-- Test contract for ItemActionHandlers' destroy policy helper.
do
    BETTERUI = {
        CIM = {},
        Inventory = {
            ActionHandlers = {},
            Utils = {},
            CONST = {
                ITEM_LIST_ACTION_MODE = 1,
                CRAFT_BAG_ACTION_MODE = 2,
                CATEGORY_ITEM_ACTION_MODE = 3,
            },
        },
        GetSetting = function(_, _) return false end,
    }

    function BETTERUI.Inventory.Utils.SafeGetTargetData(target)
        return target
    end
    function ZO_Inventory_GetBagAndIndex(target)
        return target.bagId, target.slotIndex
    end
    function ZO_Dialogs_ReleaseDialogOnButtonPress() end
    function ZO_Dialogs_ShowDialog() end
    function GetItemLink() return "item" end
    function ZO_InventorySlot_TrySplitStack() end

    loadfile("Modules/Inventory/Actions/ItemActionHandlers.lua")()
    local canDestroyTargetData = get_upvalue(BETTERUI.Inventory.ActionHandlers.OnSetup, "CanDestroyTargetData")
    assert_true(type(canDestroyTargetData) == "function", "ItemActionHandlers exposes destroy-policy helper as a closure upvalue")

    local ok, _ = pcall(canDestroyTargetData, { bagId = 3, slotIndex = 4, dataSource = { slotType = 7 } })
    assert_false(ok, "ItemActionHandlers fails closed with assertion when no destroy policy seam is loaded")
end

print(string.format("test_destroy_policy_contracts.lua: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
