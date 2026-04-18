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
local NativeStoreBridge = assert(Vendor.NativeStoreBridge, "Vendor native store bridge must load before Vendor.lua")

-- Tracks whether current interaction is fence (true) or regular store (false)
local isFenceInteraction = false
local isStableInteraction = false

-- Tracks which fence modes are enabled for the current fence interaction
local fenceEnableSell    = false
local fenceEnableLaunder = false
Vendor._sessionHasBuyMode = false

local SELL_ALL_JUNK_GAMEPAD_DIALOG_NAME = "BETTERUI_VENDOR_SELL_ALL_JUNK_DIALOG"

local function IsSellVengeanceModeAvailable()
    return rawget(_G, "BAG_VENGEANCE") ~= nil
        and rawget(_G, "ZO_VENGEANCE_BAG_SELL_ENABLED") == true
        and type(IsCurrentCampaignVengeanceRuleset) == "function"
        and IsCurrentCampaignVengeanceRuleset()
end

local function DefaultExecuteSafely(context, fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end

    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute then
        return BETTERUI.CIM.SafeExecute(context, fn, ...)
    end

    local ok, result = pcall(fn, ...)
    return ok, result
end

SafeCall = type(Vendor.ExecuteSafely) == "function" and Vendor.ExecuteSafely or DefaultExecuteSafely

local function HasVendorBuyInventory(context)
    if type(IsStoreEmpty) == "function" then
        local okStoreEmpty, isStoreEmpty = SafeCall(context .. ":IsStoreEmpty", IsStoreEmpty)
        if okStoreEmpty then
            return not isStoreEmpty
        end
    end

    if type(GetNumStoreItems) == "function" then
        local okStoreCount, storeCount = SafeCall(context .. ":GetNumStoreItems", GetNumStoreItems)
        if okStoreCount and type(storeCount) == "number" then
            return storeCount > 0
        end
    end

    return false
end

local function RunVendorSetupStep(stepName, setupFn)
    local ok, err = SafeCall("Vendor.Init:" .. tostring(stepName), setupFn)
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

---@param tabs VendorTabDef[]|nil
---@return BetterUIVendorModeSet
local function BuildActiveModeSet(tabs)
    if Vendor.ModePolicy and Vendor.ModePolicy.BuildActiveModeSet then
        return Vendor.ModePolicy.BuildActiveModeSet(tabs)
    end
    return {}
end

---@param modeSet BetterUIVendorModeSet|nil
---@return boolean
local function IsSellBuybackOnlyModeSet(modeSet)
    if Vendor.ModePolicy and Vendor.ModePolicy.IsSellBuybackOnlyModeSet then
        return Vendor.ModePolicy.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)
    end
    return false
end

-- GET ACTIVE TABS

---@return VendorTabDef[] tabs Active tab definitions
local function GetActiveTabs()
    if Vendor.ModePolicy and Vendor.ModePolicy.GetActiveTabs then
        return Vendor.ModePolicy.GetActiveTabs({
            isFenceInteraction = isFenceInteraction,
            isStableInteraction = isStableInteraction,
            fenceEnableSell = fenceEnableSell,
            fenceEnableLaunder = fenceEnableLaunder,
            sessionHasBuyMode = Vendor._sessionHasBuyMode == true,
            vendorTabs = VENDOR_TABS,
            stableTabs = STABLE_TABS,
            fenceTabs = FENCE_TABS,
            isModeTabAvailable = IsModeTabAvailable,
            storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD"),
        })
    end
    return BuildFallbackVendorTabs()
end

---@return boolean
local function IsSellBuybackOnlyStore()
    local modeSet = BuildActiveModeSet(GetActiveTabs())
    return IsSellBuybackOnlyModeSet(modeSet)
end

