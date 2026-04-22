--[[
File: Modules/Vendor/Components/BuyComponent.lua
Purpose: Buy tab component for the Vendor module.

Handles listing store items and purchasing them.
Uses GetNumStoreItems/GetStoreEntryInfo to populate the list.
]]

local Vendor = BETTERUI.Vendor

local function GetFocusedListTargetData(list)
    local getTargetData = BETTERUI.CIM and BETTERUI.CIM.Utils
        and (BETTERUI.CIM.Utils.GetListTargetData or BETTERUI.CIM.Utils.SafeGetTargetData)
    if type(getTargetData) ~= "function" then
        return nil
    end
    return getTargetData(list)
end

---@class VendorComponent
---@field Activate fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field Deactivate fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field GetPrimaryActionName fun(self: VendorComponent, vendorInstance?: BETTERUI.Vendor.Class): string
---@field IsPrimaryActionEnabled fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class): boolean
---@field OnPrimaryAction fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field BuildList fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)

-- COMPONENT TABLE
Vendor.BuyComponent = Vendor.BuyComponent or {}
local Buy = Vendor.BuyComponent

local BUY_CATEGORY_DEFS = BETTERUI.CIM.ItemTaxonomy.VENDOR_BUY_CATEGORY_DEFS

local function GetStoreFilterData(entryIndex)
    if type(GetStoreEntryTypeInfo) ~= "function" then
        return {}
    end
    return { GetStoreEntryTypeInfo(entryIndex) }
end

local function MatchesFilterType(filterData, filterType)
    if not filterType then
        return false
    end
    for _, value in ipairs(filterData or {}) do
        if value == filterType then
            return true
        end
    end
    return false
end

local function MatchesCategory(itemData, category)
    if not category or category.key == "all" then
        return true
    end

    if category.filterType then
        return MatchesFilterType(itemData.filterData, category.filterType)
    end

    if category.key == "misc" then
        for i = 2, #BUY_CATEGORY_DEFS - 1 do
            local def = BUY_CATEGORY_DEFS[i]
            if MatchesFilterType(itemData.filterData, def.filterType) then
                return false
            end
        end
        return true
    end

    return true
end

local ExecuteSafely = Vendor.ExecuteSafely

local function BuildStoreRowFromDataSource(ds)
    if not ds then
        return nil
    end

    local slotIndex = ds.slotIndex or ds.entryIndex
    if not slotIndex then
        return nil
    end

    local name = ds.name or ds.text
    if not name or name == "" then
        return nil
    end

    return {
        entryIndex        = ds.entryIndex or slotIndex,
        slotIndex         = slotIndex,
        name              = name,
        icon              = ds.icon or ds.iconFile,
        stack             = ds.stack or ds.stackCount or 1,
        price             = ds.price or 0,
        sellPrice         = ds.sellPrice or ds.price or 0,
        meetsReqsToBuy    = ds.meetsRequirementsToBuy,
        requiredToBuyErrorText = ds.requiredToBuyErrorText,
        meetsRequirementsToEquip = ds.meetsRequirementsToEquip,
        displayQuality    = ds.displayQuality or ds.quality,
        currencyType1     = ds.currencyType1,
        currencyQuantity1 = ds.currencyQuantity1,
        currencyType2     = ds.currencyType2,
        currencyQuantity2 = ds.currencyQuantity2,
        entryType         = ds.entryType,
        itemLink          = ds.itemLink or ((GetStoreItemLink and slotIndex) and GetStoreItemLink(slotIndex)) or nil,
        filterData        = ds.filterData or GetStoreFilterData(slotIndex),
        statValue         = ds.statValue,
        bestGamepadItemCategoryName = ds.bestGamepadItemCategoryName,
    }
end

