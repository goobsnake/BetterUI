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
assert_true(source:find("function Companions%.TryUnequipCompanionItem%(bagId, slotIndex%)") ~= nil,
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
assert_true(dialogSource:find("local actionExecuted = Companions%.ExecuteAction%(") ~= nil
        and dialogSource:find("return actionExecuted") ~= nil,
    "Companion action dialog propagates the selected action result")
assert_true(source:find("TWO_HANDED_WEAPON_TYPES", 1, true) == nil,
    "Companion equip routing uses canonical equip types instead of a weapon allowlist")
assert_true(source:find("function Companions%.GetCompanionEquipSlotChoices%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes explicit equip-slot choices")
assert_true(source:find("candidates = %{ EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND %}") ~= nil,
    "One-handed companion weapons expose main and off-hand choices")
assert_true(source:find("equipType == EQUIP_TYPE_TWO_HAND or equipType == EQUIP_TYPE_MAIN_HAND") ~= nil,
    "Two-handed and main-hand-only equipment target main hand")
assert_true(source:find("elseif equipType == EQUIP_TYPE_OFF_HAND then") ~= nil,
    "Off-hand-only equipment targets off hand")
assert_true(source:find("IsLockedWeaponSlot and IsLockedWeaponSlot%(equipSlot%)") ~= nil,
    "Companion equip choices skip locked weapon slots")
assert_true(source:find("function Companions%.IsCompanionItemIdentityCurrent") ~= nil,
    "Delayed companion dialogs revalidate source identity")
assert_true(source:find("function Companions%.CaptureCompanionItemIdentity") ~= nil,
    "Action dialogs can capture companion item identity before opening")
assert_true(source:find("expectedIdentity = expectedIdentity or Companions%.CaptureCompanionItemIdentity") ~= nil,
    "Explicit-slot equip captures identity before any dialog")
assert_true(source:find("BETTERUI_COMPANIONS_CONFIRM_EQUIP_BOE") ~= nil,
    "CompanionActions registers a local BoE confirm dialog fallback")
assert_true(source:find('"CONFIRM_EQUIP_BOE"', 1, true) == nil,
    "TryEquipCompanionItem no longer probes the nonexistent native CONFIRM_EQUIP_BOE dialog")
assert_true(source:find("ZO_Dialogs_ShowPlatformDialog%(COMPANION_CONFIRM_EQUIP_BOE_DIALOG") ~= nil,
    "TryEquipCompanionItemToSlot shows the custom BoE dialog")
assert_true(source:find('"RequestEquipItem", rawget%(_G, "RequestEquipItem"%), false') ~= nil,
    "Companion equip uses ESO's public actor-aware equipment request")
assert_true(source:find('"RequestMoveItem", rawget%(_G, "RequestMoveItem"%)') == nil,
    "Companion equip never calls the private RequestMoveItem API from addon code")
assert_true(source:find('"RequestUnequipItem", rawget%(_G, "RequestUnequipItem"%), false') ~= nil,
    "Companion unequip uses ESO's dedicated request with runtime protection detection")
assert_true(source:find("IsProtectedFunction%(functionName%)") ~= nil,
    "Companion request dispatch detects the live ESO protected-function contract")
assert_true(source:find("CallSecureProtected%(functionName") ~= nil,
    "Protected companion requests route through CallSecureProtected")
assert_true(source:find('"SetItemIsPlayerLocked", rawget%(_G, "SetItemIsPlayerLocked"%)') ~= nil,
    "Companion lock mutations use the runtime protected-function route")
assert_true(source:find('reason = "unsupportedCompanionActor"') ~= nil,
    "Companion junk actions fail closed because ESO suppresses them")
assert_true(source:find("local firstCompatibleSlot") ~= nil,
    "Non-weapon companion equipment resolves a deterministic compatible slot")
assert_true(source:find('id = "sort"', 1, true) ~= nil,
    "Companion action menu exposes intentional header-sort entry")
assert_true(source:find('Companions.RequestHeaderSortAfterDialog()', 1, true) ~= nil,
    "Companion sort action defers header ownership until its action dialog closes")

if failed > 0 then
    error(string.format("test_companion_actions_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_companion_actions_source.lua: %d passed", passed))
