--[[
File: Modules/CIM/Core/MultiSelectManager.lua
Purpose: Manages multi-selection state for inventory and banking lists.
         Provides selection mode entry/exit, item toggle, and batch operations.
Author: BetterUI Team
Last Modified: 2026-01-30
]]

--------------------------------------------------------------------------------
-- NAMESPACE SETUP
--------------------------------------------------------------------------------

BETTERUI.CIM.MultiSelectManager = {}
local MultiSelectManager = BETTERUI.CIM.MultiSelectManager

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

-- Hold duration threshold in milliseconds for entering select mode
MultiSelectManager.HOLD_THRESHOLD_MS = 500

-- Active instance for row setup to query (static reference)
local activeInstance = nil

--- Gets the currently active multi-select manager instance.
--- Used by row setup functions to check selection state.
--- @return table|nil instance The active manager or nil if none active
function MultiSelectManager.GetActiveInstance()
    return activeInstance
end

--- Sets the active instance (called when entering/exiting selection mode).
--- @param instance table|nil The manager instance or nil
function MultiSelectManager.SetActiveInstance(instance)
    activeInstance = instance
end

--------------------------------------------------------------------------------
-- CLASS DEFINITION
--------------------------------------------------------------------------------

--- @class MultiSelectManager
--- @field list table The parametric scroll list being managed
--- @field isActive boolean Whether selection mode is currently active
--- @field selectedItems table<string, table> Map of uniqueId -> itemData for selected items
--- @field selectionChangedCallback function Optional callback when selection changes
local Manager = ZO_Object:Subclass()
MultiSelectManager.Manager = Manager

--- Creates a new MultiSelectManager instance
--- @param list table The parametric scroll list to manage
--- @param selectionChangedCallback function? Optional callback(selectedCount) when selection changes
--- @return table instance The new manager instance
function Manager:New(list, selectionChangedCallback)
    local instance = ZO_Object.New(self)
    instance:Initialize(list, selectionChangedCallback)
    return instance
end

--- Initializes the manager with the given list
--- @param list table The parametric scroll list
--- @param selectionChangedCallback function? Optional callback when selection changes
function Manager:Initialize(list, selectionChangedCallback)
    self.list = list
    self.isActive = false
    self.selectedItems = {}
    self.selectionChangedCallback = selectionChangedCallback
end

--------------------------------------------------------------------------------
-- SELECTION MODE CONTROL
--------------------------------------------------------------------------------

--- Enters multi-select mode
--- @return boolean success True if mode was entered
function Manager:EnterSelectionMode()
    if self.isActive then return false end

    self.isActive = true
    self.selectedItems = {} -- Clear any previous selections

    -- Set as active instance for row setup queries
    MultiSelectManager.SetActiveInstance(self)

    -- Play sound for mode entry
    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)

    -- Fire callback
    if self.selectionChangedCallback then
        self.selectionChangedCallback(0)
    end

    return true
end

--- Exits multi-select mode and clears all selections
--- @return boolean success True if mode was exited
function Manager:ExitSelectionMode()
    if not self.isActive then return false end

    self.isActive = false
    self.selectedItems = {} -- Clear selections

    -- Clear active instance
    MultiSelectManager.SetActiveInstance(nil)

    -- Play sound for mode exit
    PlaySound(SOUNDS.GAMEPAD_MENU_BACK)

    -- Fire callback
    if self.selectionChangedCallback then
        self.selectionChangedCallback(0)
    end

    return true
end

--- Checks if selection mode is currently active
--- @return boolean isActive
function Manager:IsActive()
    return self.isActive
end

--------------------------------------------------------------------------------
-- ITEM SELECTION
--------------------------------------------------------------------------------

