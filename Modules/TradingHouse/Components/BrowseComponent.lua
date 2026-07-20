-- Trading House browse tab component.

local TH = BETTERUI.TradingHouse

TH.BrowseComponent = {}
local Browse = TH.BrowseComponent

local function TraceBrowse(event, phase, thInstance, data, category)
    if type(TH.Trace) == "function" then
        data = data or {}
        data.feature = data.feature or "trading-house-browse"
        data.fn = data.fn or "TradingHouse.BrowseComponent"
        TH.Trace(category or (BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH), event, phase, thInstance or TH.instance, data)
    end
end

local function NewTradingHouseOpId()
    local L = BETTERUI and BETTERUI.Log
    if L and type(L.NewFlow) == "function" then
        return L.NewFlow("thOp")
    end
    return "untracked"
end

-- Shared narration text helper avoids a per-entry closure allocation.
local function GetEntryNarrationText(entryData)
    local ds = entryData:GetDataSource()
    return ds and ds.name or ""
end

local BROWSE_SORT_KEY_UNIT = "unit"
local BROWSE_SORT_ASC_ARROW = " ▲"
local BROWSE_SORT_DESC_ARROW = " ▼"

local function GetHeaderLabel(stringIdName, fallback)
    local stringId = rawget(_G, stringIdName)
    if stringId and type(GetString) == "function" then
        local text = GetString(stringId)
        if text and text ~= "" then
            return text
        end
    end
    return fallback
end

local function GetBrowseHeaderLabel(baseText, sortKey)
    if sortKey == BROWSE_SORT_KEY_UNIT then
        return baseText .. (Browse.sortAscending == false and BROWSE_SORT_DESC_ARROW or BROWSE_SORT_ASC_ARROW)
    end
    return baseText
end

local function GetHeaderColumnAnchor(thInstance)
    local header = thInstance and thInstance.header
    if not (header and header.GetNamedChild) then
        return nil
    end
    return header:GetNamedChild("HeaderColumnBar") or header:GetNamedChild("HeaderTabBar")
end

local function GetHeaderColumnOffset(columnIndex)
    local headerLayout = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.HEADER_LAYOUT
    local columns = headerLayout and headerLayout.COLUMNS
    local orderedOffsets = {
        columns and columns.NAME or 80,
        columns and columns.TYPE or 592,
        columns and columns.TRAIT or 852,
        columns and columns.STAT or 1042,
        columns and columns.VALUE or 1192,
    }
    return orderedOffsets[columnIndex]
end

local function ApplyHeaderColumnAnchor(label, anchor, columnIndex, column)
    if not (label and anchor and label.SetAnchor and rawget(_G, "LEFT") and rawget(_G, "BOTTOMLEFT")) then
        return
    end
    if label.ClearAnchors then
        label:ClearAnchors()
    end
    local layout = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.LAYOUT
    local offsetY = layout and layout.COLUMN_HEADER_Y_OFFSET or 109
    local columnOffset = column and column.offset or GetHeaderColumnOffset(columnIndex)
    label:SetAnchor(LEFT, anchor, BOTTOMLEFT, columnOffset, offsetY)

    local widths = layout and layout.COLUMN_WIDTHS
    if label.SetDimensions then
        label:SetDimensions((column and column.width) or (widths and widths[columnIndex]) or 100, 30)
    end
end

