--[[
File: Modules/Vendor/Components/BuybackComponent.lua
Purpose: Buyback tab component for the Vendor module.
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
Vendor.BuybackComponent = Vendor.BuybackComponent or {}
local Buyback = Vendor.BuybackComponent

-- BUI-CONS-001: focused-row resolution uses the shared
-- BETTERUI.CIM.Utils.SafeGetTargetData (mirrors BuyComponent's CIM path).

local function GetBuybackItemCategoryName(itemLink)
    if not itemLink or itemLink == "" then
        return ""
    end

    if GetItemLinkItemType then
        local itemType = GetItemLinkItemType(itemLink)
        if itemType and itemType ~= ITEMTYPE_NONE then
            return GetString("SI_ITEMTYPE", itemType)
        end
    end

    return ""
end

function Buyback:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

function Buyback:Deactivate(vendorInstance)
end

function Buyback:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_BUYBACK"))
end

function Buyback:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    local price = ds.price or 0
    return vendorInstance:CanAfford(price) and vendorInstance:CanCarry(ds.itemLink)
end

function Buyback:OnPrimaryAction(vendorInstance)
    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local entryIndex = ds.entryIndex
    if not entryIndex then return end

    local price = ds.price or 0
    if not vendorInstance:CanAfford(price) then
        BETTERUI.CIM.UserAlertText("Buyback:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    -- CanCarry mirrors native: craft-bag-virtual items and partial-stack
    -- merges don't require a free backpack slot (HasInventorySpace fallback
    -- still applies when the row carries no itemLink).
    if not vendorInstance:CanCarry(ds.itemLink) then
        BETTERUI.CIM.UserAlertText("Buyback:CannotCarry",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY")))
        return
    end

    local L = BETTERUI.Log
    local traceData = {
        module = "Vendor",
        scene = BETTERUI_VENDOR_SCENE_NAME,
        feature = "vendor-buyback",
        fn = "Vendor.BuybackComponent.OnPrimaryAction",
        ["function"] = "Vendor.BuybackComponent.OnPrimaryAction",
        mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
        entryIndex = entryIndex,
        quantity = 1,
        expectedPrice = price,
        price = price,
        currencyType = rawget(_G, "CURT_MONEY"),
        item = L and L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name,
    }
    Vendor.DispatchTracedAction("vendor.buyback", traceData, function()
        BuybackItem(entryIndex)
    end)
end

function Buyback:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local numItems = GetNumBuybackItems and GetNumBuybackItems() or 0
    if numItems == 0 then return end

    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil
    for entryIndex = 1, numItems do
        local icon, name, stackCount, price, functionalQuality,
              meetsRequirements, displayQuality = GetBuybackItemInfo(entryIndex)

        if name and name ~= ""
            and (not Vendor.MatchesSearchQuery or Vendor.MatchesSearchQuery(searchQuery, name))
        then
            local itemLink = GetBuybackItemLink and GetBuybackItemLink(entryIndex) or nil
            local quality = displayQuality or functionalQuality or ITEM_DISPLAY_QUALITY_NORMAL

            local entryData = {
                entryIndex        = entryIndex,
                name              = zo_strformat(SI_TOOLTIP_ITEM_NAME, name) or name,
                icon              = icon,
                stackCount        = stackCount or 1,
                price             = price or 0,
                quality           = quality,
                functionalQuality = functionalQuality,
                meetsRequirements = meetsRequirements,
                itemLink          = itemLink,
                bestGamepadItemCategoryName = GetBuybackItemCategoryName(itemLink),
                statValue         = "",
            }

            Vendor.AddItemRow(list, entryData)
        end
    end
end
