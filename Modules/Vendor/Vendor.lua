--[[
File: Modules/Vendor/Vendor.lua
Purpose: Vendor orchestration surface for scene lifecycle, event wiring, and
         runtime coordination across the extracted vendor services.
]]

-- LOCAL STATE
local Vendor      = BETTERUI.Vendor
local MODE        = Vendor.MODE
local EVENT_NS    = "BetterUI_Vendor"

-- Tracks whether current interaction is fence (true) or regular store (false)
local isFenceInteraction = false
local isStableInteraction = false

-- Tracks which fence modes are enabled for the current fence interaction
local fenceEnableSell    = false
local fenceEnableLaunder = false
Vendor._sessionHasBuyMode = false

local SELL_ALL_JUNK_GAMEPAD_DIALOG_NAME = "BETTERUI_VENDOR_SELL_ALL_JUNK_DIALOG"
local DEFAULT_STABLE_INTERACTION_ICON = "EsoUI/Art/Collections/Default/collections_default_mount.dds"

local function ResolveVendorRuntimeDependency(fieldName, label)
    local dependency = Vendor[fieldName]
    assert(dependency, string.format("Vendor %s must load before Vendor runtime use", label))
    return dependency
end

local function IsSellVengeanceModeAvailable()
    return rawget(_G, "BAG_VENGEANCE") ~= nil
        and rawget(_G, "ZO_VENGEANCE_BAG_SELL_ENABLED") == true
        and type(IsCurrentCampaignVengeanceRuleset) == "function"
        and IsCurrentCampaignVengeanceRuleset()
end

local function HasVendorBuyInventory(context)
    local executeSafely = ResolveVendorRuntimeDependency("ExecuteSafely", "safe execute helper")
    if type(IsStoreEmpty) == "function" then
        local okStoreEmpty, isStoreEmpty = executeSafely(context .. ":IsStoreEmpty", IsStoreEmpty)
        if okStoreEmpty then
            return not isStoreEmpty
        end
    end

    if type(GetNumStoreItems) == "function" then
        local okStoreCount, storeCount = executeSafely(context .. ":GetNumStoreItems", GetNumStoreItems)
        if okStoreCount and type(storeCount) == "number" then
            return storeCount > 0
        end
    end

    return false
end

local function RunVendorSetupStep(stepName, setupFn)
    local ok, err = ResolveVendorRuntimeDependency("ExecuteSafely", "safe execute helper")(
        "Vendor.Init:" .. tostring(stepName),
        setupFn
    )
    if not ok and BETTERUI.Debug then
        BETTERUI.Debug(string.format("[Vendor] %s failed: %s", tostring(stepName), tostring(err)))
    end
    return ok, err
end

-- TAB DEFINITIONS

---@alias VendorTabDef {mode: number, name: fun(): string}
---@alias BetterUIVendorModeSet table<number, boolean>
---@alias BetterUIVendorTargetData table

---@class BetterUIVendorBatchItem
---@field dataSource BetterUIVendorBatchItem|nil
---@field entryIndex integer|nil
---@field bagId integer|nil
---@field slotIndex integer|nil
---@field stackCount integer|nil
---@field uniqueId integer|string|nil

---@class BetterUIVendorSellAllJunkComponent
---@field SellAllJunk fun(self: BetterUIVendorSellAllJunkComponent, vendorInstance: BETTERUI.Vendor.Class)

local function BuildModeTab(mode)
    return {
        mode = mode,
        name = function()
            if Vendor.ResolveModeName then
                return Vendor.ResolveModeName(mode)
            end
            return tostring(mode)
        end,
    }
end

