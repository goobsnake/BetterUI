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

--[[
Function: BETTERUI.Inventory.Utils.SafeGetTargetData
Description: Safe helper for GetTargetData calls (guards against lists without method).
Rationale: Delegates to CIM.Utils.SafeGetTargetData for shared implementation.
]]
function BETTERUI.Inventory.Utils.SafeGetTargetData(list)
    return BETTERUI.CIM.Utils.SafeGetTargetData(list)
end
