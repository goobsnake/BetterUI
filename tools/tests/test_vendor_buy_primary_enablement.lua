--[[
File: tools/tests/test_vendor_buy_primary_enablement.lua
Purpose: Regression coverage for vendor buy primary-action enablement.
]]

CURT_NONE = 0
CURT_MONEY = 1

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function getFocusedStoreData(vendorInstance)
    local list = vendorInstance and vendorInstance.list
    if not list then
        return nil
    end

    if list.GetTargetData then
        local targetData = list:GetTargetData()
        if targetData then
            return targetData
        end
    end

    if list.GetSelectedData then
        return list:GetSelectedData()
    end

    return list.selectedData
end

local function isBuyPrimaryEnabled(vendorInstance)
    local selectedData = getFocusedStoreData(vendorInstance)
    if not selectedData then
        return false
    end

    local ds = selectedData.dataSource or selectedData
    local price = ds.price or ds.currencyQuantity1 or 0
    local currencyType = ds.currencyType or ds.currencyType1 or CURT_MONEY
    if currencyType == CURT_NONE then
        currencyType = CURT_MONEY
    end

    return vendorInstance:CanAfford(price, currencyType) and vendorInstance:HasInventorySpace()
end

local function buildBuyList(rows)
    return {
        dataList = rows,
        selectedData = nil,
        targetData = nil,
        GetSelectedData = function(self)
            return self.selectedData
        end,
        GetTargetData = function(self)
            return self.targetData
        end,
        SetSelectedIndex = function(self, index)
            self.targetData = self.dataList[index]
        end,
        SetSelectedIndexWithoutAnimation = function(self, index)
            self.targetData = self.dataList[index]
            self.selectedData = self.dataList[index]
        end,
    }
end

local vendor = {
    list = nil,
    CanAfford = function(_, price, currencyType)
        return price == 25 and currencyType == CURT_MONEY
    end,
    HasInventorySpace = function()
        return true
    end,
}

local rows = {
    { dataSource = { name = "Bread", price = 25, currencyType = CURT_NONE } },
    { dataSource = { name = "Water", price = 10, currencyType = CURT_NONE } },
}

do
    local list = buildBuyList(rows)
    vendor.list = list
    list:SetSelectedIndexWithoutAnimation(1)
    assertEq(isBuyPrimaryEnabled(vendor), true, "buy primary action enables for focused gold-priced rows")
end

do
    local list = buildBuyList(rows)
    vendor.list = list
    list:SetSelectedIndex(1)
    assertEq(isBuyPrimaryEnabled(vendor), true, "buy primary action falls back to target data when selected data lags")
end

print("test_vendor_buy_primary_enablement.lua: PASS")