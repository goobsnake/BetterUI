--[[
File: Modules/Companions/Actions/CompanionActions.lua
Purpose: Companion item actions (equip, destroy, lock, junk, split) with BoE protection.
]]

if not BETTERUI.Companions then return end
local Companions = BETTERUI.Companions
local function GetProtectionPolicy()
    return BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy
end

local function CanDestroyItem(bagId, slotIndex)
    local policy = GetProtectionPolicy()
    return not policy or policy.CanDestroyItem(bagId, slotIndex)
end

local function CanLockItem(bagId, slotIndex)
    local policy = GetProtectionPolicy()
    return not policy or policy.CanLockItem(bagId, slotIndex)
end

local function CanUnlockItem(bagId, slotIndex)
    local policy = GetProtectionPolicy()
    return not policy or policy.CanUnlockItem(bagId, slotIndex)
end

local function CanJunkItem(bagId, slotIndex)
    local policy = GetProtectionPolicy()
    return not policy or policy.CanJunkItem(bagId, slotIndex)
end

local function CanUnjunkItem(bagId, slotIndex)
    local policy = GetProtectionPolicy()
    return not policy or policy.CanUnjunkItem(bagId, slotIndex)
end

local function SetCompanionItemLockState(bagId, slotIndex, locked)
    if SetItemIsPlayerLocked then
        SetItemIsPlayerLocked(bagId, slotIndex, locked)
        return true
    end
    if SetItemPlayerLocked then
        SetItemPlayerLocked(bagId, slotIndex, locked)
        return true
    end
    return false
end

local function ResolveCompanionActionTarget(selectedData)
    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    local bagId = ds and ds.bagId or nil
    local slotIndex = ds and ds.slotIndex or nil
    return ds, bagId, slotIndex
end

function Companions.CanExecuteAction(actionId, selectedData)
    local ds, bagId, slotIndex = ResolveCompanionActionTarget(selectedData)
    if actionId == "equip" then
        return ds ~= nil and bagId ~= nil and slotIndex ~= nil and not ds.isEquipped
    elseif actionId == "unequip" then
        return ds ~= nil and slotIndex ~= nil and ds.isEquipped == true
    elseif actionId == "destroy" then
        return CanDestroyItem(bagId, slotIndex)
    elseif actionId == "lock" then
        return CanLockItem(bagId, slotIndex)
    elseif actionId == "unlock" then
        return CanUnlockItem(bagId, slotIndex)
    elseif actionId == "junk" then
        return CanJunkItem(bagId, slotIndex)
    elseif actionId == "unjunk" then
        return CanUnjunkItem(bagId, slotIndex)
    elseif actionId == "split" then
        return ds ~= nil and (ds.stackCount or 1) > 1
    end
    return false
end

-- EQUIP

function Companions.ResolveCompanionEquipSlot(bagId, slotIndex)
    local equipType = GetItemEquipType and GetItemEquipType(bagId, slotIndex) or nil
    if equipType == nil or equipType == 0 or equipType == EQUIP_TYPE_INVALID then
        return nil
    end
    if not ZO_Character_EnumerateOrderedEquipSlots or not ZO_Character_DoesEquipSlotUseEquipType then
        return nil
    end
    local firstCompatibleSlot = nil
    for _, equipSlot in ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN) do
        if ZO_Character_DoesEquipSlotUseEquipType(equipSlot, equipType) then
            if not firstCompatibleSlot then
                firstCompatibleSlot = equipSlot
            end
            if not HasItemInSlot or not HasItemInSlot(BAG_COMPANION_WORN, equipSlot) then
                return equipSlot
            end
        end
    end
    return firstCompatibleSlot
end

local function DoEquipCompanionItem(bagId, slotIndex)
    local equipSlot = Companions.ResolveCompanionEquipSlot(bagId, slotIndex)
    if not equipSlot then return false end
    if CallSecureProtected then
        CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_COMPANION_WORN, equipSlot, 1)
        return true
    end
    return false
end

function Companions.TryEquipCompanionItem(bagId, slotIndex)
    if bagId == nil or slotIndex == nil then return false end
    if GetItemActorCategory and GetItemActorCategory(bagId, slotIndex) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        return false
    end
    local function DoEquip()
        return DoEquipCompanionItem(bagId, slotIndex)
    end
    if ZO_InventorySlot_WillItemBecomeBoundOnEquip and ZO_InventorySlot_WillItemBecomeBoundOnEquip(bagId, slotIndex) then
        if Companions.GetSetting("bindOnEquipProtection") ~= false then
            local itemLink = GetItemLink(bagId, slotIndex)
            ZO_Dialogs_ShowPlatformDialog("CONFIRM_EQUIP_BOE", { callback = DoEquip }, { mainTextParams = { itemLink } })
            return true
        end
    end
    return DoEquip()
end

