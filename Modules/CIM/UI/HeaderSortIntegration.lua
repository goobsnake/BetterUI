--[[
File: Modules/CIM/UI/HeaderSortIntegration.lua
Purpose: Installs the shared header-sort owner contract.
         One integration object now owns owner methods, keybind swapping,
         optional list-start entry, and navigation suspension hooks.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

BETTERUI.CIM.UI.HeaderSortIntegration = {}

local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration

local function HasLegacyValue(value)
    if value == nil then
        return false
    end

    if type(value) == "boolean" then
        return value
    end

    return true
end

---@param options BetterUIHeaderSortInstallOptions|BetterUIHeaderSortLegacyInstallOptions|table|nil
---@return boolean
local function HasLegacyInstallShape(options)
    if not options then
        return false
    end

    return HasLegacyValue(options.controller)
        or HasLegacyValue(options.controllerField)
        or HasLegacyValue(options.controllerAliasFields)
        or HasLegacyValue(options.headerControllerFn)
        or HasLegacyValue(options.initControllerFn)
        or HasLegacyValue(options.keybindDescriptor)
        or HasLegacyValue(options.mainKeybindDescriptor)
        or HasLegacyValue(options.deactivateNavigationFn)
        or HasLegacyValue(options.reactivateNavigationFn)
        or HasLegacyValue(options.onSortChangedCallback)
        or HasLegacyValue(options.onControllerCreated)
        or HasLegacyValue(options.onEnterHeaderMode)
        or HasLegacyValue(options.onExitHeaderMode)
        or HasLegacyValue(options.suspendTabBar)
end

---@param options BetterUIHeaderSortInstallOptions|BetterUIHeaderSortLegacyInstallOptions|table|nil
---@return BetterUIHeaderSortInstallOptions
local function NormalizeInstallOptions(options)
    options = options or {}

    local controllerContract = options.controllerContract or {}
    local keybinds = options.keybinds or {}
    local navigation = options.navigation or {}
    local callbacks = options.callbacks or {}

    local normalized = {
        list = options.list,
        listFn = options.listFn,
        columns = options.columns,
        controllerContract = {
            instance = controllerContract.instance,
            field = controllerContract.field or "headerSortController",
            aliasFields = controllerContract.aliasFields or {},
            resolve = controllerContract.resolve,
            initialize = controllerContract.initialize,
        },
        keybinds = {
            mainDescriptor = keybinds.mainDescriptor,
        },
        navigation = {
            deactivate = navigation.deactivate,
            reactivate = navigation.reactivate,
            suspendTabBar = navigation.suspendTabBar,
        },
        callbacks = {
            onSortChanged = callbacks.onSortChanged,
            onControllerCreated = callbacks.onControllerCreated,
            onEnterHeaderMode = callbacks.onEnterHeaderMode,
            onExitHeaderMode = callbacks.onExitHeaderMode,
        },
        createControllerFn = options.createControllerFn,
        autoEnterOnListStart = options.autoEnterOnListStart == true,
        usesLegacyShape = false,
    }

    if not HasLegacyInstallShape(options) then
        return normalized
    end

    normalized.usesLegacyShape = true
    normalized.controllerContract.instance = normalized.controllerContract.instance or options.controller
    normalized.controllerContract.field = controllerContract.field or options.controllerField or normalized.controllerContract.field
    normalized.controllerContract.aliasFields = controllerContract.aliasFields or options.controllerAliasFields or normalized.controllerContract.aliasFields
    normalized.controllerContract.resolve = controllerContract.resolve or options.headerControllerFn
    normalized.controllerContract.initialize = controllerContract.initialize or options.initControllerFn

    normalized.keybinds.mainDescriptor = normalized.keybinds.mainDescriptor
        or options.keybindDescriptor
        or options.mainKeybindDescriptor

    normalized.navigation.deactivate = normalized.navigation.deactivate or options.deactivateNavigationFn
    normalized.navigation.reactivate = normalized.navigation.reactivate or options.reactivateNavigationFn
    if normalized.navigation.suspendTabBar == nil then
        normalized.navigation.suspendTabBar = options.suspendTabBar == true
    end

    normalized.callbacks.onSortChanged = normalized.callbacks.onSortChanged or options.onSortChangedCallback
    normalized.callbacks.onControllerCreated = normalized.callbacks.onControllerCreated or options.onControllerCreated
    normalized.callbacks.onEnterHeaderMode = normalized.callbacks.onEnterHeaderMode or options.onEnterHeaderMode
    normalized.callbacks.onExitHeaderMode = normalized.callbacks.onExitHeaderMode or options.onExitHeaderMode

    return normalized
end

---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortControllerContract
local function NormalizeControllerContract(options)
    local contract = options and options.controllerContract or {}
    return {
        instance = contract.instance or nil,
        field = contract.field or "headerSortController",
        aliasFields = contract.aliasFields or {},
        resolve = contract.resolve or nil,
        initialize = contract.initialize or nil,
    }
end

---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortKeybindContract
local function NormalizeKeybindContract(options)
    local contract = options and options.keybinds or {}
    return {
        mainDescriptor = contract.mainDescriptor or nil,
    }
end

---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortNavigationContract
local function NormalizeNavigationContract(options)
    local contract = options and options.navigation or {}
    return {
        deactivate = contract.deactivate or nil,
        reactivate = contract.reactivate or nil,
        suspendTabBar = contract.suspendTabBar == true,
    }
end

---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortCallbackContract
local function NormalizeCallbackContract(options)
    local contract = options and options.callbacks or {}
    return {
        onSortChanged = contract.onSortChanged or nil,
        onControllerCreated = contract.onControllerCreated or nil,
        onEnterHeaderMode = contract.onEnterHeaderMode or nil,
        onExitHeaderMode = contract.onExitHeaderMode or nil,
    }
end

local function ResolveList(integration)
    if integration.listFn then
        return integration.listFn(integration.owner)
    end

    return integration.list or (integration.owner and (integration.owner.list or integration.owner.itemList))
end

---@param integration BetterUIHeaderSortIntegration
---@param controller table|nil
local function AssignController(integration, controller)
    if not controller then
        return nil
    end

    local owner = integration.owner
    local controllerContract = integration.controllerContract
    local controllerField = controllerContract.field
    if owner and controllerField then
        owner[controllerField] = controller
    end

    for _, aliasField in ipairs(controllerContract.aliasFields or {}) do
        if owner and aliasField then
            owner[aliasField] = controller
        end
    end

    integration.controller = controller

    if integration.callbacks.onControllerCreated then
        integration.callbacks.onControllerCreated(owner, controller, ResolveList(integration))
    end

    return controller
end

---@param integration BetterUIHeaderSortIntegration
local function BuildController(integration)
    local list = ResolveList(integration)
    if integration.createControllerFn then
        return integration.createControllerFn(integration.owner, list)
    end

    if integration.columns then
        local controllerClass = BETTERUI.CIM and BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortController
        if controllerClass and controllerClass.New then
            return controllerClass:New(list, integration.columns, integration.callbacks.onSortChanged)
        end
    end

    return nil
end

---@param integration BetterUIHeaderSortIntegration
local function ResolveController(integration)
    if integration.controller then
        return integration.controller
    end

    local owner = integration.owner
    local controllerContract = integration.controllerContract
    if owner and controllerContract.field and owner[controllerContract.field] then
        integration.controller = owner[controllerContract.field]
        return integration.controller
    end

    if controllerContract.initialize then
        controllerContract.initialize(integration.owner)
    end

    if controllerContract.resolve then
        local resolvedController = controllerContract.resolve(integration.owner)
        if resolvedController then
            return AssignController(integration, resolvedController)
        end
    end

    return AssignController(integration, BuildController(integration))
end

local function SuspendOwnerTabBar(owner)
    if not owner then
        return
    end
    local tabBar = owner and owner.headerGeneric and owner.headerGeneric.tabBar
    owner._reactivateTabBarAfterHeaderSort = false
    if tabBar and tabBar.active and tabBar.Deactivate then
        tabBar:Deactivate()
        owner._reactivateTabBarAfterHeaderSort = true
    end
end

local function RestoreOwnerTabBar(owner)
    if not owner or not owner._reactivateTabBarAfterHeaderSort then
        return
    end

    owner._reactivateTabBarAfterHeaderSort = false
    local tabBar = owner.headerGeneric and owner.headerGeneric.tabBar
    if tabBar and tabBar.Activate then
        tabBar:Activate()
    end
end

local function GetHeaderKeybindDescriptor(integration, controller)
    if not controller then
        return nil
    end

    if not controller._headerSortKeybindDescriptor and controller.CreateKeybindDescriptor then
        controller._headerSortKeybindDescriptor = controller:CreateKeybindDescriptor(function()
            HeaderSortIntegration.ExitHeaderMode(integration)
        end)
    end

    return controller._headerSortKeybindDescriptor
end

--- Installs the shared header sort owner contract.
---@param owner table
---@param options BetterUIHeaderSortInstallOptions|BetterUIHeaderSortLegacyInstallOptions|table|nil
---@return BetterUIHeaderSortIntegration integration
function HeaderSortIntegration.Install(owner, options)
    local installOptions = NormalizeInstallOptions(options)

    local controllerContract = NormalizeControllerContract(installOptions)
    local keybinds = NormalizeKeybindContract(installOptions)
    local navigation = NormalizeNavigationContract(installOptions)
    local callbacks = NormalizeCallbackContract(installOptions)

    local integration = {
        owner = owner,
        list = installOptions.list,
        listFn = installOptions.listFn,
        controller = controllerContract.instance,
        controllerContract = controllerContract,
        columns = installOptions.columns,
        callbacks = callbacks,
        createControllerFn = installOptions.createControllerFn,
        keybinds = keybinds,
        keybindDescriptor = keybinds.mainDescriptor,
        navigation = navigation,
        controllerField = controllerContract.field,
        controllerAliasFields = controllerContract.aliasFields,
        autoEnterOnListStart = installOptions.autoEnterOnListStart == true,
        usesLegacyShape = installOptions.usesLegacyShape == true,
        isActive = false,
        activeKeybindDescriptor = nil,
    }

    if navigation.suspendTabBar then
        navigation.deactivate = navigation.deactivate or SuspendOwnerTabBar
        navigation.reactivate = navigation.reactivate or RestoreOwnerTabBar
    end

    owner._headerSortIntegration = integration

    function owner:EnterHeaderSortMode()
        return HeaderSortIntegration.EnterHeaderMode(integration)
    end

    function owner:ExitHeaderSortMode()
        return HeaderSortIntegration.ExitHeaderMode(integration)
    end

    if integration.autoEnterOnListStart then
        local list = ResolveList(integration)
        if list and list.SetOnHitBeginningOfListCallback then
            list:SetOnHitBeginningOfListCallback(function()
                if not integration.isActive then
                    owner:EnterHeaderSortMode()
                end
            end)
        end
    end

    return integration
end

--- Backward-compatible wrapper for older static-list callers.
---@param list table
---@param controller table
---@param options BetterUIHeaderSortLegacyInstallOptions|BetterUIHeaderSortInstallOptions|table|nil
---@return BetterUIHeaderSortIntegration integration
function HeaderSortIntegration.Setup(list, controller, options)
    options = options or {}
    local owner = options.owner or { list = list }
    options.list = list
    options.controller = controller
    if options.autoEnterOnListStart == nil then
        options.autoEnterOnListStart = true
    end
    return HeaderSortIntegration.Install(owner, options)
end

--- Enters header sort navigation mode.
---@param integration BetterUIHeaderSortIntegration
---@return boolean
function HeaderSortIntegration.EnterHeaderMode(integration)
    if integration.isActive then
        return false
    end

    local owner = integration.owner
    local navigationSuspended = false
    if integration.navigation.deactivate then
        integration.navigation.deactivate(owner)
        navigationSuspended = true
    end

    local list = ResolveList(integration)
    if not list or not list.GetNumItems or list:GetNumItems() == 0 then
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    local controller = ResolveController(integration)
    if not controller or not controller.EnterHeaderMode then
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    if controller:EnterHeaderMode() == false then
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    integration.controller = controller
    integration.isActive = true
    owner.isInHeaderSortMode = true

    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)

    if KEYBIND_STRIP and KEYBIND_STRIP.RemoveAllKeyButtonGroups then
        KEYBIND_STRIP:RemoveAllKeyButtonGroups()
    end

    integration.activeKeybindDescriptor = GetHeaderKeybindDescriptor(integration, controller)
    if integration.activeKeybindDescriptor and KEYBIND_STRIP and KEYBIND_STRIP.AddKeybindButtonGroup then
        KEYBIND_STRIP:AddKeybindButtonGroup(integration.activeKeybindDescriptor)
    end

    if integration.callbacks.onEnterHeaderMode then
        integration.callbacks.onEnterHeaderMode(owner, controller, list)
    end

    return true
end

--- Exits header sort navigation mode and returns to the list.
---@param integration BetterUIHeaderSortIntegration
---@return boolean
function HeaderSortIntegration.ExitHeaderMode(integration)
    if not integration.isActive then
        return false
    end

    local owner = integration.owner
    local controller = integration.controller or ResolveController(integration)

    integration.isActive = false
    owner.isInHeaderSortMode = false

    if controller and controller.ExitHeaderMode then
        controller:ExitHeaderMode()
    end

    PlaySound(SOUNDS.GAMEPAD_MENU_BACK)

    if integration.activeKeybindDescriptor and KEYBIND_STRIP and KEYBIND_STRIP.RemoveKeybindButtonGroup then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(integration.activeKeybindDescriptor)
        integration.activeKeybindDescriptor = nil
    end

    if integration.keybinds.mainDescriptor and KEYBIND_STRIP and KEYBIND_STRIP.AddKeybindButtonGroup then
        KEYBIND_STRIP:AddKeybindButtonGroup(integration.keybinds.mainDescriptor)
        if KEYBIND_STRIP.UpdateKeybindButtonGroup then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(integration.keybinds.mainDescriptor)
        end
    end

    if owner.EnsureHeaderKeybindsActive then
        owner:EnsureHeaderKeybindsActive()
    end

    if integration.navigation.reactivate then
        integration.navigation.reactivate(owner)
    end

    if integration.callbacks.onExitHeaderMode then
        integration.callbacks.onExitHeaderMode(owner, controller)
    end

    return true
end

---@param integration BetterUIHeaderSortIntegration|nil
---@return table?
function HeaderSortIntegration.EnsureController(integration)
    if not integration then
        return nil
    end
    return ResolveController(integration)
end

---@param owner table?
---@return table?
function HeaderSortIntegration.GetController(owner)
    if not owner then
        return nil
    end

    if owner._headerSortIntegration then
        return ResolveController(owner._headerSortIntegration)
    end

    return owner.headerSortController or owner.sortController
end

---@param integration BetterUIHeaderSortIntegration|nil
---@return boolean
function HeaderSortIntegration.IsActive(integration)
    return integration and integration.isActive or false
end

--- Backward-compatible wrapper around the unified installer.
---@param instance table
---@param config BetterUIHeaderSortLegacyInstallOptions|BetterUIHeaderSortInstallOptions|table
---@return table?
function HeaderSortIntegration.ApplyMixin(instance, config)
    if not instance or not config then
        return nil
    end

    return HeaderSortIntegration.Install(instance, config)
end
