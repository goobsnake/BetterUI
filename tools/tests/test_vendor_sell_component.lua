--[[
File: tools/tests/test_vendor_sell_component.lua
Purpose: Regression coverage for vendor sell category matching via neutral shared seams.
Usage:
  lua tools/tests/test_vendor_sell_component.lua
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

BETTERUI = {
    Vendor = {
        ACTION = {
            SELL = "vendor_sell",
            SELL_JUNK = "vendor_sell_junk",
        },
    },
    CIM = {
        ItemTaxonomy = {
            VENDOR_SELL_CATEGORY_DEFS = {
                { key = "all", nameStringId = "ALL", iconFile = "all.dds" },
                { key = "junk", nameStringId = "JUNK", iconFile = "junk.dds", special = "junk" },
            },
        },
        SharedItemSupport = {
            DoesItemMatchCategory = function(slotData, category)
                return category.key == "junk" and slotData.isJunk == true
            end,
        },
    },
}

local authorizationCalls = 0
function BETTERUI.Vendor.AuthorizeInventoryAction(actionType, bagId, slotIndex)
    authorizationCalls = authorizationCalls + 1
    return actionType == BETTERUI.Vendor.ACTION.SELL and bagId ~= nil and slotIndex ~= nil
end

BAG_BACKPACK = 1

function GetString(value)
    return tostring(value)
end

function IsItemStolen()
    return false
end

SHARED_INVENTORY = {
    GenerateFullSlotData = function(_, _)
        return {
            { bagId = 1, slotIndex = 1, sellPrice = 10, isJunk = true },
            { bagId = 1, slotIndex = 2, sellPrice = 20, isJunk = false },
        }
    end,
}

dofile("Modules/Vendor/Components/SellComponent.lua")

print("[Vendor sell component shared category seam]")

do
    local categories = BETTERUI.Vendor.SellComponent:GetCategories({})
    assert_eq(categories[1].key, "all", "all category remains first")
    assert_eq(categories[1].itemCount, 2, "all category counts all sellable rows")
    assert_eq(categories[2].key, "junk", "junk category is preserved")
    assert_eq(categories[2].itemCount, 1, "junk category uses the shared matcher instead of Inventory reach-through")
end

do
    local vendorInstance = {
        list = {
            GetSelectedData = function()
                return {
                    dataSource = {
                        bagId = BAG_BACKPACK,
                        slotIndex = 1,
                        sellPrice = 10,
                        stolen = false,
                    },
                }
            end,
        },
    }
    local enabled = BETTERUI.Vendor.SellComponent:IsPrimaryActionEnabled(vendorInstance)
    assert_eq(enabled, true, "sell primary action consults shared vendor authorization seam")
    assert_eq(authorizationCalls > 0, true, "sell primary action invokes shared authorization helper")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
