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

local source = read_file("Modules/Vendor/Vendor.lua")

assert_contains(source, "local function BuildNativeStoreComponentSnapshot(searchContext)",
    "Vendor native store rebuild extracts active-state snapshotting")
assert_contains(source, "local function BuildNativeStoreRebuildPlan(snapshot)",
    "Vendor native store rebuild extracts plan construction")
assert_contains(source, "local function NeutralizeNativeStoreHeaderCallbacks(storeManager)",
    "Vendor native store rebuild extracts header neutralization")
assert_contains(source, "local function SweepNativeStoreDirectionalInput(storeManager, includeComponentLists)",
    "Vendor native store rebuild extracts DI cleanup")
assert_contains(source, "local function ApplyNativeStoreRebuildPlan(snapshot, rebuildPlan)",
    "Vendor native store rebuild extracts the rebuild application phase")
assert_contains(source, "local snapshot = BuildNativeStoreComponentSnapshot(searchContext)",
    "EnsureNativeStoreComponents delegates snapshot construction")
assert_contains(source, "local rebuildPlan = BuildNativeStoreRebuildPlan(snapshot)",
    "EnsureNativeStoreComponents delegates rebuild-plan selection")
assert_contains(source, "if ApplyNativeStoreRebuildPlan(snapshot, rebuildPlan) then",
    "EnsureNativeStoreComponents delegates rebuild application")
assert_not_contains(source, "local function GetActiveModes()",
    "EnsureNativeStoreComponents no longer nests its active-mode snapshot helper inline")

print("  OK")
