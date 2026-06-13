--[[
File: Modules/CIM/Core/Batching/MultiSelectManager.lua
Purpose: Manages multi-selection state for inventory and banking lists.
         Provides selection mode entry/exit, item toggle, and batch operations.
]]

-- NAMESPACE SETUP

BETTERUI.CIM.MultiSelectManager = {}
local MultiSelectManager = BETTERUI.CIM.MultiSelectManager

-- CONSTANTS

-- Hold duration threshold in milliseconds for entering select mode
MultiSelectManager.HOLD_THRESHOLD_MS = 500

-- Active instance for row setup to query (static reference)
local activeInstance = nil

--- Gets the currently active multi-select manager instance.
--- Used by row setup functions to check selection state.
--- @return BETTERUI.CIM.MultiSelectManager.Manager|nil
function MultiSelectManager.GetActiveInstance()
    return activeInstance
end

--- Sets the active instance (called when entering/exiting selection mode).
function MultiSelectManager.SetActiveInstance(instance)
    activeInstance = instance
end

-- CLASS DEFINITION

--- @class BETTERUI.CIM.MultiSelectManager.Manager : ZO_Object
--- @field list table The parametric list this manager operates on
--- @field isActive boolean Whether multi-select mode is currently active
--- @field selectedItems table<string, table> Map of primary selection key to selected item data
--- @field selectedItemAliases table<string, string> Map of alias key to primary selection key
--- @field selectionChangedCallback fun(count: integer)|nil Callback fired on selection changes
local Manager = ZO_Object:Subclass()
MultiSelectManager.Manager = Manager

--- Creates a new MultiSelectManager instance
--- @param list table The parametric scroll list to manage selections for
--- @param selectionChangedCallback fun(count: integer)|nil Optional callback on selection changes
--- @return BETTERUI.CIM.MultiSelectManager.Manager
function Manager:New(list, selectionChangedCallback)
    local instance = ZO_Object.New(self)
    instance:Initialize(list, selectionChangedCallback)
    return instance
end

--- Initializes the manager with the given list
function Manager:Initialize(list, selectionChangedCallback)
    self.list = list
    self.isActive = false
    self.selectedItems = {}
    self.selectedItemAliases = {}
    self.selectionChangedCallback = selectionChangedCallback
end

