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

local function find_nested_upvalue(func, name, seen)
    if type(func) ~= "function" or type(name) ~= "string" then
        return nil
    end
    if seen and seen[func] then
        return nil
    end
    seen = seen or {}
    seen[func] = true

    for i = 1, 64 do
        local upName, upValue = debug.getupvalue(func, i)
        if not upName then
            return nil
        end
        if upName == name and type(upValue) == "function" then
            return upValue
        end
        if type(upValue) == "function" then
            local nested = find_nested_upvalue(upValue, name, seen)
            if nested then
                return nested
            end
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

-- Test contract for BankingActions junk policy helpers.
do
    BETTERUI = {
        Banking = {
            LIST_WITHDRAW = 1,
            LIST_DEPOSIT = 2,
            Class = {},
        },
        CIM = {},
        Utils = {
            IsBankingSceneShowing = function() return true end,
        },
    }

    SLOT_TYPE_BANK_ITEM = 5
    SLOT_TYPE_GAMEPAD_INVENTORY_ITEM = 6

    function ZO_InventorySlot_DiscoverSlotActionsFromActionList() end
    ZO_GamepadEntryData = {}
    function ZO_ClearNumericallyIndexedTable(tbl)
        for i = #tbl, 1, -1 do
            table.remove(tbl, i)
        end
    end
    function ZO_GamepadEntryData.New()
        return {}
    end
    function ZO_SharedGamepadEntry_OnSetup() end

    BETTERUI.CIM.ProtectionPolicy = {
        CanJunkItem = function()
            return true
        end,
        CanUnjunkItem = function()
            return true
        end,
    }
    BETTERUI.Banking.IsSourceFurnitureVaultTransfer = function()
        return false
    end
    local callbacks = {}
    CALLBACK_MANAGER = {
        RegisterCallback = function(_, eventName, callback)
            callbacks[eventName] = callback
        end,
    }

    loadfile("Modules/Banking/Actions/BankingActions.lua")()
    local bankingController = {
        currentMode = BETTERUI.Banking.LIST_WITHDRAW,
        isInHeaderSortMode = false,
        itemActions = {
            SetInventorySlot = function() end,
            GetSlotActions = function()
                return {
                    GetNumSlotActions = function()
                        return 0
                    end,
                    GetSlotAction = function()
                        return nil
                    end,
                }
            end,
        },
        RefreshItemActions = function() end,
        GetList = function()
            return { selectedData = { bagId = 3, slotIndex = 4 } }
        end,
        AddKeybinds = function() end,
        RefreshItemList = function() end,
        SaveListPosition = function() end,
        ShowQuantityDialog = function() end,
        MoveItem = function() end,
        list = {
            IsEmpty = function()
                return false
            end,
        },
    }
    BETTERUI.Banking.Class.InitializeActionsDialog(bankingController)

    local setupCallback = callbacks.BETTERUI_EVENT_ACTION_DIALOG_SETUP
    local confirmCallback = callbacks.BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM
    assert_true(type(setupCallback) == "function",
        "BankingActions registers the action-dialog setup callback")
    assert_true(type(confirmCallback) == "function",
        "BankingActions registers the action-dialog confirm callback")

    local canJunkWithPolicy = find_nested_upvalue(setupCallback, "CanJunkWithPolicy")
    local canUnjunkWithPolicy = find_nested_upvalue(confirmCallback, "CanUnjunkWithPolicy")
    assert_true(type(canJunkWithPolicy) == "function", "BankingActions exposes banking junk-policy helper as an init closure upvalue")
    assert_true(type(canUnjunkWithPolicy) == "function", "BankingActions exposes banking unjunk-policy helper as an init closure upvalue")

    BETTERUI.CIM.ProtectionPolicy = nil
    local okJunk, _ = pcall(canJunkWithPolicy, 3, 4)
    local okUnjunk, _ = pcall(canUnjunkWithPolicy, 3, 4)
    assert_false(okJunk, "BankingActions fails closed with assertion when CIM.ProtectionPolicy is missing for junk policy")
    assert_false(okUnjunk, "BankingActions fails closed with assertion when CIM.ProtectionPolicy is missing for unjunk policy")
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

    local toggleJunkState = find_nested_upvalue(BETTERUI.Inventory.ActionHandlers.OnSetup, "ToggleJunkState")
    assert_true(type(toggleJunkState) == "function", "ItemActionHandlers exposes junk toggle handler as a setup closure upvalue")
    local canJunkWithPolicy = find_nested_upvalue(toggleJunkState, "CanJunkWithPolicy")
    local canUnjunkWithPolicy = find_nested_upvalue(toggleJunkState, "CanUnjunkWithPolicy")
    assert_true(type(canJunkWithPolicy) == "function", "ItemActionHandlers exposes junk-policy helper as a setup closure upvalue")
    assert_true(type(canUnjunkWithPolicy) == "function", "ItemActionHandlers exposes unjunk-policy helper as a setup closure upvalue")

    local okJunk, _ = pcall(canJunkWithPolicy, { bagId = 3, slotIndex = 4 })
    local okUnjunk, _ = pcall(canUnjunkWithPolicy, { bagId = 3, slotIndex = 4 })
    assert_false(okJunk, "ItemActionHandlers fails closed with assertion when CIM.ProtectionPolicy is missing for junk policy")
    assert_false(okUnjunk, "ItemActionHandlers fails closed with assertion when CIM.ProtectionPolicy is missing for unjunk policy")
end

print(string.format("test_destroy_policy_contracts.lua: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
