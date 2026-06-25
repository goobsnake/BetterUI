BETTERUI.Inventory.CraftList = BETTERUI.Inventory.List:Subclass()

--- Sets the sort function for the craft bag list.
--- Called by OnHeaderSortChanged when user sorts by column header.
---@param sortFunction function Sort comparator function
---@return nil
function BETTERUI.Inventory.CraftList:SetSortFunction(sortFunction)
    self.sortFunction = sortFunction
end

---@param filterType table|number|nil Filter type constant, table of filter types, or nil for all
---@return function comparator Filter function accepting itemData and returning boolean
function BETTERUI.Inventory.GetFilterComparator(filterType)
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
    bestItemTypeName = { tiebreaker = "name" },
    name = { tiebreaker = "requiredLevel" },
    requiredLevel = { tiebreaker = "requiredChampionPoints", isNumeric = true },
    requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
    iconFile = { tiebreaker = "uniqueId" },
    uniqueId = { isId64 = true },
}

local function BETTERUI_CraftList_DefaultItemSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "bestGamepadItemCategoryName", DEFAULT_GAMEPAD_ITEM_SORT,
        ZO_SORT_ORDER_UP)
end

-- Exported so other modules (sorting reset, craft-bag list setup) can reference
-- the canonical default comparator instead of a bare global.
BETTERUI.Inventory.CraftListDefaultSortComparator = BETTERUI_CraftList_DefaultItemSortComparator

local function TraceCraftList(phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Inventory"
    data.feature = "craftBagList"
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.LIST or "LIST", "craftbag.list_refresh", phase, data)
end

local function DescribeCraftFilter(filterType)
    if type(filterType) ~= "table" then return filterType end
    local out = {}
    local count = 0
    for _, value in pairs(filterType) do
        count = count + 1
        if #out < 5 then out[#out + 1] = value end
    end
    return { count = count, sample = out }
end

local function BuildCraftListSample(items, limit)
    local sample = {}
    local count = items and #items or 0
    local sampleCount = math.min(count, limit or 5)
    for i = 1, sampleCount do
        local itemData = items[i]
        sample[#sample + 1] = {
            index = i,
            name = itemData and itemData.name,
            bagId = itemData and itemData.bagId,
            slotIndex = itemData and itemData.slotIndex,
            uniqueId = itemData and itemData.uniqueId and tostring(itemData.uniqueId) or nil,
            category = itemData and itemData.bestItemCategoryName,
        }
    end
    return sample
end

function BETTERUI.Inventory.CraftList:AddSlotDataToTable(slotsTable, inventoryType, slotIndex)
    local itemFilterFunction = self.itemFilterFunction
    local categorizationFunction = self.categorizationFunction or
        BETTERUI.CIM.SharedItemSupport.GetBestItemCategoryDescription
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(inventoryType, slotIndex)
    if slotData then
        if (not itemFilterFunction) or itemFilterFunction(slotData) then
            -- Set categorization data once
            local categoryName = categorizationFunction(slotData)
            slotData.bestGamepadItemCategoryName = categoryName
            slotData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER,
                BETTERUI.Inventory.GetBestItemCategoryDescription(slotData))
            slotData.bestItemCategoryName = categoryName
            slotData.itemCategoryName = categoryName

            table.insert(slotsTable, slotData)
        end
    end
end

