if not BETTERUI.Vendor then BETTERUI.Vendor = {} end
local Vendor = BETTERUI.Vendor

BETTERUI_VENDOR_SCENE_NAME = BETTERUI_VENDOR_SCENE_NAME or "BETTERUI_VENDOR"
Vendor.VENDOR_INTERACTION = Vendor.VENDOR_INTERACTION or STORE_INTERACTION
Vendor.FENCE_INTERACTION = Vendor.FENCE_INTERACTION or {
    type = "Fence",
    interactTypes = { INTERACTION_VENDOR },
}
Vendor.MODE = assert(Vendor.MODE, "Vendor mode constants must load before VendorClass")

local MODE = Vendor.MODE
local DEFAULT_VENDOR_CATEGORY_ICON = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"

local SEARCH_LIFECYCLE = {
    clear = "ClearSearchInput",
    exit = "ExitSearchMode",
    headerActive = "IsHeaderFocused",
    requestEnter = "RequestHeaderFocus",
    onEnter = "OnHeaderEntered",
}

local function ResolveStableInteractionIcon()
    if BETTERUI.Vendor and BETTERUI.Vendor.GetStableInteractionIcon then
        return BETTERUI.Vendor.GetStableInteractionIcon()
    end
    return "EsoUI/Art/Collections/Default/collections_default_mount.dds"
end

local MODE_DESCRIPTORS = {
    [MODE.BUY] = {
        nameStringId = "SI_BETTERUI_VENDOR_TAB_BUY",
        iconFile = "EsoUI/Art/Vendor/vendor_tabIcon_buy_up.dds",
        nativeModeGlobalKey = "ZO_MODE_STORE_BUY",
        moduleKeyField = "VENDOR_BUY",
        regularPaneRole = "first",
        stablePaneRole = "first",
    },
    [MODE.SELL] = {
        nameStringId = "SI_BETTERUI_VENDOR_TAB_SELL",
        iconFile = "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds",
        nativeModeGlobalKey = "ZO_MODE_STORE_SELL",
        moduleKeyField = "VENDOR_SELL",
        regularPaneRole = "second",
    },
    [MODE.SELL_VENGEANCE] = {
        nameStringId = "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE",
        iconFile = "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds",
        nativeModeGlobalKey = "ZO_MODE_STORE_SELL_VENGEANCE",
        moduleKeyField = "VENDOR_SELL_VENGEANCE",
        regularPaneRole = "second",
    },
    [MODE.REPAIR] = {
        nameStringId = "SI_BETTERUI_VENDOR_TAB_REPAIR",
        iconFile = "EsoUI/Art/Vendor/vendor_tabIcon_repair_up.dds",
        nativeModeGlobalKey = "ZO_MODE_STORE_REPAIR",
        moduleKeyField = "VENDOR_REPAIR",
        emptyStateStringId = "SI_BETTERUI_VENDOR_NO_REPAIR_ITEMS",
        titleUsesItemsSuffix = true,
        stablePaneRole = "first",
    },
    [MODE.BUYBACK] = {
        nameStringId = "SI_BETTERUI_VENDOR_TAB_BUYBACK",
        iconFile = "EsoUI/Art/Vendor/vendor_tabIcon_buyBack_up.dds",
        nativeModeGlobalKey = "ZO_MODE_STORE_BUY_BACK",
        moduleKeyField = "VENDOR_BUYBACK",
        emptyStateStringId = "SI_BETTERUI_VENDOR_NO_BUYBACK_ITEMS",
        titleUsesItemsSuffix = true,
    },
    [MODE.FENCE_SELL] = {
        nameStringId = "SI_BETTERUI_VENDOR_TAB_FENCE_SELL",
        iconFile = "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds",
        nativeModeGlobalKey = "ZO_MODE_STORE_SELL_STOLEN",
        moduleKeyField = "VENDOR_FENCE_SELL",
        fencePaneRole = "first",
    },
    [MODE.FENCE_LAUNDER] = {
        nameStringId = "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER",
        iconFile = "EsoUI/Art/Vendor/vendor_tabIcon_fence_up.dds",
        nativeModeGlobalKey = "ZO_MODE_STORE_LAUNDER",
        moduleKeyField = "VENDOR_FENCE_LAUNDER",
        fencePaneRole = "second",
    },
    [MODE.STABLE] = {
        nameStringId = "SI_STABLE_STABLES_TAB",
        iconResolver = ResolveStableInteractionIcon,
        nativeModeGlobalKey = "ZO_MODE_STORE_STABLE",
        moduleKeyField = "VENDOR_STABLE",
        stablePaneRole = "second",
    },
}

local function GetModeDescriptor(mode)
    return MODE_DESCRIPTORS[mode]
end

Vendor.GetModeDescriptor = GetModeDescriptor

local ResolveModeName = assert(Vendor.ResolveModeName, "Vendor mode policy must load before VendorClass")
local ResolveModeIcon = assert(Vendor.ResolveModeIcon, "Vendor mode policy must load before VendorClass")
local ResolveNativeStoreMode = assert(Vendor.ResolveNativeStoreMode, "Vendor mode policy must load before VendorClass")
local VendorModePolicy = assert(Vendor.ModePolicy, "Vendor mode policy must load before VendorClass")
local VendorControllerRuntime = assert(Vendor.ControllerRuntime, "Vendor controller runtime must load before VendorClass")
local VendorPresentationRuntime = assert(Vendor.PresentationRuntime, "Vendor presentation runtime must load before VendorClass")

local function DoesModeUseItemsTitle(mode)
    local descriptor = GetModeDescriptor(mode)
    return descriptor and descriptor.titleUsesItemsSuffix == true or false
end

local function ResolveModeEmptyStateText(mode)
    local descriptor = GetModeDescriptor(mode)
    if not (descriptor and descriptor.emptyStateStringId) then
        return nil
    end
    local stringId = descriptor.emptyStateStringId
    return GetString(rawget(_G, stringId) or stringId)
end

local function ResolveModePaneRole(mode, isStableInteraction, isFenceInteraction)
    local descriptor = GetModeDescriptor(mode)
    if not descriptor then
        return nil
    end

    if isFenceInteraction then
        return descriptor.fencePaneRole
    end
    if isStableInteraction then
        return descriptor.stablePaneRole
    end
    return descriptor.regularPaneRole
end

---@param activeTabs table[]|nil
---@return boolean
local function IsSellBuybackOnlyTabs(activeTabs)
    local modeSet = VendorModePolicy.BuildActiveModeSet(activeTabs)
    local isFenceInteraction = BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction()
    return VendorModePolicy.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)
end

local function IsUnifiedBuyHeaderMode(mode)
    return mode == BETTERUI.Vendor.MODE.BUY
        or mode == BETTERUI.Vendor.MODE.REPAIR
        or mode == BETTERUI.Vendor.MODE.BUYBACK
end

local function ShouldIncludeHeaderModeTab(mode, currentMode, isStableInteraction, isSellBuybackOnly)
    if not mode then
        return false
    end
    if isSellBuybackOnly then
        return mode == BETTERUI.Vendor.MODE.SELL or mode == BETTERUI.Vendor.MODE.BUYBACK
    end
    if not IsUnifiedBuyHeaderMode(currentMode) then
        return false
    end
    if isStableInteraction then
        return mode == BETTERUI.Vendor.MODE.REPAIR
    end
    return mode == BETTERUI.Vendor.MODE.REPAIR or mode == BETTERUI.Vendor.MODE.BUYBACK
end

local IsStableInteractionActive

