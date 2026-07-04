--[[
File: Modules/Inventory/Lists/ItemListFiltering.lua
Purpose: Handles inventory item filtering, search matching, refresh, and tooltip updates.
]]

BETTERUI = BETTERUI or {}
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Localize frequently used globals
local GetItemLink = GetItemLink
local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
local INVENTORY_LIST_MODULE_NAME = "Inventory"
local nativeFilterFailureWarnings = {}

--- @param itemData table
--- @return boolean
local function IsStolenItem(itemData)
    return itemData.stolen
end

local function BuildQuestItemUniqueId(itemData)
    return string.format("quest:%s:%s:%s:%s",
        tostring(itemData.questIndex or ""),
        tostring(itemData.toolIndex or ""),
        tostring(itemData.stepIndex or ""),
        tostring(itemData.conditionIndex or ""))
end

local function SafeDoesNewItemMatchFilterType(itemData, filterType, caller)
    if not itemData or filterType == nil or type(ZO_InventoryUtils_DoesNewItemMatchFilterType) ~= "function" then
        return false
    end

    local ok, matches = pcall(ZO_InventoryUtils_DoesNewItemMatchFilterType, itemData, filterType)
    if ok then
        return matches == true
    end

    local warningKey = table.concat({ tostring(caller or "unknown"), tostring(filterType), tostring(matches) }, "|")
    if not nativeFilterFailureWarnings[warningKey] and BETTERUI.Log and BETTERUI.Log.Warn then
        nativeFilterFailureWarnings[warningKey] = true
        local L = BETTERUI.Log
        local categories = L.CATEGORY or {}
        L.Warn(categories.LIST, "inventory filter match failed", {
            fn = caller or "ItemListFiltering",
            filterType = filterType,
            error = tostring(matches),
            item = L.DescribeItem and L.DescribeItem(itemData.dataSource or itemData, "item") or nil,
        })
    end

    return false
end

local function IsQuestItemData(itemData)
    if type(itemData) ~= "table" then
        return false
    end
    local source = itemData.dataSource or itemData
    if type(source) ~= "table" then
        return false
    end

    -- Shared intrinsic-marker check, then this module's native quest-filter fallback
    -- (kept local so its LIST-category warning routing is preserved).
    return BETTERUI.Inventory.Utils.HasQuestItemMarkers(itemData)
        or SafeDoesNewItemMatchFilterType(itemData, ITEMFILTERTYPE_QUEST, "ItemListFiltering.IsQuestItemData")
end

function BETTERUI.Inventory.Class:PrepareQuestItemListEntry(itemData)
    local questStringId = rawget(_G, "SI_GAMEPAD_INVENTORY_QUEST_ITEMS")
    local questCategoryName = questStringId and GetString(questStringId) or "Quest"
    local hadImpossibleEquipState = itemData.isEquippedInCurrentCategory == true
        or itemData.isEquippedInAnotherCategory == true
        or itemData.equipSlot ~= nil
        or itemData.isHiddenByWardrobe == true

    itemData.isQuestItem = true
    itemData.stackCount = itemData.stackCount or 1
    itemData.icon = itemData.icon or itemData.iconFile
    itemData.iconFile = itemData.iconFile or itemData.icon
    itemData.uniqueId = itemData.uniqueId or BuildQuestItemUniqueId(itemData)
    itemData.bestItemTypeName = itemData.bestItemTypeName or questCategoryName
    itemData.bestItemCategoryName = itemData.bestItemCategoryName or questCategoryName
    itemData.bestGamepadItemCategoryName = itemData.bestGamepadItemCategoryName or questCategoryName
    itemData.itemCategoryName = itemData.itemCategoryName or questCategoryName
    itemData.sortPriorityName = itemData.sortPriorityName or string.format("%s%s", questCategoryName,
        tostring(itemData.name or ""))
    itemData.listModuleName = INVENTORY_LIST_MODULE_NAME

    local questItemId = itemData.questItemId
    if not questItemId and itemData.toolIndex and GetQuestToolQuestItemId then
        questItemId = GetQuestToolQuestItemId(itemData.questIndex, itemData.toolIndex)
    elseif not questItemId and itemData.stepIndex and itemData.conditionIndex and GetQuestConditionQuestItemId then
        questItemId = GetQuestConditionQuestItemId(itemData.questIndex, itemData.stepIndex, itemData.conditionIndex)
    end
    itemData.questItemId = questItemId
    itemData.isQuestQuickslotted = nil
    if questItemId and FindActionSlotMatchingSimpleAction then
        itemData.isQuestQuickslotted = FindActionSlotMatchingSimpleAction(ACTION_TYPE_QUEST_ITEM,
            questItemId, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) ~= nil or nil
    end

    itemData.isEquippedInCurrentCategory = nil
    itemData.isEquippedInAnotherCategory = nil
    itemData.equipSlot = nil
    itemData.isHiddenByWardrobe = nil

    if hadImpossibleEquipState and BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIST, "quest item carried equipment visual state; cleared", {
            item = BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(itemData, "quest") or nil,
            questIndex = itemData.questIndex,
            questItemId = questItemId,
        })
    end
    ZO_InventorySlot_SetType(itemData, SLOT_TYPE_QUEST_ITEM)