local function BuildModeTabs(modes)
    local tabs = {}
    for _, mode in ipairs(modes or {}) do
        tabs[#tabs + 1] = BuildModeTab(mode)
    end
    return tabs
end

local function IsModeTabAvailable(mode)
    return mode ~= MODE.SELL_VENGEANCE or IsSellVengeanceModeAvailable()
end

-- Regular vendor tabs (Buy, Sell, Repair, Buyback)
---@type VendorTabDef[]
local VENDOR_TABS = BuildModeTabs({
    MODE.BUY,
    MODE.SELL,
    MODE.SELL_VENGEANCE,
    MODE.REPAIR,
    MODE.STABLE,
    MODE.BUYBACK,
})

---@type VendorTabDef[]
local STABLE_TABS = BuildModeTabs({ MODE.BUY, MODE.REPAIR, MODE.STABLE })

-- Fence tabs (Sell Stolen, Launder)
---@type VendorTabDef[]
local FENCE_TABS = BuildModeTabs({ MODE.FENCE_SELL, MODE.FENCE_LAUNDER })

---@return VendorTabDef[]
local function BuildFallbackVendorTabs()
    local tabs = {}
    for _, tab in ipairs(VENDOR_TABS) do
        if IsModeTabAvailable(tab.mode) then
            tabs[#tabs + 1] = tab
        end
    end
    return tabs
end

---@return boolean
local function IsNativeStableModeActive()
    if Vendor.ModePolicy and Vendor.ModePolicy.IsNativeStableModeActive then
        return Vendor.ModePolicy.IsNativeStableModeActive(rawget(_G, "STORE_WINDOW_GAMEPAD"))
    end
    return false
end

-- GET ACTIVE TABS

---@return VendorTabDef[] tabs Active tab definitions
local function GetActiveTabs()
    if Vendor.ModePolicy then
        if isFenceInteraction and Vendor.ModePolicy.GetFenceActiveTabs then
            return Vendor.ModePolicy.GetFenceActiveTabs({
                fenceTabs = FENCE_TABS,
                enableSell = fenceEnableSell == true,
                enableLaunder = fenceEnableLaunder == true,
            })
        end
        if Vendor.ModePolicy.GetStoreActiveTabs then
            local sourceTabs = isStableInteraction and STABLE_TABS or VENDOR_TABS
            local fallbackTabs = isStableInteraction and STABLE_TABS or BuildFallbackVendorTabs()
            return Vendor.ModePolicy.GetStoreActiveTabs({
                sourceTabs = sourceTabs,
                fallbackTabs = fallbackTabs,
                includeBuyFromSession = Vendor._sessionHasBuyMode == true,
                includeStableRepair = isStableInteraction == true,
                isModeTabAvailable = IsModeTabAvailable,
                storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD"),
            })
        end
    end
    return BuildFallbackVendorTabs()
end

---@return boolean
local function IsSellBuybackOnlyStore()
    if not (Vendor.ModePolicy and Vendor.ModePolicy.BuildActiveModeSet and Vendor.ModePolicy.IsSellBuybackOnlyModeSet) then
        return false
    end
    local modeSet = Vendor.ModePolicy.BuildActiveModeSet(GetActiveTabs())
    return Vendor.ModePolicy.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)
end

---@return number|nil firstMode
---@return number|nil secondMode
local function GetToggleModePair()
    if Vendor.ModePolicy then
        if isFenceInteraction and Vendor.ModePolicy.GetFenceToggleModePair then
            return Vendor.ModePolicy.GetFenceToggleModePair()
        end
        if isStableInteraction and Vendor.ModePolicy.GetStableToggleModePair then
            return Vendor.ModePolicy.GetStableToggleModePair()
        end
        if Vendor.ModePolicy.GetStoreToggleModePair then
            return Vendor.ModePolicy.GetStoreToggleModePair({
                tabs = GetActiveTabs(),
                sessionHasBuyMode = Vendor._sessionHasBuyMode == true,
            })
        end
    end
    return nil, nil
end

---@param vendorInstance BETTERUI.Vendor.Class|nil
---@return BetterUIVendorTargetData|nil
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
    if Vendor.ModePolicy then
        local request = {
            tabs = tabs or {},
            storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD"),
            hasVendorBuyInventory = function()
                return HasVendorBuyInventory("Vendor.ResolveInitialStoreMode")
            end,
        }
        local resolver = nil
        if isStableInteraction and Vendor.ModePolicy.ResolveStableInitialStoreMode then
            resolver = Vendor.ModePolicy.ResolveStableInitialStoreMode
        elseif Vendor.ModePolicy.ResolveVendorInitialStoreMode then
            request.vendorTabs = VENDOR_TABS
            resolver = Vendor.ModePolicy.ResolveVendorInitialStoreMode
        end

        if resolver then
            local targetMode, shouldRememberBuyMode = resolver(request)
            if shouldRememberBuyMode then
                Vendor._sessionHasBuyMode = true
            end
            return targetMode
        end
    end

    return (tabs and tabs[1] and tabs[1].mode) or MODE.SELL
end

local function LogVendorDebug(flagName, category, message)
    if Vendor.LogDebug then
        Vendor.LogDebug(flagName, category, message)
    end
end

local function LogNativeStoreInputState(context, storeManager)
    local bridge = Vendor.NativeStoreBridge
    if bridge and bridge.LogInputState then
        bridge.LogInputState(context, storeManager)
    end
end

local function EnsureNativeStoreComponents(searchContext)
    ResolveVendorRuntimeDependency("NativeStoreBridge", "native store bridge").EnsureComponents(searchContext)
end

Vendor.EnsureNativeStoreComponents = EnsureNativeStoreComponents

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

local function ResetVendorInteractionState()
    isFenceInteraction = false
    isStableInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false
    Vendor._sessionHasBuyMode = false
    Vendor._isClosing = false
    Vendor._openStoreSyncAttempt = 0
end

local function MarkVendorClosingState()
    isFenceInteraction = false
    isStableInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false
    Vendor._sessionHasBuyMode = false
    Vendor._isClosing = true
    Vendor._openStoreSyncAttempt = 0
end

local function ResetVendorRuntimeState(instance)
    if not instance then
        return
    end

    if Vendor.ModePolicy and Vendor.ModePolicy.ResetCategoryState then
        Vendor.ModePolicy.ResetCategoryState(instance)
    else
        instance._cachedBuyCategories = nil
    end

    if Vendor.Tasks then
        Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
        Vendor.Tasks:Cancel("buyActivateRefresh")
        Vendor.Tasks:Cancel("buyListRetry")
        Vendor.Tasks:Cancel("footerRefresh")
    end

    -- A cancelled buyListRetry leaves the counter at >=1; the next store
    -- visit would then short-circuit its guaranteed first empty-list retry.
    instance._buyListRetryCount = 0
end

local function ResetActiveVendorRuntimeState()
    if Vendor.instance then
        ResetVendorRuntimeState(Vendor.instance)
    end
end

local function CancelVendorRuntimeTasks()
    if Vendor.Tasks then
        Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
        Vendor.Tasks:Cancel("buyActivateRefresh")
        Vendor.Tasks:Cancel("buyListRetry")
        Vendor.Tasks:Cancel("listRefresh")
        Vendor.Tasks:Cancel("footerRefresh")
        Vendor.Tasks:Cancel("directionalInputNormalize")
    end
end

local function RunVendorCloseCleanup(instance)
    if not instance or instance._vendorCloseCleanupApplied == true then
        return
    end

    instance._vendorCloseCleanupApplied = true

    if instance.DisableStablePreviewMode then
        instance:DisableStablePreviewMode()
    end
    if instance.ReleaseNativeStoreInputOwnership then
        instance:ReleaseNativeStoreInputOwnership()
    end
    if instance.ForceReleaseDirectionalInput then
        instance:ForceReleaseDirectionalInput()
    end
end

Vendor.ResetRuntimeState = ResetActiveVendorRuntimeState
Vendor.CancelRuntimeTasks = CancelVendorRuntimeTasks

local function ApplyVendorInteractionState(nextState)
    if not nextState then
        return
    end

    if nextState.isFenceInteraction ~= nil then
        isFenceInteraction = nextState.isFenceInteraction == true
    end
    if nextState.isStableInteraction ~= nil then
        isStableInteraction = nextState.isStableInteraction == true
    end
    if nextState.fenceEnableSell ~= nil then
        fenceEnableSell = nextState.fenceEnableSell == true
    end
    if nextState.fenceEnableLaunder ~= nil then
        fenceEnableLaunder = nextState.fenceEnableLaunder == true
    end
    if nextState.sessionHasBuyMode ~= nil then
        Vendor._sessionHasBuyMode = nextState.sessionHasBuyMode == true
    end
    if nextState.isClosing ~= nil then
        Vendor._isClosing = nextState.isClosing == true
    end
    if nextState.openStoreSyncAttempt ~= nil then
        Vendor._openStoreSyncAttempt = nextState.openStoreSyncAttempt or 0
    end
end

local VendorLifecycleRuntime = {}

function VendorLifecycleRuntime:ResetInteractionState(instance)
    ResetVendorInteractionState()
    if instance then
        instance._vendorCloseCleanupApplied = false
    end
end

function VendorLifecycleRuntime:MarkClosingState()
    MarkVendorClosingState()
end

function VendorLifecycleRuntime:SetInteractionState(nextState)
    ApplyVendorInteractionState(nextState)
end

function VendorLifecycleRuntime:ResetRuntimeState(instance)
    ResetVendorRuntimeState(instance)
end

function VendorLifecycleRuntime:CancelRuntimeTasks()
    CancelVendorRuntimeTasks()
end

function VendorLifecycleRuntime:ShowScene()
    if SCENE_MANAGER then
        SCENE_MANAGER:Show(BETTERUI_VENDOR_SCENE_NAME)
    end
end

function VendorLifecycleRuntime:HideScene()
    if not SCENE_MANAGER then
        return
    end

    local scene = SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if scene and scene.IsShowing and scene:IsShowing() then
        SCENE_MANAGER:Hide(BETTERUI_VENDOR_SCENE_NAME)
    end
end

function VendorLifecycleRuntime:LogDebug(flagName, category, message)
    LogVendorDebug(flagName, category, message)
end

function VendorLifecycleRuntime:LogNativeStoreInputState(context, storeManager)
    LogNativeStoreInputState(context, storeManager)
end

function VendorLifecycleRuntime:SafeCall(context, fn, ...)
    return ResolveVendorRuntimeDependency("ExecuteSafely", "safe execute helper")(context, fn, ...)
end

function VendorLifecycleRuntime:GetStoreManager()
    return rawget(_G, "STORE_WINDOW_GAMEPAD")
end

function VendorLifecycleRuntime:RunCloseCleanup(instance)
    return RunVendorCloseCleanup(instance)
end

-- KEYBINDS

-- Forward declarations for helper callbacks referenced from keybind descriptors.
-- Without these declarations Lua resolves names as globals inside closures.
local IsMultiSelectAvailable
local CanMultiSelectInCurrentMode
local RegisterVendorBatchDialog

---@param vendorInstance BETTERUI.Vendor.Class
---@return BetterUIKeybindDescriptorGroup keybindGroup Core keybind descriptor group
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
                    return BETTERUI.CIM.Keybinds.GetMultiSelectToggleLabel(ms, GetCurrentVendorTargetData(vendorInstance))
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
                local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
                if searchMixin and searchMixin.CallSearchLifecycle then
                    searchMixin.CallSearchLifecycle(vendorInstance, "clear")
                elseif vendorInstance.ClearSearchInput then
                    vendorInstance:ClearSearchInput()
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
                    ResolveVendorRuntimeDependency("ExecuteSafely", "safe execute helper")(
                        "Vendor.RegisterBatchDialog",
                        RegisterVendorBatchDialog
                    )
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
            name = function() return BETTERUI.CIM.Keybinds.GetMultiSelectLabel() end,
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
                local selectedData = GetCurrentVendorTargetData(vendorInstance)
                if Vendor.SelectionRuntime and Vendor.SelectionRuntime.CanSelectionPreview then
                    return Vendor.SelectionRuntime.CanSelectionPreview(vendorInstance, selectedData, isStableInteraction)
                end
                return false
            end,
            enabled = function()
                return true
            end,
            callback = function()
                if Vendor.SelectionRuntime and Vendor.SelectionRuntime.ToggleSelectionPreview then
                    Vendor.SelectionRuntime.ToggleSelectionPreview(vendorInstance, isStableInteraction)
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

Vendor._internals = Vendor._internals or {}

function Vendor._internals.ExecuteBatchAction(mode, itemData)
    return ResolveVendorRuntimeDependency("BatchRuntime", "batch runtime").ExecuteBatchAction(mode, itemData)
end

---@param request BetterUIVendorBatchRequest
---@return BetterUIVendorBatchRequest
local function AssertVendorBatchRequest(request)
    assert(type(request) == "table", "Vendor.ExecuteBatchThrottled expects BetterUIVendorBatchRequest table")
    assert(request.batchOptions == nil,
        "Vendor.ExecuteBatchThrottled expects request.options; legacy request.batchOptions is not part of the public API contract")
    return request
end

local LEGACY_BATCH_OPTION_KEYS = {
    "serverBound",
    "costPerItem",
    "skipInterBatchCooldown",
    "minServerDelayMs",
    "maxServerDelayMs",
    "cooldownEvery",
    "cooldownMs",
    "chunkCostUnits",
    "chunkPauseMs",
    "adaptiveDelay",
    "adaptiveThreshold",
    "adaptiveStepMs",
    "jitterMs",
    "awaitInventoryAck",
    "ackTimeoutMs",
    "countTowardRateOnSuccess",
    "enforceRateWindow",
    "rateLimitWindowMs",
    "rateLimitMaxActions",
    "postBatchCooldownBaseMs",
    "postBatchCooldownThreshold",
    "postBatchCooldownPerCostMs",
    "postBatchCooldownMaxMs",
}

local function AssertPublicBatchOptionsContract(batchOptions)
    if type(batchOptions) ~= "table" then
        return batchOptions
    end

    for _, key in ipairs(LEGACY_BATCH_OPTION_KEYS) do
        assert(batchOptions[key] == nil,
            string.format("Vendor.ResolveBatchOptions expects grouped options; legacy flat key `%s` is no longer part of the public contract", key))
    end

    return batchOptions
end

--- Processes vendor batch actions through a throttled pipeline with overlay progress.
---@param request BetterUIVendorBatchRequest
function Vendor.ExecuteBatchThrottled(request)
    request = AssertVendorBatchRequest(request)
    ResolveVendorRuntimeDependency("BatchRuntime", "batch runtime").ExecuteBatchThrottled(request)
end

--- Requests abort of the current vendor batch operation.
function Vendor.RequestBatchAbort()
    ResolveVendorRuntimeDependency("BatchRuntime", "batch runtime").RequestBatchAbort()
end

---@return BatchOptions
function Vendor.GetDefaultBatchOptions()
    return ResolveVendorRuntimeDependency("BatchRuntime", "batch runtime").GetDefaultBatchOptions()
end

---@param batchOptions BatchOptions|table|nil
---@return BatchOptions
function Vendor.ResolveBatchOptions(batchOptions)
    batchOptions = AssertPublicBatchOptionsContract(batchOptions)
    local batchRuntime = ResolveVendorRuntimeDependency("BatchRuntime", "batch runtime")
    local internals = batchRuntime and batchRuntime._internals or nil
    local resolveBatchOptions = internals and internals.ResolveBatchOptions or batchRuntime.ResolveBatchOptions
    assert(type(resolveBatchOptions) == "function", "Vendor batch runtime must expose internal option normalization")
    return resolveBatchOptions(batchOptions)
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
---@param component BetterUIVendorSellAllJunkComponent
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
                local ok = ResolveVendorRuntimeDependency("ExecuteSafely", "safe execute helper")(
                    "Vendor.RegisterSellAllJunkDialog",
                    RegisterVendorSellAllJunkDialog
                )
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
            local ms = Vendor.multiSelectManager
            if ms then
                local selectedCount = ms:GetSelectedCount()
                local selectedItems = ms.GetSelectedItems and ms:GetSelectedItems() or {}
                local totalItems = (Vendor.instance and Vendor.instance.list and Vendor.instance.list:GetNumItems()) or 0
                local allSelected = selectedCount > 0 and selectedCount == totalItems
                if not allSelected then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(
                            BETTERUI.CIM.Keybinds.GetSelectAllLabel(),
                            "selectAll"
                        ))
                end
                if selectedCount > 0 then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(
                            BETTERUI.CIM.Keybinds.GetDeselectAllLabel(selectedCount),
                            "deselectAll"
                        ))
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
                        table.insert(parametricList,
                            BETTERUI.CIM.Dialogs.CreateParametricActionEntry(batchLabel, "batch"))
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
                    Vendor.ExecuteBatchThrottled({
                        mode = currentMode,
                        items = items,
                        onComplete = function()
                            if ms then ms:ClearSelections() end
                            if Vendor.instance then
                                -- The final batch ack already scheduled the
                                -- coalesced "listRefresh" task; this direct
                                -- refresh renders the same final state, so drop
                                -- the pending duplicate rebuild (and take over
                                -- its footer refresh). Later inventory events
                                -- re-schedule the task as usual.
                                if Vendor.Tasks then
                                    Vendor.Tasks:Cancel("listRefresh")
                                end
                                Vendor.instance:SaveListPosition()
                                Vendor.instance:RefreshList()
                                if Vendor.instance.RefreshVendorFooter then
                                    Vendor.instance:RefreshVendorFooter()
                                end
                                Vendor.instance:EnsureListInputActive()
                            end
                            if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                            end
                        end,
                    })
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
    -- Native ZO_GamepadStoreManager gates its OnOpenStore on gamepad-preferred
    -- mode; in keyboard mode the keyboard store owns the interaction and our
    -- gamepad scene must not take over. Remember that we opened so the matching
    -- close still cleans up after a mid-interaction mode switch.
    if IsInGamepadPreferredMode and not IsInGamepadPreferredMode() then
        Vendor._openedInGamepadMode = false
        return
    end
    Vendor._openedInGamepadMode = true
    ResolveVendorRuntimeDependency("InteractionRuntime", "interaction runtime")
        .OpenStore({
            runtime = VendorLifecycleRuntime,
            nativeStoreBridge = ResolveVendorRuntimeDependency("NativeStoreBridge", "native store bridge"),
            instance = Vendor.instance,
            options = {
                interactionType = GetInteractionType and GetInteractionType() or nil,
                interactionVendor = INTERACTION_VENDOR,
                interactionStable = INTERACTION_STABLE,
                isNativeStableModeActive = IsNativeStableModeActive,
            }
        })
