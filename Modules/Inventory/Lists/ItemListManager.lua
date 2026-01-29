--[[
File: Modules/Inventory/Lists/ItemListManager.lua
Purpose: Manages the main item list (Backpack) for the Inventory module.
         Contains filtering, sorting, refreshing, and tooltip logic for items.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-- Localize frequently used globals
local GetItemLink = GetItemLink
local GetItemLinkItemType = GetItemLinkItemType
local GetItemLinkSetInfo = GetItemLinkSetInfo
local GetItemLinkEnchantInfo = GetItemLinkEnchantInfo
local IsItemLinkRecipeKnown = IsItemLinkRecipeKnown
local IsItemLinkBookKnown = IsItemLinkBookKnown
local IsItemLinkBook = IsItemLinkBook
local GetItemTrait = GetItemTrait
local IsItemBound = IsItemBound
local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
local zo_strformat = zo_strformat
local GetBestItemCategoryDescription = ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription
local WouldEquipmentBeHidden = WouldEquipmentBeHidden
local FindActionSlotMatchingItem = FindActionSlotMatchingItem
local Id64ToString = Id64ToString

local function MenuEntryTemplateEquality(left, right)
    -- Convert to string to ensure consistent comparison even if userdata instances differ
    return Id64ToString(left.uniqueId) == Id64ToString(right.uniqueId)
end

local function SetupItemList(list)
    list:AddDataTemplate(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEntryTemplateEquality
    )
    list:AddDataTemplateWithHeader(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEntryTemplateEquality,
        "ZO_GamepadMenuEntryHeaderTemplate"
    )
end

local function IsStolenItem(itemData)
    return itemData.stolen
end

local function GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)
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


--- Initializes the Item List.
--- Purpose: Creates the scroll list and sets up sorting/padding.
function BETTERUI.Inventory.Class:InitializeItemList()
    self.itemList = self:AddList("Items", SetupItemList, BETTERUI_VerticalParametricScrollList)

    self.itemList:SetSortFunction(BETTERUI.Inventory.DefaultSortComparator)

    self.itemList:SetOnSelectedDataChangedCallback(function(list, selectedData)
        if selectedData ~= nil and self.scene:IsShowing() then
            self.currentlySelectedData = selectedData

            self:SetSelectedInventoryData(selectedData)

            -- Debounce Tooltip Update (Removed immediate call to prevent scroll lag)
            if self.callLaterLeftToolTip ~= nil then
                EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
            end

            BETTERUI.Inventory.Tasks:Schedule("tooltipUpdate", 50, function()
                self:UpdateItemLeftTooltip(selectedData)
                self.callLaterLeftToolTip = nil
            end)
            self.callLaterLeftToolTip = "InventoryTooltipUpdate"

            self:PrepareNextClearNewStatus(selectedData)

            -- Debounce Keybind Refresh (Prevent rebuilding strip on every scroll step)
            if self.keybindCallLaterId ~= nil then
                EVENT_MANAGER:UnregisterForUpdate(self.keybindCallLaterId)
            end
            BETTERUI.Inventory.Tasks:Schedule("keybindUpdate", 50, function()
                self:RefreshKeybinds()
                self.keybindCallLaterId = nil
            end)
            self.keybindCallLaterId = "InventoryKeybindUpdate"
        end
    end)

    self.itemList.maxOffset = 30
    self.itemList:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * 0.75, GAMEPAD_HEADER_SELECTED_PADDING * 0.75)
    self.itemList:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * 0.75)

    local emptyText = GetString(SI_BETTERUI_EMPTY_LIST)
    local listControl = self.itemList and self.itemList.control
    if listControl and listControl.GetNamedChild then
        local noItemsLabel = listControl:GetNamedChild("NoItemsLabel")
        if noItemsLabel and noItemsLabel.GetText then
            local defaultText = noItemsLabel:GetText()
            if defaultText and defaultText ~= "" then
                emptyText = defaultText
            end
        end
    end
    self.itemList:SetNoItemText(emptyText)
end

--- Checks if the item list would be empty for the current filter.
function BETTERUI.Inventory.Class:IsItemListEmpty(filteredEquipSlot, nonEquipableFilterType)
    local baseComparator = GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)

    -- Check cache for worn items
    local worn = self:GetCachedSlotData(BAG_WORN)
    if worn then
        for _, itemData in ipairs(worn) do
            if baseComparator(itemData) and not itemData.isJunk then return false end
        end
    end

    -- Check cache for backpack items
    local backpack = self:GetCachedSlotData(BAG_BACKPACK)
    if backpack then
        for _, itemData in ipairs(backpack) do
            if baseComparator(itemData) and not itemData.isJunk then return false end
        end
    end

    return true
