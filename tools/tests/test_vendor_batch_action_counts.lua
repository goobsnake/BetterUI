--[[
File: tools/tests/test_vendor_batch_action_counts.lua
Purpose: Unit tests for vendor batch action supported-item counts and labels.
]]

CURT_NONE = 0
CURT_MONEY = 1

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            REPAIR = 3,
            BUYBACK = 4,
            FENCE_SELL = 5,
            FENCE_LAUNDER = 6,
            SELL_VENGEANCE = 7,
        },
    },
}

local stringMap = {
    SI_ITEM_ACTION_BUY = "Buy",
    SI_ITEM_ACTION_SELL = "Sell",
    SI_ITEM_ACTION_LAUNDER = "Launder",
    SI_ITEM_ACTION_BUYBACK = "Buyback",
}

function rawget(t, k)
    return t and t[k]
end

function GetString(id)
    return stringMap[id] or tostring(id or "")
end

function zo_strformat(fmt, a, b)
    if fmt == "<<1>> (<<2>>)" then
        return tostring(a) .. " (" .. tostring(b) .. ")"
    end
    return tostring(fmt or "")
end

-- BUI-CONS-008: BatchActionCounts BUY branch now delegates affordability to
-- Vendor.CanAffordStoreEntry. Mirror the VendorModePolicy implementation.
BETTERUI.Vendor.CanAffordStoreEntry = BETTERUI.Vendor.CanAffordStoreEntry or function(instance, ds)
    if not (instance and ds) then return false end
    if type(instance.CanAfford) ~= "function" then return true end
    local price = ds.price or 0
    if price > 0 then
        local currencyType = ds.currencyType or CURT_MONEY
        if currencyType == CURT_NONE then currencyType = CURT_MONEY end
        if not instance:CanAfford(price, currencyType) then return false end
    end
    local price1 = ds.currencyQuantity1 or 0
    if price1 > 0 and ds.currencyType1 and ds.currencyType1 ~= CURT_NONE
        and not instance:CanAfford(price1, ds.currencyType1) then return false end
    local price2 = ds.currencyQuantity2 or 0
    if price2 > 0 and ds.currencyType2 and ds.currencyType2 ~= CURT_NONE then
        return instance:CanAfford(price2, ds.currencyType2)
    end
    return true
end

dofile("Modules/Vendor/Core/List/BatchActionCounts.lua")

local Counts = BETTERUI.Vendor.BatchActionCounts
local MODE = BETTERUI.Vendor.MODE

local passed = 0
local failed = 0

local function assertEqual(expected, actual, message)
    if expected == actual then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [FAILED] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

print("\n=== Vendor Batch Action Counts ===\n")

do
    local items = {
        { entryIndex = 1, price = 50, currencyType = CURT_MONEY },
        { entryIndex = 2, price = 100, currencyType = CURT_MONEY },
        { entryIndex = 3, price = 250, currencyType = CURT_MONEY },
        { price = 10, currencyType = CURT_MONEY }, -- invalid: no entryIndex
    }
    local vendorInstance = {
        CanAfford = function(_, price) return (price or 0) <= 100 end,
        HasInventorySpace = function() return true end,
    }
    local count = Counts.GetSupportedActionCount(MODE.BUY, items, vendorInstance)
    assertEqual(2, count, "BUY counts only affordable purchasable entries")
end

do
    local items = {
        { entryIndex = 1, price = 1, currencyType = CURT_MONEY },
    }
    local vendorInstance = {
        CanAfford = function() return true end,
        HasInventorySpace = function() return false end,
    }
    local count = Counts.GetSupportedActionCount(MODE.BUY, items, vendorInstance)
    assertEqual(0, count, "BUY returns zero supported items when inventory is full")
end

do
    -- FIX 1 (PB-008): locked entries (meetsRequirementsToBuy == false) are
    -- excluded from the batch BUY count, mirroring the single-buy guard.
    local items = {
        { entryIndex = 1, price = 50, currencyType = CURT_MONEY, meetsRequirementsToBuy = true },
        { entryIndex = 2, price = 50, currencyType = CURT_MONEY, meetsRequirementsToBuy = false },
        { entryIndex = 3, price = 50, currencyType = CURT_MONEY }, -- nil treated as buyable
    }
    local vendorInstance = {
        CanAfford = function() return true end,
        HasInventorySpace = function() return true end,
    }
    local count = Counts.GetSupportedActionCount(MODE.BUY, items, vendorInstance)
    assertEqual(2, count, "BUY excludes entries that do not meet purchase requirements")
end

do
    local items = {
        { bagId = 1, slotIndex = 1 },
        { bagId = 1, slotIndex = 2 },
        { bagId = 1 }, -- invalid
    }
    local count = Counts.GetSupportedActionCount(MODE.SELL, items, nil)
    assertEqual(2, count, "SELL counts only bag/slot-backed entries")
end

do
    local items = {
        { bagId = 1, slotIndex = 1 },
        { bagId = 1, slotIndex = 2 },
        { slotIndex = 3 }, -- invalid
    }
    local count = Counts.GetSupportedActionCount(MODE.SELL_VENGEANCE, items, nil)
    assertEqual(2, count, "SELL_VENGEANCE counts bag/slot-backed entries")
    assertEqual("Sell (2)", Counts.BuildBatchActionLabel(MODE.SELL_VENGEANCE, count),
        "SELL_VENGEANCE uses the sell batch-action label")
end

do
    local items = {
        { entryIndex = 1 },
        { entryIndex = 2 },
        { slotIndex = 3 }, -- invalid for buyback
    }
    local count = Counts.GetSupportedActionCount(MODE.BUYBACK, items, nil)
    assertEqual(2, count, "BUYBACK counts only entryIndex-backed entries")
end

do
    local label = Counts.BuildBatchActionLabel(MODE.BUY, 3)
    assertEqual("Buy (3)", label, "Batch action label includes supported item count")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
os.exit(failed > 0 and 1 or 0)
