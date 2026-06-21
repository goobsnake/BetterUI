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
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "save position", { categoryKey = categoryKey, position = position })
        end
    end
end

--- @param categoryKey string The category key to restore
--- @return integer|nil position The saved position, or nil if none
function BETTERUI.CIM.GenericListManager:RestorePosition(categoryKey)
    local position = self.savedPositions[categoryKey]
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "restore position", { categoryKey = categoryKey, position = position })
    end
    return position
end

--- Clears all saved list positions.
function BETTERUI.CIM.GenericListManager:ClearSavedPositions()
    self.savedPositions = {}
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "clear saved positions")
    end
end

-- ITEM CACHING

--- Caches expensive item link data to avoid repeated API calls.
--- @param itemData table The item data to enrich with cached properties
--- @param bagId integer The bag containing the item
--- @param slotIndex integer The slot within the bag
function BETTERUI.CIM.GenericListManager:CacheItemLinkData(itemData, bagId, slotIndex)
    if itemData.cached_itemLink then
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "reused cached itemLink") end
        return
    end

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
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "sort by name")
    end
    local leftName = left.name or left.bestItemTypeName or ""
    local rightName = right.name or right.bestItemTypeName or ""
    return leftName < rightName
end

--- @param left table Item data with quality field
--- @param right table Item data with quality field
--- @return boolean
function BETTERUI.CIM.SortByQuality(left, right)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "sort by quality")
    end
    local leftQuality = left.displayQuality or left.quality or 0
    local rightQuality = right.displayQuality or right.quality or 0
    return leftQuality > rightQuality
end

--- Level/CP requirement comparator (higher level first).
function BETTERUI.CIM.SortByLevel(left, right)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "sort by level")
    end
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
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "sort by value")
    end
    local leftValue = left.sellPrice or 0
    local rightValue = right.sellPrice or 0
    return leftValue > rightValue
end

function BETTERUI.CIM.SortBySlotIndex(left, right)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "sort by slot index")
    end
    local leftSlot = left.slotIndex or 0
    local rightSlot = right.slotIndex or 0
    return leftSlot < rightSlot
end

--- Sorts by bag ID first, then slot index.
function BETTERUI.CIM.SortByBagAndSlot(left, right)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "sort by bag and slot")
    end
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
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SEARCH,
            "filter list by '" .. query .. "' (" .. #items .. " items)",
            { query = query, totalItems = #items })
    end
    -- Time the filter loop (a per-keystroke hot path over the full item set). Inert when
    -- PERF logging is off -- Perf.Begin returns nil and Perf.End no-ops.
    local perf = BETTERUI.CIM.Perf and BETTERUI.CIM.Perf.Begin("applyTextFilter")

    for _, item in ipairs(items) do
        local name = item.name or ""
        if name:lower():find(query, 1, true) then
            table.insert(filtered, item)
        end
    end

    -- Only build the data table + call End when a span was actually started (PERF on),
    -- so the off path allocates nothing.
    if perf then
        BETTERUI.CIM.Perf.End(perf, { items = #items, matched = #filtered, query = query })
    end
    return filtered
end

function BETTERUI.CIM.GenericListManager:BuildSortFunction(sortKeys)
    if not sortKeys or #sortKeys == 0 then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "build sort function fallback")
        end
        return BETTERUI.CIM.SortBySlotIndex
    end

    if #sortKeys == 1 then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "build sort function single")
        end
        return sortKeys[1]
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "build sort function composite", { keyCount = #sortKeys })
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
