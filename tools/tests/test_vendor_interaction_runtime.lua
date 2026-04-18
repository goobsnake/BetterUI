--[[
File: tools/tests/test_vendor_interaction_runtime.lua
Purpose: Runtime coverage for vendor interaction workflows so open/fence/close
         behavior is validated beyond source-shape assertions.
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

do
    local state = {
        isFenceInteraction = true,
        isStableInteraction = false,
        fenceEnableSell = true,
        fenceEnableLaunder = true,
    }
    local calls = {}
    local instance = {
        released = 0,
        ReleaseNativeStoreInputOwnership = function(self)
            self.released = self.released + 1
            calls[#calls + 1] = "release-native-input"
        end,
    }

    local nextState = InteractionRuntime.OnOpenStore(state, {
        resetInteractionState = function()
            calls[#calls + 1] = "reset-interaction"
        end,
        getInteractionType = function()
            return 10
        end,
        interactionVendor = 10,
        interactionStable = 20,
        isNativeStableModeActive = function()
            return false
        end,
        logVendorDebug = function()
        end,
        restoreNativeStoreSceneAlias = function()
            calls[#calls + 1] = "restore-alias"
        end,
        aliasStoreSceneToBetterUI = function()
            calls[#calls + 1] = "alias-scene"
        end,
        ensureNativeStoreComponents = function(context)
            calls[#calls + 1] = "ensure-components:" .. tostring(context)
        end,
        instance = instance,
        resetRuntimeState = function(target)
            assert_eq(target, instance, "open-store runtime reset receives vendor instance")
            calls[#calls + 1] = "reset-runtime"
        end,
        resolveVendorTargetMode = function()
            calls[#calls + 1] = "resolve-mode"
            return 42
        end,
        applyVendorResolvedMode = function(mode, refreshList)
            calls[#calls + 1] = string.format("apply-mode:%s:%s", tostring(mode), tostring(refreshList))
        end,
        showScene = function()
            calls[#calls + 1] = "show-scene"
        end,
        scheduleVendorOpenStoreSync = function(mode, delayMs)
            calls[#calls + 1] = string.format("schedule-sync:%s:%s", tostring(mode), tostring(delayMs))
        end,
    })

    assert_eq(nextState.isFenceInteraction, true, "open-store preserves non-fence interaction state")
    assert_eq(nextState.isStableInteraction, false, "open-store keeps stable mode off for regular vendors")
    assert_eq(instance.released, 1, "open-store releases native store input ownership")
    assert_eq(calls[1], "reset-interaction", "open-store resets interaction state first")
    assert_true(table.concat(calls, ","):find("alias-scene", 1, true) ~= nil, "open-store aliases the store scene")
    assert_true(table.concat(calls, ","):find("reset-runtime", 1, true) ~= nil, "open-store resets runtime state")
    assert_true(table.concat(calls, ","):find("apply-mode:42:false", 1, true) ~= nil, "open-store applies the resolved mode")
    assert_true(table.concat(calls, ","):find("schedule-sync:42:120", 1, true) ~= nil, "open-store schedules deferred mode sync")
end

do
    local state = {
        isFenceInteraction = false,
        isStableInteraction = false,
        fenceEnableSell = false,
        fenceEnableLaunder = false,
    }
    local calls = {}
    local instance = {
        modeChanges = {},
        ReleaseNativeStoreInputOwnership = function()
            calls[#calls + 1] = "release-native-input"
        end,
        SetMode = function(self, mode)
            self.modeChanges[#self.modeChanges + 1] = mode
            calls[#calls + 1] = "set-mode:" .. tostring(mode)
        end,
    }

    local nextState = InteractionRuntime.OnOpenFence(state, {
        resetInteractionState = function()
            calls[#calls + 1] = "reset-interaction"
        end,
        logVendorDebug = function()
        end,
        instance = instance,
        resetRuntimeState = function()
            calls[#calls + 1] = "reset-runtime"
        end,
        aliasStoreSceneToBetterUI = function()
            calls[#calls + 1] = "alias-scene"
        end,
        sellMode = 5,
        fenceLaunderMode = 6,
        showScene = function()
            calls[#calls + 1] = "show-scene"
        end,
    }, true, false)

    assert_eq(nextState.isFenceInteraction, true, "open-fence enables fence interaction mode")
    assert_eq(nextState.fenceEnableSell, true, "open-fence keeps sell enabled when requested")
    assert_eq(nextState.fenceEnableLaunder, false, "open-fence disables launder when requested")
    assert_true(table.concat(calls, ","):find("set-mode:5", 1, true) ~= nil, "open-fence chooses sell mode when sell is enabled")
    assert_true(table.concat(calls, ","):find("show-scene", 1, true) ~= nil, "open-fence shows the vendor scene")
end

do
    local state = {
        isFenceInteraction = true,
        isStableInteraction = true,
        fenceEnableSell = true,
        fenceEnableLaunder = true,
        sessionHasBuyMode = true,
        openStoreSyncAttempt = 7,
    }
    local calls = {}
    local instance = {
        DisableStablePreviewMode = function()
            calls[#calls + 1] = "disable-stable-preview"
        end,
        ReleaseNativeStoreInputOwnership = function()
            calls[#calls + 1] = "release-native-input"
        end,
        ForceReleaseDirectionalInput = function()
            calls[#calls + 1] = "force-release-directional-input"
        end,
    }
    local storeManager = {
        activeComponents = { "keep" },
        OnHide = function()
            calls[#calls + 1] = "native-onhide"
        end,
    }

    local nextState = InteractionRuntime.OnCloseStore(state, {
        instance = instance,
        resetRuntimeState = function()
            calls[#calls + 1] = "reset-runtime"
        end,
        cancelRuntimeTasks = function()
            calls[#calls + 1] = "cancel-runtime-tasks"
        end,
        logVendorDebug = function()
        end,
        hideScene = function()
            calls[#calls + 1] = "hide-scene"
        end,
        getStoreManager = function()
            return storeManager
        end,
        logNativeStoreInputState = function(_, manager)
            calls[#calls + 1] = "log-native-state:" .. tostring(manager == storeManager)
        end,
        safeCall = function(_, fn, target)
            fn(target)
            return true
        end,
        aliasStoreSceneToBetterUI = function()
            calls[#calls + 1] = "alias-scene"
        end,
    })

    assert_eq(nextState.isClosing, true, "close-store marks the workflow as closing")
    assert_eq(nextState.isFenceInteraction, false, "close-store clears fence interaction state")
    assert_eq(nextState.isStableInteraction, false, "close-store clears stable interaction state")
    assert_eq(nextState.sessionHasBuyMode, false, "close-store clears remembered buy-mode state")
    assert_eq(nextState.openStoreSyncAttempt, 0, "close-store resets deferred sync attempts")
    assert_eq(#storeManager.activeComponents, 0, "close-store clears native active components")
    assert_true(table.concat(calls, ","):find("cancel-runtime-tasks", 1, true) ~= nil, "close-store cancels pending runtime tasks")
    assert_true(table.concat(calls, ","):find("native-onhide", 1, true) ~= nil, "close-store runs native OnHide through the safe call")
    assert_true(table.concat(calls, ","):find("alias-scene", 1, true) ~= nil, "close-store restores the BetterUI scene alias")
end

print("test_vendor_interaction_runtime.lua: PASS")
