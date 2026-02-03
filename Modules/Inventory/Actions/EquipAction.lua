--[[
File: Modules/Inventory/Actions/EquipAction.lua
Purpose: Handles item equipping logic, including "Bind on Equip" protection,
         equipment slot selection dialogs (e.g. Ring 1 vs Ring 2), and companion equipment patching.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

--------------------------------------------------------------------------------
-- SHARED EQUIP HELPER
--------------------------------------------------------------------------------

--[[
Function: DoEquipMove
Description: Performs the actual equip move via CallSecureProtected.
Rationale: Centralizes the equip slot resolution logic to eliminate duplication
           between performEquipAction and ReleaseDialog's equipItemCallback.
Mechanism: Maps equipment type + slot preference to target equip slot, then calls RequestMoveItem.
References: Used by TryEquipItem and InitializeEquipSlotDialog.
param: bagId (number) - Source bag ID.
param: slotIndex (number) - Source slot index.
param: equipType (number) - Equipment type constant (EQUIP_TYPE_*).
param: mainSlot (boolean) - For 1H/rings: true = main hand/ring 1, false = off hand/ring 2.
param: isPrimary (boolean) - For weapons: true = front bar, false = back bar.
]]
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

    if targetSlot then
        CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, targetSlot, 1)
    end
end

--------------------------------------------------------------------------------
-- COMPANION EQUIP PATCHING
--------------------------------------------------------------------------------

local COMPANION_EQUIP_PATCH_EVENT_NAME = "BETTERUI_CompanionEquipPatch"
local COMPANION_EQUIP_PATCH_RETRY_MS = 400
local companionEquipPatchQueued = false
local companionEquipPatchRetryPending = false

-- Patches ZO_CompanionEquipment_Gamepad:TryEquipItem for bind-on-equip handling
local function AttemptCompanionEquipPatch()
    local class = _G["ZO_CompanionEquipment_Gamepad"]
    if not class then
        return false
    end
    if class._betterui_tryEquipPatched then
        return true
    end
    local orig = class.TryEquipItem
    if type(orig) ~= "function" then
        return false
    end
    class.TryEquipItem = function(self, inventorySlot)
        if self and self.selectedEquipSlot and inventorySlot then
            local sourceBag, sourceSlot = ZO_Inventory_GetBagAndIndex(inventorySlot)
            if sourceBag and sourceSlot then
                local function DoEquip()
                    CallSecureProtected("RequestMoveItem", sourceBag, sourceSlot, BAG_COMPANION_WORN,
                        self.selectedEquipSlot, 1)
                end
                if ZO_InventorySlot_WillItemBecomeBoundOnEquip(sourceBag, sourceSlot) then
                    local itemDisplayQuality = GetItemDisplayQuality(sourceBag, sourceSlot)
                    local itemDisplayQualityColor = GetItemQualityColor(itemDisplayQuality)
                    ZO_Dialogs_ShowPlatformDialog("CONFIRM_EQUIP_ITEM", { onAcceptCallback = DoEquip },
                        { mainTextParams = { itemDisplayQualityColor:Colorize(GetItemName(sourceBag, sourceSlot)) } })
                else
                    DoEquip()
                end
                return
            end
        end

        return orig(self, inventorySlot)
    end
    class._betterui_tryEquipPatched = true
    return true
end

local function EnsureCompanionEquipPatched()
    if AttemptCompanionEquipPatch() then
        if EVENT_MANAGER and EVENT_MANAGER.UnregisterForEvent then
            EVENT_MANAGER:UnregisterForEvent(COMPANION_EQUIP_PATCH_EVENT_NAME, EVENT_PLAYER_ACTIVATED)
        end
        companionEquipPatchQueued = false
        companionEquipPatchRetryPending = false
        return true
    end
    if EVENT_MANAGER and EVENT_MANAGER.RegisterForEvent and not companionEquipPatchQueued then
        companionEquipPatchQueued = true

        BETTERUI.CIM.EventRegistry.Register("Inventory", COMPANION_EQUIP_PATCH_EVENT_NAME, EVENT_PLAYER_ACTIVATED,
            function()
                BETTERUI.CIM.EventRegistry.Unregister("Inventory", COMPANION_EQUIP_PATCH_EVENT_NAME,
                    EVENT_PLAYER_ACTIVATED)
                companionEquipPatchQueued = false
                EnsureCompanionEquipPatched()
            end)
    end
    if not companionEquipPatchRetryPending and BETTERUI.Inventory.Tasks then
        companionEquipPatchRetryPending = true

        BETTERUI.Inventory.Tasks:Schedule("companionEquipPatchRetry", COMPANION_EQUIP_PATCH_RETRY_MS, function()
            companionEquipPatchRetryPending = false
            EnsureCompanionEquipPatched()
        end)
    end
    return false
end

-- Expose for external calls
BETTERUI.Inventory.EnsureCompanionEquipPatched = EnsureCompanionEquipPatched

--------------------------------------------------------------------------------
-- EQUIP LOGIC
--------------------------------------------------------------------------------

--- Attempts to equip the selected item.
---
--- Purpose: Handles item equipping logic with safety checks.
--- Mechanics:
--- 1. Checks BOE (Bind on Equip) status and Settings.Prompts dialog if needed.
--- 2. Determines target slot (Main/Off hand, Backup Bar) based on item type.
--- 3. Call `RequestMoveItem` via `CallSecureProtected`.
--- 4. Handles rings (Slot 1 vs 2).
--- 5. Handles Costumes vs Gear.
--- References: Called from "A" keybind (Equip).
---
--- @param inventorySlot table The data of the item to equip.
--- @param isCallingFromActionDialog boolean True if called from the actions dialog (delays dialogs slightly).
function BETTERUI.Inventory.Class:TryEquipItem(inventorySlot, isCallingFromActionDialog)
    -- Y-MENU FIX: The engine's gamepad_equip handler calls TryEquipItem(inventorySlot) without the
    -- isCallingFromActionDialog parameter, so we check if action dialog IS showing instead.
    -- When Y-menu is open, retrieve fresh data from current selection to avoid stale closure data.
    if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) and self.itemList then
        local freshTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
        if freshTarget and freshTarget.dataSource then
            -- Use fresh data if available
            inventorySlot = freshTarget
        end
    end

    local equipType = inventorySlot.dataSource.equipType
    local bagId = inventorySlot.dataSource.bagId
    local slotIndex = inventorySlot.dataSource.slotIndex

    -- POSITION PRESERVATION: Save uniqueId at action START, before inventory callbacks corrupt data
    -- This ensures we stay focused on THIS item after equip (it moves to BAG_WORN)
    local uid = inventorySlot.dataSource.uniqueId or GetItemUniqueId(bagId, slotIndex)
    if uid then
        self._preserveUniqueId = uid
    end
    if self.itemList and self.itemList.selectedIndex then
        self._preserveIndex = self.itemList.selectedIndex
    end

    -- Check if item is bound and handle bind-on-equip protection
    local bound = IsItemBound(bagId, slotIndex)
    local equipItemLink = GetItemLink(bagId, slotIndex)
    local bindType = GetItemLinkBindType(equipItemLink)

    local function showBindOnEquipDialog(callback)
        if
            not bound
            and bindType == BIND_TYPE_ON_EQUIP
            and BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection
        then
            local function promptForBindOnEquip()
                ZO_Dialogs_ShowPlatformDialog(
                    "CONFIRM_EQUIP_BOE",
                    { callback = callback },
                    { mainTextParams = { equipItemLink } }
                )
            end
            if isCallingFromActionDialog then
                -- Delay required to allow previous dialog to fully close before opening new one
                BETTERUI.Inventory.Tasks:Schedule("equipBindOnEquipDialog",
                    BETTERUI.CONST.INVENTORY.DIALOG_QUEUE_TIMEOUT_MS, promptForBindOnEquip)
            else
                promptForBindOnEquip()
            end
        else
            callback()
        end
    end

    -- Determine equip action based on item type
    local function performEquipAction(mainSlot, isPrimary)
        -- isPrimary indicates which weapon bar to target (true = primary/front bar, false = backup/back bar)
        DoEquipMove(bagId, slotIndex, equipType, mainSlot, isPrimary)
    end

    -- Handle different equip types
    if equipType == EQUIP_TYPE_COSTUME then
        -- Costumes equip directly
        showBindOnEquipDialog(function()
            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, EQUIP_SLOT_COSTUME, 1)
        end)
    elseif
        equipType == EQUIP_TYPE_ONE_HAND
        or equipType == EQUIP_TYPE_RING
        or equipType == EQUIP_TYPE_MAIN_HAND
        or equipType == EQUIP_TYPE_TWO_HAND
        or equipType == EQUIP_TYPE_OFF_HAND
        or equipType == EQUIP_TYPE_POISON
    then
        -- Weapons and rings: prompt to choose bar (primary/backup) and, if applicable, hand
        local function showEquipDialog()
            ZO_Dialogs_ShowDialog(
                BETTERUI_EQUIP_SLOT_DIALOG,
                { inventorySlot, self.isPrimaryWeapon },
                { mainTextParams = { GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN) } },
                true
            )
        end

        if isCallingFromActionDialog then
            -- Delay required to allow previous dialog to fully close before opening new one
            BETTERUI.Inventory.Tasks:Schedule("equipSlotDialog", BETTERUI.CONST.INVENTORY.DIALOG_QUEUE_TIMEOUT_MS,
                showEquipDialog)
        else
            showEquipDialog()
        end
    else
        -- Items that equip directly (armor, necklaces, etc.)
        -- Use RequestEquipItem which handles swapping automatically (unlike RequestMoveItem)
        showBindOnEquipDialog(function()
            local equipSucceeds, possibleError = IsEquipable(bagId, slotIndex)
            if equipSucceeds then
                local wornBag = GetItemActorCategory(bagId, slotIndex) == GAMEPLAY_ACTOR_CATEGORY_PLAYER and BAG_WORN or
                    BAG_COMPANION_WORN
                RequestEquipItem(bagId, slotIndex, wornBag)
            else
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
                    possibleError or GetString(SI_INVENTORY_ERROR_ITEM_CANNOT_BE_EQUIPPED))
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- EQUIP SLOT DIALOG
--------------------------------------------------------------------------------

