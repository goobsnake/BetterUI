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

local function TraceBuyList(event, phase, vendorInstance, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Vendor"
    data.scene = BETTERUI_VENDOR_SCENE_NAME
    data.feature = data.feature or "vendor-buy-list"
    data.fn = data.fn or "Vendor.BuyComponent"
    data["function"] = data["function"] or data.fn
    if data.mode == nil and vendorInstance and vendorInstance.GetCurrentMode then
        data.mode = vendorInstance:GetCurrentMode()
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.LIST or categories.STATE or categories.GENERAL, event, phase, data)
end

local function BuildCategorySummary(categories)
    local parts = {}
    for _, category in ipairs(categories or {}) do
        parts[#parts + 1] = tostring(category.key or "<nil>") .. ":" .. tostring(category.itemCount or 0)
    end
    return table.concat(parts, ",")
end

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

local function BuildStoreRows(vendorInstance)
    TraceBuyList("vendor.buy_population", "begin", vendorInstance, {
        hasNativeComponent = rawget(_G, "STORE_WINDOW_GAMEPAD") ~= nil,
        storeCount = (type(GetNumStoreItems) == "function") and GetNumStoreItems() or nil,
    })
    if BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
        TraceBuyList("vendor.buy_rows", "ensure_native_components", vendorInstance, {
            reason = "buildRows",
        })
        BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
    end

    local rows = BuildRowsFromNativeBuyComponent()
    if #rows > 0 then
        TraceBuyList("vendor.buy_rows", "built", vendorInstance, {
            source = "nativeBuyComponent",
            rowCount = #rows,
        })
        return rows
    end

    rows = BuildRowsFromStoreManager()
    if #rows > 0 then
        TraceBuyList("vendor.buy_rows", "built", vendorInstance, {
            source = "storeManager",
            rowCount = #rows,
        })
        return rows
    end

    rows = BuildRowsFromStoreCount()
    if #rows > 0 then
        TraceBuyList("vendor.buy_rows", "built", vendorInstance, {
            source = "storeCount",
            rowCount = #rows,
        })
        return rows
    end

    rows = BuildRowsFromIndexProbe()
    if #rows > 0 then
        TraceBuyList("vendor.buy_rows", "built", vendorInstance, {
            source = "indexProbe",
            rowCount = #rows,
        })
        return rows
    end

    TraceBuyList("vendor.buy_rows", "empty", vendorInstance, {
        source = "all",
        rowCount = 0,
    })
    return rows
end

-- One refresh pass calls GetCategories and BuildList back to back, each of
-- which needs the store rows; cache populated rows per frame so the
-- multi-source build (and its index probe fallback) runs once per refresh.
-- Empty snapshots are intentionally not cached: native store population can
-- arrive later in the same frame as the scene open.
local cachedStoreRows = nil
local cachedStoreRowsFrameMs = nil

local function GetStoreRowsCached(vendorInstance)
    local frameMs = (type(GetFrameTimeMilliseconds) == "function") and GetFrameTimeMilliseconds() or nil
    if frameMs and cachedStoreRows and cachedStoreRowsFrameMs == frameMs and #cachedStoreRows > 0 then
        TraceBuyList("vendor.buy_rows", "cache_hit", vendorInstance, {
            rowCount = #cachedStoreRows,
        })
        return cachedStoreRows
    end

    local rows = BuildStoreRows(vendorInstance)
    if frameMs and #rows > 0 then
        cachedStoreRows = rows
        cachedStoreRowsFrameMs = frameMs
    else
        -- No frame clock (test harness), or native store is not populated yet:
        -- never reuse stale/empty rows.
        cachedStoreRows = nil
        cachedStoreRowsFrameMs = nil
    end
    return rows
end

-- PB-017: The empty-buy-list retry is owned solely by VendorControllerRuntime
-- (single "buyListRetry" task sharing instance._buyListRetryCount): up to 20
-- retries @ 180ms while the list builds empty, short-circuited at
-- BUY_EMPTY_STORE_RETRY_LIMIT (8) when the native store itself reports zero
-- items (a genuinely empty store never repopulates). BuyComponent previously
-- scheduled a competing "buyListRetry" (limit 3 @ 80ms x n) from BuildList that
-- shared the same counter, so the controller's retry budget was consumed twice
-- per refresh. BuildList now leaves the retry to the controller entirely.

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
    TraceBuyList("vendor.buy_categories", "begin", vendorInstance, {
        storeCount = (type(GetNumStoreItems) == "function") and GetNumStoreItems() or nil,
    })
    if vendorInstance and vendorInstance.ApplyNativeStoreMode then
        vendorInstance:ApplyNativeStoreMode(Vendor.MODE.BUY)
    end

    local rows = GetStoreRowsCached(vendorInstance)
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

    TraceBuyList("vendor.buy_categories", "refreshed", vendorInstance, {
        rowCount = totalCount,
        categoryCount = #categories,
        categories = BuildCategorySummary(categories),
    })
    return categories
end

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:Activate(vendorInstance)
    TraceBuyList("vendor.buy_list", "activate_begin", vendorInstance)
    vendorInstance._buyListRetryCount = 0
    vendorInstance:RefreshList()

    -- Opening/switching to Buy can race native store population.
    -- Run one deferred pass after mode settles so rows are consistently visible.
    if BETTERUI.Vendor and BETTERUI.Vendor.Tasks then
        BETTERUI.Vendor.Tasks:Cancel("buyActivateRefresh")
        TraceBuyList("vendor.buy_list", "deferred_scheduled", vendorInstance, {
            delayMs = 120,
        })
        BETTERUI.Vendor.Tasks:Schedule("buyActivateRefresh", 120, function()
            if Vendor.ShouldAbortDeferredVendorRefresh
                and Vendor.ShouldAbortDeferredVendorRefresh(vendorInstance, Vendor.MODE.BUY) then
                TraceBuyList("vendor.buy_list", "deferred_refresh_aborted", vendorInstance)
                return
            end
            if vendorInstance.ApplyNativeStoreMode then
                vendorInstance:ApplyNativeStoreMode(Vendor.MODE.BUY)
            end
            cachedStoreRows = nil
            cachedStoreRowsFrameMs = nil
            TraceBuyList("vendor.buy_list", "deferred_refresh_begin", vendorInstance, {
                delayMs = 120,
            })
            vendorInstance:RefreshList()
            TraceBuyList("vendor.buy_list", "deferred_refresh_end", vendorInstance, {
                delayMs = 120,
                rowCount = vendorInstance.list and vendorInstance.list.dataList and #vendorInstance.list.dataList or nil,
            })
        end)
    else
        TraceBuyList("vendor.buy_list", "deferred_skipped", vendorInstance, {
            reason = "missingTaskQueue",
        })
    end
    TraceBuyList("vendor.buy_list", "activate_end", vendorInstance)
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:Deactivate(vendorInstance)
    -- Drop the per-frame store-row cache so a stale row set can never be
    -- reused after the store closes or the Buy mode deactivates.
    cachedStoreRows = nil
    cachedStoreRowsFrameMs = nil
    if vendorInstance then
        vendorInstance._buyListRetryCount = 0
    end
    TraceBuyList("vendor.buy_list", "deactivate", vendorInstance)
end

-- PRIMARY ACTION

---@return string name Localized action label
function Buy:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_BUY"))
end

-- BUI-CONS-008: store-entry affordability is unified in Vendor.CanAffordStoreEntry
-- (VendorModePolicy), shared with BatchActionCounts and VendorBatchRuntime.
-- The buy flow supports multi-quantity purchases: entries with
-- GetStoreEntryMaxBuyable > 1 get the inline STAT-column quantity spinner
-- (BETTERUI.Vendor.InlineBuySpinner); OnPrimaryAction reads its dialed value.
-- Quantity clamping lives in PerformVendorBuy (guards a stale spinner value).

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

    return Vendor.CanAffordStoreEntry(vendorInstance, ds)
        and vendorInstance:CanCarry(ds.itemLink)
end

local function TraceBuyBlocked(vendorInstance, reason, ds, extra)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    extra = extra or {}
    extra.module = "Vendor"
    extra.scene = BETTERUI_VENDOR_SCENE_NAME
    extra.feature = "vendor-buy"
    extra.fn = "Vendor.BuyComponent.OnPrimaryAction"
    extra["function"] = "Vendor.BuyComponent.OnPrimaryAction"
    extra.mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil
    extra.reason = reason
    if ds then
        extra.entryIndex = extra.entryIndex or ds.entryIndex or ds.slotIndex
        extra.item = extra.item or (L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name)
    end
    L.TraceEvent(L.CATEGORY.ACTION, "vendor.buy", "blocked", extra)
end

--- Performs the traced BuyStoreItem for the given entry + quantity, clamped to
--- the live GetStoreEntryMaxBuyable so a stale spinner value can never
--- over-purchase (gold/space may have changed while the spinner was open).
---@param vendorInstance BETTERUI.Vendor.Class
---@param entryIndex integer
---@param ds table Store entry data source
---@param quantity integer
local function PerformVendorBuy(vendorInstance, entryIndex, ds, quantity)
    quantity = quantity or 1
    local getMaxBuyable = rawget(_G, "GetStoreEntryMaxBuyable")
    if getMaxBuyable then
        local liveMax = getMaxBuyable(entryIndex)
        if type(liveMax) == "number" then
            if liveMax < 1 then
                -- Gold spent or bags filled since the action began: nothing is
                -- buyable right now, so never issue a zero/over-quantity purchase.
                TraceBuyBlocked(vendorInstance, "noneBuyable", ds, { liveMax = liveMax, requested = quantity })
                BETTERUI.CIM.UserAlertText("Buy:CannotAfford",
                    GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
                return
            end
            if quantity > liveMax then
                quantity = liveMax
            end
        end
    end
    if quantity < 1 then quantity = 1 end

    local L = BETTERUI.Log
    local traceData = {
        module = "Vendor",
        scene = BETTERUI_VENDOR_SCENE_NAME,
        feature = "vendor-buy",
        fn = "Vendor.BuyComponent.PerformVendorBuy",
        ["function"] = "Vendor.BuyComponent.PerformVendorBuy",
        mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
        entryIndex = entryIndex,
        quantity = quantity,
        expectedPrice = ds and ds.price or nil,
        price = ds and ds.price or nil,
        currencyType = ds and ds.currencyType or nil,
        item = L and L.DescribeItem and L.DescribeItem(ds, "selected") or (ds and ds.name),
    }
    Vendor.DispatchTracedAction("vendor.buy", traceData, function()
        BuyStoreItem(entryIndex, quantity)
    end)
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:OnPrimaryAction(vendorInstance)
    local selectedData = GetFocusedStoreData(vendorInstance)
    if not selectedData then
        TraceBuyBlocked(vendorInstance, "noSelection")
        return
    end
    local ds = selectedData.dataSource or selectedData

    local entryIndex = ds.entryIndex or ds.slotIndex
    if not entryIndex then
        TraceBuyBlocked(vendorInstance, "missingEntryIndex", ds)
        return
    end

    -- Block purchase of locked entries; surface the store-failure reason text
    -- captured from GetStoreEntryInfo when available.
    if ds.meetsRequirementsToBuy == false then
        TraceBuyBlocked(vendorInstance, "requirementsNotMet", ds, {
            requiredToBuyErrorText = ds.requiredToBuyErrorText,
        })
        BETTERUI.CIM.UserAlertText("Buy:Locked",
            ds.requiredToBuyErrorText or GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_BUY")))
        return
    end

    -- Validate affordability (both currencies) one more time
    if not Vendor.CanAffordStoreEntry(vendorInstance, ds) then
        TraceBuyBlocked(vendorInstance, "cannotAfford", ds)
        BETTERUI.CIM.UserAlertText("Buy:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    if not vendorInstance:CanCarry(ds.itemLink) then
        TraceBuyBlocked(vendorInstance, "cannotCarry", ds)
        BETTERUI.CIM.UserAlertText("Buy:CannotCarry",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY")))
        return
    end

    -- Two-stage buy matching the default store: the FIRST Buy press on a stackable
    -- (GetStoreEntryMaxBuyable > 1) reveals the inline quantity spinner (dialing
    -- mode) instead of purchasing; the SECOND Buy press (while dialing THIS entry)
    -- executes it. A max==1 row buys immediately on the first press.
    local inlineSpinner = BETTERUI.Vendor and BETTERUI.Vendor.InlineBuySpinner
    local getMaxBuyable = rawget(_G, "GetStoreEntryMaxBuyable")
    local maxBuyable = getMaxBuyable and getMaxBuyable(entryIndex) or 1

    if inlineSpinner and type(maxBuyable) == "number" and maxBuyable > 1
        and not inlineSpinner:IsDialingEntry(entryIndex) then
        if inlineSpinner:BeginDialing(vendorInstance, selectedData) then
            -- Reveal the dialing-only keybinds (L2/R2 Min/Max) now that the spinner
            -- is up. If BeginDialing declined, fall through to a direct qty=1 buy.
            if vendorInstance.RefreshVendorActionKeybinds then
                vendorInstance:RefreshVendorActionKeybinds()
            end
            -- Dialing pins the selection, so no further selection-change refresh fires.
            -- Native re-registration is suppressed at source (NativeStoreBridge keybind
            -- prehook), so one deferred core reclaim settles ownership after the dialing
            -- keybinds go in -- no multi-tick sweep needed.
            if vendorInstance.ScheduleCoreKeybindRefresh then
                vendorInstance:ScheduleCoreKeybindRefresh("dialingEntry", 0)
            end
            return
        end
    end

    -- Quantity comes from the inline spinner when it is dialing THIS entry;
    -- otherwise a single item. PerformVendorBuy re-clamps to the live max.
    local quantity = 1
    if inlineSpinner and inlineSpinner:IsDialingEntry(entryIndex) then
        local dialed = inlineSpinner:GetQuantity()
        if type(dialed) == "number" and dialed >= 1 then
            quantity = dialed
        end
    end

    -- Exits dialing mode after a COMMITTED purchase (detach spinner + restore the
    -- browse keybinds). A cancelled confirm dialog leaves the spinner up so the
    -- user can re-dial.
    local function finishDialing()
        if inlineSpinner and inlineSpinner:IsAttached() then
            inlineSpinner:Detach()
            if vendorInstance.RefreshVendorActionKeybinds then
                vendorInstance:RefreshVendorActionKeybinds()
            end
            -- Native re-registration is suppressed at source, so one deferred core
            -- reclaim settles the browse strip after detaching the spinner.
            if vendorInstance.ScheduleCoreKeybindRefresh then
                vendorInstance:ScheduleCoreKeybindRefresh("dialingExit", 0)
            end
        end
    end

    -- Multi-quantity purchases get a confirmation dialog (item + quantity +
    -- running total) unless the user enabled skipBuyConfirm. Single-item buys
    -- stay immediate. The Confirm button re-enters PerformVendorBuy, which
    -- re-clamps to the live max, so the deferred purchase is still safe.
    if quantity > 1 and Vendor.GetSetting("skipBuyConfirm") ~= true and Vendor.ShowBuyConfirmation then
        local shown = Vendor.ShowBuyConfirmation({
            itemName = ds.name,
            quantity = quantity,
            totalPrice = (ds.price or 0) * quantity,
            currencyType = ds.currencyType1 or ds.currencyType,
            onConfirm = function()
                PerformVendorBuy(vendorInstance, entryIndex, ds, quantity)
                finishDialing()
            end,
        })
        if shown then
            return
        end
    end

    PerformVendorBuy(vendorInstance, entryIndex, ds, quantity)
    finishDialing()
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then
        TraceBuyList("vendor.buy_list", "skipped", vendorInstance, {
            reason = "missingList",
        })
        return
    end

    if vendorInstance and vendorInstance.ApplyNativeStoreMode then
        vendorInstance:ApplyNativeStoreMode(Vendor.MODE.BUY)
    end

    local rows = GetStoreRowsCached(vendorInstance)
    local activeCategory = vendorInstance:GetCurrentCategory()
    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil
    TraceBuyList("vendor.buy_list", "populate_begin", vendorInstance, {
        rowCount = #rows,
        categoryKey = activeCategory and activeCategory.key or nil,
        hasSearchQuery = searchQuery ~= nil,
    })
    if #rows == 0 then
        TraceBuyList("vendor.buy_list", "empty", vendorInstance, {
            reason = "emptyRows",
            rowCount = 0,
            categoryKey = activeCategory and activeCategory.key or nil,
            hasSearchQuery = searchQuery ~= nil,
        })
        -- PB-017: retry is owned by VendorControllerRuntime; do not schedule a
        -- competing "buyListRetry" here (it double-consumed the shared counter).
        return
    end

    vendorInstance._buyListRetryCount = 0
    local addedCount = 0
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

            Vendor.AddItemRow(list, itemData)
            addedCount = addedCount + 1
        end
    end

    TraceBuyList("vendor.buy_list", "populated", vendorInstance, {
        rowCount = #rows,
        addedCount = addedCount,
        categoryKey = activeCategory and activeCategory.key or nil,
        searchQuery = searchQuery,
    })
end