end

---@param _ any Unused event code
---@param enableSell boolean|nil Whether fence sell is enabled (default true)
---@param enableLaunder boolean|nil Whether fence launder is enabled (default true)
local function OnOpenFence(_, enableSell, enableLaunder)
    -- Same gamepad-mode gate as OnOpenStore (native parity).
    if IsInGamepadPreferredMode and not IsInGamepadPreferredMode() then
        Vendor._openedInGamepadMode = false
        return
    end
    Vendor._openedInGamepadMode = true
    ResolveVendorRuntimeDependency("InteractionRuntime", "interaction runtime")
        .OpenFence({
            runtime = VendorLifecycleRuntime,
            nativeStoreBridge = ResolveVendorRuntimeDependency("NativeStoreBridge", "native store bridge"),
            instance = Vendor.instance,
            options = {
                sellMode = MODE.FENCE_SELL,
                fenceLaunderMode = MODE.FENCE_LAUNDER,
            },
            enableSell = enableSell,
            enableLaunder = enableLaunder,
        })
end

local function OnStableInteractStart()
    VendorLifecycleRuntime:SetInteractionState({
        isStableInteraction = true,
    })
end

local function OnStableInteractEnd()
    VendorLifecycleRuntime:SetInteractionState({
        isStableInteraction = false,
    })
