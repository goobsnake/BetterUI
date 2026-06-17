--[[
File: Modules/CIM/Lists/HorizontalScrollList.lua
Purpose: Horizontal parametric scroll list base class for shared headers/tab bars.
]]

-- CLASS: BETTERUI_HorizontalParametricScrollList
-- Base class for horizontal parametric lists.
BETTERUI_HorizontalParametricScrollList = ZO_ParametricScrollList:Subclass()
local LIST_ORIENTATION = (BETTERUI.CIM and BETTERUI.CIM.ListGlobals and BETTERUI.CIM.ListGlobals.ORIENTATION) or
{
    VERTICAL = true,
    HORIZONTAL = false,
}

--- Creates a new horizontal parametric scroll list.
---@param control table
---@param onActivatedChangedFunction fun(list: table, active: boolean)?
---@param onCommitWithItemsFunction fun()?
---@param onClearedFunction fun()?
---@return table
function BETTERUI_HorizontalParametricScrollList:New(control, onActivatedChangedFunction, onCommitWithItemsFunction,
                                                     onClearedFunction)
    onActivatedChangedFunction = onActivatedChangedFunction or ZO_GamepadOnDefaultScrollListActivatedChanged
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "horizontalListNew", { controlName = control and control.GetName and control:GetName() or "nil" })
    end
    local list = ZO_ParametricScrollList.New(self, control, LIST_ORIENTATION.HORIZONTAL, onActivatedChangedFunction,
        onCommitWithItemsFunction, onClearedFunction)
    list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, GAMEPAD_HEADER_SELECTED_PADDING)
    list:SetPlaySoundFunction(BETTERUI.GamepadParametricScrollListPlaySound)
    return list
end
