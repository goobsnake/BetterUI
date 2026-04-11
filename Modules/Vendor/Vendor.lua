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

-- Tracks whether current interaction is fence (true) or regular store (false)
local isFenceInteraction = false

-- Tracks which fence modes are enabled for the current fence interaction
local fenceEnableSell    = false
local fenceEnableLaunder = false

-- TAB DEFINITIONS

---@alias VendorTabDef {mode: number, name: fun(): string}

-- Regular vendor tabs (Buy, Sell, Repair, Buyback)
---@type VendorTabDef[]
local VENDOR_TABS = {
    { mode = MODE.BUY,     name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY")) end },
    { mode = MODE.SELL,    name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL")) end },
    { mode = MODE.REPAIR,  name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_REPAIR")) end },
    { mode = MODE.BUYBACK, name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUYBACK")) end },
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
    local tabs = {}
    for _, tab in ipairs(VENDOR_TABS) do
        local nativeMode = ResolveNativeModeForVendorMode(tab.mode)
        if nativeMode and activeModeSet[nativeMode] then
            tabs[#tabs + 1] = tab
        end
    end

    if #tabs == 0 then
        -- Fall back to legacy behavior when native components are not ready yet.
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
        return nil, nil
    end

    local modeSet = BuildActiveModeSet(GetActiveTabs())
    if modeSet[MODE.BUY] and modeSet[MODE.SELL] then
        return MODE.BUY, MODE.SELL
    end
    if IsSellBuybackOnlyModeSet(modeSet) then
        return MODE.SELL, MODE.BUYBACK
    end

    return nil, nil
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
    end

    if IsSellBuybackOnlyModeSet(modeSet) then
        return MODE.SELL
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

local function SafeCall(context, fn, ...)
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
    local includeBuy = true
    if type(IsStoreEmpty) == "function" then
        local okStoreEmpty, isStoreEmpty = SafeCall("Vendor.EnsureNativeStoreComponents:IsStoreEmpty", IsStoreEmpty)
        includeBuy = okStoreEmpty and (not isStoreEmpty) or false
    end

    local needRebuild = (#componentTable == 0)
        or (not isFenceInteraction and includeBuy and buyMode ~= nil and not seenActiveModes[buyMode])
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

    for _, mode in ipairs(componentTable) do
        AddMode(mode)
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

---@param vendorInstance BETTERUI.Vendor.Class|table|nil
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

-- KEYBINDS

---@param vendorInstance BETTERUI.Vendor.Class
---@return table keybindGroup Core keybind descriptor group
local function BuildCoreKeybinds(vendorInstance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            ethereal = true,
            visible = function()
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
                return #GetActiveTabs() > 1
            end,
            callback = function()
                vendorInstance:CycleTabs(1)
            end,
        },
        -- Primary action (keybind A / GAMEPAD_BUTTON_1)
        {
            name = function()
                local component = vendorInstance:GetActiveComponent()
                if component and component.GetPrimaryActionName then
                    return component:GetPrimaryActionName(vendorInstance)
                end
                return GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION"))
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local component = vendorInstance:GetActiveComponent()
                if component and component.OnPrimaryAction then
                    component:OnPrimaryAction(vendorInstance)
                end
            end,
            enabled = function()
                local component = vendorInstance:GetActiveComponent()
                if component and component.IsPrimaryActionEnabled then
                    return component:IsPrimaryActionEnabled(vendorInstance)
                end
                -- Disabled if no list data
                local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
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
                local firstMode, secondMode = GetToggleModePair()
                if not firstMode or not secondMode then
                    return false
                end
                local mode = vendorInstance:GetCurrentMode()
                if mode == firstMode or mode == secondMode then
                    return true
                end
                if vendorInstance.IsSellBuybackOnlyStore and vendorInstance:IsSellBuybackOnlyStore() then
                    return true
                end
                return false
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
        -- Tertiary action (Sell All Junk / Repair All)
        {
            name = function()
                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.SELL then
                    return GetString(rawget(_G, "SI_SELL_ALL_JUNK_KEYBIND_TEXT") or "SI_SELL_ALL_JUNK_KEYBIND_TEXT")
                end
                if mode == MODE.REPAIR then
                    local cost = GetRepairAllCost and GetRepairAllCost() or 0
                    if cost > 0 and zo_strformat and ZO_Currency_FormatGamepad then
                        local formatKind = ZO_CURRENCY_FORMAT_WHITE_AMOUNT_ICON
                        if GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) < cost then
                            formatKind = ZO_CURRENCY_FORMAT_ERROR_AMOUNT_ICON
                        end
                        return zo_strformat(
                            SI_REPAIR_ALL_KEYBIND_TEXT,
                            ZO_Currency_FormatGamepad(CURT_MONEY, cost, formatKind)
                        )
                    end
                    return GetString(rawget(_G, "SI_REPAIR_ALL_KEYBIND_TEXT") or "SI_REPAIR_ALL_KEYBIND_TEXT")
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
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
                local component = vendorInstance:GetActiveComponent()
                if not component then return end
                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.SELL and component.SellAllJunk then
                    ZO_Dialogs_ShowGamepadDialog("SELL_ALL_JUNK")
                    return
                end
                if mode == MODE.REPAIR and component.RepairAll then
                    component:RepairAll(vendorInstance)
                end
            end,
        },
        -- Back / Exit (keybind B / GAMEPAD_BUTTON_2)
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                -- Close the interaction
                SCENE_MANAGER:HideCurrentScene()
            end,
        },
    }
end

-- TAB CYCLING

---@param direction number -1 for left, 1 for right
function BETTERUI.Vendor.Class:CycleTabs(direction)
    local tabs = GetActiveTabs()
    if #tabs <= 1 then return end

    -- Find current tab index
    local currentMode = self:GetCurrentMode()
    local currentIndex = 1
    for i, tab in ipairs(tabs) do
        if tab.mode == currentMode then
            currentIndex = i
            break
        end
    end

    local newIndex
    if Vendor.GetSetting("enableCarousel") == false then
        newIndex = currentIndex + direction
        if newIndex < 1 or newIndex > #tabs then
            return
        end
    else
        -- Carousel navigation wraps around at both ends.
        newIndex = ((currentIndex - 1 + direction) % #tabs) + 1
    end
    self._preferredModeHeaderSelectionMode = tabs[newIndex].mode
    self:SetMode(tabs[newIndex].mode)
end

-- EVENT HANDLERS

local function OnOpenStore()
    isFenceInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false
    Vendor._isClosing = false
    Vendor._openStoreSyncAttempt = 0

    if not Vendor.instance then return end
    if Vendor.Tasks then
        Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
        Vendor.Tasks:Cancel("buyActivateRefresh")
        Vendor.Tasks:Cancel("buyListRetry")
    end

    local interactionType = GetInteractionType and GetInteractionType() or nil
    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenStore interaction=%s fence=%s", tostring(interactionType), tostring(isFenceInteraction))
    )

    -- Stable shares EVENT_OPEN_STORE and the native store scene.
    -- Leave native ownership in place for stable interactions.
    if interactionType == INTERACTION_STABLE then
        local customScene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
        if customScene and customScene.IsShowing and customScene:IsShowing() then
            SCENE_MANAGER:Hide(BETTERUI_VENDOR_SCENE_NAME)
        end
        RestoreNativeStoreSceneAlias()
        if SCENE_MANAGER then
            SCENE_MANAGER:Show("gamepad_store")
        end
        return
    end

    if interactionType and interactionType ~= INTERACTION_VENDOR then
        RestoreNativeStoreSceneAlias()
        return
    end

    AliasStoreSceneToBetterUI()
    if Vendor.instance.ReleaseNativeStoreInputOwnership then
        Vendor.instance:ReleaseNativeStoreInputOwnership()
    end
    EnsureNativeStoreComponents("storeTextSearch")

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
    fenceEnableSell = (enableSell ~= false)     -- default true
    fenceEnableLaunder = (enableLaunder ~= false) -- default true
    Vendor._isClosing = false
    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenFence sell=%s launder=%s", tostring(fenceEnableSell), tostring(fenceEnableLaunder))
    )

    if not Vendor.instance then return end
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

local function OnCloseStore()
    Vendor._isClosing = true
    isFenceInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false
    Vendor._openStoreSyncAttempt = 0

    if Vendor.Tasks then
        Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
        Vendor.Tasks:Cancel("buyActivateRefresh")
        Vendor.Tasks:Cancel("buyListRetry")
        Vendor.Tasks:Cancel("listRefresh")
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
        end
    end)
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
        Vendor.instance:OnItemSelectedChange(list, selectedData)
        Vendor.instance:UpdateScrollIndicator(list)
    end)

    -- Add column headers (matching Inventory/Banking layout)
    local COL = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_NAME") or "SI_BETTERUI_BANKING_COLUMN_NAME"), COL.NAME)
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TYPE") or "SI_BETTERUI_BANKING_COLUMN_TYPE"), COL.TYPE)
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TRAIT") or "SI_BETTERUI_BANKING_COLUMN_TRAIT"), COL.TRAIT)
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_STAT") or "SI_BETTERUI_BANKING_COLUMN_STAT"), COL.STAT)
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_VALUE") or "SI_BETTERUI_BANKING_COLUMN_VALUE"), COL.VALUE)
    Vendor.instance:InitializeCategoryHeader()
    Vendor.instance:InitializeScrollIndicator()

    -- Build keybinds
    Vendor.instance.coreKeybinds = BuildCoreKeybinds(Vendor.instance)

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
            screen._suppressListUpdates = false
            screen._isDirty = false
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
    end

    -- Expose helpers for use in Vendor module
    Vendor.GetActiveTabs = GetActiveTabs
    Vendor.GetToggleModePair = GetToggleModePair
    Vendor.IsSellBuybackOnlyStore = IsSellBuybackOnlyStore
    Vendor.IsFenceInteraction = function() return isFenceInteraction end

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
