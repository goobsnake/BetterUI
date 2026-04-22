--[[
File: tools/tests/test_shared_item_support.lua
Purpose: Regression coverage for neutral shared item presentation seams.
Usage:
  lua tools/tests/test_shared_item_support.lua
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

BETTERUI = {
    CIM = {},
    Inventory = {
        GetColumnFontDescriptor = function()
            return "InventoryColumn"
        end,
    },
    TradingHouse = {
        GetColumnFontDescriptor = function()
            return "TradingHouseColumn"
        end,
    },
}

dofile("Modules/CIM/Core/Presentation/SharedItemSupport.lua")

print("[Shared item support seams]")

do
    BETTERUI.CIM.SharedItemSupport.RegisterCategorySupport({
        doesItemMatchCategory = function(itemData, category)
            return itemData.kind == category.key
        end,
        getBestItemCategoryDescription = function(itemData)
            return itemData.label
        end,
    })

    assert_true(BETTERUI.CIM.SharedItemSupport.DoesItemMatchCategory({ kind = "junk" }, { key = "junk" }),
        "registered category matcher is used")
    assert_eq(BETTERUI.CIM.SharedItemSupport.GetBestItemCategoryDescription({ label = "Consumables" }), "Consumables",
        "registered category describer is used")
end

do
    assert_eq(BETTERUI.CIM.SharedItemSupport.ResolveColumnFontDescriptor("TradingHouse", "Inventory"), "TradingHouseColumn",
        "primary module font descriptor wins")
    assert_eq(BETTERUI.CIM.SharedItemSupport.ResolveColumnFontDescriptor("Missing", "Inventory"), "InventoryColumn",
        "fallback module font descriptor is used")
end

do
    local calls = {}
    BETTERUI.CIM.SharedItemSupport.RegisterTooltipSupport({
        applyTooltipStyles = function()
            calls[#calls + 1] = "apply"
        end,
        cleanupEnhancedTooltip = function(tooltipType)
            calls[#calls + 1] = "cleanup:" .. tostring(tooltipType)
        end,
        updateTooltipEquippedText = function(tooltipType, equipSlot)
            calls[#calls + 1] = string.format("equipped:%s:%s", tostring(tooltipType), tostring(equipSlot))
        end,
        isItemComparisonEnabled = function()
            return true
        end,
        compareItem = function(itemLink, bagId, slotIndex, equipBagId)
            calls[#calls + 1] = string.format("compare:%s:%s:%s:%s",
                tostring(itemLink), tostring(bagId), tostring(slotIndex), tostring(equipBagId))
            return { itemLink = itemLink }
        end,
        showComparisonOnTooltip = function(_, result)
            calls[#calls + 1] = "show:" .. tostring(result and result.itemLink)
        end,
    })

    BETTERUI.CIM.SharedItemSupport.ApplyTooltipStyles()
    BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip("LEFT")
    BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText("LEFT", 3)
    local result = BETTERUI.CIM.SharedItemSupport.CompareItem("item:1", 5, 8, 9)
    BETTERUI.CIM.SharedItemSupport.ShowComparisonOnTooltip({}, result)

    assert_eq(calls[1], "apply", "tooltip style application delegates through the shared seam")
    assert_eq(calls[2], "cleanup:LEFT", "tooltip cleanup delegates through the shared seam")
    assert_eq(calls[3], "equipped:LEFT:3", "equipped-text updates delegate through the shared seam")
    assert_true(BETTERUI.CIM.SharedItemSupport.IsItemComparisonEnabled(),
        "comparison enablement delegates through the shared seam")
    assert_eq(calls[4], "compare:item:1:5:8:9", "comparison calculation delegates through the shared seam")
    assert_eq(calls[5], "show:item:1", "comparison rendering delegates through the shared seam")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
