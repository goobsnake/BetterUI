--[[
File: Modules/CIM/Core/PositionManager.lua
Purpose: Shared position persistence manager for inventory-style lists.
         Provides save/restore functionality for list positions per-category.
         Used by Inventory and Banking modules.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-- ============================================================================
-- NAMESPACE INITIALIZATION
-- ============================================================================

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.PositionManager = {}

-- Internal storage: { [moduleName] = { [categoryKey] = { index = N, uniqueId = "..." } } }
local _storage = {}

-- ============================================================================
-- CATEGORY KEY GENERATION
-- ============================================================================

--[[
Function: BETTERUI.CIM.PositionManager.GetCategoryKey
Description: Generates a stable string key for a category entry.
Rationale: Provides consistent key generation for position lookup across modules.
Mechanism: Uses filterType, onClickDirection, text, or index as fallback identifiers.
param: categoryData (table) - The category data table.
return: string|nil - The generated key or nil if no categoryData.
]]
--- @param categoryData table|nil The category data table
--- @return string|nil key The generated key or nil if no categoryData
function BETTERUI.CIM.PositionManager.GetCategoryKey(categoryData)
    if not categoryData then return nil end

    -- Priority 1: Filter type (most stable for item categories)
    if categoryData.filterType ~= nil then
        return "f:" .. tostring(categoryData.filterType)
    end

    -- Priority 2: Click direction (for craft bag navigation)
    if categoryData.onClickDirection then
        return "dir:" .. tostring(categoryData.onClickDirection)
    end

    -- Priority 3: Category key (Banking uses this)
    if categoryData.key then
        return "k:" .. tostring(categoryData.key)
    end

    -- Priority 4: Text label
    if categoryData.text then
        return "t:" .. tostring(categoryData.text)
    end

    -- Priority 5: Index fallback
    return "idx:" .. tostring(categoryData.index or "")
end

-- ============================================================================
-- POSITION SAVE/RESTORE
-- ============================================================================

--[[
Function: BETTERUI.CIM.PositionManager.SavePosition
Description: Saves the current list position for a module/category.
Rationale: Centralizes position persistence logic for all modules.
Mechanism: Extracts selectedIndex and uniqueId from list, stores in _storage.
param: moduleName (string) - The module identifier (e.g., "Inventory", "Banking").
param: categoryKey (string) - The category key from GetCategoryKey().
param: list (table) - The list object with selectedIndex and selectedData.
]]
--- @param moduleName string The module identifier (e.g., "Inventory", "Banking")
--- @param categoryKey string The category key from GetCategoryKey()
--- @param list table The list object with selectedIndex and selectedData
function BETTERUI.CIM.PositionManager.SavePosition(moduleName, categoryKey, list)
    if not moduleName or not categoryKey or not list then return end

    -- Initialize module storage if needed
    _storage[moduleName] = _storage[moduleName] or {}

    -- Get the inner list if wrapped (e.g., craftBagList wraps an inner list)
    local innerList = list.list or list

    if not innerList.selectedIndex then return end

    local itemIndex = innerList.selectedIndex or 1
    local itemUniqueId = innerList.selectedData and innerList.selectedData.uniqueId

    -- Store both index and uniqueId for robust restoration
    _storage[moduleName][categoryKey] = {
        index = itemIndex,
        uniqueId = itemUniqueId,
    }
end

--[[
Function: BETTERUI.CIM.PositionManager.GetSavedPosition
Description: Retrieves the saved position for a module/category.
param: moduleName (string) - The module identifier.
param: categoryKey (string) - The category key.
return: table|nil - { index = N, uniqueId = "..." } or nil if not saved.
]]
--- @param moduleName string The module identifier
--- @param categoryKey string The category key
--- @return {index: number, uniqueId: string|nil}|nil position Saved position or nil
function BETTERUI.CIM.PositionManager.GetSavedPosition(moduleName, categoryKey)
    if not moduleName or not categoryKey then return nil end
    if not _storage[moduleName] then return nil end
    return _storage[moduleName][categoryKey]
end

--[[
Function: BETTERUI.CIM.PositionManager.RestorePosition
Description: Restores a saved position on a list.
Rationale: Handles uniqueId lookup with index fallback for robust restoration.
Mechanism:
  1. Retrieves saved position data.
  2. If uniqueId exists, searches dataList for matching item.
  3. Falls back to saved index if uniqueId not found (item was removed).
  4. Clamps index to valid range.
param: moduleName (string) - The module identifier.
param: categoryKey (string) - The category key.
param: list (table) - The list object.
param: dataList (table) - The list's data array.
return: number - The restored index (1 if no saved position).
]]
--- @param moduleName string The module identifier
--- @param categoryKey string The category key
--- @param list table The list object
--- @param dataList table[] The list's data array
--- @return number targetIndex The restored index (1 if no saved position)
function BETTERUI.CIM.PositionManager.RestorePosition(moduleName, categoryKey, list, dataList)
    if not moduleName or not categoryKey then return 1 end
    if not dataList or #dataList == 0 then return 1 end

    local saved = BETTERUI.CIM.PositionManager.GetSavedPosition(moduleName, categoryKey)
    if not saved then return 1 end

    local targetIndex = 1

    -- Try to find by uniqueId first (most accurate)
    if saved.uniqueId then
        for i, data in ipairs(dataList) do
            if data.uniqueId == saved.uniqueId then
                targetIndex = i
                break
            end
        end
        -- If uniqueId wasn't found, fall back to saved index
        if targetIndex == 1 and saved.index and saved.index > 1 then
            targetIndex = saved.index
        end
    elseif saved.index then
        targetIndex = saved.index
    end

    -- Clamp to valid range
    targetIndex = zo_clamp(targetIndex, 1, #dataList)

    return targetIndex
end

--[[
Function: BETTERUI.CIM.PositionManager.ClearModule
Description: Clears all saved positions for a module.
Rationale: Used when exiting a scene to prevent stale data.
param: moduleName (string) - The module identifier.
]]
--- @param moduleName string The module identifier
function BETTERUI.CIM.PositionManager.ClearModule(moduleName)
    if not moduleName then return end
    _storage[moduleName] = nil
end

--[[
Function: BETTERUI.CIM.PositionManager.ClearCategory
Description: Clears the saved position for a specific category.
param: moduleName (string) - The module identifier.
param: categoryKey (string) - The category key.
]]
--- @param moduleName string The module identifier
--- @param categoryKey string The category key
function BETTERUI.CIM.PositionManager.ClearCategory(moduleName, categoryKey)
    if not moduleName or not categoryKey then return end
    if _storage[moduleName] then
        _storage[moduleName][categoryKey] = nil
    end
end
