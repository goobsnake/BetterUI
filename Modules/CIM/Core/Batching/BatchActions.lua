--[[
File: Modules/CIM/Core/Batching/BatchActions.lua
Purpose: Common batch operations (Lock, Unlock, Junk, Unjunk) and
         dialog/analysis helpers for the multi-select system.
         Each operation pre-filters selected items to valid candidates,
         then delegates to ProcessBatchThrottled on the module instance.

Extracted from: MultiSelectMixin.lua (batch operations concern)
]]

BETTERUI.CIM = BETTERUI.CIM or {}

BETTERUI.CIM.BatchActions = BETTERUI.CIM.BatchActions or {}

local BatchActions = BETTERUI.CIM.BatchActions
local BatchConfig = BETTERUI.CIM.BatchConfig
local BatchStepHandled = BatchConfig.BatchStepHandled
local BatchStepQueued = BatchConfig.BatchStepQueued

local function GetProtectionPolicy()
    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before CIM batch-action policy checks")
    return policy
end

local function RequireProtectionPolicyMethod(methodName)
    local policy = GetProtectionPolicy()
    local method = policy and policy[methodName] or nil
    assert(type(method) == "function",
        string.format("BetterUI: CIM.ProtectionPolicy.%s must load before CIM batch-action policy checks", tostring(methodName)))
    return method
end

local function CanJunkItem(bagId, slotIndex)
    return RequireProtectionPolicyMethod("CanJunkItem")(bagId, slotIndex) == true
end

local function CanUnjunkItem(bagId, slotIndex)
    return RequireProtectionPolicyMethod("CanUnjunkItem")(bagId, slotIndex) == true
end

-- HELPERS

--- Helper: extract bagId/slotIndex from item data (handles dataSource wrapper).
---@param itemData table Item data or dataSource-wrapped entry
---@return number|nil bagId
---@return number|nil slotIndex
local function ExtractSlot(itemData)
    if not itemData then return nil, nil end
    local rawData = itemData.dataSource or itemData
    return rawData.bagId or itemData.bagId, rawData.slotIndex or itemData.slotIndex
end

--- Checks if an item exists at the specified slot.
--- Canonical implementation lives in BatchConfig, which the manifest loads
--- before this file; aliased here for batch-step reuse.
--- @private
local HasItemAtSlot = BatchConfig.HasItemAtSlot

--- Resolves the actionable stack count for an item, clamping the requested
--- stack to the live stack at the slot.
---@param itemData table Item data or dataSource-wrapped entry
---@param bagId number Bag identifier
---@param slotIndex number Slot index within the bag
---@return number|nil stackCount Clamped stack count, or nil when the slot is empty
local function ResolveStackCount(itemData, bagId, slotIndex)
    local rawData = itemData.dataSource or itemData
    local requestedStack = rawData.stackCount or itemData.stackCount or 1
    local liveStack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
    if liveStack <= 0 then
        return nil
    end
    return zo_clamp(requestedStack, 1, liveStack)
end

local function CanLockItem(bagId, slotIndex)
    return RequireProtectionPolicyMethod("CanLockItem")(bagId, slotIndex) == true
end

local function CanUnlockItem(bagId, slotIndex)
    return RequireProtectionPolicyMethod("CanUnlockItem")(bagId, slotIndex) == true
end

BatchActions.ExtractSlot = ExtractSlot
BatchActions.HasItemAtSlot = HasItemAtSlot
BatchActions.ResolveStackCount = ResolveStackCount

-- BATCH OPTION PRESETS


--- Options for lock/unlock batch operations
local LOCK_TOGGLE_BATCH_OPTIONS = BatchConfig.ComposeBatchOptions(
    BatchConfig.WithServer({
        serverBound = true,
        skipInterBatchCooldown = false,
    }),
    BatchConfig.WithUi({
        suppressUiUpdates = false,
    }),
    BatchConfig.WithPacing({
        minServerDelayMs = 140,
        maxServerDelayMs = 240,
        cooldownEvery = 22,
        cooldownMs = 1200,
        chunkCostUnits = 45,
        chunkPauseMs = 900,
        adaptiveDelay = false,
        jitterMs = 14,
    }),
    BatchConfig.WithAck({
        awaitInventoryAck = false,
    })
)

--- Options for junk toggle batch operations (same as lock options)
local JUNK_TOGGLE_BATCH_OPTIONS = LOCK_TOGGLE_BATCH_OPTIONS

-- BATCH OPERATIONS