---@return number|nil firstMode
---@return number|nil secondMode
local function GetToggleModePair()
    if Vendor.ModePolicy and Vendor.ModePolicy.GetToggleModePair then
        return Vendor.ModePolicy.GetToggleModePair({
            isFenceInteraction = isFenceInteraction,
            isStableInteraction = isStableInteraction,
            sessionHasBuyMode = Vendor._sessionHasBuyMode == true,
            tabs = GetActiveTabs(),
        })
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
    if Vendor.ModePolicy and Vendor.ModePolicy.ResolveInitialStoreMode then
        local targetMode, shouldRememberBuyMode = Vendor.ModePolicy.ResolveInitialStoreMode({
            tabs = tabs or {},
            vendorTabs = VENDOR_TABS,
            isFenceInteraction = isFenceInteraction,
            isStableInteraction = isStableInteraction,
            storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD"),
            hasVendorBuyInventory = function()
                return HasVendorBuyInventory("Vendor.ResolveInitialStoreMode")
            end,
        })
        if shouldRememberBuyMode then
            Vendor._sessionHasBuyMode = true
        end
        return targetMode
    end

    return (tabs and tabs[1] and tabs[1].mode) or MODE.SELL
end

local function RestoreNativeStoreSceneAlias()
    NativeStoreBridge.RestoreSceneAlias()
end

local function AliasStoreSceneToBetterUI()
    NativeStoreBridge.AliasSceneToBetterUI(Vendor.instance)
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

local function EnsureNativeStoreComponents(searchContext)
    NativeStoreBridge.EnsureComponents(searchContext)
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
end

local function ApplyVendorResolvedMode(targetMode, refreshList)
    NativeStoreBridge.ApplyResolvedMode(targetMode, refreshList)
end

local function ResolveVendorTargetMode()
    return NativeStoreBridge.ResolveTargetMode()
end

local ScheduleVendorOpenStoreSync

ScheduleVendorOpenStoreSync = function(targetMode, delayMs)
    NativeStoreBridge.ScheduleOpenStoreSync(targetMode, delayMs)
end

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
---@return BetterUIKeybindDescriptorGroup
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
                progressCurrent = bonus or 0,
                progressMax = maxBonus or 0,
                bestGamepadItemCategoryName = skillHeader,
                statValue = statText,
            }

            local entry = ZO_GamepadEntryData:New(rowData.name, rowData.icon)
            entry:SetDataSource(rowData)
            entry.narrationText = function()
                return rowData.name
            end

            list:AddEntry("BETTERUI_GamepadStableTrainingEntryTemplate", entry)
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

---@param mode number
---@return string
local function ResolveVendorBatchActionName(mode)
    if mode == MODE.BUY then
        return GetString(rawget(_G, "SI_ITEM_ACTION_BUY") or "SI_ITEM_ACTION_BUY")
    elseif mode == MODE.SELL or mode == MODE.FENCE_SELL then
        return GetString(rawget(_G, "SI_ITEM_ACTION_SELL") or "SI_ITEM_ACTION_SELL")
    elseif mode == MODE.FENCE_LAUNDER then
        return GetString(rawget(_G, "SI_ITEM_ACTION_LAUNDER") or "SI_ITEM_ACTION_LAUNDER")
    elseif mode == MODE.BUYBACK then
        return GetString(rawget(_G, "SI_ITEM_ACTION_BUYBACK") or "SI_ITEM_ACTION_BUYBACK")
    end
    return GetString(rawget(_G, "SI_BETTERUI_BATCH_ACTIONS") or "SI_BETTERUI_BATCH_ACTIONS")
end

---@param totalItems integer
---@return table
local function ResolveVendorBatchDelayPolicy(totalItems)
    local BatchConfig = BETTERUI.CIM.BatchConfig
    local throttleProfile = BatchConfig.ResolveBatchThrottleProfile(totalItems)
    local opts = VENDOR_BATCH_OPTIONS
    local minDelay = opts.minServerDelayMs or 145

    return {
        BatchConfig = BatchConfig,
        baseDelayMs = zo_max(throttleProfile.DELAY_MS or 100, minDelay),
        showProgress = throttleProfile.SHOW_PROGRESS == true or totalItems >= 10,
        minDelay = minDelay,
        maxDelay = opts.maxServerDelayMs or 330,
        cooldownEvery = opts.cooldownEvery or 18,
        cooldownMs = opts.cooldownMs or 1200,
        chunkCostUnits = opts.chunkCostUnits or 32,
        chunkPauseMs = opts.chunkPauseMs or 1000,
        jitterMs = opts.jitterMs or 18,
    }