local function ApplyHeaderColumnSet(thInstance, columns, modeKey, phase)
    local headerColumns = thInstance and thInstance.header and thInstance.header.columns
    if type(headerColumns) ~= "table" then
        return false
    end
    if thInstance._betteruiTHHeaderMode == modeKey then
        return true
    end

    local anchor = GetHeaderColumnAnchor(thInstance)
    if not anchor then
        return false
    end
    for i, label in ipairs(headerColumns) do
        local column = columns[i]
        if label then
            ApplyHeaderColumnAnchor(label, anchor, i, column)
            local hidden = not column or column.hidden == true
            if label.SetText then
                label:SetText(hidden and "" or (column.text or ""))
            end
            if label.SetHidden then
                label:SetHidden(hidden)
            end
            if label.SetMouseEnabled then
                label:SetMouseEnabled(not hidden and column.mouseEnabled ~= false)
            end
            if label.SetHorizontalAlignment then
                label:SetHorizontalAlignment(column and column.align or TEXT_ALIGN_LEFT)
            end
        end
    end

    thInstance._betteruiTHHeaderMode = modeKey
    TraceBrowse("trading_house.browse_columns", phase or "configured", thInstance, {
        fn = "TradingHouse.BrowseComponent.ApplyHeaderColumnSet",
        modeKey = modeKey,
        sortKey = Browse.sortKey,
        sortAscending = Browse.sortAscending ~= false,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
    return true
end

local function ConfigureBrowseColumns(thInstance)
    local modeKey = "browse:" .. (Browse.sortAscending == false and "desc" or "asc")
    return ApplyHeaderColumnSet(thInstance, {
        { text = "NAME", align = TEXT_ALIGN_LEFT, offset = 58, width = 500 },
        { text = "TIME", align = TEXT_ALIGN_RIGHT, offset = 516, width = 100 },
        -- The Browse sort indicator follows UNIT inside this right-aligned label;
        -- compensate so the visible UNIT text matches the Sell header position.
        { text = GetBrowseHeaderLabel("UNIT", BROWSE_SORT_KEY_UNIT), align = TEXT_ALIGN_RIGHT, offset = 719, width = 180 },
        { text = "TOTAL", align = TEXT_ALIGN_RIGHT, offset = 922, width = 140 },
        { text = "MARKET", align = TEXT_ALIGN_RIGHT, offset = 1117, width = 140 },
    }, modeKey, "browse")
end

local function RestoreDefaultColumns(thInstance)
    return ApplyHeaderColumnSet(thInstance, {
        { text = GetHeaderLabel("SI_BETTERUI_INV_HEADER_NAME", "NAME") },
        { text = GetHeaderLabel("SI_BETTERUI_INV_HEADER_TYPE", "TYPE") },
        { text = GetHeaderLabel("SI_BETTERUI_INV_HEADER_TRAIT", "TRAIT") },
        { text = GetHeaderLabel("SI_BETTERUI_INV_HEADER_STAT", "STAT") },
        { text = GetHeaderLabel("SI_BETTERUI_INV_HEADER_VALUE", "VALUE") },
    }, "default", "restored")
end

local function GetTradingHouseBrowseSortType()
    return rawget(_G, "TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT")
        or rawget(_G, "TRADING_HOUSE_SORT_SALE_PRICE")
end

local function NormalizeItemName(itemName)
    if type(itemName) ~= "string" or itemName == "" then
        return nil
    end
    local itemNameFormat = rawget(_G, "SI_TOOLTIP_ITEM_NAME")
    if itemNameFormat and type(zo_strformat) == "function" then
        return zo_strformat(itemNameFormat, itemName)
    end
    return itemName
end

local function ResolveUnitPrice(purchasePricePerUnit, purchasePrice, stackCount)
    local unitPrice = tonumber(purchasePricePerUnit)
    if unitPrice and unitPrice > 0 then
        return unitPrice
    end

    local total = tonumber(purchasePrice) or 0
    local stack = tonumber(stackCount) or 0
    if total > 0 and stack > 0 then
        return total / stack
    end
    return 0
end

local function CompareBrowseRows(left, right)
    local leftPrice = left and tonumber(left.unitPrice) or nil
    local rightPrice = right and tonumber(right.unitPrice) or nil
    if leftPrice ~= rightPrice then
        if leftPrice == nil then return false end
        if rightPrice == nil then return true end
        if Browse.sortAscending == false then
            return leftPrice > rightPrice
        end
        return leftPrice < rightPrice
    end

    local leftName = string.lower(tostring(left and left.name or ""))
    local rightName = string.lower(tostring(right and right.name or ""))
    if leftName ~= rightName then
        return leftName < rightName
    end

    return (tonumber(left and left.tradingHouseIndex) or 0) < (tonumber(right and right.tradingHouseIndex) or 0)
end

local function SortBrowseRows(rows)
    if type(rows) == "table" and #rows > 1 then
        table.sort(rows, CompareBrowseRows)
    end
end

local function RefreshBrowseListForSort(thInstance)
    if not (thInstance and thInstance.RefreshList) then
        return
    end
    if thInstance.GetCurrentMode and thInstance:GetCurrentMode() ~= TH.MODE.BROWSE then
        return
    end
    thInstance:RefreshList()
end

Browse.currentPage = 0
Browse.hasMorePages = false
Browse.searchPending = false
Browse.resultsInvalidated = false
Browse.categories = Browse.categories or {}
Browse.selectedCategoryKey = Browse.selectedCategoryKey or "__all"
Browse.deferredSearchToken = 0
Browse.pendingBuyTrace = nil
Browse.sortKey = BROWSE_SORT_KEY_UNIT
Browse.sortAscending = true
local buyDialogHooksInstalled = false

local function TracePendingBuyDialog(phase, reason)
    local pending = Browse.pendingBuyTrace
    if not pending then return false end
    if reason ~= nil then
        pending.reason = reason
    end
    if phase == "confirm" and pending.thOperation == "buy" and TH.BeginPendingOperation then
        pending.opId = TH.BeginPendingOperation("buy", "trading_house.buy", {
            fn = "TradingHouse.BrowseComponent.TracePendingBuyDialog",
            feature = "trading-house-browse",
            opId = pending.opId,
            tradingHouseIndex = pending.tradingHouseIndex,
            price = pending.price,
            stackCount = pending.stackCount,
            item = pending.item,
        })
    end
    TraceBrowse("trading_house.buy_dialog", phase, TH.instance, pending,
        BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
    if phase == "cancel" and pending.thOperation and TH.ClearPendingOperation then
        TH.ClearPendingOperation(pending.thOperation)
    end
    Browse.pendingBuyTrace = nil
    return true
end

local function EnsureBuyDialogHooks()
    if buyDialogHooksInstalled then return end
    buyDialogHooksInstalled = true
    if type(ZO_PostHook) ~= "function" then
        TraceBrowse("trading_house.buy_dialog", "hooks_skipped", TH.instance, {
            fn = "TradingHouse.BrowseComponent.EnsureBuyDialogHooks",
            reason = "missingZO_PostHook",
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
        return
    end
    if type(ConfirmPendingItemPurchase) == "function" then
        ZO_PostHook(_G, "ConfirmPendingItemPurchase", function(...)
            TracePendingBuyDialog("confirm", nil)
        end)
    end
    if type(ClearPendingItemPurchase) == "function" then
        ZO_PostHook(_G, "ClearPendingItemPurchase", function(...)
            TracePendingBuyDialog("cancel", "ClearPendingItemPurchase")
        end)
    end
    if type(ZO_Dialogs_ReleaseDialog) == "function" then
        ZO_PostHook(_G, "ZO_Dialogs_ReleaseDialog", function(dialogName, ...)
            if dialogName == "TRADING_HOUSE_CONFIRM_BUY_ITEM" then
                TracePendingBuyDialog("cancel", "dialogReleased")
            end
        end)
    end
    if type(ZO_Dialogs_ReleaseDialogOnButtonPress) == "function" then
        ZO_PostHook(_G, "ZO_Dialogs_ReleaseDialogOnButtonPress", function(dialogName, ...)
            if dialogName == "TRADING_HOUSE_CONFIRM_BUY_ITEM" then
                TracePendingBuyDialog("cancel", "buttonPressRelease")
            end
        end)
    end
end

--- Resolve the focused row through the shared CIM helper, mirroring the Vendor
--- buy component: prefer the converged GetListTargetData alias, else the
--- SafeGetTargetData base (both handle GetTargetData/GetSelectedData/.selectedData).
---@param thInstance BETTERUI.TradingHouse.Class|nil
---@return table|nil rowData
local function GetTargetRowData(thInstance)
    local list = thInstance and thInstance.list
    if not list then return nil end
    local getTargetData = BETTERUI.CIM and BETTERUI.CIM.Utils
        and (BETTERUI.CIM.Utils.GetListTargetData or BETTERUI.CIM.Utils.SafeGetTargetData)
    if type(getTargetData) ~= "function" then return nil end
    return getTargetData(list)
end

--- Drops the current native search-result rows from rendering: their
--- tradingHouseIndex values are no longer purchasable (e.g. after a guild
--- switch). Cleared when fresh results arrive.
function Browse:InvalidateResults()
    TraceBrowse("trading_house.search_results", "invalidated", TH.instance, {
        fn = "TradingHouse.BrowseComponent.InvalidateResults",
        page = Browse.currentPage,
        hadMorePagesBefore = Browse.hasMorePages == true,
        resultsInvalidatedBefore = Browse.resultsInvalidated == true,
    })
    Browse.resultsInvalidated = true
    Browse.hasMorePages = false
end

function Browse:Activate(thInstance)
    TraceBrowse("trading_house.browse", "activate", thInstance, {
        fn = "TradingHouse.BrowseComponent.Activate",
        page = Browse.currentPage,
        searchPending = Browse.searchPending == true,
        hasMorePages = Browse.hasMorePages == true,
        resultsInvalidated = Browse.resultsInvalidated == true,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIFECYCLE)
    ConfigureBrowseColumns(thInstance)
    thInstance:RefreshList()
end

function Browse:Deactivate(thInstance)
    TracePendingBuyDialog("cancel", "componentDeactivated")
    local pendingBefore = Browse.searchPending == true
    if pendingBefore then
        Browse.deferredSearchToken = (Browse.deferredSearchToken or 0) + 1
        Browse.searchPending = false
    end
    TraceBrowse("trading_house.browse", "deactivate", thInstance, {
        fn = "TradingHouse.BrowseComponent.Deactivate",
        page = Browse.currentPage,
        searchPendingBefore = pendingBefore,
        searchPendingAfter = Browse.searchPending == true,
        deferredToken = Browse.deferredSearchToken,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIFECYCLE)
    RestoreDefaultColumns(thInstance)
end

function Browse:SetSort(sortKey, ascending, thInstance)
    if type(sortKey) == "boolean" then
        thInstance = ascending
        ascending = sortKey
        sortKey = BROWSE_SORT_KEY_UNIT
    elseif type(sortKey) == "table" then
        thInstance = sortKey
        sortKey = BROWSE_SORT_KEY_UNIT
        ascending = Browse.sortAscending
    elseif type(ascending) == "table" and thInstance == nil then
        thInstance = ascending
        ascending = Browse.sortAscending
    end

    sortKey = sortKey or BROWSE_SORT_KEY_UNIT
    if sortKey ~= BROWSE_SORT_KEY_UNIT then
        TraceBrowse("trading_house.browse_sort", "blocked", thInstance or TH.instance, {
            fn = "TradingHouse.BrowseComponent.SetSort",
            reason = "unsupportedSortKey",
            sortKey = sortKey,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.SORT)
        return false
    end

    Browse.sortKey = BROWSE_SORT_KEY_UNIT
    Browse.sortAscending = ascending ~= false
    local target = thInstance or TH.instance
    ConfigureBrowseColumns(target)
    TraceBrowse("trading_house.browse_sort", "changed", target, {
        fn = "TradingHouse.BrowseComponent.SetSort",
        sortKey = Browse.sortKey,
        sortAscending = Browse.sortAscending,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.SORT)
    RefreshBrowseListForSort(target)
    return true
end

function Browse:CycleSort(thInstance)
    return Browse:SetSort(BROWSE_SORT_KEY_UNIT, Browse.sortAscending == false, thInstance or TH.instance)
end

function Browse:GetPrimaryActionName()
    return GetString(SI_TRADING_HOUSE_BUY_ITEM)
end

function Browse:IsPrimaryActionEnabled(thInstance)
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    local price = ds.purchasePrice or 0
    return price > 0 and thInstance:CanAfford(price) and thInstance:HasInventorySpace()
end

function Browse:OnPrimaryAction(thInstance)
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then
        TraceBrowse("trading_house.buy", "blocked", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            reason = "noSelection",
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
        return
    end
    local ds = selectedData.dataSource or selectedData

    local tradingHouseIndex = ds.tradingHouseIndex
    local price = ds.purchasePrice or 0
    local item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name
    if not tradingHouseIndex or price <= 0 then
        TraceBrowse("trading_house.buy", "blocked", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            reason = "invalidListing",
            tradingHouseIndex = tradingHouseIndex,
            price = price,
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
        return
    end

    TraceBrowse("trading_house.buy", "begin", thInstance, {
        fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
        tradingHouseIndex = tradingHouseIndex,
        price = price,
        item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)

    if not thInstance:CanAfford(price) then
        TraceBrowse("trading_house.buy", "blocked", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            reason = "cannotAfford",
            tradingHouseIndex = tradingHouseIndex,
            price = price,
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
        BETTERUI.CIM.UserAlertText("TH:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    if not thInstance:HasInventorySpace() then
        TraceBrowse("trading_house.buy", "blocked", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            reason = "cannotCarry",
            tradingHouseIndex = tradingHouseIndex,
            price = price,
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
        BETTERUI.CIM.UserAlertText("TH:CannotCarry",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY")))
        return
    end

    local opId = NewTradingHouseOpId()

    -- ZOS gamepad purchase flow (tradinghouse_browseresults_gamepad.lua): stage
    -- the pending purchase, then show the native gamepad confirm dialog whose
    -- buttons call ConfirmPendingItemPurchase/ClearPendingItemPurchase.
    if SetPendingItemPurchase then
        SetPendingItemPurchase(tradingHouseIndex)
        TraceBrowse("trading_house.buy", "pending_set", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            tradingHouseIndex = tradingHouseIndex,
            price = price,
            opId = opId,
            item = item,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
    end
    EnsureBuyDialogHooks()
    Browse.pendingBuyTrace = {
        fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
        dialog = "TRADING_HOUSE_CONFIRM_BUY_ITEM",
        thOperation = "buy",
        opId = opId,
        tradingHouseIndex = tradingHouseIndex,
        price = price,
        stackCount = ds.stackCount or 1,
        item = item,
    }

    local dialogItemData = {
        slotIndex = tradingHouseIndex,
        stackCount = ds.stackCount or 1,
        name = ds.name,
        displayQuality = ds.quality,
        currencyType = ds.currencyType,
    }
    if ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog then
        ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog(dialogItemData,
            "TRADING_HOUSE_CONFIRM_BUY_ITEM", price, ds.icon)
        if BETTERUI.CIM.Dialogs.ClaimShownForOwner then
            BETTERUI.CIM.Dialogs.ClaimShownForOwner(
                thInstance, "TRADING_HOUSE_CONFIRM_BUY_ITEM")
        end
        TraceBrowse("trading_house.buy_dialog", "shown", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            dialog = "TRADING_HOUSE_CONFIRM_BUY_ITEM",
            path = "nativeGamepadConfirmation",
            tradingHouseIndex = tradingHouseIndex,
            price = price,
            opId = opId,
            item = item,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
    else
        BETTERUI.CIM.Dialogs.ShowForOwner(thInstance, "TRADING_HOUSE_CONFIRM_BUY_ITEM", {
            listingIndex = tradingHouseIndex,
            stackCount = dialogItemData.stackCount,
            price = price,
        })
        TraceBrowse("trading_house.buy_dialog", "shown", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            dialog = "TRADING_HOUSE_CONFIRM_BUY_ITEM",
            path = "fallbackDialog",
            tradingHouseIndex = tradingHouseIndex,
            price = price,
            opId = opId,
            item = item,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
    end
    TraceBrowse("trading_house.buy_dialog", "awaiting_choice", thInstance, Browse.pendingBuyTrace,
        BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
end

---@param useLastExecutedSearchFilters boolean|nil True for page flips: reuse
--- the filters from the search that produced the current results instead of
--- re-applying (and thereby wiping) the pending filter state.
---@return boolean dispatched True if a search request was sent to the server
function Browse:ExecuteSearch(useLastExecutedSearchFilters)
    TraceBrowse("trading_house.search", "begin", TH.instance, {
        fn = "TradingHouse.BrowseComponent.ExecuteSearch",
        page = Browse.currentPage,
        reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
        searchPending = Browse.searchPending == true,
        cooldownRemainingMs = GetTradingHouseCooldownRemaining and GetTradingHouseCooldownRemaining() or nil,
    })
    if Browse.searchPending then
        TraceBrowse("trading_house.search", "blocked", TH.instance, {
            fn = "TradingHouse.BrowseComponent.ExecuteSearch",
            page = Browse.currentPage,
            reason = "searchPending",
        })
        return false
    end

    if GetTradingHouseCooldownRemaining and GetTradingHouseCooldownRemaining() > 0 then
        local cooldownRemainingMs = GetTradingHouseCooldownRemaining()
        TraceBrowse("trading_house.search", "blocked", TH.instance, {
            fn = "TradingHouse.BrowseComponent.ExecuteSearch",
            page = Browse.currentPage,
            reason = "cooldown",
            cooldownRemainingMs = cooldownRemainingMs,
        })
        BETTERUI.CIM.UserAlertText("TH:Cooldown",
            GetString(rawget(_G, "SI_BETTERUI_TH_SEARCH_COOLDOWN")))
        return false
    end

    if not ExecuteTradingHouseSearch then
        TraceBrowse("trading_house.search", "blocked", TH.instance, {
            fn = "TradingHouse.BrowseComponent.ExecuteSearch",
            page = Browse.currentPage,
            reason = "missingExecuteTradingHouseSearch",
        })
        return false
    end

    -- ZOS DoSearch pushes the current filter/preset state into the pending
    -- search before dispatching (tradinghouse_shared.lua ApplyFilters);
    -- without this, category filters and loaded presets are inert. Page
    -- flips skip it and reuse the last executed filters instead.
    if not useLastExecutedSearchFilters then
        if TH.BrowseFilters and TH.BrowseFilters.AssociateSearchFeatures then
            TH.BrowseFilters.AssociateSearchFeatures()
        end
        -- Fresh searches always start at page 0; native dispatches with
        -- targetPage or 0 (tradinghouse_shared.lua) and only page flips
        -- carry a page forward.
        Browse.currentPage = 0
        -- Guard: ApplyFilters iterates self.features, which is only populated
        -- after AssociateWithSearchFeatures is called.
        if TRADING_HOUSE_SEARCH and TRADING_HOUSE_SEARCH.features and TRADING_HOUSE_SEARCH.ApplyFilters then
            local IS_PERFORMING_SEARCH = true
            TRADING_HOUSE_SEARCH:ApplyFilters(IS_PERFORMING_SEARCH)
            -- Apply any filters that have no native browse feature (e.g. level
            -- range) after the native features have reset/applied their state.
            if TH.BrowseFilters and TH.BrowseFilters.ApplyPendingFilters then
                TH.BrowseFilters.ApplyPendingFilters(TRADING_HOUSE_SEARCH)
            end
        end
    end

    -- A name-text filter starts an async MatchTradingHouseItemNames; dispatching
    -- the search before it resolves drops the name filter from the first search
    -- (TRC-003). Mirror native (tradinghouse_shared.lua:529): when the search
    -- can't run yet (pending name match / cooldown), defer to DoSearchWhenReady
    -- so it auto-dispatches once ready, with the name filter applied. Guarded by
    -- method existence so non-native/test environments fall through unchanged.
    if not useLastExecutedSearchFilters
        and TRADING_HOUSE_SEARCH
        and TRADING_HOUSE_SEARCH.CanPerformSearch
        and TRADING_HOUSE_SEARCH.DoSearchWhenReady
        and TRADING_HOUSE_SEARCH.features
        and TRADING_HOUSE_SEARCH.features.nameSearchFeature
        and not TRADING_HOUSE_SEARCH:CanPerformSearch() then
        Browse.searchPending = true
        Browse.deferredSearchToken = Browse.deferredSearchToken + 1
        local token = Browse.deferredSearchToken
        local opId = TH.BeginPendingOperation and TH.BeginPendingOperation("search", "trading_house.search", {
            fn = "TradingHouse.BrowseComponent.ExecuteSearch",
            feature = "trading-house-browse",
            page = Browse.currentPage,
            reason = "nativeSearchNotReady",
            deferredToken = token,
            deferred = true,
        }, false) or nil
        TraceBrowse("trading_house.search", "deferred", TH.instance, {
            fn = "TradingHouse.BrowseComponent.ExecuteSearch",
            page = Browse.currentPage,
            reason = "nativeSearchNotReady",
            reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
            deferredToken = token,
            opId = opId,
        })
        TRADING_HOUSE_SEARCH:DoSearchWhenReady()
        TraceBrowse("trading_house.search", "queued", TH.instance, {
            fn = "TradingHouse.BrowseComponent.ExecuteSearch",
            page = Browse.currentPage,
            reason = "nativeSearchNotReady",
            deferredToken = token,
            opId = opId,
            searchPending = Browse.searchPending == true,
        })
        local later = rawget(_G, "zo_callLater")
        if type(later) == "function" then
            later(function()
                if Browse.deferredSearchToken == token and Browse.searchPending == true then
                    Browse.searchPending = false
                    TraceBrowse("trading_house.search", "deferred_timeout", TH.instance, {
                        fn = "TradingHouse.BrowseComponent.ExecuteSearch",
                        page = Browse.currentPage,
                        reason = "nativeSearchNotReadyTimeout",
                        deferredToken = token,
                        opId = opId,
                    })
                    if TH.ClearPendingOperation then
                        TH.ClearPendingOperation("search")
                    end
                end
            end, 10000)
        else
            Browse.searchPending = false
            Browse.deferredSearchToken = Browse.deferredSearchToken + 1
            TraceBrowse("trading_house.search", "deferred_timeout_skipped", TH.instance, {
                fn = "TradingHouse.BrowseComponent.ExecuteSearch",
                page = Browse.currentPage,
                reason = "missingScheduler",
                deferredToken = token,
                invalidatedToken = Browse.deferredSearchToken,
                opId = opId,
                searchPendingAfter = Browse.searchPending == true,
            })
            if TH.ClearPendingOperation then
                TH.ClearPendingOperation("search")
            end
        end
        return true
    end

    Browse.searchPending = true
    Browse.deferredSearchToken = Browse.deferredSearchToken + 1
    local token = Browse.deferredSearchToken
    local sortType = GetTradingHouseBrowseSortType()
    local sortAscending = Browse.sortAscending ~= false
    local opId = TH.BeginPendingOperation and TH.BeginPendingOperation("search", "trading_house.search", {
        fn = "TradingHouse.BrowseComponent.ExecuteSearch",
        feature = "trading-house-browse",
        page = Browse.currentPage,
        sortType = sortType,
        sortAscending = sortAscending,
        reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
        deferredToken = token,
    }, false) or nil
    ExecuteTradingHouseSearch(Browse.currentPage, sortType, sortAscending,
        useLastExecutedSearchFilters == true)
    TraceBrowse("trading_house.search", "requested", TH.instance, {
        fn = "TradingHouse.BrowseComponent.ExecuteSearch",
        page = Browse.currentPage,
        sortType = sortType,
        sortAscending = sortAscending,
        reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
        deferredToken = token,
        opId = opId,
    })
    return true
end

---@param itemLink string
---@param thInstance BETTERUI.TradingHouse.Class|nil
---@return boolean dispatched
function Browse:SearchForItemLink(itemLink, thInstance)
    if type(itemLink) ~= "string" or itemLink == "" then
        return false
    end
    if not (TRADING_HOUSE_SEARCH and type(TRADING_HOUSE_SEARCH.LoadSearchItem) == "function") then
        TraceBrowse("trading_house.search_item", "blocked", thInstance or TH.instance, {
            fn = "TradingHouse.BrowseComponent.SearchForItemLink",
            reason = "missingLoadSearchItem",
        })
        return false
    end

    if TH.BrowseFilters and TH.BrowseFilters.AssociateSearchFeatures then
        TH.BrowseFilters.AssociateSearchFeatures()
    end
    TRADING_HOUSE_SEARCH:LoadSearchItem(itemLink)

    local instance = thInstance or TH.instance
    if instance and instance.GetCurrentMode and instance:GetCurrentMode() ~= TH.MODE.BROWSE
        and instance.SetMode then
        instance:SetMode(TH.MODE.BROWSE)
    end

    TraceBrowse("trading_house.search_item", "loaded", instance, {
        fn = "TradingHouse.BrowseComponent.SearchForItemLink",
        itemLink = itemLink,
    })
    return Browse:ExecuteSearch()
end

function Browse:NextPage(thInstance)
    if not Browse.hasMorePages then
        TraceBrowse("trading_house.page", "next_skipped", thInstance, {
            fn = "TradingHouse.BrowseComponent.NextPage",
            reason = "noMorePages",
            page = Browse.currentPage,
        })
        return
    end
    -- Only commit the page change when the search actually dispatches.
    local USE_LAST_EXECUTED_SEARCH_FILTERS = true
    local previousPage = Browse.currentPage
    Browse.currentPage = previousPage + 1
    if not Browse:ExecuteSearch(USE_LAST_EXECUTED_SEARCH_FILTERS) then
        TraceBrowse("trading_house.page", "rollback", thInstance, {
            fn = "TradingHouse.BrowseComponent.NextPage",
            reason = "searchNotDispatched",
            rollbackFrom = Browse.currentPage,
            rollbackTo = previousPage,
        })
        Browse.currentPage = previousPage
    end
end

function Browse:PrevPage(thInstance)
    if Browse.currentPage <= 0 then
        TraceBrowse("trading_house.page", "prev_skipped", thInstance, {
            fn = "TradingHouse.BrowseComponent.PrevPage",
            reason = "firstPage",
            page = Browse.currentPage,
        })
        return
    end
    -- Only commit the page change when the search actually dispatches.
    local USE_LAST_EXECUTED_SEARCH_FILTERS = true
    local previousPage = Browse.currentPage
    Browse.currentPage = previousPage - 1
    if not Browse:ExecuteSearch(USE_LAST_EXECUTED_SEARCH_FILTERS) then
        TraceBrowse("trading_house.page", "rollback", thInstance, {
            fn = "TradingHouse.BrowseComponent.PrevPage",
            reason = "searchNotDispatched",
            rollbackFrom = Browse.currentPage,
            rollbackTo = previousPage,
        })
        Browse.currentPage = previousPage
    end
end

function Browse:OnSearchResultsReceived(thInstance)
    TraceBrowse("trading_house.search_results", "received", thInstance, {
        fn = "TradingHouse.BrowseComponent.OnSearchResultsReceived",
        page = Browse.currentPage,
        searchPendingBefore = Browse.searchPending == true,
        hadMorePagesBefore = Browse.hasMorePages == true,
    })
    Browse.searchPending = false
    Browse.deferredSearchToken = (Browse.deferredSearchToken or 0) + 1
    Browse.hasMorePages = false
    Browse.resultsInvalidated = false
    -- Each server page has its own result-category set. Begin on All Items and
    -- rebuild the carousel from the rows returned for this page.
    Browse.selectedCategoryKey = "__all"

    -- API 50: GetNumTradingHouseSearchResultsPages was removed. Paging state
    -- now comes from GetTradingHouseSearchResultsInfo() which returns
    -- numItemsOnPage, currentPage, hasMorePages.
    if GetTradingHouseSearchResultsInfo then
        local numItemsOnPage, currentPage, hasMorePages = GetTradingHouseSearchResultsInfo()
        if currentPage ~= nil then
            Browse.currentPage = currentPage
        end
        Browse.hasMorePages = hasMorePages == true
        TraceBrowse("trading_house.search_results", "state", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnSearchResultsReceived",
            numItemsOnPage = numItemsOnPage,
            currentPage = Browse.currentPage,
            hasMorePages = Browse.hasMorePages,
            resultsInvalidated = Browse.resultsInvalidated == true,
        })
    end

    if thInstance and thInstance:IsSceneShowing() and
       thInstance:GetCurrentMode() == TH.MODE.BROWSE then
        thInstance:RefreshList()
        if thInstance.UpdateTabHeader then
            thInstance:UpdateTabHeader()
        end
        TraceBrowse("trading_house.search_results", "list_refreshed", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnSearchResultsReceived",
            page = Browse.currentPage,
            mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
            sceneShowing = true,
        })
    else
        TraceBrowse("trading_house.search_results", "list_refresh_skipped", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnSearchResultsReceived",
            page = Browse.currentPage,
            reason = "sceneHiddenOrModeMismatch",
            hasInstance = thInstance ~= nil,
            mode = thInstance and thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
            sceneShowing = thInstance and thInstance.IsSceneShowing and thInstance:IsSceneShowing() or false,
        })
    end
end

function Browse:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end
    Browse.categories = nil
    if TH.InstallTradingHouseSectionRowSetup then
        TH.InstallTradingHouseSectionRowSetup()
    end
    ConfigureBrowseColumns(thInstance)

    -- Stale results (e.g. after a guild switch) reference tradingHouseIndex
    -- rows that are no longer purchasable; render nothing until a fresh
    -- search response arrives.
    if Browse.resultsInvalidated then
        TraceBrowse("th.list", "end", thInstance, {
            fn = "TradingHouse.BrowseComponent.BuildList",
            mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
            count = 0,
            reason = "resultsInvalidated",
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
        return
    end

    -- API 50: GetNumTradingHouseSearchResults was removed; the on-page result
    -- count is the first return of GetTradingHouseSearchResultsInfo().
    local numResults = 0
    if GetTradingHouseSearchResultsInfo then
        numResults = GetTradingHouseSearchResultsInfo() or 0
    end
    TraceBrowse("trading_house.browse_list", "build", thInstance, {
        fn = "TradingHouse.BrowseComponent.BuildList",
        resultCount = numResults,
        page = Browse.currentPage,
        hasMorePages = Browse.hasMorePages == true,
        resultsInvalidated = Browse.resultsInvalidated == true,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
    if numResults == 0 then
        TraceBrowse("th.list", "end", thInstance, {
            fn = "TradingHouse.BrowseComponent.BuildList",
            mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
            count = 0,
            resultCount = numResults,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
        return
    end

    if type(GetTradingHouseSearchResultItemInfo) ~= "function" then
        TraceBrowse("th.list", "end", thInstance, {
            fn = "TradingHouse.BrowseComponent.BuildList",
            mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
            count = 0,
            resultCount = numResults,
            reason = "missingSearchResultInfo",
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
        return
    end

    local rows = {}
    for i = 1, numResults do
        local icon, itemName, displayQuality, stackCount, sellerName, timeRemaining,
              purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit
              = GetTradingHouseSearchResultItemInfo(i)

        -- Purchased results return stackCount 0 and must not re-render as buyable.
        local normalizedName = NormalizeItemName(itemName)
        local stack = tonumber(stackCount) or 0
        if normalizedName and stack > 0 then
            local itemLink = GetTradingHouseSearchResultItemLink and GetTradingHouseSearchResultItemLink(i) or nil
            local quality = displayQuality or rawget(_G, "ITEM_DISPLAY_QUALITY_NORMAL") or 1
            local bestCategoryName = ""
            if itemLink and GetItemLinkItemType then
                local itemType = GetItemLinkItemType(itemLink)
                if itemType and itemType ~= rawget(_G, "ITEMTYPE_NONE") and type(GetString) == "function" then
                    bestCategoryName = GetString("SI_ITEMTYPE", itemType)
                end
            end

            local traitName = nil
            if itemLink and GetItemLinkTraitInfo then
                local traitType = GetItemLinkTraitInfo(itemLink)
                if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                    traitName = string.upper(GetString("SI_ITEMTRAITTYPE", traitType))
                end
            end

            local resolvedUnitPrice = ResolveUnitPrice(purchasePricePerUnit, purchasePrice, stack)
            local resolvedPurchasePrice = tonumber(purchasePrice) or 0
            local itemData = {
                tradingHouseIndex = i,
                name             = normalizedName,
                icon             = icon,
                stackCount       = stack,
                purchasePrice    = resolvedPurchasePrice,
                unitPrice        = resolvedUnitPrice,
                currencyType     = currencyType or rawget(_G, "CURT_MONEY"),
                quality          = quality,
                sellerName       = sellerName or "",
                timeRemaining    = tonumber(timeRemaining) or 0,
                itemLink         = itemLink,
                itemUniqueId     = itemUniqueId,
                traitName        = traitName,
                bestGamepadItemCategoryName = bestCategoryName,
                statValue        = "",
                thColumnMode     = "browse",
                thColumn1Text    = TH.FormatTradingHouseListingTimeRemaining(timeRemaining),
                thColumn1Align   = RIGHT,
                thUnitText       = TH.FormatTradingHouseColumnCurrency(resolvedUnitPrice),
                thTotalText      = TH.FormatTradingHouseColumnCurrency(resolvedPurchasePrice),
                thMarketText     = TH.FormatTradingHouseMarketTotal
                    and TH.FormatTradingHouseMarketTotal(itemLink, stack) or "-",
            }

            rows[#rows + 1] = TH.ListCategories.Annotate(itemData)
        end
    end

    SortBrowseRows(rows)
    rows = TH.ListCategories.Prepare(Browse, rows)
    if TH.ListSearch then
        rows = TH.ListSearch.FilterRows(thInstance, rows)
    end

    local renderedCount = 0
    for _, itemData in ipairs(rows) do
        local quality = itemData.quality

        local entry = ZO_GamepadEntryData:New(itemData.name, itemData.icon)
        entry:SetDataSource(itemData)
        entry.narrationText = GetEntryNarrationText

        if quality and type(GetItemQualityColor) == "function" then
            local color = GetItemQualityColor(quality)
            if color and color.UnpackRGBA and ZO_ColorDef then
                local r, g, b = color:UnpackRGBA()
                entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
            end
        end

        list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry, nil, nil, 30, 30)
        renderedCount = renderedCount + 1
    end
    TraceBrowse("th.list", "end", thInstance, {
        fn = "TradingHouse.BrowseComponent.BuildList",
        mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
        count = renderedCount,
        resultCount = numResults,
        page = Browse.currentPage,
        sortKey = Browse.sortKey,
        sortAscending = Browse.sortAscending ~= false,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
end

function Browse:GetCategories()
    return TH.ListCategories.Get(Browse)
end

function Browse:SetCategory(categoryKey, thInstance)
    TH.ListCategories.Set(Browse, categoryKey, thInstance)
end

-- Compatibility aliases for saved integrations that used the first Browse-only
-- category implementation.
Browse.GetResultCategories = Browse.GetCategories
Browse.SetResultCategory = Browse.SetCategory