end

--- Gets a comparator function for filtering item data.
--- @param filteredEquipSlot number|nil
--- @param nonEquipableFilterType number|nil ITEMFILTERTYPE_* constant
--- @return fun(itemData: table): boolean
---@param filteredEquipSlot number|nil Equipment slot to filter by
---@param nonEquipableFilterType number|nil Non-equipment filter type
---@return function comparator Filter function for item data
function BETTERUI.Inventory.Class:GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)
    return function(itemData)
        if nonEquipableFilterType then
            -- Special-case companion items: companion filter should only match companion actorCategory
            if nonEquipableFilterType == ITEMFILTERTYPE_COMPANION then
                return itemData and itemData.actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION
            end

            return SafeDoesNewItemMatchFilterType(itemData, nonEquipableFilterType,
                "ItemListFiltering.GetItemDataFilterComparator")
                or (itemData and itemData.equipType == EQUIP_TYPE_POISON and nonEquipableFilterType == ITEMFILTERTYPE_WEAPONS)
        else
            -- for "All"
            return true
        end
    end
end

--- Refreshes the item list based on the selected category and filter.
---@return nil
function BETTERUI.Inventory.Class:RefreshItemList()
    if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "Refreshing item list", {query = self.searchQuery}) end
    -- Skip refresh during batch processing to prevent flickering
    if self:IsBatchProcessing() then
        return
    end
    -- The item list may not be built yet during early / re-entrant scene-show flows.
    if not self.itemList then
        return
    end
    local targetUniqueId, targetIndex = self:CaptureItemListRefreshTarget()

    -- Update empty-state text based on search context
    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        self.itemList:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_SEARCH_NO_RESULTS")))
    else
        self.itemList:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_EMPTY_LIST")))
    end

    self.itemList:Clear()
    if self.categoryList:IsEmpty() then
        return
    end

    local targetCategoryData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
    if not targetCategoryData and self.categoryList.dataList and #self.categoryList.dataList > 0 then
        local restoreIndex = self.categoryList.targetSelectedIndex or self.categoryList.selectedIndex or 1
        restoreIndex = zo_clamp(restoreIndex, 1, #self.categoryList.dataList)
        if self.categoryList.SetSelectedIndexWithoutAnimation then
            self.categoryList:SetSelectedIndexWithoutAnimation(restoreIndex, true, false)
        else
            self.categoryList.selectedIndex = restoreIndex
            self.categoryList.targetSelectedIndex = restoreIndex
            self.categoryList.selectedData = self.categoryList.dataList[restoreIndex]
            self.categoryList.targetData = self.categoryList.selectedData
        end
        targetCategoryData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
    end

    if not targetCategoryData then
        if self.itemList.Commit then
            self.itemList:Commit()
        end
        return
    end

    local filteredEquipSlot = targetCategoryData.equipSlot
    local nonEquipableFilterType = targetCategoryData.filterType
    local showJunkCategory = (targetCategoryData and targetCategoryData.showJunk ~= nil)
    local showEquippedCategory = (targetCategoryData and targetCategoryData.showEquipped ~= nil)
    local showStolenCategory = (targetCategoryData and targetCategoryData.showStolen ~= nil)
    local filteredDataTable
    local searchLen = self.searchQuery and #tostring(self.searchQuery) or 0

    local isQuestItem = nonEquipableFilterType == ITEMFILTERTYPE_QUEST
    if isQuestItem then
        filteredDataTable = {}
        local questCache = SHARED_INVENTORY:GenerateFullQuestCache()
        for _, questItems in pairs(questCache) do
            for _, questItem in pairs(questItems) do
                self:PrepareQuestItemListEntry(questItem)
                filteredDataTable[#filteredDataTable + 1] = questItem
            end
        end
    else
        local comparator = self:GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)

        if showEquippedCategory then
            local worn = self:GetCachedSlotData(BAG_WORN)
            filteredDataTable = {}
            for _, slotData in ipairs(worn) do
                if comparator(slotData) then
                    filteredDataTable[#filteredDataTable + 1] = slotData
                end
            end
        elseif showStolenCategory then
            local backpack = self:GetCachedSlotData(BAG_BACKPACK)
            filteredDataTable = {}
            for _, slotData in ipairs(backpack) do
                if IsStolenItem(slotData) then
                    filteredDataTable[#filteredDataTable + 1] = slotData
                end
            end
        else
            -- Check if this is truly the "All Items" view (no filters)
            -- If specific filters are set (Weapons, Armor, etc.), we MUST use the comparator
            if filteredEquipSlot == nil and nonEquipableFilterType == nil then
                -- "All Items" Case: Direct insert (fastest)
                local bags = self:GetCachedSlotData(BAG_BACKPACK, BAG_WORN)
                filteredDataTable = {}
                for i = 1, #bags do
                    filteredDataTable[#filteredDataTable + 1] = bags[i]
                end
            else
                -- Specific Category (Weapons, Armor, etc.): Use Comparator
                local bags = self:GetCachedSlotData(BAG_BACKPACK, BAG_WORN)
                filteredDataTable = {}
                for _, slotData in ipairs(bags) do
                    if comparator(slotData) then
                        filteredDataTable[#filteredDataTable + 1] = slotData
                    end
                end
            end
        end
    end

    local preCount = #filteredDataTable

    -- Do search filtering FIRST, before expensive per-item processing
    -- This avoids doing API calls for items that won't even be displayed
    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        local q = tostring(self.searchQuery):lower()

        -- Reuse buffer table to avoid garbage creation
        if not self.searchMatches then self.searchMatches = {} end
        ZO_ClearNumericallyIndexedTable(self.searchMatches)

        for i = 1, #filteredDataTable do
            local it = filteredDataTable[i]
            -- Use cached lowercase name if available, otherwise compute and cache it
            local lname = it.cachedLowerName
            if not lname then
                lname = tostring(it.name or ""):lower()
                it.cachedLowerName = lname
            end
            if string.find(lname, q, 1, true) then
                self.searchMatches[#self.searchMatches + 1] = it
            end
        end
        filteredDataTable = self.searchMatches
    end

    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "refresh items", {
            categoryKey = targetCategoryData.key,
            searchLen = searchLen,
            preCount = preCount,
            postCount = #filteredDataTable,
        })
    end

    -- BATCH PROCESSING START
    -- Cancel any existing pending batch to prevent overlapping operations.
    -- The batch is scheduled through the inventory task manager (see
    -- ItemListManager), so it must be cancelled there too.
    if self.batchCallId then
        BETTERUI.Inventory.Tasks:Cancel("batchProcess")
        self.batchCallId = nil
    end
    -- Clear pending batch state to ensure clean slate
    self.pendingBatchData = nil
    self.pendingBatchIndex = nil
    self.pendingContext = nil

    -- Pre-compute sortPriorityName for all items BEFORE sorting.
    -- Populate the canonical display and sort metadata before table.sort so full
    -- refreshes and live updates use the same category/type source fields.
    for i = 1, #filteredDataTable do
        if isQuestItem then
            self:PrepareQuestItemListEntry(filteredDataTable[i])
        else
            self:PopulateInventoryCategoryFields(filteredDataTable[i])
        end
    end

    -- Use the list's custom sort function if set, otherwise fall back to default
    -- This allows header sort to override the default sorting
    -- self.currentSortComparators["itemList"] is set by OnHeaderSortChanged when user sorts by header column
    local sortFunc = (self.currentSortComparators and self.currentSortComparators["itemList"]) or
        BETTERUI.Inventory.DefaultSortComparator

    -- If the list is small enough, process synchronously (prevents flickering on small lists)
    if #filteredDataTable <= BETTERUI.Inventory.CONST.BATCH_SIZE_INITIAL then
        table.sort(filteredDataTable, sortFunc)
        self.pendingContext = {
            showJunkCategory = showJunkCategory,
            categoryKey = targetCategoryData.key,
            filteredEquipSlot = filteredEquipSlot,
            isQuestItem = isQuestItem,
            currentBestCategoryName = nil,
            targetUniqueId = targetUniqueId,
            targetIndex = targetIndex
        }
        self.pendingBatchData = filteredDataTable
        self.pendingBatchIndex = 1
        -- Process all at once
        self:ProcessScrollListBatch()
        return
    end

    -- LARGE LIST: Sort first, then process in batches
    -- sortPriorityName was pre-computed above for all items
    table.sort(filteredDataTable, sortFunc)

    self.pendingContext = {
        showJunkCategory = showJunkCategory,
        categoryKey = targetCategoryData.key,
        filteredEquipSlot = filteredEquipSlot,
        isQuestItem = isQuestItem,
        currentBestCategoryName = nil,
        targetUniqueId = targetUniqueId,
        targetIndex = targetIndex
    }
    self.pendingBatchData = filteredDataTable
    self.pendingBatchIndex = 1

    -- Run first batch immediately
    self:ProcessScrollListBatch()
end

--- Updates the left tooltip for the selected item.
---@param selectedData table|nil Selected item data for tooltip display
---@return nil
function BETTERUI.Inventory.Class:UpdateItemLeftTooltip(selectedData)
    local selectedDataSource = selectedData and (selectedData.dataSource or selectedData) or nil
    if not selectedData or not selectedDataSource then
        if GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(GAMEPAD_RIGHT_TOOLTIP)
        end
        return
    end

    GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(GAMEPAD_RIGHT_TOOLTIP)
    local bagId = selectedDataSource.bagId or selectedData.bagId
    local slotIndex = selectedDataSource.slotIndex or selectedData.slotIndex

    local isQuest = IsQuestItemData(selectedData)

    if not isQuest and bagId == nil then
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        return
    end

    if isQuest then
        local questIndex = selectedData.questIndex or selectedDataSource.questIndex
        local toolIndex = selectedData.toolIndex or selectedDataSource.toolIndex
        local stepIndex = selectedData.stepIndex or selectedDataSource.stepIndex
        local conditionIndex = selectedData.conditionIndex or selectedDataSource.conditionIndex

        if toolIndex then
            GAMEPAD_TOOLTIPS:LayoutQuestItem(GAMEPAD_LEFT_TOOLTIP,
                GetQuestToolQuestItemId(questIndex, toolIndex))
        elseif stepIndex and conditionIndex then
            GAMEPAD_TOOLTIPS:LayoutQuestItem(GAMEPAD_LEFT_TOOLTIP,
                GetQuestConditionQuestItemId(questIndex, stepIndex, conditionIndex))
        elseif bagId and slotIndex then
            -- Item fallback for quest items with missing metadata
            GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, bagId, slotIndex)
        end
    else
        -- Normal items
        local showRightTooltip = false
        if SafeDoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_WEAPONS,
                "ItemListFiltering.UpdateItemLeftTooltip")
            or SafeDoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_ARMOR,
                "ItemListFiltering.UpdateItemLeftTooltip")
            or SafeDoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_JEWELRY,
                "ItemListFiltering.UpdateItemLeftTooltip")
        then
            if self.switchInfo then
                showRightTooltip = true
            end
        end

        if not showRightTooltip then
            GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, bagId, slotIndex)
        else
            if bagId ~= nil and slotIndex ~= nil then
                self:UpdateRightTooltip(selectedData)
            end
        end
    end

    -- Safety: Ensure BetterUI tooltip properties are set (in case GeneralInterface hooks are disabled)
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    if tooltip and bagId then
        tooltip._betterui_bagId = bagId
        tooltip._betterui_slotIndex = slotIndex
        tooltip._betterui_itemLink = GetItemLink(bagId, slotIndex)
        tooltip._betterui_storeStackCount = nil
    end

    if selectedData.isEquippedInCurrentCategory or selectedData.isEquippedInAnotherCategory or selectedData.equipSlot then
        local equippedSlotIndex = bagId == BAG_WORN and slotIndex or nil
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, equippedSlotIndex)
    else
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)

        -- INV-001: Inject stat comparison for non-equipped items
        if BETTERUI.CIM.SharedItemSupport.IsItemComparisonEnabled()
            and bagId and slotIndex then
            local itemLink = GetItemLink(bagId, slotIndex)
            local result = BETTERUI.CIM.SharedItemSupport.CompareItem(itemLink, bagId, slotIndex)
            local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_LEFT_TOOLTIP)
            BETTERUI.CIM.SharedItemSupport.ShowComparisonOnTooltip(container, result)
        else
            local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_LEFT_TOOLTIP)
            BETTERUI.CIM.SharedItemSupport.ShowComparisonOnTooltip(container, nil)
        end
    end