local function BuildHeaderModeTabs(activeTabs, currentMode)
    local modeTabs = {}
    local isFenceInteraction = BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction()
    local isStableInteraction = IsStableInteractionActive()
    local isSellBuybackOnly = IsSellBuybackOnlyTabs(activeTabs)
    currentMode = currentMode or BETTERUI.Vendor.MODE.BUY

    for _, tab in ipairs(activeTabs or {}) do
        if isFenceInteraction then
        elseif ShouldIncludeHeaderModeTab(tab.mode, currentMode, isStableInteraction, isSellBuybackOnly) then
            modeTabs[#modeTabs + 1] = tab
        end
    end

    return modeTabs
end

---@param left table[]|nil
---@param right table[]|nil
---@return boolean
local function AreVendorCategoriesEquivalent(left, right)
    if left == right then
        return true
    end
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    if #left ~= #right then
        return false
    end

    for index = 1, #left do
        local leftCategory = left[index] or {}
        local rightCategory = right[index] or {}
        if (leftCategory.key or leftCategory.name or index) ~= (rightCategory.key or rightCategory.name or index)
            or leftCategory.name ~= rightCategory.name
            or leftCategory.iconFile ~= rightCategory.iconFile
            or leftCategory.filterType ~= rightCategory.filterType
            or leftCategory.itemCount ~= rightCategory.itemCount
            or leftCategory.special ~= rightCategory.special then
            return false
        end
    end

    return true
end

local function ShouldShowVendorHeaderTabBar(headerEntryCount)
    return (headerEntryCount or 0) > 0
end

local function BuildVendorHeaderModel(instance)
    local mode = instance:GetCurrentMode()
    local activeTabs = (BETTERUI.Vendor.GetActiveTabs and BETTERUI.Vendor.GetActiveTabs()) or {}
    local modeTabs = BuildHeaderModeTabs(activeTabs, mode)
    local isSellBuybackOnly = IsSellBuybackOnlyTabs(activeTabs)
    local useUnifiedBuyHeader = (not isSellBuybackOnly) and IsUnifiedBuyHeaderMode(mode)
    local categoryMode = useUnifiedBuyHeader and BETTERUI.Vendor.MODE.BUY or mode
    VendorModePolicy.EnsureModeCategories(instance, categoryMode)
    local categories = instance:GetModeCategories(categoryMode)
    local cachedBuyCategories = VendorModePolicy.GetCachedBuyCategories(instance)
    if useUnifiedBuyHeader
        and categoryMode == BETTERUI.Vendor.MODE.BUY
        and #categories <= 1
        and cachedBuyCategories
        and #cachedBuyCategories > 1 then
        categories = cachedBuyCategories
        VendorModePolicy.SetModeCategories(instance, BETTERUI.Vendor.MODE.BUY, categories)
    end

    local showCategoryEntries = not isSellBuybackOnly
    if not showCategoryEntries and #modeTabs == 0 then
        showCategoryEntries = true
    end

    local selectedCategoryIndex = VendorModePolicy.GetSelectedCategoryIndex(instance, categoryMode)
    selectedCategoryIndex = zo_clamp(selectedCategoryIndex, 1, #categories)
    local selectedCategory = categories[selectedCategoryIndex]

    local modeEntryCount = #modeTabs
    local selectedHeaderIndex
    if showCategoryEntries then
        selectedHeaderIndex = modeEntryCount + selectedCategoryIndex
        if useUnifiedBuyHeader and mode ~= BETTERUI.Vendor.MODE.BUY then
            for modeEntryIndex, tab in ipairs(modeTabs) do
                if tab.mode == mode then
                    selectedHeaderIndex = modeEntryIndex
                    break
                end
            end
        end
    else
        selectedHeaderIndex = 1
        for modeEntryIndex, tab in ipairs(modeTabs) do
            if tab.mode == mode then
                selectedHeaderIndex = modeEntryIndex
                break
            end
        end
    end

    local preferredModeSelection = instance._preferredModeHeaderSelectionMode
    if preferredModeSelection and modeEntryCount > 0 then
        for modeEntryIndex, tab in ipairs(modeTabs) do
            if tab.mode == preferredModeSelection then
                selectedHeaderIndex = modeEntryIndex
                break
            end
        end
    end

    local headerEntries = {}
    for _, tab in ipairs(modeTabs) do
        headerEntries[#headerEntries + 1] = {
            modeSwitchMode = tab.mode,
            name = ResolveModeName(tab.mode),
            iconFile = ResolveModeIcon(tab.mode),
        }
    end
    if showCategoryEntries then
        for categoryIndex, category in ipairs(categories) do
            headerEntries[#headerEntries + 1] = {
                categoryIndex = categoryIndex,
                categoryMode = categoryMode,
                name = category.name,
                iconFile = category.iconFile or DEFAULT_VENDOR_CATEGORY_ICON,
                filterType = category.filterType,
                itemCount = category.itemCount,
            }
        end
    end

    return {
        mode = mode,
        useUnifiedBuyHeader = useUnifiedBuyHeader,
        categoryMode = categoryMode,
        selectedCategoryIndex = selectedCategoryIndex,
        selectedCategory = selectedCategory,
        headerEntries = headerEntries,
        selectedHeaderIndex = selectedHeaderIndex,
        modeEntryCount = modeEntryCount,
        categoryCount = showCategoryEntries and #categories or 0,
        headerEntryCount = #headerEntries,
        shouldShowHeaderTabBar = ShouldShowVendorHeaderTabBar(#headerEntries),
    }
end

local function ApplyVendorHeaderModelState(instance, headerModel)
    VendorModePolicy.SetSelectedCategoryIndex(instance, headerModel.categoryMode, headerModel.selectedCategoryIndex)
    instance.currentCategoryIndex = headerModel.selectedCategoryIndex
    instance._preferredModeHeaderSelectionMode = nil
    instance._vendorHeaderModeEntryCount = headerModel.modeEntryCount
    instance._vendorHeaderCategoryCount = headerModel.categoryCount
    instance._vendorHeaderCategoryMode = headerModel.categoryMode
    instance._vendorHeaderEntryCount = headerModel.headerEntryCount
end

local function BuildVendorHeaderData(instance, headerModel, onSelectedChanged)
    local carouselStartOffset = (BETTERUI.Vendor and BETTERUI.Vendor.CONST and BETTERUI.Vendor.CONST.CAROUSEL and BETTERUI.Vendor.CONST.CAROUSEL.startOffset)
        or BETTERUI.CIM.CONST.CAROUSEL.startOffset
    local carouselVerticalOffset = (BETTERUI.Vendor and BETTERUI.Vendor.CONST and BETTERUI.Vendor.CONST.CAROUSEL and BETTERUI.Vendor.CONST.CAROUSEL.verticalOffset)
        or BETTERUI.CIM.CONST.CAROUSEL.verticalOffset

    return {
        titleText = function()
            local mode = headerModel.mode
            if mode == BETTERUI.Vendor.MODE.STABLE then
                return ResolveModeName(mode)
            end
            if DoesModeUseItemsTitle(mode) then
                return zo_strformat("<<1>> - <<2>>", ResolveModeName(mode), "Items")
            end
            if headerModel.selectedCategory and headerModel.selectedCategory.name and headerModel.selectedCategory.name ~= "" then
                return zo_strformat("<<1>> - <<2>>", ResolveModeName(mode), headerModel.selectedCategory.name)
            end
            return ResolveModeName(mode)
        end,
        tabBarData = { parent = instance },
        carouselConfig = {
            enabled = (not BETTERUI.Vendor.GetSetting) or (BETTERUI.Vendor.GetSetting("enableCarousel") ~= false),
            startOffset = carouselStartOffset,
            verticalOffset = carouselVerticalOffset,
            itemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing,
        },
        onSelectedChanged = onSelectedChanged,
    }
end

local function CreateVendorHeaderSelectionHandler(instance, headerModel, headerNavigation, navigationState)
    local coalescedCategoryHandler = nil
    if headerNavigation and headerNavigation.CreateCoalescedHandler then
        coalescedCategoryHandler = headerNavigation.CreateCoalescedHandler({
            delay = BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS,
            onSave = function(screen)
                screen:SaveListPosition()
            end,
            onApply = function(screen, headerIndex)
                local appliedHeaderIndex = zo_clamp(headerIndex or 1, 1, #headerModel.headerEntries)
                local appliedEntry = headerModel.headerEntries[appliedHeaderIndex]
                if not appliedEntry then
                    return
                end

                local categoryIndex = appliedEntry.categoryIndex or 1
                local selectedCategoryMode = appliedEntry.categoryMode or screen:GetCurrentMode()
                VendorModePolicy.EnsureModeCategories(screen, selectedCategoryMode)
                local shouldSwitchToBuy = headerModel.useUnifiedBuyHeader
                    and screen:GetCurrentMode() ~= BETTERUI.Vendor.MODE.BUY
                    and selectedCategoryMode == BETTERUI.Vendor.MODE.BUY
                local currentCategoryIndex = VendorModePolicy.GetSelectedCategoryIndex(screen, selectedCategoryMode)
                if currentCategoryIndex == categoryIndex and not shouldSwitchToBuy then
                    if screen.UpdateVendorHeaderTitle then
                        screen:UpdateVendorHeaderTitle()
                    end
                    return
                end

                VendorModePolicy.SetSelectedCategoryIndex(screen, selectedCategoryMode, categoryIndex)
                screen.currentCategoryIndex = categoryIndex
                if screen.UpdateVendorHeaderTitle then
                    screen:UpdateVendorHeaderTitle()
                end

                if shouldSwitchToBuy then
                    screen:SetMode(BETTERUI.Vendor.MODE.BUY)
                    return
                end

                screen:RefreshList()
            end,
            sceneCheck = function()
                if instance.IsSceneShowing then
                    return instance:IsSceneShowing()
                end
                if instance.IsSceneActiveOrShowing then
                    return instance:IsSceneActiveOrShowing()
                end
                return true
            end,
        })
    end

    return function(list)
        if instance._suppressVendorHeaderSelection then
            return
        end

        local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(instance) or nil
        if navigationState and state and navigationState.ShouldSuppressCallback and navigationState.ShouldSuppressCallback(state) then
            return
        end

        local index = list and list.selectedIndex or headerModel.selectedHeaderIndex
        index = zo_clamp(index, 1, #headerModel.headerEntries)
        local selectedEntry = headerModel.headerEntries[index]
        if not selectedEntry then
            return
        end

        if selectedEntry.modeSwitchMode then
            local targetMode = selectedEntry.modeSwitchMode
            if targetMode ~= headerModel.mode then
                instance._preferredModeHeaderSelectionMode = targetMode
                instance:SetMode(targetMode)
            end
            return
        end

        if coalescedCategoryHandler then
            coalescedCategoryHandler(instance, list, selectedEntry)
            return
        end

        local categoryIndex = selectedEntry.categoryIndex or 1
        local selectedCategoryMode = selectedEntry.categoryMode or headerModel.mode
        VendorModePolicy.EnsureModeCategories(instance, selectedCategoryMode)
        local shouldSwitchToBuy = headerModel.useUnifiedBuyHeader
            and headerModel.mode ~= BETTERUI.Vendor.MODE.BUY
            and selectedCategoryMode == BETTERUI.Vendor.MODE.BUY
        local currentCategoryIndex = VendorModePolicy.GetSelectedCategoryIndex(instance, selectedCategoryMode)
        if currentCategoryIndex == categoryIndex and not shouldSwitchToBuy then
            return
        end

        VendorModePolicy.SetSelectedCategoryIndex(instance, selectedCategoryMode, categoryIndex)
        instance.currentCategoryIndex = categoryIndex
        if shouldSwitchToBuy then
            instance:SetMode(BETTERUI.Vendor.MODE.BUY)
            return
        end
        instance:RefreshList()
    end
end

local function RenderVendorHeader(instance, headerGeneric, headerModel)
    instance._suppressVendorHeaderSelection = true
    if not headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(headerGeneric, instance.vendorHeaderData, false)
    end
    if headerGeneric.tabBar then
        headerGeneric.tabBar:Clear()
    end

    for _, entryInfo in ipairs(headerModel.headerEntries) do
        local entryData = ZO_GamepadEntryData:New(entryInfo.name, entryInfo.iconFile or DEFAULT_VENDOR_CATEGORY_ICON)
        entryData.filterType = entryInfo.filterType
        entryData.itemCount = entryInfo.itemCount
        entryData.countBadgeOffsetY = 3
        entryData.modeSwitchMode = entryInfo.modeSwitchMode
        entryData.categoryIndex = entryInfo.categoryIndex
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(headerGeneric, entryData)
    end

    BETTERUI.GenericHeader.Refresh(headerGeneric, instance.vendorHeaderData, false)

    local tabBarControl = headerGeneric:GetNamedChild("TabBar")
    if tabBarControl then
        tabBarControl:SetHidden(not headerModel.shouldShowHeaderTabBar)
    end
end

local function RestoreVendorHeaderInteraction(instance, headerGeneric, headerModel, headerNavigation)
    if headerGeneric.tabBar and headerModel.shouldShowHeaderTabBar then
        local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(instance) or nil
        if state and state.justToggledMode then
            headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(headerModel.selectedHeaderIndex, true, true)
        else
            if state then
                state.suppressHeaderCallback = true
            end
            headerGeneric.tabBar:SetSelectedIndex(headerModel.selectedHeaderIndex, true, true)
            if state then
                state.suppressHeaderCallback = false
            end
        end
        instance:RefreshVendorHeaderCarouselLayout()
    elseif headerGeneric.tabBar then
        SetTabBarVisualActive(headerGeneric.tabBar, false)
        ReleaseDirectionalInputRegistrations(headerGeneric.tabBar, true)
    end

    local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(instance) or nil
    if state then
        state.justToggledMode = false
    end
    instance._suppressVendorHeaderSelection = false
    if instance.PositionSearchControl then
        instance:PositionSearchControl()
    end

    if instance:IsSceneShowing() then
        instance:EnsureHeaderKeybindsActive()
        if not instance._searchModeActive and not instance._searchHeaderActive then
            instance:EnsureListInputActive()
        end
    end

    instance:EnsureColumnHeadersVisible()
end

local ExecuteSafely = assert(Vendor.ExecuteSafely, "Vendor safe execute helper must load before VendorClass")

local LogVendorDebug = Vendor.LogDebug

---@return boolean
function IsStableInteractionActive()
    return BETTERUI.Vendor
        and BETTERUI.Vendor.IsStableInteraction
        and BETTERUI.Vendor.IsStableInteraction()
        or false
end

local IsDirectionalInputListening = Vendor.IsDirectionalInputListening

---@param obj table|nil
---@return number registrationCount
local function CountDirectionalInputRegistrations(obj)
    if not obj or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.inputObjects) then
        return 0
    end

    local registrationCount = 0
    for _, registeredObject in ipairs(DIRECTIONAL_INPUT.inputObjects) do
        if registeredObject == obj then
            registrationCount = registrationCount + 1
        end
    end

    return registrationCount
end

---@param tabBar table|nil
---@param active boolean
---@return nil
local function SetTabBarVisualActive(tabBar, active)
    if not tabBar or tabBar.active == active then
        return
    end

    tabBar.active = active
    tabBar.dirty = false

    local onActivatedChanged = (tabBar.GetOnActivatedChangedFunction and tabBar:GetOnActivatedChangedFunction())
        or tabBar.onActivatedChangedFunction
    if onActivatedChanged then
        onActivatedChanged(tabBar, active)
    end

    if tabBar.RefreshVisible then
        tabBar:RefreshVisible()
    end
    if tabBar.Commit then
        tabBar:Commit()
    end
end

local function ReleaseDirectionalInputRegistrations(obj, includeMovementController)
    if BETTERUI.Vendor and BETTERUI.Vendor.ReleaseDirectionalInputRegistrations then
        return BETTERUI.Vendor.ReleaseDirectionalInputRegistrations(obj, includeMovementController)
    end
    return 0
end

local function ReleaseSpinnerDirectionalInput(spinner)
    if not spinner then
        return
    end

    if spinner.DetachFromListEntry then
        ExecuteSafely("Vendor.ReleaseSpinnerDirectionalInput:DetachFromListEntry", spinner.DetachFromListEntry, spinner)
    end
    if spinner.Deactivate then
        ExecuteSafely("Vendor.ReleaseSpinnerDirectionalInput:Deactivate", spinner.Deactivate, spinner)
    end
    if spinner.SetHidden then
        spinner:SetHidden(true)
    end

    ReleaseDirectionalInputRegistrations(spinner, true)

    if spinner.spinner then
        if spinner.spinner.Deactivate then
            ExecuteSafely("Vendor.ReleaseSpinnerDirectionalInput:DeactivateNestedSpinner", spinner.spinner.Deactivate, spinner.spinner)
        end
        ReleaseDirectionalInputRegistrations(spinner.spinner, true)
    end
end

local function ForEachHeaderDirectionalInputCandidate(header, callback)
    if not header or type(callback) ~= "function" then
        return
    end

    local seen = {}
    local function Visit(candidate)
        if not candidate or seen[candidate] then
            return
        end
        seen[candidate] = true
        callback(candidate)
    end

    Visit(header.headerFocus)
    Visit(header.headerFocusControl)
    Visit(header.headerFocusControl and header.headerFocusControl.owner)
    Visit(header.tabBar)
    Visit(header.tabBar and header.tabBar.control)
end

local function ReleaseHeaderDirectionalInput(header, context)
    local releasedCount = 0

    ForEachHeaderDirectionalInputCandidate(header, function(candidate)
        if candidate.Deactivate then
            ExecuteSafely(context or "Vendor.ReleaseHeaderDirectionalInput:Deactivate", candidate.Deactivate, candidate)
        end
        releasedCount = releasedCount + ReleaseDirectionalInputRegistrations(candidate, true)
    end)

    return releasedCount
end

local function HasVisibleGamepadDialog()
    if not GetControl then
        return false
    end

    local gamepadDialog = GetControl("ZO_DialogGamepad1")
    return gamepadDialog and gamepadDialog.IsHidden and not gamepadDialog:IsHidden() or false
end

local function ShouldAllowVendorDeferredNormalization(screen)
    return screen
        and screen.IsSceneShowing and screen:IsSceneShowing()
        and not screen.confirmationMode
        and not screen._searchModeActive
        and not screen._searchHeaderActive
        and not HasVisibleGamepadDialog()
end

local function SupportsVendorHeaderSearch(screen)
    return screen
        and screen.textSearchKeybindStripDescriptor ~= nil
        and screen.textSearchHeaderControl ~= nil
        and screen.textSearchHeaderFocus ~= nil
end

local HEADER_COLUMN_KEYS = { "NAME", "TYPE", "TRAIT", "STAT", "VALUE" }
local LAYOUT_COLUMN_KEYS = { "SUBMENU", "TYPE", "TRAIT", "STAT", "VALUE" }

local function ResolveHeaderColumnOffset(columnIndex)
    if not columnIndex then
        return nil
    end

    local headerColumns = BETTERUI.CIM.CONST.HEADER_LAYOUT and BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    if headerColumns then
        local headerKey = HEADER_COLUMN_KEYS[columnIndex]
        if headerKey and headerColumns[headerKey] then
            return headerColumns[headerKey]
        end
    end

    local layoutColumns = BETTERUI.CIM.CONST.LAYOUT and BETTERUI.CIM.CONST.LAYOUT.COLUMNS
    if layoutColumns then
        local layoutKey = LAYOUT_COLUMN_KEYS[columnIndex]
        local columnDef = layoutKey and layoutColumns[layoutKey]
        if type(columnDef) == "table" and columnDef.OFFSET_X then
            return columnDef.OFFSET_X
        end

        local legacyOffset = layoutColumns[columnIndex]
        if type(legacyOffset) == "number" then
            return legacyOffset
        end
    end

    return nil
end

local VendorDeferredTask = assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask,
    "BetterUI: CIM.DeferredTask must load before Vendor/Core/VendorClass")
local function EnsureVendorTaskManager()
    if not BETTERUI.Vendor._taskManager then
        BETTERUI.Vendor._taskManager = VendorDeferredTask.CreateManager()
    end
    return BETTERUI.Vendor._taskManager
end
BETTERUI.Vendor.EnsureTaskManager = EnsureVendorTaskManager
BETTERUI.Vendor.Tasks = BETTERUI.Vendor.Tasks or VendorDeferredTask.CreateLazyManagerProxy(EnsureVendorTaskManager)

---@class BETTERUI.Vendor.Class : BETTERUI.CIM.GenericWindow
---@field currentMode number Current active vendor mode (see BETTERUI.Vendor.MODE)
---@field components table<number, VendorComponent> Registered mode components
---@field list table|nil Parametric list control
---@field coreKeybinds table Core keybind button group
---@field header table|nil Header control with SetTitle method
---@field _keybindsAdded boolean Whether keybinds are currently registered
---@field _suppressListUpdates boolean Whether list refreshes are suppressed
---@field _isDirty boolean Whether list needs refresh after suppression ends
---@field unifiedFooterController table|nil Footer controller reference
BETTERUI.Vendor.Class = BETTERUI.CIM.GenericWindow:Subclass()
BETTERUI.Vendor.Class.SEARCH_LIFECYCLE = SEARCH_LIFECYCLE

---@param ... any Arguments forwarded to GenericWindow:New
---@return BETTERUI.Vendor.Class
function BETTERUI.Vendor.Class:New(...)
    local obj = BETTERUI.CIM.GenericWindow.New(self, ...)
    return obj --[[@as BETTERUI.Vendor.Class]]
end

---@return boolean showing True if the vendor scene is currently showing
function BETTERUI.Vendor.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

---@return boolean active True when the vendor scene is not hidden (showing/shown/transitioning)
function BETTERUI.Vendor.Class:IsSceneActiveOrShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then
        return false
    end
    if scene.GetState and rawget(_G, "SCENE_HIDDEN") then
        return scene:GetState() ~= SCENE_HIDDEN
    end
    return scene:IsShowing()
end

---@return boolean
function BETTERUI.Vendor.Class:IsSellBuybackOnlyStore()
    if BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction() then
        return false
    end

    if BETTERUI.Vendor.IsSellBuybackOnlyStore then
        return BETTERUI.Vendor.IsSellBuybackOnlyStore()
    end

    local activeTabs = (BETTERUI.Vendor.GetActiveTabs and BETTERUI.Vendor.GetActiveTabs()) or {}
    return IsSellBuybackOnlyTabs(activeTabs)
end

---@return nil
function BETTERUI.Vendor.Class:ReleaseNativeStoreInputOwnership()
    VendorControllerRuntime.ReleaseNativeStoreInputOwnership(self, {
        isDirectionalInputListening = IsDirectionalInputListening,
        releaseSpinnerDirectionalInput = ReleaseSpinnerDirectionalInput,
        logVendorDebug = LogVendorDebug,
        executeSafely = ExecuteSafely,
        releaseDirectionalInputRegistrations = ReleaseDirectionalInputRegistrations,
        releaseHeaderDirectionalInput = ReleaseHeaderDirectionalInput,
    })
end

---@return nil
function BETTERUI.Vendor.Class:ForceReleaseDirectionalInput()
    VendorControllerRuntime.ForceReleaseDirectionalInput(self, {
        isDirectionalInputListening = IsDirectionalInputListening,
        releaseSpinnerDirectionalInput = ReleaseSpinnerDirectionalInput,
        releaseDirectionalInputRegistrations = ReleaseDirectionalInputRegistrations,
        releaseHeaderDirectionalInput = ReleaseHeaderDirectionalInput,
        logVendorDebug = LogVendorDebug,
    })
end

---@param reason string|nil
---@return boolean detached
function BETTERUI.Vendor.Class:DetachUnexpectedSearchHeaderFocus(reason)
    if SupportsVendorHeaderSearch(self) then
        return false
    end

    local focusControl = self.textSearchHeaderControl
    local focusObject = self.textSearchHeaderFocus
    local hadSearchFocus = focusControl ~= nil or focusObject ~= nil or self.headerFocus ~= nil
    if not hadSearchFocus then
        return false
    end

    local function ClearHeader(header)
        if not header then
            return
        end

        if header.headerFocusControl == focusControl then
            header.headerFocusControl = nil
        end
        if header.headerFocus == focusObject or header.headerFocus == focusControl then
            header.headerFocus = nil
        end

        local tabBarControl = header.tabBar and header.tabBar.control
        if tabBarControl then
            if tabBarControl.headerFocusControl == focusControl then
                tabBarControl.headerFocusControl = nil
            end
            if tabBarControl.headerFocus == focusObject or tabBarControl.headerFocus == focusControl then
                tabBarControl.headerFocus = nil
            end
        end
    end

    if focusObject then
        if focusObject.SetFocused then
            ExecuteSafely("Vendor.DetachUnexpectedSearchHeaderFocus:SetFocused", focusObject.SetFocused, focusObject, false)
        end
        if focusObject.Deactivate then
            ExecuteSafely("Vendor.DetachUnexpectedSearchHeaderFocus:DeactivateFocus", focusObject.Deactivate, focusObject)
        end
        ReleaseDirectionalInputRegistrations(focusObject, true)
    end

    if focusControl then
        if focusControl.SetHidden then
            focusControl:SetHidden(true)
        end
        ReleaseDirectionalInputRegistrations(focusControl, true)
    end

    ClearHeader(self.headerGeneric)
    ClearHeader(self.header)

    if self.headerFocus == focusObject or self.headerFocus == focusControl then
        self.headerFocus = nil
    end

    self._searchModeActive = false
    self._searchHeaderActive = false

    if hadSearchFocus then
        LogVendorDebug(
            "DIRECTIONAL_INPUT",
            "VendorDI",
            string.format("DetachUnexpectedSearchHeaderFocus reason=%s", tostring(reason or "unknown"))
        )
    end

    return hadSearchFocus
end

---@param reason string|nil
---@return nil
function BETTERUI.Vendor.Class:NormalizeDirectionalInputOwnership(reason)
    if not (self.IsSceneShowing and self:IsSceneShowing()) then
        return
    end

    if self.DetachUnexpectedSearchHeaderFocus then
        self:DetachUnexpectedSearchHeaderFocus(reason)
    end

    if HasVisibleGamepadDialog() then
        return
    end

    if not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.inputObjects) then
        return
    end

    local allowed = {}
    local function Allow(obj, includeMovementController)
        if not obj then
            return
        end

        allowed[obj] = true
        if obj.spinner then
            allowed[obj.spinner] = true
        end

        if includeMovementController then
            if obj.movementController then
                allowed[obj.movementController] = true
            end
            if obj.horizontalMovementController then
                allowed[obj.horizontalMovementController] = true
            end
            if obj.verticalMovementController then
                allowed[obj.verticalMovementController] = true
            end
            if obj.spinner and obj.spinner.spinner then
                allowed[obj.spinner.spinner] = true
            end
        end
    end

    local function AllowHeader(header)
        ForEachHeaderDirectionalInputCandidate(header, function(candidate)
            Allow(candidate, true)
        end)
    end

    if self.confirmationMode then
        Allow(self.spinner, true)
    elseif (self._searchModeActive or self._searchHeaderActive) and SupportsVendorHeaderSearch(self) then
        Allow(self.textSearchHeaderFocus, true)
        Allow(self.headerFocus, true)
        Allow(self.textSearchHeaderControl, true)
        Allow(self.list, true)
        AllowHeader(self.headerGeneric)
        AllowHeader(self.header)
    elseif self.isInHeaderSortMode then
        Allow(self.headerGeneric and self.headerGeneric.tabBar, true)
        AllowHeader(self.headerGeneric)
        AllowHeader(self.header)
    else
        Allow(self.list, true)
    end

    local snapshot = {}
    for i, obj in ipairs(DIRECTIONAL_INPUT.inputObjects) do
        snapshot[i] = obj
    end

    local releasedCount = 0
    for _, obj in ipairs(snapshot) do
        if obj and not allowed[obj] then
            releasedCount = releasedCount + ReleaseDirectionalInputRegistrations(obj, true)
        end
    end

    if releasedCount > 0 then
        LogVendorDebug(
            "DIRECTIONAL_INPUT",
            "VendorDI",
            string.format("NormalizeDirectionalInputOwnership released=%d reason=%s", releasedCount, tostring(reason or "unknown"))
        )
    end
end

---@param reason string|nil
---@param delayMs number|nil
---@return nil
function BETTERUI.Vendor.Class:ScheduleDirectionalInputNormalization(reason, delayMs)
    if not (BETTERUI.Vendor and BETTERUI.Vendor.Tasks) then
        return
    end

    if not ShouldAllowVendorDeferredNormalization(self) then
        BETTERUI.Vendor.Tasks:Cancel("directionalInputNormalize")
        return
    end

    BETTERUI.Vendor.Tasks:Cancel("directionalInputNormalize")
    BETTERUI.Vendor.Tasks:Schedule("directionalInputNormalize", delayMs or 40, function()
        if ShouldAllowVendorDeferredNormalization(self) and self.NormalizeDirectionalInputOwnership then
            self:NormalizeDirectionalInputOwnership(string.format("%s:deferred", tostring(reason or "unknown")))
        end
    end)
end

---@return number mode Current vendor mode constant
function BETTERUI.Vendor.Class:GetCurrentMode()
    return self.currentMode or BETTERUI.Vendor.MODE.BUY
end

---@param mode number|nil
---@return nil
function BETTERUI.Vendor.Class:ApplyNativeStoreMode(mode)
    local function ReleaseNativeInputIfNeeded()
        if self.IsSceneActiveOrShowing and self:IsSceneActiveOrShowing() and self.ReleaseNativeStoreInputOwnership then
            self:ReleaseNativeStoreInputOwnership()
        end
    end

    local targetMode = ResolveNativeStoreMode(mode or self:GetCurrentMode())
    if targetMode == nil then
        return
    end

    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("ApplyNativeStoreMode requested=%s native=%s", tostring(mode or self:GetCurrentMode()), tostring(targetMode))
    )

    if type(SetStoreMode) == "function" then
        local currentMode = nil
        if type(GetStoreMode) == "function" then
            local okGetMode, modeResult = ExecuteSafely("Vendor.ApplyNativeStoreMode:GetStoreMode", GetStoreMode)
            if okGetMode then
                currentMode = modeResult
            end
        end
        if currentMode ~= targetMode then
            ExecuteSafely("Vendor.ApplyNativeStoreMode:SetStoreMode", SetStoreMode, targetMode)
        end
    end

    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if not storeManager then
        ReleaseNativeInputIfNeeded()
        return
    end

    if type(storeManager.SetMode) ~= "function" then
        ReleaseNativeInputIfNeeded()
        return
    end

    local targetVendorMode = mode or self:GetCurrentMode()
    local shouldEnsureNativeComponents = targetVendorMode == BETTERUI.Vendor.MODE.BUY
        or targetVendorMode == BETTERUI.Vendor.MODE.STABLE
    if shouldEnsureNativeComponents and BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
        BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
    end

    local activeComponents = storeManager.activeComponents
    if type(activeComponents) ~= "table" or #activeComponents == 0 then
        ReleaseNativeInputIfNeeded()
        return
    end

    local hasTargetMode = false
    for _, component in ipairs(activeComponents) do
        if component and type(component.GetStoreMode) == "function" then
            local okMode, componentMode = ExecuteSafely("Vendor.ApplyNativeStoreMode:ComponentMode", component.GetStoreMode, component)
            if okMode and componentMode == targetMode then
                hasTargetMode = true
                break
            end
        end
    end

    if not hasTargetMode then
        if shouldEnsureNativeComponents and BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
            BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
            activeComponents = storeManager.activeComponents
            if type(activeComponents) == "table" and #activeComponents > 0 then
                for _, component in ipairs(activeComponents) do
                    if component and type(component.GetStoreMode) == "function" then
                        local okMode, componentMode = ExecuteSafely("Vendor.ApplyNativeStoreMode:ComponentModeRetry", component.GetStoreMode, component)
                        if okMode and componentMode == targetMode then
                            hasTargetMode = true
                            break
                        end
                    end
                end
            end
        end

        if not hasTargetMode then
            ReleaseNativeInputIfNeeded()
            return
        end
    end

    local currentMode = nil
    if type(storeManager.GetCurrentMode) == "function" then
        local okCurrent, currentResult = ExecuteSafely("Vendor.ApplyNativeStoreMode:GetCurrentMode", storeManager.GetCurrentMode, storeManager)
        if okCurrent then
            currentMode = currentResult
        end
    end

    if currentMode ~= targetMode then
        ExecuteSafely("Vendor.ApplyNativeStoreMode:StoreManagerSetMode", storeManager.SetMode, storeManager, targetMode)
    end

    ReleaseNativeInputIfNeeded()
    LogVendorDebug(
        "DIRECTIONAL_INPUT",
        "VendorDI",
        string.format("ApplyNativeStoreMode complete store=%s currentList=%s", tostring(IsDirectionalInputListening(storeManager)), tostring(IsDirectionalInputListening(storeManager._currentList)))
    )
end

---@return nil
function BETTERUI.Vendor.Class:InitializeCategoryHeader()
    VendorModePolicy.EnsureModeCategories(self, self:GetCurrentMode())

    self.headerGeneric = (self.header and self.header:GetNamedChild("Header")) or self.header
    if not self.headerGeneric then
        return
    end

    BETTERUI.GenericHeader.Initialize(self.headerGeneric, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
end

---@param mode number
---@return table[] categories
function BETTERUI.Vendor.Class:GetModeCategories(mode)
    return VendorModePolicy.GetModeCategories(self, mode)
end

---@param mode number
---@param categories table[]|nil
---@return nil
function BETTERUI.Vendor.Class:SetModeCategories(mode, categories)
    local previousCategories, normalizedCategories, selectedIndex = VendorModePolicy.SetModeCategories(self, mode, categories)

    if mode == self:GetCurrentMode() then
        self.currentCategoryIndex = selectedIndex
        local shouldRebuildHeader = self.vendorHeaderData == nil or not AreVendorCategoriesEquivalent(previousCategories, normalizedCategories)
        if shouldRebuildHeader then
            self:RebuildCategoryHeader()
        elseif self.UpdateVendorHeaderTitle then
            self:UpdateVendorHeaderTitle()
        end
    end
end

---@return table|nil category
function BETTERUI.Vendor.Class:GetCurrentCategory()
    local mode = self:GetCurrentMode()
    return VendorModePolicy.GetCurrentCategory(self, mode)
end

---@param mode number Vendor mode constant
---@return string moduleKey PositionManager module key for this mode
local function GetVendorModeModuleKey(mode)
    local MODULES = BETTERUI.CIM.CONST.MODULES
    local descriptor = GetModeDescriptor(mode)
    if descriptor and descriptor.moduleKeyField and MODULES[descriptor.moduleKeyField] then
        return MODULES[descriptor.moduleKeyField]
    end
    return "Vendor"
end

Vendor.GetModeModuleKey = GetVendorModeModuleKey
Vendor.ResolveModePaneRole = ResolveModePaneRole

---@param self BETTERUI.Vendor.Class
---@return string categoryKey PositionManager category key for the active category
local function GetVendorCategoryKey(self)
    local category = self:GetCurrentCategory()
    if not category then return "k:all" end
    return BETTERUI.CIM.PositionManager.GetCategoryKey(category) or "k:all"
end

---@return nil
function BETTERUI.Vendor.Class:SaveListPosition()
    VendorControllerRuntime.SaveListPosition(self, {
        getModeModuleKey = GetVendorModeModuleKey,
        getCategoryKey = GetVendorCategoryKey,
    })
end

---@return nil
function BETTERUI.Vendor.Class:UpdateVendorHeaderTitle()
    local headerGeneric = self.headerGeneric
    local titleContainer = headerGeneric and headerGeneric.GetNamedChild and headerGeneric:GetNamedChild("TitleContainer")
    local titleControl = titleContainer and titleContainer.GetNamedChild and titleContainer:GetNamedChild("Title")
    if not (titleControl and self.vendorHeaderData and self.vendorHeaderData.titleText) then
        return
    end

    titleControl:SetText(self.vendorHeaderData.titleText(self.vendorHeaderData.name))

    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
end

--- Clears the text search input and normalized query state.
---@return nil
function BETTERUI.Vendor.Class:ClearSearchInput()
    self.searchQuery = ""
    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    if searchMixin and searchMixin.ClearSearchText then
        searchMixin.ClearSearchText(self)
    elseif self.ClearSearchText then
        self:ClearSearchText()
    end
end

---@return nil
function BETTERUI.Vendor.Class:ClearTextSearch()
    self:ClearSearchInput()
end

--- Checks whether search/header focus is active.
---@return boolean focused
function BETTERUI.Vendor.Class:IsHeaderFocused()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        return self.textSearchHeaderFocus:IsActive()
    end
    return self._searchModeActive == true
end

---@return boolean active
function BETTERUI.Vendor.Class:IsHeaderActive()
    return self:IsHeaderFocused()
end

--- Requests focus for the search header.
---@return nil
function BETTERUI.Vendor.Class:RequestHeaderFocus()
    if self.OnHeaderEntered then
        self:OnHeaderEntered()
    else
        self:EnterSearchMode()
    end
end

---@return nil
function BETTERUI.Vendor.Class:RequestEnterHeader()
    self:RequestHeaderFocus()
end

--- Repositions the search control under the header title.
---@return nil
function BETTERUI.Vendor.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then
        return
    end

    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.headerGeneric or self.header
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        titleContainer = anchorTarget:GetNamedChild("TitleContainer") or anchorTarget:GetNamedChild("Header")
    end

    local parentForAnchor = titleContainer or anchorTarget
    local searchConst = BETTERUI.CIM.SearchBar and BETTERUI.CIM.SearchBar.GetConstants and BETTERUI.CIM.SearchBar.GetConstants("BANKING")
    local xOffset = (searchConst and searchConst.X_OFFSET) or 55
    local yOffset = (searchConst and searchConst.Y_OFFSET) or 15
    local rightInset = (searchConst and searchConst.RIGHT_INSET) or -8

    if parentForAnchor then
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, rightInset, yOffset)
    end

    self.textSearchHeaderControl:SetHidden(false)
    if ZO_GamepadGenericHeader_SetHeaderFocusControl then
        local headerTarget
        if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.control then
            headerTarget = self.headerGeneric.tabBar.control
        else
            headerTarget = self.headerGeneric or self.header
        end
        if headerTarget then
            ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
        end
    end
end

--- Enters text-search mode and swaps active keybind groups.
---@return nil
function BETTERUI.Vendor.Class:EnterSearchMode()
    if self._searchModeActive then
        return
    end
    self._searchModeActive = true
    self._searchHeaderActive = true

    if self.coreKeybinds and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
    end

    if self.textSearchKeybindStripDescriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Activate and not self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Activate()
    end
    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(true)
    end

    if self.NormalizeDirectionalInputOwnership then
        self:NormalizeDirectionalInputOwnership("EnterSearchMode")
    end
end

--- Exits text-search mode and restores list/core keybind ownership.
---@return nil
function BETTERUI.Vendor.Class:ExitSearchMode()
    if not self._searchModeActive and not self._searchHeaderActive then
        return
    end
    self._searchModeActive = false
    self._searchHeaderActive = false

    if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate and self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Deactivate()
    end
    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(false)
    end

    if self.list and self.list.Activate and (not self.list.IsActive or not self.list:IsActive()) then
        self.list:Activate()
    end
    if self.coreKeybinds then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.coreKeybinds)
    end

    if self.EnsureHeaderKeybindsActive then
        self:EnsureHeaderKeybindsActive()
    end
    if self.EnsureListInputActive then
        self:EnsureListInputActive()
    end
    if self.NormalizeDirectionalInputOwnership then
        self:NormalizeDirectionalInputOwnership("ExitSearchMode")
    end
