--[[
File: Modules/Inventory/State/PositionManager.lua
Purpose: Manages the persistence of inventory list positions and selection states.
         Delegates core logic to BETTERUI.CIM.PositionManager for shared behavior.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

if not BETTERUI.Inventory.State then BETTERUI.Inventory.State = {} end

-- Module identifier constants from CIM
local MODULES = BETTERUI.CIM.CONST.MODULES

--[[
Function: GetCategoryKey
Generates a stable string key for a category entry.
]]
--- Generates a stable string key for a category entry.
--- @param categoryData table The category data
--- @return string key The category key
function BETTERUI.Inventory.GetCategoryKey(categoryData)
    return BETTERUI.CIM.PositionManager.GetCategoryKey(categoryData)
end

--[[
Function: FindCategoryIndexByKey
Finds the index of a category in the list by its unique key.
]]
--- Finds the index of a category in the list by its unique key.
--- @param self table The Inventory class instance
--- @param key string The category key to find
--- @return number|nil index The index of the category, or nil if not found
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
Restores the list position and selection from saved state.
Uses CIM.PositionManager to retrieve saved uniqueId/index,
sets currentlySelectedData before RefreshItemList so batch
processing restores to the correct position.
]]
--- Restores the list position and selection from saved state.
--- @param self table The Inventory class instance
function BETTERUI.Inventory.ToSavedPosition(self)
    -- Determine if we're on inventory or craft bag based on current category
    local catData = self.categoryList and self.categoryList.selectedData
    if not catData then return end

    local isCraftBag = catData.onClickDirection ~= nil
    local currentList = isCraftBag and self.craftBagList or self.itemList
    local subModuleKey = isCraftBag and MODULES.INVENTORY_CRAFTBAG or MODULES.INVENTORY_ITEMS

    -- Get category key for position lookup
    local key = BETTERUI.CIM.PositionManager.GetCategoryKey(catData)

    -- Retrieve saved position from CIM PositionManager
    local saved = BETTERUI.CIM.PositionManager.GetSavedPosition(subModuleKey, key)

    -- Set currentlySelectedData so RefreshItemList uses it
    if saved and saved.uniqueId then
        self.currentlySelectedData = { uniqueId = saved.uniqueId, savedIndex = saved.index }
    elseif saved and saved.index then
        self.currentlySelectedData = { savedIndex = saved.index }
    else
        self.currentlySelectedData = nil
    end

    -- Flag category switch so RefreshItemList skips stale-index fallback
    -- (prevents old category's scroll position bleeding into new category)
    self._categorySwitchInProgress = true

    -- Set current list and refresh for the current category
    if isCraftBag then
        self:SetCurrentList(self.craftBagList)
        self:RefreshCraftBagList()
    else
        self:SetCurrentList(self.itemList)
        self:RefreshItemList()
    end

    self._categorySwitchInProgress = false

    -- Craft bag position restoration: CraftList:RefreshList has no internal position
    -- restoration (unlike RefreshItemList which reads currentlySelectedData). Apply the
    -- saved position explicitly after refresh, matching ProcessScrollListBatch's pattern.
    if isCraftBag and currentList then
        local innerList = currentList.list or currentList
        local craftDataList = innerList.dataList
        if craftDataList and #craftDataList > 0 then
            local restored = false
            if saved and saved.uniqueId then
                for i, data in ipairs(craftDataList) do
                    local uid = (data.dataSource and data.dataSource.uniqueId) or data.uniqueId
                    if uid and Id64ToString(uid) == Id64ToString(saved.uniqueId) then
                        innerList:SetSelectedIndexWithoutAnimation(i, true, false)
                        restored = true
                        break
                    end
                end
            end
            if not restored and saved and saved.index then
                local targetIdx = math.min(saved.index, #craftDataList)
                targetIdx = math.max(1, targetIdx)
                innerList:SetSelectedIndexWithoutAnimation(targetIdx, true, false)
            elseif not restored then
                -- No saved position: reset to top (prevent stale index bleed)
                innerList:SetSelectedIndexWithoutAnimation(1, true, false)
            end
        end
    end

    -- For small lists that process synchronously, apply fallback position restoration
    local dataList = currentList.list and currentList.list.dataList or currentList.dataList
    if dataList and #dataList > 0 and not self.pendingBatchData then
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        if self.callLaterLeftToolTip then
            EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
        end
        BETTERUI.Inventory.Tasks:Schedule("tooltipRefresh", BETTERUI.Inventory.CONST.TOOLTIP_REFRESH_DELAY_MS, function()
            if self.UpdateItemLeftTooltip then
                self:UpdateItemLeftTooltip(currentList.selectedData)
            end
        end)
        self.callLaterLeftToolTip = "InventoryTooltipRefresh"
    end
end

--[[
Function: SaveListPosition
Saves the current list position and selection.
]]
--- Saves the current list position and selection.
--- @param self table The Inventory class instance
function BETTERUI.Inventory.SaveListPosition(self)
    -- Guard against nil state
    if not self.categoryList or not self.categoryList.selectedData then return end

    local catData = self.categoryList.selectedData
    local key = BETTERUI.CIM.PositionManager.GetCategoryKey(catData)
    if not key then return end

    local isCraftBag = catData.onClickDirection ~= nil
    local subModuleKey = isCraftBag and MODULES.INVENTORY_CRAFTBAG or MODULES.INVENTORY_ITEMS

    -- Get the correct list
    local currentList = isCraftBag and self.craftBagList or self.itemList

    -- Save position using CIM PositionManager
    BETTERUI.CIM.PositionManager.SavePosition(subModuleKey, key, currentList)

    -- Also update the fields that SwitchActiveList reads for restoration
    if isCraftBag then
        self.savedCraftBagCategoryKey = key
        self.savedCraftBagCategoryIndex = self.categoryList.selectedIndex
        if currentList then
            local selectedIndex = currentList.selectedIndex
                or (currentList.list and currentList.list.selectedIndex)
            if selectedIndex then
                self.savedCraftBagPositionsByKey = self.savedCraftBagPositionsByKey or {}
                self.savedCraftBagPositionsByKey[key] = selectedIndex
            end
            -- Save uniqueId for precise item restoration
            local selectedData = currentList.selectedData
                or (currentList.list and currentList.list.selectedData)
            if selectedData then
                local uid = (selectedData.dataSource and selectedData.dataSource.uniqueId)
                    or selectedData.uniqueId
                if uid then
                    self.savedCraftBagSelectedItemUniqueByKey = self.savedCraftBagSelectedItemUniqueByKey or {}
                    self.savedCraftBagSelectedItemUniqueByKey[key] = uid
                end
            end
        end
    else
        self.savedInventoryCategoryKey = key
        self.savedInventoryCategoryIndex = self.categoryList.selectedIndex
        if currentList then
            local selectedIndex = currentList.selectedIndex
                or (currentList.list and currentList.list.selectedIndex)
            if selectedIndex then
                self.savedInventoryPositionsByKey = self.savedInventoryPositionsByKey or {}
                self.savedInventoryPositionsByKey[key] = selectedIndex
            end
            -- Save uniqueId for precise item restoration
            local selectedData = currentList.selectedData
                or (currentList.list and currentList.list.selectedData)
            if selectedData then
                local uid = (selectedData.dataSource and selectedData.dataSource.uniqueId)
                    or selectedData.uniqueId
                if uid then
                    self.savedInventorySelectedItemUniqueByKey = self.savedInventorySelectedItemUniqueByKey or {}
                    self.savedInventorySelectedItemUniqueByKey[key] = uid
                end
            end
        end
    end
end

-- Register mixins for Core to pick up
BETTERUI.Inventory.RegisterMixin("ToSavedPosition", BETTERUI.Inventory.ToSavedPosition)
BETTERUI.Inventory.RegisterMixin("SaveListPosition", BETTERUI.Inventory.SaveListPosition)
