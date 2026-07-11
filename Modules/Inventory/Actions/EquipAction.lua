local function TraceInventoryEquip(phase, bagId, slotIndex, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.bagId = data.bagId or bagId
    data.slotIndex = data.slotIndex or slotIndex
    if not data.target and L.DescribeItem and bagId and slotIndex then
        data.target = L.DescribeItem({ bagId = bagId, slotIndex = slotIndex }, "target")
    end
    L.TraceEvent(L.CATEGORY.ACTION, "inventory.equip", phase, data, L.LEVEL.INFO)
end

local function DoEquipMove(bagId, slotIndex, equipType, mainSlot, isPrimary)
    local targetPrimary = (isPrimary ~= false)

    local targetSlot = nil

    if equipType == EQUIP_TYPE_ONE_HAND then
        if mainSlot then
            targetSlot = targetPrimary and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN
        else
            targetSlot = targetPrimary and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF
        end
    elseif equipType == EQUIP_TYPE_MAIN_HAND or equipType == EQUIP_TYPE_TWO_HAND then
        targetSlot = targetPrimary and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN
    elseif equipType == EQUIP_TYPE_OFF_HAND then
        targetSlot = targetPrimary and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF
    elseif equipType == EQUIP_TYPE_POISON then
        targetSlot = targetPrimary and EQUIP_SLOT_POISON or EQUIP_SLOT_BACKUP_POISON
    elseif equipType == EQUIP_TYPE_RING then
        targetSlot = mainSlot and EQUIP_SLOT_RING1 or EQUIP_SLOT_RING2
    end

    TraceInventoryEquip("move_resolved", bagId, slotIndex, {
        equipType = equipType,
        targetBag = BAG_WORN,
        targetSlot = targetSlot,
        mainSlot = mainSlot == true,
        primaryWeaponSet = targetPrimary,
        route = "equipSlotDialog",
    })
    if not targetSlot then
        TraceInventoryEquip("blocked", bagId, slotIndex, {
            reason = "missingTargetSlot",
            equipType = equipType,
            mainSlot = mainSlot == true,
            primaryWeaponSet = targetPrimary,
            route = "equipSlotDialog",
        })
        return false
    end

    TraceInventoryEquip("move_requested", bagId, slotIndex, {
        targetBag = BAG_WORN,
        targetSlot = targetSlot,
        quantity = 1,
        route = "equipSlotDialog",
    })
    local ok = CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, targetSlot, 1)
    if not ok then
        TraceInventoryEquip("request_failed", bagId, slotIndex, {
            targetBag = BAG_WORN,
            targetSlot = targetSlot,
            quantity = 1,
            route = "equipSlotDialog",
        })
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.ACTION, "RequestMoveItem failed via CallSecureProtected", {bagId = bagId, slotIndex = slotIndex, targetSlot = targetSlot}) end
        BETTERUI.CIM.UserNotifySecureActionFailed("EquipAction:EquipMove")
        return false
    end
    TraceInventoryEquip("requested", bagId, slotIndex, {
        targetBag = BAG_WORN,
        targetSlot = targetSlot,
        quantity = 1,
        route = "equipSlotDialog",
    })
    return true
end

local function GetEquipSlotDialogName()
    assert(BETTERUI.Inventory and BETTERUI.Inventory.GetEquipSlotDialogName,
        "BetterUI: Inventory.GetEquipSlotDialogName must load before EquipAction")
    return BETTERUI.Inventory.GetEquipSlotDialogName()
end

-- Companion equipment owns its canonical direct RequestMoveItem flow.
-- Keep this export as a compatibility no-op for older call sites.
local function EnsureCompanionEquipPatched()
    return true
end

BETTERUI.Inventory.EnsureCompanionEquipPatched = EnsureCompanionEquipPatched