end

---@param mode number
---@param items BetterUIVendorBatchItem[]
---@param onComplete function|nil
---@return table
local function CreateVendorBatchRunner(mode, items, onComplete)
    local BatchOverlay = BETTERUI.CIM.BatchOverlay
    local delayPolicy = ResolveVendorBatchDelayPolicy(#items)
    local runner = {
        mode = mode,
        items = items,
        onComplete = onComplete,
        totalItems = #items,
        actionName = ResolveVendorBatchActionName(mode),
        BatchOverlay = BatchOverlay,
        BatchConfig = delayPolicy.BatchConfig,
        delayPolicy = delayPolicy,
        showProgress = delayPolicy.showProgress,
        processedCount = 0,
        index = 0,
        stopReason = nil,
        nextCooldownAt = delayPolicy.cooldownEvery > 0 and delayPolicy.cooldownEvery or nil,
        nextChunkAt = delayPolicy.chunkCostUnits > 0 and delayPolicy.chunkCostUnits or nil,
    }

    function runner:IsSceneActive()
        return Vendor.instance and Vendor.instance.IsSceneShowing and Vendor.instance:IsSceneShowing()
    end

    function runner:BuildProgressMainText()
        return string.format("Processing (%d/%d)", self.processedCount, self.totalItems)
    end

    function runner:BuildProgressSecondaryText()
        return string.format("Please Wait - Press %s to abort", self.BatchConfig.ResolveBatchAbortBindingMarkup())
    end

    function runner:Finish()
        Vendor._batchProcessing = false
        Vendor._batchAbortRequested = false

        if self.showProgress or self.stopReason then
            local completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_PROCESSING_COMPLETE")),
                self.processedCount)
            if self.stopReason == "bagFull" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_BAG_FULL")), self.processedCount,
                    self.totalItems)
            elseif self.stopReason == "sceneExit" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORTED_SCENE_EXIT")), "Vendor",
                    self.processedCount, self.totalItems)
            elseif self.stopReason == "aborted" then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_ABORTED_COMPLETE")),
                    self.processedCount, self.totalItems)
            elseif self.processedCount < self.totalItems then
                completeText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_BATCH_PARTIAL_SUCCESS")),
                    self.processedCount, self.totalItems)
            end
            self.BatchOverlay.ShowStatus({
                displayName = self.actionName,
                bodyText = completeText,
            })
            self.BatchOverlay.Hide((self.stopReason and 4000) or 2000)
        else
            self.BatchOverlay.Hide()
        end

        if self.onComplete then
            self.onComplete(self.stopReason)
        end
    end

    function runner:RecordServerAction()
        if self.BatchConfig.RecordServerAction then
            self.BatchConfig.RecordServerAction(self.BatchConfig.GetNowMs(), self.BatchConfig.SERVER_RATE_WINDOW_MS)
        end
    end

    function runner:UpdateProgress()
        if self.showProgress then
            self.BatchOverlay.Show(
                self.actionName,
                function() return self:BuildProgressMainText() end,
                function() return self:BuildProgressSecondaryText() end
            )
        end
    end

    function runner:ResolveDelayMs()
        local delayMs = self.delayPolicy.baseDelayMs
        local jitterMs = self.delayPolicy.jitterMs
        local minDelay = self.delayPolicy.minDelay
        local maxDelay = self.delayPolicy.maxDelay

        if jitterMs > 0 and self.BatchConfig.ResolveSignedJitter then
            delayMs = zo_clamp(delayMs + self.BatchConfig.ResolveSignedJitter(jitterMs), minDelay, maxDelay)
        else
            delayMs = zo_clamp(delayMs, minDelay, maxDelay)
        end

        if self.delayPolicy.cooldownMs > 0 and self.nextCooldownAt and self.processedCount >= self.nextCooldownAt then
            delayMs = delayMs + self.delayPolicy.cooldownMs
            while self.nextCooldownAt and self.processedCount >= self.nextCooldownAt do
                self.nextCooldownAt = self.nextCooldownAt + self.delayPolicy.cooldownEvery
            end
        end

        if self.delayPolicy.chunkPauseMs > 0 and self.nextChunkAt and self.processedCount >= self.nextChunkAt then
            delayMs = delayMs + self.delayPolicy.chunkPauseMs
            while self.nextChunkAt and self.processedCount >= self.nextChunkAt do
                self.nextChunkAt = self.nextChunkAt + self.delayPolicy.chunkCostUnits
            end
        end

        return delayMs
    end

    function runner:Step()
        if not self:IsSceneActive() then
            self.stopReason = "sceneExit"
            self:Finish()
            return
        end

        if Vendor._batchAbortRequested then
            self.stopReason = "aborted"
            self:Finish()
            return
        end

        self.index = self.index + 1
        if self.index > self.totalItems then
            self:Finish()
            return
        end

        Vendor.ExecuteBatchAction(self.mode, self.items[self.index])
        self.processedCount = self.processedCount + 1

        if self.mode == MODE.BUY or self.mode == MODE.BUYBACK then
            local vendorInstance = Vendor.instance
            if vendorInstance and vendorInstance.HasInventorySpace and not vendorInstance:HasInventorySpace() then
                self.stopReason = "bagFull"
                self:Finish()
                return
            end
        end

        self:RecordServerAction()
        self:UpdateProgress()
        zo_callLater(function() self:Step() end, self:ResolveDelayMs())
    end

    function runner:StartAfterDialogDismiss(remainingMs)
        if not Vendor._batchProcessing then
            return
        end
        if Vendor._batchAbortRequested then
            self.stopReason = "aborted"
            self:Finish()
            return
        end
        if not self:IsSceneActive() then
            self.stopReason = "sceneExit"
            self:Finish()
            return
        end

        if self.BatchOverlay.IsAnyBatchActionDialogShowing and self.BatchOverlay.IsAnyBatchActionDialogShowing() and remainingMs > 0 then
            zo_callLater(function() self:StartAfterDialogDismiss(remainingMs - 25) end, 25)
            return
        end

        zo_callLater(function()
            if not Vendor._batchProcessing then
                return
            end
            self:UpdateProgress()
            self:Step()
        end, 160)
    end

    function runner:Start()
        self:StartAfterDialogDismiss(1800)
    end

    return runner
