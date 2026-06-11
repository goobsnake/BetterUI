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

print("test_vendor_native_store_rebuild_source")

ZO_MODE_STORE_BUY = 1
ZO_MODE_STORE_SELL = 2
ZO_MODE_STORE_REPAIR = 3
ZO_MODE_STORE_BUY_BACK = 4
ZO_MODE_STORE_STABLE = 5
ZO_MODE_STORE_SELL_VENGEANCE = 6

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
        LogDebug = function()
        end,
    },
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

    local manager = {
        sceneName = "gamepad_store",
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
    end
end

dofile("Modules/Vendor/Core/Bridge/VendorNativeStoreBridge.lua")
local NativeStoreBridge = BETTERUI.Vendor.NativeStoreBridge

do
    local storeManager, setActiveCalls, setModeCalls, getInitializeStoreCalls, getTabBarDeactivated = BuildStoreManager()
    STORE_WINDOW_GAMEPAD = storeManager

    NativeStoreBridge.EnsureComponents("test-search")

    assert_eq(storeManager.sceneName, "betterui_native_store_blocked", "ensure components blocks native scene while rebuilding")
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

print("  OK")
