--[[
File: tools/tests/test_vendor_scene_cleanup_once.lua
Purpose: Regression coverage for once-per-hide Vendor shared input cleanup.
Usage:
  lua tools/tests/test_vendor_scene_cleanup_once.lua
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local lifecycleConfig
local cleanupCalls = 0
local deactivateCalls = 0
local clearSearchCalls = 0
local spinnerDetachCalls = 0
local closeCleanupCalls = 0
local componentDeactivateCalls = 0

BETTERUI_VENDOR_SCENE_NAME = "BETTERUI_VENDOR"
BETTERUI = {
    Vendor = {
        InlineBuySpinner = {
            Detach = function()
                spinnerDetachCalls = spinnerDetachCalls + 1
            end,
        },
    },
    CIM = {
        CONST = {
            LAYOUT = {
                PANEL = {
                    WIDTH = 100,
                    ZO_WIDTH = 200,
                },
            },
        },
        SetTooltipWidth = function() end,
        SceneLifecycle = {
            Register = function(_, config)
                lifecycleConfig = config
            end,
        },
        SceneCleanup = {
            CleanupInputState = function()
                cleanupCalls = cleanupCalls + 1
            end,
            DeactivateLists = function()
                deactivateCalls = deactivateCalls + 1
            end,
            ClearSearchState = function()
                clearSearchCalls = clearSearchCalls + 1
            end,
        },
    },
    Interface = {
        UpdateCurrentKeybindGroups = function()
            return true
        end,
    },
}

BETTERUI.Vendor.RunLifecycleCloseCleanup = function(screen)
    if screen._vendorCloseCleanupApplied then
        return
    end
    screen._vendorCloseCleanupApplied = true
    closeCleanupCalls = closeCleanupCalls + 1
end

local activePreviewCallback = nil
ITEM_PREVIEW_GAMEPAD = {
    RegisterCallback = function(_, eventName, callback)
        if eventName == "RefreshActions" then
            activePreviewCallback = callback
        end
    end,
    UnregisterCallback = function(_, eventName, callback)
        if eventName == "RefreshActions" and activePreviewCallback == callback then
            activePreviewCallback = nil
        end
    end,
}
GAMEPAD_TOOLTIPS = nil

dofile("Modules/Vendor/Core/VendorBootstrapRuntime.lua")

local component = {
    Deactivate = function()
        componentDeactivateCalls = componentDeactivateCalls + 1
    end,
}

local screen = {
    coreKeybinds = {},
    GetCurrentMode = function()
        return nil
    end,
    DeactivateHeaderKeybinds = function() end,
    DeactivateListInput = function() end,
    GetActiveComponent = function()
        return component
    end,
    ApplyNativeStoreMode = function() end,
    RefreshVendorFooter = function() end,
    InitializeScrollIndicator = function() end,
    RefreshList = function() end,
    EnsureHeaderKeybindsActive = function() end,
    EnsureColumnHeadersVisible = function() end,
}

BETTERUI.Vendor.BootstrapRuntime.RegisterSceneLifecycle(screen, {
    taskManager = {},
})

assert_eq(type(lifecycleConfig), "table", "lifecycle registration captures callbacks")

lifecycleConfig.onHiding(screen)
lifecycleConfig.onHidden(screen)

assert_eq(cleanupCalls, 1, "HIDING then HIDDEN cleans input state once")
assert_eq(deactivateCalls, 1, "HIDING then HIDDEN deactivates lists once")
assert_eq(clearSearchCalls, 1, "HIDING then HIDDEN clears search once")
assert_eq(spinnerDetachCalls, 1, "HIDING then HIDDEN detaches spinner once")
assert_eq(closeCleanupCalls, 1, "existing close cleanup remains once per hide")
assert_eq(componentDeactivateCalls, 1, "HIDDEN still deactivates the active component")

cleanupCalls = 0
deactivateCalls = 0
clearSearchCalls = 0
spinnerDetachCalls = 0
screen._vendorCloseCleanupApplied = false
screen._vendorSharedInputCleanupApplied = false

lifecycleConfig.onHidden(screen)

assert_eq(cleanupCalls, 1, "direct HIDDEN fallback cleans input state")
assert_eq(deactivateCalls, 1, "direct HIDDEN fallback deactivates lists")
assert_eq(clearSearchCalls, 1, "direct HIDDEN fallback clears search")
assert_eq(spinnerDetachCalls, 1, "direct HIDDEN fallback detaches spinner")

screen._vendorSharedInputCleanupApplied = true
lifecycleConfig.onShowing(screen, false)
assert_eq(screen._vendorSharedInputCleanupApplied, false, "SHOWING resets shared cleanup generation")

cleanupCalls = 0
deactivateCalls = 0
clearSearchCalls = 0
spinnerDetachCalls = 0
lifecycleConfig.onHiding(screen)

assert_eq(cleanupCalls, 1, "next HIDING runs cleanup after SHOWING reset")
assert_eq(deactivateCalls, 1, "next HIDING deactivates lists after SHOWING reset")
assert_eq(clearSearchCalls, 1, "next HIDING clears search after SHOWING reset")
assert_eq(spinnerDetachCalls, 1, "next HIDING detaches spinner after SHOWING reset")

lifecycleConfig.onShowing(screen, false)
assert_eq(activePreviewCallback ~= nil, true, "SHOWING registers the preview callback")
lifecycleConfig.onHidden(screen)
assert_eq(activePreviewCallback, nil, "direct HIDDEN unregisters the preview callback")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
