--[[
File: tools/tests/test_vendor_authorization_surface_source.lua
Purpose: Source-level regression checks for the shared vendor authorization seam
         across primary and batch sell/launder flows.

Usage:
  lua tools/tests/test_vendor_authorization_surface_source.lua
]]

if false then
    dofile("Modules/CIM/Actions/ProtectionPolicy.lua")
    dofile("Modules/Vendor/Module.lua")
    dofile("Modules/Vendor/Components/SellComponent.lua")
    dofile("Modules/Vendor/Components/FenceSellComponent.lua")
    dofile("Modules/Vendor/Components/FenceLaunderComponent.lua")
    dofile("Modules/Vendor/Components/SellVengeanceComponent.lua")
    dofile("Modules/Vendor/Vendor.lua")
end

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local protectionPolicy = read_file("Modules/CIM/Actions/ProtectionPolicy.lua")
assert_true(protectionPolicy:find("function Policy%.CanVendorAction%(actionType, bagId, slotIndex, context%)") ~= nil,
    "ProtectionPolicy exposes CanVendorAction for shared vendor authorization")

local moduleLua = read_file("Modules/Vendor/Module.lua")
assert_true(moduleLua:find("Vendor%.ACTION = Vendor%.ACTION or %{%s*") ~= nil,
    "Vendor module defines shared action identifiers")
assert_true(moduleLua:find("function BETTERUI%.Vendor%.AuthorizeInventoryAction%(actionType, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Vendor module exposes shared authorization seam")

local sellComponent = read_file("Modules/Vendor/Components/SellComponent.lua")
assert_true(sellComponent:find("Vendor%.AuthorizeInventoryAction%(Vendor%.ACTION%.SELL, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Sell component routes primary sell through shared authorization seam")
assert_true(sellComponent:find("Vendor%.AuthorizeInventoryAction%(Vendor%.ACTION%.SELL_JUNK, BAG_BACKPACK, slot, vendorInstance%)") ~= nil,
    "Sell component routes sell-all-junk through shared authorization seam")

local fenceSell = read_file("Modules/Vendor/Components/FenceSellComponent.lua")
assert_true(fenceSell:find("Vendor%.AuthorizeInventoryAction%(Vendor%.ACTION%.FENCE_SELL, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Fence sell component routes primary sell through shared authorization seam")

local fenceLaunder = read_file("Modules/Vendor/Components/FenceLaunderComponent.lua")
assert_true(fenceLaunder:find("Vendor%.AuthorizeInventoryAction%(Vendor%.ACTION%.FENCE_LAUNDER, bagId, slotIndex,") ~= nil,
    "Fence launder component routes primary action through shared authorization seam")

local sellVengeance = read_file("Modules/Vendor/Components/SellVengeanceComponent.lua")
assert_true(sellVengeance:find("Vendor%.AuthorizeInventoryAction%(Vendor%.ACTION%.SELL_VENGEANCE, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Sell vengeance component routes primary sell through shared authorization seam")

local vendorLua = read_file("Modules/Vendor/Vendor.lua")
assert_true(vendorLua:find("Vendor%.AuthorizeInventoryAction%(Vendor%.ACTION%.SELL, bagId, slotIndex, Vendor%.instance%)") ~= nil,
    "Vendor batch sell path routes through shared authorization seam")
assert_true(vendorLua:find("Vendor%.AuthorizeInventoryAction%(Vendor%.ACTION%.FENCE_SELL, bagId, slotIndex, Vendor%.instance%)") ~= nil,
    "Vendor batch fence sell path routes through shared authorization seam")
assert_true(vendorLua:find("Vendor%.AuthorizeInventoryAction%(Vendor%.ACTION%.FENCE_LAUNDER, bagId, slotIndex, Vendor%.instance%)") ~= nil,
    "Vendor batch fence launder path routes through shared authorization seam")

if failed > 0 then
    error(string.format("test_vendor_authorization_surface_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_vendor_authorization_surface_source.lua: %d passed", passed))
