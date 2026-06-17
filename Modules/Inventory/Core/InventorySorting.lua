-- Modules/Inventory/Core/InventorySorting.lua
-- Header sort mode: column definitions, comparators, controller init, and column linking.
-- Extracted from InventoryClass.lua for maintainability.

local Class = BETTERUI.Inventory.Class
local NormalizeIdentityValue = BETTERUI.Inventory.Utils and BETTERUI.Inventory.Utils.NormalizeIdentityValue

local function GetSortDataSource(data)
    return data and (data.dataSource or data) or nil
end

-- Memoized stable-key cache. The key is a pure function of the resolved
-- (name, bagId, slotIndex, uniqueId) inputs; cache hits revalidate all four
-- inputs so a reused slot-data table never serves a stale key. Weak keys let
-- entry tables be collected between rebuilds. This avoids rebuilding the key
-- string (format + Id64 normalization) on every tie-break comparison, which
-- runs O(n log n) times during a sort.
local stableKeyCache = setmetatable({}, { __mode = "k" })

local function GetStableSortKey(data)
    local itemData = GetSortDataSource(data)
    if not itemData then
        return ""
    end
    local name = itemData.name or data.name or ""
    local bagId = itemData.bagId or data.bagId or ""
    local slotIndex = itemData.slotIndex or data.slotIndex or ""
    local uniqueId = itemData.uniqueId or data.uniqueId

    local cached = stableKeyCache[data]
    if cached and cached.name == name and cached.bagId == bagId
        and cached.slotIndex == slotIndex and cached.uniqueId == uniqueId then
        return cached.key
    end

    local uniqueIdString = uniqueId and ((NormalizeIdentityValue and NormalizeIdentityValue(uniqueId)) or tostring(uniqueId)) or ""
    local key = string.format("%s|%s|%s|%s",
        tostring(name),
        tostring(bagId),
        tostring(slotIndex),
        uniqueIdString)
    stableKeyCache[data] = {
        name = name,
        bagId = bagId,
        slotIndex = slotIndex,
        uniqueId = uniqueId,
        key = key,
    }
    return key
end

local function CompareStableFallback(left, right)
    local defaultComparator = BETTERUI.Inventory and BETTERUI.Inventory.DefaultSortComparator
    if type(defaultComparator) == "function" then
        if defaultComparator(left, right) then
            return true
        end
        if defaultComparator(right, left) then
            return false
        end
    end

    local leftKey = GetStableSortKey(left)
    local rightKey = GetStableSortKey(right)
    if leftKey == rightKey then
        return false
    end
    return leftKey < rightKey
end

local function GetInventoryListTypes()
    local inventoryConstants = BETTERUI.Inventory and BETTERUI.Inventory.CONST
    assert(inventoryConstants and inventoryConstants.LIST_TYPES,
        "InventorySorting requires BETTERUI.Inventory.CONST.LIST_TYPES")
    return inventoryConstants.LIST_TYPES
end

local function GetInventoryListType(key)
    return GetInventoryListTypes()[key]
end

-- HEADER SORT MODE
-- Column definitions for header sort navigation
-- Each column has a name (for display), key (internal), sortKey, and optional defaultDirection
--- @class SortColumnDef
--- @field name string Display name ("NAME", "TYPE", etc.)
--- @field key string Internal identifier
--- @field sortKey string Data field used for comparisons
--- @field defaultDirection? string "ascending" or "descending"

--- @type BetterUIHeaderSortColumnDef[]
local INVENTORY_SORT_COLUMNS = {
    { name = "NAME",  key = "name",  sortKey = "name" },
    { name = "TYPE",  key = "type",  sortKey = "bestGamepadItemCategoryName" },
    { name = "TRAIT", key = "trait", sortKey = "trait" },
    { name = "STAT",  key = "stat",  sortKey = "stat" },
    { name = "VALUE", key = "value", sortKey = "value", defaultDirection = "descending" },
}

---@param instance BETTERUI.Inventory.Class
---@return BetterUIHeaderSortInstallOptions
local function BuildInventoryHeaderSortInstallOptions(instance)
    return {
        listFn = function()
            return instance:GetCurrentList()
        end,
        keybinds = {
            mainDescriptor = instance.mainKeybindStripDescriptor,
        },
        controllerContract = {
            field = "headerSortController",
            resolve = function()
                local listType = instance.currentListType or GetInventoryListType("ITEM")
                return instance.headerSortControllers[listType]
            end,
            initialize = function()
                instance:InitializeHeaderSortController()
            end,
        },
        callbacks = {
            -- Suspend the underlying list while header-sort owns the keybind strip. With the list
            -- still active, the first sort press (A -> ToggleSort -> RefreshItemList ->
            -- commit/reselect) re-establishes the list's native keybind context and clobbers the
            -- header-sort A/Back keybinds, leaving only Back/Clear-sort -- and Back then falls
            -- through to the scene (exiting the inventory). Deactivating the list keeps the
            -- header-sort descriptor as the sole owner of the strip until exit.
            onEnterHeaderMode = function(owner)
                local list = owner.GetCurrentList and owner:GetCurrentList()
                if list and list.Deactivate then
                    list:Deactivate()
                end
            end,
            onExitHeaderMode = function(owner)
                local list = owner.GetCurrentList and owner:GetCurrentList()
                if list and list.Activate then
                    list:Activate()
                end
            end,
        },
    }
