--[[
File: Modules/Vendor/Core/Lifecycle/VendorControllerRuntime.lua
Purpose: Own vendor controller transitions, list refresh, and native-store recovery so VendorClass stays coordinator-focused.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.ControllerRuntime = Vendor.ControllerRuntime or {}
local ControllerRuntime = Vendor.ControllerRuntime

local MODE = assert(Vendor.MODE, "Vendor mode constants must load before controller runtime")

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
        KEYBIND_STRIP:RemoveKeybindButtonGroup(storeManager.keybindStripDescriptor)
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
    if not mode or instance.currentMode == mode then
        return
    end

    local headerNavigation = BETTERUI.CIM and BETTERUI.CIM.HeaderNavigation or nil
    local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(instance) or nil
    if state then
        state.justToggledMode = true
    end

    instance:SaveListPosition()

    local oldComponent = instance:GetActiveComponent()
    if oldComponent and oldComponent.Deactivate then
        oldComponent:Deactivate(instance)
    end

    instance.currentMode = mode

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
        newComponent:Activate(instance)
    end

    if instance:IsSceneShowing() and KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end

    instance:RebuildCategoryHeader()
    instance:RefreshVendorFooter()
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function ControllerRuntime.RefreshList(instance, deps)
    if instance._suppressListUpdates then
        instance._isDirty = true
        return
    end

    if not instance.list then
        return
    end

    instance:ApplyListLayoutTuning()

    local component = instance:GetActiveComponent()
    if component and component.GetCategories then
        instance:SetModeCategories(instance:GetCurrentMode(), component:GetCategories(instance))
    else
        instance:SetModeCategories(instance:GetCurrentMode(), nil)
    end

    instance.list:Clear()

    if component and component.BuildList then
        component:BuildList(instance)
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

    instance:ApplySortToList()
    instance.list:Commit()
    instance._isDirty = false

    if currentMode and instance.list and instance.list.dataList and #instance.list.dataList > 0 then
        local moduleKey = deps.getModeModuleKey(currentMode)
        local categoryKey = deps.getCategoryKey(instance)
        local targetIndex = BETTERUI.CIM.PositionManager.RestorePosition(moduleKey, categoryKey, instance.list, instance.list.dataList)
        if instance.list.SetSelectedIndexWithoutAnimation then
            instance.list:SetSelectedIndexWithoutAnimation(targetIndex, true, false)
        elseif instance.list.SetSelectedIndex then
            instance.list:SetSelectedIndex(targetIndex)
        end
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
        if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
            KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
        end
    end
    instance:UpdateScrollIndicator(instance.list)

    if instance:GetCurrentMode() == MODE.BUY then
        local entryCount = (instance.list.dataList and #instance.list.dataList) or 0
        if entryCount == 0 and instance:IsSceneActiveOrShowing() then
            local retryCount = (instance._buyListRetryCount or 0) + 1
            instance._buyListRetryCount = retryCount
            if retryCount <= 20 then
                Vendor.Tasks:Cancel("buyListRetry")
                Vendor.Tasks:Schedule("buyListRetry", 180, function()
                    if Vendor.ShouldAbortDeferredVendorRefresh
                        and Vendor.ShouldAbortDeferredVendorRefresh(instance, MODE.BUY) then
                        return
                    end
                    if Vendor.EnsureNativeStoreComponents then
                        Vendor.EnsureNativeStoreComponents("storeTextSearch")
                    end
                    instance:ApplyNativeStoreMode(MODE.BUY)
                    instance:RefreshList()
                end)
            end
        else
            instance._buyListRetryCount = 0
        end
    else
        instance._buyListRetryCount = 0
    end
end
