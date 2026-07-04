--[[
File: Modules/Vendor/Components/SellVengeanceComponent.lua
Purpose: Sell Vengeance tab component for the Vendor module.

Lists and sells items from BAG_VENGEANCE when the Vengeance ruleset is active.
]]

local Vendor = BETTERUI.Vendor

Vendor.SellVengeanceComponent = Vendor.SellVengeanceComponent or {}
local SellVengeance = Vendor.SellVengeanceComponent

-- BUI-CONS-001: focused-row resolution uses BETTERUI.CIM.Utils.SafeGetTargetData.

-- BUI-CONS-008: authorization assert-wrapper unified in Vendor.AuthorizeAction.
local function AuthorizeVendorAction(actionType, bagId, slotIndex, vendorInstance)
    return Vendor.AuthorizeAction(actionType, bagId, slotIndex, vendorInstance)
end

-- BUI-CONS-008: the vengeance-availability predicate is owned by Vendor.lua and
-- exposed as Vendor.IsSellVengeanceModeAvailable; delegate to it.
local function IsSellVengeanceAvailable()
    return Vendor.IsSellVengeanceModeAvailable and Vendor.IsSellVengeanceModeAvailable() or false
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

-- One refresh pass calls GetCategories and BuildList back to back, each of
-- which needs the sellable vengeance rows; the shared per-refresh memoize
-- (BUI-CONS-008) builds the bag snapshot once per frame instead of once per
-- caller. No frame clock (test harness) => never reuse a stale snapshot.
local GetSellableVengeanceRowsCached, invalidateVengeanceRows =
    Vendor.PerRefreshCache(BuildSellableVengeanceItems)

function SellVengeance:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

function SellVengeance:Deactivate(_vendorInstance)
    -- Drop the per-frame row cache so a stale row set can never be reused
    -- after the tab deactivates.
    invalidateVengeanceRows()
end

function SellVengeance:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_SELL") or "SI_ITEM_ACTION_SELL")
end

function SellVengeance:IsPrimaryActionEnabled(vendorInstance)
    if not IsSellVengeanceAvailable() then
        return false
    end

    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
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

    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
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

    local L = BETTERUI.Log
    local expectedPrice = ds.stackSellPrice or ((ds.sellPrice or 0) * stackSize)
    local traceData = {
        module = "Vendor",
        scene = BETTERUI_VENDOR_SCENE_NAME,
        feature = "vendor-sell-vengeance",
        fn = "Vendor.SellVengeanceComponent.OnPrimaryAction",
        ["function"] = "Vendor.SellVengeanceComponent.OnPrimaryAction",
        mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
        bagId = bagId,
        slotIndex = slotIndex,
        quantity = stackSize,
        stackSize = stackSize,
        expectedPrice = expectedPrice,
        currencyType = rawget(_G, "CURT_MONEY"),
        item = L and L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name,
    }
    Vendor.DispatchTracedAction("vendor.sell_vengeance", traceData, function()
        SellInventoryItem(bagId, slotIndex, stackSize)
    end)
end

function SellVengeance:GetCategories(_vendorInstance)
    return {
        {
            key = "all",
            name = GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE") or "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE"),
            iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
            itemCount = #GetSellableVengeanceRowsCached(),
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
    for _, slot in ipairs(GetSellableVengeanceRowsCached()) do
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

            Vendor.AddItemRow(list, entryData)
        end
    end
end
