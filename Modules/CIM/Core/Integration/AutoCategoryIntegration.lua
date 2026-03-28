--[[
File: Modules/CIM/Core/AutoCategoryIntegration.lua
Purpose: Integration with AutoCategory addon for advanced inventory sorting.
         Provides rule-based categorization for items.
]]

-- ============================================================================
-- AUTOCATEGORY INTEGRATION
-- ============================================================================

--- @param itemData {bagId: number, slotIndex: number} The item data with bagId and slotIndex
--- @return boolean useCustomCategory True if AutoCategory is active
--- @return boolean matched True if a rule matched
--- @return string categoryName The name of the matched category
--- @return number categoryPriority The priority for sorting
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
