--[[
File: Modules/CIM/Core/Data/PositionManager.lua
Purpose: Shared position persistence manager for inventory-style lists.
         Provides save/restore functionality for list positions per-category.
         Used by Inventory and Banking modules.
]]

-- NAMESPACE INITIALIZATION

BETTERUI.CIM = BETTERUI.CIM or {}

---@class BETTERUI.CIM.PositionManager
BETTERUI.CIM.PositionManager = {}

---@class SavedPosition
---@field index number Saved list index
---@field uniqueId string|nil Unique item ID for robust restoration

-- Internal storage: { [moduleName] = { [categoryKey] = { index = N, uniqueId = "..." } } }
local _storage = {}

local function TracePositionEvent(event, phase, message, data)
    local L = BETTERUI.Log
    if not L then return end
    local categories = L.CATEGORY or {}
    if L.TraceEvent then
        L.TraceEvent(categories.NAV, event, phase, data or {})
    elseif L.Trace then
        L.Trace(categories.NAV, message, data or {})
    end
end

local function AreUniqueIdsEqual(left, right)
    if left == nil or right == nil then return false end
    if type(AreId64sEqual) == "function" then
        local ok, equal = pcall(AreId64sEqual, left, right)
        if ok then return equal == true end
    end
    return tostring(left) == tostring(right)
end

-- CATEGORY KEY GENERATION

---@param categoryData table|nil Category data with filterType, onClickDirection, key, text, or index
---@return string|nil key Unique category key, or nil if categoryData is nil
function BETTERUI.CIM.PositionManager.GetCategoryKey(categoryData)
    if not categoryData then return nil end

    -- Priority 1: Filter type (most stable for item categories)
    if categoryData.filterType ~= nil then
        local key = "f:" .. tostring(categoryData.filterType)
        TracePositionEvent("list.position.category_key", "resolved", "category key resolved", { key = key, source = "filterType" })
        return key
    end

    -- Priority 2: Click direction (for craft bag navigation)
    if categoryData.onClickDirection then
        local key = "dir:" .. tostring(categoryData.onClickDirection)
        TracePositionEvent("list.position.category_key", "resolved", "category key resolved", { key = key, source = "onClickDirection" })
        return key
    end

    -- Priority 3: Category key (Banking uses this)
    if categoryData.key then
        local key = "k:" .. tostring(categoryData.key)
        TracePositionEvent("list.position.category_key", "resolved", "category key resolved", { key = key, source = "key" })
        return key
    end

    -- Priority 4: Text label
    if categoryData.text then
        local key = "t:" .. tostring(categoryData.text)
        TracePositionEvent("list.position.category_key", "resolved", "category key resolved", { key = key, source = "text" })
        return key
    end

    -- Priority 5: Index fallback
    local key = "idx:" .. tostring(categoryData.index or "")
    TracePositionEvent("list.position.category_key", "resolved", "category key resolved", { key = key, source = "index" })
    return key
end

-- POSITION SAVE/RESTORE

---@param moduleName string Module name key (e.g. "Inventory", "Banking")
---@param categoryKey string Category key from GetCategoryKey
---@param list table List control with selectedIndex and selectedData fields
function BETTERUI.CIM.PositionManager.SavePosition(moduleName, categoryKey, list)
    if not moduleName or not categoryKey or not list then return end

    -- Initialize module storage if needed
    _storage[moduleName] = _storage[moduleName] or {}

    -- Get the inner list if wrapped (e.g., craftBagList wraps an inner list)
    local innerList = list.list or list

    if not innerList.selectedIndex then return end

    local itemIndex = innerList.selectedIndex or 1
    local selectedData = innerList.selectedData
    local rawSelectedData = selectedData and (selectedData.dataSource or selectedData)
    local itemUniqueId = rawSelectedData and rawSelectedData.uniqueId

    -- Store both index and uniqueId for robust restoration
    _storage[moduleName][categoryKey] = {
        index = itemIndex,
        uniqueId = itemUniqueId,
    }
    TracePositionEvent("list.position", "saved", "save list position", {
        moduleName = moduleName,
        categoryKey = categoryKey,
        index = itemIndex,
        uniqueId = itemUniqueId,
        hasUniqueId = itemUniqueId ~= nil,
    })
end

---@param moduleName string Module name key
---@param categoryKey string Category key
---@return SavedPosition|nil saved Saved position data, or nil if none
function BETTERUI.CIM.PositionManager.GetSavedPosition(moduleName, categoryKey)
    if not moduleName or not categoryKey then return nil end
    if not _storage[moduleName] then return nil end
    local saved = _storage[moduleName][categoryKey]
    TracePositionEvent("list.position", "read", "get saved position", {
        moduleName = moduleName,
        categoryKey = categoryKey,
        found = saved ~= nil,
        index = saved and saved.index or nil,
        uniqueId = saved and saved.uniqueId or nil,
    })
    return saved
end

---@param moduleName string Module name key
---@param categoryKey string Category key
---@param list table|nil List control (unused, kept for API compat)
---@param dataList table[] Array of item data with optional uniqueId fields
---@return number targetIndex Best restored index clamped to [1, #dataList]
function BETTERUI.CIM.PositionManager.RestorePosition(moduleName, categoryKey, list, dataList)
    if not moduleName or not categoryKey then return 1 end
    if not dataList or #dataList == 0 then return 1 end

    local saved = BETTERUI.CIM.PositionManager.GetSavedPosition(moduleName, categoryKey)
    if not saved then return 1 end

    local targetIndex = 1
    local foundByUniqueId = false

    -- Try to find by uniqueId first (most accurate)
    if saved.uniqueId then
        for i, data in ipairs(dataList) do
            local rawData = data.dataSource or data
            if AreUniqueIdsEqual(rawData.uniqueId, saved.uniqueId) then
                targetIndex = i
                foundByUniqueId = true
                break
            end
        end
        -- If uniqueId wasn't found, fall back to saved index
        if not foundByUniqueId and saved.index then
            targetIndex = saved.index
        end
    elseif saved.index then
        targetIndex = saved.index
    end

    -- Clamp to valid range
    targetIndex = zo_clamp(targetIndex, 1, #dataList)

    TracePositionEvent("list.position", "restored", "restore list position", {
        moduleName = moduleName,
        categoryKey = categoryKey,
        targetIndex = targetIndex,
        savedIndex = saved.index,
        savedUniqueId = saved.uniqueId,
        foundByUniqueId = foundByUniqueId,
        itemCount = #dataList,
    })
    return targetIndex
end

---@param moduleName string Module name key
function BETTERUI.CIM.PositionManager.ClearModule(moduleName)
    if not moduleName then return end
    _storage[moduleName] = nil
    TracePositionEvent("list.position", "cleared", "clear saved positions", { moduleName = moduleName, categoryKey = nil, scope = "module" })
end

---@param moduleName string Module name key
---@param categoryKey string Category key to clear
function BETTERUI.CIM.PositionManager.ClearCategory(moduleName, categoryKey)
    if not moduleName or not categoryKey then return end
    if _storage[moduleName] then
        _storage[moduleName][categoryKey] = nil
    end
    TracePositionEvent("list.position", "cleared", "clear saved positions", { moduleName = moduleName, categoryKey = categoryKey, scope = "category" })
end
