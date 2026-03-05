--[[
File: Modules/Inventory/Actions/DestroyAction.lua
Purpose: Handles item destruction logic, offering a safer replacement for the engine's DestroyItem
         by respecting "Junk" status and "Quick Destroy" settings.
]]

--------------------------------------------------------------------------------
-- DESTROY ITEM LOGIC
--------------------------------------------------------------------------------

local BLOCK_TABBAR_CALLBACK = true

local function ForceDestroyItemSafely(bagId, slotIndex)
    if SetCursorItemSoundsEnabled then
        SetCursorItemSoundsEnabled(false)
    end

    local ok, err = pcall(function()
        DestroyItem(bagId, slotIndex)
    end)

    if SetCursorItemSoundsEnabled then
        SetCursorItemSoundsEnabled(true)
    end

    if not ok then
        if BETTERUI and BETTERUI.Debug then
            BETTERUI.Debug(string.format("DestroyItem failed for %s:%s (%s)", tostring(bagId), tostring(slotIndex), tostring(err)))
        end
        return false
    end

    return true
end

--- Attempts to destroy an item, dealing with junk status and user confirmation settings.
---
--- Purpose: Safer replacement for `DestroyItem`.
--- Mechanics:
--- 1. Checks if item is Junk or `force` flag is true.
--- 2. If so, destroys immediately (fixing sound and refreshing cache).
--- 3. Returns true if destroyed, false if confirmation (UI) is needed.
--- @param suppressUiRefresh boolean? When true, skips immediate cache/UI refresh work.
--- References: Called by Hooked Destroy and Action Dialog.
function BETTERUI.Inventory.TryDestroyItem(bagId, slotIndex, force, suppressUiRefresh)
    if not bagId or not slotIndex then
        return false
    end
    -- Only destroy immediately when explicitly forced (quickDestroy setting)
    -- Junk items still get the confirmation dialog for safety
    if force then
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
--- - Overwrites `ZO_InventorySlot_InitiateDestroyItem`.
--- - If quickDestroy is enabled, destroys immediately via `TryDestroyItem`.
--- - Otherwise, shows `BETTERUI_CONFIRM_DESTROY_DIALOG` for user confirmation.
--- - Always returns true to prevent the engine's cursor-based destroy flow
---   from showing a second (native) confirmation dialog.
function BETTERUI.Inventory.HookDestroyItem()
    ZO_InventorySlot_InitiateDestroyItem = function(inventorySlot)
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        if not bag or not index then return false end

        local quick = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
            and BETTERUI.Settings.Modules["Inventory"]
            and BETTERUI.Settings.Modules["Inventory"].quickDestroy == true

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
    end
end
