if not BETTERUI.Companions then return end
local Companions = BETTERUI.Companions

local function GetCurrentSceneName()
    if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentSceneName) == "function" then
        local ok, sceneName = pcall(function() return SCENE_MANAGER:GetCurrentSceneName() end)
        if ok then
            return sceneName
        end
    end
    return nil
end

local function TraceCompanionAction(event, phase, data)
    local L = BETTERUI and BETTERUI.Log or nil
    if not L or type(L.TraceEvent) ~= "function" then return end
    local payload = data or {}
    payload.module = "Companions"
    payload.feature = "actions"
    payload.scene = GetCurrentSceneName()
    payload.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if type(L.SetLastAction) == "function" then
        L.SetLastAction(event)
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.ACTION or categories.GENERAL, event, phase, payload)
end
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
    TraceCompanionAction("companions.secure_move", "failed", { fn = "NotifySecureMoveFailed", context = context })
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
    TraceCompanionAction("companions.preview", "requested", { fn = "TryPreviewCompanionItem", bagId = bagId, slotIndex = slotIndex })
    if not Companions.CanPreviewCompanionItem(bagId, slotIndex) then
        TraceCompanionAction("companions.preview", "rejected", { fn = "TryPreviewCompanionItem", reason = "notPreviewable", bagId = bagId, slotIndex = slotIndex })
        return false
    end
    local previewManager = SYSTEMS and SYSTEMS.GetObject and SYSTEMS:GetObject("itemPreview") or nil
    if previewManager and type(previewManager.PreviewInventoryItem) == "function" then
        previewManager:PreviewInventoryItem(bagId, slotIndex)
        TraceCompanionAction("companions.preview", "shown", { fn = "TryPreviewCompanionItem", source = "itemPreviewSystem", bagId = bagId, slotIndex = slotIndex })
        return true
    end
    if type(PreviewInventoryItem) ~= "function" then
        TraceCompanionAction("companions.preview", "rejected", { fn = "TryPreviewCompanionItem", reason = "missingPreviewApi", bagId = bagId, slotIndex = slotIndex })
        return false
    end
    PreviewInventoryItem(bagId, slotIndex, 1)
    TraceCompanionAction("companions.preview", "shown", { fn = "TryPreviewCompanionItem", source = "engine", variation = 1, bagId = bagId, slotIndex = slotIndex })
    return true
end

function Companions.EndCompanionItemPreview()
    if type(EndCurrentItemPreview) == "function" then
        EndCurrentItemPreview()
        TraceCompanionAction("companions.preview", "ended", { fn = "EndCompanionItemPreview" })
    end
end

local function ResolveCompanionActionTarget(selectedData)
    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    local bagId = ds and ds.bagId or nil
    local slotIndex = ds and ds.slotIndex or nil
    local slotType = ds and ds.slotType or nil
    return ds, bagId, slotIndex, slotType
end

local function ResolveActionEligibility(actionId, selectedData)
    local ds, bagId, slotIndex, slotType = ResolveCompanionActionTarget(selectedData)
    if not ds then
        return false, "missingTarget"
    end
    if actionId ~= "unequip" and (bagId == nil or slotIndex == nil) then
        return false, "missingSlot"
    end
    if actionId == "equip" then
        if ds.isEquipped then return false, "alreadyEquipped" end
        return true
    elseif actionId == "unequip" then
        if slotIndex == nil then return false, "missingSlot" end
        return ds.isEquipped == true, ds.isEquipped == true and nil or "notEquipped"
    elseif actionId == "preview" then
        local canPreview = Companions.CanPreviewCompanionItem(bagId, slotIndex)
        return canPreview, canPreview and nil or "notPreviewable"
    elseif actionId == "destroy" then
        local canDestroy = CanDestroyItem(bagId, slotIndex, slotType)
        return canDestroy, canDestroy and nil or "policyBlocked"
    elseif actionId == "lock" then
        local canLock = CanLockItem(bagId, slotIndex)
        return canLock, canLock and nil or "cannotLock"
    elseif actionId == "unlock" then
        local canUnlock = CanUnlockItem(bagId, slotIndex)
        return canUnlock, canUnlock and nil or "cannotUnlock"
    elseif actionId == "junk" then
        local canJunk = CanJunkItem(bagId, slotIndex)
        return canJunk, canJunk and nil or "cannotJunk"
    elseif actionId == "unjunk" then
        local canUnjunk = CanUnjunkItem(bagId, slotIndex)
        return canUnjunk, canUnjunk and nil or "cannotUnjunk"
    elseif actionId == "split" then
        local canSplit = (ds.stackCount or 1) > 1
        return canSplit, canSplit and nil or "singleItem"
    end
    return false, "unknownAction"
