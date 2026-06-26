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

local SPECIALIZED_NATIVE_VENDOR_SCENES = {
    "TamrielTomesSceneGamepad",
    "TamrielTomesIntroSceneGamepad",
    "TamrielTomesPurchaseSceneGamepad",
    "tamrielTomesPurchasePreview_Gamepad",
    "TamrielTomesRewardPreviewSceneGamepad",
}

local function BuildTraceState(state)
    state = state or {}
    return {
        isFenceInteraction = state.isFenceInteraction == true,
        isStableInteraction = state.isStableInteraction == true,
        fenceEnableSell = state.fenceEnableSell == true,
        fenceEnableLaunder = state.fenceEnableLaunder == true,
        sessionHasBuyMode = state.sessionHasBuyMode == true,
        isClosing = state.isClosing == true,
        openStoreSyncAttempt = state.openStoreSyncAttempt or 0,
    }
end

local function TraceVendorInteraction(event, phase, state, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then
        return
    end
    data = data or {}
    local traceState = BuildTraceState(state)
    for key, value in pairs(traceState) do
        if data[key] == nil then
            data[key] = value
        end
    end
    data.module = data.module or "Vendor"
    data.scene = data.scene or BETTERUI_VENDOR_SCENE_NAME
    data.feature = data.feature or "vendor-interaction"
    data.fn = data.fn or "Vendor.InteractionRuntime"
    data["function"] = data["function"] or data.fn
    L.TraceEvent(L.CATEGORY.LIFECYCLE, event, phase, data)
end

local function GetCurrentSceneName()
    if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentSceneName) == "function" then
        return SCENE_MANAGER:GetCurrentSceneName()
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentScene) == "function" then
        local scene = SCENE_MANAGER:GetCurrentScene()
        if scene and type(scene.GetName) == "function" then
            return scene:GetName()
        end
    end
    return nil
end

local function GetSceneState(scene)
    if scene and type(scene.GetState) == "function" then
        local ok, state = pcall(scene.GetState, scene)
        if ok then
            return state
        end
    end
    return nil
end

local function IsSceneShowing(scene)
    if scene and type(scene.IsShowing) == "function" then
        local ok, showing = pcall(scene.IsShowing, scene)
        return ok and showing == true
    end
    return false
end

local function IsSceneShowingNext(sceneName)
    if SCENE_MANAGER and type(SCENE_MANAGER.IsShowingNext) == "function" then
        local ok, showingNext = pcall(SCENE_MANAGER.IsShowingNext, SCENE_MANAGER, sceneName)
        return ok and showingNext == true
    end
    return false
end

local function FindSpecializedNativeScene()
    if not SCENE_MANAGER then
        return nil, nil
    end

    local currentSceneName = GetCurrentSceneName()
    for _, sceneName in ipairs(SPECIALIZED_NATIVE_VENDOR_SCENES) do
        local scene = SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(sceneName) or nil
        local state = GetSceneState(scene)
        local isCurrent = currentSceneName == sceneName
        local showingNext = IsSceneShowingNext(sceneName)
        local showing = IsSceneShowing(scene)
        local activeState = state ~= nil
            and (state == rawget(_G, "SCENE_SHOWING") or state == rawget(_G, "SCENE_SHOWN"))

        if isCurrent or showingNext or showing or activeState then
            return sceneName, state or (showingNext and "showingNext") or (isCurrent and "current") or "showing"
        end
    end

    return nil, nil
end

InteractionRuntime.FindSpecializedNativeScene = FindSpecializedNativeScene

-- Dialogs that may still be open when the store interaction ends. Native
-- ZO_GamepadStoreManager:OnCloseStore releases REPAIR_ALL; the BetterUI batch
-- and sell-all-junk dialogs are registered in Vendor.lua and must be released
-- alongside it so they cannot linger after the scene hides.
local VENDOR_CLEANUP_DIALOG_NAMES = {
    "REPAIR_ALL",
    "BETTERUI_VENDOR_BATCH_DIALOG",
    "BETTERUI_VENDOR_SELL_ALL_JUNK_DIALOG",
}

