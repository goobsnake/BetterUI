--[[
File: tools/tests/test_vendor_mode_policy_source.lua
Purpose: Guards the vendor mode-policy boundary so category ownership and
         cache resets stay centralized in VendorModePolicy.
Usage:
  lua tools/tests/test_vendor_mode_policy_source.lua
]]

if false then
    dofile("Modules/Vendor/Core/VendorModePolicy.lua")
end

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

print("test_vendor_mode_policy_source")

local policySource = read_file("Modules/Vendor/Core/VendorModePolicy.lua")
local classSource = read_file("Modules/Vendor/Core/VendorClass.lua")
local vendorSource = read_file("Modules/Vendor/Vendor.lua")

assert_contains(policySource, "function ModePolicy.GetModeCategories(owner, mode)",
    "VendorModePolicy owns category lookup")
assert_contains(policySource, "function ModePolicy.SetModeCategories(owner, mode, categories)",
    "VendorModePolicy owns category updates")
assert_contains(policySource, "function ModePolicy.GetSelectedCategoryIndex(owner, mode)",
    "VendorModePolicy owns category selection indexes")
assert_contains(policySource, "function ModePolicy.ResetCategoryState(owner)",
    "VendorModePolicy owns category cache resets")
assert_contains(policySource, "local function CloneTabs(tabs)",
    "VendorModePolicy owns tab snapshot cloning")
assert_contains(policySource, "return CloneTabs(context.stableTabs or {})",
    "VendorModePolicy clones stable fallback tabs before returning them")
assert_contains(policySource, "return CloneTabs(tabs)",
    "VendorModePolicy always returns owned tab snapshots")

assert_contains(classSource, 'local VendorModePolicy = assert(Vendor.ModePolicy, "Vendor mode policy must load before VendorClass")',
    "VendorClass requires the mode policy boundary")
assert_contains(classSource, "return VendorModePolicy.GetModeCategories(self, mode)",
    "VendorClass delegates category lookup to VendorModePolicy")
assert_contains(classSource, "local previousCategories, normalizedCategories, selectedIndex = VendorModePolicy.SetModeCategories(self, mode, categories)",
    "VendorClass delegates category updates to VendorModePolicy")
assert_contains(classSource, "return VendorModePolicy.GetCurrentCategory(self, mode)",
    "VendorClass delegates current category reads to VendorModePolicy")
assert_contains(classSource, "local cachedBuyCategories = VendorModePolicy.GetCachedBuyCategories(instance)",
    "VendorClass reads cached buy categories through VendorModePolicy")
assert_contains(classSource, "local selectedCategoryIndex = VendorModePolicy.GetSelectedCategoryIndex(instance, categoryMode)",
    "VendorClass reads selected category state through VendorModePolicy")
assert_not_contains(classSource, "instance.categoryIndexByMode[",
    "VendorClass no longer mutates selected category indexes directly")
assert_not_contains(classSource, "instance.modeCategories[",
    "VendorClass no longer mutates mode categories directly")
assert_not_contains(classSource, "instance._cachedBuyCategories",
    "VendorClass no longer reads or writes the cached buy-category field directly")

assert_contains(vendorSource, "Vendor.ModePolicy.ResetCategoryState(Vendor.instance)",
    "Vendor runtime clears category caches through VendorModePolicy")

print("  OK")
