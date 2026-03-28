--[[
File: Modules/CIM/Lists/GenericListManager.lua
Purpose: Shared list management logic for Inventory and Banking modules.
         Provides sorting, filtering, position tracking, and caching utilities.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

--- @class BETTERUI.CIM.GenericListManager : ZO_Object
--- @field savedPositions table<string, integer> Saved scroll positions by category key
--- @field itemCache table Cached item link data for avoiding repeated API calls
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

-- POSITION MANAGEMENT

--- @param categoryKey string The category key to save for
--- @param position integer The scroll position to save
function BETTERUI.CIM.GenericListManager:SavePosition(categoryKey, position)
    if categoryKey then
        self.savedPositions[categoryKey] = position
    end
end

--- @param categoryKey string The category key to restore
--- @return integer|nil position The saved position, or nil if none
function BETTERUI.CIM.GenericListManager:RestorePosition(categoryKey)
    return self.savedPositions[categoryKey]
end

--- Clears all saved list positions.
function BETTERUI.CIM.GenericListManager:ClearSavedPositions()
    self.savedPositions = {}
end

-- ITEM CACHING

--- Caches expensive item link data to avoid repeated API calls.
--- @param itemData table The item data to enrich with cached properties
--- @param bagId integer The bag containing the item
--- @param slotIndex integer The slot within the bag
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

-- SORTING COMPARATORS (Static Functions)

--- @param left table Item data with name field
--- @param right table Item data with name field
--- @return boolean
function BETTERUI.CIM.SortByName(left, right)
    local leftName = left.name or left.bestItemTypeName or ""
    local rightName = right.name or right.bestItemTypeName or ""
    return leftName < rightName
end

--- @param left table Item data with quality field
--- @param right table Item data with quality field
--- @return boolean
function BETTERUI.CIM.SortByQuality(left, right)
    local leftQuality = left.displayQuality or left.quality or 0
    local rightQuality = right.displayQuality or right.quality or 0
    return leftQuality > rightQuality
end

--- Level/CP requirement comparator (higher level first).
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

function BETTERUI.CIM.SortByValue(left, right)
    local leftValue = left.sellPrice or 0
    local rightValue = right.sellPrice or 0
    return leftValue > rightValue
end

function BETTERUI.CIM.SortBySlotIndex(left, right)
    local leftSlot = left.slotIndex or 0
    local rightSlot = right.slotIndex or 0
    return leftSlot < rightSlot
end

--- Sorts by bag ID first, then slot index.
function BETTERUI.CIM.SortByBagAndSlot(left, right)
    local leftBag = left.bagId or 0
    local rightBag = right.bagId or 0

    if leftBag ~= rightBag then
        return leftBag < rightBag
    end

    return BETTERUI.CIM.SortBySlotIndex(left, right)
end

-- FILTERING UTILITIES (Instance Methods)

--- Filters item list by name substring (case-insensitive).
--- @param items table[] The items to filter
--- @param searchQuery string|nil The search text
--- @return table[] filteredItems Items matching the query
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

-- UTILITY FUNCTIONS (Static)

--- Equality function for parametric list templates.
function BETTERUI.CIM.MenuEntryTemplateEquality(left, right)
    return left.uniqueId == right.uniqueId
end
