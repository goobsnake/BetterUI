--------------------------------------------------------------------------------
-- BetterUI Craft Bag List
--
-- This file implements the specific list logic for the ESO Plus Craft Bag.
-- It subclasses `BETTERUI.Inventory.List` but overrides key methods to handle
-- the unique filtering and sorting requirements of the virtual bag.
--
-- KEY RESPONSIBILITIES:
--
-- 1.  **Filtering (`GetFilterComparator`)**:
--     *   Generates filter functions based on item types (Alchemy, Blacksmithing, etc.).
--     *   Supports complex filters (tables of filter types) or "All" mode.
--
-- 2.  **List Refresh (`RefreshList`)**:
--     *   Rebuilds the craft bag list based on the current filter and search query.
--     *   Applies text search filtering (name only) to narrow down results.
--     *   Sorts items using `BETTERUI_CraftList_DefaultItemSortComparator`.
--
-- 3.  **Data Generation**:
--     *   `AddSlotDataToTable`: Populates the list with cached category information.
--
-- TODO(refactor): GetFilterComparator duplicates logic from Inventory.lua - extract to shared utility
-- TODO(cleanup): Unreachable code at line 54 (return after if/else) - remove dead code
-- TODO(optimization): Text search in RefreshList creates new table every call - reuse buffer
--------------------------------------------------------------------------------

--- @class BETTERUI.Inventory.CraftList : BETTERUI.Inventory.List
BETTERUI.Inventory.CraftList = BETTERUI.Inventory.List:Subclass()

-- Creates a filter comparator for craft bag items
--- @param filterType number|table: Filter type(s) to apply
--- @return function: Returns true if item matches filter
-- Creates a filter comparator for craft bag items.
--- @param filterType number|table The filter type(s) to apply. Can be a single filter ID or a table of IDs.
--- @return function A function that returns true if an item matches the filter(s).
function GetFilterComparator(filterType)
	return function(itemData)
		if filterType then
			-- we can pass a table of filters into the function, and this case has to be handled separately
			if type(filterType) == "table" then
				local filterHit = false
				
				for key, filter in pairs(filterType) do
					if ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, filter) then
						filterHit = true
					end
				end
				
				return filterHit
			else
				return ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, filterType)	
			end
		else
			-- for "All"
			return true
		end

		return ZO_InventoryUtils_DoesNewItemMatchSupplies(itemData)
	end
end

local DEFAULT_GAMEPAD_ITEM_SORT =
{
    bestGamepadItemCategoryName = { tiebreaker = "bestItemTypeName" },
	bestItemTypeName = { tiebreaker = "name"},
    name = { tiebreaker = "requiredLevel" },
    requiredLevel = { tiebreaker = "requiredChampionPoints", isNumeric = true },
    requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
    iconFile = { tiebreaker = "uniqueId" },
    uniqueId = { isId64 = true },
}

--- Default item sort comparator for craft list
--- @param left table: Left item data
--- @param right table: Right item data
--- @return boolean: True if left should come before right
local function BETTERUI_CraftList_DefaultItemSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "bestGamepadItemCategoryName", DEFAULT_GAMEPAD_ITEM_SORT, ZO_SORT_ORDER_UP)
end

--- Adds slot data to the table if it passes the filter
--- @param slotsTable table: The table to add to
--- @param inventoryType number: The inventory type
--- @param slotIndex number: The slot index
function BETTERUI.Inventory.CraftList:AddSlotDataToTable(slotsTable, inventoryType, slotIndex)
    local itemFilterFunction = self.itemFilterFunction
    local categorizationFunction = self.categorizationFunction or ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(inventoryType, slotIndex)
    if slotData then
        if (not itemFilterFunction) or itemFilterFunction(slotData) then
            -- Set categorization data once
            local categoryName = categorizationFunction(slotData)
            slotData.bestGamepadItemCategoryName = categoryName
            slotData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(slotData))
            slotData.bestItemCategoryName = categoryName
            slotData.itemCategoryName = categoryName

            table.insert(slotsTable, slotData)
        end
    end
end

--- Refreshes the craft list with filtered and sorted items
--- @param filterType number|table: The filter type(s)
--- Refreshes the craft list with filtered and sorted items.
--- @param filterType number|table The filter type(s) to apply.
--- @param searchQuery string|nil The text search query to filter by name.
function BETTERUI.Inventory.CraftList:RefreshList(filterType, searchQuery)
    self.list:Clear()

    self.itemFilterFunction = GetFilterComparator(filterType)
    local filteredDataTable = self:GenerateSlotTable()

    -- Apply text search filtering when requested (case-insensitive substring match on item name only)
    -- NOTE: we intentionally exclude category/type fields from the craft-bag search so
    -- short queries (single-character) don't match engine-provided type strings like "(Alchemy)".
    if searchQuery and tostring(searchQuery) ~= "" then
        local q = tostring(searchQuery):lower()
        local matches = {}
        for i = 1, #filteredDataTable do
            local it = filteredDataTable[i]
            local name = tostring(it.name or "")
            local lname = name:lower()
            if string.find(lname, q, 1, true) then
                table.insert(matches, it)
            end
        end
        filteredDataTable = matches
    end

    -- Sort the filtered data
    table.sort(filteredDataTable, BETTERUI_CraftList_DefaultItemSortComparator)

    local lastBestItemCategoryName
    for i, itemData in ipairs(filteredDataTable) do
        local data = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
        data:InitializeInventoryVisualData(itemData)

        -- Use the pre-calculated category name
        data.bestItemCategoryName = itemData.bestItemCategoryName
        data.itemCategoryName = itemData.bestItemCategoryName
        data.bestItemTypeName = itemData.bestItemTypeName
        data.bestGamepadItemCategoryName = itemData.bestItemCategoryName

        -- Set header only when category changes
        if itemData.bestItemCategoryName ~= lastBestItemCategoryName then
            data:SetHeader(itemData.bestItemCategoryName)
            lastBestItemCategoryName = itemData.bestItemCategoryName
        end

        self.list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", data)
    end

    self.list:Commit()
end