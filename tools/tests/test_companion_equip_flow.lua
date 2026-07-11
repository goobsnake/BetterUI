local equipmentRequests = {}
local shownDialog = nil
local shownPlatformDialog = nil
local registeredBoeDialog = nil
local currentEquipType = nil
local currentIdentity = "item-a"
local willBind = false
local notificationCount = 0
local secureCalls = {}
local itemLocked = false
local itemJunk = false

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
        ProtectionPolicy = {
            CanLockItem = function() return true end,
            CanUnlockItem = function() return true end,
            CanJunkItem = function() return true end,
            CanUnjunkItem = function() return true end,
        },
        UserNotify = function()
            notificationCount = notificationCount + 1
        end,
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
HasItemInSlot = function(bag, slot)
    if bag == BAG_COMPANION_WORN then
        return slot == EQUIP_SLOT_RING1 or slot == EQUIP_SLOT_CHEST
    end
    return slot == EQUIP_SLOT_RING1
end
ZO_InventorySlot_WillItemBecomeBoundOnEquip = function() return willBind end
RequestMoveItem = function(...)
    equipmentRequests[#equipmentRequests + 1] = { "RequestMoveItem", ... }
end
RequestUnequipItem = function(...)
    equipmentRequests[#equipmentRequests + 1] = { "RequestUnequipItem", ... }
end
RequestEquipItem = function(...)
    equipmentRequests[#equipmentRequests + 1] = { "RequestEquipItem", ... }
end
IsProtectedFunction = function(functionName)
    return functionName == "RequestMoveItem"
        or functionName == "RequestUnequipItem"
        or functionName == "SetItemIsPlayerLocked"
        or functionName == "SetItemIsJunk"
end
CallSecureProtected = function(functionName, ...)
    secureCalls[#secureCalls + 1] = functionName
    if functionName == "RequestMoveItem" and type(RequestMoveItem) == "function" then
        RequestMoveItem(...)
    elseif functionName == "RequestUnequipItem" and type(RequestUnequipItem) == "function" then
        RequestUnequipItem(...)
    elseif functionName == "SetItemIsPlayerLocked" then
        SetItemIsPlayerLocked(...)
    elseif functionName == "SetItemIsJunk" then
        SetItemIsJunk(...)
    else
        return false
    end
    return true
end
IsItemPlayerLocked = function() return itemLocked end
SetItemIsPlayerLocked = function(_, _, locked) itemLocked = locked end
IsItemJunk = function() return itemJunk end
SetItemIsJunk = function(_, _, junk) itemJunk = junk end
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
assert(#equipmentRequests == 0, "one-handed equip performs no request before user selection")

assert(BETTERUI.Companions.TryEquipCompanionItemToSlot(
    1, 2, EQUIP_SLOT_OFF_HAND, shownDialog.expectedIdentity) == true,
    "off-hand dialog selection requests the move")
assert(#equipmentRequests == 1
        and equipmentRequests[1][1] == "RequestEquipItem"
        and equipmentRequests[1][2] == 1
        and equipmentRequests[1][3] == 2
        and equipmentRequests[1][4] == BAG_COMPANION_WORN
        and equipmentRequests[1][5] == EQUIP_SLOT_OFF_HAND,
    "off-hand selection uses the public companion RequestEquipItem route")
assert(#secureCalls == 0,
    "companion equip never invokes the private RequestMoveItem API")
currentIdentity = "item-b"
assert(BETTERUI.Companions.TryEquipCompanionItemToSlot(
    1, 2, EQUIP_SLOT_MAIN_HAND, "item-a") == false,
    "stale dialog identity fails closed")
assert(#equipmentRequests == 1, "stale dialog identity performs no equipment request")

currentEquipType = EQUIP_TYPE_TWO_HAND
assert(BETTERUI.Companions.TryEquipCompanionItem(1, 2) == true,
    "two-handed companion weapons equip directly")
assert(#equipmentRequests == 2 and equipmentRequests[2][5] == EQUIP_SLOT_MAIN_HAND,
    "two-handed weapons target only companion main hand")

currentEquipType = EQUIP_TYPE_OFF_HAND
assert(BETTERUI.Companions.TryEquipCompanionItem(1, 2) == true,
    "off-hand-only equipment equips directly")
assert(#equipmentRequests == 3 and equipmentRequests[3][5] == EQUIP_SLOT_OFF_HAND,
    "off-hand-only equipment targets companion off hand")

currentEquipType = EQUIP_TYPE_RING
shownDialog = nil
assert(BETTERUI.Companions.TryEquipCompanionItem(1, 2) == true,
    "multi-slot non-weapon equipment resolves without a hand-choice dialog")
assert(shownDialog == nil, "ring equipment does not reuse the dual-wield hand chooser")
assert(#equipmentRequests == 4 and equipmentRequests[4][5] == EQUIP_SLOT_RING2,
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
assert(#equipmentRequests == 4, "stale BoE acceptance performs no protected equipment request")

assert(BETTERUI.Companions.TryUnequipCompanionItem(
    BAG_COMPANION_WORN, EQUIP_SLOT_CHEST) == true,
    "companion unequip submits the dedicated unequip request")
assert(#equipmentRequests == 5
        and equipmentRequests[5][1] == "RequestUnequipItem"
        and equipmentRequests[5][2] == BAG_COMPANION_WORN
        and equipmentRequests[5][3] == EQUIP_SLOT_CHEST,
    "companion unequip passes the worn bag and equipment slot")
assert(secureCalls[#secureCalls] == "RequestUnequipItem",
    "protected companion unequip is submitted through CallSecureProtected")

local savedRequestEquipItem = RequestEquipItem
local savedRequestUnequipItem = RequestUnequipItem
willBind = false
currentEquipType = EQUIP_TYPE_TWO_HAND
currentIdentity = "item-e"
RequestEquipItem = nil
local notificationsBefore = notificationCount
assert(BETTERUI.Companions.TryEquipCompanionItemToSlot(
    1, 2, EQUIP_SLOT_MAIN_HAND, currentIdentity) == false,
    "companion equip fails closed when the public equip request API is unavailable")
assert(notificationCount == notificationsBefore + 1,
    "missing companion equip API notifies the user")

RequestEquipItem = savedRequestEquipItem
RequestUnequipItem = nil
notificationsBefore = notificationCount
assert(BETTERUI.Companions.TryUnequipCompanionItem(
    BAG_COMPANION_WORN, EQUIP_SLOT_CHEST) == false,
    "companion unequip fails closed when the direct ESO request API is unavailable")
assert(notificationCount == notificationsBefore + 1,
    "missing companion unequip API notifies the user")
RequestUnequipItem = savedRequestUnequipItem

IsProtectedFunction = function() return false end
secureCalls = {}
equipmentRequests = {}
assert(BETTERUI.Companions.TryUnequipCompanionItem(
    BAG_COMPANION_WORN, EQUIP_SLOT_CHEST) == true,
    "unprotected companion unequip still uses the documented direct API")
assert(#secureCalls == 0 and equipmentRequests[1][1] == "RequestUnequipItem",
    "unprotected companion unequip avoids the protected-call wrapper")
assert(BETTERUI.Companions.TryUnequipCompanionItem(1, EQUIP_SLOT_CHEST) == false,
    "companion unequip rejects non-companion worn bags")
assert(BETTERUI.Companions.TryUnequipCompanionItem(
    BAG_COMPANION_WORN, EQUIP_SLOT_OFF_HAND) == false,
    "companion unequip rejects an empty worn slot")

IsProtectedFunction = function(functionName)
    return functionName == "SetItemIsPlayerLocked"
        or functionName == "SetItemIsJunk"
end
secureCalls = {}
assert(BETTERUI.Companions.ToggleCompanionItemLock(1, 2) == true and itemLocked == true,
    "companion lock changes the item state")
assert(secureCalls[1] == "SetItemIsPlayerLocked",
    "protected companion lock routes through CallSecureProtected")
assert(BETTERUI.Companions.ToggleCompanionItemJunk(1, 2) == false and itemJunk == false,
    "unsupported companion junk fails closed without fabricating a state change")
assert(secureCalls[2] == nil,
    "unsupported companion junk never invokes SetItemIsJunk")

print("test_companion_equip_flow.lua: OK")
