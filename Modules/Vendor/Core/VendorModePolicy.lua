--[[
File: Modules/Vendor/Core/VendorModePolicy.lua
Purpose: Shared vendor mode-policy surface for native-mode translation, active
         tab derivation, and initial-mode selection.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.ModePolicy = Vendor.ModePolicy or {}
local ModePolicy = Vendor.ModePolicy
local DEFAULT_VENDOR_CATEGORY_ICON = "BetterUI/Modules/Vendor/Images/vendor.dds"

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

function ModePolicy.GetModeCategories(owner, mode)
    local _, categories = EnsureStoredCategories(owner, mode)
    return CloneCategories(categories)
end

function ModePolicy.GetCachedBuyCategories(owner)
    local state = EnsureCategoryState(owner)
    if not state.cachedBuyCategories or #state.cachedBuyCategories == 0 then
        return nil
    end
    return CloneCategories(state.cachedBuyCategories)
end

function ModePolicy.GetSelectedCategoryIndex(owner, mode)
    local state, categories = EnsureStoredCategories(owner, mode)
    local selectedIndex = state.selectedIndexByMode[mode] or 1
    if selectedIndex < 1 or selectedIndex > #categories then
        selectedIndex = 1
        state.selectedIndexByMode[mode] = selectedIndex
    end
    owner.categoryIndexByMode = state.selectedIndexByMode
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

    return previousCategories, CloneCategories(normalized), selectedIndex
end

function ModePolicy.GetCurrentCategory(owner, mode)
    local categories = ModePolicy.GetModeCategories(owner, mode)
    local selectedIndex = ModePolicy.GetSelectedCategoryIndex(owner, mode)
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

function ModePolicy.GetActiveTabs(context)
    context = context or {}
    if context.isFenceInteraction then
        local tabs = {}
        local fenceTabs = context.fenceTabs or {}
        if context.fenceEnableSell then
            tabs[#tabs + 1] = fenceTabs[1]
        end
        if context.fenceEnableLaunder then
            tabs[#tabs + 1] = fenceTabs[2]
        end
        if #tabs == 0 and fenceTabs[1] then
            tabs[1] = fenceTabs[1]
        end
        return CloneTabs(tabs)
    end

    local activeModeSet = ModePolicy.GetNativeActiveModeSet(context.storeManager)
    local includeBuyFromSession = context.sessionHasBuyMode == true
    local sourceTabs = context.isStableInteraction and (context.stableTabs or {}) or (context.vendorTabs or {})
    local tabs = {}
    for _, tab in ipairs(sourceTabs) do
        if not context.isModeTabAvailable or context.isModeTabAvailable(tab.mode) then
            local nativeMode = ModePolicy.ResolveNativeStoreMode(tab.mode)
            local includeStableRepair = context.isStableInteraction
                and tab.mode == Vendor.MODE.REPAIR
                and (type(CanStoreRepair) ~= "function" or CanStoreRepair())
            if (nativeMode and activeModeSet[nativeMode])
                or (tab.mode == Vendor.MODE.BUY and includeBuyFromSession)
                or includeStableRepair then
                tabs[#tabs + 1] = tab
            end
        end
    end

    if #tabs == 0 then
        if context.isStableInteraction then
            return CloneTabs(context.stableTabs or {})
        end
        for _, tab in ipairs(context.vendorTabs or {}) do
            if not context.isModeTabAvailable or context.isModeTabAvailable(tab.mode) then
                tabs[#tabs + 1] = tab
            end
        end
    end

    return CloneTabs(tabs)
end

function ModePolicy.GetToggleModePair(context)
    context = context or {}
    local mode = Vendor.MODE or {}
    if context.isFenceInteraction then
        return mode.FENCE_SELL, mode.FENCE_LAUNDER
    end
    if context.isStableInteraction then
        return mode.BUY, mode.STABLE
    end

    local modeSet = ModePolicy.BuildActiveModeSet(context.tabs)
    if modeSet[mode.BUY] and modeSet[mode.SELL] then
        return mode.BUY, mode.SELL
    end
    if modeSet[mode.SELL] and context.sessionHasBuyMode == true then
        return mode.BUY, mode.SELL
    end
    if ModePolicy.IsSellBuybackOnlyModeSet(modeSet, context.isFenceInteraction) then
        return mode.SELL, mode.BUYBACK
    end

    return nil, nil
end

function ModePolicy.ResolveInitialStoreMode(context)
    context = context or {}
    local mode = Vendor.MODE or {}
    local tabs = context.tabs or {}
    local vendorTabs = context.vendorTabs or tabs
    local modeSet = ModePolicy.BuildActiveModeSet(tabs)
    local nativeModeSet = ModePolicy.GetNativeActiveModeSet(context.storeManager)
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

    if ModePolicy.IsSellBuybackOnlyModeSet(modeSet, context.isFenceInteraction) then
        return mode.SELL, shouldRememberBuyMode
    end

    if context.isStableInteraction then
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
        and type(context.hasVendorBuyInventory) == "function"
        and context.hasVendorBuyInventory() then
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

Vendor.ResolveModeName = ModePolicy.ResolveModeName
Vendor.ResolveModeIcon = ModePolicy.ResolveModeIcon
Vendor.ResolveNativeStoreMode = ModePolicy.ResolveNativeStoreMode
