--[[
File: tools/tests/test_vendor_root_lifecycle_runtime.lua
Purpose: Behavior-focused, headless coverage for root Vendor lifecycle entrypoints
         through event-registered callbacks.

Usage:
  lua tools/tests/test_vendor_root_lifecycle_runtime.lua
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

local function assert_true(condition, message)
    assert_eq(condition, true, message)
end

-- =================================================================================
-- GLOBAL STUBS
-- =================================================================================

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
        DEFAULTS = {},
    },
    CIM = {
        ARCHETYPES = {
            RUNTIME_COORDINATOR = "runtime-coordinator",
        },
        DeferredTask = {},
    },
}

local eventCallbacks = {}
local function createEventManager()
    return {
        RegisterForEvent = function(self, eventName, eventCode, callback)
            eventCallbacks[eventCode] = callback
        end,
        UnregisterForEvent = function(self, _eventName)
            return
        end,
    }
end

local eventManager = createEventManager()
EVENT_MANAGER = eventManager

function GetEventManager()
    return eventManager
end

function GetWindowManager()
    return {
        CreateControl = function(_, _, _)
            return {}
        end,
    }
end

function GetString(value)
    return tostring(value)
end

function BETTERUI.CIM.DeferredTask.CreateManager()
    return {
        Cancel = function() end,
        Schedule = function() end,
    }
end

BETTERUI.CIM.SafeExecute = function(_, fn, ...)
    return pcall(fn, ...)
end
function BETTERUI.CIM.UserNotify(_, _message)
end

BETTERUI.CIM.SetTooltipWidth = function(_) end
BETTERUI.CIM.WindowManager = {
    CleanupPanel = function() end,
}

local currentInteractionType
function GetInteractionType()
    return currentInteractionType
end

local nativeStableModeActive = false
function IsNativeStableModeActive()
    return nativeStableModeActive
end

-- Event constants consumed by Vendor.EventBridge registration.
EVENT_STABLE_INTERACT_START = 10
EVENT_STABLE_INTERACT_END = 11
EVENT_OPEN_STORE = 12
EVENT_OPEN_FENCE = 13
EVENT_CLOSE_STORE = 14
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 15
EVENT_INVENTORY_FULL_UPDATE = 16
EVENT_SELL_RECEIPT = 17
EVENT_BUY_RECEIPT = 18
EVENT_BUYBACK_RECEIPT = 19
EVENT_ITEM_REPAIR_ALREADY_APPLIED_CONFIRMATION = 20
EVENT_ITEM_LAUNDER_RESULT = 21
EVENT_JUSTICE_FENCE_UPDATE = 22
EVENT_MONEY_UPDATE = 23
EVENT_CURRENCY_UPDATE = 24
EVENT_MOUNT_INFO_UPDATED = 25

INTERACTION_VENDOR = "Vendor"
INTERACTION_STABLE = "Stable"

STORE_WINDOW_GAMEPAD = {
    activeComponents = {},
    _currentList = {},
    headerFocus = {},
}

local nativeBridgeLog = {}
local function clearNativeBridgeLog()
    nativeBridgeLog = {
        alias = 0,
        takeOver = 0,
        restore = 0,
        ensure = {},
        resolved = 0,
        applied = {},
        scheduled = {},
        cleanupCalled = false,
    }
end
clearNativeBridgeLog()

local bootstrapRuntimeCalls = {
    components = 0,
    list = 0,
    search = 0,
    interactive = 0,
    scene = 0,
    sceneLifecycle = 0,
}