end

--- Processes vendor batch actions through a throttled pipeline with overlay progress.
--- Works for all vendor modes including BUY/BUYBACK (which lack bagId/slotIndex).
---@param mode number Vendor mode constant (MODE.BUY, MODE.SELL, etc.)
---@param items BetterUIVendorBatchItem[] Array of selected item data tables
---@param onComplete function|nil Callback invoked when processing finishes
function Vendor.ExecuteBatchThrottled(mode, items, onComplete)
    local totalItems = #items
    if totalItems == 0 then
        if onComplete then onComplete() end
        return
    end

    if mode == MODE.BUYBACK then
        table.sort(items, function(a, b)
            local dsA = a.dataSource or a
            local dsB = b.dataSource or b
            return (dsA.entryIndex or 0) > (dsB.entryIndex or 0)
        end)
    end

    if Vendor._batchProcessing then
        return
    end
    Vendor._batchProcessing = true
    Vendor._batchAbortRequested = false

    local runner = CreateVendorBatchRunner(mode, items, onComplete)
    runner:Start()
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
            local ms = Vendor.multiSelectManager
            if ms then
                local selectedCount = ms:GetSelectedCount()
                local selectedItems = ms.GetSelectedItems and ms:GetSelectedItems() or {}
                local totalItems = (Vendor.instance and Vendor.instance.list and Vendor.instance.list:GetNumItems()) or 0
                local allSelected = selectedCount > 0 and selectedCount == totalItems
                if not allSelected then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(
                            GetString(rawget(_G, "SI_BETTERUI_SELECT_ALL") or "SI_BETTERUI_SELECT_ALL"),
                            "selectAll"
                        ))
                end
                if selectedCount > 0 then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(
                            zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_BETTERUI_DESELECT_ALL") or "SI_BETTERUI_DESELECT_ALL"), selectedCount),
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
    ResetVendorInteractionState()

    if not Vendor.instance then return end
    ResetVendorRuntimeState(Vendor.instance)

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

    local targetMode = ResolveVendorTargetMode()
    ApplyVendorResolvedMode(targetMode, false)

    if SCENE_MANAGER then
        SCENE_MANAGER:Show(BETTERUI_VENDOR_SCENE_NAME)
    end

    -- Keep one short native sync window after scene show so the buy component can
    -- populate from the native store manager without fighting scene ownership.
    ScheduleVendorOpenStoreSync(targetMode, 120)
end

---@param _ any Unused event code
---@param enableSell boolean|nil Whether fence sell is enabled (default true)
---@param enableLaunder boolean|nil Whether fence launder is enabled (default true)
local function OnOpenFence(_, enableSell, enableLaunder)
    ResetVendorInteractionState()
    isFenceInteraction = true
    fenceEnableSell = (enableSell ~= false)     -- default true
    fenceEnableLaunder = (enableLaunder ~= false) -- default true
    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("OnOpenFence sell=%s launder=%s", tostring(fenceEnableSell), tostring(fenceEnableLaunder))
    )

    if not Vendor.instance then return end
    ResetVendorRuntimeState(Vendor.instance)
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
        if Vendor.ModePolicy and Vendor.ModePolicy.ResetCategoryState then
            Vendor.ModePolicy.ResetCategoryState(Vendor.instance)
        else
            Vendor.instance._cachedBuyCategories = nil
        end
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