function BETTERUI.Inventory.Class:TryEquipItem(inventorySlot, isCallingFromActionDialog)
    if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) and self.itemList then
        local freshTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
        if freshTarget and freshTarget.dataSource then
            inventorySlot = freshTarget
        end
    end

    local ds = inventorySlot and inventorySlot.dataSource
    if not ds then
        TraceInventoryEquip("skipped", nil, nil, { reason = "missingDataSource" })
        return
    end

    local equipType = ds.equipType
    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    TraceInventoryEquip("requested", bagId, slotIndex, {
        equipType = equipType,
        fromActionDialog = isCallingFromActionDialog == true,
        actorCategory = GetItemActorCategory and GetItemActorCategory(bagId, slotIndex) or nil,
    })

    local uid = ds.uniqueId or GetItemUniqueId(bagId, slotIndex)
    if uid then
        self._preserveUniqueId = uid
    end
    if self.itemList and self.itemList.selectedIndex then
        self._preserveIndex = self.itemList.selectedIndex
    end

    local bound = IsItemBound(bagId, slotIndex)
    local equipItemLink = GetItemLink(bagId, slotIndex)
    local bindType = GetItemLinkBindType(equipItemLink)

    local function showBindOnEquipDialog(callback)
        local boeProtection = BETTERUI.GetSetting("Inventory", "bindOnEquipProtection", true)
        if
            not bound
            and bindType == BIND_TYPE_ON_EQUIP
            -- Protection must default ON so unset profiles still get the BOE confirm.
            and boeProtection
        then
            local function promptForBindOnEquip()
                TraceInventoryEquip("boe_prompted", bagId, slotIndex, {
                    dialog = "CONFIRM_EQUIP_BOE",
                    queued = isCallingFromActionDialog == true,
                    route = "tryEquip",
                })
                ZO_Dialogs_ShowPlatformDialog(
                    "CONFIRM_EQUIP_BOE",
                    { callback = callback },
                    { mainTextParams = { equipItemLink } }
                )
            end
            if isCallingFromActionDialog then
                BETTERUI.Inventory.Tasks:Schedule("equipBindOnEquipDialog",
                    BETTERUI.Inventory.CONST.DIALOG_QUEUE_TIMEOUT_MS, promptForBindOnEquip)
            else
                promptForBindOnEquip()
            end
        else
            TraceInventoryEquip("boe_skipped", bagId, slotIndex, {
                bound = bound == true,
                bindType = bindType,
                protection = boeProtection == true,
                route = "tryEquip",
            })
            callback()
        end
    end

    if equipType == EQUIP_TYPE_COSTUME then
        -- Capture the slot identity before the (possibly queued) bind-on-equip
        -- confirmation so a changed slot cancels instead of equipping the wrong item.
        local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bagId, slotIndex, inventorySlot)
        showBindOnEquipDialog(function()
            if BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(expectedSlotIdentity, bagId, slotIndex) ~= true then
                TraceInventoryEquip("stale", bagId, slotIndex, {
                    route = "costume",
                    reason = "slotIdentityChanged",
                })
                BETTERUI.CIM.UserNotify("EquipAction:StaleSlot",
                    GetString(rawget(_G, "SI_BETTERUI_ITEM_CHANGED_CANCELLED")))
                return
            end
            TraceInventoryEquip("move_requested", bagId, slotIndex, {
                targetBag = BAG_WORN,
                targetSlot = EQUIP_SLOT_COSTUME,
                quantity = 1,
                route = "costume",
            })
            if not CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, EQUIP_SLOT_COSTUME, 1) then
                TraceInventoryEquip("request_failed", bagId, slotIndex, {
                    targetBag = BAG_WORN,
                    targetSlot = EQUIP_SLOT_COSTUME,
                    quantity = 1,
                    route = "costume",
                })
                BETTERUI.CIM.UserNotifySecureActionFailed("EquipAction:EquipCostume")
            else
                TraceInventoryEquip("requested", bagId, slotIndex, {
                    targetBag = BAG_WORN,
                    targetSlot = EQUIP_SLOT_COSTUME,
                    quantity = 1,
                    route = "costume",
                })
            end
        end)
    elseif
        equipType == EQUIP_TYPE_ONE_HAND
        or equipType == EQUIP_TYPE_RING
        or equipType == EQUIP_TYPE_MAIN_HAND
        or equipType == EQUIP_TYPE_TWO_HAND
        or equipType == EQUIP_TYPE_OFF_HAND
        or equipType == EQUIP_TYPE_POISON
    then
        local function showEquipDialog()
            -- Capture the slot identity at dialog-open time so the equip move can be
            -- cancelled if the slot contents change while the dialog (or the queued
            -- bind-on-equip confirmation) is up.
            local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bagId, slotIndex, inventorySlot)
            TraceInventoryEquip("slot_dialog_show", bagId, slotIndex, {
                dialog = GetEquipSlotDialogName(),
                equipType = equipType,
                primaryWeaponSet = self.isPrimaryWeapon == true,
                fromActionDialog = isCallingFromActionDialog == true,
            })
            ZO_Dialogs_ShowDialog(
                GetEquipSlotDialogName(),
                { inventorySlot, self.isPrimaryWeapon, expectedSlotIdentity = expectedSlotIdentity },
                { mainTextParams = { GetString(rawget(_G, "SI_BETTERUI_INV_EQUIPSLOT_MAIN")) } },
                true
            )
        end

        if isCallingFromActionDialog then
            TraceInventoryEquip("slot_dialog_queued", bagId, slotIndex, {
                dialog = GetEquipSlotDialogName(),
                equipType = equipType,
                delayMs = BETTERUI.Inventory.CONST.DIALOG_QUEUE_TIMEOUT_MS,
            })
            BETTERUI.Inventory.Tasks:Schedule("equipSlotDialog", BETTERUI.Inventory.CONST.DIALOG_QUEUE_TIMEOUT_MS,
                showEquipDialog)
        else
            showEquipDialog()
        end
    else
        -- Capture the slot identity before the (possibly queued) bind-on-equip
        -- confirmation so a changed slot cancels instead of equipping the wrong item.
        local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bagId, slotIndex, inventorySlot)
        showBindOnEquipDialog(function()
            if BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(expectedSlotIdentity, bagId, slotIndex) ~= true then
                TraceInventoryEquip("stale", bagId, slotIndex, {
                    route = "directEquip",
                    reason = "slotIdentityChanged",
                })
                BETTERUI.CIM.UserNotify("EquipAction:StaleSlot",
                    GetString(rawget(_G, "SI_BETTERUI_ITEM_CHANGED_CANCELLED")))
                return
            end
            local equipSucceeds, possibleError = IsEquipable(bagId, slotIndex)
            TraceInventoryEquip("equipable_checked", bagId, slotIndex, {
                result = equipSucceeds == true,
                reason = possibleError,
                route = "directEquip",
            })
            if equipSucceeds then
                local wornBag = GetItemActorCategory(bagId, slotIndex) == GAMEPLAY_ACTOR_CATEGORY_PLAYER and BAG_WORN or
                    BAG_COMPANION_WORN
                TraceInventoryEquip("request_equip_requested", bagId, slotIndex, {
                    targetBag = wornBag,
                    route = "directEquip",
                })
                RequestEquipItem(bagId, slotIndex, wornBag)
                TraceInventoryEquip("request_equip_dispatched", bagId, slotIndex, {
                    targetBag = wornBag,
                    route = "directEquip",
                })
            else
                TraceInventoryEquip("blocked", bagId, slotIndex, {
                    reason = possibleError,
                    route = "directEquip",
                })
                BETTERUI.CIM.UserNotify("EquipAction:Equip",
                    possibleError or GetString(rawget(_G, "SI_INVENTORY_ERROR_ITEM_CANNOT_BE_EQUIPPED")))
            end
        end)
    end