local function makeVendorInstance()
    return {
        _vendorCloseCleanupApplied = false,
        currentMode = BETTERUI.Vendor.MODE.SELL,
        releaseInputCalls = 0,
        releaseDirectionalCalls = 0,
        forceReleaseCalls = 0,
        showFooter = false,
        savedPositions = 0,
        keybindRefreshes = 0,
        title = nil,
        releaseNativeInputOwnershipCalls = 0,
        closeCleanupCalls = 0,
        scene = {
            AddFragment = function() end,
            AddFragmentGroup = function() end,
            SetHideOnSceneHidden = function() end,
        },
        control = {},
        list = {
            selectedData = nil,
            GetTargetData = function(self)
                return self.selectedData
            end,
        },
        SetTitle = function(self, title)
            self.title = title
        end,
        SetupList = function(self, template, rowSetup)
            self.template = template
            self.rowSetup = rowSetup
        end,
        AddTemplate = function(self, template, rowSetup)
            self.secondaryTemplate = template
            self.secondaryRowSetup = rowSetup
        end,
        InitializeCategoryHeader = function(self)
            self.categoryHeaderInitialized = true
        end,
        InitializeScrollIndicator = function(self)
            self.scrollIndicatorInitialized = true
        end,
        AddSearch = function(self, _descriptor, _callback)
            self.addedSearch = true
        end,
        PositionSearchControl = function(self)
            self.searchPositioned = true
        end,
        InitVendorFooter = function(self)
            self.vendorFooter = true
        end,
        IsSceneShowing = function(self)
            return true
        end,
        ApplyNativeStoreMode = function(self, mode)
            self.appliedNativeMode = mode
        end,
        RefreshList = function(self)
            self.refreshListCount = (self.refreshListCount or 0) + 1
        end,
        InitializeScrollIndicator = function(self)
            self.scrollIndicatorInitialized = true
        end,
        EnsureHeaderKeybindsActive = function(self)
        end,
        EnsureColumnHeadersVisible = function(self)
        end,
        OnItemSelectedChange = function(self)
        end,
        UpdateScrollIndicator = function(self)
            self.scrollIndicatorUpdated = (self.scrollIndicatorUpdated or 0) + 1
        end,
        RefreshVendorFooter = function(self)
            self.refreshFooterCount = (self.refreshFooterCount or 0) + 1
        end,
        GetCurrentMode = function(self)
            return self.currentMode
        end,
        SetMode = function(self, mode)
            self.currentMode = mode
            self.modeSetCalls = self.modeSetCalls or {}
            table.insert(self.modeSetCalls, mode)
        end,
        SaveListPosition = function(self)
            self.savedPositions = self.savedPositions + 1
        end,
        DisableStablePreviewMode = function(self)
            self.stablePreviewDisabled = true
        end,
        ForceReleaseDirectionalInput = function(self)
            self.forceReleaseCalls = self.forceReleaseCalls + 1
        end,
        ReleaseNativeStoreInputOwnership = function(self)
            self.releaseNativeInputOwnershipCalls = self.releaseNativeInputOwnershipCalls + 1
        end,
        DeactivateHeaderKeybinds = function(self)
        end,
        DeactivateListInput = function(self)
        end,
    }
end

local vendorInstance = makeVendorInstance()

BETTERUI.Vendor.Class = {
    New = function()
        return vendorInstance
    end,
}

-- Minimal bootstrap collaborator surface to keep Init() in a controlled headless path.
BETTERUI.Vendor.BootstrapRuntime = {
    InitializeList = function(_, deps)
        bootstrapRuntimeCalls.list = bootstrapRuntimeCalls.list + 1
        bootstrapRuntimeCalls.lastListDeps = deps
    end,
    InitializeSearch = function(_, deps)
        bootstrapRuntimeCalls.search = bootstrapRuntimeCalls.search + 1
        bootstrapRuntimeCalls.lastSearchDeps = deps
    end,
    InitializeInteractiveSurfaces = function(_, deps)
        bootstrapRuntimeCalls.interactive = bootstrapRuntimeCalls.interactive + 1
        bootstrapRuntimeCalls.lastInteractiveDeps = deps
    end,
    CreateScene = function(_, deps)
        bootstrapRuntimeCalls.scene = bootstrapRuntimeCalls.scene + 1
        bootstrapRuntimeCalls.lastSceneDeps = deps
    end,
    RegisterSceneLifecycle = function(_, deps)
        bootstrapRuntimeCalls.sceneLifecycle = bootstrapRuntimeCalls.sceneLifecycle + 1
        bootstrapRuntimeCalls.lastSceneLifecycleDeps = deps
    end,
}

BETTERUI.Vendor.ComponentCatalog = {
    Register = function()
        bootstrapRuntimeCalls.components = bootstrapRuntimeCalls.components + 1
    end,
}

