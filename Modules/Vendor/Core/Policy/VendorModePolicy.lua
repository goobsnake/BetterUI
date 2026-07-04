--[[
File: Modules/Vendor/Core/Policy/VendorModePolicy.lua
Purpose: Shared vendor mode-policy surface for native-mode translation, active
         tab derivation, and initial-mode selection.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.ModePolicy = Vendor.ModePolicy or {}
local ModePolicy = Vendor.ModePolicy
local DEFAULT_VENDOR_CATEGORY_ICON = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"

local function AddIfValue(tableRef, value)
    if value ~= nil then
        tableRef[value] = true
    end
end

local function BuildNativeStoreFallbackEntryTypes()
    local types = {}
    AddIfValue(types, rawget(_G, "STORE_ENTRY_TYPE_ANTIQUITY_LEAD"))
    AddIfValue(types, rawget(_G, "STORE_ENTRY_TYPE_COLLECTIBLE"))
    AddIfValue(types, rawget(_G, "STORE_ENTRY_TYPE_HOUSE_WITH_TEMPLATE"))
    AddIfValue(types, rawget(_G, "STORE_ENTRY_TYPE_INTERACTABLE"))
    AddIfValue(types, rawget(_G, "STORE_ENTRY_TYPE_MONSTER"))
    AddIfValue(types, rawget(_G, "STORE_ENTRY_TYPE_QUEST_ITEM"))
    AddIfValue(types, rawget(_G, "STORE_ENTRY_TYPE_SUBSTORE"))
    return types
end

local NATIVE_STORE_FALLBACK_ENTRY_TYPES = BuildNativeStoreFallbackEntryTypes()

local function BuildFallbackCategory()
    return {
        key = "all",
        name = GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_ALL") or "SI_BETTERUI_INV_ITEM_ALL"),
        iconFile = DEFAULT_VENDOR_CATEGORY_ICON,
        itemCount = 0,
    }
end

local function CloneCategory(category)
    local snapshot = {}
    for key, value in pairs(category or {}) do
        snapshot[key] = value
    end
    return snapshot
end

local function CloneCategories(categories)
    local snapshots = {}
    for index, category in ipairs(categories or {}) do
        snapshots[index] = CloneCategory(category)
    end
    return snapshots
end

local function CloneTab(tab)
    local snapshot = {}
    for key, value in pairs(tab or {}) do
        snapshot[key] = value
    end
    return snapshot
end

local function CloneTabs(tabs)
    local snapshots = {}
    for index, tab in ipairs(tabs or {}) do
        snapshots[index] = CloneTab(tab)
    end
    return snapshots
end

local function ReadCategoryState(owner)
    if type(owner) ~= "table" then
        return nil
    end

    local state = owner._modeCategoryState
    if type(state) == "table" then
        return {
            categoriesByMode = state.categoriesByMode or {},
            selectedIndexByMode = state.selectedIndexByMode or {},
            cachedBuyCategories = state.cachedBuyCategories,
        }
    end

    return {
        categoriesByMode = owner.modeCategories or {},
        selectedIndexByMode = owner.categoryIndexByMode or {},
        cachedBuyCategories = owner._cachedBuyCategories,
    }
end

local function EnsureCategoryState(owner)
    owner._modeCategoryState = owner._modeCategoryState or {
        categoriesByMode = owner.modeCategories or {},
        selectedIndexByMode = owner.categoryIndexByMode or {},
        cachedBuyCategories = owner._cachedBuyCategories and CloneCategories(owner._cachedBuyCategories) or nil,
    }

    local state = owner._modeCategoryState
    owner.modeCategories = state.categoriesByMode
    owner.categoryIndexByMode = state.selectedIndexByMode
    owner._cachedBuyCategories = state.cachedBuyCategories
    return state
end

local function EnsureStoredCategories(owner, mode)
    local state = EnsureCategoryState(owner)
    local categories = state.categoriesByMode[mode]
    if not categories or #categories == 0 then
        categories = { BuildFallbackCategory() }
        state.categoriesByMode[mode] = categories
    end
    return state, categories
end

local function ResolveStoredCategories(owner, mode)
    local state = ReadCategoryState(owner)
    local categories = state and state.categoriesByMode and state.categoriesByMode[mode] or nil
    if not categories or #categories == 0 then
        return { BuildFallbackCategory() }
    end
    return categories
end

local function ResolveSelectedCategoryIndex(owner, mode, categoryCount)
    local state = ReadCategoryState(owner)
    local selectedIndex = (state and state.selectedIndexByMode and state.selectedIndexByMode[mode]) or 1
    if selectedIndex < 1 or selectedIndex > categoryCount then
        selectedIndex = 1
    end
    return selectedIndex
end

local function GetModeDescriptor(mode)
    local resolver = Vendor.GetModeDescriptor
    if type(resolver) ~= "function" then
        return nil
    end
    return resolver(mode)
end

function ModePolicy.ResolveModeName(mode)
    local descriptor = GetModeDescriptor(mode)
    local stringId = descriptor and descriptor.nameStringId or "SI_BETTERUI_VENDOR_TITLE"
    return GetString(rawget(_G, stringId) or stringId)
end

function ModePolicy.ResolveModeIcon(mode)
    local descriptor = GetModeDescriptor(mode)
    if descriptor then
        if descriptor.iconResolver then
            return descriptor.iconResolver()
        end
        if descriptor.iconFile then
            return descriptor.iconFile
        end
    end
    return DEFAULT_VENDOR_CATEGORY_ICON
end

function ModePolicy.ResolveNativeStoreMode(mode)
    local descriptor = GetModeDescriptor(mode)
    return descriptor and rawget(_G, descriptor.nativeModeGlobalKey) or nil
end

function ModePolicy.BuildFallbackCategory()
    return BuildFallbackCategory()
end

function ModePolicy.EnsureModeCategories(owner, mode)
    local _, categories = EnsureStoredCategories(owner, mode)
    return CloneCategories(categories)
end

function ModePolicy.GetModeCategories(owner, mode)
    local categories = ResolveStoredCategories(owner, mode)
    return CloneCategories(categories)
end

function ModePolicy.GetCachedBuyCategories(owner)
    local state = ReadCategoryState(owner)
    if not state or not state.cachedBuyCategories or #state.cachedBuyCategories == 0 then
        return nil
    end
    return CloneCategories(state.cachedBuyCategories)
end

function ModePolicy.GetSelectedCategoryIndex(owner, mode)
    local state = ReadCategoryState(owner)
    local categories = state and state.categoriesByMode and state.categoriesByMode[mode] or nil
    local categoryCount = (type(categories) == "table" and #categories > 0) and #categories or 1
    local selectedIndex = (state and state.selectedIndexByMode and state.selectedIndexByMode[mode]) or 1
    if selectedIndex < 1 or selectedIndex > categoryCount then
        return 1
    end
    return selectedIndex
end

function ModePolicy.SetSelectedCategoryIndex(owner, mode, selectedIndex)
    local state, categories = EnsureStoredCategories(owner, mode)
    if selectedIndex < 1 or selectedIndex > #categories then
        selectedIndex = 1
    end
    state.selectedIndexByMode[mode] = selectedIndex
    owner.categoryIndexByMode = state.selectedIndexByMode
    return selectedIndex
end

function ModePolicy.SetModeCategories(owner, mode, categories)
    local state = EnsureCategoryState(owner)
    local previousCategories = CloneCategories(state.categoriesByMode[mode] or {})
    local normalized = CloneCategories(categories)
    if #normalized == 0 then
        normalized = { BuildFallbackCategory() }
    end

    state.categoriesByMode[mode] = normalized
    if mode == (Vendor.MODE and Vendor.MODE.BUY) and #normalized > 0 then
        state.cachedBuyCategories = CloneCategories(normalized)
    end

    local selectedIndex = state.selectedIndexByMode[mode] or 1
    if selectedIndex < 1 or selectedIndex > #normalized then
        selectedIndex = 1
    end
    state.selectedIndexByMode[mode] = selectedIndex

    owner.modeCategories = state.categoriesByMode
    owner.categoryIndexByMode = state.selectedIndexByMode
    owner._cachedBuyCategories = state.cachedBuyCategories

    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.CATEGORY, "vendor mode resolved",
            { mode = mode, tabCount = #normalized, selectedIndex = selectedIndex })
    end

    return previousCategories, CloneCategories(normalized), selectedIndex
end

function ModePolicy.GetCurrentCategory(owner, mode)
    local categories = ModePolicy.GetModeCategories(owner, mode)
    local selectedIndex = ResolveSelectedCategoryIndex(owner, mode, #categories)
    return categories[selectedIndex]
end

function ModePolicy.ResetCategoryState(owner)
    if not owner then
        return
    end
    owner._modeCategoryState = nil
    owner.modeCategories = nil
    owner.categoryIndexByMode = nil
    owner._cachedBuyCategories = nil
end

function ModePolicy.BuildActiveModeSet(tabs)
    local modeSet = {}
    for _, tab in ipairs(tabs or {}) do
        if tab and tab.mode then
            modeSet[tab.mode] = true
        end
    end
    return modeSet
end

function ModePolicy.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)
    if isFenceInteraction then
        return false
    end

    local mode = Vendor.MODE or {}
    local sellMode = mode.SELL or 2
    local buybackMode = mode.BUYBACK or 4
    local buyMode = mode.BUY or 1
    local repairMode = mode.REPAIR or 3

    modeSet = modeSet or {}
    local hasSell = modeSet[sellMode] == true
    local hasBuyback = modeSet[buybackMode] == true
    local hasBuy = modeSet[buyMode] == true
    local hasRepair = modeSet[repairMode] == true
    return hasSell and hasBuyback and not hasBuy and not hasRepair
end

function ModePolicy.GetNativeActiveModeSet(storeManager)
    local modeSet = {}
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

function ModePolicy.IsNativeStableModeActive(storeManager)
    local stableMode = rawget(_G, "ZO_MODE_STORE_STABLE")
    if not stableMode then
        return false
    end
    local nativeModeSet = ModePolicy.GetNativeActiveModeSet(storeManager)
    return nativeModeSet[stableMode] == true
end

local function CollectAvailableTabs(sourceTabs, isModeTabAvailable)
    local availableTabs = {}
    for _, tab in ipairs(sourceTabs or {}) do
        if not isModeTabAvailable or isModeTabAvailable(tab.mode) then
            availableTabs[#availableTabs + 1] = tab
        end
    end
    return availableTabs
end

function ModePolicy.GetFenceActiveTabs(request)
    request = request or {}
    local tabs = {}
    local fenceTabs = request.fenceTabs or {}
    if request.enableSell then
        tabs[#tabs + 1] = fenceTabs[1]
    end
    if request.enableLaunder then
        tabs[#tabs + 1] = fenceTabs[2]
    end
    if #tabs == 0 and fenceTabs[1] then
        tabs[1] = fenceTabs[1]
    end
    return CloneTabs(tabs)
end

function ModePolicy.GetStoreActiveTabs(request)
    request = request or {}
    local activeModeSet = ModePolicy.GetNativeActiveModeSet(request.storeManager)
    local sourceTabs = request.sourceTabs or {}
    local fallbackTabs = request.fallbackTabs or sourceTabs
    local tabs = {}
    for _, tab in ipairs(sourceTabs) do
        if not request.isModeTabAvailable or request.isModeTabAvailable(tab.mode) then
            local nativeMode = ModePolicy.ResolveNativeStoreMode(tab.mode)
            local includeStableRepair = request.includeStableRepair == true
                and tab.mode == Vendor.MODE.REPAIR
                and (type(CanStoreRepair) ~= "function" or CanStoreRepair())
            if (nativeMode and activeModeSet[nativeMode])
                or (tab.mode == Vendor.MODE.BUY and request.includeBuyFromSession == true)
                or includeStableRepair then
                tabs[#tabs + 1] = tab
            end
        end
    end

    if #tabs == 0 then
        return CloneTabs(fallbackTabs)
    end

    return CloneTabs(tabs)
end

function ModePolicy.GetFenceToggleModePair()
    local mode = Vendor.MODE or {}
    return mode.FENCE_SELL, mode.FENCE_LAUNDER
end

function ModePolicy.GetStableToggleModePair()
    local mode = Vendor.MODE or {}
    return mode.BUY, mode.STABLE
end

function ModePolicy.GetStoreToggleModePair(request)
    request = request or {}
    local mode = Vendor.MODE or {}
    local modeSet = ModePolicy.BuildActiveModeSet(request.tabs)
    if modeSet[mode.BUY] and modeSet[mode.SELL] then
        return mode.BUY, mode.SELL
    end
    if modeSet[mode.SELL] and request.sessionHasBuyMode == true then
        return mode.BUY, mode.SELL
    end
    if ModePolicy.IsSellBuybackOnlyModeSet(modeSet, false) then
        return mode.SELL, mode.BUYBACK
    end

    return nil, nil
end

function ModePolicy.ResolveVendorInitialStoreMode(request)
    request = request or {}
    local mode = Vendor.MODE or {}
    local tabs = request.tabs or {}
    local vendorTabs = request.vendorTabs or tabs
    local modeSet = ModePolicy.BuildActiveModeSet(tabs)
    local nativeModeSet = ModePolicy.GetNativeActiveModeSet(request.storeManager)
    local nativeModesReady = next(nativeModeSet) ~= nil
    local shouldRememberBuyMode = false

    if nativeModesReady then
        modeSet = {}
        for _, tab in ipairs(vendorTabs) do
            local nativeMode = ModePolicy.ResolveNativeStoreMode(tab.mode)
            if nativeMode and nativeModeSet[nativeMode] then
                modeSet[tab.mode] = true
            end
        end
        if modeSet[mode.BUY] then
            shouldRememberBuyMode = true
        end
    end

    if ModePolicy.IsSellBuybackOnlyModeSet(modeSet, false) then
        return mode.SELL, shouldRememberBuyMode
    end

    if not nativeModesReady then
        if modeSet[mode.SELL] then
            return mode.SELL, shouldRememberBuyMode
        end
        if modeSet[mode.BUYBACK] then
            return mode.BUYBACK, shouldRememberBuyMode
        end
        if modeSet[mode.REPAIR] then
            return mode.REPAIR, shouldRememberBuyMode
        end
    end

    if nativeModesReady and modeSet[mode.BUY] then
        return mode.BUY, true
    end
    if modeSet[mode.SELL] then
        return mode.SELL, shouldRememberBuyMode
    end
    if modeSet[mode.SELL_VENGEANCE] then
        return mode.SELL_VENGEANCE, shouldRememberBuyMode
    end
    if modeSet[mode.BUYBACK] then
        return mode.BUYBACK, shouldRememberBuyMode
    end
    if modeSet[mode.REPAIR] then
        return mode.REPAIR, shouldRememberBuyMode
    end

    return (tabs[1] and tabs[1].mode) or mode.SELL, shouldRememberBuyMode
end

function ModePolicy.ResolveStableInitialStoreMode(request)
    request = request or {}
    local mode = Vendor.MODE or {}
    local modeSet = ModePolicy.BuildActiveModeSet(request.tabs)
    local nativeModeSet = ModePolicy.GetNativeActiveModeSet(request.storeManager)
    local nativeModesReady = next(nativeModeSet) ~= nil
    local shouldRememberBuyMode = modeSet[mode.BUY] == true

    local stableMode = rawget(_G, "ZO_MODE_STORE_STABLE")
    if nativeModesReady and stableMode and nativeModeSet[stableMode] then
        return mode.STABLE, shouldRememberBuyMode
    end
    if modeSet[mode.STABLE] then
        return mode.STABLE, shouldRememberBuyMode
    end
    if modeSet[mode.BUY] then
        return mode.BUY, true
    end
    if modeSet[mode.REPAIR] then
        return mode.REPAIR, shouldRememberBuyMode
    end

    return mode.BUY, shouldRememberBuyMode
end

function ModePolicy.ShouldUseNativeStoreFallback(request)
    request = request or {}
    if request.isStableInteraction or request.isFenceInteraction then
        return false
    end

    local getNumStoreItems = request.getNumStoreItems or rawget(_G, "GetNumStoreItems")
    local getStoreEntryInfo = request.getStoreEntryInfo or rawget(_G, "GetStoreEntryInfo")
    if type(getNumStoreItems) ~= "function" or type(getStoreEntryInfo) ~= "function" then
        return false
    end

    local itemEntryType = rawget(_G, "STORE_ENTRY_TYPE_ITEM")
    local entryCount = getNumStoreItems() or 0
    if entryCount <= 0 then
        return false
    end

    for entryIndex = 1, entryCount do
        local entryType = select(14, getStoreEntryInfo(entryIndex))
        if entryType ~= nil
            and (NATIVE_STORE_FALLBACK_ENTRY_TYPES[entryType]
                or (itemEntryType ~= nil and entryType ~= itemEntryType)) then
            return true, "nonItemStoreEntry", entryType, entryIndex
        end
    end

    return false
end

function ModePolicy.GetActiveTabs(context)
    context = context or {}
    if context.isFenceInteraction then
        return ModePolicy.GetFenceActiveTabs({
            fenceTabs = context.fenceTabs,
            enableSell = context.fenceEnableSell == true,
            enableLaunder = context.fenceEnableLaunder == true,
        })
    end

    local sourceTabs = context.isStableInteraction and (context.stableTabs or {}) or (context.vendorTabs or {})
    local fallbackTabs = context.isStableInteraction
        and (context.stableTabs or {})
        or CollectAvailableTabs(context.vendorTabs or {}, context.isModeTabAvailable)
    local nativeModeSet = ModePolicy.GetNativeActiveModeSet(context.storeManager)
    local nativeModesReady = next(nativeModeSet) ~= nil
    local includeBuyFromSession = context.sessionHasBuyMode == true
    if context.isStableInteraction and not nativeModesReady then
        includeBuyFromSession = false
    end
    return ModePolicy.GetStoreActiveTabs({
        sourceTabs = sourceTabs,
        fallbackTabs = fallbackTabs,
        includeBuyFromSession = includeBuyFromSession,
        includeStableRepair = context.isStableInteraction == true and nativeModesReady,
        isModeTabAvailable = context.isModeTabAvailable,
        storeManager = context.storeManager,
    })
end

function ModePolicy.GetToggleModePair(context)
    context = context or {}
    if context.isFenceInteraction then
        return ModePolicy.GetFenceToggleModePair()
    end
    if context.isStableInteraction then
        return ModePolicy.GetStableToggleModePair()
    end

    return ModePolicy.GetStoreToggleModePair({
        tabs = context.tabs,
        sessionHasBuyMode = context.sessionHasBuyMode == true,
    })
end

function ModePolicy.ResolveInitialStoreMode(context)
    context = context or {}
    local initialMode
    local shouldRememberBuyMode
    if context.isStableInteraction then
        initialMode, shouldRememberBuyMode = ModePolicy.ResolveStableInitialStoreMode({
            tabs = context.tabs,
            storeManager = context.storeManager,
        })
    else
        initialMode, shouldRememberBuyMode = ModePolicy.ResolveVendorInitialStoreMode({
            tabs = context.tabs,
            vendorTabs = context.vendorTabs or context.tabs,
            storeManager = context.storeManager,
            hasVendorBuyInventory = context.hasVendorBuyInventory,
        })
    end

    local L = BETTERUI.Log
    if L and L.TraceEvent then
        L.TraceEvent(L.CATEGORY.NAV, "vendor.mode", "changed", {
            module = "Vendor",
            feature = "vendor-mode-policy",
            fn = "Vendor.ModePolicy.ResolveInitialStoreMode",
            ["function"] = "Vendor.ModePolicy.ResolveInitialStoreMode",
            old = context.oldMode or context.currentMode,
            ["new"] = initialMode,
            mode = initialMode,
            targetMode = initialMode,
            trigger = context.trigger or "ResolveInitialStoreMode",
            isStable = context.isStableInteraction == true,
            isFence = context.isFenceInteraction == true,
        })
    end

    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "vendor initial mode resolved", {
            initialMode = initialMode,
            isStable = context.isStableInteraction == true,
            isFence = context.isFenceInteraction == true,
        })
    end

    return initialMode, shouldRememberBuyMode
end

Vendor.ResolveModeName = ModePolicy.ResolveModeName
Vendor.ResolveModeIcon = ModePolicy.ResolveModeIcon
Vendor.ResolveNativeStoreMode = ModePolicy.ResolveNativeStoreMode

-- SHARED VENDOR COMPONENT HELPERS (BUI-CONS-008)
-- Extracted from the per-tab components to remove byte-identical duplication.
-- VendorModePolicy loads before every vendor component and both batch files
-- (BetterUI.txt), so these are available at component load/runtime without a
-- manifest change. All engine globals are referenced at call time.

--- Build and append a standard vendor list entry (ZO_GamepadEntryData with the
--- item sub-entry template, narration, and quality name colors). Shared by the
--- buy/buyback/repair/sell/fence list builders.
---@param list table List control exposing AddEntry
---@param entryData table Row data source (name/icon/quality/...)
---@return table|nil entry The created entry, or nil when inputs are missing
function Vendor.AddItemRow(list, entryData)
    if not (list and entryData) then
        return nil
    end
    local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
    entry:SetDataSource(entryData)
    entry.narrationText = function() return entryData.name end
    if entryData.quality then
        local r, g, b = GetItemQualityColor(entryData.quality):UnpackRGBA()
        entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
    end
    list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
    return entry
end

--- Wrap an engine action call in the standard vendor trace envelope
--- (TraceActionRequested -> engine call -> ScheduleActionSettled). The caller
--- supplies the event name and trace payload so per-component trace output is
--- byte-for-byte unchanged.
---@param event string Trace event name (e.g. "vendor.buy")
---@param traceData table Trace payload
---@param fn fun() Zero-arg closure performing the engine call
function Vendor.DispatchTracedAction(event, traceData, fn)
    local goldBefore = Vendor.TraceActionRequested and Vendor.TraceActionRequested(event, traceData) or nil
    fn()
    if Vendor.ScheduleActionSettled then
        Vendor.ScheduleActionSettled(event, traceData, goldBefore)
    end
end

--- Authorize a vendor inventory action through the shared protection seam.
---@param actionType any Vendor.ACTION.* identifier
---@param bagId number|nil
---@param slotIndex number|nil
---@param vendorInstance table|nil
---@return boolean allowed
---@return any reason Deny reason when not allowed
function Vendor.AuthorizeAction(actionType, bagId, slotIndex, vendorInstance)
    local authorizeInventoryAction = Vendor.AuthorizeInventoryAction
    assert(type(authorizeInventoryAction) == "function",
        "Vendor.AuthorizeInventoryAction must load before Vendor authorized actions")
    local allowed, reason = authorizeInventoryAction(actionType, bagId, slotIndex, vendorInstance)
    return allowed == true, reason
end

--- True when the player's carried gold is at the wallet maximum. Selling for
--- gold while at the cap fails server-side, so the regular sell flows must
--- block first (mirrors native ZO_GamepadStoreSell:CanSell). Fence sell/launder
--- do NOT use this because stolen-goods sales do not credit the gold wallet.
---@return boolean atCap
function Vendor.IsAtGoldCap()
    if type(GetMaxPossibleCurrency) ~= "function" then
        return false
    end
    local carried = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    local maxPossible = GetMaxPossibleCurrency(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    return maxPossible > 0 and carried >= maxPossible
end

--- True when every currency charge for a store entry is affordable. Gold and
--- alt-currency charges are independent (alt-currency entries report
--- price == 0, not nil), so each charge is checked on its own. Carry/inventory
--- space is intentionally NOT covered here.
---@param instance table Vendor instance exposing CanAfford
---@param ds table Store entry data source
---@return boolean affordable
function Vendor.CanAffordStoreEntry(instance, ds)
    if not (instance and ds) then
        return false
    end
    -- Defensive: when the instance carries no CanAfford (limited callers/mocks)
    -- treat affordability as satisfied, matching the batch-count guard.
    if type(instance.CanAfford) ~= "function" then
        return true
    end
    local price = ds.price or 0
    if price > 0 then
        local currencyType = ds.currencyType or CURT_MONEY
        if currencyType == CURT_NONE then
            currencyType = CURT_MONEY
        end
        if not instance:CanAfford(price, currencyType) then
            return false
        end
    end
    local price1 = ds.currencyQuantity1 or 0
    local currencyType1 = ds.currencyType1
    if price1 > 0 and currencyType1 and currencyType1 ~= CURT_NONE
        and not instance:CanAfford(price1, currencyType1) then
        return false
    end
    local price2 = ds.currencyQuantity2 or 0
    local currencyType2 = ds.currencyType2
    if price2 > 0 and currencyType2 and currencyType2 ~= CURT_NONE then
        return instance:CanAfford(price2, currencyType2)
    end
    return true
end

--- Build a per-refresh memoizing getter. One vendor refresh calls GetCategories
--- and BuildList back to back; both need the same bag/store scan, so the result
--- is computed at most once per render frame (keyed by GetFrameTimeMilliseconds).
--- Without a frame clock (test harness) the result is never reused.
---@param computeFn fun(...): any Producer invoked to (re)compute the value
---@return fun(...): any getter Frame-memoized getter forwarding varargs to computeFn
---@return fun() invalidate Drops any cached value
function Vendor.PerRefreshCache(computeFn)
    local cachedValue = nil
    local cachedFrameMs = nil

    local function invalidate()
        cachedValue = nil
        cachedFrameMs = nil
    end

    local function get(...)
        local frameMs = (type(GetFrameTimeMilliseconds) == "function") and GetFrameTimeMilliseconds() or nil
        if frameMs and cachedValue ~= nil and cachedFrameMs == frameMs then
            return cachedValue
        end
        local value = computeFn(...)
        if frameMs then
            cachedValue = value
            cachedFrameMs = frameMs
        else
            -- No frame clock (test harness): never reuse a stale result.
            cachedValue = nil
            cachedFrameMs = nil
        end
        return value
    end

    return get, invalidate
end
