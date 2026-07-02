--[[
File: tools/tests/test_vendor_action_outcomes.lua
Purpose: Source contract for BUI-TRACE-002 Phase 2 vendor action outcomes.
Usage:   lua tools/tests/test_vendor_action_outcomes.lua
]]

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return "" end
    local content = handle:read("*a") or ""
    handle:close()
    return content
end

local passed, failed = 0, 0
local function check(condition, message)
    if condition then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
    end
end

print("\n=== vendor action outcome source contract ===\n")

local vendor = readFile("Modules/Vendor/Vendor.lua")
local scheduleSettledStart = vendor:find("function Vendor.ScheduleActionSettled", 1, true) or math.huge
local scheduleSettledEnd = vendor:find("-- TAB DEFINITIONS", scheduleSettledStart, true) or #vendor
local scheduleSettledBody = scheduleSettledStart < math.huge and vendor:sub(scheduleSettledStart, scheduleSettledEnd) or ""
local scheduleInactiveGate = scheduleSettledBody:find("if not (L and L.IsActive and L.IsActive()) then return end", 1, true) or math.huge
local scheduleTimer = scheduleSettledBody:find("zo_callLater(function()", 1, true) or math.huge
local files = {
    buy = {
        path = "Modules/Vendor/Components/BuyComponent.lua",
        event = "vendor.buy",
        fields = { "entryIndex", "quantity", "expectedPrice", "currencyType", "goldBefore" },
    },
    buyback = {
        path = "Modules/Vendor/Components/BuybackComponent.lua",
        event = "vendor.buyback",
        fields = { "entryIndex", "quantity", "expectedPrice", "currencyType", "goldBefore" },
    },
    sell = {
        path = "Modules/Vendor/Components/SellComponent.lua",
        event = "vendor.sell",
        fields = { "bagId", "slotIndex", "quantity", "expectedPrice", "currencyType", "goldBefore" },
    },
    sellAllJunk = {
        path = "Modules/Vendor/Components/SellComponent.lua",
        event = "vendor.sell_all_junk",
        fields = { "itemCount", "expectedPrice = totalValue", "currencyType", "goldBefore" },
    },
    sellVengeance = {
        path = "Modules/Vendor/Components/SellVengeanceComponent.lua",
        event = "vendor.sell_vengeance",
        fields = { "bagId", "slotIndex", "quantity", "expectedPrice", "currencyType", "goldBefore" },
    },
    repair = {
        path = "Modules/Vendor/Components/RepairComponent.lua",
        event = "vendor.repair",
        fields = { "bagId", "slotIndex", "quantity", "expectedPrice", "currencyType", "goldBefore" },
    },
    repairAll = {
        path = "Modules/Vendor/Components/RepairComponent.lua",
        event = "vendor.repair_all",
        fields = { "itemCount", "expectedPrice = repairAllCost", "currencyType", "goldBefore" },
    },
    fenceSell = {
        path = "Modules/Vendor/Components/FenceSellComponent.lua",
        event = "vendor.fence_sell",
        fields = { "bagId", "slotIndex", "quantity", "expectedPrice", "currencyType", "goldBefore" },
    },
    fenceLaunder = {
        path = "Modules/Vendor/Components/FenceLaunderComponent.lua",
        event = "vendor.fence_launder",
        fields = { "bagId", "slotIndex", "quantity", "expectedPrice", "currencyType", "goldBefore" },
    },
}

check(vendor:find("function Vendor.TraceActionRequested", 1, true) ~= nil
    and vendor:find("function Vendor.ScheduleActionSettled", 1, true) ~= nil
    and vendor:find("zo_callLater(function()", 1, true) ~= nil
    and vendor:find('TraceVendorEvent(event, "requested"', 1, true) ~= nil
    and vendor:find('TraceVendorEvent(event, "settled"', 1, true) ~= nil
    and vendor:find("payload.goldBefore", 1, true) ~= nil
    and vendor:find("payload.goldAfter", 1, true) ~= nil
    and vendor:find("payload.goldDelta", 1, true) ~= nil
    and scheduleInactiveGate < scheduleTimer,
    "Vendor shared outcome helper gates inactive logging before scheduling the settled timer")

check(vendor:find("local function ScrubVendorPrivacy", 1, true) ~= nil
    and vendor:find("data.carriedGold = nil", 1, true) ~= nil
    and vendor:find("data.bankGold = nil", 1, true) ~= nil
    and vendor:find("data.goldBefore = nil", 1, true) ~= nil
    and vendor:find("data.goldAfter = nil", 1, true) ~= nil
    and vendor:find("ScrubVendorPrivacy(data)", 1, true) ~= nil,
    "Vendor trace payloads scrub absolute balances when builog privacy is on")

for name, spec in pairs(files) do
    local content = readFile(spec.path)
    check(content:find('Vendor.TraceActionRequested("' .. spec.event .. '"', 1, true) ~= nil,
        name .. " emits requested through the shared helper")
    check(content:find('Vendor.ScheduleActionSettled("' .. spec.event .. '"', 1, true) ~= nil,
        name .. " schedules settled through the shared helper")
    check(content:find('"' .. spec.event .. '", "request"', 1, true) == nil
        and content:find('"' .. spec.event .. '", "requested"', 1, true) == nil,
        name .. " does not keep legacy immediate request/requested traces beside outcomes")
    for _, field in ipairs(spec.fields) do
        check(content:find(field, 1, true) ~= nil,
            name .. " outcome payload includes " .. field)
    end
end

local fenceSell = readFile("Modules/Vendor/Components/FenceSellComponent.lua")
check(fenceSell:find("local unitPrice = ds.sellPrice", 1, true) ~= nil
    and fenceSell:find("local expectedPrice = unitPrice * quantity", 1, true) ~= nil,
    "fence sell expectedPrice uses clamped quantity instead of full-stack total")

local repair = readFile("Modules/Vendor/Components/RepairComponent.lua")
check(repair:find("local function CountRepairAllItems", 1, true) ~= nil
    and repair:find("GetRepairableItems", 1, true) == nil
    and repair:find("GetItemRepairCost", 1, true) ~= nil,
    "repair all itemCount is computed from real repair APIs")

if failed > 0 then
    error(string.format("test_vendor_action_outcomes.lua failed with %d failure(s)", failed))
end
print(string.format("test_vendor_action_outcomes.lua: %d passed", passed))
