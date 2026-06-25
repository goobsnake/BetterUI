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

local function IsDestroyTraceActive()
    return BETTERUI.Log and BETTERUI.Log.IsActive and BETTERUI.Log.IsActive()
end

local function TraceDestroyAction(phase, data)
    if not IsDestroyTraceActive() then
        return
    end
    data = data or {}
    data.phase = phase
    BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "inventory destroy", data)
end

local function BuildDestroyTracePayload(bagId, slotIndex, slotType, data)
    data = data or {}
    data.bagId = bagId
    data.slotIndex = slotIndex
    data.slotType = slotType
    if bagId and slotIndex and not data.skipLiveSlotRead and IsDestroyTraceActive() then
        if GetItemName then
            local ok, name = pcall(GetItemName, bagId, slotIndex)
            if ok then data.name = name end
        end
        if GetSlotStackSize then
            local ok, stackCount = pcall(GetSlotStackSize, bagId, slotIndex)
            if ok then data.stackCount = stackCount end
        end
    end
    data.skipLiveSlotRead = nil
    return data
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
    TraceDestroyAction("request", BuildDestroyTracePayload(bagId, slotIndex, slotType, {
        force = force == true,
        suppressUiRefresh = suppressUiRefresh == true,
    }))
    if not bagId or not slotIndex then
        TraceDestroyAction("blocked", BuildDestroyTracePayload(bagId, slotIndex, slotType, { reason = "invalidSlot" }))
        return false
    end
    if not CanDestroyItemWithPolicy(bagId, slotIndex, slotType) then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SAFE, "Destroy blocked by protection policy", {bagId = bagId, slotIndex = slotIndex}) end
        TraceDestroyAction("blocked", BuildDestroyTracePayload(bagId, slotIndex, slotType, { reason = "protectionPolicy" }))
        return false
    end

    if force then
        local canDestroy = CanForceDestroyItem(bagId, slotIndex, slotType)
        if not canDestroy then
            TraceDestroyAction("blocked", BuildDestroyTracePayload(bagId, slotIndex, slotType, { reason = "forcePolicy" }))
            return false
        end

        -- Direct engine destroy path (matches the original working hook behavior)
        if not ForceDestroyItemSafely(bagId, slotIndex) then
            TraceDestroyAction("failed", BuildDestroyTracePayload(bagId, slotIndex, slotType, { reason = "engineDestroyFailed" }))
            return false
        end

        if not suppressUiRefresh then
            TraceDestroyAction("refresh_scheduled", BuildDestroyTracePayload(bagId, slotIndex, slotType, {
                delayMs = 80,
                refreshItemList = GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList ~= nil,
                refreshCategoryList = GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshCategoryList ~= nil,
                refreshHeader = GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshHeader ~= nil,
                skipLiveSlotRead = true,
            }))
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
        else
            TraceDestroyAction("refresh_skipped", BuildDestroyTracePayload(bagId, slotIndex, slotType, {
                reason = "suppressed",
                skipLiveSlotRead = true,
            }))
        end

        TraceDestroyAction("complete", BuildDestroyTracePayload(bagId, slotIndex, slotType, { force = true, skipLiveSlotRead = true }))
        return true
    end
    TraceDestroyAction("blocked", BuildDestroyTracePayload(bagId, slotIndex, slotType, { reason = "requiresConfirmation" }))
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
        TraceDestroyAction("hook_fired", BuildDestroyTracePayload(bag, index, inventorySlot and inventorySlot.slotType, {
            hasInventorySlot = inventorySlot ~= nil,
        }))
        if not bag or not index then
            TraceDestroyAction("hook_skipped", BuildDestroyTracePayload(bag, index, inventorySlot and inventorySlot.slotType, { reason = "invalidSlot" }))
            return false
        end
        local slotType = inventorySlot and inventorySlot.slotType or nil
        if not CanDestroyItemWithPolicy(bag, index, slotType) then
            TraceDestroyAction("hook_blocked", BuildDestroyTracePayload(bag, index, slotType, { reason = "protectionPolicy" }))
            return true
        end

        local quick = BETTERUI.GetSetting("Inventory", "quickDestroy", false) == true

        if BETTERUI.Inventory.TryDestroyItem(bag, index, quick, false, slotType) then
            TraceDestroyAction("hook_consumed", BuildDestroyTracePayload(bag, index, slotType, {
                path = "quickDestroy",
                skipLiveSlotRead = quick == true,
            }))
            return true
        end

        if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
            TraceDestroyAction("action_dialog_released", BuildDestroyTracePayload(bag, index, slotType, {
                dialogName = ZO_GAMEPAD_INVENTORY_ACTION_DIALOG,
            }))
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        end
        local link = GetItemLink(bag, index)
        local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bag, index, inventorySlot)
        TraceDestroyAction("confirm_dialog_show", BuildDestroyTracePayload(bag, index, slotType, {
            itemLink = link,
            quickDestroy = quick == true,
            expectedSlotIdentity = expectedSlotIdentity,
        }))
        ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
            { bagId = bag, slotIndex = index, slotType = slotType, itemLink = link, expectedSlotIdentity = expectedSlotIdentity }, nil, true, true)
        return true
    end)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "raw hook installed", { method = "ZO_InventorySlot_InitiateDestroyItem", target = type("ZO_InventorySlot_InitiateDestroyItem") }) end

    BETTERUI.Inventory._destroyHookInstalled = true
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "destroy item hook installed") end
end