end

---@return nil
function BETTERUI.Vendor.Class:LeaveSearchMode()
    self:ExitSearchMode()
end

--- Handles search focus loss.
---@return nil
function BETTERUI.Vendor.Class:OnSearchFocusLost()
    self:ExitSearchMode()
end

---@return nil
function BETTERUI.Vendor.Class:ExitSearchFocus()
    self:OnSearchFocusLost()
end

--- Callback when navigating from list into header/search.
---@return nil
function BETTERUI.Vendor.Class:OnHeaderEntered()
    if self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden()) then
        self:EnterSearchMode()

        BETTERUI.Vendor.Tasks:Schedule("searchKeybindCleanup", 20, function()
            if not self._searchModeActive or not KEYBIND_STRIP then
                return
            end

            local keybindGroups = KEYBIND_STRIP.keybindButtonGroups
            if keybindGroups then
                for i = #keybindGroups, 1, -1 do
                    local group = keybindGroups[i]
                    if group and group ~= self.textSearchKeybindStripDescriptor then
                        KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                    end
                end
            end

            if self._searchModeActive and self.textSearchKeybindStripDescriptor then
                BETTERUI.Interface.EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
            end
        end)
    end
end

---@return nil
function BETTERUI.Vendor.Class:OnEnterHeader()
    self:OnHeaderEntered()
