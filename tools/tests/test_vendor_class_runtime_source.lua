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

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", label, tostring(expected), tostring(actual)))
    end
end

local function assert_count(haystack, needle, expected, label)
    local count = 0
    local cursor = 1
    while true do
        local index = haystack:find(needle, cursor, true)
        if not index then break end
        count = count + 1
        cursor = index + #needle
    end
    assert_eq(count, expected, label)
end

local function load_class_method(source, methodName, nextMethodName)
    local startMarker = "function BETTERUI.Vendor.Class:" .. methodName
    local endMarker = "function BETTERUI.Vendor.Class:" .. nextMethodName
    local startIndex = assert(source:find(startMarker, 1, true), "missing method " .. methodName)
    local endIndex = assert(source:find(endMarker, startIndex + #startMarker, true), "missing next method " .. nextMethodName)
    local loader = loadstring or load
    local chunk = assert(loader(source:sub(startIndex, endIndex - 1)))
    chunk()
end

print("test_vendor_class_runtime_source")

local classSource = read_file("Modules/Vendor/Core/VendorClass.lua")
local safeExecuteSource = read_file("Modules/Vendor/Core/VendorSafeExecute.lua")
local controllerRuntimeSource = read_file("Modules/Vendor/Core/Lifecycle/VendorControllerRuntime.lua")
local bootstrapRuntimeSource = read_file("Modules/Vendor/Core/VendorBootstrapRuntime.lua")
local vendorRootSource = read_file("Modules/Vendor/Vendor.lua")
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
assert_contains(classSource, "local msSelectedCount =",
    "Vendor keybind fingerprint includes multi-select selected count")
assert_contains(classSource, "inlineSpinner:GetQuantity()",
    "Vendor keybind fingerprint reads inline-buy quantity from the attached spinner")
assert_contains(classSource, "pcall(self.CanAfford, self, totalPrice, currencyType)",
    "Vendor keybind fingerprint reflects inline-buy affordability using the existing CanAfford API")
assert_count(bootstrapRuntimeSource, 'screen:RefreshCoreKeybindOwnership("sceneShowing", true)', 1,
    "Vendor scene showing performs exactly one deterministic forced core reclaim")
assert_not_contains(bootstrapRuntimeSource, "ScheduleSceneEntryKeybindRefresh",
    "Vendor bootstrap no longer schedules a redundant deferred scene-entry reclaim")
assert_not_contains(vendorRootSource, "RegisterSceneEntryKeybindRecovery",
    "Vendor root no longer registers a second SCENE_SHOWN reclaim callback")
assert_not_contains(classSource, "function BETTERUI.Vendor.Class:ScheduleSceneEntryKeybindRefresh",
    "Vendor class no longer exposes deferred scene-entry reclaim machinery")
assert_not_contains(classSource,
    "BETTERUI.Interface.EnsureKeybindGroupAdded(self.coreKeybinds)\n    if BETTERUI.Interface.UpdateKeybindGroup then",
    "Vendor core ownership does not immediately Ensure then Update the same keybind group")
assert_not_contains(classSource,
    "BETTERUI.Interface.EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)\n        if BETTERUI.Interface.UpdateKeybindGroup then",
    "Vendor search entry does not immediately Ensure then Update the same keybind group")

-- Execute the production method bodies in a minimal deterministic keybind harness.
-- This keeps call-count coverage focused without loading the full ESOUI class graph.
BETTERUI = {
    Vendor = { Class = {} },
    Interface = {},
}

local dialogVisible = false
function HasVisibleGamepadDialog()
    return dialogVisible
end
function TraceVendorKeybindLayer()
end

load_class_method(classSource, "RefreshCoreKeybindOwnership", "ScheduleCoreKeybindRefresh")
load_class_method(classSource, "RefreshVendorActionKeybinds", "RefreshVendorHeaderCarouselLayout")

local calls = {}
local groupPresent = true
local fullyOwned = true
local function reset_calls()
    calls = { ensure = 0, remove = 0, updateGroup = 0, updateGlobal = 0 }
end

BETTERUI.Interface.HasKeybindGroup = function()
    return groupPresent
end
BETTERUI.Interface.EnsureKeybindGroupAdded = function()
    calls.ensure = calls.ensure + 1
    groupPresent = true
end
BETTERUI.Interface.RemoveKeybindGroupIfPresent = function()
    calls.remove = calls.remove + 1
    groupPresent = false
end
BETTERUI.Interface.UpdateKeybindGroup = function()
    calls.updateGroup = calls.updateGroup + 1
end
BETTERUI.Interface.UpdateCurrentKeybindGroups = function()
    calls.updateGlobal = calls.updateGlobal + 1
    return true
end

local instance = setmetatable({
    coreKeybinds = {},
    sceneShowing = true,
    IsSceneShowing = function(self) return self.sceneShowing end,
    IsCoreKeybindGroupDisplaced = function() return not fullyOwned end,
    IsCoreKeybindGroupFullyOwned = function() return fullyOwned end,
}, { __index = BETTERUI.Vendor.Class })

reset_calls()
instance:RefreshVendorActionKeybinds()
assert_eq(calls.updateGlobal, 1, "enabled Vendor action refresh performs the required global label refresh")
assert_eq(calls.updateGroup, 0, "intact Vendor ownership skips the redundant per-group update")
assert_eq(calls.ensure, 0, "intact Vendor ownership does not re-add the core group")

reset_calls()
fullyOwned = false
groupPresent = true
instance:RefreshVendorActionKeybinds()
assert_eq(calls.remove, 1, "displaced Vendor ownership removes the stale core group")
assert_eq(calls.ensure, 1, "displaced Vendor ownership deterministically reclaims the core group")
assert_eq(calls.updateGroup, 0, "displaced Vendor reclaim relies on re-add plus the global label refresh")
assert_eq(calls.updateGlobal, 1, "displaced Vendor reclaim still refreshes global labels")

reset_calls()
fullyOwned = true
instance.sceneShowing = false
instance:RefreshVendorActionKeybinds()
assert_eq(calls.updateGlobal, 0, "rapid Vendor close blocks late action-keybind refreshes")
assert_eq(calls.ensure, 0, "rapid Vendor close blocks late ownership reclaims")

reset_calls()
instance.sceneShowing = true
dialogVisible = true
instance:RefreshVendorActionKeybinds()
assert_eq(calls.updateGlobal, 0, "visible dialogs retain their keybind layer")
assert_eq(calls.ensure, 0, "visible dialogs block Vendor ownership reclaims")

reset_calls()
dialogVisible = false
instance._searchModeActive = true
instance:RefreshVendorActionKeybinds()
assert_eq(calls.updateGlobal, 0, "active Vendor search retains its keybind layer")
assert_eq(calls.ensure, 0, "active Vendor search blocks core ownership reclaims")

print("  OK")
