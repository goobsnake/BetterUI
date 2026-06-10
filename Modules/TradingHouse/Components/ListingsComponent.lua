--[[
File: Modules/TradingHouse/Components/ListingsComponent.lua
Purpose: Listings tab component for the Trading House module.

Shows the player's active guild store listings and supports
cancellation via CancelTradingHouseListing.
]]

local TH = BETTERUI.TradingHouse

-- COMPONENT TABLE
TH.ListingsComponent = {}
local Listings = TH.ListingsComponent

-- ACTIVATE / DEACTIVATE

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:Activate(thInstance)
    -- Request fresh listing data from server
    if RequestTradingHouseListings then
        RequestTradingHouseListings()
    end
    thInstance:RefreshList()
end

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:Deactivate(thInstance)
    -- No cleanup needed
end

-- PRIMARY ACTION

---@return string name Localized action label
function Listings:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_BETTERUI_TH_CANCEL_LISTING") or "SI_TRADING_HOUSE_CANCEL_LISTING")
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return boolean enabled True if cancellation is possible
function Listings:IsPrimaryActionEnabled(thInstance)
    local selectedData = thInstance.list and thInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    return ds.listingIndex ~= nil
end

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:OnPrimaryAction(thInstance)
    local selectedData = thInstance.list and thInstance.list:GetSelectedData()
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local listingIndex = ds.listingIndex
    if not listingIndex then return end

    -- Show cancel confirmation
    ZO_Dialogs_ShowGamepadDialog("CONFIRM_TRADING_HOUSE_CANCEL_LISTING", {
        listingIndex = listingIndex,
        currentHouseId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil,
    })
end

-- LIST BUILDING

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end

    local numListings = GetNumTradingHouseListings and GetNumTradingHouseListings() or 0
    if numListings == 0 then return end

    for i = 1, numListings do
        -- API 50 return order: icon, itemName, displayQuality, stackCount,
        -- sellerName, timeRemaining, salePrice, currencyType, itemUniqueId,
        -- salePricePerUnit.
        local icon, itemName, displayQuality, stackCount, _, timeRemaining, price, _, itemUniqueId
            = GetTradingHouseListingItemInfo(i)

        if itemName and itemName ~= "" then
            local itemLink = GetTradingHouseListingItemLink and GetTradingHouseListingItemLink(i) or nil
            local quality  = displayQuality or ITEM_DISPLAY_QUALITY_NORMAL

            -- Category
            local bestCategoryName = ""
            if itemLink and GetItemLinkItemType then
                local itemType = GetItemLinkItemType(itemLink)
                if itemType and itemType ~= ITEMTYPE_NONE then
                    bestCategoryName = GetString("SI_ITEMTYPE", itemType)
                end
            end

            -- Trait
            local traitName = nil
            if itemLink and GetItemLinkTraitInfo then
                local traitType = GetItemLinkTraitInfo(itemLink)
                if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                    traitName = string.upper(GetString("SI_ITEMTRAITTYPE", traitType))
                end
            end

            -- Unit price
            local unitPrice = 0
            if price and stackCount and stackCount > 0 then
                unitPrice = math.floor(price / stackCount)
            end

            local itemData = {
                listingIndex   = i,
                name           = zo_strformat(SI_TOOLTIP_ITEM_NAME, itemName),
                icon           = icon,
                stackCount     = stackCount or 1,
                purchasePrice  = price or 0,
                unitPrice      = unitPrice,
                quality        = quality,
                timeRemaining  = timeRemaining,
                itemLink       = itemLink,
                itemUniqueId   = itemUniqueId,
                traitName      = traitName,
                bestGamepadItemCategoryName = bestCategoryName,
                statValue      = "",
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
