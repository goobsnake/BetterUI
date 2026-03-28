--[[
File: Modules/CIM/Lists/ListRefreshManager.lua
Purpose: Unified list refresh management with batching, position restoration,
         and dirty state coalescing to eliminate scattered RefreshList implementations.

Used By: Inventory/Lists/ItemListManager.lua, Banking/Banking.lua
Dependencies: BatchProcessor.lua, GenericListManager.lua
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Lists then BETTERUI.CIM.Lists = {} end

-- LIST REFRESH MANAGER CLASS

--- @class BETTERUI.CIM.Lists.ListRefreshManager : ZO_Object
--- @field coalesceDelay integer Refresh coalescing delay in ms
--- @field useBatching boolean Whether to use BatchProcessor for refreshes
--- @field batchProcessor BETTERUI.CIM.Lists.BatchProcessor|nil Optional batch processor
--- @field isDirty boolean Whether a refresh is pending
--- @field pendingRefreshCallId number|nil zo_callLater handle for pending refresh
--- @field savedPosition integer|nil Last saved scroll position
--- @field savedUniqueId string|nil Last saved item uniqueId for position restoration
BETTERUI.CIM.Lists.ListRefreshManager = ZO_Object:Subclass()

function BETTERUI.CIM.Lists.ListRefreshManager:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

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

function BETTERUI.CIM.Lists.ListRefreshManager:ExecuteRefresh(list, refreshFn)
    self.isDirty = false

    -- Execute the refresh function
    if refreshFn then
        refreshFn()
    end

    -- Restore position after refresh
    self:RestorePosition(list)
end

--- Cancels any pending queued refresh.
function BETTERUI.CIM.Lists.ListRefreshManager:Cancel()
    if self.pendingRefreshCallId then
        zo_removeCallLater(self.pendingRefreshCallId)
        self.pendingRefreshCallId = nil
    end
    self.isDirty = false
end

function BETTERUI.CIM.Lists.ListRefreshManager:IsDirty()
    return self.isDirty
end

--- Marks the list as needing refresh without queuing.
function BETTERUI.CIM.Lists.ListRefreshManager:MarkDirty()
    self.isDirty = true
end

--- Clears the dirty flag without executing refresh.
function BETTERUI.CIM.Lists.ListRefreshManager:ClearDirty()
    self.isDirty = false
end
