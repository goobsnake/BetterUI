--[[
File: Modules/CIM/Core/AutoCategoryIntegration.lua
Purpose: Integration with AutoCategory addon for advanced inventory sorting.
         Provides rule-based categorization for items.
]]

-- AUTOCATEGORY INTEGRATION

---@param itemData table
---@return boolean useCustomCategory
---@return boolean matched
---@return string categoryName
---@return number categoryPriority
function BETTERUI.GetCustomCategory(itemData)
    local useCustomCategory = false
    if AutoCategory and AutoCategory.Inited then
        useCustomCategory = true
        local bagId = itemData.bagId
        local slotIndex = itemData.slotIndex
        local matched, categoryName, categoryPriority = AutoCategory:MatchCategoryRules(bagId, slotIndex)
        return useCustomCategory, matched, categoryName, categoryPriority
    end

    return useCustomCategory, false, "", 0
end
