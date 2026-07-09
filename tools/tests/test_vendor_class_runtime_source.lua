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

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

print("test_vendor_class_runtime_source")

local classSource = read_file("Modules/Vendor/Core/VendorClass.lua")
local safeExecuteSource = read_file("Modules/Vendor/Core/VendorSafeExecute.lua")
local controllerRuntimeSource = read_file("Modules/Vendor/Core/Lifecycle/VendorControllerRuntime.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(safeExecuteSource, "function Vendor.ExecuteSafely(context, fn, ...)",
    "Vendor safe-execute helper defines the shared vendor execution wrapper")
assert_contains(classSource, 'local ExecuteSafely = assert(Vendor.ExecuteSafely, "Vendor safe execute helper must load before VendorClass")',
    "VendorClass depends on the shared safe-execute helper instead of defining its own wrapper")
assert_contains(classSource, 'local VendorControllerRuntime = assert(Vendor.ControllerRuntime, "Vendor controller runtime must load before VendorClass")',
    "VendorClass requires the controller runtime collaborator")
assert_contains(classSource, 'local VendorModePolicy = assert(Vendor.ModePolicy, "Vendor mode policy must load before VendorClass")',
    "VendorClass requires the shared vendor mode-policy collaborator")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorSafeExecute.lua",
    "Vendor manifest loads the shared safe-execute helper before VendorClass")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\Lifecycle\\VendorControllerRuntime.lua",
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
assert_contains(classSource, "local modeSet = VendorModePolicy.BuildActiveModeSet(activeTabs)",
    "VendorClass builds active-mode sets through VendorModePolicy directly")
assert_contains(classSource, "return VendorModePolicy.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)",
    "VendorClass evaluates sell/buyback-only state through VendorModePolicy directly")
assert_not_contains(classSource, "BETTERUI.Vendor.BuildActiveModeSet",
    "VendorClass no longer reaches through the root vendor table for mode-set helpers")
assert_not_contains(classSource, "BETTERUI.Vendor.IsSellBuybackOnlyModeSet",
    "VendorClass no longer reaches through the root vendor table for sell/buyback helper state")
assert_not_contains(classSource, "Vendor.GetModeModuleKey = GetVendorModeModuleKey",
    "VendorClass keeps mode-module-key wiring private instead of exposing duplicate root helpers")
assert_not_contains(classSource, "Vendor.ResolveModePaneRole = ResolveModePaneRole",
    "VendorClass keeps pane-role resolver private instead of exposing duplicate root helpers")
assert_contains(classSource, "getModeModuleKey = GetVendorModeModuleKey,",
    "VendorClass supplies mode position keys through the controller runtime contract")
assert_contains(classSource, "getCategoryKey = GetVendorCategoryKey,",
    "VendorClass supplies category position keys through the controller runtime contract")
assert_contains(classSource, "resolveModeEmptyStateText = ResolveModeEmptyStateText,",
    "VendorClass supplies empty-state policy through the controller runtime contract")
assert_not_contains(classSource, "function BETTERUI.Vendor.Class:RunCoreKeybindSettleTick",
    "Vendor settle-sweep machinery removed -- native keybind suppression at source is the real fix")
assert_contains(classSource, "return iface.IsGroupKeybindButtonOwnedBySelf(self.coreKeybinds, \"UI_SHORTCUT_NEGATIVE\")\n        and iface.IsGroupKeybindButtonOwnedBySelf(self.coreKeybinds, \"UI_SHORTCUT_LEFT_SHOULDER\")\n        and iface.IsGroupKeybindButtonOwnedBySelf(self.coreKeybinds, \"UI_SHORTCUT_RIGHT_SHOULDER\")",
    "Vendor full-ownership gate checks identity ownership for Back and both category shoulders")
assert_not_contains(classSource, "return iface.IsGroupKeybindButtonPresent(self.coreKeybinds, \"UI_SHORTCUT_LEFT_SHOULDER\")",
    "Vendor full-ownership gate must not use key-presence-only checks for LB/RB")

print("  OK")