BETTERUI.Vendor.NativeStoreBridge = {
    TakeOverScene = function()
        nativeBridgeLog.takeOver = nativeBridgeLog.takeOver + 1
    end,
    AliasSceneToBetterUI = function(_, instance)
        nativeBridgeLog.alias = nativeBridgeLog.alias + 1
        nativeBridgeLog.lastAliasInstance = instance
    end,
    RestoreSceneAlias = function()
        nativeBridgeLog.restore = nativeBridgeLog.restore + 1
    end,
    EnsureComponents = function(context)
        table.insert(nativeBridgeLog.ensure, context)
    end,
    ResolveTargetMode = function()
        nativeBridgeLog.resolved = nativeBridgeLog.resolved + 1
        return BETTERUI.Vendor.MODE.SELL
    end,
    ApplyResolvedMode = function(mode, refreshList)
        table.insert(nativeBridgeLog.applied, {
            mode = mode,
            refreshList = refreshList,
        })
    end,
    ScheduleOpenStoreSync = function(mode, delayMs)
        table.insert(nativeBridgeLog.scheduled, {
            mode = mode,
            delayMs = delayMs,
        })
    end,
}

BETTERUI.CIM.SceneLifecycle = {
    Register = function() end,
}

BETTERUI.CIM.Runner = {
    RegisterSceneLifecycle = function() end,
}

-- Use real interaction runtime so open/fence/close flows are exercised end-to-end.
dofile("Modules/Vendor/Core/VendorSafeExecute.lua")
dofile("Modules/Vendor/Core/Lifecycle/VendorEventBridge.lua")
dofile("Modules/Vendor/Core/Lifecycle/VendorInteractionRuntime.lua")
dofile("Modules/Vendor/Core/VendorKeybinds.lua")
dofile("Modules/Vendor/Vendor.lua")

-- Vendor init-time collaborators required after loading root table.
function BETTERUI.CIM.ApplyModuleSharedSettingsStatics(_, _)
end

-- Rebuild vendor state for each scenario.
local function resetHarness()
    clearNativeBridgeLog()
    bootstrapRuntimeCalls.components = 0
    bootstrapRuntimeCalls.list = 0
    bootstrapRuntimeCalls.search = 0
    bootstrapRuntimeCalls.interactive = 0
    bootstrapRuntimeCalls.scene = 0
    bootstrapRuntimeCalls.sceneLifecycle = 0

    vendorInstance.currentMode = BETTERUI.Vendor.MODE.SELL
    vendorInstance._vendorCloseCleanupApplied = false
    vendorInstance.releaseNativeInputOwnershipCalls = 0
    vendorInstance.releaseInputCalls = 0
    vendorInstance.forceReleaseCalls = 0
    vendorInstance.refreshListCount = 0
    vendorInstance.scrollIndicatorUpdated = 0
    vendorInstance.modeSetCalls = {}

    if STORE_WINDOW_GAMEPAD then
        STORE_WINDOW_GAMEPAD.activeComponents = {
            {}
        }
        STORE_WINDOW_GAMEPAD.OnHide = function()
            STORE_WINDOW_GAMEPAD.onHideCalls = (STORE_WINDOW_GAMEPAD.onHideCalls or 0) + 1
        end
    end

    if BETTERUI.CIM and BETTERUI.CIM.DeferredTask and BETTERUI.CIM.DeferredTask.GetSharedManager then
        BETTERUI.CIM.Tasks = nil
    end
    BETTERUI.Vendor.Tasks = {
        Cancel = function() end,
        Schedule = function() end,
        CancelAll = function() end,
    }
    BETTERUI.Vendor.initialized = nil
end

-- Ensure a clean vendor instance and run Init() once for callback registration.
resetHarness()
BETTERUI.Vendor.Init()

assert_true(type(eventCallbacks[EVENT_OPEN_STORE]) == "function", "root vendor wires store-open lifecycle callback")
assert_true(type(eventCallbacks[EVENT_OPEN_FENCE]) == "function", "root vendor wires fence-open lifecycle callback")
assert_true(type(eventCallbacks[EVENT_CLOSE_STORE]) == "function", "root vendor wires close-store lifecycle callback")
assert_true(type(eventCallbacks[EVENT_STABLE_INTERACT_START]) == "function", "root vendor wires stable-start callback")
assert_true(type(eventCallbacks[EVENT_STABLE_INTERACT_END]) == "function", "root vendor wires stable-end callback")
assert_true(type(eventCallbacks[EVENT_MOUNT_INFO_UPDATED]) == "function", "root vendor wires stable mount-info refresh callback")
assert_eq(1, nativeBridgeLog.takeOver, "vendor init takes over the native store scene once")
assert_eq(1, nativeBridgeLog.alias, "vendor init aliases the native store scene to the BetterUI runtime")
assert_eq(1, bootstrapRuntimeCalls.list, "vendor init delegates list bootstrap through the bootstrap runtime")
assert_eq(1, bootstrapRuntimeCalls.sceneLifecycle, "vendor init delegates scene lifecycle registration through the bootstrap runtime")

