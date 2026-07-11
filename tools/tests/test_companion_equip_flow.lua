local moves = {}
local shownDialog = nil
local shownPlatformDialog = nil
local registeredBoeDialog = nil
local currentEquipType = nil
local currentIdentity = "item-a"
local willBind = false

EQUIP_TYPE_INVALID = 0
EQUIP_TYPE_ONE_HAND = 1
EQUIP_TYPE_TWO_HAND = 2
EQUIP_TYPE_MAIN_HAND = 3
EQUIP_TYPE_OFF_HAND = 4
EQUIP_TYPE_RING = 5
EQUIP_SLOT_MAIN_HAND = 10
EQUIP_SLOT_OFF_HAND = 11
EQUIP_SLOT_RING1 = 12
EQUIP_SLOT_RING2 = 13
EQUIP_SLOT_CHEST = 14
BAG_COMPANION_WORN = 20
GAMEPLAY_ACTOR_CATEGORY_COMPANION = 30
GAMEPAD_DIALOGS = { BASIC = 1 }
SI_DIALOG_CONFIRM_BINDING_ITEM_TITLE = "bind-title"
SI_DIALOG_CONFIRM_EQUIPPING_ITEM_BODY = "bind-body"
SI_DIALOG_ACCEPT = "accept"
SI_DIALOG_CANCEL = "cancel"

BETTERUI = {
    Companions = {
        GetSetting = function() return true end,
    },
    CIM = {
        ProtectionPolicy = {},
        UserNotify = function() end,
        Dialogs = {
            GetCurrentInfo = function() return registeredBoeDialog end,
            Register = function(_, info)
                registeredBoeDialog = info
                return true
            end,
        },
    },
}

GetItemEquipType = function() return currentEquipType end
GetItemUniqueId = function() return currentIdentity end
GetItemActorCategory = function() return GAMEPLAY_ACTOR_CATEGORY_COMPANION end
GetItemLink = function() return "|H1:item:test|h|h" end
AreId64sEqual = function(left, right) return left == right end
IsLockedWeaponSlot = function() return false end
ZO_Character_DoesEquipSlotUseEquipType = function(slot, equipType)
    if equipType == EQUIP_TYPE_ONE_HAND then
        return slot == EQUIP_SLOT_MAIN_HAND or slot == EQUIP_SLOT_OFF_HAND
    elseif equipType == EQUIP_TYPE_TWO_HAND or equipType == EQUIP_TYPE_MAIN_HAND then
        return slot == EQUIP_SLOT_MAIN_HAND
    elseif equipType == EQUIP_TYPE_OFF_HAND then
        return slot == EQUIP_SLOT_OFF_HAND
    elseif equipType == EQUIP_TYPE_RING then
        return slot == EQUIP_SLOT_RING1 or slot == EQUIP_SLOT_RING2
    end
    return slot == EQUIP_SLOT_CHEST
end
ZO_Character_EnumerateOrderedEquipSlots = function()
    local slots = {
        EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND,
        EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_CHEST,
    }
    local index = 0
    return function()
        index = index + 1
        if slots[index] then return index, slots[index] end
    end
end
HasItemInSlot = function(_, slot) return slot == EQUIP_SLOT_RING1 end
ZO_InventorySlot_WillItemBecomeBoundOnEquip = function() return willBind end
RequestMoveItem = function(sourceBag, sourceSlot, destinationBag, destinationSlot, quantity)
    moves[#moves + 1] = {
        sourceBag, sourceSlot, destinationBag, destinationSlot, quantity,
    }
end
CallSecureProtected = function(functionName, ...)
    assert(functionName == "RequestMoveItem", "companion flow uses the expected protected move")
    RequestMoveItem(...)
    return true
end
ZO_Dialogs_ShowPlatformDialog = function(name, data)
    shownPlatformDialog = { name = name, data = data }
end

