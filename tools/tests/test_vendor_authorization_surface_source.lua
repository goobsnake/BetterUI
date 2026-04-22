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
    dofile("Modules/Vendor/Core/VendorBatchRuntime.lua")
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
assert_true(protectionPolicy:find("local FALLBACK_VENDOR_ACTION", 1, true) == nil,
    "ProtectionPolicy no longer duplicates vendor action-id tables")
assert_true(protectionPolicy:find("BuildFallbackVendorActionId", 1, true) == nil,
    "ProtectionPolicy no longer defines a local fallback vendor action-id builder")
assert_true(protectionPolicy:find("vendor.ResolveActionId", 1, true) ~= nil,
    "ProtectionPolicy resolves vendor action ids through the canonical vendor resolver when available")
assert_true(protectionPolicy:find('return "vendor_"', 1, true) == nil and protectionPolicy:find('return "fence_"', 1, true) == nil,
    "ProtectionPolicy no longer owns raw vendor action-id string construction")

local moduleLua = read_file("Modules/Vendor/Module.lua")
assert_true(moduleLua:find("local function EnsureVendorActionIds%(%s*%)") ~= nil,
    "Vendor module centralizes shared action-id initialization")
assert_true(moduleLua:find("function BETTERUI%.Vendor%.ResolveActionId%(actionKey%)") ~= nil,
    "Vendor module exposes canonical action-id resolution")
assert_true(moduleLua:find("function BETTERUI%.Vendor%.AuthorizeInventoryAction%(actionType, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Vendor module exposes shared authorization seam")
assert_true(moduleLua:find("local function GetProtectionPolicy%(%s*%)") ~= nil,
    "Vendor module resolves ProtectionPolicy through an explicit required-policy seam")
assert_true(moduleLua:find("local function RequireProtectionPolicyMethod%(policy, methodName%)") ~= nil,
    "Vendor module centralizes required policy-method resolution")
assert_true(moduleLua:find("return false, \"no_item\"", 1, true) == nil,
    "Vendor authorization seam no longer uses raw no_item fallback strings")

local sellComponent = read_file("Modules/Vendor/Components/SellComponent.lua")
assert_true(sellComponent:find("local function AuthorizeVendorAction%(actionType, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Sell component defines a focused local authorization helper")
assert_true(sellComponent:find("local allowed, reason = authorizeInventoryAction%(actionType, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Sell component local helper captures shared authorization seam results")
assert_true(sellComponent:find("return allowed == true, reason", 1, true) ~= nil,
    "Sell component local helper normalizes policy authorization to explicit boolean allow")
assert_true(sellComponent:find("AuthorizeVendorAction%(Vendor%.ACTION%.SELL, ds%.bagId, ds%.slotIndex, vendorInstance%)") ~= nil,
    "Sell component routes primary sell through the local authorization helper")
assert_true(sellComponent:find("AuthorizeVendorAction%(Vendor%.ACTION%.SELL_JUNK, BAG_BACKPACK, slot, vendorInstance%)") ~= nil,
    "Sell component routes sell-all-junk through the local authorization helper")
assert_true(sellComponent:find("if canSell ~= true then", 1, true) ~= nil,
    "Sell component blocks primary sell unless policy explicitly allows it")
assert_true(sellComponent:find("if canSell == true then", 1, true) ~= nil,
    "Sell component sell-all-junk path processes items only when policy explicitly allows it")

local fenceSell = read_file("Modules/Vendor/Components/FenceSellComponent.lua")
assert_true(fenceSell:find("local function AuthorizeVendorAction%(actionType, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Fence sell component defines a focused local authorization helper")
assert_true(fenceSell:find("AuthorizeVendorAction%(Vendor%.ACTION%.FENCE_SELL, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Fence sell component routes primary sell through the local authorization helper")
assert_true(fenceSell:find("if canSell ~= true then", 1, true) ~= nil,
    "Fence sell component blocks sell unless policy explicitly allows it")

local fenceLaunder = read_file("Modules/Vendor/Components/FenceLaunderComponent.lua")
assert_true(fenceLaunder:find("local function AuthorizeVendorAction%(actionType, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Fence launder component defines a focused local authorization helper")
assert_true(fenceLaunder:find("AuthorizeVendorAction%(Vendor%.ACTION%.FENCE_LAUNDER, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Fence launder component routes primary action through the local authorization helper")
assert_true(fenceLaunder:find("if canLaunder ~= true then", 1, true) ~= nil,
    "Fence launder component blocks launder unless policy explicitly allows it")

local sellVengeance = read_file("Modules/Vendor/Components/SellVengeanceComponent.lua")
assert_true(sellVengeance:find("local function AuthorizeVendorAction%(actionType, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Sell vengeance component defines a focused local authorization helper")
assert_true(sellVengeance:find("AuthorizeVendorAction%(Vendor%.ACTION%.SELL_VENGEANCE, bagId, slotIndex, vendorInstance%)") ~= nil,
    "Sell vengeance component routes primary sell through the local authorization helper")
assert_true(sellVengeance:find("if canSell ~= true then", 1, true) ~= nil,
    "Sell vengeance component blocks sell unless policy explicitly allows it")

local batchRuntimeLua = read_file("Modules/Vendor/Core/VendorBatchRuntime.lua")
assert_true(batchRuntimeLua:find("local function AuthorizeVendorInventoryAction%(actionType, bagId, slotIndex%)") ~= nil,
    "Vendor batch runtime defines a focused batch authorization helper")
assert_true(batchRuntimeLua:find("local allowed, reason = authorizeInventoryAction%(actionType, bagId, slotIndex, Vendor%.instance%)") ~= nil,
    "Vendor batch authorization helper captures shared authorization seam results")
assert_true(batchRuntimeLua:find("return allowed == true, reason", 1, true) ~= nil,
    "Vendor batch authorization helper normalizes policy authorization to explicit boolean allow")
assert_true(batchRuntimeLua:find("AuthorizeVendorInventoryAction%(Vendor%.ACTION%.SELL, bagId, slotIndex%)") ~= nil,
    "Vendor batch sell path routes through the batch authorization helper")
assert_true(batchRuntimeLua:find("AuthorizeVendorInventoryAction%(Vendor%.ACTION%.FENCE_SELL, bagId, slotIndex%)") ~= nil,
    "Vendor batch fence sell path routes through the batch authorization helper")
assert_true(batchRuntimeLua:find("AuthorizeVendorInventoryAction%(Vendor%.ACTION%.FENCE_LAUNDER, bagId, slotIndex%)") ~= nil,
    "Vendor batch fence launder path routes through the batch authorization helper")
assert_true(batchRuntimeLua:find("if canSell ~= true then", 1, true) ~= nil,
    "Vendor batch sell paths are blocked unless policy explicitly allows them")
assert_true(batchRuntimeLua:find("if canLaunder ~= true then", 1, true) ~= nil,
    "Vendor batch launder paths are blocked unless policy explicitly allows them")

if failed > 0 then
    error(string.format("test_vendor_authorization_surface_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_vendor_authorization_surface_source.lua: %d passed", passed))
