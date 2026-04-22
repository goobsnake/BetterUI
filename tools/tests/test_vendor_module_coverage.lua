--[[
File: tools/tests/test_vendor_module_coverage.lua
Purpose: Smoke coverage for the live Vendor modules still flagged by desloppify.
]]

if false then
    dofile("Modules/Vendor/Module.lua")
    dofile("Modules/Vendor/Core/VendorModePolicy.lua")
    dofile("Modules/Vendor/Core/VendorSelectionRuntime.lua")
    dofile("Modules/Vendor/Core/VendorSafeExecute.lua")
    dofile("Modules/Vendor/Core/VendorNativeStoreBridge.lua")
    dofile("Modules/Vendor/Core/VendorBootstrapRuntime.lua")
    dofile("Modules/Vendor/Core/VendorComponentCatalog.lua")
    dofile("Modules/Vendor/Core/VendorEventBridge.lua")
    dofile("Modules/Vendor/Core/VendorInteractionRuntime.lua")
    dofile("Modules/Vendor/Core/VendorBatchRuntime.lua")
    dofile("Modules/Vendor/Core/VendorControllerRuntime.lua")
    dofile("Modules/Vendor/Core/VendorPresentationRuntime.lua")
    dofile("Modules/Vendor/Core/VendorClass.lua")
    dofile("Modules/Vendor/Core/VendorRowSetup.lua")
    dofile("Modules/Vendor/Core/BatchActionCounts.lua")
    dofile("Modules/Vendor/Components/BuyComponent.lua")
    dofile("Modules/Vendor/Components/BuybackComponent.lua")
    dofile("Modules/Vendor/Components/FenceLaunderComponent.lua")
    dofile("Modules/Vendor/Components/FenceSellComponent.lua")
    dofile("Modules/Vendor/Components/RepairComponent.lua")
    dofile("Modules/Vendor/Components/StableTrainingComponent.lua")
    dofile("Modules/Vendor/Components/SellComponent.lua")
    dofile("Modules/Vendor/Components/SellVengeanceComponent.lua")
    dofile("Modules/Vendor/Vendor.lua")
end

local vendorCoverageTargets = {
    "Modules/Vendor/Module.lua",
    "Modules/Vendor/Core/VendorModePolicy.lua",
    "Modules/Vendor/Core/VendorSelectionRuntime.lua",
    "Modules/Vendor/Core/VendorSafeExecute.lua",
    "Modules/Vendor/Core/VendorNativeStoreBridge.lua",
    "Modules/Vendor/Core/VendorBootstrapRuntime.lua",
    "Modules/Vendor/Core/VendorComponentCatalog.lua",
    "Modules/Vendor/Core/VendorEventBridge.lua",
    "Modules/Vendor/Core/VendorInteractionRuntime.lua",
    "Modules/Vendor/Core/VendorBatchRuntime.lua",
    "Modules/Vendor/Core/VendorControllerRuntime.lua",
    "Modules/Vendor/Core/VendorPresentationRuntime.lua",
    "Modules/Vendor/Core/VendorClass.lua",
    "Modules/Vendor/Core/VendorRowSetup.lua",
    "Modules/Vendor/Core/BatchActionCounts.lua",
    "Modules/Vendor/Components/BuyComponent.lua",
    "Modules/Vendor/Components/BuybackComponent.lua",
    "Modules/Vendor/Components/FenceLaunderComponent.lua",
    "Modules/Vendor/Components/FenceSellComponent.lua",
    "Modules/Vendor/Components/RepairComponent.lua",
    "Modules/Vendor/Components/StableTrainingComponent.lua",
    "Modules/Vendor/Components/SellComponent.lua",
    "Modules/Vendor/Components/SellVengeanceComponent.lua",
    "Modules/Vendor/Vendor.lua",
}

local testsPassed = 0
local testsFailed = 0

local function assertTrue(condition, message)
    if condition then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        io.stderr:write("Assertion failed: " .. message .. "\n")
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
end

