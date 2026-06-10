-- Trading House browse tab component.

local TH = BETTERUI.TradingHouse

TH.BrowseComponent = {}
local Browse = TH.BrowseComponent

Browse.currentPage = 0
Browse.hasMorePages = false
Browse.searchPending = false

function Browse:Activate(thInstance)
    thInstance:RefreshList()
end

function Browse:Deactivate(thInstance)
end

function Browse:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_TRADING_HOUSE_PURCHASE") or "SI_TRADING_HOUSE_PURCHASE")
end

function Browse:IsPrimaryActionEnabled(thInstance)
    local selectedData = thInstance.list and thInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    local price = ds.purchasePrice or 0
    return price > 0 and thInstance:CanAfford(price) and thInstance:HasInventorySpace()
end

function Browse:OnPrimaryAction(thInstance)
    local selectedData = thInstance.list and thInstance.list:GetSelectedData()
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local tradingHouseIndex = ds.tradingHouseIndex
    local price = ds.purchasePrice or 0
    if not tradingHouseIndex or price <= 0 then return end

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

    ZO_Dialogs_ShowGamepadDialog("CONFIRM_TRADING_HOUSE_PURCHASE", {
        purchaseIndex = tradingHouseIndex,
        price = price,
    })
end

function Browse:ExecuteSearch()
    if Browse.searchPending then return end

    if GetTradingHouseCooldownRemaining and GetTradingHouseCooldownRemaining() > 0 then
        BETTERUI.CIM.UserAlertText("TH:Cooldown",
            GetString(rawget(_G, "SI_BETTERUI_TH_SEARCH_COOLDOWN")))
        return
    end

    Browse.searchPending = true
    if ExecuteTradingHouseSearch then
        ExecuteTradingHouseSearch(Browse.currentPage, TRADING_HOUSE_SORT_SALE_PRICE, true)
    end
end

function Browse:NextPage(thInstance)
    if Browse.hasMorePages then
        Browse.currentPage = Browse.currentPage + 1
        Browse:ExecuteSearch()
    end
end

function Browse:PrevPage(thInstance)
    if Browse.currentPage > 0 then
        Browse.currentPage = Browse.currentPage - 1
        Browse:ExecuteSearch()
    end
end

function Browse:OnSearchResultsReceived(thInstance)
    Browse.searchPending = false
    Browse.hasMorePages = false

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

    -- API 50: GetNumTradingHouseSearchResults was removed; the on-page result
    -- count is the first return of GetTradingHouseSearchResultsInfo().
    local numResults = 0
    if GetTradingHouseSearchResultsInfo then
        numResults = GetTradingHouseSearchResultsInfo() or 0
    end
    if numResults == 0 then return end

    for i = 1, numResults do
        local icon, itemName, displayQuality, stackCount, sellerName, timeRemaining,
              purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit
              = GetTradingHouseSearchResultItemInfo(i)

        if itemName and itemName ~= "" then
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
            entry.narrationText = function() return itemData.name end

            if quality then
                local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
            end

            list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
        end
    end
end