function BETTERUI.Inventory.CraftList:RefreshList(...)
    -- Argless calls come from the base-class show/inventory-update handlers and
    -- must NOT reset the craft-bag filter/search context; explicit calls (from
    -- RefreshCraftBagList) always pass both arguments and update it.
    local filterType, searchQuery
    if select("#", ...) > 0 then
        filterType, searchQuery = ...
        self.lastFilterType = filterType
        self.lastSearchQuery = searchQuery
    else
        filterType = self.lastFilterType
        searchQuery = self.lastSearchQuery
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "Refreshing CraftList", {filterType = filterType}) end
    TraceCraftList("begin", {
        filterType = DescribeCraftFilter(filterType),
        searchLength = searchQuery and #tostring(searchQuery) or 0,
        explicitArgs = select("#", ...) > 0,
    })

    -- Cancel any in-flight deferred batch and reset pending state BEFORE the
    -- hidden early-out, so a refresh while hidden cannot leave a stale batch
    -- (built from pre-refresh data) resuming later.
    if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Cancel then
        BETTERUI.Inventory.Tasks:Cancel("craftBatchProcess")
    end
    self.batchCallId = nil
    self.pendingBatchData = nil
    self.pendingBatchIndex = nil
    self.pendingContext = nil

    -- Hidden/dirty early-out mirroring the base class: defer the rebuild until
    -- the OnEffectivelyShown handler sees isDirty and refreshes on show.
    if self.control and self.control.IsHidden and self.control:IsHidden() then
        self.isDirty = true
        TraceCraftList("skipped", {
            reason = "hidden",
            filterType = DescribeCraftFilter(filterType),
            searchLength = searchQuery and #tostring(searchQuery) or 0,
        })
        return
    end
    self.isDirty = false

    -- Update empty-state text based on search context
    if searchQuery and tostring(searchQuery) ~= "" then
        self.list:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_SEARCH_NO_RESULTS")))
    else
        self.list:SetNoItemText(GetString(SI_INVENTORY_ERROR_CRAFT_BAG_EMPTY))
    end

    self.list:Clear()

    self.itemFilterFunction = BETTERUI.Inventory.GetFilterComparator(filterType)
    local filteredDataTable = self:GenerateSlotTable()
    TraceCraftList("filtered", {
        rowCount = #filteredDataTable,
        filterType = DescribeCraftFilter(filterType),
        searchLength = searchQuery and #tostring(searchQuery) or 0,
        sample = BuildCraftListSample(filteredDataTable, 5),
    })

    -- Apply text search filtering when requested (case-insensitive substring match on item name only)
    -- Intentionally exclude category/type fields from the craft-bag search so
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
        TraceCraftList("search_filtered", {
            rowCount = #filteredDataTable,
            searchLength = #tostring(searchQuery),
            sample = BuildCraftListSample(filteredDataTable, 5),
        })
    end


    -- Sort the filtered data using custom sort function if set, otherwise default
    local sortFunc = self.sortFunction or BETTERUI_CraftList_DefaultItemSortComparator
    table.sort(filteredDataTable, sortFunc)
    TraceCraftList("sorted", {
        rowCount = #filteredDataTable,
        customSort = self.sortFunction ~= nil,
        sample = BuildCraftListSample(filteredDataTable, 5),
    })

    -- BATCH PROCESSING CONSTANTS (Using global BetterUI.Inventory.CONST)

    -- Small List: Synchronous
    if #filteredDataTable <= BETTERUI.Inventory.CONST.BATCH_SIZE_INITIAL then
        local lastBestItemCategoryName
        for i, itemData in ipairs(filteredDataTable) do
            local data = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
            data:InitializeInventoryVisualData(itemData)
            -- Use the pre-calculated category name
            data.bestItemCategoryName = itemData.bestItemCategoryName
            data.itemCategoryName = itemData.bestItemCategoryName
            data.bestItemTypeName = itemData.bestItemTypeName
            data.bestGamepadItemCategoryName = itemData.bestItemCategoryName

            -- Set header only when category changes; headers only render when the
            -- row is added through the WithHeader template variant.
            if itemData.bestItemCategoryName ~= lastBestItemCategoryName then
                data:SetHeader(itemData.bestItemCategoryName)
                lastBestItemCategoryName = itemData.bestItemCategoryName
                self.list:AddEntryWithHeader("BETTERUI_GamepadItemSubEntryTemplate", data)
            else
                self.list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", data)
            end
        end
        self.list:Commit()
        TraceCraftList("committed", {
            mode = "sync",
            rowCount = #filteredDataTable,
            sample = BuildCraftListSample(filteredDataTable, 5),
        })
        return
    end

    -- Large List: Batch
    self.pendingBatchData = filteredDataTable
    self.pendingBatchIndex = 1
    self.pendingContext = {
        lastBestItemCategoryName = nil,
        filterType = DescribeCraftFilter(filterType),
        searchLength = searchQuery and #tostring(searchQuery) or 0,
        sample = BuildCraftListSample(filteredDataTable, 5),
    }
    TraceCraftList("batch_begin", {
        rowCount = #filteredDataTable,
        filterType = self.pendingContext.filterType,
        searchLength = self.pendingContext.searchLength,
        sample = self.pendingContext.sample,
    })

    self:ProcessBatch()
end

--- Processes a batch of craft bag items.
function BETTERUI.Inventory.CraftList:ProcessBatch()
    if not self.pendingBatchData or not self.list then
        TraceCraftList("batch_skipped", {
            reason = self.list and "missingPendingData" or "missingList",
        })
        return
    end

    local startIndex = self.pendingBatchIndex or 1
    local totalItems = #self.pendingBatchData

    if startIndex > totalItems then
        TraceCraftList("batch_complete", {
            reason = "indexPastEnd",
            rowCount = totalItems,
            sample = self.pendingContext and self.pendingContext.sample or nil,
        })
        self.pendingBatchData = nil
        self.pendingBatchIndex = nil
        self.pendingContext = nil
        return
    end

    local endIndex = math.min(startIndex + BETTERUI.Inventory.CONST.BATCH_SIZE_REMAINING - 1, totalItems)
    local lastBestItemCategoryName = self.pendingContext.lastBestItemCategoryName

    for i = startIndex, endIndex do
        local itemData = self.pendingBatchData[i]
        local data = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
        data:InitializeInventoryVisualData(itemData)

        data.bestItemCategoryName = itemData.bestItemCategoryName
        data.itemCategoryName = itemData.bestItemCategoryName
        data.bestItemTypeName = itemData.bestItemTypeName
        data.bestGamepadItemCategoryName = itemData.bestItemCategoryName

        -- Headers only render when the row is added through the WithHeader template variant.
        if itemData.bestItemCategoryName ~= lastBestItemCategoryName then
            data:SetHeader(itemData.bestItemCategoryName)
            lastBestItemCategoryName = itemData.bestItemCategoryName
            self.list:AddEntryWithHeader("BETTERUI_GamepadItemSubEntryTemplate", data)
        else
            self.list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", data)
        end
    end

    self.pendingContext.lastBestItemCategoryName = lastBestItemCategoryName
    self.list:Commit()
    self.pendingBatchIndex = endIndex + 1
    TraceCraftList("chunk_committed", {
        startIndex = startIndex,
        endIndex = endIndex,
        nextIndex = self.pendingBatchIndex,
        rowCount = totalItems,
        sample = self.pendingContext and self.pendingContext.sample or nil,
    })

    if self.pendingBatchIndex <= totalItems then
        BETTERUI.Inventory.Tasks:Schedule("craftBatchProcess", 10, function() self:ProcessBatch() end)
    else
        TraceCraftList("committed", {
            mode = "batch",
            rowCount = totalItems,
            sample = self.pendingContext and self.pendingContext.sample or nil,
        })
        self.pendingBatchData = nil
        self.pendingBatchIndex = nil
        self.pendingContext = nil
    end
end
