--[[
File: Modules/CIM/Lists/ItemDataProcessor.lua
Purpose: Shared factory for creating item entry data for inventory/banking lists.
         Eliminates duplicate entry creation code between modules.
]]

-- ITEM ENTRY DATA FACTORY

---@param itemData table
---@param options {visualDataInit: fun(self: table, data: table)?, isQuestItem: boolean?}?
---@return table?
function BETTERUI.CIM.CreateItemEntryData(itemData, options)
    options = options or {}

    local itemName = itemData.name
    local itemIcon = itemData.iconFile or itemData.icon

    -- Validate required fields
    if not itemName or not itemIcon then
        return nil
    end

    local data = ZO_GamepadEntryData:New(itemName, itemIcon)

    -- Initialize visual data (quality colors, icons, etc.)
    local visualInit = options.visualDataInit
    if visualInit then
        data.InitializeInventoryVisualData = visualInit
        data:InitializeInventoryVisualData(itemData)
    end

    -- Set up cooldown info
    local remaining, duration
    if options.isQuestItem then
        if itemData.toolIndex then
            remaining, duration = GetQuestToolCooldownInfo(itemData.questIndex, itemData.toolIndex)
        elseif itemData.stepIndex and itemData.conditionIndex then
            remaining, duration = GetQuestItemCooldownInfo(itemData.questIndex, itemData.stepIndex,
                itemData.conditionIndex)
        end
    else
        if itemData.bagId and itemData.slotIndex then
            remaining, duration = GetItemCooldownInfo(itemData.bagId, itemData.slotIndex)
        end
    end

    if remaining and duration and remaining > 0 and duration > 0 then
        data:SetCooldown(remaining, duration)
    end

    -- Copy category metadata
    local categoryName = itemData.bestGamepadItemCategoryName or itemData.bestItemCategoryName
    data.bestItemCategoryName = itemData.bestItemCategoryName or categoryName
    data.itemCategoryName = itemData.itemCategoryName or data.bestItemCategoryName
    data.bestGamepadItemCategoryName = categoryName or data.bestItemCategoryName
    data.bestItemTypeName = itemData.bestItemTypeName
    data.listModuleName = itemData.listModuleName

    -- Copy equipped/junk status
    data.isEquippedInCurrentCategory = itemData.isEquippedInCurrentCategory
    data.isEquippedInAnotherCategory = itemData.isEquippedInAnotherCategory
    data.isJunk = itemData.isJunk

    -- Explicitly copy slot metadata for action discovery (Y-menu)
    -- Native engine functions bypass Lua metatable fallback, so these must be direct properties
    -- Required by: ZO_InventorySlot_GetType, ZO_InventorySlot_GetStackCount, ZO_Inventory_GetBagAndIndex
    data.slotType = itemData.slotType
    data.stackCount = itemData.stackCount
    data.bagId = itemData.bagId
    data.slotIndex = itemData.slotIndex

    return data
end

---@param list table
---@param data table
---@param currentCategoryName string?
---@param useHeaders boolean?
---@return string? currentCategoryName
function BETTERUI.CIM.AddItemEntryToList(list, data, currentCategoryName, useHeaders)
    local template = "BETTERUI_GamepadItemSubEntryTemplate"

    if data.bestGamepadItemCategoryName ~= currentCategoryName then
        currentCategoryName = data.bestGamepadItemCategoryName
        data:SetHeader(currentCategoryName)
        if useHeaders then
            list:AddEntryWithHeader(template, data)
        else
            list:AddEntry(template, data)
        end
    else
        list:AddEntry(template, data)
    end

    return currentCategoryName
end