local function RegisterVendorComponents(instance)
    local componentRegistrations = {
        { mode = MODE.BUY, component = Vendor.BuyComponent },
        { mode = MODE.SELL, component = Vendor.SellComponent },
        { mode = MODE.SELL_VENGEANCE, component = Vendor.SellVengeanceComponent },
        { mode = MODE.REPAIR, component = Vendor.RepairComponent },
        { mode = MODE.STABLE, component = Vendor.StableTrainingComponent },
        { mode = MODE.BUYBACK, component = Vendor.BuybackComponent },
        { mode = MODE.FENCE_SELL, component = Vendor.FenceSellComponent },
        { mode = MODE.FENCE_LAUNDER, component = Vendor.FenceLaunderComponent },
    }

    for _, registration in ipairs(componentRegistrations) do
        if registration.component then
            instance:RegisterComponent(registration.mode, registration.component)
        end
    end
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
    instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI.Vendor.VendorEntrySetup
    )
    instance:AddTemplate(
        "BETTERUI_GamepadStableTrainingEntryTemplate",
        BETTERUI.Vendor.VendorEntrySetup
    )
    instance.list:SetOnSelectedDataChangedCallback(function(list, selectedData)
        if instance._searchModeActive and instance.list
            and instance.list.IsActive and instance.list:IsActive() then
            instance:OnItemSelectedChange(list, selectedData)
            instance:UpdateScrollIndicator(list)
            instance:OnSearchFocusLost()
            return
        end
        instance:OnItemSelectedChange(list, selectedData)
        instance:UpdateScrollIndicator(list)
    end)
    if instance.list then
        instance.list.owner = instance
        if instance.list.MovePrevious then
            local originalMovePrevious = instance.list.MovePrevious
            instance.list.MovePrevious = function(list, allowWrapping, suppressFailSound)
                local didMove = originalMovePrevious(list, allowWrapping, suppressFailSound)
                if didMove then
                    return true
                end

                if instance.OnHeaderEntered then
                    instance:OnHeaderEntered()
                elseif instance.RequestHeaderFocus then
                    instance:RequestHeaderFocus()
                end
                return true
            end
        end
    end

    AddVendorColumns(instance)
    instance:InitializeCategoryHeader()
    instance:InitializeScrollIndicator()
    instance.searchQuery = ""
