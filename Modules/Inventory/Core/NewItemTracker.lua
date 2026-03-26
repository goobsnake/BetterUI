--[[
File: Modules/Inventory/Core/NewItemTracker.lua
Purpose: BetterUI-owned "New Item" status lifecycle manager.
         Replaces reliance on GAMEPAD_INVENTORY:PrepareNextClearNewStatus()
         and TryClearNewStatusOnHidden() which can desync with BetterUI's
         custom list system, causing ghost "new" item indicators.

KEY MECHANICS:
1.  **Prepare**: When an item is selected, its bagId/slotIndex is staged
    for "new" status clearing.
2.  **Commit**: When the scene hides or the list type changes, all staged
    items have their "new" status cleared via SHARED_INVENTORY:ClearNewStatus().
3.  **Immediate Clear**: Items moved, destroyed, or explicitly acted upon
    are cleared immediately without waiting for scene hide.
4.  **Safety**: Uses pcall around SHARED_INVENTORY calls to prevent
    errors from nil/invalid bag/slot combinations.

USAGE:
    -- On item selection:
    BETTERUI.Inventory.NewItemTracker.PrepareForClear(bagId, slotIndex)

    -- On scene hide / list type change:
    BETTERUI.Inventory.NewItemTracker.CommitPendingClears()

    -- On immediate item action (move, destroy, etc.):
    BETTERUI.Inventory.NewItemTracker.ClearImmediate(bagId, slotIndex)
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.NewItemTracker = {}

local NewItemTracker = BETTERUI.Inventory.NewItemTracker

-- Staged items waiting to have "new" status cleared on next scene hide
-- Format: { [uniqueKey] = { bagId = N, slotIndex = N } }
local pendingClears = {}

-------------------------------------------------------------------------------------------------
-- KEY GENERATION
-------------------------------------------------------------------------------------------------

--- Generates a unique key for a bag/slot combination.
--- @param bagId number
--- @param slotIndex number
--- @return string key
local function MakeKey(bagId, slotIndex)
    return tostring(bagId) .. "_" .. tostring(slotIndex)
end

-------------------------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------------------------

--- Stage an item for "new" status clearing when the scene hides.
--- Called when a user selects/views an item in the inventory list.
--- @param bagId number The bag containing the item
--- @param slotIndex number The slot index within the bag
function NewItemTracker.PrepareForClear(bagId, slotIndex)
    if not bagId or not slotIndex then return end
    local key = MakeKey(bagId, slotIndex)
    pendingClears[key] = { bagId = bagId, slotIndex = slotIndex }
end

--- Stage an item from selectedData (ZO_GamepadEntryData or item table).
--- Convenience wrapper for list selection callbacks.
--- @param selectedData table Item data from list selection
function NewItemTracker.PrepareFromSelectedData(selectedData)
    if not selectedData then return end
    local bagId = selectedData.bagId or (selectedData.dataSource and selectedData.dataSource.bagId)
    local slotIndex = selectedData.slotIndex or (selectedData.dataSource and selectedData.dataSource.slotIndex)
    NewItemTracker.PrepareForClear(bagId, slotIndex)
end

--- Commit all pending "new" status clears.
--- Called when the inventory scene hides or the list type changes.
--- This is the safe lifecycle point to clear new indicators.
function NewItemTracker.CommitPendingClears()
    if not SHARED_INVENTORY then return end

    for key, entry in pairs(pendingClears) do
        local ok, err = pcall(function()
            SHARED_INVENTORY:ClearNewStatus(entry.bagId, entry.slotIndex)
        end)
        if not ok then
            BETTERUI.CIM.Debug.Log(
                "NewItemTracker: failed to clear new status for " .. key .. ": " .. tostring(err),
                "NewItemTracker"
            )
        end
    end

    -- Reset pending table
    pendingClears = {}
end

--- Immediately clear "new" status for a specific item.
--- Used when an item is moved, destroyed, or explicitly acted upon.
--- @param bagId number The bag containing the item
--- @param slotIndex number The slot index within the bag
function NewItemTracker.ClearImmediate(bagId, slotIndex)
    if not bagId or not slotIndex then return end
    if not SHARED_INVENTORY then return end

    local key = MakeKey(bagId, slotIndex)
    -- Remove from pending if it was staged
    pendingClears[key] = nil

    -- Clear immediately
    local ok, err = pcall(function()
        SHARED_INVENTORY:ClearNewStatus(bagId, slotIndex)
    end)
    if not ok then
        BETTERUI.CIM.Debug.Log(
            "NewItemTracker: immediate clear failed for " .. key .. ": " .. tostring(err),
            "NewItemTracker"
        )
    end
end

--- Returns the number of items pending "new" status clear.
--- Useful for debugging.
--- @return number count The number of pending clears
function NewItemTracker.GetPendingCount()
    local count = 0
    for _ in pairs(pendingClears) do
        count = count + 1
    end
    return count
end

--- Resets all pending clears without actually clearing them.
--- Used when the inventory is destroyed/recreated.
function NewItemTracker.Reset()
    pendingClears = {}
end