local function BuildRowsFromNativeBuyComponent()
    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    local buyMode = rawget(_G, "ZO_MODE_STORE_BUY")
    if not (storeManager and buyMode and storeManager.components) then
        return {}
    end

    local buyComponent = storeManager.components[buyMode]
    local buyList = buyComponent and buyComponent.list
    if not buyList then
        return {}
    end

    if buyList.UpdateList then
        local ok = ExecuteSafely("Vendor.Buy:NativeBuyListUpdate", buyList.UpdateList, buyList)
        if not ok then
            return {}
        end
    end

    local rows = {}
    for _, entryData in ipairs(buyList.dataList or {}) do
        local ds = entryData and (entryData.dataSource or entryData)
        local row = BuildStoreRowFromDataSource(ds)
        if row then
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function BuildRowsFromStoreManager()
    if type(ZO_StoreManager_GetStoreItems) ~= "function" then
        return {}
    end

    local ok, storeItems = ExecuteSafely("Vendor.Buy:StoreManagerItems", ZO_StoreManager_GetStoreItems)
    if not ok then
        return {}
    end
    storeItems = storeItems or {}

    local rows = {}
    for _, item in ipairs(storeItems) do
        if item and item.name and item.name ~= "" then
            rows[#rows + 1] = {
                entryIndex        = item.slotIndex,
                slotIndex         = item.slotIndex,
                name              = item.name,
                icon              = item.icon,
                stack             = item.stack,
                price             = item.price,
                sellPrice         = item.sellPrice,
                meetsReqsToBuy    = item.meetsRequirementsToBuy,
                requiredToBuyErrorText = item.requiredToBuyErrorText,
                meetsRequirementsToEquip = item.meetsRequirementsToEquip,
                displayQuality    = item.displayQuality or item.quality,
                currencyType1     = item.currencyType1,
                currencyQuantity1 = item.currencyQuantity1,
                currencyType2     = item.currencyType2,
                currencyQuantity2 = item.currencyQuantity2,
                entryType         = item.entryType,
                itemLink          = item.itemLink or GetStoreItemLink(item.slotIndex),
                filterData        = item.filterData or {},
                statValue         = item.statValue,
                bestGamepadItemCategoryName = item.bestGamepadItemCategoryName,
            }
        end
    end
    return rows
end

local function BuildRowsFromStoreCount()
    local numItems = (type(GetNumStoreItems) == "function") and GetNumStoreItems() or 0
    if numItems <= 0 then
        return {}
    end

    local rows = {}
    for entryIndex = 1, numItems do
        local icon, name, stack, price, sellPrice, meetsReqsToBuy, _, displayQuality, _, currencyType1, currencyQuantity1,
            _, _, entryType = GetStoreEntryInfo(entryIndex)

        if name and name ~= "" then
            local itemLink = GetStoreItemLink(entryIndex)
            local filterData = GetStoreFilterData(entryIndex)
            local statValue = (type(GetStoreEntryStatValue) == "function") and GetStoreEntryStatValue(entryIndex) or ""
            rows[#rows + 1] = {
                entryIndex        = entryIndex,
                slotIndex         = entryIndex,
                name              = name,
                icon              = icon,
                stack             = stack,
                price             = price,
                sellPrice         = sellPrice,
                meetsReqsToBuy    = meetsReqsToBuy,
                requiredToBuyErrorText = nil,
                meetsRequirementsToEquip = true,
                displayQuality    = displayQuality,
                currencyType1     = currencyType1,
                currencyQuantity1 = currencyQuantity1,
                currencyType2     = nil,
                currencyQuantity2 = nil,
                entryType         = entryType,
                itemLink          = itemLink,
                filterData        = filterData,
                statValue         = statValue,
            }
        end
    end
    return rows
end

---@param vendorInstance BETTERUI.Vendor.Class|nil
---@return table|nil
local function GetFocusedStoreData(vendorInstance)
    local list = vendorInstance and vendorInstance.list
    if not list then
        return nil
    end

    return GetFocusedListTargetData(list)
end

