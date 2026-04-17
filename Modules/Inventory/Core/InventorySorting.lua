-- Modules/Inventory/Core/InventorySorting.lua
-- Header sort mode: column definitions, comparators, controller init, and column linking.
-- Extracted from InventoryClass.lua for maintainability.

local Class = BETTERUI.Inventory.Class
local CompareNils = BETTERUI.CIM.Utils.CompareNils

-- HEADER SORT MODE
-- Column definitions for header sort navigation
-- Each column has a name (for display), key (internal), sortKey, and optional defaultDirection
--- @class SortColumnDef
--- @field name string Display name ("NAME", "TYPE", etc.)
--- @field key string Internal identifier
--- @field sortKey string Data field used for comparisons
--- @field defaultDirection? string "ascending" or "descending"

--- @type SortColumnDef[]
local INVENTORY_SORT_COLUMNS = {
    { name = "NAME",  key = "name",  sortKey = "name" },
    { name = "TYPE",  key = "type",  sortKey = "bestGamepadItemCategoryName" },
    { name = "TRAIT", key = "trait", sortKey = "trait" },
    { name = "STAT",  key = "stat",  sortKey = "stat" },
    { name = "VALUE", key = "value", sortKey = "value", defaultDirection = "descending" },
}

--- Helper: Get trait display name for sorting (alphabetical with blanks last)
--- @param data table Item data or dataSource wrapper
--- @return string|nil traitName Uppercased trait name or nil
local function GetCachedTraitSortName(data, itemData)
    local cachedTrait = itemData.cached_traitName or data.cached_traitName
    if cachedTrait and cachedTrait ~= "-" and cachedTrait ~= "" then
        return cachedTrait
    end
    return nil
end

local function ResolveTraitSortType(data, itemData)
    local traitType = itemData.traitType or itemData.traitInformation or data.traitType
    if traitType and traitType ~= 0 then
        return traitType
    end

    local bagId = itemData.bagId or data.bagId
    local slotIndex = itemData.slotIndex or data.slotIndex
    if bagId ~= nil and slotIndex ~= nil and GetItemTrait then
        return GetItemTrait(bagId, slotIndex)
    end

    return nil
end

local function GetTraitSortNameFromType(traitType)
    if not traitType or traitType == ITEM_TRAIT_TYPE_NONE or traitType == 0 then
        return nil
    end

    local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
    if traitName == nil or traitName == "" then
        return nil
    end

    return traitName:upper()
end

local function CacheTraitSortName(data, itemData, traitName)
    itemData.cached_traitName = traitName
    if data ~= itemData then
        data.cached_traitName = traitName
    end
end

local function GetTraitSortValue(data)
    if not data then return nil end
    local itemData = data.dataSource or data

    local cachedTrait = GetCachedTraitSortName(data, itemData)
    if cachedTrait then
        return cachedTrait
    end

    local traitName = GetTraitSortNameFromType(ResolveTraitSortType(data, itemData))
    if traitName then
        CacheTraitSortName(data, itemData, traitName)
    end
    return traitName
end

--- Helper: Get stat sort value (alphabetical first, then numeric, blanks last)
--- @param data table Item data or dataSource wrapper
--- @return number priority Sort priority group (1=alpha, 2=numeric, 3=blank)
--- @return string|number value Sort value within group
local function GetStatSortValue(data)
    if not data then return 3, "" end
    local statValue = data.statValue
    if statValue == nil or statValue == "" or statValue == 0 or statValue == "-" then
        return 3, ""
    end
    local statStr = tostring(statValue)
    local numVal = tonumber(statStr)
    if numVal then
        return 2, numVal
    end
    if statStr:match("^%a") then
        return 1, statStr:upper()
    end
    return 2.5, statStr
end

