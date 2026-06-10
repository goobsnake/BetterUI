--[[
File: Modules/Inventory/Lists/ItemListManager.lua
Purpose: Manages the main item list (Backpack) for the Inventory module.
         Contains list initialization, category metadata preparation, and batched row assembly.
]]

-- Localize frequently used globals
local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
local zo_strformat = zo_strformat
local GetBestItemCategoryDescription = BETTERUI.CIM.SharedItemSupport.GetBestItemCategoryDescription
local WouldEquipmentBeHidden = WouldEquipmentBeHidden
local FindActionSlotMatchingItem = FindActionSlotMatchingItem
local INVENTORY_LIST_MODULE_NAME = "Inventory"
local NormalizeIdentityValue = BETTERUI.Inventory.Utils and BETTERUI.Inventory.Utils.NormalizeIdentityValue

--- @param left {uniqueId: userdata}
--- @param right {uniqueId: userdata}
--- @return boolean
local function MenuEntryTemplateEquality(left, right)
    -- Convert to string to ensure consistent comparison even if userdata instances differ.
    local leftId = left and left.uniqueId and NormalizeIdentityValue(left.uniqueId)
    local rightId = right and right.uniqueId and NormalizeIdentityValue(right.uniqueId)
    return leftId ~= nil and leftId == rightId
end

--- @param list table Scroll list instance
local function SetupItemList(list)
    -- Short controlPoolPrefix keeps generated pooled-control names (parent scroll
    -- + prefix + index + child suffixes) under the engine's max control-name length.
    list:AddDataTemplate(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEntryTemplateEquality,
        "BUI_ItemRow"
    )
    list:AddDataTemplateWithHeader(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEntryTemplateEquality,
        "ZO_GamepadMenuEntryHeaderTemplate",
        nil,
        "BUI_ItemRow"
    )
end

--- @param filteredEquipSlot number|nil
--- @param nonEquipableFilterType number|nil ITEMFILTERTYPE_* constant
--- @return fun(itemData: table): boolean
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
---@return nil
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

            -- Keybind Refresh - protected by RefreshKeybinds() override.
            -- Let the override handle transition windows so settled reselection
            -- can update the A-button in the same frame.
            self:RefreshKeybinds()

            -- Update scroll indicator position
            -- Use targetSelectedIndex (the intended final position) rather than GetSelectedIndex()
            -- (the animated intermediate) to prevent the thumb from stopping short of the bottom
            local listCtrl = self.itemList and self.itemList.control
            if listCtrl and BETTERUI.CIM.ScrollIndicator then
                BETTERUI.CIM.ScrollIndicator.Update(listCtrl)
            end
        end
    end)

    self.itemList.maxOffset = 30
    self.itemList:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * 0.75, GAMEPAD_HEADER_SELECTED_PADDING * 0.75)
    self.itemList:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * 0.75)

    -- Move selected item position up to align with tooltip arrow
    -- Negative values move the focus point upward from center
    self.itemList:SetFixedCenterOffset(-50)

    local emptyText = GetString(rawget(_G, "SI_BETTERUI_EMPTY_LIST"))
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

    -- Initialize scroll indicator for main item list
    -- offsetX=5, offsetTopY=-8 (above list top), offsetBottomY=-10 (above footer top)
    -- Note: List BOTTOMRIGHT is anchored 10px below FooterContainerFooter's top,
    -- so offsetBottomY=-10 aligns the container bottom with the footer's top edge.
    if listControl and BETTERUI.CIM.ScrollIndicator then
        BETTERUI.CIM.ScrollIndicator.Setup(listControl, {
            listObject = self.itemList,
            offsetX = 5,
            offsetTopY = -8,
            offsetBottomY = -10,
            visibleItems = 12,
        })
    end
end

--- Checks if the item list would be empty for the current filter.
--- @param filteredEquipSlot number|nil
--- @param nonEquipableFilterType number|nil
--- @return boolean
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

--- Counts items matching a filter type for category badge display.
--- @param nonEquipableFilterType number|nil ITEMFILTERTYPE_* constant
--- @return number count
function BETTERUI.Inventory.Class:GetCategoryItemCount(nonEquipableFilterType)
    local baseComparator = GetItemDataFilterComparator(nil, nonEquipableFilterType)
    local count = 0

    -- Count worn items
    local worn = self:GetCachedSlotData(BAG_WORN)
    if worn then
        for _, itemData in ipairs(worn) do
            if baseComparator(itemData) and not itemData.isJunk then
                count = count + 1
            end
        end
    end

    -- Count backpack items
    local backpack = self:GetCachedSlotData(BAG_BACKPACK)
    if backpack then
        for _, itemData in ipairs(backpack) do
            if baseComparator(itemData) and not itemData.isJunk then
                count = count + 1
            end
        end
    end

    return count
end

--- Checks for any junk items in the backpack.
--- @return boolean
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

--- Counts junk items in the backpack for category badge display.
function BETTERUI.Inventory.Class:CountJunkInBackpack()
    local count = 0
    -- Prefer shared inventory cache
    local backpack = self:GetCachedSlotData(BAG_BACKPACK)
    if backpack then
        for _, slotData in ipairs(backpack) do
            if slotData and slotData.isJunk == true then
                count = count + 1
            end
        end
    end

    -- Fallback if cache unavailable
    if count == 0 then
        local size = GetBagSize(BAG_BACKPACK) or 0
        for slotIndex = 0, size - 1 do
            if IsItemJunk(BAG_BACKPACK, slotIndex) then
                count = count + 1
            end
        end
    end
    return count
