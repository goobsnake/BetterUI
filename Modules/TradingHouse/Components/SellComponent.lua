--[[
File: Modules/TradingHouse/Components/SellComponent.lua
Purpose: Sell tab component for the Trading House module.

Lists the player's sellable inventory items and handles posting
listings to the guild store via RequestPostItemOnTradingHouse.
]]

local TH = BETTERUI.TradingHouse

-- COMPONENT TABLE
TH.SellComponent = {}
local Sell = TH.SellComponent

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
function Sell:Activate(thInstance)
    thInstance:RefreshList()
end

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:Deactivate(thInstance)
    -- No cleanup needed
end

-- PRIMARY ACTION

---@return string name Localized action label
function Sell:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_BETTERUI_TH_LIST_ITEM") or "SI_TRADING_HOUSE_POST_ITEM")
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return boolean enabled True if listing is possible
function Sell:IsPrimaryActionEnabled(thInstance)
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Must have a valid bag/slot
    if not ds.bagId or not ds.slotIndex then return false end

    -- Item must be sellable at trading house
    if IsItemBound and ds.bagId and ds.slotIndex then
        if IsItemBound(ds.bagId, ds.slotIndex) then return false end
    end

    local itemLink = ds.itemLink or (GetItemLink and GetItemLink(ds.bagId, ds.slotIndex))
    if itemLink and GetItemLinkSellInformation then
        local sellInfo = GetItemLinkSellInformation(itemLink)
        if sellInfo == ITEM_SELL_INFORMATION_CANNOT_SELL
            or sellInfo == ITEM_SELL_INFORMATION_CANNOT_TRADE then
            return false
        end
    end

    if IsItemBoPAndTradeable and ds.bagId and ds.slotIndex then
        if IsItemBoPAndTradeable(ds.bagId, ds.slotIndex) then return false end
    end

    return true
end

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:OnPrimaryAction(thInstance)
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local bagId    = ds.bagId
    local slotIndex = ds.slotIndex
    if not bagId or not slotIndex then return end

    -- Check if item can be listed
    if IsItemBound and IsItemBound(bagId, slotIndex) then
        BETTERUI.CIM.UserAlertText("TH:BoundItem",
            GetString(rawget(_G, "SI_BETTERUI_TH_CANNOT_LIST_BOUND")))
        return
    end

    local itemLink = GetItemLink(bagId, slotIndex)
    if itemLink and GetItemLinkSellInformation then
        local sellInfo = GetItemLinkSellInformation(itemLink)
        if sellInfo == ITEM_SELL_INFORMATION_CANNOT_SELL
            or sellInfo == ITEM_SELL_INFORMATION_CANNOT_TRADE then
            BETTERUI.CIM.UserAlertText("TH:CannotList",
                GetString(rawget(_G, "SI_BETTERUI_TH_CANNOT_LIST")) or "This item cannot be listed")
            return
        end
    end

    if IsItemBoPAndTradeable and IsItemBoPAndTradeable(bagId, slotIndex) then
        BETTERUI.CIM.UserAlertText("TH:BoundItem",
            GetString(rawget(_G, "SI_BETTERUI_TH_CANNOT_LIST_BOUND")))
        return
    end

    -- Gate posting on the guild's listing cap.
    if GetTradingHouseListingCounts then
        local currentListings, maxListings = GetTradingHouseListingCounts()
        if currentListings and maxListings and currentListings >= maxListings then
            BETTERUI.CIM.UserAlertText("TH:ListingCap",
                GetString(rawget(_G, "SI_BETTERUI_TH_LISTING_CAP")) or "You have reached the maximum number of listings")
            return
        end
    end

    -- Show the listing dialog (stack count and price entry)
    local stackCount = GetSlotStackSize(bagId, slotIndex) or 1
    local itemLink = GetItemLink(bagId, slotIndex)
    local itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bagId, slotIndex))
    -- Single GetItemInfo call: icon plus the vendor sell price fallback.
    local icon, _, sellPrice = GetItemInfo(bagId, slotIndex)
    -- Use the native suggested-price helper when available
    -- (tradinghouse_shared.lua:72-77); fall back to vendor price * stack.
    local defaultPrice = 100
    if ZO_TradingHouse_CalculateItemSuggestedPostPrice then
        defaultPrice = ZO_TradingHouse_CalculateItemSuggestedPostPrice(bagId, slotIndex)
    elseif sellPrice then
        defaultPrice = sellPrice * stackCount
    end
    if defaultPrice <= 0 then
        defaultPrice = 100
    end

    ZO_Dialogs_ShowGamepadDialog("BETTERUI_TRADING_HOUSE_CREATE_LISTING", {
        bagId        = bagId,
        slotIndex    = slotIndex,
        stackCount   = stackCount,
        itemName     = itemName,
        itemLink     = itemLink,
        icon         = icon,
        defaultPrice = defaultPrice,
    })
