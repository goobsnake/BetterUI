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
Sell.categories = Sell.categories or {}
Sell.selectedCategoryKey = Sell.selectedCategoryKey or "__all"

local function TraceSell(event, phase, thInstance, data, category)
    if type(TH.Trace) == "function" then
        data = data or {}
        data.feature = data.feature or "trading-house-sell"
        data.fn = data.fn or "TradingHouse.SellComponent"
        TH.Trace(category or (BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION), event, phase, thInstance or TH.instance, data)
    end
end

local function HeaderText(stringIdName, fallback)
    local stringId = rawget(_G, stringIdName)
    if stringId ~= nil and type(GetString) == "function" then
        local text = GetString(stringId)
        if text and text ~= "" then
            return text
        end
    end
    return fallback
end

local function SafeGetIndexedString(prefix, value)
    if type(GetString) ~= "function" or value == nil then
        return ""
    end
    return GetString(prefix, value) or ""
end

local SELL_COLUMNS = {
    { text = HeaderText("SI_BETTERUI_INV_HEADER_NAME", "NAME"), align = TEXT_ALIGN_LEFT, offset = 58, width = 500 },
    { text = "QTY", align = TEXT_ALIGN_RIGHT, offset = 516, width = 100 },
    { text = "UNIT", align = TEXT_ALIGN_RIGHT, offset = 704, width = 180 },
    { text = "TOTAL", align = TEXT_ALIGN_RIGHT, offset = 922, width = 140 },
    { text = "MARKET", align = TEXT_ALIGN_RIGHT, offset = 1117, width = 140 },
}

local function ApplySellHeaders(thInstance)
    if TH.InstallTradingHouseSectionRowSetup then
        TH.InstallTradingHouseSectionRowSetup()
    end
    if TH.SetTradingHouseSectionHeaders then
        TH.SetTradingHouseSectionHeaders(thInstance, SELL_COLUMNS)
    end
end

local function ClearSellSectionState(thInstance)
    if TH.RestoreTradingHouseSectionHeaders then
        TH.RestoreTradingHouseSectionHeaders(thInstance)
    end
    if TH.SetTradingHousePermissionMessage then
        TH.SetTradingHousePermissionMessage(thInstance, false)
    end
end

