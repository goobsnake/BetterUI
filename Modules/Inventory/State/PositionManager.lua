--[[
File: Modules/Inventory/State/PositionManager.lua
Purpose: Manages the persistence of inventory list positions and selection states.
         Ensures users return to the same item when switching tabs or categories.
Author: BetterUI Team
Last Modified: 2026-01-24
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
]]
function BETTERUI.Inventory.ToSavedPosition(self)
    -- Determine if we're on inventory or craft bag based on current category
    local catData = self.categoryList and self.categoryList.selectedData
    if not catData then return end

    local isCraftBag = catData.onClickDirection ~= nil
    local currentList = isCraftBag and self.craftBagList or self.itemList

    -- Set current list and refresh for the current category
    if isCraftBag then
        self:SetCurrentList(self.craftBagList)
        self:RefreshCraftBagList()
    else
        self:SetCurrentList(self.itemList)
        self:RefreshItemList()
    end

    -- Get category key for position lookup
    local key = BETTERUI.Inventory.GetCategoryKey(catData)
    local lastPosition = 1

    if isCraftBag then
        -- Restore craft bag item position for this category ONLY if previously saved
        if key and self.savedCraftBagPositionsByKey and self.savedCraftBagPositionsByKey[key] then
            lastPosition = self.savedCraftBagPositionsByKey[key]
            -- Prefer unique id restore if available
            if self.savedCraftBagSelectedItemUniqueByKey and self.savedCraftBagSelectedItemUniqueByKey[key] then
                local uid = self.savedCraftBagSelectedItemUniqueByKey[key]
                local dataList = self.craftBagList.list and self.craftBagList.list.dataList or self.craftBagList
                .dataList
                if dataList then
                    for i, entry in ipairs(dataList) do
                        if entry and entry.uniqueId == uid then
                            lastPosition = i
                            break
                        end
                    end
                end
            end
        end
    else
        -- Restore inventory item position for this category ONLY if previously saved
        if key and self.savedInventoryPositionsByKey and self.savedInventoryPositionsByKey[key] then
            lastPosition = self.savedInventoryPositionsByKey[key]
            -- Prefer unique id restore if available
            if self.savedInventorySelectedItemUniqueByKey and self.savedInventorySelectedItemUniqueByKey[key] then
                local uid = self.savedInventorySelectedItemUniqueByKey[key]
                local dataList = self.itemList.list and self.itemList.list.dataList or self.itemList.dataList
                if dataList then
                    for i, entry in ipairs(dataList) do
                        if entry and entry.uniqueId == uid then
                            lastPosition = i
                            break
                        end
                    end
                end
            end
        end
    end

    -- Apply the position to the current list
    local dataList = currentList.list and currentList.list.dataList or currentList.dataList
    if dataList and #dataList > 0 then
        lastPosition = zo_clamp(lastPosition, 1, #dataList)
        -- Use inner list for SetSelectedIndexWithoutAnimation if available (craftBagList wraps inner list)
        local innerList = currentList.list or currentList
        if innerList.SetSelectedIndexWithoutAnimation then
            innerList:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
        end

        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        if self.callLaterLeftToolTip then
            EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
        end
        local callLaterId = zo_callLater(function()
            -- Provide safe access to UpdateItemLeftTooltip for when it's still in the main file
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
