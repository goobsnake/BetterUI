--[[
File: Modules/CIM/Core/BatchActions.lua
Purpose: Common batch operations (Lock, Unlock, Junk, Unjunk) and
         dialog/analysis helpers for the multi-select system.
         Each operation pre-filters selected items to valid candidates,
         then delegates to ProcessBatchThrottled on the module instance.

Extracted from: MultiSelectMixin.lua (batch operations concern)
]]

BETTERUI.CIM = BETTERUI.CIM or {}

--- @class BETTERUI.CIM.BatchActions
--- @field ExtractSlot fun(itemData: table): number|nil, number|nil
--- @field HasItemAtSlot fun(bagId: number, slotIndex: number): boolean
BETTERUI.CIM.BatchActions = BETTERUI.CIM.BatchActions or {}

local BatchActions = BETTERUI.CIM.BatchActions

-------------------------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------------------------

--- Helper: extract bagId/slotIndex from item data (handles dataSource wrapper).
--- @private
--- @param itemData table The item data table
--- @return number|nil bagId The bag ID
--- @return number|nil slotIndex The slot index
local function ExtractSlot(itemData)
    local rawData = itemData.dataSource or itemData
    return rawData.bagId or itemData.bagId, rawData.slotIndex or itemData.slotIndex
end

--- Checks if an item exists at the specified slot
--- @private
--- @param bagId number The bag ID
--- @param slotIndex number The slot index
--- @return boolean hasItem True if an item exists at the slot
local function HasItemAtSlot(bagId, slotIndex)
    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
    return (stackCount or 0) > 0
end

BatchActions.ExtractSlot = ExtractSlot
BatchActions.HasItemAtSlot = HasItemAtSlot

-------------------------------------------------------------------------------------------------
-- BATCH OPTION PRESETS
-------------------------------------------------------------------------------------------------

--- @class BatchOptions
--- @field serverBound boolean Whether operation is server-bound
--- @field awaitInventoryAck boolean Whether to await inventory acknowledgment
--- @field minServerDelayMs number Minimum server delay in milliseconds
--- @field maxServerDelayMs number Maximum server delay in milliseconds
--- @field cooldownEvery number Apply cooldown every N items
--- @field cooldownMs number Cooldown duration in milliseconds
--- @field chunkCostUnits number Cost units per chunk
--- @field chunkPauseMs number Pause duration between chunks
--- @field adaptiveDelay boolean Whether to use adaptive delay
--- @field jitterMs number Jitter amount in milliseconds

--- Options for lock/unlock batch operations
--- @type BatchOptions
local LOCK_TOGGLE_BATCH_OPTIONS = {
    serverBound = true,
    awaitInventoryAck = false,
    minServerDelayMs = 140,
    maxServerDelayMs = 240,
    cooldownEvery = 22,
    cooldownMs = 1200,
    chunkCostUnits = 45,
    chunkPauseMs = 900,
    adaptiveDelay = false,
    jitterMs = 14,
}

--- Options for junk toggle batch operations (same as lock options)
--- @type BatchOptions
local JUNK_TOGGLE_BATCH_OPTIONS = LOCK_TOGGLE_BATCH_OPTIONS

-------------------------------------------------------------------------------------------------
-- BATCH OPERATIONS
-------------------------------------------------------------------------------------------------

