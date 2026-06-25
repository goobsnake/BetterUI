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

-- Shared narration text helper avoids a per-entry closure allocation.
local function GetEntryNarrationText(entryData)
    local ds = entryData:GetDataSource()
    return ds and ds.name or ""
end

Browse.currentPage = 0
Browse.hasMorePages = false
Browse.searchPending = false
Browse.resultsInvalidated = false

--- Resolve the focused row the same way the Vendor keybind strip does
--- (GetTargetData when available, falling back to GetSelectedData).
---@param thInstance BETTERUI.TradingHouse.Class|nil
---@return table|nil rowData
local function GetTargetRowData(thInstance)
    local list = thInstance and thInstance.list
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    return list:GetSelectedData()
end

--- Drops the current native search-result rows from rendering: their
--- tradingHouseIndex values are no longer purchasable (e.g. after a guild
--- switch). Cleared when fresh results arrive.
function Browse:InvalidateResults()
    Browse.resultsInvalidated = true
    Browse.hasMorePages = false
end

function Browse:Activate(thInstance)
    thInstance:RefreshList()
end

function Browse:Deactivate(thInstance)
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
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local tradingHouseIndex = ds.tradingHouseIndex
    local price = ds.purchasePrice or 0
    if not tradingHouseIndex or price <= 0 then return end

    TraceBrowse("trading_house.buy", "request", thInstance, {
        fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
        tradingHouseIndex = tradingHouseIndex,
        price = price,
        item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)

    if not thInstance:CanAfford(price) then
        BETTERUI.CIM.UserAlertText("TH:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    if not thInstance:HasInventorySpace() then
        BETTERUI.CIM.UserAlertText("TH:CannotCarry",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY")))
        return
    end

    -- ZOS gamepad purchase flow (tradinghouse_browseresults_gamepad.lua): stage
    -- the pending purchase, then show the native gamepad confirm dialog whose
    -- buttons call ConfirmPendingItemPurchase/ClearPendingItemPurchase.
    if SetPendingItemPurchase then
        SetPendingItemPurchase(tradingHouseIndex)
        TraceBrowse("trading_house.buy", "pending_set", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            tradingHouseIndex = tradingHouseIndex,
            price = price,
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
    end

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
        TraceBrowse("trading_house.buy_dialog", "shown", thInstance, {
            fn = "TradingHouse.BrowseComponent.OnPrimaryAction",
            dialog = "TRADING_HOUSE_CONFIRM_BUY_ITEM",
            path = "nativeGamepadConfirmation",
            tradingHouseIndex = tradingHouseIndex,
            price = price,
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
    else
        ZO_Dialogs_ShowGamepadDialog("TRADING_HOUSE_CONFIRM_BUY_ITEM", {
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
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
    end
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
        and not TRADING_HOUSE_SEARCH:CanPerformSearch() then
        Browse.searchPending = true
        TraceBrowse("trading_house.search", "deferred", TH.instance, {
            fn = "TradingHouse.BrowseComponent.ExecuteSearch",
            page = Browse.currentPage,
            reason = "nativeSearchNotReady",
            reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
        })
        TRADING_HOUSE_SEARCH:DoSearchWhenReady()
        return true
    end

    Browse.searchPending = true
    TraceBrowse("trading_house.search", "request", TH.instance, {
        fn = "TradingHouse.BrowseComponent.ExecuteSearch",
        page = Browse.currentPage,
        sortType = TRADING_HOUSE_SORT_SALE_PRICE,
        sortAscending = true,
        reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
    })
    ExecuteTradingHouseSearch(Browse.currentPage, TRADING_HOUSE_SORT_SALE_PRICE, true,
        useLastExecutedSearchFilters == true)
    TraceBrowse("trading_house.search", "requested", TH.instance, {
        fn = "TradingHouse.BrowseComponent.ExecuteSearch",
        page = Browse.currentPage,
        sortType = TRADING_HOUSE_SORT_SALE_PRICE,
        sortAscending = true,
        reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
    })
    return true
end

function Browse:NextPage(thInstance)
    if not Browse.hasMorePages then return end
    -- Only commit the page change when the search actually dispatches.
    local USE_LAST_EXECUTED_SEARCH_FILTERS = true
    local previousPage = Browse.currentPage
    Browse.currentPage = previousPage + 1
    if not Browse:ExecuteSearch(USE_LAST_EXECUTED_SEARCH_FILTERS) then
        Browse.currentPage = previousPage
    end
end

function Browse:PrevPage(thInstance)
    if Browse.currentPage <= 0 then return end
    -- Only commit the page change when the search actually dispatches.
    local USE_LAST_EXECUTED_SEARCH_FILTERS = true
    local previousPage = Browse.currentPage
    Browse.currentPage = previousPage - 1
    if not Browse:ExecuteSearch(USE_LAST_EXECUTED_SEARCH_FILTERS) then
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
    Browse.hasMorePages = false
    Browse.resultsInvalidated = false

    -- API 50: GetNumTradingHouseSearchResultsPages was removed. Paging state
    -- now comes from GetTradingHouseSearchResultsInfo() which returns
    -- numItemsOnPage, currentPage, hasMorePages.
    if GetTradingHouseSearchResultsInfo then
        local _, currentPage, hasMorePages = GetTradingHouseSearchResultsInfo()
        if currentPage ~= nil then
            Browse.currentPage = currentPage
        end
        Browse.hasMorePages = hasMorePages == true
    end

    if thInstance and thInstance:IsSceneShowing() and
       thInstance:GetCurrentMode() == TH.MODE.BROWSE then
        thInstance:RefreshList()
    end
end

function Browse:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end

    -- Stale results (e.g. after a guild switch) reference tradingHouseIndex
    -- rows that are no longer purchasable; render nothing until a fresh
    -- search response arrives.
    if Browse.resultsInvalidated then return end

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
    if numResults == 0 then return end

    for i = 1, numResults do
        local icon, itemName, displayQuality, stackCount, sellerName, timeRemaining,
              purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit
              = GetTradingHouseSearchResultItemInfo(i)

        -- Purchased results return stackCount 0 and must not re-render as buyable.
        if itemName and itemName ~= "" and (stackCount or 0) > 0 then
            local itemLink = GetTradingHouseSearchResultItemLink and GetTradingHouseSearchResultItemLink(i) or nil
            local quality = displayQuality or ITEM_DISPLAY_QUALITY_NORMAL

            local bestCategoryName = ""
            if itemLink and GetItemLinkItemType then
                local itemType = GetItemLinkItemType(itemLink)
                if itemType and itemType ~= ITEMTYPE_NONE then
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

            local itemData = {
                tradingHouseIndex = i,
                name             = zo_strformat(SI_TOOLTIP_ITEM_NAME, itemName),
                icon             = icon,
                stackCount       = stackCount or 1,
                purchasePrice    = purchasePrice or 0,
                unitPrice        = purchasePricePerUnit or (purchasePrice and stackCount and stackCount > 0 and math.floor(purchasePrice / stackCount) or 0),
                currencyType     = currencyType or CURT_MONEY,
                quality          = quality,
                sellerName       = sellerName or "",
                timeRemaining    = timeRemaining,
                itemLink         = itemLink,
                itemUniqueId     = itemUniqueId,
                traitName        = traitName,
                bestGamepadItemCategoryName = bestCategoryName,
                statValue        = "",
            }

            local entry = ZO_GamepadEntryData:New(itemData.name, itemData.icon)
            entry:SetDataSource(itemData)
            entry.narrationText = GetEntryNarrationText

            if quality then
                local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
            end

            list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
        end
    end
end
