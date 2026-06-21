if not BETTERUI.Companions then return end
local Companions = BETTERUI.Companions
local function GetProtectionPolicy()
    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before CompanionActions policy checks")
    return policy
end

local function RequireProtectionPolicyMethod(methodName)
    local policy = GetProtectionPolicy()
    local method = policy and policy[methodName] or nil
    assert(type(method) == "function",
        string.format("BetterUI: CIM.ProtectionPolicy.%s must load before CompanionActions policy checks", tostring(methodName)))
    return method
end

local function CanDestroyItem(bagId, slotIndex, slotType)
    return RequireProtectionPolicyMethod("CanDestroyItem")(bagId, slotIndex, slotType) == true
end

local function CanLockItem(bagId, slotIndex)
    return RequireProtectionPolicyMethod("CanLockItem")(bagId, slotIndex) == true
end

local function CanUnlockItem(bagId, slotIndex)
    return RequireProtectionPolicyMethod("CanUnlockItem")(bagId, slotIndex) == true
end

local function CanJunkItem(bagId, slotIndex)
    -- Companion-screen junk is gated by the Companions module toggle, not the Inventory FCO setting.
    return RequireProtectionPolicyMethod("CanJunkItem")(bagId, slotIndex, "Companions") == true
end

local function CanUnjunkItem(bagId, slotIndex)
    return RequireProtectionPolicyMethod("CanUnjunkItem")(bagId, slotIndex) == true
end

local function RequireInventoryDestroyExecutor()
    local inventory = BETTERUI and BETTERUI.Inventory or nil
    local destroyExecutor = inventory and inventory.TryDestroyItem or nil
    assert(type(destroyExecutor) == "function",
        "BetterUI: Inventory.TryDestroyItem must load before companion quick-destroy actions")
    return destroyExecutor
end

--- Alerts the user when a secure RequestMoveItem call is rejected by the client.
---@param context string Logging context label
local function NotifySecureMoveFailed(context)
    local stringId = rawget(_G, "SI_BETTERUI_ITEM_MOVE_FAILED")
    BETTERUI.CIM.UserNotify(context, stringId and GetString(stringId) or "Item move request failed")
end

local function SetCompanionItemLockState(bagId, slotIndex, locked)
    if SetItemIsPlayerLocked then
        SetItemIsPlayerLocked(bagId, slotIndex, locked)
        return true
    end
    return false
end

function Companions.CanPreviewCompanionItem(bagId, slotIndex)
    if bagId == nil or slotIndex == nil then return false end
    if type(CanInventoryItemBePreviewed) ~= "function" then return false end
    return CanInventoryItemBePreviewed(bagId, slotIndex) == true
end

function Companions.TryPreviewCompanionItem(bagId, slotIndex)
    if not Companions.CanPreviewCompanionItem(bagId, slotIndex) then return false end
    if type(PreviewInventoryItem) ~= "function" then return false end
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "companion item previewed", { bagId = bagId, slotIndex = slotIndex })
    end
    PreviewInventoryItem(bagId, slotIndex)
    return true
end

function Companions.EndCompanionItemPreview()
    if type(EndCurrentItemPreview) == "function" then
        EndCurrentItemPreview()
    end
end

local function ResolveCompanionActionTarget(selectedData)
    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    local bagId = ds and ds.bagId or nil
    local slotIndex = ds and ds.slotIndex or nil
    local slotType = ds and ds.slotType or nil
    return ds, bagId, slotIndex, slotType
end

function Companions.CanExecuteAction(actionId, selectedData)
    local ds, bagId, slotIndex, slotType = ResolveCompanionActionTarget(selectedData)
    if actionId == "equip" then
        return ds ~= nil and bagId ~= nil and slotIndex ~= nil and not ds.isEquipped
    elseif actionId == "unequip" then
        return ds ~= nil and slotIndex ~= nil and ds.isEquipped == true
    elseif actionId == "preview" then
        return Companions.CanPreviewCompanionItem(bagId, slotIndex)
    elseif actionId == "destroy" then
        return CanDestroyItem(bagId, slotIndex, slotType)
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

local TWO_HANDED_WEAPON_TYPES = {
    [WEAPONTYPE_TWO_HANDED_SWORD] = true,
    [WEAPONTYPE_TWO_HANDED_AXE] = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
    [WEAPONTYPE_FIRE_STAFF] = true,
    [WEAPONTYPE_FROST_STAFF] = true,
    [WEAPONTYPE_LIGHTNING_STAFF] = true,
    [WEAPONTYPE_HEALING_STAFF] = true,
    [WEAPONTYPE_BOW] = true,
}

