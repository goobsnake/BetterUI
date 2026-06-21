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
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local bagId    = ds.bagId
    local slotIndex = ds.slotIndex
    if not bagId or not slotIndex then return end

    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "trading house sell item started", { name = ds.name, bagId = bagId, slotIndex = slotIndex })
    end

    -- Gate on the guild's sell privilege first, matching the native sell
    -- screen (tradinghouse_sell_gamepad.lua:178-179). Without sell permission
    -- in the selected guild the post would be rejected server-side.
    if CanSellOnTradingHouse and GetSelectedTradingHouseGuildId then
        if not CanSellOnTradingHouse(GetSelectedTradingHouseGuildId()) then
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
        BETTERUI.CIM.UserAlertText("TH:CannotList",
            GetString(rawget(_G, "SI_BETTERUI_TH_CANNOT_LIST")) or "This item cannot be listed")
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

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIST, "sell list built", { slots = bagSlots })
    end

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
