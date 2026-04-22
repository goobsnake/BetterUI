--[[
File: Modules/CIM/Core/AutoCategoryIntegration.lua
Purpose: Integration with AutoCategory addon for advanced inventory sorting.
         Provides rule-based categorization for items.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.AutoCategoryIntegration = BETTERUI.CIM.AutoCategoryIntegration or {}

local AutoCategoryIntegration = BETTERUI.CIM.AutoCategoryIntegration
local OptionalAddons = assert(BETTERUI.CIM.OptionalAddons,
    "BetterUI: CIM.OptionalAddons must load before AutoCategoryIntegration")

-- AUTOCATEGORY INTEGRATION

---@param itemData table
---@return boolean useCustomCategory
---@return boolean matched
---@return string categoryName
---@return number categoryPriority
function AutoCategoryIntegration.GetCustomCategory(itemData)
    if type(itemData) ~= "table" then
        return false, false, "", 0
    end

    local useCustomCategory = false
    local autoCategory = OptionalAddons.GetGlobal("AutoCategory")
    if autoCategory and autoCategory.Inited then
        useCustomCategory = true
        local bagId = itemData.bagId
        local slotIndex = itemData.slotIndex
        local matched, categoryName, categoryPriority = autoCategory:MatchCategoryRules(bagId, slotIndex)
        return useCustomCategory, matched, categoryName, categoryPriority
    end

    return useCustomCategory, false, "", 0
end

BETTERUI.GetCustomCategory = AutoCategoryIntegration.GetCustomCategory