end

Companions.GetActionEligibility = ResolveActionEligibility

function Companions.CanExecuteAction(actionId, selectedData)
    return ResolveActionEligibility(actionId, selectedData)
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
        TraceCompanionAction("companions.equip_slot", "rejected", { fn = "ResolveCompanionEquipSlot", reason = "invalidEquipType", bagId = bagId, slotIndex = slotIndex, equipType = equipType })
        return nil
    end
    if not ZO_Character_EnumerateOrderedEquipSlots or not ZO_Character_DoesEquipSlotUseEquipType then
        TraceCompanionAction("companions.equip_slot", "rejected", { fn = "ResolveCompanionEquipSlot", reason = "missingEquipSlotApi", bagId = bagId, slotIndex = slotIndex, equipType = equipType })
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
                    TraceCompanionAction("companions.equip_slot", "selected", { fn = "ResolveCompanionEquipSlot", source = "emptyCompatible", bagId = bagId, slotIndex = slotIndex, equipType = equipType, equipSlot = equipSlot, twoHanded = isTwoHanded })
                    return equipSlot
                end
            end
        end
    end
    TraceCompanionAction("companions.equip_slot", "selected", { fn = "ResolveCompanionEquipSlot", source = "fallbackCompatible", bagId = bagId, slotIndex = slotIndex, equipType = equipType, equipSlot = firstCompatibleSlot, twoHanded = isTwoHanded })
    return firstCompatibleSlot
end

local function DoEquipCompanionItem(bagId, slotIndex)
    TraceCompanionAction("companions.equip", "secure_move_begin", { fn = "DoEquipCompanionItem", bagId = bagId, slotIndex = slotIndex })
    local equipSlot = Companions.ResolveCompanionEquipSlot(bagId, slotIndex)
    if not equipSlot then
        NotifySecureMoveFailed("Companions:ResolveEquipSlot")
        TraceCompanionAction("companions.equip", "secure_move_rejected", { fn = "DoEquipCompanionItem", reason = "noEquipSlot", bagId = bagId, slotIndex = slotIndex })
        return false
    end
    if CallSecureProtected then
        if not CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_COMPANION_WORN, equipSlot, 1) then
            NotifySecureMoveFailed("Companions:Equip")
            TraceCompanionAction("companions.equip", "secure_move_failed", { fn = "DoEquipCompanionItem", bagId = bagId, slotIndex = slotIndex, destinationBag = BAG_COMPANION_WORN, destinationSlot = equipSlot })
            return false
        end
        TraceCompanionAction("companions.equip", "secure_move_requested", { fn = "DoEquipCompanionItem", bagId = bagId, slotIndex = slotIndex, destinationBag = BAG_COMPANION_WORN, destinationSlot = equipSlot })
        return true
    end
    TraceCompanionAction("companions.equip", "secure_move_rejected", { fn = "DoEquipCompanionItem", reason = "missingCallSecureProtected", bagId = bagId, slotIndex = slotIndex, destinationBag = BAG_COMPANION_WORN, destinationSlot = equipSlot })
    return false
end

local COMPANION_CONFIRM_EQUIP_BOE_DIALOG = "BETTERUI_COMPANIONS_CONFIRM_EQUIP_BOE"

