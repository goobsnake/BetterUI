--[[
File: Modules/Inventory/Actions/DestroyAction.lua
Purpose: Handles item destruction logic, offering a safer replacement for the engine's DestroyItem
         by respecting "Junk" status and "Quick Destroy" settings.
]]

--------------------------------------------------------------------------------
-- DESTROY ITEM LOGIC
--------------------------------------------------------------------------------

local BLOCK_TABBAR_CALLBACK = true

--- Attempts to destroy an item, dealing with junk status and user confirmation settings.
---
--- Purpose: Safer replacement for `DestroyItem`.
--- Mechanics:
--- 1. Checks if item is Junk or `force` flag is true.
--- 2. If so, destroys immediately (fixing sound and refreshing cache).
--- 3. Returns true if destroyed, false if confirmation (UI) is needed.
--- References: Called by Hooked Destroy and Action Dialog.
function BETTERUI.Inventory.TryDestroyItem(bagId, slotIndex, force)
    if not bagId or not slotIndex then
        return false
    end
    -- Allow destruction if explicitly confirmed or the item is junk
    if force or IsItemJunk(bagId, slotIndex) then
        -- Direct engine destroy path (matches the original working hook behavior)
        SetCursorItemSoundsEnabled(false)
        DestroyItem(bagId, slotIndex)
        -- Proactively refresh inventory caches to reflect removal
        if SHARED_INVENTORY and SHARED_INVENTORY.PerformFullUpdateOnBagCache then
            pcall(function()
                SHARED_INVENTORY:PerformFullUpdateOnBagCache(bagId)
            end)
        end
        -- UI refreshes (safe if scene present)
        zo_callLater(function()
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
        end, 80)
        return true
    end
    return false
end

--- Hooks the native destroy logic (X button in some contexts).
---
--- Purpose: Redirects engine destruction calls to `TryDestroyItem`.
--- Mechanics: Overwrites `ZO_InventorySlot_InitiateDestroyItem` with a wrapper that checks `quickDestroy` settings.
function BETTERUI.Inventory.HookDestroyItem()
    ZO_InventorySlot_InitiateDestroyItem = function(inventorySlot)
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        local force = false
        if BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Inventory"] then
            force = BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
        end
        return BETTERUI.Inventory.TryDestroyItem(bag, index, force)
    end
end
