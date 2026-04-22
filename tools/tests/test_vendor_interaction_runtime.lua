--[[
File: tools/tests/test_vendor_interaction_runtime.lua
Purpose: Runtime coverage for vendor interaction workflows so open/fence/close
         behavior is validated through the lifecycle runtime collaborator seam.
Usage:
  lua tools/tests/test_vendor_interaction_runtime.lua
]]

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    assert_eq(value, true, message)
end

BETTERUI = {
    Vendor = {},
}

dofile("Modules/Vendor/Core/VendorInteractionRuntime.lua")

local InteractionRuntime = BETTERUI.Vendor.InteractionRuntime

local function BuildRuntime(log)
    return {
        state = {
            isFenceInteraction = false,
            isStableInteraction = false,
            fenceEnableSell = false,
            fenceEnableLaunder = false,
        },
        ResetInteractionState = function(self, instance)
            self.state.isFenceInteraction = false
            self.state.isStableInteraction = false
            self.state.fenceEnableSell = false
            self.state.fenceEnableLaunder = false
            if instance then
                instance._vendorCloseCleanupApplied = false
            end
            log[#log + 1] = "reset-interaction"
        end,
        MarkClosingState = function(self)
            self.state.isFenceInteraction = false
            self.state.isStableInteraction = false
            self.state.fenceEnableSell = false
            self.state.fenceEnableLaunder = false
            log[#log + 1] = "mark-closing"
        end,
        SetInteractionState = function(self, nextState)
            for key, value in pairs(nextState or {}) do
                self.state[key] = value
            end
            log[#log + 1] = "set-interaction-state"
        end,
        ResetRuntimeState = function(_, instance)
            if instance then
                log[#log + 1] = "reset-runtime"
            end
        end,
        CancelRuntimeTasks = function()
            log[#log + 1] = "cancel-runtime-tasks"
        end,
        ShowScene = function()
            log[#log + 1] = "show-scene"
        end,
        HideScene = function()
            log[#log + 1] = "hide-scene"
        end,
        LogDebug = function(_, _, _, _)
            log[#log + 1] = "log-debug"
        end,
        LogNativeStoreInputState = function(_, context, _storeManager)
            log[#log + 1] = "log-native-state:" .. tostring(context)
        end,
        SafeCall = function(_, _, fn, target)
            fn(target)
            return true
        end,
        GetStoreManager = function()
            return {
                activeComponents = { "keep" },
                OnHide = function()
                    log[#log + 1] = "native-onhide"
                end,
            }
        end,
        RunCloseCleanup = function(_, instance)
            if instance then
                instance.closeCleanupCalls = (instance.closeCleanupCalls or 0) + 1
            end
            log[#log + 1] = "run-close-cleanup"
        end,
    }
end

local function BuildBridge(log)
    return {
        RestoreSceneAlias = function()
            log[#log + 1] = "restore-alias"
        end,
        AliasSceneToBetterUI = function()
            log[#log + 1] = "alias-scene"
        end,
        EnsureComponents = function(_, context)
            log[#log + 1] = "ensure-components:" .. tostring(context)
        end,
        ResolveTargetMode = function()
            log[#log + 1] = "resolve-target-mode"
            return 42
        end,
        ApplyResolvedMode = function(_, mode, refreshList)
            log[#log + 1] = string.format("apply-mode:%s:%s", tostring(mode), tostring(refreshList))
        end,
        ScheduleOpenStoreSync = function(_, mode, delayMs)
            log[#log + 1] = string.format("schedule-sync:%s:%s", tostring(mode), tostring(delayMs))
        end,
    }
end

do
    local calls = {}
    local runtime = BuildRuntime(calls)
    local bridge = BuildBridge(calls)
    local instance = {
        ReleaseNativeStoreInputOwnership = function()
            calls[#calls + 1] = "release-native-input"
        end,
    }

    InteractionRuntime.OpenStore({
        runtime = runtime,
        nativeStoreBridge = bridge,
        instance = instance,
        options = {
            interactionType = 10,
            interactionVendor = 10,
            interactionStable = 20,
            isNativeStableModeActive = function()
                return false
            end,
        },
    })

    assert_eq(runtime.state.isFenceInteraction, false, "open-store clears fence state")
    assert_eq(runtime.state.isStableInteraction, false, "open-store keeps stable mode off for regular vendors")
    assert_true(table.concat(calls, ","):find("alias-scene", 1, true) ~= nil, "open-store aliases scene")
    assert_true(table.concat(calls, ","):find("release-native-input", 1, true) ~= nil,
        "open-store releases native input ownership")
    assert_true(table.concat(calls, ","):find("apply-mode:42:false", 1, true) ~= nil, "open-store applies target mode")
    assert_true(table.concat(calls, ","):find("schedule-sync:42:120", 1, true) ~= nil,
        "open-store schedules deferred sync")
end

do
    local calls = {}
    local runtime = BuildRuntime(calls)
    local bridge = BuildBridge(calls)
    local instance = {
        ReleaseNativeStoreInputOwnership = function()
            calls[#calls + 1] = "release-native-input"
        end,
        SetMode = function(_, mode)
            calls[#calls + 1] = "set-mode:" .. tostring(mode)
        end,
    }

    InteractionRuntime.OpenFence({
        runtime = runtime,
        nativeStoreBridge = bridge,
        instance = instance,
        options = {
            sellMode = 5,
            fenceLaunderMode = 6,
        },
        enableSell = true,
        enableLaunder = false,
    })

    assert_eq(runtime.state.isFenceInteraction, true, "open-fence enables fence interaction mode")
    assert_eq(runtime.state.fenceEnableSell, true, "open-fence tracks sell enablement")
    assert_eq(runtime.state.fenceEnableLaunder, false, "open-fence tracks launder enablement")
    assert_true(table.concat(calls, ","):find("set-mode:5", 1, true) ~= nil, "open-fence switches to sell mode")
    assert_true(table.concat(calls, ","):find("show-scene", 1, true) ~= nil, "open-fence shows scene")
end

do
    local calls = {}
    local runtime = BuildRuntime(calls)
    local bridge = BuildBridge(calls)
    local instance = {}

    InteractionRuntime.CloseStore({
        runtime = runtime,
        nativeStoreBridge = bridge,
        instance = instance,
    })

    assert_eq(runtime.state.isFenceInteraction, false, "close-store clears fence interaction state")
    assert_eq(runtime.state.isStableInteraction, false, "close-store clears stable interaction state")
    assert_true(table.concat(calls, ","):find("cancel-runtime-tasks", 1, true) ~= nil,
        "close-store cancels runtime tasks")
    assert_true(table.concat(calls, ","):find("run-close-cleanup", 1, true) ~= nil,
        "close-store runs centralized close cleanup")
    assert_true(table.concat(calls, ","):find("native-onhide", 1, true) ~= nil,
        "close-store runs native OnHide through safe call")
    assert_true(table.concat(calls, ","):find("alias-scene", 1, true) ~= nil,
        "close-store re-aliases scene back to BetterUI")
end

do
    local calls = {}
    local originalSafeExecute = BETTERUI.Vendor.ExecuteSafely
    BETTERUI.Vendor.ExecuteSafely = function(context, fn, ...)
        calls[#calls + 1] = "safe-context:" .. tostring(context)
        return pcall(fn, ...)
    end

    local storeManager = {
        activeComponents = { "keep" },
        OnHide = function()
            calls[#calls + 1] = "native-onhide"
        end,
    }

    InteractionRuntime.CloseStore({
        state = {},
        deps = {
            instance = {},
            markClosingState = function()
            end,
            resetRuntimeState = function()
            end,
            cancelRuntimeTasks = function()
            end,
            hideScene = function()
            end,
            aliasSceneToBetterUI = function()
            end,
            runCloseCleanup = function()
            end,
            getStoreManager = function()
                return storeManager
            end,
            logNativeStoreInputState = function()
            end,
        },
    })

    BETTERUI.Vendor.ExecuteSafely = originalSafeExecute

    assert_true(table.concat(calls, ","):find("safe-context:Vendor.OnCloseStore:NativeOnHide", 1, true) ~= nil,
        "close-store fallback safe call preserves context when runtime safe-call dependency is absent")
end

do
    local calls = {}
    local runtime = BuildRuntime(calls)
    local bridge = BuildBridge(calls)
    local instance = {
        ReleaseNativeStoreInputOwnership = function()
            calls[#calls + 1] = "release-native-input"
        end,
    }

    InteractionRuntime.OnOpenStore({
        runtime = runtime,
        nativeStoreBridge = bridge,
        instance = instance,
        options = {
            interactionType = 10,
            interactionVendor = 10,
            interactionStable = 20,
        },
    })

    assert_true(table.concat(calls, ","):find("show-scene", 1, true) ~= nil,
        "legacy OnOpenStore alias delegates through the canonical request runtime path")
end

do
    local openStoreOk = pcall(function()
        InteractionRuntime.OnOpenStore("invalid")
    end)
    local openFenceOk = pcall(function()
        InteractionRuntime.OnOpenFence("invalid")
    end)
    local closeStoreOk = pcall(function()
        InteractionRuntime.OnCloseStore("invalid")
    end)

    assert_eq(openStoreOk, false, "OnOpenStore rejects non-table requests")
    assert_eq(openFenceOk, false, "OnOpenFence rejects non-table requests")
    assert_eq(closeStoreOk, false, "OnCloseStore rejects non-table requests")
end

print("test_vendor_interaction_runtime.lua: PASS")
