--[[
File: Modules/CIM/UI/SelectionHighlight.lua
Purpose: Provides a gradient highlight bar for selected inventory/banking rows.
         Gradient is defined in XML via FadeGradient element for reliability.
         This Lua just shows/hides the SelectionBar.
]]

-- Ensure namespace exists
if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.SelectionHighlight then BETTERUI.CIM.SelectionHighlight = {} end

local SelectionHighlight = BETTERUI.CIM.SelectionHighlight

--- Shows or hides the row selection bar.
---@param control table
---@param selected boolean
function SelectionHighlight.Setup(control, selected)
    if not control then return end

    local selectionBar = control:GetNamedChild("SelectionBar")
    if not selectionBar then return end

    selectionBar:SetHidden(not selected)
end