dofile("Modules/Companions/Actions/CompanionActions.lua")

BETTERUI.Companions.ShowCompanionEquipSlotDialog = function(bagId, slotIndex, equipSlots, expectedIdentity)
    shownDialog = {
        bagId = bagId,
        slotIndex = slotIndex,
        equipSlots = equipSlots,
        expectedIdentity = expectedIdentity,
    }
    return true
end

currentEquipType = EQUIP_TYPE_ONE_HAND
local choices = BETTERUI.Companions.GetCompanionEquipSlotChoices(1, 2)
assert(#choices == 2, "one-handed companion weapons expose both primary hand choices")
assert(choices[1] == EQUIP_SLOT_MAIN_HAND and choices[2] == EQUIP_SLOT_OFF_HAND,
    "one-handed choices are ordered main hand then off hand")
assert(BETTERUI.Companions.ResolveCompanionEquipSlot(1, 2) == nil,
    "ambiguous one-handed weapons never silently resolve a hand")

assert(BETTERUI.Companions.TryEquipCompanionItem(1, 2) == true,
    "one-handed equip opens the hand-choice dialog")
assert(shownDialog and #shownDialog.equipSlots == 2, "hand-choice dialog receives both slots")
assert(#moves == 0, "one-handed equip performs no move before user selection")

assert(BETTERUI.Companions.TryEquipCompanionItemToSlot(
    1, 2, EQUIP_SLOT_OFF_HAND, shownDialog.expectedIdentity) == true,
    "off-hand dialog selection requests the move")
assert(#moves == 1 and moves[1][4] == EQUIP_SLOT_OFF_HAND,
    "off-hand selection moves exactly once to the companion off hand")

currentIdentity = "item-b"
assert(BETTERUI.Companions.TryEquipCompanionItemToSlot(
    1, 2, EQUIP_SLOT_MAIN_HAND, "item-a") == false,
    "stale dialog identity fails closed")
assert(#moves == 1, "stale dialog identity performs no move")

currentEquipType = EQUIP_TYPE_TWO_HAND
assert(BETTERUI.Companions.TryEquipCompanionItem(1, 2) == true,
    "two-handed companion weapons equip directly")
assert(#moves == 2 and moves[2][4] == EQUIP_SLOT_MAIN_HAND,
    "two-handed weapons target only companion main hand")

currentEquipType = EQUIP_TYPE_OFF_HAND
assert(BETTERUI.Companions.TryEquipCompanionItem(1, 2) == true,
    "off-hand-only equipment equips directly")
assert(#moves == 3 and moves[3][4] == EQUIP_SLOT_OFF_HAND,
    "off-hand-only equipment targets companion off hand")

currentEquipType = EQUIP_TYPE_RING
shownDialog = nil
assert(BETTERUI.Companions.TryEquipCompanionItem(1, 2) == true,
    "multi-slot non-weapon equipment resolves without a hand-choice dialog")
assert(shownDialog == nil, "ring equipment does not reuse the dual-wield hand chooser")
assert(#moves == 4 and moves[4][4] == EQUIP_SLOT_RING2,
    "ring equipment prefers the first empty compatible companion slot")

currentEquipType = EQUIP_TYPE_ONE_HAND
currentIdentity = "item-c"
willBind = true
assert(BETTERUI.Companions.TryEquipCompanionItemToSlot(
    1, 2, EQUIP_SLOT_OFF_HAND, currentIdentity) == true,
    "BoE companion equip opens its confirmation dialog")
assert(shownPlatformDialog and registeredBoeDialog,
    "BoE confirmation captures the selected hand and item identity")
currentIdentity = "item-d"
assert(registeredBoeDialog.buttons[1].callback({ data = shownPlatformDialog.data }) == false,
    "BoE acceptance fails closed when the source slot changed")
assert(#moves == 4, "stale BoE acceptance performs no protected move")

print("test_companion_equip_flow.lua: OK")
