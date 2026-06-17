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
    if not selectionBar then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "selectionHighlightNoBar", { controlName = control and control.GetName and control:GetName() or "nil" })
        end
        return
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "selectionHighlight", { selected = selected == true })
    end
    selectionBar:SetHidden(not selected)
end
