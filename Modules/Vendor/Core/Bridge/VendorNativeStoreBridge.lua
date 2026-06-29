--[[
File: Modules/Vendor/Core/Bridge/VendorNativeStoreBridge.lua
Purpose: Own native-store reconciliation, component rebuild policy, and scene
         takeover so Vendor.lua can stay focused on scene orchestration.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.NativeStoreBridge = Vendor.NativeStoreBridge or {}
local NativeStoreBridge = Vendor.NativeStoreBridge
local CLOSE_STORE_BEFORE_SWEEP_CONTEXT = "OnCloseStore:beforeSweep"
local CLOSE_STORE_AFTER_SWEEP_CONTEXT = "OnCloseStore:afterSweep"
local CLOSE_STORE_NATIVE_ON_HIDE_CONTEXT = "Vendor.OnCloseStore:NativeOnHide"
local updateDirectionalInputHookedManagers = setmetatable({}, { __mode = "k" })

local function LogVendorDebug(flagName, category, message)
    if Vendor.LogDebug then
        Vendor.LogDebug(flagName, category, message)
    end
end

local function TraceNativeStoreBridge(event, phase, data)
    local L = BETTERUI and BETTERUI.Log or nil
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Vendor"
    data.scene = rawget(_G, "BETTERUI_VENDOR_SCENE_NAME") or "BETTERUI_VENDOR"
    data.feature = data.feature or "vendor-native-store"
    data.fn = data.fn or "Vendor.NativeStoreBridge"
    L.TraceEvent(L.CATEGORY.LIFECYCLE, event, phase, data)
end

local function GetVendorExecuteSafely()
    local executor = Vendor.ExecuteSafely
    assert(type(executor) == "function", "Vendor safe execute helper must load before NativeStoreBridge use")
    return executor
end

local function IsDirectionalInputListening(obj)
    if Vendor.IsDirectionalInputListening then
        return Vendor.IsDirectionalInputListening(obj)
    end
    return false
end

local function LogNativeStoreInputState(context, storeManager)
    if not storeManager then
        return
    end
    -- Runs on the vendor store rebuild/sweep hot path; skip the eager string.format
    -- and the IsDirectionalInputListening sweep entirely when logging is inactive.
    if not (BETTERUI.Log and BETTERUI.Log.IsActive()) then
        return
    end

    LogVendorDebug(
        "DIRECTIONAL_INPUT",
        "VendorDI",
        string.format(
            "%s store=%s headerFocus=%s currentList=%s",
            context,
            tostring(IsDirectionalInputListening(storeManager)),
            tostring(IsDirectionalInputListening(storeManager.headerFocus)),
            tostring(IsDirectionalInputListening(storeManager._currentList))
        )
    )
end

function NativeStoreBridge.LogInputState(context, storeManager)
    LogNativeStoreInputState(context, storeManager)
end

local function GetActiveNativeStoreModes(storeManager)
    local modes = {}
    local seen = {}
    local activeComponents = storeManager.activeComponents
    if type(activeComponents) ~= "table" then
        return modes, seen
    end
    for _, component in ipairs(activeComponents) do
        if component and type(component.GetStoreMode) == "function" then
            local okMode, mode = GetVendorExecuteSafely()("Vendor.NativeStoreBridge:GetActiveMode", component.GetStoreMode, component)
            if okMode and mode and not seen[mode] then
                seen[mode] = true
                modes[#modes + 1] = mode
            end
        end
    end
    return modes, seen
end

local function BuildComponentSnapshot(searchContext)
    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if not storeManager or type(storeManager.SetActiveComponents) ~= "function" then
        return nil
    end

    local buyMode = rawget(_G, "ZO_MODE_STORE_BUY")
    local sellMode = rawget(_G, "ZO_MODE_STORE_SELL")
    local sellVengeanceMode = rawget(_G, "ZO_MODE_STORE_SELL_VENGEANCE")
    local buyBackMode = rawget(_G, "ZO_MODE_STORE_BUY_BACK")
    local repairMode = rawget(_G, "ZO_MODE_STORE_REPAIR")
    local stableMode = rawget(_G, "ZO_MODE_STORE_STABLE")

    local componentTable, seenActiveModes = GetActiveNativeStoreModes(storeManager)
    local isStableInteraction = Vendor.IsStableInteraction and Vendor.IsStableInteraction() or false
    local isFenceInteraction = Vendor.IsFenceInteraction and Vendor.IsFenceInteraction() or false
    local hasNativeBuyComponent = buyMode ~= nil
        and type(storeManager.components) == "table"
        and storeManager.components[buyMode] ~= nil
    local includeBuy = Vendor._sessionHasBuyMode == true
        or (buyMode ~= nil and seenActiveModes[buyMode] == true)
        or (isStableInteraction and hasNativeBuyComponent)
    if not includeBuy and Vendor.HasVendorBuyInventory then
        includeBuy = Vendor.HasVendorBuyInventory("Vendor.NativeStoreBridge")
    end
    if includeBuy then
        Vendor._sessionHasBuyMode = true
    end
    local needRebuild
    if isStableInteraction then
        needRebuild = (#componentTable == 0)
            or (includeBuy and buyMode ~= nil and not seenActiveModes[buyMode])
            or (stableMode ~= nil and not seenActiveModes[stableMode])
            or (sellMode ~= nil and seenActiveModes[sellMode])
            or (buyBackMode ~= nil and seenActiveModes[buyBackMode])
    else
        needRebuild = (#componentTable == 0)
            or (not isFenceInteraction and includeBuy and buyMode ~= nil and not seenActiveModes[buyMode])
            or (stableMode ~= nil and seenActiveModes[stableMode])
    end

    return {
        storeManager = storeManager,
        searchContext = searchContext or "storeTextSearch",
        availableComponents = storeManager.components or {},
        componentTable = componentTable,
        includeBuy = includeBuy,
        needRebuild = needRebuild,
        isStableInteraction = isStableInteraction,
        buyMode = buyMode,
        sellMode = sellMode,
        sellVengeanceMode = sellVengeanceMode,
        buyBackMode = buyBackMode,
        repairMode = repairMode,
        stableMode = stableMode,
    }
end

local function SweepDirectionalInput(storeManager, includeComponentLists)
    if not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Deactivate) then
        return
    end
    if DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT:IsListening(storeManager) then
        DIRECTIONAL_INPUT:Deactivate(storeManager)
    end
    if not includeComponentLists then
        return
    end
    local activeComps = storeManager.activeComponents
    if type(activeComps) == "table" then
        for _, comp in ipairs(activeComps) do
            if comp and comp.list and DIRECTIONAL_INPUT.IsListening
                and DIRECTIONAL_INPUT:IsListening(comp.list) then
                DIRECTIONAL_INPUT:Deactivate(comp.list)
            end
        end
    end
    if storeManager._currentList and DIRECTIONAL_INPUT.IsListening
        and DIRECTIONAL_INPUT:IsListening(storeManager._currentList) then
        DIRECTIONAL_INPUT:Deactivate(storeManager._currentList)
    end
    if storeManager.headerFocus and DIRECTIONAL_INPUT.IsListening
        and DIRECTIONAL_INPUT:IsListening(storeManager.headerFocus) then
        DIRECTIONAL_INPUT:Deactivate(storeManager.headerFocus)
    end
end

local function BuildRebuildPlan(snapshot)
    local modeSet = {}
    local rebuiltModes = {}

    local function AddMode(mode)
        if mode and not modeSet[mode] and snapshot.availableComponents[mode] then
            modeSet[mode] = true
            rebuiltModes[#rebuiltModes + 1] = mode
        end
    end

    if snapshot.isStableInteraction then
        if snapshot.includeBuy then
            AddMode(snapshot.buyMode)
        end
        AddMode(snapshot.stableMode)
        if snapshot.repairMode and (type(CanStoreRepair) ~= "function" or CanStoreRepair()) then
            AddMode(snapshot.repairMode)
        end
    else
        if snapshot.includeBuy then
            AddMode(snapshot.buyMode)
        end
        AddMode(snapshot.sellMode)
        if snapshot.sellVengeanceMode and Vendor.IsSellVengeanceModeAvailable and Vendor.IsSellVengeanceModeAvailable() then
            AddMode(snapshot.sellVengeanceMode)
        end
        AddMode(snapshot.buyBackMode)
        if snapshot.repairMode and (type(CanStoreRepair) ~= "function" or CanStoreRepair()) then
            AddMode(snapshot.repairMode)
        end
    end

    for _, mode in ipairs(snapshot.componentTable) do
        if snapshot.isStableInteraction then
            if mode == snapshot.buyMode
                or mode == snapshot.repairMode
                or mode == snapshot.stableMode then
                AddMode(mode)
            end
        elseif mode ~= snapshot.stableMode then
            AddMode(mode)
        end
    end

    return {
        modeSet = modeSet,
        rebuiltModes = rebuiltModes,
    }
end

local function NeutralizeHeaderCallbacks(storeManager)
    local nativeHeader = storeManager.header
    if not (nativeHeader and nativeHeader.tabBar) then
        return
    end

    local nativeTabBar = nativeHeader.tabBar
    if nativeTabBar.SetOnActivatedChangedFunction then
        nativeTabBar:SetOnActivatedChangedFunction(nil)
    end
    if nativeTabBar.RemoveAllOnSelectedDataChangedCallbacks then
        nativeTabBar:RemoveAllOnSelectedDataChangedCallbacks()
    end
    if nativeTabBar.IsActive and nativeTabBar:IsActive() and nativeTabBar.Deactivate then
        nativeTabBar:Deactivate()
    end
end

local function GuardedBridgeCall(context, fn, ...)
    local ok, result = GetVendorExecuteSafely()(context, fn, ...)
    if not ok then
        LogVendorDebug(
            "SCENE_TRANSITIONS",
            "VendorScene",
            string.format("NativeStoreBridge guard failed in %s: %s", tostring(context), tostring(result))
        )
        return false, result
    end
    return true, result
end

local function ApplyRebuildPlan(snapshot, rebuildPlan)
    if #rebuildPlan.rebuiltModes == 0 then
        return false
    end

    local storeManager = snapshot.storeManager
    local okSetActive = GuardedBridgeCall(
        "Vendor.NativeStoreBridge:SetActiveComponents",
        storeManager.SetActiveComponents,
        storeManager,
        rebuildPlan.rebuiltModes,
        snapshot.searchContext
    )
    -- Neutralize header callbacks even when the guarded call fails: a partial
    -- SetActiveComponents may already have wired native header callbacks.
    NeutralizeHeaderCallbacks(storeManager)
    if not okSetActive then
        return false
    end
    if storeManager._currentList and storeManager._currentList.Deactivate then
        if not storeManager._currentList.IsActive or storeManager._currentList:IsActive() then
            storeManager._currentList:Deactivate()
        end
    end

    if snapshot.buyMode and rebuildPlan.modeSet[snapshot.buyMode] then
        -- U50 has no global SetStoreMode (verified absent from
        -- ESOUIDocumentation.txt); drive mode through storeManager:SetMode only.
        if type(storeManager.SetMode) == "function" then
            local okStoreManagerSetMode = GuardedBridgeCall(
                "Vendor.NativeStoreBridge:StoreManagerSetMode",
                storeManager.SetMode,
                storeManager,
                snapshot.buyMode
            )
            if not okStoreManagerSetMode then
                return false
            end
        end
    end
    if type(storeManager.InitializeStore) == "function" then
        local okInitialize = GuardedBridgeCall(
            "Vendor.NativeStoreBridge:InitializeStore",
            storeManager.InitializeStore,
            storeManager
        )
        if not okInitialize then
            return false
        end
    end

    return true
end

local function ShouldAbortOpenStoreSync()
    if Vendor._isClosing then
        return true, "closing"
    end
    if not Vendor.instance then
        return true, "missingInstance"
    end
    if Vendor.IsFenceInteraction and Vendor.IsFenceInteraction() then
        return true, "fenceInteraction"
    end
    if Vendor.instance.IsSceneActiveOrShowing and not Vendor.instance:IsSceneActiveOrShowing() then
        return true, "sceneInactive"
    end
    return false, nil
end

---@param storeManager table|nil
---@param safeCall fun(context:string, fn:function, ...:any):boolean,...|nil
---@param logInputState fun(context:string, storeManager:table|nil)|nil
---@return nil
function NativeStoreBridge.CleanupAfterCloseStore(storeManager, safeCall, logInputState)
    if not storeManager then
        TraceNativeStoreBridge("vendor.native_store_cleanup", "skipped", {
            fn = "NativeStoreBridge.CleanupAfterCloseStore",
            reason = "missingStoreManager",
        })
        return
    end

    safeCall = safeCall or GetVendorExecuteSafely()
    logInputState = logInputState or LogNativeStoreInputState

    local activeBefore = type(storeManager.activeComponents) == "table" and #storeManager.activeComponents or nil
    TraceNativeStoreBridge("vendor.native_store_cleanup", "begin", {
        fn = "NativeStoreBridge.CleanupAfterCloseStore",
        activeComponentsBefore = activeBefore,
        hasOnHide = type(storeManager.OnHide) == "function",
    })
    logInputState(CLOSE_STORE_BEFORE_SWEEP_CONTEXT, storeManager)
    if type(storeManager.OnHide) == "function" then
        safeCall(CLOSE_STORE_NATIVE_ON_HIDE_CONTEXT, storeManager.OnHide, storeManager)
        TraceNativeStoreBridge("vendor.native_store_cleanup", "native_onhide", {
            fn = "NativeStoreBridge.CleanupAfterCloseStore",
            context = CLOSE_STORE_NATIVE_ON_HIDE_CONTEXT,
        })
    else
        TraceNativeStoreBridge("vendor.native_store_cleanup", "native_onhide_skipped", {
            fn = "NativeStoreBridge.CleanupAfterCloseStore",
            reason = "missingOnHide",
        })
    end
    storeManager.activeComponents = {}
    logInputState(CLOSE_STORE_AFTER_SWEEP_CONTEXT, storeManager)
    TraceNativeStoreBridge("vendor.native_store_cleanup", "end", {
        fn = "NativeStoreBridge.CleanupAfterCloseStore",
        activeComponentsBefore = activeBefore,
        activeComponentsAfter = type(storeManager.activeComponents) == "table" and #storeManager.activeComponents or nil,
    })
end

function NativeStoreBridge.SetSceneAlias(sceneObject)
    Vendor.activeStoreSceneObject = sceneObject
end

function NativeStoreBridge.RestoreSceneAlias()
    if Vendor.nativeStoreScene then
        NativeStoreBridge.SetSceneAlias(Vendor.nativeStoreScene)
    end
end

function NativeStoreBridge.AliasSceneToBetterUI(instance)
    if instance and instance.scene then
        NativeStoreBridge.SetSceneAlias(instance.scene)
    end
end

function NativeStoreBridge.UpdateSceneManagerStoreAlias(instance)
    if instance and instance.scene then
        NativeStoreBridge.SetSceneAlias(instance.scene)
    else
        NativeStoreBridge.RestoreSceneAlias()
    end
end

function NativeStoreBridge.TakeOverScene(instance)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "NativeStoreBridge: TakeOverScene")
    end
    Vendor.nativeStoreScene = Vendor.nativeStoreScene or (SCENE_MANAGER and SCENE_MANAGER:GetScene("gamepad_store"))

    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if storeManager then
        if storeManager.control then
            storeManager.control:UnregisterForEvent(EVENT_OPEN_STORE)
            storeManager.control:UnregisterForEvent(EVENT_CLOSE_STORE)
        end
        if EVENT_MANAGER then
            EVENT_MANAGER:UnregisterForEvent("ZO_StoreWindow_Gamepad", EVENT_OPEN_STORE)
            EVENT_MANAGER:UnregisterForEvent("ZO_StoreWindow_Gamepad", EVENT_CLOSE_STORE)
        end

        if type(storeManager.UpdateDirectionalInput) == "function" then
            if not updateDirectionalInputHookedManagers[storeManager] and type(ZO_PreHook) == "function" then
                ZO_PreHook(storeManager, "UpdateDirectionalInput", function()
                    local nativeScene = Vendor.nativeStoreScene
                    if nativeScene and nativeScene.IsShowing and nativeScene:IsShowing() then
                        return false
                    end
                    return true
                end)
                updateDirectionalInputHookedManagers[storeManager] = true
                TraceNativeStoreBridge("vendor.native_store_directional_input", "hook_installed", {
                    fn = "NativeStoreBridge.TakeOverScene",
                })
            elseif not updateDirectionalInputHookedManagers[storeManager] then
                TraceNativeStoreBridge("vendor.native_store_directional_input", "hook_skipped", {
                    fn = "NativeStoreBridge.TakeOverScene",
                    reason = "missing ZO_PreHook",
                })
            end
        end
    end

    NativeStoreBridge.AliasSceneToBetterUI(instance)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "scene ownership recorded without scene-manager hook", {
            fn = "NativeStoreBridge.TakeOverScene",
            sceneName = "gamepad_store",
            hasInstanceScene = instance and instance.scene ~= nil,
        })
    end
end

function NativeStoreBridge.EnsureComponents(searchContext)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "NativeStoreBridge: EnsureComponents", {
            searchContext = searchContext,
        })
    end
    local snapshot = BuildComponentSnapshot(searchContext)
    if not snapshot then
        return
    end

    LogVendorDebug(
        "DIRECTIONAL_INPUT",
        "VendorDI",
        string.format(
            "EnsureComponents(%s): rebuild=%s includeBuy=%s activeModes=%d",
            tostring(snapshot.searchContext),
            tostring(snapshot.needRebuild),
            tostring(snapshot.includeBuy),
            #snapshot.componentTable
        )
    )
    if not snapshot.needRebuild then
        SweepDirectionalInput(snapshot.storeManager, false)
        LogNativeStoreInputState("NativeStoreBridge:skipRebuild", snapshot.storeManager)
        return
    end

    local rebuildPlan = BuildRebuildPlan(snapshot)
    -- Apply the plan, then always run the directional-input sweep (develop
    -- behavior): skipping it after a failed guarded native call leaves the
    -- native store manager registered on DIRECTIONAL_INPUT, causing joystick
    -- double-scroll/lockup.
    ApplyRebuildPlan(snapshot, rebuildPlan)
    SweepDirectionalInput(snapshot.storeManager, true)
    LogNativeStoreInputState("NativeStoreBridge:postSweep", snapshot.storeManager)
end

function NativeStoreBridge.ResolveTargetMode()
    local tabs = Vendor.GetActiveTabs and Vendor.GetActiveTabs() or {}
    local resolver = Vendor.ResolveInitialStoreMode
    local targetMode = resolver and resolver(tabs) or ((tabs and tabs[1] and tabs[1].mode) or (Vendor.MODE and Vendor.MODE.SELL))
    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("NativeStoreBridge.ResolveTargetMode targetMode=%s tabs=%d", tostring(targetMode), #tabs)
    )
    return targetMode
end

function NativeStoreBridge.ApplyResolvedMode(targetMode, refreshList)
    local instance = Vendor.instance
    if not instance or not targetMode then
        return
    end

    if instance.GetCurrentMode and instance:GetCurrentMode() ~= targetMode then
        instance:SetMode(targetMode)
    else
        instance:ApplyNativeStoreMode(targetMode)
    end

    if refreshList and instance.RefreshList then
        instance:RefreshList()
    end
end

function NativeStoreBridge.GetCurrentMode()
    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if not storeManager or type(storeManager.GetCurrentMode) ~= "function" then
        return nil
    end

    local okMode, modeResult = GetVendorExecuteSafely()("Vendor.NativeStoreBridge:GetCurrentMode", storeManager.GetCurrentMode, storeManager)
    if okMode then
        return modeResult
    end
    return nil
end

function NativeStoreBridge.ScheduleOpenStoreSync(targetMode, delayMs)
    if not Vendor.Tasks then
        TraceNativeStoreBridge("vendor.open_store_sync", "skipped", {
            reason = "missingTasks",
            targetMode = targetMode,
            delayMs = delayMs,
        })
        return
    end

    Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
    TraceNativeStoreBridge("vendor.open_store_sync", "scheduled", {
        targetMode = targetMode,
        delayMs = delayMs or 120,
    })
    Vendor.Tasks:Schedule("ensureStoreComponentsOnOpen", delayMs or 120, function()
        local abort, reason = ShouldAbortOpenStoreSync()
        if abort then
            TraceNativeStoreBridge("vendor.open_store_sync", "aborted", {
                step = "beforeEnsureComponents",
                reason = reason,
                targetMode = targetMode,
            })
            return
        end

        TraceNativeStoreBridge("vendor.open_store_sync", "ensure_components", {
            targetMode = targetMode,
            searchContext = "storeTextSearch",
        })
        NativeStoreBridge.EnsureComponents("storeTextSearch")
        abort, reason = ShouldAbortOpenStoreSync()
        if abort then
            TraceNativeStoreBridge("vendor.open_store_sync", "aborted", {
                step = "afterEnsureComponents",
                reason = reason,
                targetMode = targetMode,
            })
            return
        end

        local resolvedTargetMode = NativeStoreBridge.ResolveTargetMode()
        if resolvedTargetMode ~= targetMode then
            targetMode = resolvedTargetMode
        end
        abort, reason = ShouldAbortOpenStoreSync()
        if abort then
            TraceNativeStoreBridge("vendor.open_store_sync", "aborted", {
                step = "afterResolveTargetMode",
                reason = reason,
                targetMode = targetMode,
                resolvedTargetMode = resolvedTargetMode,
            })
            return
        end

        NativeStoreBridge.ApplyResolvedMode(targetMode, true)
        TraceNativeStoreBridge("vendor.open_store_sync", "mode_applied", {
            targetMode = targetMode,
            resolvedTargetMode = resolvedTargetMode,
        })

        local targetNativeMode = Vendor.ResolveNativeStoreMode and Vendor.ResolveNativeStoreMode(targetMode) or nil
        if targetNativeMode == nil or NativeStoreBridge.GetCurrentMode() == targetNativeMode then
            Vendor._openStoreSyncAttempt = 0
            TraceNativeStoreBridge("vendor.open_store_sync", "complete", {
                targetMode = targetMode,
                targetNativeMode = targetNativeMode,
            })
            return
        end

        local syncAttempt = (Vendor._openStoreSyncAttempt or 0) + 1
        Vendor._openStoreSyncAttempt = syncAttempt
        local currentNativeMode = NativeStoreBridge.GetCurrentMode()
        TraceNativeStoreBridge("vendor.open_store_sync", syncAttempt <= 4 and "retry" or "give_up", {
            targetMode = targetMode,
            targetNativeMode = targetNativeMode,
            currentNativeMode = currentNativeMode,
            attempt = syncAttempt,
            maxAttempts = 4,
        })
        if syncAttempt <= 4 then
            NativeStoreBridge.ScheduleOpenStoreSync(targetMode, 140)
        end
    end)
end
