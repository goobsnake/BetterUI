--[[
File: tools/tests/test_vendor_presentation_runtime_source.lua
Purpose: Behavior-focused coverage for vendor presentation runtime preview flows.
Usage:
  lua tools/tests/test_vendor_presentation_runtime_source.lua
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, message)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    assert_eq(value == true, true, message)
end

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            REPAIR = 3,
            BUYBACK = 4,
            FENCE_SELL = 5,
            FENCE_LAUNDER = 6,
            STABLE = 7,
            SELL_VENGEANCE = 8,
        },
    },
}

FRAME_TARGET_STORE_GAMEPAD_FRAGMENT = {}
FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT = {}
GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT = {}
FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT = {}
BETTERUI_VENDOR_SCENE_NAME = "BETTERUI_VENDOR"

local blurOps = {}
SCENE_MANAGER = {
    AddFragment = function(_, fragment)
        blurOps[#blurOps + 1] = { op = "add", fragment = fragment }
    end,
    RemoveFragmentImmediately = function(_, fragment)
        blurOps[#blurOps + 1] = { op = "remove", fragment = fragment }
    end,
}

ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE = "validate"
ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE = "execute"

local previewActions = {}
function ZO_StoreManager_DoPreviewAction(action, storeEntryIndex)
    previewActions[#previewActions + 1] = { action = action, storeEntryIndex = storeEntryIndex }
    if action == ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE then
        return storeEntryIndex == 5
    end
    return true
end

function IsCharacterPreviewingAvailable()
    return true
end

ITEM_PREVIEW_GAMEPAD = {
    enabled = false,
    toggles = 0,
    sets = {},
    IsInteractionCameraPreviewEnabled = function(self)
        return self.enabled
    end,
    ToggleInteractionCameraPreview = function(self)
        self.toggles = self.toggles + 1
        self.enabled = not self.enabled
    end,
    SetInteractionCameraPreviewEnabled = function(self, enabled)
        self.enabled = enabled == true
        self.sets[#self.sets + 1] = enabled == true
    end,
}

dofile("Modules/Vendor/Core/Presentation/VendorPresentationRuntime.lua")

local Runtime = BETTERUI.Vendor.PresentationRuntime

local mode = BETTERUI.Vendor.MODE.BUY
local blurState = {}
local hiddenState = {}
local disableCalls = 0
local refreshCalls = 0

local instance = {
    GetCurrentMode = function()
        return mode
    end,
    SetVendorPreviewBlurActive = function(_, hidden)
        blurState[#blurState + 1] = hidden == true
        return Runtime.SetVendorPreviewBlurActive(nil, hidden)
    end,
    SetVendorStorePreviewUiHidden = function(_, hidden)
        hiddenState[#hiddenState + 1] = hidden == true
    end,
    DisableVendorStorePreviewMode = function(self)
        disableCalls = disableCalls + 1
        Runtime.DisableVendorStorePreviewMode(self)
    end,
    CanPreviewVendorStoreEntry = function(self, selectedData)
        return Runtime.CanPreviewVendorStoreEntry(self, selectedData, function()
            return false
        end)
    end,
    UpdateVendorStorePreview = function(self, selectedData)
        refreshCalls = refreshCalls + 1
        Runtime.UpdateVendorStorePreview(self, selectedData, function()
            return false
        end)
    end,
    list = {
        GetTargetData = function()
            return {
                dataSource = {
                    entryIndex = 5,
                },
            }
        end,
    },
}

assert_eq(Runtime.CanPreviewVendorStoreEntry(instance, { entryIndex = 5 }, function()
    return true
end), false, "preview is blocked during stable interactions")

mode = BETTERUI.Vendor.MODE.SELL
assert_eq(Runtime.CanPreviewVendorStoreEntry(instance, { entryIndex = 5 }, function()
    return false
end), false, "preview is blocked outside buy mode")

mode = BETTERUI.Vendor.MODE.BUY
assert_eq(Runtime.CanPreviewVendorStoreEntry(instance, { entryIndex = 5 }, function()
    return false
end), true, "preview allows eligible buy entries")

ITEM_PREVIEW_GAMEPAD.enabled = true
Runtime.UpdateVendorStorePreview(instance, {
    dataSource = {
        entryIndex = 5,
    },
}, function()
    return false
end)
assert_true(#previewActions >= 2, "update preview validates and executes preview actions when eligible")
assert_eq(blurState[#blurState], true, "update preview enables blur for eligible entries")
assert_eq(hiddenState[#hiddenState], true, "update preview hides UI while preview is active")

local disableBeforeInvalidUpdate = disableCalls
Runtime.UpdateVendorStorePreview(instance, {
    dataSource = {
        entryIndex = 999,
    },
}, function()
    return false
end)
assert_true(disableCalls > disableBeforeInvalidUpdate,
    "update preview disables preview mode when selection cannot be previewed")

local refreshBeforeToggle = refreshCalls
ITEM_PREVIEW_GAMEPAD.enabled = false
Runtime.ToggleVendorStorePreviewMode(instance, function()
    return false
end)
assert_eq(ITEM_PREVIEW_GAMEPAD.toggles, 1, "toggle preview flips interaction camera preview state")
assert_true(refreshCalls > refreshBeforeToggle, "toggle preview refreshes preview for current list selection")

if failed > 0 then
    error(string.format("test_vendor_presentation_runtime_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_vendor_presentation_runtime_source.lua: %d passed", passed))
