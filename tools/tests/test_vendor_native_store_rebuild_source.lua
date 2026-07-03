--[[
File: tools/tests/test_vendor_native_store_rebuild_source.lua
Purpose: Behavior-first coverage for native-store rebuild planning and cleanup
         orchestration.
Usage:
  lua tools/tests/test_vendor_native_store_rebuild_source.lua
]]

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    assert_eq(value, true, message)
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

print("test_vendor_native_store_rebuild_source")

ZO_MODE_STORE_BUY = 1
ZO_MODE_STORE_SELL = 2
ZO_MODE_STORE_REPAIR = 3
ZO_MODE_STORE_BUY_BACK = 4
ZO_MODE_STORE_STABLE = 5
ZO_MODE_STORE_SELL_VENGEANCE = 6
EVENT_OPEN_STORE = 101
EVENT_CLOSE_STORE = 102

local diDeactivations = {}
DIRECTIONAL_INPUT = {
    IsListening = function(_, object)
        return object ~= nil
    end,
    Deactivate = function(_, object)
        diDeactivations[#diDeactivations + 1] = object
    end,
}

local setStoreModeCalls = {}
function SetStoreMode(mode)
    setStoreModeCalls[#setStoreModeCalls + 1] = mode
end

function CanStoreRepair()
    return true
end

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 10,
            SELL = 20,
            REPAIR = 30,
            BUYBACK = 40,
            STABLE = 50,
            SELL_VENGEANCE = 60,
        },
        ExecuteSafely = function(context, fn, ...)
            return pcall(fn, ...)
        end,
        ResolveNativeStoreMode = function(mode)
            local map = {
                [10] = ZO_MODE_STORE_BUY,
                [20] = ZO_MODE_STORE_SELL,
                [30] = ZO_MODE_STORE_REPAIR,
                [40] = ZO_MODE_STORE_BUY_BACK,
                [50] = ZO_MODE_STORE_STABLE,
                [60] = ZO_MODE_STORE_SELL_VENGEANCE,
            }
            return map[mode]
        end,
        GetActiveTabs = function()
            return {
                { mode = 10 },
                { mode = 20 },
                { mode = 40 },
                { mode = 30 },
            }
        end,
        ResolveInitialStoreMode = function()
            return 20
        end,
        IsFenceInteraction = function()
            return false
        end,
        IsStableInteraction = function()
            return false
        end,
        IsSellVengeanceModeAvailable = function()
            return false
        end,
        HasVendorBuyInventory = function()
            return true
        end,
        instance = {
            IsSceneActiveOrShowing = function()
                return true
            end,
            GetCurrentMode = function()
                return 20
            end,
            SetMode = function(_, mode)
                BETTERUI.Vendor.instance.currentMode = mode
            end,
            ApplyNativeStoreMode = function(_, mode)
                BETTERUI.Vendor.instance.currentMode = mode
            end,
            RefreshList = function()
            end,
        },
        Tasks = {
            Cancel = function()
            end,
            Schedule = function(_, _, _, callback)
                callback()
            end,
        },
        InteractionRuntime = {
            FindSpecializedNativeScene = function()
                return nil, nil
            end,
        },
        LogDebug = function()
        end,
    },
    GetModuleEnabled = function(moduleName)
        return moduleName == "Vendor"
    end,
}

local function CreateComponent(mode)
    return {
        list = { id = "list-" .. tostring(mode) },
        GetStoreMode = function()
            return mode
        end,
    }
end

local function HasMode(modes, expectedMode)
    for _, mode in ipairs(modes or {}) do
        if mode == expectedMode then
            return true
        end
    end
    return false
end