end

--- Updates the comparison tooltip (displayed in the Left Tooltip window in BetterUI).
---@param selectedData table|nil Selected item data for right tooltip
---@return nil
function BETTERUI.Inventory.Class:UpdateRightTooltip(selectedData)
    local selectedItemData = selectedData
    local selectedDataSource = selectedItemData and (selectedItemData.dataSource or selectedItemData) or nil
    local bagId = selectedDataSource and (selectedDataSource.bagId or selectedItemData.bagId) or nil
    local slotIndex = selectedDataSource and (selectedDataSource.slotIndex or selectedItemData.slotIndex) or nil
    local selectedEquipSlot

    if self:GetCurrentList() == self.itemList then
        if selectedDataSource ~= nil then
            selectedEquipSlot = self:GetEquipSlotForEquipType(selectedDataSource.equipType)
        end
    else
        selectedEquipSlot = 0
    end

    -- Check if item supports comparison (has valid equipType)
    local canCompare = selectedDataSource ~= nil and
        selectedDataSource.equipType ~= nil and
        selectedDataSource.equipType ~= 0

    if canCompare and selectedEquipSlot then
        -- Comparison View: Overwrites the Left Tooltip with comparison data
        GAMEPAD_TOOLTIPS:LayoutItemStatComparison(GAMEPAD_LEFT_TOOLTIP, bagId, slotIndex, selectedEquipSlot)
        GAMEPAD_TOOLTIPS:SetStatusLabelText(GAMEPAD_LEFT_TOOLTIP,
            GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ITEM_COMPARE_TOOLTIP_TITLE")))
    elseif selectedItemData ~= nil and bagId ~= nil and slotIndex ~= nil then
        -- Fallback: Show standard tooltip for non-comparable items
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, bagId, slotIndex)
        -- Reset switchInfo since this item can't be compared
        self.switchInfo = false
    elseif selectedEquipSlot and GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, BAG_WORN, selectedEquipSlot) then
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, selectedEquipSlot)
    end
end
