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

Browse.currentPage = 0
Browse.hasMorePages = false
Browse.searchPending = false
Browse.resultsInvalidated = false
Browse.deferredSearchToken = 0
Browse.pendingBuyTrace = nil
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
    local opId = TH.BeginPendingOperation and TH.BeginPendingOperation("search", "trading_house.search", {
        fn = "TradingHouse.BrowseComponent.ExecuteSearch",
        feature = "trading-house-browse",
        page = Browse.currentPage,
        sortType = TRADING_HOUSE_SORT_SALE_PRICE,
        sortAscending = true,
        reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
        deferredToken = token,
    }, false) or nil
    ExecuteTradingHouseSearch(Browse.currentPage, TRADING_HOUSE_SORT_SALE_PRICE, true,
        useLastExecutedSearchFilters == true)
    TraceBrowse("trading_house.search", "requested", TH.instance, {
        fn = "TradingHouse.BrowseComponent.ExecuteSearch",
        page = Browse.currentPage,
        sortType = TRADING_HOUSE_SORT_SALE_PRICE,
        sortAscending = true,
        reuseLastExecutedSearchFilters = useLastExecutedSearchFilters == true,
        deferredToken = token,
        opId = opId,
    })
    return true
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

    local renderedCount = 0
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
            renderedCount = renderedCount + 1
        end
    end
    TraceBrowse("th.list", "end", thInstance, {
        fn = "TradingHouse.BrowseComponent.BuildList",
        mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
        count = renderedCount,
        resultCount = numResults,
        page = Browse.currentPage,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
end
