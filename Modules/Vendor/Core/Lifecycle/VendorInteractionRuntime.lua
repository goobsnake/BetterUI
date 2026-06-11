--[[
File: Modules/Vendor/Core/Lifecycle/VendorInteractionRuntime.lua
Purpose: Own vendor open/close interaction orchestration so Vendor.lua stays a
         thin coordinator while tests can still exercise the workflow in
         isolation.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.InteractionRuntime = Vendor.InteractionRuntime or {}
local InteractionRuntime = Vendor.InteractionRuntime
local unpackCompat = table.unpack or unpack
local CLOSE_STORE_BEFORE_SWEEP_CONTEXT = "CloseStore:beforeSweep"
local CLOSE_STORE_AFTER_SWEEP_CONTEXT = "CloseStore:afterSweep"
local CLOSE_STORE_NATIVE_ON_HIDE_CONTEXT = "Vendor.CloseStore:NativeOnHide"

local function PackResults(...)
    return {
        n = select("#", ...),
        ...
    }
end

local function DefaultShowVendorScene()
    if SCENE_MANAGER then
        SCENE_MANAGER:Show(BETTERUI_VENDOR_SCENE_NAME)
    end
end

local function DefaultHideVendorScene()
    if not SCENE_MANAGER then
        return
    end

    local scene = SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if scene and scene.IsShowing and scene:IsShowing() then
        SCENE_MANAGER:Hide(BETTERUI_VENDOR_SCENE_NAME)
    end
end

local function DefaultIsNativeStableModeActive()
    local modePolicy = Vendor.ModePolicy
    if modePolicy and modePolicy.IsNativeStableModeActive then
        return modePolicy.IsNativeStableModeActive(rawget(_G, "STORE_WINDOW_GAMEPAD"))
    end
    return false
end

local function DefaultLogVendorDebug(flagName, category, message)
    if Vendor.LogDebug then
        Vendor.LogDebug(flagName, category, message)
    end
end

local function DefaultSafeCall(context, fn, ...)
    local safeContext = context
    if safeContext == nil or safeContext == "" then
        safeContext = "Vendor.InteractionRuntime:SafeCall"
    else
        safeContext = tostring(safeContext)
    end

    if Vendor.ExecuteSafely then
        return Vendor.ExecuteSafely(safeContext, fn, ...)
    end
    if type(fn) ~= "function" then
        return false, "No function provided"
    end

    local results = PackResults(pcall(fn, ...))
    local ok = results[1]
    if not ok then
        local err = results[2]
        local userNotify = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.UserNotify
        if type(userNotify) == "function" then
            pcall(userNotify, safeContext, tostring(err))
        end
        return false, err
    end

    return true, unpackCompat(results, 2, results.n)
end

local function BuildInteractionState(seed)
    seed = seed or {}
    return {
        isFenceInteraction = seed.isFenceInteraction == true,
        isStableInteraction = seed.isStableInteraction == true,
        fenceEnableSell = seed.fenceEnableSell == true,
        fenceEnableLaunder = seed.fenceEnableLaunder == true,
        sessionHasBuyMode = seed.sessionHasBuyMode == true,
        isClosing = seed.isClosing == true,
        openStoreSyncAttempt = seed.openStoreSyncAttempt or 0,
    }
end

local function IsLifecycleRuntime(runtime)
    return type(runtime) == "table"
        and (
            type(runtime.ResetInteractionState) == "function"
            or type(runtime.SetInteractionState) == "function"
            or type(runtime.MarkClosingState) == "function"
        )
end

local function RequireRequestTable(request, apiName)
    if request == nil then
        return {}
    end
    assert(type(request) == "table", string.format("%s expects a request table", tostring(apiName)))
    return request
end

local function ResolveVendorDependency(fieldName)
    if type(Vendor.ResolveRuntimeDependency) == "function" then
        local resolved = Vendor.ResolveRuntimeDependency(fieldName, true)
        if resolved ~= nil then
            return resolved
        end
    end
    return Vendor[fieldName]
end

local function ResolveBridgeMethod(nativeStoreBridge, deps, keyName, methodName)
    local override = deps[keyName]
    if type(override) == "function" then
        return override
    end

    local bridgeMethod = nativeStoreBridge and nativeStoreBridge[methodName]
    assert(type(bridgeMethod) == "function",
        string.format("Vendor interaction runtime requires NativeStoreBridge.%s", methodName))
    return function(...)
        return bridgeMethod(...)
    end
end

local function ResolveOptionalBridgeMethod(nativeStoreBridge, deps, keyName, methodName)
    local override = deps[keyName]
    if type(override) == "function" then
        return override
    end

    local bridgeMethod = nativeStoreBridge and nativeStoreBridge[methodName]
    if type(bridgeMethod) ~= "function" then
        return nil
    end
    return function(...)
        return bridgeMethod(...)
    end
end

local function ResolveDeps(deps)
    deps = deps or {}
    local nativeStoreBridge = deps.nativeStoreBridge or ResolveVendorDependency("NativeStoreBridge")

    local getStoreManager = deps.getStoreManager
    if type(getStoreManager) ~= "function" then
        local explicitStoreManager = deps.storeManager
        getStoreManager = function()
            if explicitStoreManager ~= nil then
                return explicitStoreManager
            end
            return rawget(_G, "STORE_WINDOW_GAMEPAD")
        end
    end

    local restoreSceneAlias = ResolveBridgeMethod(nativeStoreBridge, deps, "restoreSceneAlias", "RestoreSceneAlias")
    local aliasSceneToBetterUI = ResolveBridgeMethod(nativeStoreBridge, deps, "aliasSceneToBetterUI", "AliasSceneToBetterUI")
    local ensureComponents = ResolveBridgeMethod(nativeStoreBridge, deps, "ensureComponents", "EnsureComponents")
    local resolveTargetMode = ResolveBridgeMethod(nativeStoreBridge, deps, "resolveTargetMode", "ResolveTargetMode")
    local applyResolvedMode = ResolveBridgeMethod(nativeStoreBridge, deps, "applyResolvedMode", "ApplyResolvedMode")
    local scheduleOpenStoreSync = ResolveBridgeMethod(nativeStoreBridge, deps, "scheduleOpenStoreSync", "ScheduleOpenStoreSync")
    local cleanupCloseStore = ResolveOptionalBridgeMethod(nativeStoreBridge, deps, "cleanupCloseStore", "CleanupAfterCloseStore")
    local logNativeStoreInputState = deps.logNativeStoreInputState
        or (nativeStoreBridge and nativeStoreBridge.LogInputState)
        or function()
        end

    return {
        instance = deps.instance ~= nil and deps.instance or ResolveVendorDependency("instance"),
        resetInteractionState = deps.resetInteractionState or function()
        end,
        markClosingState = deps.markClosingState or function()
        end,
        resetRuntimeState = deps.resetRuntimeState or ResolveVendorDependency("ResetRuntimeState"),
        cancelRuntimeTasks = deps.cancelRuntimeTasks or ResolveVendorDependency("CancelRuntimeTasks") or function()
        end,
        logVendorDebug = deps.logVendorDebug or DefaultLogVendorDebug,
        showScene = deps.showScene or DefaultShowVendorScene,
        hideScene = deps.hideScene or DefaultHideVendorScene,
        getInteractionType = deps.getInteractionType or rawget(_G, "GetInteractionType"),
        interactionVendor = deps.interactionVendor or rawget(_G, "INTERACTION_VENDOR"),
        interactionStable = deps.interactionStable or rawget(_G, "INTERACTION_STABLE"),
        isNativeStableModeActive = deps.isNativeStableModeActive or DefaultIsNativeStableModeActive,
        restoreSceneAlias = restoreSceneAlias,
        aliasSceneToBetterUI = aliasSceneToBetterUI,
        ensureComponents = ensureComponents,
        resolveTargetMode = resolveTargetMode,
        applyResolvedMode = applyResolvedMode,
        scheduleOpenStoreSync = scheduleOpenStoreSync,
        sellMode = deps.sellMode or (Vendor.MODE and Vendor.MODE.FENCE_SELL),
        fenceLaunderMode = deps.fenceLaunderMode or (Vendor.MODE and Vendor.MODE.FENCE_LAUNDER),
        getStoreManager = getStoreManager,
        logNativeStoreInputState = logNativeStoreInputState,
        runCloseCleanup = deps.runCloseCleanup or function()
        end,
        safeCall = deps.safeCall or DefaultSafeCall,
        cleanupCloseStore = cleanupCloseStore,
    }
end

local function BuildLifecycleDeps(runtime, nativeStoreBridge, instance, options)
    options = options or {}
    return {
        nativeStoreBridge = nativeStoreBridge,
        instance = instance,
        resetInteractionState = function()
            if runtime.ResetInteractionState then
                runtime:ResetInteractionState(instance)
            end
        end,
        markClosingState = function()
            if runtime.MarkClosingState then
                runtime:MarkClosingState()
            end
        end,
        resetRuntimeState = function(target)
            if runtime.ResetRuntimeState then
                runtime:ResetRuntimeState(target)
            end
        end,
        cancelRuntimeTasks = function()
            if runtime.CancelRuntimeTasks then
                runtime:CancelRuntimeTasks()
            end
        end,
        logVendorDebug = function(flagName, category, message)
            if runtime.LogDebug then
                runtime:LogDebug(flagName, category, message)
            end
        end,
        showScene = function()
            if runtime.ShowScene then
                runtime:ShowScene()
            else
                DefaultShowVendorScene()
            end
        end,
        hideScene = function()
            if runtime.HideScene then
                runtime:HideScene()
            else
                DefaultHideVendorScene()
            end
        end,
        getInteractionType = options.getInteractionType
            or (options.interactionType ~= nil and function()
                return options.interactionType
            end or nil),
        interactionVendor = options.interactionVendor,
        interactionStable = options.interactionStable,
        isNativeStableModeActive = options.isNativeStableModeActive or DefaultIsNativeStableModeActive,
        restoreSceneAlias = options.restoreSceneAlias,
        aliasSceneToBetterUI = options.aliasSceneToBetterUI,
        ensureComponents = options.ensureComponents,
        resolveTargetMode = options.resolveTargetMode,
        applyResolvedMode = options.applyResolvedMode,
        scheduleOpenStoreSync = options.scheduleOpenStoreSync,
        sellMode = options.sellMode,
        fenceLaunderMode = options.fenceLaunderMode,
        getStoreManager = function()
            if runtime.GetStoreManager then
                return runtime:GetStoreManager()
            end
            return rawget(_G, "STORE_WINDOW_GAMEPAD")
        end,
        logNativeStoreInputState = function(context, storeManager)
            if runtime.LogNativeStoreInputState then
                runtime:LogNativeStoreInputState(context, storeManager)
            end
        end,
        runCloseCleanup = function()
            if runtime.RunCloseCleanup then
                runtime:RunCloseCleanup(instance)
            end
        end,
        safeCall = function(context, fn, ...)
            if runtime.SafeCall then
                return runtime:SafeCall(context, fn, ...)
            end
            return DefaultSafeCall(context, fn, ...)
        end,
        cleanupCloseStore = nativeStoreBridge and nativeStoreBridge.CleanupAfterCloseStore and function(storeManager, safeCall, logNativeStoreInputState)
                return nativeStoreBridge.CleanupAfterCloseStore(storeManager, safeCall, logNativeStoreInputState)
            end or nil,
    }
end

local function ApplyRuntimeState(runtime, state)
    if runtime.SetInteractionState then
        runtime:SetInteractionState(state)
    end
end

local function MakeStatePublisher(runtime)
    if not runtime then
        return function()
        end
    end
    return function(state)
        ApplyRuntimeState(runtime, state)
    end
end

-- The native bridge and initial-mode resolver may flip the live session flag
-- (Vendor._sessionHasBuyMode) while the open workflow runs. Sync it back into
-- the state table so the final ApplyRuntimeState publish does not clobber the
-- live value with the stale seed.
local function SyncSessionBuyModeFromLiveState(state)
    state.sessionHasBuyMode = Vendor._sessionHasBuyMode == true
    return state
end

local function OpenStoreInternal(state, deps, publishState)
    publishState = publishState or function()
    end
    local resolved = ResolveDeps(deps)
    resolved.resetInteractionState()

    local interactionType = nil
    if type(resolved.getInteractionType) == "function" then
        interactionType = resolved.getInteractionType()
    end
    local allowNativeStableFallback = interactionType == nil
    state.isStableInteraction = interactionType == resolved.interactionStable
        or (allowNativeStableFallback and resolved.isNativeStableModeActive())
    -- Publish the interaction flags BEFORE any native component work:
    -- EnsureComponents and ResolveTargetMode read the live module state
    -- (Vendor.IsStableInteraction / Vendor.GetActiveTabs) during the open
    -- flow, so deferring the publish until after the workflow would feed
    -- them stale flags (non-stable rebuild plan, wrong tab set).
    publishState(state)
    resolved.logVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OpenStore interaction=%s fence=%s stable=%s",
            tostring(interactionType), tostring(state.isFenceInteraction), tostring(state.isStableInteraction))
    )

    if interactionType
        and interactionType ~= resolved.interactionVendor
        and interactionType ~= resolved.interactionStable
    then
        resolved.restoreSceneAlias()
        return state
    end

    local instance = resolved.instance
    resolved.aliasSceneToBetterUI(instance)
    if instance and instance.ReleaseNativeStoreInputOwnership then
        instance:ReleaseNativeStoreInputOwnership()
    end
    resolved.ensureComponents("storeTextSearch")
    if not state.isStableInteraction and allowNativeStableFallback and resolved.isNativeStableModeActive() then
        state.isStableInteraction = true
        publishState(state)
        resolved.ensureComponents("storeTextSearch")
    end

    if instance and resolved.resetRuntimeState then
        resolved.resetRuntimeState(instance)
    end

    local targetMode = resolved.resolveTargetMode()
    if targetMode then
        resolved.applyResolvedMode(targetMode, false)
    end
    resolved.showScene()
    if targetMode then
        resolved.scheduleOpenStoreSync(targetMode, 120)
    end

    return SyncSessionBuyModeFromLiveState(state)