end

-- LIST BUILDING

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end

    local bagId = BAG_BACKPACK
    local bagSlots = GetBagSize(bagId) or 0

    for slotIndex = 0, bagSlots - 1 do
        -- Skip empty slots
        local stackCount = GetSlotStackSize(bagId, slotIndex)
        if stackCount and stackCount > 0 then
            -- GetItemInfo returns: icon, stack, sellPrice, meetsUsageRequirement,
            -- locked, equipType, itemStyleId, functionalQuality, displayQuality.
            local icon, stack, sellPrice, _, locked,
                _, _, _, displayQuality = GetItemInfo(bagId, slotIndex)

            -- Skip bound/locked/stolen/untradeable items
            local isBound = IsItemBound and IsItemBound(bagId, slotIndex) or false
            local isStolen = IsItemStolen and IsItemStolen(bagId, slotIndex) or false
            local isBoPTradeable = IsItemBoPAndTradeable and IsItemBoPAndTradeable(bagId, slotIndex) or false
            local itemLink = GetItemLink(bagId, slotIndex)
            local sellInfo = itemLink and GetItemLinkSellInformation
                and GetItemLinkSellInformation(itemLink)
                or ITEM_SELL_INFORMATION_NONE
            local cannotSell = sellInfo == ITEM_SELL_INFORMATION_CANNOT_SELL

            if not isBound and not locked and not isStolen and not isBoPTradeable and not cannotSell and icon ~= nil then
                local itemName = GetItemName(bagId, slotIndex)
                if itemName and itemName ~= "" then
                    local quality  = displayQuality or ITEM_DISPLAY_QUALITY_NORMAL

                    -- Category
                    local bestCategoryName = ""
                    if GetItemType then
                        local itemType = GetItemType(bagId, slotIndex)
                        if itemType and itemType ~= ITEMTYPE_NONE then
                            bestCategoryName = GetString("SI_ITEMTYPE", itemType)
                        end
                    end

                    -- Trait
                    local traitName = nil
                    if GetItemTrait then
                        local traitType = GetItemTrait(bagId, slotIndex)
                        if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                            traitName = string.upper(GetString("SI_ITEMTRAITTYPE", traitType))
                        end
                    end

                    -- Stat / value
                    local statValue = ""
                    if itemLink and GetItemLinkArmorType then
                        local armorType = GetItemLinkArmorType(itemLink)
                        if armorType and armorType ~= ARMORTYPE_NONE then
                            statValue = GetString("SI_ARMORTYPE", armorType)
                        end
                    end

                    local itemData = {
                        bagId        = bagId,
                        slotIndex    = slotIndex,
                        name         = zo_strformat(SI_TOOLTIP_ITEM_NAME, itemName),
                        icon         = icon,
                        stackCount   = stack or 1,
                        sellPrice    = sellPrice or 0,
                        quality      = quality,
                        itemLink     = itemLink,
                        traitName    = traitName,
                        statValue    = statValue,
                        bestGamepadItemCategoryName = bestCategoryName,
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
    end
end