end

--- Handles text updates from search edit box callbacks.
---@param searchText string
---@return nil
function BETTERUI.Vendor.Class:OnSearchTextChanged(searchText)
    self.searchQuery = searchText
    self:RefreshList()
end

---@return nil
function BETTERUI.Vendor.Class:EnsureHeaderKeybindsActive()
    -- Guard against premature DIRECTIONAL_INPUT registration during scene
    -- transitions — matches Banking pattern (prevents joystick lock-up).
    if self.isInHeaderSortMode then
        return
    end
    if self.scene and not self.scene:IsShowing() then
        return
    end

    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end
    if not ShouldShowVendorHeaderTabBar(self._vendorHeaderEntryCount) then
        ReleaseHeaderDirectionalInput(self.headerGeneric, "Vendor.EnsureHeaderKeybindsActive:HeaderGenericHidden")
        ReleaseHeaderDirectionalInput(self.header, "Vendor.EnsureHeaderKeybindsActive:HeaderHidden")
        SetTabBarVisualActive(tabBar, false)
        return
    end

    if self.DetachUnexpectedSearchHeaderFocus then
        self:DetachUnexpectedSearchHeaderFocus("EnsureHeaderKeybindsActive")
    end

    -- Vendor uses core shoulder keybinds for tab cycling; do not register the
    -- header tab bar on DIRECTIONAL_INPUT or it can steal focus from the item list.
    ReleaseHeaderDirectionalInput(self.headerGeneric, "Vendor.EnsureHeaderKeybindsActive:HeaderGeneric")
    ReleaseHeaderDirectionalInput(self.header, "Vendor.EnsureHeaderKeybindsActive:Header")
    if tabBar.keybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(tabBar.keybindStripDescriptor)
    end
    SetTabBarVisualActive(tabBar, true)
