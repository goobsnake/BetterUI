--[[
File: tools/tests/test_inventory_core.lua
Purpose: Unit tests for inventory core contracts in InventoryClass.lua and
         Inventory.lua covering cache behavior, equipment-slot selection,
         and list orchestration helpers.
]]

if false then
    dofile("Modules/Inventory/Core/InventoryClass.lua")
    dofile("Modules/Inventory/Inventory.lua")
end

local generatedFullSlotCalls = {}
local createdControls = {}
local shownDialogs = {}
local equipSlots = {}
local lockedSlots = {}
local activeSlots = {}
local slotEquipTypes = {}

BETTERUI = {
    Inventory = {
        CONST = {
            ITEM_LIST_ACTION_MODE = 2,
            CRAFT_BAG_ACTION_MODE = 3,
        },
        Utils = {},
    },
    CIM = {
        DeferredTask = {
            Manager = {
                New = function()
                    return {}
                end,
            },
            CreateLazyManagerProxy = function(factory)
                return setmetatable({}, {
                    __index = function(_, key)
                        local manager = factory()
                        return manager and manager[key]
                    end,
                })
            end,
        },
    },
}

function BETTERUI.Debug() end

function BETTERUI.Inventory.Utils.SafeGetTargetData(list)
    return list and list.selectedData or nil
end

ZO_GamepadInventory = {}

function ZO_GamepadInventory:Subclass()
    local child = {}
    child.__index = child
    setmetatable(child, { __index = self })
    return child
end

SHARED_INVENTORY = {}

