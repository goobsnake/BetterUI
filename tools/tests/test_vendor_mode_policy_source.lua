--[[
File: tools/tests/test_vendor_mode_policy_source.lua
Purpose: Guards the shared Vendor mode-policy surface so mode translation,
         active-tab selection, and initial-mode choice stay centralized.
Usage:
  lua tools/tests/test_vendor_mode_policy_source.lua
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

print("test_vendor_mode_policy_source")

local policySource = read_file("Modules/Vendor/Core/VendorModePolicy.lua")
local vendorSource = read_file("Modules/Vendor/Vendor.lua")

assert_contains(policySource, "function ModePolicy.ResolveNativeStoreMode(mode)",
    "Vendor mode policy owns native-mode translation")
assert_contains(policySource, "function ModePolicy.GetActiveTabs(context)",
    "Vendor mode policy owns active-tab selection")
assert_contains(policySource, "function ModePolicy.ResolveInitialStoreMode(context)",
    "Vendor mode policy owns initial-mode selection")
assert_contains(vendorSource, "return Vendor.ModePolicy.GetActiveTabs({",
    "Vendor runtime delegates active-tab selection to the shared mode policy")
assert_contains(vendorSource, "Vendor.ModePolicy.ResolveInitialStoreMode({",
    "Vendor runtime delegates initial-mode selection to the shared mode policy")
assert_contains(vendorSource, "Vendor.ModePolicy.GetToggleModePair({",
    "Vendor runtime delegates toggle-mode pairing to the shared mode policy")

print("  OK")
