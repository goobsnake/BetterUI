--[[
File: Modules/CIM/Core/Integration/AutoCategoryIntegration.lua
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
    if type(autoCategory) == "table" and not autoCategory.Inited then
        if BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.CATEGORY, "AutoCategory loaded but Inited is nil/false; category rules skipped", { bagId = itemData.bagId, slotIndex = itemData.slotIndex })
        end
    end
    if type(autoCategory) == "table" and autoCategory.Inited and type(autoCategory.MatchCategoryRules) == "function" then
        useCustomCategory = true
        local bagId = itemData.bagId
        local slotIndex = itemData.slotIndex
        local ok, matched, categoryName, categoryPriority = pcall(
            autoCategory.MatchCategoryRules,
            autoCategory,
            bagId,
            slotIndex
        )
        if not ok then
            if BETTERUI.Log then
                BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.CATEGORY, "auto category match failed", { error = tostring(matched) })
            end
            return useCustomCategory, false, "", 0
        end

        local categoryPriorityType = type(categoryPriority)
        local normalizedPriority = nil
        if categoryPriorityType == "number" or categoryPriorityType == "string" then
            normalizedPriority = tonumber(categoryPriority)
        end

        return useCustomCategory,
            matched == true,
            type(categoryName) == "string" and categoryName or "",
            normalizedPriority or 0
    end

    return useCustomCategory, false, "", 0
end

BETTERUI.GetCustomCategory = AutoCategoryIntegration.GetCustomCategory