local function ReleaseVendorDialogs()
    if type(ZO_Dialogs_ReleaseDialog) ~= "function" then
        TraceVendorInteraction("vendor.dialogs", "release_skipped", nil, {
            fn = "ReleaseVendorDialogs",
            reason = "missingReleaseDialog",
            dialogs = table.concat(VENDOR_CLEANUP_DIALOG_NAMES, ","),
        })
        return
    end
    for _, dialogName in ipairs(VENDOR_CLEANUP_DIALOG_NAMES) do
        ZO_Dialogs_ReleaseDialog(dialogName)
        TraceVendorInteraction("vendor.dialogs", "release_requested", nil, {
            fn = "ReleaseVendorDialogs",
            dialogName = dialogName,
        })
    end
end

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
    local shouldUseNativeStoreFallback = deps.shouldUseNativeStoreFallback
        or (Vendor.ModePolicy and Vendor.ModePolicy.ShouldUseNativeStoreFallback)
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
        findSpecializedNativeScene = deps.findSpecializedNativeScene or FindSpecializedNativeScene,
        shouldUseNativeStoreFallback = shouldUseNativeStoreFallback,
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
        findSpecializedNativeScene = options.findSpecializedNativeScene or FindSpecializedNativeScene,
        shouldUseNativeStoreFallback = options.shouldUseNativeStoreFallback,
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

local function ReadStoreEntryType(entryIndex)
    if type(GetStoreEntryInfo) ~= "function" then
        return nil, nil
    end

    local _, name, _, _, _, _, _, _, _, _, _, _, _, entryType = GetStoreEntryInfo(entryIndex)
    return name, entryType
end

local function ShouldHandOffStoreToNative(resolved, interactionType)
    if type(resolved.findSpecializedNativeScene) == "function" then
        local specializedSceneName, specializedSceneState = resolved.findSpecializedNativeScene()
        if specializedSceneName then
            return true, "specializedNativeScene", {
                interactionType = interactionType,
                specializedSceneName = specializedSceneName,
                specializedSceneState = specializedSceneState,
            }
        end
    end

    if interactionType
        and interactionType ~= resolved.interactionVendor
        and interactionType ~= resolved.interactionStable
    then
        return true, "unsupportedInteraction", {
            interactionType = interactionType,
        }
    end

    if interactionType ~= resolved.interactionVendor then
        return false
    end

    if type(resolved.shouldUseNativeStoreFallback) == "function" then
        local okFallback, useNativeFallback, fallbackReason, fallbackEntryType, fallbackEntryIndex = resolved.safeCall(
            "Vendor.OpenStore:ShouldUseNativeStoreFallback",
            resolved.shouldUseNativeStoreFallback,
            {
                interactionType = interactionType,
                isStableInteraction = false,
                isFenceInteraction = false,
                storeManager = resolved.getStoreManager and resolved.getStoreManager() or nil,
            }
        )
        if okFallback and useNativeFallback then
            return true, fallbackReason or "nativeStoreFallback", {
                interactionType = interactionType,
                entryIndex = fallbackEntryIndex,
                entryType = fallbackEntryType,
            }
        end
        if not okFallback then
            TraceVendorInteraction("vendor.store_guard", "error", nil, {
                fn = "ShouldHandOffStoreToNative",
                interactionType = interactionType,
                reason = "guardFailed",
                error = tostring(useNativeFallback),
            })
        end
    end

    -- BetterUI's vendor scene owns the store keybind layer. Specialized event
    -- merchants can expose non-item store entries whose native keybinds include
    -- alternate verbs such as hold-to-acquire; leave those entries on native UI.
    local standardEntryType = rawget(_G, "STORE_ENTRY_TYPE_ITEM")
    if standardEntryType == nil or type(GetStoreEntryInfo) ~= "function" then
        return false
    end

    local numStoreItems = 0
    if type(GetNumStoreItems) == "function" then
        numStoreItems = GetNumStoreItems() or 0
    end
    local maxProbe = numStoreItems > 0 and math.min(numStoreItems, 10) or 10
    local probedEntries = 0

    for entryIndex = 1, maxProbe do
        local name, entryType = ReadStoreEntryType(entryIndex)
        if name and name ~= "" then
            probedEntries = probedEntries + 1
            if entryType ~= nil and entryType ~= standardEntryType then
                return true, "specialStoreEntryType", {
                    interactionType = interactionType,
                    entryIndex = entryIndex,
                    entryType = entryType,
                    standardEntryType = standardEntryType,
                    probedEntries = probedEntries,
                }
            end
        end
    end

    return false, nil, {
        interactionType = interactionType,
        standardEntryType = standardEntryType,
        probedEntries = probedEntries,
    }
