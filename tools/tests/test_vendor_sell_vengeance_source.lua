--[[
File: tools/tests/test_vendor_sell_vengeance_source.lua
Purpose: Source-level regression checks for SellVengeance vendor integration.
]]

local passed = 0
local failed = 0

local function read_file(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(string.format("failed to open %s: %s", path, tostring(err)))
    end

    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if string.find(haystack, needle, 1, true) then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- missing %s", label, needle))
    end
end

print("[Vendor SellVengeance source integration]")

local vendorLua = read_file("Modules/Vendor/Vendor.lua")
local vendorClass = read_file("Modules/Vendor/Core/VendorClass.lua")
local constantsLua = read_file("Modules/CIM/Constants.lua")
local batchCountsLua = read_file("Modules/Vendor/Core/BatchActionCounts.lua")
local componentLua = read_file("Modules/Vendor/Components/SellVengeanceComponent.lua")
local manifest = read_file("BetterUI.txt")
local stringsEn = read_file("lang/en.lua")

assert_contains(vendorClass, "SELL_VENGEANCE", "vendor mode constants include SELL_VENGEANCE")
assert_contains(vendorClass, "ZO_MODE_STORE_SELL_VENGEANCE", "vendor class resolves native vengeance store mode")
assert_contains(vendorClass, "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE", "vendor class resolves vengeance mode label")
assert_contains(vendorClass, "VENDOR_SELL_VENGEANCE", "vendor class maps vengeance mode to a position key")

assert_contains(vendorLua, "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE", "vendor tab definitions include SellVengeance label")
assert_contains(vendorLua, "MODE.SELL_VENGEANCE", "vendor tab definitions include SellVengeance mode")
assert_contains(vendorLua, "Vendor.SellVengeanceComponent", "vendor init references SellVengeance component")
assert_contains(vendorLua, "RegisterComponent(MODE.SELL_VENGEANCE, Vendor.SellVengeanceComponent)", "vendor init registers SellVengeance component")

assert_contains(constantsLua, "VENDOR_SELL_VENGEANCE", "shared module constants include SellVengeance key")
assert_contains(batchCountsLua, "MODE.SELL_VENGEANCE", "batch action counts treat SellVengeance as sell-capable")

assert_contains(componentLua, "BAG_VENGEANCE", "SellVengeance component reads BAG_VENGEANCE")
assert_contains(componentLua, "IsCurrentCampaignVengeanceRuleset", "SellVengeance component guards on vengeance ruleset")
assert_contains(componentLua, "ZO_VENGEANCE_BAG_SELL_ENABLED", "SellVengeance component guards on bag sell enablement")
assert_contains(componentLua, "SellInventoryItem", "SellVengeance component sells items through SellInventoryItem")

assert_contains(manifest, "Modules\\Vendor\\Components\\SellVengeanceComponent.lua", "manifest loads SellVengeance component")
assert_contains(stringsEn, "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE", "english strings define SellVengeance tab label")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end