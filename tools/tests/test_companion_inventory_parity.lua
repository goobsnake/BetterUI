local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function assert_contains(source, needle, message)
    assert(source:find(needle, 1, true), message .. "\nMissing: " .. needle)
end

local function assert_not_contains(source, needle, message)
    assert(not source:find(needle, 1, true), message .. "\nUnexpected: " .. needle)
end

local classSource = read_file("Modules/Companions/Core/CompanionsClass.lua")
local runtimeSource = read_file("Modules/Companions/Core/CompanionsRuntime.lua")
local listSource = read_file("Modules/Companions/Core/CompanionListManager.lua")
local itemListSource = read_file("Modules/Companions/Core/CompanionItemList.lua")
local actionSource = read_file("Modules/Companions/Actions/CompanionActions.lua")
local dialogSource = read_file("Modules/Companions/Dialogs/CompanionDialogs.lua")
local snapshotSource = read_file("Modules/CIM/Core/Diagnostics/LayoutSnapshot.lua")
local companionXml = read_file("Modules/Companions/Templates/GamepadCompanionInventory.xml")

assert_contains(companionXml, 'inherits="BETTERUI_Gamepad_ParametricList_Screen"',
    "Companions materialize the same screen shell as Inventory")
assert_contains(classSource, "BETTERUI.CIM.UnifiedFooter.MODE.CURRENCY",
    "Companions use the Inventory currency footer mode")
assert_contains(classSource, 'local mainHasItem, mainIcon = GetWornItemInfo(BAG_COMPANION_WORN, EQUIP_SLOT_MAIN_HAND)',
    "Companion header distinguishes an empty main-hand slot")
assert_contains(classSource, 'local offHasItem, offIcon = GetWornItemInfo(BAG_COMPANION_WORN, EQUIP_SLOT_OFF_HAND)',
    "Companion header distinguishes an empty off-hand slot")
assert_contains(classSource, "ZO_Character_GetEmptyEquipSlotTexture(equipSlot)",
    "Empty Companion weapon slots use ESO's slot-specific empty artwork")
assert_contains(classSource, 'EsoUI/Art/CharacterWindow/gearSlot_mainHand.dds',
    "Companion main-hand empty artwork has a guarded fallback")
assert_contains(classSource, 'EsoUI/Art/CharacterWindow/gearSlot_offHand.dds',
    "Companion off-hand empty artwork has a guarded fallback")
assert_not_contains(classSource, 'EMPTY_EQUIPMENT_SLOT_TEXTURE',
    "Companion empty weapon slots do not reuse the question-mark texture")
assert_contains(classSource, "function BETTERUI.Companions.Class:RefreshCompanionWeaponHeader()",
    "Companions own a primary weapon header refresh")
assert_contains(classSource, "GetWornItemInfo(BAG_COMPANION_WORN, EQUIP_SLOT_MAIN_HAND)",
    "Companion main-hand header icon comes from the companion worn bag")
assert_contains(classSource, "GetWornItemInfo(BAG_COMPANION_WORN, EQUIP_SLOT_OFF_HAND)",
    "Companion off-hand header icon comes from the companion worn bag")
assert_contains(classSource, 'SetCompanionHeaderControlHidden("BackupEquipText", true)',
    "Companion backup weapon label is hidden")
assert_contains(classSource, 'SetCompanionHeaderControlHidden("BackupMainHandIcon", true)',
    "Companion backup main-hand box is hidden")
assert_contains(classSource, 'SetCompanionHeaderControlHidden("PoisonIcon", true)',
    "Companion poison box is hidden")
assert_not_contains(classSource, 'GetNamedChild("Withdraw")',
    "Companions no longer repurpose Banking footer controls")
assert_not_contains(classSource, 'GetNamedChild("Deposit")',
    "Companions no longer repurpose Banking footer controls")

assert_contains(runtimeSource, "BUI_GpCmp, BETTERUI_COMPANION_EQUIP_SCENE_NAME",
    "Companion Inventory runtime consumes the XML-created control")
assert_contains(snapshotSource, 'companions = { globals = { "BUI_GpCmp" } }',
    "Layout snapshots resolve the new Companion Inventory shell")
assert_not_contains(runtimeSource, "SetupCompanionRow",
    "Companion rows use Inventory's shared row setup without scene-specific offsets")
assert_contains(runtimeSource, "BETTERUI_SharedGamepadEntry_OnSetup,",
    "Companion rows use the exact Inventory shared row setup")
assert_not_contains(listSource, "AlignCompanionListToHeader",
    "Inventory XML owns Companion list positioning")
assert_contains(listSource, 'preset = "INVENTORY"',
    "Companion search placement uses the Inventory preset")
assert_contains(listSource, "local carouselMissing = tabBar.keybindStripDescriptor",
    "Companion search exit detects a stale LB/RB carousel group")
assert_contains(listSource, "tabBar:Deactivate()",
    "Companion search exit resets a stale active carousel before reactivation")
assert_not_contains(listSource, "startOffset = COMPANION_CAROUSEL_START_OFFSET",
    "Companion category carousel uses Inventory defaults")
assert_contains(itemListSource, "function BETTERUI.Companions.Class:RefreshList(options)",
    "Companion list refresh accepts explicit position-preservation intent")
assert_contains(itemListSource, "if options and options.preserveCurrentPosition",
    "Companion list saves its current category position before a same-category rebuild")
assert_contains(itemListSource, "self.list:Commit(true, true)",
    "Companion list commit does not transiently reselect the first row")
assert_contains(itemListSource, "SetSelectedIndexWithoutAnimation(targetIndex, true, false)",
    "Companion list restores selection without scrolling from the top")
assert_contains(listSource, 'BETTERUI.CIM.PositionManager.SavePosition("Companions", previousCategory.key, self.list)',
    "Companion carousel saves the outgoing category position before switching")

assert_contains(actionSource, "function Companions.GetCompanionEquipSlotChoices(bagId, slotIndex)",
    "Companion actions expose explicit primary weapon slot choices")
assert_contains(actionSource, "function Companions.TryEquipCompanionItemToSlot(bagId, slotIndex, equipSlot, expectedIdentity)",
    "Companion actions expose a secure explicit-slot equip path")
assert_contains(actionSource, "Companions.ShowCompanionEquipSlotDialog(",
    "Ambiguous dual-wield weapons open the slot-choice dialog")
assert_contains(dialogSource, 'local COMPANION_EQUIP_SLOT_DIALOG = "BETTERUI_COMPANION_EQUIP_SLOT_DIALOG"',
    "Companion dialogs register a dedicated dual-wield slot chooser")
assert_contains(dialogSource, "Companions.TryEquipCompanionItemToSlot(",
    "Slot-choice confirmation performs the secure move in the dialog hardware-event callback")
assert_contains(dialogSource, "RestoreCompanionDialogKeybindOwnership",
    "Slot-choice dialog restores Companion focus and keybind ownership")

print("test_companion_inventory_parity.lua: OK")
