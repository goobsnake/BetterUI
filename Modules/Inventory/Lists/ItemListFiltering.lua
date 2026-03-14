--[[
File: Modules/Inventory/Lists/ItemListFiltering.lua
Purpose: Handles inventory item filtering, search matching, refresh, and tooltip updates.
Author: BetterUI Team
Last Modified: 2026-03-14
]]

BETTERUI = BETTERUI or {}
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Localize frequently used globals
local GetItemLink = GetItemLink
local zo_strformat = zo_strformat
local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
local GetBestItemCategoryDescription = BETTERUI.Inventory.Categories.GetBestItemCategoryDescription
local Id64ToString = Id64ToString

local function IsStolenItem(itemData)
    return itemData.stolen
end

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
function BETTERUI.Inventory.Class:RefreshItemList()
    -- Skip refresh during batch processing to prevent flickering
    if self:IsBatchProcessing() then
        return
    end
    -- Capture current selection before clearing
    -- Priority: _splitStackUniqueId > _preserveUniqueId > uniqueId > savedIndex
    local targetUniqueId = nil
    local targetIndex = nil

    -- Priority 1: Split stack specific (set in dialog callback)
    if self._splitStackUniqueId then
        targetUniqueId = Id64ToString(self._splitStackUniqueId)
        self._splitStackUniqueId = nil
        -- Priority 2: Global preserve uniqueId (set in OnInventoryUpdated before callbacks fire)
    elseif self._preserveUniqueId then
        targetUniqueId = Id64ToString(self._preserveUniqueId)
        self._preserveUniqueId = nil
    elseif self.currentlySelectedData then
        -- Priority 3: Use saved uniqueId from currentlySelectedData if available
        if self.currentlySelectedData.uniqueId then
            targetUniqueId = Id64ToString(self.currentlySelectedData.uniqueId)
        end
        -- Priority 4: Use saved index from ToSavedPosition (per-category)
        if self.currentlySelectedData.savedIndex then
            targetIndex = self.currentlySelectedData.savedIndex
        end
    end

    -- Capture current active index before clearing as an ultimate fallback
    if not targetIndex and self.itemList:GetSelectedIndex() then
        targetIndex = self.itemList:GetSelectedIndex()
    end

    -- Priority fallback: Global preserve index (when item leaves list after equip/consume)
    if not targetIndex and self._preserveIndex then
        targetIndex = self._preserveIndex
    end
    self._preserveIndex = nil -- Clear after capturing

    -- Update empty-state text based on search context
    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        self.itemList:SetNoItemText(GetString(SI_BETTERUI_SEARCH_NO_RESULTS))
    else
        self.itemList:SetNoItemText(GetString(SI_BETTERUI_EMPTY_LIST))
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
            -- OPTIMIZATION: Check if this is truly the "All Items" view (no filters)
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

    -- OPTIMIZATION: Do search filtering FIRST, before expensive per-item processing
    -- This avoids doing API calls for items that won't even be displayed
    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        local q = tostring(self.searchQuery):lower()

        -- OPTIMIZATION: Reuse buffer table to avoid garbage creation
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
    -- DefaultSortComparator uses sortPriorityName as the primary key, so it must be
    -- populated before table.sort. Without this, first-load has nil values (falling
    -- through to tiebreakers) while subsequent refreshes have stale values from batch
    -- processing, producing inconsistent sort order.
    for i = 1, #filteredDataTable do
        local itemData = filteredDataTable[i]
        if not itemData.sortPriorityName then
            local bestCategoryDesc = itemData.cachedBestCategoryDesc
            if not bestCategoryDesc then
                bestCategoryDesc = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.cachedBestCategoryDesc = bestCategoryDesc
            end
            if AutoCategory and AutoCategory.Inited then
                local customCategory, matched, catName, catPriority = BETTERUI.GetCustomCategory(itemData)
                if customCategory and not matched then
                    itemData.sortPriorityName = string.format("%03d%s", 999, catName)
                elseif customCategory then
                    itemData.sortPriorityName = string.format("%03d%s", 100 - catPriority, catName)
                else
                    itemData.sortPriorityName = bestCategoryDesc
                end
            else
                itemData.sortPriorityName = bestCategoryDesc
            end
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

    -- NOTE: Loop body removed here as it is now handled by ProcessScrollListBatch

    -- OPTIMIZATION: Removed redundant RefreshCategoryList() call here
    -- SwitchActiveList already calls RefreshCategoryList before RefreshItemList
end

--- Updates the left tooltip for the selected item.
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
        BETTERUI.Inventory.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, slotIndex)
    else
        BETTERUI.Inventory.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)

        -- INV-001: Inject stat comparison for non-equipped items
        if BETTERUI.Inventory.StatComparison and selectedData.bagId and selectedData.slotIndex then
            local itemLink = GetItemLink(selectedData.bagId, selectedData.slotIndex)
            local result = BETTERUI.Inventory.StatComparison.Compare(itemLink, selectedData.bagId, selectedData.slotIndex)
            if result and result.lines and #result.lines > 0 then
                local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_LEFT_TOOLTIP)
                if container then
                    if not container._betterUiComparison then
                        local label = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
                        label:SetMaxLineCount(0)
                        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
                        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                        container._betterUiComparison = label
                    end
                    local compLabel = container._betterUiComparison
                    local fontSize = BETTERUI.GetTooltipFontSize()
                    local compFontSize = math.floor(fontSize * 0.75)
                    compLabel:SetFont("$(MEDIUM_FONT)|" .. compFontSize .. "|shadow")
                    compLabel:SetText(BETTERUI.Inventory.StatComparison.FormatForTooltip(result))

                    -- Position at bottom of tooltip container
                    compLabel:ClearAnchors()
                    compLabel:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, 5, -5)
                    compLabel:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -5, -5)
                    compLabel:SetHidden(false)
                end
            else
                -- No comparison applicable — hide label
                local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_LEFT_TOOLTIP)
                if container and container._betterUiComparison then
                    container._betterUiComparison:SetHidden(true)
                end
            end
        end
    end
end

--- Updates the comparison tooltip (displayed in the Left Tooltip window in BetterUI)
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
            GetString(SI_GAMEPAD_INVENTORY_ITEM_COMPARE_TOOLTIP_TITLE))
    elseif selectedItemData ~= nil and selectedItemData.bagId ~= nil and selectedItemData.slotIndex ~= nil then
        -- Fallback: Show standard tooltip for non-comparable items
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedItemData.bagId, selectedItemData.slotIndex)
        -- Reset switchInfo since this item can't be compared
        self.switchInfo = false
    elseif selectedEquipSlot and GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, BAG_WORN, selectedEquipSlot) then
        BETTERUI.Inventory.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, selectedEquipSlot)
    end
end
