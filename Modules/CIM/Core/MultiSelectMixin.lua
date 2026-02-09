--[[
File: Modules/CIM/Core/MultiSelectMixin.lua
Purpose: Shared multi-select mixin applied to any module class (Banking, Inventory, etc.).
         Provides batch throttling, selection mode lifecycle, and common batch operations
         (lock/unlock/junk) without code duplication.

Usage:
    BETTERUI.CIM.MultiSelectMixin.Apply(self, {
        getList        = function(s) return s.list end,
        refreshList    = function(s) s:RefreshList() end,
        refreshKeybinds = function(s) KEYBIND_STRIP:UpdateKeybindButtonGroup(s.coreKeybinds) end,
    })

Author: BetterUI Team
Last Modified: 2026-02-09
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.MultiSelectMixin = {}

local Mixin = BETTERUI.CIM.MultiSelectMixin

-- Use centralized constants from CIM
local BATCH_THROTTLE_DELAY_MS = BETTERUI.CIM.CONST.TIMING.BATCH_ACTION_DELAY_MS
local BATCH_PROGRESS_THRESHOLD = BETTERUI.CIM.CONST.TIMING.BATCH_PROGRESS_THRESHOLD

-------------------------------------------------------------------------------------------------
-- MIXIN APPLICATION
-------------------------------------------------------------------------------------------------

--- Applies the multi-select mixin to a module class instance.
--- The config table provides module-specific hooks so the shared logic
--- can interact with each module's list, keybinds, and refresh mechanisms.
--- @param target table The module class instance (e.g., Banking or Inventory instance)
--- @param config table Module-specific callbacks:
---   getList(self)          -> returns the active parametric scroll list
---   refreshList(self)      -> refreshes the list (visuals + data)
---   refreshKeybinds(self)  -> refreshes keybind strip visibility/labels
function Mixin.Apply(target, config)
    target._msConfig = config
end

-------------------------------------------------------------------------------------------------
-- SELECTION MODE LIFECYCLE
-------------------------------------------------------------------------------------------------

--- Enters multi-selection mode.
--- Sets state, notifies manager, auto-selects the currently focused item,
--- and refreshes visuals.
function Mixin.EnterSelectionMode(self)
    if self.isInSelectionMode then return end
    if not self.multiSelectManager then return end

    self.isInSelectionMode = true
    self.multiSelectManager:EnterSelectionMode()

    -- Auto-select the currently focused item
    local list = self._msConfig.getList(self)
    local target = nil
    if list then
        if list.GetSelectedData then
            target = list:GetSelectedData()
        else
            target = list.selectedData
        end
    end
    if target then
        self.multiSelectManager:ToggleSelection(target)
    end

    -- Update visuals
    self._msConfig.refreshKeybinds(self)
    self._msConfig.refreshList(self)
end

--- Exits multi-selection mode.
--- Clears state, notifies manager, and refreshes visuals.
function Mixin.ExitSelectionMode(self)
    if not self.isInSelectionMode then return end

    self.isInSelectionMode = false
    self.hadSelections = nil
    self.selectedCount = 0
    if self.multiSelectManager then
        self.multiSelectManager:ExitSelectionMode()
    end

    -- Update visuals
    self._msConfig.refreshKeybinds(self)
    self._msConfig.refreshList(self)
end

--- Called when the selection count changes.
--- Tracks hadSelections for auto-exit logic: when the user deselects the
--- last item (count reaches 0 after having selected at least one), the
--- mode exits automatically. The hadSelections guard prevents exiting on
--- initial entry when MultiSelectManager fires callback(0) before the
--- first ToggleSelection.
--- @param selectedCount number The number of currently selected items
function Mixin.OnSelectionCountChanged(self, selectedCount)
    if self.isInSelectionMode and selectedCount > 0 then
        self.selectedCount = selectedCount
        self.hadSelections = true
    else
        self.selectedCount = 0
    end

    -- Auto-exit when last item is deselected
    if self.isInSelectionMode and selectedCount == 0 and self.hadSelections then
        self.hadSelections = nil
        self:ExitSelectionMode()
        return
    end

    -- Refresh keybinds to update Y-button batch actions visibility
    self._msConfig.refreshKeybinds(self)
end

--- Gets whether selection mode is currently active.
--- @return boolean isActive
function Mixin.IsInSelectionMode(self)
    return self.isInSelectionMode or false
end

--- Checks if batch processing is currently in progress.
--- Used by refresh functions to skip updates during batch operations.
--- @return boolean True if batch processing is active
function Mixin.IsBatchProcessing(self)
    return self.isBatchProcessing == true
end

-------------------------------------------------------------------------------------------------
-- THROTTLED BATCH PROCESSING
-------------------------------------------------------------------------------------------------

--- Processes items with staggered delays to prevent rate-limiting.
--- Suppresses list/keybind refreshes during processing to prevent flickering.
--- @param items table Array of items to process
--- @param actionFn fun(bagId: number, slotIndex: number, itemData: table): boolean? Per-item function; return false to stop early
--- @param onComplete fun()? Optional callback when all items processed
--- @param actionName string? Name of the action for progress notifications
function Mixin.ProcessBatchThrottled(self, items, actionFn, onComplete, actionName)
    local index = 0
    local totalItems = #items
    local processedCount = 0
    local stoppedEarly = false
    local showProgress = totalItems >= BATCH_PROGRESS_THRESHOLD
    local self_ref = self

    -- Set batch processing flag to suppress refreshes
    self.isBatchProcessing = true

    local displayName = actionName or GetString(SI_BETTERUI_BATCH_ACTIONS)

    -- Show start notification for large batches
    if showProgress then
        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
        messageParams:SetText(displayName,
            zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_START), totalItems))
        messageParams:SetLifespanMS(3000)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end

    local function processNext()
        index = index + 1

        if index > totalItems or stoppedEarly then
            -- Clear batch processing flag
            self_ref.isBatchProcessing = false

            -- Show completion notification
            if showProgress or stoppedEarly then
                local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
                local completeText
                if stoppedEarly then
                    completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_BAG_FULL), processedCount, totalItems)
                else
                    completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_COMPLETE), totalItems)
                end
                messageParams:SetText(displayName, completeText)
                messageParams:SetLifespanMS(stoppedEarly and 4000 or 2000)
                CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
            end

            if onComplete then onComplete() end
            return
        end

        local itemData = items[index]
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex

        if bagId and slotIndex then
            local result = actionFn(bagId, slotIndex, itemData)
            if result == false then
                stoppedEarly = true
            else
                processedCount = processedCount + 1
            end
        end

        zo_callLater(processNext, BATCH_THROTTLE_DELAY_MS)
    end

    processNext()
