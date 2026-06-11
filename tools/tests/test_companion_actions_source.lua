--[[
File: tools/tests/test_companion_actions_source.lua
Purpose: Source-level regression checks for companion item action seams.

Usage:
  lua tools/tests/test_companion_actions_source.lua
]]

if false then
    dofile("Modules/Companions/Actions/CompanionActions.lua")
    dofile("Modules/Companions/Dialogs/CompanionDialogs.lua")
end

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local source = read_file("Modules/Companions/Actions/CompanionActions.lua")
local dialogSource = read_file("Modules/Companions/Dialogs/CompanionDialogs.lua")

assert_true(source:find("function Companions%.ResolveCompanionEquipSlot%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes ResolveCompanionEquipSlot")
assert_true(source:find("function Companions%.CanExecuteAction%(actionId, selectedData%)") ~= nil,
    "CompanionActions exposes CanExecuteAction")
assert_true(source:find("function Companions%.TryEquipCompanionItem%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes TryEquipCompanionItem")
assert_true(source:find("function Companions%.TryUnequipCompanionItem%(slotIndex%)") ~= nil,
    "CompanionActions exposes TryUnequipCompanionItem")
assert_true(source:find("function Companions%.ToggleCompanionItemLock%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes ToggleCompanionItemLock")
assert_true(source:find("function Companions%.ToggleCompanionItemJunk%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes ToggleCompanionItemJunk")
assert_true(source:find("function Companions%.BuildActionList%(selectedData%)") ~= nil,
    "CompanionActions exposes BuildActionList")
assert_true(source:find("function Companions%.ExecuteAction%(actionId, selectedData%)") ~= nil,
    "CompanionActions exposes ExecuteAction")
assert_true(source:find("local function GetProtectionPolicy%(%s*%)") ~= nil,
    "CompanionActions resolves ProtectionPolicy through an accessor seam")
assert_true(source:find("local ProtectionPolicy = BETTERUI%.CIM and BETTERUI%.CIM%.ProtectionPolicy") == nil,
    "CompanionActions avoids import-time ProtectionPolicy snapshots")
assert_true(source:find("local function RequireProtectionPolicyMethod%(methodName%)") ~= nil,
    "CompanionActions centralizes required policy-method resolution")
assert_true(source:find('RequireProtectionPolicyMethod%("CanLockItem"%)') ~= nil,
    "Companion lock actions consult the shared protection policy")
assert_true(source:find('RequireProtectionPolicyMethod%("CanJunkItem"%)') ~= nil,
    "Companion junk actions consult the shared protection policy")
assert_true(source:find('RequireProtectionPolicyMethod%("CanUnjunkItem"%)') ~= nil,
    "Companion unjunk actions consult the shared protection policy")
assert_true(source:find("return not policy or policy.CanLockItem", 1, true) == nil,
    "Companion lock actions no longer fail open when ProtectionPolicy is missing")
assert_true(source:find("return not policy or policy.CanUnlockItem", 1, true) == nil,
    "Companion unlock actions no longer fail open when ProtectionPolicy is missing")
assert_true(source:find("return not policy or policy.CanJunkItem", 1, true) == nil,
    "Companion junk actions no longer fail open when ProtectionPolicy is missing")
assert_true(source:find("return not policy or policy.CanUnjunkItem", 1, true) == nil,
    "Companion unjunk actions no longer fail open when ProtectionPolicy is missing")
assert_true(source:find("BETTERUI%.Inventory and BETTERUI%.Inventory%.CanDestroyItemWithPolicy") == nil,
    "Companion destroy checks no longer bounce through Inventory destroy-policy wrappers")
assert_true(source:find('RequireProtectionPolicyMethod%("CanDestroyItem"%)') ~= nil,
    "Companion destroy checks use the canonical required protection-policy seam")
assert_true(source:find("local function RequireInventoryDestroyExecutor%(%s*%)") ~= nil,
    "Companion quick-destroy resolves the inventory destroy executor through an explicit seam")
assert_true(source:find("inventory and inventory%.TryDestroyItem") ~= nil,
    "Companion quick-destroy delegates to the canonical inventory destroy executor")
assert_true(source:find('table.insert%(actions, %{%s*id = "equip", name = GetString%(SI_ITEM_ACTION_EQUIP%) %}%)') ~= nil,
    "CompanionActions offers equip action entries")
assert_true(source:find('table.insert%(actions, %{%s*id = "destroy", name = GetString%(SI_ITEM_ACTION_DESTROY%) %}%)') ~= nil,
    "CompanionActions offers destroy action entries")
assert_true(source:find('elseif actionId == "split" then') ~= nil
        and source:find("Companions%.ShowCompanionSplitStackDialog%(bagId, slotIndex%)") ~= nil,
    "CompanionActions routes split actions through the split-stack dialog helper")
assert_true(dialogSource:find("Companions%.ExecuteAction%(actionId, itemData%)") ~= nil,
    "Companion batch dialog routes protected batch actions through CompanionActions")
assert_true(source:find("TWO_HANDED_WEAPON_TYPES") ~= nil,
    "ResolveCompanionEquipSlot classifies two-handed weapon types")
assert_true(source:find("IsLockedWeaponSlot and IsLockedWeaponSlot%(equipSlot%)") ~= nil,
    "ResolveCompanionEquipSlot skips locked weapon slots")
assert_true(source:find("isTwoHanded and equipSlot ~= EQUIP_SLOT_MAIN_HAND") ~= nil,
    "ResolveCompanionEquipSlot restricts two-handed weapons to MAIN_HAND")
assert_true(source:find("BETTERUI_COMPANIONS_CONFIRM_EQUIP_BOE") ~= nil,
    "CompanionActions registers a local BoE confirm dialog fallback")
assert_true(source:find("FindFirstEmptySlotInBag%(BAG_BACKPACK%)") ~= nil,
    "TryUnequipCompanionItem finds the destination slot via FindFirstEmptySlotInBag")
assert_true(source:find("GetNumBagFreeSlots%(BAG_BACKPACK%)") == nil,
    "TryUnequipCompanionItem avoids redundant GetNumBagFreeSlots pre-check")

if failed > 0 then
    error(string.format("test_companion_actions_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_companion_actions_source.lua: %d passed", passed))