local function AddSelectionKey(keys, seen, key)
    if key and key ~= "" and not seen[key] then
        seen[key] = true
        keys[#keys + 1] = key
    end
end

local function NormalizeSelectionKeyValue(value)
    if value == nil then
        return nil
    end
    if Id64ToString and type(value) ~= "string" then
        local ok, normalized = pcall(Id64ToString, value)
        if ok and normalized ~= nil then
            return tostring(normalized)
        end
    end
    return tostring(value)
end

--- Gets all stable selection keys for an item.
--- Some list rebuilds preserve only `uniqueId` or only `bagId/slotIndex`, so we retain both.
--- @param itemData table The item data (may be ZO_GamepadEntryData or raw slot data)
--- @return table keys Ordered array of selection keys
function Manager:GetItemSelectionKeys(itemData)
    if not itemData then
        return {}
    end

    local rawData = itemData.dataSource or itemData
    local keys = {}
    local seen = {}

    local uniqueId = rawData.uniqueId or itemData.uniqueId
    if uniqueId then
        AddSelectionKey(keys, seen, NormalizeSelectionKeyValue(uniqueId))
    end

    local bagId = rawData.bagId or itemData.bagId
    local slotIndex = rawData.slotIndex or itemData.slotIndex
    if bagId ~= nil and slotIndex ~= nil then
        AddSelectionKey(keys, seen, string.format("%d_%d", bagId, slotIndex))
    end

    -- Some scenes (for example Vendor Buyback) provide entryIndex rows without bag/slot ids.
    -- Keep these selectable by deriving a stable key from entryIndex.
    local entryIndex = rawData.entryIndex or itemData.entryIndex
    if entryIndex ~= nil then
        AddSelectionKey(keys, seen, string.format("entry_%s", tostring(entryIndex)))
    end

    return keys
end

--- Resolves the stored primary key for a selected item, or a stable default key when not selected.
--- @param itemData table The item data to resolve
--- @return string|nil primaryKey
function Manager:GetPrimarySelectionKey(itemData)
    local keys = self:GetItemSelectionKeys(itemData)
    for _, key in ipairs(keys) do
        local primaryKey = (self.selectedItemAliases and self.selectedItemAliases[key]) or key
        if primaryKey and self.selectedItems[primaryKey] then
            return primaryKey
        end
    end
    return keys[1]
end

--- Stores a selected item and all of its lookup aliases.
--- @param primaryKey string The canonical key for the selection
--- @param itemData table The selected item data
function Manager:RegisterSelectedItem(primaryKey, itemData)
    if not primaryKey or not itemData then
        return
    end

    -- Capture the item's stable identity at selection time so batch steps can
    -- confirm the live slot still holds this exact item before acting on it.
    -- An item that moves into a freed slotIndex mid-batch would otherwise be
    -- junked/locked in place of the originally selected item. Only stamped when
    -- bagId/slotIndex are known (skipped for entryIndex-only rows like Buyback).
    if itemData.expectedSlotIdentity == nil
        and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.CaptureSlotIdentity then
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex
        if bagId ~= nil and slotIndex ~= nil then
            itemData.expectedSlotIdentity =
                BETTERUI.CIM.Utils.CaptureSlotIdentity(bagId, slotIndex, itemData)
        end
    end

    self.selectedItems[primaryKey] = itemData
    self.selectedItemAliases[primaryKey] = primaryKey
    for _, key in ipairs(self:GetItemSelectionKeys(itemData)) do
        self.selectedItemAliases[key] = primaryKey
    end
end

--- Removes a selected item and all lookup aliases that point to it.
--- @param primaryKey string The canonical key to remove
--- @param itemData table|nil Optional current item data for alias cleanup
function Manager:UnregisterSelectedItem(primaryKey, itemData)
    if not primaryKey then
        return
    end

    local storedItemData = itemData or self.selectedItems[primaryKey]
    self.selectedItems[primaryKey] = nil

    local keysToRemove = { primaryKey }
    if storedItemData then
        for _, key in ipairs(self:GetItemSelectionKeys(storedItemData)) do
            keysToRemove[#keysToRemove + 1] = key
        end
    end
    for key, mappedPrimaryKey in pairs(self.selectedItemAliases) do
        if mappedPrimaryKey == primaryKey then
            keysToRemove[#keysToRemove + 1] = key
        end
    end
    for _, key in ipairs(keysToRemove) do
        if self.selectedItemAliases[key] == primaryKey or key == primaryKey then
            self.selectedItemAliases[key] = nil
        end
    end
end

-- SELECTION MODE CONTROL

--- Enters multi-select mode
function Manager:EnterSelectionMode()
    if self.isActive then return false end

    self.isActive = true
    self.selectedItems = {} -- Clear any previous selections
    self.selectedItemAliases = {}

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
function Manager:ExitSelectionMode()
    if not self.isActive then return false end

    self.isActive = false
    self.selectedItems = {} -- Clear selections
    self.selectedItemAliases = {}

    -- Clear the active instance only when it is still this manager; another
    -- instance may have entered selection mode in the meantime.
    if MultiSelectManager.GetActiveInstance() == self then
        MultiSelectManager.SetActiveInstance(nil)
    end

    -- Play sound for mode exit
    PlaySound(SOUNDS.GAMEPAD_MENU_BACK)

    -- Fire callback
    if self.selectionChangedCallback then
        self.selectionChangedCallback(0)
    end

    return true
end

--- Checks if selection mode is currently active
function Manager:IsActive()
    return self.isActive
end

-- ITEM SELECTION

--- Toggles selection state for an item
--- @param itemData table The item data (or ZO_GamepadEntryData wrapper)
--- @return boolean isNowSelected Whether the item is selected after toggle
function Manager:ToggleSelection(itemData)
    if not itemData then return false end

    local primaryKey = self:GetPrimarySelectionKey(itemData)
    if not primaryKey then return false end

    if self.selectedItems[primaryKey] then
        -- Deselect
        self:UnregisterSelectedItem(primaryKey, itemData)
        PlaySound(SOUNDS.GAMEPAD_MENU_BACKWARD)
    else
        -- Select
        self:RegisterSelectedItem(primaryKey, itemData)
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    end

    -- Fire callback
    if self.selectionChangedCallback then
        self.selectionChangedCallback(self:GetSelectedCount())
    end

    return self.selectedItems[primaryKey] ~= nil
end

--- Checks if an item is currently selected
--- @param itemData table The item data to check
--- @return boolean
function Manager:IsSelected(itemData)
    if not itemData then return false end

    local primaryKey = self:GetPrimarySelectionKey(itemData)
    if not primaryKey then return false end

    return self.selectedItems[primaryKey] ~= nil
end

--- Selects an item without toggling
function Manager:Select(itemData)
    if not itemData then return end

    local primaryKey = self:GetPrimarySelectionKey(itemData)
    if not primaryKey then return end

    if not self.selectedItems[primaryKey] then
        self:RegisterSelectedItem(primaryKey, itemData)
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)

        if self.selectionChangedCallback then
            self.selectionChangedCallback(self:GetSelectedCount())
        end
    end
end

--- Deselects an item without toggling
function Manager:Deselect(itemData)
    if not itemData then return end

    local primaryKey = self:GetPrimarySelectionKey(itemData)
    if not primaryKey then return end

    if self.selectedItems[primaryKey] then
        self:UnregisterSelectedItem(primaryKey, itemData)
        PlaySound(SOUNDS.GAMEPAD_MENU_BACKWARD)

        if self.selectionChangedCallback then
            self.selectionChangedCallback(self:GetSelectedCount())
        end
    end
end

--- Clears all selections without exiting selection mode
function Manager:ClearSelections()
    self.selectedItems = {}
    self.selectedItemAliases = {}

    if self.selectionChangedCallback then
        self.selectionChangedCallback(0)
    end
end

--- Resolves the iterable view of a list: inner parametric list, item count,
--- and optional dataList fallback. Shared by SelectAll and RefreshSelections.
--- @param targetList table|nil The list (possibly a ZO_GamepadInventoryList wrapper)
--- @return table|nil innerList, integer numItems, table|nil dataList
local function ResolveListItems(targetList)
    if not targetList then return nil, 0, nil end

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

    return innerList, numItems, dataList
end

--- Returns the entry data at index using the resolved list view.
local function GetListEntryData(innerList, dataList, index)
    if dataList then
        -- Direct access when using dataList fallback
        return dataList[index]
    end
    if innerList and innerList.GetDataForDataIndex then
        return innerList:GetDataForDataIndex(index)
    end
    return nil
end

--- Selects all items in the specified list (or the stored list if none provided)
--- Handles ZO_GamepadEntryData which wraps item data in dataSource
function Manager:SelectAll(listOverride)
    local targetList = listOverride or self.list
    if not targetList then return end

    local innerList, numItems, dataList = ResolveListItems(targetList)

    for i = 1, numItems do
        local data = GetListEntryData(innerList, dataList, i)

        if data then
            local primaryKey = self:GetPrimarySelectionKey(data)
            if primaryKey then
                -- Store the full data (including wrapper) for consistent id lookup later
                self:RegisterSelectedItem(primaryKey, data)
            end
        end
    end

    if self.selectionChangedCallback then
        self.selectionChangedCallback(self:GetSelectedCount())
    end
end

-- SELECTION QUERIES

--- Gets the count of selected items
--- @return integer
function Manager:GetSelectedCount()
    local count = 0
    for _ in pairs(self.selectedItems) do
        count = count + 1
    end
    return count
end

--- Gets all selected items as an array
--- @return table[]
function Manager:GetSelectedItems()
    local items = {}
    for _, itemData in pairs(self.selectedItems) do
        items[#items + 1] = itemData
    end
    return items
end

--- Checks if any items are selected
function Manager:HasSelections()
    return next(self.selectedItems) ~= nil
end

-- BATCH OPERATIONS

--- Performs a batch operation on all selected items
--- @param operationFn fun(itemData: table): boolean|nil Operation to perform on each item
--- @return integer processedCount Number of items successfully processed
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

-- UTILITIES

--- Gets the primary selection key for an item
--- Handles ZO_GamepadEntryData which wraps item data in dataSource
--- Returns the first key from GetItemSelectionKeys: the normalized uniqueId
--- when present, otherwise a "bagId_slotIndex" or "entry_N" composite key
--- @param itemData table The item data (raw or ZO_GamepadEntryData wrapper)
--- @return string|nil uniqueId The primary selection key, or nil if unresolvable
function Manager:GetItemUniqueId(itemData)
    local keys = self:GetItemSelectionKeys(itemData)
    return keys[1]
end

--- Refreshes selection state after list data changes
--- Removes selections for items no longer in the list
function Manager:RefreshSelections()
    if not self.list then return end

    -- Reuse SelectAll's list resolution so wrapped lists (GetParametricList)
    -- and dataList-only lists refresh correctly instead of silently no-oping.
    local innerList, numItems, dataList = ResolveListItems(self.list)

    -- Build lookup of every current alias key to the latest list data.
    local currentItemsByKey = {}
    for i = 1, numItems do
        local data = GetListEntryData(innerList, dataList, i)
        if data then
            for _, key in ipairs(self:GetItemSelectionKeys(data)) do
                currentItemsByKey[key] = data
            end
        end
    end

    -- Rebuild selection aliases against the latest list data and drop missing items.
    local refreshedSelectedItems = {}
    local refreshedAliases = {}
    local removedCount = 0
    for primaryKey, itemData in pairs(self.selectedItems) do
        local matchedData = currentItemsByKey[primaryKey]
        if not matchedData then
            for _, key in ipairs(self:GetItemSelectionKeys(itemData)) do
                matchedData = currentItemsByKey[key]
                if matchedData then
                    break
                end
            end
        end

        if matchedData then
            refreshedSelectedItems[primaryKey] = matchedData
            refreshedAliases[primaryKey] = primaryKey
            for _, key in ipairs(self:GetItemSelectionKeys(matchedData)) do
                refreshedAliases[key] = primaryKey
            end
        else
            removedCount = removedCount + 1
        end
    end

    self.selectedItems = refreshedSelectedItems
    self.selectedItemAliases = refreshedAliases

    -- Fire callback if anything was removed
    if removedCount > 0 and self.selectionChangedCallback then
        self.selectionChangedCallback(self:GetSelectedCount())
    end
end

-- EXPORT TO NAMESPACE

-- Convenience factory function
function MultiSelectManager.Create(list, selectionChangedCallback)
    return Manager:New(list, selectionChangedCallback)
end