end

--- Checks for any junk items in the backpack.
function BETTERUI.Inventory.Class:HasAnyJunkInBackpack()
    -- Prefer shared inventory cache
    local backpack = self:GetCachedSlotData(BAG_BACKPACK)
    if backpack then
        for _, slotData in ipairs(backpack) do
            if slotData and slotData.isJunk == true then
                return true
            end
        end
    end

    -- Fallback
    local size = GetBagSize(BAG_BACKPACK) or 0
    for slotIndex = 0, size - 1 do
        if IsItemJunk(BAG_BACKPACK, slotIndex) then
            return true
        end
    end
    return false
end

--- Sets up visual data (name, icon, coloring) for an inventory row.
function BETTERUI.Inventory.Class:InitializeInventoryVisualData(itemData)
    self.uniqueId = itemData.uniqueId
    self.bestItemCategoryName = itemData.bestItemCategoryName
    self:SetDataSource(itemData)
    self.dataSource.requiredChampionPoints = GetItemRequiredChampionPoints(itemData.bagId, itemData.slotIndex)
    self:AddIcon(itemData.icon)
    if not itemData.questIndex then
        self:SetNameColors(self:GetColorsBasedOnQuality(self.quality))
    end
    self.cooldownIcon = itemData.icon or itemData.iconFile

    self:SetFontScaleOnSelection(false)
end

-- BATCH LOADING CONSTANTS
-- Batch constants replaced by BETTERUI.Inventory.CONST equivalents

