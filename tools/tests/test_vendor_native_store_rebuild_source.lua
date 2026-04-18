--[[
File: tools/tests/test_vendor_native_store_rebuild_source.lua
Purpose: Guards the Vendor native-store rebuild split so snapshotting, rebuild
         planning, header neutralization, and DI cleanup stay separated.
Usage:
  lua tools/tests/test_vendor_native_store_rebuild_source.lua
]]

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

print("test_vendor_native_store_rebuild_source")

local vendorSource = read_file("Modules/Vendor/Vendor.lua")
local bridgeSource = read_file("Modules/Vendor/Core/VendorNativeStoreBridge.lua")

assert_contains(bridgeSource, "local function BuildComponentSnapshot(searchContext)",
    "Vendor native store rebuild extracts active-state snapshotting")
assert_contains(bridgeSource, "local function BuildRebuildPlan(snapshot)",
    "Vendor native store rebuild extracts plan construction")
assert_contains(bridgeSource, "local function NeutralizeHeaderCallbacks(storeManager)",
    "Vendor native store rebuild extracts header neutralization")
assert_contains(bridgeSource, "local function SweepDirectionalInput(storeManager, includeComponentLists)",
    "Vendor native store rebuild extracts DI cleanup")
assert_contains(bridgeSource, "local function ApplyRebuildPlan(snapshot, rebuildPlan)",
    "Vendor native store rebuild extracts the rebuild application phase")
assert_contains(bridgeSource, "local snapshot = BuildComponentSnapshot(searchContext)",
    "NativeStoreBridge.EnsureComponents delegates snapshot construction")
assert_contains(bridgeSource, "local rebuildPlan = BuildRebuildPlan(snapshot)",
    "NativeStoreBridge.EnsureComponents delegates rebuild-plan selection")
assert_contains(bridgeSource, "if ApplyRebuildPlan(snapshot, rebuildPlan) then",
    "NativeStoreBridge.EnsureComponents delegates rebuild application")
assert_not_contains(bridgeSource, "local function GetActiveModes()",
    "NativeStoreBridge no longer nests its active-mode snapshot helper inline")
assert_contains(vendorSource, "GetVendorNativeStoreBridge().EnsureComponents(searchContext)",
    "Vendor runtime delegates native-store component reconciliation to NativeStoreBridge")

print("  OK")
