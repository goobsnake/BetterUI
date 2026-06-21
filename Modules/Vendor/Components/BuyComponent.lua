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
        -- Misc means "matches none of the keyed filter categories"; filter by
        -- key instead of assuming all/misc sit at fixed positions in the defs.
        for _, def in ipairs(BUY_CATEGORY_DEFS) do
            if def.key ~= "all" and def.key ~= "misc" and def.filterType
                and MatchesFilterType(itemData.filterData, def.filterType) then
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
        -- U50 GetStoreEntryInfo return order (ESOUIDocumentation.txt:15973):
        -- 1 icon, 2 name, 3 stack, 4 price, 5 sellPrice, 6 meetsRequirementsToBuy,
        -- 7 meetsRequirementsToEquip, 8 displayQuality, 9 questNameColor,
        -- 10 currencyType1, 11 currencyQuantity1, 12 currencyType2,
        -- 13 currencyQuantity2, 14 entryType, 15 buyStoreFailure, 16 buyErrorStringId.
        local icon, name, stack, price, sellPrice, meetsReqsToBuy, meetsReqsToEquip, displayQuality, _, currencyType1, currencyQuantity1,
            currencyType2, currencyQuantity2, entryType, buyStoreFailure, buyErrorStringId = GetStoreEntryInfo(entryIndex)

        if name and name ~= "" then
            local itemLink = GetStoreItemLink(entryIndex)
            local filterData = GetStoreFilterData(entryIndex)
            local statValue = (type(GetStoreEntryStatValue) == "function") and GetStoreEntryStatValue(entryIndex) or ""
            -- Mirror ZO_StoreManager_GetStoreItems: derive a user-facing lock
            -- reason from the store-failure/error data when the entry cannot be
            -- bought (missing requirements, already-owned collectible, ...).
            local requiredToBuyErrorText
            if not meetsReqsToBuy and type(ZO_StoreManager_GetRequiredToBuyErrorText) == "function" then
                requiredToBuyErrorText = ZO_StoreManager_GetRequiredToBuyErrorText(buyStoreFailure, buyErrorStringId or 0, currencyType1)
            end
            rows[#rows + 1] = {
                entryIndex        = entryIndex,
                slotIndex         = entryIndex,
                name              = name,
                icon              = icon,
                stack             = stack,
                price             = price,
                sellPrice         = sellPrice,
                meetsReqsToBuy    = meetsReqsToBuy,
                buyStoreFailure   = buyStoreFailure,
                buyErrorStringId  = buyErrorStringId,
                requiredToBuyErrorText = requiredToBuyErrorText,
                meetsRequirementsToEquip = meetsReqsToEquip ~= false,
                displayQuality    = displayQuality,
                currencyType1     = currencyType1,
                currencyQuantity1 = currencyQuantity1,
                -- Returns 12-13 of GetStoreEntryInfo; required by the
                -- secondary-currency affordability checks.
                currencyType2     = currencyType2,
                currencyQuantity2 = currencyQuantity2,
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
            currencyType2, currencyQuantity2, entryType = GetStoreEntryInfo(entryIndex)

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
                -- Returns 12-13 of GetStoreEntryInfo; required by the
                -- secondary-currency affordability checks.
                currencyType2     = currencyType2,
                currencyQuantity2 = currencyQuantity2,
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

-- One refresh pass calls GetCategories and BuildList back to back, each of
-- which needs the store rows; cache the built rows per frame so the
-- multi-source build (and its index probe fallback) runs once per refresh.
local cachedStoreRows = nil
local cachedStoreRowsFrameMs = nil

local function GetStoreRowsCached()
    local frameMs = (type(GetFrameTimeMilliseconds) == "function") and GetFrameTimeMilliseconds() or nil
    if frameMs and cachedStoreRows and cachedStoreRowsFrameMs == frameMs then
        return cachedStoreRows
    end

    local rows = BuildStoreRows()
    if frameMs then
        cachedStoreRows = rows
        cachedStoreRowsFrameMs = frameMs
    else
        -- No frame clock (test harness): never reuse stale rows.
        cachedStoreRows = nil
        cachedStoreRowsFrameMs = nil
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

    local rows = GetStoreRowsCached()
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
    -- Drop the per-frame store-row cache so a stale row set can never be
    -- reused after the store closes or the Buy mode deactivates.
    cachedStoreRows = nil
    cachedStoreRowsFrameMs = nil
end

-- PRIMARY ACTION

---@return string name Localized action label
function Buy:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_BUY"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@param ds table Store entry data source
---@return boolean affordable True if all currencies for the entry are covered
local function CanAffordStoreEntry(vendorInstance, ds)
    -- Gold and alt-currency charges are independent: alt-currency entries
    -- report price == 0 (not nil), so each charge is checked on its own.
    local price = ds.price or 0
    if price > 0 then
        local currencyType = ds.currencyType or CURT_MONEY
        if currencyType == CURT_NONE then
            currencyType = CURT_MONEY
        end
        if not vendorInstance:CanAfford(price, currencyType) then
            return false
        end
    end

    local price1 = ds.currencyQuantity1 or 0
    local currencyType1 = ds.currencyType1
    if price1 > 0 and currencyType1 and currencyType1 ~= CURT_NONE
        and not vendorInstance:CanAfford(price1, currencyType1) then
        return false
    end

    -- Some store entries also charge a secondary currency; every charge must
    -- be affordable for the purchase to succeed.
    local price2 = ds.currencyQuantity2 or 0
    local currencyType2 = ds.currencyType2
    if price2 > 0 and currencyType2 and currencyType2 ~= CURT_NONE then
        return vendorInstance:CanAfford(price2, currencyType2)
    end
    return true
end

--- Clamp a purchase request to what is actually available and affordable.
---@param requested integer Quantity the user/UI asked for
---@param stackAvailable integer Maximum stack the store offers
---@param unitPrice number Cost per unit (0 for free items)
---@param money number Player's current balance for the item's currency
---@return integer quantity Final clamped quantity (0 if unaffordable or invalid)
local function ClampPurchaseQuantity(requested, stackAvailable, unitPrice, money)
    requested = tonumber(requested) or 0
    stackAvailable = tonumber(stackAvailable) or 0
    unitPrice = tonumber(unitPrice) or 0
    money = tonumber(money) or 0

    if requested <= 0 or stackAvailable <= 0 then
        return 0
    end

    local maxByStack = math.max(1, stackAvailable)
    local maxByMoney = (unitPrice <= 0) and maxByStack or math.floor(money / unitPrice)
    local maxAffordable = math.max(0, math.min(maxByStack, maxByMoney))

    return math.min(requested, maxAffordable)
end

Vendor.ClampPurchaseQuantity = Vendor.ClampPurchaseQuantity or ClampPurchaseQuantity

--- Resolve the effective unit price and currency type for a store entry.
---@param ds table Store entry data source
---@return number unitPrice
---@return number currencyType
local function GetStoreItemUnitPrice(ds)
    local unitPrice = ds.price or 0
    local currencyType = ds.currencyType or CURT_MONEY

    -- Alt-currency entries report price == 0 and store the cost in currencyQuantity1.
    if unitPrice <= 0 and ds.currencyQuantity1 and ds.currencyQuantity1 > 0 then
        unitPrice = ds.currencyQuantity1
        currencyType = ds.currencyType1 or CURT_MONEY
    end

    if currencyType == CURT_NONE then
        currencyType = CURT_MONEY
    end

    return unitPrice, currencyType
end

--- Player balance for a given currency, falling back to GetCurMoney when
--- GetCurrencyAmount is unavailable.
---@param currencyType number
---@return number money
local function GetPlayerMoneyForCurrency(currencyType)
    if type(GetCurrencyAmount) == "function" then
        local location = (type(GetCurrencyPlayerStoredLocation) == "function"
            and GetCurrencyPlayerStoredLocation(currencyType))
            or CURRENCY_LOCATION_CHARACTER
        return GetCurrencyAmount(currencyType, location) or 0
    end
    if type(GetCurMoney) == "function" then
        return GetCurMoney() or 0
    end
    return 0
end

---@param vendorInstance BETTERUI.Vendor.Class
---@param ds table Store entry data source
---@param quantity integer
---@return boolean affordable True if all currencies for the requested quantity are covered
local function CanAffordStoreEntryQuantity(vendorInstance, ds, quantity)
    quantity = tonumber(quantity) or 1

    local price = (ds.price or 0) * quantity
    if price > 0 then
        local currencyType = ds.currencyType or CURT_MONEY
        if currencyType == CURT_NONE then
            currencyType = CURT_MONEY
        end
        if not vendorInstance:CanAfford(price, currencyType) then
            return false
        end
    end

    local price1 = (ds.currencyQuantity1 or 0) * quantity
    local currencyType1 = ds.currencyType1
    if price1 > 0 and currencyType1 and currencyType1 ~= CURT_NONE
        and not vendorInstance:CanAfford(price1, currencyType1) then
        return false
    end

    local price2 = (ds.currencyQuantity2 or 0) * quantity
    local currencyType2 = ds.currencyType2
    if price2 > 0 and currencyType2 and currencyType2 ~= CURT_NONE then
        return vendorInstance:CanAfford(price2, currencyType2)
    end
    return true
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if a buy action is possible
function Buy:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = GetFocusedStoreData(vendorInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Locked entries (missing requirements, already-owned collectible, ...)
    -- cannot be purchased; GetStoreEntryInfo reports this via
    -- meetsRequirementsToBuy and BuyStoreItem would fail server-side.
    if ds.meetsRequirementsToBuy == false then
        return false
    end

    return CanAffordStoreEntry(vendorInstance, ds)
        and vendorInstance:CanCarry(ds.itemLink)
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:OnPrimaryAction(vendorInstance)
    local selectedData = GetFocusedStoreData(vendorInstance)
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local entryIndex = ds.entryIndex or ds.slotIndex
    if not entryIndex then return end

    -- Block purchase of locked entries; surface the store-failure reason text
    -- captured from GetStoreEntryInfo when available.
    if ds.meetsRequirementsToBuy == false then
        BETTERUI.CIM.UserAlertText("Buy:Locked",
            ds.requiredToBuyErrorText or GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_BUY")))
        return
    end

    -- Validate affordability (both currencies) one more time
    if not CanAffordStoreEntry(vendorInstance, ds) then
        BETTERUI.CIM.UserAlertText("Buy:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    if not vendorInstance:CanCarry(ds.itemLink) then
        BETTERUI.CIM.UserAlertText("Buy:CannotCarry",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY")))
        return
    end

    -- Default to a single-item purchase (matches native intent and the buy
    -- primary-action contract). A future interactive quantity spinner can pass
    -- its chosen value through Vendor.ClampPurchaseQuantity to buy a full stack.
    local quantity = 1

    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "vendor item bought", {
            entryIndex = entryIndex,
            quantity = quantity,
            name = ds.name,
            itemLink = ds.itemLink
        })
    end

    BuyStoreItem(entryIndex, quantity)
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    if vendorInstance and vendorInstance.ApplyNativeStoreMode then
        vendorInstance:ApplyNativeStoreMode(Vendor.MODE.BUY)
    end

    local rows = GetStoreRowsCached()
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
