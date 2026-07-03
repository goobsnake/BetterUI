--[[
File: Modules/CIM/Lists/ListRefreshManager.lua
Purpose: Unified list refresh management with batching, position restoration,
         and dirty state coalescing to eliminate scattered RefreshList implementations.

Used By: Inventory/Lists/ItemListManager.lua, Banking/Banking.lua
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Lists then BETTERUI.CIM.Lists = {} end

-- LIST REFRESH MANAGER CLASS

--- @class BETTERUI.CIM.Lists.ListRefreshManager : ZO_Object
--- @field coalesceDelay integer Refresh coalescing delay in ms
--- @field isDirty boolean Whether a refresh is pending
--- @field pendingRefreshCallId number|nil zo_callLater handle for pending refresh
--- @field pendingRefreshFlow string|nil Flow id carried by the pending coalesced refresh
--- @field pendingRefreshCoalescedCount integer Number of queue calls coalesced into the pending refresh
--- @field pendingRefreshWatchdogKey string|nil Watchdog expectation key for the pending refresh
--- @field savedPosition integer|nil Last saved scroll position
--- @field savedUniqueId string|nil Last saved item uniqueId for position restoration
BETTERUI.CIM.Lists.ListRefreshManager = ZO_Object:Subclass()

local nextRefreshManagerId = 0

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

local function NormalizeRefreshOptions(savePosition, options)
    if type(savePosition) == "table" and options == nil then
        options = savePosition
        savePosition = options.savePosition
    end
    return savePosition, options or {}
end

local function AddRefreshTraceContext(data, options)
    options = options or {}
    local coalescedCount = options.coalescedCount or 0
    data.flow = options.flow
    data.source = options.source
    data.reason = options.reason
    data.token = options.token
    data.coalesced = coalescedCount > 0
    data.coalescedCount = coalescedCount
    return data
end

local function WatchdogExpectRefresh(key, options)
    local watchdog = BETTERUI.CIM and BETTERUI.CIM.Watchdog
    if watchdog and type(watchdog.Expect) == "function" then
        options = options or {}
        pcall(watchdog.Expect, "list.refresh", key, 5000, {
            flow = options.flow,
            source = options.source,
            reason = options.reason,
            token = options.token,
        })
    end
end

local function WatchdogResolveRefresh(key, outcome)
    if key == nil then return end
    local watchdog = BETTERUI.CIM and BETTERUI.CIM.Watchdog
    if watchdog and type(watchdog.Resolve) == "function" then
        pcall(watchdog.Resolve, "list.refresh", key, outcome)
    end
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

    self.isDirty = false
    self.pendingRefreshCallId = nil
    self.refreshToken = 0
    self.pendingRefreshFlow = nil
    self.pendingRefreshSource = nil
    self.pendingRefreshReason = nil
    self.pendingRefreshToken = nil
    self.pendingRefreshCoalescedCount = 0
    self.pendingRefreshWatchdogKey = nil
    nextRefreshManagerId = nextRefreshManagerId + 1
    self.refreshWatchdogPrefix = "manager" .. tostring(nextRefreshManagerId)
    self.savedPosition = nil
    self.savedUniqueId = nil
end

---@param list table
---@param options BetterUIListRefreshTraceOptions|nil
---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:SavePosition(list, options)
    if not list then return end

    self.savedPosition = list:GetSelectedIndex() or 1
    local selectedData = list:GetSelectedData()
    if selectedData then
        self.savedUniqueId = selectedData.uniqueId
    else
        self.savedUniqueId = nil
    end
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refresh save position", AddRefreshTraceContext({
            savedPosition = self.savedPosition,
            savedUniqueId = self.savedUniqueId,
        }, options))
    end
    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "saved", AddRefreshTraceContext({
            selected = SafeDescribeListSelection(list, "saved"),
            savedPosition = self.savedPosition,
            savedUniqueId = self.savedUniqueId,
        }, options))
    end
end

