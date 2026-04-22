--[[
File: tools/tests/test_vendor_mode_policy_source.lua
Purpose: Behavior-focused coverage for Vendor mode-policy category ownership
         and tab derivation flows.
Usage:
  lua tools/tests/test_vendor_mode_policy_source.lua
]]

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    assert_eq(value, true, message)
end

print("test_vendor_mode_policy_source")

SI_BETTERUI_INV_ITEM_ALL = "SI_BETTERUI_INV_ITEM_ALL"

function GetString(value)
    return tostring(value)
end

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            REPAIR = 3,
            BUYBACK = 4,
            FENCE_SELL = 5,
            FENCE_LAUNDER = 6,
            STABLE = 7,
            SELL_VENGEANCE = 8,
        },
    },
}

ZO_MODE_STORE_BUY = 101
ZO_MODE_STORE_SELL = 102
ZO_MODE_STORE_REPAIR = 103
ZO_MODE_STORE_BUY_BACK = 104
ZO_MODE_STORE_STABLE = 105
ZO_MODE_STORE_SELL_VENGEANCE = 106

BETTERUI.Vendor.GetModeDescriptor = function(mode)
    local descriptors = {
        [BETTERUI.Vendor.MODE.BUY] = { nativeModeGlobalKey = "ZO_MODE_STORE_BUY", nameStringId = "BUY_NAME" },
        [BETTERUI.Vendor.MODE.SELL] = { nativeModeGlobalKey = "ZO_MODE_STORE_SELL", nameStringId = "SELL_NAME" },
        [BETTERUI.Vendor.MODE.REPAIR] = { nativeModeGlobalKey = "ZO_MODE_STORE_REPAIR", nameStringId = "REPAIR_NAME" },
        [BETTERUI.Vendor.MODE.BUYBACK] = { nativeModeGlobalKey = "ZO_MODE_STORE_BUY_BACK", nameStringId = "BUYBACK_NAME" },
        [BETTERUI.Vendor.MODE.FENCE_SELL] = { nativeModeGlobalKey = "ZO_MODE_STORE_SELL", nameStringId = "FENCE_SELL_NAME" },
        [BETTERUI.Vendor.MODE.FENCE_LAUNDER] = { nativeModeGlobalKey = "ZO_MODE_STORE_BUY_BACK", nameStringId = "FENCE_LAUNDER_NAME" },
        [BETTERUI.Vendor.MODE.STABLE] = { nativeModeGlobalKey = "ZO_MODE_STORE_STABLE", nameStringId = "STABLE_NAME" },
        [BETTERUI.Vendor.MODE.SELL_VENGEANCE] = { nativeModeGlobalKey = "ZO_MODE_STORE_SELL_VENGEANCE", nameStringId = "SELL_VENGEANCE_NAME" },
    }
    return descriptors[mode]
end

dofile("Modules/Vendor/Core/VendorModePolicy.lua")

local ModePolicy = BETTERUI.Vendor.ModePolicy
local MODE = BETTERUI.Vendor.MODE

assert_eq(BETTERUI.Vendor.BuildActiveModeSet, nil, "mode policy does not leak BuildActiveModeSet onto root vendor table")
assert_eq(BETTERUI.Vendor.IsSellBuybackOnlyModeSet, nil,
    "mode policy does not leak IsSellBuybackOnlyModeSet onto root vendor table")

