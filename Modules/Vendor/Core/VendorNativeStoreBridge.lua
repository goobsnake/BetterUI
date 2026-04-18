--[[
File: Modules/Vendor/Core/VendorNativeStoreBridge.lua
Purpose: Own native-store reconciliation, component rebuild policy, and scene
         takeover so Vendor.lua can stay focused on scene orchestration.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.NativeStoreBridge = Vendor.NativeStoreBridge or {}
local NativeStoreBridge = Vendor.NativeStoreBridge

local function LogVendorDebug(flagName, category, message)
    if BETTERUI.Vendor and BETTERUI.Vendor.DebugLog then
        BETTERUI.Vendor.DebugLog(message, flagName, category)
    end
end

local function SafeCall(context, fn, ...)
    local executor = Vendor.ExecuteSafely
    if type(executor) == "function" then
        return executor(context, fn, ...)
    end
    if type(fn) ~= "function" then
        return false, nil
    end
    local ok, result = pcall(fn, ...)
    return ok, result
end

local function IsDirectionalInputListening(obj)
    if BETTERUI.Vendor and BETTERUI.Vendor.IsDirectionalInputListening then
        return BETTERUI.Vendor.IsDirectionalInputListening(obj)
    end
    return false
end

local function LogNativeStoreInputState(context, storeManager)
    if not storeManager then
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

local function GetActiveNativeStoreModes(storeManager)
    local modes = {}
    local seen = {}
    local activeComponents = storeManager.activeComponents
    if type(activeComponents) ~= "table" then
        return modes, seen
    end
    for _, component in ipairs(activeComponents) do
        if component and type(component.GetStoreMode) == "function" then
            local okMode, mode = SafeCall("Vendor.NativeStoreBridge:GetActiveMode", component.GetStoreMode, component)
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
    local includeBuy = Vendor._sessionHasBuyMode == true
        or (buyMode ~= nil and seenActiveModes[buyMode] == true)
    if not includeBuy and Vendor.HasVendorBuyInventory then
        includeBuy = Vendor.HasVendorBuyInventory("Vendor.NativeStoreBridge")
    end
    if includeBuy then
        Vendor._sessionHasBuyMode = true
    end

    local isStableInteraction = Vendor.IsStableInteraction and Vendor.IsStableInteraction() or false
    local isFenceInteraction = Vendor.IsFenceInteraction and Vendor.IsFenceInteraction() or false
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

local function ApplyRebuildPlan(snapshot, rebuildPlan)
    if #rebuildPlan.rebuiltModes == 0 then
        return false
    end

    local storeManager = snapshot.storeManager
    if storeManager.sceneName ~= "betterui_native_store_blocked" then
        storeManager.sceneName = "betterui_native_store_blocked"
    end

    SafeCall("Vendor.NativeStoreBridge:SetActiveComponents",
        storeManager.SetActiveComponents, storeManager, rebuildPlan.rebuiltModes, snapshot.searchContext)

    NeutralizeHeaderCallbacks(storeManager)
    if storeManager._currentList and storeManager._currentList.Deactivate then
        if not storeManager._currentList.IsActive or storeManager._currentList:IsActive() then
            storeManager._currentList:Deactivate()
        end
    end

    if snapshot.buyMode and rebuildPlan.modeSet[snapshot.buyMode] then
        if type(SetStoreMode) == "function" then
            SafeCall("Vendor.NativeStoreBridge:SetStoreMode", SetStoreMode, snapshot.buyMode)
        end
        if type(storeManager.SetMode) == "function" then
            SafeCall("Vendor.NativeStoreBridge:StoreManagerSetMode", storeManager.SetMode, storeManager, snapshot.buyMode)
        end
    end
    if type(storeManager.InitializeStore) == "function" then
        SafeCall("Vendor.NativeStoreBridge:InitializeStore", storeManager.InitializeStore, storeManager)
    end

    return true
end

local function ShouldAbortOpenStoreSync()
    if Vendor._isClosing then
        return true
    end
    if not Vendor.instance then
        return true
    end
    if Vendor.IsFenceInteraction and Vendor.IsFenceInteraction() then
        return true
    end
    if Vendor.instance.IsSceneActiveOrShowing and not Vendor.instance:IsSceneActiveOrShowing() then
        return true
    end
    return false
end

function NativeStoreBridge.SetSceneAlias(sceneObject)
    if not SCENE_MANAGER or not SCENE_MANAGER.scenes then
        return
    end
    SCENE_MANAGER.scenes["gamepad_store"] = sceneObject
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
    Vendor.nativeStoreScene = Vendor.nativeStoreScene or (SCENE_MANAGER and SCENE_MANAGER:GetScene("gamepad_store"))

    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if storeManager then
        storeManager.sceneName = "betterui_native_store_blocked"
        if storeManager.control then
            storeManager.control:UnregisterForEvent(EVENT_OPEN_STORE)
            storeManager.control:UnregisterForEvent(EVENT_CLOSE_STORE)
        end
        if EVENT_MANAGER then
            EVENT_MANAGER:UnregisterForEvent("ZO_StoreWindow_Gamepad", EVENT_OPEN_STORE)
            EVENT_MANAGER:UnregisterForEvent("ZO_StoreWindow_Gamepad", EVENT_CLOSE_STORE)
        end

        local origStoreManagerUpdateDI = storeManager.UpdateDirectionalInput
        storeManager.UpdateDirectionalInput = function(self, ...)
            local nativeScene = Vendor.nativeStoreScene
            if nativeScene and nativeScene.IsShowing and nativeScene:IsShowing() then
                if origStoreManagerUpdateDI then
                    return origStoreManagerUpdateDI(self, ...)
                end
            end
        end
    end

    if SCENE_MANAGER and ZO_PreHook then
        ZO_PreHook(SCENE_MANAGER, "Show", function(self, shownSceneName, ...)
            if shownSceneName == "gamepad_store" and instance and instance.scene then
                self.scenes["gamepad_store"] = instance.scene
            end
        end)
    end
end

function NativeStoreBridge.EnsureComponents(searchContext)
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
    if ApplyRebuildPlan(snapshot, rebuildPlan) then
        SweepDirectionalInput(snapshot.storeManager, true)
        LogNativeStoreInputState("NativeStoreBridge:postSweep", snapshot.storeManager)
    end
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

    local okMode, modeResult = SafeCall("Vendor.NativeStoreBridge:GetCurrentMode", storeManager.GetCurrentMode, storeManager)
    if okMode then
        return modeResult
    end
    return nil
end

function NativeStoreBridge.ScheduleOpenStoreSync(targetMode, delayMs)
    if not Vendor.Tasks then
        return
    end

    Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
    Vendor.Tasks:Schedule("ensureStoreComponentsOnOpen", delayMs or 120, function()
        if ShouldAbortOpenStoreSync() then
            return
        end

        NativeStoreBridge.EnsureComponents("storeTextSearch")
        if ShouldAbortOpenStoreSync() then
            return
        end

        local resolvedTargetMode = NativeStoreBridge.ResolveTargetMode()
        if resolvedTargetMode ~= targetMode then
            targetMode = resolvedTargetMode
        end
        if ShouldAbortOpenStoreSync() then
            return
        end

        NativeStoreBridge.ApplyResolvedMode(targetMode, true)

        local targetNativeMode = Vendor.ResolveNativeStoreMode and Vendor.ResolveNativeStoreMode(targetMode) or nil
        if targetNativeMode == nil or NativeStoreBridge.GetCurrentMode() == targetNativeMode then
            Vendor._openStoreSyncAttempt = 0
            return
        end

        local syncAttempt = (Vendor._openStoreSyncAttempt or 0) + 1
        Vendor._openStoreSyncAttempt = syncAttempt
        if syncAttempt <= 4 then
            NativeStoreBridge.ScheduleOpenStoreSync(targetMode, 140)
        end
    end)
end