local function IsTwoHandedWeapon(bagId, slotIndex)
    if not GetItemWeaponType then return false end
    local weaponType = GetItemWeaponType(bagId, slotIndex)
    return TWO_HANDED_WEAPON_TYPES[weaponType] == true
end

function Companions.ResolveCompanionEquipSlot(bagId, slotIndex)
    local equipType = GetItemEquipType and GetItemEquipType(bagId, slotIndex) or nil
    if equipType == nil or equipType == 0 or equipType == EQUIP_TYPE_INVALID then
        return nil
    end
    if not ZO_Character_EnumerateOrderedEquipSlots or not ZO_Character_DoesEquipSlotUseEquipType then
        return nil
    end
    local isTwoHanded = IsTwoHandedWeapon(bagId, slotIndex)
    local firstCompatibleSlot = nil
    for _, equipSlot in ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN) do
        if ZO_Character_DoesEquipSlotUseEquipType(equipSlot, equipType) then
            -- Skip locked weapon slots.
            if IsLockedWeaponSlot and IsLockedWeaponSlot(equipSlot) then
                -- locked: cannot equip here
            -- Two-handed weapons must target MAIN_HAND only.
            elseif isTwoHanded and equipSlot ~= EQUIP_SLOT_MAIN_HAND then
                -- off-hand / backup off-hand is invalid for two-handed weapons
            else
                if not firstCompatibleSlot then
                    firstCompatibleSlot = equipSlot
                end
                if not HasItemInSlot or not HasItemInSlot(BAG_COMPANION_WORN, equipSlot) then
                    return equipSlot
                end
            end
        end
    end
    return firstCompatibleSlot
end

local function DoEquipCompanionItem(bagId, slotIndex)
    local equipSlot = Companions.ResolveCompanionEquipSlot(bagId, slotIndex)
    if not equipSlot then
        NotifySecureMoveFailed("Companions:ResolveEquipSlot")
        return false
    end
    if CallSecureProtected then
        if not CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_COMPANION_WORN, equipSlot, 1) then
            NotifySecureMoveFailed("Companions:Equip")
            return false
        end
        return true
    end
    return false
end

local COMPANION_CONFIRM_EQUIP_BOE_DIALOG = "BETTERUI_COMPANIONS_CONFIRM_EQUIP_BOE"

local function EnsureCompanionEquipBoEDialogRegistered()
    if ESO_Dialogs and ESO_Dialogs[COMPANION_CONFIRM_EQUIP_BOE_DIALOG] then
        return
    end
    ESO_Dialogs = ESO_Dialogs or {}
    ESO_Dialogs[COMPANION_CONFIRM_EQUIP_BOE_DIALOG] = {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title = {
            text = SI_DIALOG_CONFIRM_BINDING_ITEM_TITLE,
        },
        mainText = {
            text = SI_DIALOG_CONFIRM_EQUIPPING_ITEM_BODY,
        },
        buttons = {
            {
                text = SI_DIALOG_ACCEPT,
                callback = function(dialog)
                    dialog.data.callback()
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
            },
        },
    }
end

function Companions.TryEquipCompanionItem(bagId, slotIndex)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "companion item equipped", { bagId = bagId, slotIndex = slotIndex })
    end
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
            -- BetterUI uses a queued, companion-specific BoE confirm dialog (custom callback
            -- contract + canQueue) rather than native CONFIRM_EQUIP_ITEM.
            EnsureCompanionEquipBoEDialogRegistered()
            ZO_Dialogs_ShowPlatformDialog(COMPANION_CONFIRM_EQUIP_BOE_DIALOG, { callback = DoEquip }, { mainTextParams = { itemLink } })
            return true
        end
    end
    return DoEquip()
end

