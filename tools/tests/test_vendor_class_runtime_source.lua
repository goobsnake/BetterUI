--[[
File: tools/tests/test_vendor_class_runtime_source.lua
Purpose: Guards the VendorClass controller split so mode transitions and list
         refresh orchestration stay behind the controller runtime collaborator.
Usage:
  lua tools/tests/test_vendor_class_runtime_source.lua
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

print("test_vendor_class_runtime_source")

local classSource = read_file("Modules/Vendor/Core/VendorClass.lua")
local safeExecuteSource = read_file("Modules/Vendor/Core/VendorSafeExecute.lua")
local controllerRuntimeSource = read_file("Modules/Vendor/Core/VendorControllerRuntime.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(safeExecuteSource, "function Vendor.ExecuteSafely(context, fn, ...)",
    "Vendor safe-execute helper defines the shared vendor execution wrapper")
assert_contains(classSource, 'local ExecuteSafely = assert(Vendor.ExecuteSafely, "Vendor safe execute helper must load before VendorClass")',
    "VendorClass depends on the shared safe-execute helper instead of defining its own wrapper")
assert_contains(classSource, 'local VendorControllerRuntime = assert(Vendor.ControllerRuntime, "Vendor controller runtime must load before VendorClass")',
    "VendorClass requires the controller runtime collaborator")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorSafeExecute.lua",
    "Vendor manifest loads the shared safe-execute helper before VendorClass")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorControllerRuntime.lua",
    "Vendor manifest loads the controller runtime collaborator before VendorClass")

assert_contains(controllerRuntimeSource, "function ControllerRuntime.ToggleBuySellMode(instance, deps)",
    "Vendor controller runtime owns mode toggle orchestration")
assert_contains(controllerRuntimeSource, "function ControllerRuntime.SetMode(instance, mode)",
    "Vendor controller runtime owns mode transition orchestration")
assert_contains(controllerRuntimeSource, "function ControllerRuntime.RefreshList(instance, deps)",
    "Vendor controller runtime owns list refresh orchestration")
assert_contains(controllerRuntimeSource, "function ControllerRuntime.SaveListPosition(instance, deps)",
    "Vendor controller runtime owns saved-position persistence")

assert_contains(classSource, "VendorControllerRuntime.ToggleBuySellMode(self, {",
    "VendorClass.ToggleBuySellMode delegates to the controller runtime collaborator")
assert_contains(classSource, "VendorControllerRuntime.SetMode(self, mode)",
    "VendorClass.SetMode delegates to the controller runtime collaborator")
assert_contains(classSource, "VendorControllerRuntime.RefreshList(self, {",
    "VendorClass.RefreshList delegates to the controller runtime collaborator")
assert_contains(classSource, "getModeModuleKey = GetVendorModeModuleKey,",
    "VendorClass supplies mode position keys through the controller runtime contract")
assert_contains(classSource, "getCategoryKey = GetVendorCategoryKey,",
    "VendorClass supplies category position keys through the controller runtime contract")
assert_contains(classSource, "resolveModeEmptyStateText = ResolveModeEmptyStateText,",
    "VendorClass supplies empty-state policy through the controller runtime contract")

print("  OK")
