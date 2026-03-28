--[[
File: Modules/CIM/Lists/GenericListManager.lua
Purpose: Shared list management logic for Inventory and Banking modules.
         Provides sorting, filtering, position tracking, and caching utilities.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

--[[
Class: BETTERUI.CIM.GenericListManager
Base class for list management logic shared across inventory-like windows.
]]
BETTERUI.CIM.GenericListManager = ZO_Object:Subclass()

function BETTERUI.CIM.GenericListManager:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BETTERUI.CIM.GenericListManager:Initialize()
    self.savedPositions = {}
    self.itemCache = {}
end

-------------------------------------------------------------------------------------------------
-- POSITION MANAGEMENT
-------------------------------------------------------------------------------------------------

--- @param categoryKey string The category to save position for
--- @param position number The position to save
function BETTERUI.CIM.GenericListManager:SavePosition(categoryKey, position)
    if categoryKey then
        self.savedPositions[categoryKey] = position
    end
end

--- @param categoryKey string The category to restore position for
--- @return number|nil position The saved position or nil if not found
function BETTERUI.CIM.GenericListManager:RestorePosition(categoryKey)
    return self.savedPositions[categoryKey]
end

--[[
Function: BETTERUI.CIM.GenericListManager:ClearSavedPositions
Clears all saved list positions.
]]
function BETTERUI.CIM.GenericListManager:ClearSavedPositions()
    self.savedPositions = {}
end

-------------------------------------------------------------------------------------------------
-- ITEM CACHING
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericListManager:CacheItemLinkData
Caches expensive item link data to avoid repeated API calls.
param: itemData (table) - The item data table to cache into.
param: bagId (number) - The bag ID.
param: slotIndex (number) - The slot index.
]]
function BETTERUI.CIM.GenericListManager:CacheItemLinkData(itemData, bagId, slotIndex)
    if itemData.cached_itemLink then return end

    local itemLink = GetItemLink(bagId, slotIndex)
    itemData.cached_itemLink = itemLink

    if itemLink then
        itemData.cached_itemType = GetItemLinkItemType(itemLink)
        itemData.cached_setItem = GetItemLinkSetInfo(itemLink, false)
        itemData.cached_hasEnchantment = GetItemLinkEnchantInfo(itemLink)

        if itemData.cached_itemType == ITEMTYPE_RECIPE then
            itemData.cached_isRecipeAndUnknown = not IsItemLinkRecipeKnown(itemLink)
        end

        itemData.cached_isBookKnown = IsItemLinkBookKnown(itemLink)
    end
end

-------------------------------------------------------------------------------------------------
-- SORTING COMPARATORS (Static Functions)
-------------------------------------------------------------------------------------------------

--- @param left table First item data
--- @param right table Second item data
--- @return boolean result True if left should come before right
function BETTERUI.CIM.SortByName(left, right)
    local leftName = left.name or left.bestItemTypeName or ""
    local rightName = right.name or right.bestItemTypeName or ""
    return leftName < rightName
end

--[[
Function: BETTERUI.CIM.SortByQuality
Quality tier comparator (higher quality first).
param: left (table) - First item data.
param: right (table) - Second item data.
return: boolean - True if left should come before right.
]]
function BETTERUI.CIM.SortByQuality(left, right)
    local leftQuality = left.displayQuality or left.quality or 0
    local rightQuality = right.displayQuality or right.quality or 0
    return leftQuality > rightQuality
end

--[[
Function: BETTERUI.CIM.SortByLevel
Level/CP requirement comparator (higher level first).
param: left (table) - First item data.
param: right (table) - Second item data.
return: boolean - True if left should come before right.
]]
function BETTERUI.CIM.SortByLevel(left, right)
    local leftLevel = left.requiredLevel or 0
    local rightLevel = right.requiredLevel or 0

    -- Consider champion points for endgame gear
    if leftLevel == rightLevel then
        local leftCP = left.requiredChampionPoints or 0
        local rightCP = right.requiredChampionPoints or 0
        return leftCP > rightCP
    end

    return leftLevel > rightLevel
end

--- @param left table First item data
--- @param right table Second item data
--- @return boolean result True if left should come before right
function BETTERUI.CIM.SortByValue(left, right)
    local leftValue = left.sellPrice or 0
    local rightValue = right.sellPrice or 0
    return leftValue > rightValue
end

--[[
Function: BETTERUI.CIM.SortBySlotIndex
Bag slot order comparator.
param: left (table) - First item data.
param: right (table) - Second item data.
return: boolean - True if left should come before right.
]]
function BETTERUI.CIM.SortBySlotIndex(left, right)
    local leftSlot = left.slotIndex or 0
    local rightSlot = right.slotIndex or 0
    return leftSlot < rightSlot
end

--[[
Function: BETTERUI.CIM.SortByBagAndSlot
Sorts by bag ID first, then slot index.
param: left (table) - First item data.
param: right (table) - Second item data.
return: boolean - True if left should come before right.
]]
function BETTERUI.CIM.SortByBagAndSlot(left, right)
    local leftBag = left.bagId or 0
    local rightBag = right.bagId or 0

    if leftBag ~= rightBag then
        return leftBag < rightBag
    end

    return BETTERUI.CIM.SortBySlotIndex(left, right)
end

-------------------------------------------------------------------------------------------------
-- FILTERING UTILITIES (Instance Methods)
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericListManager:ApplyTextFilter
Filters item list by name substring (case-insensitive).
param: items (table) - Array of item data tables.
param: searchQuery (string) - The search string to match.
return: table - Filtered array of items matching the query.
]]
function BETTERUI.CIM.GenericListManager:ApplyTextFilter(items, searchQuery)
    if not searchQuery or searchQuery == "" then
        return items
    end

    local query = searchQuery:lower()
    local filtered = {}

    for _, item in ipairs(items) do
        local name = item.name or ""
        if name:lower():find(query, 1, true) then
            table.insert(filtered, item)
        end
    end

    return filtered
end

--- @param sortKeys table Array of sort functions to chain
--- @return function comparator Combined comparator function
function BETTERUI.CIM.GenericListManager:BuildSortFunction(sortKeys)
    if not sortKeys or #sortKeys == 0 then
        return BETTERUI.CIM.SortBySlotIndex
    end

    if #sortKeys == 1 then
        return sortKeys[1]
    end

    return function(left, right)
        for _, sortFn in ipairs(sortKeys) do
            local leftFirst = sortFn(left, right)
            local rightFirst = sortFn(right, left)

            -- If this sort function distinguishes the items, use its result
            if leftFirst ~= rightFirst then
                return leftFirst
            end
            -- Otherwise, continue to next sort key
        end

        -- All sort keys were equal; maintain original order
        return false
    end
end

-------------------------------------------------------------------------------------------------
-- UTILITY FUNCTIONS (Static)
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.MenuEntryTemplateEquality
Equality function for parametric list templates.
             Used to determine if two list entries represent the same item.
param: left (table) - First entry.
param: right (table) - Second entry.
return: boolean - True if entries are equal.
]]
function BETTERUI.CIM.MenuEntryTemplateEquality(left, right)
    return left.uniqueId == right.uniqueId
end