function Companions.TryUnequipCompanionItem(slotIndex)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "companion item unequipped", { slotIndex = slotIndex })
    end
    if slotIndex == nil then return false end
    -- FindFirstEmptySlotInBag(bagId) -> nilable slotIndex; slot 0 may be occupied.
    -- Use a single lookup to avoid a TOCTOU between GetNumBagFreeSlots and
    -- finding the actual empty slot.
    local destinationSlot = FindFirstEmptySlotInBag and FindFirstEmptySlotInBag(BAG_BACKPACK) or nil
    if destinationSlot == nil then
        BETTERUI.CIM.UserAlertText("Companions:BagFull",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY") or "SI_BETTERUI_VENDOR_CANNOT_CARRY"))
        return false
    end
    if CallSecureProtected then
        if not CallSecureProtected("RequestMoveItem", BAG_COMPANION_WORN, slotIndex, BAG_BACKPACK, destinationSlot, 1) then
            NotifySecureMoveFailed("Companions:Unequip")
            return false
        end
        return true
    end
    return false
end

function Companions.IsCompanionItemLocked(bagId, slotIndex)
    if IsItemPlayerLocked then
        return IsItemPlayerLocked(bagId, slotIndex)
    end
    return false
end

function Companions.ToggleCompanionItemLock(bagId, slotIndex)
    local locked = Companions.IsCompanionItemLocked(bagId, slotIndex)
    -- Explicit branch: `locked and CanUnlockItem(...) or CanLockItem(...)` falls
    -- through to CanLockItem when CanUnlockItem returns false.
    local canToggle
    if locked then
        canToggle = CanUnlockItem(bagId, slotIndex)
    else
        canToggle = CanLockItem(bagId, slotIndex)
    end
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
    -- Explicit branch (see ToggleCompanionItemLock): avoid falling through to
    -- CanJunkItem when CanUnjunkItem returns false.
    local canToggle
    if junk then
        canToggle = CanUnjunkItem(bagId, slotIndex)
    else
        canToggle = CanJunkItem(bagId, slotIndex)
    end
    if not canToggle then
        return false
    end

    SetItemIsJunk(bagId, slotIndex, not junk)
    return true
end

function Companions.ShowCompanionDestroyDialog(bagId, slotIndex, slotType)
    if not CanDestroyItem(bagId, slotIndex, slotType) then
        return false
    end
    local itemLink = GetItemLink(bagId, slotIndex)
    ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
        { bagId = bagId, slotIndex = slotIndex, itemLink = itemLink }, nil, true, true)
    return true
end

--- Returns true when the slot still holds the item captured in identity
--- (uniqueId preferred, itemLink fallback). Batch destroys run staggered, so
--- the slot may have been emptied or refilled with a different item since the
--- confirmation was shown.
---@param identity {uniqueId: id64|nil, itemLink: string|nil}|nil
---@return boolean matches
local function MatchesCapturedItemIdentity(bagId, slotIndex, identity)
    if not identity then
        return true
    end
    if identity.uniqueId ~= nil and GetItemUniqueId and AreId64sEqual then
        local currentId = GetItemUniqueId(bagId, slotIndex)
        return currentId ~= nil and AreId64sEqual(currentId, identity.uniqueId)
    end
    if identity.itemLink and identity.itemLink ~= "" then
        return GetItemLink(bagId, slotIndex) == identity.itemLink
    end
    return true
end

--- Destroys without a per-item confirmation. Used by batch destroy after a
--- single batch-level confirmation has already been shown.
---@param expectedIdentity {uniqueId: id64|nil, itemLink: string|nil}|nil when provided, skip the destroy if the slot no longer matches
---@return boolean destroyed
function Companions.QuickDestroyCompanionItem(bagId, slotIndex, slotType, expectedIdentity)
    if not MatchesCapturedItemIdentity(bagId, slotIndex, expectedIdentity) then
        return false
    end
    if not CanDestroyItem(bagId, slotIndex, slotType) then
        return false
    end
    return RequireInventoryDestroyExecutor()(bagId, slotIndex, true, false, slotType) == true
end

function Companions.ShowCompanionSplitStackDialog(bagId, slotIndex)
    local stackSize = GetSlotStackSize(bagId, slotIndex) or 1
    if stackSize > 1 and ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog("ZO_GAMEPAD_SPLIT_STACK_DIALOG", { bag = bagId, slot = slotIndex, stack = stackSize })
    end
end

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

    -- Preview
    if Companions.CanExecuteAction("preview", ds) then
        local previewStringId = rawget(_G, "SI_ITEM_ACTION_PREVIEW")
        local previewName = previewStringId and GetString(previewStringId) or "Preview"
        table.insert(actions, { id = "preview", name = previewName })
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
    local ds, bagId, slotIndex, slotType = ResolveCompanionActionTarget(selectedData)
    if not Companions.CanExecuteAction(actionId, ds) then
        return false
    end

    if actionId == "equip" then
        return Companions.TryEquipCompanionItem(bagId, slotIndex)
    elseif actionId == "unequip" then
        return Companions.TryUnequipCompanionItem(slotIndex)
    elseif actionId == "preview" then
        return Companions.TryPreviewCompanionItem(bagId, slotIndex)
    elseif actionId == "destroy" then
        if not CanDestroyItem(bagId, slotIndex, slotType) then
            return false
        end

        if Companions.GetSetting("quickDestroy") == true then
            return RequireInventoryDestroyExecutor()(bagId, slotIndex, true, false, slotType)
        else
            return Companions.ShowCompanionDestroyDialog(bagId, slotIndex, slotType)
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