end

---@return nil
function BETTERUI.Vendor.Class:EnsureListInputActive()
    -- Only activate list input when the scene is actually showing.
    if self.scene and not self.scene:IsShowing() then
        return
    end

    local list = self.list
    if not list then
        return
    end

    if self.DetachUnexpectedSearchHeaderFocus then
        self:DetachUnexpectedSearchHeaderFocus("EnsureListInputActive")
    end

    local listRegistrationCount = CountDirectionalInputRegistrations(list)
    local controllerRegistrationCount = CountDirectionalInputRegistrations(list.movementController)
    local listListening = listRegistrationCount > 0
    local controllerListening = controllerRegistrationCount > 0
    local shouldResetListInput = listRegistrationCount > 1 or controllerRegistrationCount > 1
        or (controllerListening and not listListening)
    local isListActive = not list.IsActive or list:IsActive()

    if shouldResetListInput then
        local releasedCount = ReleaseDirectionalInputRegistrations(list, true)
        if releasedCount > 0 then
            LogVendorDebug(
                "DIRECTIONAL_INPUT",
                "VendorDI",
                string.format(
                    "EnsureListInputActive cleared stale vendor list registrations=%d list=%d controller=%d",
                    releasedCount,
                    listRegistrationCount,
                    controllerRegistrationCount
                )
            )
        end

        if list.SetActive then
            list:SetActive(false)
        elseif list.Deactivate and (not list.IsActive or list:IsActive()) then
            list:Deactivate()
        end

        listListening = false
        isListActive = false
    end

    local shouldActivateList = list.Activate and (shouldResetListInput or not isListActive)
    if shouldActivateList then
        -- ZO_ParametricScrollList:Activate() already registers the list when
        -- directionalInputEnabled is true. Setting it via the public mutator here
        -- would register the same list twice and accelerate scrolling.
        list.directionalInputEnabled = true
    elseif list.SetDirectionalInputEnabled and not listListening then
        list:SetDirectionalInputEnabled(true)
    end

    if shouldActivateList then
        LogVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "EnsureListInputActive activating vendor list")
        list:Activate()
    end

    if self.NormalizeDirectionalInputOwnership and not self.confirmationMode
        and not self._searchModeActive and not self._searchHeaderActive then
        self:NormalizeDirectionalInputOwnership("EnsureListInputActive")
        if self.ScheduleDirectionalInputNormalization then
            self:ScheduleDirectionalInputNormalization("EnsureListInputActive")
        end
    end