end

local function OnCloseStore()
    -- Unlike the open handlers, close is NOT gated on the current preferred
    -- mode: a store opened in gamepad mode must still clean up even if the
    -- player switched to keyboard mid-interaction. Only skip when we never
    -- opened (i.e. the open was suppressed because it started in keyboard mode).
    if Vendor._openedInGamepadMode == false then
        return
    end
    Vendor._openedInGamepadMode = false
    ResolveVendorRuntimeDependency("InteractionRuntime", "interaction runtime")
        .CloseStore({
            runtime = VendorLifecycleRuntime,
            nativeStoreBridge = ResolveVendorRuntimeDependency("NativeStoreBridge", "native store bridge"),
            instance = Vendor.instance,
        })
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

---@param _ any Unused event code
---@param reason number|nil ItemRepairReason (nil = repair-all could not afford)
local function OnRepairFailure(_, reason)
    -- Surface the failure (native ZO_GamepadStoreManager:FailedRepairMessageBox,
    -- storewindow_gamepad.lua:620-633), then still refresh so the list reflects
    -- any partial repair state.
    local message
    if reason == rawget(_G, "ITEM_REPAIR_ALREADY_REPAIRED") then
        message = GetString(rawget(_G, "SI_ITEMREPAIRREASON1") or "SI_ITEMREPAIRREASON1")
    elseif reason == rawget(_G, "ITEM_REPAIR_CANT_AFFORD_REPAIR") then
        message = GetString(rawget(_G, "SI_ITEMREPAIRREASON2") or "SI_ITEMREPAIRREASON2")
    elseif reason == nil then
        message = GetString(rawget(_G, "SI_REPAIR_ALL_CANNOT_AFFORD") or "SI_REPAIR_ALL_CANNOT_AFFORD")
    end
    if message and message ~= "" and BETTERUI.CIM and BETTERUI.CIM.UserAlertText then
        BETTERUI.CIM.UserAlertText("Vendor:RepairFailure", message)
    end
    OnInventoryUpdated()