end

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

-- Stat sort values resolve through the shared default
-- (BETTERUI.CIM.SortManager.GetStatSortValue).

--- Helper: Get value sort value (market price first, then vendor price)
--- The cache holds the UNIT price so stack-size changes between refreshes
--- cannot leave a stale stack total behind; InvalidateItemMeta clears it.
--- @param data table Item data or dataSource wrapper
--- @return number price Market price or vendor price for the current stack
local function GetValueSortValue(data)
    if not data then return 0 end
    local itemData = data.dataSource or data
    local stackCount = itemData.stackCount or 1
    if stackCount <= 0 then stackCount = 1 end
    if itemData.cached_marketUnitPrice then
        return itemData.cached_marketUnitPrice * stackCount
    end
    local marketIntegration = BETTERUI.CIM and BETTERUI.CIM.MarketIntegration
    if marketIntegration and type(marketIntegration.GetMarketPrice) == "function" then
        local itemLink = itemData.itemLink or itemData.cached_itemLink or
            (itemData.bagId and itemData.slotIndex and GetItemLink(itemData.bagId, itemData.slotIndex))
        if itemLink then
            local marketUnitPrice = marketIntegration.GetMarketPrice(itemLink, 1)
            if marketUnitPrice and marketUnitPrice > 0 then
                itemData.cached_marketUnitPrice = marketUnitPrice
                return marketUnitPrice * stackCount
            end
        end
    end
    local vendorStackPrice = itemData.stackSellPrice or 0
    itemData.cached_marketUnitPrice = vendorStackPrice / stackCount
    return vendorStackPrice
end

--- Creates a sort comparator for a column via the shared CIM factory,
--- wiring inventory-specific value getters and the stable tie-breaker.
--- @param sortKey string The data field to sort by
--- @param ascending boolean Whether to sort ascending
--- @return fun(left: table, right: table): boolean comparator
local function CreateColumnSortComparator(sortKey, ascending)
    return BETTERUI.CIM.SortManager.CreateColumnSortComparator(sortKey, ascending, {
        getTraitValue = GetTraitSortValue,
        getValueValue = GetValueSortValue,
        tieBreak = CompareStableFallback,
    })
end

--- Initializes the header sort controller for this inventory instance.
function Class:InitializeHeaderSortController()
    if self.headerSortControllers then return end

    local controllerClass = BETTERUI.CIM.UI.HeaderSortController
    if not controllerClass then return end

    local inventoryItemList = GetInventoryListType("ITEM")
    local inventoryCraftBagList = GetInventoryListType("CRAFT_BAG")

    self.headerSortControllers = {}

    self.headerSortControllers[inventoryItemList] = controllerClass:New(
        self.itemList,
        INVENTORY_SORT_COLUMNS,
        function(columnKey, direction, sortFn)
            self:OnHeaderSortChanged(inventoryItemList, columnKey, direction)
        end
    )

    self.headerSortControllers[inventoryCraftBagList] = controllerClass:New(
        self.craftBagList,
        INVENTORY_SORT_COLUMNS,
        function(columnKey, direction, sortFn)
            self:OnHeaderSortChanged(inventoryCraftBagList, columnKey, direction)
        end
    )

    self.horizontalMovementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)

    local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration
    if HeaderSortIntegration and HeaderSortIntegration.Install then
        HeaderSortIntegration.Install(self, BuildInventoryHeaderSortInstallOptions(self))
    end

    self:LinkColumnLabels()
end

--- Links column header labels to the sort controller for visual feedback.
function Class:LinkColumnLabels()
    if not self.headerSortControllers then return end

    local inventoryItemList = GetInventoryListType("ITEM")
    local inventoryCraftBagList = GetInventoryListType("CRAFT_BAG")
    local headerControllerItem = self.headerSortControllers[inventoryItemList]
    local headerControllerCraft = self.headerSortControllers[inventoryCraftBagList]

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
    local inventoryItemList = GetInventoryListType("ITEM")
    local inventoryCraftBagList = GetInventoryListType("CRAFT_BAG")

    local column = nil
    for _, col in ipairs(INVENTORY_SORT_COLUMNS) do
        if col.key == columnKey then
            column = col
            break
        end
    end

    if not column then return end

    local currentList
    if listType == inventoryItemList then
        currentList = self.itemList
    elseif listType == inventoryCraftBagList then
        currentList = self.craftBagList
    else
        return
    end
    if not currentList then return end

    self.currentSortComparators = self.currentSortComparators or {}

    if direction == SORT_DIRECTION.NONE then
        self.currentSortComparators[listType] = nil
        if currentList.SetSortFunction then
            if listType == inventoryCraftBagList then
                currentList:SetSortFunction(BETTERUI.Inventory.CraftListDefaultSortComparator)
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
    if listType == inventoryItemList then
        self:RefreshItemList()
    elseif listType == inventoryCraftBagList then
        self:RefreshCraftBagList()
    end
end

-- EnterHeaderSortMode and ExitHeaderSortMode are injected by CIM mixin.
-- See InitializeHeaderSortController where ApplyMixin is called.
