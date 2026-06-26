--[[
File: Modules/Vendor/Core/Lifecycle/VendorControllerRuntime.lua
Purpose: Own vendor controller transitions, list refresh, and native-store recovery so VendorClass stays coordinator-focused.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.ControllerRuntime = Vendor.ControllerRuntime or {}
local ControllerRuntime = Vendor.ControllerRuntime

local MODE = assert(Vendor.MODE, "Vendor mode constants must load before controller runtime")
local BUY_EMPTY_STORE_RETRY_LIMIT = 8

local VENDOR_SORT_COMPARATORS = {
    name = function(a, b)
        local nameA = tostring((a.dataSource and a.dataSource.name) or a.name or "")
        local nameB = tostring((b.dataSource and b.dataSource.name) or b.name or "")
        return nameA < nameB
    end,
    type = function(a, b)
        local typeA = tostring((a.dataSource and a.dataSource.bestItemTypeName) or "")
        local typeB = tostring((b.dataSource and b.dataSource.bestItemTypeName) or "")
        if typeA == typeB then
            return VENDOR_SORT_COMPARATORS.name(a, b)
        end
        return typeA < typeB
    end,
    trait = function(a, b)
        local traitA = tostring((a.dataSource and a.dataSource.traitName) or "")
        local traitB = tostring((b.dataSource and b.dataSource.traitName) or "")
        local blankA = traitA == "" and 1 or 0
        local blankB = traitB == "" and 1 or 0
        if blankA ~= blankB then
            return blankA < blankB
        end
        if traitA == traitB then
            return VENDOR_SORT_COMPARATORS.name(a, b)
        end
        return traitA < traitB
    end,
    stat = function(a, b)
        local statA = (a.dataSource and a.dataSource.statValue) or ""
        local statB = (b.dataSource and b.dataSource.statValue) or ""
        local numA = tonumber(statA)
        local numB = tonumber(statB)
        if numA and numB then
            if numA ~= numB then
                return numA > numB
            end
        elseif statA ~= statB then
            return tostring(statA) < tostring(statB)
        end
        return VENDOR_SORT_COMPARATORS.name(a, b)
    end,
    value = function(a, b)
        local valA = (a.dataSource and (a.dataSource.price or a.dataSource.repairCost or a.dataSource.launderCost or a.dataSource.stackSellPrice or a.dataSource.sellPrice or 0)) or 0
        local valB = (b.dataSource and (b.dataSource.price or b.dataSource.repairCost or b.dataSource.launderCost or b.dataSource.stackSellPrice or b.dataSource.sellPrice or 0)) or 0
        if valA ~= valB then
            return valA > valB
        end
        return VENDOR_SORT_COMPARATORS.name(a, b)
    end,
}

local function GetVendorModeName(mode)
    if Vendor.ResolveModeName then
        local ok, name = pcall(Vendor.ResolveModeName, mode)
        if ok and name ~= nil then
            return tostring(name)
        end
    end
    return tostring(mode or "<none>")
end

local function GetVendorComponentName(component)
    if type(component) ~= "table" then
        return nil
    end
    return component.traceName or component.name or component.id or component.label
end

local function CountVendorList(instance)
    local dataList = instance and instance.list and instance.list.dataList
    return type(dataList) == "table" and #dataList or nil
end

local function DescribeVendorSelection(instance)
    local L = BETTERUI.Log
    local list = instance and instance.list
    if not list then
        return nil
    end
    if L and L.DescribeListSelection then
        local ok, description = pcall(L.DescribeListSelection, list, "selection")
        if ok then
            return description
        end
    end
    local selectedData = nil
    if list.GetTargetData then
        selectedData = list:GetTargetData()
    elseif list.GetSelectedData then
        selectedData = list:GetSelectedData()
    end
    local dataSource = selectedData and (selectedData.dataSource or selectedData) or nil
    if L and L.DescribeItem and dataSource then
        local ok, description = pcall(L.DescribeItem, dataSource, "selection")
        if ok then
            return description
        end
    end
    return dataSource and (dataSource.name or dataSource.itemLink or tostring(dataSource.bagId or "")) or nil
end

local function TraceVendor(category, event, phase, instance, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then
        return
    end
    data = data or {}
    local mode = data.mode or (instance and instance.GetCurrentMode and instance:GetCurrentMode()) or nil
    data.module = data.module or "Vendor"
    data.scene = data.scene or BETTERUI_VENDOR_SCENE_NAME
    data.feature = data.feature or "vendor-controller"
    data.fn = data.fn or "Vendor.ControllerRuntime"
    data["function"] = data["function"] or data.fn
    data.mode = mode
    data.modeName = data.modeName or GetVendorModeName(mode)
    data.rowCount = data.rowCount or CountVendorList(instance)
    data.selection = data.selection or DescribeVendorSelection(instance)
    L.TraceEvent(category or L.CATEGORY.ACTION, event, phase, data)
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function ControllerRuntime.SaveListPosition(instance, deps)
    local currentMode = instance:GetCurrentMode()
    if not currentMode or not instance.list then
        return
    end

    local moduleKey = deps.getModeModuleKey(currentMode)
    local categoryKey = deps.getCategoryKey(instance)
    BETTERUI.CIM.PositionManager.SavePosition(moduleKey, categoryKey, instance.list)
end

---@param instance BETTERUI.Vendor.Class
---@return nil
function ControllerRuntime.ApplySortToList(instance)
    if not instance.list or not instance.list.dataList then
        return
    end

    local sortKey = "name"
    local sortOrder = ZO_SORT_ORDER_UP
    if instance.sortController and instance.sortController.GetActiveSortColumn then
        local column, direction = instance.sortController:GetActiveSortColumn()
        if column and direction and direction ~= BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.NONE then
            sortKey = column.key or sortKey
            if direction == BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.DESCENDING then
                sortOrder = ZO_SORT_ORDER_DOWN
            end
        end
    end

    local comparator = VENDOR_SORT_COMPARATORS[sortKey] or VENDOR_SORT_COMPARATORS.name
    if sortOrder == ZO_SORT_ORDER_DOWN then
        local baseComparator = comparator
        comparator = function(a, b)
            return baseComparator(b, a)
        end
    end
    table.sort(instance.list.dataList, comparator)
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function ControllerRuntime.ReleaseNativeStoreInputOwnership(instance, deps)
    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if not storeManager then
        return
    end

    deps.releaseSpinnerDirectionalInput(storeManager.spinner)

    deps.logVendorDebug(
        "DIRECTIONAL_INPUT",
        "VendorDI",
        string.format(
            "ReleaseNativeStoreInputOwnership store=%s headerFocus=%s currentList=%s",
            tostring(deps.isDirectionalInputListening(storeManager)),
            tostring(deps.isDirectionalInputListening(storeManager.headerFocus)),
            tostring(deps.isDirectionalInputListening(storeManager._currentList))
        )
    )

    if type(storeManager.DeactivateActiveComponent) == "function" then
        deps.executeSafely(
            "Vendor.ReleaseNativeStoreInputOwnership:DeactivateActiveComponent",
            storeManager.DeactivateActiveComponent,
            storeManager,
            false
        )
    end

    if type(storeManager.DeactivateTextSearch) == "function" then
        deps.executeSafely("Vendor.ReleaseNativeStoreInputOwnership:DeactivateTextSearch", storeManager.DeactivateTextSearch, storeManager)
    end

    local headerFocus = storeManager.headerFocus
    if headerFocus then
        if headerFocus.Deactivate then
            deps.executeSafely("Vendor.ReleaseNativeStoreInputOwnership:HeaderFocusDeactivate", headerFocus.Deactivate, headerFocus)
        end
        deps.releaseDirectionalInputRegistrations(headerFocus)
    end

    if type(storeManager.RemoveListKeybinds) == "function" then
        deps.executeSafely("Vendor.ReleaseNativeStoreInputOwnership:RemoveListKeybinds", storeManager.RemoveListKeybinds, storeManager)
    end

    if storeManager.keybindStripDescriptor and KEYBIND_STRIP then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(storeManager.keybindStripDescriptor)
    end

    if type(storeManager.Deactivate) == "function" then
        deps.executeSafely("Vendor.ReleaseNativeStoreInputOwnership:Deactivate", storeManager.Deactivate, storeManager)
    end

    deps.releaseDirectionalInputRegistrations(storeManager)

    local nativeHeader = storeManager.header
    if nativeHeader then
        deps.releaseHeaderDirectionalInput(nativeHeader, "Vendor.ReleaseNativeStoreInputOwnership:NativeHeader")

        local nativeTabBar = nativeHeader.tabBar
        if nativeTabBar then
            if nativeTabBar.Deactivate then
                nativeTabBar:Deactivate()
            end
            deps.releaseDirectionalInputRegistrations(nativeTabBar)
        end
    end

    if storeManager._currentList then
        if storeManager._currentList.Deactivate then
            storeManager._currentList:Deactivate()
        end
        if storeManager._currentList.SetDirectionalInputEnabled then
            storeManager._currentList:SetDirectionalInputEnabled(false)
        end
        deps.releaseDirectionalInputRegistrations(storeManager._currentList, true)
    end

    local activeComponents = storeManager.activeComponents
    if type(activeComponents) == "table" then
        for _, component in ipairs(activeComponents) do
            if component and component.list then
                if component.list.SetDirectionalInputEnabled then
                    component.list:SetDirectionalInputEnabled(false)
                end
                deps.releaseDirectionalInputRegistrations(component.list, true)
            end
        end
    end
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function ControllerRuntime.ForceReleaseDirectionalInput(instance, deps)
    if not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT.Deactivate) then
        return
    end

    deps.logVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "ForceReleaseDirectionalInput invoked")

    local function SafeDeactivate(object, includeMovementController, disableDirectionalInput)
        if not object then
            return
        end
        if disableDirectionalInput and object.SetDirectionalInputEnabled then
            object:SetDirectionalInputEnabled(false)
        end
        if object.Deactivate then
            if not object.IsActive or object:IsActive() or deps.isDirectionalInputListening(object)
                or (includeMovementController and deps.isDirectionalInputListening(object.movementController)) then
                object:Deactivate()
            end
        end
        deps.releaseDirectionalInputRegistrations(object, includeMovementController)
    end

    SafeDeactivate(instance, true)
    SafeDeactivate(instance.list, true, true)
    deps.releaseSpinnerDirectionalInput(instance.spinner)
    deps.releaseHeaderDirectionalInput(instance.headerGeneric, "Vendor.ForceReleaseDirectionalInput:HeaderGeneric")
    deps.releaseHeaderDirectionalInput(instance.header, "Vendor.ForceReleaseDirectionalInput:Header")
    SafeDeactivate(instance.textSearchHeaderFocus, true)
    SafeDeactivate(instance.headerFocus, true)
    SafeDeactivate(instance.textSearchHeaderControl, true)
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function ControllerRuntime.ToggleBuySellMode(instance, deps)
    deps = deps or {}

    local firstMode, secondMode = nil, nil
    if deps.getToggleModePair then
        firstMode, secondMode = deps.getToggleModePair()
    end
    if not firstMode or not secondMode then
        return
    end

    local mode = instance:GetCurrentMode()
    if deps.isStableInteractionActive and deps.isStableInteractionActive()
        and firstMode == MODE.BUY and secondMode == MODE.STABLE then
        if mode == secondMode then
            instance:SetMode(firstMode)
        else
            instance:SetMode(secondMode)
        end
        return
    end

    if mode == firstMode then
        instance:SetMode(secondMode)
    elseif mode == secondMode then
        instance:SetMode(firstMode)
    else
        instance:SetMode(firstMode)
    end
end

---@param instance BETTERUI.Vendor.Class
---@param mode number
---@return nil
function ControllerRuntime.SetMode(instance, mode)
    local L = BETTERUI.Log
    local oldMode = instance and instance.currentMode or nil
    if not mode then
        TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.mode", "skipped", instance, {
            targetMode = mode,
            oldMode = oldMode,
            reason = "missingMode",
        })
        return
    end
    if oldMode == mode then
        TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.mode", "skipped", instance, {
            targetMode = mode,
            oldMode = oldMode,
            reason = "sameMode",
        })
        return
    end

    TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.mode", "begin", instance, {
        targetMode = mode,
        targetModeName = GetVendorModeName(mode),
        oldMode = oldMode,
        oldModeName = GetVendorModeName(oldMode),
    })

    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "vendor mode set", {
            mode = mode,
            oldMode = oldMode
        })
    end

    local headerNavigation = BETTERUI.CIM and BETTERUI.CIM.HeaderNavigation or nil
    local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(instance) or nil
    if state then
        state.justToggledMode = true
    end

    instance:SaveListPosition()

    local oldComponent = instance:GetActiveComponent()
    if oldComponent and oldComponent.Deactivate then
        TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.component", "deactivate_before", instance, {
            component = GetVendorComponentName(oldComponent),
            targetMode = mode,
            oldMode = oldMode,
        })
        oldComponent:Deactivate(instance)
        TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.component", "deactivate_after", instance, {
            component = GetVendorComponentName(oldComponent),
            targetMode = mode,
            oldMode = oldMode,
        })
    end

    instance.currentMode = mode
    TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.mode", "applied", instance, {
        targetMode = mode,
        oldMode = oldMode,
    })

    if Vendor.multiSelectManager then
        Vendor.multiSelectManager:ExitSelectionMode()
    end

    if mode ~= MODE.BUY and instance.DisableStablePreviewMode then
        instance:DisableStablePreviewMode()
    end
    if mode ~= MODE.BUY and instance.DisableVendorStorePreviewMode then
        instance:DisableVendorStorePreviewMode()
    end

    instance:ApplyNativeStoreMode(mode)

    local newComponent = instance:GetActiveComponent()
    if newComponent and newComponent.Activate then
        TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.component", "activate_before", instance, {
            component = GetVendorComponentName(newComponent),
            oldMode = oldMode,
        })
        newComponent:Activate(instance)
        TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.component", "activate_after", instance, {
            component = GetVendorComponentName(newComponent),
            oldMode = oldMode,
        })
    end

    if instance:IsSceneShowing() then
        TraceVendor(L and L.CATEGORY.ACTION, "vendor.keybinds", "refresh_before", instance, {
            keybinds = L and L.DescribeKeybindDescriptors and L.DescribeKeybindDescriptors(instance.coreKeybinds, "core") or nil,
            reason = "modeChanged",
        })
        local refreshed = BETTERUI.Interface and BETTERUI.Interface.UpdateCurrentKeybindGroups
            and BETTERUI.Interface.UpdateCurrentKeybindGroups()
            or false
        TraceVendor(L and L.CATEGORY.ACTION, "vendor.keybinds", "refresh_after", instance, {
            keybinds = L and L.DescribeKeybindDescriptors and L.DescribeKeybindDescriptors(instance.coreKeybinds, "core") or nil,
            refreshed = refreshed == true,
            reason = "modeChanged",
        })
    end

    instance:RebuildCategoryHeader()
    instance:RefreshVendorFooter()
    TraceVendor(L and L.CATEGORY.LIFECYCLE, "vendor.mode", "end", instance, {
        targetMode = mode,
        oldMode = oldMode,
    })
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function ControllerRuntime.RefreshList(instance, deps)
    local L = BETTERUI.Log
    if instance._suppressListUpdates then
        instance._isDirty = true
        TraceVendor(L and L.CATEGORY.LIST, "vendor.list_refresh", "skipped", instance, {
            reason = "suppressed",
            isDirty = true,
        })
        return
    end

    if not instance.list then
        TraceVendor(L and L.CATEGORY.LIST, "vendor.list_refresh", "skipped", instance, {
            reason = "missingList",
        })
        return
    end

    TraceVendor(L and L.CATEGORY.LIST, "vendor.list_refresh", "begin", instance, {
        isDirty = instance._isDirty == true,
        searchQuery = instance.searchQuery,
    })

    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIST, "vendor list refreshed", {
            mode = instance:GetCurrentMode(),
            isDirty = instance._isDirty == true
        })
    end

    instance:ApplyListLayoutTuning()

    local component = instance:GetActiveComponent()
    if component and component.GetCategories then
        instance:SetModeCategories(instance:GetCurrentMode(), component:GetCategories(instance))
    else
        instance:SetModeCategories(instance:GetCurrentMode(), nil)
    end

    instance.list:Clear()
    TraceVendor(L and L.CATEGORY.LIST, "vendor.list_refresh", "cleared", instance, {
        component = GetVendorComponentName(component),
    })

    if component and component.BuildList then
        TraceVendor(L and L.CATEGORY.LIST, "vendor.list_build", "before", instance, {
            component = GetVendorComponentName(component),
        })
        component:BuildList(instance)
        TraceVendor(L and L.CATEGORY.LIST, "vendor.list_build", "after", instance, {
            component = GetVendorComponentName(component),
            rowCount = CountVendorList(instance),
        })
    else
        TraceVendor(L and L.CATEGORY.LIST, "vendor.list_build", "skipped", instance, {
            reason = "missingComponentBuildList",
            component = GetVendorComponentName(component),
        })
    end

    local currentMode = instance:GetCurrentMode()
    local hasSearchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(instance.searchQuery) ~= nil
    if instance.list.SetNoItemText then
        local modeEmptyStateText = deps.resolveModeEmptyStateText(currentMode)
        if hasSearchQuery then
            instance.list:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_SEARCH_NO_RESULTS")))
        elseif modeEmptyStateText then
            instance.list:SetNoItemText(modeEmptyStateText)
        else
            instance.list:SetNoItemText(GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_EMPTY")))
        end
    end

    local sortBeforeSample = {}
    if instance.list and instance.list.dataList then
        for i = 1, math.min(3, #instance.list.dataList) do
            local ds = instance.list.dataList[i] and (instance.list.dataList[i].dataSource or instance.list.dataList[i]) or nil
            sortBeforeSample[i] = ds and {
                name = ds.name,
                itemLink = ds.itemLink,
                entryIndex = ds.entryIndex,
                bagId = ds.bagId,
                slotIndex = ds.slotIndex,
            } or nil
        end
    end
    instance:ApplySortToList()
    local sortAfterSample = {}
    if instance.list and instance.list.dataList then
        for i = 1, math.min(3, #instance.list.dataList) do
            local ds = instance.list.dataList[i] and (instance.list.dataList[i].dataSource or instance.list.dataList[i]) or nil
            sortAfterSample[i] = ds and {
                name = ds.name,
                itemLink = ds.itemLink,
                entryIndex = ds.entryIndex,
                bagId = ds.bagId,
                slotIndex = ds.slotIndex,
            } or nil
        end
    end
    TraceVendor(L and L.CATEGORY.LIST, "vendor.list_sort", "applied", instance, {
        rowCount = CountVendorList(instance),
        mode = currentMode,
        sortKey = instance.sortKey or instance._sortKey,
        sortOrder = instance.sortOrder or instance._sortOrder or instance.sortDirection,
        before = sortBeforeSample,
        after = sortAfterSample,
    })
    instance.list:Commit()
    instance._isDirty = false
    TraceVendor(L and L.CATEGORY.LIST, "vendor.list_refresh", "committed", instance, {
        rowCount = CountVendorList(instance),
    })

    if currentMode and instance.list and instance.list.dataList and #instance.list.dataList > 0 then
        local moduleKey = deps.getModeModuleKey(currentMode)
        local categoryKey = deps.getCategoryKey(instance)
        local targetIndex = BETTERUI.CIM.PositionManager.RestorePosition(moduleKey, categoryKey, instance.list, instance.list.dataList)
        if instance.list.SetSelectedIndexWithoutAnimation then
            instance.list:SetSelectedIndexWithoutAnimation(targetIndex, true, false)
        elseif instance.list.SetSelectedIndex then
            instance.list:SetSelectedIndex(targetIndex)
        end
        TraceVendor(L and L.CATEGORY.LIST, "vendor.selection", "restored", instance, {
            moduleKey = moduleKey,
            categoryKey = categoryKey,
            targetIndex = targetIndex,
        })
    else
        TraceVendor(L and L.CATEGORY.LIST, "vendor.selection", "skipped", instance, {
            reason = "emptyList",
        })
    end

    if Vendor.multiSelectManager then
        Vendor.multiSelectManager:RefreshSelections()
    end

    instance:EnsureColumnHeadersVisible()
    if instance:IsSceneShowing() then
        if not instance._searchModeActive and not instance._searchHeaderActive then
            instance:EnsureListInputActive()
        end
        instance:OnItemSelectedChange(instance.list, instance.list:GetTargetData())
        TraceVendor(L and L.CATEGORY.ACTION, "vendor.keybinds", "refresh_before", instance, {
            keybinds = L and L.DescribeKeybindDescriptors and L.DescribeKeybindDescriptors(instance.coreKeybinds, "core") or nil,
            reason = "listRefresh",
        })
        local updateCurrentKeybinds = BETTERUI.Interface and BETTERUI.Interface.UpdateCurrentKeybindGroups
        local refreshed = updateCurrentKeybinds and updateCurrentKeybinds() or false
        TraceVendor(L and L.CATEGORY.ACTION, "vendor.keybinds", "refresh_after", instance, {
            keybinds = L and L.DescribeKeybindDescriptors and L.DescribeKeybindDescriptors(instance.coreKeybinds, "core") or nil,
            refreshed = refreshed == true,
            reason = "listRefresh",
        })
    end
    instance:UpdateScrollIndicator(instance.list)

    if instance:GetCurrentMode() == MODE.BUY then
        local entryCount = (instance.list.dataList and #instance.list.dataList) or 0
        -- Short-circuit: when the store still reports zero items after at
        -- least one retry, further retries cannot produce entries. The first
        -- pass always retries because some stores misreport 0 while the
        -- index-probe fallback can still find entries.
        local storeReportsEmpty = GetNumStoreItems ~= nil and (GetNumStoreItems() or 0) == 0
        -- An empty list caused by an active search query or a non-default
        -- category filter is the expected result of user filtering, not a
        -- native-store race; retrying would never repopulate it and just churns
        -- the store rebuild, so skip the retry in that case.
        local hasActiveSearch = false
        if Vendor.NormalizeSearchQuery then
            hasActiveSearch = Vendor.NormalizeSearchQuery(instance.searchQuery) ~= nil
        else
            hasActiveSearch = instance.searchQuery ~= nil and instance.searchQuery ~= ""
        end
        local activeCategory = instance.GetCurrentCategory and instance:GetCurrentCategory() or nil
        local hasNonDefaultCategory = activeCategory ~= nil and activeCategory.key ~= nil and activeCategory.key ~= "all"
        if entryCount == 0 and storeReportsEmpty and (instance._buyListRetryCount or 0) >= BUY_EMPTY_STORE_RETRY_LIMIT then
            instance._buyListRetryCount = 0
            TraceVendor(L and L.CATEGORY.LIST, "vendor.buy_retry", "skipped", instance, {
                reason = "storeEmptyAfterRetryLimit",
                entryCount = entryCount,
                maxEmptyStoreRetries = BUY_EMPTY_STORE_RETRY_LIMIT,
            })
        elseif entryCount == 0 and (hasActiveSearch or hasNonDefaultCategory) then
            -- User filtering produced the empty list; nothing to retry.
            instance._buyListRetryCount = 0
            TraceVendor(L and L.CATEGORY.LIST, "vendor.buy_retry", "skipped", instance, {
                reason = "userFilterEmpty",
                hasActiveSearch = hasActiveSearch,
                hasNonDefaultCategory = hasNonDefaultCategory,
            })
        elseif entryCount == 0 and instance:IsSceneActiveOrShowing() then
            local retryCount = (instance._buyListRetryCount or 0) + 1
            instance._buyListRetryCount = retryCount
            if retryCount <= 20 then
                TraceVendor(L and L.CATEGORY.LIST, "vendor.buy_retry", "scheduled", instance, {
                    retryCount = retryCount,
                    delayMs = 180,
                })
                Vendor.Tasks:Cancel("buyListRetry")
                Vendor.Tasks:Schedule("buyListRetry", 180, function()
                    if Vendor.ShouldAbortDeferredVendorRefresh
                        and Vendor.ShouldAbortDeferredVendorRefresh(instance, MODE.BUY) then
                        TraceVendor(L and L.CATEGORY.LIST, "vendor.buy_retry", "aborted", instance, {
                            retryCount = retryCount,
                            reason = "deferredRefreshAbort",
                        })
                        return
                    end
                    if Vendor.EnsureNativeStoreComponents then
                        Vendor.EnsureNativeStoreComponents("storeTextSearch")
                    end
                    TraceVendor(L and L.CATEGORY.LIST, "vendor.buy_retry", "refresh_begin", instance, {
                        retryCount = retryCount,
                    })
                    instance:ApplyNativeStoreMode(MODE.BUY)
                    instance:RefreshList()
                    TraceVendor(L and L.CATEGORY.LIST, "vendor.buy_retry", "refresh_end", instance, {
                        retryCount = retryCount,
                        rowCount = CountVendorList(instance),
                    })
                end)
            else
                TraceVendor(L and L.CATEGORY.LIST, "vendor.buy_retry", "skipped", instance, {
                    retryCount = retryCount,
                    reason = "retryLimit",
                })
            end
        else
            instance._buyListRetryCount = 0
        end
    else
        instance._buyListRetryCount = 0
    end

    TraceVendor(L and L.CATEGORY.LIST, "vendor.list_refresh", "end", instance, {
        rowCount = CountVendorList(instance),
    })
end
