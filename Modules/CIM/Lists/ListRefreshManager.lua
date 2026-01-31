--[[
File: Modules/CIM/Lists/ListRefreshManager.lua
Purpose: Unified list refresh management with batching, position restoration,
         and dirty state coalescing to eliminate scattered RefreshList implementations.
Author: BetterUI Team
Last Modified: 2026-01-31

Used By: Inventory/Lists/ItemListManager.lua, Banking/Banking.lua
Dependencies: BatchProcessor.lua, GenericListManager.lua
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Lists then BETTERUI.CIM.Lists = {} end

-- ============================================================================
-- LIST REFRESH MANAGER CLASS
-- ============================================================================

--[[
Class: BETTERUI.CIM.Lists.ListRefreshManager
Description: Manages list refreshes with automatic position restoration.
             Combines batch processing with coalescing to prevent UI stuttering.
Rationale: Centralizes refresh logic scattered across Inventory/Banking modules.
Mechanism:
  1. QueueRefresh() marks the list dirty and schedules coalesced refresh.
  2. ExecuteRefresh() performs the actual refresh with optional batching.
  3. RestorePosition() attempts to re-select the previously selected item.
]]
BETTERUI.CIM.Lists.ListRefreshManager = ZO_Object:Subclass()

function BETTERUI.CIM.Lists.ListRefreshManager:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

--[[
Function: Initialize
Description: Initializes the refresh manager.
param: options (table|nil) - Configuration:
  - coalesceDelay (number): Delay in ms before executing queued refresh (default: 80)
  - useBatching (boolean): Whether to use batch processing (default: false)
  - batchProcessor (table): BatchProcessor instance (required if useBatching is true)
]]
--- @param options table|nil Configuration options
function BETTERUI.CIM.Lists.ListRefreshManager:Initialize(options)
    options = options or {}
    self.coalesceDelay = options.coalesceDelay or BETTERUI.CIM.CONST.TIMING.CATEGORY_REFRESH_COALESCE_MS
    self.useBatching = options.useBatching or false
    self.batchProcessor = options.batchProcessor

    self.isDirty = false
    self.pendingRefreshCallId = nil
    self.savedPosition = nil
    self.savedUniqueId = nil
end

--[[
Function: SavePosition
Description: Saves the current list position for later restoration.
param: list (table) - The parametric list to save position from.
]]
--- @param list table The parametric list
function BETTERUI.CIM.Lists.ListRefreshManager:SavePosition(list)
    if not list then return end

    self.savedPosition = list:GetSelectedIndex() or 1
    local selectedData = list:GetSelectedData()
    if selectedData then
        self.savedUniqueId = selectedData.uniqueId
    else
        self.savedUniqueId = nil
    end
end

--[[
Function: RestorePosition
Description: Attempts to restore position after a refresh.
             Tries to find the item by uniqueId first, then falls back to index.
param: list (table) - The parametric list to restore position on.
return: boolean - True if position was restored.
]]
--- @param list table The parametric list
--- @return boolean success True if position was restored
function BETTERUI.CIM.Lists.ListRefreshManager:RestorePosition(list)
    if not list then return false end

    local targetIndex = nil

    -- Try to find by uniqueId first
    if self.savedUniqueId then
        for i = 1, list:GetNumItems() do
            local data = list:GetDataForDataIndex(i)
            if data and data.uniqueId == self.savedUniqueId then
                targetIndex = i
                break
            end
        end
    end

    -- Fall back to saved index
    if not targetIndex then
        targetIndex = self.savedPosition or 1
    end

    -- Clamp to valid range
    local numItems = list:GetNumItems() or 0
    if numItems == 0 then return false end

    targetIndex = math.min(targetIndex, numItems)
    targetIndex = math.max(targetIndex, 1)

    -- Set the position
    if list.SetSelectedIndex then
        list:SetSelectedIndex(targetIndex)
        return true
    elseif list.SetSelectedDataIndex then
        list:SetSelectedDataIndex(targetIndex)
        return true
    end

    return false
end

--[[
Function: QueueRefresh
Description: Queues a refresh with coalescing to prevent rapid redraws.
param: list (table) - The parametric list to refresh.
param: refreshFn (function) - The function that performs the actual data refresh.
param: savePosition (boolean) - Whether to save position before refresh (default: true).
]]
--- @param list table The parametric list
--- @param refreshFn function The refresh function
--- @param savePosition boolean Whether to save position
function BETTERUI.CIM.Lists.ListRefreshManager:QueueRefresh(list, refreshFn, savePosition)
    if savePosition ~= false then
        self:SavePosition(list)
    end

    self.isDirty = true

    -- Cancel any pending refresh
    if self.pendingRefreshCallId then
        zo_removeCallLater(self.pendingRefreshCallId)
    end

    -- Schedule coalesced refresh
    self.pendingRefreshCallId = zo_callLater(function()
        self.pendingRefreshCallId = nil
        if self.isDirty then
            self:ExecuteRefresh(list, refreshFn)
        end
    end, self.coalesceDelay)
end

--[[
Function: ExecuteRefresh
Description: Immediately executes a refresh with optional position restoration.
param: list (table) - The parametric list to refresh.
param: refreshFn (function) - The function that performs the actual data refresh.
]]
--- @param list table The parametric list
--- @param refreshFn function The refresh function
function BETTERUI.CIM.Lists.ListRefreshManager:ExecuteRefresh(list, refreshFn)
    self.isDirty = false

    -- Execute the refresh function
    if refreshFn then
        refreshFn()
    end

    -- Restore position after refresh
    self:RestorePosition(list)
end

--[[
Function: Cancel
Description: Cancels any pending queued refresh.
]]
function BETTERUI.CIM.Lists.ListRefreshManager:Cancel()
    if self.pendingRefreshCallId then
        zo_removeCallLater(self.pendingRefreshCallId)
        self.pendingRefreshCallId = nil
    end
    self.isDirty = false
end

--[[
Function: IsDirty
Description: Returns whether a refresh is pending.
return: boolean - True if a refresh is queued.
]]
--- @return boolean isDirty True if refresh is queued
function BETTERUI.CIM.Lists.ListRefreshManager:IsDirty()
    return self.isDirty
end

--[[
Function: MarkDirty
Description: Marks the list as needing refresh without queuing.
             Useful when external events should trigger refresh on next show.
]]
function BETTERUI.CIM.Lists.ListRefreshManager:MarkDirty()
    self.isDirty = true
end

--[[
Function: ClearDirty
Description: Clears the dirty flag without executing refresh.
]]
function BETTERUI.CIM.Lists.ListRefreshManager:ClearDirty()
    self.isDirty = false
end
