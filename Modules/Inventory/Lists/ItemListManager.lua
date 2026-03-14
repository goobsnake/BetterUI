--[[
File: Modules/Inventory/Lists/ItemListManager.lua
Purpose: Manages the main inventory item list setup, counts, and batch rendering.
Author: BetterUI Team
Last Modified: 2026-03-14
]]

-- Localize frequently used globals
local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
local zo_strformat = zo_strformat
local GetBestItemCategoryDescription = BETTERUI.Inventory.Categories.GetBestItemCategoryDescription
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

            -- Keybind Refresh - protected by RefreshKeybinds() override
            self:RefreshKeybinds()

            -- Update scroll indicator position
            -- Use targetSelectedIndex (the intended final position) rather than GetSelectedIndex()
            -- (the animated intermediate) to prevent the thumb from stopping short of the bottom
            local listCtrl = self.itemList and self.itemList.control
            if listCtrl and BETTERUI.CIM.ScrollIndicator then
                local currentIndex = list.targetSelectedIndex or list:GetSelectedIndex() or 1
                local totalItems = (list.GetNumItems and list:GetNumItems()) or (list.dataList and #list.dataList) or 0
                local visibleItems = 12 -- Approximate visible items
                BETTERUI.CIM.ScrollIndicator.Update(listCtrl, currentIndex, totalItems, visibleItems)
            end
        end
    end)

    self.itemList.maxOffset = 30
    self.itemList:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * 0.75, GAMEPAD_HEADER_SELECTED_PADDING * 0.75)
    self.itemList:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * 0.75)

    -- Move selected item position up to align with tooltip arrow
    -- Negative values move the focus point upward from center
    self.itemList:SetFixedCenterOffset(-50)

    -- NOTE: Removed SetOnHitBeginningOfListCallback for header sort mode.
    -- Header sort mode is now entered ONLY via Y Hold keybind.
    -- D-pad Up at top of list should focus the search box, not enter header mode.
    -- See keybind UI_SHORTCUT_QUINARY in InventoryKeybinds.lua for Y Hold entry point.

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

    -- Initialize scroll indicator for main item list
    -- offsetX=5, offsetTopY=-8 (above list top), offsetBottomY=-10 (above footer top)
    -- Note: List BOTTOMRIGHT is anchored 10px below FooterContainerFooter's top,
    -- so offsetBottomY=-10 aligns the container bottom with the footer's top edge.
    if listControl and BETTERUI.CIM.ScrollIndicator then
        BETTERUI.CIM.ScrollIndicator.Initialize(listControl, 5, -8, -10, self.itemList)
    end
end

--- Checks if the item list would be empty for the current filter.
function BETTERUI.Inventory.Class:IsItemListEmpty(filteredEquipSlot, nonEquipableFilterType)
    local baseComparator = self:GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)

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
--- @param nonEquipableFilterType number|nil The item filter type (nil = All)
--- @return number count The number of matching items
function BETTERUI.Inventory.Class:GetCategoryItemCount(nonEquipableFilterType)
    local baseComparator = self:GetItemDataFilterComparator(nil, nonEquipableFilterType)
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
--- @return number count The number of junk items
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
            -- Note: uniqueId may be on data.dataSource (wrapper) or data directly
            local dataList = self.itemList.dataList or (self.itemList.list and self.itemList.list.dataList)
            if dataList then
                for i, data in ipairs(dataList) do
                    local itemUniqueId = (data.dataSource and data.dataSource.uniqueId) or data.uniqueId
                    if itemUniqueId and Id64ToString(itemUniqueId) == targetUniqueId then
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