--- Toggles selection state for an item
--- @param itemData table The item data to toggle
--- @return boolean isNowSelected True if item is now selected, false if deselected
function Manager:ToggleSelection(itemData)
    if not itemData then return false end

    local uniqueId = self:GetItemUniqueId(itemData)
    if not uniqueId then return false end

    if self.selectedItems[uniqueId] then
        -- Deselect
        self.selectedItems[uniqueId] = nil
        PlaySound(SOUNDS.GAMEPAD_MENU_BACKWARD)
    else
        -- Select
        self.selectedItems[uniqueId] = itemData
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    end

    -- Fire callback
    if self.selectionChangedCallback then
        self.selectionChangedCallback(self:GetSelectedCount())
    end

    return self.selectedItems[uniqueId] ~= nil
end

--- Checks if an item is currently selected
--- @param itemData table The item data to check
--- @return boolean isSelected
function Manager:IsSelected(itemData)
    if not itemData then return false end

    local uniqueId = self:GetItemUniqueId(itemData)
    if not uniqueId then return false end

    return self.selectedItems[uniqueId] ~= nil
end

--- Selects an item without toggling
--- @param itemData table The item data to select
function Manager:Select(itemData)
    if not itemData then return end

    local uniqueId = self:GetItemUniqueId(itemData)
    if not uniqueId then return end

    if not self.selectedItems[uniqueId] then
        self.selectedItems[uniqueId] = itemData
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)

        if self.selectionChangedCallback then
            self.selectionChangedCallback(self:GetSelectedCount())
        end
    end
end

--- Deselects an item without toggling
--- @param itemData table The item data to deselect
function Manager:Deselect(itemData)
    if not itemData then return end

    local uniqueId = self:GetItemUniqueId(itemData)
    if not uniqueId then return end

    if self.selectedItems[uniqueId] then
        self.selectedItems[uniqueId] = nil
        PlaySound(SOUNDS.GAMEPAD_MENU_BACKWARD)

        if self.selectionChangedCallback then
            self.selectionChangedCallback(self:GetSelectedCount())
        end
    end
end

--- Clears all selections without exiting selection mode
function Manager:ClearSelections()
    self.selectedItems = {}

    if self.selectionChangedCallback then
        self.selectionChangedCallback(0)
    end
end

