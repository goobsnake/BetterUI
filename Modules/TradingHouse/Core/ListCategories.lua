--[[
File: Modules/TradingHouse/Core/ListCategories.lua
Purpose: Shared, mode-owned category taxonomy and filtering for Trading House
         Browse, Sell, and My Listings lists.
]]

local TH = BETTERUI.TradingHouse

TH.ListCategories = TH.ListCategories or {}
local Categories = TH.ListCategories

local ALL_KEY = "__all"
local ALL_ICON = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"
local MISC_ICON = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds"

local function GetDefinitions()
    local taxonomy = BETTERUI.CIM and BETTERUI.CIM.ItemTaxonomy
    return taxonomy and taxonomy.BANK_CATEGORY_DEFS or {}
end

local function GetDefinitionName(definition)
    if definition and definition.nameStringId and type(GetString) == "function" then
        local name = GetString(definition.nameStringId)
        if name and name ~= "" then
            return name
        end
    end
    if definition and definition.key == "all" then
        return "All Items"
    end
    return definition and definition.key or "Miscellaneous"
end

local function GetAllCategory()
    for _, definition in ipairs(GetDefinitions()) do
        if definition.key == "all" then
            return {
                key = ALL_KEY,
                name = GetDefinitionName(definition),
                icon = definition.iconFile or ALL_ICON,
                order = 0,
            }
        end
    end
    return { key = ALL_KEY, name = "All Items", icon = ALL_ICON, order = 0 }
end

local function GetItemCategoryDefinition(itemLink)
    local taxonomy = BETTERUI.CIM and BETTERUI.CIM.ItemTaxonomy
    local definitions = taxonomy and taxonomy.BANK_CATEGORY_DEFS or {}
    local filterData = {}
    if itemLink and type(GetItemLinkFilterTypeInfo) == "function" then
        filterData = { GetItemLinkFilterTypeInfo(itemLink) }
    end
    local fallbackDefinition = nil
    local fallbackOrder = #definitions + 1

    for order, definition in ipairs(definitions) do
        if definition.key == "misc" then
            fallbackDefinition = definition
            fallbackOrder = order
        elseif definition.key ~= "all" and definition.filterType ~= nil then
            for _, filterType in ipairs(filterData) do
                if definition.filterType == filterType then
                    return definition, order
                end
            end
        end
    end

    return fallbackDefinition or {
        key = "misc",
        nameStringId = rawget(_G, "SI_BETTERUI_INV_ITEM_MISC"),
        iconFile = MISC_ICON,
    }, fallbackOrder
end

---@param itemData table
---@return table itemData
function Categories.Annotate(itemData)
    itemData = itemData or {}
    local definition, order = GetItemCategoryDefinition(itemData.itemLink)
    itemData.listCategoryKey = definition.key
    itemData.listCategoryName = GetDefinitionName(definition)
    itemData.listCategoryIcon = definition.iconFile
    itemData.listCategoryFilterType = definition.filterType
    itemData.listCategoryOrder = order
    return itemData
end

local function BuildCategories(rows)
    local categories = { GetAllCategory() }
    local categoryByKey = {}
    for _, itemData in ipairs(rows or {}) do
        local key = itemData.listCategoryKey
        if key and not categoryByKey[key] then
            categoryByKey[key] = true
            categories[#categories + 1] = {
                key = key,
                name = itemData.listCategoryName,
                icon = itemData.listCategoryIcon,
                filterType = itemData.listCategoryFilterType,
                order = itemData.listCategoryOrder,
            }
        end
    end
    table.sort(categories, function(left, right)
        if left.key == right.key then return false end
        if left.key == ALL_KEY then return true end
        if right.key == ALL_KEY then return false end
        local leftOrder = left.order or 999
        local rightOrder = right.order or 999
        if leftOrder == rightOrder then
            return tostring(left.name or left.key) < tostring(right.name or right.key)
        end
        return leftOrder < rightOrder
    end)
    return categories, categoryByKey
end

---@param component table
---@param rows table[]
---@return table[] filteredRows
function Categories.Prepare(component, rows)
    rows = rows or {}
    local categories, categoryByKey = BuildCategories(rows)
    component.categories = categories

    local selectedKey = component.selectedCategoryKey or ALL_KEY
    if selectedKey ~= ALL_KEY and not categoryByKey[selectedKey] then
        selectedKey = ALL_KEY
    end
    component.selectedCategoryKey = selectedKey

    if selectedKey == ALL_KEY then
        return rows
    end

    local filteredRows = {}
    for _, itemData in ipairs(rows) do
        if itemData.listCategoryKey == selectedKey then
            filteredRows[#filteredRows + 1] = itemData
        end
    end
    return filteredRows
end

---@param component table
---@return table[] categories
function Categories.Get(component)
    if type(component.categories) ~= "table" or #component.categories == 0 then
        component.categories = { GetAllCategory() }
    end
    return component.categories
end

---@param component table
---@param categoryKey string|nil
---@param thInstance BETTERUI.TradingHouse.Class|nil
---@return nil
function Categories.Set(component, categoryKey, thInstance)
    local selectedKey = categoryKey or ALL_KEY
    if component.selectedCategoryKey == selectedKey then
        return
    end
    component.selectedCategoryKey = selectedKey
    if thInstance and thInstance.RefreshList then
        thInstance:RefreshList()
    end
end