do
    local owner = {}
    local _, categories = ModePolicy.SetModeCategories(owner, MODE.BUY, {
        { key = "weapons", name = "Weapons", iconFile = "w.dds", itemCount = 3 },
    })
    local returnedCategories = ModePolicy.GetModeCategories(owner, MODE.BUY)
    assert_eq(#returnedCategories, 1, "set/get categories persists exactly one category")
    assert_eq(returnedCategories[1].key, "weapons", "category key is preserved")

    returnedCategories[1].key = "mutated"
    local rereadCategories = ModePolicy.GetModeCategories(owner, MODE.BUY)
    assert_eq(rereadCategories[1].key, "weapons", "mode-policy returns owned clones, not mutable backing state")

    assert_eq(categories[1].key, "weapons", "set categories returns normalized clone snapshot")
end

do
    local owner = {}
    ModePolicy.SetModeCategories(owner, MODE.SELL, {})
    local categories = ModePolicy.GetModeCategories(owner, MODE.SELL)
    assert_eq(#categories, 1, "empty category writes normalize to a fallback category")
    assert_eq(categories[1].key, "all", "fallback category key is `all`")
end

do
    local owner = {}
    ModePolicy.SetModeCategories(owner, MODE.BUY, {
        { key = "all", name = "All" },
        { key = "armor", name = "Armor" },
    })

    local clampedLow = ModePolicy.SetSelectedCategoryIndex(owner, MODE.BUY, 0)
    local clampedHigh = ModePolicy.SetSelectedCategoryIndex(owner, MODE.BUY, 999)
    local selectedIndex = ModePolicy.GetSelectedCategoryIndex(owner, MODE.BUY)

    assert_eq(clampedLow, 1, "selected category index clamps low values to 1")
    assert_eq(clampedHigh, 1, "selected category index clamps high values to 1 when out-of-range")
    assert_eq(selectedIndex, 1, "selected category index remains valid after clamps")
end

do
    local owner = {}
    ModePolicy.SetModeCategories(owner, MODE.BUY, {
        { key = "all", name = "All" },
    })
    ModePolicy.SetSelectedCategoryIndex(owner, MODE.BUY, 1)
    ModePolicy.ResetCategoryState(owner)

    assert_eq(owner.modeCategories, nil, "reset category state clears mode category ownership on the owner")
    assert_eq(owner.categoryIndexByMode, nil, "reset category state clears selected category index ownership on the owner")
    assert_eq(owner._cachedBuyCategories, nil, "reset category state clears cached buy categories on the owner")
end

do
    local fenceTabs = {
        { mode = MODE.FENCE_SELL, name = "Sell" },
        { mode = MODE.FENCE_LAUNDER, name = "Launder" },
    }

    local activeTabs = ModePolicy.GetFenceActiveTabs({
        fenceTabs = fenceTabs,
        enableSell = false,
        enableLaunder = false,
    })
    assert_eq(#activeTabs, 1, "fence tabs fall back to sell when no explicit mode is enabled")
    assert_eq(activeTabs[1].mode, MODE.FENCE_SELL, "fence fallback tab mode is sell")

    activeTabs[1].mode = -1
    local rereadTabs = ModePolicy.GetFenceActiveTabs({
        fenceTabs = fenceTabs,
        enableSell = true,
        enableLaunder = true,
    })
    assert_eq(rereadTabs[1].mode, MODE.FENCE_SELL, "fence tab derivation returns cloned tab snapshots")
end

do
    local storeManager = {
        activeComponents = {
            {
                GetStoreMode = function()
                    return ZO_MODE_STORE_SELL
                end,
            },
            {
                GetStoreMode = function()
                    return ZO_MODE_STORE_BUY_BACK
                end,
            },
        },
    }

    local sourceTabs = {
        { mode = MODE.BUY, name = "Buy" },
        { mode = MODE.SELL, name = "Sell" },
        { mode = MODE.BUYBACK, name = "Buyback" },
    }
    local fallbackTabs = {
        { mode = MODE.SELL, name = "Sell" },
    }

    local tabs = ModePolicy.GetStoreActiveTabs({
        sourceTabs = sourceTabs,
        fallbackTabs = fallbackTabs,
        includeBuyFromSession = false,
        includeStableRepair = false,
        storeManager = storeManager,
    })

    assert_eq(#tabs, 2, "store tab derivation returns native-active modes when available")
    assert_eq(tabs[1].mode, MODE.SELL, "first active tab resolves to sell")
    assert_eq(tabs[2].mode, MODE.BUYBACK, "second active tab resolves to buyback")
end

print("  OK")