function Companions.TryUnequipCompanionItem(slotIndex)
    if slotIndex == nil then return false end
    if not GetNumBagFreeSlots(BAG_BACKPACK) or GetNumBagFreeSlots(BAG_BACKPACK) == 0 then
        BETTERUI.CIM.UserAlertText("Companions:BagFull",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY") or "SI_BETTERUI_VENDOR_CANNOT_CARRY"))
        return false
    end
    if CallSecureProtected then
        CallSecureProtected("RequestMoveItem", BAG_COMPANION_WORN, slotIndex, BAG_BACKPACK, 0, 1)
        return true
    end
    return false
end

-- BASIC ACTIONS

function Companions.IsCompanionItemLocked(bagId, slotIndex)
    if IsItemPlayerLocked then
        return IsItemPlayerLocked(bagId, slotIndex)
    end
    return false
end

function Companions.ToggleCompanionItemLock(bagId, slotIndex)
    local locked = Companions.IsCompanionItemLocked(bagId, slotIndex)
    local canToggle = locked and CanUnlockItem(bagId, slotIndex) or CanLockItem(bagId, slotIndex)
    if not canToggle then
        return false
    end
    return SetCompanionItemLockState(bagId, slotIndex, not locked)
end

function Companions.IsCompanionItemJunk(bagId, slotIndex)
    if IsItemJunk then
        return IsItemJunk(bagId, slotIndex)
    end
    return false
end

function Companions.ToggleCompanionItemJunk(bagId, slotIndex)
    if not SetItemIsJunk then
        return false
    end

    local junk = Companions.IsCompanionItemJunk(bagId, slotIndex)
    local canToggle = junk and CanUnjunkItem(bagId, slotIndex) or CanJunkItem(bagId, slotIndex)
    if not canToggle then
        return false
    end

    SetItemIsJunk(bagId, slotIndex, not junk)
    return true
end

function Companions.ShowCompanionDestroyDialog(bagId, slotIndex)
    if not CanDestroyItem(bagId, slotIndex) then
        return false
    end
    local itemLink = GetItemLink(bagId, slotIndex)
    ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
        { bagId = bagId, slotIndex = slotIndex, itemLink = itemLink }, nil, true, true)
    return true
end

function Companions.ShowCompanionSplitStackDialog(bagId, slotIndex)
    local stackSize = GetSlotStackSize(bagId, slotIndex) or 1
    if stackSize > 1 and ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog("ZO_GAMEPAD_SPLIT_STACK_DIALOG", { bag = bagId, slot = slotIndex, stack = stackSize })
    end
end

-- ACTION DIALOG BUILDER

function Companions.BuildActionList(selectedData)
    local actions = {}
    if not selectedData then return actions end
    local ds = selectedData.dataSource or selectedData
    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    if not bagId or not slotIndex then return actions end

    -- Equip / Unequip
    if ds.isEquipped then
        table.insert(actions, { id = "unequip", name = GetString(SI_ITEM_ACTION_UNEQUIP) })
    else
        table.insert(actions, { id = "equip", name = GetString(SI_ITEM_ACTION_EQUIP) })
    end

    -- Destroy
    if Companions.CanExecuteAction("destroy", ds) then
        table.insert(actions, { id = "destroy", name = GetString(SI_ITEM_ACTION_DESTROY) })
    end

    -- Lock / Unlock
    if IsItemPlayerLocked then
        if Companions.IsCompanionItemLocked(bagId, slotIndex) and Companions.CanExecuteAction("unlock", ds) then
            table.insert(actions, { id = "unlock", name = GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED) })
        elseif Companions.CanExecuteAction("lock", ds) then
            table.insert(actions, { id = "lock", name = GetString(SI_ITEM_ACTION_MARK_AS_LOCKED) })
        end
    end

    -- Junk / Unjunk
    if IsItemJunk then
        if Companions.IsCompanionItemJunk(bagId, slotIndex) and Companions.CanExecuteAction("unjunk", ds) then
            table.insert(actions, { id = "unjunk", name = GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK) })
        elseif Companions.CanExecuteAction("junk", ds) then
            table.insert(actions, { id = "junk", name = GetString(SI_ITEM_ACTION_MARK_AS_JUNK) })
        end
    end

    -- Split Stack
    local stackCount = ds.stackCount or 1
    if stackCount > 1 then
        table.insert(actions, { id = "split", name = GetString(SI_ITEM_ACTION_SPLIT_STACK) })
    end

    return actions
end

function Companions.ExecuteAction(actionId, selectedData)
    if not selectedData then return false end
    local ds, bagId, slotIndex = ResolveCompanionActionTarget(selectedData)
    if not Companions.CanExecuteAction(actionId, ds) then
        return false
    end

    if actionId == "equip" then
        return Companions.TryEquipCompanionItem(bagId, slotIndex)
    elseif actionId == "unequip" then
        return Companions.TryUnequipCompanionItem(slotIndex)
    elseif actionId == "destroy" then
        if Companions.GetSetting("quickDestroy") == true then
            DestroyItem(bagId, slotIndex)
            return true
        else
            return Companions.ShowCompanionDestroyDialog(bagId, slotIndex)
        end
    elseif actionId == "lock" then
        return Companions.ToggleCompanionItemLock(bagId, slotIndex)
    elseif actionId == "unlock" then
        return Companions.ToggleCompanionItemLock(bagId, slotIndex)
    elseif actionId == "junk" then
        return Companions.ToggleCompanionItemJunk(bagId, slotIndex)
    elseif actionId == "unjunk" then
        return Companions.ToggleCompanionItemJunk(bagId, slotIndex)
    elseif actionId == "split" then
        Companions.ShowCompanionSplitStackDialog(bagId, slotIndex)
        return true
    end
    return false
end