end

local function OpenFenceInternal(state, deps, enableSell, enableLaunder, publishState)
    publishState = publishState or function()
    end
    local resolved = ResolveDeps(deps)
    resolved.resetInteractionState()
    state.isFenceInteraction = true
    state.fenceEnableSell = enableSell ~= false
    state.fenceEnableLaunder = enableLaunder ~= false
    -- Publish fence flags BEFORE SetMode/ShowScene so Vendor.GetActiveTabs
    -- builds FENCE_TABS during the open flow instead of stale VENDOR_TABS.
    publishState(state)
    resolved.logVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OpenFence sell=%s launder=%s", tostring(state.fenceEnableSell), tostring(state.fenceEnableLaunder))
    )

    local instance = resolved.instance
    if not instance then
        return state
    end

    if resolved.resetRuntimeState then
        resolved.resetRuntimeState(instance)
    end
    resolved.aliasSceneToBetterUI(instance)
    if instance.ReleaseNativeStoreInputOwnership then
        instance:ReleaseNativeStoreInputOwnership()
    end

    if state.fenceEnableSell then
        instance:SetMode(resolved.sellMode)
    elseif state.fenceEnableLaunder then
        instance:SetMode(resolved.fenceLaunderMode)
    else
        -- Defensive: a fence open with both capabilities disabled would keep a
        -- stale mode from the previous interaction; fall back to sell mode.
        instance:SetMode(resolved.sellMode)
    end
    resolved.showScene()

    return SyncSessionBuyModeFromLiveState(state)