---@param list table
---@param options BetterUIListRefreshTraceOptions|nil
---@return boolean, boolean?
function BETTERUI.CIM.Lists.ListRefreshManager:RestorePosition(list, options)
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
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "restore_end", AddRefreshTraceContext({
                restored = false,
                restoredById = restoredById == true,
                method = nil,
                restoreReason = "empty",
                failureReason = "empty",
            }, options))
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
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "restore_end", AddRefreshTraceContext({
                restored = true, method = restoredById and "id" or "index", targetIndex = targetIndex,
                restoredById = restoredById == true,
                restoreReason = restoreReason,
                selected = SafeDescribeListSelection(list, "after"),
            }, options))
        end
        return true, restoredById
    elseif list.SetSelectedDataIndex then
        list:SetSelectedDataIndex(targetIndex)
        if BETTERUI.Log and BETTERUI.Log.TraceEvent then
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "restore_end", AddRefreshTraceContext({
                restored = true, method = restoredById and "id" or "index", targetIndex = targetIndex,
                restoredById = restoredById == true,
                restoreReason = restoreReason,
                selected = SafeDescribeListSelection(list, "after"),
            }, options))
        end
        return true, restoredById
    end

    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "restore_end", AddRefreshTraceContext({
            restored = false,
            method = nil,
            targetIndex = targetIndex,
            restoredById = restoredById == true,
            restoreReason = restoreReason,
            failureReason = "missingSelectionSetter",
            selected = SafeDescribeListSelection(list, "after"),
        }, options))
    end
    return false, restoredById
end

---@param list table
---@param refreshFn fun()
---@param savePosition boolean?
---@param options BetterUIListRefreshTraceOptions|nil
---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:QueueRefresh(list, refreshFn, savePosition, options)
    savePosition, options = NormalizeRefreshOptions(savePosition, options)
    local numItems = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0
    local hadPendingRefresh = self.pendingRefreshCallId ~= nil
    local coalescedCount = hadPendingRefresh and ((self.pendingRefreshCoalescedCount or 0) + 1) or 0

    self.pendingRefreshFlow = options.flow or self.pendingRefreshFlow
    self.pendingRefreshSource = options.source or self.pendingRefreshSource
    self.pendingRefreshReason = options.reason or self.pendingRefreshReason
    self.pendingRefreshToken = options.token or self.pendingRefreshToken
    self.pendingRefreshCoalescedCount = coalescedCount

    local traceFlow = self.pendingRefreshFlow
    local traceSource = self.pendingRefreshSource
    local traceReason = self.pendingRefreshReason
    local traceToken = self.pendingRefreshToken
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "queue refresh", {
        numItems = numItems,
        coalesceDelay = self.coalesceDelay,
        flow = traceFlow,
        source = traceSource,
        reason = traceReason,
        token = traceToken,
        coalesced = hadPendingRefresh,
        coalescedCount = coalescedCount,
    }) end
    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "queued", AddRefreshTraceContext({
            numItems = numItems, coalesceDelay = self.coalesceDelay, savePosition = savePosition ~= false,
            selected = SafeDescribeListSelection(list, "before"),
        }, {
            flow = traceFlow,
            source = traceSource,
            reason = traceReason,
            token = traceToken,
            coalescedCount = coalescedCount,
        }))
    end

    if savePosition ~= false then
        self:SavePosition(list, {
            flow = traceFlow,
            source = traceSource,
            reason = traceReason,
            token = traceToken,
            coalescedCount = coalescedCount,
        })
    end

    self.isDirty = true
    self.refreshToken = (self.refreshToken or 0) + 1
    local refreshToken = self.refreshToken
    local watchdogKey = tostring(self.refreshWatchdogPrefix or "manager") .. ":" .. tostring(refreshToken)
    if self.pendingRefreshWatchdogKey then
        WatchdogResolveRefresh(self.pendingRefreshWatchdogKey, "coalesced")
    end
    self.pendingRefreshWatchdogKey = watchdogKey
    WatchdogExpectRefresh(watchdogKey, {
        flow = traceFlow,
        source = traceSource,
        reason = traceReason,
        token = traceToken,
    })

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
            WatchdogResolveRefresh(watchdogKey, "stale")
            if self.pendingRefreshWatchdogKey == watchdogKey then
                self.pendingRefreshWatchdogKey = nil
            end
            return
        end
        self.pendingRefreshCallId = nil
        if self.isDirty then
            local executeOptions = {
                flow = self.pendingRefreshFlow,
                source = self.pendingRefreshSource,
                reason = self.pendingRefreshReason,
                token = self.pendingRefreshToken,
                coalescedCount = self.pendingRefreshCoalescedCount or 0,
                watchdogKey = self.pendingRefreshWatchdogKey,
            }
            self.pendingRefreshFlow = nil
            self.pendingRefreshSource = nil
            self.pendingRefreshReason = nil
            self.pendingRefreshToken = nil
            self.pendingRefreshCoalescedCount = 0
            self.pendingRefreshWatchdogKey = nil
            self:ExecuteRefresh(list, refreshFn, executeOptions)
        else
            WatchdogResolveRefresh(watchdogKey, "clean")
            if self.pendingRefreshWatchdogKey == watchdogKey then
                self.pendingRefreshWatchdogKey = nil
            end
        end
    end, self.coalesceDelay)