--- Selects all items in the specified list (or the stored list if none provided)
--- Handles ZO_GamepadEntryData which wraps item data in dataSource
--- @param listOverride table? Optional list to use instead of stored self.list
function Manager:SelectAll(listOverride)
    local targetList = listOverride or self.list
    if not targetList then return end

    -- ZO_GamepadInventoryList wraps a parametric list - get the inner list for data access
    local innerList = targetList.GetParametricList and targetList:GetParametricList() or targetList

    -- Use same fallback pattern as ItemListManager.lua line 102:
    -- (list.GetNumItems and list:GetNumItems()) or (list.dataList and #list.dataList) or 0
    local numItems = 0
    local dataList = nil

    if targetList.GetNumItems then
        numItems = targetList:GetNumItems()
    elseif innerList.dataList then
        -- Fallback: ESO parametric scroll lists use dataList
        dataList = innerList.dataList
        numItems = #dataList
    end

    for i = 1, numItems do
        local data
        if dataList then
            -- Direct access when using dataList fallback
            data = dataList[i]
        elseif innerList.GetDataForDataIndex then
            data = innerList:GetDataForDataIndex(i)
        end

        if data then
            -- Handle ZO_GamepadEntryData which wraps raw item data in dataSource
            local rawData = data.dataSource or data
            local bagId = rawData.bagId or data.bagId
            local slotIndex = rawData.slotIndex or data.slotIndex

            if bagId and slotIndex then
                local uniqueId = self:GetItemUniqueId(data)
                if uniqueId then
                    -- Store the full data (including wrapper) for consistent id lookup later
                    self.selectedItems[uniqueId] = data
                end
            end
        end
    end

    if self.selectionChangedCallback then
        self.selectionChangedCallback(self:GetSelectedCount())
    end
end

--------------------------------------------------------------------------------
-- SELECTION QUERIES
--------------------------------------------------------------------------------

--- Gets the count of selected items
--- @return number count
function Manager:GetSelectedCount()
    local count = 0
    for _ in pairs(self.selectedItems) do
        count = count + 1
    end
    return count
end

--- Gets all selected items as an array
--- @return table[] items Array of itemData tables
function Manager:GetSelectedItems()
    local items = {}
    for _, itemData in pairs(self.selectedItems) do
        items[#items + 1] = itemData
    end
    return items
end

--- Checks if any items are selected
--- @return boolean hasSelections
function Manager:HasSelections()
    return next(self.selectedItems) ~= nil
end

--------------------------------------------------------------------------------
-- BATCH OPERATIONS
--------------------------------------------------------------------------------

--- Performs a batch operation on all selected items
--- @param operationFn function(itemData) Function to call for each selected item
--- @return number processedCount Number of items processed
function Manager:BatchOperation(operationFn)
    if not operationFn then return 0 end

    local items = self:GetSelectedItems()
    local processedCount = 0

    for _, itemData in ipairs(items) do
        local success = operationFn(itemData)
        if success ~= false then
            processedCount = processedCount + 1
        end
    end

    return processedCount
end

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------

--- Gets a unique identifier for an item
--- Handles ZO_GamepadEntryData which wraps item data in dataSource
--- Uses ESO's Id64ToString for reliable Id64 conversion
--- @param itemData table The item data (may be ZO_GamepadEntryData or raw slot data)
--- @return string|nil uniqueId The unique identifier or nil
function Manager:GetItemUniqueId(itemData)
    if not itemData then return nil end

    -- Check for dataSource (ZO_GamepadEntryData wraps raw item data)
    local rawData = itemData.dataSource or itemData

    -- Try uniqueId first (most reliable - use rawData for consistency)
    local uniqueId = rawData.uniqueId or itemData.uniqueId
    if uniqueId then
        -- CRITICAL: Use Id64ToString for ESO's Id64 userdata type.
        -- Lua's tostring() produces inconsistent results for Id64.
        if Id64ToString then
            return Id64ToString(uniqueId)
        else
            return tostring(uniqueId)
        end
    end

    -- Fall back to bagId + slotIndex combination
    -- Check both rawData and itemData since properties might be copied to top level
    local bagId = rawData.bagId or itemData.bagId
    local slotIndex = rawData.slotIndex or itemData.slotIndex
    if bagId and slotIndex then
        return string.format("%d_%d", bagId, slotIndex)
    end

    return nil
end

--- Refreshes selection state after list data changes
--- Removes selections for items no longer in the list
function Manager:RefreshSelections()
    if not self.list then return end

    -- Build set of current uniqueIds in list
    local currentIds = {}
    local numItems = self.list:GetNumItems()
    for i = 1, numItems do
        local data = self.list:GetDataForDataIndex(i)
        if data then
            local uniqueId = self:GetItemUniqueId(data)
            if uniqueId then
                currentIds[uniqueId] = true
            end
        end
    end

    -- Remove selections for items no longer present
    local toRemove = {}
    for uniqueId, _ in pairs(self.selectedItems) do
        if not currentIds[uniqueId] then
            toRemove[#toRemove + 1] = uniqueId
        end
    end

    for _, uniqueId in ipairs(toRemove) do
        self.selectedItems[uniqueId] = nil
    end

    -- Fire callback if anything was removed
    if #toRemove > 0 and self.selectionChangedCallback then
        self.selectionChangedCallback(self:GetSelectedCount())
    end
end

--------------------------------------------------------------------------------
-- EXPORT TO NAMESPACE
--------------------------------------------------------------------------------

-- Convenience factory function
function MultiSelectManager.Create(list, selectionChangedCallback)
    return Manager:New(list, selectionChangedCallback)
end
