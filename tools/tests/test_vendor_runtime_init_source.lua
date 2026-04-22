--[[
File: tools/tests/test_vendor_runtime_init_source.lua
Purpose: Behavior-first runtime/API coverage for Vendor runtime collaborators
         and request-contract aliases.
Usage:
  lua tools/tests/test_vendor_runtime_init_source.lua
]]

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    assert_eq(value, true, message)
end

print("test_vendor_runtime_init_source")

BETTERUI_VENDOR_SCENE_NAME = "BETTERUI_VENDOR"

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
        ModePolicy = {
            IsNativeStableModeActive = function()
                return false
            end,
        },
    },
    CIM = {
        UserNotify = function()
        end,
    },
}

SCENE_MANAGER = {
    scenes = {},
    Show = function()
    end,
    Hide = function()
    end,
    GetScene = function()
        return nil
    end,
}

dofile("Modules/Vendor/Core/Bridge/VendorNativeStoreBridge.lua")
dofile("Modules/Vendor/Core/VendorBootstrapRuntime.lua")
dofile("Modules/Vendor/Core/Lifecycle/VendorInteractionRuntime.lua")

local InteractionRuntime = BETTERUI.Vendor.InteractionRuntime
local NativeStoreBridge = BETTERUI.Vendor.NativeStoreBridge
local BootstrapRuntime = BETTERUI.Vendor.BootstrapRuntime

assert_true(type(InteractionRuntime.OpenStore) == "function", "interaction runtime exposes request-based OpenStore")
assert_true(type(InteractionRuntime.OpenFence) == "function", "interaction runtime exposes request-based OpenFence")
assert_true(type(InteractionRuntime.CloseStore) == "function", "interaction runtime exposes request-based CloseStore")
assert_true(InteractionRuntime.OnOpenStore == nil, "interaction runtime does not expose legacy OnOpenStore alias")
assert_true(InteractionRuntime.OnOpenFence == nil, "interaction runtime does not expose legacy OnOpenFence alias")
assert_true(InteractionRuntime.OnCloseStore == nil, "interaction runtime does not expose legacy OnCloseStore alias")

assert_true(type(NativeStoreBridge.TakeOverScene) == "function", "native store bridge exposes scene takeover")
assert_true(type(NativeStoreBridge.EnsureComponents) == "function", "native store bridge exposes component reconciliation")
assert_true(type(NativeStoreBridge.ResolveTargetMode) == "function", "native store bridge exposes target mode resolution")
assert_true(type(NativeStoreBridge.ScheduleOpenStoreSync) == "function", "native store bridge exposes deferred sync")

assert_true(type(BootstrapRuntime.InitializeList) == "function", "bootstrap runtime exposes list initialization")
assert_true(type(BootstrapRuntime.InitializeSearch) == "function", "bootstrap runtime exposes search initialization")
assert_true(type(BootstrapRuntime.CreateScene) == "function", "bootstrap runtime exposes scene creation")
assert_true(type(BootstrapRuntime.RegisterSceneLifecycle) == "function", "bootstrap runtime exposes scene lifecycle registration")

do
    local openStoreOk = pcall(function()
        InteractionRuntime.OpenStore("invalid")
    end)
    local openFenceOk = pcall(function()
        InteractionRuntime.OpenFence("invalid")
    end)
    local closeStoreOk = pcall(function()
        InteractionRuntime.CloseStore("invalid")
    end)
    assert_eq(openStoreOk, false, "OpenStore rejects non-table request contracts")
    assert_eq(openFenceOk, false, "OpenFence rejects non-table request contracts")
    assert_eq(closeStoreOk, false, "CloseStore rejects non-table request contracts")
end

do
    local lifecycleCalls = {}
    local runtime = {
        state = {},
        ResetInteractionState = function(self)
            lifecycleCalls[#lifecycleCalls + 1] = "reset-interaction"
            self.state = {}
        end,
        SetInteractionState = function(self, state)
            lifecycleCalls[#lifecycleCalls + 1] = "set-state"
            self.state = state
        end,
        ResetRuntimeState = function()
            lifecycleCalls[#lifecycleCalls + 1] = "reset-runtime"
        end,
        ShowScene = function()
            lifecycleCalls[#lifecycleCalls + 1] = "show-scene"
        end,
    }

    local bridge = {
        RestoreSceneAlias = function()
            lifecycleCalls[#lifecycleCalls + 1] = "restore-alias"
        end,
        AliasSceneToBetterUI = function()
            lifecycleCalls[#lifecycleCalls + 1] = "alias-scene"
        end,
        EnsureComponents = function(_, context)
            lifecycleCalls[#lifecycleCalls + 1] = "ensure-components:" .. tostring(context)
        end,
        ResolveTargetMode = function()
            lifecycleCalls[#lifecycleCalls + 1] = "resolve-target-mode"
            return 9
        end,
        ApplyResolvedMode = function(_, mode, refreshList)
            lifecycleCalls[#lifecycleCalls + 1] = string.format("apply-mode:%s:%s", tostring(mode), tostring(refreshList))
        end,
        ScheduleOpenStoreSync = function(_, mode, delayMs)
            lifecycleCalls[#lifecycleCalls + 1] = string.format("schedule:%s:%s", tostring(mode), tostring(delayMs))
        end,
    }

    InteractionRuntime.OpenStore({
        runtime = runtime,
        nativeStoreBridge = bridge,
        instance = {},
        options = {
            interactionType = 100,
            interactionVendor = 100,
            interactionStable = 200,
        },
    })

    assert_true(runtime.state.isStableInteraction == false, "runtime-adapter path updates lifecycle state")
    assert_true(table.concat(lifecycleCalls, ","):find("show-scene", 1, true) ~= nil,
        "runtime-adapter path performs open-store scene transitions")
end

do
    local safeContexts = {}
    BETTERUI.Vendor.ExecuteSafely = function(context, fn, ...)
        safeContexts[#safeContexts + 1] = context
        return pcall(fn, ...)
    end

    local storeManager = {
        activeComponents = { "keep" },
        OnHide = function()
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

    local safeContextLog = table.concat(safeContexts, ",")
    assert_true(
        safeContextLog:find("Vendor.CloseStore:NativeOnHide", 1, true) ~= nil
            or safeContextLog:find("Vendor.OnCloseStore:NativeOnHide", 1, true) ~= nil
            or safeContextLog:find("CloseStore:beforeSweep", 1, true) ~= nil
            or safeContextLog:find("OnCloseStore:beforeSweep", 1, true) ~= nil,
        "close-store safe execution preserves explicit lifecycle cleanup context strings")
end

print("  OK")