end

local function InitializeVendorSearch(instance)
    local searchCallbackRevision = 0
    local searchHandlerRevision = 0

    local function HandleVendorSearchChanged(editOrText)
        if instance.OnSearchTextChanged then
            instance:OnSearchTextChanged(editOrText)
        else
            instance.searchQuery = tostring(editOrText or "")
            instance:RefreshList()
        end
        searchCallbackRevision = searchCallbackRevision + 1
    end

    instance.textSearchKeybindStripDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor(instance)
    if instance.AddSearch then
        instance:AddSearch(instance.textSearchKeybindStripDescriptor, HandleVendorSearchChanged)
        if instance.PositionSearchControl then
            instance:PositionSearchControl()
        end
    end
    if BETTERUI.Interface.SearchMixin and BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers then
        BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(instance, {
            isSceneShowing = function()
                return instance.IsSceneShowing and instance:IsSceneShowing() or false
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
end

local function InitializeVendorInteractiveSurfaces(instance)
    instance.coreKeybinds = BuildCoreKeybinds(instance)

    if BETTERUI.CIM and BETTERUI.CIM.MultiSelectManager and BETTERUI.CIM.MultiSelectManager.Create then
        Vendor.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(instance.list, function()
            if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
            end
        end)
    else
        Vendor.multiSelectManager = nil
    end
    instance.multiSelectManager = Vendor.multiSelectManager

    if BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortIntegration and BETTERUI.CIM.UI.HeaderSortIntegration.Install then
        RunVendorSetupStep("Header sort integration setup", function()
            local integration = BETTERUI.CIM.UI.HeaderSortIntegration.Install(instance, {
                list = instance.list,
                columns = {
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_NAME") or "SI_BETTERUI_BANKING_COLUMN_NAME"),  key = "name" },
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TYPE") or "SI_BETTERUI_BANKING_COLUMN_TYPE"),  key = "type" },
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TRAIT") or "SI_BETTERUI_BANKING_COLUMN_TRAIT"), key = "trait" },
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_STAT") or "SI_BETTERUI_BANKING_COLUMN_STAT"),  key = "stat" },
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_VALUE") or "SI_BETTERUI_BANKING_COLUMN_VALUE"), key = "value", defaultDirection = "descending" },
                },
                callbacks = {
                    onSortChanged = function()
                        instance:RefreshList()
                    end,
                },
                controllerContract = {
                    field = "sortController",
                    aliasFields = { "headerSortController" },
                },
                keybinds = {
                    mainDescriptor = instance.coreKeybinds,
                },
                autoEnterOnListStart = true,
            })
            BETTERUI.CIM.UI.HeaderSortIntegration.EnsureController(integration)
        end)
    end
end

local function CreateVendorScene(instance)
    instance.fragment = ZO_SimpleSceneFragment:New(instance.control)
    instance.fragment:SetHideOnSceneHidden(true)

    local vendorFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_VendorFooterDummy", GuiRoot, CT_CONTROL)
    vendorFooterDummy:SetHidden(true)
    instance.footerFragment = ZO_SimpleSceneFragment:New(vendorFooterDummy)
    instance.footerFragment:SetHideOnSceneHidden(true)

    local scene = ZO_InteractScene:New(BETTERUI_VENDOR_SCENE_NAME, SCENE_MANAGER, Vendor.VENDOR_INTERACTION)
    instance.scene = scene
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(instance.footerFragment)
end

local function TakeOverNativeStoreScene(instance)
    NativeStoreBridge.TakeOverScene(instance)
end

local function RegisterVendorSceneLifecycle(instance)
    BETTERUI.CIM.SceneLifecycle.Register(instance, {
        keybinds = { instance.coreKeybinds },
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
                screen:SaveListPosition()
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
                BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
                BETTERUI.CIM.SceneCleanup.DeactivateLists(screen, screen.list)
                BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
            end
            if GAMEPAD_TOOLTIPS then
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
                GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
            end
            if BETTERUI.CIM.SharedItemSupport and BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip then
                BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
                BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
            end
            if screen.list and screen.list.control and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator then
                BETTERUI.CIM.ScrollIndicator.Hide(screen.list.control)
            end
        end,
        onHidden = function(screen)
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
end

local function RegisterVendorEvents(eventManager)
    if not eventManager then
        return
    end

    if EVENT_STABLE_INTERACT_START then
        eventManager:RegisterForEvent(EVENT_NS .. "_StableStart", EVENT_STABLE_INTERACT_START, OnStableInteractStart)
    end
    if EVENT_STABLE_INTERACT_END then
        eventManager:RegisterForEvent(EVENT_NS .. "_StableEnd", EVENT_STABLE_INTERACT_END, OnStableInteractEnd)
    end
    eventManager:RegisterForEvent(EVENT_NS .. "_Open", EVENT_OPEN_STORE, OnOpenStore)
    eventManager:RegisterForEvent(EVENT_NS .. "_OpenFence", EVENT_OPEN_FENCE, OnOpenFence)
    eventManager:RegisterForEvent(EVENT_NS .. "_Close", EVENT_CLOSE_STORE, OnCloseStore)
    eventManager:RegisterForEvent(EVENT_NS .. "_InvUpdate",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdated)
    eventManager:RegisterForEvent(EVENT_NS .. "_InvFull",
        EVENT_INVENTORY_FULL_UPDATE, OnInventoryUpdated)
    eventManager:RegisterForEvent(EVENT_NS .. "_SellReceipt",
        EVENT_SELL_RECEIPT, OnSellReceipt)
    eventManager:RegisterForEvent(EVENT_NS .. "_BuyReceipt",
        EVENT_BUY_RECEIPT, OnInventoryUpdated)
    eventManager:RegisterForEvent(EVENT_NS .. "_BuybackReceipt",
        EVENT_BUYBACK_RECEIPT, OnInventoryUpdated)
    eventManager:RegisterForEvent(EVENT_NS .. "_RepairItem",
        EVENT_ITEM_REPAIR_ALREADY_APPLIED_CONFIRMATION, OnInventoryUpdated)
    eventManager:RegisterForEvent(EVENT_NS .. "_ItemLaunder",
        EVENT_ITEM_LAUNDER_RESULT, OnInventoryUpdated)
    eventManager:RegisterForEvent(EVENT_NS .. "_FenceUpdate",
        EVENT_JUSTICE_FENCE_UPDATE, OnInventoryUpdated)
    eventManager:RegisterForEvent(EVENT_NS .. "_MoneyUpdate",
        EVENT_MONEY_UPDATE, OnMoneyUpdated)
    if EVENT_CURRENCY_UPDATE then
        eventManager:RegisterForEvent(EVENT_NS .. "_CurrencyUpdate",
            EVENT_CURRENCY_UPDATE, OnMoneyUpdated)
    end
end

local function ExposeVendorRuntimeHelpers()
    Vendor.DebugLog = LogVendorDebug
    Vendor.IsDirectionalInputListening = IsDirectionalInputListening
    Vendor.GetActiveTabs = GetActiveTabs
    Vendor.BuildActiveModeSet = BuildActiveModeSet
    Vendor.GetToggleModePair = GetToggleModePair
    Vendor.IsSellBuybackOnlyModeSet = IsSellBuybackOnlyModeSet
    Vendor.IsSellBuybackOnlyStore = IsSellBuybackOnlyStore
    Vendor.IsFenceInteraction = function() return isFenceInteraction end
    Vendor.GetStableInteractionIcon = ResolveStableInteractionIcon
    Vendor.IsStableInteraction = function() return isStableInteraction end
    Vendor.IsSellVengeanceModeAvailable = IsSellVengeanceModeAvailable
    Vendor.HasVendorBuyInventory = HasVendorBuyInventory
    Vendor.ResolveInitialStoreMode = ResolveInitialStoreMode
    Vendor.UpdateSceneManagerStoreAlias = function()
        NativeStoreBridge.UpdateSceneManagerStoreAlias(Vendor.instance)
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
    AliasStoreSceneToBetterUI()
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