end

---@param list table
---@param refreshFn fun()
---@param options BetterUIListRefreshTraceOptions|nil
---@return nil
function BETTERUI.CIM.Lists.ListRefreshManager:ExecuteRefresh(list, refreshFn, options)
    options = options or {}
    self.isDirty = false
    local beforeCount = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0

    -- Execute the refresh function
    if refreshFn then
        refreshFn()
    end

    -- Restore position after refresh
    local success, restoredById = self:RestorePosition(list, options)
    local numItems = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0
    local coalescedCount = options.coalescedCount or 0
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "execute refresh", {
        numItems = numItems,
        restoredById = restoredById == true,
        coalesceDelay = self.coalesceDelay,
        flow = options.flow,
        source = options.source,
        reason = options.reason,
        token = options.token,
        coalesced = coalescedCount > 0,
        coalescedCount = coalescedCount,
    }) end
    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "executed", AddRefreshTraceContext({
            beforeCount = beforeCount, afterCount = numItems, restored = success == true,
            restoredById = restoredById == true, selected = SafeDescribeListSelection(list, "after"),
        }, options))
    end
    WatchdogResolveRefresh(options.watchdogKey, "executed")
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
    WatchdogResolveRefresh(self.pendingRefreshWatchdogKey, "cancelled")
    self.pendingRefreshFlow = nil
    self.pendingRefreshSource = nil
    self.pendingRefreshReason = nil
    self.pendingRefreshToken = nil
    self.pendingRefreshCoalescedCount = 0
    self.pendingRefreshWatchdogKey = nil
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

-- SHARED MOVE-PREVIOUS HEADER WRAPPER
-- Extracted from Banking.lua, CompanionsRuntime.lua, VendorBootstrapRuntime.lua.
-- Wraps list.MovePrevious to enter the header/search bar on a failed upward move
-- (list at top). Instance-level wrap of BetterUI-owned list objects; no shared-class
-- mutation, so cross-addon safe. The _betteruiMovePreviousWrapperInstalled guard
-- prevents double-wrapping.

--- @param list table List control with a MovePrevious method
--- @param onTopExit fun()? Callback invoked when MovePrevious fails (list at top).
---        If nil, the wrapper still consumes the failed move (returns true) to prevent
---        the default parametric list boundary sound.
function BETTERUI.CIM.Lists.WrapMovePreviousToHeader(list, onTopExit)
    if not (list and type(list.MovePrevious) == "function") then
        return false
    end
    if list._betteruiMovePreviousWrapperInstalled then
        return true
    end

    -- Direct assignment is intentional: ZO_PostHook does not expose the original
    -- return value, which we need to detect a failed move (list at top).
    -- The _betteruiMovePreviousWrapperInstalled guard prevents double-wrapping.
    local originalMovePrevious = list.MovePrevious
    list._betteruiMovePreviousWrapperInstalled = true
    list.MovePrevious = function(self, allowWrapping, suppressFailSound)
        local didMove = originalMovePrevious(self, allowWrapping, suppressFailSound)
        if didMove then
            return true
        end
        if type(onTopExit) == "function" then
            onTopExit(self)
        end
        return true
    end
    return true
end
