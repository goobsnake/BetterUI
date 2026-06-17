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

---@param ... any
---@return table
function BETTERUI.CIM.Lists.ListRefreshManager:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

---@param options BetterUIListRefreshManagerOptions|nil
---@return nil
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

---@param list table
---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:SavePosition(list)
    if not list then return end

    self.savedPosition = list:GetSelectedIndex() or 1
    local selectedData = list:GetSelectedData()
    if selectedData then
        self.savedUniqueId = selectedData.uniqueId
    else
        self.savedUniqueId = nil
    end
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refreshSavePosition", { savedPosition = self.savedPosition, savedUniqueId = self.savedUniqueId })
    end
end

---@param list table
---@return boolean, boolean?
function BETTERUI.CIM.Lists.ListRefreshManager:RestorePosition(list)
    if not list then return false, false end

    local targetIndex = nil
    local restoredById = false

    -- Try to find by uniqueId first
    if self.savedUniqueId then
        local numItemsForSearch = list:GetNumItems() or 0
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refreshRestoreSearchById", { savedUniqueId = self.savedUniqueId, numItems = numItemsForSearch })
        end
        for i = 1, numItemsForSearch do
            local data = list:GetDataForDataIndex(i)
            if data and data.uniqueId == self.savedUniqueId then
                targetIndex = i
                restoredById = true
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
    if numItems == 0 then return false, restoredById end

    targetIndex = math.min(targetIndex, numItems)
    targetIndex = math.max(targetIndex, 1)

    -- Set the position
    if list.SetSelectedIndex then
        list:SetSelectedIndex(targetIndex)
        return true, restoredById
    elseif list.SetSelectedDataIndex then
        list:SetSelectedDataIndex(targetIndex)
        return true, restoredById
    end

    return false, restoredById
end

---@param list table
---@param refreshFn fun()
---@param savePosition boolean?
---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:QueueRefresh(list, refreshFn, savePosition)
    local numItems = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "queueRefresh", { numItems = numItems, coalesceDelay = self.coalesceDelay }) end

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

---@param list table
---@param refreshFn fun()
---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:ExecuteRefresh(list, refreshFn)
    self.isDirty = false

    -- Execute the refresh function
    if refreshFn then
        refreshFn()
    end

    -- Restore position after refresh
    local success, restoredById = self:RestorePosition(list)
    local numItems = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "executeRefresh", { numItems = numItems, restoredById = restoredById == true, coalesceDelay = self.coalesceDelay }) end
end

---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:Cancel()
    if self.pendingRefreshCallId then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIST, "refreshCancel")
        end
        zo_removeCallLater(self.pendingRefreshCallId)
        self.pendingRefreshCallId = nil
    end
    self.isDirty = false
end

---@return boolean
function BETTERUI.CIM.Lists.ListRefreshManager:IsDirty()
    return self.isDirty
end

---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:MarkDirty()
    self.isDirty = true
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refreshMarkDirty")
    end
end

---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:ClearDirty()
    self.isDirty = false
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refreshClearDirty")
    end
end
