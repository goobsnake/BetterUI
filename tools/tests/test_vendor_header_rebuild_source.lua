--[[
File: tools/tests/test_vendor_header_rebuild_source.lua
Purpose: Guards the Vendor header rebuild split so header-model construction,
         selection callbacks, and post-render activation stay separated.
Usage:
  lua tools/tests/test_vendor_header_rebuild_source.lua
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

print("test_vendor_header_rebuild_source")

local source = read_file("Modules/Vendor/Core/VendorClass.lua")

assert_contains(source, "local function BuildVendorHeaderModel(instance)",
    "Vendor header rebuild extracts a header-model builder")
assert_contains(source, "local function CreateVendorHeaderSelectionHandler(instance, headerModel, headerNavigation, navigationState)",
    "Vendor header rebuild extracts the selection callback factory")
assert_contains(source, "local function RenderVendorHeader(instance, headerGeneric, headerModel)",
    "Vendor header rebuild extracts header rendering")
assert_contains(source, "local function RestoreVendorHeaderInteraction(instance, headerGeneric, headerModel, headerNavigation)",
    "Vendor header rebuild extracts post-render interaction restoration")
assert_contains(source, "local headerModel = BuildVendorHeaderModel(self)",
    "RebuildCategoryHeader delegates model construction")
assert_contains(source, "self.vendorHeaderData = BuildVendorHeaderData(self, headerModel, onSelectedChanged)",
    "RebuildCategoryHeader delegates header data assembly")
assert_contains(source, "RenderVendorHeader(self, headerGeneric, headerModel)",
    "RebuildCategoryHeader delegates header rendering")
assert_contains(source, "RestoreVendorHeaderInteraction(self, headerGeneric, headerModel, headerNavigation)",
    "RebuildCategoryHeader delegates post-render activation")
assert_not_contains(source, "self.vendorHeaderData.onSelectedChanged = function(list)",
    "RebuildCategoryHeader no longer defines the selection callback inline")

print("  OK")
