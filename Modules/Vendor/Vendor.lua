--[[
File: Modules/Vendor/Vendor.lua
Purpose: Main orchestrator for the Vendor module.

This file handles:
1. Creating the Vendor class instance and scene
2. Registering all components (Buy, Sell, Repair, Buyback, FenceSell, FenceLaunder)
3. Wiring EVENT_OPEN_STORE / EVENT_OPEN_FENCE / EVENT_CLOSE_STORE
4. Tab navigation (carousel or tab-bar)
5. Scene alias so BetterUI replaces the native gamepad_store scene

KEY MECHANICS:
  - EVENT_OPEN_STORE: Opens in BUY mode with Buy/Sell/Repair/Buyback tabs
  - EVENT_OPEN_FENCE: Opens with FenceSell/FenceLaunder tabs (no Buy/Repair/Buyback)
  - Tab switching calls VendorClass:SetMode() which routes to component Activate/Deactivate
  - Scene is created as ZO_InteractScene and aliased to gamepad_store
]]

-- LOCAL STATE
local Vendor      = BETTERUI.Vendor
local MODE        = Vendor.MODE
local EVENT_NS    = "BetterUI_Vendor"
local SafeCall

-- Tracks whether current interaction is fence (true) or regular store (false)
local isFenceInteraction = false
local isStableInteraction = false

-- Tracks which fence modes are enabled for the current fence interaction
local fenceEnableSell    = false
local fenceEnableLaunder = false
Vendor._sessionHasBuyMode = false

local SELL_ALL_JUNK_GAMEPAD_DIALOG_NAME = "BETTERUI_VENDOR_SELL_ALL_JUNK_DIALOG"

-- TAB DEFINITIONS

---@alias VendorTabDef {mode: number, name: fun(): string}

