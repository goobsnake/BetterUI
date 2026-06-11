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
4.  **Safety**: Uses SafeExecute around SHARED_INVENTORY calls to prevent
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

--- @class NewItemTrackerModule
--- @field PrepareForClear fun(bagId: number, slotIndex: number)
--- @field PrepareFromSelectedData fun(selectedData: table)
--- @field CommitPendingClears fun()
--- @field ClearImmediate fun(bagId: number, slotIndex: number)
--- @field GetPendingCount fun(): number
--- @field Reset fun()
BETTERUI.Inventory.NewItemTracker = {}

local NewItemTracker = BETTERUI.Inventory.NewItemTracker

--- @type table<string, {bagId: number, slotIndex: number, identity: table|nil}>
local pendingClears = {}

--- Captures the slot identity (uniqueId-based) when the module helper is available.
--- Resolved lazily because Core/Utils.lua may load after this file in tests.
--- @param bagId number
--- @param slotIndex number
--- @param slotData table|nil
--- @return table|nil identity
local function CaptureIdentity(bagId, slotIndex, slotData)
    local utils = BETTERUI.Inventory.Utils
    if utils and utils.CaptureSlotIdentity then
        return utils.CaptureSlotIdentity(bagId, slotIndex, slotData)
    end
    return nil
end

--- Returns whether the bag slot still holds the item captured at prepare time.
--- Falls back to true when no identity was captured (helper unavailable).
--- @param entry {bagId: number, slotIndex: number, identity: table|nil}
--- @return boolean
local function IsEntryIdentityCurrent(entry)
    if not entry.identity then
        return true
    end
    local utils = BETTERUI.Inventory.Utils
    if utils and utils.IsSlotIdentityCurrent then
        return utils.IsSlotIdentityCurrent(entry.identity, entry.bagId, entry.slotIndex) == true
    end
    return true
end

-- KEY GENERATION

--- Generates a unique key for a bag/slot combination.
--- @param bagId number
--- @param slotIndex number
--- @return string
local function MakeKey(bagId, slotIndex)
    return tostring(bagId) .. "_" .. tostring(slotIndex)
end

-- PUBLIC API

--- Stage an item for "new" status clearing when the scene hides.
--- Called when a user selects/views an item in the inventory list.
--- @param bagId number
--- @param slotIndex number
--- @param slotData table|nil Optional slot/entry data used to resolve the uniqueId
function NewItemTracker.PrepareForClear(bagId, slotIndex, slotData)
    if not bagId or not slotIndex then return end
    local key = MakeKey(bagId, slotIndex)
    pendingClears[key] = {
        bagId = bagId,
        slotIndex = slotIndex,
        identity = CaptureIdentity(bagId, slotIndex, slotData),
    }
end

--- Stage an item from selectedData (ZO_GamepadEntryData or item table).
--- Convenience wrapper for list selection callbacks.
--- @param selectedData table ZO_GamepadEntryData or item table with bagId/slotIndex
function NewItemTracker.PrepareFromSelectedData(selectedData)
    if not selectedData then return end
    local bagId = selectedData.bagId or (selectedData.dataSource and selectedData.dataSource.bagId)
    local slotIndex = selectedData.slotIndex or (selectedData.dataSource and selectedData.dataSource.slotIndex)
    NewItemTracker.PrepareForClear(bagId, slotIndex, selectedData)
end

--- Commit all pending "new" status clears.
--- Called when the inventory scene hides or the list type changes.
--- This is the safe lifecycle point to clear new indicators.
function NewItemTracker.CommitPendingClears()
    if not SHARED_INVENTORY then return end

    for key, entry in pairs(pendingClears) do
        -- Skip slots whose contents changed since prepare time so a different
        -- item's "new" status is not cleared by stale bag/slot coordinates.
        if IsEntryIdentityCurrent(entry) then
            BETTERUI.CIM.SafeExecute(
                "NewItemTracker:CommitPendingClears:" .. key,
                SHARED_INVENTORY.ClearNewStatus, SHARED_INVENTORY, entry.bagId, entry.slotIndex
            )
        end
    end

    -- Reset pending table
    pendingClears = {}
end

--- Immediately clear "new" status for a specific item.
--- Used when an item is moved, destroyed, or explicitly acted upon.
--- @param bagId number
--- @param slotIndex number
function NewItemTracker.ClearImmediate(bagId, slotIndex)
    if not bagId or not slotIndex then return end
    if not SHARED_INVENTORY then return end

    local key = MakeKey(bagId, slotIndex)
    -- Remove from pending if it was staged
    pendingClears[key] = nil

    -- Clear immediately
    BETTERUI.CIM.SafeExecute(
        "NewItemTracker:ClearImmediate:" .. key,
        SHARED_INVENTORY.ClearNewStatus, SHARED_INVENTORY, bagId, slotIndex
    )
end

--- Returns the number of items pending "new" status clear.
--- @return number
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