local function BuildStoreManager()
    local setActiveCalls = {}
    local setModeCalls = {}
    local initializeStoreCalls = 0
    local tabBarDeactivated = 0
    local registeredControlEvents = {}
    local unregisteredControlEvents = {}

    local manager = {
        sceneName = "gamepad_store",
        control = {
            RegisterForEvent = function(_, eventId, callback)
                registeredControlEvents[eventId] = callback
                return true
            end,
            UnregisterForEvent = function(_, eventId)
                unregisteredControlEvents[#unregisteredControlEvents + 1] = eventId
                registeredControlEvents[eventId] = nil
                return true
            end,
        },
        components = {
            [ZO_MODE_STORE_BUY] = CreateComponent(ZO_MODE_STORE_BUY),
            [ZO_MODE_STORE_SELL] = CreateComponent(ZO_MODE_STORE_SELL),
            [ZO_MODE_STORE_REPAIR] = CreateComponent(ZO_MODE_STORE_REPAIR),
            [ZO_MODE_STORE_BUY_BACK] = CreateComponent(ZO_MODE_STORE_BUY_BACK),
            [ZO_MODE_STORE_STABLE] = CreateComponent(ZO_MODE_STORE_STABLE),
        },
        activeComponents = {
            CreateComponent(ZO_MODE_STORE_SELL),
        },
        header = {
            tabBar = {
                SetOnActivatedChangedFunction = function()
                end,
                RemoveAllOnSelectedDataChangedCallbacks = function()
                end,
                IsActive = function()
                    return true
                end,
                Deactivate = function()
                    tabBarDeactivated = tabBarDeactivated + 1
                end,
            },
        },
        _currentList = {
            IsActive = function()
                return true
            end,
            Deactivate = function()
            end,
        },
        SetActiveComponents = function(self, modes, searchContext)
            setActiveCalls[#setActiveCalls + 1] = {
                modes = modes,
                searchContext = searchContext,
            }
            local rebuilt = {}
            for _, mode in ipairs(modes) do
                if self.components[mode] then
                    rebuilt[#rebuilt + 1] = self.components[mode]
                end
            end
            self.activeComponents = rebuilt
        end,
        SetMode = function(_, mode)
            setModeCalls[#setModeCalls + 1] = mode
        end,
        InitializeStore = function()
            initializeStoreCalls = initializeStoreCalls + 1
        end,
    }

    return manager, setActiveCalls, setModeCalls, function()
        return initializeStoreCalls
    end, function()
        return tabBarDeactivated
    end, registeredControlEvents, unregisteredControlEvents
end

dofile("Modules/Vendor/Core/Bridge/VendorNativeStoreBridge.lua")
local NativeStoreBridge = BETTERUI.Vendor.NativeStoreBridge

do
    local storeManager, setActiveCalls, setModeCalls, getInitializeStoreCalls, getTabBarDeactivated = BuildStoreManager()
    STORE_WINDOW_GAMEPAD = storeManager

    NativeStoreBridge.EnsureComponents("test-search")

    assert_eq(storeManager.sceneName, "gamepad_store", "ensure components leaves native sceneName metadata intact while rebuilding")
    assert_eq(#setActiveCalls, 1, "ensure components rebuilds native active components when required")
    assert_eq(setActiveCalls[1].searchContext, "test-search", "ensure components forwards explicit search context")
    assert_true(#setActiveCalls[1].modes >= 3, "rebuild includes all eligible non-stable store modes")
    assert_eq(setModeCalls[1], ZO_MODE_STORE_BUY, "rebuild re-targets native store manager to buy mode when available")
    -- U50 has no global SetStoreMode (verified absent from ESOUIDocumentation.txt);
    -- the rebuild must NOT call it and instead drives mode via storeManager:SetMode.
    assert_eq(setStoreModeCalls[1], nil, "rebuild does not call the (nonexistent) global SetStoreMode")
    assert_eq(getInitializeStoreCalls(), 1, "rebuild initializes the native store after rebuilding components")
    assert_eq(getTabBarDeactivated(), 1, "rebuild neutralizes native tab bar callbacks and deactivates active tab bar")
    assert_true(#diDeactivations > 0, "rebuild sweeps directional input registrations after applying plan")
end

do
    local storeManager, setActiveCalls = BuildStoreManager()
    STORE_WINDOW_GAMEPAD = storeManager
    storeManager.activeComponents = {
        CreateComponent(ZO_MODE_STORE_STABLE),
    }
    BETTERUI.Vendor._sessionHasBuyMode = false
    BETTERUI.Vendor.IsStableInteraction = function()
        return true
    end
    BETTERUI.Vendor.HasVendorBuyInventory = function()
        return false
    end

    NativeStoreBridge.EnsureComponents("stable-search")

    assert_eq(#setActiveCalls, 1, "stable rebuild runs even when buy inventory probing is empty")
    assert_true(HasMode(setActiveCalls[1].modes, ZO_MODE_STORE_BUY),
        "stable rebuild always preserves native buy component when available")
    assert_true(HasMode(setActiveCalls[1].modes, ZO_MODE_STORE_STABLE),
        "stable rebuild preserves native stable component")

    BETTERUI.Vendor.IsStableInteraction = function()
        return false
    end
    BETTERUI.Vendor.HasVendorBuyInventory = function()
        return true
    end
end

do
    local cleanupContexts = {}
    local safeContexts = {}

    local storeManager = {
        activeComponents = { "keep" },
        OnHide = function()
        end,
    }

    NativeStoreBridge.CleanupAfterCloseStore(storeManager, function(context, fn, ...)
        safeContexts[#safeContexts + 1] = context
        return pcall(fn, ...)
    end, function(context)
        cleanupContexts[#cleanupContexts + 1] = context
    end)

    assert_eq(cleanupContexts[1], "OnCloseStore:beforeSweep", "cleanup emits before-sweep context")
    assert_eq(cleanupContexts[2], "OnCloseStore:afterSweep", "cleanup emits after-sweep context")
    assert_eq(safeContexts[1], "Vendor.OnCloseStore:NativeOnHide", "cleanup preserves explicit safe-call context")
    assert_eq(#storeManager.activeComponents, 0, "cleanup clears native active components")
end

do
    local storeManager, _, _, _, _, registeredControlEvents, unregisteredControlEvents = BuildStoreManager()
    STORE_WINDOW_GAMEPAD = storeManager
    local nativeOpenFallbacks = 0
    local nativeCloseFallbacks = 0
    BETTERUI.Vendor.InteractionRuntime.ShowNativeStore = function(request)
        nativeOpenFallbacks = nativeOpenFallbacks + 1
        assert_eq(request.deps.storeManager, storeManager, "native open fallback receives the taken-over store manager")
    end
    BETTERUI.Vendor.InteractionRuntime.HideNativeStore = function(request)
        nativeCloseFallbacks = nativeCloseFallbacks + 1
        assert_eq(request.deps.storeManager, storeManager, "native close fallback receives the taken-over store manager")
    end

    NativeStoreBridge.TakeOverScene({ scene = {} })

    assert_eq(unregisteredControlEvents[1], EVENT_OPEN_STORE,
        "takeover unregisters the native open control callback before installing the wrapper")
    assert_eq(unregisteredControlEvents[2], EVENT_CLOSE_STORE,
        "takeover unregisters the native close control callback before installing the wrapper")
    assert_eq(type(registeredControlEvents[EVENT_OPEN_STORE]), "function",
        "takeover installs a replacement open control callback")
    assert_eq(type(registeredControlEvents[EVENT_CLOSE_STORE]), "function",
        "takeover installs a replacement close control callback")

    registeredControlEvents[EVENT_OPEN_STORE]()
    registeredControlEvents[EVENT_CLOSE_STORE]()
    assert_eq(nativeOpenFallbacks, 0, "enabled Vendor module suppresses native open callback for BetterUI flow")
    assert_eq(nativeCloseFallbacks, 0, "enabled Vendor module suppresses native close callback for BetterUI flow")

    BETTERUI.GetModuleEnabled = function()
        return false
    end
    registeredControlEvents[EVENT_OPEN_STORE]()
    registeredControlEvents[EVENT_CLOSE_STORE]()
    assert_eq(nativeOpenFallbacks, 1, "disabled Vendor module routes open callback to native fallback")
    assert_eq(nativeCloseFallbacks, 1, "disabled Vendor module routes close callback to native fallback")

    BETTERUI.GetModuleEnabled = function(moduleName)
        return moduleName == "Vendor"
    end
end

do
    local source = assert((function()
        local handle = assert(io.open("Modules/Vendor/Core/Bridge/VendorNativeStoreBridge.lua", "r"))
        local contents = handle:read("*a")
        handle:close()
        return contents
    end)())

    assert_not_contains(source, "local methods = { \"OnOpenStore\", \"OnCloseStore\", \"OpenStore\", \"CloseStore\" }",
        "TakeOverScene no longer prehooks nonexistent ZO_GamepadStoreManager methods")
    assert_not_contains(source, "ZO_PreHook(storeManager, methodName",
        "TakeOverScene does not use dynamic native store method prehooks")
    assert_contains(source, "vendor.native_store_takeover", "TakeOverScene has suppression trace hook channel")
    assert_contains(source, "InstallNativeStoreControlEventHandlers",
        "TakeOverScene installs replacement control event handlers")
    assert_contains(source, "control:UnregisterForEvent(openEvent)",
        "TakeOverScene explicitly unregisters the native open control callback")
    assert_contains(source, "control_event_hook_installed",
        "TakeOverScene traces replacement control event installation")
    assert_contains(source, "ShouldBetterUIOwnNativeStoreOpenEvent",
        "TakeOverScene suppresses native callbacks only when BetterUI owns store flow")
    assert_contains(source, "ShowNativeStoreFallback",
        "TakeOverScene routes non-BetterUI open events through native fallback")
end

print("  OK")
