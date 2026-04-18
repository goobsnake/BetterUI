--[[
File: tools/tests/test_vendor_mode_runtime.lua
Purpose: Runtime coverage for the controller runtime's mode transition seam.
Usage:
  lua tools/tests/test_vendor_mode_runtime.lua
]]

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assert_table_entry(sequence, index, expected, message)
    assert_eq(sequence[index], expected, message)
end

local keybindUpdates = 0
local exitSelectionModeCalls = 0

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            STABLE = 7,
        },
        multiSelectManager = {
            ExitSelectionMode = function()
                exitSelectionModeCalls = exitSelectionModeCalls + 1
            end,
        },
    },
    CIM = {
        HeaderNavigation = {
            GetOrCreateState = function(instance)
                instance.headerState = instance.headerState or {}
                return instance.headerState
            end,
        },
    },
}

KEYBIND_STRIP = {
    UpdateCurrentKeybindButtonGroups = function()
        keybindUpdates = keybindUpdates + 1
    end,
}

dofile("Modules/Vendor/Core/VendorControllerRuntime.lua")

local ControllerRuntime = BETTERUI.Vendor.ControllerRuntime
local MODE = BETTERUI.Vendor.MODE

local transitionLog = {}
local savedPositions = 0
local nativeModes = {}
local headerRebuilds = 0
local footerRefreshes = 0
local stablePreviewDisables = 0
local vendorPreviewDisables = 0

local oldComponent = {
    Deactivate = function(_, instance)
        transitionLog[#transitionLog + 1] = "deactivate:" .. tostring(instance.currentMode)
    end,
}

local sellComponent = {
    Activate = function(_, instance)
        transitionLog[#transitionLog + 1] = "activate:" .. tostring(instance.currentMode)
    end,
}

local vendorInstance = {
    currentMode = MODE.BUY,
    components = {
        [MODE.BUY] = oldComponent,
        [MODE.SELL] = sellComponent,
    },
    SaveListPosition = function()
        savedPositions = savedPositions + 1
    end,
    GetActiveComponent = function(self)
        return self.components[self.currentMode]
    end,
    ApplyNativeStoreMode = function(_, mode)
        nativeModes[#nativeModes + 1] = mode
    end,
    RebuildCategoryHeader = function()
        headerRebuilds = headerRebuilds + 1
    end,
    RefreshVendorFooter = function()
        footerRefreshes = footerRefreshes + 1
    end,
    DisableStablePreviewMode = function()
        stablePreviewDisables = stablePreviewDisables + 1
    end,
    DisableVendorStorePreviewMode = function()
        vendorPreviewDisables = vendorPreviewDisables + 1
    end,
    IsSceneShowing = function()
        return true
    end,
}

ControllerRuntime.SetMode(vendorInstance, MODE.SELL)

assert_eq(vendorInstance.currentMode, MODE.SELL, "controller runtime applies the new current mode")
assert_eq(savedPositions, 1, "controller runtime saves the outgoing list position")
assert_eq(exitSelectionModeCalls, 1, "controller runtime exits multi-select before switching modes")
assert_eq(vendorInstance.headerState.justToggledMode, true, "controller runtime marks the header state as a toggled-mode transition")
assert_table_entry(transitionLog, 1, "deactivate:1", "controller runtime deactivates the outgoing component first")
assert_table_entry(transitionLog, 2, "activate:2", "controller runtime activates the incoming component after switching modes")
assert_eq(nativeModes[1], MODE.SELL, "controller runtime applies the matching native store mode")
assert_eq(stablePreviewDisables, 1, "controller runtime disables stable preview when leaving buy mode")
assert_eq(vendorPreviewDisables, 1, "controller runtime disables vendor preview when leaving buy mode")
assert_eq(headerRebuilds, 1, "controller runtime rebuilds the category header after switching modes")
assert_eq(footerRefreshes, 1, "controller runtime refreshes the footer after switching modes")
assert_eq(keybindUpdates, 1, "controller runtime refreshes keybinds while the scene is showing")

print("test_vendor_mode_runtime.lua: PASS")
