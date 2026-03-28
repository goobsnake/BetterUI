--[[
File: Modules/CIM/Lists/BatchProcessor.lua
Purpose: Shared batch processing utilities for inventory-style lists.
         Provides incremental list population to prevent UI freezing on large datasets.

Used By: Inventory/Lists/ItemListManager.lua, Banking (future)
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Lists then BETTERUI.CIM.Lists = {} end

-- ============================================================================
-- BATCH PROCESSOR CLASS
-- ============================================================================

--[[
Class: BETTERUI.CIM.Lists.BatchProcessor
Manages incremental list population for large datasets.
  1. Start() initializes batch state with data and options.
  2. ProcessBatch() handles one batch of items.
  3. zo_callLater schedules the next batch.
  4. OnComplete callback fires when all items are processed.
]]
BETTERUI.CIM.Lists.BatchProcessor = ZO_Object:Subclass()

function BETTERUI.CIM.Lists.BatchProcessor:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

--- @param options table|nil Configuration options
function BETTERUI.CIM.Lists.BatchProcessor:Initialize(options)
    options = options or {}
    self.initialBatchSize = options.initialBatchSize or BETTERUI.CIM.CONST.TIMING.BATCH_SIZE_INITIAL
    self.remainingBatchSize = options.remainingBatchSize or BETTERUI.CIM.CONST.TIMING.BATCH_SIZE_REMAINING
    self.batchDelay = options.batchDelay or 10

    self.pendingData = nil
    self.pendingIndex = nil
    self.context = nil
    self.batchCallId = nil
    self.onProcessItem = nil
    self.onComplete = nil
    self.isActiveCheck = nil
end

--- @param data table Array of items to process
--- @param options table Processing configuration
function BETTERUI.CIM.Lists.BatchProcessor:Start(data, options)
    -- Cancel any existing batch
    self:Cancel()

    if not data or #data == 0 then
        if options.onComplete then
            options.onComplete(options.context)
        end
        return
    end

    self.pendingData = data
    self.pendingIndex = 1
    self.context = options.context or {}
    self.onProcessItem = options.onProcessItem
    self.onComplete = options.onComplete
    self.isActiveCheck = options.isActiveCheck

    -- Process first batch immediately
    self:ProcessBatch()
end

--[[
Function: ProcessBatch
Processes one batch of items.
]]
function BETTERUI.CIM.Lists.BatchProcessor:ProcessBatch()
    if not self.pendingData then return end

    -- Check if we should continue
    if self.isActiveCheck and not self.isActiveCheck() then
        self:Cancel()
        return
    end

    local startIndex = self.pendingIndex or 1
    local totalItems = #self.pendingData

    -- If done, fire completion
    if startIndex > totalItems then
        local context = self.context
        local onComplete = self.onComplete
        self:Reset()
        if onComplete then
            onComplete(context)
        end
        return
    end

    -- Calculate batch size
    local batchSize = (startIndex == 1) and self.initialBatchSize or self.remainingBatchSize
    local endIndex = math.min(startIndex + batchSize - 1, totalItems)

    -- Process items in this batch
    if self.onProcessItem then
        for i = startIndex, endIndex do
            self.onProcessItem(self.pendingData[i], i, self.context)
        end
    end

    self.pendingIndex = endIndex + 1

    -- Schedule next batch if needed
    if self.pendingIndex <= totalItems then
        self.batchCallId = zo_callLater(function()
            self:ProcessBatch()
        end, self.batchDelay)
    else
        -- All done
        local context = self.context
        local onComplete = self.onComplete
        self:Reset()
        if onComplete then
            onComplete(context)
        end
    end
end

--[[
Function: Cancel
Cancels any pending batch operations.
]]
function BETTERUI.CIM.Lists.BatchProcessor:Cancel()
    if self.batchCallId then
        zo_removeCallLater(self.batchCallId)
        self.batchCallId = nil
    end
    self:Reset()
end

--[[
Function: Reset
Resets internal state.
]]
function BETTERUI.CIM.Lists.BatchProcessor:Reset()
    self.pendingData = nil
    self.pendingIndex = nil
    self.context = nil
    self.onProcessItem = nil
    self.onComplete = nil
    self.isActiveCheck = nil
end

--- @return boolean active True if batch processing is in progress
function BETTERUI.CIM.Lists.BatchProcessor:IsActive()
    return self.pendingData ~= nil
end
