--[[
File: Modules/Inventory/Lists/ItemListFiltering.lua
Purpose: Handles inventory item filtering, search matching, refresh, and tooltip updates.
]]

BETTERUI = BETTERUI or {}
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Localize frequently used globals
local GetItemLink = GetItemLink
local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType

--- @param itemData table
--- @return boolean
local function IsStolenItem(itemData)
    return itemData.stolen
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

            return ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, nonEquipableFilterType)
                or (itemData.equipType == EQUIP_TYPE_POISON and nonEquipableFilterType == ITEMFILTERTYPE_WEAPONS)
        else
            -- for "All"
            return true
        end
    end
end

--- Refreshes the item list based on the selected category and filter.
---@return nil
function BETTERUI.Inventory.Class:RefreshItemList()
    -- Skip refresh during batch processing to prevent flickering
    if self:IsBatchProcessing() then
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

    local targetCategoryData = self.categoryList.selectedData -- Use safe access if possible, or direct
    if not targetCategoryData then
        -- Fallback if SafeGetTargetData is not available here or mixin failed
        targetCategoryData = self.categoryList.targetData or self.categoryList.selectedData
    end

    local filteredEquipSlot = targetCategoryData.equipSlot
    local nonEquipableFilterType = targetCategoryData.filterType
    local showJunkCategory = (targetCategoryData and targetCategoryData.showJunk ~= nil)
    local showEquippedCategory = (targetCategoryData and targetCategoryData.showEquipped ~= nil)
    local showStolenCategory = (targetCategoryData and targetCategoryData.showStolen ~= nil)
    local filteredDataTable

    local isQuestItem = nonEquipableFilterType == ITEMFILTERTYPE_QUEST
    if isQuestItem then
        filteredDataTable = {}
        local questCache = SHARED_INVENTORY:GenerateFullQuestCache()
        for _, questItems in pairs(questCache) do
            for _, questItem in pairs(questItems) do
                ZO_InventorySlot_SetType(questItem, SLOT_TYPE_QUEST_ITEM)
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

    -- BATCH PROCESSING START
    -- Cancel any existing pending batch to prevent overlapping operations
    if self.batchCallId then
        zo_removeCallLater(self.batchCallId)
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
        self:PopulateInventoryCategoryFields(filteredDataTable[i])
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
    if not selectedData or not selectedData.dataSource or not selectedData.dataSource.bagId then
        if GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(GAMEPAD_RIGHT_TOOLTIP)
        end
        return
    end

    GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(GAMEPAD_RIGHT_TOOLTIP)

    local isQuest = ZO_InventoryUtils_DoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_QUEST)

    if isQuest then
        if selectedData.toolIndex then
            GAMEPAD_TOOLTIPS:LayoutQuestItem(GAMEPAD_LEFT_TOOLTIP,
                GetQuestToolQuestItemId(selectedData.questIndex, selectedData.toolIndex))
        elseif selectedData.stepIndex and selectedData.conditionIndex then
            GAMEPAD_TOOLTIPS:LayoutQuestItem(GAMEPAD_LEFT_TOOLTIP,
                GetQuestConditionQuestItemId(selectedData.questIndex, selectedData.stepIndex,
                    selectedData.conditionIndex))
        else
            -- Item fallback for quest items with missing metadata
            GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedData.bagId, selectedData.slotIndex)
        end
    else
        -- Normal items
        local showRightTooltip = false
        if ZO_InventoryUtils_DoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_WEAPONS)
            or ZO_InventoryUtils_DoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_ARMOR)
            or ZO_InventoryUtils_DoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_JEWELRY)
        then
            if self.switchInfo then
                showRightTooltip = true
            end
        end

        if not showRightTooltip then
            GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedData.bagId, selectedData.slotIndex)
        else
            if selectedData.bagId ~= nil and selectedData.slotIndex ~= nil then
                self:UpdateRightTooltip(selectedData)
            end
        end
    end

    -- Safety: Ensure BetterUI tooltip properties are set (in case GeneralInterface hooks are disabled)
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    if tooltip and selectedData.bagId then
        tooltip._betterui_bagId = selectedData.bagId
        tooltip._betterui_slotIndex = selectedData.slotIndex
        tooltip._betterui_itemLink = GetItemLink(selectedData.bagId, selectedData.slotIndex)
        tooltip._betterui_storeStackCount = nil
    end

    if selectedData.isEquippedInCurrentCategory or selectedData.isEquippedInAnotherCategory or selectedData.equipSlot then
        local slotIndex = selectedData.bagId == BAG_WORN and selectedData.slotIndex or nil
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, slotIndex)
    else
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)

        -- INV-001: Inject stat comparison for non-equipped items
        if BETTERUI.CIM.SharedItemSupport.IsItemComparisonEnabled()
            and selectedData.bagId and selectedData.slotIndex then
            local itemLink = GetItemLink(selectedData.bagId, selectedData.slotIndex)
            local result = BETTERUI.CIM.SharedItemSupport.CompareItem(itemLink, selectedData.bagId, selectedData.slotIndex)
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
    local selectedEquipSlot

    if self:GetCurrentList() == self.itemList then
        if selectedItemData ~= nil and selectedItemData.dataSource ~= nil then
            selectedEquipSlot = self:GetEquipSlotForEquipType(selectedItemData.dataSource.equipType)
        end
    else
        selectedEquipSlot = 0
    end

    -- Check if item supports comparison (has valid equipType)
    local canCompare = selectedItemData ~= nil and
        selectedItemData.dataSource ~= nil and
        selectedItemData.dataSource.equipType ~= nil and
        selectedItemData.dataSource.equipType ~= 0

    if canCompare and selectedEquipSlot then
        -- Comparison View: Overwrites the Left Tooltip with comparison data
        GAMEPAD_TOOLTIPS:LayoutItemStatComparison(GAMEPAD_LEFT_TOOLTIP, selectedItemData.bagId,
            selectedItemData.slotIndex, selectedEquipSlot)
        GAMEPAD_TOOLTIPS:SetStatusLabelText(GAMEPAD_LEFT_TOOLTIP,
            GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ITEM_COMPARE_TOOLTIP_TITLE")))
    elseif selectedItemData ~= nil and selectedItemData.bagId ~= nil and selectedItemData.slotIndex ~= nil then
        -- Fallback: Show standard tooltip for non-comparable items
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedItemData.bagId, selectedItemData.slotIndex)
        -- Reset switchInfo since this item can't be compared
        self.switchInfo = false
    elseif selectedEquipSlot and GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, BAG_WORN, selectedEquipSlot) then
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, selectedEquipSlot)
    end
end