local function EnsureCompanionEquipBoEDialogRegistered()
    if ESO_Dialogs and ESO_Dialogs[COMPANION_CONFIRM_EQUIP_BOE_DIALOG] then
        return
    end
    local dialogInfo = {
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
                    local data = dialog and dialog.data or {}
                    TraceCompanionAction("companions.equip_boe_dialog", "accepted", { fn = "EnsureCompanionEquipBoEDialogRegistered", dialog = COMPANION_CONFIRM_EQUIP_BOE_DIALOG, bagId = data.bagId, slotIndex = data.slotIndex, itemLink = data.itemLink })
                    local callback = data.callback
                    if type(callback) == "function" then
                        return callback()
                    end
                    TraceCompanionAction("companions.equip_boe_dialog", "callback_missing", { fn = "EnsureCompanionEquipBoEDialogRegistered", dialog = COMPANION_CONFIRM_EQUIP_BOE_DIALOG, bagId = data.bagId, slotIndex = data.slotIndex, itemLink = data.itemLink })
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
                callback = function(dialog)
                    local data = dialog and dialog.data or {}
                    TraceCompanionAction("companions.equip_boe_dialog", "cancelled", { fn = "EnsureCompanionEquipBoEDialogRegistered", dialog = COMPANION_CONFIRM_EQUIP_BOE_DIALOG, bagId = data.bagId, slotIndex = data.slotIndex, itemLink = data.itemLink })
                end,
            },
        },
    }
    if BETTERUI.CIM and BETTERUI.CIM.Dialogs and BETTERUI.CIM.Dialogs.Register then
        BETTERUI.CIM.Dialogs.Register(COMPANION_CONFIRM_EQUIP_BOE_DIALOG, dialogInfo)
    elseif ZO_Dialogs_RegisterCustomDialog then
        ZO_Dialogs_RegisterCustomDialog(COMPANION_CONFIRM_EQUIP_BOE_DIALOG, dialogInfo)
    else
        ESO_Dialogs = ESO_Dialogs or {}
        ESO_Dialogs[COMPANION_CONFIRM_EQUIP_BOE_DIALOG] = dialogInfo
    end
end

function Companions.TryEquipCompanionItem(bagId, slotIndex)
    TraceCompanionAction("companions.equip", "requested", { fn = "TryEquipCompanionItem", bagId = bagId, slotIndex = slotIndex })
    if bagId == nil or slotIndex == nil then
        TraceCompanionAction("companions.equip", "rejected", { fn = "TryEquipCompanionItem", reason = "missingSlot", bagId = bagId, slotIndex = slotIndex })
        return false
    end
    if GetItemActorCategory and GetItemActorCategory(bagId, slotIndex) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        TraceCompanionAction("companions.equip", "rejected", { fn = "TryEquipCompanionItem", reason = "notCompanionItem", bagId = bagId, slotIndex = slotIndex, actorCategory = GetItemActorCategory(bagId, slotIndex) })
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
            if type(ZO_Dialogs_ShowPlatformDialog) ~= "function" then
                TraceCompanionAction("companions.equip_boe_dialog", "rejected", { fn = "TryEquipCompanionItem", reason = "missingDialogApi", bagId = bagId, slotIndex = slotIndex, itemLink = itemLink })
                return false
            end
            ZO_Dialogs_ShowPlatformDialog(COMPANION_CONFIRM_EQUIP_BOE_DIALOG, { callback = DoEquip, bagId = bagId, slotIndex = slotIndex, itemLink = itemLink }, { mainTextParams = { itemLink } })
            TraceCompanionAction("companions.equip_boe_dialog", "shown", { fn = "TryEquipCompanionItem", dialog = COMPANION_CONFIRM_EQUIP_BOE_DIALOG, bagId = bagId, slotIndex = slotIndex, itemLink = itemLink })
            return true
        end
    end
    local moved = DoEquip()
    TraceCompanionAction("companions.equip", "result", { fn = "TryEquipCompanionItem", bagId = bagId, slotIndex = slotIndex, requested = moved })
    return moved
