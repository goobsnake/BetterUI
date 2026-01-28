--[[
File: Modules/Inventory/Core/Utils.lua
Purpose: Shared utility functions for the Inventory module.
Author: BetterUI Team
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Utils = {}

--- Wraps a value around min/max bounds for circular navigation.
--- @param newValue number The value to wrap
--- @param maxValue number The maximum value (1 is implicit minimum)
--- @return number The wrapped value
function BETTERUI.Inventory.Utils.WrapValue(newValue, maxValue)
    if newValue < 1 then
        return maxValue
    end
    if newValue > maxValue then
        return 1
    end
    return newValue
end

--- Checks if the player has unlocked weapon swap (requires level 15).
--- @return boolean True if player can use backup bar
function BETTERUI.Inventory.Utils.CanUseBackupBar()
    return GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()
end

--- Callback for Right Bumper (Next) navigation.
--- Usage: Passed to BETTERUI_TabBarScrollList in GenericHeader
function BETTERUI.Inventory.Utils.OnTabNext(parent, successful)
    if successful then
        if not parent.categoryList or not parent.categoryList.dataList or #parent.categoryList.dataList == 0 then
            return
        end
        parent:SaveListPosition()

        parent.categoryList.targetSelectedIndex =
            BETTERUI.Inventory.Utils.WrapValue(parent.categoryList.targetSelectedIndex + 1, #parent.categoryList
                .dataList)
        parent.categoryList.selectedIndex = parent.categoryList.targetSelectedIndex
        parent.categoryList.selectedData = parent.categoryList.dataList[parent.categoryList.selectedIndex]
        parent.categoryList.defaultSelectedIndex = parent.categoryList.selectedIndex

        BETTERUI.GenericHeader.SetTitleText(parent.header, parent.categoryList.selectedData.text)

        parent:ToSavedPosition()
    end
end

--- Callback for Left Bumper (Previous) navigation.
--- Usage: Passed to BETTERUI_TabBarScrollList in GenericHeader
function BETTERUI.Inventory.Utils.OnTabPrev(parent, successful)
    if successful then
        if not parent.categoryList or not parent.categoryList.dataList or #parent.categoryList.dataList == 0 then
            return
        end
        parent:SaveListPosition()

        parent.categoryList.targetSelectedIndex =
            BETTERUI.Inventory.Utils.WrapValue(parent.categoryList.targetSelectedIndex - 1, #parent.categoryList
                .dataList)
        parent.categoryList.selectedIndex = parent.categoryList.targetSelectedIndex
        parent.categoryList.selectedData = parent.categoryList.dataList[parent.categoryList.selectedIndex]
        parent.categoryList.defaultSelectedIndex = parent.categoryList.selectedIndex

        BETTERUI.GenericHeader.SetTitleText(parent.header, parent.categoryList.selectedData.text)

        parent:ToSavedPosition()
    end
end

--- Safe helper for GetTargetData calls (guards against lists without method)
--- @param list table The list object to query
--- @return table|nil The target data of the list
function BETTERUI.Inventory.Utils.SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    -- Fallback for basic tables or parametric lists
    return list.selectedData
end
