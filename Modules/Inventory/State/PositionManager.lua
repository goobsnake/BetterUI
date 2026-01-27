--[[
File: Modules/Inventory/State/PositionManager.lua
Purpose: Manages the persistence of inventory list positions and selection states.
         Ensures users return to the same item when switching tabs or categories.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

if not BETTERUI.Inventory.State then BETTERUI.Inventory.State = {} end

--[[
Function: GetCategoryKey
Description: Generates a stable string key for a category entry.
used for saving/restoring selection state per category.
]]
function BETTERUI.Inventory.GetCategoryKey(categoryData)
    if not categoryData then return nil end
    if categoryData.filterType ~= nil then
        return "f:" .. tostring(categoryData.filterType)
    end
    if categoryData.onClickDirection then
        return "dir:" .. tostring(categoryData.onClickDirection)
    end
    if categoryData.text then
        return "t:" .. tostring(categoryData.text)
    end
    return "idx:" .. tostring(categoryData.index or "")
end

--[[
Function: FindCategoryIndexByKey
Description: Finds the index of a category in the list by its unique key.
]]
function BETTERUI.Inventory.FindCategoryIndexByKey(self, key)
    if not key or not self.categoryList or not self.categoryList.dataList then return nil end
    for i, d in ipairs(self.categoryList.dataList) do
        if BETTERUI.Inventory.GetCategoryKey(d) == key then
            return i
        end
    end
    return nil
end

--[[
Function: ToSavedPosition
Description: Restores the list position and selection from saved state.
Mechanism: Retrieves the saved uniqueId for the target category FIRST,
           then sets self.currentlySelectedData before calling RefreshItemList
           so that batch processing will restore to the correct position.
]]
function BETTERUI.Inventory.ToSavedPosition(self)
    -- Determine if we're on inventory or craft bag based on current category
    local catData = self.categoryList and self.categoryList.selectedData
    if not catData then return end

    local isCraftBag = catData.onClickDirection ~= nil
    local currentList = isCraftBag and self.craftBagList or self.itemList

    -- Get category key for position lookup
    local key = BETTERUI.Inventory.GetCategoryKey(catData)
    local savedUniqueId = nil

    -- Retrieve the saved uniqueId for this category BEFORE calling refresh
    -- This ensures RefreshItemList's batch processing restores to the correct item
    if isCraftBag then
        if key and self.savedCraftBagSelectedItemUniqueByKey and self.savedCraftBagSelectedItemUniqueByKey[key] then
            savedUniqueId = self.savedCraftBagSelectedItemUniqueByKey[key]
        end
    else
        if key and self.savedInventorySelectedItemUniqueByKey and self.savedInventorySelectedItemUniqueByKey[key] then
            savedUniqueId = self.savedInventorySelectedItemUniqueByKey[key]
        end
    end

    -- Set currentlySelectedData to the saved uniqueId so RefreshItemList uses it
    -- This prevents batch processing from restoring to the wrong item (the item
    -- that was selected in the PREVIOUS category but also exists in the new one)
    if savedUniqueId then
        self.currentlySelectedData = { uniqueId = savedUniqueId }
    else
        -- No saved position for this category - clear to prevent wrong restoration
        self.currentlySelectedData = nil
    end

    -- Set current list and refresh for the current category
    if isCraftBag then
        self:SetCurrentList(self.craftBagList)
        self:RefreshCraftBagList()
    else
        self:SetCurrentList(self.itemList)
        self:RefreshItemList()
    end

    -- For small lists that process synchronously, apply fallback position restoration
    -- (Large lists with batch processing will restore in ProcessScrollListBatch)
    local dataList = currentList.list and currentList.list.dataList or currentList.dataList
    if dataList and #dataList > 0 and not self.pendingBatchData then
        -- List was processed synchronously (small list) - position was already restored
        -- by RefreshItemList via batch processing. Just update tooltip.
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        if self.callLaterLeftToolTip then
            EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
        end
        local callLaterId = zo_callLater(function()
            if self.UpdateItemLeftTooltip then
                self:UpdateItemLeftTooltip(currentList.selectedData)
            end
        end, BETTERUI.CONST.INVENTORY.TOOLTIP_REFRESH_DELAY_MS)
        self.callLaterLeftToolTip = "CallLaterFunction" .. callLaterId
    end
end

--[[
Function: SaveListPosition
Description: Saves the current list position and selection.
]]
function BETTERUI.Inventory.SaveListPosition(self)
    -- Guard against nil state
    if not self.categoryList or not self.categoryList.selectedData then return end

    local catData = self.categoryList.selectedData
    local key = BETTERUI.Inventory.GetCategoryKey(catData)
    if not key then return end

    local isCraftBag = catData.onClickDirection ~= nil

    -- Get the correct list and its inner list (craftBagList wraps an inner list)
    local currentList = isCraftBag and self.craftBagList or self.itemList
    local innerList = currentList and (currentList.list or currentList)

    if not innerList or not innerList.selectedIndex then return end

    local itemIndex = innerList.selectedIndex or 1
    local itemUniqueId = innerList.selectedData and innerList.selectedData.uniqueId

    if isCraftBag then
        -- Save craft bag state (completely independent from inventory)
        self.savedCraftBagCategoryKey = key
        self.savedCraftBagPositionsByKey = self.savedCraftBagPositionsByKey or {}
        self.savedCraftBagPositionsByKey[key] = itemIndex
        if itemUniqueId then
            self.savedCraftBagSelectedItemUniqueByKey = self.savedCraftBagSelectedItemUniqueByKey or {}
            self.savedCraftBagSelectedItemUniqueByKey[key] = itemUniqueId
        end
    else
        -- Save inventory state (completely independent from craft bag)
        self.savedInventoryCategoryKey = key
        self.savedInventoryPositionsByKey = self.savedInventoryPositionsByKey or {}
        self.savedInventoryPositionsByKey[key] = itemIndex
        if itemUniqueId then
            self.savedInventorySelectedItemUniqueByKey = self.savedInventorySelectedItemUniqueByKey or {}
            self.savedInventorySelectedItemUniqueByKey[key] = itemUniqueId
        end
    end
end

-- Register mixins for Core to pick up
BETTERUI.Inventory.RegisterMixin("ToSavedPosition", BETTERUI.Inventory.ToSavedPosition)
BETTERUI.Inventory.RegisterMixin("SaveListPosition", BETTERUI.Inventory.SaveListPosition)
