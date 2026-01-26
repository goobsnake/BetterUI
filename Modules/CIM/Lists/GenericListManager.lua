--[[
File: Modules/CIM/Lists/GenericListManager.lua
Purpose: Shared list management logic for Inventory and Banking modules.
         Provides sorting, filtering, position tracking, and caching utilities.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

local _

if not BETTERUI.CIM then BETTERUI.CIM = {} end

--[[
Class: BETTERUI.CIM.GenericListManager
Description: Base class for list management logic shared across inventory-like windows.
]]
BETTERUI.CIM.GenericListManager = ZO_Object:Subclass()

function BETTERUI.CIM.GenericListManager:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BETTERUI.CIM.GenericListManager:Initialize()
    self.savedPositions = {}
    self.itemCache = {}
end

-------------------------------------------------------------------------------------------------
-- POSITION MANAGEMENT
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericListManager:SavePosition
Description: Saves the current list position for later restoration.
param: categoryKey (string) - The category to save position for.
param: position (number) - The scroll position to save.
]]
function BETTERUI.CIM.GenericListManager:SavePosition(categoryKey, position)
    if categoryKey then
        self.savedPositions[categoryKey] = position
    end
end

--[[
Function: BETTERUI.CIM.GenericListManager:RestorePosition
Description: Restores a previously saved list position.
param: categoryKey (string) - The category to restore position for.
return: number|nil - The saved position, or nil if not found.
]]
function BETTERUI.CIM.GenericListManager:RestorePosition(categoryKey)
    return self.savedPositions[categoryKey]
end

--[[
Function: BETTERUI.CIM.GenericListManager:ClearSavedPositions
Description: Clears all saved list positions.
]]
function BETTERUI.CIM.GenericListManager:ClearSavedPositions()
    self.savedPositions = {}
end

-------------------------------------------------------------------------------------------------
-- ITEM CACHING
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericListManager:CacheItemLinkData
Description: Caches expensive item link data to avoid repeated API calls.
param: itemData (table) - The item data table to cache into.
param: bagId (number) - The bag ID.
param: slotIndex (number) - The slot index.
]]
function BETTERUI.CIM.GenericListManager:CacheItemLinkData(itemData, bagId, slotIndex)
    if itemData.cached_itemLink then return end

    local itemLink = GetItemLink(bagId, slotIndex)
    itemData.cached_itemLink = itemLink

    if itemLink then
        itemData.cached_itemType = GetItemLinkItemType(itemLink)
        itemData.cached_setItem = GetItemLinkSetInfo(itemLink, false)
        itemData.cached_hasEnchantment = GetItemLinkEnchantInfo(itemLink)

        if itemData.cached_itemType == ITEMTYPE_RECIPE then
            itemData.cached_isRecipeAndUnknown = not IsItemLinkRecipeKnown(itemLink)
        end

        itemData.cached_isBookKnown = IsItemLinkBookKnown(itemLink)
    end
end

-------------------------------------------------------------------------------------------------
-- UTILITY FUNCTIONS (Static)
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.MenuEntryTemplateEquality
Description: Equality function for parametric list templates.
             Used to determine if two list entries represent the same item.
param: left (table) - First entry.
param: right (table) - Second entry.
return: boolean - True if entries are equal.
]]
function BETTERUI.CIM.MenuEntryTemplateEquality(left, right)
    return left.uniqueId == right.uniqueId
end
