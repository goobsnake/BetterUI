--[[
File: Modules/CIM/Lists/GenericListManager.lua
Purpose: Shared list management logic for Inventory and Banking modules.
         Provides sorting, filtering, position tracking, and caching utilities.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

--[[
Class: BETTERUI.CIM.GenericListManager
Description: Base class for list management logic shared across inventory-like windows.
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

--[[
Function: BETTERUI.CIM.GenericListManager:SavePosition
Description: Saves the current list position for later restoration.
param: categoryKey (string) - The category to save position for.
param: position (number) - The scroll position to save.
]]
--- @param categoryKey string The category to save position for
--- @param position number The position to save
function BETTERUI.CIM.GenericListManager:SavePosition(categoryKey, position)
    if categoryKey then
        self.savedPositions[categoryKey] = position
    end
end

--[[
Function: BETTERUI.CIM.GenericListManager:RestorePosition
Description: Restores a previously saved list position.
param: categoryKey (string) - The category to restore position for.
return: number|nil - The saved position, or nil if not found.
]]
--- @param categoryKey string The category to restore position for
--- @return number|nil position The saved position or nil if not found
function BETTERUI.CIM.GenericListManager:RestorePosition(categoryKey)
    return self.savedPositions[categoryKey]
end

--[[
Function: BETTERUI.CIM.GenericListManager:ClearSavedPositions
Description: Clears all saved list positions.
]]
function BETTERUI.CIM.GenericListManager:ClearSavedPositions()
    self.savedPositions = {}
end

-------------------------------------------------------------------------------------------------
-- ITEM CACHING
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericListManager:CacheItemLinkData
Description: Caches expensive item link data to avoid repeated API calls.
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

--[[
Function: BETTERUI.CIM.SortByName
Description: Alphabetical name comparator.
Rationale: Sorts items A-Z by display name.
param: left (table) - First item data.
param: right (table) - Second item data.
return: boolean - True if left should come before right.
]]
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
Description: Quality tier comparator (higher quality first).
Rationale: Sorts by item quality (Legendary > Epic > Superior > etc.)
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
Description: Level/CP requirement comparator (higher level first).
Rationale: Sorts by item level requirement.
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

--[[
Function: BETTERUI.CIM.SortByValue
Description: Sell price comparator (higher value first).
Rationale: Sorts by gold sell value.
param: left (table) - First item data.
param: right (table) - Second item data.
return: boolean - True if left should come before right.
]]
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
Description: Bag slot order comparator.
Rationale: Sorts by physical slot position (preserves bag order).
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
Description: Sorts by bag ID first, then slot index.
Rationale: Useful for bank views showing multiple bags.
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
Description: Filters item list by name substring (case-insensitive).
Rationale: Common search implementation for both Inventory and Banking.
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

--[[
Function: BETTERUI.CIM.GenericListManager:BuildSortFunction
Description: Creates a multi-key comparator from an array of sort functions.
Rationale: Allows chaining sort criteria (e.g., quality then name).
Mechanism: Returns a comparator that tries each sort function in order,
           stopping at the first one that produces a difference.
param: sortKeys (table) - Array of sort functions to chain.
return: function - Combined comparator function.
]]
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
Description: Equality function for parametric list templates.
             Used to determine if two list entries represent the same item.
param: left (table) - First entry.
param: right (table) - Second entry.
return: boolean - True if entries are equal.
]]
function BETTERUI.CIM.MenuEntryTemplateEquality(left, right)
    return left.uniqueId == right.uniqueId
end
