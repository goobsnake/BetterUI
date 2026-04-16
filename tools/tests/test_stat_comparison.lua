--[[
File: tools/tests/test_stat_comparison.lua
Purpose: Unit tests for the StatComparison engine.
         Tests public API: Compare() and FormatForTooltip().

Usage:
  lua tools/tests/test_stat_comparison.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { Inventory = {}, CIM = {} }

-- ESO equip type constants
EQUIP_TYPE_INVALID = 0
EQUIP_TYPE_HEAD = 1
EQUIP_TYPE_CHEST = 2
EQUIP_TYPE_SHOULDERS = 3
EQUIP_TYPE_WAIST = 4
EQUIP_TYPE_LEGS = 5
EQUIP_TYPE_FEET = 6
EQUIP_TYPE_HAND = 7
EQUIP_TYPE_NECK = 8
EQUIP_TYPE_RING = 9
EQUIP_TYPE_MAIN_HAND = 10
EQUIP_TYPE_TWO_HAND = 11
EQUIP_TYPE_OFF_HAND = 12
EQUIP_TYPE_ONE_HAND = 13

-- ESO equip slot constants
EQUIP_SLOT_HEAD = 0
EQUIP_SLOT_CHEST = 2
EQUIP_SLOT_SHOULDERS = 3
EQUIP_SLOT_WAIST = 9
EQUIP_SLOT_LEGS = 8
EQUIP_SLOT_FEET = 7
EQUIP_SLOT_HAND = 4
EQUIP_SLOT_NECK = 1
EQUIP_SLOT_RING1 = 6
EQUIP_SLOT_MAIN_HAND = 5
EQUIP_SLOT_OFF_HAND = 15

-- Weapon type constants
WEAPONTYPE_NONE = 0
WEAPONTYPE_SWORD = 1
ITEM_TRAIT_TYPE_NONE = 0

BAG_WORN = 0
BAG_COMPANION_WORN = 1

-- ============================================================================
-- ITEM DATABASE (mock inventory)
-- ============================================================================

local itemDB = {
    ["iron_helm"] = {
        equipType = EQUIP_TYPE_HEAD,
        armorRating = 100,
        weaponType = WEAPONTYPE_NONE,
        weaponPower = 0,
        quality = 2,
        level = 10,
        itemId = 1001,
        enchant = nil,
        setName = nil,
    },
    ["steel_helm"] = {
        equipType = EQUIP_TYPE_HEAD,
        armorRating = 150,
        weaponType = WEAPONTYPE_NONE,
        weaponPower = 0,
        quality = 3,
        level = 20,
        itemId = 1002,
        enchant = "Health Enchant",
        setName = "Hunding's Rage",
    },
    ["iron_sword"] = {
        equipType = EQUIP_TYPE_MAIN_HAND,
        armorRating = 0,
        weaponType = WEAPONTYPE_SWORD,
        weaponPower = 200,
        quality = 2,
        level = 10,
        itemId = 2001,
        enchant = "Fire Damage",
        setName = nil,
    },
    ["steel_sword"] = {
        equipType = EQUIP_TYPE_MAIN_HAND,
        armorRating = 0,
        weaponType = WEAPONTYPE_SWORD,
        weaponPower = 300,
        quality = 3,
        level = 20,
        itemId = 2002,
        enchant = "Shock Damage",
        setName = "Mother's Sorrow",
    },
    ["greatsword"] = {
        equipType = EQUIP_TYPE_TWO_HAND,
        armorRating = 0,
        weaponType = WEAPONTYPE_SWORD,
        weaponPower = 400,
        quality = 3,
        level = 25,
        itemId = 2003,
        enchant = nil,
        setName = nil,
    },
    ["offhand_dagger"] = {
        equipType = EQUIP_TYPE_OFF_HAND,
        armorRating = 0,
        weaponType = WEAPONTYPE_SWORD,
        weaponPower = 125,
        quality = 2,
        level = 18,
        itemId = 2004,
        enchant = nil,
        setName = nil,
    },
    ["ring"] = {
        equipType = EQUIP_TYPE_RING,
        armorRating = 0,
        weaponType = WEAPONTYPE_NONE,
        weaponPower = 0,
        quality = 4,
        level = 50,
        itemId = 3001,
        enchant = nil,
        setName = nil,
    },
    ["junk"] = {
        equipType = EQUIP_TYPE_INVALID,
        armorRating = 0,
        weaponType = WEAPONTYPE_NONE,
        weaponPower = 0,
        quality = 0,
        level = 1,
        itemId = 9999,
        enchant = nil,
        setName = nil,
    },
}

-- Equipped items (keyed by equip slot)
local equippedItems = {}
local companionEquippedItems = {}

local function getItemData(link)
    return link and itemDB[link]
end

-- ESO API stubs
function GetItemLinkEquipType(link)
    local data = getItemData(link)
    return data and data.equipType or EQUIP_TYPE_INVALID
end

function GetItemLink(bagId, slotIndex)
    if bagId == BAG_WORN then
        return equippedItems[slotIndex] or ""
    end
    if bagId == BAG_COMPANION_WORN then
        return companionEquippedItems[slotIndex] or ""
    end
    return ""
end

function GetItemLinkItemId(link)
    local data = getItemData(link)
    return data and data.itemId or 0
end

-- Unique ID tracking for same-item detection
local uniqueIdCounter = 0
local assignedIds = {}
function GetItemUniqueId(bagId, slotIndex)
    local key = bagId .. "_" .. slotIndex
    if not assignedIds[key] then
        uniqueIdCounter = uniqueIdCounter + 1
        assignedIds[key] = uniqueIdCounter
    end
    return assignedIds[key]
end

function Id64ToString(id) return tostring(id) end

function GetItemLinkArmorRating(link, _)
    local data = getItemData(link)
    return data and data.armorRating or 0
end

function GetItemLinkWeaponType(link)
    local data = getItemData(link)
    return data and data.weaponType or WEAPONTYPE_NONE
end

function GetItemLinkWeaponPower(link)
    local data = getItemData(link)
    return data and data.weaponPower or 0
end

function GetItemLinkDisplayQuality(link)
    local data = getItemData(link)
    return data and data.quality or 0
end

function GetItemLinkRequiredLevel(link)
    local data = getItemData(link)
    return data and data.level or 0
end

function GetItemLinkEnchantInfo(link)
    local data = getItemData(link)
    if data and data.enchant then
        return true, "|cFFFFFF" .. data.enchant .. "|r", data.enchant
    end
    return false, nil, ""
end

function GetItemLinkSetInfo(link)
    local data = getItemData(link)
    if data and data.setName then
        return true, "|cFFFFFF" .. data.setName .. "|r"
    end
    return false, nil
end

function GetString(stringId, ...)
    if type(stringId) == "string" then
        return stringId .. "_" .. tostring(select(1, ...))
    end
    return tostring(stringId)
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/Inventory/Core/StatComparison.lua")

local StatComparison = BETTERUI.Inventory.StatComparison

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assert_nil(value, message)
    assert_equal(nil, value, message)
end

local function assert_not_nil(value, message)
    if value ~= nil then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("    Expected: non-nil")
        print("    Actual:   nil")
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

local function assert_false(value, message)
    assert_equal(false, value, message)
end

local function reset()
    equippedItems = {}
    companionEquippedItems = {}
    assignedIds = {}
    uniqueIdCounter = 0
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== StatComparison Tests ===\n")

-- Test 1: Compare with nil link returns nil
print("Test: Compare with nil link")
reset()
assert_nil(StatComparison.Compare(nil, 1, 1), "nil link returns nil")

-- Test 2: Compare with empty link returns nil
print("\nTest: Compare with empty link")
reset()
assert_nil(StatComparison.Compare("", 1, 1), "empty link returns nil")

-- Test 3: Compare with non-equippable item returns nil
print("\nTest: Non-equippable item returns nil")
reset()
assert_nil(StatComparison.Compare("junk", 1, 1), "junk item returns nil")

-- Test 4: Compare with empty slot shows upgrade
print("\nTest: Empty slot shows upgrade")
reset()
local result = StatComparison.Compare("iron_helm", 1, 1)
assert_not_nil(result, "result returned for empty slot")
assert_equal(EQUIP_SLOT_HEAD, result.equipSlot, "correct equip slot")
assert_true(result.isUpgrade, "marked as upgrade")
assert_nil(result.equippedLink, "no equipped item link")

-- Test 5: Armor upgrade shows positive delta
print("\nTest: Armor upgrade delta")
reset()
equippedItems[EQUIP_SLOT_HEAD] = "iron_helm"
result = StatComparison.Compare("steel_helm", 2, 1)
assert_not_nil(result, "comparison result returned")
assert_equal(50, result.deltas.armorRating, "armor delta = +50")
assert_equal(1, result.deltas.quality, "quality delta = +1")
assert_equal(10, result.deltas.level, "level delta = +10")
assert_true(result.isUpgrade, "identified as upgrade")

-- Test 6: Armor downgrade shows negative delta
print("\nTest: Armor downgrade delta")
reset()
equippedItems[EQUIP_SLOT_HEAD] = "steel_helm"
result = StatComparison.Compare("iron_helm", 2, 1)
assert_not_nil(result, "comparison result returned")
assert_equal(-50, result.deltas.armorRating, "armor delta = -50")
assert_equal(-1, result.deltas.quality, "quality delta = -1")
assert_false(result.isUpgrade, "not identified as upgrade")

-- Test 7: Weapon comparison
print("\nTest: Weapon comparison")
reset()
equippedItems[EQUIP_SLOT_MAIN_HAND] = "iron_sword"
result = StatComparison.Compare("steel_sword", 2, 1)
assert_not_nil(result, "weapon comparison result returned")
assert_equal(100, result.deltas.weaponDamage, "weapon damage delta = +100")
assert_true(result.isUpgrade, "weapon upgrade identified")

-- Test 8: Set bonus change detected
print("\nTest: Set bonus detection")
reset()
equippedItems[EQUIP_SLOT_MAIN_HAND] = "iron_sword"
result = StatComparison.Compare("steel_sword", 2, 1)
assert_not_nil(result, "result has set info")
assert_equal("Mother's Sorrow", result.candidateSet, "candidate set name")
assert_nil(result.equippedSet, "equipped has no set")

-- Test 9: Enchantment detection
print("\nTest: Enchantment detection")
reset()
equippedItems[EQUIP_SLOT_HEAD] = "iron_helm"
result = StatComparison.Compare("steel_helm", 2, 1)
assert_equal("Health Enchant", result.candidateEnchant, "candidate enchant detected")
assert_nil(result.equippedEnchant, "equipped has no enchant")

-- Test 10: FormatForTooltip with nil result
print("\nTest: FormatForTooltip with nil")
reset()
assert_equal("", StatComparison.FormatForTooltip(nil), "nil result returns empty string")

-- Test 11: FormatForTooltip with empty lines
print("\nTest: FormatForTooltip with result")
reset()
equippedItems[EQUIP_SLOT_HEAD] = "iron_helm"
result = StatComparison.Compare("steel_helm", 2, 1)
local formatted = StatComparison.FormatForTooltip(result)
assert_not_nil(formatted, "formatted text is not nil")
assert_true(#formatted > 0, "formatted text has content")

-- Test 12: Ring equip type maps correctly
print("\nTest: Ring equip slot mapping")
reset()
result = StatComparison.Compare("ring", 2, 1)
assert_not_nil(result, "ring comparison returns result")
assert_equal(EQUIP_SLOT_RING1, result.equipSlot, "ring maps to RING1 slot")

-- Test 13: Display lines contain color codes
print("\nTest: Display lines contain color formatting")
reset()
equippedItems[EQUIP_SLOT_HEAD] = "iron_helm"
result = StatComparison.Compare("steel_helm", 2, 1)
local hasColorCode = false
for _, line in ipairs(result.lines) do
    if line:find("|c") then
        hasColorCode = true
        break
    end
end
assert_true(hasColorCode, "display lines contain color codes")

-- Test 14: Companion equip bag uses BAG_COMPANION_WORN for comparisons
print("\nTest: Companion equip bag comparison")
reset()
companionEquippedItems[EQUIP_SLOT_MAIN_HAND] = "iron_sword"
result = StatComparison.Compare("steel_sword", 2, 1, BAG_COMPANION_WORN)
assert_not_nil(result, "companion comparison returns result")
assert_equal("iron_sword", result.equippedLink, "companion equipped item used")
assert_equal(100, result.deltas.weaponDamage, "companion weapon damage delta = +100")

-- Test 15: Companion equip bag empty slot reports upgrade
print("\nTest: Companion equip bag empty slot")
reset()
result = StatComparison.Compare("iron_helm", 2, 1, BAG_COMPANION_WORN)
assert_not_nil(result, "companion empty slot returns result")
assert_true(result.isUpgrade, "companion empty slot is upgrade")
assert_nil(result.equippedLink, "companion empty slot has no equipped link")

-- Test 16: Off-hand compare suppressed when a two-handed weapon blocks the slot
print("\nTest: Two-handed main hand blocks off-hand comparison")
reset()
equippedItems[EQUIP_SLOT_MAIN_HAND] = "greatsword"
result = StatComparison.Compare("offhand_dagger", 2, 1)
assert_nil(result, "off-hand compare returns nil when a two-handed main hand blocks the slot")

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))

if tests_failed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
