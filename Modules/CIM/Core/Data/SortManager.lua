--[[
File: Modules/CIM/Core/SortManager.lua
Purpose: Unified sort system for BetterUI inventory and banking lists.
         Provides consistent sort options across modules without code duplication.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.SortManager = {}

-- ============================================================================
-- SORT TYPE CONSTANTS
-- ============================================================================

---@enum SortType
BETTERUI.CIM.SortManager.SORT_TYPES = {
    CATEGORY = 1,    -- Default: Sort by item category (weapons, armor, etc.)
    NAME = 2,        -- Alphabetical by item name
    QUALITY = 3,     -- By quality tier (legendary first)
    STACK_COUNT = 4, -- By stack size (largest first)
    VALUE = 5,       -- By vendor value (highest first)
    LEVEL = 6,       -- By item level
}

---@enum SortOrder
BETTERUI.CIM.SortManager.SORT_ORDER = {
    ASCENDING = 1,
    DESCENDING = 2,
}

-- Human-readable names for UI display
local SORT_TYPE_NAMES = {
    [1] = "Category",
    [2] = "Name",
    [3] = "Quality",
    [4] = "Stack Count",
    [5] = "Value",
    [6] = "Level",
}

-- ============================================================================
-- SORT COMPARATOR FUNCTIONS
-- ============================================================================

local SORT_TYPES = BETTERUI.CIM.SortManager.SORT_TYPES
local SORT_ORDER = BETTERUI.CIM.SortManager.SORT_ORDER

--[[
Function: GetItemQualityValue
Description: Returns numeric quality value for sorting (higher = better).
param: itemData (table) - Item data with quality info.
return: number - Quality value (0-5).
]]
--- @param itemData table|nil Item data with quality info
--- @return number quality Quality value (0-5)
local function GetItemQualityValue(itemData)
    if not itemData then return 0 end
    if itemData.quality then
        return itemData.quality
    end
    if itemData.displayQuality then
        return itemData.displayQuality
    end
    if itemData.bagId and itemData.slotIndex then
        return GetItemQuality(itemData.bagId, itemData.slotIndex)
    end
    return 0
end

--[[
Function: GetItemValue
Description: Returns vendor sell value for sorting.
param: itemData (table) - Item data.
return: number - Vendor value.
]]
--- @param itemData table|nil Item data
--- @return number value Vendor value
local function GetItemValue(itemData)
    if not itemData then return 0 end
    if itemData.sellPrice then
        return itemData.sellPrice
    end
    if itemData.bagId and itemData.slotIndex then
        local _, sellPrice = GetItemInfo(itemData.bagId, itemData.slotIndex)
        return sellPrice or 0
    end
    return 0
end

--[[
Function: GetItemLevel
Description: Returns required/actual level for sorting.
param: itemData (table) - Item data.
return: number - Item level.
]]
--- @param itemData table|nil Item data
--- @return number level Item level
local function GetItemLevel(itemData)
    if not itemData then return 0 end
    if itemData.requiredLevel then
        return itemData.requiredLevel
    end
    if itemData.bagId and itemData.slotIndex then
        return GetItemRequiredLevel(itemData.bagId, itemData.slotIndex) or 0
    end
    return 0
end

-- ============================================================================
-- CORE SORT API
-- ============================================================================

--[[
Function: BETTERUI.CIM.SortManager.CreateComparator
Description: Creates a comparator function for table.sort().
Rationale: Single entry point for all sort comparisons, used by Inventory and Banking.
param: sortType (number) - One of SORT_TYPES.
param: sortOrder (number) - ASCENDING or DESCENDING.
return: function(a, b) - Comparator function.
]]
function BETTERUI.CIM.SortManager.CreateComparator(sortType, sortOrder)
    sortOrder = sortOrder or SORT_ORDER.ASCENDING
    local descending = (sortOrder == SORT_ORDER.DESCENDING)

    return function(a, b)
        -- Guard: Return stable order if either input is nil
        if not a and not b then return false end
        if not a then return false end
        if not b then return true end

        local valA, valB

        if sortType == SORT_TYPES.NAME then
            valA = (a.name or ""):lower()
            valB = (b.name or ""):lower()
        elseif sortType == SORT_TYPES.QUALITY then
            valA = GetItemQualityValue(a)
            valB = GetItemQualityValue(b)
        elseif sortType == SORT_TYPES.STACK_COUNT then
            valA = a.stackCount or 1
            valB = b.stackCount or 1
        elseif sortType == SORT_TYPES.VALUE then
            valA = GetItemValue(a)
            valB = GetItemValue(b)
        elseif sortType == SORT_TYPES.LEVEL then
            valA = GetItemLevel(a)
            valB = GetItemLevel(b)
        else -- CATEGORY (default)
            valA = a.bestItemCategoryName or ""
            valB = b.bestItemCategoryName or ""
        end

        -- Handle equal values: secondary sort by name for stability
        if valA == valB then
            local nameA = (a.name or ""):lower()
            local nameB = (b.name or ""):lower()
            return nameA < nameB
        end

        if descending then
            return valA > valB
        else
            return valA < valB
        end
    end
end

--[[
Function: BETTERUI.CIM.SortManager.SortItems
Description: Sorts an array of item data in-place.
param: items (table) - Array of item data to sort.
param: sortType (number) - One of SORT_TYPES.
param: sortOrder (number) - ASCENDING or DESCENDING.
]]
function BETTERUI.CIM.SortManager.SortItems(items, sortType, sortOrder)
    if not items or #items == 0 then return end

    local comparator = BETTERUI.CIM.SortManager.CreateComparator(sortType, sortOrder)
    table.sort(items, comparator)
end

--[[
Function: BETTERUI.CIM.SortManager.GetSortTypeName
Description: Returns human-readable name for a sort type.
param: sortType (number) - One of SORT_TYPES.
return: string - Display name.
]]
function BETTERUI.CIM.SortManager.GetSortTypeName(sortType)
    return SORT_TYPE_NAMES[sortType] or "Unknown"
end

--[[
Function: BETTERUI.CIM.SortManager.GetAllSortTypes
Description: Returns all sort type constants with names for UI building.
return: table - Array of {id, name} pairs.
]]
function BETTERUI.CIM.SortManager.GetAllSortTypes()
    local result = {}
    for id, name in pairs(SORT_TYPE_NAMES) do
        table.insert(result, { id = id, name = name })
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

-- ============================================================================
-- SETTINGS INTEGRATION
-- ============================================================================

--[[
Function: BETTERUI.CIM.SortManager.GetCurrentSortType
Description: Gets the currently configured sort type from settings.
param: module (string) - "Inventory" or "Banking".
return: number - Current sort type.
]]
function BETTERUI.CIM.SortManager.GetCurrentSortType(module)
    local settings = BETTERUI.Settings and BETTERUI.Settings.SortOptions
    if settings and settings[module] then
        return settings[module].sortType or SORT_TYPES.CATEGORY
    end
    return SORT_TYPES.CATEGORY
end

--[[
Function: BETTERUI.CIM.SortManager.SetSortType
Description: Sets the sort type preference (persisted to saved variables).
param: module (string) - "Inventory" or "Banking".
param: sortType (number) - One of SORT_TYPES.
]]
function BETTERUI.CIM.SortManager.SetSortType(module, sortType)
    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.SortOptions = BETTERUI.Settings.SortOptions or {}
    BETTERUI.Settings.SortOptions[module] = BETTERUI.Settings.SortOptions[module] or {}
    BETTERUI.Settings.SortOptions[module].sortType = sortType
end

--[[
Function: BETTERUI.CIM.SortManager.GetCurrentSortOrder
Description: Gets the currently configured sort order from settings.
param: module (string) - "Inventory" or "Banking".
return: number - Current sort order.
]]
function BETTERUI.CIM.SortManager.GetCurrentSortOrder(module)
    local settings = BETTERUI.Settings and BETTERUI.Settings.SortOptions
    if settings and settings[module] then
        return settings[module].sortOrder or SORT_ORDER.ASCENDING
    end
    return SORT_ORDER.ASCENDING
end

--[[
Function: BETTERUI.CIM.SortManager.SetSortOrder
Description: Sets the sort order preference (persisted to saved variables).
param: module (string) - "Inventory" or "Banking".
param: sortOrder (number) - ASCENDING or DESCENDING.
]]
function BETTERUI.CIM.SortManager.SetSortOrder(module, sortOrder)
    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.SortOptions = BETTERUI.Settings.SortOptions or {}
    BETTERUI.Settings.SortOptions[module] = BETTERUI.Settings.SortOptions[module] or {}
    BETTERUI.Settings.SortOptions[module].sortOrder = sortOrder
end