--- Helper: Get value sort value (market price first, then vendor price)
--- @param data table Item data or dataSource wrapper
--- @return number price Market price or vendor price
local function GetValueSortValue(data)
    if not data then return 0 end
    local itemData = data.dataSource or data
    if itemData.cached_marketPrice then
        return itemData.cached_marketPrice
    end
    local marketIntegration = BETTERUI.CIM and BETTERUI.CIM.MarketIntegration
    if marketIntegration and type(marketIntegration.GetMarketPrice) == "function" then
        local itemLink = itemData.itemLink or itemData.cached_itemLink or
            (itemData.bagId and itemData.slotIndex and GetItemLink(itemData.bagId, itemData.slotIndex))
        if itemLink then
            local marketPrice = marketIntegration.GetMarketPrice(itemLink, itemData.stackCount or 1)
            if marketPrice and marketPrice > 0 then
                itemData.cached_marketPrice = marketPrice
                return marketPrice
            end
        end
    end
    local vendorPrice = itemData.stackSellPrice or 0
    itemData.cached_marketPrice = vendorPrice
    return vendorPrice
end

--- Creates sort comparator for a column with the specified direction
--- @param sortKey string The data field to sort by
--- @param ascending boolean Whether to sort ascending
--- @return fun(left: table, right: table): boolean comparator
local function CreateColumnSortComparator(sortKey, ascending)
    -- TRAIT: Alphabetical with blanks after "z"
    if sortKey == "trait" then
        return function(left, right)
            local leftVal = GetTraitSortValue(left)
            local rightVal = GetTraitSortValue(right)
            local nilResult = CompareNils(leftVal, rightVal, true)
            if nilResult ~= nil then return nilResult end
            if ascending then return leftVal < rightVal else return leftVal > rightVal end
        end
    end

    -- STAT: Alphabetical first, then numeric by value, special chars, blanks last
    if sortKey == "stat" then
        return function(left, right)
            local leftPrio, leftVal = GetStatSortValue(left)
            local rightPrio, rightVal = GetStatSortValue(right)
            if leftPrio == 3 and rightPrio == 3 then return false end
            if leftPrio == 3 then return false end
            if rightPrio == 3 then return true end
            if leftPrio ~= rightPrio then
                if ascending then return leftPrio < rightPrio else return leftPrio > rightPrio end
            end
            if ascending then return leftVal < rightVal else return leftVal > rightVal end
        end
    end

    -- VALUE: Market price first, then vendor price
    if sortKey == "value" then
        return function(left, right)
            local leftVal = GetValueSortValue(left)
            local rightVal = GetValueSortValue(right)
            if ascending then
                if leftVal == 0 and rightVal == 0 then return false end
                if leftVal == 0 then return true end
                if rightVal == 0 then return false end
            else
                if leftVal == 0 and rightVal == 0 then return false end
                if leftVal == 0 then return false end
                if rightVal == 0 then return true end
            end
            if ascending then return leftVal < rightVal else return leftVal > rightVal end
        end
    end

    -- Default comparator for NAME, TYPE, and other columns
    return function(left, right)
        local leftVal = left[sortKey]
        local rightVal = right[sortKey]
        local nilResult = CompareNils(leftVal, rightVal, ascending)
        if nilResult ~= nil then return nilResult end
        if type(leftVal) == "string" and type(rightVal) == "string" then
            if ascending then return leftVal < rightVal else return leftVal > rightVal end
        end
        if ascending then return leftVal < rightVal else return leftVal > rightVal end
    end
end