end

-------------------------------------------------------------------------------------------------
-- COMMON BATCH OPERATIONS
-- Each operation pre-filters selected items to valid candidates, then uses
-- ProcessBatchThrottled. The completion callback exits selection mode and
-- refreshes the list.
-------------------------------------------------------------------------------------------------

--- Helper: extract bagId/slotIndex from item data (handles dataSource wrapper).
local function ExtractSlot(itemData)
    local rawData = itemData.dataSource or itemData
    return rawData.bagId or itemData.bagId, rawData.slotIndex or itemData.slotIndex
end

--- Performs batch lock on all selected items (throttled).
function Mixin.BatchLock(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and CanItemBePlayerLocked(bagId, slotIndex)
            and not IsItemPlayerLocked(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsPlayerLocked(bagId, slotIndex, true)
        return true
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_MARK_AS_LOCKED))
end

--- Performs batch unlock on all selected items (throttled).
function Mixin.BatchUnlock(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and IsItemPlayerLocked(bagId, slotIndex) then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsPlayerLocked(bagId, slotIndex, false)
        return true
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED))
end

--- Performs batch mark-as-junk on all selected items (throttled).
function Mixin.BatchMarkAsJunk(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex then
            if CanItemBeMarkedAsJunk(bagId, slotIndex)
                and not IsItemPlayerLocked(bagId, slotIndex)
                and not IsItemJunk(bagId, slotIndex)
            then
                table.insert(items, itemData)
            end
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsJunk(bagId, slotIndex, true)
        return true
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_MARK_AS_JUNK))
end

--- Performs batch unmark-as-junk on all selected items (throttled).
function Mixin.BatchUnmarkAsJunk(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and IsItemJunk(bagId, slotIndex)
            and not IsItemPlayerLocked(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsJunk(bagId, slotIndex, false)
        return true
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK))
end

-------------------------------------------------------------------------------------------------
-- ITEM ANALYSIS
-- Shared analysis logic used by ShowBatchActionsMenu in each module.
-------------------------------------------------------------------------------------------------

--- Analyzes selected items and returns counts for each applicable batch action.
--- Modules call this to build their batch actions dialog entries.
--- @param selectedItems table Array of selected item data
--- @return table counts { lockedCount, unlockedCount, canLockCount, canMarkJunkCount, canUnmarkJunkCount }
function Mixin.AnalyzeSelectedItems(selectedItems)
    local counts = {
        lockedCount = 0,
        unlockedCount = 0,
        canLockCount = 0,
        canMarkJunkCount = 0,
        canUnmarkJunkCount = 0,
    }

    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex then
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

--- Creates a single parametric dialog entry for a batch action.
--- @param label string The display label (e.g., "Lock (5)")
--- @param callback function The action callback
--- @return table entry The parametric list entry
function Mixin.CreateDialogEntry(label, callback)
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
--- @param counts table From AnalyzeSelectedItems
--- @param self table The module instance (for batch method callbacks)
function Mixin.AppendCommonBatchEntries(parametricList, counts, self)
    if counts.canLockCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_MARK_AS_LOCKED), counts.canLockCount)
        table.insert(parametricList, Mixin.CreateDialogEntry(label, function() self:BatchLock() end))
    end

    if counts.lockedCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED), counts.lockedCount)
        table.insert(parametricList, Mixin.CreateDialogEntry(label, function() self:BatchUnlock() end))
    end

    if counts.canMarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_MARK_AS_JUNK), counts.canMarkJunkCount)
        table.insert(parametricList, Mixin.CreateDialogEntry(label, function() self:BatchMarkAsJunk() end))
    end

    if counts.canUnmarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK), counts.canUnmarkJunkCount)
        table.insert(parametricList, Mixin.CreateDialogEntry(label, function() self:BatchUnmarkAsJunk() end))
    end
end
