--[[
File: tools/tests/test_companion_item_preview.lua
Purpose: Unit tests for companion equipment item-preview gating logic.

Usage:
  lua tools/tests/test_companion_item_preview.lua
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

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

local previewCalls = {}
local endPreviewCalls = 0
local previewEligible = false

function CanInventoryItemBePreviewed(bagId, slotIndex)
    return previewEligible == true
end

function PreviewInventoryItem(bagId, slotIndex)
    table.insert(previewCalls, { bagId = bagId, slotIndex = slotIndex })
end

function EndCurrentItemPreview()
    endPreviewCalls = endPreviewCalls + 1
end

function GetString(value)
    return tostring(value)
end

function IsItemPlayerLocked(bagId, slotIndex)
    return false
end

function IsItemJunk(bagId, slotIndex)
    return false
end

function GetSlotStackSize(bagId, slotIndex)
    return 1
end

SI_ITEM_ACTION_PREVIEW = "SI_ITEM_ACTION_PREVIEW"
SI_ITEM_ACTION_EQUIP = "SI_ITEM_ACTION_EQUIP"
SI_ITEM_ACTION_UNEQUIP = "SI_ITEM_ACTION_UNEQUIP"
SI_ITEM_ACTION_DESTROY = "SI_ITEM_ACTION_DESTROY"
SI_ITEM_ACTION_MARK_AS_LOCKED = "SI_ITEM_ACTION_MARK_AS_LOCKED"
SI_ITEM_ACTION_UNMARK_AS_LOCKED = "SI_ITEM_ACTION_UNMARK_AS_LOCKED"
SI_ITEM_ACTION_MARK_AS_JUNK = "SI_ITEM_ACTION_MARK_AS_JUNK"
SI_ITEM_ACTION_UNMARK_AS_JUNK = "SI_ITEM_ACTION_UNMARK_AS_JUNK"
SI_ITEM_ACTION_SPLIT_STACK = "SI_ITEM_ACTION_SPLIT_STACK"

-- Weapon-type constants referenced by CompanionActions' TWO_HANDED_WEAPON_TYPES
-- table at load time (real values are injected by the ESO engine).
WEAPONTYPE_TWO_HANDED_SWORD = 1
WEAPONTYPE_TWO_HANDED_AXE = 2
WEAPONTYPE_TWO_HANDED_HAMMER = 3
WEAPONTYPE_FIRE_STAFF = 4
WEAPONTYPE_FROST_STAFF = 5
WEAPONTYPE_LIGHTNING_STAFF = 6
WEAPONTYPE_HEALING_STAFF = 7
WEAPONTYPE_BOW = 8

BETTERUI = {
    CIM = {
        ProtectionPolicy = {
            CanDestroyItem = function() return false end,
            CanLockItem = function() return false end,
            CanUnlockItem = function() return false end,
            CanJunkItem = function() return false end,
            CanUnjunkItem = function() return false end,
        },
    },
    Companions = {
        GetSetting = function(key) return nil end,
    },
}

local originalCanInventoryItemBePreviewed = CanInventoryItemBePreviewed

dofile("Modules/Companions/Actions/CompanionActions.lua")

local Companions = BETTERUI.Companions

print("[Companion item preview]")

-- Predicate: nil arguments should never preview.
assert_eq(Companions.CanPreviewCompanionItem(nil, nil), false, "nil bag/slot is not previewable")

-- Predicate: gated by CanInventoryItemBePreviewed.
previewEligible = true
assert_true(Companions.CanPreviewCompanionItem(1, 2), "eligible bag/slot is previewable")

previewEligible = false
assert_eq(Companions.CanPreviewCompanionItem(1, 2), false, "ineligible bag/slot is not previewable")

-- Predicate: nil-guard the engine API.
CanInventoryItemBePreviewed = nil
assert_eq(Companions.CanPreviewCompanionItem(1, 2), false, "missing CanInventoryItemBePreviewed is not previewable")
CanInventoryItemBePreviewed = originalCanInventoryItemBePreviewed

-- TryPreview: calls engine API only when eligible.
previewEligible = true
previewCalls = {}
assert_true(Companions.TryPreviewCompanionItem(7, 8), "TryPreview returns true when eligible")
assert_eq(#previewCalls, 1, "TryPreview calls PreviewInventoryItem once")
assert_eq(previewCalls[1].bagId, 7, "TryPreview passes correct bagId")
assert_eq(previewCalls[1].slotIndex, 8, "TryPreview passes correct slotIndex")

previewEligible = false
previewCalls = {}
assert_eq(Companions.TryPreviewCompanionItem(7, 8), false, "TryPreview returns false when ineligible")
assert_eq(#previewCalls, 0, "TryPreview does not call PreviewInventoryItem when ineligible")

-- EndCompanionItemPreview: nil-guarded teardown.
endPreviewCalls = 0
Companions.EndCompanionItemPreview()
assert_eq(endPreviewCalls, 1, "EndCompanionItemPreview calls EndCurrentItemPreview")

local function hasAction(actions, id)
    for _, action in ipairs(actions) do
        if action.id == id then
            return true
        end
    end
    return false
end

-- BuildActionList includes preview for eligible equipped companion items.
previewEligible = true
local equippedActions = Companions.BuildActionList({
    dataSource = { bagId = 9, slotIndex = 3, isEquipped = true, stackCount = 1 },
})
assert_true(hasAction(equippedActions, "preview"), "action list includes preview for eligible equipped item")
assert_true(hasAction(equippedActions, "unequip"), "action list still includes unequip for equipped item")

-- BuildActionList includes preview for eligible backpack companion items.
local backpackActions = Companions.BuildActionList({
    dataSource = { bagId = 1, slotIndex = 5, isEquipped = false, stackCount = 1 },
})
assert_true(hasAction(backpackActions, "preview"), "action list includes preview for eligible backpack item")
assert_true(hasAction(backpackActions, "equip"), "action list still includes equip for backpack item")

-- BuildActionList omits preview when the engine says the slot cannot be previewed.
previewEligible = false
local ineligibleActions = Companions.BuildActionList({
    dataSource = { bagId = 1, slotIndex = 5, isEquipped = false, stackCount = 1 },
})
assert_eq(hasAction(ineligibleActions, "preview"), false, "action list omits preview for ineligible item")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