end

function Companions.TryUnequipCompanionItem(slotIndex)
    TraceCompanionAction("companions.unequip", "requested", { fn = "TryUnequipCompanionItem", sourceBag = BAG_COMPANION_WORN, slotIndex = slotIndex })
    if slotIndex == nil then
        TraceCompanionAction("companions.unequip", "rejected", { fn = "TryUnequipCompanionItem", reason = "missingSlot", sourceBag = BAG_COMPANION_WORN, slotIndex = slotIndex })
        return false
    end
    -- FindFirstEmptySlotInBag(bagId) -> nilable slotIndex; slot 0 may be occupied.
    -- Use a single lookup to avoid a TOCTOU between GetNumBagFreeSlots and
    -- finding the actual empty slot.
    local destinationSlot = FindFirstEmptySlotInBag and FindFirstEmptySlotInBag(BAG_BACKPACK) or nil
    if destinationSlot == nil then
        TraceCompanionAction("companions.unequip", "rejected", { fn = "TryUnequipCompanionItem", reason = "backpackFull", sourceBag = BAG_COMPANION_WORN, slotIndex = slotIndex, destinationBag = BAG_BACKPACK })
        BETTERUI.CIM.UserAlertText("Companions:BagFull",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY") or "SI_BETTERUI_VENDOR_CANNOT_CARRY"))
        return false
    end
    if CallSecureProtected then
        if not CallSecureProtected("RequestMoveItem", BAG_COMPANION_WORN, slotIndex, BAG_BACKPACK, destinationSlot, 1) then
            NotifySecureMoveFailed("Companions:Unequip")
            TraceCompanionAction("companions.unequip", "secure_move_failed", { fn = "TryUnequipCompanionItem", sourceBag = BAG_COMPANION_WORN, slotIndex = slotIndex, destinationBag = BAG_BACKPACK, destinationSlot = destinationSlot })
            return false
        end
        TraceCompanionAction("companions.unequip", "secure_move_requested", { fn = "TryUnequipCompanionItem", sourceBag = BAG_COMPANION_WORN, slotIndex = slotIndex, destinationBag = BAG_BACKPACK, destinationSlot = destinationSlot })
        return true
    end
    TraceCompanionAction("companions.unequip", "rejected", { fn = "TryUnequipCompanionItem", reason = "missingCallSecureProtected", sourceBag = BAG_COMPANION_WORN, slotIndex = slotIndex, destinationBag = BAG_BACKPACK, destinationSlot = destinationSlot })
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
    TraceCompanionAction("companions.lock_toggle", "requested", { fn = "ToggleCompanionItemLock", bagId = bagId, slotIndex = slotIndex, locked = locked, targetLocked = not locked })
    -- Explicit branch: `locked and CanUnlockItem(...) or CanLockItem(...)` falls
    -- through to CanLockItem when CanUnlockItem returns false.
    local canToggle
    if locked then
        canToggle = CanUnlockItem(bagId, slotIndex)
    else
        canToggle = CanLockItem(bagId, slotIndex)
    end
    if not canToggle then
        TraceCompanionAction("companions.lock_toggle", "rejected", { fn = "ToggleCompanionItemLock", bagId = bagId, slotIndex = slotIndex, locked = locked, targetLocked = not locked })
        return false
    end
    local changed = SetCompanionItemLockState(bagId, slotIndex, not locked)
    TraceCompanionAction("companions.lock_toggle", "result", { fn = "ToggleCompanionItemLock", bagId = bagId, slotIndex = slotIndex, locked = locked, targetLocked = not locked, changed = changed })
    return changed
end

function Companions.IsCompanionItemJunk(bagId, slotIndex)
    if IsItemJunk then
        return IsItemJunk(bagId, slotIndex)
    end
    return false
end

function Companions.ToggleCompanionItemJunk(bagId, slotIndex)
    if not SetItemIsJunk then
        TraceCompanionAction("companions.junk_toggle", "rejected", { fn = "ToggleCompanionItemJunk", reason = "missingJunkApi", bagId = bagId, slotIndex = slotIndex })
        return false
    end

    local junk = Companions.IsCompanionItemJunk(bagId, slotIndex)
    TraceCompanionAction("companions.junk_toggle", "requested", { fn = "ToggleCompanionItemJunk", bagId = bagId, slotIndex = slotIndex, junk = junk, targetJunk = not junk })
    -- Explicit branch (see ToggleCompanionItemLock): avoid falling through to
    -- CanJunkItem when CanUnjunkItem returns false.
    local canToggle
    if junk then
        canToggle = CanUnjunkItem(bagId, slotIndex)
    else
        canToggle = CanJunkItem(bagId, slotIndex)
    end
    if not canToggle then
        TraceCompanionAction("companions.junk_toggle", "rejected", { fn = "ToggleCompanionItemJunk", bagId = bagId, slotIndex = slotIndex, junk = junk, targetJunk = not junk })
        return false
    end

    SetItemIsJunk(bagId, slotIndex, not junk)
    TraceCompanionAction("companions.junk_toggle", "result", { fn = "ToggleCompanionItemJunk", bagId = bagId, slotIndex = slotIndex, junk = junk, targetJunk = not junk, changed = true })
    return true
end

function Companions.ShowCompanionDestroyDialog(bagId, slotIndex, slotType)
    if not CanDestroyItem(bagId, slotIndex, slotType) then
        TraceCompanionAction("companions.destroy_dialog", "rejected", { fn = "ShowCompanionDestroyDialog", reason = "policyBlocked", bagId = bagId, slotIndex = slotIndex, slotType = slotType })
        return false
    end
    local itemLink = GetItemLink(bagId, slotIndex)
    ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
        { bagId = bagId, slotIndex = slotIndex, itemLink = itemLink }, nil, true, true)
    TraceCompanionAction("companions.destroy_dialog", "shown", { fn = "ShowCompanionDestroyDialog", dialog = "BETTERUI_CONFIRM_DESTROY_DIALOG", bagId = bagId, slotIndex = slotIndex, slotType = slotType, itemLink = itemLink })
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
function Companions.QuickDestroyCompanionItem(bagId, slotIndex, slotType, expectedIdentity, batchId)
    if not MatchesCapturedItemIdentity(bagId, slotIndex, expectedIdentity) then
        TraceCompanionAction("companions.quick_destroy", "skipped", { fn = "QuickDestroyCompanionItem", reason = "identityMismatch", bagId = bagId, slotIndex = slotIndex, slotType = slotType, batchId = batchId })
        return false
    end
    if not CanDestroyItem(bagId, slotIndex, slotType) then
        TraceCompanionAction("companions.quick_destroy", "rejected", { fn = "QuickDestroyCompanionItem", reason = "policyBlocked", bagId = bagId, slotIndex = slotIndex, slotType = slotType, batchId = batchId })
        return false
    end
    local destroyed = RequireInventoryDestroyExecutor()(bagId, slotIndex, true, false, slotType) == true
    TraceCompanionAction("companions.quick_destroy", "result", { fn = "QuickDestroyCompanionItem", bagId = bagId, slotIndex = slotIndex, slotType = slotType, destroyed = destroyed, batchId = batchId })
    return destroyed
