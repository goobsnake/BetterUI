--[[
File: tools/tests/test_runtime_setup_apply.lua
Purpose: Headless regression tests for RuntimeSetup.Apply side effects.
Usage: lua tools/tests/test_runtime_setup_apply.lua
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
        sceneLogRegistrations = 0,
        refreshSelectionCalls = 0,
        lastRefreshSelectionArgs = nil,
        delayedCalls = {},
    }

    BETTERUI = {
        CIM = {},
    }

    local debugRegistrationCalls = 0
    local debugEnabled = options.debugEnabled == true
    local developerVisible = options.developerVisible == true
    BETTERUI.CIM.Debug = {
        EnsureCommandsRegistered = function()
            debugRegistrationCalls = debugRegistrationCalls + 1
        end,
        IsEnabled = function()
            return debugEnabled
        end,
        ShouldShowDeveloperSettings = function()
            return developerVisible
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

    BETTERUI.CIM.SceneLog = {
        EnsureRegistered = function()
            state.sceneLogRegistrations = state.sceneLogRegistrations + 1
            return true
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
    assert_eq(harness.sceneLogRegistrations, 2,
        "Apply ensures framework scene logging is registered on every call")
    assert_eq(harness.debugRegistrationCalls(), 0,
        "Apply skips debug command registration while debug tooling is disabled")
    assert_eq(harness.registeredEvents["BETTERUI_RuntimeSetup_TamrielTomesGuardRetry"], nil,
        "Apply does not register a Tamriel Tomes retry event")
    assert_eq(harness.preHooks.SetSelectedTamrielTomesRewardData, nil,
        "Apply leaves Tamriel Tomes unhooked to avoid DirectPurchase taint")

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

    assert_eq(harness.debugRegistrationCalls(), 0,
        "Apply keeps debug command registration disabled when debug tooling is inactive")
    assert_eq(harness.registeredEvents["BETTERUI_RuntimeSetup_TamrielTomesGuardRetry"], nil,
        "Apply does not register a Tamriel Tomes retry event when the native class is absent")
    assert_eq(harness.preHooks.SetSelectedTamrielTomesRewardData, nil,
        "Apply still avoids Tamriel Tomes hooks when the native class appears later")
end

do
    local harness = newHarness({ withTamrielTomes = true, debugEnabled = true })
    harness.Apply({ Modules = {} })
    assert_eq(harness.debugRegistrationCalls(), 1,
        "Apply registers debug commands when debug mode is active")
end

do
    local harness = newHarness({ withTamrielTomes = true, developerVisible = true })
    harness.Apply({ Modules = {} })
    assert_eq(harness.debugRegistrationCalls(), 1,
        "Apply registers debug commands when developer settings are explicitly visible")
end

do
    -- Restore persisted /builog logging state across a reload.
    local harness = newHarness({ withTamrielTomes = true })
    local applyPresetCalls = {}
    local setEnabledCalls = {}
    local suppressPopupCalls = {}
    local screenshotAutoCalls = {}
    local chatSurfaceCalls = {}
    local minLevelCalls = {}
    BETTERUI.CIM.InterfaceLog = {
        SetEnabled = function(value) setEnabledCalls[#setEnabledCalls + 1] = value end,
        SetSuppressPopups = function(value) suppressPopupCalls[#suppressPopupCalls + 1] = value end,
        SetScreenshotAutoMode = function(mode, persist)
            screenshotAutoCalls[#screenshotAutoCalls + 1] = { mode = mode, persist = persist }
        end,
        SetChatSurface = function(value, persist)
            chatSurfaceCalls[#chatSurfaceCalls + 1] = { value = value, persist = persist }
        end,
        SetMinLevelSetting = function(name, persist)
            minLevelCalls[#minLevelCalls + 1] = { name = name, persist = persist }
        end,
        Write = function() end,
    }
    -- Permissive Log stub: explicit IsActive/ApplyPreset; any other method (Trace/etc.)
    -- is a no-op and any CATEGORY access yields a string, so Apply's other Log calls
    -- don't crash once BETTERUI.Log is present.
    BETTERUI.Log = setmetatable({
        IsActive = function() return false end,
        ApplyPreset = function(name) applyPresetCalls[#applyPresetCalls + 1] = name end,
        CATEGORY = setmetatable({}, { __index = function() return "CAT" end }),
    }, { __index = function() return function() end end })
    local store = {
        interfaceLogEnabled = true,
        interfaceLogPreset = "debug",
        interfaceLogSuppressPopups = false,
        interfaceLogScreenshotAutoMode = "warn",
        interfaceLogChat = true,
        interfaceLogMinLevel = "trace",
    }
    BETTERUI.GetSetting = function(_, key, default)
        local v = store[key]
        if v == nil then return default end
        return v
    end

    harness.Apply({ Modules = {} })
    assert_eq(applyPresetCalls[1], "debug",
        "Apply restores the persisted /builog preset after reload")
    assert_eq(suppressPopupCalls[1], false,
        "Apply restores persisted /builog popup visibility after reload")
    assert_eq(screenshotAutoCalls[1] and screenshotAutoCalls[1].mode, "warn",
        "Apply restores persisted /builog screenshot auto mode after reload")
    assert_eq(screenshotAutoCalls[1] and screenshotAutoCalls[1].persist, false,
        "Apply restores screenshot auto mode without re-persisting it")
    assert_eq(chatSurfaceCalls[1] and chatSurfaceCalls[1].value, false,
        "Apply forces legacy /builog chat surfacing off after reload")
    assert_eq(chatSurfaceCalls[1] and chatSurfaceCalls[1].persist, false,
        "Apply restores chat surfacing without re-persisting it")
    assert_eq(minLevelCalls[1] and minLevelCalls[1].name, "trace",
        "Apply restores persisted /builog min-level override after reload")
    assert_eq(minLevelCalls[1] and minLevelCalls[1].persist, false,
        "Apply restores min-level override without re-persisting it")

    store.interfaceLogPreset = ""
    applyPresetCalls = {}
    setEnabledCalls = {}
    harness.Apply({ Modules = {} })
    assert_eq(setEnabledCalls[1], true,
        "Apply re-enables plain /builog on (no named preset) after reload")
    assert_eq(#applyPresetCalls, 0,
        "plain-on restore does not call ApplyPreset")

    store.interfaceLogEnabled = false
    setEnabledCalls = {}
    applyPresetCalls = {}
    harness.Apply({ Modules = {} })
    assert_eq(#setEnabledCalls, 0,
        "Apply restores nothing when persisted logging is disabled")

    store.interfaceLogEnabled = nil
    setEnabledCalls = {}
    applyPresetCalls = {}
    harness.Apply({ Modules = {} })
    assert_eq(#setEnabledCalls, 0,
        "Apply leaves builog off when the persisted logging flag is missing")
    assert_eq(#applyPresetCalls, 0,
        "missing builog flag does not restore a preset on new installs")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