print("[Vendor root lifecycle runtime]")

do
    resetHarness()
    eventCallbacks[EVENT_STABLE_INTERACT_START]()
    assert_true(BETTERUI.Vendor.IsStableInteraction(), "stable-start callback mutates stable interaction state")
    eventCallbacks[EVENT_STABLE_INTERACT_END]()
    assert_true(not BETTERUI.Vendor.IsStableInteraction(), "stable-end callback clears stable interaction state")
end

do
    resetHarness()
    currentInteractionType = INTERACTION_VENDOR
    nativeStableModeActive = false

    eventCallbacks[EVENT_OPEN_STORE]()
    assert_eq(1, nativeBridgeLog.alias, "open-store event re-aliases the native store scene through Vendor root orchestration")
    assert_true(vendorInstance.releaseNativeInputOwnershipCalls > 0, "store-open root path releases native input ownership")
    assert_eq(false, BETTERUI.Vendor.IsFenceInteraction(), "open-store event leaves fence state false")
    assert_eq(false, BETTERUI.Vendor.IsStableInteraction(), "open-store event leaves stable state false for vendor interactions")
    assert_eq(1, #nativeBridgeLog.ensure, "open-store root path rebuilds native store components")
    assert_eq(1, nativeBridgeLog.resolved, "open-store root path resolves target mode")
    assert_eq(BETTERUI.Vendor.MODE.SELL, nativeBridgeLog.applied[1].mode, "open-store root path applies resolved target mode")
    assert_eq(120, nativeBridgeLog.scheduled[1].delayMs, "open-store root path schedules store-sync delay")
    assert_eq(EVENT_OPEN_STORE, 12, "guard: open store event id is bound to expected channel")
end

do
    resetHarness()
    currentInteractionType = INTERACTION_STABLE

    eventCallbacks[EVENT_OPEN_STORE]()
    assert_true(BETTERUI.Vendor.IsStableInteraction(), "open-store event records stable interaction state")
    assert_eq(false, BETTERUI.Vendor.IsFenceInteraction(), "stable interaction open does not enter fence mode")
end

do
    resetHarness()
    vendorInstance.currentMode = BETTERUI.Vendor.MODE.SELL

    eventCallbacks[EVENT_OPEN_FENCE](nil, true, false)
    assert_true(BETTERUI.Vendor.IsFenceInteraction(), "open-fence event marks active fence state")
    assert_eq(BETTERUI.Vendor.MODE.FENCE_SELL, vendorInstance.currentMode, "open-fence event sets sell fence mode when enabled")
    assert_true(vendorInstance.releaseNativeInputOwnershipCalls > 0, "fence-open root path releases native input ownership")

    eventCallbacks[EVENT_CLOSE_STORE]()
    assert_true(not BETTERUI.Vendor.IsFenceInteraction(), "close-store event clears fence state")
    assert_true(not BETTERUI.Vendor.IsStableInteraction(), "close-store event clears stable state")
    assert_eq(true, vendorInstance._vendorCloseCleanupApplied, "close-store event runs runtime close cleanup")
    assert_eq(2, nativeBridgeLog.alias, "close-store event re-aliases the BetterUI scene after cleanup")
    assert_eq(0, nativeBridgeLog.restore, "close-store fallback cleanup does not restore the native scene alias")
    assert_eq(0, #((STORE_WINDOW_GAMEPAD or {}).activeComponents or {}), "close-store event clears native active components in fallback close path")
end

print(string.format("test_vendor_root_lifecycle_runtime.lua: %d passed", passed))
if failed > 0 then
    print(string.format("test_vendor_root_lifecycle_runtime.lua: %d failed", failed))
    os.exit(1)
end