--- Initializes the custom dialog for selecting equipment slots (e.g., Ring 1 vs Ring 2).
function BETTERUI.Inventory.Class:InitializeEquipSlotDialog()
    local dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.BASIC)

    local function ReleaseDialog(data, mainSlot)
        local equipType = data[1].dataSource.equipType
        local bound = IsItemBound(data[1].dataSource.bagId, data[1].dataSource.slotIndex)
        local equipItemLink = GetItemLink(data[1].dataSource.bagId, data[1].dataSource.slotIndex)
        local bindType = GetItemLinkBindType(equipItemLink)

        local equipItemCallback = function()
            -- data[2] indicates primary bar selection (true = front bar, false = back bar)
            DoEquipMove(data[1].dataSource.bagId, data[1].dataSource.slotIndex, equipType, mainSlot, data[2])
        end

        ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_EQUIP_SLOT_DIALOG)

        if
            not bound
            and bindType == BIND_TYPE_ON_EQUIP
            and BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection
        then
            -- Use global DIALOG_QUEUE_WORKAROUND_TIMEOUT_DURATION if defined, or safe default
            local delay = DIALOG_QUEUE_WORKAROUND_TIMEOUT_DURATION or 300
            BETTERUI.Inventory.Tasks:Schedule("equipBOEConfirmDialog", delay, function()
                ZO_Dialogs_ShowPlatformDialog(
                    "CONFIRM_EQUIP_BOE",
                    { callback = equipItemCallback },
                    { mainTextParams = { equipItemLink } }
                )
            end)
        else
            equipItemCallback()
        end
    end

    local function GetDialogSwitchButtonText(isPrimary)
        return GetString(SI_BETTERUI_INV_SWITCH_EQUIPSLOT)
    end

    local function GetDialogMainText(dialog)
        local equipType = dialog.data[1].dataSource.equipType
        local itemName = GetItemName(dialog.data[1].dataSource.bagId, dialog.data[1].dataSource.slotIndex)
        local itemLink = GetItemLink(dialog.data[1].dataSource.bagId, dialog.data[1].dataSource.slotIndex)
        local itemQuality = GetItemLinkFunctionalQuality(itemLink)
        local itemColor = GetItemQualityColor(itemQuality)
        itemName = itemColor:Colorize(itemName)
        local str = ""
        local weaponChoice = GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN)
        if not dialog.data[2] then
            weaponChoice = GetString(SI_BETTERUI_INV_EQUIPSLOT_BACKUP)
        end
        if equipType == EQUIP_TYPE_ONE_HAND then
            str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_ONE_HAND_WEAPON), itemName, weaponChoice)
        elseif
            equipType == EQUIP_TYPE_MAIN_HAND
            or equipType == EQUIP_TYPE_OFF_HAND
            or equipType == EQUIP_TYPE_TWO_HAND
            or equipType == EQUIP_TYPE_POISON
        then
            str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_OTHER_WEAPON), itemName, weaponChoice)
        elseif equipType == EQUIP_TYPE_RING then
            str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_RING), itemName)
        end
        return str
    end

    BETTERUI.CIM.Dialogs.Register(BETTERUI_EQUIP_SLOT_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
            allowRightStickPassThrough = true,
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        title = {
            text = GetString(SI_BETTERUI_INV_EQUIPSLOT_TITLE),
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
                    local equipType = dialog.data[1].dataSource.equipType
                    if equipType == EQUIP_TYPE_ONE_HAND then
                        return GetString(SI_BETTERUI_INV_EQUIP_PROMPT_MAIN)
                    elseif
                        equipType == EQUIP_TYPE_MAIN_HAND
                        or equipType == EQUIP_TYPE_OFF_HAND
                        or equipType == EQUIP_TYPE_TWO_HAND
                        or equipType == EQUIP_TYPE_POISON
                    then
                        return GetString(SI_BETTERUI_INV_EQUIP)
                    elseif equipType == EQUIP_TYPE_RING then
                        return GetString(SI_BETTERUI_INV_FIRST_SLOT)
                    end
                    return ""
                end,
                callback = function(dialog)
                    ReleaseDialog(dialog.data, true)
                end,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = function(dialog)
                    local equipType = dialog.data[1].dataSource.equipType
                    if equipType == EQUIP_TYPE_ONE_HAND then
                        return GetString(SI_BETTERUI_INV_EQUIP_PROMPT_BACKUP)
                    elseif
                        equipType == EQUIP_TYPE_MAIN_HAND
                        or equipType == EQUIP_TYPE_OFF_HAND
                        or equipType == EQUIP_TYPE_TWO_HAND
                        or equipType == EQUIP_TYPE_POISON
                    then
                        return ""
                    elseif equipType == EQUIP_TYPE_RING then
                        return GetString(SI_BETTERUI_INV_SECOND_SLOT)
                    end
                    return ""
                end,
                visible = function(dialog)
                    local equipType = dialog.data[1].dataSource.equipType
                    if equipType == EQUIP_TYPE_ONE_HAND or equipType == EQUIP_TYPE_RING then
                        return true
                    end
                    return false
                end,
                callback = function(dialog)
                    ReleaseDialog(dialog.data, false)
                end,
            },
            {
                keybind = "DIALOG_TERTIARY",
                text = function(dialog)
                    return GetDialogSwitchButtonText(dialog.data[2])
                end,
                visible = function(dialog)
                    if not (GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()) then
                        return false
                    end
                    local equipType = dialog.data[1].dataSource.equipType
                    return equipType ~= EQUIP_TYPE_RING
                end,
                callback = function(dialog)
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
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                alignment = KEYBIND_STRIP_ALIGN_RIGHT,
                text = SI_DIALOG_CANCEL,
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_EQUIP_SLOT_DIALOG)
                end,
            },
        },
    })
end