-- Regular vendor tabs (Buy, Sell, Repair, Buyback)
---@type VendorTabDef[]
local VENDOR_TABS = {
    { mode = MODE.BUY,     name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY")) end },
    { mode = MODE.SELL,    name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL")) end },
    { mode = MODE.REPAIR,  name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_REPAIR")) end },
    { mode = MODE.STABLE,  name = function() return GetString(rawget(_G, "SI_STABLE_STABLES_TAB")) end },
    { mode = MODE.BUYBACK, name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUYBACK")) end },
}

---@type VendorTabDef[]
local STABLE_TABS = {
    { mode = MODE.BUY,    name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY")) end },
    { mode = MODE.REPAIR, name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_REPAIR")) end },
    { mode = MODE.STABLE, name = function() return GetString(rawget(_G, "SI_STABLE_STABLES_TAB")) end },
}

-- Fence tabs (Sell Stolen, Launder)
---@type VendorTabDef[]
local FENCE_TABS = {
    { mode = MODE.FENCE_SELL,    name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_SELL")) end },
    { mode = MODE.FENCE_LAUNDER, name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER")) end },
}

local function ResolveNativeModeForVendorMode(mode)
    if mode == MODE.BUY then
        return rawget(_G, "ZO_MODE_STORE_BUY")
    elseif mode == MODE.SELL then
        return rawget(_G, "ZO_MODE_STORE_SELL")
    elseif mode == MODE.REPAIR then
        return rawget(_G, "ZO_MODE_STORE_REPAIR")
    elseif mode == MODE.BUYBACK then
        return rawget(_G, "ZO_MODE_STORE_BUY_BACK")
    elseif mode == MODE.FENCE_SELL then
        return rawget(_G, "ZO_MODE_STORE_SELL_STOLEN")
    elseif mode == MODE.FENCE_LAUNDER then
        return rawget(_G, "ZO_MODE_STORE_LAUNDER")
    elseif mode == MODE.STABLE then
        return rawget(_G, "ZO_MODE_STORE_STABLE")
    end
    return nil
end

local function GetNativeActiveModeSet()
    local modeSet = {}
    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    local activeComponents = storeManager and storeManager.activeComponents
    if type(activeComponents) ~= "table" then
        return modeSet
    end

    for _, component in ipairs(activeComponents) do
        if component and type(component.GetStoreMode) == "function" then
            local mode = component:GetStoreMode()
            if mode then
                modeSet[mode] = true
            end
        end
    end
    return modeSet
end

---@return boolean
local function IsNativeStableModeActive()
    local stableMode = rawget(_G, "ZO_MODE_STORE_STABLE")
    if not stableMode then
        return false
    end
    local nativeModeSet = GetNativeActiveModeSet()
    return nativeModeSet[stableMode] == true
end

-- GET ACTIVE TABS

--- Returns the tab list for the current interaction type.
---@return VendorTabDef[] tabs Active tab definitions
local function GetActiveTabs()
    if isFenceInteraction then
        local tabs = {}
        if fenceEnableSell then
            tabs[#tabs + 1] = FENCE_TABS[1]
        end
        if fenceEnableLaunder then
            tabs[#tabs + 1] = FENCE_TABS[2]
        end
        -- Safety: if no tabs enabled, fall back to sell
        if #tabs == 0 then
            tabs[1] = FENCE_TABS[1]
        end
        return tabs
    end

    local activeModeSet = GetNativeActiveModeSet()
    local includeBuyFromSession = Vendor._sessionHasBuyMode == true
    local sourceTabs = isStableInteraction and STABLE_TABS or VENDOR_TABS
    local tabs = {}
    for _, tab in ipairs(sourceTabs) do
        local nativeMode = ResolveNativeModeForVendorMode(tab.mode)
        local includeStableRepair = isStableInteraction
            and tab.mode == MODE.REPAIR
            and (type(CanStoreRepair) ~= "function" or CanStoreRepair())
        if (nativeMode and activeModeSet[nativeMode])
            or (tab.mode == MODE.BUY and includeBuyFromSession)
            or includeStableRepair then
            tabs[#tabs + 1] = tab
        end
    end

    if #tabs == 0 then
        -- Fall back to legacy behavior when native components are not ready yet.
        if isStableInteraction then
            return STABLE_TABS
        end
        return VENDOR_TABS
    end

    return tabs
end

---@param tabs VendorTabDef[]|nil
---@return table<number, boolean>
local function BuildActiveModeSet(tabs)
    if Vendor.BuildActiveModeSet then
        return Vendor.BuildActiveModeSet(tabs)
    end

    local fallbackModeSet = {}
    for _, tab in ipairs(tabs or {}) do
        if tab and tab.mode then
            fallbackModeSet[tab.mode] = true
        end
    end
    return fallbackModeSet
end

---@param modeSet table<number, boolean>|nil
---@return boolean
local function IsSellBuybackOnlyModeSet(modeSet)
    if Vendor.IsSellBuybackOnlyModeSet then
        return Vendor.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)
    end

    local fallback = modeSet or {}
    local hasSell = fallback[MODE.SELL] == true
    local hasBuyback = fallback[MODE.BUYBACK] == true
    local hasBuy = fallback[MODE.BUY] == true
    local hasRepair = fallback[MODE.REPAIR] == true
    return (not isFenceInteraction) and hasSell and hasBuyback and not hasBuy and not hasRepair
end

---@return boolean
local function IsSellBuybackOnlyStore()
    local modeSet = BuildActiveModeSet(GetActiveTabs())
    return IsSellBuybackOnlyModeSet(modeSet)
end

---@return number|nil firstMode
---@return number|nil secondMode
local function GetToggleModePair()
    if isFenceInteraction then
        return MODE.FENCE_SELL, MODE.FENCE_LAUNDER
    end

    if isStableInteraction then
        return MODE.BUY, MODE.STABLE
    end

    local modeSet = BuildActiveModeSet(GetActiveTabs())
    if modeSet[MODE.BUY] and modeSet[MODE.SELL] then
        return MODE.BUY, MODE.SELL
    end
    if modeSet[MODE.SELL] and Vendor._sessionHasBuyMode == true then
        return MODE.BUY, MODE.SELL
    end
    if IsSellBuybackOnlyModeSet(modeSet) then
        return MODE.SELL, MODE.BUYBACK
    end

    return nil, nil
end

---@param vendorInstance BETTERUI.Vendor.Class|nil
---@return table|nil
local function GetCurrentVendorTargetData(vendorInstance)
    local list = vendorInstance and vendorInstance.list
    if not list then
        return nil
    end

    if list.GetTargetData then
        return list:GetTargetData()
    end

    return list.selectedData
end

---@param tabs VendorTabDef[]|nil
---@return number targetMode
local function ResolveInitialStoreMode(tabs)
    tabs = tabs or {}

    local modeSet = BuildActiveModeSet(tabs)
    local nativeModeSet = GetNativeActiveModeSet()
    local nativeModesReady = next(nativeModeSet) ~= nil
    if nativeModesReady then
        modeSet = {}
        for _, tab in ipairs(VENDOR_TABS) do
            local nativeMode = ResolveNativeModeForVendorMode(tab.mode)
            if nativeMode and nativeModeSet[nativeMode] then
                modeSet[tab.mode] = true
            end
        end
        if modeSet[MODE.BUY] then
            Vendor._sessionHasBuyMode = true
        end
    end

    if IsSellBuybackOnlyModeSet(modeSet) then
        return MODE.SELL
    end

    if isStableInteraction then
        if modeSet[MODE.BUY] then
            Vendor._sessionHasBuyMode = true
            return MODE.BUY
        end
        local stableMode = rawget(_G, "ZO_MODE_STORE_STABLE")
        if nativeModesReady and stableMode and nativeModeSet[stableMode] then
            return MODE.STABLE
        end
        if modeSet[MODE.REPAIR] then
            return MODE.REPAIR
        end
        return MODE.BUY
    end

    -- When native components are not ready yet, do not trust transient buy-state APIs.
    -- Defaulting to SELL prevents opening personal vendors on an empty BUY list.
    if not nativeModesReady then
        if modeSet[MODE.SELL] then
            return MODE.SELL
        end
        if modeSet[MODE.BUYBACK] then
            return MODE.BUYBACK
        end
        if modeSet[MODE.REPAIR] then
            return MODE.REPAIR
        end
    end

    if nativeModesReady and modeSet[MODE.BUY] then
        local hasBuyList = false
        if type(IsStoreEmpty) == "function" then
            local okStoreEmpty, isStoreEmpty = SafeCall("Vendor.ResolveInitialStoreMode:IsStoreEmpty", IsStoreEmpty)
            if okStoreEmpty then
                hasBuyList = not isStoreEmpty
            end
        end
        if not hasBuyList and type(GetNumStoreItems) == "function" then
            local okStoreCount, storeCount = SafeCall("Vendor.ResolveInitialStoreMode:GetNumStoreItems", GetNumStoreItems)
            if okStoreCount and type(storeCount) == "number" then
                hasBuyList = storeCount > 0
            end
        end
        if hasBuyList then
            Vendor._sessionHasBuyMode = true
            return MODE.BUY
        end
    end

    if modeSet[MODE.SELL] then
        return MODE.SELL
    end
    if modeSet[MODE.BUYBACK] then
        return MODE.BUYBACK
    end
    if modeSet[MODE.REPAIR] then
        return MODE.REPAIR
    end

    return (tabs[1] and tabs[1].mode) or MODE.SELL
end

local function SetStoreSceneAlias(sceneObject)
    if not SCENE_MANAGER or not SCENE_MANAGER.scenes then
        return
    end
    SCENE_MANAGER.scenes["gamepad_store"] = sceneObject
end

local function RestoreNativeStoreSceneAlias()
    if Vendor.nativeStoreScene then
        SetStoreSceneAlias(Vendor.nativeStoreScene)
    end
end

local function AliasStoreSceneToBetterUI()
    if Vendor.instance and Vendor.instance.scene then
        SetStoreSceneAlias(Vendor.instance.scene)
    end
end

function SafeCall(context, fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end

    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute then
        return BETTERUI.CIM.SafeExecute(context, fn, ...)
    end

    local ok, result = pcall(fn, ...)
    return ok, result
end

local function LogVendorDebug(flagName, category, message)
    if BETTERUI.Vendor and BETTERUI.Vendor.DebugLog then
        BETTERUI.Vendor.DebugLog(message, flagName, category)
    end
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

local function EnsureNativeStoreComponents(searchContext)
    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if not storeManager or type(storeManager.SetActiveComponents) ~= "function" then
        return
    end

    local buyMode = rawget(_G, "ZO_MODE_STORE_BUY")
    local sellMode = rawget(_G, "ZO_MODE_STORE_SELL")
    local sellVengeanceMode = rawget(_G, "ZO_MODE_STORE_SELL_VENGEANCE")
    local buyBackMode = rawget(_G, "ZO_MODE_STORE_BUY_BACK")
    local repairMode = rawget(_G, "ZO_MODE_STORE_REPAIR")
    local stableMode = rawget(_G, "ZO_MODE_STORE_STABLE")
    local availableComponents = storeManager.components or {}

    local function GetActiveModes()
        local modes = {}
        local seen = {}
        local activeComponents = storeManager.activeComponents
        if type(activeComponents) ~= "table" then
            return modes, seen
        end
        for _, component in ipairs(activeComponents) do
            if component and type(component.GetStoreMode) == "function" then
                local okMode, mode = SafeCall("Vendor.EnsureNativeStoreComponents:GetActiveMode", component.GetStoreMode, component)
                if okMode and mode and not seen[mode] then
                    seen[mode] = true
                    modes[#modes + 1] = mode
                end
            end
        end
        return modes, seen
    end

    local componentTable, seenActiveModes = GetActiveModes()
    local includeBuy = Vendor._sessionHasBuyMode == true
        or (buyMode ~= nil and seenActiveModes[buyMode] == true)
    if not includeBuy and type(IsStoreEmpty) == "function" then
        local okStoreEmpty, isStoreEmpty = SafeCall("Vendor.EnsureNativeStoreComponents:IsStoreEmpty", IsStoreEmpty)
        if okStoreEmpty then
            includeBuy = not isStoreEmpty
        end
    end
    if not includeBuy and type(GetNumStoreItems) == "function" then
        local okStoreCount, storeCount = SafeCall("Vendor.EnsureNativeStoreComponents:GetNumStoreItems", GetNumStoreItems)
        if okStoreCount and type(storeCount) == "number" then
            includeBuy = storeCount > 0
        end
    end
    if includeBuy then
        Vendor._sessionHasBuyMode = true
    end

    local needRebuild = false
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
    LogVendorDebug(
        "DIRECTIONAL_INPUT",
        "VendorDI",
        string.format(
            "EnsureNativeStoreComponents(%s): rebuild=%s includeBuy=%s activeModes=%d",
            tostring(searchContext or "storeTextSearch"),
            tostring(needRebuild),
            tostring(includeBuy),
            #componentTable
        )
    )
    if not needRebuild then
        -- Even when no rebuild is needed, sweep the storeManager off DI.
        -- An earlier SetActiveComponents call or native code path may have
        -- registered it via DIRECTIONAL_INPUT:Activate directly (bypassing the
        -- object's active flag), so obj:Deactivate() alone is not reliable.
        if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Deactivate then
            if DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT:IsListening(storeManager) then
                DIRECTIONAL_INPUT:Deactivate(storeManager)
            end
        end
        LogNativeStoreInputState("EnsureNativeStoreComponents:skipRebuild", storeManager)
        return
    end

    local modeSet = {}
    local rebuiltModes = {}
    local function AddMode(mode)
        if mode and not modeSet[mode] and availableComponents[mode] then
            modeSet[mode] = true
            rebuiltModes[#rebuiltModes + 1] = mode
        end
    end

    -- Rebuild from vanilla rules when active components are missing or incomplete.
    if isStableInteraction then
        if includeBuy then
            AddMode(buyMode)
        end
        AddMode(stableMode)
        if repairMode and (type(CanStoreRepair) ~= "function" or CanStoreRepair()) then
            AddMode(repairMode)
        end
    else
        if includeBuy then
            AddMode(buyMode)
        end
        AddMode(sellMode)
        if sellVengeanceMode and type(IsCurrentCampaignVengeanceRuleset) == "function"
            and IsCurrentCampaignVengeanceRuleset() and rawget(_G, "ZO_VENGEANCE_BAG_SELL_ENABLED") then
            AddMode(sellVengeanceMode)
        end
        AddMode(buyBackMode)
        if repairMode and (type(CanStoreRepair) ~= "function" or CanStoreRepair()) then
            AddMode(repairMode)
        end
    end

    for _, mode in ipairs(componentTable) do
        if isStableInteraction then
            if mode == buyMode
                or mode == repairMode
                or mode == stableMode then
                AddMode(mode)
            end
        elseif mode ~= stableMode then
            AddMode(mode)
        end
    end

    if #rebuiltModes > 0 then
        -- Ensure storeManager.sceneName is redirected before SetActiveComponents.
        -- SetActiveComponents \u2192 RebuildHeaderTabs \u2192 Commit() triggers ShowComponent
        -- via the SelectedDataChanged callback chain; the redirected sceneName makes
        -- ShowComponent's IsShowing check fail so no native lists are activated on DI.
        if storeManager.sceneName ~= "betterui_native_store_blocked" then
            storeManager.sceneName = "betterui_native_store_blocked"
        end

        SafeCall("Vendor.EnsureNativeStoreComponents:SetActiveComponents",
            storeManager.SetActiveComponents, storeManager, rebuiltModes, searchContext or "storeTextSearch")

        -- Neutralize native tabBar callbacks that SetActiveComponents just installed.
        -- RebuildHeaderTabs sets an activatedCallback (ShowComponent) and a
        -- SelectedDataChanged callback (OnCategoryChanged \u2192 ShowComponent) on the
        -- native header's tabBar. Clear both so no future activation/selection change
        -- can re-activate native lists on DIRECTIONAL_INPUT.
        local nativeHeader = storeManager.header
        if nativeHeader and nativeHeader.tabBar then
            local nativeTabBar = nativeHeader.tabBar
            if nativeTabBar.SetOnActivatedChangedFunction then
                nativeTabBar:SetOnActivatedChangedFunction(nil)
            end
            if nativeTabBar.RemoveAllOnSelectedDataChangedCallbacks then
                nativeTabBar:RemoveAllOnSelectedDataChangedCallbacks()
            end
            -- Deactivate the native tabBar if SetActiveComponents activated it.
            if nativeTabBar.IsActive and nativeTabBar:IsActive() and nativeTabBar.Deactivate then
                nativeTabBar:Deactivate()
            end
        end
        -- Deactivate any native list that ShowComponent may have activated before
        -- the sceneName redirect took effect (timing edge on very first open).
        if storeManager._currentList and storeManager._currentList.Deactivate then
            if not storeManager._currentList.IsActive or storeManager._currentList:IsActive() then
                storeManager._currentList:Deactivate()
            end
        end

        if buyMode and modeSet[buyMode] then
            if type(SetStoreMode) == "function" then
                SafeCall("Vendor.EnsureNativeStoreComponents:SetStoreMode", SetStoreMode, buyMode)
            end
            if type(storeManager.SetMode) == "function" then
                SafeCall("Vendor.EnsureNativeStoreComponents:StoreManagerSetMode", storeManager.SetMode, storeManager, buyMode)
            end
        end
        if type(storeManager.InitializeStore) == "function" then
            SafeCall("Vendor.EnsureNativeStoreComponents:InitializeStore", storeManager.InitializeStore, storeManager)
        end

        -- Final DI sweep: deactivate the native storeManager and every native
        -- component list from DIRECTIONAL_INPUT using direct API calls.  This
        -- bypasses the objects' internal active-flag guards (Deactivate() is a
        -- no-op when .active is already false) and catches any code path inside
        -- SetActiveComponents / SetMode / InitializeStore that may have
        -- registered objects via DIRECTIONAL_INPUT:Activate directly.
        if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Deactivate then
            if DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT:IsListening(storeManager) then
                DIRECTIONAL_INPUT:Deactivate(storeManager)
            end
            -- Sweep native component lists — component:Refresh() may have
            -- activated them via OnEffectivelyShown handlers.
            local activeComps = storeManager.activeComponents
            if type(activeComps) == "table" then
                for _, comp in ipairs(activeComps) do
                    if comp and comp.list and DIRECTIONAL_INPUT.IsListening
                        and DIRECTIONAL_INPUT:IsListening(comp.list) then
                        DIRECTIONAL_INPUT:Deactivate(comp.list)
                    end
                end
            end
            -- Also sweep _currentList if it differs from any component list.
            if storeManager._currentList and DIRECTIONAL_INPUT.IsListening
                and DIRECTIONAL_INPUT:IsListening(storeManager._currentList) then
                DIRECTIONAL_INPUT:Deactivate(storeManager._currentList)
            end
            -- Sweep headerFocus.
            if storeManager.headerFocus and DIRECTIONAL_INPUT.IsListening
                and DIRECTIONAL_INPUT:IsListening(storeManager.headerFocus) then
                DIRECTIONAL_INPUT:Deactivate(storeManager.headerFocus)
            end
        end
        LogNativeStoreInputState("EnsureNativeStoreComponents:postSweep", storeManager)
    end
end

Vendor.EnsureNativeStoreComponents = EnsureNativeStoreComponents

---@return boolean
local function ShouldAbortOpenStoreSync()
    if Vendor._isClosing then
        return true
    end
    if not Vendor.instance then
        return true
    end
    if isFenceInteraction then
        return true
    end
    if Vendor.instance.IsSceneActiveOrShowing and not Vendor.instance:IsSceneActiveOrShowing() then
        return true
    end
    return false
end
---@param expectedMode number|nil
---@return boolean
local function ShouldAbortDeferredVendorRefresh(vendorInstance, expectedMode)
    if Vendor._isClosing then
        LogVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "Deferred vendor refresh aborted: vendor is closing")
        return true
    end
    if not vendorInstance then
        LogVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "Deferred vendor refresh aborted: missing vendor instance")
        return true
    end
    if expectedMode and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() ~= expectedMode then
        LogVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "Deferred vendor refresh aborted: mode changed")
        return true
    end
    if vendorInstance.IsSceneShowing then
        local isShowing = vendorInstance:IsSceneShowing()
        if not isShowing then
            LogVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "Deferred vendor refresh aborted: scene is not fully showing")
        end
        return not isShowing
    end
    if vendorInstance.IsSceneActiveOrShowing then
        local isActive = vendorInstance:IsSceneActiveOrShowing()
        if not isActive then
            LogVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "Deferred vendor refresh aborted: scene is no longer active")
        end
        return not isActive
    end
    return false
end

Vendor.ShouldAbortDeferredVendorRefresh = ShouldAbortDeferredVendorRefresh

local STABLE_TRAIN_ORDER = {
    RIDING_TRAIN_SPEED,
    RIDING_TRAIN_STAMINA,
    RIDING_TRAIN_CARRYING_CAPACITY,
}

local DEFAULT_STABLE_INTERACTION_ICON = "EsoUI/Art/Collections/Default/collections_default_mount.dds"

local function ResolveStableInteractionIcon()
    return DEFAULT_STABLE_INTERACTION_ICON
end

local function BuildStableTrainingIcon(trainingType)
    if STABLE_TRAINING_TEXTURES_GAMEPAD then
        return STABLE_TRAINING_TEXTURES_GAMEPAD[trainingType]
    end
    return nil
end

local function IsStableSkillTrainable(trainingType, bonus, maxBonus)
    if not trainingType then
        return false
    end
    if (bonus or 0) >= (maxBonus or 0) then
        return false
    end
    if type(GetTimeUntilCanBeTrained) == "function" and GetTimeUntilCanBeTrained() ~= 0 then
        return false
    end
    if STABLE_MANAGER and STABLE_MANAGER.CanAffordTraining then
        return STABLE_MANAGER:CanAffordTraining()
    end
    return false
end

local function BuildStableTrainingStateText(isAtMax, timeUntilCanTrain)
    if isAtMax then
        return "MAX"
    end
    if (timeUntilCanTrain or 0) == 0 then
        return GetString(rawget(_G, "SI_GAMEPAD_STABLE_TRAINABLE_READY") or "SI_GAMEPAD_STABLE_TRAINABLE_READY")
    end
    if ZO_FormatTimeMilliseconds then
        return ZO_FormatTimeMilliseconds(
            timeUntilCanTrain,
            TIME_FORMAT_STYLE_COLONS,
            TIME_FORMAT_PRECISION_TWELVE_HOUR
        )
    end
    return "-"
end

local function BuildStableTrainingValueText(trainingCost, canAfford, isAtMax)
    if isAtMax or (trainingCost or 0) <= 0 then
        return "-"
    end

    if ZO_Currency_FormatGamepad then
        local format = canAfford and ZO_CURRENCY_FORMAT_WHITE_AMOUNT_ICON or ZO_CURRENCY_FORMAT_ERROR_AMOUNT_ICON
        return ZO_Currency_FormatGamepad(CURT_MONEY, trainingCost, format)
    end

    return tostring(trainingCost)
end

Vendor.StableTrainingComponent = Vendor.StableTrainingComponent or {}
local StableTraining = Vendor.StableTrainingComponent

function StableTraining:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

function StableTraining:Deactivate(_vendorInstance)
    -- No teardown required.
end

function StableTraining:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_GAMEPAD_STABLE_TRAIN") or "SI_GAMEPAD_STABLE_TRAIN")
end

function StableTraining:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then
        return false
    end
    local ds = selectedData.dataSource or selectedData
    return ds and ds.isSkillTrainable == true
end

---@param _vendorInstance BETTERUI.Vendor.Class
---@return table[]
function StableTraining:GetCategories(_vendorInstance)
    return {
        {
            key = "stable_all",
            name = GetString(rawget(_G, "SI_STATS_RIDING_SKILL") or "SI_STATS_RIDING_SKILL"),
            iconFile = ResolveStableInteractionIcon(),
            itemCount = #STABLE_TRAIN_ORDER,
        },
    }
end

function StableTraining:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then
        return
    end
    local ds = selectedData.dataSource or selectedData
    if not (ds and ds.trainingType and ds.isSkillTrainable) then
        return
    end

    TrainRiding(ds.trainingType)
    vendorInstance:RefreshList()
end

function StableTraining:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then
        return
    end

    local searchQuery = Vendor.GetNormalizedSearchQuery and Vendor.GetNormalizedSearchQuery(vendorInstance) or nil
    local skillHeader = GetString(rawget(_G, "SI_STATS_RIDING_SKILL") or "SI_STATS_RIDING_SKILL")
    local trainingCost = (type(GetTrainingCost) == "function" and GetTrainingCost()) or 0
    local timeUntilCanTrain = (type(GetTimeUntilCanBeTrained) == "function" and GetTimeUntilCanBeTrained()) or 0
    local canAffordTraining = (STABLE_MANAGER and STABLE_MANAGER.CanAffordTraining and STABLE_MANAGER:CanAffordTraining()) or false
    local isTrainWindowOpen = timeUntilCanTrain == 0

    for _, trainingType in ipairs(STABLE_TRAIN_ORDER) do
        local bonus, maxBonus = 0, 0
        if STABLE_MANAGER and STABLE_MANAGER.GetStats then
            bonus, maxBonus = STABLE_MANAGER:GetStats(trainingType)
        end
        local isAtMax = (bonus or 0) >= (maxBonus or 0)

        local formatStringId = trainingType == RIDING_TRAIN_SPEED
            and (rawget(_G, "SI_MOUNT_ATTRIBUTE_SPEED_FORMAT") or "SI_MOUNT_ATTRIBUTE_SPEED_FORMAT")
            or (rawget(_G, "SI_MOUNT_ATTRIBUTE_SIMPLE_FORMAT") or "SI_MOUNT_ATTRIBUTE_SIMPLE_FORMAT")
        local statText = zo_strformat(formatStringId, bonus or 0)
        local trainingName = GetString("SI_RIDINGTRAINTYPE", trainingType)
        local icon = BuildStableTrainingIcon(trainingType)
        local trainable = IsStableSkillTrainable(trainingType, bonus, maxBonus)
        local stableStateText = BuildStableTrainingStateText(isAtMax, timeUntilCanTrain)
        local valueText = BuildStableTrainingValueText(trainingCost, canAffordTraining, isAtMax)
        local matchesSearch = (not Vendor.MatchesSearchQuery) or Vendor.MatchesSearchQuery(searchQuery, trainingName)

        if matchesSearch then
            local rowData = {
                name = trainingName,
                icon = icon,
                price = (isTrainWindowOpen and not isAtMax) and trainingCost or 0,
                stackCount = 1,
                stack = 1,
                trainingType = trainingType,
                bonus = bonus or 0,
                maxBonus = maxBonus or 0,
                isSkillTrainable = trainable,
                trainStateText = stableStateText,
                valueText = valueText,
                bestGamepadItemCategoryName = skillHeader,
                statValue = statText,
            }

            local entry = ZO_GamepadEntryData:New(rowData.name, rowData.icon)
            entry:SetDataSource(rowData)
            entry.narrationText = function()
                return rowData.name
            end

            list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
        end
    end
end

-- KEYBINDS

-- Forward declarations for helper callbacks referenced from keybind descriptors.
-- Without these declarations Lua resolves names as globals inside closures.
local IsMultiSelectAvailable
local GetMultiSelectKeybindName
local CanMultiSelectInCurrentMode
local RegisterVendorBatchDialog

---@param vendorInstance BETTERUI.Vendor.Class
---@return table keybindGroup Core keybind descriptor group
local function BuildCoreKeybinds(vendorInstance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            ethereal = true,
            visible = function()
                if vendorInstance.headerGeneric and vendorInstance.headerGeneric.tabBar then
                    return false
                end
                if vendorInstance._vendorHeaderEntryCount and vendorInstance._vendorHeaderEntryCount > 1 then
                    return true
                end
                return #GetActiveTabs() > 1
            end,
            callback = function()
                vendorInstance:CycleTabs(-1)
            end,
        },
        {
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            ethereal = true,
            visible = function()
                if vendorInstance.headerGeneric and vendorInstance.headerGeneric.tabBar then
                    return false
                end
                if vendorInstance._vendorHeaderEntryCount and vendorInstance._vendorHeaderEntryCount > 1 then
                    return true
                end
                return #GetActiveTabs() > 1
            end,
            callback = function()
                vendorInstance:CycleTabs(1)
            end,
        },
        -- Primary action (keybind A / GAMEPAD_BUTTON_1)
        {
            name = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    local selectedData = GetCurrentVendorTargetData(vendorInstance)
                    if selectedData and ms:IsSelected(selectedData) then
                        return GetString(rawget(_G, "SI_BETTERUI_DESELECT_ITEM") or "SI_BETTERUI_DESELECT_ITEM")
                    end

                    local selectedCount = ms.GetSelectedCount and ms:GetSelectedCount() or 0
                    local selectWithCount = rawget(_G, "SI_BETTERUI_SELECT_WITH_COUNT")
                    if selectWithCount then
                        return zo_strformat(GetString(selectWithCount), selectedCount)
                    end

                    return GetString(SI_GAMEPAD_SELECT_OPTION)
                end
                local component = vendorInstance:GetActiveComponent()
                if component and component.GetPrimaryActionName then
                    return component:GetPrimaryActionName(vendorInstance)
                end
                return GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION"))
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    local selectedData = GetCurrentVendorTargetData(vendorInstance)
                    if selectedData then
                        vendorInstance:SaveListPosition()
                        ms:ToggleSelection(selectedData)
                        vendorInstance:RefreshList()
                        vendorInstance:EnsureListInputActive()
                    end
                    return
                end
                local component = vendorInstance:GetActiveComponent()
                if component and component.OnPrimaryAction then
                    component:OnPrimaryAction(vendorInstance)
                end
            end,
            enabled = function()
                local ms = Vendor.multiSelectManager
                local selectedData = GetCurrentVendorTargetData(vendorInstance)
                if ms and ms:IsActive() then
                    return selectedData ~= nil
                end

                local component = vendorInstance:GetActiveComponent()
                if component and component.IsPrimaryActionEnabled then
                    return component:IsPrimaryActionEnabled(vendorInstance)
                end
                return selectedData ~= nil
            end,
        },
        -- Secondary action (Switch Buy/Sell lists)
        {
            name = function()
                return GetString(rawget(_G, "SI_BETTERUI_BANKING_TOGGLE_LIST") or "SI_BETTERUI_BANKING_TOGGLE_LIST")
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then return false end
                local firstMode, secondMode = GetToggleModePair()
                if not firstMode or not secondMode then
                    return false
                end
                return true
            end,
            enabled = function()
                local firstMode, secondMode = GetToggleModePair()
                if not firstMode or not secondMode then
                    return false
                end
                return true
            end,
            callback = function()
                vendorInstance:ToggleBuySellMode()
            end,
        },
        -- Quaternary action (Clear search when active)
        BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(
            function()
                if not (vendorInstance.textSearchHeaderControl and not vendorInstance.textSearchHeaderControl:IsHidden()) then
                    return
                end
                if vendorInstance.ClearTextSearch then
                    vendorInstance:ClearTextSearch()
                end
                if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
            function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then return false end
                return vendorInstance.textSearchHeaderControl ~= nil and not vendorInstance.textSearchHeaderControl:IsHidden()
            end,
            function()
                return vendorInstance.searchQuery and vendorInstance.searchQuery ~= ""
            end
        ),
        -- Tertiary action (Item Actions / Batch Actions in multi-select)
        {
            name = function()
                local defaultActionLabel = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND") or "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND")
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return defaultActionLabel
                end

                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.REPAIR then
                    local repairAllStringId = rawget(_G, "SI_BETTERUI_VENDOR_REPAIR_ALL")
                    if repairAllStringId then
                        return GetString(repairAllStringId)
                    end
                    return "Repair All"
                end
                if mode == MODE.SELL then
                    return GetString(rawget(_G, "SI_SELL_ALL_JUNK_KEYBIND_TEXT") or "SI_SELL_ALL_JUNK_KEYBIND_TEXT")
                end

                return defaultActionLabel
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return CanMultiSelectInCurrentMode() and ms:HasSelections()
                end
                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.SELL then
                    return Vendor.GetSetting("enableBatchJunkSell") ~= false
                end
                if mode == MODE.REPAIR then
                    local repairAllCost = GetRepairAllCost and GetRepairAllCost() or 0
                    return repairAllCost > 0
                end
                return false
            end,
            enabled = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return ms:HasSelections()
                end
                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.SELL then
                    local _, itemCount = Vendor.GetJunkSellSummary()
                    return itemCount > 0
                end
                if mode == MODE.REPAIR then
                    local repairAllCost = GetRepairAllCost and GetRepairAllCost() or 0
                    if repairAllCost <= 0 then
                        return false
                    end
                    if vendorInstance:CanAfford(repairAllCost) then
                        return true
                    end
                    return false, GetString(rawget(_G, "SI_REPAIR_ALL_CANNOT_AFFORD") or "SI_REPAIR_ALL_CANNOT_AFFORD")
                end
                return false
            end,
            callback = function()
                -- During batch processing, Y aborts
                if Vendor._batchProcessing then
                    Vendor.RequestBatchAbort()
                    return
                end
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    SafeCall("Vendor.RegisterBatchDialog", RegisterVendorBatchDialog)
                    if ZO_Dialogs_ShowGamepadDialog then
                        ZO_Dialogs_ShowGamepadDialog("BETTERUI_VENDOR_BATCH_DIALOG")
                    end
                    return
                end
                local component = vendorInstance:GetActiveComponent()
                if not component then return end
                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.SELL and component.SellAllJunk then
                    Vendor.ShowSellAllJunkDialog(vendorInstance, component)
                    return
                end
                if mode == MODE.REPAIR and component.RepairAll then
                    component:RepairAll(vendorInstance)
                end
            end,
        },
        -- Quinary: Enter/Exit Multi-Select
        {
            name = function() return GetMultiSelectKeybindName() end,
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return false
                end
                return CanMultiSelectInCurrentMode() and IsMultiSelectAvailable()
            end,
            callback = function()
                local ms = Vendor.multiSelectManager
                if not ms then return end
                if not ms:IsActive() then
                    vendorInstance:SaveListPosition()
                    ms:EnterSelectionMode()
                    local target = GetCurrentVendorTargetData(vendorInstance)
                    if target and ms.Select then
                        ms:Select(target)
                    elseif target then
                        ms:ToggleSelection(target)
                    end
                    vendorInstance:RefreshList()
                    vendorInstance:EnsureListInputActive()
                end
                if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- Preview toggle
        {
            name = function()
                if ITEM_PREVIEW_GAMEPAD and ITEM_PREVIEW_GAMEPAD.IsInteractionCameraPreviewEnabled
                    and ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
                    return GetString(rawget(_G, "SI_CRAFTING_EXIT_PREVIEW_MODE") or "SI_CRAFTING_EXIT_PREVIEW_MODE")
                end
                return GetString(rawget(_G, "SI_CRAFTING_ENTER_PREVIEW_MODE") or "SI_CRAFTING_ENTER_PREVIEW_MODE")
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = function()
                if not (vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() == MODE.BUY) then
                    return false
                end

                local selectedData = GetCurrentVendorTargetData(vendorInstance)
                if isStableInteraction then
                    if vendorInstance.CanPreviewStableStoreEntry then
                        return vendorInstance:CanPreviewStableStoreEntry(selectedData)
                    end
                    return false
                end

                if vendorInstance.CanPreviewVendorStoreEntry then
                    return vendorInstance:CanPreviewVendorStoreEntry(selectedData)
                end
                return false
            end,
            enabled = function()
                return true
            end,
            callback = function()
                if isStableInteraction then
                    if vendorInstance.ToggleStablePreviewMode then
                        vendorInstance:ToggleStablePreviewMode()
                    end
                else
                    if vendorInstance.ToggleVendorStorePreviewMode then
                        vendorInstance:ToggleVendorStorePreviewMode()
                    end
                end
                if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- Fence-only: Stack All Items (left stick)
        {
            name = GetString(rawget(_G, "SI_ITEM_ACTION_STACK_ALL") or "SI_ITEM_ACTION_STACK_ALL"),
            keybind = "UI_SHORTCUT_LEFT_STICK",
            visible = function()
                return isFenceInteraction
            end,
            enabled = function()
                return isFenceInteraction
            end,
            callback = function()
                StackBag(BAG_BACKPACK)
            end,
        },
        -- Back / Exit (keybind B / GAMEPAD_BUTTON_2)
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    vendorInstance:SaveListPosition()
                    ms:ExitSelectionMode()
                    vendorInstance:RefreshList()
                    vendorInstance:EnsureListInputActive()
                    if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                    end
                    return
                end
                -- Close the interaction
                SCENE_MANAGER:HideCurrentScene()
            end,
        },
    }
end

-- MULTI-SELECT HELPERS

IsMultiSelectAvailable = function()
    local instance = Vendor.instance
    return instance and instance.list and instance.list:GetNumItems() > 0
end

GetMultiSelectKeybindName = function()
    return GetString(rawget(_G, "SI_BETTERUI_MULTI_SELECT") or "SI_BETTERUI_MULTI_SELECT")
end

CanMultiSelectInCurrentMode = function()
    local mode = Vendor.instance and Vendor.instance:GetCurrentMode()
    if not mode then return false end
    if mode == MODE.BUY then
        return not isStableInteraction
    end
    return mode == MODE.SELL
        or mode == MODE.FENCE_SELL
        or mode == MODE.FENCE_LAUNDER
        or mode == MODE.BUYBACK
end

function Vendor.ExecuteBatchAction(mode, itemData)
    local ds = itemData.dataSource or itemData
    if mode == MODE.BUY then
        local entryIndex = ds.entryIndex or ds.slotIndex
        if not entryIndex then return end
        local vendorInstance = Vendor.instance
        if vendorInstance then
            local price = ds.price or 0
            local currencyType = ds.currencyType or ds.currencyType1 or CURT_MONEY
            if currencyType == CURT_NONE then
                currencyType = CURT_MONEY
            end
            if not vendorInstance:CanAfford(price, currencyType) then return end
            if not vendorInstance:HasInventorySpace() then return end
        end
        BuyStoreItem(entryIndex, 1)
    elseif mode == MODE.SELL then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                SellInventoryItem(bagId, slotIndex, stackSize)
            end
        end
    elseif mode == MODE.FENCE_SELL then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local funcQuality = GetItemFunctionalQuality and GetItemFunctionalQuality(bagId, slotIndex)
            if funcQuality and funcQuality >= ITEM_FUNCTIONAL_QUALITY_ARTIFACT then
                return
            end
            local remaining = 0
            if GetFenceSellTransactionInfo then
                local totalSells, sellsUsed = GetFenceSellTransactionInfo()
                remaining = zo_max((totalSells or 0) - (sellsUsed or 0), 0)
            end
            if remaining <= 0 then return end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                SellInventoryItem(bagId, slotIndex, stackSize)
            end
        end
    elseif mode == MODE.FENCE_LAUNDER then
        local bagId = ds.bagId
        local slotIndex = ds.slotIndex
        if bagId and slotIndex then
            local remaining = 0
            if GetFenceLaunderTransactionInfo then
                local totalLaunders, laundersUsed = GetFenceLaunderTransactionInfo()
                remaining = zo_max((totalLaunders or 0) - (laundersUsed or 0), 0)
            end
            if remaining <= 0 then return end
            local cost = GetItemLaunderPrice and GetItemLaunderPrice(bagId, slotIndex) or 0
            if Vendor.instance and not Vendor.instance:CanAfford(cost) then return end
            local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
            if stackSize > 0 then
                LaunderItem(bagId, slotIndex, stackSize)
            end
        end
    elseif mode == MODE.BUYBACK then
        local entryIndex = ds.entryIndex
        if entryIndex then
            local vendorInstance = Vendor.instance
            if vendorInstance then
                local price = ds.price or 0
                if not vendorInstance:CanAfford(price) then return end
                if not vendorInstance:HasInventorySpace() then return end
            end
            BuybackItem(entryIndex)
        end
    end
end

-- VENDOR BATCH OPTIONS (server-bound throttling, matching banking/inventory pacing)
local VENDOR_BATCH_OPTIONS = {
    serverBound          = true,
    minServerDelayMs     = 145,
    maxServerDelayMs     = 330,
    cooldownEvery        = 18,
    cooldownMs           = 1200,
    chunkCostUnits       = 32,
    chunkPauseMs         = 1000,
    jitterMs             = 18,
}

--- Processes vendor batch actions through a throttled pipeline with overlay progress.
--- Works for all vendor modes including BUY/BUYBACK (which lack bagId/slotIndex).
---@param mode number Vendor mode constant (MODE.BUY, MODE.SELL, etc.)
---@param items table[] Array of selected item data tables
---@param onComplete function|nil Callback invoked when processing finishes
function Vendor.ExecuteBatchThrottled(mode, items, onComplete)
    local BatchOverlay = BETTERUI.CIM.BatchOverlay
    local BatchConfig = BETTERUI.CIM.BatchConfig

    local totalItems = #items
    if totalItems == 0 then
        if onComplete then onComplete() end
        return
    end

    -- BUYBACK FIX: Process highest entryIndex first so removals don't
    -- invalidate lower indices that haven't been processed yet.
    if mode == MODE.BUYBACK then
        table.sort(items, function(a, b)
            local dsA = a.dataSource or a
            local dsB = b.dataSource or b
            return (dsA.entryIndex or 0) > (dsB.entryIndex or 0)
        end)
    end

    -- Prevent re-entry
    if Vendor._batchProcessing then return end
    Vendor._batchProcessing = true
    Vendor._batchAbortRequested = false

    -- Resolve display name for the overlay
    local actionName
    if mode == MODE.BUY then
        actionName = GetString(rawget(_G, "SI_ITEM_ACTION_BUY") or "SI_ITEM_ACTION_BUY")
    elseif mode == MODE.SELL or mode == MODE.FENCE_SELL then
        actionName = GetString(rawget(_G, "SI_ITEM_ACTION_SELL") or "SI_ITEM_ACTION_SELL")
    elseif mode == MODE.FENCE_LAUNDER then
        actionName = GetString(rawget(_G, "SI_ITEM_ACTION_LAUNDER") or "SI_ITEM_ACTION_LAUNDER")
    elseif mode == MODE.BUYBACK then
        actionName = GetString(rawget(_G, "SI_ITEM_ACTION_BUYBACK") or "SI_ITEM_ACTION_BUYBACK")
    else
        actionName = GetString(rawget(_G, "SI_BETTERUI_BATCH_ACTIONS") or "SI_BETTERUI_BATCH_ACTIONS")
    end

    -- Resolve throttle profile
    local throttleProfile = BatchConfig.ResolveBatchThrottleProfile(totalItems)
    local baseDelayMs = throttleProfile.DELAY_MS or 100
    local showProgress = throttleProfile.SHOW_PROGRESS == true or totalItems >= 10
    local opts = VENDOR_BATCH_OPTIONS
    local minDelay = opts.minServerDelayMs or 145
    local maxDelay = opts.maxServerDelayMs or 330
    local cooldownEvery = opts.cooldownEvery or 18
    local cooldownMs = opts.cooldownMs or 1200
    local chunkCostUnits = opts.chunkCostUnits or 32
    local chunkPauseMs = opts.chunkPauseMs or 1000
    local jitterMs = opts.jitterMs or 18
    baseDelayMs = zo_max(baseDelayMs, minDelay)

    local index = 0
    local processedCount = 0
    local stopReason = nil
    local nextCooldownAt = cooldownEvery > 0 and cooldownEvery or nil
    local nextChunkAt = chunkCostUnits > 0 and chunkCostUnits or nil

    local function IsSceneActive()
        return Vendor.instance and Vendor.instance.IsSceneShowing and Vendor.instance:IsSceneShowing()
    end

    local function BuildProgressMainText()
        return string.format("Processing (%d/%d)", processedCount, totalItems)
    end

    local function BuildProgressSecondaryText()
        return string.format("Please Wait - Press %s to abort", BatchConfig.ResolveBatchAbortBindingMarkup())
    end

    local function FinishBatch()
        Vendor._batchProcessing = false
        Vendor._batchAbortRequested = false

        if showProgress or stopReason then
            local completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_PROCESSING_COMPLETE")), processedCount)
            if stopReason == "bagFull" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_BAG_FULL")), processedCount, totalItems)
            elseif stopReason == "sceneExit" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORTED_SCENE_EXIT")), "Vendor", processedCount, totalItems)
            elseif stopReason == "aborted" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORTED_COMPLETE")), processedCount, totalItems)
            elseif processedCount < totalItems then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_PARTIAL_SUCCESS")), processedCount, totalItems)
            end
            BatchOverlay.Show(actionName, completeText)
            BatchOverlay.Hide((stopReason and 4000) or 2000)
        else
            BatchOverlay.Hide()
        end

        if onComplete then onComplete(stopReason) end
    end

    local processNext
    processNext = function()
        -- Scene exit check
        if not IsSceneActive() then
            stopReason = "sceneExit"
            FinishBatch()
            return
        end

        -- Abort check
        if Vendor._batchAbortRequested then
            stopReason = "aborted"
            FinishBatch()
            return
        end

        index = index + 1
        if index > totalItems then
            FinishBatch()
            return
        end

        -- Execute the action for this item
        Vendor.ExecuteBatchAction(mode, items[index])
        processedCount = processedCount + 1

        -- Abort batch when bag is full during BUY or BUYBACK operations
        if mode == MODE.BUY or mode == MODE.BUYBACK then
            local vi = Vendor.instance
            if vi and vi.HasInventorySpace and not vi:HasInventorySpace() then
                stopReason = "bagFull"
                FinishBatch()
                return
            end
        end

        -- Record server action for shared rate tracking
        if BatchConfig.RecordServerAction then
            BatchConfig.RecordServerAction(BatchConfig.GetNowMs(), BatchConfig.SERVER_RATE_WINDOW_MS)
        end

        -- Update progress overlay
        if showProgress then
            BatchOverlay.Show(actionName, BuildProgressMainText, BuildProgressSecondaryText)
        end

        -- Calculate delay with cooldown and chunk pauses
        local delayMs = baseDelayMs
        if jitterMs > 0 and BatchConfig.ResolveSignedJitter then
            delayMs = zo_clamp(delayMs + BatchConfig.ResolveSignedJitter(jitterMs), minDelay, maxDelay)
        else
            delayMs = zo_clamp(delayMs, minDelay, maxDelay)
        end

        -- Cooldown pause every N items
        if cooldownMs > 0 and nextCooldownAt and processedCount >= nextCooldownAt then
            delayMs = delayMs + cooldownMs
            while nextCooldownAt and processedCount >= nextCooldownAt do
                nextCooldownAt = nextCooldownAt + cooldownEvery
            end
        end

        -- Chunk pause at cost boundaries
        if chunkPauseMs > 0 and nextChunkAt and processedCount >= nextChunkAt then
            delayMs = delayMs + chunkPauseMs
            while nextChunkAt and processedCount >= nextChunkAt do
                nextChunkAt = nextChunkAt + chunkCostUnits
            end
        end

        zo_callLater(processNext, delayMs)
    end

    -- Wait for the dialog to dismiss before starting
    local function StartAfterDialogDismiss(remainingMs)
        if not Vendor._batchProcessing then return end
        if Vendor._batchAbortRequested then stopReason = "aborted"; FinishBatch(); return end
        if not IsSceneActive() then stopReason = "sceneExit"; FinishBatch(); return end

        if BatchOverlay.IsAnyBatchActionDialogShowing and BatchOverlay.IsAnyBatchActionDialogShowing() and remainingMs > 0 then
            zo_callLater(function() StartAfterDialogDismiss(remainingMs - 25) end, 25)
            return
        end

        -- Small settle delay after dialog closes
        zo_callLater(function()
            if not Vendor._batchProcessing then return end
            if showProgress then
                BatchOverlay.Show(actionName, BuildProgressMainText, BuildProgressSecondaryText)
            end
            processNext()
        end, 160)
    end

    StartAfterDialogDismiss(1800)
end

--- Requests abort of the current vendor batch operation.
function Vendor.RequestBatchAbort()
    if Vendor._batchProcessing then
        Vendor._batchAbortRequested = true
    end
end

local function RegisterVendorSellAllJunkDialog()
    if not (ZO_Dialogs_RegisterCustomDialog and GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC) then
        return false
    end
    if ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered(SELL_ALL_JUNK_GAMEPAD_DIALOG_NAME) then
        return true
    end

    ZO_Dialogs_RegisterCustomDialog(SELL_ALL_JUNK_GAMEPAD_DIALOG_NAME, {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title = {
            text = rawget(_G, "SI_PROMPT_TITLE_SELL_ITEMS") or rawget(_G, "SI_SELL_ALL_JUNK_KEYBIND_TEXT") or "SI_SELL_ALL_JUNK_KEYBIND_TEXT",
        },
        mainText = {
            text = rawget(_G, "SI_SELL_ALL_JUNK") or "SI_SELL_ALL_JUNK",
        },
        buttons = {
            [1] = {
                text = rawget(_G, "SI_SELL_ALL_JUNK_CONFIRM") or "SI_SELL_ALL_JUNK_CONFIRM",
                callback = function(dialog)
                    local dialogData = dialog and dialog.data
                    local vendorInstance = dialogData and dialogData.vendorInstance
                    local component = dialogData and dialogData.component
                    if vendorInstance and component and component.SellAllJunk then
                        component:SellAllJunk(vendorInstance)
                    end
                end,
            },
            [2] = {
                text = rawget(_G, "SI_DIALOG_CANCEL") or "SI_DIALOG_CANCEL",
            },
        },
    })

    return true
end

---@param vendorInstance BETTERUI.Vendor.Class
---@param component table
---@return boolean shown
function Vendor.ShowSellAllJunkDialog(vendorInstance, component)
    if not vendorInstance or not component or type(component.SellAllJunk) ~= "function" then
        return false
    end

    local dialogData = {
        vendorInstance = vendorInstance,
        component = component,
    }

    if ZO_Dialogs_ShowGamepadDialog then
        local ok = SafeCall("Vendor.RegisterSellAllJunkDialog", RegisterVendorSellAllJunkDialog)
        if ok and (not ZO_Dialogs_IsDialogRegistered or ZO_Dialogs_IsDialogRegistered(SELL_ALL_JUNK_GAMEPAD_DIALOG_NAME)) then
            ZO_Dialogs_ShowGamepadDialog(SELL_ALL_JUNK_GAMEPAD_DIALOG_NAME, dialogData)
            return true
        end
    end

    if ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog("SELL_ALL_JUNK", dialogData)
        return true
    end

    return false
end

RegisterVendorBatchDialog = function()
    if ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered("BETTERUI_VENDOR_BATCH_DIALOG") then
        return
    end
    ZO_Dialogs_RegisterCustomDialog("BETTERUI_VENDOR_BATCH_DIALOG", {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = SI_BETTERUI_INV_BATCH_ACTIONS or SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND },
        parametricList = {},
        setup = function(dialog)
            dialog.info = dialog.info or {}
            if type(dialog.info.parametricList) ~= "table" then
                dialog.info.parametricList = {}
            end
            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)
            local function AddAction(name, actionId)
                local entryData = ZO_GamepadEntryData:New(name)
                entryData:SetIconTintOnSelection(true)
                entryData.actionId = actionId
                entryData.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = entryData,
                })
            end
            local ms = Vendor.multiSelectManager
            if ms then
                local selectedCount = ms:GetSelectedCount()
                local selectedItems = ms.GetSelectedItems and ms:GetSelectedItems() or {}
                local totalItems = (Vendor.instance and Vendor.instance.list and Vendor.instance.list:GetNumItems()) or 0
                local allSelected = selectedCount > 0 and selectedCount == totalItems
                if not allSelected then
                    AddAction(GetString(rawget(_G, "SI_BETTERUI_SELECT_ALL") or "SI_BETTERUI_SELECT_ALL"), "selectAll")
                end
                if selectedCount > 0 then
                    AddAction(zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_BETTERUI_DESELECT_ALL") or "SI_BETTERUI_DESELECT_ALL"), selectedCount), "deselectAll")
                end
                local currentMode = Vendor.instance and Vendor.instance:GetCurrentMode()
                if currentMode and selectedCount > 0 then
                    local supportedCount = 0
                    if Vendor.BatchActionCounts and Vendor.BatchActionCounts.GetSupportedActionCount then
                        supportedCount = Vendor.BatchActionCounts.GetSupportedActionCount(currentMode, selectedItems, Vendor.instance)
                    end

                    local batchLabel = nil
                    if Vendor.BatchActionCounts and Vendor.BatchActionCounts.BuildBatchActionLabel then
                        batchLabel = Vendor.BatchActionCounts.BuildBatchActionLabel(currentMode, supportedCount)
                    end

                    if batchLabel then
                        AddAction(batchLabel, "batch")
                    end
                end
            end
            dialog:setupFunc()
        end,
        buttons = {
            {
                text = SI_DIALOG_CANCEL,
                keybind = "DIALOG_NEGATIVE",
            },
            {
                text = SI_GAMEPAD_SELECT_OPTION,
                keybind = "DIALOG_PRIMARY",
                callback = function(dialog)
                    local selected = dialog.entryList and dialog.entryList:GetTargetData()
                    if not selected or not selected.actionId then return end
                    local ms = Vendor.multiSelectManager
                    if not ms then return end
                    local actionId = selected.actionId
                    if actionId == "selectAll" then
                        ms:SelectAll()
                        if Vendor.instance then
                            Vendor.instance:SaveListPosition()
                            Vendor.instance:RefreshList()
                            Vendor.instance:EnsureListInputActive()
                        end
                        return
                    elseif actionId == "deselectAll" then
                        ms:ClearSelections()
                        if Vendor.instance then
                            Vendor.instance:SaveListPosition()
                            Vendor.instance:RefreshList()
                            Vendor.instance:EnsureListInputActive()
                        end
                        return
                    end

                    local currentMode = Vendor.instance and Vendor.instance:GetCurrentMode()
                    local items = ms:GetSelectedItems()
                    Vendor.ExecuteBatchThrottled(currentMode, items, function()
                        if ms then ms:ClearSelections() end
                        if Vendor.instance then
                            Vendor.instance:SaveListPosition()
                            Vendor.instance:RefreshList()
                            Vendor.instance:EnsureListInputActive()
                        end
                        if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                            KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                        end
                    end)
                end,
            },
        },
    })
end

-- TAB CYCLING

---@param direction number
function BETTERUI.Vendor.Class:CycleModeTabs(direction)
    local tabs = GetActiveTabs()
    if #tabs <= 1 then return end

    local currentMode = self:GetCurrentMode()
    local currentIndex = 1
    for i, tab in ipairs(tabs) do
        if tab.mode == currentMode then
            currentIndex = i
            break
        end
    end

    local newIndex = ((currentIndex - 1 + direction) % #tabs) + 1
    self._preferredModeHeaderSelectionMode = tabs[newIndex].mode
    self:SetMode(tabs[newIndex].mode)
end

---@param direction number -1 for left, 1 for right
function BETTERUI.Vendor.Class:CycleTabs(direction)
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    local headerEntryCount = self._vendorHeaderEntryCount or 0
    if tabBar and headerEntryCount > 1 then
        if direction < 0 then
            tabBar:MovePrevious(true)
        else
            tabBar:MoveNext(true)
        end
        return
    end

    self:CycleModeTabs(direction)
end

-- EVENT HANDLERS

local function OnOpenStore()
    isFenceInteraction = false
    isStableInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false
    Vendor._sessionHasBuyMode = false
    Vendor._isClosing = false
    Vendor._openStoreSyncAttempt = 0

    if not Vendor.instance then return end
    Vendor.instance._cachedBuyCategories = nil
    if Vendor.Tasks then
        Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
        Vendor.Tasks:Cancel("buyActivateRefresh")
        Vendor.Tasks:Cancel("buyListRetry")
        Vendor.Tasks:Cancel("footerRefresh")
    end

    local interactionType = GetInteractionType and GetInteractionType() or nil
    local allowNativeStableFallback = interactionType == nil
    isStableInteraction = isStableInteraction
        or interactionType == INTERACTION_STABLE
        or (allowNativeStableFallback and IsNativeStableModeActive())
    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenStore interaction=%s fence=%s stable=%s", tostring(interactionType), tostring(isFenceInteraction), tostring(isStableInteraction))
    )

    if interactionType and interactionType ~= INTERACTION_VENDOR and interactionType ~= INTERACTION_STABLE then
        RestoreNativeStoreSceneAlias()
        return
    end

    AliasStoreSceneToBetterUI()
    if Vendor.instance.ReleaseNativeStoreInputOwnership then
        Vendor.instance:ReleaseNativeStoreInputOwnership()
    end
    EnsureNativeStoreComponents("storeTextSearch")
    if not isStableInteraction and allowNativeStableFallback and IsNativeStableModeActive() then
        -- Some clients open stablemaster as generic vendor interaction.
        -- Re-detect using native modes and rebuild with stable tab policy.
        isStableInteraction = true
        EnsureNativeStoreComponents("storeTextSearch")
    end

    local tabs = GetActiveTabs()
    local targetMode = ResolveInitialStoreMode(tabs)
    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenStore targetMode=%s tabs=%d", tostring(targetMode), #tabs)
    )
    if Vendor.instance.GetCurrentMode and Vendor.instance:GetCurrentMode() ~= targetMode then
        Vendor.instance:SetMode(targetMode)
    else
        Vendor.instance:ApplyNativeStoreMode(targetMode)
    end

    if SCENE_MANAGER then
        SCENE_MANAGER:Show(BETTERUI_VENDOR_SCENE_NAME)
    end

    if Vendor.Tasks then
        -- Keep one short native sync window after scene show so the buy component can
        -- populate from the native store manager without fighting scene ownership.
        Vendor.Tasks:Schedule("ensureStoreComponentsOnOpen", 120, function()
            if ShouldAbortOpenStoreSync() then
                return
            end

            EnsureNativeStoreComponents("storeTextSearch")
            if ShouldAbortOpenStoreSync() then
                return
            end
            local resolvedTargetMode = ResolveInitialStoreMode(GetActiveTabs())
            if resolvedTargetMode ~= targetMode then
                targetMode = resolvedTargetMode
            end
            if ShouldAbortOpenStoreSync() then
                return
            end
            if Vendor.instance.GetCurrentMode and Vendor.instance:GetCurrentMode() ~= targetMode then
                Vendor.instance:SetMode(targetMode)
            else
                Vendor.instance:ApplyNativeStoreMode(targetMode)
            end
            Vendor.instance:RefreshList()

            local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
            local nativeCurrentMode = nil
            if storeManager and type(storeManager.GetCurrentMode) == "function" then
                local okMode, modeResult = SafeCall("Vendor.OnOpenStore:GetCurrentModeAfterRefresh", storeManager.GetCurrentMode, storeManager)
                if okMode then
                    nativeCurrentMode = modeResult
                end
            end

            local targetNativeMode = ResolveNativeModeForVendorMode(targetMode)
            if targetNativeMode ~= nil and nativeCurrentMode ~= targetNativeMode then
                local syncAttempt = (Vendor._openStoreSyncAttempt or 0) + 1
                Vendor._openStoreSyncAttempt = syncAttempt
                if syncAttempt <= 4 and Vendor.Tasks then
                    Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
                    Vendor.Tasks:Schedule("ensureStoreComponentsOnOpen", 140, function()
                        if ShouldAbortOpenStoreSync() then
                            return
                        end
                        EnsureNativeStoreComponents("storeTextSearch")
                        if ShouldAbortOpenStoreSync() then
                            return
                        end
                        local retriedTargetMode = ResolveInitialStoreMode(GetActiveTabs())
                        if retriedTargetMode ~= targetMode then
                            targetMode = retriedTargetMode
                        end
                        if ShouldAbortOpenStoreSync() then
                            return
                        end
                        if Vendor.instance.GetCurrentMode and Vendor.instance:GetCurrentMode() ~= targetMode then
                            Vendor.instance:SetMode(targetMode)
                        else
                            Vendor.instance:ApplyNativeStoreMode(targetMode)
                        end
                        Vendor.instance:RefreshList()
                    end)
                end
            else
                Vendor._openStoreSyncAttempt = 0
            end
        end)
    end
end

---@param _ any Unused event code
---@param enableSell boolean|nil Whether fence sell is enabled (default true)
---@param enableLaunder boolean|nil Whether fence launder is enabled (default true)
local function OnOpenFence(_, enableSell, enableLaunder)
    isFenceInteraction = true
    isStableInteraction = false
    fenceEnableSell = (enableSell ~= false)     -- default true
    fenceEnableLaunder = (enableLaunder ~= false) -- default true
    Vendor._sessionHasBuyMode = false
    Vendor._isClosing = false
    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenFence sell=%s launder=%s", tostring(fenceEnableSell), tostring(fenceEnableLaunder))
    )

    if not Vendor.instance then return end
    Vendor.instance._cachedBuyCategories = nil
    AliasStoreSceneToBetterUI()
    if Vendor.instance.ReleaseNativeStoreInputOwnership then
        Vendor.instance:ReleaseNativeStoreInputOwnership()
    end

    -- Set mode to first available fence tab
    if fenceEnableSell then
        Vendor.instance:SetMode(MODE.FENCE_SELL)
    elseif fenceEnableLaunder then
        Vendor.instance:SetMode(MODE.FENCE_LAUNDER)
    end
    -- Show BetterUI vendor scene directly; native manager sceneName is remapped above.
    if SCENE_MANAGER then
        SCENE_MANAGER:Show(BETTERUI_VENDOR_SCENE_NAME)
    end
end

local function OnStableInteractStart()
    isStableInteraction = true
end

local function OnStableInteractEnd()
    isStableInteraction = false
end

local function OnCloseStore()
    Vendor._isClosing = true
    isFenceInteraction = false
    isStableInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false
    Vendor._sessionHasBuyMode = false
    Vendor._openStoreSyncAttempt = 0
    if Vendor.instance then
        Vendor.instance._cachedBuyCategories = nil
        if Vendor.instance.DisableStablePreviewMode then
            Vendor.instance:DisableStablePreviewMode()
        end
    end

    if Vendor.Tasks then
        Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
        Vendor.Tasks:Cancel("buyActivateRefresh")
        Vendor.Tasks:Cancel("buyListRetry")
        Vendor.Tasks:Cancel("listRefresh")
        Vendor.Tasks:Cancel("footerRefresh")
        Vendor.Tasks:Cancel("directionalInputNormalize")
    end

    LogVendorDebug("SCENE_TRANSITIONS", "VendorScene", "OnCloseStore begin")

    local sceneName = BETTERUI_VENDOR_SCENE_NAME
    if SCENE_MANAGER then
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene and scene.IsShowing and scene:IsShowing() then
            SCENE_MANAGER:Hide(sceneName)
        end
    end

    if Vendor.instance and Vendor.instance.ReleaseNativeStoreInputOwnership then
        Vendor.instance:ReleaseNativeStoreInputOwnership()
    end
    if Vendor.instance and Vendor.instance.ForceReleaseDirectionalInput then
        Vendor.instance:ForceReleaseDirectionalInput()
    end

    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    LogNativeStoreInputState("OnCloseStore:beforeSweep", storeManager)
    if storeManager and type(storeManager.OnHide) == "function" then
        SafeCall("Vendor.OnCloseStore:NativeOnHide", storeManager.OnHide, storeManager)
    end
    if storeManager then
        -- Clear native mode residue so the next vendor open does not inherit stale stable tabs.
        storeManager.activeComponents = {}
    end
    LogNativeStoreInputState("OnCloseStore:afterSweep", storeManager)
    LogVendorDebug("SCENE_TRANSITIONS", "VendorScene", "OnCloseStore complete")

    -- Keep BetterUI as default owner so vendor opens route directly here.
    AliasStoreSceneToBetterUI()
end

local function OnInventoryUpdated()
    if not Vendor.instance then return end
    if not Vendor.instance:IsSceneShowing() then return end

    -- Coalesce rapid updates
    Vendor.Tasks:Cancel("listRefresh")
    Vendor.Tasks:Schedule("listRefresh", 100, function()
        if Vendor.instance and Vendor.instance:IsSceneShowing() then
            Vendor.instance:RefreshList()
            if Vendor.instance.RefreshVendorFooter then
                Vendor.instance:RefreshVendorFooter()
            end
        end
    end)
end

local function OnMoneyUpdated()
    if not Vendor.instance then return end
    if not Vendor.instance:IsSceneShowing() then return end

    if Vendor.Tasks then
        Vendor.Tasks:Cancel("footerRefresh")
        Vendor.Tasks:Schedule("footerRefresh", 40, function()
            if Vendor.instance and Vendor.instance:IsSceneShowing() and Vendor.instance.RefreshVendorFooter then
                Vendor.instance:RefreshVendorFooter()
                if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end
        end)
        return
    end

    if Vendor.instance.RefreshVendorFooter then
        Vendor.instance:RefreshVendorFooter()
        if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
            KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
        end
    end
end

local function OnSellReceipt()
    -- Refresh after selling an item
    OnInventoryUpdated()
end

-- INITIALIZATION

--- Initializes the Vendor module.
---@return nil
function BETTERUI.Vendor.Init()
    if Vendor.initialized then return end

    -- Create the Vendor class instance with proper window/scene names
    Vendor.instance = Vendor.Class:New("BETTERUI_VendorWindow", BETTERUI_VENDOR_SCENE_NAME)
    Vendor.instance:SetTitle("|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_VENDOR_TITLE")) .. "|r")

    -- Register components (each is initialized in its own file)
    if Vendor.BuyComponent then
        Vendor.instance:RegisterComponent(MODE.BUY, Vendor.BuyComponent)
    end
    if Vendor.SellComponent then
        Vendor.instance:RegisterComponent(MODE.SELL, Vendor.SellComponent)
    end
    if Vendor.RepairComponent then
        Vendor.instance:RegisterComponent(MODE.REPAIR, Vendor.RepairComponent)
    end
    if Vendor.StableTrainingComponent then
        Vendor.instance:RegisterComponent(MODE.STABLE, Vendor.StableTrainingComponent)
    end
    if Vendor.BuybackComponent then
        Vendor.instance:RegisterComponent(MODE.BUYBACK, Vendor.BuybackComponent)
    end
    if Vendor.FenceSellComponent then
        Vendor.instance:RegisterComponent(MODE.FENCE_SELL, Vendor.FenceSellComponent)
    end
    if Vendor.FenceLaunderComponent then
        Vendor.instance:RegisterComponent(MODE.FENCE_LAUNDER, Vendor.FenceLaunderComponent)
    end

    -- Register the item list template with our vendor-specific row setup
    Vendor.instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI.Vendor.VendorEntrySetup
    )
    Vendor.instance.list:SetOnSelectedDataChangedCallback(function(list, selectedData)
        if Vendor.instance._searchModeActive and Vendor.instance.list
            and Vendor.instance.list.IsActive and Vendor.instance.list:IsActive() then
            Vendor.instance:OnItemSelectedChange(list, selectedData)
            Vendor.instance:UpdateScrollIndicator(list)
            Vendor.instance:OnSearchFocusLost()
            return
        end
        Vendor.instance:OnItemSelectedChange(list, selectedData)
        Vendor.instance:UpdateScrollIndicator(list)
    end)
    if Vendor.instance.list then
        Vendor.instance.list.owner = Vendor.instance
        if Vendor.instance.list.MovePrevious then
            local originalMovePrevious = Vendor.instance.list.MovePrevious
            Vendor.instance.list.MovePrevious = function(list, allowWrapping, suppressFailSound)
                local didMove = originalMovePrevious(list, allowWrapping, suppressFailSound)
                if didMove then
                    return true
                end

                if Vendor.instance and Vendor.instance.OnHeaderEntered then
                    Vendor.instance:OnHeaderEntered()
                elseif Vendor.instance and Vendor.instance.RequestHeaderFocus then
                    Vendor.instance:RequestHeaderFocus()
                end
                return true
            end
        end
    end

    -- Add column headers (matching Inventory/Banking layout)
    local COL = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_NAME") or "SI_BETTERUI_BANKING_COLUMN_NAME"), COL.NAME)
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TYPE") or "SI_BETTERUI_BANKING_COLUMN_TYPE"), COL.TYPE)
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TRAIT") or "SI_BETTERUI_BANKING_COLUMN_TRAIT"), COL.TRAIT)
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_STAT") or "SI_BETTERUI_BANKING_COLUMN_STAT"), COL.STAT)
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_VALUE") or "SI_BETTERUI_BANKING_COLUMN_VALUE"), COL.VALUE)
    Vendor.instance:InitializeCategoryHeader()
    Vendor.instance:InitializeScrollIndicator()
    Vendor.instance.searchQuery = ""

    -- Tracks whether AddSearch's native callback already handled this text-change event.
    -- SetupEditBoxHandlers runs after the original handler, so we can skip duplicate refreshes.
    local searchCallbackRevision = 0
    local searchHandlerRevision = 0

    local function HandleVendorSearchChanged(editOrText)
        if Vendor.instance.OnSearchTextChanged then
            Vendor.instance:OnSearchTextChanged(editOrText)
        else
            Vendor.instance.searchQuery = tostring(editOrText or "")
            Vendor.instance:RefreshList()
        end
        searchCallbackRevision = searchCallbackRevision + 1
    end

    Vendor.instance.textSearchKeybindStripDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor(Vendor.instance)
    if Vendor.instance.AddSearch then
        Vendor.instance:AddSearch(Vendor.instance.textSearchKeybindStripDescriptor, HandleVendorSearchChanged)
        if Vendor.instance.PositionSearchControl then
            Vendor.instance:PositionSearchControl()
        end
    end
    if BETTERUI.Interface.SearchMixin and BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers then
        BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(Vendor.instance, {
            isSceneShowing = function()
                return Vendor.instance and Vendor.instance.IsSceneShowing and Vendor.instance:IsSceneShowing() or false
            end,
            onTextChanged = function(window, txt)
                -- Fallback: if the native AddSearch callback did not fire, refresh here.
                if searchHandlerRevision == searchCallbackRevision then
                    if window.OnSearchTextChanged then
                        window:OnSearchTextChanged(txt or "")
                    else
                        window.searchQuery = txt or ""
                        if window.RefreshList then
                            window:RefreshList()
                        end
                    end
                end
                searchHandlerRevision = searchCallbackRevision
                if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
            enterHeaderFn = function(window)
                if window.RequestHeaderFocus then
                    window:RequestHeaderFocus()
                else
                    window:EnterSearchMode()
                end
            end,
        })
    end

    -- Sort Controller
    if BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortController then
        local ok, err = pcall(function()
            local sortController = BETTERUI.CIM.UI.HeaderSortController:New(Vendor.instance)
            sortController:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_NAME") or "SI_BETTERUI_BANKING_COLUMN_NAME"), "name")
            sortController:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TYPE") or "SI_BETTERUI_BANKING_COLUMN_TYPE"), "type")
            sortController:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TRAIT") or "SI_BETTERUI_BANKING_COLUMN_TRAIT"), "trait")
            sortController:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_STAT") or "SI_BETTERUI_BANKING_COLUMN_STAT"), "stat")
            sortController:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_VALUE") or "SI_BETTERUI_BANKING_COLUMN_VALUE"), "value")
            sortController:SetSortChangedCallback(function()
                Vendor.instance:RefreshList()
            end)
            Vendor.instance.sortController = sortController
        end)
        if not ok and BETTERUI.Debug then
            BETTERUI.Debug("[Vendor] Sort controller init failed: " .. tostring(err))
        end
    end

    -- Build keybinds
    Vendor.instance.coreKeybinds = BuildCoreKeybinds(Vendor.instance)

    -- Multi-Select
    if BETTERUI.CIM and BETTERUI.CIM.MultiSelectManager and BETTERUI.CIM.MultiSelectManager.Create then
        Vendor.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(Vendor.instance.list, function()
            if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
            end
        end)
    else
        Vendor.multiSelectManager = nil
    end
    Vendor.instance.multiSelectManager = Vendor.multiSelectManager

    -- Header Sort Integration
    if Vendor.instance.sortController and BETTERUI.CIM.UI.HeaderSortIntegration and BETTERUI.CIM.UI.HeaderSortIntegration.Setup then
        local ok, err = pcall(function()
            BETTERUI.CIM.UI.HeaderSortIntegration.Setup(
                Vendor.instance.list,
                Vendor.instance.sortController,
                {
                    keybindStrip = true,
                    mainKeybindDescriptor = Vendor.instance.coreKeybinds,
                    onSortChanged = function()
                        Vendor.instance:RefreshList()
                    end,
                }
            )
        end)
        if not ok and BETTERUI.Debug then
            BETTERUI.Debug("[Vendor] Header sort integration setup failed: " .. tostring(err))
        end
    end

    -- Initialize scene fragments manually — vendor does not use BETTERUI_BankingFooterBar
    Vendor.instance.fragment = ZO_SimpleSceneFragment:New(Vendor.instance.control)
    Vendor.instance.fragment:SetHideOnSceneHidden(true)
    -- Dummy footer fragment (vendor footer is embedded in the window template, not a separate overlay)
    local vendorFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_VendorFooterDummy", GuiRoot, CT_CONTROL)
    vendorFooterDummy:SetHidden(true)
    Vendor.instance.footerFragment = ZO_SimpleSceneFragment:New(vendorFooterDummy)
    Vendor.instance.footerFragment:SetHideOnSceneHidden(true)

    -- Create the scene
    local sceneName = BETTERUI_VENDOR_SCENE_NAME
    local scene = ZO_InteractScene:New(sceneName, SCENE_MANAGER, Vendor.VENDOR_INTERACTION)
    Vendor.instance.scene = scene

    -- Capture vanilla store scene once so we can safely restore it outside vendor/fence interactions.
    Vendor.nativeStoreScene = Vendor.nativeStoreScene or (SCENE_MANAGER and SCENE_MANAGER:GetScene("gamepad_store"))

    -- Suppress native store manager interference.
    -- The native OnOpenStore handler calls SetActiveComponents → RebuildHeaderTabs →
    -- tabBar:Commit() which triggers ShowComponent via the SelectedDataChanged callback
    -- chain. ShowComponent checks SCENE_MANAGER:IsShowing(self.sceneName) — because
    -- BetterUI aliases "gamepad_store" to its own scene, the check passes and native
    -- component lists get activated on DIRECTIONAL_INPUT alongside BetterUI's lists,
    -- causing joystick navigation lockup.
    --
    -- Fix: (1) Redirect sceneName so ShowComponent's scene check always fails.
    --      (2) Unregister native event handlers so they cannot race BetterUI's handlers.
    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if storeManager then
        storeManager.sceneName = "betterui_native_store_blocked"
        if storeManager.control then
            storeManager.control:UnregisterForEvent(EVENT_OPEN_STORE)
            storeManager.control:UnregisterForEvent(EVENT_CLOSE_STORE)
        end
        -- Fallback: some game builds register events via EVENT_MANAGER directly.
        if EVENT_MANAGER then
            EVENT_MANAGER:UnregisterForEvent("ZO_StoreWindow_Gamepad", EVENT_OPEN_STORE)
            EVENT_MANAGER:UnregisterForEvent("ZO_StoreWindow_Gamepad", EVENT_CLOSE_STORE)
        end

        -- Override native store manager's UpdateDirectionalInput to prevent it from
        -- processing joystick input when BetterUI owns the vendor scene.  Even if 
        -- the storeManager somehow registers on DIRECTIONAL_INPUT (via
        -- ActivateCurrentList, SetQuantitySpinnerActive, OnShowing, or future ESO
        -- updates), this no-op ensures it cannot cause doubled vertical movement
        -- (fast scrolling symptom) or post-exit input lockup.
        -- Pass through to the original when the native scene is explicitly showing
        -- (non-BetterUI interactions such as stables).
        local origStoreManagerUpdateDI = storeManager.UpdateDirectionalInput
        storeManager.UpdateDirectionalInput = function(self, ...)
            local nativeScene = Vendor.nativeStoreScene
            if nativeScene and nativeScene.IsShowing and nativeScene:IsShowing() then
                if origStoreManagerUpdateDI then
                    return origStoreManagerUpdateDI(self, ...)
                end
            end
            -- Suppress — BetterUI's list handles all directional input.
        end
    end

    -- Defensive alias reassertion: if anything re-adds the native gamepad_store scene,
    -- force it back to BetterUI's scene on every Show call.
    if SCENE_MANAGER and ZO_PreHook then
        ZO_PreHook(SCENE_MANAGER, "Show", function(self, sceneName, ...)
            if sceneName == "gamepad_store" and Vendor.instance and Vendor.instance.scene then
                self.scenes["gamepad_store"] = Vendor.instance.scene
            end
        end)
    end

    -- Add required fragment groups (matching WindowClass.InitializeScene pattern)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(Vendor.instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(Vendor.instance.footerFragment)

    -- Register unified scene lifecycle with the core vendor keybind group.
    -- The header tab bar owns LB/RB navigation for categories and custom vendor entries.
    BETTERUI.CIM.SceneLifecycle.Register(Vendor.instance, {
        keybinds = { Vendor.instance.coreKeybinds },
        taskManager = Vendor.Tasks,
        onShowing = function(screen, wasPushed)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            if screen.ReleaseNativeStoreInputOwnership then
                screen:ReleaseNativeStoreInputOwnership()
            end
            if screen.ForceReleaseDirectionalInput then
                screen:ForceReleaseDirectionalInput()
            end
            screen:ApplyNativeStoreMode(screen:GetCurrentMode())
            screen:RefreshVendorFooter()
            screen:InitializeScrollIndicator()
            screen:RefreshList()
            screen:EnsureHeaderKeybindsActive()
            screen:EnsureColumnHeadersVisible()
            if ITEM_PREVIEW_GAMEPAD and ITEM_PREVIEW_GAMEPAD.RegisterCallback then
                if not screen.onItemPreviewRefreshActionsCallback then
                    screen.onItemPreviewRefreshActionsCallback = function()
                        if screen.RefreshVendorActionKeybinds then
                            screen:RefreshVendorActionKeybinds()
                        elseif KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                            KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                        end
                    end
                end
                ITEM_PREVIEW_GAMEPAD:RegisterCallback("RefreshActions", screen.onItemPreviewRefreshActionsCallback)
            end
            if screen.list then
                screen:OnItemSelectedChange(screen.list, screen.list:GetTargetData())
                screen:UpdateScrollIndicator(screen.list)
            end
            if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
            end
        end,
        onHiding = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
            if ITEM_PREVIEW_GAMEPAD and ITEM_PREVIEW_GAMEPAD.UnregisterCallback and screen.onItemPreviewRefreshActionsCallback then
                ITEM_PREVIEW_GAMEPAD:UnregisterCallback("RefreshActions", screen.onItemPreviewRefreshActionsCallback)
            end
            local currentMode = screen:GetCurrentMode()
            if currentMode and screen.list then
                BETTERUI.CIM.PositionManager.SavePosition("Vendor", "mode_" .. currentMode, screen.list)
            end
            if Vendor.multiSelectManager then
                Vendor.multiSelectManager:ExitSelectionMode()
            end
            screen._suppressListUpdates = false
            screen._isDirty = false
            if screen.DisableStablePreviewMode then
                screen:DisableStablePreviewMode()
            end
            if screen.ReleaseNativeStoreInputOwnership then
                screen:ReleaseNativeStoreInputOwnership()
            end
            if screen.ForceReleaseDirectionalInput then
                screen:ForceReleaseDirectionalInput()
            end
            screen:DeactivateHeaderKeybinds()
            screen:DeactivateListInput()
            if BETTERUI.CIM and BETTERUI.CIM.SceneCleanup then
                -- Match Banking/Inventory cleanup so directional input is always released.
                BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
                BETTERUI.CIM.SceneCleanup.DeactivateLists(screen, screen.list)
                BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
            end
            if GAMEPAD_TOOLTIPS then
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
                GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
            end
            if BETTERUI.Inventory and BETTERUI.Inventory.CleanupEnhancedTooltip then
                BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
                BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
            end
            if screen.list and screen.list.control and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator then
                BETTERUI.CIM.ScrollIndicator.Hide(screen.list.control)
            end
        end,
        onHidden = function(screen)
            -- Repeat the DI/search cleanup on HIDDEN as a last-chance sweep.
            -- Native callbacks and deferred work can still re-register owners
            -- after HIDING cleanup has already run during scene transition.
            if screen.DisableStablePreviewMode then
                screen:DisableStablePreviewMode()
            end
            if screen.ReleaseNativeStoreInputOwnership then
                screen:ReleaseNativeStoreInputOwnership()
            end
            if screen.ForceReleaseDirectionalInput then
                screen:ForceReleaseDirectionalInput()
            end
            if BETTERUI.CIM and BETTERUI.CIM.SceneCleanup then
                BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
                BETTERUI.CIM.SceneCleanup.DeactivateLists(screen, screen.list)
                BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
            end
            local component = screen:GetActiveComponent()
            if component and component.Deactivate then
                component:Deactivate(screen)
            end
        end,
    })

    -- Keep BetterUI alias by default so EVENT_OPEN_STORE routes directly here,
    -- preventing native scene input from claiming directional ownership first.
    AliasStoreSceneToBetterUI()

    -- Set up vendor-specific footer labels (replace banking WITHDRAW/DEPOSIT with gold/capacity)
    Vendor.instance:InitVendorFooter()

    -- Register events
    local em = EVENT_MANAGER
    if em then
        if EVENT_STABLE_INTERACT_START then
            em:RegisterForEvent(EVENT_NS .. "_StableStart", EVENT_STABLE_INTERACT_START, OnStableInteractStart)
        end
        if EVENT_STABLE_INTERACT_END then
            em:RegisterForEvent(EVENT_NS .. "_StableEnd", EVENT_STABLE_INTERACT_END, OnStableInteractEnd)
        end
        em:RegisterForEvent(EVENT_NS .. "_Open", EVENT_OPEN_STORE, OnOpenStore)
        em:RegisterForEvent(EVENT_NS .. "_OpenFence", EVENT_OPEN_FENCE, OnOpenFence)
        em:RegisterForEvent(EVENT_NS .. "_Close", EVENT_CLOSE_STORE, OnCloseStore)
        em:RegisterForEvent(EVENT_NS .. "_InvUpdate",
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_InvFull",
            EVENT_INVENTORY_FULL_UPDATE, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_SellReceipt",
            EVENT_SELL_RECEIPT, OnSellReceipt)
        em:RegisterForEvent(EVENT_NS .. "_BuyReceipt",
            EVENT_BUY_RECEIPT, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_BuybackReceipt",
            EVENT_BUYBACK_RECEIPT, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_RepairItem",
            EVENT_ITEM_REPAIR_ALREADY_APPLIED_CONFIRMATION, OnInventoryUpdated)
        -- Fence-specific events
        em:RegisterForEvent(EVENT_NS .. "_ItemLaunder",
            EVENT_ITEM_LAUNDER_RESULT, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_FenceUpdate",
            EVENT_JUSTICE_FENCE_UPDATE, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_MoneyUpdate",
            EVENT_MONEY_UPDATE, OnMoneyUpdated)
        if EVENT_CURRENCY_UPDATE then
            em:RegisterForEvent(EVENT_NS .. "_CurrencyUpdate",
                EVENT_CURRENCY_UPDATE, OnMoneyUpdated)
        end
    end

    -- Expose helpers for use in Vendor module
    Vendor.GetActiveTabs = GetActiveTabs
    Vendor.GetToggleModePair = GetToggleModePair
    Vendor.IsSellBuybackOnlyStore = IsSellBuybackOnlyStore
    Vendor.IsFenceInteraction = function() return isFenceInteraction end
    Vendor.GetStableInteractionIcon = ResolveStableInteractionIcon
    Vendor.IsStableInteraction = function() return isStableInteraction end

    -- Register narration for Vendor scene (ACC-001)
    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_VENDOR_SCENE_NAME,
            function() return Vendor.instance and Vendor.instance.list and Vendor.instance.list:GetTargetData() end,
            function() return Vendor.instance and Vendor.instance:GetTitle() end
        )
    end

    Vendor.initialized = true
end

-- PUBLIC API

--- Check if the Vendor module has been initialized.
---@return boolean initialized True if Init() has completed
function BETTERUI.Vendor.IsInitialized()
    return Vendor.initialized == true
end

--- Check if a store is currently open.
---@return boolean isOpen True if the vendor scene is showing
function BETTERUI.Vendor.IsStoreOpen()
    if Vendor.instance and Vendor.instance:IsSceneShowing() then
        return true
    end
    return false
end