end

-- INITIALIZATION

local function RegisterVendorComponents(instance)
    ResolveVendorRuntimeDependency("ComponentCatalog", "component catalog").Register(instance)
end

local function AddVendorColumns(instance)
    local COL = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_NAME") or "SI_BETTERUI_BANKING_COLUMN_NAME"), COL.NAME)
    instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TYPE") or "SI_BETTERUI_BANKING_COLUMN_TYPE"), COL.TYPE)
    instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TRAIT") or "SI_BETTERUI_BANKING_COLUMN_TRAIT"), COL.TRAIT)
    instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_STAT") or "SI_BETTERUI_BANKING_COLUMN_STAT"), COL.STAT)
    instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_VALUE") or "SI_BETTERUI_BANKING_COLUMN_VALUE"), COL.VALUE)
end

local function InitializeVendorList(instance)
    ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").InitializeList(instance, {
        rowSetup = BETTERUI.Vendor.VendorEntrySetup,
        addColumns = AddVendorColumns,
    })
end

local function InitializeVendorSearch(instance)
    ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").InitializeSearch(instance)
end

local function InitializeVendorInteractiveSurfaces(instance)
    ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").InitializeInteractiveSurfaces(instance, {
        buildCoreKeybinds = BuildCoreKeybinds,
        runVendorSetupStep = RunVendorSetupStep,
    })
