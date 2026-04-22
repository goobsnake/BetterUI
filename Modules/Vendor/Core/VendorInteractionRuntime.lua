--[[
File: Modules/Vendor/Core/VendorInteractionRuntime.lua
Purpose: Own vendor open/close interaction orchestration so Vendor.lua stays a thin event coordinator.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.InteractionRuntime = Vendor.InteractionRuntime or {}
local InteractionRuntime = Vendor.InteractionRuntime

---@param state table
---@param deps table
---@return table
function InteractionRuntime.OnOpenStore(state, deps)
    deps.resetInteractionState()
    local nativeStoreBridge = deps.nativeStoreBridge

    local interactionType = deps.getInteractionType and deps.getInteractionType() or nil
    local allowNativeStableFallback = interactionType == nil
    state.isStableInteraction = state.isStableInteraction
        or interactionType == deps.interactionStable
        or (allowNativeStableFallback and deps.isNativeStableModeActive())
    deps.logVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenStore interaction=%s fence=%s stable=%s",
            tostring(interactionType), tostring(state.isFenceInteraction), tostring(state.isStableInteraction))
    )

    if interactionType and interactionType ~= deps.interactionVendor and interactionType ~= deps.interactionStable then
        nativeStoreBridge.RestoreSceneAlias()
        return state
    end

    nativeStoreBridge.AliasSceneToBetterUI(deps.instance)
    if deps.instance and deps.instance.ReleaseNativeStoreInputOwnership then
        deps.instance:ReleaseNativeStoreInputOwnership()
    end
    nativeStoreBridge.EnsureComponents("storeTextSearch")
    if not state.isStableInteraction and allowNativeStableFallback and deps.isNativeStableModeActive() then
        state.isStableInteraction = true
        nativeStoreBridge.EnsureComponents("storeTextSearch")
    end

    if deps.instance and deps.resetRuntimeState then
        deps.resetRuntimeState(deps.instance)
    end

    local targetMode = nativeStoreBridge.ResolveTargetMode()
    if targetMode then
        nativeStoreBridge.ApplyResolvedMode(targetMode, false)
    end
    deps.showScene()
    if targetMode then
        nativeStoreBridge.ScheduleOpenStoreSync(targetMode, 120)
    end

    return state
end

---@param state table
---@param deps table
---@param enableSell boolean|nil
---@param enableLaunder boolean|nil
---@return table
function InteractionRuntime.OnOpenFence(state, deps, enableSell, enableLaunder)
    deps.resetInteractionState()
    local nativeStoreBridge = deps.nativeStoreBridge
    state.isFenceInteraction = true
    state.fenceEnableSell = enableSell ~= false
    state.fenceEnableLaunder = enableLaunder ~= false
    deps.logVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenFence sell=%s launder=%s", tostring(state.fenceEnableSell), tostring(state.fenceEnableLaunder))
    )

    if not deps.instance then
        return state
    end

    if deps.instance and deps.resetRuntimeState then
        deps.resetRuntimeState(deps.instance)
    end
    nativeStoreBridge.AliasSceneToBetterUI(deps.instance)
    if deps.instance.ReleaseNativeStoreInputOwnership then
        deps.instance:ReleaseNativeStoreInputOwnership()
    end

    if state.fenceEnableSell then
        deps.instance:SetMode(deps.sellMode)
    elseif state.fenceEnableLaunder then
        deps.instance:SetMode(deps.fenceLaunderMode)
    end
    deps.showScene()

    return state
end

---@param state table
---@param deps table
---@return table
function InteractionRuntime.OnCloseStore(state, deps)
    local nativeStoreBridge = deps.nativeStoreBridge
    state.isClosing = true
    state.isFenceInteraction = false
    state.isStableInteraction = false
    state.fenceEnableSell = false
    state.fenceEnableLaunder = false
    state.sessionHasBuyMode = false
    state.openStoreSyncAttempt = 0

    if deps.instance then
        if deps.resetRuntimeState then
            deps.resetRuntimeState(deps.instance)
        end
        if deps.instance.DisableStablePreviewMode then
            deps.instance:DisableStablePreviewMode()
        end
    end

    deps.cancelRuntimeTasks()
    deps.logVendorDebug("SCENE_TRANSITIONS", "VendorScene", "OnCloseStore begin")
    deps.hideScene()

    if deps.instance and deps.instance.ReleaseNativeStoreInputOwnership then
        deps.instance:ReleaseNativeStoreInputOwnership()
    end
    if deps.instance and deps.instance.ForceReleaseDirectionalInput then
        deps.instance:ForceReleaseDirectionalInput()
    end

    local storeManager = deps.storeManager
    deps.logNativeStoreInputState("OnCloseStore:beforeSweep", storeManager)
    if storeManager and type(storeManager.OnHide) == "function" then
        deps.safeCall("Vendor.OnCloseStore:NativeOnHide", storeManager.OnHide, storeManager)
    end
    if storeManager then
        storeManager.activeComponents = {}
    end
    deps.logNativeStoreInputState("OnCloseStore:afterSweep", storeManager)
    deps.logVendorDebug("SCENE_TRANSITIONS", "VendorScene", "OnCloseStore complete")
    nativeStoreBridge.AliasSceneToBetterUI(deps.instance)

    return state
end