local function BuildRowsFromIndexProbe()
    if type(GetStoreEntryInfo) ~= "function" then
        return {}
    end

    local rows = {}
    local misses = 0
    local hadAny = false

    -- Defensive fallback: some clients report 0 from GetNumStoreItems while entries are still queryable.
    for entryIndex = 1, 300 do
        local icon, name, stack, price, sellPrice, meetsReqsToBuy, _, displayQuality, _, currencyType1, currencyQuantity1,
            _, _, entryType = GetStoreEntryInfo(entryIndex)

        if name and name ~= "" then
            hadAny = true
            misses = 0
            local itemLink = (type(GetStoreItemLink) == "function") and GetStoreItemLink(entryIndex) or nil
            local filterData = GetStoreFilterData(entryIndex)
            local statValue = (type(GetStoreEntryStatValue) == "function") and GetStoreEntryStatValue(entryIndex) or ""
            rows[#rows + 1] = {
                entryIndex        = entryIndex,
                slotIndex         = entryIndex,
                name              = name,
                icon              = icon,
                stack             = stack,
                price             = price,
                sellPrice         = sellPrice,
                meetsReqsToBuy    = meetsReqsToBuy,
                requiredToBuyErrorText = nil,
                meetsRequirementsToEquip = true,
                displayQuality    = displayQuality,
                currencyType1     = currencyType1,
                currencyQuantity1 = currencyQuantity1,
                currencyType2     = nil,
                currencyQuantity2 = nil,
                entryType         = entryType,
                itemLink          = itemLink,
                filterData        = filterData,
                statValue         = statValue,
            }
        elseif hadAny then
            misses = misses + 1
            if misses >= 25 then
                break
            end
        end
    end

    return rows
end

local function BuildStoreRows()
    if BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
        BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
    end

    local rows = BuildRowsFromNativeBuyComponent()
    if #rows > 0 then
        return rows
    end

    rows = BuildRowsFromStoreManager()
    if #rows > 0 then
        return rows
    end

    rows = BuildRowsFromStoreCount()
    if #rows > 0 then
        return rows
    end

    rows = BuildRowsFromIndexProbe()
    if #rows > 0 then
        return rows
    end

    return rows
end

local function GetStoreItemCategoryName(itemLink)
    if not itemLink or itemLink == "" then
        return ""
    end

    if GetItemLinkItemType then
        local itemType = GetItemLinkItemType(itemLink)
        if itemType and itemType ~= ITEMTYPE_NONE then
            return GetString("SI_ITEMTYPE", itemType)
        end
    end

    return ""
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return table[]
function Buy:GetCategories(vendorInstance)
    if vendorInstance and vendorInstance.ApplyNativeStoreMode then
        vendorInstance:ApplyNativeStoreMode(Vendor.MODE.BUY)
    end

    local rows = BuildStoreRows()
    local totalCount = #rows
    local categories = {}

    for _, def in ipairs(BUY_CATEGORY_DEFS) do
        local count = 0
        if def.key == "all" then
            count = totalCount
        else
            for _, row in ipairs(rows) do
                if MatchesCategory(row, def) then
                    count = count + 1
                end
            end
        end

        if def.key == "all" or count > 0 then
            categories[#categories + 1] = {
                key = def.key,
                name = GetString(rawget(_G, def.nameStringId) or def.nameStringId),
                iconFile = def.iconFile,
                filterType = def.filterType,
                itemCount = count,
            }
        end
    end

    if #categories == 0 then
        categories[1] = {
            key = "all",
            name = GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_ALL") or "SI_BETTERUI_INV_ITEM_ALL"),
            iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
            itemCount = 0,
        }
    end

    return categories
end

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:Activate(vendorInstance)
    vendorInstance:RefreshList()

    -- Opening/switching to Buy can race native store population.
    -- Run one deferred pass after mode settles so rows are consistently visible.
    if BETTERUI.Vendor and BETTERUI.Vendor.Tasks then
        BETTERUI.Vendor.Tasks:Cancel("buyActivateRefresh")
        BETTERUI.Vendor.Tasks:Schedule("buyActivateRefresh", 120, function()
            if Vendor.ShouldAbortDeferredVendorRefresh
                and Vendor.ShouldAbortDeferredVendorRefresh(vendorInstance, Vendor.MODE.BUY) then
                return
            end
            if vendorInstance.ApplyNativeStoreMode then
                vendorInstance:ApplyNativeStoreMode(Vendor.MODE.BUY)
            end
            vendorInstance:RefreshList()
        end)
    end
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:Deactivate(vendorInstance)
    -- No cleanup needed for Buy mode
end

-- PRIMARY ACTION