end

local function CloseStoreInternal(state, deps)
    local resolved = ResolveDeps(deps)
    resolved.markClosingState()
    state.isClosing = true
    state.isFenceInteraction = false
    state.isStableInteraction = false
    state.fenceEnableSell = false
    state.fenceEnableLaunder = false
    state.sessionHasBuyMode = false
    state.openStoreSyncAttempt = 0

    local instance = resolved.instance
    if instance then
        if resolved.resetRuntimeState then
            resolved.resetRuntimeState(instance)
        end
    end

    resolved.cancelRuntimeTasks()
    resolved.logVendorDebug("SCENE_TRANSITIONS", "VendorScene", "CloseStore begin")
    resolved.hideScene()

    local storeManager = resolved.getStoreManager()
    resolved.runCloseCleanup()
    if type(resolved.cleanupCloseStore) == "function" then
        resolved.cleanupCloseStore(storeManager, resolved.safeCall, resolved.logNativeStoreInputState)
    else
        resolved.logNativeStoreInputState(CLOSE_STORE_BEFORE_SWEEP_CONTEXT, storeManager)
        if storeManager and type(storeManager.OnHide) == "function" then
            resolved.safeCall(CLOSE_STORE_NATIVE_ON_HIDE_CONTEXT, storeManager.OnHide, storeManager)
        end
        if storeManager then
            storeManager.activeComponents = {}
        end
        resolved.logNativeStoreInputState(CLOSE_STORE_AFTER_SWEEP_CONTEXT, storeManager)
    end
    resolved.logVendorDebug("SCENE_TRANSITIONS", "VendorScene", "CloseStore complete")
    resolved.aliasSceneToBetterUI(instance)

    return state
