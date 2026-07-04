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

-- BUI-CONS-001/008: shared helpers SellComponent now delegates to. Mirror the
-- VendorModePolicy/CIM implementations so this isolated test still passes.
BETTERUI.CIM.Utils = BETTERUI.CIM.Utils or {}
BETTERUI.CIM.Utils.SafeGetTargetData = BETTERUI.CIM.Utils.SafeGetTargetData or function(list)
    if not list then return nil end
    if list.GetTargetData then return list:GetTargetData() end
    if list.GetSelectedData then return list:GetSelectedData() end
    if list.targetData ~= nil then return list.targetData end
    return list.selectedData
end
BETTERUI.Vendor.AuthorizeAction = BETTERUI.Vendor.AuthorizeAction or function(actionType, bagId, slotIndex, vendorInstance)
    local f = BETTERUI.Vendor.AuthorizeInventoryAction
    assert(type(f) == "function", "Vendor.AuthorizeInventoryAction must load")
    local allowed, reason = f(actionType, bagId, slotIndex, vendorInstance)
    return allowed == true, reason
end
BETTERUI.Vendor.IsAtGoldCap = BETTERUI.Vendor.IsAtGoldCap or function()
    if type(GetMaxPossibleCurrency) ~= "function" then return false end
    local carried = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    local maxPossible = GetMaxPossibleCurrency(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    return maxPossible > 0 and carried >= maxPossible
end
BETTERUI.Vendor.DispatchTracedAction = BETTERUI.Vendor.DispatchTracedAction or function(event, traceData, fn)
    local V = BETTERUI.Vendor
    local goldBefore = V.TraceActionRequested and V.TraceActionRequested(event, traceData) or nil
    fn()
    if V.ScheduleActionSettled then V.ScheduleActionSettled(event, traceData, goldBefore) end
end

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

print("[Vendor sell component: player-locked filter + gold cap]")

-- Finding L: the SELL list builder must exclude isPlayerLocked items (the
-- action layer denies them) while leaving stolen/fence flows untouched. Drive
-- the same GetCategories seam with a player-locked row present.
do
    local previousGenerate = SHARED_INVENTORY.GenerateFullSlotData
    SHARED_INVENTORY.GenerateFullSlotData = function(_, _)
        return {
            { bagId = 1, slotIndex = 1, sellPrice = 10, isJunk = true },
            { bagId = 1, slotIndex = 2, sellPrice = 20, isJunk = false },
            { bagId = 1, slotIndex = 3, sellPrice = 30, isJunk = false, playerLocked = true },
        }
    end
    local lockedSlots = { [3] = true }
    IsItemPlayerLocked = function(_, slotIndex)
        return lockedSlots[slotIndex] == true
    end

    local categories = BETTERUI.Vendor.SellComponent:GetCategories({})
    assert_eq(categories[1].key, "all", "all category remains first with locked rows present")
    assert_eq(categories[1].itemCount, 2, "sell list excludes player-locked items from the all count")

    IsItemPlayerLocked = nil
    SHARED_INVENTORY.GenerateFullSlotData = previousGenerate
end

-- Findings E + K: gold-cap gating. Provide currency/cap stubs and the native
-- store-failure string so the sell actions block at the cap with an alert.
do
    CURT_MONEY = 1
    CURRENCY_LOCATION_CHARACTER = 1
    STORE_FAILURE_SELL_FAILED_MONEY_CAP = 7
    local atCap = false
    GetMaxPossibleCurrency = function() return 1000 end
    GetCurrencyAmount = function() return atCap and 1000 or 500 end
    GetSlotStackSize = function() return 1 end
    SellInventoryItem = function() end
    function GetString(id, value)
        if id == "SI_STOREFAILURE" and value == STORE_FAILURE_SELL_FAILED_MONEY_CAP then
            return "You cannot sell items when you are at the gold cap."
        end
        return tostring(id)
    end

    local lastAlert
    BETTERUI.CIM.UserAlertText = function(tag, message)
        lastAlert = { tag = tag, message = message }
    end

    local function makeSellVendor()
        return {
            list = {
                GetSelectedData = function()
                    return { dataSource = { bagId = BAG_BACKPACK, slotIndex = 1, sellPrice = 10, stolen = false } }
                end,
            },
        }
    end

    -- Below the cap: sell stays enabled and routes to SellInventoryItem.
    atCap = false
    assert_eq(BETTERUI.Vendor.SellComponent:IsPrimaryActionEnabled(makeSellVendor()), true,
        "sell primary action enabled below the gold cap")

    -- At the cap: disabled, and the action surfaces the native failure alert.
    atCap = true
    assert_eq(BETTERUI.Vendor.SellComponent:IsPrimaryActionEnabled(makeSellVendor()), false,
        "sell primary action disabled at the gold cap")
    lastAlert = nil
    BETTERUI.Vendor.SellComponent:OnPrimaryAction(makeSellVendor())
    assert_eq(lastAlert and lastAlert.tag, "Sell:GoldCap", "sell at gold cap raises the gold-cap alert")
    assert_eq(lastAlert and lastAlert.message, "You cannot sell items when you are at the gold cap.",
        "gold-cap alert uses the native SI_STOREFAILURE string")

    -- SellAllJunk pre-checks the cap too (finding K).
    lastAlert = nil
    BETTERUI.Vendor.GetJunkSellSummary = function() return 100, 5 end
    BETTERUI.Vendor.SellComponent:SellAllJunk(makeSellVendor())
    assert_eq(lastAlert and lastAlert.tag, "Sell:GoldCap", "SellAllJunk blocks at the gold cap before queuing")

    GetMaxPossibleCurrency = nil
    GetCurrencyAmount = nil
    GetSlotStackSize = nil
    SellInventoryItem = nil
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