end

function BETTERUI.Inventory.Class:InitializeEquipSlotDialog()
    local function ReleaseDialog(data, mainSlot)
        local ds = data[1] and data[1].dataSource
        if not ds then return end
        local equipType = ds.equipType
        local bound = IsItemBound(ds.bagId, ds.slotIndex)
        local equipItemLink = GetItemLink(ds.bagId, ds.slotIndex)
        local bindType = GetItemLinkBindType(equipItemLink)
        local expectedSlotIdentity = data.expectedSlotIdentity
        TraceInventoryEquip("slot_dialog_release", ds.bagId, ds.slotIndex, {
            dialog = GetEquipSlotDialogName(),
            equipType = equipType,
            mainSlot = mainSlot == true,
            primaryWeaponSet = data[2] ~= false,
        })

        local equipItemCallback = function()
            -- Re-verify at execution time: the slot may have changed while the
            -- equip-slot dialog or the delayed bind-on-equip confirmation was up.
            if BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(expectedSlotIdentity, ds.bagId, ds.slotIndex) ~= true then
                TraceInventoryEquip("stale", ds.bagId, ds.slotIndex, {
                    route = "equipSlotDialog",
                    reason = "slotIdentityChanged",
                })
                BETTERUI.CIM.UserNotify("EquipAction:StaleSlot",
                    GetString(rawget(_G, "SI_BETTERUI_ITEM_CHANGED_CANCELLED")))
                return
            end
            TraceInventoryEquip("slot_dialog_accept", ds.bagId, ds.slotIndex, {
                dialog = GetEquipSlotDialogName(),
                mainSlot = mainSlot == true,
                primaryWeaponSet = data[2] ~= false,
            })
            DoEquipMove(ds.bagId, ds.slotIndex, equipType, mainSlot, data[2])
        end

        ZO_Dialogs_ReleaseDialogOnButtonPress(GetEquipSlotDialogName())

        if
            not bound
            and bindType == BIND_TYPE_ON_EQUIP
            -- Protection must default ON so unset profiles still get the BOE confirm.
            and BETTERUI.GetSetting("Inventory", "bindOnEquipProtection", true)
        then
            -- Let the equip-slot dialog finish releasing before queueing the
            -- bind-on-equip confirmation (no engine constant exposes this).
            local delay = 300
            TraceInventoryEquip("boe_queued", ds.bagId, ds.slotIndex, {
                dialog = "CONFIRM_EQUIP_BOE",
                route = "equipSlotDialog",
                delayMs = delay,
            })
            BETTERUI.Inventory.Tasks:Schedule("equipBOEConfirmDialog", delay, function()
                TraceInventoryEquip("boe_prompted", ds.bagId, ds.slotIndex, {
                    dialog = "CONFIRM_EQUIP_BOE",
                    route = "equipSlotDialog",
                })
                ZO_Dialogs_ShowPlatformDialog(
                    "CONFIRM_EQUIP_BOE",
                    { callback = equipItemCallback },
                    { mainTextParams = { equipItemLink } }
                )
            end)
        else
            TraceInventoryEquip("boe_skipped", ds.bagId, ds.slotIndex, {
                bound = bound == true,
                bindType = bindType,
                protection = BETTERUI.GetSetting("Inventory", "bindOnEquipProtection", true) == true,
                route = "equipSlotDialog",
            })
            equipItemCallback()
        end
    end

    local function GetDialogSwitchButtonText(isPrimary)
        return GetString(rawget(_G, "SI_BETTERUI_INV_SWITCH_EQUIPSLOT"))
    end

    local function GetDialogEquipType(dialog)
        local entry = dialog.data and dialog.data[1]
        local ds = entry and entry.dataSource
        return ds and ds.equipType
    end

    local function GetDialogMainText(dialog)
        local ds = dialog.data[1] and dialog.data[1].dataSource
        if not ds then return "" end
        local equipType = ds.equipType
        local itemName = GetItemName(ds.bagId, ds.slotIndex)
        local itemLink = GetItemLink(ds.bagId, ds.slotIndex)
        local itemQuality = GetItemLinkFunctionalQuality(itemLink)
        local itemColor = GetItemQualityColor(itemQuality)
        itemName = itemColor:Colorize(itemName)
        local str = ""
        local weaponChoice = GetString(rawget(_G, "SI_BETTERUI_INV_EQUIPSLOT_MAIN"))
        if not dialog.data[2] then
            weaponChoice = GetString(rawget(_G, "SI_BETTERUI_INV_EQUIPSLOT_BACKUP"))
        end
        if equipType == EQUIP_TYPE_ONE_HAND then
            str = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_INV_EQUIP_ONE_HAND_WEAPON")), itemName, weaponChoice)
        elseif
            equipType == EQUIP_TYPE_MAIN_HAND
            or equipType == EQUIP_TYPE_OFF_HAND
            or equipType == EQUIP_TYPE_TWO_HAND
            or equipType == EQUIP_TYPE_POISON
        then
            str = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_INV_EQUIP_OTHER_WEAPON")), itemName, weaponChoice)
        elseif equipType == EQUIP_TYPE_RING then
            str = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_INV_EQUIP_RING")), itemName)
        end
        return str
    end

    BETTERUI.CIM.Dialogs.Register(GetEquipSlotDialogName(), {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
            allowRightStickPassThrough = true,
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        title = {
            text = GetString(rawget(_G, "SI_BETTERUI_INV_EQUIPSLOT_TITLE")),
        },
        mainText = {
            text = function(dialog)
                return GetDialogMainText(dialog)
            end,
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = function(dialog)
                    local equipType = GetDialogEquipType(dialog)
                    if equipType == EQUIP_TYPE_ONE_HAND then
                        return GetString(rawget(_G, "SI_BETTERUI_INV_EQUIP_PROMPT_MAIN"))
                    elseif
                        equipType == EQUIP_TYPE_MAIN_HAND
                        or equipType == EQUIP_TYPE_OFF_HAND
                        or equipType == EQUIP_TYPE_TWO_HAND
                        or equipType == EQUIP_TYPE_POISON
                    then
                        return GetString(rawget(_G, "SI_BETTERUI_INV_EQUIP"))
                    elseif equipType == EQUIP_TYPE_RING then
                        return GetString(rawget(_G, "SI_BETTERUI_INV_FIRST_SLOT"))
                    end
                    return ""
                end,
                callback = function(dialog)
                    local ds = dialog and dialog.data and dialog.data[1] and dialog.data[1].dataSource
                    if ds then
                        TraceInventoryEquip("slot_dialog_button", ds.bagId, ds.slotIndex, {
                            button = "primary",
                            dialog = GetEquipSlotDialogName(),
                        })
                    end
                    ReleaseDialog(dialog.data, true)
                end,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = function(dialog)
                    local equipType = GetDialogEquipType(dialog)
                    if equipType == EQUIP_TYPE_ONE_HAND then
                        return GetString(rawget(_G, "SI_BETTERUI_INV_EQUIP_PROMPT_BACKUP"))
                    elseif
                        equipType == EQUIP_TYPE_MAIN_HAND
                        or equipType == EQUIP_TYPE_OFF_HAND
                        or equipType == EQUIP_TYPE_TWO_HAND
                        or equipType == EQUIP_TYPE_POISON
                    then
                        return ""
                    elseif equipType == EQUIP_TYPE_RING then
                        return GetString(rawget(_G, "SI_BETTERUI_INV_SECOND_SLOT"))
                    end
                    return ""
                end,
                visible = function(dialog)
                    local equipType = GetDialogEquipType(dialog)
                    if equipType == EQUIP_TYPE_ONE_HAND or equipType == EQUIP_TYPE_RING then
                        return true
                    end
                    return false
                end,
                callback = function(dialog)
                    local ds = dialog and dialog.data and dialog.data[1] and dialog.data[1].dataSource
                    if ds then
                        TraceInventoryEquip("slot_dialog_button", ds.bagId, ds.slotIndex, {
                            button = "secondary",
                            dialog = GetEquipSlotDialogName(),
                        })
                    end
                    ReleaseDialog(dialog.data, false)
                end,
            },
            {
                keybind = "DIALOG_TERTIARY",
                text = function(dialog)
                    return GetDialogSwitchButtonText(dialog.data[2])
                end,
                visible = function(dialog)
                    if GetUnitLevel("player") < GetWeaponSwapUnlockedLevel() then
                        return false
                    end
                    local equipType = GetDialogEquipType(dialog)
                    return equipType ~= nil and equipType ~= EQUIP_TYPE_RING
                end,
                callback = function(dialog)
                    local ds = dialog and dialog.data and dialog.data[1] and dialog.data[1].dataSource
                    if ds then
                        TraceInventoryEquip("slot_dialog_toggle", ds.bagId, ds.slotIndex, {
                            oldPrimaryWeaponSet = dialog.data[2] == true,
                            newPrimaryWeaponSet = dialog.data[2] ~= true,
                        })
                    end
                    dialog.data[2] = not dialog.data[2]
                    GAMEPAD_INVENTORY.isPrimaryWeapon = dialog.data[2]
                    GAMEPAD_INVENTORY:RefreshHeader()
                    ZO_GenericGamepadDialog_RefreshText(
                        dialog,
                        dialog.headerData.titleText,
                        GetDialogMainText(dialog),
                        ""
                    )
                    ZO_GenericGamepadDialog_RefreshKeybinds(dialog)
                    if ds then
                        TraceInventoryEquip("slot_dialog_keybinds_refreshed", ds.bagId, ds.slotIndex, {
                            primaryWeaponSet = dialog.data[2] == true,
                        })
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                alignment = KEYBIND_STRIP_ALIGN_RIGHT,
                text = SI_DIALOG_CANCEL,
                callback = function(dialog)
                    local ds = dialog and dialog.data and dialog.data[1] and dialog.data[1].dataSource
                    if ds then
                        TraceInventoryEquip("slot_dialog_cancel", ds.bagId, ds.slotIndex, {
                            dialog = GetEquipSlotDialogName(),
                        })
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(GetEquipSlotDialogName())
                end,
            },
        },
    })
end
