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

local function TraceSell(event, phase, thInstance, data, category)
    if type(TH.Trace) == "function" then
        data = data or {}
        data.feature = data.feature or "trading-house-sell"
        data.fn = data.fn or "TradingHouse.SellComponent"
        TH.Trace(category or (BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION), event, phase, thInstance or TH.instance, data)
    end
end

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

    -- Gate on the guild's sell privilege the same way the native sell screen
    -- does (tradinghouse_sell_gamepad.lua:178-179): the selected item is only
    -- listable when CanSellOnTradingHouse(selectedGuild) is true.
    if CanSellOnTradingHouse and GetSelectedTradingHouseGuildId then
        if not CanSellOnTradingHouse(GetSelectedTradingHouseGuildId()) then
            return false
        end
    end

    -- IsItemSellableOnTradingHouse is the engine's canonical sellability test
    -- (tradinghouse_sell_gamepad.lua:124). It already accounts for bound,
    -- locked, stolen, and BoP-tradeable state, so use it as the authority
    -- rather than a hand-rolled chain that produced false negatives (e.g.
    -- BoP-tradeable items that ARE sellable).
    if IsItemSellableOnTradingHouse then
        return IsItemSellableOnTradingHouse(ds.bagId, ds.slotIndex) == true
    end

    return true
end

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:OnPrimaryAction(thInstance)
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then
        TraceSell("trading_house.create_listing", "blocked", thInstance, {
            fn = "TradingHouse.SellComponent.OnPrimaryAction",
            reason = "noSelection",
        })
        return
    end
    local ds = selectedData.dataSource or selectedData

    local bagId    = ds.bagId
    local slotIndex = ds.slotIndex
    if not bagId or not slotIndex then
        TraceSell("trading_house.create_listing", "blocked", thInstance, {
            fn = "TradingHouse.SellComponent.OnPrimaryAction",
            reason = "missingBagSlot",
            bagId = bagId,
            slotIndex = slotIndex,
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        })
        return
    end

    TraceSell("trading_house.create_listing", "begin", thInstance, {
        fn = "TradingHouse.SellComponent.OnPrimaryAction",
        bagId = bagId,
        slotIndex = slotIndex,
        item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
    })

    -- Gate on the guild's sell privilege first, matching the native sell
    -- screen (tradinghouse_sell_gamepad.lua:178-179). Without sell permission
    -- in the selected guild the post would be rejected server-side.
    if CanSellOnTradingHouse and GetSelectedTradingHouseGuildId then
        if not CanSellOnTradingHouse(GetSelectedTradingHouseGuildId()) then
            TraceSell("trading_house.create_listing", "blocked", thInstance, {
                fn = "TradingHouse.SellComponent.OnPrimaryAction",
                reason = "guildCannotSell",
                guildId = GetSelectedTradingHouseGuildId(),
                bagId = bagId,
                slotIndex = slotIndex,
            })
            BETTERUI.CIM.UserAlertText("TH:CannotSellGuild",
                GetString(rawget(_G, "SI_BETTERUI_TH_CANNOT_LIST")) or "This item cannot be listed")
            return
        end
    end

    -- IsItemSellableOnTradingHouse is the engine's canonical sellability test
    -- (tradinghouse_sell_gamepad.lua:124) and supersedes the previous
    -- hand-rolled bound/sell-info/BoP chain, which excluded sellable
    -- BoP-tradeable items.
    if IsItemSellableOnTradingHouse and not IsItemSellableOnTradingHouse(bagId, slotIndex) then
        TraceSell("trading_house.create_listing", "blocked", thInstance, {
            fn = "TradingHouse.SellComponent.OnPrimaryAction",
            reason = "notSellableOnTradingHouse",
            bagId = bagId,
            slotIndex = slotIndex,
        })
        BETTERUI.CIM.UserAlertText("TH:CannotList",
            GetString(rawget(_G, "SI_BETTERUI_TH_CANNOT_LIST")) or "This item cannot be listed")
        return
    end

    -- Gate posting on the guild's listing cap.
    if GetTradingHouseListingCounts then
        local currentListings, maxListings = GetTradingHouseListingCounts()
        if currentListings and maxListings and currentListings >= maxListings then
            TraceSell("trading_house.create_listing", "blocked", thInstance, {
                fn = "TradingHouse.SellComponent.OnPrimaryAction",
                reason = "listingCap",
                currentListings = currentListings,
                maxListings = maxListings,
                bagId = bagId,
                slotIndex = slotIndex,
            })
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
    TraceSell("trading_house.create_listing_dialog", "shown", thInstance, {
        fn = "TradingHouse.SellComponent.OnPrimaryAction",
        dialog = "BETTERUI_TRADING_HOUSE_CREATE_LISTING",
        bagId = bagId,
        slotIndex = slotIndex,
        stackCount = stackCount,
        defaultPrice = defaultPrice,
        item = itemName,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
end

-- LIST BUILDING

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end

    local bagId = BAG_BACKPACK
    local bagSlots = GetBagSize(bagId) or 0

    TraceSell("trading_house.sell_list", "build", thInstance, {
        fn = "TradingHouse.SellComponent.BuildList",
        bagId = bagId,
        bagSlots = bagSlots,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)

    for slotIndex = 0, bagSlots - 1 do
        -- Skip empty slots
        local stackCount = GetSlotStackSize(bagId, slotIndex)
        if stackCount and stackCount > 0 then
            -- GetItemInfo returns: icon, stack, sellPrice, meetsUsageRequirement,
            -- locked, equipType, itemStyleId, functionalQuality, displayQuality.
            local icon, stack, sellPrice, _, _,
                _, _, _, displayQuality = GetItemInfo(bagId, slotIndex)

            -- IsItemSellableOnTradingHouse is the engine's canonical item filter
            -- (tradinghouse_sell_gamepad.lua:124). It is the single authority for
            -- listability and already covers bound/locked/stolen/BoP-tradeable/
            -- cannot-sell state, so the previous hand-rolled exclusion chain
            -- (which wrongly dropped sellable BoP-tradeable items) is removed.
            local isSellable = (not IsItemSellableOnTradingHouse)
                or IsItemSellableOnTradingHouse(bagId, slotIndex)
            local itemLink = GetItemLink(bagId, slotIndex)

            if isSellable and icon ~= nil then
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
