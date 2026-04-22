--[[
File: tools/tests/test_craft_bag_transfer_policy.lua
Purpose: Runtime coverage for craft-bag transfers honoring the shared policy seam.
Usage:
  lua tools/tests/test_craft_bag_transfer_policy.lua
]]

local passed = 0
local failed = 0

local function assert_equal(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_equal(value, true, label)
end

local secureCalls = {}
local userNotifications = {}
local canStow = true
local denyReason = nil
local stackSize = 10
local maxStackSize = 20
local destinationSlot = 17
local hasSpace = true
local hasCraftBagAccess = true
local itemCanBeVirtual = true
local itemIsStolen = false

BAG_VIRTUAL = 100
BAG_BACKPACK = 1
SI_INVENTORY_ERROR_INVENTORY_FULL = 9001

BETTERUI = {
    CIM = {
        Utils = {},
    },
}

function ZO_Inventory_GetBagAndIndex(inventorySlot)
    return inventorySlot and inventorySlot.bagId, inventorySlot and inventorySlot.slotIndex
end

function GetSlotStackSize(_bagId, _slotIndex)
    return stackSize, maxStackSize
end

function CallSecureProtected(action, ...)
    secureCalls[#secureCalls + 1] = { action = action, args = { ... } }
end

function HasCraftBagAccess()
    return hasCraftBagAccess
end

function CanItemBeVirtual()
    return itemCanBeVirtual
end

function IsItemStolen()
    return itemIsStolen
end

function DoesBagHaveSpaceFor()
    return hasSpace
end

BETTERUI.CIM.Utils.ResolveMoveDestinationSlot = function()
    return destinationSlot
end

BETTERUI.CIM.UserNotify = function(context, stringId)
    userNotifications[#userNotifications + 1] = {
        context = context,
        stringId = stringId,
    }
end

BETTERUI.CIM.ProtectionPolicy = {
    DENY = {
        STOLEN = "stolen",
        NO_CRAFT_ACCESS = "no_craft_access",
        NOT_CRAFTABLE = "not_craftable",
        NO_ITEM = "no_item",
    },
    CanStowToCraftBag = function(_bagId, _slotIndex)
        return canStow, denyReason
    end,
}

local defaultPolicyCanStow = BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag

dofile("Modules/CIM/Actions/GenericSlotActions.lua")

print("[Craft bag transfer policy]")

do
    secureCalls = {}
    hasCraftBagAccess = true
    itemCanBeVirtual = true
    itemIsStolen = false
    canStow = false
    denyReason = "stolen"

    local moved, reason = BETTERUI.CIM.TryMoveToCraftBag({ bagId = BAG_BACKPACK, slotIndex = 4 }, BAG_VIRTUAL, 3)

    assert_equal(moved, false, "policy denial stops stow transfer")
    assert_equal(reason, "stolen", "policy denial reason is returned")
    assert_equal(#secureCalls, 0, "policy denial avoids secure transfer calls")
    assert_equal(BETTERUI.CIM.CanItemMoveToCraftBag({ bagId = BAG_BACKPACK, slotIndex = 4 }), false,
        "CanItemMoveToCraftBag follows policy denial")
end

do
    secureCalls = {}
    hasCraftBagAccess = false
    itemCanBeVirtual = true
    itemIsStolen = false
    BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag = nil

    local ok, err = pcall(BETTERUI.CIM.TryMoveToCraftBag, { bagId = BAG_BACKPACK, slotIndex = 4 }, BAG_VIRTUAL, 3)

    assert_equal(ok, false, "missing CanStowToCraftBag policy method is a required-policy contract violation")
    assert_true(type(err) == "string"
            and string.find(err, "CanStowToCraftBag must load before craft-bag transfer checks", 1, true) ~= nil,
        "missing CanStowToCraftBag policy method raises the explicit required-policy error")
    assert_equal(#secureCalls, 0, "missing policy method avoids secure transfer calls")

    BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag = defaultPolicyCanStow
end

do
    secureCalls = {}
    hasCraftBagAccess = true
    itemCanBeVirtual = true
    itemIsStolen = false
    stackSize = 0
    BETTERUI.CIM.ProtectionPolicy.DENY.NO_ITEM = "deny_no_item"

    local moved, reason = BETTERUI.CIM.TryMoveToCraftBag({ bagId = BAG_BACKPACK, slotIndex = 4 }, BAG_VIRTUAL, 3)

    assert_equal(moved, false, "empty stacks are denied before transfer")
    assert_equal(reason, "deny_no_item", "empty-stack denial resolves via shared no-item constant")
    assert_equal(#secureCalls, 0, "empty-stack denial avoids secure transfer calls")

    BETTERUI.CIM.ProtectionPolicy.DENY.NO_ITEM = "no_item"
    stackSize = 10
end

do
    secureCalls = {}
    hasCraftBagAccess = true
    itemCanBeVirtual = true
    itemIsStolen = false
    BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag = defaultPolicyCanStow
    canStow = true
    denyReason = nil

    local moved = BETTERUI.CIM.TryMoveToCraftBag({ bagId = BAG_BACKPACK, slotIndex = 4 }, BAG_VIRTUAL, 3)

    assert_equal(moved, true, "policy-approved stow succeeds")
    assert_equal(#secureCalls, 2, "stow executes pickup and placement")
    assert_equal(secureCalls[1].action, "PickupInventoryItem", "stow starts with pickup")
    assert_equal(secureCalls[1].args[3], 3, "stow honors explicit quantity")
    assert_equal(secureCalls[2].action, "PlaceInInventory", "stow places into craft bag")
    assert_equal(secureCalls[2].args[1], BAG_VIRTUAL, "stow targets the craft bag")
    assert_true(BETTERUI.CIM.CanItemMoveToCraftBag({ bagId = BAG_BACKPACK, slotIndex = 4 }),
        "CanItemMoveToCraftBag returns true when policy allows")
end

do
    secureCalls = {}
    userNotifications = {}
    hasSpace = true
    hasCraftBagAccess = true
    itemCanBeVirtual = true
    itemIsStolen = false
    destinationSlot = 42

    local moved = BETTERUI.CIM.TryMoveToCraftBag({ bagId = BAG_VIRTUAL, slotIndex = 9 }, BAG_BACKPACK, 2)

    assert_equal(moved, true, "retrieve path still succeeds through shared helper")
    assert_equal(#secureCalls, 2, "retrieve executes pickup and placement")
    assert_equal(secureCalls[1].args[3], 2, "retrieve honors explicit quantity")
    assert_equal(secureCalls[2].args[2], destinationSlot, "retrieve uses resolved destination slot")
    assert_equal(#userNotifications, 0, "successful retrieve does not notify")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
