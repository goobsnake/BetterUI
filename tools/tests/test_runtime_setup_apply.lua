--[[
File: tools/tests/test_runtime_setup_apply.lua
Purpose: Headless regression tests for RuntimeSetup.Apply side effects.
Usage: lua tools/tests/test_runtime_setup_apply.lua
]]

if false then
    dofile("Modules/CIM/Core/Lifecycle/RuntimeSetup.lua")
end

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

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

local function assert_not_nil(value, label)
    assert_eq(value ~= nil, true, label)
end

local function newHarness(options)
    options = options or {}

    local state = {
        ensureSharedManagerCalls = 0,
        ensureRuntimeStateCalls = 0,
        registeredEvents = {},
        unregisteredEvents = {},
        preHooks = {},
        refreshSelectionCalls = 0,
        lastRefreshSelectionArgs = nil,
        delayedCalls = {},
    }

    BETTERUI = {
        CIM = {},
    }

    local debugRegistrationCalls = 0
    BETTERUI.CIM.Debug = {
        EnsureCommandsRegistered = function()
            debugRegistrationCalls = debugRegistrationCalls + 1
        end,
    }

    BETTERUI.CIM.DeferredTask = {
        EnsureSharedManager = function()
            state.ensureSharedManagerCalls = state.ensureSharedManagerCalls + 1
            return { manager = "shared" }
        end,
    }

    BETTERUI.CIM.EventRegistry = {
        EnsureRuntimeState = function()
            state.ensureRuntimeStateCalls = state.ensureRuntimeStateCalls + 1
        end,
    }

    EVENT_PLAYER_ACTIVATED = 3
    EVENT_MANAGER = {
        RegisterForEvent = function(_, name, eventCode, callback)
            state.registeredEvents[name] = {
                eventCode = eventCode,
                callback = callback,
            }
        end,
        UnregisterForEvent = function(_, name, eventCode)
            state.unregisteredEvents[#state.unregisteredEvents + 1] = {
                name = name,
                eventCode = eventCode,
            }
            state.registeredEvents[name] = nil
        end,
    }

    function zo_callLater(callback, delayMs)
        state.delayedCalls[#state.delayedCalls + 1] = delayMs
        callback()
    end

    function ZO_PreHook(target, methodName, callback)
        state.preHooks[methodName] = callback
        target[methodName] = callback
    end

    if options.withTamrielTomes ~= false then
        ZO_TamrielTomesScreen_Shared = {}
    else
        ZO_TamrielTomesScreen_Shared = nil
    end

    function GetCVar(key)
        if key == "language.2" then
            return "en"
        end
        return nil
    end

    dofile("Modules/CIM/Core/Lifecycle/RuntimeSetup.lua")

    state.Apply = BETTERUI.CIM.RuntimeSetup.Apply
    state.debugRegistrationCalls = function()
        return debugRegistrationCalls
    end
    return state
end

print("[RuntimeSetup.Apply direct harness]")

do
    local harness = newHarness({ withTamrielTomes = true })
    local settings = {
        Modules = {
            Tooltips = {
                m_enabled = true,
                showMarketPrice = true,
            },
            Inventory = {
                showMarketPrice = false,
            },
        },
    }

    harness.Apply(settings)
    harness.Apply(settings)

    assert_eq(harness.ensureSharedManagerCalls, 2,
        "Apply ensures shared task manager state on every call")
    assert_eq(harness.ensureRuntimeStateCalls, 2,
        "Apply ensures lifecycle runtime state on every call")
    assert_eq(harness.debugRegistrationCalls(), 2,
        "Apply registers debug commands through the explicit runtime hook")
    assert_eq(harness.registeredEvents["BETTERUI_RuntimeSetup_TamrielTomesGuardRetry"], nil,
        "Apply does not register a retry event when Tamriel Tomes is already available")
    assert_not_nil(harness.preHooks.SetSelectedTamrielTomesRewardData,
        "Apply installs the Tamriel Tomes selection guard")

    local invalidSelectionScreen = {
        gridList = {
            RefreshSelection = function(_, ...)
                harness.refreshSelectionCalls = harness.refreshSelectionCalls + 1
                harness.lastRefreshSelectionArgs = { ... }
            end,
        },
    }
    local hook = harness.preHooks.SetSelectedTamrielTomesRewardData
    assert_true(hook(invalidSelectionScreen, { bogus = true }),
        "selection guard blocks invalid placeholder data")
    assert_eq(harness.refreshSelectionCalls, 1,
        "selection guard schedules a grid refresh for invalid placeholder data")
    assert_eq(harness.lastRefreshSelectionArgs[1], true,
        "selection guard refresh preserves the force-refresh flag")
    assert_eq(harness.lastRefreshSelectionArgs[2], true,
        "selection guard refresh preserves the maintain-focus flag")

    local validSelection = {
        CanClaimReward = function() end,
        CanPreviewReward = function() end,
        GetRewardData = function() end,
    }
    assert_eq(hook(invalidSelectionScreen, validSelection), false,
        "selection guard allows valid reward rows through")

    assert_not_nil(settings.Modules.GeneralInterface,
        "Apply migrates Tooltips settings onto the canonical GeneralInterface module")
    assert_eq(settings.Modules.GeneralInterface.showMarketPrice, true,
        "Apply preserves migrated market-price visibility")
    assert_eq(settings.Modules.Inventory.showMarketPrice, nil,
        "Apply clears the legacy Inventory market-price key")
    assert_eq(settings.Modules.Tooltips, nil,
        "Apply removes the legacy Tooltips module key")
end

do
    local harness = newHarness({ withTamrielTomes = false })
    local settings = { Modules = {} }

    harness.Apply(settings)

    local retryRegistration = harness.registeredEvents["BETTERUI_RuntimeSetup_TamrielTomesGuardRetry"]
    assert_eq(harness.debugRegistrationCalls(), 1,
        "Apply still registers debug commands when Tamriel Tomes is unavailable")
    assert_not_nil(retryRegistration,
        "Apply registers a retry event when Tamriel Tomes is not available yet")
    assert_eq(retryRegistration.eventCode, EVENT_PLAYER_ACTIVATED,
        "retry guard waits for player activation")

    ZO_TamrielTomesScreen_Shared = {}
    retryRegistration.callback()

    assert_not_nil(harness.preHooks.SetSelectedTamrielTomesRewardData,
        "retry callback installs the selection guard once Tamriel Tomes becomes available")
    assert_eq(harness.registeredEvents["BETTERUI_RuntimeSetup_TamrielTomesGuardRetry"], nil,
        "retry callback clears the retry registration after a successful install")
    assert_eq(harness.unregisteredEvents[1].name, "BETTERUI_RuntimeSetup_TamrielTomesGuardRetry",
        "retry callback unregisters the retry event after the guard is installed")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
