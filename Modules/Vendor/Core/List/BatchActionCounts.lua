-- Modules/Vendor/Core/List/BatchActionCounts.lua
-- Shared helper for vendor batch-action eligibility counts and labels.

local Vendor = BETTERUI.Vendor
local MODE = Vendor.MODE

Vendor.BatchActionCounts = Vendor.BatchActionCounts or {}
local Counts = Vendor.BatchActionCounts

local function GetDataSource(itemData)
    return (itemData and itemData.dataSource) or itemData
end

local function IsSupportedActionItem(mode, itemData, vendorInstance)
    local ds = GetDataSource(itemData)
    if not ds then
        return false
    end

    if mode == MODE.BUY then
        local entryIndex = ds.entryIndex or ds.slotIndex
        if not entryIndex then
            return false
        end

        if vendorInstance then
            -- Mirror BuyComponent: gold and alt-currency charges are
            -- independent (alt-currency entries report price == 0, not nil).
            local price = ds.price or 0
            if price > 0 then
                local currencyType = ds.currencyType or CURT_MONEY
                if currencyType == CURT_NONE then
                    currencyType = CURT_MONEY
                end
                if vendorInstance.CanAfford and not vendorInstance:CanAfford(price, currencyType) then
                    return false
                end
            end
            local price1 = ds.currencyQuantity1 or 0
            local currencyType1 = ds.currencyType1
            if price1 > 0 and currencyType1 and currencyType1 ~= CURT_NONE
                and vendorInstance.CanAfford and not vendorInstance:CanAfford(price1, currencyType1) then
                return false
            end
            local price2 = ds.currencyQuantity2 or 0
            local currencyType2 = ds.currencyType2
            if price2 > 0 and currencyType2 and currencyType2 ~= CURT_NONE
                and vendorInstance.CanAfford and not vendorInstance:CanAfford(price2, currencyType2) then
                return false
            end
            -- CanCarry mirrors native: craft-bag-virtual / partial-stack items
            -- need no free backpack slot; fall back to the free-slot test.
            if vendorInstance.CanCarry then
                if not vendorInstance:CanCarry(ds.itemLink) then
                    return false
                end
            elseif vendorInstance.HasInventorySpace and not vendorInstance:HasInventorySpace() then
                return false
            end
        end
        return true
    elseif mode == MODE.SELL or mode == MODE.SELL_VENGEANCE or mode == MODE.FENCE_SELL or mode == MODE.FENCE_LAUNDER then
        return ds.bagId ~= nil and ds.slotIndex ~= nil
    elseif mode == MODE.BUYBACK then
        return ds.entryIndex ~= nil
    end

    return false
end

local function GetBatchActionStringId(mode)
    if mode == MODE.BUY then
        return rawget(_G, "SI_ITEM_ACTION_BUY") or "SI_ITEM_ACTION_BUY"
    elseif mode == MODE.SELL or mode == MODE.SELL_VENGEANCE or mode == MODE.FENCE_SELL then
        return rawget(_G, "SI_ITEM_ACTION_SELL") or "SI_ITEM_ACTION_SELL"
    elseif mode == MODE.FENCE_LAUNDER then
        return rawget(_G, "SI_ITEM_ACTION_LAUNDER") or "SI_ITEM_ACTION_LAUNDER"
    elseif mode == MODE.BUYBACK then
        return rawget(_G, "SI_ITEM_ACTION_BUYBACK") or "SI_ITEM_ACTION_BUYBACK"
    end
    return nil
end

---@param mode number
---@param items table[]|nil
---@param vendorInstance BETTERUI.Vendor.Class|nil
---@return integer
function Counts.GetSupportedActionCount(mode, items, vendorInstance)
    if not mode or type(items) ~= "table" then
        return 0
    end

    local count = 0
    for _, itemData in ipairs(items) do
        if IsSupportedActionItem(mode, itemData, vendorInstance) then
            count = count + 1
        end
    end
    return count
end

---@param mode number
---@param supportedCount integer
---@return string|nil
function Counts.BuildBatchActionLabel(mode, supportedCount)
    if not mode or not supportedCount or supportedCount <= 0 then
        return nil
    end

    local actionStringId = GetBatchActionStringId(mode)
    if not actionStringId then
        return nil
    end

    return zo_strformat("<<1>> (<<2>>)", GetString(actionStringId), supportedCount)
end
