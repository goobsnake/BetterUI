--[[
File: Modules/Inventory/Core/Utils.lua
Purpose: Shared utility functions for the Inventory module.
         Delegates common functions to CIM.Utils for shared behavior.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Utils = {}

--[[
Function: BETTERUI.Inventory.Utils.WrapValue
Description: Wraps a value around min/max bounds for circular navigation.
Rationale: Delegates to CIM.Utils.WrapValue for shared implementation.
]]
--- @param newValue number The value to wrap
--- @param maxValue number The maximum value
--- @return number wrappedValue The wrapped value
function BETTERUI.Inventory.Utils.WrapValue(newValue, maxValue)
    return BETTERUI.CIM.Utils.WrapValue(newValue, maxValue)
end

--- Checks if the player has unlocked weapon swap (requires level 15).
--- @return boolean True if player can use backup bar
function BETTERUI.Inventory.Utils.CanUseBackupBar()
    return GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()
end

--- Callback for Right Bumper (Next) navigation.
--- Usage: Passed to BETTERUI_TabBarScrollList in GenericHeader
--- Rationale: Delegates to CIM.HeaderNavigation.CycleCategory for shared behavior.
--- @param parent table The parent class instance
--- @param successful boolean Whether the bumper press was successful
function BETTERUI.Inventory.Utils.OnTabNext(parent, successful)
    if not successful then return end
    if not parent.categoryList or not parent.categoryList.dataList or #parent.categoryList.dataList == 0 then
        return
    end

    -- Use shared CIM HeaderNavigation for consistent cycling
    BETTERUI.CIM.HeaderNavigation.CycleCategory(parent, 1, {
        categories = parent.categoryList.dataList,
        getCurrentIndex = function()
            return parent.categoryList.targetSelectedIndex or parent.categoryList.selectedIndex or 1
        end,
        setCurrentIndex = function(idx)
            parent.categoryList.targetSelectedIndex = idx
            parent.categoryList.selectedIndex = idx
            parent.categoryList.selectedData = parent.categoryList.dataList[idx]
            parent.categoryList.defaultSelectedIndex = idx
        end,
        onRefresh = function()
            BETTERUI.GenericHeader.SetTitleText(parent.header, parent.categoryList.selectedData.text)
            parent:ToSavedPosition()
        end,
    })
end

--- Callback for Left Bumper (Previous) navigation.
--- Usage: Passed to BETTERUI_TabBarScrollList in GenericHeader
--- Rationale: Delegates to CIM.HeaderNavigation.CycleCategory for shared behavior.
--- @param parent table The parent class instance
--- @param successful boolean Whether the bumper press was successful
function BETTERUI.Inventory.Utils.OnTabPrev(parent, successful)
    if not successful then return end
    if not parent.categoryList or not parent.categoryList.dataList or #parent.categoryList.dataList == 0 then
        return
    end

    -- Use shared CIM HeaderNavigation for consistent cycling
    BETTERUI.CIM.HeaderNavigation.CycleCategory(parent, -1, {
        categories = parent.categoryList.dataList,
        getCurrentIndex = function()
            return parent.categoryList.targetSelectedIndex or parent.categoryList.selectedIndex or 1
        end,
        setCurrentIndex = function(idx)
            parent.categoryList.targetSelectedIndex = idx
            parent.categoryList.selectedIndex = idx
            parent.categoryList.selectedData = parent.categoryList.dataList[idx]
            parent.categoryList.defaultSelectedIndex = idx
        end,
        onRefresh = function()
            BETTERUI.GenericHeader.SetTitleText(parent.header, parent.categoryList.selectedData.text)
            parent:ToSavedPosition()
        end,
    })
end

--[[
Function: BETTERUI.Inventory.Utils.SafeGetTargetData
Description: Safe helper for GetTargetData calls (guards against lists without method).
Rationale: Delegates to CIM.Utils.SafeGetTargetData for shared implementation.
]]
--- @param list table The list to get target data from
--- @return table|nil targetData The target data
function BETTERUI.Inventory.Utils.SafeGetTargetData(list)
    return BETTERUI.CIM.Utils.SafeGetTargetData(list)
end