--- Performs batch lock on all selected items (throttled).
function BatchActions.BatchLock(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and CanLockItem(bagId, slotIndex) then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled({
        items = items,
        step = function(bagId, slotIndex, itemData)
            if itemData and itemData.expectedSlotIdentity
                and BETTERUI.CIM.Utils.IsSlotIdentityCurrent(itemData.expectedSlotIdentity, bagId, slotIndex) ~= true then
                return BatchStepHandled()
            end
            if not CanLockItem(bagId, slotIndex) then
                return BatchStepHandled()
            end

            SetItemIsPlayerLocked(bagId, slotIndex, true)
            return BatchStepQueued()
        end,
        onComplete = function()
            self:ExitSelectionMode()
        end,
        actionName = GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_LOCKED")),
        options = LOCK_TOGGLE_BATCH_OPTIONS,
    })
end

--- Performs batch unlock on all selected items (throttled).
function BatchActions.BatchUnlock(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and CanUnlockItem(bagId, slotIndex) then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled({
        items = items,
        step = function(bagId, slotIndex, itemData)
            if itemData and itemData.expectedSlotIdentity
                and BETTERUI.CIM.Utils.IsSlotIdentityCurrent(itemData.expectedSlotIdentity, bagId, slotIndex) ~= true then
                return BatchStepHandled()
            end
            if not CanUnlockItem(bagId, slotIndex) then
                return BatchStepHandled()
            end

            SetItemIsPlayerLocked(bagId, slotIndex, false)
            return BatchStepQueued()
        end,
        onComplete = function()
            self:ExitSelectionMode()
        end,
        actionName = GetString(rawget(_G, "SI_ITEM_ACTION_UNMARK_AS_LOCKED")),
        options = LOCK_TOGGLE_BATCH_OPTIONS,
    })
end

--- Performs batch mark-as-junk on all selected items (throttled).
function BatchActions.BatchMarkAsJunk(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex then
            if HasItemAtSlot(bagId, slotIndex)
                and not IsItemJunk(bagId, slotIndex)
                and CanJunkItem(bagId, slotIndex)
            then
                table.insert(items, itemData)
            end
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled({
        items = items,
        step = function(bagId, slotIndex, itemData)
            if itemData and itemData.expectedSlotIdentity
                and BETTERUI.CIM.Utils.IsSlotIdentityCurrent(itemData.expectedSlotIdentity, bagId, slotIndex) ~= true then
                return BatchStepHandled()
            end
            if not HasItemAtSlot(bagId, slotIndex) then
                return BatchStepHandled()
            end
            if IsItemJunk(bagId, slotIndex)
                or not CanJunkItem(bagId, slotIndex)
            then
                return BatchStepHandled()
            end

            SetItemIsJunk(bagId, slotIndex, true)
            return BatchStepQueued()
        end,
        onComplete = function()
            self:ExitSelectionMode()
        end,
        actionName = GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_JUNK")),
        options = JUNK_TOGGLE_BATCH_OPTIONS,
    })
end

--- Performs batch unmark-as-junk on all selected items (throttled).
function BatchActions.BatchUnmarkAsJunk(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and HasItemAtSlot(bagId, slotIndex)
            and IsItemJunk(bagId, slotIndex)
            and CanUnjunkItem(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled({
        items = items,
        step = function(bagId, slotIndex, itemData)
            if itemData and itemData.expectedSlotIdentity
                and BETTERUI.CIM.Utils.IsSlotIdentityCurrent(itemData.expectedSlotIdentity, bagId, slotIndex) ~= true then
                return BatchStepHandled()
            end
            if not HasItemAtSlot(bagId, slotIndex) then
                return BatchStepHandled()
            end
            if not IsItemJunk(bagId, slotIndex)
                or not CanUnjunkItem(bagId, slotIndex)
            then
                return BatchStepHandled()
            end

            SetItemIsJunk(bagId, slotIndex, false)
            return BatchStepQueued()
        end,
        onComplete = function()
            self:ExitSelectionMode()
        end,
        actionName = GetString(rawget(_G, "SI_ITEM_ACTION_UNMARK_AS_JUNK")),
        options = JUNK_TOGGLE_BATCH_OPTIONS,
    })
end

-- ITEM ANALYSIS
-- Shared analysis logic used by ShowBatchActionsMenu in each module.

--- Analysis result counts for batch actions

--- Analyzes selected items and returns counts for each applicable batch action.
--- Modules call this to build their batch actions dialog entries.
function BatchActions.AnalyzeSelectedItems(selectedItems)
    local counts = {
        lockedCount = 0,
        canLockCount = 0,
        canMarkJunkCount = 0,
        canUnmarkJunkCount = 0,
    }

    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local isLocked = IsItemPlayerLocked(bagId, slotIndex)
            local canBeLocked = CanLockItem(bagId, slotIndex)
            local canBeUnlocked = CanUnlockItem(bagId, slotIndex)

            if isLocked then
                if canBeUnlocked then
                    counts.lockedCount = counts.lockedCount + 1
                end
            elseif canBeLocked then
                counts.canLockCount = counts.canLockCount + 1
            end

            local isJunk = IsItemJunk(bagId, slotIndex)
            local canMarkAsJunk = CanJunkItem(bagId, slotIndex)
            local canUnmarkAsJunk = CanUnjunkItem(bagId, slotIndex)
            if isJunk then
                if canUnmarkAsJunk then
                    counts.canUnmarkJunkCount = counts.canUnmarkJunkCount + 1
                end
            elseif canMarkAsJunk then
                    counts.canMarkJunkCount = counts.canMarkJunkCount + 1
            end
        end
    end

    return counts
end

-- DIALOG HELPERS
-- Shared helpers to build batch actions dialog entries consistently.

--- Dialog entry for parametric list

--- Creates a single parametric dialog entry for a batch action.
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