assertEqual(24, #vendorCoverageTargets, "coverage list stays aligned with the live Vendor manifest-backed runtime surface")

BETTERUI = {
    Vendor = {
        DEFAULTS = {},
    },
    CIM = {
        RegisterModuleAccessors = function() end,
        InitModuleDefaults = function(_, moduleOptions)
            return moduleOptions
        end,
        DeferredTask = {
            Manager = {
                New = function()
                    return {
                        Cancel = function() end,
                        Schedule = function() end,
                    }
                end,
            },
            CreateLazyManagerProxy = function(factory)
                return setmetatable({}, {
                    __index = function(_, key)
                        local manager = factory()
                        local value = manager[key]
                        if type(value) == "function" then
                            return function(_, ...)
                                return value(manager, ...)
                            end
                        end
                        return value
                    end,
                })
            end,
        },
        SafeExecute = function(_, fn, ...)
            return true, fn(...)
        end,
        UserNotify = function() end,
        ApplyModuleSharedSettingsStatics = function() end,
        TryRegisterModulePanel = function() end,
        GenericWindow = {
            New = function(self, ...)
                return setmetatable({ args = { ... } }, { __index = self })
            end,
            Subclass = function(self)
                return setmetatable({}, { __index = self })
            end,
        },
    },
}

ZO_GamepadEntryData = {
    New = function(...)
        return { ... }
    end,
}

local originalGlobalMetatable = getmetatable(_G)
setmetatable(_G, {
    __index = function(_, key)
        if type(key) ~= "string" then
            return nil
        end

        if key:match("^SI_") then
            return key
        end

        if key:match("^ITEMFILTERTYPE_")
            or key:match("^STORE_")
            or key:match("^INTERACTION_")
            or key:match("^BAG_")
            or key:match("^ZO_MODE_")
            or key:match("^SLOT_TYPE_")
        then
            return 0
        end

        return nil
    end,
})

local seenPaths = {}
for _, path in ipairs(vendorCoverageTargets) do
    assertTrue(seenPaths[path] ~= true, "coverage target list keeps unique module paths: " .. path)
    seenPaths[path] = true

    local chunk, loadError = loadfile(path)
    assertTrue(type(chunk) == "function", string.format("module compiles for smoke coverage: %s (%s)", path, tostring(loadError)))
end

dofile("Modules/CIM/Core/Data/ItemTaxonomy.lua")

for _, path in ipairs(vendorCoverageTargets) do
    local ok, loadError = pcall(dofile, path)
    assertTrue(ok, string.format("module loads into the Vendor namespace: %s (%s)", path, tostring(loadError)))
end

assertTrue(type(BETTERUI.Vendor.InitModule) == "function", "module entry point loads")
assertTrue(type(BETTERUI.Vendor.Class) == "table", "vendor class loads")
assertTrue(type(BETTERUI.Vendor.VendorEntrySetup) == "function", "vendor row setup loads")
assertTrue(type(BETTERUI.Vendor.BuyComponent) == "table", "buy component loads")
assertTrue(type(BETTERUI.Vendor.BuybackComponent) == "table", "buyback component loads")
assertTrue(type(BETTERUI.Vendor.FenceLaunderComponent) == "table", "fence launder component loads")
assertTrue(type(BETTERUI.Vendor.FenceSellComponent) == "table", "fence sell component loads")
assertTrue(type(BETTERUI.Vendor.RepairComponent) == "table", "repair component loads")
assertTrue(type(BETTERUI.Vendor.StableTrainingComponent) == "table", "stable training component loads")
assertTrue(type(BETTERUI.Vendor.SellComponent) == "table", "sell component loads")
assertTrue(type(BETTERUI.Vendor.SellVengeanceComponent) == "table", "sell vengeance component loads")
assertTrue(type(BETTERUI.Vendor.BootstrapRuntime) == "table", "vendor bootstrap runtime loads")
assertTrue(type(BETTERUI.Vendor.ControllerRuntime) == "table", "vendor controller runtime loads")
assertTrue(type(BETTERUI.Vendor.InteractionRuntime) == "table", "vendor interaction runtime loads")
assertTrue(type(BETTERUI.Vendor.PresentationRuntime) == "table", "vendor presentation runtime loads")
assertEqual("vendor_sell", BETTERUI.Vendor.ResolveActionId("SELL"), "vendor action resolver exposes SELL")
assertEqual("vendor_sell_junk", BETTERUI.Vendor.ResolveActionId("SELL_JUNK"), "vendor action resolver exposes SELL_JUNK")
assertEqual("vendor_sell_vengeance", BETTERUI.Vendor.ResolveActionId("SELL_VENGEANCE"), "vendor action resolver exposes SELL_VENGEANCE")
assertEqual("fence_sell", BETTERUI.Vendor.ResolveActionId("FENCE_SELL"), "vendor action resolver exposes FENCE_SELL")
assertEqual("fence_launder", BETTERUI.Vendor.ResolveActionId("FENCE_LAUNDER"), "vendor action resolver exposes FENCE_LAUNDER")
assertEqual(nil, BETTERUI.Vendor.ResolveActionId("UNKNOWN"), "vendor action resolver rejects unknown keys")

do
    local originalProtectionPolicy = BETTERUI.CIM.ProtectionPolicy
    local observed = {}
    BETTERUI.CIM.ProtectionPolicy = {
        CanVendorAction = function(actionType, bagId, slotIndex, context)
            observed.actionType = actionType
            observed.bagId = bagId
            observed.slotIndex = slotIndex
            observed.context = context
            return false, "policy_denied"
        end,
    }

    local vendorInstance = {
        CanAfford = function(_, cost)
            observed.canAffordCost = cost
            return cost == 123
        end,
    }
    local allowed, reason = BETTERUI.Vendor.AuthorizeInventoryAction("vendor_sell", 1, 4, vendorInstance)
    assertTrue(allowed == false, "vendor authorization seam preserves explicit policy deny results")
    assertEqual("policy_denied", reason, "vendor authorization seam preserves explicit policy deny reasons")
    assertEqual("vendor_sell", observed.actionType, "vendor authorization seam forwards action type to policy")
    assertEqual(1, observed.bagId, "vendor authorization seam forwards bag id to policy")
    assertEqual(4, observed.slotIndex, "vendor authorization seam forwards slot index to policy")
    assertTrue(type(observed.context) == "table" and type(observed.context.canAfford) == "function",
        "vendor authorization seam forwards affordability context to policy")
    assertTrue(observed.context.canAfford(123) == true and observed.canAffordCost == 123,
        "vendor authorization seam affordability context delegates to vendor instance")

    BETTERUI.CIM.ProtectionPolicy.CanVendorAction = nil
    local missingMethodAccepted, missingMethodError = pcall(function()
        BETTERUI.Vendor.AuthorizeInventoryAction("vendor_sell", 1, 4, vendorInstance)
    end)
    assertTrue(missingMethodAccepted == false,
        "vendor authorization seam requires ProtectionPolicy.CanVendorAction instead of fail-open fallbacks")
    assertTrue(type(missingMethodError) == "string"
            and string.find(missingMethodError, "ProtectionPolicy.CanVendorAction must load", 1, true) ~= nil,
        "vendor authorization seam raises an explicit missing CanVendorAction contract error")

    BETTERUI.CIM.ProtectionPolicy = nil
    local missingPolicyAccepted, missingPolicyError = pcall(function()
        BETTERUI.Vendor.AuthorizeInventoryAction("vendor_sell", 1, 4, vendorInstance)
    end)
    assertTrue(missingPolicyAccepted == false,
        "vendor authorization seam requires ProtectionPolicy instead of fail-open fallbacks")
    assertTrue(type(missingPolicyError) == "string"
            and string.find(missingPolicyError, "CIM.ProtectionPolicy must load before Vendor.AuthorizeInventoryAction", 1, true) ~= nil,
        "vendor authorization seam raises an explicit missing policy contract error")

    BETTERUI.CIM.ProtectionPolicy = originalProtectionPolicy
end

do
    local modePolicy = BETTERUI.Vendor.ModePolicy
    local mode = BETTERUI.Vendor.MODE and BETTERUI.Vendor.MODE.SELL or 2
    local readOnlyOwner = {
        modeCategories = {
            [mode] = {
                { key = "all" },
            },
        },
        categoryIndexByMode = {
            [mode] = 2,
        },
    }

    local selectedIndex = modePolicy.GetSelectedCategoryIndex(readOnlyOwner, mode)
    assertEqual(1, selectedIndex, "vendor selected-category getter clamps to a valid index")
    assertTrue(readOnlyOwner._modeCategoryState == nil,
        "vendor selected-category getter remains read-only and does not initialize category state")
    assertEqual(2, readOnlyOwner.categoryIndexByMode[mode],
        "vendor selected-category getter does not mutate stored index state")

    local statelessOwner = {}
    assertEqual(1, modePolicy.GetSelectedCategoryIndex(statelessOwner, mode),
        "vendor selected-category getter resolves defaults without mutating stateless owners")
    assertTrue(statelessOwner._modeCategoryState == nil and statelessOwner.categoryIndexByMode == nil,
        "vendor selected-category getter keeps stateless owner tables untouched")
end

do
    local originalBatchRuntime = BETTERUI.Vendor.BatchRuntime
    local observed = {
        completed = 0,
        throttledRequests = {},
    }
    local sampleItem = { id = "sample-item" }
    local sampleItems = { sampleItem }
    local sampleOptions = { server = { serverBound = true } }
    local resolvedOptions = { server = { serverBound = false } }

    BETTERUI.Vendor.BatchRuntime = {
        ExecuteBatchAction = function(mode, itemData)
            observed.actionMode = mode
            observed.actionItem = itemData
            return { status = "handled" }
        end,
        ExecuteBatchThrottled = function(request)
            observed.throttledRequest = request
            observed.throttledRequests[#observed.throttledRequests + 1] = request
            observed.throttledMode = request.mode
            observed.throttledItems = request.items
            observed.throttledOptions = request.options
            observed.legacyBatchOptions = request.batchOptions
            if request.onComplete then
                request.onComplete()
            end
        end,
        RequestBatchAbort = function()
            observed.abortRequested = true
        end,
        GetDefaultBatchOptions = function()
            observed.defaultOptionsRequested = true
            return sampleOptions
        end,
        _internals = {
            ResolveBatchOptions = function(options)
                observed.resolveOptionsInput = options
                return resolvedOptions
            end,
        },
    }

    local stepResult = BETTERUI.Vendor._internals.ExecuteBatchAction(BETTERUI.Vendor.MODE.SELL, sampleItem)
    BETTERUI.Vendor.ExecuteBatchThrottled({
        mode = BETTERUI.Vendor.MODE.FENCE_SELL,
        items = sampleItems,
        onComplete = function()
            observed.completed = observed.completed + 1
        end,
        options = sampleOptions,
    })
    BETTERUI.Vendor.ExecuteBatchThrottled({
        mode = BETTERUI.Vendor.MODE.BUYBACK,
        items = sampleItems,
        onComplete = function()
            observed.completed = observed.completed + 1
        end,
        options = sampleOptions,
    })
    BETTERUI.Vendor.RequestBatchAbort()
    local observedDefaultOptions = BETTERUI.Vendor.GetDefaultBatchOptions()
    local observedResolvedOptions = BETTERUI.Vendor.ResolveBatchOptions(sampleOptions)

    assertEqual(BETTERUI.Vendor.MODE.SELL, observed.actionMode, "vendor internal batch-action seam delegates the requested mode")
    assertTrue(observed.actionItem == sampleItem, "vendor internal batch-action seam forwards the selected item payload")
    assertEqual("handled", stepResult.status, "vendor internal batch-action seam preserves explicit step-result contract return values")
    assertEqual(BETTERUI.Vendor.MODE.FENCE_SELL, observed.throttledRequests[1].mode, "vendor throttled facade accepts named batch requests")
    assertTrue(observed.throttledItems == sampleItems, "vendor throttled facade forwards the selected item list")
    assertTrue(observed.throttledOptions == sampleOptions, "vendor throttled facade forwards explicit batch options")
    assertTrue(observed.legacyBatchOptions == nil, "vendor throttled facade does not publish legacy batchOptions")
    assertEqual(BETTERUI.Vendor.MODE.BUYBACK, observed.throttledRequests[2].mode, "vendor throttled facade accepts repeated named batch requests")
    assertEqual(2, observed.completed, "vendor throttled facade preserves completion callbacks for named requests")
    assertTrue(observed.abortRequested == true, "vendor abort facade delegates to the batch runtime collaborator")
    assertTrue(observed.defaultOptionsRequested == true, "vendor batch-options facade delegates default option retrieval")
    assertTrue(observed.resolveOptionsInput == sampleOptions, "vendor batch-options facade delegates option normalization input")
    assertTrue(observedDefaultOptions == sampleOptions, "vendor default batch-options facade preserves collaborator return value")
    assertTrue(observedResolvedOptions == resolvedOptions, "vendor resolved batch-options facade preserves collaborator return value")
    local acceptedLegacyPublicOptions, _ = pcall(function()
        BETTERUI.Vendor.ResolveBatchOptions({
            serverBound = false,
        })
    end)
    assertTrue(acceptedLegacyPublicOptions == false,
        "vendor batch-options facade rejects legacy flat option keys on the public contract")

    BETTERUI.Vendor.BatchRuntime = originalBatchRuntime
end

do
    local originalDebug = BETTERUI.CIM.Debug
    local debugLogs = {}
    BETTERUI.CIM.Debug = {
        FLAGS = {
            SCENE_TRANSITIONS = true,
        },
        IsEnabled = function()
            return true
        end,
        Log = function(message, category)
            debugLogs[#debugLogs + 1] = {
                message = message,
                category = category,
            }
        end,
    }

    BETTERUI.Vendor.LogDebug("SCENE_TRANSITIONS", "VendorScene", "canonical")
    BETTERUI.Vendor.LogDebug("VendorScene", "SCENE_TRANSITIONS", "reversed")

    assertEqual(2, #debugLogs, "vendor debug helper supports canonical and reversed helper contracts")
    assertEqual("canonical", debugLogs[1].message, "vendor debug helper logs canonical messages")
    assertEqual("VendorScene", debugLogs[1].category, "vendor debug helper logs canonical categories")
    assertEqual("reversed", debugLogs[2].message, "vendor debug helper logs reversed-contract messages")
    assertEqual("VendorScene", debugLogs[2].category, "vendor debug helper normalizes reversed contracts")

    BETTERUI.CIM.Debug = originalDebug
end

do
    local originalSafeExecute = BETTERUI.CIM.SafeExecute
    local originalUserNotify = BETTERUI.CIM.UserNotify
    BETTERUI.CIM.SafeExecute = nil
    BETTERUI.CIM.UserNotify = nil

    local okWithoutNotifier, errWithoutNotifier = BETTERUI.Vendor.ExecuteSafely("VendorSafeExecute:withoutNotifier", function()
        error("original vendor fallback error")
    end)
    assertTrue(okWithoutNotifier == false, "vendor safe execute fallback returns failure when notifier is absent")
    assertTrue(type(errWithoutNotifier) == "string" and string.find(errWithoutNotifier, "original vendor fallback error", 1, true) ~= nil,
        "vendor safe execute fallback preserves the original error when notifier is absent")

    BETTERUI.CIM.UserNotify = function()
        error("notifier failure should not replace original")
    end
    local okNotifierThrows, errNotifierThrows = BETTERUI.Vendor.ExecuteSafely("VendorSafeExecute:notifierThrows", function()
        error("original vendor fallback error 2")
    end)
    assertTrue(okNotifierThrows == false, "vendor safe execute fallback returns failure when notifier throws")
    assertTrue(type(errNotifierThrows) == "string" and string.find(errNotifierThrows, "original vendor fallback error 2", 1, true) ~= nil,
        "vendor safe execute fallback preserves the original error when notifier throws")

    local okMultiReturn, firstValue, secondValue, thirdValue = BETTERUI.Vendor.ExecuteSafely("VendorSafeExecute:multiReturn",
        function()
            return "a", "b", "c"
        end)
    assertTrue(okMultiReturn == true, "vendor safe execute fallback succeeds for successful calls")
    assertEqual("a", firstValue, "vendor safe execute fallback preserves first return value")
    assertEqual("b", secondValue, "vendor safe execute fallback preserves second return value")
    assertEqual("c", thirdValue, "vendor safe execute fallback preserves third return value")

    BETTERUI.CIM.SafeExecute = originalSafeExecute
    BETTERUI.CIM.UserNotify = originalUserNotify
end

do
    local originalSafeExecute = BETTERUI.CIM.SafeExecute
    local originalUserNotify = BETTERUI.CIM.UserNotify
    local originalDirectionalInput = _G.DIRECTIONAL_INPUT
    local originalStoreWindowGamepad = _G.STORE_WINDOW_GAMEPAD
    local originalCanStoreRepair = _G.CanStoreRepair
    local originalModes = {
        ZO_MODE_STORE_BUY = _G.ZO_MODE_STORE_BUY,
        ZO_MODE_STORE_SELL = _G.ZO_MODE_STORE_SELL,
        ZO_MODE_STORE_SELL_VENGEANCE = _G.ZO_MODE_STORE_SELL_VENGEANCE,
        ZO_MODE_STORE_BUY_BACK = _G.ZO_MODE_STORE_BUY_BACK,
        ZO_MODE_STORE_REPAIR = _G.ZO_MODE_STORE_REPAIR,
        ZO_MODE_STORE_STABLE = _G.ZO_MODE_STORE_STABLE,
    }
    local originalIsStableInteraction = BETTERUI.Vendor.IsStableInteraction
    local originalIsFenceInteraction = BETTERUI.Vendor.IsFenceInteraction
    local originalHasVendorBuyInventory = BETTERUI.Vendor.HasVendorBuyInventory
    local originalIsSellVengeanceModeAvailable = BETTERUI.Vendor.IsSellVengeanceModeAvailable

    BETTERUI.CIM.SafeExecute = nil
    BETTERUI.CIM.UserNotify = function()
    end
    _G.CanStoreRepair = function()
        return true
    end

    _G.ZO_MODE_STORE_BUY = 11
    _G.ZO_MODE_STORE_SELL = 22
    _G.ZO_MODE_STORE_SELL_VENGEANCE = 33
    _G.ZO_MODE_STORE_BUY_BACK = 44
    _G.ZO_MODE_STORE_REPAIR = 55
    _G.ZO_MODE_STORE_STABLE = 66

    local function buildDirectionalInput()
        local directionalInput = {
            inputObjects = {},
        }
        function directionalInput:IsListening(obj)
            for _, entry in ipairs(self.inputObjects) do
                if entry == obj then
                    return true
                end
            end
            return false
        end
        function directionalInput:Deactivate(obj)
            for index = #self.inputObjects, 1, -1 do
                if self.inputObjects[index] == obj then
                    table.remove(self.inputObjects, index)
                end
            end
        end
        return directionalInput
    end

    _G.DIRECTIONAL_INPUT = buildDirectionalInput()
    local storeManager = {
        sceneName = "gamepad_store",
        activeComponents = {
            {
                GetStoreMode = function()
                    return ZO_MODE_STORE_STABLE
                end,
            },
            {
                GetStoreMode = function()
                    return ZO_MODE_STORE_SELL
                end,
            },
        },
        components = {
            [ZO_MODE_STORE_SELL] = {},
            [ZO_MODE_STORE_BUY_BACK] = {},
            [ZO_MODE_STORE_REPAIR] = {},
        },
    }
    local setActiveCalls = 0
    local initializeCalls = 0
    storeManager.SetActiveComponents = function()
        setActiveCalls = setActiveCalls + 1
        error("simulated set active components failure")
    end
    storeManager.InitializeStore = function()
        initializeCalls = initializeCalls + 1
    end
    _G.STORE_WINDOW_GAMEPAD = storeManager
    table.insert(_G.DIRECTIONAL_INPUT.inputObjects, storeManager)

    BETTERUI.Vendor._sessionHasBuyMode = false
    BETTERUI.Vendor.IsStableInteraction = function()
        return false
    end
    BETTERUI.Vendor.IsFenceInteraction = function()
        return false
    end
    BETTERUI.Vendor.HasVendorBuyInventory = function()
        return false
    end
    BETTERUI.Vendor.IsSellVengeanceModeAvailable = function()
        return false
    end

    local ensureOk, ensureErr = pcall(function()
        BETTERUI.Vendor.NativeStoreBridge.EnsureComponents("test_guard_failure")
    end)

    assertTrue(ensureOk == true, string.format(
        "native-store rebuild guard failure does not escape EnsureComponents (error=%s)", tostring(ensureErr)))
    assertEqual(1, setActiveCalls, "native-store rebuild attempts SetActiveComponents once")
    assertEqual(0, initializeCalls, "native-store rebuild aborts initialization after guarded SetActiveComponents failure")
    assertTrue(_G.DIRECTIONAL_INPUT:IsListening(storeManager),
        "native-store rebuild guard failure skips directional-input sweep")

    BETTERUI.CIM.SafeExecute = originalSafeExecute
    BETTERUI.CIM.UserNotify = originalUserNotify
    _G.DIRECTIONAL_INPUT = originalDirectionalInput
    _G.STORE_WINDOW_GAMEPAD = originalStoreWindowGamepad
    _G.CanStoreRepair = originalCanStoreRepair
    _G.ZO_MODE_STORE_BUY = originalModes.ZO_MODE_STORE_BUY
    _G.ZO_MODE_STORE_SELL = originalModes.ZO_MODE_STORE_SELL
    _G.ZO_MODE_STORE_SELL_VENGEANCE = originalModes.ZO_MODE_STORE_SELL_VENGEANCE
    _G.ZO_MODE_STORE_BUY_BACK = originalModes.ZO_MODE_STORE_BUY_BACK
    _G.ZO_MODE_STORE_REPAIR = originalModes.ZO_MODE_STORE_REPAIR
    _G.ZO_MODE_STORE_STABLE = originalModes.ZO_MODE_STORE_STABLE
    BETTERUI.Vendor.IsStableInteraction = originalIsStableInteraction
    BETTERUI.Vendor.IsFenceInteraction = originalIsFenceInteraction
    BETTERUI.Vendor.HasVendorBuyInventory = originalHasVendorBuyInventory
    BETTERUI.Vendor.IsSellVengeanceModeAvailable = originalIsSellVengeanceModeAvailable
end

setmetatable(_G, originalGlobalMetatable)

if testsFailed > 0 then
    error(string.format("test_vendor_module_coverage.lua failed with %d failure(s)", testsFailed))
end

print(string.format("test_vendor_module_coverage.lua: %d passed", testsPassed))
