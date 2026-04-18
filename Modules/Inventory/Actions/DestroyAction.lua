--[[
File: Modules/Inventory/Actions/DestroyAction.lua
Purpose: Handles item destruction logic, offering a safer replacement for the engine's DestroyItem
         by respecting "Junk" status and "Quick Destroy" settings.
]]

-- DESTROY ITEM LOGIC

local BLOCK_TABBAR_CALLBACK = true

local function CanForceDestroyItem(bagId, slotIndex)
    local policy = BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy
    if policy and policy.CanDestroyItem then
        return policy.CanDestroyItem(bagId, slotIndex)
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

---@param bagId number Bag ID containing the item
---@param slotIndex number Slot index of the item
---@return boolean ok Whether destruction succeeded
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

--- Safer replacement for raw DestroyItem. Destroys immediately when forced,
--- otherwise returns false to signal that a confirmation dialog is needed.
---@param bagId number|nil Bag ID
---@param slotIndex number|nil Slot index
---@param force boolean|nil Whether to destroy without confirmation
---@param suppressUiRefresh boolean|nil Whether to skip UI refresh after destroy
---@return boolean success Whether the item was destroyed
function BETTERUI.Inventory.TryDestroyItem(bagId, slotIndex, force, suppressUiRefresh)
    if not bagId or not slotIndex then
        return false
    end
    if not CanDestroyItemWithPolicy(bagId, slotIndex) then
        return false
    end
    -- Only destroy immediately when explicitly forced (quickDestroy setting)
    -- Junk items still get the confirmation dialog for safety
    if force then
        local canDestroy = CanForceDestroyItem(bagId, slotIndex)
        if not canDestroy then
            return false
        end

        -- Direct engine destroy path (matches the original working hook behavior)
        if not ForceDestroyItemSafely(bagId, slotIndex) then
            return false
        end

        if not suppressUiRefresh then
            -- Proactively refresh inventory caches to reflect removal
            if SHARED_INVENTORY and SHARED_INVENTORY.PerformFullUpdateOnBagCache then
                SHARED_INVENTORY:PerformFullUpdateOnBagCache(bagId)
            end
            -- UI refreshes (safe if scene present)
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

--- Hooks the native destroy logic (RS-button and engine action callbacks).
---
--- Purpose: Redirects engine destruction calls to BetterUI's destroy flow.
--- Mechanics:
--- - Uses `ZO_PreHook` for `ZO_InventorySlot_InitiateDestroyItem` (no global replacement).
--- - If quickDestroy is enabled, destroys immediately via `TryDestroyItem`.
--- - Otherwise, shows `BETTERUI_CONFIRM_DESTROY_DIALOG` for user confirmation.
--- - Always returns true to prevent the engine's cursor-based destroy flow
---   from showing a second (native) confirmation dialog.
---@return nil
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

        -- TryDestroyItem handles junk and force-destroy cases (returns true if destroyed)
        if BETTERUI.Inventory.TryDestroyItem(bag, index, quick) then
            return true
        end

        -- Non-junk, non-quickDestroy: show BetterUI's confirmation dialog
        -- This prevents the engine's own cursor-based destroy dialog from appearing
        -- Dismiss the action dialog first if it's still showing (safety against stacked dialogs)
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
