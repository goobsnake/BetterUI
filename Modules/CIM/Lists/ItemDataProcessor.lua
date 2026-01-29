--[[
File: Modules/CIM/Lists/ItemDataProcessor.lua
Purpose: Shared factory for creating item entry data for inventory/banking lists.
         Eliminates duplicate entry creation code between modules.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-------------------------------------------------------------------------------------------------
-- ITEM ENTRY DATA FACTORY
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.CreateItemEntryData
Description: Creates a ZO_GamepadEntryData for display in inventory/banking scroll lists.
Rationale: Consolidates duplicate entry creation code from ItemListManager and BankListManager.
Mechanism:
  1. Creates new ZO_GamepadEntryData with item name and icon
  2. Initializes visual data (quality colors, icons)
  3. Sets up cooldown info if applicable
  4. Copies slot metadata required for Y-menu action discovery
  5. Copies category and junk/equipped status
param: itemData (table) - Raw item data from SHARED_INVENTORY or similar.
param: options (table) - Optional configuration:
    - isQuestItem (boolean): If true, uses quest cooldown APIs instead of item cooldown.
    - visualDataInit (function): Custom visual data initializer (defaults to BETTERUI.Inventory.Class.InitializeInventoryVisualData).
return: ZO_GamepadEntryData - The entry data ready for list:AddEntry().
]]
--- @param itemData table Raw item data from SHARED_INVENTORY or similar
--- @param options table|nil Optional configuration
--- @return ZO_GamepadEntryData|nil data The entry data ready for list:AddEntry()
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
    local visualInit = options.visualDataInit or BETTERUI.Inventory.Class.InitializeInventoryVisualData
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
    data.bestItemCategoryName = itemData.bestItemCategoryName
    data.bestGamepadItemCategoryName = itemData.bestItemCategoryName

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

--[[
Function: BETTERUI.CIM.AddItemEntryToList
Description: Helper to add an item entry to a list with optional category header.
Rationale: Encapsulates the category header logic used by both Inventory and Banking.
param: list (table) - The scroll list to add to.
param: data (ZO_GamepadEntryData) - The entry data.
param: currentCategoryName (string|nil) - The current category name for header comparison.
param: useHeaders (boolean) - Whether to use AutoCategory-style headers.
return: string - The new current category name (for tracking).
]]
--- @param list table The scroll list to add to
--- @param data ZO_GamepadEntryData The entry data
--- @param currentCategoryName string|nil The current category name for header comparison
--- @param useHeaders boolean Whether to use AutoCategory-style headers
--- @return string currentCategoryName The new current category name
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
