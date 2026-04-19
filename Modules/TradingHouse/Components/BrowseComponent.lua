-- Trading House browse tab component.

local TH = BETTERUI.TradingHouse

---@class THComponent
---@field Activate fun(self: THComponent, thInstance: BETTERUI.TradingHouse.Class)
---@field Deactivate fun(self: THComponent, thInstance: BETTERUI.TradingHouse.Class)
---@field GetPrimaryActionName fun(self: THComponent, thInstance?: BETTERUI.TradingHouse.Class): string
---@field IsPrimaryActionEnabled fun(self: THComponent, thInstance: BETTERUI.TradingHouse.Class): boolean
---@field OnPrimaryAction fun(self: THComponent, thInstance: BETTERUI.TradingHouse.Class)
---@field BuildList fun(self: THComponent, thInstance: BETTERUI.TradingHouse.Class)

TH.BrowseComponent = {}
local Browse = TH.BrowseComponent

Browse.currentPage = 0
Browse.hasMorePages = false
Browse.searchPending = false

---@param thInstance BETTERUI.TradingHouse.Class
function Browse:Activate(thInstance)
    thInstance:RefreshList()
end

---@param thInstance BETTERUI.TradingHouse.Class
function Browse:Deactivate(thInstance)
end

---@return string name Localized action label
function Browse:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_TRADING_HOUSE_PURCHASE") or "SI_TRADING_HOUSE_PURCHASE")
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return boolean enabled True if a purchase is possible
function Browse:IsPrimaryActionEnabled(thInstance)
    local selectedData = thInstance.list and thInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    local price = ds.purchasePrice or 0
    return price > 0 and thInstance:CanAfford(price) and thInstance:HasInventorySpace()
end

---@param thInstance BETTERUI.TradingHouse.Class
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

--- Initiates a guild store search.
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

--- Go to next page of results.
function Browse:NextPage(thInstance)
    if Browse.hasMorePages then
        Browse.currentPage = Browse.currentPage + 1
        Browse:ExecuteSearch()
    end
end

--- Go to previous page of results.
function Browse:PrevPage(thInstance)
    if Browse.currentPage > 0 then
        Browse.currentPage = Browse.currentPage - 1
        Browse:ExecuteSearch()
    end
end

--- Called when search results are received from the server.
function Browse:OnSearchResultsReceived(thInstance)
    Browse.searchPending = false
    Browse.hasMorePages = false

    -- Check if there are more pages
    if GetNumTradingHouseSearchResultsPages then
        local totalPages = GetNumTradingHouseSearchResultsPages()
        Browse.hasMorePages = (Browse.currentPage + 1) < totalPages
    end

    if thInstance and thInstance:IsSceneShowing() and
       thInstance:GetCurrentMode() == TH.MODE.BROWSE then
        thInstance:RefreshList()
    end
end

-- LIST BUILDING

---@param thInstance BETTERUI.TradingHouse.Class
function Browse:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end

    local numResults = GetNumTradingHouseSearchResults and GetNumTradingHouseSearchResults() or 0
    if numResults == 0 then return end

    for i = 1, numResults do
        local icon, itemName, displayQuality, stackCount, sellerName, timeRemaining,
              purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit
              = GetTradingHouseSearchResultItemInfo(i)

        if itemName and itemName ~= "" then
            local itemLink = GetTradingHouseSearchResultItemLink and GetTradingHouseSearchResultItemLink(i) or nil
            local quality = displayQuality or ITEM_DISPLAY_QUALITY_NORMAL

            -- Get category name from item link
            local bestCategoryName = ""
            if itemLink and GetItemLinkItemType then
                local itemType = GetItemLinkItemType(itemLink)
                if itemType and itemType ~= ITEMTYPE_NONE then
                    bestCategoryName = GetString("SI_ITEMTYPE", itemType)
                end
            end

            -- Get trait info
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
