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

-- SETUP FUNCTIONS

--- Shows/hides the selection highlight bar for an inventory/banking row.
---
--- Purpose: Toggles selection highlight visibility.
--- The gradient styling is pre-defined in XML (SharedTemplates.xml) using
--- FadeGradient element, so we only need to toggle visibility here.
---
---@param control table
---@param selected boolean
function SelectionHighlight.Setup(control, selected)
    if not control then return end

    -- SelectionBar is defined in XML template with FadeGradient
    local selectionBar = control:GetNamedChild("SelectionBar")
    if not selectionBar then return end

    -- Simply show/hide - gradient and color are pre-defined in XML
    selectionBar:SetHidden(not selected)
end