function SHARED_INVENTORY:GenerateFullSlotData(_, ...)
    generatedFullSlotCalls[#generatedFullSlotCalls + 1] = { ... }
    return {
        { bagId = 1, slotIndex = 10, brandNew = false },
        { bagId = 1, slotIndex = 11, brandNew = true, tag = "fresh" },
    }
end

function ZO_Character_EnumerateOrderedEquipSlots()
    return ipairs(equipSlots)
end

function IsLockedWeaponSlot(slot)
    return lockedSlots[slot] or false
end

function ZO_Character_DoesEquipSlotUseEquipType(slot, equipType)
    return slotEquipTypes[slot] == equipType
end

function IsActiveCombatRelatedEquipmentSlot(slot)
    return activeSlots[slot] or false
end

EQUIP_TYPE_MAIN_HAND = 1
EQUIP_TYPE_OFF_HAND = 2
EQUIP_TYPE_TWO_HAND = 3
EQUIP_TYPE_POISON = 4
EQUIP_TYPE_RING = 5

PLAYER_INVENTORY = {}

function PLAYER_INVENTORY:SlotForInventoryControl(inventorySlot)
    return inventorySlot and inventorySlot.mockSlot or nil
end

function CreateControlFromVirtual(name, parent, template)
    local control = {
        name = name,
        parent = parent,
        template = template,
        list = {},
    }
    createdControls[#createdControls + 1] = control
    return control
end

function ZO_Dialogs_ShowGamepadDialog(name, params)
    shownDialogs[#shownDialogs + 1] = {
        name = name,
        params = params,
    }
end

function GetNextBackpackUpgradePrice()
    return 777
end

dofile("Modules/Inventory/Core/InventoryClass.lua")
dofile("Modules/Inventory/Inventory.lua")

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

local function assert_same(expected, actual, message)
    assert_true(expected == actual, message)
end

print("\n=== Inventory Core Tests ===\n")

print("-- GetCachedSlotData normalizes bag order and invalidates cleanly --")
do
    generatedFullSlotCalls = {}
    local instance = setmetatable({}, { __index = BETTERUI.Inventory.Class })

    local first = instance:GetCachedSlotData(2, 1)
    local second = instance:GetCachedSlotData(1, 2)

    assert_same(first, second, "Repeated bag sets share the same cached slot table")
    assert_equal(1, #generatedFullSlotCalls, "GenerateFullSlotData runs only once for the cached bag set")
    assert_equal(1, generatedFullSlotCalls[1][1], "Bag IDs are sorted before cache population")
    assert_equal(2, generatedFullSlotCalls[1][2], "Second sorted bag ID is preserved")

    instance:InvalidateSlotDataCache()
    local third = instance:GetCachedSlotData(1, 2)
    assert_true(third ~= first, "Invalidating the cache forces a fresh slot table")
    assert_equal(2, #generatedFullSlotCalls, "GenerateFullSlotData runs again after invalidation")
end

print("\n-- GetEquipSlotForEquipType prefers the intended weapon bar and AreAnyItemsNew filters results --")
do
    local instance = setmetatable({}, { __index = BETTERUI.Inventory.Class })

    equipSlots = { 100, 200, 300 }
    slotEquipTypes = {
        [100] = EQUIP_TYPE_MAIN_HAND,
        [200] = EQUIP_TYPE_MAIN_HAND,
        [300] = EQUIP_TYPE_RING,
    }
    activeSlots = {
        [100] = true,
        [200] = false,
    }
    lockedSlots = {}

    instance.isPrimaryWeapon = true
    assert_equal(100, instance:GetEquipSlotForEquipType(EQUIP_TYPE_MAIN_HAND),
        "Primary weapon selection prefers the active main-hand slot")

    instance.isPrimaryWeapon = false
    assert_equal(200, instance:GetEquipSlotForEquipType(EQUIP_TYPE_MAIN_HAND),
        "Backup weapon selection prefers the inactive main-hand slot")

    instance.GetCachedSlotData = function()
        return {
            { brandNew = false, tag = "old" },
            { brandNew = true, tag = "fresh" },
        }
    end

    assert_true(instance:AreAnyItemsNew(function(itemData, expectedTag)
        return itemData.tag == expectedTag
    end, "fresh", 1), "AreAnyItemsNew respects the provided filter callback")
    assert_equal(false, instance:AreAnyItemsNew(function(itemData)
        return itemData.tag == "missing"
    end, nil, 1), "AreAnyItemsNew returns false when no filtered item is new")
end

print("\n-- Inventory orchestration helpers create lists, route selection, and proxy lock state --")
do
    local instance = setmetatable({
        control = { container = { name = "container" } },
        lists = {},
        createdFragments = {},
    }, { __index = BETTERUI.Inventory.Class })

    instance.CreateAndSetupList = function(selfRef, listControl, callbackParam, listClass, ...)
        return {
            sourceControl = listControl,
            callbackParam = callbackParam,
            listClass = listClass,
            extraArgs = { ... },
        }
    end

    instance.CreateListFragment = function(selfRef, name, hidden)
        selfRef.createdFragments[#selfRef.createdFragments + 1] = {
            name = name,
            hidden = hidden,
        }
    end

    local list = instance:AddList("ItemList", "selected", "ListClass", "extra")
    assert_equal(15, list.alignToScreenCenterExpectedEntryHalfHeight, "AddList applies the expected list alignment height")
    assert_same(list, instance.lists.ItemList, "AddList stores the created list by name")
    assert_equal("ItemList", instance.createdFragments[1].name, "AddList creates the corresponding hidden fragment")

    shownDialogs = {}
    local switchedTo = {}
    instance.SwitchActiveList = function(selfRef, listType)
        switchedTo[#switchedTo + 1] = listType
    end

    instance.categoryList = { selectedData = { isBagSpaceEntry = true } }
    instance:Select()
    assert_equal("BUY_BAG_SPACE_FROM_INVENTORY_GAMEPAD", shownDialogs[1].name,
        "Select opens the bag-space upgrade dialog for bag-space rows")

    instance.categoryList.selectedData = { text = "All", onClickDirection = nil }
    instance:Select()
    assert_equal("itemList", switchedTo[#switchedTo], "Select chooses the item list for regular inventory categories")

    instance.categoryList.selectedData = { text = "Craft Bag", onClickDirection = 1 }
    instance:Select()
    assert_equal("craftBagList", switchedTo[#switchedTo], "Select chooses the craft bag list for craft-bag categories")

    instance.craftBagList = { name = "craft" }
    instance.itemList = { name = "items" }

    instance.GetCurrentList = function()
        return instance.craftBagList
    end
    instance:Switch()
    assert_equal("itemList", switchedTo[#switchedTo], "Switch toggles back to the item list when craft bag is active")

    instance.GetCurrentList = function()
        return instance.itemList
    end
    instance:Switch()
    assert_equal("craftBagList", switchedTo[#switchedTo], "Switch toggles into the craft bag when inventory is active")

    assert_equal(false, instance:BETTERUI_IsSlotLocked(nil), "BETTERUI_IsSlotLocked returns false for nil inventory slots")
    assert_true(instance:BETTERUI_IsSlotLocked({ mockSlot = { locked = true } }),
        "BETTERUI_IsSlotLocked proxies the underlying player inventory lock flag")
end

print("\n=== Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    os.exit(1)
end