end

---@return nil
function BETTERUI.Vendor.Class:InitializeScrollIndicator()
    if not (self.list and self.list.control and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator) then
        return
    end

    BETTERUI.CIM.ScrollIndicator.Ensure(self.list.control, {
        offsetX = 25,
        offsetTopY = -5,
        offsetBottomY = -10,
    })
    BETTERUI.CIM.ScrollIndicator.BindListObject(self.list.control, self.list)
end

---@return nil
function BETTERUI.Vendor.Class:ApplyListLayoutTuning()
    local list = self.list
    if not list then
        return
    end

    list.maxOffset = rawget(_G, "BETTERUI_BANK_LIST_MAX_OFFSET") or 30

    local headerPaddingScale = rawget(_G, "BETTERUI_BANK_HEADER_PADDING_SCALE") or 0.75
    if list.SetHeaderPadding and GAMEPAD_HEADER_DEFAULT_PADDING and GAMEPAD_HEADER_SELECTED_PADDING then
        list:SetHeaderPadding(
            GAMEPAD_HEADER_DEFAULT_PADDING * headerPaddingScale,
            GAMEPAD_HEADER_SELECTED_PADDING * headerPaddingScale
        )
    end
    if list.SetUniversalPostPadding and GAMEPAD_DEFAULT_POST_PADDING then
        list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * headerPaddingScale)
    end

    if list.SetFixedCenterOffset then
        -- Align selected row with the tooltip arrow like Inventory/Banking.
        list:SetFixedCenterOffset(-50)
    end
