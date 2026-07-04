--[[
File: tools/tests/test_trading_house_sell_filter.lua
Purpose: Behavioral tests for the Trading House Sell component's engine-authority
         filtering and guild sell-privilege gating (PB-009).

         BuildList and IsPrimaryActionEnabled/OnPrimaryAction must defer to the
         engine's canonical helpers -- IsItemSellableOnTradingHouse(bagId,
         slotIndex) and CanSellOnTradingHouse(guildId) -- rather than a
         hand-rolled exclusion chain.
Usage:
  lua tools/tests/test_trading_house_sell_filter.lua
]]

BETTERUI = {
    TradingHouse = {},
    CIM = {
        Utils = {
            -- Mirrors BETTERUI.CIM.Utils.SafeGetTargetData (BUI-CONS-001): the
            -- shared focused-row resolver the TH components now delegate to.
            SafeGetTargetData = function(list)
                if not list then return nil end
                if type(list.GetTargetData) == "function" then return list:GetTargetData() end
                if type(list.GetSelectedData) == "function" then return list:GetSelectedData() end
                return list.targetData or list.selectedData
            end,
        },
    },
}

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
    assert_eq(value == true, true, label)
end

-- ENGINE / FRAMEWORK STUBS ---------------------------------------------------

local alerts = {}
function BETTERUI.CIM.UserAlertText(id, text)
    alerts[#alerts + 1] = { id = id, text = text }
end

-- Per-slot sellability controlled by the test. Default: sellable.
local sellableBySlot = {}
local function IsSellable(slotIndex)
    local v = sellableBySlot[slotIndex]
    if v == nil then return true end
    return v
end

function IsItemSellableOnTradingHouse(bagId, slotIndex)
    return IsSellable(slotIndex)
end

local selectedGuildId = 101
function GetSelectedTradingHouseGuildId()
    return selectedGuildId
end

local canSellByGuild = { [101] = true }
function CanSellOnTradingHouse(guildId)
    return canSellByGuild[guildId] == true
end

-- Mirror the shared section helper (Core/PriceEntry.lua) the component now
-- routes its permission gate through; the test does not load that file.
function BETTERUI.TradingHouse.IsTradingHouseSellPermittedForCurrentGuild()
    local guildId = GetSelectedTradingHouseGuildId()
    return CanSellOnTradingHouse(guildId), guildId, nil, nil
end

local listingCounts = { current = 0, max = 30 }
function GetTradingHouseListingCounts()
    return listingCounts.current, listingCounts.max
end

local backpackSlots = 4
BAG_BACKPACK = 1
function GetBagSize(bagId)
    return backpackSlots
end

function GetSlotStackSize(bagId, slotIndex)
    return 1
end

function GetItemInfo(bagId, slotIndex)
    -- icon, stack, sellPrice, meetsUsageRequirement, locked, equipType,
    -- itemStyleId, functionalQuality, displayQuality
    return "icon.dds", 1, 50, true, false, 0, 0, 1, 1
end

function GetItemLink(bagId, slotIndex)
    return "|H1:item:" .. tostring(slotIndex) .. "|h|h"
end

function GetItemName(bagId, slotIndex)
    return "Item " .. tostring(slotIndex)
end

function zo_strformat(formatString, value)
    return tostring(value)
end

ITEM_DISPLAY_QUALITY_NORMAL = 1
ITEMTYPE_NONE = 0
ITEM_TRAIT_TYPE_NONE = 0
ARMORTYPE_NONE = 0
SI_TOOLTIP_ITEM_NAME = "SI_TOOLTIP_ITEM_NAME"

function GetString(stringId, enumValue)
    return tostring(stringId)
end

function rawget(t, k)
    return t[k]
end

function GetItemType(bagId, slotIndex)
    return ITEMTYPE_NONE
end

function GetItemTrait(bagId, slotIndex)
    return ITEM_TRAIT_TYPE_NONE
end

function GetItemLinkArmorType(itemLink)
    return ARMORTYPE_NONE
end

ZO_ColorDef = {}
function ZO_ColorDef:New() return {} end

function GetItemQualityColor(quality)
    return {
        UnpackRGBA = function() return 1, 1, 1, 1 end,
    }
end

-- Minimal list capturing AddEntry calls.
local function NewList()
    return {
        entries = {},
        AddEntry = function(self, template, entry)
            self.entries[#self.entries + 1] = entry
        end,
        GetTargetData = function(self) return self.targetData end,
        GetSelectedData = function(self) return self.targetData end,
    }
end

ZO_GamepadEntryData = {}
function ZO_GamepadEntryData:New(name, icon)
    local entry = { name = name, icon = icon }
    function entry:SetDataSource(ds) self.dataSource = ds end
    function entry:SetNameColors(_, _) end
    return entry
end

-- Stack-count / item dialog helpers used by OnPrimaryAction's dialog path.
function ZO_Dialogs_ShowGamepadDialog(name, data) end
ZO_TradingHouse_CalculateItemSuggestedPostPrice = nil

local function resetState()
    alerts = {}
    sellableBySlot = {}
    selectedGuildId = 101
    canSellByGuild = { [101] = true }
    listingCounts = { current = 0, max = 30 }
    backpackSlots = 4
end

-- LOAD PRODUCTION SOURCE -----------------------------------------------------

dofile("Modules/TradingHouse/Components/SellComponent.lua")
local Sell = BETTERUI.TradingHouse.SellComponent

-- TESTS ----------------------------------------------------------------------

print("[Sell:BuildList engine-authority filter]")
resetState()
-- Slot 2 is NOT sellable per the engine; everything else is.
sellableBySlot = { [2] = false }
local list = NewList()
local thInstance = { list = list }
Sell:BuildList(thInstance)

local listedSlots = {}
for _, entry in ipairs(list.entries) do
    listedSlots[entry.dataSource.slotIndex] = true
end
assert_true(listedSlots[0] == true, "Engine-sellable slot 0 is listed")
assert_true(listedSlots[1] == true, "Engine-sellable slot 1 is listed")
assert_eq(listedSlots[2], nil, "Engine-unsellable slot 2 is excluded")
assert_true(listedSlots[3] == true, "Engine-sellable slot 3 is listed")

-- An item the engine includes (e.g. a BoP-tradeable item that IS sellable) is
-- listed; the previous hand-rolled chain would have wrongly dropped it.
print("[Sell:BuildList includes engine-sellable items]")
resetState()
sellableBySlot = {}  -- all sellable
list = NewList()
Sell:BuildList({ list = list })
assert_eq(#list.entries, backpackSlots, "All engine-sellable slots are listed")

print("[Sell:IsPrimaryActionEnabled gates on CanSellOnTradingHouse]")
resetState()
local row = { dataSource = { bagId = BAG_BACKPACK, slotIndex = 0 } }
list = NewList()
list.targetData = row
thInstance = { list = list }

canSellByGuild = { [101] = true }
sellableBySlot = {}
assert_true(Sell:IsPrimaryActionEnabled(thInstance) == true,
    "Primary action enabled when guild allows selling and item is sellable")

canSellByGuild = { [101] = false }
assert_true(Sell:IsPrimaryActionEnabled(thInstance) == false,
    "Primary action disabled when CanSellOnTradingHouse is false")

canSellByGuild = { [101] = true }
sellableBySlot = { [0] = false }
assert_true(Sell:IsPrimaryActionEnabled(thInstance) == false,
    "Primary action disabled when item is not engine-sellable")

print("[Sell:OnPrimaryAction blocks when guild cannot sell]")
resetState()
row = { dataSource = { bagId = BAG_BACKPACK, slotIndex = 0 } }
list = NewList()
list.targetData = row
thInstance = { list = list }
canSellByGuild = { [101] = false }
Sell:OnPrimaryAction(thInstance)
assert_true(#alerts >= 1, "OnPrimaryAction alerts when the guild cannot sell")
assert_eq(alerts[1].id, "TH:CannotSellGuild", "OnPrimaryAction uses the cannot-sell-guild alert id")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
