--[[
File: Modules/CIM/Lists/GenericListManager.lua
Purpose: Shared parametric-list helpers used by Inventory and Banking modules.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

--- Equality function for parametric list templates.
function BETTERUI.CIM.MenuEntryTemplateEquality(left, right)
    return left.uniqueId == right.uniqueId
end