end

local function ResolveRuntimeDepsFromRequest(request)
    local runtime = request.runtime
    if type(request.deps) == "table" then
        return request.deps, runtime
    end

    if IsLifecycleRuntime(runtime) then
        return BuildLifecycleDeps(
            runtime,
            request.nativeStoreBridge,
            request.instance,
            request.options
        ), runtime
    end

    return request.deps, nil
end

---@param request table|nil
---@return table
function InteractionRuntime.OpenStore(request)
    request = RequireRequestTable(request, "InteractionRuntime.OpenStore")
    local deps, runtime = ResolveRuntimeDepsFromRequest(request)
    local state = OpenStoreInternal(BuildInteractionState(request.state), deps, MakeStatePublisher(runtime))
    if runtime then
        ApplyRuntimeState(runtime, state)
    end
    return state
end

---@param request table|nil
---@return table
function InteractionRuntime.OpenFence(request)
    request = RequireRequestTable(request, "InteractionRuntime.OpenFence")
    local deps, runtime = ResolveRuntimeDepsFromRequest(request)
    local state = OpenFenceInternal(
        BuildInteractionState(request.state),
        deps,
        request.enableSell,
        request.enableLaunder,
        MakeStatePublisher(runtime)
    )
    if runtime then
        ApplyRuntimeState(runtime, state)
    end
    return state
end

---@param request table|nil
---@return table
function InteractionRuntime.CloseStore(request)
    request = RequireRequestTable(request, "InteractionRuntime.CloseStore")
    local deps, runtime = ResolveRuntimeDepsFromRequest(request)
    local state = CloseStoreInternal(BuildInteractionState(request.state), deps)
    if runtime then
        ApplyRuntimeState(runtime, state)
    end
    return state
end