--- Performs batch lock on all selected items (throttled).
--- @param self table Module instance with multiSelectManager and ProcessBatchThrottled
function BatchActions.BatchLock(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and HasItemAtSlot(bagId, slotIndex)
            and CanItemBePlayerLocked(bagId, slotIndex)
            and not IsItemPlayerLocked(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if not CanItemBePlayerLocked(bagId, slotIndex) or IsItemPlayerLocked(bagId, slotIndex) then
            return true
        end

        SetItemIsPlayerLocked(bagId, slotIndex, true)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_LOCKED")), LOCK_TOGGLE_BATCH_OPTIONS)
end

--- Performs batch unlock on all selected items (throttled).
--- @param self table Module instance
function BatchActions.BatchUnlock(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and HasItemAtSlot(bagId, slotIndex)
            and IsItemPlayerLocked(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if not IsItemPlayerLocked(bagId, slotIndex) then
            return true
        end

        SetItemIsPlayerLocked(bagId, slotIndex, false)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(rawget(_G, "SI_ITEM_ACTION_UNMARK_AS_LOCKED")), LOCK_TOGGLE_BATCH_OPTIONS)
end

--- Performs batch mark-as-junk on all selected items (throttled).
--- @param self table Module instance
function BatchActions.BatchMarkAsJunk(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex then
            if HasItemAtSlot(bagId, slotIndex)
                and CanItemBeMarkedAsJunk(bagId, slotIndex)
                and not IsItemPlayerLocked(bagId, slotIndex)
                and not IsItemJunk(bagId, slotIndex)
            then
                table.insert(items, itemData)
            end
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if not CanItemBeMarkedAsJunk(bagId, slotIndex)
            or IsItemPlayerLocked(bagId, slotIndex)
            or IsItemJunk(bagId, slotIndex)
        then
            return true
        end

        SetItemIsJunk(bagId, slotIndex, true)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_JUNK")), JUNK_TOGGLE_BATCH_OPTIONS)
end

--- Performs batch unmark-as-junk on all selected items (throttled).
--- @param self table Module instance
function BatchActions.BatchUnmarkAsJunk(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and HasItemAtSlot(bagId, slotIndex)
            and IsItemJunk(bagId, slotIndex)
            and not IsItemPlayerLocked(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if IsItemPlayerLocked(bagId, slotIndex) or not IsItemJunk(bagId, slotIndex) then
            return true
        end

        SetItemIsJunk(bagId, slotIndex, false)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(rawget(_G, "SI_ITEM_ACTION_UNMARK_AS_JUNK")), JUNK_TOGGLE_BATCH_OPTIONS)
end

-------------------------------------------------------------------------------------------------
-- ITEM ANALYSIS
-- Shared analysis logic used by ShowBatchActionsMenu in each module.
-------------------------------------------------------------------------------------------------

--- Analysis result counts for batch actions
--- @class BatchActionCounts
--- @field lockedCount number Count of locked items
--- @field unlockedCount number Count of unlocked items
--- @field canLockCount number Count of items that can be locked
--- @field canMarkJunkCount number Count of items that can be marked as junk
--- @field canUnmarkJunkCount number Count of items that can be unmarked as junk

--- Analyzes selected items and returns counts for each applicable batch action.
--- Modules call this to build their batch actions dialog entries.
--- @param selectedItems table Array of selected item data
--- @return BatchActionCounts counts Table with counts for each action type
function BatchActions.AnalyzeSelectedItems(selectedItems)
    --- @type BatchActionCounts
    local counts = {
        lockedCount = 0,
        unlockedCount = 0,
        canLockCount = 0,
        canMarkJunkCount = 0,
        canUnmarkJunkCount = 0,
    }

    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local isLocked = IsItemPlayerLocked(bagId, slotIndex)
            local canBeLocked = CanItemBePlayerLocked(bagId, slotIndex)

            if isLocked then
                counts.lockedCount = counts.lockedCount + 1
            else
                counts.unlockedCount = counts.unlockedCount + 1
            end

            if canBeLocked and not isLocked then
                counts.canLockCount = counts.canLockCount + 1
            end

            local isJunk = IsItemJunk(bagId, slotIndex)
            local canBeJunked = CanItemBeMarkedAsJunk(bagId, slotIndex)
            if canBeJunked and not isLocked then
                if isJunk then
                    counts.canUnmarkJunkCount = counts.canUnmarkJunkCount + 1
                else
                    counts.canMarkJunkCount = counts.canMarkJunkCount + 1
                end
            end
        end
    end

    return counts
end

-------------------------------------------------------------------------------------------------
-- DIALOG HELPERS
-- Shared helpers to build batch actions dialog entries consistently.
-------------------------------------------------------------------------------------------------

--- Dialog entry for parametric list
--- @class DialogEntry
--- @field template string The XML template name
--- @field entryData table The entry data object

--- Creates a single parametric dialog entry for a batch action.
--- @param label string The display label (e.g., "Lock (5)")
--- @param callback function The action callback
--- @return DialogEntry entry The parametric list entry
function BatchActions.CreateDialogEntry(label, callback)
    local entry = ZO_GamepadEntryData:New(label)
    entry:SetIconTintOnSelection(true)
    entry.setup = ZO_SharedGamepadEntry_OnSetup
    entry.callback = callback
    return {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = entry,
    }
end

--- Appends the standard shared batch action entries (Lock, Unlock, Mark Junk, Unmark Junk)
--- to a parametric list based on the analysis counts.
--- Modules call this after adding their own module-specific entries.
--- @param parametricList table The list to append entries to
--- @param counts BatchActionCounts From AnalyzeSelectedItems
--- @param self table The module instance (for batch method callbacks)
function BatchActions.AppendCommonBatchEntries(parametricList, counts, self)
    if counts.canLockCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_LOCKED")), counts.canLockCount)
        table.insert(parametricList, BatchActions.CreateDialogEntry(label, function() self:BatchLock() end))
    end

    if counts.lockedCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_ITEM_ACTION_UNMARK_AS_LOCKED")), counts.lockedCount)
        table.insert(parametricList, BatchActions.CreateDialogEntry(label, function() self:BatchUnlock() end))
    end

    if counts.canMarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_JUNK")), counts.canMarkJunkCount)
        table.insert(parametricList, BatchActions.CreateDialogEntry(label, function() self:BatchMarkAsJunk() end))
    end

    if counts.canUnmarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_ITEM_ACTION_UNMARK_AS_JUNK")), counts.canUnmarkJunkCount)
        table.insert(parametricList, BatchActions.CreateDialogEntry(label, function() self:BatchUnmarkAsJunk() end))
    end
end
