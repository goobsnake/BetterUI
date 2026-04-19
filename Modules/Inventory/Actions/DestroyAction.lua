-- Inventory destroy-action helpers.

local BLOCK_TABBAR_CALLBACK = true

local function CanForceDestroyItem(bagId, slotIndex, slotType)
    local policy = BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy
    if policy and policy.CanDestroyItem then
        return policy.CanDestroyItem(bagId, slotIndex, slotType) == true
    end

    return true
end

local function GetProtectionPolicy()
    return BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy
end

local function CanDestroyItemWithPolicy(bagId, slotIndex, slotType)
    local policy = GetProtectionPolicy()
    if policy and policy.CanDestroyItem then
        return policy.CanDestroyItem(bagId, slotIndex, slotType) == true
    end
    return true
end

BETTERUI.Inventory.CanDestroyItemWithPolicy = CanDestroyItemWithPolicy

local function ForceDestroyItemSafely(bagId, slotIndex)
    if SetCursorItemSoundsEnabled then
        SetCursorItemSoundsEnabled(false)
    end

    local ok = BETTERUI.CIM.SafeExecute(
        string.format("DestroyItem:%s:%s", tostring(bagId), tostring(slotIndex)),
        DestroyItem, bagId, slotIndex
    )

    if SetCursorItemSoundsEnabled then
        SetCursorItemSoundsEnabled(true)
    end

    return ok
end

function BETTERUI.Inventory.TryDestroyItem(bagId, slotIndex, force, suppressUiRefresh, slotType)
    if not bagId or not slotIndex then
        return false
    end
    if not CanDestroyItemWithPolicy(bagId, slotIndex, slotType) then
        return false
    end

    if force then
        local canDestroy = CanForceDestroyItem(bagId, slotIndex, slotType)
        if not canDestroy then
            return false
        end

        -- Direct engine destroy path (matches the original working hook behavior)
        if not ForceDestroyItemSafely(bagId, slotIndex) then
            return false
        end

        if not suppressUiRefresh then
            if SHARED_INVENTORY and SHARED_INVENTORY.PerformFullUpdateOnBagCache then
                SHARED_INVENTORY:PerformFullUpdateOnBagCache(bagId)
            end
            BETTERUI.Inventory.Tasks:Schedule("destroyItemRefresh", 80, function()
                if GAMEPAD_INVENTORY then
                    if GAMEPAD_INVENTORY.RefreshItemList then
                        GAMEPAD_INVENTORY:RefreshItemList()
                    end
                    if GAMEPAD_INVENTORY.RefreshCategoryList then
                        GAMEPAD_INVENTORY:RefreshCategoryList()
                    end
                    if GAMEPAD_INVENTORY.RefreshHeader then
                        GAMEPAD_INVENTORY:RefreshHeader(BLOCK_TABBAR_CALLBACK)
                    end
                end
            end)
        end

        return true
    end
    return false
end

function BETTERUI.Inventory.HookDestroyItem()
    if BETTERUI.Inventory._destroyHookInstalled then
        return
    end
    if type(ZO_PreHook) ~= "function" then
        return
    end

    ZO_PreHook("ZO_InventorySlot_InitiateDestroyItem", function(inventorySlot)
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        if not bag or not index then
            return false
        end
        local slotType = inventorySlot and inventorySlot.slotType or nil
        if not CanDestroyItemWithPolicy(bag, index, slotType) then
            return true
        end

        local quick = BETTERUI.GetSetting("Inventory", "quickDestroy", false) == true

        if BETTERUI.Inventory.TryDestroyItem(bag, index, quick, false, slotType) then
            return true
        end

        if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        end
        local link = GetItemLink(bag, index)
        ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
            { bagId = bag, slotIndex = index, itemLink = link }, nil, true, true)
        return true
    end)

    BETTERUI.Inventory._destroyHookInstalled = true
end
