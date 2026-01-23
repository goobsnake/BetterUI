--[[
File: Modules/Inventory/CraftList.lua
Purpose: Implements the specific list logic for the ESO Plus Craft Bag.
         Subclasses BETTERUI.Inventory.List.
Last Modified: 2026-01-23

KEY RESPONSIBILITIES:
1.  Filtering (GetFilterComparator):
    *   Generates filter functions based on item types (Alchemy, Blacksmithing, etc.).
    *   Supports complex filters (tables of filter types) or "All" mode.

2.  List Refresh (RefreshList):
    *   Rebuilds the craft bag list based on the current filter and search query.
    *   Applies text search filtering (name only) to narrow down results.
    *   Sorts items using BETTERUI_CraftList_DefaultItemSortComparator.

3.  Data Generation:
    *   AddSlotDataToTable: Populates the list with cached category information.
]]

--- @class BETTERUI.Inventory.CraftList : BETTERUI.Inventory.List
BETTERUI.Inventory.CraftList = BETTERUI.Inventory.List:Subclass()

--- Creates a filter comparator for craft bag items.
---
--- Purpose: Generates a closure to filter items.
--- Mechanics:
--- - If `filterType` is a table: Matches ANY of the contained types (OR logic).
--- - If `filterType` is a number: Matches that specific type.
--- - If `filterType` is nil/false: Matches EVERYTHING ("All" category).
---
--- @param filterType number|table|nil The filter type(s) to apply.
--- @return function A predicate function (itemData) -> boolean.
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

--- Default item sort comparator for craft list.
---
--- Purpose: Sorts craft bag items.
--- Mechanics: Category Name -> Type Name -> Name -> Level, etc.
---
--- @param left table: Left item data
--- @param right table: Right item data
--- @return boolean: True if left should come before right
local function BETTERUI_CraftList_DefaultItemSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "bestGamepadItemCategoryName", DEFAULT_GAMEPAD_ITEM_SORT, ZO_SORT_ORDER_UP)
end

--- Adds slot data to the table if it passes the filter.
---
--- Purpose: Populates the list cache with valid items.
--- Mechanics:
--- - Generates slot data via `SHARED_INVENTORY`.
--- - Applies `itemFilterFunction`.
--- - Calculates and caches `bestGamepadItemCategoryName` and `bestItemTypeName`.
---
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

--- Refreshes the craft list with filtered and sorted items.
---
--- Purpose: Rebuilds the Craft Bag list.
--- Mechanics:
--- 1. Updates Filter Function.
--- 2. Generates Slot Table (full or filtered).
--- 3. **Text Search**: Filter by name (case-insensitive substring).
---    - *Optimization*: Excludes category names to ensure precise matching for short strings.
--- 4. **Sort**: Applies default comparator.
--- 5. **Entries**: Creates `ZO_GamepadEntryData`, sets headers on category change, and adds to list.
--- 6. **Commit**: Renders the list.
---
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
        
        -- Reuse buffer table to avoid garbage creation on every keystroke
        if not self.searchMatches then self.searchMatches = {} end
        ZO_ClearNumericallyIndexedTable(self.searchMatches)
        
        for i = 1, #filteredDataTable do
            local it = filteredDataTable[i]
            local name = tostring(it.name or "")
            local lname = name:lower()
            if string.find(lname, q, 1, true) then
                table.insert(self.searchMatches, it)
            end
        end
        filteredDataTable = self.searchMatches
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
