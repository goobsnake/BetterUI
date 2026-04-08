--[[
File: Modules/Vendor/Components/BuyComponent.lua
Purpose: Buy tab component for the Vendor module.

Handles listing store items and purchasing them.
Uses GetNumStoreItems/GetStoreEntryInfo to populate the list.
]]

local Vendor = BETTERUI.Vendor

---@class VendorComponent
---@field Activate fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field Deactivate fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field GetPrimaryActionName fun(self: VendorComponent, vendorInstance?: BETTERUI.Vendor.Class): string
---@field IsPrimaryActionEnabled fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class): boolean
---@field OnPrimaryAction fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field BuildList fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)

-- COMPONENT TABLE
Vendor.BuyComponent = {}
local Buy = Vendor.BuyComponent

local BUY_CATEGORY_DEFS = {
    {
        key = "all",
        nameStringId = "SI_BETTERUI_INV_ITEM_ALL",
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
    },
    {
        key = "weapons",
        nameStringId = "SI_BETTERUI_INV_ITEM_WEAPONS",
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds",
        filterType = ITEMFILTERTYPE_WEAPONS,
    },
    {
        key = "apparel",
        nameStringId = "SI_BETTERUI_INV_ITEM_APPAREL",
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds",
        filterType = ITEMFILTERTYPE_ARMOR,
    },
    {
        key = "jewelry",
        nameStringId = "SI_BETTERUI_INV_ITEM_JEWELRY",
        iconFile = "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds",
        filterType = ITEMFILTERTYPE_JEWELRY,
    },
    {
        key = "consumable",
        nameStringId = "SI_BETTERUI_INV_ITEM_CONSUMABLE",
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds",
        filterType = ITEMFILTERTYPE_CONSUMABLE,
    },
    {
        key = "materials",
        nameStringId = "SI_BETTERUI_INV_ITEM_MATERIALS",
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds",
        filterType = ITEMFILTERTYPE_CRAFTING,
    },
    {
        key = "furnishing",
        nameStringId = "SI_BETTERUI_INV_ITEM_FURNISHING",
        iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds",
        filterType = ITEMFILTERTYPE_FURNISHING,
    },
    {
        key = "misc",
        nameStringId = "SI_BETTERUI_INV_ITEM_MISC",
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds",
    },
}

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

local function BuildStoreRows()
    local rows = {}

    if type(ZO_StoreManager_GetStoreItems) == "function" then
        local storeItems = ZO_StoreManager_GetStoreItems() or {}
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
                    itemLink          = GetStoreItemLink(item.slotIndex),
                    filterData        = item.filterData or {},
                }
            end
        end
        if #rows > 0 then
            return rows
        end
    end

    local numItems = GetNumStoreItems and GetNumStoreItems() or 0
    if numItems <= 0 then
        return rows
    end

    for entryIndex = 1, numItems do
        local icon, name, stack, price, sellPrice, meetsReqsToBuy, _, displayQuality, _, currencyType1, currencyQuantity1,
            _, _, entryType = GetStoreEntryInfo(entryIndex)

        if name and name ~= "" then
            local itemLink = GetStoreItemLink(entryIndex)
            local filterData = GetStoreFilterData(entryIndex)
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
            }
        end
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
    if vendorInstance and vendorInstance.ApplyNativeStoreMode then
        vendorInstance:ApplyNativeStoreMode(Vendor.MODE.BUY)
    end
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:Deactivate(vendorInstance)
    -- No cleanup needed for Buy mode
end

-- PRIMARY ACTION

---@return string name Localized action label
function Buy:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_TRADING_HOUSE_PURCHASE"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if a buy action is possible
function Buy:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Check affordability using stored price
    local price = ds.price or 0
    local currencyType = ds.currencyType or CURT_MONEY
    return vendorInstance:CanAfford(price, currencyType)
        and vendorInstance:HasInventorySpace()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local entryIndex = ds.entryIndex or ds.slotIndex
    if not entryIndex then return end

    -- Validate affordability one more time
    local price = ds.price or 0
    local currencyType = ds.currencyType or CURT_MONEY
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
    for _, row in ipairs(rows) do
        if MatchesCategory(row, activeCategory) then
            local bestCategoryName = GetStoreItemCategoryName(row.itemLink)
            local itemData = {
                entryIndex        = row.entryIndex,
                slotIndex         = row.slotIndex or row.entryIndex,
                name              = zo_strformat(SI_TOOLTIP_ITEM_NAME, row.name) or row.name,
                icon              = row.icon,
                stackCount        = row.stack or 1,
                stack             = row.stack or 1,
                price             = row.currencyQuantity1 or row.price or 0,
                currencyType      = row.currencyType1 or CURT_MONEY,
                currencyType1     = row.currencyType1 or CURT_MONEY,
                currencyQuantity1 = row.currencyQuantity1 or row.price or 0,
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
                bestGamepadItemCategoryName = bestCategoryName,
                statValue         = "",
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