end

function Companions.ShowCompanionSplitStackDialog(bagId, slotIndex)
    local stackSize = GetSlotStackSize(bagId, slotIndex) or 1
    if stackSize > 1 and ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog("ZO_GAMEPAD_SPLIT_STACK_DIALOG", { bag = bagId, slot = slotIndex, stack = stackSize })
        TraceCompanionAction("companions.split_stack_dialog", "shown", { fn = "ShowCompanionSplitStackDialog", dialog = "ZO_GAMEPAD_SPLIT_STACK_DIALOG", bagId = bagId, slotIndex = slotIndex, stackSize = stackSize })
        return true
    end
    TraceCompanionAction("companions.split_stack_dialog", "skipped", { fn = "ShowCompanionSplitStackDialog", reason = stackSize <= 1 and "singleItem" or "missingDialogApi", bagId = bagId, slotIndex = slotIndex, stackSize = stackSize })
    return false
end

function Companions.BuildActionList(selectedData)
    local actions = {}
    if not selectedData then
        TraceCompanionAction("companions.action_menu", "built", { fn = "BuildActionList", reason = "noSelection", actionCount = 0 })
        return actions
    end
    local ds = selectedData.dataSource or selectedData
    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    if not bagId or not slotIndex then
        TraceCompanionAction("companions.action_menu", "built", { fn = "BuildActionList", reason = "missingSlot", bagId = bagId, slotIndex = slotIndex, actionCount = 0 })
        return actions
    end

    local eligibility = {}

    -- Equip / Unequip
    if ds.isEquipped then
        local canUnequip, unequipReason = Companions.CanExecuteAction("unequip", ds)
        eligibility.unequip = { allowed = canUnequip == true, reason = unequipReason }
        eligibility.equip = { allowed = false, reason = "alreadyEquipped" }
        table.insert(actions, { id = "unequip", name = GetString(SI_ITEM_ACTION_UNEQUIP) })
    else
        local canEquip, equipReason = Companions.CanExecuteAction("equip", ds)
        eligibility.equip = { allowed = canEquip == true, reason = equipReason }
        eligibility.unequip = { allowed = false, reason = "notEquipped" }
        table.insert(actions, { id = "equip", name = GetString(SI_ITEM_ACTION_EQUIP) })
    end

    -- Preview
    local canPreview, previewReason = Companions.CanExecuteAction("preview", ds)
    eligibility.preview = { allowed = canPreview == true, reason = previewReason }
    if canPreview then
        local previewStringId = rawget(_G, "SI_ITEM_ACTION_PREVIEW")
        local previewName = previewStringId and GetString(previewStringId) or "Preview"
        table.insert(actions, { id = "preview", name = previewName })
    end

    -- Destroy
    local canDestroy, destroyReason = Companions.CanExecuteAction("destroy", ds)
    eligibility.destroy = { allowed = canDestroy == true, reason = destroyReason }
    if canDestroy then
        table.insert(actions, { id = "destroy", name = GetString(SI_ITEM_ACTION_DESTROY) })
    end

    -- Lock / Unlock
    if IsItemPlayerLocked then
        local locked = Companions.IsCompanionItemLocked(bagId, slotIndex)
        local canUnlock, unlockReason = Companions.CanExecuteAction("unlock", ds)
        local canLock, lockReason = Companions.CanExecuteAction("lock", ds)
        eligibility.unlock = { allowed = canUnlock == true, reason = unlockReason }
        eligibility.lock = { allowed = canLock == true, reason = lockReason }
        if locked and canUnlock then
            table.insert(actions, { id = "unlock", name = GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED) })
        elseif canLock then
            table.insert(actions, { id = "lock", name = GetString(SI_ITEM_ACTION_MARK_AS_LOCKED) })
        end
    else
        eligibility.lock = { allowed = false, reason = "missingLockApi" }
        eligibility.unlock = { allowed = false, reason = "missingLockApi" }
    end

    -- Junk / Unjunk
    if IsItemJunk then
        local junk = Companions.IsCompanionItemJunk(bagId, slotIndex)
        local canUnjunk, unjunkReason = Companions.CanExecuteAction("unjunk", ds)
        local canJunk, junkReason = Companions.CanExecuteAction("junk", ds)
        eligibility.unjunk = { allowed = canUnjunk == true, reason = unjunkReason }
        eligibility.junk = { allowed = canJunk == true, reason = junkReason }
        if junk and canUnjunk then
            table.insert(actions, { id = "unjunk", name = GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK) })
        elseif canJunk then
            table.insert(actions, { id = "junk", name = GetString(SI_ITEM_ACTION_MARK_AS_JUNK) })
        end
    else
        eligibility.junk = { allowed = false, reason = "missingJunkApi" }
        eligibility.unjunk = { allowed = false, reason = "missingJunkApi" }
    end

    -- Split Stack
    local stackCount = ds.stackCount or 1
    local canSplit, splitReason = Companions.CanExecuteAction("split", ds)
    eligibility.split = { allowed = canSplit == true, reason = splitReason }
    if canSplit then
        table.insert(actions, { id = "split", name = GetString(SI_ITEM_ACTION_SPLIT_STACK) })
    end

    local actionIds = {}
    for i = 1, #actions do
        actionIds[i] = actions[i].id
    end
    TraceCompanionAction("companions.action_menu", "built", { fn = "BuildActionList", bagId = bagId, slotIndex = slotIndex, equipped = ds.isEquipped == true, stackCount = stackCount, actionCount = #actions, actionIds = table.concat(actionIds, ","), eligibility = eligibility })
    return actions
end

function Companions.ExecuteAction(actionId, selectedData)
    TraceCompanionAction("companions.action", "requested", { fn = "ExecuteAction", actionId = actionId })
    if not selectedData then
        TraceCompanionAction("companions.action", "rejected", { fn = "ExecuteAction", reason = "noSelection", actionId = actionId })
        return false
    end
    local ds, bagId, slotIndex, slotType = ResolveCompanionActionTarget(selectedData)
    local canExecute, denyReason = Companions.CanExecuteAction(actionId, ds)
    if not canExecute then
        TraceCompanionAction("companions.action", "rejected", { fn = "ExecuteAction", reason = denyReason or "cannotExecute", actionId = actionId, bagId = bagId, slotIndex = slotIndex, slotType = slotType })
        return false
    end

    local result = false
    local resultDetails = nil
    if actionId == "equip" then
        result = Companions.TryEquipCompanionItem(bagId, slotIndex)
    elseif actionId == "unequip" then
        result = Companions.TryUnequipCompanionItem(slotIndex)
    elseif actionId == "preview" then
        result = Companions.TryPreviewCompanionItem(bagId, slotIndex)
    elseif actionId == "destroy" then
        if not CanDestroyItem(bagId, slotIndex, slotType) then
            TraceCompanionAction("companions.action", "rejected", { fn = "ExecuteAction", reason = "destroyPolicyBlocked", actionId = actionId, bagId = bagId, slotIndex = slotIndex, slotType = slotType })
            result = false
        elseif Companions.GetSetting("quickDestroy") == true then
            result = RequireInventoryDestroyExecutor()(bagId, slotIndex, true, false, slotType)
        else
            result = Companions.ShowCompanionDestroyDialog(bagId, slotIndex, slotType)
        end
    elseif actionId == "lock" then
        result = Companions.ToggleCompanionItemLock(bagId, slotIndex)
    elseif actionId == "unlock" then
        result = Companions.ToggleCompanionItemLock(bagId, slotIndex)
    elseif actionId == "junk" then
        result = Companions.ToggleCompanionItemJunk(bagId, slotIndex)
    elseif actionId == "unjunk" then
        result = Companions.ToggleCompanionItemJunk(bagId, slotIndex)
    elseif actionId == "split" then
        local didShowDialog = Companions.ShowCompanionSplitStackDialog(bagId, slotIndex)
        result = didShowDialog == true
        resultDetails = { didShowDialog = didShowDialog == true }
    end
    local traceData = { fn = "ExecuteAction", actionId = actionId, bagId = bagId, slotIndex = slotIndex, slotType = slotType, result = result == true }
    if resultDetails then
        for key, value in pairs(resultDetails) do
            traceData[key] = value
        end
    end
    TraceCompanionAction("companions.action", "result", traceData)
    return result
end