end

--- Sets up visual data (name, icon, coloring) for an inventory row.
function BETTERUI.Inventory.Class:InitializeInventoryVisualData(itemData)
    BETTERUI.CIM.InitializeSharedItemVisualData(self, itemData)
end

--- Populates the canonical category and sort metadata used by inventory rows.
---@param itemData table
---@return nil
function BETTERUI.Inventory.Class:PopulateInventoryCategoryFields(itemData)
    local bestCategoryDesc = itemData.cachedBestCategoryDesc
    if not bestCategoryDesc then
        bestCategoryDesc = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
        itemData.cachedBestCategoryDesc = bestCategoryDesc
    end

    local categoryName = bestCategoryDesc
    local sortPriorityName = bestCategoryDesc
    local optionalAddons = BETTERUI.CIM and BETTERUI.CIM.OptionalAddons
    if optionalAddons and optionalAddons.IsLoaded and optionalAddons.IsLoaded("AutoCategory") then
        local customCategory, matched, catName, catPriority = BETTERUI.CIM.AutoCategoryIntegration.GetCustomCategory(itemData)
        if customCategory and not matched then
            categoryName = AC_UNGROUPED_NAME
            sortPriorityName = string.format("%03d%s", 999, catName)
        elseif customCategory then
            categoryName = catName
            sortPriorityName = string.format("%03d%s", 100 - catPriority, catName)
        end
    end

    itemData.bestItemTypeName = bestCategoryDesc
    itemData.bestItemCategoryName = categoryName
    itemData.bestGamepadItemCategoryName = categoryName
    itemData.itemCategoryName = categoryName
    itemData.sortPriorityName = sortPriorityName
    itemData.listModuleName = INVENTORY_LIST_MODULE_NAME
end

--- Applies per-refresh list state to an inventory row before entry creation.
---@param itemData table
---@param filteredEquipSlot number|nil
---@param isQuestItem boolean
---@return nil
function BETTERUI.Inventory.Class:PrepareInventoryListEntry(itemData, filteredEquipSlot, isQuestItem)
    if isQuestItem then
        self:PrepareQuestItemListEntry(itemData)
        return
    end

    self:PopulateInventoryCategoryFields(itemData)

    if itemData.bagId == BAG_WORN then
        itemData.isEquippedInCurrentCategory = (itemData.slotIndex == filteredEquipSlot)
        itemData.isEquippedInAnotherCategory = (itemData.slotIndex ~= filteredEquipSlot)
        itemData.isHiddenByWardrobe = WouldEquipmentBeHidden(itemData.slotIndex or EQUIP_SLOT_NONE,
            GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    else
        local slotIndex = FindActionSlotMatchingItem(itemData.bagId, itemData.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
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
end

--- Captures the preferred selection target before rebuilding the item list.
---@return string|nil targetUniqueId
---@return number|nil targetIndex
function BETTERUI.Inventory.Class:CaptureItemListRefreshTarget()
    local targetUniqueId = nil
    local targetIndex = nil
    local hadActionPreserveContext = (self._splitStackUniqueId ~= nil) or (self._preserveUniqueId ~= nil)
        or (self._preserveIndex ~= nil)
    local preservedIndex = self._preserveIndex

    if self._splitStackUniqueId then
        targetUniqueId = NormalizeIdentityValue(self._splitStackUniqueId)
        self._splitStackUniqueId = nil
    elseif self._preserveUniqueId then
        targetUniqueId = NormalizeIdentityValue(self._preserveUniqueId)
        self._preserveUniqueId = nil
    elseif self.currentlySelectedData then
        if self.currentlySelectedData.uniqueId then
            targetUniqueId = NormalizeIdentityValue(self.currentlySelectedData.uniqueId)
        end
        if self.currentlySelectedData.savedIndex then
            targetIndex = self.currentlySelectedData.savedIndex
        end
    end

    if preservedIndex and hadActionPreserveContext then
        targetIndex = preservedIndex
    end

    if not targetIndex and not hadActionPreserveContext and not self._categorySwitchInProgress
        and self.itemList:GetSelectedIndex()
    then
        targetIndex = self.itemList:GetSelectedIndex()
    end

    self._preserveIndex = nil
    return targetUniqueId, targetIndex
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
        -- Commit is needed even with zero items so SetNoItemText can display
        self.itemList:Commit()
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
    local targetUniqueId = self.pendingContext.targetUniqueId

    -- Loop logic duplicated from RefreshItemList (extracted for batching)
    for i = startIndex, endIndex do
        local itemData = self.pendingBatchData[i]
        self:PrepareInventoryListEntry(itemData, filteredEquipSlot, isQuestItem)

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
                    BETTERUI.CIM.OptionalAddons and BETTERUI.CIM.OptionalAddons.IsLoaded("AutoCategory")
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
            -- Note: uniqueId may be on data.dataSource (wrapper) or data directly
            local dataList = self.itemList.dataList or (self.itemList.list and self.itemList.list.dataList)
            if dataList then
                for i, data in ipairs(dataList) do
                    local itemUniqueId = (data.dataSource and data.dataSource.uniqueId) or data.uniqueId
                    if itemUniqueId and NormalizeIdentityValue(itemUniqueId) == targetUniqueId then
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