end

local function CreateVendorScene(instance)
    ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").CreateScene(instance)
end

local function TakeOverNativeStoreScene(instance)
    ResolveVendorRuntimeDependency("NativeStoreBridge", "native store bridge").TakeOverScene(instance)
end

local function RegisterVendorSceneLifecycle(instance)
    ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").RegisterSceneLifecycle(instance, {
        taskManager = Vendor.Tasks,
    })
end

local function RegisterVendorEvents(eventManager)
    ResolveVendorRuntimeDependency("EventBridge", "event bridge").Register(eventManager, EVENT_NS, {
        onStableInteractStart = OnStableInteractStart,
        onStableInteractEnd = OnStableInteractEnd,
        onStableInfoUpdated = OnInventoryUpdated,
        onOpenStore = OnOpenStore,
        onOpenFence = OnOpenFence,
        onCloseStore = OnCloseStore,
        onInventoryUpdated = OnInventoryUpdated,
        onSellReceipt = OnSellReceipt,
        onRepairFailure = OnRepairFailure,
        onMoneyUpdated = OnMoneyUpdated,
    })
end

local function ExposeVendorRuntimeHelpers()
    Vendor.GetActiveTabs = GetActiveTabs
    Vendor.GetToggleModePair = GetToggleModePair
    Vendor.IsSellBuybackOnlyStore = IsSellBuybackOnlyStore
    Vendor.IsFenceInteraction = function() return isFenceInteraction end
    Vendor.GetStableInteractionIcon = Vendor.ResolveStableInteractionIcon or function()
        return DEFAULT_STABLE_INTERACTION_ICON
    end
    Vendor.IsStableInteraction = function() return isStableInteraction end
    Vendor.IsSellVengeanceModeAvailable = IsSellVengeanceModeAvailable
    Vendor.HasVendorBuyInventory = HasVendorBuyInventory
    Vendor.ResolveInitialStoreMode = ResolveInitialStoreMode
    Vendor.RunLifecycleCloseCleanup = RunVendorCloseCleanup
    Vendor.UpdateSceneManagerStoreAlias = function()
        ResolveVendorRuntimeDependency("NativeStoreBridge", "native store bridge")
            .UpdateSceneManagerStoreAlias(Vendor.instance)
    end
end

local function RegisterVendorNarration()
    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_VENDOR_SCENE_NAME,
            function() return Vendor.instance and Vendor.instance.list and Vendor.instance.list:GetTargetData() end,
            function() return Vendor.instance and Vendor.instance:GetTitle() end
        )
    end
end

--- Initializes the Vendor module.
---@return nil
function BETTERUI.Vendor.Init()
    if Vendor.initialized then return end

    local instance = Vendor.Class:New("BETTERUI_VendorWindow", BETTERUI_VENDOR_SCENE_NAME)
    Vendor.instance = instance
    instance:SetTitle("|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_VENDOR_TITLE")) .. "|r")

    RegisterVendorComponents(instance)
    InitializeVendorList(instance)
    InitializeVendorSearch(instance)
    InitializeVendorInteractiveSurfaces(instance)
    CreateVendorScene(instance)
    TakeOverNativeStoreScene(instance)
    RegisterVendorSceneLifecycle(instance)
    ResolveVendorRuntimeDependency("NativeStoreBridge", "native store bridge").AliasSceneToBetterUI(Vendor.instance)
    instance:InitVendorFooter()
    RegisterVendorEvents(EVENT_MANAGER)
    ExposeVendorRuntimeHelpers()
    RegisterVendorNarration()

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
