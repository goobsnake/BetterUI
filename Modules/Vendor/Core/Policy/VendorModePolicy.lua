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
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.CATEGORY, "vendorMode",
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

    if nativeModesReady
        and modeSet[mode.BUY]
        and type(request.hasVendorBuyInventory) == "function"
        and request.hasVendorBuyInventory() then
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
    local shouldRememberBuyMode = nativeModesReady and modeSet[mode.BUY] == true or false

    if modeSet[mode.BUY] then
        return mode.BUY, true
    end
    local stableMode = rawget(_G, "ZO_MODE_STORE_STABLE")
    if nativeModesReady and stableMode and nativeModeSet[stableMode] then
        return mode.STABLE, shouldRememberBuyMode
    end
    if modeSet[mode.REPAIR] then
        return mode.REPAIR, shouldRememberBuyMode
    end

    return mode.BUY, shouldRememberBuyMode
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
    return ModePolicy.GetStoreActiveTabs({
        sourceTabs = sourceTabs,
        fallbackTabs = fallbackTabs,
        includeBuyFromSession = context.sessionHasBuyMode == true,
        includeStableRepair = context.isStableInteraction == true,
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
    if context.isStableInteraction then
        return ModePolicy.ResolveStableInitialStoreMode({
            tabs = context.tabs,
            storeManager = context.storeManager,
        })
    end

    return ModePolicy.ResolveVendorInitialStoreMode({
        tabs = context.tabs,
        vendorTabs = context.vendorTabs or context.tabs,
        storeManager = context.storeManager,
        hasVendorBuyInventory = context.hasVendorBuyInventory,
    })
end

Vendor.ResolveModeName = ModePolicy.ResolveModeName
Vendor.ResolveModeIcon = ModePolicy.ResolveModeIcon
Vendor.ResolveNativeStoreMode = ModePolicy.ResolveNativeStoreMode
