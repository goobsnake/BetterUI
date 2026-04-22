--[[
File: Modules/Vendor/Core/VendorInteractionRuntime.lua
Purpose: Own vendor open/close interaction orchestration so Vendor.lua stays a
         thin coordinator while tests can still exercise the workflow in
         isolation.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.InteractionRuntime = Vendor.InteractionRuntime or {}
local InteractionRuntime = Vendor.InteractionRuntime

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

local function DefaultSafeCall(_context, fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end
    return pcall(fn, ...)
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

local function IsModernRuntimeCall(runtime, nativeStoreBridge)
    return type(runtime) == "table"
        and (
            type(runtime.ResetInteractionState) == "function"
            or type(runtime.SetInteractionState) == "function"
            or type(runtime.MarkClosingState) == "function"
        )
        and type(nativeStoreBridge) == "table"
end

local function ResolveDeps(deps)
    deps = deps or {}
    local nativeStoreBridge = deps.nativeStoreBridge or Vendor.NativeStoreBridge

    local function RequireBridgeMethod(methodName)
        local method = nativeStoreBridge and nativeStoreBridge[methodName]
        assert(type(method) == "function",
            string.format("Vendor interaction runtime requires NativeStoreBridge.%s", methodName))
        return method
    end

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

    return {
        instance = deps.instance ~= nil and deps.instance or Vendor.instance,
        resetInteractionState = deps.resetInteractionState or function()
        end,
        markClosingState = deps.markClosingState or function()
        end,
        resetRuntimeState = deps.resetRuntimeState or Vendor.ResetRuntimeState,
        cancelRuntimeTasks = deps.cancelRuntimeTasks or Vendor.CancelRuntimeTasks or function()
        end,
        logVendorDebug = deps.logVendorDebug or DefaultLogVendorDebug,
        showScene = deps.showScene or DefaultShowVendorScene,
        hideScene = deps.hideScene or DefaultHideVendorScene,
        getInteractionType = deps.getInteractionType or rawget(_G, "GetInteractionType"),
        interactionVendor = deps.interactionVendor or rawget(_G, "INTERACTION_VENDOR"),
        interactionStable = deps.interactionStable or rawget(_G, "INTERACTION_STABLE"),
        isNativeStableModeActive = deps.isNativeStableModeActive or DefaultIsNativeStableModeActive,
        restoreSceneAlias = deps.restoreSceneAlias or deps.restoreNativeStoreSceneAlias or function()
            RequireBridgeMethod("RestoreSceneAlias")(nativeStoreBridge)
        end,
        aliasSceneToBetterUI = deps.aliasSceneToBetterUI or deps.aliasStoreSceneToBetterUI or function(instance)
            RequireBridgeMethod("AliasSceneToBetterUI")(nativeStoreBridge, instance)
        end,
        ensureComponents = deps.ensureComponents or deps.ensureNativeStoreComponents or function(searchContext)
            RequireBridgeMethod("EnsureComponents")(nativeStoreBridge, searchContext)
        end,
        resolveTargetMode = deps.resolveTargetMode or deps.resolveVendorTargetMode or function()
            return RequireBridgeMethod("ResolveTargetMode")(nativeStoreBridge)
        end,
        applyResolvedMode = deps.applyResolvedMode or deps.applyVendorResolvedMode or function(targetMode, refreshList)
            RequireBridgeMethod("ApplyResolvedMode")(nativeStoreBridge, targetMode, refreshList)
        end,
        scheduleOpenStoreSync = deps.scheduleOpenStoreSync or deps.scheduleVendorOpenStoreSync or function(targetMode, delayMs)
            RequireBridgeMethod("ScheduleOpenStoreSync")(nativeStoreBridge, targetMode, delayMs)
        end,
        sellMode = deps.sellMode or (Vendor.MODE and Vendor.MODE.FENCE_SELL),
        fenceLaunderMode = deps.fenceLaunderMode or (Vendor.MODE and Vendor.MODE.FENCE_LAUNDER),
        getStoreManager = getStoreManager,
        logNativeStoreInputState = deps.logNativeStoreInputState
            or (nativeStoreBridge and nativeStoreBridge.LogInputState)
            or function()
            end,
        runCloseCleanup = deps.runCloseCleanup or function()
        end,
        safeCall = deps.safeCall or Vendor.ExecuteSafely or DefaultSafeCall,
        cleanupCloseStore = deps.cleanupCloseStore
            or (nativeStoreBridge and nativeStoreBridge.CleanupAfterCloseStore),
    }
end

local function BuildModernDeps(runtime, nativeStoreBridge, instance, options)
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
        restoreNativeStoreSceneAlias = options.restoreNativeStoreSceneAlias,
        aliasStoreSceneToBetterUI = options.aliasStoreSceneToBetterUI,
        ensureNativeStoreComponents = options.ensureNativeStoreComponents,
        resolveVendorTargetMode = options.resolveVendorTargetMode,
        applyVendorResolvedMode = options.applyVendorResolvedMode,
        scheduleVendorOpenStoreSync = options.scheduleVendorOpenStoreSync,
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

local function OpenStoreInternal(state, deps)
    local resolved = ResolveDeps(deps)
    resolved.resetInteractionState()

    local interactionType = nil
    if type(resolved.getInteractionType) == "function" then
        interactionType = resolved.getInteractionType()
    end
    local allowNativeStableFallback = interactionType == nil
    state.isStableInteraction = interactionType == resolved.interactionStable
        or (allowNativeStableFallback and resolved.isNativeStableModeActive())
    resolved.logVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenStore interaction=%s fence=%s stable=%s",
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

    return state
end

local function OpenFenceInternal(state, deps, enableSell, enableLaunder)
    local resolved = ResolveDeps(deps)
    resolved.resetInteractionState()
    state.isFenceInteraction = true
    state.fenceEnableSell = enableSell ~= false
    state.fenceEnableLaunder = enableLaunder ~= false
    resolved.logVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenFence sell=%s launder=%s", tostring(state.fenceEnableSell), tostring(state.fenceEnableLaunder))
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
    end
    resolved.showScene()

    return state
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
    resolved.logVendorDebug("SCENE_TRANSITIONS", "VendorScene", "OnCloseStore begin")
    resolved.hideScene()

    local storeManager = resolved.getStoreManager()
    resolved.runCloseCleanup()
    if type(resolved.cleanupCloseStore) == "function" then
        resolved.cleanupCloseStore(storeManager, resolved.safeCall, resolved.logNativeStoreInputState)
    else
        resolved.logNativeStoreInputState("OnCloseStore:beforeSweep", storeManager)
        if storeManager and type(storeManager.OnHide) == "function" then
            resolved.safeCall("Vendor.OnCloseStore:NativeOnHide", storeManager.OnHide, storeManager)
        end
        if storeManager then
            storeManager.activeComponents = {}
        end
        resolved.logNativeStoreInputState("OnCloseStore:afterSweep", storeManager)
    end
    resolved.logVendorDebug("SCENE_TRANSITIONS", "VendorScene", "OnCloseStore complete")
    resolved.aliasSceneToBetterUI(instance)

    return state
end

---@return table
function InteractionRuntime.OnOpenStore(a, b, c, d)
    if IsModernRuntimeCall(a, b) then
        local state = OpenStoreInternal(BuildInteractionState(), BuildModernDeps(a, b, c, d))
        ApplyRuntimeState(a, state)
        return state
    end

    return OpenStoreInternal(BuildInteractionState(a), b)
end

---@return table
function InteractionRuntime.OnOpenFence(a, b, c, d, e, f)
    if IsModernRuntimeCall(a, b) then
        local state = OpenFenceInternal(BuildInteractionState(), BuildModernDeps(a, b, c, d), e, f)
        ApplyRuntimeState(a, state)
        return state
    end

    return OpenFenceInternal(BuildInteractionState(a), b, c, d)
end

---@return table
function InteractionRuntime.OnCloseStore(a, b, c)
    if IsModernRuntimeCall(a, b) then
        local state = CloseStoreInternal(BuildInteractionState(), BuildModernDeps(a, b, c, nil))
        ApplyRuntimeState(a, state)
        return state
    end

    return CloseStoreInternal(BuildInteractionState(a), b)
end
