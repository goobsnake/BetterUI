--[[
File: Modules/Inventory/State/PositionManager.lua
Purpose: Manages the persistence of inventory list positions and selection states.
         Delegates core logic to BETTERUI.CIM.PositionManager for shared behavior.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

if not BETTERUI.Inventory.State then BETTERUI.Inventory.State = {} end

-- Module identifier for CIM PositionManager
local MODULE_NAME = "Inventory"

--[[
Function: GetCategoryKey
Description: Generates a stable string key for a category entry.
Rationale: Delegates to CIM.PositionManager for consistent key generation.
]]
function BETTERUI.Inventory.GetCategoryKey(categoryData)
    return BETTERUI.CIM.PositionManager.GetCategoryKey(categoryData)
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
Mechanism: Uses CIM.PositionManager to retrieve saved uniqueId/index,
           sets currentlySelectedData before RefreshItemList so batch
           processing restores to the correct position.
]]
function BETTERUI.Inventory.ToSavedPosition(self)
    -- Determine if we're on inventory or craft bag based on current category
    local catData = self.categoryList and self.categoryList.selectedData
    if not catData then return end

    local isCraftBag = catData.onClickDirection ~= nil
    local currentList = isCraftBag and self.craftBagList or self.itemList
    local subModule = isCraftBag and "CraftBag" or "Items"

    -- Get category key for position lookup
    local key = BETTERUI.CIM.PositionManager.GetCategoryKey(catData)

    -- Retrieve saved position from CIM PositionManager
    local saved = BETTERUI.CIM.PositionManager.GetSavedPosition(MODULE_NAME .. "_" .. subModule, key)

    -- Set currentlySelectedData so RefreshItemList uses it
    if saved and saved.uniqueId then
        self.currentlySelectedData = { uniqueId = saved.uniqueId, savedIndex = saved.index }
    elseif saved and saved.index then
        self.currentlySelectedData = { savedIndex = saved.index }
    else
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
    local dataList = currentList.list and currentList.list.dataList or currentList.dataList
    if dataList and #dataList > 0 and not self.pendingBatchData then
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
Mechanism: Delegates to CIM.PositionManager for storage.
]]
function BETTERUI.Inventory.SaveListPosition(self)
    -- Guard against nil state
    if not self.categoryList or not self.categoryList.selectedData then return end

    local catData = self.categoryList.selectedData
    local key = BETTERUI.CIM.PositionManager.GetCategoryKey(catData)
    if not key then return end

    local isCraftBag = catData.onClickDirection ~= nil
    local subModule = isCraftBag and "CraftBag" or "Items"

    -- Get the correct list
    local currentList = isCraftBag and self.craftBagList or self.itemList

    -- Save position using CIM PositionManager
    BETTERUI.CIM.PositionManager.SavePosition(MODULE_NAME .. "_" .. subModule, key, currentList)
end

-- Register mixins for Core to pick up
BETTERUI.Inventory.RegisterMixin("ToSavedPosition", BETTERUI.Inventory.ToSavedPosition)
BETTERUI.Inventory.RegisterMixin("SaveListPosition", BETTERUI.Inventory.SaveListPosition)
