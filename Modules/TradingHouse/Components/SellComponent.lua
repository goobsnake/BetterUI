--[[
File: Modules/TradingHouse/Components/SellComponent.lua
Purpose: Sell tab component for the Trading House module.

Lists the player's sellable inventory items and handles posting
listings to the guild store via PostItemOnTradingHouse.
]]

local TH = BETTERUI.TradingHouse

-- COMPONENT TABLE
TH.SellComponent = {}
local Sell = TH.SellComponent

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
    local selectedData = thInstance.list and thInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Must have a valid bag/slot
    if not ds.bagId or not ds.slotIndex then return false end

    -- Item must be sellable at trading house
    if IsItemBound and ds.bagId and ds.slotIndex then
        if IsItemBound(ds.bagId, ds.slotIndex) then return false end
    end

    return true
end

---@param thInstance BETTERUI.TradingHouse.Class
function Sell:OnPrimaryAction(thInstance)
    local selectedData = thInstance.list and thInstance.list:GetSelectedData()
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

    -- Show the listing dialog (stack count and price entry)
    local stackCount = GetSlotStackSize(bagId, slotIndex) or 1
    local itemLink = GetItemLink(bagId, slotIndex)
    local itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bagId, slotIndex))
    local icon, _, _, _, _ = GetItemInfo(bagId, slotIndex)

    -- Derive a default listing price hint from the item's vendor sell price
    local defaultPrice
    if GetItemSellPriceWithBonus then
        defaultPrice = GetItemSellPriceWithBonus(bagId, slotIndex) * stackCount
    else
        local _, _, sellPrice = GetItemInfo(bagId, slotIndex)
        defaultPrice = (sellPrice or 0) * stackCount
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
            local icon, stack, sellPrice, _, locked,
                _, _, displayQuality = GetItemInfo(bagId, slotIndex)

            -- Skip bound/locked/stolen items
            local isBound = IsItemBound and IsItemBound(bagId, slotIndex) or false
            local isStolen = IsItemStolen and IsItemStolen(bagId, slotIndex) or false

            if not isBound and not locked and not isStolen and icon ~= nil then
                local itemName = GetItemName(bagId, slotIndex)
                if itemName and itemName ~= "" then
                    local itemLink = GetItemLink(bagId, slotIndex)
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
                    entry.narrationText = function() return itemData.name end

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
