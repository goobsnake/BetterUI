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
    -- BUI-CONS-004: DefaultSafeCall (used when a block omits deps.safeCall) now
    -- routes through Vendor.ExecuteSafely, a thin delegator over the
    -- unconditional BETTERUI.CIM.SafeExecute. Provide both so the fallback safe
    -- call resolves exactly as it does in production; the spy-override block
    -- below still replaces Vendor.ExecuteSafely directly.
    CIM = {
        SafeExecute = function(_context, fn, ...)
            if type(fn) ~= "function" then
                return false, "No function provided"
            end
            return pcall(fn, ...)
        end,
    },
}

BETTERUI.Vendor.ExecuteSafely = function(context, fn, ...)
    return BETTERUI.CIM.SafeExecute(context, fn, ...)
end

dofile("Modules/Vendor/Core/Lifecycle/VendorInteractionRuntime.lua")

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
        EnsureComponents = function(context)
            log[#log + 1] = "ensure-components:" .. tostring(context)
        end,
        ResolveTargetMode = function()
            log[#log + 1] = "resolve-target-mode"
            return 42
        end,
        ApplyResolvedMode = function(mode, refreshList)
            log[#log + 1] = string.format("apply-mode:%s:%s", tostring(mode), tostring(refreshList))
        end,
        ScheduleOpenStoreSync = function(mode, delayMs)
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
    local originalInterface = BETTERUI.Interface
    BETTERUI.Interface = {
        RemoveKeybindGroupIfPresent = function(group)
            calls[#calls + 1] = "remove-keybind:" .. tostring(group)
        end,
        UpdateCurrentKeybindGroups = function()
            calls[#calls + 1] = "update-current-keybinds"
        end,
    }
    local instance = {
        coreKeybinds = "core-kb",
        textSearchKeybindStripDescriptor = "search-kb",
        headerGeneric = {
            tabBar = {
                keybindStripDescriptor = "generic-tabbar-kb",
            },
        },
        header = {
            tabBar = {
                keybindStripDescriptor = "legacy-tabbar-kb",
            },
        },
        DeactivateHeaderKeybinds = function()
            calls[#calls + 1] = "deactivate-header-keybinds"
        end,
        DeactivateListInput = function()
            calls[#calls + 1] = "deactivate-list-input"
        end,
        ForceReleaseDirectionalInput = function()
            calls[#calls + 1] = "release-directional-input"
        end,
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
            findSpecializedNativeScene = function()
                return "TamrielTomesSceneGamepad", "showing"
            end,
        },
    })

    BETTERUI.Interface = originalInterface

    assert_true(table.concat(calls, ","):find("deactivate-header-keybinds", 1, true) ~= nil,
        "native handoff deactivates header keybinds")
    assert_true(table.concat(calls, ","):find("deactivate-list-input", 1, true) ~= nil,
        "native handoff deactivates list input")
    assert_true(table.concat(calls, ","):find("release-directional-input", 1, true) ~= nil,
        "native handoff releases directional input")
    assert_true(table.concat(calls, ","):find("release-native-input", 1, true) ~= nil,
        "native handoff releases native input ownership")
    assert_true(table.concat(calls, ","):find("remove-keybind:core-kb", 1, true) ~= nil,
        "native handoff removes core keybind strip")
    assert_true(table.concat(calls, ","):find("remove-keybind:search-kb", 1, true) ~= nil,
        "native handoff removes search keybind strip")
    assert_true(table.concat(calls, ","):find("remove-keybind:generic-tabbar-kb", 1, true) ~= nil,
        "native handoff removes generic header tab keybind strip")
    assert_true(table.concat(calls, ","):find("remove-keybind:legacy-tabbar-kb", 1, true) ~= nil,
        "native handoff removes legacy header tab keybind strip")
    assert_true(table.concat(calls, ","):find("update-current-keybinds", 1, true) ~= nil,
        "native handoff updates current keybind groups")
    assert_true(table.concat(calls, ","):find("restore-alias", 1, true) ~= nil,
        "native handoff restores scene alias")
    assert_true(table.concat(calls, ","):find("alias-scene", 1, true) == nil,
        "native handoff does not try to alias into BetterUI scene")
    assert_true(table.concat(calls, ","):find("show-native-store", 1, true) == nil,
        "native handoff skips ShowNativeStore for specialized scene")
end

do
    local originalSceneManager = SCENE_MANAGER
    local originalIsInGamepadPreferredMode = IsInGamepadPreferredMode
    local originalIsStoreEmpty = IsStoreEmpty
    local originalCanStoreRepair = CanStoreRepair
    local originalIsCurrentCampaignVengeanceRuleset = IsCurrentCampaignVengeanceRuleset
    local originalVengeanceEnabled = ZO_VENGEANCE_BAG_SELL_ENABLED
    local originalReleaseDialog = ZO_Dialogs_ReleaseDialog
    local originalModeBuy = ZO_MODE_STORE_BUY
    local originalModeSell = ZO_MODE_STORE_SELL
    local originalModeSellVengeance = ZO_MODE_STORE_SELL_VENGEANCE
    local originalModeBuyBack = ZO_MODE_STORE_BUY_BACK
    local originalModeRepair = ZO_MODE_STORE_REPAIR
    local originalSceneName = GAMEPAD_STORE_SCENE_NAME

    ZO_MODE_STORE_BUY = 1
    ZO_MODE_STORE_SELL = 2
    ZO_MODE_STORE_SELL_VENGEANCE = 3
    ZO_MODE_STORE_BUY_BACK = 4
    ZO_MODE_STORE_REPAIR = 5
    GAMEPAD_STORE_SCENE_NAME = "gamepad_store"
    ZO_VENGEANCE_BAG_SELL_ENABLED = true
    IsInGamepadPreferredMode = function() return true end
    IsStoreEmpty = function() return false end
    CanStoreRepair = function() return true end
    IsCurrentCampaignVengeanceRuleset = function() return true end

    local setActiveCalls = {}
    local sceneCalls = {}
    local releasedDialogs = {}
    local deactivateTextSearchCalls = 0
    local storeManager = {
        SetActiveComponents = function(_, modes, searchContext)
            setActiveCalls[#setActiveCalls + 1] = {
                modes = modes,
                searchContext = searchContext,
            }
        end,
        DeactivateTextSearch = function()
            deactivateTextSearchCalls = deactivateTextSearchCalls + 1
        end,
    }
    SCENE_MANAGER = {
        Show = function(_, sceneName)
            sceneCalls[#sceneCalls + 1] = "show:" .. tostring(sceneName)
        end,
        Hide = function(_, sceneName)
            sceneCalls[#sceneCalls + 1] = "hide:" .. tostring(sceneName)
        end,
    }
    ZO_Dialogs_ReleaseDialog = function(dialogName)
        releasedDialogs[#releasedDialogs + 1] = dialogName
    end

    local bridge = BuildBridge({})
    local deps = {
        nativeStoreBridge = bridge,
        getStoreManager = function()
            return storeManager
        end,
        safeCall = function(_, fn, ...)
            fn(...)
            return true
        end,
    }

    InteractionRuntime.ShowNativeStore({ deps = deps })
    assert_eq(setActiveCalls[1].searchContext, "storeTextSearch",
        "ShowNativeStore rebuilds native components with native search context")
    assert_eq(table.concat(setActiveCalls[1].modes, ","), "1,2,3,4,5",
        "ShowNativeStore mirrors ESOUI native store modes including vengeance and repair")
    assert_eq(sceneCalls[1], "show:gamepad_store", "ShowNativeStore shows the native gamepad store scene")

    InteractionRuntime.HideNativeStore({ deps = deps })
    assert_eq(releasedDialogs[1], "REPAIR_ALL", "HideNativeStore releases the native repair dialog")
    assert_eq(deactivateTextSearchCalls, 1, "HideNativeStore deactivates native text search")
    assert_eq(sceneCalls[2], "hide:gamepad_store", "HideNativeStore hides the native gamepad store scene")

    SCENE_MANAGER = originalSceneManager
    IsInGamepadPreferredMode = originalIsInGamepadPreferredMode
    IsStoreEmpty = originalIsStoreEmpty
    CanStoreRepair = originalCanStoreRepair
    IsCurrentCampaignVengeanceRuleset = originalIsCurrentCampaignVengeanceRuleset
    ZO_VENGEANCE_BAG_SELL_ENABLED = originalVengeanceEnabled
    ZO_Dialogs_ReleaseDialog = originalReleaseDialog
    ZO_MODE_STORE_BUY = originalModeBuy
    ZO_MODE_STORE_SELL = originalModeSell
    ZO_MODE_STORE_SELL_VENGEANCE = originalModeSellVengeance
    ZO_MODE_STORE_BUY_BACK = originalModeBuyBack
    ZO_MODE_STORE_REPAIR = originalModeRepair
    GAMEPAD_STORE_SCENE_NAME = originalSceneName
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
            restoreSceneAlias = function()
            end,
            hideScene = function()
            end,
            aliasSceneToBetterUI = function()
            end,
            ensureComponents = function()
            end,
            resolveTargetMode = function()
                return nil
            end,
            applyResolvedMode = function()
            end,
            scheduleOpenStoreSync = function()
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

    assert_true(table.concat(calls, ","):find("safe-context:Vendor.CloseStore:NativeOnHide", 1, true) ~= nil,
        "close-store fallback safe call preserves context when runtime safe-call dependency is absent")
end

do
    local originalSceneManager = SCENE_MANAGER
    local sceneName, sceneState = nil, nil
    SCENE_MANAGER = {
        GetCurrentSceneName = function()
            return "Tamrieltomes_PurchasePreview_Gamepad"
        end,
        IsShowingNext = function(_, candidateScene)
            assert_eq(type(candidateScene), "string", "scene manager receives scene-name lookup in ShowNext check")
            return false
        end,
        GetScene = function(_, sceneName)
            assert_eq(type(sceneName), "string", "scene manager receives scene-name lookup")
            return {
                IsShowing = function()
                    return false
                end,
                GetState = function()
                    return nil
                end,
            }
        end,
    }

    sceneName, sceneState = InteractionRuntime.FindSpecializedNativeScene()
    assert_eq(sceneName, "Tamrieltomes_PurchasePreview_Gamepad", "FindSpecializedNativeScene matches Tamriel Tomes scene-name drift")
    assert_eq(sceneState, "current", "FindSpecializedNativeScene reports scene state as current for drift names")

    SCENE_MANAGER = originalSceneManager
end

do
    local removedGroups = {}
    local updateCalls = 0
    local originalInterface = BETTERUI.Interface
    BETTERUI.Interface = {
        RemoveKeybindGroupIfPresent = function(group)
            removedGroups[#removedGroups + 1] = group
        end,
        UpdateCurrentKeybindGroups = function()
            updateCalls = updateCalls + 1
        end,
    }

    local calls = {}
    local instance = {
        coreKeybinds = "core",
        textSearchKeybindStripDescriptor = "search",
        headerGeneric = {
            tabBar = { keybindStripDescriptor = "generic-header" },
        },
        header = {
            tabBar = { keybindStripDescriptor = "header" },
        },
        DeactivateHeaderKeybinds = function()
            calls[#calls + 1] = "deactivate-header"
        end,
        DeactivateListInput = function()
            calls[#calls + 1] = "deactivate-list"
        end,
        ForceReleaseDirectionalInput = function()
            calls[#calls + 1] = "release-directional"
        end,
        ReleaseNativeStoreInputOwnership = function()
            calls[#calls + 1] = "release-native-input"
        end,
    }

    InteractionRuntime.PurgeNativeHandoffKeybindInterference(instance)

    assert_eq(table.concat(calls, ","), "deactivate-header,deactivate-list,release-directional,release-native-input",
        "handoff purge releases BetterUI input ownership in order")
    assert_eq(table.concat(removedGroups, ","), "core,search,generic-header,header",
        "handoff purge removes all BetterUI keybind descriptors from the strip")
    assert_eq(updateCalls, 1, "handoff purge refreshes active keybind groups")

    BETTERUI.Interface = originalInterface
end

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

    assert_eq(openStoreOk, false, "OpenStore rejects non-table requests")
    assert_eq(openFenceOk, false, "OpenFence rejects non-table requests")
    assert_eq(closeStoreOk, false, "CloseStore rejects non-table requests")
end

print("test_vendor_interaction_runtime.lua: PASS")
