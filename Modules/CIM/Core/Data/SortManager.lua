--[[
File: Modules/CIM/Core/Data/SortManager.lua
Purpose: Unified sort system for BetterUI inventory and banking lists.
         Provides consistent sort options across modules without code duplication.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

---@class BETTERUI.CIM.SortManager
---@field SORT_TYPES SortTypes
---@field SORT_ORDER SortOrder
BETTERUI.CIM.SortManager = {}

---@class SortTypes
---@field CATEGORY number
---@field NAME number
---@field QUALITY number
---@field STACK_COUNT number
---@field VALUE number
---@field LEVEL number

---@class SortOrder
---@field ASCENDING number
---@field DESCENDING number

-- SORT TYPE CONSTANTS

BETTERUI.CIM.SortManager.SORT_TYPES = {
    CATEGORY = 1,    -- Default: Sort by item category (weapons, armor, etc.)
    NAME = 2,        -- Alphabetical by item name
    QUALITY = 3,     -- By quality tier (legendary first)
    STACK_COUNT = 4, -- By stack size (largest first)
    VALUE = 5,       -- By vendor value (highest first)
    LEVEL = 6,       -- By item level
}

BETTERUI.CIM.SortManager.SORT_ORDER = {
    ASCENDING = 1,
    DESCENDING = 2,
}

-- Human-readable names for UI display: localized string ids with English
-- fallbacks for environments where the ids are not registered.
local SORT_TYPE_NAME_STRING_IDS = {
    [1] = "SI_BETTERUI_SORT_TYPE_CATEGORY",
    [2] = "SI_BETTERUI_SORT_TYPE_NAME",
    [3] = "SI_BETTERUI_SORT_TYPE_QUALITY",
    [4] = "SI_BETTERUI_SORT_TYPE_STACK_COUNT",
    [5] = "SI_BETTERUI_SORT_TYPE_VALUE",
    [6] = "SI_BETTERUI_SORT_TYPE_LEVEL",
}

local SORT_TYPE_NAME_FALLBACKS = {
    [1] = "Category",
    [2] = "Name",
    [3] = "Quality",
    [4] = "Stack Count",
    [5] = "Value",
    [6] = "Level",
}

---@param sortType number
---@return string|nil name Localized name, English fallback, or nil for unknown types
local function ResolveSortTypeName(sortType)
    local stringId = SORT_TYPE_NAME_STRING_IDS[sortType]
    if stringId and type(GetString) == "function" then
        local localized = GetString(rawget(_G, stringId))
        if localized and localized ~= "" then
            return localized
        end
    end
    return SORT_TYPE_NAME_FALLBACKS[sortType]
end

-- SORT COMPARATOR FUNCTIONS

local SORT_TYPES = BETTERUI.CIM.SortManager.SORT_TYPES
local SORT_ORDER = BETTERUI.CIM.SortManager.SORT_ORDER

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

-- CORE SORT API

--- Creates a comparator function for table.sort().
--- Single entry point for all sort comparisons, used by Inventory and Banking.
---@param sortType number Sort type constant from SORT_TYPES
---@param sortOrder number|nil Sort order constant from SORT_ORDER (default: ASCENDING)
---@return fun(a: table, b: table): boolean comparator
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

--- Sorts an array of item data in-place.
--- Sort keys are precomputed once per entry (decorate) so the comparator,
--- which runs O(n log n) times, avoids the per-compare ESO API calls and
--- string allocations CreateComparator performs. The resulting total order is
--- identical to sorting with CreateComparator directly.
---@param items table[]|nil Array of item data to sort
---@param sortType number Sort type constant
---@param sortOrder number|nil Sort order constant
function BETTERUI.CIM.SortManager.SortItems(items, sortType, sortOrder)
    if not items or #items == 0 then return end

    sortOrder = sortOrder or SORT_ORDER.ASCENDING
    local descending = (sortOrder == SORT_ORDER.DESCENDING)

    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "sort items", { numItems = #items, sortType = sortType, order = sortOrder }) end

    -- Decorate: resolve the primary sort value and lowercased tie-break name
    -- once per entry; both are pure functions of the entry during the sort.
    local primaryKey = {}
    local nameKey = {}
    for i = 1, #items do
        local item = items[i]
        if item then
            local lowerName = (item.name or ""):lower()
            nameKey[item] = lowerName

            local value
            if sortType == SORT_TYPES.NAME then
                value = lowerName
            elseif sortType == SORT_TYPES.QUALITY then
                value = GetItemQualityValue(item)
            elseif sortType == SORT_TYPES.STACK_COUNT then
                value = item.stackCount or 1
            elseif sortType == SORT_TYPES.VALUE then
                value = GetItemValue(item)
            elseif sortType == SORT_TYPES.LEVEL then
                value = GetItemLevel(item)
            else -- CATEGORY (default)
                value = item.bestItemCategoryName or ""
            end
            primaryKey[item] = value
        end
    end

    table.sort(items, function(a, b)
        -- Guard: same stable order for nil inputs as CreateComparator
        if not a and not b then return false end
        if not a then return false end
        if not b then return true end

        local valA = primaryKey[a]
        local valB = primaryKey[b]

        -- Handle equal values: secondary sort by name for stability
        if valA == valB then
            return nameKey[a] < nameKey[b]
        end

        if descending then
            return valA > valB
        else
            return valA < valB
        end
    end)
end

---@param sortType number Sort type constant
---@return string name Human-readable sort type name
function BETTERUI.CIM.SortManager.GetSortTypeName(sortType)
    local fallbackUnknown = "Unknown"
    if type(GetString) == "function" then
        local localizedUnknown = GetString(rawget(_G, "SI_BETTERUI_SORT_TYPE_UNKNOWN"))
        if localizedUnknown and localizedUnknown ~= "" then
            fallbackUnknown = localizedUnknown
        end
    end
    return ResolveSortTypeName(sortType) or fallbackUnknown
end

--- Returns all sort type constants with names for UI building.
---@return {id: number, name: string}[] sortTypes Sorted array of sort type descriptors
function BETTERUI.CIM.SortManager.GetAllSortTypes()
    local result = {}
    for id in pairs(SORT_TYPE_NAME_FALLBACKS) do
        table.insert(result, { id = id, name = ResolveSortTypeName(id) })
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

-- SETTINGS INTEGRATION

---@param module string Module name key (e.g. "Inventory")
---@return number sortType Current sort type for the module
function BETTERUI.CIM.SortManager.GetCurrentSortType(module)
    local settings = BETTERUI.Settings and BETTERUI.Settings.SortOptions
    if settings and settings[module] then
        return settings[module].sortType or SORT_TYPES.CATEGORY
    end
    return SORT_TYPES.CATEGORY
end

---@param module string Module name key
---@param sortType number Sort type constant to set
function BETTERUI.CIM.SortManager.SetSortType(module, sortType)
    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.SortOptions = BETTERUI.Settings.SortOptions or {}
    BETTERUI.Settings.SortOptions[module] = BETTERUI.Settings.SortOptions[module] or {}
    BETTERUI.Settings.SortOptions[module].sortType = sortType
end

---@param module string Module name key
---@return number sortOrder Current sort order for the module
function BETTERUI.CIM.SortManager.GetCurrentSortOrder(module)
    local settings = BETTERUI.Settings and BETTERUI.Settings.SortOptions
    if settings and settings[module] then
        return settings[module].sortOrder or SORT_ORDER.ASCENDING
    end
    return SORT_ORDER.ASCENDING
end

---@param module string Module name key
---@param sortOrder number Sort order constant to set
function BETTERUI.CIM.SortManager.SetSortOrder(module, sortOrder)
    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.SortOptions = BETTERUI.Settings.SortOptions or {}
    BETTERUI.Settings.SortOptions[module] = BETTERUI.Settings.SortOptions[module] or {}
    BETTERUI.Settings.SortOptions[module].sortOrder = sortOrder
end

-- HEADER-SORT COLUMN COMPARATORS
-- Shared comparator mechanics for the header-sort integration used by the
-- Inventory and Banking modules. Value extraction for the special columns
-- stays module-specific (caching strategies differ per module); the shared
-- mechanics are comparator construction, direction flip, nil handling, and
-- tie-breaking.

---@class BetterUIHeaderSortComparatorHooks
---@field getTraitValue fun(data: table): string|nil Resolves the uppercased trait name (nil for blanks)
---@field getValueValue fun(data: table): number Resolves the gold value (0 for unknown)
---@field getStatValue nil|fun(data: table): number, string|number Optional stat resolver (defaults to SortManager.GetStatSortValue)
---@field tieBreak nil|fun(left: table, right: table): boolean Optional stable tie-breaker; ties compare equal (false) when omitted

--- Helper: Get stat sort value (alphabetical first, then numeric, blanks last)
---@param data table Item data or dataSource wrapper
---@return number priority Sort priority group (1=alpha, 2=numeric, 2.5=special, 3=blank)
---@return string|number value Sort value within group
function BETTERUI.CIM.SortManager.GetStatSortValue(data)
    if not data then return 3, "" end
    local statValue = data.statValue
    if statValue == nil or statValue == "" or statValue == 0 or statValue == "-" then
        return 3, "" -- Blank - lowest priority
    end
    local statStr = tostring(statValue)
    local numVal = tonumber(statStr)
    if numVal then
        return 2, numVal -- Numeric - medium priority
    end
    if statStr:match("^%a") then
        return 1, statStr:upper() -- Alphabetical - highest priority
    end
    return 2.5, statStr -- Special characters - after numeric, before blank
end

---@param tieBreak nil|fun(left: table, right: table): boolean
---@param left table
---@param right table
---@return boolean
local function BreakTie(tieBreak, left, right)
    if tieBreak then
        return tieBreak(left, right)
    end
    return false
end

---@param leftVal string|number
---@param rightVal string|number
---@param ascending boolean
---@return boolean
local function CompareDirectional(leftVal, rightVal, ascending)
    if ascending then
        return leftVal < rightVal
    else
        return leftVal > rightVal
    end
end

--- Creates a header-sort comparator for a column with the specified direction.
--- Special columns: trait (alphabetical, blanks last), stat (alpha/numeric/blank
--- priority groups), value (market price priority, zero values pinned by
--- direction). All other columns compare the raw field named by sortKey.
---@param sortKey string The data field to sort by
---@param ascending boolean Whether to sort ascending
---@param hooks BetterUIHeaderSortComparatorHooks Module-specific value getters and tie-breaking
---@return fun(left: table, right: table): boolean comparator
function BETTERUI.CIM.SortManager.CreateColumnSortComparator(sortKey, ascending, hooks)
    hooks = hooks or {}
    local tieBreak = hooks.tieBreak
    local CompareNils = BETTERUI.CIM.Utils.CompareNils

    -- TRAIT: Alphabetical with blanks after "z"
    if sortKey == "trait" then
        local getTraitValue = hooks.getTraitValue
        return function(left, right)
            local leftVal = getTraitValue(left)
            local rightVal = getTraitValue(right)
            if leftVal == nil and rightVal == nil then return BreakTie(tieBreak, left, right) end
            -- Blanks (nil) always sort last regardless of direction
            local nilResult = CompareNils(leftVal, rightVal, true)
            if nilResult ~= nil then return nilResult end
            if leftVal == rightVal then return BreakTie(tieBreak, left, right) end
            return CompareDirectional(leftVal, rightVal, ascending)
        end
    end

    -- STAT: Alphabetical first, then numeric by value, special chars, blanks last
    if sortKey == "stat" then
        local getStatValue = hooks.getStatValue or BETTERUI.CIM.SortManager.GetStatSortValue
        return function(left, right)
            local leftPrio, leftVal = getStatValue(left)
            local rightPrio, rightVal = getStatValue(right)
            -- Blanks (priority 3) always sort last regardless of direction
            if leftPrio == 3 and rightPrio == 3 then return BreakTie(tieBreak, left, right) end
            if leftPrio == 3 then return false end
            if rightPrio == 3 then return true end
            if leftPrio ~= rightPrio then
                return CompareDirectional(leftPrio, rightPrio, ascending)
            end
            if leftVal == rightVal then return BreakTie(tieBreak, left, right) end
            return CompareDirectional(leftVal, rightVal, ascending)
        end
    end

    -- VALUE: Market price first, then vendor price
    -- Ascending: 0 comes first (lowest); descending: 0 comes last
    if sortKey == "value" then
        local getValueValue = hooks.getValueValue
        return function(left, right)
            local leftVal = getValueValue(left)
            local rightVal = getValueValue(right)
            if leftVal == 0 and rightVal == 0 then return BreakTie(tieBreak, left, right) end
            if ascending then
                if leftVal == 0 then return true end
                if rightVal == 0 then return false end
            else
                if leftVal == 0 then return false end
                if rightVal == 0 then return true end
            end
            if leftVal == rightVal then return BreakTie(tieBreak, left, right) end
            return CompareDirectional(leftVal, rightVal, ascending)
        end
    end

    -- Default comparator for NAME, TYPE, and other columns
    return function(left, right)
        local leftVal = left[sortKey]
        local rightVal = right[sortKey]
        if leftVal == nil and rightVal == nil then return BreakTie(tieBreak, left, right) end
        local nilResult = CompareNils(leftVal, rightVal, ascending)
        if nilResult ~= nil then return nilResult end
        if leftVal == rightVal then return BreakTie(tieBreak, left, right) end
        return CompareDirectional(leftVal, rightVal, ascending)
    end
end
