--[[
File: Modules/Vendor/Vendor.lua
Purpose: Vendor orchestration surface for scene lifecycle, event wiring, and
         runtime coordination across the extracted vendor services.
]]

-- LOCAL STATE
local Vendor      = BETTERUI.Vendor
local MODE        = Vendor.MODE
local EVENT_NS    = "BetterUI_Vendor"
local SafeCall
local NativeStoreBridge = assert(Vendor.NativeStoreBridge, "Vendor native store bridge must load before Vendor.lua")
local VendorBootstrapRuntime = assert(Vendor.BootstrapRuntime, "Vendor bootstrap runtime must load before Vendor.lua")
local VendorComponentCatalog = assert(Vendor.ComponentCatalog, "Vendor component catalog must load before Vendor.lua")
local VendorEventBridge = assert(Vendor.EventBridge, "Vendor event bridge must load before Vendor.lua")
local VendorInteractionRuntime = assert(Vendor.InteractionRuntime, "Vendor interaction runtime must load before Vendor.lua")
local VendorBatchRuntime = assert(Vendor.BatchRuntime, "Vendor batch runtime must load before Vendor.lua")

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

local function ResetActiveVendorRuntimeState()
    if Vendor.instance then
        ResetVendorRuntimeState(Vendor.instance)
    end
end

local function SnapshotVendorInteractionState()
    return {
        isFenceInteraction = isFenceInteraction,
        isStableInteraction = isStableInteraction,
        fenceEnableSell = fenceEnableSell,
        fenceEnableLaunder = fenceEnableLaunder,
    }
end

local function ApplyVendorInteractionState(nextState)
    if not nextState then
        return
    end

    isFenceInteraction = nextState.isFenceInteraction == true
    isStableInteraction = nextState.isStableInteraction == true
    fenceEnableSell = nextState.fenceEnableSell == true
    fenceEnableLaunder = nextState.fenceEnableLaunder == true
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

local function PrepareVendorOpenStoreMode()
    local targetMode = ResolveVendorTargetMode()
    ApplyVendorResolvedMode(targetMode, false)
    ScheduleVendorOpenStoreSync(targetMode, 120)
    return targetMode
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
    VendorBatchRuntime.ExecuteBatchAction(mode, itemData)
end

---@param mode number
---@return string
local function ResolveVendorBatchActionName(mode)
    return VendorBatchRuntime.ResolveBatchActionName(mode)
end

---@param totalItems integer
---@return table
local function ResolveVendorBatchDelayPolicy(totalItems)
    return VendorBatchRuntime.ResolveBatchDelayPolicy(totalItems)
end

---@param mode number
---@param items BetterUIVendorBatchItem[]
---@param onComplete function|nil
---@return table
local function CreateVendorBatchRunner(mode, items, onComplete)
    return VendorBatchRuntime.CreateBatchRunner(mode, items, onComplete)
end

--- Processes vendor batch actions through a throttled pipeline with overlay progress.
--- Works for all vendor modes including BUY/BUYBACK (which lack bagId/slotIndex).
---@param mode number Vendor mode constant (MODE.BUY, MODE.SELL, etc.)
---@param items BetterUIVendorBatchItem[] Array of selected item data tables
---@param onComplete function|nil Callback invoked when processing finishes
function Vendor.ExecuteBatchThrottled(mode, items, onComplete)
    VendorBatchRuntime.ExecuteBatchThrottled(mode, items, onComplete)
end

--- Requests abort of the current vendor batch operation.
function Vendor.RequestBatchAbort()
    VendorBatchRuntime.RequestBatchAbort()
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
    ApplyVendorInteractionState(VendorInteractionRuntime.OnOpenStore(SnapshotVendorInteractionState(), {
        resetInteractionState = ResetVendorInteractionState,
        instance = Vendor.instance,
        resetRuntimeState = ResetActiveVendorRuntimeState,
        getInteractionType = GetInteractionType,
        interactionVendor = INTERACTION_VENDOR,
        interactionStable = INTERACTION_STABLE,
        isNativeStableModeActive = IsNativeStableModeActive,
        logVendorDebug = LogVendorDebug,
        restoreNativeStoreSceneAlias = RestoreNativeStoreSceneAlias,
        aliasStoreSceneToBetterUI = AliasStoreSceneToBetterUI,
        ensureNativeStoreComponents = EnsureNativeStoreComponents,
        resolveVendorTargetMode = ResolveVendorTargetMode,
        applyVendorResolvedMode = ApplyVendorResolvedMode,
        showScene = function()
            if SCENE_MANAGER then
                SCENE_MANAGER:Show(BETTERUI_VENDOR_SCENE_NAME)
            end
        end,
        scheduleVendorOpenStoreSync = ScheduleVendorOpenStoreSync,
    }))