local function IsSellPermissionBlocked(thInstance)
    if not TH.IsTradingHouseSellPermittedForCurrentGuild then
        return false
    end
    local canSell, guildId, guildName, guildIndex = TH.IsTradingHouseSellPermittedForCurrentGuild()
    if canSell then
        return false
    end
    TraceSell("trading_house.sell_permission", "blocked", thInstance, {
        fn = "TradingHouse.SellComponent.IsSellPermissionBlocked",
        guildId = guildId,
        guildName = guildName,
        guildIndex = guildIndex,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
    return true
end

local function FormatColumnCurrency(value)
    if TH.FormatTradingHouseColumnCurrency then
        return TH.FormatTradingHouseColumnCurrency(value)
    end
    if BETTERUI and BETTERUI.FormatAbbreviatedNumber then
        return BETTERUI.FormatAbbreviatedNumber(value)
    end
    return tostring(value or 0)
end

local function FormatColumnUnit(totalPrice, quantity)
    if TH.FormatTradingHouseColumnUnitPrice then
        return TH.FormatTradingHouseColumnUnitPrice(totalPrice, quantity)
    end
    quantity = tonumber(quantity) or 0
    if quantity <= 0 then
        return "-"
    end
    return FormatColumnCurrency(math.floor((tonumber(totalPrice) or 0) / quantity))
end

local function ResolveSellDisplayPrices(itemLink, quantity, fallbackTotal)
    if type(TH.ResolveTradingHouseMarketPrices) ~= "function" then
        return nil, fallbackTotal, false
    end
    local unitPrice, marketTotal, hasMarketPrice =
        TH.ResolveTradingHouseMarketPrices(itemLink, quantity)
    return unitPrice, marketTotal or fallbackTotal, hasMarketPrice
end

Sell.ResolveSellDisplayPrices = ResolveSellDisplayPrices

local function CalculateSuggestedPostPrice(bagId, slotIndex, stackCount, sellPrice)
    local defaultPrice = 100
    if type(ZO_TradingHouse_CalculateItemSuggestedPostPrice) == "function" then
        defaultPrice = ZO_TradingHouse_CalculateItemSuggestedPostPrice(bagId, slotIndex) or defaultPrice
    elseif sellPrice then
        defaultPrice = sellPrice * (stackCount or 1)
    end
    if defaultPrice <= 0 then
        defaultPrice = 100
    end
    return math.floor(defaultPrice)
end

-- Shared narration text helper avoids a per-entry closure allocation.
local function GetEntryNarrationText(entryData)
    local ds = entryData:GetDataSource()
    return ds and ds.name or ""
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

-- ACTIVATE / DEACTIVATE

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:Activate(thInstance)
    ApplySellHeaders(thInstance)
    thInstance:RefreshList()
end

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:Deactivate(thInstance)
    ClearSellSectionState(thInstance)
end

-- PRIMARY ACTION

---@return string name Localized action label
function Sell:GetPrimaryActionName()
    return HeaderText("SI_BETTERUI_TH_LIST_ITEM", HeaderText("SI_TRADING_HOUSE_POST_ITEM", "List Item"))
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return boolean enabled True if listing is possible
function Sell:IsPrimaryActionEnabled(thInstance)
    if IsSellPermissionBlocked(thInstance) then
        return false
    end
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Must have a valid bag/slot
    if not ds.bagId or not ds.slotIndex then return false end

    -- Gate on the guild's sell privilege the same way the native sell screen
    -- does (tradinghouse_sell_gamepad.lua:178-179): the selected item is only
    -- listable when CanSellOnTradingHouse(selectedGuild) is true.
    if type(CanSellOnTradingHouse) == "function" and type(GetSelectedTradingHouseGuildId) == "function" then
        local guildId = GetSelectedTradingHouseGuildId()
        if guildId and not CanSellOnTradingHouse(guildId) then
            return false
        end
    end

    -- IsItemSellableOnTradingHouse is the engine's canonical sellability test
    -- (tradinghouse_sell_gamepad.lua:124). It already accounts for bound,
    -- locked, stolen, and BoP-tradeable state, so use it as the authority
    -- rather than a hand-rolled chain that produced false negatives (e.g.
    -- BoP-tradeable items that ARE sellable).
    if type(IsItemSellableOnTradingHouse) == "function" then
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
    if IsSellPermissionBlocked(thInstance) then
        local guildId = type(GetSelectedTradingHouseGuildId) == "function" and GetSelectedTradingHouseGuildId() or nil
        TraceSell("trading_house.create_listing", "blocked", thInstance, {
            fn = "TradingHouse.SellComponent.OnPrimaryAction",
            reason = "guildCannotSell",
            guildId = guildId,
            bagId = bagId,
            slotIndex = slotIndex,
        })
        BETTERUI.CIM.UserAlertText("TH:CannotSellGuild",
            HeaderText("SI_BETTERUI_TH_CANNOT_LIST", "This item cannot be listed"))
        return
    end

    -- IsItemSellableOnTradingHouse is the engine's canonical sellability test
    -- (tradinghouse_sell_gamepad.lua:124) and supersedes the previous
    -- hand-rolled bound/sell-info/BoP chain, which excluded sellable
    -- BoP-tradeable items.
    if type(IsItemSellableOnTradingHouse) == "function" and not IsItemSellableOnTradingHouse(bagId, slotIndex) then
        TraceSell("trading_house.create_listing", "blocked", thInstance, {
            fn = "TradingHouse.SellComponent.OnPrimaryAction",
            reason = "notSellableOnTradingHouse",
            bagId = bagId,
            slotIndex = slotIndex,
        })
        BETTERUI.CIM.UserAlertText("TH:CannotList",
            HeaderText("SI_BETTERUI_TH_CANNOT_LIST", "This item cannot be listed"))
        return
    end

    -- Gate posting on the guild's listing cap.
    if type(GetTradingHouseListingCounts) == "function" then
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
                HeaderText("SI_BETTERUI_TH_LISTING_CAP", "You have reached the maximum number of listings"))
            return
        end
    end

    -- Show the listing dialog (stack count and price entry)
    local stackCount = type(GetSlotStackSize) == "function" and (GetSlotStackSize(bagId, slotIndex) or 1) or 1
    local itemLink = type(GetItemLink) == "function" and GetItemLink(bagId, slotIndex) or nil
    local rawItemName = type(GetItemName) == "function" and GetItemName(bagId, slotIndex) or ""
    local itemName = type(zo_strformat) == "function" and zo_strformat(SI_TOOLTIP_ITEM_NAME, rawItemName) or rawItemName
    -- Single GetItemInfo call: icon plus the vendor sell price fallback.
    local icon, _, sellPrice
    if type(GetItemInfo) == "function" then
        icon, _, sellPrice = GetItemInfo(bagId, slotIndex)
    end
    -- Use the native suggested-price helper when available
    -- (tradinghouse_shared.lua:72-77); fall back to vendor price * stack.
    local defaultPrice = CalculateSuggestedPostPrice(bagId, slotIndex, stackCount, sellPrice)

    local L = BETTERUI and BETTERUI.Log
    local opId = nil
    if L and type(L.NewFlow) == "function" then
        opId = L.NewFlow("thOp")
    end
    opId = opId or "untracked"

    if type(ZO_Dialogs_ShowGamepadDialog) ~= "function" then
        TraceSell("trading_house.create_listing_dialog", "blocked", thInstance, {
            fn = "TradingHouse.SellComponent.OnPrimaryAction",
            reason = "missingDialogApi",
            bagId = bagId,
            slotIndex = slotIndex,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
        return
    end

    BETTERUI.CIM.Dialogs.ShowForOwner(thInstance, "BETTERUI_TRADING_HOUSE_CREATE_LISTING", {
        bagId        = bagId,
        slotIndex    = slotIndex,
        stackCount   = stackCount,
        itemName     = itemName,
        itemLink     = itemLink,
        icon         = icon,
        defaultPrice = defaultPrice,
        thOperation  = "create_listing",
        opId         = opId,
    })
    TraceSell("trading_house.create_listing_dialog", "shown", thInstance, {
        fn = "TradingHouse.SellComponent.OnPrimaryAction",
        dialog = "BETTERUI_TRADING_HOUSE_CREATE_LISTING",
        bagId = bagId,
        slotIndex = slotIndex,
        stackCount = stackCount,
        defaultPrice = defaultPrice,
        opId = opId,
        item = itemName,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
end

-- LIST BUILDING

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end
    Sell.categories = nil

    ApplySellHeaders(thInstance)
    if IsSellPermissionBlocked(thInstance) then
        if TH.SetTradingHousePermissionMessage then
            TH.SetTradingHousePermissionMessage(thInstance, true, TH.GetTradingHouseNoPermissionText and TH.GetTradingHouseNoPermissionText())
        end
        TraceSell("th.list", "end", thInstance, {
            fn = "TradingHouse.SellComponent.BuildList",
            mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
            count = 0,
            reason = "guildCannotSell",
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
        return
    elseif TH.SetTradingHousePermissionMessage then
        TH.SetTradingHousePermissionMessage(thInstance, false)
    end

    local bagId = BAG_BACKPACK
    if not bagId or type(GetBagSize) ~= "function" then
        TraceSell("trading_house.sell_list", "skipped", thInstance, {
            fn = "TradingHouse.SellComponent.BuildList",
            reason = "missingBagApi",
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
        return
    end
    local bagSlots = GetBagSize(bagId) or 0

    TraceSell("trading_house.sell_list", "build", thInstance, {
        fn = "TradingHouse.SellComponent.BuildList",
        bagId = bagId,
        bagSlots = bagSlots,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)

    local rows = {}
    for slotIndex = 0, bagSlots - 1 do
        -- Skip empty slots
        local stackCount = type(GetSlotStackSize) == "function" and GetSlotStackSize(bagId, slotIndex) or 0
        if stackCount and stackCount > 0 then
            -- GetItemInfo returns: icon, stack, sellPrice, meetsUsageRequirement,
            -- locked, equipType, itemStyleId, functionalQuality, displayQuality.
            local icon, stack, sellPrice, _, _,
                _, _, _, displayQuality
            if type(GetItemInfo) == "function" then
                icon, stack, sellPrice, _, _, _, _, _, displayQuality = GetItemInfo(bagId, slotIndex)
            end

            -- IsItemSellableOnTradingHouse is the engine's canonical item filter
            -- (tradinghouse_sell_gamepad.lua:124). It is the single authority for
            -- listability and already covers bound/locked/stolen/BoP-tradeable/
            -- cannot-sell state, so the previous hand-rolled exclusion chain
            -- (which wrongly dropped sellable BoP-tradeable items) is removed.
            local isSellable = (type(IsItemSellableOnTradingHouse) ~= "function")
                or IsItemSellableOnTradingHouse(bagId, slotIndex)
            local itemLink = type(GetItemLink) == "function" and GetItemLink(bagId, slotIndex) or nil

            if isSellable and icon ~= nil then
                local itemName = type(GetItemName) == "function" and GetItemName(bagId, slotIndex) or nil
                if itemName and itemName ~= "" then
                    local quality  = displayQuality or ITEM_DISPLAY_QUALITY_NORMAL
                    local displayStack = stack or stackCount or 1
                    local suggestedPrice = CalculateSuggestedPostPrice(bagId, slotIndex, displayStack, sellPrice)

                    -- Category
                    local bestCategoryName = ""
                    if type(GetItemType) == "function" then
                        local itemType = GetItemType(bagId, slotIndex)
                        if itemType and itemType ~= ITEMTYPE_NONE then
                            bestCategoryName = SafeGetIndexedString("SI_ITEMTYPE", itemType)
                        end
                    end

                    -- Trait
                    local traitName = nil
                    if type(GetItemTrait) == "function" then
                        local traitType = GetItemTrait(bagId, slotIndex)
                        if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                            traitName = string.upper(SafeGetIndexedString("SI_ITEMTRAITTYPE", traitType))
                        end
                    end

                    -- Stat / value
                    local statValue = ""
                    if itemLink and type(GetItemLinkArmorType) == "function" then
                        local armorType = GetItemLinkArmorType(itemLink)
                        if armorType and armorType ~= ARMORTYPE_NONE then
                            statValue = SafeGetIndexedString("SI_ARMORTYPE", armorType)
                        end
                    end

                    local _, marketTotalPrice, usesMarketPrice =
                        ResolveSellDisplayPrices(itemLink, displayStack, suggestedPrice)
                    local displayUnitText = FormatColumnUnit(suggestedPrice, displayStack)

                    local itemData = {
                        bagId        = bagId,
                        slotIndex    = slotIndex,
                        name         = type(zo_strformat) == "function" and zo_strformat(SI_TOOLTIP_ITEM_NAME, itemName) or itemName,
                        icon         = icon,
                        stackCount   = displayStack,
                        vendorSellPrice = sellPrice or 0,
                        stackSellPrice = suggestedPrice,
                        quality      = quality,
                        itemLink     = itemLink,
                        traitName    = FormatColumnUnit(suggestedPrice, displayStack),
                        statValue    = "",
                        bestGamepadItemCategoryName = tostring(displayStack),
                        thColumnMode = "sell",
                        thColumn1Text = tostring(displayStack),
                        thColumn1Align = RIGHT,
                        thUnitText = displayUnitText,
                        thTotalText = FormatColumnCurrency(suggestedPrice),
                        thMarketText = TH.FormatTradingHouseMarketValue(marketTotalPrice, usesMarketPrice),
                        usesMarketPrice = usesMarketPrice,
                        originalTraitName = traitName,
                        originalStatValue = statValue,
                        originalBestGamepadItemCategoryName = bestCategoryName,
                    }

                    rows[#rows + 1] = TH.ListCategories.Annotate(itemData)
                end
            end
        end
    end

    rows = TH.ListCategories.Prepare(Sell, rows)
    if TH.ListSearch then
        rows = TH.ListSearch.FilterRows(thInstance, rows)
    end
    local renderedCount = 0
    for _, itemData in ipairs(rows) do
        local entry = ZO_GamepadEntryData:New(itemData.name, itemData.icon)
        entry:SetDataSource(itemData)
        entry.narrationText = GetEntryNarrationText

        if itemData.quality and type(GetItemQualityColor) == "function" and ZO_ColorDef and ZO_ColorDef.New then
            local r, g, b = GetItemQualityColor(itemData.quality):UnpackRGBA()
            entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
        end

        list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry, nil, nil, 30, 30)
        renderedCount = renderedCount + 1
    end
    TraceSell("th.list", "end", thInstance, {
        fn = "TradingHouse.SellComponent.BuildList",
        mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
        count = renderedCount,
        bagSlots = bagSlots,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
end

function Sell:GetCategories()
    return TH.ListCategories.Get(Sell)
end

function Sell:SetCategory(categoryKey, thInstance)
    TH.ListCategories.Set(Sell, categoryKey, thInstance)
end