--- Processes a batch of items for the scroll list.
--- Used by RefreshItemList to load large lists incrementally.
function BETTERUI.Inventory.Class:ProcessScrollListBatch()
    if not self.pendingBatchData or not self.scene:IsShowing() then return end

    local startIndex = self.pendingBatchIndex or 1
    local totalItems = #self.pendingBatchData

    -- If we're done, clear state
    if startIndex > totalItems then
        self.pendingBatchData = nil
        self.pendingBatchIndex = nil
        return
    end

    local batchSize = (startIndex == 1) and BETTERUI.Inventory.CONST.BATCH_SIZE_INITIAL or
        BETTERUI.Inventory.CONST.BATCH_SIZE_REMAINING
    local endIndex = math.min(startIndex + batchSize - 1, totalItems)

    local showJunkCategory = self.pendingContext.showJunkCategory
    local filteredEquipSlot = self.pendingContext.filteredEquipSlot
    local isQuestItem = self.pendingContext.isQuestItem
    local currentBestCategoryName = self.pendingContext.currentBestCategoryName
    local showRightTooltip = false -- Logic simplified for batch
    local targetUniqueId = self.pendingContext.targetUniqueId

    -- Loop logic duplicated from RefreshItemList (extracted for batching)
    for i = startIndex, endIndex do
        local itemData = self.pendingBatchData[i]

        -- Logic block: Calculate Category (Required for Sort)
        local bestCategoryDesc = itemData.cachedBestCategoryDesc
        if not bestCategoryDesc then
            bestCategoryDesc = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
            itemData.cachedBestCategoryDesc = bestCategoryDesc
        end

        -- Logic block: AutoCategory
        if AutoCategory and AutoCategory.Inited then
            local customCategory, matched, catName, catPriority = BETTERUI.GetCustomCategory(itemData)
            if customCategory and not matched then
                itemData.bestItemTypeName = bestCategoryDesc
                itemData.bestItemCategoryName = AC_UNGROUPED_NAME
                itemData.sortPriorityName = string.format("%03d%s", 999, catName)
            elseif customCategory then
                itemData.bestItemTypeName = bestCategoryDesc
                itemData.bestItemCategoryName = catName
                itemData.sortPriorityName = string.format("%03d%s", 100 - catPriority, catName)
            else
                itemData.bestItemTypeName = bestCategoryDesc
                itemData.bestItemCategoryName = bestCategoryDesc
                itemData.sortPriorityName = bestCategoryDesc
            end
        else
            itemData.bestItemTypeName = bestCategoryDesc
            itemData.bestItemCategoryName = bestCategoryDesc
            itemData.sortPriorityName = bestCategoryDesc
        end

        -- Logic block: Equipped Status
        if itemData.bagId == BAG_WORN then
            itemData.isEquippedInCurrentCategory = (itemData.slotIndex == filteredEquipSlot)
            itemData.isEquippedInAnotherCategory = (itemData.slotIndex ~= filteredEquipSlot)
            itemData.isHiddenByWardrobe = WouldEquipmentBeHidden(itemData.slotIndex or EQUIP_SLOT_NONE,
                GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        else
            local slotIndex = FindActionSlotMatchingItem(itemData.bagId, itemData.slotIndex,
                HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            itemData.isEquippedInCurrentCategory = slotIndex and true or nil
        end

        if isQuestItem then
            ZO_InventorySlot_SetType(itemData, SLOT_TYPE_QUEST_ITEM)
        else
            ZO_InventorySlot_SetType(itemData, SLOT_TYPE_GAMEPAD_INVENTORY_ITEM)
        end

        if itemData.itemType == ITEMTYPE_BOOK or itemData.itemType == ITEMTYPE_LOREBOOK then
            itemData.cached_isBook = true
        end

        -- Create Entry using shared CIM factory
        local data = BETTERUI.CIM.CreateItemEntryData(itemData, {
            isQuestItem = isQuestItem,
            visualDataInit = BETTERUI.Inventory.Class.InitializeInventoryVisualData
        })

        if data then
            if (not data.isJunk and not showJunkCategory) or (data.isJunk and showJunkCategory) then
                self.pendingContext.currentBestCategoryName = BETTERUI.CIM.AddItemEntryToList(
                    self.itemList,
                    data,
                    self.pendingContext.currentBestCategoryName,
                    AutoCategory ~= nil
                )
            end
        end
    end

    self.pendingBatchIndex = endIndex + 1

    -- Schedule next batch
    if self.pendingBatchIndex <= totalItems then
        -- Batch processing: yield to allow frame render, preventing UI freeze
        self.batchCallId = BETTERUI.Inventory.Tasks:Schedule("batchProcess", 10,
            function() self:ProcessScrollListBatch() end)
    else
        -- Final batch complete - commit once with proper selection restoration
        -- Use dontReselect=true to prevent default reselection, then restore manually
        self.itemList:Commit(true)

        -- Restore selection if we have a target uniqueId
        local restored = false
        if targetUniqueId then
            -- Manual lookup to find index, then use SetSelectedIndexWithoutAnimation for instant focus
            local dataList = self.itemList.dataList or (self.itemList.list and self.itemList.list.dataList)
            if dataList then
                for i, data in ipairs(dataList) do
                    if data.uniqueId and Id64ToString(data.uniqueId) == targetUniqueId then
                        self.itemList:SetSelectedIndexWithoutAnimation(i, true, false)
                        restored = true
                        break
                    end
                end
            end
        end

        -- Fallback: if uniqueId restoration failed (item consumed/removed), use index position
        if not restored and self.pendingContext.targetIndex then
            local dataList = self.itemList.dataList or (self.itemList.list and self.itemList.list.dataList)
            if dataList and #dataList > 0 then
                -- Clamp to valid range (in case list shrank)
                local targetIdx = math.min(self.pendingContext.targetIndex, #dataList)
                targetIdx = math.max(1, targetIdx)
                -- Use WithoutAnimation for instant focus (matches Banking behavior)
                self.itemList:SetSelectedIndexWithoutAnimation(targetIdx, true, false)
            end
        end

        self.pendingBatchData = nil
        self.pendingContext = nil
    end
end

--- Refreshes the item list based on the selected category and filter.
function BETTERUI.Inventory.Class:RefreshItemList()
    -- Capture current selection before clearing (uniqueId primary, index fallback)
    local targetUniqueId = nil
    local targetIndex = nil
    if self.currentlySelectedData then
        -- Use saved uniqueId if available
        if self.currentlySelectedData.uniqueId then
            targetUniqueId = Id64ToString(self.currentlySelectedData.uniqueId)
        end
        -- Use saved index from ToSavedPosition (per-category) if available
        -- This is the correct per-category index, not the previous category's index
        if self.currentlySelectedData.savedIndex then
            targetIndex = self.currentlySelectedData.savedIndex
        end
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
        local comparator = GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)

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

    local sortFunc = BETTERUI.Inventory.DefaultSortComparator

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

    -- LARGE LIST: Process first batch synchronously, then defer the rest
    -- Partial sort? No, sort raw data first so top items appear first

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
    if tooltip and not tooltip._betterui_itemLink and selectedData.bagId then
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