end

---@param list table|nil
---@return nil
function BETTERUI.Vendor.Class:UpdateScrollIndicator(list)
    local targetList = list or self.list
    local listControl = targetList and targetList.control
    if not (listControl and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator) then
        return
    end

    local currentIndex = targetList.targetSelectedIndex
        or (targetList.GetSelectedIndex and targetList:GetSelectedIndex())
        or 1
    local totalItems = (targetList.GetNumItems and targetList:GetNumItems())
        or (targetList.dataList and #targetList.dataList)
        or 0
    local visibleItems = BETTERUI.CIM.CONST.UI.BANKING_VISIBLE_ITEMS or 10

    BETTERUI.CIM.ScrollIndicator.Update(listControl, currentIndex, totalItems, visibleItems)
end

---@return nil
function BETTERUI.Vendor.Class:DeactivateListInput()
    local list = self.list
    if not list then
        return
    end
    if list.SetDirectionalInputEnabled then
        list:SetDirectionalInputEnabled(false)
    end
    if list.Deactivate and (not list.IsActive or list:IsActive()) then
        list:Deactivate()
    end
    ReleaseDirectionalInputRegistrations(list, true)
end

---@return nil
function BETTERUI.Vendor.Class:EnsureColumnHeadersVisible()
    if not (self.header and self.header.columns) then
        return
    end

    local anchorTarget = (self.header and self.header:GetNamedChild("HeaderTabBar"))
        or (self.headerGeneric and self.headerGeneric:GetNamedChild("TabBar"))
        or (self.header and self.header:GetNamedChild("HeaderColumnBar"))

    for _, label in ipairs(self.header.columns) do
        if label then
            if anchorTarget then
                local idx = label.columnIndex
                local xOffset = ResolveHeaderColumnOffset(idx)
                if xOffset then
                    label:ClearAnchors()
                    label:SetAnchor(LEFT, anchorTarget, BOTTOMLEFT, xOffset, BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET)
                end
            end
            label:SetHidden(false)
            label:SetAlpha(1)
            if label.SetDrawLayer then
                label:SetDrawLayer(DL_OVERLAY)
            end
            if label.SetDrawTier then
                label:SetDrawTier(DT_HIGH)
            end
            if label.SetDrawLevel then
                label:SetDrawLevel(10)
            end
        end
    end
end

---@return nil
function BETTERUI.Vendor.Class:DeactivateHeaderKeybinds()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end
    SetTabBarVisualActive(tabBar, false)
    if tabBar.Deactivate then
        tabBar:Deactivate()
    end
    ReleaseDirectionalInputRegistrations(tabBar, true)
    if tabBar.keybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(tabBar.keybindStripDescriptor)
    end
end

---@return nil
function BETTERUI.Vendor.Class:RefreshVendorActionKeybinds()
    if not (KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups) then
        return
    end
    if self.IsSceneShowing and not self:IsSceneShowing() then
        return
    end
    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
end

---@return nil
function BETTERUI.Vendor.Class:RefreshVendorHeaderCarouselLayout()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end

    tabBar.carouselMode = (not BETTERUI.Vendor.GetSetting) or (BETTERUI.Vendor.GetSetting("enableCarousel") ~= false)

    if tabBar.UpdateAnchors then
        local selectedIndex = tabBar.targetSelectedIndex or tabBar.selectedIndex or 1
        tabBar:UpdateAnchors(selectedIndex, true, false, false)
    end
end

---@return nil
function BETTERUI.Vendor.Class:RebuildCategoryHeader()
    local headerGeneric = self.headerGeneric
    if not headerGeneric then
        return
    end

    local headerNavigation = BETTERUI.CIM and BETTERUI.CIM.HeaderNavigation or nil
    local navigationState = BETTERUI.CIM and BETTERUI.CIM.NavigationState or nil
    local headerModel = BuildVendorHeaderModel(self)
    ApplyVendorHeaderModelState(self, headerModel)
    local onSelectedChanged = CreateVendorHeaderSelectionHandler(self, headerModel, headerNavigation, navigationState)
    self.vendorHeaderData = BuildVendorHeaderData(self, headerModel, onSelectedChanged)
    RenderVendorHeader(self, headerGeneric, headerModel)
    RestoreVendorHeaderInteraction(self, headerGeneric, headerModel, headerNavigation)
end

---@return nil
function BETTERUI.Vendor.Class:ToggleBuySellMode()
    VendorControllerRuntime.ToggleBuySellMode(self, {
        getToggleModePair = function()
            if BETTERUI.Vendor.GetToggleModePair then
                return BETTERUI.Vendor.GetToggleModePair()
            end
            return nil, nil
        end,
        isStableInteractionActive = IsStableInteractionActive,
    })
end

---@param mode number Vendor mode constant from BETTERUI.Vendor.MODE
function BETTERUI.Vendor.Class:SetMode(mode)
    VendorControllerRuntime.SetMode(self, mode)
end

---@return VendorComponent|nil component The currently active component, or nil
function BETTERUI.Vendor.Class:GetActiveComponent()
    if not self.components then return nil end
    return self.components[self:GetCurrentMode()]
end

---@param mode number Vendor mode constant from BETTERUI.Vendor.MODE
---@param component VendorComponent Component implementing Activate/Deactivate/BuildList
function BETTERUI.Vendor.Class:RegisterComponent(mode, component)
    if not mode or not component then return end
    self.components = self.components or {}
    self.components[mode] = component
end

function BETTERUI.Vendor.Class:ApplySortToList()
    VendorControllerRuntime.ApplySortToList(self)
end

---@return nil
function BETTERUI.Vendor.Class:RefreshList()
    VendorControllerRuntime.RefreshList(self, {
        getModeModuleKey = GetVendorModeModuleKey,
        getCategoryKey = GetVendorCategoryKey,
        resolveModeEmptyStateText = ResolveModeEmptyStateText,
    })
end

---@param selectedData table|nil
---@return boolean
function BETTERUI.Vendor.Class:CanPreviewStableStoreEntry(selectedData)
    return VendorPresentationRuntime.CanPreviewStableStoreEntry(self, selectedData)
end

---@param shouldActivateVendorBlur boolean
---@return nil
function BETTERUI.Vendor.Class:SetVendorPreviewBlurActive(shouldActivateVendorBlur)
    VendorPresentationRuntime.SetVendorPreviewBlurActive(self, shouldActivateVendorBlur)
end

---@param hidden boolean
---@return nil
function BETTERUI.Vendor.Class:SetVendorStorePreviewUiHidden(hidden)
    VendorPresentationRuntime.SetVendorStorePreviewUiHidden(self, hidden)
end

---@param selectedData table|nil
---@return boolean
function BETTERUI.Vendor.Class:CanPreviewVendorStoreEntry(selectedData)
    return VendorPresentationRuntime.CanPreviewVendorStoreEntry(self, selectedData, IsStableInteractionActive)
end

---@return nil
function BETTERUI.Vendor.Class:DisableVendorStorePreviewMode()
    VendorPresentationRuntime.DisableVendorStorePreviewMode(self)
end

---@param selectedData table|nil
---@return nil
function BETTERUI.Vendor.Class:UpdateVendorStorePreview(selectedData)
    VendorPresentationRuntime.UpdateVendorStorePreview(self, selectedData, IsStableInteractionActive)
end

---@return nil
function BETTERUI.Vendor.Class:ToggleVendorStorePreviewMode()
    VendorPresentationRuntime.ToggleVendorStorePreviewMode(self, IsStableInteractionActive)
end

---@param hidden boolean
---@return nil
function BETTERUI.Vendor.Class:SetStablePreviewUiHidden(hidden)
    VendorPresentationRuntime.SetStablePreviewUiHidden(self, hidden)
end

---@return nil
function BETTERUI.Vendor.Class:DisableStablePreviewMode()
    VendorPresentationRuntime.DisableStablePreviewMode(self)
end

---@return nil
function BETTERUI.Vendor.Class:ToggleStablePreviewMode()
    VendorPresentationRuntime.ToggleStablePreviewMode(self, IsStableInteractionActive)
end

---@return nil
function BETTERUI.Vendor.Class:UpdateStablePreview()
    VendorPresentationRuntime.UpdateStablePreview(self, IsStableInteractionActive)
end

---@param _list table
---@param selectedData table|nil
---@return nil
function BETTERUI.Vendor.Class:OnItemSelectedChange(_list, selectedData)
    local selectionRuntime = assert(BETTERUI.Vendor.SelectionRuntime, "Vendor selection runtime must load before selection updates")
    selectionRuntime.HandleSelection(self, selectedData, IsStableInteractionActive())
end

---@return nil
function BETTERUI.Vendor.Class:SuppressListUpdates()
    self._suppressListUpdates = true
    self._isDirty = false
end

---@return nil
function BETTERUI.Vendor.Class:FlushListUpdates()
    self._suppressListUpdates = false
    if self._isDirty then
        self:RefreshList()
    end
end

---@return boolean isFence True if current mode is a fence mode
function BETTERUI.Vendor.Class:IsFenceMode()
    local mode = self:GetCurrentMode()
    return mode == BETTERUI.Vendor.MODE.FENCE_SELL
        or mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER
end

---@return number currencyType1 Primary currency type
---@return number|nil currencyType2 Secondary currency type, or nil
function BETTERUI.Vendor.Class:GetStoreCurrencyTypes()
    if GetStoreUsedCurrencyTypes then
        return GetStoreUsedCurrencyTypes()
    end
    return CURT_MONEY, nil
end

---@param cost number|nil Item cost to check
---@param currencyType number|nil Currency type (defaults to CURT_MONEY)
---@return boolean canAfford True if player can afford the cost
function BETTERUI.Vendor.Class:CanAfford(cost, currencyType)
    if not cost or cost <= 0 then return true end
    currencyType = currencyType or CURT_MONEY
    local current = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER) or 0
    return current >= cost
end

---@return boolean hasSpace True if backpack has at least one free slot
function BETTERUI.Vendor.Class:HasInventorySpace()
    local numFree = GetNumBagFreeSlots(BAG_BACKPACK)
    return numFree and numFree > 0
end


---@return nil
function BETTERUI.Vendor.Class:InitVendorFooter()
    VendorPresentationRuntime.InitVendorFooter(self, IsStableInteractionActive)
end

---@return nil
function BETTERUI.Vendor.Class:RefreshVendorFooter()
    VendorPresentationRuntime.RefreshVendorFooter(self, {
        isStableInteractionActive = IsStableInteractionActive,
        isFenceInteraction = function()
            return BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction()
        end,
        resolveModePaneRole = ResolveModePaneRole,
        resolveStableInteractionIcon = ResolveStableInteractionIcon,
    })
end
