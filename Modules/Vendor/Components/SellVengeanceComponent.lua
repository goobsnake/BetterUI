--[[
File: Modules/Vendor/Components/SellVengeanceComponent.lua
Purpose: Sell Vengeance tab component for the Vendor module.

Lists and sells items from BAG_VENGEANCE when the Vengeance ruleset is active.
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
Vendor.SellVengeanceComponent = Vendor.SellVengeanceComponent or {}
local SellVengeance = Vendor.SellVengeanceComponent

local function AuthorizeVendorAction(actionType, bagId, slotIndex, vendorInstance)
    local authorizeInventoryAction = Vendor.AuthorizeInventoryAction
    assert(type(authorizeInventoryAction) == "function",
        "Vendor.AuthorizeInventoryAction must load before Vendor sell vengeance actions")
    local allowed, reason = authorizeInventoryAction(actionType, bagId, slotIndex, vendorInstance)
    return allowed == true, reason
end

local function IsSellVengeanceAvailable()
    return rawget(_G, "BAG_VENGEANCE") ~= nil
        and rawget(_G, "ZO_VENGEANCE_BAG_SELL_ENABLED") == true
        and type(IsCurrentCampaignVengeanceRuleset) == "function"
        and IsCurrentCampaignVengeanceRuleset()
end

local function GetVengeanceBagId()
    return rawget(_G, "BAG_VENGEANCE")
end

local function BuildSellableVengeanceItems()
    local rows = {}
    local bagId = GetVengeanceBagId()
    if not IsSellVengeanceAvailable() or bagId == nil then
        return rows
    end

    local bagItems = SHARED_INVENTORY and SHARED_INVENTORY:GenerateFullSlotData(nil, bagId)
    if bagItems then
        for _, itemData in pairs(bagItems) do
            local slot = itemData
            local sellPrice = slot.sellPrice or slot.stackSellPrice or 0
            if sellPrice > 0 then
                rows[#rows + 1] = slot
            end
        end
        return rows
    end

    local bagSize = (type(GetBagSize) == "function" and GetBagSize(bagId)) or 0
    for slotIndex = 0, (bagSize or 0) - 1 do
        local icon, stackCount, sellPrice = GetItemInfo(bagId, slotIndex)
        if (sellPrice or 0) > 0 then
            rows[#rows + 1] = {
                bagId = bagId,
                slotIndex = slotIndex,
                iconFile = icon,
                stackCount = stackCount,
                sellPrice = sellPrice,
                name = GetItemName(bagId, slotIndex),
                itemLink = GetItemLink(bagId, slotIndex),
                quality = GetItemDisplayQuality(bagId, slotIndex),
            }
        end
    end

    return rows
end

function SellVengeance:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

function SellVengeance:Deactivate(_vendorInstance)
end

function SellVengeance:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_SELL") or "SI_ITEM_ACTION_SELL")
end

function SellVengeance:IsPrimaryActionEnabled(vendorInstance)
    if not IsSellVengeanceAvailable() then
        return false
    end

    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then
        return false
    end

    local ds = selectedData.dataSource or selectedData
    local sellPrice = ds.sellPrice or ds.stackSellPrice or 0
    if ds.bagId == nil or ds.slotIndex == nil or sellPrice <= 0 then
        return false
    end

    local allowed = AuthorizeVendorAction(Vendor.ACTION.SELL_VENGEANCE, ds.bagId, ds.slotIndex, vendorInstance)
    return allowed == true
end

function SellVengeance:OnPrimaryAction(vendorInstance)
    if not IsSellVengeanceAvailable() then
        return
    end

    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then
        return
    end

    local ds = selectedData.dataSource or selectedData
    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    if bagId == nil or slotIndex == nil then
        return
    end

    local canSell = AuthorizeVendorAction(Vendor.ACTION.SELL_VENGEANCE, bagId, slotIndex, vendorInstance)
    if canSell ~= true then
        return
    end

    local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
    if stackSize <= 0 then
        return
    end

    SellInventoryItem(bagId, slotIndex, stackSize)
end

function SellVengeance:GetCategories(_vendorInstance)
    return {
        {
            key = "all",
            name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE") or "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE"),
            iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
            itemCount = #BuildSellableVengeanceItems(),
        },
    }
end

function SellVengeance:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list or not IsSellVengeanceAvailable() then
        return
    end

    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil
    local bagId = GetVengeanceBagId()
    for _, slot in ipairs(BuildSellableVengeanceItems()) do
        local searchName = slot.name or (bagId and GetItemName(bagId, slot.slotIndex)) or ""
        if not Vendor.MatchesSearchQuery or Vendor.MatchesSearchQuery(searchQuery, searchName) then
            local sellPrice = slot.sellPrice or slot.stackSellPrice or 0
            local rowBagId = slot.bagId or bagId
            local rowSlotIndex = slot.slotIndex
            local stackCount = slot.stackCount or 1
            local name = slot.name or zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(rowBagId, rowSlotIndex))
            local icon = slot.iconFile
            if not icon then
                icon = GetItemInfo(rowBagId, rowSlotIndex)
            end
            local quality = slot.displayQuality or slot.quality or ITEM_DISPLAY_QUALITY_NORMAL
            local perItemSellPrice = GetItemSellValueWithBonuses(rowBagId, rowSlotIndex) or sellPrice or 0

            local entryData = {
                name = name,
                icon = icon,
                stackCount = stackCount,
                sellPrice = sellPrice,
                stackSellPrice = perItemSellPrice * stackCount,
                quality = quality,
                bagId = rowBagId,
                slotIndex = rowSlotIndex,
                stolen = false,
                itemLink = GetItemLink(rowBagId, rowSlotIndex),
                bestGamepadItemCategoryName = slot.bestGamepadItemCategoryName or "",
                statValue = slot.statValue or "",
            }

            local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
            entry:SetDataSource(entryData)
            entry.narrationText = function()
                return entryData.name
            end

            if quality then
                local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
            end

            list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
        end
    end
end
