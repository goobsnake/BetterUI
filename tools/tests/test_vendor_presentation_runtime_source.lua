--[[
File: tools/tests/test_vendor_presentation_runtime_source.lua
Purpose: Guards VendorClass preview/footer delegation into the focused presentation runtime.
Usage:
  lua tools/tests/test_vendor_presentation_runtime_source.lua
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

print("test_vendor_presentation_runtime_source")

local vendorClassSource = read_file("Modules/Vendor/Core/VendorClass.lua")
local presentationRuntimeSource = read_file("Modules/Vendor/Core/VendorPresentationRuntime.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(vendorClassSource, "local VendorPresentationRuntime = assert(Vendor.PresentationRuntime",
    "VendorClass requires the presentation runtime collaborator")
assert_contains(vendorClassSource, "VendorPresentationRuntime.CanPreviewVendorStoreEntry(self, selectedData, IsStableInteractionActive)",
    "VendorClass delegates vendor preview eligibility to presentation runtime")
assert_contains(vendorClassSource, "VendorPresentationRuntime.UpdateVendorStorePreview(self, selectedData, IsStableInteractionActive)",
    "VendorClass delegates vendor preview refresh to presentation runtime")
assert_contains(vendorClassSource, "VendorPresentationRuntime.ToggleStablePreviewMode(self, IsStableInteractionActive)",
    "VendorClass delegates stable preview toggling to presentation runtime")
assert_contains(vendorClassSource, "VendorPresentationRuntime.InitVendorFooter(self, IsStableInteractionActive)",
    "VendorClass delegates footer initialization to presentation runtime")
assert_contains(vendorClassSource, "VendorPresentationRuntime.RefreshVendorFooter(self, {",
    "VendorClass delegates footer refresh rendering to presentation runtime")

assert_contains(presentationRuntimeSource, "function PresentationRuntime.UpdateVendorStorePreview(instance, selectedData, isStableInteractionActive)",
    "Presentation runtime owns vendor preview refresh behavior")
assert_contains(presentationRuntimeSource, "function PresentationRuntime.UpdateStablePreview(instance, isStableInteractionActive)",
    "Presentation runtime owns stable preview refresh behavior")
assert_contains(presentationRuntimeSource, "function PresentationRuntime.InitVendorFooter(instance, isStableInteractionActive)",
    "Presentation runtime owns footer initialization behavior")
assert_contains(presentationRuntimeSource, "function PresentationRuntime.RefreshVendorFooter(instance, deps)",
    "Presentation runtime owns footer rendering behavior")

assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorPresentationRuntime.lua",
    "Vendor manifest loads the presentation runtime collaborator")

print("  OK")
