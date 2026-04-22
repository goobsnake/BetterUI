--[[
File: Modules/Inventory/Core/Utils.lua
Purpose: Shared utility functions for the Inventory module.
         Delegates common functions to CIM.Utils for shared behavior.
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}

--- @class InventoryUtils
--- @field OnTabNext fun(parent: table, successful: boolean)
--- @field OnTabPrev fun(parent: table, successful: boolean)
--- @field SafeGetTargetData fun(list: table): table|nil
--- @field GetListTargetData fun(list: table): table|nil
BETTERUI.Inventory.Utils = BETTERUI.Inventory.Utils or {}

---@param parent table Inventory instance with categoryList
---@param step number Navigation step (+1 or -1)
local function CycleCategoryTab(parent, step)
    if not parent.categoryList or not parent.categoryList.dataList or #parent.categoryList.dataList == 0 then
        return
    end

    BETTERUI.CIM.HeaderNavigation.CycleCategory(parent, step, {
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

--- Callback for Right Bumper (Next) navigation.
--- Usage: Passed to BETTERUI_TabBarScrollList in GenericHeader
--- Rationale: Delegates to CIM.HeaderNavigation.CycleCategory for shared behavior.
--- @param parent table Inventory instance with categoryList
--- @param successful boolean Whether the bumper press was successful
function BETTERUI.Inventory.Utils.OnTabNext(parent, successful)
    if not successful then return end
    CycleCategoryTab(parent, 1)
end

--- Callback for Left Bumper (Previous) navigation.
--- Usage: Passed to BETTERUI_TabBarScrollList in GenericHeader
--- Rationale: Delegates to CIM.HeaderNavigation.CycleCategory for shared behavior.
--- @param parent table Inventory instance with categoryList
--- @param successful boolean Whether the bumper press was successful
function BETTERUI.Inventory.Utils.OnTabPrev(parent, successful)
    if not successful then return end
    CycleCategoryTab(parent, -1)
end

BETTERUI.Inventory.Utils.SafeGetTargetData = BETTERUI.CIM.Utils.SafeGetTargetData
if type(BETTERUI.CIM.Utils.GetListTargetData) == "function" then
    BETTERUI.Inventory.Utils.SafeGetTargetData = BETTERUI.CIM.Utils.GetListTargetData
elseif type(BETTERUI.Inventory.Utils.SafeGetTargetData) ~= "function" then
    BETTERUI.Inventory.Utils.SafeGetTargetData = function(list)
        if not list then
            return nil
        end
        if list.GetTargetData then
            return list:GetTargetData()
        end
        if list.GetSelectedData then
            return list:GetSelectedData()
        end
        if list.targetData ~= nil then
            return list.targetData
        end
        return list.selectedData
    end
end
BETTERUI.Inventory.Utils.GetListTargetData = BETTERUI.Inventory.Utils.SafeGetTargetData
