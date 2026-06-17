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

-- Shared narration text helper avoids a per-entry closure allocation.
local function GetEntryNarrationText(entryData)
    local ds = entryData:GetDataSource()
    return ds and ds.name or ""
end

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

-- ACTIVATE / DEACTIVATE

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:Activate(thInstance)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "tradingHouseListingsActive")
    end
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
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    return ds.listingIndex ~= nil
end

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:OnPrimaryAction(thInstance)
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local listingIndex = ds.listingIndex
    if not listingIndex then return end

    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "tradingHouseCancelListingStart", { name = ds.name, index = listingIndex })
    end

    -- ZOS gamepad cancel flow (tradinghouse_listings_gamepad.lua): the gamepad
    -- TRADING_HOUSE_CONFIRM_REMOVE_LISTING dialog expects listingIndex/stackCount/price.
    local dialogItemData = {
        slotIndex = listingIndex,
        stackCount = ds.stackCount or 1,
        name = ds.name,
        displayQuality = ds.quality,
        currencyType = CURT_MONEY,
    }
    local price = ds.purchasePrice or 0
    if ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog then
        ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog(dialogItemData,
            "TRADING_HOUSE_CONFIRM_REMOVE_LISTING", price, ds.icon)
    else
        ZO_Dialogs_ShowGamepadDialog("TRADING_HOUSE_CONFIRM_REMOVE_LISTING", {
            listingIndex = listingIndex,
            stackCount = dialogItemData.stackCount,
            price = price,
        })
    end
end

-- LIST BUILDING

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end

    local numListings = GetNumTradingHouseListings and GetNumTradingHouseListings() or 0
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIST, "listingsBuildList", { count = numListings })
    end
    if numListings == 0 then return end

    for i = 1, numListings do
        -- API 50 return order: icon, itemName, displayQuality, stackCount,
        -- sellerName, timeRemaining, salePrice, currencyType, itemUniqueId,
        -- salePricePerUnit.
        local icon, itemName, displayQuality, stackCount, _, timeRemaining, price, _, itemUniqueId
            = GetTradingHouseListingItemInfo(i)

        -- Cancelled/empty listings can report stackCount 0; skip them.
        if itemName and itemName ~= "" and (stackCount or 0) > 0 then
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
            entry.narrationText = GetEntryNarrationText

            if quality then
                local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
            end

            list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
        end
    end
end
