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

local function SafeDescribeListSelection(list, phase)
    local log = BETTERUI and BETTERUI.Log or nil
    if log and type(log.DescribeListSelection) == "function" then
        local ok, selected = pcall(log.DescribeListSelection, list, phase)
        if ok then return selected end
        return { phase = phase, describeError = tostring(selected) }
    end

    local selectedIndex = nil
    if list and type(list.GetSelectedIndex) == "function" then
        local ok, index = pcall(function() return list:GetSelectedIndex() end)
        if ok then selectedIndex = index end
    end
    return { phase = phase, selectedIndex = selectedIndex, reason = "describeHelperUnavailable" }
end

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
    self.refreshToken = 0
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
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refresh save position", { savedPosition = self.savedPosition, savedUniqueId = self.savedUniqueId })
    end
    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "saved", {
            selected = SafeDescribeListSelection(list, "saved"),
            savedPosition = self.savedPosition,
            savedUniqueId = self.savedUniqueId,
        })
    end
end

---@param list table
---@return boolean, boolean?
function BETTERUI.CIM.Lists.ListRefreshManager:RestorePosition(list)
    if not list then return false, false end

    local targetIndex = nil
    local restoredById = false
    local restoreReason = nil

    -- Try to find by uniqueId first
    if self.savedUniqueId then
        local numItemsForSearch = list:GetNumItems() or 0
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refresh restore search by id", { savedUniqueId = self.savedUniqueId, numItems = numItemsForSearch })
        end
        for i = 1, numItemsForSearch do
            local data = list:GetDataForDataIndex(i)
            if data and data.uniqueId == self.savedUniqueId then
                targetIndex = i
                restoredById = true
                break
            end
        end
        if restoredById then
            restoreReason = "savedUniqueId"
        else
            restoreReason = "savedUniqueIdNotFound"
        end
    end

    -- Fall back to saved index
    if not targetIndex then
        targetIndex = self.savedPosition or 1
        restoreReason = restoreReason or (self.savedPosition and "savedIndex" or "defaultIndex")
    end

    -- Clamp to valid range
    local numItems = list:GetNumItems() or 0
    if numItems == 0 then
        if BETTERUI.Log and BETTERUI.Log.TraceEvent then
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "restore_end", {
                restored = false,
                restoredById = restoredById == true,
                method = nil,
                restoreReason = "empty",
                reason = "empty",
            })
        end
        return false, restoredById
    end

    local unclampedTargetIndex = targetIndex
    targetIndex = math.min(targetIndex, numItems)
    targetIndex = math.max(targetIndex, 1)
    if unclampedTargetIndex ~= targetIndex then
        restoreReason = "indexClamped"
    end

    -- Set the position
    if list.SetSelectedIndex then
        list:SetSelectedIndex(targetIndex)
        if BETTERUI.Log and BETTERUI.Log.TraceEvent then
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "restore_end", {
                restored = true, method = restoredById and "id" or "index", targetIndex = targetIndex,
                restoredById = restoredById == true,
                restoreReason = restoreReason,
                selected = SafeDescribeListSelection(list, "after"),
            })
        end
        return true, restoredById
    elseif list.SetSelectedDataIndex then
        list:SetSelectedDataIndex(targetIndex)
        if BETTERUI.Log and BETTERUI.Log.TraceEvent then
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "restore_end", {
                restored = true, method = restoredById and "id" or "index", targetIndex = targetIndex,
                restoredById = restoredById == true,
                restoreReason = restoreReason,
                selected = SafeDescribeListSelection(list, "after"),
            })
        end
        return true, restoredById
    end

    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "restore_end", {
            restored = false,
            method = nil,
            targetIndex = targetIndex,
            restoredById = restoredById == true,
            restoreReason = restoreReason,
            reason = "missingSelectionSetter",
            selected = SafeDescribeListSelection(list, "after"),
        })
    end
    return false, restoredById
end

---@param list table
---@param refreshFn fun()
---@param savePosition boolean?
---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:QueueRefresh(list, refreshFn, savePosition)
    local numItems = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "queue refresh", { numItems = numItems, coalesceDelay = self.coalesceDelay }) end
    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "queued", {
            numItems = numItems, coalesceDelay = self.coalesceDelay, savePosition = savePosition ~= false,
            selected = SafeDescribeListSelection(list, "before"),
        })
    end

    if savePosition ~= false then
        self:SavePosition(list)
    end

    self.isDirty = true
    self.refreshToken = (self.refreshToken or 0) + 1
    local refreshToken = self.refreshToken

    -- Cancel any pending refresh
    if self.pendingRefreshCallId then
        zo_removeCallLater(self.pendingRefreshCallId)
    end

    -- Schedule coalesced refresh
    self.pendingRefreshCallId = zo_callLater(function()
        if refreshToken ~= self.refreshToken then
            if BETTERUI.Log and BETTERUI.Log.IsActive() then
                BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refresh stale token", { expected = refreshToken, actual = self.refreshToken })
            end
            return
        end
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
    local beforeCount = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0

    -- Execute the refresh function
    if refreshFn then
        refreshFn()
    end

    -- Restore position after refresh
    local success, restoredById = self:RestorePosition(list)
    local numItems = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "execute refresh", { numItems = numItems, restoredById = restoredById == true, coalesceDelay = self.coalesceDelay }) end
    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "executed", {
            beforeCount = beforeCount, afterCount = numItems, restored = success == true,
            restoredById = restoredById == true, selected = SafeDescribeListSelection(list, "after"),
        })
    end
end

---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:Cancel()
    self.refreshToken = (self.refreshToken or 0) + 1
    if self.pendingRefreshCallId then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIST, "refresh cancel")
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
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refresh mark dirty")
    end
end

---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:ClearDirty()
    self.isDirty = false
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refresh clear dirty")
    end
end