---@return string name Localized action label
function Buy:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_BUY"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if a buy action is possible
function Buy:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = GetFocusedStoreData(vendorInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Check affordability using stored price
    local price = ds.price or ds.currencyQuantity1 or 0
    local currencyType = ds.currencyType or ds.currencyType1 or CURT_MONEY
    if currencyType == CURT_NONE then
        currencyType = CURT_MONEY
    end
    return vendorInstance:CanAfford(price, currencyType)
        and vendorInstance:HasInventorySpace()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:OnPrimaryAction(vendorInstance)
    local selectedData = GetFocusedStoreData(vendorInstance)
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local entryIndex = ds.entryIndex or ds.slotIndex
    if not entryIndex then return end

    -- Validate affordability one more time
    local price = ds.price or ds.currencyQuantity1 or 0
    local currencyType = ds.currencyType or ds.currencyType1 or CURT_MONEY
    if currencyType == CURT_NONE then
        currencyType = CURT_MONEY
    end
    if not vendorInstance:CanAfford(price, currencyType) then
        BETTERUI.CIM.UserAlertText("Buy:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    if not vendorInstance:HasInventorySpace() then
        BETTERUI.CIM.UserAlertText("Buy:CannotCarry",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY")))
        return
    end

    -- Quantity = 1 for normal purchase (stack purchase would need spinner)
    BuyStoreItem(entryIndex, 1)
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    if vendorInstance and vendorInstance.ApplyNativeStoreMode then
        vendorInstance:ApplyNativeStoreMode(Vendor.MODE.BUY)
    end

    local rows = BuildStoreRows()
    if #rows == 0 then return end

    local activeCategory = vendorInstance:GetCurrentCategory()
    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil
    for _, row in ipairs(rows) do
        if MatchesCategory(row, activeCategory)
            and (not Vendor.MatchesSearchQuery or Vendor.MatchesSearchQuery(searchQuery, row.name))
        then
            local bestCategoryName = GetStoreItemCategoryName(row.itemLink)
            local currencyType1 = row.currencyType1 or CURT_MONEY
            local currencyQuantity1 = row.currencyQuantity1
            local price = row.price or 0
            if currencyType1 ~= CURT_MONEY and currencyType1 ~= CURT_NONE then
                if currencyQuantity1 and currencyQuantity1 > 0 then
                    price = currencyQuantity1
                end
            elseif (not price or price <= 0) and currencyQuantity1 and currencyQuantity1 > 0 then
                price = currencyQuantity1
            end
            local itemData = {
                entryIndex        = row.entryIndex,
                slotIndex         = row.slotIndex or row.entryIndex,
                name              = zo_strformat(SI_TOOLTIP_ITEM_NAME, row.name) or row.name,
                icon              = row.icon,
                stackCount        = row.stack or 1,
                stack             = row.stack or 1,
                price             = price,
                currencyType      = currencyType1,
                currencyType1     = currencyType1,
                currencyQuantity1 = currencyQuantity1 or price,
                currencyType2     = row.currencyType2,
                currencyQuantity2 = row.currencyQuantity2,
                sellPrice         = row.sellPrice or 0,
                meetsRequirements = row.meetsReqsToBuy,
                meetsRequirementsToBuy = row.meetsReqsToBuy,
                meetsRequirementsToEquip = row.meetsRequirementsToEquip,
                requiredToBuyErrorText = row.requiredToBuyErrorText,
                quality           = row.displayQuality or ITEM_DISPLAY_QUALITY_NORMAL,
                displayQuality    = row.displayQuality or ITEM_DISPLAY_QUALITY_NORMAL,
                itemLink          = row.itemLink,
                entryType         = row.entryType,
                filterData        = row.filterData,
                -- Trait/type info
                bestGamepadItemCategoryName = row.bestGamepadItemCategoryName or bestCategoryName,
                statValue         = row.statValue or "",
            }

            -- Get trait info if available
            if row.itemLink and GetItemLinkTraitInfo then
                local traitType = GetItemLinkTraitInfo(row.itemLink)
                if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                    itemData.traitName = GetString("SI_ITEMTRAITTYPE", traitType)
                end
            end

            local entry = ZO_GamepadEntryData:New(itemData.name, itemData.icon)
            entry:SetDataSource(itemData)
            entry.narrationText = function() return itemData.name end

            -- Set quality color
            if itemData.quality then
                local r, g, b = GetItemQualityColor(itemData.quality):UnpackRGBA()
                entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
            end

            list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
        end
    end
end