--- Initializes the header sort controller for this inventory instance.
function Class:InitializeHeaderSortController()
    if self.headerSortControllers then return end

    local controllerClass = BETTERUI.CIM.UI.HeaderSortController
    if not controllerClass then return end

    self.headerSortControllers = {}

    local INVENTORY_ITEM_LIST = "itemList"
    local INVENTORY_CRAFT_BAG_LIST = "craftBagList"

    self.headerSortControllers[INVENTORY_ITEM_LIST] = controllerClass:New(
        self.itemList,
        INVENTORY_SORT_COLUMNS,
        function(columnKey, direction, sortFn)
            self:OnHeaderSortChanged(INVENTORY_ITEM_LIST, columnKey, direction)
        end
    )

    self.headerSortControllers[INVENTORY_CRAFT_BAG_LIST] = controllerClass:New(
        self.craftBagList,
        INVENTORY_SORT_COLUMNS,
        function(columnKey, direction, sortFn)
            self:OnHeaderSortChanged(INVENTORY_CRAFT_BAG_LIST, columnKey, direction)
        end
    )

    self.horizontalMovementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)

    local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration
    if HeaderSortIntegration and HeaderSortIntegration.Install then
        HeaderSortIntegration.Install(self, {
            listFn = function() return self:GetCurrentList() end,
            keybindDescriptor = self.mainKeybindStripDescriptor,
            headerControllerFn = function()
                local listType = self.currentListType or INVENTORY_ITEM_LIST
                return self.headerSortControllers[listType]
            end,
            initControllerFn = function() self:InitializeHeaderSortController() end,
        })
    end

    self:LinkColumnLabels()
end

--- Links column header labels to the sort controller for visual feedback.
function Class:LinkColumnLabels()
    if not self.headerSortControllers then return end

    local headerControllerItem = self.headerSortControllers["itemList"]
    local headerControllerCraft = self.headerSortControllers["craftBagList"]

    if not headerControllerItem.SetColumnLabel then return end

    local COLUMN_LABEL_NAMES = {
        "Column1Label", -- NAME (index 1)
        "Column2Label", -- TYPE (index 2)
        "Column4Label", -- TRAIT (index 3)
        "Column6Label", -- STAT (index 4)
        "Column5Label", -- VALUE (index 5)
    }

    if self.header and self.header.columns and #self.header.columns > 0 then
        for i, labelControl in ipairs(self.header.columns) do
            if labelControl then
                headerControllerItem:SetColumnLabel(i, labelControl)
                headerControllerCraft:SetColumnLabel(i, labelControl)
            end
        end
        return
    end

    if self.header then
        local columnBar = self.header:GetNamedChild("ColumnBar")
        for i, labelName in ipairs(COLUMN_LABEL_NAMES) do
            local labelControl = self.header:GetNamedChild(labelName)
            if not labelControl and columnBar then
                labelControl = columnBar:GetNamedChild(labelName)
            end
            if labelControl then
                headerControllerItem:SetColumnLabel(i, labelControl)
                headerControllerCraft:SetColumnLabel(i, labelControl)
            end
        end
    end
end

--- Called when sort direction changes on a column.
function Class:OnHeaderSortChanged(listType, columnKey, direction)
    local SORT_DIRECTION = BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION

    local column = nil
    for _, col in ipairs(INVENTORY_SORT_COLUMNS) do
        if col.key == columnKey then
            column = col
            break
        end
    end

    if not column then return end

    local currentList = listType == "itemList" and self.itemList or self.craftBagList
    if not currentList then return end

    self.currentSortComparators = self.currentSortComparators or {}

    if direction == SORT_DIRECTION.NONE then
        self.currentSortComparators[listType] = nil
        if currentList.SetSortFunction then
            if listType == "craftBagList" then
                currentList:SetSortFunction(BETTERUI_CraftList_DefaultItemSortComparator)
            else
                currentList:SetSortFunction(nil)
            end
        end
    else
        local ascending = (direction == SORT_DIRECTION.ASCENDING)
        self.currentSortComparators[listType] = CreateColumnSortComparator(column.sortKey, ascending)
        if currentList.SetSortFunction then
            currentList:SetSortFunction(self.currentSortComparators[listType])
        end
    end

    -- Refresh the appropriate list to apply new sort
    if listType == "itemList" then
        self:RefreshItemList()
    elseif listType == "craftBagList" then
        self:RefreshCraftBagList()
    end
end

-- EnterHeaderSortMode and ExitHeaderSortMode are injected by CIM mixin.
-- See InitializeHeaderSortController where ApplyMixin is called.
