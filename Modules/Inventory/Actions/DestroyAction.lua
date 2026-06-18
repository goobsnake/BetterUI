-- Inventory destroy-action helpers.

local BLOCK_TABBAR_CALLBACK = true

local function CanForceDestroyItem(bagId, slotIndex, slotType)
    return BETTERUI.Inventory.CanDestroyItemWithPolicy(bagId, slotIndex, slotType) == true
end

local function GetProtectionPolicy()
    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before inventory destroy-policy checks")
    return policy
end

local function RequireProtectionPolicyMethod(methodName)
    local policy = GetProtectionPolicy()
    local method = policy and policy[methodName] or nil
    assert(type(method) == "function",
        string.format("BetterUI: CIM.ProtectionPolicy.%s must load before inventory destroy-policy checks", tostring(methodName)))
    return method
end

local function CanDestroyItemWithPolicy(bagId, slotIndex, slotType)
    return RequireProtectionPolicyMethod("CanDestroyItem")(bagId, slotIndex, slotType) == true
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
    if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "Destroy item request", {bagId = bagId, slotIndex = slotIndex, force = force}) end
    if not bagId or not slotIndex then
        return false
    end
    if not CanDestroyItemWithPolicy(bagId, slotIndex, slotType) then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SAFE, "Destroy blocked by protection policy", {bagId = bagId, slotIndex = slotIndex}) end
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
        if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "InitiateDestroyItem Hook fired", {bag = bag, index = index}) end
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
        local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bag, index, inventorySlot)
        ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
            { bagId = bag, slotIndex = index, slotType = slotType, itemLink = link, expectedSlotIdentity = expectedSlotIdentity }, nil, true, true)
        return true
    end)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "rawHookInstalled", { method = "ZO_InventorySlot_InitiateDestroyItem", target = type("ZO_InventorySlot_InitiateDestroyItem") }) end

    BETTERUI.Inventory._destroyHookInstalled = true
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "destroyItemHookInstalled") end
end