end

---@param _ any Unused event code
---@param enableSell boolean|nil Whether fence sell is enabled (default true)
---@param enableLaunder boolean|nil Whether fence launder is enabled (default true)
local function OnOpenFence(_, enableSell, enableLaunder)
    ResetVendorInteractionState()
    ApplyVendorInteractionState(VendorInteractionRuntime.OnOpenFence(SnapshotVendorInteractionState(), {
        resetInteractionState = ResetVendorInteractionState,
        instance = Vendor.instance,
        resetRuntimeState = ResetActiveVendorRuntimeState,
        aliasStoreSceneToBetterUI = AliasStoreSceneToBetterUI,
        logVendorDebug = LogVendorDebug,
        sellMode = MODE.FENCE_SELL,
        fenceLaunderMode = MODE.FENCE_LAUNDER,
        showScene = function()
            if SCENE_MANAGER then
                SCENE_MANAGER:Show(BETTERUI_VENDOR_SCENE_NAME)
            end
        end,
    }, enableSell, enableLaunder))
end

local function OnStableInteractStart()
    isStableInteraction = true
end

local function OnStableInteractEnd()
    isStableInteraction = false
end

local function OnCloseStore()
    Vendor._isClosing = true
    Vendor._sessionHasBuyMode = false
    Vendor._openStoreSyncAttempt = 0
    ApplyVendorInteractionState(VendorInteractionRuntime.OnCloseStore(SnapshotVendorInteractionState(), {
        instance = Vendor.instance,
        resetRuntimeState = ResetActiveVendorRuntimeState,
        cancelRuntimeTasks = function()
            if Vendor.Tasks then
                Vendor.Tasks:Cancel("ensureStoreComponentsOnOpen")
                Vendor.Tasks:Cancel("buyActivateRefresh")
                Vendor.Tasks:Cancel("buyListRetry")
                Vendor.Tasks:Cancel("listRefresh")
                Vendor.Tasks:Cancel("footerRefresh")
                Vendor.Tasks:Cancel("directionalInputNormalize")
            end
        end,
        logVendorDebug = LogVendorDebug,
        hideScene = function()
            if SCENE_MANAGER then
                local scene = SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
                if scene and scene.IsShowing and scene:IsShowing() then
                    SCENE_MANAGER:Hide(BETTERUI_VENDOR_SCENE_NAME)
                end
            end
        end,
        getStoreManager = function() return rawget(_G, "STORE_WINDOW_GAMEPAD") end,
        logNativeStoreInputState = LogNativeStoreInputState,
        safeCall = SafeCall,
        aliasStoreSceneToBetterUI = AliasStoreSceneToBetterUI,
    }))
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
    VendorComponentCatalog.Register(instance)
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
    VendorBootstrapRuntime.InitializeList(instance, {
        rowSetup = BETTERUI.Vendor.VendorEntrySetup,
        addColumns = AddVendorColumns,
    })
end

local function InitializeVendorSearch(instance)
    VendorBootstrapRuntime.InitializeSearch(instance, {
        createSearchKeybindDescriptor = BETTERUI.Interface and BETTERUI.Interface.CreateSearchKeybindDescriptor,
        setupEditBoxHandlers = BETTERUI.Interface and BETTERUI.Interface.SearchMixin and BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers,
    })
end

local function InitializeVendorInteractiveSurfaces(instance)
    VendorBootstrapRuntime.InitializeInteractiveSurfaces(instance, {
        buildCoreKeybinds = BuildCoreKeybinds,
        runVendorSetupStep = RunVendorSetupStep,
    })
end

local function CreateVendorScene(instance)
    VendorBootstrapRuntime.CreateScene(instance, {})
end

local function TakeOverNativeStoreScene(instance)
    NativeStoreBridge.TakeOverScene(instance)
end

local function RegisterVendorSceneLifecycle(instance)
    VendorBootstrapRuntime.RegisterSceneLifecycle(instance, {
        taskManager = Vendor.Tasks,
    })
end

local function RegisterVendorEvents(eventManager)
    VendorEventBridge.Register(eventManager, EVENT_NS, {
        onStableInteractStart = OnStableInteractStart,
        onStableInteractEnd = OnStableInteractEnd,
        onOpenStore = OnOpenStore,
        onOpenFence = OnOpenFence,
        onCloseStore = OnCloseStore,
        onInventoryUpdated = OnInventoryUpdated,
        onSellReceipt = OnSellReceipt,
        onMoneyUpdated = OnMoneyUpdated,
    })
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