end

-- Mirror ZO_GamepadStoreManager:OnOpenStore (storewindow_gamepad.lua:22-45):
-- rebuild the native store components and show the native gamepad_store scene.
-- Used when an unsupported interaction type hands the store back to native,
-- since TakeOverScene permanently unregistered native's EVENT_OPEN_STORE.
---@param resolved table Resolved dependency table from ResolveDeps
---@return nil
local function ShowNativeStore(resolved)
    local storeManager = resolved.getStoreManager and resolved.getStoreManager() or nil
    if storeManager and type(storeManager.SetActiveComponents) == "function" then
        local modeBuy = rawget(_G, "ZO_MODE_STORE_BUY")
        local modeSell = rawget(_G, "ZO_MODE_STORE_SELL")
        local modeBuyBack = rawget(_G, "ZO_MODE_STORE_BUY_BACK")
        local componentTable = {}
        if not (IsStoreEmpty and IsStoreEmpty()) and modeBuy then
            componentTable[#componentTable + 1] = modeBuy
        end
        if modeSell then
            componentTable[#componentTable + 1] = modeSell
        end
        if modeBuyBack then
            componentTable[#componentTable + 1] = modeBuyBack
        end
        if CanStoreRepair and CanStoreRepair() then
            local modeRepair = rawget(_G, "ZO_MODE_STORE_REPAIR")
            if modeRepair then
                componentTable[#componentTable + 1] = modeRepair
            end
        end
        if #componentTable > 0 then
            resolved.safeCall("Vendor.OpenStore:NativeSetActiveComponents",
                storeManager.SetActiveComponents, storeManager, componentTable, "storeTextSearch")
        end
    end

    local nativeSceneName = rawget(_G, "GAMEPAD_STORE_SCENE_NAME") or "gamepad_store"
    if SCENE_MANAGER and type(SCENE_MANAGER.Show) == "function" then
        resolved.safeCall("Vendor.OpenStore:ShowNativeStoreScene", SCENE_MANAGER.Show, SCENE_MANAGER, nativeSceneName)
    end
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

    TraceVendorInteraction("vendor.store", "open_begin", state, {
        interactionType = interactionType,
    })
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "store opened", {
            interactionType = interactionType,
        })
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

    local nativeHandoff, nativeReason, nativeData = ShouldHandOffStoreToNative(resolved, interactionType)
    if nativeHandoff then
        -- Hand specialized store interactions back to native. The alias is
        -- restored, but TakeOverScene permanently unregistered the native
        -- EVENT_OPEN_STORE handler, so nothing would show the store UI on its
        -- own. Explicitly drive the native open flow here, mirroring
        -- ZO_GamepadStoreManager:OnOpenStore (storewindow_gamepad.lua:22-45).
        nativeData = nativeData or {}
        TraceVendorInteraction("vendor.store", "native_handoff", state, {
            interactionType = interactionType,
            reason = nativeReason,
            entryIndex = nativeData.entryIndex,
            entryType = nativeData.entryType,
            standardEntryType = nativeData.standardEntryType,
            probedEntries = nativeData.probedEntries,
            specializedSceneName = nativeData.specializedSceneName,
            specializedSceneState = nativeData.specializedSceneState,
        })
        resolved.restoreSceneAlias()
        if nativeReason ~= "specializedNativeScene" then
            ShowNativeStore(resolved)
        end
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
    TraceVendorInteraction("vendor.store", "target_resolved", state, {
        targetMode = targetMode,
    })
    if targetMode then
        resolved.applyResolvedMode(targetMode, false)
    end
    TraceVendorInteraction("vendor.store_scene", "show_request", state, {
        targetMode = targetMode,
    })
    resolved.showScene()
    TraceVendorInteraction("vendor.store_scene", "show_complete", state, {
        targetMode = targetMode,
    })
    if targetMode then
        resolved.scheduleOpenStoreSync(targetMode, 120)
    end

    local finalState = SyncSessionBuyModeFromLiveState(state)
    TraceVendorInteraction("vendor.store", "open_end", finalState, {
        targetMode = targetMode,
    })
    return finalState
end

local function OpenFenceInternal(state, deps, enableSell, enableLaunder, publishState)
    TraceVendorInteraction("vendor.fence", "open_begin", state, {
        enableSell = enableSell,
        enableLaunder = enableLaunder,
    })
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "fence opened", {
            enableSell = enableSell,
            enableLaunder = enableLaunder,
        })
    end
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

    local finalState = SyncSessionBuyModeFromLiveState(state)
    TraceVendorInteraction("vendor.fence", "open_end", finalState, {
        enableSell = enableSell,
        enableLaunder = enableLaunder,
    })
    return finalState
end

local function CloseStoreInternal(state, deps)
    TraceVendorInteraction("vendor.store", "close_begin", state, nil)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "store closed")
    end
    local resolved = ResolveDeps(deps)
    resolved.markClosingState()
    -- Release any store dialogs still open at interaction end (native parity +
    -- BetterUI batch/sell-all-junk dialogs) so they cannot linger post-close.
    ReleaseVendorDialogs()
    TraceVendorInteraction("vendor.dialogs", "released", state, {
        dialogs = table.concat(VENDOR_CLEANUP_DIALOG_NAMES, ","),
    })
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
    TraceVendorInteraction("vendor.store_scene", "hide_request", state, nil)
    resolved.hideScene()
    TraceVendorInteraction("vendor.store_scene", "hide_complete", state, nil)

    local storeManager = resolved.getStoreManager()
    TraceVendorInteraction("vendor.store", "cleanup_begin", state, {
        fn = "CloseStoreInternal",
        hasStoreManager = storeManager ~= nil,
        hasBridgeCleanup = type(resolved.cleanupCloseStore) == "function",
    })
    resolved.runCloseCleanup()
    if type(resolved.cleanupCloseStore) == "function" then
        resolved.cleanupCloseStore(storeManager, resolved.safeCall, resolved.logNativeStoreInputState)
        TraceVendorInteraction("vendor.store", "cleanup_bridge", state, {
            fn = "CloseStoreInternal",
            hasStoreManager = storeManager ~= nil,
        })
    else
        resolved.logNativeStoreInputState(CLOSE_STORE_BEFORE_SWEEP_CONTEXT, storeManager)
        if storeManager and type(storeManager.OnHide) == "function" then
            resolved.safeCall(CLOSE_STORE_NATIVE_ON_HIDE_CONTEXT, storeManager.OnHide, storeManager)
            TraceVendorInteraction("vendor.store", "cleanup_native_onhide", state, {
                fn = "CloseStoreInternal",
                context = CLOSE_STORE_NATIVE_ON_HIDE_CONTEXT,
            })
        else
            TraceVendorInteraction("vendor.store", "cleanup_native_onhide_skipped", state, {
                fn = "CloseStoreInternal",
                reason = storeManager and "missingOnHide" or "missingStoreManager",
            })
        end
        if storeManager then
            storeManager.activeComponents = {}
            TraceVendorInteraction("vendor.store", "cleanup_components_cleared", state, {
                fn = "CloseStoreInternal",
            })
        end
        resolved.logNativeStoreInputState(CLOSE_STORE_AFTER_SWEEP_CONTEXT, storeManager)
    end
    resolved.logVendorDebug("SCENE_TRANSITIONS", "VendorScene", "CloseStore complete")
    resolved.aliasSceneToBetterUI(instance)
    TraceVendorInteraction("vendor.store", "close_end", state, nil)

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
